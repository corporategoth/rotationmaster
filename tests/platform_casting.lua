local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project)
    local a, e = f.addon, f.env
    local s = { exists = true, name = 'Arcane Missiles', ending = 103000, flag = false, now = 100, calls = {} }

    local function call(key)
        s.calls[key] = (s.calls[key] or 0) + 1

        if s.throw == key then
            error('native ' .. key .. ' failed')
        end
    end

    e.UnitExists = function(unit)
        assert(unit == 'target')
        call('exists')
        return s.exists
    end

    e.GetTime = function()
        call('time')
        return s.now
    end

    e.UnitCastingInfo = function(unit)
        assert(unit == 'target')
        call('cast')
        return s.name, 'display', 1, 99000, s.ending, false, 'cast-guid', s.flag, 5143
    end

    e.UnitChannelInfo = function(unit)
        assert(unit == 'target')
        call('channel')
        return s.name, 'display', 1, 99000, s.ending, false, s.flag, 5143, false, 0
    end

    f.load('Platform/casting.lua')
    return f, a.Platform, s
end

test('owned cast adapter normalizes seconds and exact cast/channel interruptibility tuple positions', function()
    local _, p, s = fixture()

    for _, kind in ipairs({ 'cast', 'channel' }) do
        local record = assert(p:GetUnitCastObservation('target', kind))

        assert(
            record.active
                and record.name == 'Arcane Missiles'
                and record.remainingSeconds == 3
                and record.interruptible == true
        )

        assert(not record.remainingReason and not record.interruptibleReason)
    end

    s.flag = true
    assert(p:GetUnitCastObservation('target', 'channel').interruptible == false)
    s.ending = 99000
    assert(p:GetUnitCastObservation('target', 'cast').remainingSeconds == 0)
    local first = p:GetUnitCastObservation('target', 'cast')
    first.name = 'changed'
    assert(p:GetUnitCastObservation('target', 'cast').name == 'Arcane Missiles')
end)

test('policy unit and query guards prevent unsupported or invalid native calls', function()
    for _, project in ipairs({ 999 }) do
        local _, p, s = fixture(project)
        local record, why = p:GetUnitCastObservation('target', 'cast')
        assert(record == nil and why == 'unsupported-policy' and next(s.calls) == nil)
    end

    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, unit in ipairs({ '', 0, false, {}, opaque }) do
        assert(p:GetUnitCastObservation(unit, 'cast') == nil)
    end

    for _, kind in ipairs({ '', 0, false, {}, opaque, 'casting' }) do
        assert(p:GetUnitCastObservation('target', kind) == nil)
    end

    assert(
        p:GetUnitCastObservation(nil, 'cast') == nil
            and p:GetUnitCastObservation('target', nil) == nil
            and next(s.calls) == nil
    )
end)

test('unit existence false is inactive while missing failed nil and unreadable existence stay unavailable', function()
    local f, p, s = fixture()
    s.exists = false
    assert(p:GetUnitCastObservation('target', 'cast').active == false and not s.calls.cast)
    s.exists = nil
    local record, why = p:GetUnitCastObservation('target', 'cast')
    assert(not record and why == 'unit-data-unavailable' and not s.calls.cast)
    s.throw = 'exists'
    record, why = p:GetUnitCastObservation('target', 'cast')
    assert(not record and why == 'api-error' and not s.calls.cast)
    s.throw = nil
    local opaque = {}
    s.exists = opaque
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    record, why = p:GetUnitCastObservation('target', 'cast')
    assert(not record and why == 'restricted-value')
    f.env.UnitExists = nil
    record, why = p:GetUnitCastObservation('target', 'cast')
    assert(not record and why == 'missing-api')
end)

test(
    'readable nil names are inactive, a secret name is an unnamed cast, and missing failed malformed queries stay unknown',
    function()
        for _, kind in ipairs({ 'cast', 'channel' }) do
            local f, p, s = fixture()
            s.name = nil
            local record = p:GetUnitCastObservation('target', kind)
            assert(record.active == false and not s.calls.time)
            s.name = ''
            local _, why = p:GetUnitCastObservation('target', kind)
            assert(why == 'invalid-api-result')
            s.throw = kind
            _, why = p:GetUnitCastObservation('target', kind)
            assert(why == 'api-error')
            s.throw = nil
            local opaque = {}
            s.name = opaque
            f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
            local hidden = p:GetUnitCastObservation('target', kind)
            assert(hidden.active and hidden.name == nil and hidden.nameReason == 'restricted-value')
            f.env[kind == 'cast' and 'UnitCastingInfo' or 'UnitChannelInfo'] = nil
            _, why = p:GetUnitCastObservation('target', kind)
            assert(why == 'missing-api')
        end
    end
)

test('optional timer and flag failures preserve the active name and isolate their availability reasons', function()
    for _, kind in ipairs({ 'cast', 'channel' }) do
        local f, p, s = fixture()
        s.ending = nil
        s.flag = nil
        local record = p:GetUnitCastObservation('target', kind)

        assert(
            record.active
                and record.name == 'Arcane Missiles'
                and record.remainingSeconds == nil
                and record.remainingReason == 'cast-time-unavailable'
                and record.interruptible == nil
                and record.interruptibleReason == 'interruptibility-unavailable'
        )

        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
        s.ending = opaque
        s.flag = opaque
        record = p:GetUnitCastObservation('target', kind)

        assert(
            record.active
                and record.remainingReason == 'restricted-value'
                and record.interruptibleReason == 'restricted-value'
        )

        for _, bad in ipairs({ false, '103000', -1, math.huge, 0 / 0, {} }) do
            s.ending = bad
            record = p:GetUnitCastObservation('target', kind)
            assert(record.active and record.remainingReason == 'invalid-api-result')
        end

        for _, bad in ipairs({ 0, 1, 'false', {} }) do
            s.flag = bad
            record = p:GetUnitCastObservation('target', kind)
            assert(record.active and record.interruptibleReason == 'invalid-api-result')
        end
    end
end)

test('clock access is guarded field-level and cannot disable a readable active/name observation', function()
    local f, p, s = fixture()
    s.throw = 'time'
    local record = p:GetUnitCastObservation('target', 'cast')
    assert(record.active and record.remainingReason == 'api-error' and record.interruptible == true)
    s.throw = nil
    f.env.GetTime = nil
    record = p:GetUnitCastObservation('target', 'cast')
    assert(record.active and record.remainingReason == 'missing-api')
    f.env.GetTime = function() return s.now end
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    s.now = opaque
    record = p:GetUnitCastObservation('target', 'cast')
    assert(record.active and record.remainingReason == 'restricted-value')

    for _, bad in ipairs({ false, '100', -1, math.huge, 0 / 0, {} }) do
        s.now = bad
        record = p:GetUnitCastObservation('target', 'cast')
        assert(record.active and record.remainingReason == 'invalid-api-result')
    end
end)

finish()
