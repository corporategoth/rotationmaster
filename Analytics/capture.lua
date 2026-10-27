-- Pure trusted-receipt builder. No live producers, native proof or persistence.
local _, addon = ...
local type, next, rawget, rawequal, getmetatable, pcall = type, next, rawget, rawequal, getmetatable, pcall
local huge, min = math.huge, math.min
local analytics = addon.Analytics or {}
addon.Analytics = analytics
local replay = analytics.Replay
local RECORDS, ALIASES, PENDING, BYTES = 4096, 1024, 128, 524288

local function finite(v)
    return type(v) == 'number' and v == v and v ~= huge and v ~= -huge
end

local function integer(v, low)
    return finite(v) and v >= low and v <= 2147483647 and v % 1 == 0
end

local function plain(v)
    return type(v) == 'table' and getmetatable(v) == nil
end

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

local function closed(value, allowed)
    if not plain(value) then return false end

    for k in next, value do
        if type(k) ~= 'string' or not rawget(allowed, k) then return false end
    end

    return true
end

-- Fixed data-only charge, not a Lua heap/wire-size claim. Cast rows reserve the
-- longest kind (autorepeat), plus18+keyBytes for each private alias tombstone.
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

local function rowCharge(row)
    local bytes = 10

    for k, v in next, row do
        bytes = bytes + 2 + #k + charge(k == 'castKind' and 'autorepeat' or v)
    end

    return bytes
end

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}

    for k, v in next, value do
        result[k] = copy(v)
    end

    return result
end

local function evidence(state)
    return {
        ordinary = state.ordinary,
        presentation = state.presentation,
        damage = 'unavailable',
        collection = 'not-wired',
    }
end

local function finishPending(state)
    for _, alias in next, state.byAlias do
        if alias.pending then alias.pending = false end
    end

    state.pending = 0
end

local function expire(state, time)
    for _, alias in next, state.byAlias do
        if alias.pending and time - alias.time > 30 then
            alias.pending = false
            state.pending = state.pending - 1
        end
    end
end

