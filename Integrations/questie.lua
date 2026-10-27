-- Original consumer of Questie's public callback API. A receipt says only that
-- RM received an update; it does not describe current quest progress.
local _, addon = ...
addon.Integrations = addon.Integrations or {}
local supported = { era = true, tbc = true, progression = true, forever = true }
local families = { era = true, tbc = true, progression = true, forever = true, retail = true, unknown = true }
local reasonNames = { 'accepted', 'updated', 'turned-in', 'abandoned' }
local enumNames = { 'QUEST_ACCEPTED', 'QUEST_UPDATED', 'QUEST_TURNED_IN', 'QUEST_ABANDONED' }
local retired = {}
local ownedFault = {}

local function copy(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function positiveInteger(value)
    return finite(value) and value > 0 and value % 1 == 0
end

local function unavailable(reason)
    return { status = 'unavailable', reason = reason }
end

function addon.Integrations.NewQuestie(options)
    options = options or {}
    local resolve, now, readable, onChange = options.resolve, options.now, options.readable, options.onChange
    local service = {}
    local enabled, disposed, epoch = false, false, 0
    local failureOwner, probeMetadata, metadataEpoch
    local binding, receipts, count, lastClock, sequence = nil, {}, 0, nil, 0
    local notifying, callbackBusy = false, false

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

    local function clear()
        receipts = {}
        count = 0
        lastClock = nil
    end

    local function retire()
        epoch = epoch + 1
        failureOwner = nil
        binding = nil
        clear()
        return epoch
    end

    local function guard(g)
        if disposed or not enabled or epoch ~= g then error(retired, 0) end
    end

    local function fault(state, reason)
        error({ owner = ownedFault, state = state, reason = reason }, 0)
    end

    local function call(g, fn, reason, ...)
        guard(g)
        if type(fn) ~= 'function' then fault('error', reason) end
        local ok, result = pcall(fn, ...)
        guard(g)
        if not ok then fault('error', reason) end
        return result
    end

    local function read(g, value)
        local accepted

        if readable then
            accepted = call(g, readable, 'readability-error', value)
        else
            local platform = addon.Platform
            accepted = call(g, platform and platform.CanReadValue, 'readability-error', platform, value)
        end

        if accepted ~= true then fault('client-restricted', 'restricted-value') end
        return value
    end

    local function field(g, object, key)
        return read(g, rawget(object, key))
    end

    local function defaultResolve(g)
        local platform = addon.Platform
        local info = call(g, platform and platform.GetClientInfo, 'resolver-error', platform)
        read(g, info)
        if type(info) ~= 'table' then fault('error', 'resolver-error') end
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
            if type(provider) == 'table' then api = field(g, provider, 'API') end
        end

        return { loaded = loaded, api = api, version = version, family = family }
    end

    local function probe(g)
        local source = resolve and call(g, resolve, 'resolver-error') or defaultResolve(g)
        read(g, source)
        if type(source) ~= 'table' then fault('incompatible', 'invalid-source') end
        local loaded = field(g, source, 'loaded')
        local family = field(g, source, 'family')
        local version = field(g, source, 'version')
        family = type(family) == 'string' and families[family] and family or 'unknown'
        version = type(version) == 'string' and version:sub(1, 64):gsub('%c', '?') or nil
        probeMetadata = { family = family, version = version }
        metadataEpoch = g
        local result = { family = family, version = version, state = 'missing', reason = 'provider-missing' }
        if loaded == false or loaded == nil then return result end
        if loaded ~= true then fault('incompatible', 'invalid-loaded') end
        local api = field(g, source, 'api')
        if api == nil then return result end

        if not supported[family] then
            result.state = 'incompatible'
            result.reason = 'unsupported-client'
            return result
        end

        if type(api) ~= 'table' then fault('incompatible', 'invalid-api') end
        local readyFn = field(g, api, 'RegisterOnReady')
        local updateFn = field(g, api, 'RegisterForQuestUpdates')

        if type(readyFn) ~= 'function' or type(updateFn) ~= 'function' then
            fault('incompatible', 'invalid-registration')
        end

        local ready = field(g, api, 'isReady')
        if type(ready) ~= 'boolean' then fault('incompatible', 'invalid-readiness') end
        local enums = field(g, api, 'Enums')
        if type(enums) ~= 'table' then fault('incompatible', 'invalid-enums') end
        local reasons = field(g, enums, 'QuestUpdateTriggerReason')
        if type(reasons) ~= 'table' then fault('incompatible', 'invalid-enums') end

        for index, key in ipairs(enumNames) do
            if field(g, reasons, key) ~= index then fault('incompatible', 'invalid-enums') end
        end

        result.api = api
        result.readyFn = readyFn
        result.updateFn = updateFn
        result.ready = ready
        result.state = ready and 'available' or 'waiting'
        result.reason = ready and 'ready' or 'provider-waiting'
        return result
    end

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
            if status[key] ~= value then changed = true end
        end

        for key, value in pairs(status) do
            if nextStatus[key] ~= value then changed = true end
        end

        status = nextStatus
        return changed
    end

    local function notify(g, owner)
        if not onChange or notifying then return end
        local notificationEpoch = epoch
        notifying = true
        local ok = pcall(onChange, copy(status))
        notifying = false
        -- The notification may itself retire this operation. A failing stale
        -- notification cannot overwrite a newer owner or terminal disposal.
        if disposed or epoch ~= notificationEpoch or (g and epoch ~= g) then return end

        if not ok then
            retire()
            failureOwner = owner or g
            cache('error', 'notification-error')
        end
    end

    local function publish(g, state, reason, source)
        guard(g)
        if cache(state, reason, source) then notify(g) end
        guard(g)
        return copy(status)
    end

    local function execute(g, body)
        local ok, result = pcall(body, g)
        if ok then return result end
        if rawequal(result, retired) or epoch ~= g or disposed or not enabled then return nil end
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

    local function same(source, current)
        return current
            and rawequal(source.api, current.api)
            and source.readyFn == current.readyFn
            and source.updateFn == current.updateFn
            and source.family == current.family
    end

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

        if failedReady[api] or failedUpdates[api] then fault('error', 'registration-failed') end
        guard(g)
        return contract
    end

    attachUpdates = function(g, current, contract)
        guard(g)
        if seenUpdates[current.api] then return end
        seenUpdates[current.api] = true
        local api = current.api
        local callback = function(...) updateCallback(api, contract, ...) end
        local ok = pcall(contract.updateFn, callback)
        -- Attempt outcome belongs to this API even if the call retired its
        -- status owner. Record it before guarding publication authority.
        if not ok then failedUpdates[api] = true end
        guard(g)
        if not ok then fault('error', 'update-registration-error') end
    end

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
            if source.ready ~= true then return end
            attachUpdates(g, current, contract)
            if status.state ~= 'available' then publish(g, 'available', 'ready', source) end
        end)

        callbackBusy = false
    end

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
            if not positiveInteger(id) then return end
            read(g, index)
            if index ~= nil and not positiveInteger(index) then return end
            read(g, reason)
            if not positiveInteger(reason) or reason > 4 then return end
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
                    if not oldSequence or row.sequence < oldSequence then oldest, oldSequence = key, row.sequence end
                end

                receipts[oldest] = nil
                count = count - 1
            end

            if receipts[id] == nil then count = count + 1 end
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

    function service:GetStatus()
        return copy(status)
    end

    function service:Refresh()
        if disposed then return nil end
        if not enabled then return copy(status) end
        local old = binding
        epoch = epoch + 1
        local g = epoch
        binding = nil

        local result = execute(g, function()
            local source = probe(g)
            if not same(source, old) or source.ready ~= true then clear() end
            if source.api == nil then return publish(g, source.state, source.reason, source) end
            local contract = contractFor(g, source)
            binding = source

            -- Reserve both the lease and attempted-registration marker before
            -- calling the provider, whose ready callback can run synchronously.
            if not seenReady[source.api] then
                seenReady[source.api] = true
                local api = source.api
                local callback = function() readyCallback(api, contract) end
                local ok = pcall(contract.readyFn, callback)
                if not ok then failedReady[api] = true end
                guard(g)
                if not ok then fault('error', 'ready-registration-error') end
            end

            source = verify(g, source, false)
            binding = source
            if source.ready then attachUpdates(g, source, contract) end
            source = verify(g, source, false)
            binding = source
            if not source.ready then clear() end
            return publish(g, source.state, source.reason, source)
        end)

        if disposed then return nil end

        if epoch ~= g then
            if failureOwner == g then return copy(status) end
            return nil
        end

        return result or copy(status)
    end

    function service:SetEnabled(value)
        if disposed then return false, 'disposed' end
        if type(value) ~= 'boolean' then return false, 'invalid-enabled' end

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

    function service:GetRecentUpdate(id)
        if disposed then return unavailable('disposed') end
        if not enabled then return unavailable('disabled') end
        if not binding or status.state ~= 'available' then return unavailable(status.reason) end
        local current = binding
        local g = epoch

        local result = execute(g, function()
            verify(g, current, true)
            local stamp = clock(g)
            read(g, id)
            if not positiveInteger(id) then return unavailable('invalid-quest-id') end
            local row = receipts[id]
            if not row then return unavailable('no-recent-update') end

            if stamp >= row.expiresAt then
                receipts[id] = nil
                count = count - 1
                return unavailable('expired')
            end

            return copy(row)
        end)

        return result or unavailable(status.reason)
    end

    function service:Dispose()
        if disposed then return end
        disposed = true
        enabled = false
        retire()
        cache('disabled', 'disposed')
        notify()
    end

    return service
end
