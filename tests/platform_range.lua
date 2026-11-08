-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local fixture = dofile('tests/fixtures/platform.lua')
local test, finish = F.suite()
local modules = { 'Platform/client.lua', 'Platform/spells.lua', 'Platform/range.lua' }

test('native attack range uses normalized booleans and legacy numeric results', function()
    local result = true

    local p = fixture({
        C_Spell = {
            IsSpellInRange = function(id, unit)
                assert(id == 6603 and unit == 'target')
                return result
            end,
        },
        LibStub = function()
            error('must not use an estimate after a native result')
        end,
    }, modules)

    assert(p:IsBeyondMeleeRange('target') == false)
    result = false
    assert(p:IsBeyondMeleeRange('target') == true)

    p = fixture({
        GetSpellInfo = function(id)
            assert(id == 6603)
            return 'Localized Attack', nil, 123, nil, nil, nil, 6603
        end,
        IsSpellInRange = function(name, unit)
            assert(name == 'Localized Attack' and unit == 'target')
            return 0
        end,
    }, modules)

    assert(p:IsBeyondMeleeRange('target') == true)
end)

test('interval estimates distinguish known close, known beyond and uncertainty', function()
    local low, high = 0, 5

    local p = fixture({
        C_Spell = { IsSpellInRange = function() return nil end },
        LibStub = function()
            return {
                GetRange = function(_, unit, visible)
                    assert(unit == 'target' and visible)
                    return low, high
                end,
            }
        end,
    }, modules)

    assert(p:IsBeyondMeleeRange('target') == false)
    low, high = 5, 8
    assert(p:IsBeyondMeleeRange('target') == true)
    high = nil
    assert(p:IsBeyondMeleeRange('target') == true)
    low, high = 0, 8
    local beyond, why = p:IsBeyondMeleeRange('target')
    assert(beyond == nil and why == 'range-uncertain')
    low, high = nil, nil
    beyond, why = p:IsBeyondMeleeRange('target')
    assert(beyond == nil and why == 'range-unavailable')
end)

test('restricted or failed native checks never fall through to an estimate', function()
    local opaque = {}

    local p = fixture({
        C_Spell = { IsSpellInRange = function() return opaque end },
        canaccessvalue = function(v) return not rawequal(v, opaque) end,
        LibStub = function()
            error('restricted result fell through')
        end,
    }, modules)

    local result, why = p:IsBeyondMeleeRange('target')
    assert(result == nil and why == 'restricted-value')

    p = fixture({
        C_Spell = {
            IsSpellInRange = function()
                error('blocked')
            end,
        },
        LibStub = function()
            error('failed result fell through')
        end,
    }, modules)

    result, why = p:IsBeyondMeleeRange('target')
    assert(result == nil and why == 'api-error')
end)

test('beyond-melee condition preserves unavailable estimates under NOT', function()
    local f = F.new()
    f.env.UnitExists = function() return true end
    f.load('Platform/client.lua')
    f.load('Platform/spells.lua')
    f.load('Platform/range.lua')
    f.load('Core/conditions.lua')
    f.load('Conditions/range.lua')
    local value = { type = 'NOT', value = { type = 'BEYOND_MELEE', unit = 'target' } }
    assert(f.addon:evaluateConditionResult(value).status == 'unavailable')
    f.env.C_Spell = { IsSpellInRange = function() return false end }
    assert(not f.addon:evaluateCondition(value))
end)

test('an open-ended or absent LibRangeCheck answer falls back to the ranges of the spells on the bars', function()
    local answer = { 100, nil }
    local provider = { GetRange = function() return answer[1], answer[2] end }
    local p, _, addon = fixture({ LibStub = function() return provider end }, modules)
    local ranges = { [1] = { max = 5 }, [2] = { max = 30 }, [3] = { max = 40 }, [4] = { max = 35, min = 8 } }
    local inRange = { [1] = false, [2] = true, [3] = true, [4] = true }
    addon.GetBarSpellIds = function() return { 1, 2, 3, 4 } end
    p.GetSpellInfo = function(_, id) return { name = 'S', maxRange = ranges[id].max, minRange = ranges[id].min } end
    p.GetSpellRangeState = function(_, id) return { applicable = true, inRange = inRange[id] } end
    local bounds = p:GetRangeCheckBounds('target')
    assert(bounds.source == 'spells' and bounds.minimum == 8 and bounds.maximum == 30, 'spell bracket')
    answer = { nil, nil }
    assert(p:GetRangeCheckBounds('target').source == 'spells', 'absent answer')
    answer = { 5, 10 }
    bounds = p:GetRangeCheckBounds('target')

    assert(
        bounds.source == nil and bounds.minimum == 5 and bounds.maximum == 10,
        'a closed LibRangeCheck answer is kept'
    )

    answer = { 100, nil }
    addon.GetBarSpellIds = function() return {} end
    bounds = p:GetRangeCheckBounds('target')
    assert(bounds.minimum == 100 and bounds.maximum == nil, 'no spell answer keeps LibRangeCheck')
end)

finish()
