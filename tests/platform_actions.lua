-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local fixture = dofile('tests/fixtures/platform.lua')
local test, finish = F.suite()
local modules = { 'Platform/client.lua', 'Platform/spells.lua', 'Platform/actions.lua' }

test('modern usability preserves false power state and validates both booleans', function()
    local p, env = fixture({
        C_Spell = {
            IsSpellUsable = function(id)
                assert(id == 8042)
                return false, true
            end,
        },
    }, modules)

    local usable, power = p:IsSpellUsable(8042)
    assert(usable == false and power == true)
    env.C_Spell.IsSpellUsable = function() return true, false end
    usable, power = p:IsSpellUsable(8042)
    assert(usable == true and power == false)
    env.C_Spell.IsSpellUsable = function() return true, nil end
    local _, _, why = p:IsSpellUsable(8042)
    assert(why == 'invalid-api-result')
end)

test('modern exact-ID range distinguishes actual rangeless spells from invalid tests', function()
    local p, env = fixture({
        C_Spell = {
            SpellHasRange = function(id) return id ~= 324 end,
            IsSpellInRange = function(id, unit)
                assert(id == 8042 and unit == 'target')
                return false
            end,
        },
    }, modules)

    local range = p:GetSpellRangeState(8042, 'target', 'spell')
    assert(range.applicable and range.inRange == false)
    range = p:GetSpellRangeState(324, 'target', 'spell')
    assert(range.applicable == false)
    env.C_Spell.IsSpellInRange = function() return nil end
    local missing, why = p:GetSpellRangeState(8042, 'target', 'spell')
    assert(missing == nil and why == 'invalid-range-check')
end)

test('legacy range uses exact ranked spellbook slots and separate pet bank', function()
    local slots = {}

    local p, env = fixture({
        BOOKTYPE_SPELL = 'spell',
        BOOKTYPE_PET = 'pet',
        FindSpellBookSlotBySpellID = function(id, pet)
            slots[#slots + 1] = { id, pet }
            return pet and 2 or 17
        end,
        SpellHasRange = function(slot, bank)
            assert(slot == (bank == 'pet' and 2 or 17))
            return true
        end,
        IsSpellInRange = function(slot, bank, unit)
            assert(unit == 'target')
            return bank == 'pet' and 1 or 0
        end,
        IsUsableSpell = function() return true, false end,
    }, modules)

    local range = p:GetSpellRangeState(8042, 'target', 'spell')
    assert(range.inRange == false and slots[1][1] == 8042 and slots[1][2] == false)
    range = p:GetSpellRangeState(974, 'target', 'pet')
    assert(range.inRange == true and slots[2][2] == true)
    local usable, power = p:IsSpellUsable(8042)
    assert(usable and power == false)

    env.FindSpellBookSlotBySpellID = function(_, pet)
        assert(pet == false or pet == true)

        if pet then
            return 2
        end
    end

    assert(p:GetSpellRangeState(974, 'target', 'any').inRange)
end)

test('restricted or failed native observations never use legacy fallback', function()
    local opaque = {}

    local p, env = fixture({
        canaccessvalue = function(v) return not rawequal(v, opaque) end,
        C_Spell = { IsSpellUsable = function() return opaque, false end, SpellHasRange = function() return opaque end },
        IsUsableSpell = function()
            error('legacy fallback')
        end,
        IsSpellInRange = function()
            error('legacy fallback')
        end,
    }, modules)

    local _, _, why = p:IsSpellUsable(8042)
    assert(why == 'restricted-value')
    local missing, reason = p:GetSpellRangeState(8042, 'target', 'spell')
    assert(not missing and reason == 'restricted-value')
    env.C_Spell.SpellHasRange = function() return true end

    env.C_Spell.IsSpellInRange = function()
        error('native error')
    end

    missing, reason = p:GetSpellRangeState(8042, 'target', 'spell')
    assert(not missing and reason == 'api-error')
end)

test('absent range-shape API allows valid range tests but never turns nil into in-range', function()
    local p, env = fixture({ C_Spell = { IsSpellInRange = function() return true end } }, modules)
    assert(p:GetSpellRangeState(403, 'target', 'spell').inRange)
    env.C_Spell.IsSpellInRange = function() return nil end
    local state, why = p:GetSpellRangeState(403, 'target', 'spell')
    assert(not state and why == 'invalid-range-check')
    env.C_Spell = nil
    state, why = p:GetSpellRangeState(403, 'target', 'spell')
    assert(not state and why == 'missing-api')
end)

test('malformed present legacy range shape and restricted slots stay unavailable', function()
    local opaque = {}

    local p, env = fixture({
        canaccessvalue = function(v) return not rawequal(v, opaque) end,
        FindSpellBookSlotBySpellID = function() return 2 end,
        SpellHasRange = function() return nil end,
        IsSpellInRange = function() return 1 end,
    }, modules)

    local state, why = p:GetSpellRangeState(403, 'target', 'spell')
    assert(not state and why == 'invalid-api-result')
    env.FindSpellBookSlotBySpellID = function() return opaque end
    state, why = p:GetSpellRangeState(403, 'target', 'pet')
    assert(not state and why == 'restricted-value')
end)

test(
    'pass reader checks inputs before cache keys and shares native identities without admitting invalid banks',
    function()
        local opaque = {}
        local calls = 0

        local p = fixture({
            canaccessvalue = function(v) return not rawequal(v, opaque) end,
            C_Spell = {
                IsSpellInRange = function()
                    calls = calls + 1
                    return true
                end,
            },
        }, modules)

        local read = p:NewSpellRangeReader()
        assert(read(403, 'target', 'spell').inRange and read(403, 'target', 'any').inRange and calls == 1)
        local state, why = read(403, 'target', 'bad')
        assert(not state and why == 'invalid-spell-bank')
        state, why = read(opaque, 'target', 'spell')
        assert(not state and why == 'restricted-value')
        state, why = read(403, opaque, 'spell')
        assert(not state and why == 'restricted-value')
    end
)

finish()
