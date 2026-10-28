-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Talent tree names (Data/talent_trees.lua): every place a tree is shown names it,
-- for the class the rotation is for, and the shipped table agrees with the Built Ins.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local corpus = dofile('tests/fixtures/default_corpus.lua')

local function read(path)
    local h = assert(io.open(path, 'rb'))
    local s = h:read('*a')
    h:close()
    return s
end

local enUS = dofile('tests/fixtures/locale_entries.lua').english()

local function lookup(project, expansion, class)
    local f = F.new(project, expansion, class)
    f.load('Platform/talents.lua')
    return f
end

local function data()
    return lookup(2, 0, 'SHAMAN').addon.TalentTrees.data
end

local FAMILIES = { era = { 2, 0 }, tbc = { 5, 1 }, wrath = { 11, 2 }, cata = { 14, 3 }, forever = { 18, 12 } }

test('every family lists three distinct trees per class, each with a locale key', function()
    local d = data()
    assert(d.version == 1 and #d.familyOrder == 5)

    for _, key in ipairs(d.familyOrder) do
        local row = assert(d.families[key], key)
        local classes = 0
        assert(type(row.label) == 'string' and type(row.basis) == 'string')

        for class, names in pairs(row.classes) do
            classes = classes + 1
            assert(#names == 3, key .. ' ' .. class)
            local seen = {}

            for _, name in ipairs(names) do
                assert(not seen[name], key .. ' ' .. class .. ' repeats ' .. name)
                seen[name] = true
                assert(enUS['TalentTree.' .. name] == name, 'no locale key for tree name ' .. name)
            end
        end

        assert(
            classes == (key == 'wrath' and 10 or key == 'cata' and 10 or 9),
            key .. ' covers ' .. classes .. ' classes'
        )
    end

    assert(not d.families.era.classes.DEATHKNIGHT and d.families.wrath.classes.DEATHKNIGHT[2] == 'Frost')
end)

-- The SPECIALIZATION condition maps a specialization to its tree on these clients; it must agree.
test('the specialization table and the tree table agree on which tree is which', function()
    local source = read('Conditions/specialization.lua')
    local families = data().families
    local seen = 0

    for class, tree, name in source:gmatch('%[%d+%]%s*=%s*{%s*"(%u+)",%s*(%d+),%s*"([%a ]+)"%s*}') do
        tree = tonumber(tree)
        local listed = families.wrath.classes[class]
        assert(listed, class)
        seen = seen + 1
        local want = listed[tree]

        assert(
            want == name
                or class == 'DRUID'
                    and tree == 2
                    and want == 'Feral Combat'
                    and (name == 'Feral' or name == 'Guardian'),
            class .. ' tree ' .. tree .. ': specialization says ' .. name .. ', tree table says ' .. tostring(want)
        )
    end

    assert(seen == 31, 'expected the 31 talent-tree specializations (Druid has four), found ' .. seen)
end)

-- The Built In premades say which tree they are for (their id's role) and carry the
-- tree's number in their conditions; the number must name that tree.
local ROLE_TREES = { ['PRIEST.healer'] = { 'Discipline', 'Holy' }, ['PALADIN.shockadin'] = { 'Holy' } }

local function indexOf(names, wanted)
    for i, name in ipairs(names) do
        if name == wanted then
            return i
        end
    end
end

local function impliedTrees(class, role, names)
    local wanted = ROLE_TREES[class .. '.' .. role]

    if wanted then
        local set = {}

        for _, name in ipairs(wanted) do
            set[assert(indexOf(names, name), name)] = true
        end

        return set
    end

    for i, name in ipairs(names) do
        local plain = name:lower():gsub('%s', '')

        if plain == role or plain:sub(1, #role) == role and #role >= 4 then
            return { [i] = true }
        end
    end
end

local function trees(condition, found, negated)
    if type(condition) ~= 'table' then
        return
    end
    if condition.type == 'NOT' then
        return trees(condition.value, found, not negated)
    end

    if condition.type == 'PRIMARY_TALENT_TREE' then
        found.primary[#found.primary + 1] = { tree = condition.tree, negated = negated }
    end

    if type(condition.value) == 'table' then
        for _, child in ipairs(condition.value) do
            trees(child, found, negated)
        end
    end
end

local function everyTree(value, out, seen)
    if type(value) ~= 'table' or seen[value] then
        return
    end

    seen[value] = true

    if
        (value.type == 'PRIMARY_TALENT_TREE' or value.type == 'TALENT_TREE_POINTS' or value.type == 'TALENT')
        and type(value.tree) == 'number'
    then
        out[#out + 1] = value.tree
    end

    for _, child in pairs(value) do
        everyTree(child, out, seen)
    end
end

-- Returns the problems with one pack (a list of strings), given the family table.
local function problems(pack, families)
    local out = {}
    local scope = pack.applicability
    local family = scope.families and scope.families[1]
    local row = families[family]

    if not row then  -- retail, Mists: no tree conditions
        return out
    end

    local names = row.classes[scope.class]
    local used = {}
    everyTree(pack.body, used, {})

    if #used > 0 and not names then
        out[#out + 1] = pack.id .. ': tree conditions for a class the ' .. family .. ' table does not list'
        return out
    end

    for _, tree in ipairs(used) do
        if not names[tree] then
            out[#out + 1] = pack.id .. ': tree ' .. tree .. ' is not one of ' .. scope.class .. '\'s trees'
        end
    end

    local found = { primary = {} }
    trees(pack.body.switch, found, false)
    local positive = {}

    for _, entry in ipairs(found.primary) do
        if not entry.negated then
            positive[#positive + 1] = entry.tree
        end
    end

    if #positive == 0 then
        return out
    end

    local role = pack.id:match('^rm%.%a+%.%a+%.(%a+)')
    local implied = impliedTrees(scope.class, role, names)

    if not implied then
        out[#out + 1] = pack.id
            .. ': switches on a primary tree but its role "'
            .. tostring(role)
            .. '" names none (add it to ROLE_TREES)'

        return out
    end

    for _, tree in ipairs(positive) do
        if not implied[tree] then
            out[#out + 1] = pack.id
                .. ': switch uses tree '
                .. tree
                .. ' ('
                .. names[tree]
                .. ') but the premade is for '
                .. role
        end
    end

    return out
end

test('every Built In premade names the tree its number says', function()
    local _, packs = corpus.load(2, 0, 'SHAMAN')
    local d = data()
    local checked, named = 0, 0

    for _, pack in ipairs(packs) do
        local list = problems(pack, d.families)
        assert(#list == 0, table.concat(list, '; '))
        local found = { primary = {} }
        trees(pack.body.switch, found, false)

        if #found.primary > 0 then
            named = named + 1
        end

        checked = checked + 1
    end

    assert(
        checked > 100 and named > 40,
        'the corpus did not load (' .. checked .. ' packs, ' .. named .. ' switching on a tree)'
    )
end)

test('a premade whose tree number names another tree is caught', function()
    local d = data()

    local function pack(id, class, family, switch, body)
        return {
            id = id,
            applicability = { class = class, families = { family } },
            body = body or { switch = switch, rotation = {}, cooldowns = {} },
        }
    end

    local good = pack('rm.era.shaman.elemental', 'SHAMAN', 'era', {
        type = 'AND',
        value = { { type = 'PRIMARY_TALENT_TREE', tree = 1 } },
    })

    assert(#problems(good, d.families) == 0)

    local wrong = pack('rm.era.shaman.elemental', 'SHAMAN', 'era', {
        type = 'AND',
        value = { { type = 'PRIMARY_TALENT_TREE', tree = 2 } },
    })

    assert(#problems(wrong, d.families) == 1, 'Elemental premade on the Enhancement tree went unnoticed')
    local swapped = pack('rm.era.druid.feral', 'DRUID', 'era', { type = 'PRIMARY_TALENT_TREE', tree = 3 })
    assert(#problems(swapped, d.families) == 1, 'Feral premade on the Restoration tree went unnoticed')

    local outside = pack('rm.tbc.mage.fire', 'MAGE', 'tbc', { type = 'PRIMARY_TALENT_TREE', tree = 2 }, {
        switch = { type = 'PRIMARY_TALENT_TREE', tree = 2 },
        rotation = { { conditions = { type = 'TALENT_TREE_POINTS', tree = 4 } } },
        cooldowns = {},
    })

    assert(#problems(outside, d.families) == 1, 'a fourth tree went unnoticed')

    local negated = pack('rm.era.shaman.elemental', 'SHAMAN', 'era', {
        type = 'NOT',
        value = { type = 'PRIMARY_TALENT_TREE', tree = 3 },
    })

    assert(#problems(negated, d.families) == 0, 'excluding another tree is not a claim about this one')
    local unknown = pack('rm.era.shaman.tank', 'SHAMAN', 'era', { type = 'PRIMARY_TALENT_TREE', tree = 2 })
    assert(#problems(unknown, d.families) == 1, 'a role that names no tree was accepted')
    local reordered = data()
    reordered.families.era.classes.SHAMAN = { 'Enhancement', 'Elemental', 'Restoration' }
    assert(#problems(good, reordered.families) == 1, 'a reordered table went unnoticed')
end)

local function live(f, names)
    local e = f.env
    e.GetNumTalentTabs = function() return #names end
    e.GetNumTalents = function() return 2 end

    e.C_SpecializationInfo = {
        GetSpecializationInfo = function(tree) return tree, names[tree], 'Description', tree, nil, nil, tree * 3 end,
        GetTalentInfo = function()
            return {
                name = 'Convection',
                icon = 1,
                rank = 1,
                maxRank = 5,
                talentID = 101,
                spellID = 108269,
                tier = 1,
                column = 2,
                selected = true,
                available = true,
                known = true,
            }
        end,
    }
end

local function fixture(project, expansion, class)
    local f = F.new(project, expansion, class)

    for _, path in ipairs({
        'Platform/talents.lua',
        'Core/conditions.lua',
        'Conditions/common.lua',
        'Conditions/character.lua',
        'Conditions/talent.lua',
    }) do
        f.load(path)
    end

    return f
end

local function inRotationFor(f, class)
    f.addon.activeRotationEditor = class and { workspace = { RotationClass = function() return class end } } or nil
end

local function field(parent, label)
    for _, w in ipairs(parent.children) do
        if (w.caption and w.caption:GetText() or w.label) == label then
            return w
        end

        if w.children then
            local inner = field(w, label)

            if inner then
                return inner
            end
        end
    end
end

local function widget(f, tag, value)
    local parent, top = f.widget('parent'), f.widget('top')
    top:SetUserData('root', value)
    top:SetUserData('funcs', { print = function() return 'Updated' end })
    parent:SetUserData('top', top)
    f.addon.conditionDefinitions[tag].widget(parent, 0, value)
    return parent
end

local function listed(picker)
    picker.configure()
    local names = {}

    for _, index in ipairs(picker.order) do
        names[#names + 1] = picker.list[index]
    end

    return table.concat(names, '/')
end

test('your own class is named by the game, in the game language, and by the table when the game cannot', function()
    local f = fixture(2, 0, 'SHAMAN')
    local Trees = f.addon.TalentTrees
    assert(Trees.Family() == 'era' and Trees.PlayerClass() == 'SHAMAN')
    live(f, { 'Élémentaire', 'Amélioration', 'Restauration' })
    local choice = Trees.Choices('SHAMAN')
    assert(choice.live and choice.choices[1] == 'Élémentaire' and choice.choices[3] == 'Restauration')
    assert(Trees.Name(2, 'SHAMAN') == 'Amélioration')

    -- The game answers for two trees only: the third comes from the table.
    f.env.C_SpecializationInfo.GetSpecializationInfo = function(tree)
        if tree < 3 then
            return tree, 'Tree ' .. tree, '', tree, nil, nil, 0
        end
    end

    f.env.GetNumTalentTabs = function() return 3 end
    assert(Trees.Choices('SHAMAN').choices[3] == 'Restoration' and Trees.Choices('SHAMAN').choices[1] == 'Tree 1')
    -- No talent data yet (a fresh login): the table names all three.
    f.env.GetNumTalentTabs = function() return 0 end
    f.env.C_SpecializationInfo = nil
    f.env.GetTalentTabInfo = nil
    local early = Trees.Choices('SHAMAN')

    assert(
        not early.live and early.choices[1] == 'Elemental' and early.choices[2] == 'Enhancement' and #early.order == 3
    )

    f.env.GetNumTalentTabs = nil
    assert(Trees.Choices('SHAMAN').choices[3] == 'Restoration' and Trees.Name(1) == 'Elemental')
end)

test('another class is named by the table, never by the player\'s own trees', function()
    local f = fixture(2, 0, 'SHAMAN')
    local Trees = f.addon.TalentTrees
    live(f, { 'Elemental', 'Enhancement', 'Restoration' })
    local warrior = Trees.Choices('WARRIOR')

    assert(
        not warrior.live
            and warrior.choices[1] == 'Arms'
            and warrior.choices[2] == 'Fury'
            and warrior.choices[3] == 'Protection'
    )

    assert(
        Trees.Name(2, 'WARRIOR') == 'Fury'
            and Trees.Name(2, 'DRUID') == 'Feral Combat'
            and Trees.Name(1, 'ROGUE') == 'Assassination'
    )

    assert(
        Trees.Name(4, 'WARRIOR') == nil
            and Trees.Name(0, 'WARRIOR') == nil
            and Trees.Name(1.5, 'WARRIOR') == nil
            and Trees.Name(1, 'DEATHKNIGHT') == nil
    )

    assert(Trees.Choices('DEATHKNIGHT') == nil, 'Era has no Death Knight')

    for family, client in pairs(FAMILIES) do
        local g = lookup(client[1], client[2], 'SHAMAN')
        assert(g.addon.TalentTrees.Family() == family, family)

        assert(
            g.addon.TalentTrees.Names('SHAMAN')[1] == 'Elemental'
                and g.addon.TalentTrees.Choices('WARRIOR').choices[3] == 'Protection',
            family
        )

        assert((g.addon.TalentTrees.Names('DEATHKNIGHT') ~= nil) == (family == 'wrath' or family == 'cata'), family)
    end

    for _, client in ipairs({ { 1, 12 }, { 19, 4 } }) do
        local g = lookup(client[1], client[2], 'SHAMAN')
        assert(g.addon.TalentTrees.Family() == nil and g.addon.TalentTrees.Choices('SHAMAN') == nil)
    end
end)

test('the tree pickers list the names of the rotation\'s class and summaries use them', function()
    local f = fixture(2, 0, 'SHAMAN')
    live(f, { 'Elemental', 'Enhancement', 'Restoration' })

    for _, tag in ipairs({ 'PRIMARY_TALENT_TREE', 'TALENT_TREE_POINTS' }) do
        local value = tag == 'PRIMARY_TALENT_TREE' and { type = tag, tree = 2 } or {
            type = tag,
            tree = 2,
            operator = 'GREATERTHAN',
            value = 5,
        }

        local picker = widget(f, tag, value).children[1]
        assert(listed(picker) == 'Elemental/Enhancement/Restoration', tag)
        assert(f.addon.conditionDefinitions[tag].print(0, value):find('Enhancement', 1, true), tag)
        -- A Warrior rotation opened on a Shaman: Warrior trees, whatever the game says.
        inRotationFor(f, 'WARRIOR')
        picker = widget(f, tag, value).children[1]
        assert(listed(picker) == 'Arms/Fury/Protection', tag)
        assert(picker.value == 2 or picker.configure and picker.value == 2)
        local text = f.addon.conditionDefinitions[tag].print(0, value)
        assert(text:find('Fury', 1, true) and not text:find('Enhancement', 1, true), text)
        value.tree = 3
        text = f.addon.conditionDefinitions[tag].print(0, value)
        assert(text:find('Protection', 1, true), text)
        inRotationFor(f, nil)
    end

    -- Before the game has the talent data the table still names the trees, and no number is shown.
    f.env.GetNumTalentTabs = function() return 0 end
    f.env.C_SpecializationInfo = nil
    local value = { type = 'PRIMARY_TALENT_TREE', tree = 3 }
    assert(listed(widget(f, 'PRIMARY_TALENT_TREE', value).children[1]) == 'Elemental/Enhancement/Restoration')
    local text = f.addon.conditionDefinitions.PRIMARY_TALENT_TREE.print(0, value)
    assert(text:find('Restoration', 1, true) and not text:find('%d'), text)

    assert(f.addon.conditionDefinitions.TALENT.print(0, {
        type = 'TALENT',
        tree = 1,
        talent = 1,
        operator = 'EQUALS',
        value = 2,
    }):find('Elemental', 1, true))
end)

test('the Classic talent condition names a foreign class\'s trees but not its talents', function()
    local f = fixture(2, 0, 'SHAMAN')
    live(f, { 'Elemental', 'Enhancement', 'Restoration' })
    local value = { type = 'TALENT', tree = 2, talent = 1, operator = 'EQUALS', value = 2 }
    local definition = f.addon.conditionDefinitions.TALENT

    assert(
        definition.print(0, value):find('Convection', 1, true) and definition.print(0, value):find(
            'Enhancement',
            1,
            true
        )
    )

    inRotationFor(f, 'WARRIOR')
    local parent = widget(f, 'TALENT', value)
    assert(listed(field(parent, 'Talent Tree')) == 'Arms/Fury/Protection')
    local talents = field(parent, 'Talent')
    talents.configure()
    assert(#talents.order == 0 and talents.disabled, 'a Shaman talent was offered for a Warrior tree')
    local text = definition.print(0, value)
    assert(text:find('Fury', 1, true) and not text:find('Convection', 1, true) and text:find('<talent>', 1, true), text)
    assert(value.tree == 2 and value.talent == 1, 'viewing converted the reference')
end)

test('a client without three-tree talents keeps the unsupported message and the saved tree', function()
    local f = fixture(1, 12, 'SHAMAN')
    local value = { type = 'PRIMARY_TALENT_TREE', tree = 2 }
    local parent = widget(f, 'PRIMARY_TALENT_TREE', value)
    assert(#parent.children == 2 and parent.children[2].disabled and value.tree == 2)
    local text = f.addon.conditionDefinitions.PRIMARY_TALENT_TREE.print(0, value)
    assert(text:find('2', 1, true), 'an unnamed tree was hidden')
end)

test('a rotation workspace reports the class its rotation is for', function()
    local f = fixture(2, 0, 'SHAMAN')
    local Trees = f.addon.TalentTrees
    assert(Trees.ContextClass() == 'SHAMAN')
    f.addon.activeRotationEditor = { workspace = { RotationClass = function() return 'DRUID' end } }
    assert(Trees.ContextClass() == 'DRUID')
    f.addon.activeRotationEditor = { workspace = { RotationClass = function() return nil end } }
    assert(Trees.ContextClass() == 'SHAMAN', 'a rotation with no class is the player\'s')
    f.addon.activeRotationEditor = { workspace = {} }
    assert(Trees.ContextClass() == 'SHAMAN', 'a workspace that cannot say is the player\'s')
    f.addon.activeRotationEditor = nil
    assert(Trees.ContextClass() == 'SHAMAN')
end)

finish()
