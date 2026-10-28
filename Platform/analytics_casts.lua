-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- addon.Analytics.NativeCasts: an explicit, volatile TBC player-cast receipt capture
-- (docs/architecture/analytics-replay.md). Start registers one owned frame and one duration timer and feeds
-- UNIT_SPELLCAST_* receipts into the bounded Analytics.NewCapture builder; Stop, Clear, the timeout or a world/control
-- change ends it. Nothing is saved and loading registers no events or timers.
-- Every native call goes through call() and read(), so a Clear or a secret value during the call retires the session
-- instead of publishing. It must not run off capture, score casts or keep raw GUIDs, names or error text.
-- Loaded from the Platform section of RotationMaster.toc after Analytics/capture.lua; UI/analytics_capture.lua drives
-- it, and main.lua and UI/preview.lua bind their capture sinks to it at startup. The BEGIN/END ANALYTICS comment pairs
-- delimit regions that tests rebuild: keep them in place. Function bodies here are frozen.

local _, addon = ...

-- ============================================================================
-- Module state
-- ============================================================================

-- Local copies of the globals this file calls, so later changes to the globals cannot redirect the capture.
local type, next, rawget, rawequal, getmetatable, pcall, error =
    type, next, rawget, rawequal, getmetatable, pcall, error

local huge = math.huge
-- analytics is the shared Analytics table; service is the public NativeCasts object, installed immediately so
-- UI/analytics_capture.lua can capture its methods.
local analytics = addon.Analytics or {}
addon.Analytics = analytics
local newCapture = analytics.NewCapture
local platform = addon.Platform
local service = {}
analytics.NativeCasts = service
-- active is the running session, last the retained completed or failed capture (at most one), frame and methods the
-- single owned event frame and its original methods, unusable a latch set when a frame could not be released, cleaning
-- a reentrancy guard.
local active, last, frame, methods, unusable, cleaning
-- generation changes on every Start and Clear so a late callback can tell its session was retired; retiring and
-- resourceCalls count teardowns and frame calls still in flight.
local generation, retiring, resourceCalls = 0, 0, 0
-- The public phase reported by GetStatus: idle, starting, running, stopping or unusable, with the reason of the last
-- end.
local phase, reason = 'idle', nil
-- BEGIN ANALYTICS PREVIEW HANDOFF
-- Two fixed source producers, consumed during normal TOC startup. No listeners.
local installAdvice, installPreview, armed

-- Startup handoff used by main.lua: accepts the install function for the advice sink once, then removes itself. The
-- sink is armed only while a capture runs.
function addon:BindAnalyticsAdviceCapture(install)
    if not rawequal(self, addon) or installAdvice or type(install) ~= 'function' then
        return false
    end

    installAdvice = install
    addon.BindAnalyticsAdviceCapture = nil
    return true
end

-- Startup handoff used by UI/preview.lua: accepts the install function for the preview-delivery sink once, then removes
-- itself.
function addon:BindAnalyticsPreviewCapture(install)
    if not rawequal(self, addon) or installPreview or type(install) ~= 'function' then
        return false
    end

    installPreview = install
    addon.BindAnalyticsPreviewCapture = nil
    return true
end

-- Removes both producer sinks and the session advice, but only when `s` is the session that armed them.
local function disarm(s)
    if armed ~= s then
        return
    end

    armed = nil

    if installAdvice then
        installAdvice(nil)
    end
    if installPreview then
        installPreview(nil)
    end

    s.advice = nil
end

-- END ANALYTICS PREVIEW HANDOFF
-- The cast events the capture records; the handler ignores any other event that reaches the frame.
local castEvents = {
    UNIT_SPELLCAST_SENT = true,
    UNIT_SPELLCAST_START = true,
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_SUCCEEDED = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true,
}

-- Every event the owned frame registers: the cast events plus the two context changes (entering world, losing control)
-- that end a capture.
local events = {
    'UNIT_SPELLCAST_SENT', 'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_STOP', 'UNIT_SPELLCAST_SUCCEEDED',
    'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_INTERRUPTED', 'UNIT_SPELLCAST_CHANNEL_START',
    'UNIT_SPELLCAST_CHANNEL_STOP', 'PLAYER_ENTERING_WORLD', 'PLAYER_CONTROL_LOST'
}

