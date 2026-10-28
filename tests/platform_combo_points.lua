-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project or 5)
    local p, e = f.addon.Platform, f.env
    local s = { combo = 3, maximum = 5, calls = {} }

    local function call(k, ...)
        s.calls[#s.calls + 1] = { k, n = select('#', ...), ... }

        if s.throw == k then
            error('private combo failure')
        end

        return s[k], s.tail
    end

    e.GetComboPoints = function(...) return call('combo', ...) end
    e.UnitPowerMax = function(...) return call('maximum', ...) end

    e.UnitPower = function()
        error('combo must not use UnitPower fallback')
    end

    return f, p, s
end

local function observe(p, power, kind)
    assert(p.GetPlayerComboPointObservation, 'explicit combo observer missing')
    return p:GetPlayerComboPointObservation(power, kind)
end

local function unavailable(fn, why)
    local v, r = fn()
    assert(v == nil and r == why, tostring(v) .. ':' .. tostring(r) .. ' expected ' .. why)
end

test('explicit player current and maximum preserve exact two native args and first result', function()
    local _, p, s = fixture()
    s.tail = {}
    assert(observe(p, 14, 'current') == 3)
    local c = s.calls[1]
    assert(c.n == 2 and c[1] == 'combo' and c[2] == 'player' and c[3] == 'target')
    assert(observe(p, 14, 'maximum') == 5)
    c = s.calls[2]
    assert(c.n == 2 and c[1] == 'maximum' and c[2] == 'player' and c[3] == 14)
end)

test('finite zero signed fractions and negative maxima remain observable', function()
    for _, kind in ipairs({ 'current', 'maximum' }) do
        for _, v in ipairs({ 0, -2, .5, -.25, 1e308 }) do
            local _, p, s = fixture()
            s[kind == 'current' and 'combo' or 'maximum'] = v
            assert(observe(p, 4, kind) == v)
        end
    end
end)

test('invalid and unreadable query fields reject before native calls', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, bad in ipairs({ false, '4', -1, .5, {}, 0 / 0, math.huge, opaque }) do
        unavailable(function()
            return observe(p, bad, 'current')
        end, rawequal(bad, opaque) and 'restricted-value' or 'invalid-point-power-query')
    end

    unavailable(function() return observe(p, nil, 'current') end, 'invalid-point-power-query')

    for _, bad in ipairs({ 'both', false, {}, opaque }) do
        unavailable(function()
            return observe(p, 4, bad)
        end, rawequal(bad, opaque) and 'restricted-value' or 'invalid-point-power-query')
    end

    assert(#s.calls == 0)
end)

test('missing throwing nil malformed and restricted quantity remains unknown with no fallback', function()
    for _, kind in ipairs({ 'current', 'maximum' }) do
        for _, mode in ipairs({'missing', 'throw', 'nil', 'false', 'text', 'table', 'nan', 'inf', 'opaque'}) do
            local f, p, s = fixture()
            local k = kind == 'current' and 'combo' or 'maximum'
            local why
            local opaque = {}
            f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

            if mode == 'missing' then
                f.env[k == 'combo' and 'GetComboPoints' or 'UnitPowerMax'] = nil
                why = 'missing-api'
            elseif mode == 'throw' then
                s.throw = k
                why = 'api-error'
            elseif mode == 'nil' then
                s[k] = nil
                why = 'point-power-unavailable'
            elseif mode == 'opaque' then
                s[k] = opaque
                why = 'restricted-value'
            else
                s[k] = ({ ['false'] = false, text = '3', table = {}, nan = 0 / 0, inf = math.huge })[mode]
                why = 'invalid-api-result'
            end

            unavailable(function() return observe(p, 4, kind) end, why)
        end
    end
end)

test('only TBC probe family uses explicit combo observer and load stays silent', function()
    for _, project in ipairs({ 1, 2, 11, 14, 18, 19, 999 }) do
        local _, p, s = fixture(project)

        unavailable(function()
            return observe(p, 4, 'current')
        end, (project == 1 or project == 18 or project == 999) and 'unsupported-policy' or 'unsupported-point-transport')

        assert(#s.calls == 0)
    end

    local f, p, s = fixture()
    f.load('Platform/points.lua')
    assert(#s.calls == 0)
    assert(observe(p, 4, 'current') == 3)
end)

test('live native replacements and failed facts recover without observer-local memo', function()
    local f, p, s = fixture()
    s.combo = nil
    unavailable(function() return observe(p, 4, 'current') end, 'point-power-unavailable')

    f.env.GetComboPoints = function(...)
        assert(select('#', ...) == 2)
        return 0
    end

    assert(observe(p, 4, 'current') == 0)
end)

test('unreadable or inherited family cannot authorize combo transport', function()
    local f, p, s = fixture()
    local original = p.GetClientInfo
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    p.GetClientInfo = function(self)
        local info = original(self)
        info.family = opaque
        return info
    end

    unavailable(function() return observe(p, 4, 'current') end, 'restricted-value')

    p.GetClientInfo = function()
        return setmetatable({ combatDataPolicy = 'probe' }, {
            __index = function()
                error('family getter must not run')
            end,
        })
    end

    unavailable(function() return observe(p, 4, 'current') end, 'unsupported-point-transport')
    assert(#s.calls == 0)
end)

finish()
