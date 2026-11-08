-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- BOSS, ELITE and CASTING_ANY: a boss is a boss mob, a World Boss or a skull-level elite; elite is Elite, Rare Elite or
-- World Boss; casting or channeling ignores which spell, so a hidden cast still counts. Missing units are false and
-- unreadable values unavailable, also under NOT.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local SECRET = setmetatable({}, { __tostring = function() return 'secret' end })

local function fixture(project, expansion, options)
    options = options or {}
    local f = F.new(project or 18, expansion or 12)
    local a, e = f.addon, f.env
    local s = { exists = true, classification = 'elite', level = 60, boss = false, cast = nil, channel = nil }

    e.UnitExists = function() return s.exists end
    e.UnitClassification = function() return s.classification end
    e.UnitLevel = function() return s.level end
    e.UnitIsBossMob = options.noBossMob and nil or function() return s.boss end
    e.UnitCastingInfo = function() return s.cast, 'display', 1, 99000, 103000, false, 'guid', false, 5143 end
    e.UnitChannelInfo = function() return s.channel, 'display', 1, 99000, 103000, false, false, 5143, false, 0 end

    for _, file in ipairs({
        'Platform/casting.lua', 'Platform/unit_rank.lua', 'Diagnostics/errors.lua', 'Core/conditions.lua',
        'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua', 'Core/rotation_sequence.lua',
        'Conditions/unit_rank.lua'
    }) do
        f.load(file)
    end

    local readable = a.Platform.CanReadValue

    a.Platform.CanReadValue = function(platform, value)
        if value == SECRET then
            return false
        end

        return readable(platform, value)
    end

    return f, a, s
end

local function status(a, tag, unit)
    return a:evaluateConditionResult({ type = tag, unit = unit or 'target' }).status
end

local function negated(a, tag)
    return a:evaluateConditionResult({ type = 'NOT', value = { type = tag, unit = 'target' } }).status
end

test('BOSS matches a boss mob, a World Boss or a skull-level elite, and nothing else', function()
    local _, a, s = fixture()
    assert(status(a, 'BOSS') == 'no-match', 'a plain elite is not a boss')
    s.boss = true
    assert(status(a, 'BOSS') == 'match', 'UnitIsBossMob')
    s.boss, s.classification = false, 'worldboss'
    assert(status(a, 'BOSS') == 'match', 'World Boss')
    s.classification, s.level = 'elite', -1
    assert(status(a, 'BOSS') == 'match', 'skull-level elite')
    s.classification = 'normal'
    assert(status(a, 'BOSS') == 'no-match', 'a skull-level normal mob is not a boss')
    s.classification, s.level, s.boss = 'elite', 60, SECRET
    assert(status(a, 'BOSS') == 'no-match', 'a hidden boss flag falls back to the classification')
end)

test('BOSS without UnitIsBossMob uses the classification and level only', function()
    local _, a, s = fixture(2, 0, { noBossMob = true })
    assert(status(a, 'BOSS') == 'no-match', 'a plain elite')
    s.level = -1
    assert(status(a, 'BOSS') == 'match', 'skull-level elite')
    s.level, s.classification = 60, 'worldboss'
    assert(status(a, 'BOSS') == 'match', 'World Boss')
end)

test('ELITE matches Elite, Rare Elite and World Boss', function()
    local _, a, s = fixture()

    for classification, expected in pairs({
        elite = 'match',
        rareelite = 'match',
        worldboss = 'match',
        rare = 'no-match',
        normal = 'no-match',
        trivial = 'no-match',
        minus = 'no-match',
    }) do
        s.classification = classification
        assert(status(a, 'ELITE') == expected, classification)
    end
end)

test('a missing unit is false and an unreadable classification is unavailable, also under NOT', function()
    for _, tag in ipairs({ 'BOSS', 'ELITE' }) do
        local _, a, s = fixture()
        s.exists = false
        assert(status(a, tag) == 'no-match' and negated(a, tag) == 'match', tag .. ' missing unit')
        s.exists, s.classification = true, SECRET
        assert(status(a, tag) == 'unavailable' and negated(a, tag) == 'unavailable', tag .. ' secret')
        s.classification = nil
        assert(status(a, tag) == 'unavailable', tag .. ' nil classification')
    end
end)

test('CASTING_ANY matches a cast or a channel, including a hidden spell', function()
    local _, a, s = fixture()
    assert(status(a, 'CASTING_ANY') == 'no-match' and negated(a, 'CASTING_ANY') == 'match')
    s.cast = 'Frostbolt'
    assert(status(a, 'CASTING_ANY') == 'match', 'cast')
    s.cast, s.channel = nil, 'Arcane Missiles'
    assert(status(a, 'CASTING_ANY') == 'match', 'channel')
    s.channel, s.cast = nil, SECRET
    assert(status(a, 'CASTING_ANY') == 'match', 'a hidden cast is still a cast')
    s.cast = nil
    s.exists = false
    assert(status(a, 'CASTING_ANY') == 'no-match', 'missing unit')
end)

test('help and summaries render', function()
    local _, a = fixture()

    for _, tag in ipairs({ 'BOSS', 'ELITE', 'CASTING_ANY' }) do
        local definition = a.conditionDefinitions[tag]
        assert(definition and definition.valid(0, { unit = 'target' }) and not definition.valid(0, {}), tag)
        assert(tag == 'CASTING_ANY' or not definition.valid(0, { unit = 'player' }), tag .. ' accepted you')
        assert(type(definition.print(0, { unit = 'target' })) == 'string', tag)
        local frame = { children = {} }

        function frame:AddChild(child)
            self.children[#self.children + 1] = child
        end

        a.layout_condition_unitwidget_help = a.layout_condition_unitwidget_help or function() end
        a.help_funcs.CreateText = a.help_funcs.CreateText or function(text) return { text = text } end
        definition.help(frame)
        assert(#frame.children >= 1, tag .. ' help')
    end
end)

finish()
