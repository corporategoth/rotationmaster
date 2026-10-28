-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project)
    local a, e = f.addon, f.env
    local s = { exists = true, name = 'Wolf', calls = {} }

    local function call(key, ...)
        assert(select('#', ...) == 1 and select(1, ...) == 'pet', 'pet query changed token or arity')
        s.calls[#s.calls + 1] = key

        if s.throw == key then
            error('native pet failure')
        end

        return s[key]
    end

    e.UnitExists = function(...) return call('exists', ...) end
    e.GetUnitName = function(...) return call('name', ...) end

    e.UnitName = function()
        error('GetUnitName was replaced with UnitName')
    end

    e.UnitIsDead = function()
        error('pet existence gained an alive check')
    end

    e.HasPetUI = function()
        error('pet existence gained a pet-bar check')
    end

    local file = io.open('Platform/pet.lua')

    if file then
        file:close()
        f.load('Platform/pet.lua')
    end

    return f, a.Platform, s
end

local function observe(p, includeName)
    assert(type(p.GetPetObservation) == 'function', 'owned pet observer missing')
    return p:GetPetObservation(includeName)
end

local function unavailable(p, includeName, reason)
    local value, why = observe(p, includeName)
    assert(value == nil and why == reason, tostring(value) .. ':' .. tostring(why) .. ' expected ' .. reason)
end

test('presence is one exact pet existence query and optional name uses the existing one-argument helper', function()
    local _, p, s = fixture()
    local record, why = observe(p, false)
    assert(record.exists == true and record.name == nil and why == nil and #s.calls == 1 and s.calls[1] == 'exists')
    record, why = observe(p, true)

    assert(
        record.exists == true
            and record.name == 'Wolf'
            and why == nil
            and #s.calls == 3
            and s.calls[2] == 'exists'
            and s.calls[3] == 'name'
    )

    s.exists = false
    record, why = observe(p, true)
    assert(record.exists == false and record.name == nil and why == nil and #s.calls == 4)
end)

test('mode guards and conservative policy precede native calls while nil defaults to presence', function()
    for _, project in ipairs({ 999 }) do
        local _, p, s = fixture(project)
        unavailable(p, true, 'unsupported-policy')
        assert(#s.calls == 0)
    end

    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, bad in ipairs({ 0, 'false', '', {}, opaque }) do
        unavailable(p, bad, rawequal(bad, opaque) and 'restricted-value' or 'invalid-pet-query')
    end

    assert(#s.calls == 0)
    local record = observe(p)
    assert(record.exists and record.name == nil and #s.calls == 1)
end)

test('existence must be a readable strict boolean for both query modes', function()
    for _, mode in ipairs({ false, true }) do
        local f, p, s = fixture()
        s.exists = nil
        unavailable(p, mode, 'pet-data-unavailable')

        for _, bad in ipairs({ 0, 1, 'false', {} }) do
            s.exists = bad
            unavailable(p, mode, 'invalid-api-result')
        end

        s.exists = true
        s.throw = 'exists'
        unavailable(p, mode, 'api-error')
        s.throw = nil
        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
        s.exists = opaque
        unavailable(p, mode, 'restricted-value')
        f.env.UnitExists = nil
        unavailable(p, mode, 'missing-api')
    end
end)

test('known presence and absence do not require names while requested unknown names remain unavailable', function()
    local f, p, s = fixture()
    f.env.GetUnitName = nil
    assert(observe(p, false).exists == true and #s.calls == 1)
    s.exists = false
    assert(observe(p, true).exists == false and #s.calls == 2)
    s.exists = true
    unavailable(p, true, 'missing-api')
    f, p, s = fixture()
    s.name = nil
    unavailable(p, true, 'pet-name-unavailable')

    for _, bad in ipairs({ '', false, 0, {} }) do
        s.name = bad
        unavailable(p, true, 'invalid-api-result')
    end

    s.name = 'Wolf'
    s.throw = 'name'
    unavailable(p, true, 'api-error')
    s.throw = nil
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    s.name = opaque
    unavailable(p, true, 'restricted-value')
end)

test('all probe families load without queries and use live helper replacements preserving formatted names', function()
    for _, project in ipairs({ 2, 5, 11, 14, 19 }) do
        local f, p, s = fixture(project)
        assert(type(p.GetPetObservation) == 'function', 'owned pet observer missing')
        f.load('Platform/pet.lua')
        assert(#s.calls == 0)
        assert(observe(p, true).name == 'Wolf')

        f.env.GetUnitName = function(...)
            assert(select('#', ...) == 1 and select(1, ...) == 'pet')
            return 'Wolf (*)'
        end

        assert(observe(p, true).name == 'Wolf (*)', 'observer lost GetUnitName display formatting')

        f.env.UnitExists = function(unit)
            assert(unit == 'pet')
            return false
        end

        f.env.GetUnitName = function()
            error('absent pet queried name')
        end

        assert(observe(p, true).exists == false)
    end
end)

test('secret and access checks reject opaque metadata and inaccessible false before comparisons', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = nil
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    s.name = opaque
    unavailable(p, true, 'restricted-value')
    assert(observe(p, false).exists == true)
    s.exists = opaque
    unavailable(p, false, 'restricted-value')
    s.exists = false
    f.env.issecretvalue = nil
    f.env.canaccessvalue = function(v) return v ~= false end
    unavailable(p, true, 'restricted-value')
    unavailable(p, false, 'restricted-value')
end)

finish()
