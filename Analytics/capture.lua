-- Pure trusted-receipt builder. No live producers, native proof or persistence.
-- Publishes addon.Analytics.NewCapture(options), an in-memory recorder that accepts caller-normalized receipts, turns
-- them into the version-1 trace Analytics/replay.lua expects and returns replay's report as a snapshot.
-- Loaded from RotationMaster.toc right after Analytics/replay.lua, whose Replay function it captures at load; the
-- cast-event producer that feeds it is Platform/analytics_casts.lua. Raw cast keys stay private to a session and never
-- reach the trace or a snapshot. Limits (4096 rows, 1024 aliases, 128 pending, 512 KiB charge) match replay's, and any
-- breach ends the session with an unavailable snapshot rather than a partial one.
local _, addon = ...
local type, next, rawget, rawequal, getmetatable, pcall = type, next, rawget, rawequal, getmetatable, pcall
local huge, min = math.huge, math.min
local analytics = addon.Analytics or {}
addon.Analytics = analytics
local replay = analytics.Replay
local RECORDS, ALIASES, PENDING, BYTES = 4096, 1024, 128, 524288

-- ============================================================================
-- Validation primitives and schemas
-- ============================================================================

-- Whether a value is a real, finite number (rejects NaN and both infinities).
-- @param v any  The value to test.
-- @return boolean  True for a finite number.
local function finite(v)
    return type(v) == 'number' and v == v and v ~= huge and v ~= -huge
end

-- Whether a value is a finite whole number between a minimum and 2^31 - 1.
-- @param v any  The value to test.
-- @param low number  The smallest accepted value.
-- @return boolean  True for such a number.
local function integer(v, low)
    return finite(v) and v >= low and v <= 2147483647 and v % 1 == 0
end

-- Whether a value is a table with no metatable, so no hidden __index or __eq can run during validation.
-- @param v any  The value to test.
-- @return boolean  True for a plain table.
local function plain(v)
    return type(v) == 'table' and getmetatable(v) == nil
end

-- Whether a value is a string present in an allowed-value set (read with rawget).
-- @param v any  The value to test.
-- @param set table  The allowed values (value -> true).
-- @return boolean  True when v is in the set.
local function member(v, set)
    return type(v) == 'string' and rawget(set, v) == true
end

local modes = { unavailable = true, ['trusted-receipt'] = true }
local actors = { player = true, pet = true, other = true, unknown = true }
local kinds = { ordinary = true, channel = true, autorepeat = true, unmodeled = true }
local actions = { spell = true, unmodeled = true, none = true, unknown = true }
local states = { visible = true, hidden = true, unknown = true }
local reasons = { stop = true, context = true, disabled = true, error = true, ['end'] = true, unknown = true }
local statuses = { success = true, failed = true, interrupted = true, stop = true }
local optionsKeys = { adviceMaxAge = true }
local contextKeys = { family = true, actor = true, ordinaryEvidence = true, presentationEvidence = true }

local fields = {
    advice = { type = true, epoch = true, action = true, spell = true },
    presentation = { type = true, adviceSeq = true, state = true },
    retire = { type = true, reason = true },
    attempt = { type = true, key = true, epoch = true, actor = true, castKind = true, spell = true, phase = true },
    result = { type = true, key = true, actor = true, castKind = true, spell = true, status = true },
}

-- Whether a value is a plain table whose keys are all strings listed in an allowed set.
-- @param value any  The value to test.
-- @param allowed table  The allowed keys (key -> true); this is how unknown fields are refused.
-- @return boolean  True for such a table.
local function closed(value, allowed)
    if not plain(value) then
        return false
    end

    for k in next, value do
        if type(k) ~= 'string' or not rawget(allowed, k) then
            return false
        end
    end

    return true
end

-- ============================================================================
-- Size accounting and helpers
-- ============================================================================

-- Charges the size of a value in the data-only byte accounting.
-- @param v any  The value to charge.
-- @return number  The charge: 2 plus the length for a string, 8 for a number, 1 for a boolean and 2 otherwise.
--
-- Fixed data-only charge, not a Lua heap or wire-size claim. Cast rows reserve the longest kind (autorepeat), plus
-- 18 + keyBytes for each private alias tombstone.
local function charge(v)
    local t = type(v)

    if t == 'string' then
        return 2 + #v
    elseif t == 'number' then
        return 8
    elseif t == 'boolean' then
        return 1
    end

    return 2
end

-- Computes the byte charge of one row.
-- @param row table  The row.
-- @return number  The charge; castKind is always charged as the longest kind because replay may rewrite it at Stop.
local function rowCharge(row)
    local bytes = 10

    for k, v in next, row do
        bytes = bytes + 2 + #k + charge(k == 'castKind' and 'autorepeat' or v)
    end

    return bytes