-- The end reasons a caller may pass to Stop.
local reasons = { stop = true, context = true, disabled = true, error = true, ['end'] = true, unknown = true }
-- Identity token that marks an error table as one raised by fail(), as opposed to a native error.
local fault = {}

-- Raises a capture failure carrying a fixed reason token; issue() reads it back.
local function fail(why)
    error({ owner = fault, reason = why }, 0)
end

-- Returns the reason token of an error raised by fail(), and "native-error" for anything else so raw error text never
-- escapes.
local function issue(value)
    if type(value) == 'table' and rawequal(rawget(value, 'owner'), fault) then
        return rawget(value, 'reason')
    end

    return 'native-error'
end

-- True for a real number that is neither NaN nor infinite.
local function finite(v)
    return type(v) == 'number' and v == v and v ~= huge and v ~= -huge
end

-- Deep copies plain data, used so callers never receive a table the capture keeps.
local function copy(v)
    if type(v) ~= 'table' then
        return v
    end

    local out = {}

    for k, x in next, v do
        out[k] = copy(x)
    end

    return out
end

-- True while session `s` has not been superseded by Clear or a newer Start.
local function current(s)
    return generation == s.generation
end

-- Raises "retired-operation" when `s` is no longer current; call it after anything that could have run foreign code.
local function fence(s)
    if not current(s) then
        fail('retired-operation')
    end
end

-- Runs a native or foreign function under pcall for session `s`. Raises "retired-operation" if the session was retired
-- or changed phase during the call and "native-error" if the call raised; otherwise returns its first result.
local function call(s, fn, ...)
    local before = s.phase
    local ok, value = pcall(fn, ...)
    fence(s)

    if before ~= s.phase then
        fail('retired-operation')
    end
    if not ok then
        fail('native-error')
    end

    return value
end

-- A Clear inside an in-flight setter/registration cannot hand its frame to a
-- new Start before that call returns and its retired startup tail releases it.
local function resourceCall(s, fn, ...)
    resourceCalls = resourceCalls + 1
    local ok, value = pcall(call, s, fn, ...)
    resourceCalls = resourceCalls - 1

    if not ok then
        error(value, 0)
    end

    return value
end

-- Returns `value` after asking Platform:CanReadValue whether it can be used; raises "unreadable-value" for a secret
-- value. Required before comparing or indexing any game value.
local function read(s, value)
    local ok = call(s, s.read, platform, value)

    if ok ~= true then
        fail('unreadable-value')
    end

    return value
end

-- Reads GetTime for session `s` and returns it, raising "invalid-time" if it is not a finite number, goes backwards or
-- passes 600 seconds from the start. Updates s.elapsed.
local function clock(s)
    local now = read(s, call(s, s.clock))

    if not finite(now) then
        fail('invalid-time')
    end

    if s.started ~= nil then
        local elapsed = now - s.started

        if elapsed < 0 or elapsed > 600 or elapsed < s.elapsed then
            fail('invalid-time')
        end

        s.elapsed = elapsed
    end

    return now
end

-- Builds the retained capture record: status, reason, client identity, and the fixed labels that state what the capture
-- does not prove (native acceptance, ordinary casts, damage). `capture` is the builder result for a completed capture.
local function wrapper(s, status, why, capture)
    return {
        format = 1,
        producer = 'UNIT_SPELLCAST-adapter',
        status = status,
        reason = why,
        client = copy(s.client or {}),
        tupleContract = 'wow-ui-source:2cfec7c00f0f24762d5ca35a4beb1e93c0cde328:UnitDocumentation',
        -- BEGIN ANALYTICS START WITNESS SNAPSHOT
        startWitness = status == 'complete' and copy(s.startWitness) or nil,
        -- END ANALYTICS START WITNESS SNAPSHOT
        nativeAcceptance = 'unverified',
        runtimeVerified = false,
        advice = s.adviceProducer and 'primary-publisher-receipts' or 'not-wired',
        presentation = s.previewProducer and 'owned-native-preview-boundaries' or 'not-wired',
        ordinary = 'unavailable',
        autorepeat = 'unassociated',
        damage = 'unavailable',
        capture = capture,
    }
