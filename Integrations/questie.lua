-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Original consumer of Questie's public callback API. A receipt says only that
-- RM received an update; it does not describe current quest progress.
-- Owns addon.Integrations.NewQuestie, a service that registers once with Questie's API (RegisterOnReady and
-- RegisterForQuestUpdates), keeps at most 64 update receipts that expire after 30 seconds, and publishes a status
-- (missing, waiting, available, incompatible, client-restricted, error, disabled). Must not read quest state from the
-- game or from Questie beyond those callbacks, and never lets a provider error escape: only owned reason codes leave.
-- The session instance is created and synced by main.lua (InitializeQuestieIntegration, SyncQuestieIntegration).
-- Loaded from RotationMaster.toc after UI/lua_editor.lua; declared on Era, TBC, progression and Forever.
local _, addon = ...
addon.Integrations = addon.Integrations or {}
local supported = { era = true, tbc = true, progression = true, forever = true }
local families = { era = true, tbc = true, progression = true, forever = true, retail = true, unknown = true }
local reasonNames = { 'accepted', 'updated', 'turned-in', 'abandoned' }
local enumNames = { 'QUEST_ACCEPTED', 'QUEST_UPDATED', 'QUEST_TURNED_IN', 'QUEST_ABANDONED' }
local retired = {}
local ownedFault = {}

-- ============================================================================
-- Value helpers
-- ============================================================================

