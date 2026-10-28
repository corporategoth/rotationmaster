local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(values)
    local addon = {}
    local env = setmetatable(values or {}, { __index = _G })
    env._G = env
    local load = assert(loadfile('Platform/client.lua'))
    setfenv(load, env)
    load('rotationmaster', addon)
    return addon.Platform, env
end

local families = {
    { 'WOW_PROJECT_MAINLINE', 1, 'retail' },
    { 'WOW_PROJECT_CLASSIC', 2, 'era' },
    { 'WOW_PROJECT_MISTS_CLASSIC', 19, 'progression' },
    { 'WOW_PROJECT_CATACLYSM_CLASSIC', 14, 'progression' },
    { 'WOW_PROJECT_WRATH_CLASSIC', 11, 'progression' },
    { 'WOW_PROJECT_BURNING_CRUSADE_CLASSIC', 5, 'tbc' },
    { 'WOW_PROJECT_CAMELOT', 18, 'forever' },
}

for _, case in ipairs(families) do
    test('explicit project constant identifies ' .. case[3] .. ' ' .. case[1], function()
        local platform = fixture({
            WOW_PROJECT_ID = case[2],
            [case[1]] = case[2],
            LE_EXPANSION_LEVEL_CURRENT = 4,
            GetBuildInfo = function() return 'test-version', 'test-build', 'date', 50504 end,
        })

        local info = platform:GetClientInfo()
        assert(info.family == case[3] and info.projectId == case[2])
        assert(info.interface == 50504 and info.expansion == 4)
        assert(info.version == 'test-version' and info.build == 'test-build')
        assert(info.runtimeVerified == false)
        local policy = (case[3] == 'retail' or case[3] == 'forever') and 'restricted' or 'probe'
        assert(info.combatDataPolicy == policy)
    end)
end

test('absent project constants and unknown future project stay unknown', function()
    for _, values in ipairs({
        {},
        { WOW_PROJECT_ID = 999 },
        { WOW_PROJECT_ID = 18, WOW_PROJECT_CAMELOT = 17 },
        { WOW_PROJECT_ID = 18, WOW_PROJECT_CAMELOT = '18' },
    }) do
        local platform = fixture(values)
        assert(platform:GetClientInfo().family == 'unknown')
        assert(platform:GetClientInfo().combatDataPolicy == 'unsupported')
    end
end)

test('ruleset facts remain independent and snapshots cannot mutate later results', function()
    local platform = fixture({
        WOW_PROJECT_ID = 2,
        WOW_PROJECT_CLASSIC = 2,
        LE_EXPANSION_LEVEL_CURRENT = 0,
        C_Seasons = { GetActiveSeason = function() return 2 end },
        C_GameRules = {
            IsHardcoreActive = function() return false end,
            IsSelfFoundAllowed = function() return true end,
            GetCurrentGameModeRecordID = function() return 77 end,
        },
        GetClassicExpansionLevel = function() return 0 end,
        GetLocale = function() return 'deDE' end,
    })

    local info = platform:GetClientInfo()
    assert(info.seasonId == 2 and info.hardcore == false and info.selfFoundAllowed == true)
    assert(info.gameModeId == 77 and info.classicExpansionLevel == 0 and info.locale == 'deDE')
    assert(info.selfFoundActive == nil)
    info.family = 'broken'
    assert(platform:GetClientInfo().family == 'era')
end)

test('value access guards do not stringify opaque observations', function()
    local secret = setmetatable({}, {
        __tostring = function()
            error('opaque value inspected')
        end,
    })

    local platform = fixture({ issecretvalue = function(value) return rawequal(value, secret) end })
    assert(not platform:CanReadValue(secret))
    assert(platform:CanReadValue(42))
    local denied = fixture({ canaccessvalue = function(value) return not rawequal(value, secret) end })
    assert(not denied:CanReadValue(secret))
    local legacy = fixture({})
    assert(legacy:CanReadValue(nil) and legacy:CanReadValue(false))
end)

test('API declaration presence is separate from readability and assisted availability', function()
    local platform = fixture({
        C_Spell = { GetSpellInfo = function() end, GetSpellCooldown = function() end },
        GetSpellBookItemInfo = function() end,
        UnitAura = function() end,
        C_AssistedCombat = {
            IsAvailable = function() return false, 'not supported for this character' end,
            GetNextCastSpell = function()
                error('must not request suggestion while unavailable')
            end,
        },
    })

    local surface = platform:GetAPISurface()
    assert(surface.spellMetadata.status == 'present' and surface.spellMetadata.source == 'C_Spell.GetSpellInfo')
    assert(surface.spellbook.status == 'present' and surface.spellbook.source == 'GetSpellBookItemInfo')
    assert(surface.aura.readability == 'unverified' and surface.cooldown.readability == 'unverified')
    assert(surface.eventValidation.status == 'missing')
    local availability = platform:GetAssistedAvailability()
    assert(availability.available == false and availability.reason == 'not supported for this character')
    local empty = fixture({})
    assert(empty:GetAPISurface().spellMetadata.status == 'missing')
    assert(empty:GetAssistedAvailability().available == false)
end)

finish()
