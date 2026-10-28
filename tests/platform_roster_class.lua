-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project or 11, 2, 'MAGE')
    local s = { exists = true, class = 'MAGE', calls = {} }

    local function call(name, ...)
        s.calls[#s.calls + 1] = { name, n = select('#', ...), ... }

        if s.throw == name then
            error('native failure')
        end
    end

    f.env.UnitExists = function(...)
        assert(select('#', ...) == 1)
        call('exists', ...)
        return s.exists
    end

    f.env.UnitClass = function(...)
        assert(select('#', ...) == 1)
        call('class', ...)
        return s.label, s.class, s.id, s.tail
    end

    local file = io.open('Platform/roster_class.lua')

    if file then
        file:close()
        f.load('Platform/roster_class.lua')
    end

    return f, f.addon.Platform, s
end

local function observe(p, unit)
    assert(type(p.GetRosterClassObservation) == 'function', 'roster class observer absent')
    return p:GetRosterClassObservation(unit)
end

local function unknown(p, unit, why)
    local value, reason = observe(p, unit)
    assert(value == nil and reason == why, tostring(reason) .. ' expected ' .. why)
end

test('exact canonical roster routing preserves existence then class return two and ignores other fields', function()
    local _, p, s = fixture()
    s.label = {}
    s.id = {}
    s.tail = {}

    for _, unit in ipairs({ 'player', 'party1', 'party4', 'raid1', 'raid40' }) do
        s.calls = {}
        assert(observe(p, unit) == 'MAGE')

        assert(
            #s.calls == 2
                and s.calls[1][1] == 'exists'
                and s.calls[2][1] == 'class'
                and s.calls[1][2] == unit
                and s.calls[2][2] == unit
        )
    end

    s.class = 'FUTURE_CLASS'
    assert(observe(p, 'player') == 'FUTURE_CLASS')
end)

test('closed roster inputs reject nonroster malformed and unreadable units without native calls', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, unit in ipairs({
        '',
        'target',
        'pet',
        'party0',
        'party5',
        'raid0',
        'raid41',
        'raid01',
        'Player',
        1,
        false,
        {},
        opaque,
    }) do
        unknown(p, unit, rawequal(unit, opaque) and 'restricted-value' or 'invalid-roster-unit')
    end

    unknown(p, nil, 'invalid-roster-unit')
    assert(#s.calls == 0)
end)

test('known absence requires no metadata capability', function()
    local f, p, s = fixture()
    s.exists = false
    f.env.UnitClass = nil
    assert(observe(p, 'party1') == false and #s.calls == 1)
end)

test('required existence distinguishes false from nil malformed restricted thrown and missing', function()
    local f, p, s = fixture()
    s.exists = nil
    unknown(p, 'player', 'roster-data-unavailable')

    for _, value in ipairs({ 0, 'true', {}, math.huge }) do
        s.exists = value
        unknown(p, 'player', 'invalid-api-result')
    end

    local opaque = {}
    s.exists = opaque
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    unknown(p, 'player', 'restricted-value')
    s.exists = true
    s.throw = 'exists'
    unknown(p, 'player', 'api-error')
    s.throw = nil
    f.env.UnitExists = nil
    unknown(p, 'player', 'missing-api')

    for _, call in ipairs(s.calls) do
        assert(call[1] == 'exists')
    end
end)

test('present roster members require only a readable nonempty class token', function()
    local f, p, s = fixture()
    s.class = nil
    unknown(p, 'party1', 'roster-class-unavailable')

    for _, value in ipairs({ '', 0, false, {}, math.huge }) do
        s.class = value
        unknown(p, 'party1', 'invalid-api-result')
    end

    local opaque = {}
    s.class = opaque
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    unknown(p, 'party1', 'restricted-value')
    s.class = 'MAGE'
    s.throw = 'class'
    unknown(p, 'party1', 'api-error')
    s.throw = nil
    f.env.UnitClass = nil
    unknown(p, 'party1', 'missing-api')
end)

test('all identified public roster families are readable and unknown clients make no native calls', function()
    for _, project in ipairs({ 1, 2, 5, 11, 14, 18, 19 }) do
        local _, p, s = fixture(project)
        assert(#s.calls == 0 and observe(p, 'player') == 'MAGE')
    end

    local _, p, s = fixture(999)
    unknown(p, 'player', 'unsupported-client')
    assert(#s.calls == 0)
end)

finish()
