-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- SPELL_USABLE: the game's own usable answer (which includes reactive requirements such as Execute range), or only
-- whether the cost is covered; an unreadable answer is unavailable, also under NOT.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local SECRET = {}

local function fixture(project)
    local f = F.new(project or 18, 12)
    local a, e = f.addon, f.env
    local s = { usable = true, power = false, calls = 0 }

    e.C_Spell = e.C_Spell or {}

    e.C_Spell.IsSpellUsable = function(id)
        assert(id == 5308)
        s.calls = s.calls + 1
        return s.usable, s.power
    end

    for _, file in ipairs({
        'Platform/actions.lua',
        'Diagnostics/errors.lua',
        'Core/conditions.lua',
        'Data/plain.lua',
        'Data/tags.lua',
        'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua',
        'Conditions/spell_usable.lua',
    }) do
        f.load(file)
    end

    a.Widget_GetSpellId = function(_, spell) return spell end
    a.IsConditionSpellID = a.IsConditionSpellID or function(id) return type(id) == 'number' end
    local readable = a.Platform.CanReadValue

    a.Platform.CanReadValue = function(platform, value)
        if value == SECRET then
            return false
        end

        return readable(platform, value)
    end

    return f, a, s
end

local function status(a, check)
    return a:evaluateConditionResult({ type = 'SPELL_USABLE', spell = 5308, check = check }).status
end

test('usable now follows the game, including a reactive requirement such as Execute range', function()
    local _, a, s = fixture()
    assert(status(a) == 'match' and status(a, 'usable') == 'match')
    s.usable, s.power = false, false
    assert(status(a) == 'no-match', 'target above the Execute threshold')
    s.usable, s.power = false, true
    assert(status(a) == 'no-match', 'lacking resources')
end)

test('enough resources is only the cost', function()
    local _, a, s = fixture()
    s.usable, s.power = false, false
    assert(status(a, 'affordable') == 'match', 'affordable while not usable for another reason')
    s.power = true
    assert(status(a, 'affordable') == 'no-match')
end)

test('an unreadable answer is unavailable, also under NOT', function()
    local _, a, s = fixture()
    s.usable = SECRET
    assert(status(a) == 'unavailable' and status(a, 'affordable') == 'unavailable')

    assert(
        a:evaluateConditionResult({
            type = 'NOT',
            value = { type = 'SPELL_USABLE', spell = 5308 },
        }).status == 'unavailable'
    )
end)

test('one game query per spell per evaluation', function()
    local _, a, s = fixture()
    local cache = {}
    a.conditionDefinitions.SPELL_USABLE.evaluate({ spell = 5308 }, cache)
    a.conditionDefinitions.SPELL_USABLE.evaluate({ spell = 5308, check = 'affordable' }, cache)
    assert(s.calls == 1, 'queried ' .. s.calls .. ' times')
end)

test('validation and summaries', function()
    local _, a = fixture()
    local definition = a.conditionDefinitions.SPELL_USABLE
    assert(definition.valid(0, { spell = 5308 }) and definition.valid(0, { spell = 5308, check = 'affordable' }))
    assert(not definition.valid(0, { spell = 5308, check = 'other' }) and not definition.valid(0, {}))
    a.Widget_GetSpellLink = function() return 'Execute' end
    assert(definition.print(0, { spell = 5308 }):find('usable', 1, true))
    assert(definition.print(0, { spell = 5308, check = 'affordable' }):find('resources', 1, true))
end)

finish()