function analytics.NewCapture(options)
    if type(replay) ~= 'function' then return nil, 'missing-replay' end
    if options ~= nil and not closed(options, optionsKeys) then return nil, 'invalid-options' end
    local age = options and rawget(options, 'adviceMaxAge')
    if age == nil then age = 0.5 end
    if not finite(age) or age <= 0 or age > 0.5 then return nil, 'invalid-options' end
    local active, last, api

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

    local function owned(self, lease)
        if not rawequal(self, api) then return nil, 'foreign-receiver' end
        if not active or not rawequal(lease, active.lease) then return nil, 'retired-lease' end
        return active
    end

    local function validTime(state, time)
        if not finite(time) or time < 0 or time > 600 then return nil, 'invalid-time' end
        if time < state.time then return nil, 'decreasing-time' end
        return true
    end

    api = {}

    function api:Start(context)
        if not rawequal(self, api) then return nil, 'foreign-receiver' end
        if active then return nil, 'already-running' end

        if
            not closed(context, contextKeys)
            or rawget(context, 'family') ~= 'tbc'
            or rawget(context, 'actor') ~= 'player'
        then
            return nil, 'invalid-context'
        end

        local ordinary, presentation = rawget(context, 'ordinaryEvidence'), rawget(context, 'presentationEvidence')
        if ordinary == nil then ordinary = 'unavailable' end
        if presentation == nil then presentation = 'unavailable' end
        if not member(ordinary, modes) or not member(presentation, modes) then return nil, 'invalid-context' end
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

    function api:Push(lease, time, receipt)
        local state, why = owned(self, lease)
        if not state then return nil, why end
        local ok, issue = validTime(state, time)
        if not ok then return fail(state, issue) end
        if not plain(receipt) then return fail(state, 'invalid-receipt') end
        local kind, allowed = rawget(receipt, 'type'), nil
        if type(kind) == 'string' then allowed = rawget(fields, kind) end
        if not allowed or not closed(receipt, allowed) then return fail(state, 'invalid-receipt') end
        if state.seq >= RECORDS then return fail(state, 'record-limit') end
        local row = { type = kind, seq = state.seq + 1, time = time }
        local alias, key, newAlias, signal

        if kind == 'advice' then
            row.epoch, row.action = rawget(receipt, 'epoch'), rawget(receipt, 'action')

            if not integer(row.epoch, 1) or not member(row.action, actions) then
                return fail(state, 'invalid-receipt')
            end

            local spell = rawget(receipt, 'spell')

            if row.action == 'spell' then
                if not integer(spell, 1) then return fail(state, 'invalid-receipt') end
                row.spell, row.validUntil = spell, time + age
            elseif spell ~= nil then
                return fail(state, 'invalid-receipt')
            end
        elseif kind == 'presentation' then
            row.adviceSeq, row.state = rawget(receipt, 'adviceSeq'), rawget(receipt, 'state')

            if not integer(row.adviceSeq, 1) or row.adviceSeq >= row.seq or not member(row.state, states) then
                return fail(state, 'invalid-receipt')
            end

            if row.state == 'visible' and state.presentation ~= 'trusted-receipt' then row.state = 'unknown' end
        elseif kind == 'retire' then
            row.reason = rawget(receipt, 'reason')
            if not member(row.reason, reasons) then return fail(state, 'invalid-receipt') end
        else
            key = rawget(receipt, 'key')

            if key ~= nil and (type(key) ~= 'string' or #key == 0 or #key > 128) then
                return fail(state, 'invalid-receipt')
            end

            row.actor, row.spell = rawget(receipt, 'actor'), rawget(receipt, 'spell')
            signal = rawget(receipt, 'castKind')
            if signal == nil then signal = 'unmodeled' end

            if not member(row.actor, actors) or not integer(row.spell, 0) or not member(signal, kinds) then
                return fail(state, 'invalid-receipt')
            end

            if signal == 'ordinary' and state.ordinary ~= 'trusted-receipt' then signal = 'unmodeled' end
            row.castKind = signal

            if kind == 'attempt' then
                row.epoch, row.phase = rawget(receipt, 'epoch'), rawget(receipt, 'phase')

                if not integer(row.epoch, 1) or (row.phase ~= 'sent' and row.phase ~= 'start') then
                    return fail(state, 'invalid-receipt')
                end
            else
                row.status = rawget(receipt, 'status')
                if not member(row.status, statuses) then return fail(state, 'invalid-receipt') end
            end

            if key then
                alias = rawget(state.keys, key)

                if not alias then
                    if state.aliases >= ALIASES then return fail(state, 'alias-limit') end
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
        if bytes > BYTES then return fail(state, 'payload-limit') end
        expire(state, time)

        if kind == 'advice' then
            if state.epoch ~= nil and state.epoch ~= row.epoch then finishPending(state) end
            state.epoch = row.epoch
        elseif kind == 'retire' then
            state.epoch = nil
            finishPending(state)
        elseif alias then
            if kind == 'attempt' and not alias.started and not alias.resultSeen then
                if state.pending >= PENDING then return fail(state, 'pending-limit') end
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

            if signal ~= 'unmodeled' then alias[signal] = true end
        end

        state.rows[row.seq] = row
        state.seq = row.seq
        state.time = time
        state.bytes = bytes
        return row.seq
    end

    function api:Stop(lease, time, reason)
        local state, why = owned(self, lease)
        if not state then return nil, why end
        local ok, issue = validTime(state, time)

        if not ok then
            fail(state, issue)
            return copy(last), issue
        end

        if reason == nil then reason = 'stop' end

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
            if row.type == 'advice' and row.action == 'spell' then row.validUntil = min(row.validUntil, time) end

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

    function api:Clear()
        if not rawequal(self, api) then return nil, 'foreign-receiver' end
        active = nil
        last = nil
        return true
    end

    function api:GetSnapshot()
        if not rawequal(self, api) then return nil, 'foreign-receiver' end
        if active then return nil, 'running' end
        if not last then return nil, 'no-session' end
        return copy(last)
    end

    return api
end