end

-- Only this frame's original methods and this operation's exact script may be
-- removed. Failed release makes the singleton unusable rather than leaking frames.
local function cleanup(s)
    if cleaning then
        return false
    end

    cleaning = true
    local good = not s.timerAmbiguous

    local function invoke(fn, ...)
        if type(fn) ~= 'function' then
            good = false
            return nil
        end

        local ok, v = pcall(fn, ...)

        if not ok then
            good = false
            return nil
        end

        return v
    end

    if s.timer ~= nil then
        if invoke(s.cancel, addon, s.timer) ~= true then
            good = false
        end

        s.timer = nil
    end

    local ownedFrame, ownedMethods = s.frame, s.methods

    if ownedFrame and ownedMethods then
        local frame, methods = ownedFrame, ownedMethods
        local safe = true

        for name, fn in next, methods do
            local ok, v = pcall(function() return frame[name] end)

            if not ok or not rawequal(v, fn) then
                good = false
                safe = false
            end
        end

        if safe then
            local script = invoke(methods.GetScript, frame, 'OnEvent')

            if rawequal(script, s.handler) then
                invoke(methods.SetScript, frame, 'OnEvent', nil)
            elseif script ~= nil then
                good = false
            end

            for _, event in ipairs(events) do
                local registered = invoke(methods.IsEventRegistered, frame, event)

                if registered then
                    invoke(methods.UnregisterEvent, frame, event)
                end
            end

            local remaining = invoke(methods.GetScript, frame, 'OnEvent')

            if remaining ~= nil then
                good = false
            end

            for _, event in ipairs(events) do
                if invoke(methods.IsEventRegistered, frame, event) then
                    good = false
                end
            end
        end
    end

    if not good then
        unusable = true
    end

    cleaning = false
    return good
end

-- Moves the public phase back to idle (or unusable) once nothing is active, being torn down or in flight.
local function settle()
    if not active and not cleaning and retiring == 0 then
        phase = unusable and 'unusable' or 'idle'
    end
end

-- Marks session `s` as stopping and disarms its producers; the first step of every stop path.
local function retire(s)
    -- BEGIN ANALYTICS PREVIEW RETIRE
    disarm(s)
    -- END ANALYTICS PREVIEW RETIRE
    s.phase = 'stopping'

    if rawequal(active, s) then
        active = nil
    end

    phase = 'stopping'
end

-- Ends session `s` with failure reason `why`: retires it, releases the frame and timer, clears the builder and keeps an
-- unavailable record. A cleanup failure replaces the reason with "cleanup-failed".
local function abort(s, why)
    retiring = retiring + 1
    retire(s)
    local ok = cleanup(s)

    if s.builder then
        s.builder:Clear()
    end

    if current(s) then
        last = wrapper(s, 'unavailable', ok and why or 'cleanup-failed')
        phase = unusable and 'unusable' or 'idle'
        reason = last.reason
    end

    retiring = retiring - 1
    settle()
end

-- Reads object[key] for session `s` with both the object and the value checked for readability.
local function field(s, object, key)
    read(s, object)
    local value = call(s, function() return object[key] end)
    return read(s, value)
end

-- Validates the client record and stores a trimmed copy in s.client. Raises "unsupported-client" unless the client is
-- TBC with the probe policy, and "invalid-client-info" for malformed fields.
local function clientInfo(s)
    local info = read(s, call(s, s.clientReader, platform))

    if type(info) ~= 'table' then
        fail('unsupported-client')
    end

    local family = field(s, info, 'family')
    local policy = field(s, info, 'combatDataPolicy')

    if family ~= 'tbc' or policy ~= 'probe' then
        fail('unsupported-client')
    end

    local out = { family = 'tbc' }

    for _, name in ipairs({ 'build', 'interface', 'version', 'locale' }) do
        local v = field(s, info, name)

        if v ~= nil then
            if type(v) == 'string' and #v <= 64 then
                out[name] = v
            elseif finite(v) and v >= 0 and v <= 2147483647 then
                out[name] = v
            else
                fail('invalid-client-info')
            end
        end
    end

    s.client = out