end

-- Deep copies plain data, so snapshots handed to callers share nothing with the session.
-- @param value any  The value to copy.
-- @return any  A deep copy of a table; any other value unchanged.
local function copy(value)
    if type(value) ~= 'table' then
        return value
    end

    local result = {}

    for k, v in next, value do
        result[k] = copy(v)
    end

    return result
end

-- Builds the evidence block of a snapshot.
-- @param state table  The session.
-- @return table  { ordinary, presentation, damage, collection }: how ordinary and presentation receipts were trusted
--   for this session; damage is never collected here.
local function evidence(state)
    return {
        ordinary = state.ordinary,
        presentation = state.presentation,
        damage = 'unavailable',
        collection = 'not-wired',
    }
end

-- Ends every pending attempt alias (an epoch change or retire made them unobservable) and zeroes the counter.
-- @param state table  The session.
local function finishPending(state)
    for _, alias in next, state.byAlias do
        if alias.pending then
            alias.pending = false
        end
    end

    state.pending = 0
end

-- Drops pending status from attempts older than 30 seconds, mirroring replay's expiry so the pending limit agrees.
-- @param state table  The session.
-- @param time number  The current session time in seconds.
local function expire(state, time)
    for _, alias in next, state.byAlias do
        if alias.pending and time - alias.time > 30 then
            alias.pending = false
            state.pending = state.pending - 1
        end
    end
end

-- ============================================================================
-- Capture builder
-- ============================================================================

