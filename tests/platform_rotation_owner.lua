local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local p = f.addon.Platform
    local s = { token = 'SHAMAN', calls = 0 }
    local opaque = {}

    f.env.UnitClass = function(...)
        assert(select('#', ...) == 1 and (...) == 'player', 'changed native owner query')
        s.calls = s.calls + 1

        if s.throw then
            error('class failed')
        end

        return opaque, s.token, opaque
    end

    f.env.canaccessvalue = function(value) return not rawequal(value, opaque) end
    local h = io.open('Platform/rotation_owner.lua')

    if h then
        h:close()
        f.load('Platform/rotation_owner.lua')
    end

    return f, p, s, opaque
end

local function observe(p)
    assert(type(p.GetPlayerOwnerClassObservation) == 'function', 'fresh owner observation missing')
    return p:GetPlayerOwnerClassObservation()
end

test('owner class consumes only return2 from one fresh exact player query', function()
    local _, p, s = fixture()
    assert(s.calls == 0)
    assert(observe(p) == 'SHAMAN' and s.calls == 1)
    s.token = 'MAGE'
    assert(observe(p) == 'MAGE' and s.calls == 2)
end)

test('owner observation does not require eligibility family existence or other class tuple fields', function()
    local f, p, s = fixture()

    local function unused()
        error('unconsumed owner observation')
    end

    p.GetClientInfo = unused
    f.env.UnitExists = unused
    f.env.UnitLevel = unused
    f.env.UnitHasVehicleUI = unused
    f.env.UnitInVehicle = unused
    f.env.C_PetBattles = { IsInBattle = unused }
    assert(observe(p) == 'SHAMAN' and s.calls == 1)
end)

test('missing thrown absent malformed and unreadable class observations remain unavailable', function()
    local f, p, s, opaque = fixture()

    local function unknown(reason)
        local token, why = observe(p)
        assert(token == nil and why == reason, tostring(why))
    end

    for _, bad in ipairs({ false, 0, 0 / 0, '', {}, opaque }) do
        s.token = bad
        unknown(rawequal(bad, opaque) and 'restricted-value' or 'invalid-api-result')
    end

    s.token = nil
    unknown('class-data-unavailable')
    s.throw = true
    unknown('api-error')
    s.throw = false
    f.env.UnitClass = nil
    unknown('missing-api')
end)

test('readability is enforced with and without native access helpers', function()
    local f, p, s, opaque = fixture()
    s.token = opaque
    f.env.canaccessvalue = nil
    f.env.issecretvalue = function(v) return rawequal(v, opaque) end
    local token, why = observe(p)
    assert(token == nil and why == 'restricted-value')
    f.env.issecretvalue = nil
    s.token = 'SHAMAN'
    assert(observe(p) == 'SHAMAN')
    f.env.canaccessvalue = function() return false end
    token, why = observe(p)
    assert(token == nil and why == 'restricted-value')
end)

test('module load stays query free and later calls use replacement native API', function()
    local f, p, s = fixture()
    f.load('Platform/rotation_owner.lua')
    assert(s.calls == 0)

    f.env.UnitClass = function(...)
        assert(select('#', ...) == 1 and (...) == 'player')
        return 'Ignored', 'DRUID', 11
    end

    assert(observe(p) == 'DRUID' and s.calls == 0)
end)

test('actual editable public helper clone keeps fresh return2 and readability contracts', function()
    local f, p, s, opaque = fixture()
    local a = f.addon
    f.load('Data/builtin_sources.lua')
    f.load('Core/builtin_sources.lua')
    f.load('Core/custom_authoring.lua')

    f.env.loadstring = function(code, name)
        local fn, why = loadstring(code, name)

        if fn then
            setfenv(fn, f.env)
        end

        return fn, why
    end

    local id = 'builtin:Platform/rotation_owner.lua:Platform_GetPlayerOwnerClassObservation'
    local record = assert(a.builtinFunctions[id], 'new owner helper catalog pending')

    assert(
        record.public
            and record.source.args[1].type == 'RMPlatform'
            and #record.source.args == 1
            and #record.source.returns == 2
    )

    assert(a:ResolveFunctionBinding(id) == p.GetPlayerOwnerClassObservation)
    assert(a:InstallCustomFunction('COPY_OWNER_OBSERVATION', a:CopySettingsData(record.source)))
    local clone = assert(a:ResolveFunctionBinding('COPY_OWNER_OBSERVATION'))
    assert(clone(p) == 'SHAMAN')
    s.token = 'MAGE'
    assert(clone(p) == 'MAGE' and s.calls == 2)
    s.token = opaque
    local value, why = clone(p)
    assert(value == nil and why == 'restricted-value')
end)

finish()