end

-- Looks up the platform reader, clock, frame factory and timer functions once per Start and raises "missing-dependency"
-- if any is not a function.
local function loadDependencies(s)
    if type(platform) ~= 'table' or type(newCapture) ~= 'function' then
        fail('missing-dependency')
    end

    local ok = pcall(function()
        s.read = platform.CanReadValue
        s.clientReader = platform.GetClientInfo
        s.clock = GetTime
        s.create = CreateFrame
        s.schedule = addon.ScheduleTimer
        s.cancel = addon.CancelTimer
    end)

    fence(s)

    if not ok then
        fail('missing-dependency')
    end

    for _, fn in ipairs({ s.read, s.clientReader, s.clock, s.create, s.schedule, s.cancel }) do
        if type(fn) ~= 'function' then
            fail('missing-dependency')
        end
    end

    -- ipairs cannot detect a nil dependency in the middle.
    if
        type(s.read) ~= 'function'
        or type(s.clientReader) ~= 'function'
        or type(s.clock) ~= 'function'
        or type(s.create) ~= 'function'
        or type(s.schedule) ~= 'function'
        or type(s.cancel) ~= 'function'
    then
        fail('missing-dependency')
    end
end

-- Ends session `s` normally with reason `why`: finalizes the builder trace, releases the frame and timer, stores the
-- result as the retained capture and returns a copy of it, or nil and "retired-operation" if a Clear raced it.
local function stop(s, why)
    retiring = retiring + 1
    retire(s)

    local ok, value = pcall(function()
        clock(s)
        return s.builder:Stop(s.builderLease, s.elapsed, why)
    end)

    local release = cleanup(s)

    if not current(s) then
        retiring = retiring - 1
        settle()
        return nil, 'retired-operation'
    end

    if not ok then
        last = wrapper(s, 'unavailable', issue(value))
        s.builder:Clear()
    elseif not release then
        last = wrapper(s, 'unavailable', 'cleanup-failed')
        s.builder:Clear()
    elseif type(value) ~= 'table' or value.status ~= 'complete' then
        last = wrapper(s, 'unavailable', type(value) == 'table' and value.reason or 'builder-error')
    else
        last = wrapper(s, 'complete', why, value)
    end

    phase = unusable and 'unusable' or 'idle'
    reason = last.reason
    retiring = retiring - 1
    settle()
    return copy(last)
end

-- ============================================================================
-- Advice and presentation receipts
-- ============================================================================

-- BEGIN ANALYTICS PREVIEW RECEIPTS
-- Adds one advice, presentation or retire row to the builder for session `s`. Raises if the session ended or the
-- builder refused the row, with the builder reason when it gave one.
local function pushEvidence(s, row)
    local seq, why = s.builder:Push(s.builderLease, s.elapsed, row)
    fence(s)

    if active ~= s or s.phase ~= 'running' then
        fail('retired-operation')
    end
    if not seq then
        fail(why or 'builder-error')
    end

    return seq
end

-- Retires the current advice (bumping the session epoch) and records a "context" retire row, unless the advice already
-- changed while the clock was read.
local function retireEvidence(s)
    local a = s.advice
    clock(s)

    if not rawequal(s.advice, a) then
        return
    end

    s.advice = nil
    s.epoch = (s.epoch or 1) + 1
    pushEvidence(s, { type = 'retire', reason = 'context' })
end

-- Before an attempt is recorded, re-checks that the advice is still current and its preview still visible; retires it
-- otherwise so a stale advice cannot be matched to the cast.
local function checkAdvice(s)
    local a = s.advice

    if not a then
        return
    end

    local valid = call(s, a.current)

    if not rawequal(s.advice, a) then
        return
    end

    if valid ~= true then
        retireEvidence(s)
        return
    end

    if a.visible then
        local visible = call(s, a.visible)

        if not rawequal(s.advice, a) then
            return
        end

        if visible ~= 'visible' then
            retireEvidence(s)
        end
    end
end

