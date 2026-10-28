local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/platform.lua')

local function fixture(env)
    return make(env, { 'Platform/client.lua', 'Platform/auras.lua' })
end

local test, finish = F.suite()

test('modern aura fields normalize without exposing the native record', function()
    local original = {
        name = 'Earth Shield',
        spellId = 974,
        applications = 6,
        expirationTime = 125,
        duration = 600,
        sourceUnit = 'player',
    }

    local p = fixture({
        C_UnitAuras = {
            GetAuraDataByIndex = function(unit, index, filter)
                assert(unit == 'party1' and index == 1 and filter == 'HELPFUL')
                return original
            end,
        },
    })

    local aura = p:GetAuraByIndex('party1', 1, 'HELPFUL')

    assert(
        aura.name == 'Earth Shield' and aura.spellID == 974 and aura.applications == 6 and aura.sourceUnit == 'player'
    )

    assert(p:AuraRemaining(aura, 100) == 25)
    aura.name = 'Changed'
    assert(original.name == 'Earth Shield')
end)

test('legacy tuple positions retain charges, dispel type and caster', function()
    local p = fixture({
        UnitAura = function(unit, index, filter)
            assert(filter == 'HARMFUL|RAID')
            return 'Curse', 123, 3, 'Curse', 30, 130, 'party1', false, false, 99
        end,
    })

    local aura = p:GetAuraByIndex('target', 1, 'HARMFUL|RAID')
    assert(aura.name == 'Curse' and aura.applications == 3 and aura.dispelName == 'Curse')
    assert(aura.spellID == 99 and aura.sourceUnit == 'party1' and p:AuraRemaining(aura, 100) == 30)
end)

