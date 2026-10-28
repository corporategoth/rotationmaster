-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project)
    local s = { value = 0, calls = 0 }

    f.env.GetShapeshiftForm = function(...)
        assert(select('#', ...) == 0, 'form query acquired arguments')
        s.calls = s.calls + 1

        if s.throw then
            error('native form failure')
        end

        return s.value, s.tail
    end

    f.env.GetNumShapeshiftForms = function()
        error('observation queried form count')
    end

    f.env.UnitExists = function()
        error('observation queried actor')
    end

    local file = io.open('Platform/form.lua')

    if file then
        file:close()
        f.load('Platform/form.lua')
    end

    return f, f.addon.Platform, s
end

local function observe(p)
    assert(type(p.GetPlayerFormObservation) == 'function', 'owned form observer missing')
    return p:GetPlayerFormObservation()
end

local function unavailable(p, why)
    local value, reason = observe(p)
    assert(value == nil and reason == why, tostring(value) .. ':' .. tostring(reason) .. ' expected ' .. why)
end

test('form keeps exact zero-argument finite numeric equality domain and ignores native tails', function()
    local _, p, s = fixture()

    for _, n in ipairs({ 0, 1, 3, .5, -1, -.25, 1e308 }) do
        s.value = n
        s.tail = {}
        local value, why = observe(p)
        assert(value == n and why == nil)
    end

    assert(s.calls == 7)
end)

test('missing failed nil malformed and nonfinite first results are unavailable', function()
    local f, p, s = fixture()
    s.value = nil
    unavailable(p, 'form-unavailable')

    for _, bad in ipairs({ false, true, '0', {}, 0 / 0, math.huge, -math.huge }) do
        s.value = bad
        unavailable(p, 'invalid-api-result')
    end

    s.value = 0
    s.throw = true
    unavailable(p, 'api-error')
    s.throw = nil
    f.env.GetShapeshiftForm = nil
    unavailable(p, 'missing-api')
end)

test('readability precedes comparisons and no unknown value is coerced to humanoid', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    s.value = opaque
    unavailable(p, 'restricted-value')
    f.env.canaccessvalue = nil
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    unavailable(p, 'restricted-value')
    s.value = 0
    assert(observe(p) == 0)
    f.env.issecretvalue = nil
    f.env.canaccessvalue = function(v) return v ~= 0 end
    unavailable(p, 'restricted-value')
end)

test('all probe families query live current API without load-time observation', function()
    for _, project in ipairs({ 2, 5, 11, 14, 19 }) do
        local f, p, s = fixture(project)
        assert(s.calls == 0)
        f.load('Platform/form.lua')
        assert(s.calls == 0)
        assert(observe(p) == 0 and s.calls == 1)

        f.env.GetShapeshiftForm = function(...)
            assert(select('#', ...) == 0)
            return -.5
        end

        assert(observe(p) == -.5 and s.calls == 1)
    end
end)

test('unsupported policy skips every native form query', function()
    for _, project in ipairs({ 999 }) do
        local _, p, s = fixture(project)
        unavailable(p, 'unsupported-policy')
        assert(s.calls == 0)
    end
end)

finish()