-- The sink that main.lua and UI/preview.lua call during a capture. Events: "retire" (advice withdrawn), "advice" (a
-- spell was advised) and "delivery" (the preview showed it). Each is re-validated through witness callbacks around
-- clock reads, and any failure aborts the capture rather than guessing.
local function producer(s, event, window, witness, kind, spell)
    if active ~= s or s.phase ~= 'running' then
        return
    end

    local ok, why = pcall(function()
        if event == 'retire' then
            if s.advice and (window == nil or rawequal(window, s.advice.window)) then
                retireEvidence(s)
            end
        elseif event == 'advice' then
            if type(witness) ~= 'function' or call(s, witness) ~= true then
                return
            end

            clock(s)

            if call(s, witness) ~= true then
                return
            end

            local action = kind == 'spell' and 'spell' or 'unmodeled'

            if action == 'spell' and (not finite(spell) or spell <= 0 or spell % 1 ~= 0) then
                fail('invalid-receipt')
            end

            local row = { type = 'advice', epoch = s.epoch or 1, action = action }

            if action == 'spell' then
                row.spell = spell
            end

            local seq = pushEvidence(s, row)
            s.advice = { seq = seq, spell = spell, window = window, current = witness, action = action }
        elseif event == 'delivery' then
            local a = s.advice

            if not a or a.action ~= 'spell' or not rawequal(a.window, window) or a.spell ~= spell or a.ack then
                return
            end

            local valid = call(s, a.current)

            if not rawequal(s.advice, a) then
                return
            end

            if valid ~= true then
                retireEvidence(s)
                return
            end

            local state = call(s, witness)

            if not rawequal(s.advice, a) then
                return
            end

            if state == 'retired' then
                retireEvidence(s)
                return
            end

            if state ~= 'visible' and state ~= 'hidden' then
                state = 'unknown'
            end

            clock(s)

            if not rawequal(s.advice, a) then
                return
            end

            valid = call(s, a.current)

            if not rawequal(s.advice, a) then
                return
            end

            if valid ~= true then
                retireEvidence(s)
                return
            end

            -- Visibility callbacks may themselves retire a window or start a new poll.
            local repeated = call(s, witness)

            if not rawequal(s.advice, a) then
                return
            end

            if repeated == 'retired' then
                retireEvidence(s)
                return
            end

            if repeated ~= state then
                state = 'unknown'
            end

            valid = call(s, a.current)

            if not rawequal(s.advice, a) then
                return
            end

            if valid ~= true then
                retireEvidence(s)
                return
            end

            pushEvidence(s, { type = 'presentation', adviceSeq = a.seq, state = state })
            a.ack = true

            if state == 'visible' then
                a.visible = witness
            end
        end
    end)

    if not ok and current(s) and active == s then
        abort(s, issue(why))
    end
end

-- Hands the producer sink to the advice and preview installers when a capture begins; without an advice installer
-- nothing is armed.
local function arm(s)
    if not installAdvice then
        return
    end

    armed = s
    s.previewProducer = installPreview ~= nil
    s.adviceProducer = true

    local sink = function(...)
        producer(s, ...)
    end

    installAdvice(sink)

    if installPreview then
        installPreview(sink)
    end
end