test('Era duration augmentation is optional and receives the actual filter', function()
    local calls = 0

    -- The library wraps the UnitAura global (Era's default loadDeprecationFallbacks=1).
    local p = fixture({
        WOW_PROJECT_CLASSIC = 2,
        WOW_PROJECT_ID = 2,
        UnitAura = function()
            error('read through the library')
        end,
        LibStub = function(name, silent)
            assert(name == 'LibClassicDurations' and silent == true)

            return {
                UnitAuraDirect = function(_, _, filter)
                    assert(filter == 'HARMFUL|RAID')
                    calls = calls + 1
                    return 'Curse', 1, 1, 'Curse', 30, 130, 'player', nil, nil, 99
                end,
            }
        end,
    })

    assert(p:GetAuraByIndex('target', 1, 'HARMFUL|RAID').expirationTime == 130 and calls == 1)

    p = fixture({
        WOW_PROJECT_CLASSIC = 2,
        WOW_PROJECT_ID = 2,
        LibStub = function() return nil end,
        C_UnitAuras = { GetAuraDataByIndex = function() return { name = 'Buff', spellId = 1 } end },
    })

    assert(p:GetAuraByIndex('player', 1, 'HELPFUL').name == 'Buff')
end)

test(
    'Era with loadDeprecationFallbacks off reads C_UnitAuras and never the library that wraps the missing UnitAura',
    function()
        local p = fixture({
            WOW_PROJECT_CLASSIC = 2,
            WOW_PROJECT_ID = 2,
            LibStub = function()
                -- The real library captured the missing UnitAura at load: every read fails.
                return {
                    UnitAuraDirect = function()
                        error("attempt to call upvalue 'UnitAura' (a nil value)")
                    end,
                }
            end,
            C_UnitAuras = {
                GetAuraDataByIndex = function(unit, index, filter)
                    assert(filter == 'HARMFUL')
                    return { name = 'Rend', spellId = 772, expirationTime = 130, duration = 15 }
                end,
            },
        })

        local aura = assert(p:GetAuraByIndex('target', 1, 'HARMFUL'))
        assert(aura.name == 'Rend' and aura.spellID == 772 and aura.expirationTime == 130)
    end
)

test('permanent auras remain infinite and expired auras clamp to zero', function()
    local p = fixture({ UnitAura = function() return 'Buff', 1, 0, nil, 0, 0, 'player', nil, nil, 1 end })
    local aura = p:GetAuraByIndex('player', 1, 'HELPFUL')
    assert(p:AuraRemaining(aura, 100) == math.huge)
    aura.duration = 10
    aura.expirationTime = 90
    assert(p:AuraRemaining(aura, 100) == 0)
    aura.expirationTime = nil
    local value, why = p:AuraRemaining(aura, 100)
    assert(value == nil and why == 'aura-time-unavailable')
end)

test('field-level restrictions preserve readable presence but never forge a duration', function()
    local opaque = setmetatable({}, {
        __tostring = function()
            error('opaque inspected')
        end,
    })

    for _, guard in ipairs({ 'issecretvalue', 'canaccessvalue' }) do
        local env = {
            C_UnitAuras = {
                GetAuraDataByIndex = function()
                    return {
                        name = 'Earth Shield',
                        spellId = 974,
                        duration = 600,
                        expirationTime = opaque,
                        applications = opaque,
                        sourceUnit = 'player',
                    }
                end,
            },
        }

        env[guard] = function(v)
            if guard == 'issecretvalue' then
                return rawequal(v, opaque)
            end

            return not rawequal(v, opaque)
        end

        local p = fixture(env)
        local aura = p:GetAuraByIndex('party1', 1, 'HELPFUL')
        assert(aura.name == 'Earth Shield' and aura.expirationTime == nil and aura.applications == nil)
        assert(p:ReadAuraField(aura, 'spellID') == 974)
        local value, why = p:AuraRemaining(aura, 100)
        assert(value == nil and why == 'restricted-value')
        value, why = p:ReadAuraField(aura, 'applications')
        assert(value == nil and why == 'restricted-value')
        env.C_UnitAuras.GetAuraDataByIndex = function() return opaque end
        value, why = p:GetAuraByIndex('party1', 1, 'HELPFUL')
        assert(value == nil and why == 'restricted-value')
    end
end)

test('nil ends enumeration while missing and rejected APIs remain unavailable', function()
    local p = fixture({ UnitAura = function() end })
    local aura, why = p:GetAuraByIndex('player', 1, 'HELPFUL')
    assert(aura == nil and why == nil)
    p = fixture()
    aura, why = p:GetAuraByIndex('player', 1, 'HELPFUL')
    assert(aura == nil and why == 'missing-api')

    p = fixture({
        C_UnitAuras = {
            GetAuraDataByIndex = function()
                error('access denied')
            end,
        },
        UnitAura = function()
            error('must not try fallback')
        end,
    })

    aura, why = p:GetAuraByIndex('player', 1, 'HELPFUL')
    assert(aura == nil and why == 'api-error')
    aura, why = p:GetAuraByIndex('player', 0, 'HELPFUL')
    assert(aura == nil and why == 'invalid-aura-query')
end)

test('aura polling does not collect build metadata for every aura index', function()
    local calls = 0

    local p = fixture({
        GetBuildInfo = function()
            calls = calls + 1
            return 'test', 'build', 'date', 20506
        end,
        UnitAura = function() return nil end,
    })

    for i = 1, 40 do
        p:GetAuraByIndex('player', i, 'HELPFUL')
    end

    assert(calls <= 1, 'repeated metadata reads in the recommendation loop')
end)

test('a readable expiration determines remaining time without a hidden duration', function()
    local opaque = {}

    local p = fixture({
        canaccessvalue = function(v) return not rawequal(v, opaque) end,
        C_UnitAuras = {
            GetAuraDataByIndex = function() return { name = 'Buff', duration = opaque, expirationTime = 125 } end,
        },
    })

    assert(p:AuraRemaining(p:GetAuraByIndex('player', 1, 'HELPFUL'), 100) == 25)
end)

finish()
