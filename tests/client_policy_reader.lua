-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local a = {}
    local state = { metadata = 0, reads = 0 }

    local e = setmetatable(
        { WOW_PROJECT_ID = 5, WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5, LE_EXPANSION_LEVEL_CURRENT = 1 },
        { __index = _G }
    )

    e._G = e

    for _, name in ipairs({ 'GetLocale', 'GetBuildInfo', 'GetClassicExpansionLevel' }) do
        e[name] = function()
            state.metadata = state.metadata + 1
            return 'build', '2345', 'date', 20506
        end
    end

    e.issecretvalue = function()
        state.reads = state.reads + 1
        return false
    end

    e.canaccessvalue = function() return true end

    local load = function(path)
        local fn = assert(loadfile(path))
        setfenv(fn, e)
        fn('rotationmaster', a)
    end

    load('Platform/client.lua')
    local reader

    if a.ConsumeClientPolicyReader then
        reader = a:ConsumeClientPolicyReader()
    end

    reader = reader or function(p) return p:GetClientInfo().combatDataPolicy end
    return a, e, state, reader, load
end

test('owned policy reads omit irrelevant full metadata without retaining a public snapshot', function()
    local a, e, s, reader = fixture()
    local p = a.Platform
    assert(reader(p) == 'probe' and s.metadata == 0, 'policy-only read built full metadata')
    e.WOW_PROJECT_ID = 1
    e.WOW_PROJECT_MAINLINE = 1
    assert(reader(p) == 'restricted' and s.metadata == 0)
    e.WOW_PROJECT_ID = 999
    assert(reader(p) == 'unsupported' and s.metadata == 0)
end)

test('project and readability remain fresh on every invocation', function()
    local a, e, s, reader = fixture()
    local p = a.Platform
    assert(reader(p) == 'probe')
    local reads = s.reads

    e.issecretvalue = function(v)
        s.reads = s.reads + 1
        return v == 5
    end

    assert(reader(p) == 'unsupported' and s.reads > reads)
    e.issecretvalue = function() return false end
    e.canaccessvalue = function(v) return v ~= 5 end
    assert(reader(p) == 'unsupported')
    e.canaccessvalue = function() return true end
    assert(reader(p) == 'probe')
end)

test('public full metadata remains fresh detached and complete', function()
    local a, e, s, reader = fixture()
    local p = a.Platform

    e.GetLocale = function()
        s.metadata = s.metadata + 1
        return 'enUS'
    end

    e.C_Seasons = { GetActiveSeason = function() return 2 end }
    e.C_GameRules = { IsHardcoreActive = function() return false end }
    local x = p:GetClientInfo()
    assert(x.locale == 'enUS' and x.seasonId == 2 and x.hardcore == false and x.runtimeVerified == false)
    x.family = 'bad'
    e.GetLocale = function() return 'deDE' end
    local y = p:GetClientInfo()
    assert(y.locale == 'deDE' and y.family == 'tbc' and y ~= x)
    assert(reader(p) == 'probe')
end)

test('overridden full method is selected once and its actual first result is used', function()
    local a, e, s, reader = fixture()
    local p = a.Platform
    local calls, gets = 0, 0

    p.GetClientInfo = function(self, ...)
        assert(self == p and select('#', ...) == 0)
        calls = calls + 1

        return setmetatable({}, {
            __index = function(_, key)
                assert(key == 'combatDataPolicy')
                gets = gets + 1
                return 'restricted'
            end,
        }),
            'ignored'
    end

    assert(reader(p) == 'restricted' and calls == 1 and gets == 1)
end)

test('public accessor method lookup remains once even when it returns original function', function()
    local a, e, s, reader = fixture()
    local p = a.Platform
    local original = p.GetClientInfo
    local gets = 0
    p.GetClientInfo = nil

    setmetatable(p, {
        __index = function(_, key)
            assert(key == 'GetClientInfo')
            gets = gets + 1
            return original
        end,
    })

    assert(reader(p) == 'probe' and gets == 1 and s.metadata > 0, 'accessor did not keep actual full dispatch')
end)

test('foreign receiver retains selected method and error identity', function()
    local a, e, s, reader = fixture()
    local calls = 0
    local foreign = {}

    -- Capture the receiver separately: Lua locals are not in their own initializer scope.
    foreign.GetClientInfo = function(self)
        assert(self == foreign)
        calls = calls + 1
        return { combatDataPolicy = 'foreign' }
    end

    assert(reader(foreign) == 'foreign' and calls == 1)
    local marker = {}

    a.Platform.GetClientInfo = function()
        error(marker)
    end

    local ok, why = pcall(reader, a.Platform)
    assert(not ok and why == marker)
end)

test('same public function with changed environment falls back to its full semantics', function()
    local a, e, s, reader = fixture()
    local p = a.Platform
    local original = p.GetClientInfo
    local proxy = setmetatable({ WOW_PROJECT_ID = 1, WOW_PROJECT_MAINLINE = 1 }, { __index = e })
    setfenv(original, proxy)
    assert(reader(p) == 'restricted' and s.metadata > 0, 'changed environment incorrectly projected')
    setfenv(original, e)
    s.metadata = 0
    assert(reader(p) == 'probe' and s.metadata == 0, 'restored owned method not eligible')
end)