-- Creates a capture object.
-- @param options table|nil  May only hold adviceMaxAge, a number above 0 and at most 0.5 seconds (default 0.5).
-- @return table|nil  The capture object (Start, Push, Stop, Clear, GetSnapshot); nil if replay is missing or options
--   are invalid.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Only one session can run at a time, and every method must be called with the colon on the returned object.
function analytics.NewCapture(options)
    if type(replay) ~= 'function' then
        return nil, 'missing-replay'
    end
    if options ~= nil and not closed(options, optionsKeys) then
        return nil, 'invalid-options'
    end

    local age = options and rawget(options, 'adviceMaxAge')

    if age == nil then
        age = 0.5
    end

    if not finite(age) or age <= 0 or age > 0.5 then
        return nil, 'invalid-options'
    end

    local active, last, api

    -- Ends the running session and stores an unavailable snapshot.
    -- @param state table  The session.
    -- @param reason string  The reason carried by the snapshot.
    -- @return nil  Always nil.
    -- @return string  reason.
    local function fail(state, reason)
        active = nil

        last = {
            format = 1,
            model = 1,
            kind = 'trusted-receipt-builder',
            status = 'unavailable',
            reason = reason,
            nativeCertified = false,
            evidence = evidence(state),
            chargedBytes = state.bytes,
        }

        return nil, reason
    end

    -- Resolves the active session for a method call.
    -- @param self any  The receiver of the method call.
    -- @param lease table  The lease returned by Start.
    -- @return table|nil  The active session when self is this object and lease is the live one; nil otherwise.
    -- @return string|nil  'foreign-receiver' or 'retired-lease' when the first return is nil; nil otherwise.
    local function owned(self, lease)
        if not rawequal(self, api) then
            return nil, 'foreign-receiver'
        end
        if not active or not rawequal(lease, active.lease) then
            return nil, 'retired-lease'
        end

        return active
    end

    -- Checks a caller-supplied elapsed time.
    -- @param state table  The session.
    -- @param time any  The elapsed time in seconds: finite, 0 to 600, and not before the last accepted row.
    -- @return boolean|nil  True when valid; nil otherwise.
    -- @return string|nil  'invalid-time' or 'decreasing-time' when the first return is nil; nil otherwise.
    local function validTime(state, time)
        if not finite(time) or time < 0 or time > 600 then
            return nil, 'invalid-time'
        end
        if time < state.time then
            return nil, 'decreasing-time'
        end

        return true
    end

    api = {}

    -- Begins a session for a validated context.
    -- @param context table  { family = 'tbc', actor = 'player', ordinaryEvidence?, presentationEvidence? }; the
    --   evidence modes are 'unavailable' (default) or 'trusted-receipt'.
    -- @return table|nil  The session lease; nil when refused.
    -- @return string|nil  The reason code ('foreign-receiver', 'already-running' or 'invalid-context') when the first
    --   return is nil; nil otherwise.
    --
    -- Refuses while another session runs. Any earlier snapshot is discarded.
    function api:Start(context)
        if not rawequal(self, api) then
            return nil, 'foreign-receiver'
        end
        if active then
            return nil, 'already-running'
        end
        if
            not closed(context, contextKeys)
            or rawget(context, 'family') ~= 'tbc'
            or rawget(context, 'actor') ~= 'player'
        then
            return nil, 'invalid-context'
        end

        local ordinary, presentation = rawget(context, 'ordinaryEvidence'), rawget(context, 'presentationEvidence')

        if ordinary == nil then
            ordinary = 'unavailable'
        end
        if presentation == nil then
            presentation = 'unavailable'
        end

        if not member(ordinary, modes) or not member(presentation, modes) then
            return nil, 'invalid-context'
        end

        local lease = {}

        active = {
            lease = lease,
            ordinary = ordinary,
            presentation = presentation,
            rows = {},
            keys = {},
            byAlias = {},
            aliases = 0,
            pending = 0,
            seq = 0,
            time = 0,
            bytes = 90,
        }

        last = nil
        return lease
    end

    -- Validates one receipt and appends it as a row with the next sequence number.
    -- @param lease table  The lease returned by Start.
    -- @param time number  The elapsed session time in seconds.
    -- @param receipt table  The receipt: advice, presentation, retire, attempt or result, checked against its closed
    --   schema.
    -- @return number|nil  The sequence number; nil when refused.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- A bad receipt or a limit breach also ends the session. Raw cast keys become numeric aliases here and are never
    -- stored on a row.
    function api:Push(lease, time, receipt)
        local state, why = owned(self, lease)

        if not state then
            return nil, why
        end

        local ok, issue = validTime(state, time)

        if not ok then
            return fail(state, issue)
        end
        if not plain(receipt) then
            return fail(state, 'invalid-receipt')
        end

        local kind, allowed = rawget(receipt, 'type'), nil

        if type(kind) == 'string' then
            allowed = rawget(fields, kind)
        end

        if not allowed or not closed(receipt, allowed) then
            return fail(state, 'invalid-receipt')
        end
        if state.seq >= RECORDS then
            return fail(state, 'record-limit')
        end

        local row = { type = kind, seq = state.seq + 1, time = time }
        local alias, key, newAlias, signal

        if kind == 'advice' then
            row.epoch, row.action = rawget(receipt, 'epoch'), rawget(receipt, 'action')

            if not integer(row.epoch, 1) or not member(row.action, actions) then
                return fail(state, 'invalid-receipt')
            end

            local spell = rawget(receipt, 'spell')

            if row.action == 'spell' then
                if not integer(spell, 1) then
                    return fail(state, 'invalid-receipt')
                end

                row.spell, row.validUntil = spell, time + age
            elseif spell ~= nil then
                return fail(state, 'invalid-receipt')
            end
        elseif kind == 'presentation' then
            row.adviceSeq, row.state = rawget(receipt, 'adviceSeq'), rawget(receipt, 'state')

            if not integer(row.adviceSeq, 1) or row.adviceSeq >= row.seq or not member(row.state, states) then
                return fail(state, 'invalid-receipt')
            end

            if row.state == 'visible' and state.presentation ~= 'trusted-receipt' then
                row.state = 'unknown'
            end
        elseif kind == 'retire' then
            row.reason = rawget(receipt, 'reason')

            if not member(row.reason, reasons) then
                return fail(state, 'invalid-receipt')
            end
        else
            key = rawget(receipt, 'key')

            if key ~= nil and (type(key) ~= 'string' or #key == 0 or #key > 128) then
                return fail(state, 'invalid-receipt')
            end

            row.actor, row.spell = rawget(receipt, 'actor'), rawget(receipt, 'spell')
            signal = rawget(receipt, 'castKind')

            if signal == nil then
                signal = 'unmodeled'
            end

            if not member(row.actor, actors) or not integer(row.spell, 0) or not member(signal, kinds) then
                return fail(state, 'invalid-receipt')
            end

            if signal == 'ordinary' and state.ordinary ~= 'trusted-receipt' then
                signal = 'unmodeled'
            end

            row.castKind = signal

            if kind == 'attempt' then
                row.epoch, row.phase = rawget(receipt, 'epoch'), rawget(receipt, 'phase')

                if not integer(row.epoch, 1) or (row.phase ~= 'sent' and row.phase ~= 'start') then
                    return fail(state, 'invalid-receipt')
                end
            else
                row.status = rawget(receipt, 'status')

                if not member(row.status, statuses) then
                    return fail(state, 'invalid-receipt')
                end
            end

            if key then
                alias = rawget(state.keys, key)

                if not alias then
                    if state.aliases >= ALIASES then
                        return fail(state, 'alias-limit')
                    end

                    newAlias = true
                    alias = { id = state.aliases + 1 }
                    row.cast = alias.id
                else
                    row.cast = alias.id
                end
            else
                row.cast = 0
            end
        end

        local bytes = state.bytes + rowCharge(row) + (newAlias and 18 + #key or 0)

        if bytes > BYTES then
            return fail(state, 'payload-limit')
        end

        expire(state, time)

        if kind == 'advice' then
            if state.epoch ~= nil and state.epoch ~= row.epoch then
                finishPending(state)
            end

            state.epoch = row.epoch
        elseif kind == 'retire' then
            state.epoch = nil
            finishPending(state)
        elseif alias then
            if kind == 'attempt' and not alias.started and not alias.resultSeen then
                if state.pending >= PENDING then
                    return fail(state, 'pending-limit')
                end

                alias.started = true
                alias.pending = true
                alias.time = time
                state.pending = state.pending + 1
            elseif kind == 'result' then
                alias.resultSeen = true

                if row.status ~= 'stop' and alias.pending then
                    alias.pending = false
                    state.pending = state.pending - 1
                end
            end

            if newAlias then
                state.keys[key] = alias
                state.byAlias[alias.id] = alias
                state.aliases = alias.id
            end

            if signal ~= 'unmodeled' then
                alias[signal] = true
            end
        end

        state.rows[row.seq] = row
        state.seq = row.seq
        state.time = time
        state.bytes = bytes
        return row.seq
    end

    -- Ends the session and returns a detached snapshot.
    -- @param lease table  The lease returned by Start.
    -- @param time number  The elapsed session time in seconds.
    -- @param reason string|nil  An allowlisted end reason; nil means 'stop'.
    -- @return table|nil  The snapshot (the unavailable one, plus a reason, if replay refuses the trace); nil for a
    --   foreign receiver or retired lease.
    -- @return string|nil  The reason code when the snapshot is unavailable or the first return is nil; nil otherwise.
    --
    -- Resolves each alias's cast kind from every receipt that mentioned it and runs replay over the trace.
    function api:Stop(lease, time, reason)
        local state, why = owned(self, lease)

        if not state then
            return nil, why
        end

        local ok, issue = validTime(state, time)

        if not ok then
            fail(state, issue)
            return copy(last), issue
        end

        if reason == nil then
            reason = 'stop'
        end

        if not member(reason, reasons) then
            fail(state, 'invalid-reason')
            return copy(last), 'invalid-reason'
        end

        -- Retire authority before the one source-owned reducer call. Raw private keys
        -- and kind flags never enter the trace or any returned snapshot.
        active = nil
        local trace = { format = 1, model = 1, family = 'tbc', actor = 'player', duration = time, records = {} }

        for i = 1, state.seq do
            local row = copy(state.rows[i])

            if row.type == 'advice' and row.action == 'spell' then
                row.validUntil = min(row.validUntil, time)
            end

            if (row.type == 'attempt' or row.type == 'result') and row.cast > 0 then
                local alias = state.byAlias[row.cast]

                if alias.channel and alias.autorepeat then
                    row.castKind = 'unmodeled'
                elseif alias.channel then
                    row.castKind = 'channel'
                elseif alias.autorepeat then
                    row.castKind = 'autorepeat'
                elseif alias.ordinary then
                    row.castKind = 'ordinary'
                else
                    row.castKind = 'unmodeled'
                end
            end

            trace.records[i] = row
        end

        local reduced, report = pcall(replay, trace)

        if not reduced or type(report) ~= 'table' or report.status ~= 'complete' then
            fail(state, 'replay-refused')
            return copy(last), 'replay-refused'
        end

        last = {
            format = 1,
            model = 1,
            kind = 'trusted-receipt-builder',
            status = 'complete',
            reason = reason,
            nativeCertified = false,
            evidence = evidence(state),
            chargedBytes = state.bytes,
            trace = trace,
            report = report,
        }

        return copy(last)
    end

    -- Discards any running session and the last snapshot.
    -- @return boolean|nil  True; nil for a foreign receiver.
    -- @return string|nil  'foreign-receiver' when the first return is nil; nil otherwise.
    function api:Clear()
        if not rawequal(self, api) then
            return nil, 'foreign-receiver'
        end

        active = nil
        last = nil
        return true
    end

    -- Returns a copy of the last snapshot.
    -- @return table|nil  The copy; nil while a session is running or when there is none.
    -- @return string|nil  'foreign-receiver', 'running' or 'no-session' when the first return is nil; nil otherwise.
    function api:GetSnapshot()
        if not rawequal(self, api) then
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

    return api
end