-- END ANALYTICS PREVIEW RECEIPTS
-- BEGIN ANALYTICS START WITNESS
-- Optional event-local diagnostics, never a cast-kind authority. No raw tuple
-- or identity is retained; two bounded cast reads straddle the repeat query.
local function startWitness(s, key, spell)
    local ok, result = pcall(function()
        if key == nil or spell <= 0 then
            return 'unknown'
        end

        local casting = call(s, function() return UnitCastingInfo end)
        local spells = call(s, function() return C_Spell end)

        if type(casting) ~= 'function' or type(spells) ~= 'table' then
            return 'unknown'
        end

        local repeatSpell = call(s, function() return spells.IsAutoRepeatSpell end)

        if type(repeatSpell) ~= 'function' then
            return 'unknown'
        end

        local function same()
            if not rawequal(call(s, function() return UnitCastingInfo end), casting) then
                return false
            end
            if not rawequal(call(s, function() return C_Spell end), spells) then
                return false
            end

            return rawequal(call(s, function() return spells.IsAutoRepeatSpell end), repeatSpell)
        end

        local function observe()
            ---@type any
            local tuple = call(s, function()
                local name, _, _, _, _, trade, castID, _, spellID = casting('player')
                return { name = name, trade = trade, key = castID, spell = spellID }
            end)

            local name, trade, id, action = read(s, tuple.name), read(s, tuple.trade), read(s, tuple.key), read(
                s,
                tuple.spell
            )

            if not same() then
                return 'unknown'
            end
            if
                type(name) ~= 'string'
                or #name == 0
                or type(trade) ~= 'boolean'
                or type(id) ~= 'string'
                or #id < 1
                or #id > 128
                or not finite(action)
                or action <= 0
                or action > 2147483647
                or action % 1 ~= 0
            then
                return 'unknown'
            end
            if id ~= key or action ~= spell then
                return 'mismatch'
            end
            if trade then
                return 'excluded'
            end

            return 'matched'
        end

        local first = observe()

        if first ~= 'matched' then
            return first
        end

        local repeatValue = read(s, call(s, repeatSpell, spell))

        if not same() or type(repeatValue) ~= 'boolean' then
            return 'unknown'
        end
        if repeatValue then
            return 'excluded'
        end

        return observe()
    end)

    fence(s)

    if not rawequal(active, s) or s.phase ~= 'running' then
        fail('retired-operation')
    end

    return ok and result or 'unknown'
end

-- ============================================================================
-- Cast event receipts
-- ============================================================================