test('unknown callable and malformed methods retain public dispatch behavior', function()
    local a, e, s, reader = fixture()
    local p = a.Platform
    local n = 0

    p.GetClientInfo = setmetatable({}, {
        __call = function(_, self)
            assert(self == p)
            n = n + 1
            return { combatDataPolicy = 'callable' }
        end,
    })

    assert(reader(p) == 'callable' and n == 1)

    for _, value in ipairs({ false, 17, 'bad' }) do
        p.GetClientInfo = value
        assert(not pcall(reader, p))
    end
end)

test('real flag and attackability adapters skip metadata but keep native observations fresh', function()
    local a, e, s, reader, load = fixture()
    local p = a.Platform
    local combat = false
    e.UnitExists = function() return true end
    e.UnitAffectingCombat = function() return combat end
    e.UnitCanAttack = function() return combat end
    e.UnitIsDead = function() return false end
    load('Platform/unit_flags.lua')
    load('Platform/unit_attackability.lua')
    assert(p:GetUnitFlagObservation('player', 'combat') == false)
    assert(p:GetUnitAttackabilityObservation('target') == false)
    combat = true
    assert(p:GetUnitFlagObservation('player', 'combat') == true and p:GetUnitAttackabilityObservation('target') == true)
    assert(s.metadata == 0, 'real adapter full metadata remains')
    -- Restricted clients read these never-secret flags too; an unknown policy does not.
    p.GetClientInfo = function() return { combatDataPolicy = 'restricted' } end
    assert(p:GetUnitFlagObservation('player', 'combat') == true and p:GetUnitAttackabilityObservation('target') == true)
    p.GetClientInfo = function() return { combatDataPolicy = 'unsupported' } end
    assert(p:GetUnitFlagObservation('player', 'combat') == nil and p:GetUnitAttackabilityObservation('target') == nil)
end)

test('foreign receiver identity does not invoke user equality', function()
    local a, e, s, reader = fixture()
    local p = a.Platform
    local equal = 0

    local mt = {
        __eq = function()
            equal = equal + 1
            return true
        end,
    }

    setmetatable(p, mt)
    local foreign = setmetatable({ GetClientInfo = function() return { combatDataPolicy = 'foreign' } end }, mt)
    assert(reader(foreign) == 'foreign' and equal == 0)
end)

test('late readability override reentry preserves the full selected-method path', function()
    local function run(projected)
        local a, e, s, reader = fixture()
        local p = a.Platform
        local original = p.GetClientInfo
        local calls = 0
        local proxy = setmetatable({ WOW_PROJECT_ID = 1, WOW_PROJECT_MAINLINE = 1 }, { __index = e })

        e.issecretvalue = function(value)
            calls = calls + 1

            if calls == 1 then
                setfenv(original, proxy)
            end

            return false
        end

        local result = projected and reader(p) or p:GetClientInfo().combatDataPolicy
        assert(getfenv(original) == proxy)
        setfenv(original, e)
        return result, calls, s.metadata
    end

    local old, oldCalls, oldMetadata = run(false)
    local new, newCalls, newMetadata = run(true)
    assert(old == new and oldCalls == newCalls and oldMetadata == newMetadata and newMetadata > 0)
end)

test('optional cold and hot environment inspection requires an actual table', function()
    for _, cold in ipairs({ true, false }) do
        for _, denied in ipairs({ false, 17, 'not an environment' }) do
            local a = {}
            local restricted = false
            local e = setmetatable({ WOW_PROJECT_ID = 5, WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5 }, { __index = _G })
            e._G = e

            e.getfenv = function(fn)
                if cold or restricted then
                    return denied
                end

                return getfenv(fn)
            end

            local load = assert(loadfile('Platform/client.lua'))
            setfenv(load, e)
            load('rotationmaster', a)
            local reader = assert(a:ConsumeClientPolicyReader())
            assert(reader(a.Platform) == 'probe')
            restricted = true
            assert(reader(a.Platform) == 'probe', 'optional environment result altered policy')
        end
    end
end)

test('public fallback metadata errors stay outside optional inspection protection', function()
    local a = {}
    local denied = false
    local e = setmetatable({ WOW_PROJECT_ID = 5, WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5 }, { __index = _G })
    e._G = e

    e.getfenv = function(fn)
        if denied then
            error('optional deny')
        end

        return getfenv(fn)
    end

    local load = assert(loadfile('Platform/client.lua'))
    setfenv(load, e)
    load('rotationmaster', a)
    local reader = assert(a:ConsumeClientPolicyReader())
    assert(reader(a.Platform) == 'probe')
    local marker = {}

    e.C_Seasons = setmetatable({}, {
        __index = function()
            error(marker)
        end,
    })

    denied = true
    local ok, why = pcall(reader, a.Platform)
    assert(not ok and why == marker, 'public metadata error swallowed')
end)

finish()