-- Returns a shallow copy of a table.
-- @param source table  The table to copy.
-- @return table  The copy.
local function copy(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

-- Tells whether a value is a real finite number (not NaN, not infinite).
-- @param value any  The value to test.
-- @return boolean  True when it is.
local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

-- Tells whether a value is a positive whole number.
-- @param value any  The value to test.
-- @return boolean  True when it is.
local function positiveInteger(value)
    return finite(value) and value > 0 and value % 1 == 0
end

-- Builds the answer of every reader when no receipt can be given.
-- @param reason string  The reason code.
-- @return table  {status="unavailable", reason=reason}.
local function unavailable(reason)
    return { status = 'unavailable', reason = reason }
end

-- ============================================================================
-- Questie service
-- ============================================================================

-- Creates the Questie service.
-- @param options table|nil  All fields optional, used by tests: resolve() describing the provider, now() for the clock,
--   readable(value) for the readability check, onChange(status) called when the status changes.
-- @return table  The service (GetStatus, Refresh, SetEnabled, GetRecentUpdate, Dispose).
--
-- Every asynchronous piece of work carries the epoch (generation) it started in and is dropped if the service has been
-- refreshed, disabled or disposed since; provider callbacks never run nested (callbackBusy).
function addon.Integrations.NewQuestie(options)
    options = options or {}
    local resolve, now, readable, onChange = options.resolve, options.now, options.readable, options.onChange
    local service = {}
    local enabled, disposed, epoch = false, false, 0
    local failureOwner, probeMetadata, metadataEpoch
    local binding, receipts, count, lastClock, sequence = nil, {}, 0, nil, 0
    local notifying, callbackBusy = false, false

    -- Creates a new table with weak keys.
    -- @return table  The table.
    local function weakKeys()
        return setmetatable({}, { __mode = 'k' })
    end

    -- Boolean attempt markers survive logical detach without retaining an API.
    -- Weak values keep immutable function contracts from rooting provider cycles.
    local seenReady, seenUpdates, failedReady, failedUpdates = weakKeys(), weakKeys(), weakKeys(), weakKeys()
    local contracts = setmetatable({}, { __mode = 'kv' })

    local status = {
        state = 'disabled',
        reason = 'disabled',
        enabled = false,
        provider = 'Questie',
        versionStatus = 'unverified',
        family = 'unknown',
        familyContract = 'unsupported',
        nativeAcceptance = 'unverified',
        coverage = 'recent-update-receipts-only',
        generation = 0,
    }

    -- Forgets every receipt.
    local function clear()
        receipts = {}
        count = 0
        lastClock = nil
    end

    -- Starts a new epoch, which invalidates all work in flight, and drops the binding and receipts.
    -- @return number  The new epoch.
    local function retire()
        epoch = epoch + 1
        failureOwner = nil
        binding = nil
        clear()
        return epoch
    end

    -- Aborts the current work (with the private "retired" marker) when epoch g is no longer the live one.
    -- @param g number  The epoch the work belongs to.
    local function guard(g)
        if disposed or not enabled or epoch ~= g then
            error(retired, 0)
        end
    end

    -- Aborts the current work with an owned failure; execute turns it into the published state and reason.
    -- @param state string  The state to publish.
    -- @param reason string  The reason code to publish.
    local function fault(state, reason)
        error({ owner = ownedFault, state = state, reason = reason }, 0)
    end

    -- Calls fn under pcall between two guards.
    -- @param g number  The epoch the work belongs to; a call that retired it (a provider calling back into this
    --   service) aborts the work.
    -- @param fn function|nil  The function to call; anything else faults.
    -- @param reason string  The reason code of the fault raised when fn is missing or throws.
    -- @param ... any  The arguments passed to fn.
    -- @return any  The first result of fn.
    local function call(g, fn, reason, ...)
        guard(g)

        if type(fn) ~= 'function' then
            fault('error', reason)
        end

        local ok, result = pcall(fn, ...)
        guard(g)

        if not ok then
            fault('error', reason)
        end

        return result
    end

    -- Proves a value readable (not a secret).
    -- @param g number  The epoch the work belongs to.
    -- @param value any  The value to check.
    -- @return any  The value unchanged; a restricted value faults as "client-restricted".
    local function read(g, value)
        local accepted

        if readable then
            accepted = call(g, readable, 'readability-error', value)
        else
            local platform = addon.Platform
            accepted = call(g, platform and platform.CanReadValue, 'readability-error', platform, value)
        end

        if accepted ~= true then
            fault('client-restricted', 'restricted-value')
        end

        return value
    end

    -- Reads object[key] without metamethods and proves it readable.
    -- @param g number  The epoch the work belongs to.
    -- @param object table  The table to read from.
    -- @param key any  The key.
    -- @return any  The value (a restricted value faults as "client-restricted").
    local function field(g, object, key)
        return read(g, rawget(object, key))
    end

    -- Describes Questie from the live client: client family, whether it is loaded, its version and its public API
    -- table.
    -- @param g number  The epoch the work belongs to.
    -- @return table  {loaded=boolean, api=table|nil, version=string|nil, family=string}.
    local function defaultResolve(g)
        local platform = addon.Platform
        local info = call(g, platform and platform.GetClientInfo, 'resolver-error', platform)
        read(g, info)

        if type(info) ~= 'table' then
            fault('error', 'resolver-error')
        end

        local family = field(g, info, 'family')
        local native = C_AddOns
        local loadedFn = type(native) == 'table' and rawget(native, 'IsAddOnLoaded') or IsAddOnLoaded
        local loaded = read(g, call(g, loadedFn, 'resolver-error', 'Questie'))
        local versionFn = type(native) == 'table' and rawget(native, 'GetAddOnMetadata') or GetAddOnMetadata
        local version

        if type(versionFn) == 'function' then
            version = read(g, call(g, versionFn, 'resolver-error', 'Questie', 'Version'))
        end

        local api

        if loaded == true then
            local provider = read(g, rawget(_G, 'Questie'))

            if type(provider) == 'table' then
                api = field(g, provider, 'API')
            end
        end

        return { loaded = loaded, api = api, version = version, family = family }
    end

    -- Resolves the provider and validates its whole contract: registration functions, readiness flag and the quest
    -- update reason enum (it must match the four values RM maps).
    -- @param g number  The epoch the work belongs to.
    -- @return table  A result with state and reason (missing, incompatible, waiting or available) and, when usable, the
    --   API and its functions (api, readyFn, updateFn, ready); an invalid shape faults.
    local function probe(g)
        local source = resolve and call(g, resolve, 'resolver-error') or defaultResolve(g)
        read(g, source)

        if type(source) ~= 'table' then
            fault('incompatible', 'invalid-source')
        end

        local loaded = field(g, source, 'loaded')
        local family = field(g, source, 'family')
        local version = field(g, source, 'version')
        family = type(family) == 'string' and families[family] and family or 'unknown'
        version = type(version) == 'string' and version:sub(1, 64):gsub('%c', '?') or nil
        probeMetadata = { family = family, version = version }
        metadataEpoch = g
        local result = { family = family, version = version, state = 'missing', reason = 'provider-missing' }

        if loaded == false or loaded == nil then
            return result
        end

        if loaded ~= true then
            fault('incompatible', 'invalid-loaded')
        end

        local api = field(g, source, 'api')

        if api == nil then
            return result
        end

        if not supported[family] then
            result.state = 'incompatible'
            result.reason = 'unsupported-client'
            return result
        end

        if type(api) ~= 'table' then
            fault('incompatible', 'invalid-api')
        end

        local readyFn = field(g, api, 'RegisterOnReady')
        local updateFn = field(g, api, 'RegisterForQuestUpdates')

        if type(readyFn) ~= 'function' or type(updateFn) ~= 'function' then
            fault('incompatible', 'invalid-registration')
        end

        local ready = field(g, api, 'isReady')

        if type(ready) ~= 'boolean' then
            fault('incompatible', 'invalid-readiness')
        end

        local enums = field(g, api, 'Enums')

        if type(enums) ~= 'table' then
            fault('incompatible', 'invalid-enums')
        end

        local reasons = field(g, enums, 'QuestUpdateTriggerReason')

        if type(reasons) ~= 'table' then
            fault('incompatible', 'invalid-enums')
        end

        for index, key in ipairs(enumNames) do
            if field(g, reasons, key) ~= index then
                fault('incompatible', 'invalid-enums')
            end
        end

        result.api = api
        result.readyFn = readyFn
        result.updateFn = updateFn
        result.ready = ready
        result.state = ready and 'available' or 'waiting'
        result.reason = ready and 'ready' or 'provider-waiting'
        return result
    end

    -- Rebuilds the status table for a new state and reason.
    -- @param state string  The new state.
    -- @param reason string  The new reason code.
    -- @param source table|nil  When given, the version and family are taken from it.
    -- @return boolean  True when anything changed.
    local function cache(state, reason, source)
        local nextStatus = copy(status)
        nextStatus.state = state
        nextStatus.reason = reason
        nextStatus.enabled = enabled
        nextStatus.generation = epoch

        if source then
            nextStatus.version = source.version
            nextStatus.family = source.family
        end

        nextStatus.versionStatus = nextStatus.version == '12.1.0' and 'source-tested' or 'unverified'
        nextStatus.familyContract = supported[nextStatus.family] and 'declared-unverified' or 'unsupported'
        local changed = false

        for key, value in pairs(nextStatus) do
            if status[key] ~= value then
                changed = true
            end
        end

        for key, value in pairs(status) do
            if nextStatus[key] ~= value then
                changed = true
            end
        end

        status = nextStatus
        return changed
    end

    -- Calls onChange with a copy of the status, once at a time.
    -- @param g number|nil  The epoch the notification belongs to; nothing is changed if it was superseded.
    -- @param owner number|nil  The failure owner recorded when the notification fails; defaults to g.
    --
    -- A failing notification retires the service into an "error" status, unless a newer operation or disposal has
    -- already replaced this one.
    local function notify(g, owner)
        if not onChange or notifying then
            return
        end

        local notificationEpoch = epoch
        notifying = true
        local ok = pcall(onChange, copy(status))
        notifying = false

        -- The notification may itself retire this operation. A failing stale
        -- notification cannot overwrite a newer owner or terminal disposal.
        if disposed or epoch ~= notificationEpoch or (g and epoch ~= g) then
            return
        end

        if not ok then
            retire()
            failureOwner = owner or g
            cache('error', 'notification-error')
        end
    end

    -- Publishes a new status for an epoch (notifying on change).
    -- @param g number  The epoch the work belongs to.
    -- @param state string  The new state.
    -- @param reason string  The new reason code.
    -- @param source table|nil  When given, the version and family are taken from it.
    -- @return table  A copy of the status.
    local function publish(g, state, reason, source)
        guard(g)

        if cache(state, reason, source) then
            notify(g)
        end

        guard(g)
        return copy(status)
    end

    -- Runs body(g) under pcall and is the only boundary errors cross.
    -- @param g number  The epoch the work belongs to.
    -- @param body function  The work, called as body(g).
    -- @return any|nil  The body's result; nil for a superseded run or a failure.
    --
    -- A superseded run returns nil quietly; any other failure retires the service and publishes its owned state and
    -- reason (arbitrary errors become "adapter-error").
    local function execute(g, body)
        local ok, result = pcall(body, g)

        if ok then
            return result
        end
        if rawequal(result, retired) or epoch ~= g or disposed or not enabled then
            return nil
        end

        -- Only owned codes leave this boundary. Arbitrary exceptions stay private.
        local state, reason = 'error', 'adapter-error'

        if type(result) == 'table' and rawequal(rawget(result, 'owner'), ownedFault) then
            state, reason = rawget(result, 'state'), rawget(result, 'reason')
        end

        local metadata = metadataEpoch == g and probeMetadata or nil
        retire()
        failureOwner = g
        cache(state, reason, metadata)
        notify(epoch, g)
        return nil
    end

    -- Reads the clock.
    -- @param g number  The epoch the work belongs to.
    -- @return number  The time; a non-finite value or one that runs backwards faults, so that expiry arithmetic stays
    --   sound.
    local function clock(g)
        local value

        if now then
            value = read(g, call(g, now, 'clock-error'))
        else
            value = read(g, call(g, GetTime, 'clock-error'))
        end

        if not finite(value) or not finite(value + 30) or (lastClock and value < lastClock) then
            fault('error', 'invalid-clock')
        end

        lastClock = value
        return value
    end

    -- Tells whether a freshly probed source is the same provider (same API table, functions and family) as the binding.
    -- @param source table  The probed source.
    -- @param current table|nil  The current binding.
    -- @return boolean|nil  True when they are the same; false or nil otherwise.
    local function same(source, current)
        return current
            and rawequal(source.api, current.api)
            and source.readyFn == current.readyFn
            and source.updateFn == current.updateFn
            and source.family == current.family
    end

    -- Probes again before trusting a callback.
    -- @param g number  The epoch the work belongs to.
    -- @param current table  The current binding.
    -- @param requireReady boolean  True to also require that the provider is ready.
    -- @return table  The fresh source.
    --
    -- If the provider changed (or is not ready when requireReady), retires the service with "source-changed" and
    -- aborts.
    local function verify(g, current, requireReady)
        local source = probe(g)

        if not same(source, current) or (requireReady and source.ready ~= true) then
            retire()
            cache(source.state == 'available' and 'waiting' or source.state, 'source-changed', source)
            notify(epoch)
            error(retired, 0)
        end

        return source
    end

    local attachUpdates, readyCallback, updateCallback

    -- Returns the immutable pair of registration functions recorded for this API table the first time it was seen.
    -- @param g number  The epoch the work belongs to.
    -- @param source table  The probed source (api, readyFn, updateFn).
    -- @return table  {readyFn=function, updateFn=function}.
    --
    -- A changed pair, an earlier attempt whose outcome is unknown, or a failed attempt faults: RM never registers twice
    -- with the same provider, because the contract it consumes has no unregister call.
    local function contractFor(g, source)
        local api = source.api
        local contract = contracts[api]

        if contract then
            if contract.readyFn ~= source.readyFn or contract.updateFn ~= source.updateFn then
                fault('incompatible', 'registration-changed')
            end
        elseif seenReady[api] or seenUpdates[api] then
            fault('error', 'registration-unconfirmed')
        else
            contract = { readyFn = source.readyFn, updateFn = source.updateFn }
            contracts[api] = contract
        end

        if failedReady[api] or failedUpdates[api] then
            fault('error', 'registration-failed')
        end

        guard(g)
        return contract
    end

    -- Registers the quest update callback with the provider, once per API table.
    -- @param g number  The epoch the work belongs to.
    -- @param current table  The current binding.
    -- @param contract table  The registration functions recorded for the API.
    --
    -- The attempt is recorded before the call, so a retry after a failure or a refresh never registers a second time.
    attachUpdates = function(g, current, contract)
        guard(g)

        if seenUpdates[current.api] then
            return
        end

        seenUpdates[current.api] = true
        local api = current.api

        local callback = function(...)
            updateCallback(api, contract, ...)
        end

        local ok = pcall(contract.updateFn, callback)

        -- Attempt outcome belongs to this API even if the call retired its
        -- status owner. Record it before guarding publication authority.
        if not ok then
            failedUpdates[api] = true
        end

        guard(g)

        if not ok then
            fault('error', 'update-registration-error')
        end
    end

    -- Provider callback: Questie became ready. Re-verifies the provider, attaches the update callback and publishes
    -- "available".
    -- @param api table  The API table the callback was registered with.
    -- @param contract table  The registration functions recorded for the API.
    --
    -- Ignored when it is not for the current binding or runs nested.
    readyCallback = function(api, contract)
        if
            callbackBusy
            or disposed
            or not enabled
            or not binding
            or not rawequal(binding.api, api)
            or binding.readyFn ~= contract.readyFn
            or binding.updateFn ~= contract.updateFn
        then
            return
        end

        local current = binding
        local g = epoch
        callbackBusy = true

        execute(g, function()
            local source = verify(g, current, false)

            if source.ready ~= true then
                return
            end

            attachUpdates(g, current, contract)

            if status.state ~= 'available' then
                publish(g, 'available', 'ready', source)
            end
        end)

        callbackBusy = false
    end

    -- Provider callback: a quest update. Validates every argument, then stores a receipt for 30 seconds, evicting
    -- expired ones and, at 64, the oldest.
    -- @param api table  The API table the callback was registered with.
    -- @param contract table  The registration functions recorded for the API.
    -- @param id number  The quest ID.
    -- @param index number|nil  The objective index.
    -- @param reason number  The trigger reason, 1 to 4.
    --
    -- Anything invalid is silently ignored.
    updateCallback = function(api, contract, id, index, reason)
        if
            callbackBusy
            or disposed
            or not enabled
            or not binding
            or not rawequal(binding.api, api)
            or binding.readyFn ~= contract.readyFn
            or binding.updateFn ~= contract.updateFn
        then
            return
        end

        local current = binding
        local g = epoch
        callbackBusy = true

        execute(g, function()
            verify(g, current, true)
            read(g, id)

            if not positiveInteger(id) then
                return
            end

            read(g, index)

            if index ~= nil and not positiveInteger(index) then
                return
            end

            read(g, reason)

            if not positiveInteger(reason) or reason > 4 then
                return
            end

            local stamp = clock(g)
            guard(g)

            -- Expired entries may be dropped lazily; capacity stays bounded even
            -- if no consumer queries the service.
            for key, row in pairs(receipts) do
                if stamp >= row.expiresAt then
                    receipts[key] = nil
                    count = count - 1
                end
            end

            if receipts[id] == nil and count == 64 then
                local oldest, oldSequence

                for key, row in pairs(receipts) do
                    if not oldSequence or row.sequence < oldSequence then
                        oldest, oldSequence = key, row.sequence
                    end
                end

                receipts[oldest] = nil
                count = count - 1
            end

            if receipts[id] == nil then
                count = count + 1
            end

            sequence = sequence + 1

            receipts[id] = {
                status = 'available',
                source = 'Questie',
                kind = 'quest-update',
                questId = id,
                objectiveIndex = index,
                reason = reasonNames[reason],
                observedAt = stamp,
                expiresAt = stamp + 30,
                sequence = sequence,
                generation = g,
                coverage = 'receipt-only',
            }

            notify(g)
        end)

        callbackBusy = false
    end

    -- Returns a copy of the status.
    -- @return table  {state, reason, enabled, provider, version, family, ...}.
    function service:GetStatus()
        return copy(status)
    end

    -- Probes the provider again and (re)binds to it, publishing the outcome.
    -- @return table|nil  A copy of the status; nil when the service is disposed or a newer operation superseded this
    --   one.
    function service:Refresh()
        if disposed then
            return nil
        end
        if not enabled then
            return copy(status)
        end

        local old = binding
        epoch = epoch + 1
        local g = epoch
        binding = nil

        local result = execute(g, function()
            local source = probe(g)

            if not same(source, old) or source.ready ~= true then
                clear()
            end

            if source.api == nil then
                return publish(g, source.state, source.reason, source)
            end

            local contract = contractFor(g, source)
            binding = source

            -- Reserve both the lease and attempted-registration marker before
            -- calling the provider, whose ready callback can run synchronously.
            if not seenReady[source.api] then
                seenReady[source.api] = true
                local api = source.api

                local callback = function()
                    readyCallback(api, contract)
                end

                local ok = pcall(contract.readyFn, callback)

                if not ok then
                    failedReady[api] = true
                end

                guard(g)

                if not ok then
                    fault('error', 'ready-registration-error')
                end
            end

            source = verify(g, source, false)
            binding = source

            if source.ready then
                attachUpdates(g, source, contract)
            end

            source = verify(g, source, false)
            binding = source

            if not source.ready then
                clear()
            end

            return publish(g, source.state, source.reason, source)
        end)

        if disposed then
            return nil
        end

        if epoch ~= g then
            if failureOwner == g then
                return copy(status)
            end

            return nil
        end

        return result or copy(status)
    end

    -- Turns the integration on (which refreshes it) or off (which drops the binding and receipts).
    -- @param value boolean  True to turn it on, false to turn it off.
    -- @return boolean  True when applied.
    -- @return string|nil  The reason code when false ("disposed" or "invalid-enabled"); nil when true.
    function service:SetEnabled(value)
        if disposed then
            return false, 'disposed'
        end
        if type(value) ~= 'boolean' then
            return false, 'invalid-enabled'
        end

        if value then
            enabled = true
            self:Refresh()
        elseif enabled then
            enabled = false
            retire()
            cache('disabled', 'disabled')
            notify()
        end

        return true
    end

    -- Looks up the receipt for a quest.
    -- @param id number  The quest ID.
    -- @return table  The receipt when Questie reported an update in the last 30 seconds; otherwise an "unavailable"
    --   record {status="unavailable", reason} with the reason ("no-recent-update", "expired", ...).
    --
    -- A receipt only says an update arrived, not what the quest's progress is.
    function service:GetRecentUpdate(id)
        if disposed then
            return unavailable('disposed')
        end
        if not enabled then
            return unavailable('disabled')
        end
        if not binding or status.state ~= 'available' then
            return unavailable(status.reason)
        end

        local current = binding
        local g = epoch

        local result = execute(g, function()
            verify(g, current, true)
            local stamp = clock(g)
            read(g, id)

            if not positiveInteger(id) then
                return unavailable('invalid-quest-id')
            end

            local row = receipts[id]

            if not row then
                return unavailable('no-recent-update')
            end

            if stamp >= row.expiresAt then
                receipts[id] = nil
                count = count - 1
                return unavailable('expired')
            end

            return copy(row)
        end)

        return result or unavailable(status.reason)
    end

    -- Retires the service for good; every later call reports "disposed".
    function service:Dispose()
        if disposed then
            return
        end

        disposed = true
        enabled = false
        retire()
        cache('disabled', 'disposed')
        notify()
    end

    return service
end
