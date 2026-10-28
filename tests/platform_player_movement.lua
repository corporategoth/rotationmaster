local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project)
    local a, e = f.addon, f.env
    local s = { speed = 0, calls = 0 }

    e.GetUnitSpeed = function(...)
        assert(select('#', ...) == 1 and (...) == 'player', 'movement query redirected or added native arguments')
        s.calls = s.calls + 1

        if s.throw then
            error('native failed')
        end

        return s.speed, s.run, s.flight, s.swim
    end

    e.UnitExists = function()
        error('movement invented an existence dependency')
    end

    e.UnitPowerType = function()
        error('movement invented a form dependency')
    end

    local file = io.open('Platform/player_movement.lua')

    if file then
        file:close()
        f.load('Platform/player_movement.lua')
    end

    return f, a.Platform, s
end

test('movement observes exact player tuple preserving zero fractions and fresh complete records', function()
    local _, p, s = fixture()
    assert(s.calls == 0, 'module queried movement while loading')

    for _, speed in ipairs({ 0, .125, 7, 1e308 }) do
        s.speed = speed
        local r, why = p:GetPlayerMovementObservation()
        assert(r.speed == speed and why == nil)
        r.speed = -1
        assert(p:GetPlayerMovementObservation().speed == speed)
    end

    assert(s.calls == 8)
end)

test('unsupported and restricted policies cannot query speed', function()
    for _, project in ipairs({ 999 }) do
        local _, p, s = fixture(project)
        local r, why = p:GetPlayerMovementObservation()
        assert(r == nil and why == 'unsupported-policy' and s.calls == 0)
    end
end)

test('all supported probe families keep the exact speed observation', function()
    for _, project in ipairs({ 2, 5, 11, 14, 19 }) do
        local _, p, s = fixture(project)
        s.speed = .5
        assert(p:GetPlayerMovementObservation().speed == .5 and s.calls == 1)
    end
end)

test('missing failed and nil speed are unavailable observations', function()
    local f, p, s = fixture()
    s.speed = nil
    local r, why = p:GetPlayerMovementObservation()
    assert(r == nil and why == 'movement-data-unavailable')
    s.throw = true
    r, why = p:GetPlayerMovementObservation()
    assert(r == nil and why == 'api-error')
    s.throw = nil
    f.env.GetUnitSpeed = nil
    r, why = p:GetPlayerMovementObservation()
    assert(r == nil and why == 'missing-api')
end)

test('current speed must be readable finite and nonnegative before comparisons', function()
    local f, p, s = fixture()

    local secret = setmetatable({}, {
        __eq = function()
            error('unreadable speed compared')
        end,
        __lt = function()
            error('unreadable speed ordered')
        end,
    })

    f.env.canaccessvalue = function(v) return not rawequal(v, secret) end
    s.speed = secret
    local r, why = p:GetPlayerMovementObservation()
    assert(r == nil and why == 'restricted-value')
    f.env.canaccessvalue = nil
    f.env.issecretvalue = function(v) return rawequal(v, secret) end
    r, why = p:GetPlayerMovementObservation()
    assert(r == nil and why == 'restricted-value')
    f.env.issecretvalue = nil

    for _, bad in ipairs({ -1, math.huge, -math.huge, 0 / 0, '0', true, false, {} }) do
        s.speed = bad
        r, why = p:GetPlayerMovementObservation()
        assert(r == nil and why == 'invalid-api-result')
    end

    s.speed = .25
    assert(p:GetPlayerMovementObservation().speed == .25, 'old clients without secret guards lost readable speed')
end)

test('unused run flight and swim fields do not hide a readable current speed', function()
    local f, p, s = fixture()
    local secret = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, secret) end
    s.speed = 0
    s.run = secret
    s.flight = secret
    s.swim = secret
    assert(p:GetPlayerMovementObservation().speed == 0 and s.calls == 1)
end)

finish()
