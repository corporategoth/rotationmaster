-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project)
    local e = f.env
    local s = { exists = true, calls = {} }

    e.UnitExists = function(...)
        assert(select('#', ...) == 1)
        s.calls[#s.calls + 1] = { ... }

        if s.throw then
            error('presence failure')
        end

        if s.empty then
            return
        end

        return s.exists, s.tail
    end

    if not f.addon.Platform.GetUnitPresenceObservation then
        local file = io.open('Platform/unit_presence.lua')

        if file then
            file:close()
            f.load('Platform/unit_presence.lua')
        end
    end

    return f, f.addon.Platform, s
end

local function observe(p, unit)
    assert(type(p.GetUnitPresenceObservation) == 'function', 'owned presence observer missing')
    return p:GetUnitPresenceObservation(unit or 'target')
end

local function unknown(p, reason)
    local v, r = observe(p)
    assert(v == nil and r == reason, tostring(v) .. ':' .. tostring(r))
end

test('all identified families preserve readable Boolean presence with exact selected unit arity', function()
    for _, project in ipairs({ 1, 18, 2, 5, 11, 14, 19 }) do
        local _, p, s = fixture(project)

        for _, unit in ipairs({ 'target', 'player', 'pet', 'mouseover', 'vehicle' }) do
            local v, r = observe(p, unit)
            assert(v == true and r == nil and s.calls[#s.calls][1] == unit)
        end

        s.exists = false
        local v, r = observe(p)
        assert(v == false and r == nil)
    end
end)

test('unknown client and unreadable or empty input never invoke native presence', function()
    local _, p, s = fixture(999)
    unknown(p, 'unsupported-client')
    assert(#s.calls == 0)
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, unit in ipairs({ '', false, 0, {}, opaque }) do
        local v, r = p:GetUnitPresenceObservation(unit)
        assert(v == nil and r == (rawequal(unit, opaque) and 'restricted-value' or 'invalid-unit'))
    end

    assert(p:GetUnitPresenceObservation(nil) == nil and #s.calls == 0)
end)

test('missing failed nil no-return and malformed observations are unavailable', function()
    local f, p, s = fixture()
    s.exists = nil
    unknown(p, 'unit-data-unavailable')
    s.empty = true
    unknown(p, 'unit-data-unavailable')
    s.empty = false

    for _, bad in ipairs({ 0, 1, 'false', {}, math.huge, 0 / 0 }) do
        s.exists = bad
        unknown(p, 'invalid-api-result')
    end

    s.throw = true
    unknown(p, 'api-error')
    s.throw = false
    f.env.UnitExists = nil
    unknown(p, 'missing-api')
end)

test('secret results and denied Boolean false remain unknown before interpretation', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = nil
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    s.exists = opaque
    unknown(p, 'restricted-value')
    f.env.issecretvalue = nil
    f.env.canaccessvalue = function(v) return v ~= false end
    s.exists = false
    unknown(p, 'restricted-value')
    s.exists = true
    assert(observe(p) == true)
end)

test('the live platform readability contract can independently deny required results', function()
    local _, p, s = fixture()
    local original = p.CanReadValue

    p.CanReadValue = function(self, v)
        if v == true then
            return false
        end

        return original(self, v)
    end

    unknown(p, 'restricted-value')
    s.exists = false
    assert(observe(p) == false)
end)

test('unused tuple tails and absent optional readability capability do not alter Boolean presence', function()
    local f, p, s = fixture()
    local opaque = {}
    s.tail = opaque
    f.env.canaccessvalue = nil
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    assert(observe(p) == true)
    s.exists = false
    assert(observe(p) == false)
end)

test('module loading performs no observations and current native replacements are read live', function()
    local f, p, s = fixture()
    assert(type(p.GetUnitPresenceObservation) == 'function', 'owned presence observer missing')
    s.calls = {}
    f.load('Platform/unit_presence.lua')
    assert(#s.calls == 0)

    f.env.UnitExists = function(...)
        assert(select('#', ...) == 1 and (...) == 'target')
        return false
    end

    assert(observe(p) == false)

    f.env.UnitExists = function()
        error('new presence API failure')
    end

    unknown(p, 'api-error')
end)

finish()
