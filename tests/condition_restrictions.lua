-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Where the game hides a condition's data: on Retail and Forever each listed condition names the situations from
-- Blizzard's secret predicates (combat and encounters, a unit that is not you, dungeons and raids), refined per spell by
-- C_Secrets; clients without secret values have no notes.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local corpus = dofile('tests/fixtures/default_corpus.lua')

local function client(project, expansion)
    local f = corpus.load(project, expansion, 'ROGUE', { modules = false })
    f.load('Core/condition_support.lua')
    f.load('Core/condition_restrictions.lua')
    return f, f.addon
end

local restricted = { { 1, 12, 'Retail' }, { 18, 12, 'Forever' } }

local function has(notes, key)
    for _, note in ipairs(notes or {}) do
        if note == key then
            return true
        end
    end
end

test('aura and cooldown conditions are hidden in combat, encounters, Mythic+ and PvP', function()
    for _, c in ipairs(restricted) do
        local _, a = client(c[1], c[2])

        for _, tag in ipairs({ 'BUFF', 'DEBUFF_REMAIN', 'SPELL_COOLDOWN', 'TOTEM' }) do
            local notes = a:GetConditionRestrictions(tag, { unit = 'player', spell = 'Name only' })
            assert(has(notes, 'restricted'), c[3] .. ' ' .. tag)
        end

        local text = a:DescribeConditionRestrictions('BUFF', { unit = 'target', spell = 'Name only' })
        assert(text and text:find('boss encounters', 1, true) and text:find('unavailable', 1, true), c[3])
    end
end)

test('unit-bound notes apply to other units only', function()
    for _, c in ipairs(restricted) do
        local _, a = client(c[1], c[2])
        assert(has(a:GetConditionRestrictions('CASTING_SPELL', { unit = 'target' }), 'cast'), c[3])
        assert(a:GetConditionRestrictions('CASTING_SPELL', { unit = 'player' }) == nil, c[3])
        assert(a:GetConditionRestrictions('CASTING_SPELL', { unit = 'pet' }) == nil, c[3])
        assert(has(a:GetConditionRestrictions('CLASS', { unit = 'target' }), 'identity'), c[3])
        assert(a:GetConditionRestrictions('CLASS', { unit = 'player' }) == nil, c[3])
        assert(has(a:GetConditionRestrictions('ISSAME', { unit = 'target', otherunit = 'player' }), 'map'), c[3])
        assert(has(a:GetConditionRestrictions('STAT', { unit = 'player' }), 'combat'), c[3])
        assert(a:GetConditionRestrictions('MOVING', {}) == nil, c[3] .. ' MOVING follows the movement events')
    end
end)

test('a spell the game flags never or always secret refines the note', function()
    local f, a = client(18, 12)
    local level = {}

    f.env.C_Secrets = f.env.C_Secrets or {}
    f.env.C_Secrets.GetSpellAuraSecrecy = function(spell) return level[spell] end
    level[100], level[200], level[300] = 0, 1, 2
    assert(a:GetConditionRestrictions('BUFF', { unit = 'player', spell = 100 }) == nil, 'never secret kept a note')
    local always = a:GetConditionRestrictions('BUFF', { unit = 'player', spell = 200 })
    assert(#always == 1 and always[1] == 'always', 'always secret')
    assert(has(a:GetConditionRestrictions('BUFF', { unit = 'player', spell = 300 }), 'restricted'), 'contextual')
    assert(has(a:GetConditionRestrictions('BUFF', { unit = 'player', spell = 400 }), 'restricted'), 'unknown level')
end)

test('conditions the game never hides, and clients without secrets, have no notes', function()
    local _, a = client(18, 12)

    for _, tag in ipairs({ 'COMBAT', 'SPELL_AVAIL', 'CASTING', 'CLASSIFICATION', 'ENCOUNTER' }) do
        assert(a:GetConditionRestrictions(tag, { unit = 'target' }) == nil, tag)
        assert(a:DescribeConditionRestrictions(tag, { unit = 'target' }) == nil, tag)
    end

    for _, c in ipairs({ { 2, 0 }, { 5, 1 }, { 19, 4 } }) do
        local _, era = client(c[1], c[2])
        assert(era:GetConditionRestrictions('BUFF', { unit = 'target' }) == nil, 'project ' .. c[1])
    end
end)

test('every listed condition is a Built In condition', function()
    local _, a = client(18, 12)

    for tag in pairs(a.conditionRestrictions) do
        assert(a.conditionRequirements[tag], tag .. ' is not a Built In condition')
    end
end)

finish()
