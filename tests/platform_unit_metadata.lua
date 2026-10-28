-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local apis = { class = 'UnitClass', creature = 'UnitCreatureType', classification = 'UnitClassification' }
local expected = { class = 'MAGE', creature = 'Humanoid', classification = 'normal' }

local function fixture(project)
    local f = F.new(project)
    local a, e = f.addon, f.env

    local s = {
        exists = true,
        class = 'MAGE',
        creature = 'Humanoid',
        classification = 'normal',
        label = 'Mage',
        classID = 8,
        creatureID = 7,
        calls = {},
    }

    local function call(key, ...)
        assert(select('#', ...) == 1)
        s.calls[#s.calls + 1] = { key, ... }

        if s.throw == key then
            error('native metadata failure')
        end
    end

    e.UnitExists = function(...)
        call('exists', ...)
        return s.exists
    end

    e.UnitClass = function(...)
        call('class', ...)

        if s.noReturns == 'class' then
            return
        end

        return s.label, s.class, s.classID
    end

    e.UnitCreatureType = function(...)
        call('creature', ...)

        if s.noReturns == 'creature' then
            return
        end

        return s.creature, s.creatureID
    end

    e.UnitClassification = function(...)
        call('classification', ...)

        if s.noReturns == 'classification' then
            return
        end

        return s.classification
    end

    local file = io.open('Platform/unit_metadata.lua')

    if file then
        file:close()
        f.load('Platform/unit_metadata.lua')
    end

    return f, a.Platform, s
end

local function observe(p, kind, unit)
    assert(type(p.GetUnitMetadataObservation) == 'function', 'owned unit metadata observer missing')
    return p:GetUnitMetadataObservation(unit or 'target', kind)
end

local function unavailable(p, kind, reason)
    local value, why = observe(p, kind)
    assert(value == nil and why == reason, tostring(value) .. ':' .. tostring(why) .. ' expected ' .. reason)
end

test('closed kinds preserve exact selected-unit query order and consumed fields', function()
    local _, p, s = fixture()

    for kind in pairs(apis) do
        for _, unit in ipairs({ 'player', 'target', 'pet', 'vehicle', 'focus' }) do
            s.calls = {}
            local value, why = observe(p, kind, unit)
            assert(value == expected[kind] and why == nil and #s.calls == 2)
            assert(s.calls[1][1] == 'exists' and s.calls[1][2] == unit and #s.calls[1] == 2)
            assert(s.calls[2][1] == kind and s.calls[2][2] == unit and #s.calls[2] == 2)
        end
    end
end)

test('policy kind and unit guards precede all native queries', function()
    for _, project in ipairs({ 999 }) do
        local _, p, s = fixture(project)

        for kind in pairs(apis) do
            unavailable(p, kind, 'unsupported-policy')
        end

        assert(#s.calls == 0)
    end

    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, bad in ipairs({ '', false, 0, {}, opaque }) do
        local value, why = p:GetUnitMetadataObservation(bad, 'class')
        assert(value == nil and why == (rawequal(bad, opaque) and 'restricted-value' or 'invalid-unit'))
        value, why = p:GetUnitMetadataObservation('target', bad)
        assert(value == nil and why == (rawequal(bad, opaque) and 'restricted-value' or 'invalid-unit-metadata-query'))
    end

    assert(
        p:GetUnitMetadataObservation(nil, 'class') == nil
            and p:GetUnitMetadataObservation('target', nil) == nil
            and #s.calls == 0
    )

    s.exists = false
    unavailable(p, 'CLASS', 'invalid-unit-metadata-query')
    assert(#s.calls == 0)
end)

test('each required observation rejects missing failed nil empty nonstring and restricted results', function()
    for kind, api in pairs(apis) do
        local f, p, s = fixture()
        s.exists = nil
        unavailable(p, kind, 'unit-data-unavailable')

        for _, bad in ipairs({ 0, 1, 'false', {} }) do
            s.exists = bad
            unavailable(p, kind, 'invalid-api-result')
        end

        s.exists = true
        s.throw = 'exists'
        unavailable(p, kind, 'api-error')
        s.throw = nil
        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
        s.exists = opaque
        unavailable(p, kind, 'restricted-value')
        s.exists = true
        f.env.UnitExists = nil
        unavailable(p, kind, 'missing-api')
        f, p, s = fixture()
        s[kind] = nil
        unavailable(p, kind, 'unit-metadata-unavailable')
        s.noReturns = kind
        unavailable(p, kind, 'unit-metadata-unavailable')
        s.noReturns = nil

        for _, bad in ipairs({ '', false, 0, 1, {} }) do
            s[kind] = bad
            unavailable(p, kind, 'invalid-api-result')
        end

        s[kind] = expected[kind]
        s.throw = kind
        unavailable(p, kind, 'api-error')
        s.throw = nil
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
        s[kind] = opaque
        unavailable(p, kind, 'restricted-value')
        f.env[api] = nil
        unavailable(p, kind, 'missing-api')
    end
end)

test('readable first-unit absence needs no metadata API and no other kind query', function()
    for kind in pairs(apis) do
        local f, p, s = fixture()
        s.exists = false

        for _, api in pairs(apis) do
            f.env[api] = nil
        end

        local value, why = observe(p, kind)
        assert(value == false and why == nil and #s.calls == 1)
        f, p, s = fixture()
        s.exists = false
        s.throw = kind
        assert(observe(p, kind) == false and #s.calls == 1)
    end
end)

test('only consumed metadata is required and readable future strings retain native identity', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    s.label = opaque
    s.classID = opaque
    s.creatureID = opaque
    assert(observe(p, 'class') == 'MAGE' and observe(p, 'creature') == 'Humanoid')
    s.label = nil
    s.classID = nil
    s.creatureID = nil
    assert(observe(p, 'class') == 'MAGE' and observe(p, 'creature') == 'Humanoid')

    for kind in pairs(apis) do
        s[kind] = 'Future native value'
        assert(observe(p, kind) == 'Future native value')
    end

    f.env.canaccessvalue = nil
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    s.class = opaque
    unavailable(p, 'class', 'restricted-value')
    s.class = 'MAGE'
    assert(observe(p, 'class') == 'MAGE')
    f.env.issecretvalue = nil
    f.env.canaccessvalue = function(v) return v ~= false end
    s.exists = false
    unavailable(p, 'class', 'restricted-value')
end)

test('probe families load without native queries and observe live API replacements', function()
    for _, project in ipairs({ 2, 5, 11, 14, 19 }) do
        local f, p, s = fixture(project)
        assert(type(p.GetUnitMetadataObservation) == 'function', 'owned unit metadata observer missing')
        f.load('Platform/unit_metadata.lua')
        assert(#s.calls == 0, 'adapter queried natives while loading')

        for kind in pairs(apis) do
            assert(observe(p, kind) == expected[kind])
        end

        f.env.UnitClass = function(unit)
            assert(unit == 'target')
            return 'Localized replacement', 'WARRIOR'
        end

        assert(observe(p, 'class') == 'WARRIOR')

        f.env.UnitCreatureType = function(unit)
            assert(unit == 'target')
            return 'Bête'
        end

        assert(observe(p, 'creature') == 'Bête')

        f.env.UnitClassification = function(unit)
            assert(unit == 'target')
            return 'elite'
        end

        assert(observe(p, 'classification') == 'elite')

        f.env.UnitExists = function(unit)
            assert(unit == 'target')
            return false
        end

        f.env.UnitClass = function()
            error('absent unit reached metadata API')
        end

        assert(observe(p, 'class') == false)
    end
end)

finish()
