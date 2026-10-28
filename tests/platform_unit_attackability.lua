local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project)
    local a, e = f.addon, f.env
    local s = { exists = true, attack = true, dead = false, calls = {} }

    local function call(key, ...)
        s.calls[#s.calls + 1] = { key, ... }

        if s.throw == key then
            error('native failure')
        end

        return s[key]
    end

    e.UnitExists = function(...)
        assert(select('#', ...) == 1)
        return call('exists', ...)
    end

    e.UnitCanAttack = function(...)
        assert(select('#', ...) == 2)
        return call('attack', ...)
    end

    e.UnitIsDead = function(...)
        assert(select('#', ...) == 1)
        return call('dead', ...)
    end

    e.UnitIsDeadOrGhost = function()
        error('ghost substitution')
    end

    local file = io.open('Platform/unit_attackability.lua')

    if file then
        file:close()
        f.load('Platform/unit_attackability.lua')
    end

    return f, a.Platform, s
end

local function observe(p, unit)
    assert(type(p.GetUnitAttackabilityObservation) == 'function', 'owned attackability adapter missing')
    return p:GetUnitAttackabilityObservation(unit or 'target')
end

local function unavailable(p, s, reason)
    local value, why = observe(p)
    assert(value == nil and why == reason, tostring(value) .. ':' .. tostring(why) .. ' expected ' .. reason)
end

test('exact player attacker and selected unit tuples preserve alive dead and false controls', function()
    local _, p, s = fixture()

    for _, unit in ipairs({ 'target', 'pet', 'vehicle', 'focus' }) do
        s.calls = {}
        local v, why = observe(p, unit)
        assert(v == true and why == nil and #s.calls == 3)
        assert(s.calls[1][1] == 'exists' and s.calls[1][2] == unit and #s.calls[1] == 2)
        assert(s.calls[2][1] == 'attack' and s.calls[2][2] == 'player' and s.calls[2][3] == unit and #s.calls[2] == 3)
        assert(s.calls[3][1] == 'dead' and s.calls[3][2] == unit and #s.calls[3] == 2)
    end

    s.dead = true
    assert(observe(p) == false)
    s.attack = false
    s.calls = {}
    assert(observe(p) == false and #s.calls == 2)
    s.exists = false
    s.calls = {}
    assert(observe(p) == false and #s.calls == 1)
end)

test('policy and readable nonempty unit validation precede all native queries', function()
    for _, project in ipairs({ 999 }) do
        local _, p, s = fixture(project)
        unavailable(p, s, 'unsupported-policy')
        assert(#s.calls == 0)
    end

    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, unit in ipairs({ '', false, 0, {}, opaque }) do
        local v, why = p:GetUnitAttackabilityObservation(unit)
        assert(v == nil and why == (unit == opaque and 'restricted-value' or 'invalid-unit'))
    end

    assert(p:GetUnitAttackabilityObservation(nil) == nil and #s.calls == 0)
end)

test('every required observation rejects nil missing failed malformed and restricted values', function()
    local apis = { exists = 'UnitExists', attack = 'UnitCanAttack', dead = 'UnitIsDead' }

    local missing = {
        exists = 'unit-data-unavailable',
        attack = 'attackability-data-unavailable',
        dead = 'death-data-unavailable',
    }

    for key, api in pairs(apis) do
        local f, p, s = fixture()
        s[key] = nil
        unavailable(p, s, missing[key])

        for _, bad in ipairs({ 0, 1, 'false', {} }) do
            s[key] = bad
            unavailable(p, s, 'invalid-api-result')
        end

        s[key] = true
        s.throw = key
        unavailable(p, s, 'api-error')
        s.throw = nil
        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
        s[key] = opaque
        unavailable(p, s, 'restricted-value')
        f.env[api] = nil
        unavailable(p, s, 'missing-api')
    end
end)

test('known false short circuits unavailable later APIs without requiring a death query', function()
    local f, p, s = fixture()
    s.exists = false
    f.env.UnitCanAttack = nil
    f.env.UnitIsDead = nil
    local v, why = observe(p)
    assert(v == false and why == nil and #s.calls == 1)
    f, p, s = fixture()
    s.attack = false
    f.env.UnitIsDead = nil
    v, why = observe(p)
    assert(v == false and why == nil and #s.calls == 2)
    f, p, s = fixture()
    s.attack = false
    s.throw = 'dead'
    assert(observe(p) == false and #s.calls == 2)
end)

test('secret and access checks preserve false only after successful readability proof', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = nil
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    s.dead = opaque
    unavailable(p, s, 'restricted-value')
    s.dead = false
    assert(observe(p) == true)
    f.env.issecretvalue = nil
    f.env.canaccessvalue = function(v) return v ~= false end
    s.attack = false
    unavailable(p, s, 'restricted-value')
end)

finish()