-- END ANALYTICS START WITNESS
-- Records one player UNIT_SPELLCAST_* event as an attempt or result row. The session check comes before any payload is
-- read; unreadable or malformed payloads abort the capture. Events for other units are ignored.
local function receipt(s, event, unit, key, spell)
    -- The lease check is before native readability or any payload operation.
    if not rawequal(active, s) or s.phase ~= 'running' then
        return
    end

    local ok, why = pcall(function()
        read(s, unit)

        if unit ~= 'player' then
            return
        end

        read(s, key)
        read(s, spell)

        if key ~= nil and (type(key) ~= 'string' or #key < 1 or #key > 128) then
            fail('invalid-payload')
        end

        if spell == nil then
            spell = 0
        end

        if not finite(spell) or spell < 0 or spell > 2147483647 or spell % 1 ~= 0 then
            fail('invalid-payload')
        end

        clock(s)
        -- BEGIN ANALYTICS PREVIEW ATTEMPT
        checkAdvice(s)
        -- END ANALYTICS PREVIEW ATTEMPT
        -- BEGIN ANALYTICS START WITNESS RECEIPT
        local witness

        if event == 'UNIT_SPELLCAST_START' then
            witness = startWitness(s, key, spell)
        end

        -- END ANALYTICS START WITNESS RECEIPT
        local r = { key = key, actor = 'player', spell = spell, castKind = 'unmodeled' }

        if
            event == 'UNIT_SPELLCAST_SENT' or event == 'UNIT_SPELLCAST_START' or event == 'UNIT_SPELLCAST_CHANNEL_START'
        then
            r.type = 'attempt'
            r.epoch = s.epoch or 1
            r.phase = event == 'UNIT_SPELLCAST_SENT' and 'sent' or 'start'
        else
            r.type = 'result'

            if event == 'UNIT_SPELLCAST_SUCCEEDED' then
                r.status = 'success'
            elseif event == 'UNIT_SPELLCAST_FAILED' then
                r.status = 'failed'
            elseif event == 'UNIT_SPELLCAST_INTERRUPTED' then
                r.status = 'interrupted'
            else
                r.status = 'stop'
            end
        end

        if event == 'UNIT_SPELLCAST_CHANNEL_START' or event == 'UNIT_SPELLCAST_CHANNEL_STOP' then
            r.castKind = 'channel'
        end

        local n, problem = s.builder:Push(s.builderLease, s.elapsed, r)
        fence(s)

        if not n then
            fail(problem or 'builder-error')
        end

        -- BEGIN ANALYTICS START WITNESS COUNT
        if witness then
            local counts = s.startWitness
            counts.observed = counts.observed + 1
            counts[witness] = counts[witness] + 1
        end
        -- END ANALYTICS START WITNESS COUNT
    end)

    if not ok and current(s) and rawequal(active, s) then
        abort(s, issue(why))
    end
end

-- ============================================================================
-- Public service
-- ============================================================================

-- Begins a capture. options may only hold duration in seconds (default 30, at most 600). Returns the session lease, or
-- nil and a reason such as "busy", "unusable", "invalid-options" or the failure token. Creates the owned frame the
-- first time, refuses a frame or handler it does not own, and schedules the end of the capture.
function service:Start(options)
    if not rawequal(self, service) then
        return nil, 'foreign-receiver'
    end
    if active or cleaning or retiring > 0 or resourceCalls > 0 or phase == 'stopping' then
        return nil, 'busy'
    end
    if unusable then
        return nil, 'unusable'
    end

    if options ~= nil then
        if type(options) ~= 'table' or getmetatable(options) ~= nil then
            return nil, 'invalid-options'
        end

        for k in next, options do
            if k ~= 'duration' then
                return nil, 'invalid-options'
            end
        end
    end

    local duration = options and rawget(options, 'duration')

    if duration == nil then
        duration = 30
    end

    if not finite(duration) or duration <= 0 or duration > 600 then
        return nil, 'invalid-options'
    end

    generation = generation + 1
    local s = { generation = generation, lease = {}, phase = 'starting', elapsed = 0 }
    active = s
    phase = 'starting'
    -- BEGIN ANALYTICS START WITNESS SESSION
    s.startWitness = { observed = 0, matched = 0, mismatch = 0, excluded = 0, unknown = 0 }

    -- END ANALYTICS START WITNESS SESSION
    local ok, why = pcall(function()
        loadDependencies(s)
        clientInfo(s)
        s.started = clock(s)
        s.builder = assert(newCapture())

        s.builderLease = assert(s.builder:Start({
            family = 'tbc',
            actor = 'player',
            ordinaryEvidence = 'unavailable',
            presentationEvidence = installAdvice and installPreview and 'trusted-receipt' or 'unavailable',
        }))

        fence(s)

        s.handler = function(_, event, unit, a, b, c)
            if not rawequal(active, s) or s.phase ~= 'running' then
                return
            end

            local readable, problem = pcall(function()
                read(s, event)

                if type(event) ~= 'string' then
                    fail('invalid-payload')
                end
            end)

            if not readable then
                if current(s) and rawequal(active, s) then
                    abort(s, issue(problem))
                end

                return
            end

            if event == 'PLAYER_ENTERING_WORLD' or event == 'PLAYER_CONTROL_LOST' then
                stop(s, 'context')
                return
            end

            if not rawget(castEvents, event) then
                return
            end

            if event == 'UNIT_SPELLCAST_SENT' then
                receipt(s, event, unit, b, c)
            else
                receipt(s, event, unit, a, b)
            end
        end

        s.frame, s.methods = frame, methods

        if not frame then
            local created
            resourceCalls = resourceCalls + 1
            local success, value = pcall(s.create, 'Frame')
            created = value
            resourceCalls = resourceCalls - 1

            if not success then
                unusable = true
            end

            if success and (type(created) == 'table' or type(created) == 'userdata') then
                frame = created
                s.frame = created
            end

            if not current(s) and frame then
                unusable = true
            end

            fence(s)

            if not success or not frame then
                fail('native-error')
            end

            methods = {}
            s.methods = methods

            for _, name in ipairs({
                'GetScript',
                'SetScript',
                'IsEventRegistered',
                'RegisterEvent',
                'UnregisterEvent',
                'RegisterUnitEvent',
            }) do
                local method = resourceCall(s, function() return frame[name] end)

                if name ~= 'RegisterUnitEvent' or method ~= nil then
                    if type(method) ~= 'function' then
                        fail('missing-frame-method')
                    end

                    methods[name] = method
                end
            end
        end

        for name, fn in next, methods do
            if not rawequal(resourceCall(s, function() return frame[name] end), fn) then
                fail('foreign-frame-method')
            end
        end

        if resourceCall(s, methods.GetScript, frame, 'OnEvent') ~= nil then
            fail('foreign-frame-handler')
        end

        for _, event in ipairs(events) do
            if resourceCall(s, methods.IsEventRegistered, frame, event) then
                fail('foreign-registration')
            end
        end

        resourceCall(s, methods.SetScript, frame, 'OnEvent', s.handler)

        for _, event in ipairs(events) do
            if rawget(castEvents, event) and methods.RegisterUnitEvent then
                resourceCall(s, methods.RegisterUnitEvent, frame, event, 'player')
            else
                resourceCall(s, methods.RegisterEvent, frame, event)
            end

            if not resourceCall(s, methods.IsEventRegistered, frame, event) then
                fail('registration-failed')
            end
        end

        if not rawequal(resourceCall(s, methods.GetScript, frame, 'OnEvent'), s.handler) then
            fail('foreign-frame-handler')
        end

        resourceCalls = resourceCalls + 1

        local success, handle = pcall(
            s.schedule,
            addon,
            function()
                if not rawequal(active, s) then
                    return
                end

                s.timer = nil

                if s.phase ~= 'running' then
                    abort(s, 'timer-before-commit')
                else
                    stop(s, 'end')
                end
            end,
            duration
        )

        resourceCalls = resourceCalls - 1

        if success and handle ~= nil then
            s.timer = handle
        else
            s.timerAmbiguous = true
        end

        fence(s)

        if not success or handle == nil then
            fail('timer-failed')
        end
        if not rawequal(active, s) or s.phase ~= 'starting' then
            fail('timer-before-commit')
        end

        s.phase = 'running'
        phase = 'running'
        reason = nil
        last = nil
        -- BEGIN ANALYTICS PREVIEW ARM
        arm(s)
        -- END ANALYTICS PREVIEW ARM
    end)

    if not ok then
        if current(s) then
            abort(s, issue(why))
        else
            cleanup(s)

            if s.builder then
                s.builder:Clear()
            end
        end

        settle()
        return nil, current(s) and (reason or issue(why)) or 'retired-operation'
    end

    return s.lease
end

-- Ends the capture identified by `lease` with an allowlisted reason (default "stop") and returns a copy of the stored
-- result, or nil and a reason for a stale lease or invalid reason.
function service:Stop(lease, why)
    if not rawequal(self, service) then
        return nil, 'foreign-receiver'
    end
    if not active or not rawequal(lease, active.lease) then
        return nil, 'retired-lease'
    end
    if active.phase ~= 'running' then
        return nil, 'busy'
    end

    if why == nil then
        why = 'stop'
    end

    if type(why) ~= 'string' or not rawget(reasons, why) then
        return nil, 'invalid-reason'
    end

    return stop(active, why)
end

-- Retires any capture, releases its frame and timer and drops the retained result. Always returns true; also the
-- shutdown path.
function service:Clear()
    if not rawequal(self, service) then
        return nil, 'foreign-receiver'
    end

    generation = generation + 1
    local s = active
    active = nil
    last = nil
    reason = nil

    -- BEGIN ANALYTICS PREVIEW CLEAR
    if s then
        disarm(s)
    end

    -- END ANALYTICS PREVIEW CLEAR
    if s then
        retiring = retiring + 1
        phase = 'stopping'
        cleanup(s)

        if s.builder then
            s.builder:Clear()
        end

        retiring = retiring - 1
    end

    settle()
    return true
end

-- Returns a small status table (phase, reason and the fixed "unverified/unavailable" labels) without any capture data.
function service:GetStatus()
    if not rawequal(self, service) then
        return nil, 'foreign-receiver'
    end

    return {
        phase = phase,
        reason = reason,
        nativeAcceptance = 'unverified',
        runtimeVerified = false,
        advice = 'not-wired',
        presentation = 'not-wired',
        ordinary = 'unavailable',
        autorepeat = 'unassociated',
        damage = 'unavailable',
    }
end

-- Returns a copy of the retained capture, or nil with "running" while a capture is active and "no-session" when none
-- has finished.
function service:GetSnapshot()
    if not rawequal(self, service) then
        return nil, 'foreign-receiver'
    end
    if active then
        return nil, 'running'
    end
    if not last then
        return nil, 'no-session'
    end

    return copy(last)
end
