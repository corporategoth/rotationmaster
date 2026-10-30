-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project, expansion)
    local f = F.new(project, expansion)
    local a, e = f.addon, f.env
    local state = { rank = 2, selected = true, calls = 0 }
    local compress = f.libraries.LibCompress
    compress.fcs16init = function() return '' end
    compress.fcs16update = function(_, hash, value) return hash .. value end
    compress.fcs16final = function(_, hash) return hash end
    e.GetNumTalentTabs = function() return 3 end
    e.GetNumTalents = function() return 2 end

    e.C_SpecializationInfo = {
        GetSpecializationInfo = function(tree) return tree, 'Elemental', 'Description', 1, nil, nil, 2 end,
        GetTalentInfo = function(query)
            state.calls = state.calls + 1

            return {
                name = 'Convection',
                icon = 1,
                rank = state.rank,
                maxRank = 5,
                talentID = 101,
                spellID = 108269,
                tier = 1,
                column = 2,
                selected = state.selected,
                available = true,
                known = true,
                grantedByAura = false,
                previewRank = 0,
                meetsPrereq = true,
                meetsPreviewPrereq = true,
                isExceptional = false,
                hasGoldBorder = false,
                isPVPTalentUnlocked = false,
            }
        end,
    }

    for _, path in ipairs({
        'Platform/talents.lua',
        'Core/conditions.lua',
        'Conditions/common.lua',
        'Conditions/character.lua',
        'Conditions/talent.lua',
    }) do
        f.load(path)
    end

    return f, state
end

local function tree()
    return { type = 'TALENT', tree = 1, talent = 1, operator = 'EQUALS', value = 2 }
end

test('real talent rank condition uses native records reuses each pass and sees newly spent points', function()
    local f, s = fixture()
    local a = f.addon
    local value = tree()
    assert(a:evaluateConditionResult(value).status == 'match')
    s.calls = 0

    assert(
        a:evaluateCondition({ type = 'AND', value = { value, tree() } }) and s.calls == 1,
        'rank was sampled inconsistently within one pass'
    )

    s.rank = 0
    assert(a:evaluateConditionResult(value).status == 'no-match', 'permanent talent cache hid a respec')
    assert(a:evaluateCondition({ type = 'NOT', value = value }))
    local opaque = {}
    f.env.canaccessvalue = function(v) return v ~= opaque end
    s.rank = opaque

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = value }).status == 'unavailable',
        'secret rank became unselected'
    )

    f.env.C_SpecializationInfo.GetTalentInfo = function()
        error('native unavailable')
    end

    assert(a:evaluateConditionResult({ type = 'NOT', value = value }).status == 'unavailable')
end)

test('grid selection is explicit and historical tree or legacy retail slots remain unavailable under NOT', function()
    local f, s = fixture(19, 4)
    local a = f.addon
    local value = { type = 'TALENT', layout = 'grid', value = 3 }
    assert(a:evaluateCondition(value))
    s.selected = false
    assert(not a:evaluateCondition(value))
    assert(a:evaluateCondition({ type = 'NOT', value = value }))

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = tree() }).status == 'unavailable',
        'Mists placeholder ranks were interpreted as real tree state'
    )

    f = fixture(1, 12)
    a = f.addon

    f.env.C_SpecializationInfo.GetTalentInfo = function()
        error('modern trait tree must not query an old slot')
    end

    assert(a:evaluateConditionResult({ type = 'NOT', value = { type = 'TALENT', value = 1 } }).status == 'unavailable')

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = { type = 'TALENT', layout = 'grid', value = 1 } }).status
            == 'unavailable'
    )
end)

test(
    'malformed rank and grid fields cannot call native APIs and metadata printers remain readable when absent',
    function()
        local f, s = fixture()
        local a = f.addon
        local definition = a.conditionDefinitions.TALENT

        for _, mutation in ipairs({
            { tree = 1.5 },
            { talent = -1 },
            { value = math.huge },
            { value = 0 / 0 },
            { operator = 'TYPO' },
            { layout = 'future' },
        }) do
            local value = tree()

            for key, v in pairs(mutation) do
                value[key] = v
            end

            assert(not definition.valid(0, value))
        end

        assert(s.calls == 0)
        local text = definition.print(0, tree())
        assert(text:find('Convection', 1, true) and text:find('Elemental', 1, true))
        f.env.C_SpecializationInfo = nil
        f.env.GetTalentInfo = nil
        f.env.GetTalentTabInfo = nil
        -- The game no longer answers: the talent is a placeholder, the tree is still named (by the shipped table).
        text = definition.print(0, tree())

        assert(
            text:find('<talent>', 1, true)
                and text:find('Elemental', 1, true)
                and not text:find('<talent tree>', 1, true)
        )

        local unknown = tree()
        unknown.tree = 9
        text = definition.print(0, unknown)
        assert(text:find('<talent>', 1, true) and text:find('<talent tree>', 1, true))
        local help = f.widget('help')
        definition.help(help)
        assert(#F.text(help) > 20)
    end
)

local function find(parent, label)
    for _, w in ipairs(parent.children) do
        if (w.caption and w.caption:GetText() or w.label) == label then
            return w
        end

        if w.children then
            local inner = find(w, label)

            if inner then
                return inner
            end
        end
    end
end

local function fields(f, value, spec)
    local parent, top = f.widget('parent'), f.widget('top')
    top:SetUserData('root', value)
    top:SetUserData('funcs', { print = function() return 'Updated condition' end })
    parent:SetUserData('top', top)
    f.addon.conditionDefinitions.TALENT.widget(parent, spec or 0, value)
    return parent
end

test('talent icons and unsupported-layout messages use native primitives without Ace allocation', function()
    for _, branch in ipairs({ { 5, 1 }, { 1, 12 } }) do
        local f = fixture(branch[1], branch[2])
        assert(f.libraries['AceGUI-3.0'] == nil)
        local parent = fields(f, tree())
        assert(#parent.children > 0)

        for _, child in ipairs(parent.children) do
            assert(child.rmWidget, 'non-native talent field')
        end
    end
end)

test('tree editor names native trees and clears former talent only on an explicit tree change', function()
    local f = fixture()
    local value = tree()
    local parent = fields(f, value)
    local trees = find(parent, 'Talent Tree')
    assert(trees)
    trees.configure()
    assert(trees.list[1] == 'Elemental' and value.talent == 1 and value.layout == nil)
    -- The talents of a tree are listed by name with their icon.
    local talents = find(parent, 'Talent')
    talents.configure()
    assert(talents.list[1].text == 'Convection' and talents.list[1].icon == 1, 'talent list lacks name or icon')
    trees:Fire('OnValueChanged', 2)
    assert(value.tree == 2 and value.talent == nil and value.layout == 'tree')
    f.env.GetNumTalentTabs = nil
    f.env.GetNumTalents = nil
    f.env.C_SpecializationInfo = nil
    assert(fields(f, tree()), 'missing metadata prevented opening an old condition')
end)

test(
    'Mists picker does not silently convert historical references and writes grid identity only on explicit choice',
    function()
        local f = fixture(19, 4)
        local value = tree()
        local parent = fields(f, value, 2)
        assert(value.tree == 1 and value.talent == 1 and value.value == 2 and value.layout == nil)
        local picker = find(parent, 'Talent')
        local tier = find(parent, 'Tier')
        assert(picker and tier)
        picker.configure()
        tier.configure()

        -- Six tiers of three: the tier above, its three talents below, the tier's own level in its name.
        assert(
            #tier.order == 6
                and tier.list[1] == 'Tier 1 (level 15)'
                and tier.list[6] == 'Tier 6 (level 90)'
                and tier.value == 1
        )

        assert(
            picker.value == nil
                and #picker.order == 3
                and picker.list[1].text == 'Convection'
                and picker.list[1].icon == 1
        )

        assert(value.layout == nil and value.value == 2, 'viewing a tier converted the historical reference')
        tier:Fire('OnValueChanged', 3)
        picker.configure()
        assert(#picker.order == 3 and picker.value == nil and value.layout == nil)
        picker:Fire('OnValueChanged', 2)

        assert(
            value.layout == 'grid'
                and value.value == 8
                and value.tree == nil
                and value.talent == nil
                and value.operator == nil,
            'tier 3, talent 2 is slot 8'
        )

        -- The saved slot reopens on its own tier and talent.
        local again = fields(f, { type = 'TALENT', layout = 'grid', value = 8 }, 2)
        local savedTier, savedPicker = find(again, 'Tier'), find(again, 'Talent')
        savedTier.configure()
        savedPicker.configure()
        assert(savedTier.value == 3 and savedPicker.value == 2, 'the saved Mists talent was not shown')
        picker:Fire('OnValueChanged', 3)
        assert(value.value == 9)
        assert(f.addon.conditionDefinitions.TALENT.valid(2, value))
        f = fixture(1, 12)
        value = { type = 'TALENT', value = 1 }
        assert(fields(f, value) and value.value == 1 and value.layout == nil)
    end
)

test('Classic tree point and primary-tree predicates use actual public points without spec-slot guesses', function()
    local f = fixture()
    local a = f.addon
    assert(a.conditionDefinitions.PRIMARY_TALENT_TREE, 'primary-tree condition missing')
    local points = { 5, 20, 0 }

    f.env.C_SpecializationInfo.GetSpecializationInfo = function(tree)
        return tree, 'Tree ' .. tree, '', tree, nil, nil, points[tree]
    end

    local primary = { type = 'PRIMARY_TALENT_TREE', tree = 2 }
    local spent = { type = 'TALENT_TREE_POINTS', tree = 2, operator = 'GREATERTHAN', value = 10 }
    assert(a:evaluateCondition(primary) and a:evaluateCondition(spent))
    primary.tree = 1
    assert(not a:evaluateCondition(primary))
    points[1] = 20
    assert(a:evaluateConditionResult({ type = 'NOT', value = primary }).status == 'unavailable')
    points = { 0, 0, 0 }
    assert(a:evaluateConditionResult({ type = 'NOT', value = primary }).status == 'unavailable')
    spent.operator = 'EQUALS'
    spent.value = 0
    assert(a:evaluateCondition(spent), 'explicit zero points comparison is unavailable')
    local secret = {}
    f.env.canaccessvalue = function(value) return not rawequal(value, secret) end
    points[2] = secret
    assert(a:evaluateConditionResult({ type = 'NOT', value = spent }).status == 'unavailable')

    for _, client in ipairs({ { 19, 4 }, { 1, 12 }, { 18, 12 } }) do
        local other = fixture(client[1], client[2])
        assert(other.addon:evaluateConditionResult({ type = 'NOT', value = primary }).status == 'unavailable')
    end
end)

test('primary tree cache is per evaluation and its native chooser preserves references while viewing', function()
    local f = fixture()
    local a = f.addon
    local points = { 5, 20, 0 }
    local calls = 0

    f.env.C_SpecializationInfo.GetSpecializationInfo = function(index)
        calls = calls + 1
        return index, 'Tree ' .. index, '', index, nil, nil, points[index]
    end

    local condition = { type = 'PRIMARY_TALENT_TREE', tree = 2 }

    assert(
        a:evaluateCondition({ type = 'AND', value = { condition, { type = 'PRIMARY_TALENT_TREE', tree = 2 } } })
            and calls == 3,
        'primary tree sampled more than once within one evaluation'
    )

    points[1] = 30
    assert(not a:evaluateCondition(condition), 'primary-tree cache concealed changed points')
    local top, parent = f.widget('Frame'), f.widget('Group')
    parent:SetUserData('top', top)
    top:SetUserData('root', condition)
    top:SetUserData('funcs', { print = function() return 'Updated' end })
    a.conditionDefinitions.PRIMARY_TALENT_TREE.widget(parent, 0, condition)
    local picker = parent.children[1]
    picker.configure()
    assert(picker.type == 'RM-Selector' and picker:GetValue() == 2 and condition.tree == 2)
    picker:SetValue(1)
    assert(condition.tree == 2, 'view state mutated the authored tree')
    picker:Fire('OnValueChanged', 1)
    assert(condition.tree == 1 and top.statusText == 'Updated')
    local other = fixture(1, 12)
    local root = { type = 'PRIMARY_TALENT_TREE', tree = 2 }
    top, parent = other.widget('Frame'), other.widget('Group')
    parent:SetUserData('top', top)
    top:SetUserData('root', root)
    top:SetUserData('funcs', { print = function() return '' end })
    other.addon.conditionDefinitions.PRIMARY_TALENT_TREE.widget(parent, 0, root)
    assert(root.tree == 2 and parent.children[2].disabled, 'unsupported view converted or enabled the reference')
end)

test('missing authored talent trees stay unavailable under NOT rather than matching another tree', function()
    local f = fixture()
    local a = f.addon

    f.env.C_SpecializationInfo.GetSpecializationInfo = function(index)
        if index > 3 then
            return
        end

        return index, 'Tree ' .. index, '', index, nil, nil, index == 2 and 20 or 0
    end

    assert(
        a:evaluateCondition({ type = 'NOT', value = { type = 'PRIMARY_TALENT_TREE', tree = 1 } }),
        'existing non-primary tree should be an ordinary mismatch'
    )

    for _, condition in ipairs({
        { type = 'PRIMARY_TALENT_TREE', tree = 16 },
        { type = 'TALENT_TREE_POINTS', tree = 16, operator = 'EQUALS', value = 0 },
    }) do
        assert(
            a:evaluateConditionResult({ type = 'NOT', value = condition }).status == 'unavailable',
            'absent authored tree became true under NOT: ' .. condition.type
        )
    end

    f.env.GetNumTalentTabs = function() return 0 end

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = { type = 'PRIMARY_TALENT_TREE', tree = 1 } }).status
            == 'unavailable'
    )
end)

test(
    'tree-switch schemas report required fields and carry portable references without class or spec assumptions',
    function()
        local f = fixture()
        local data = dofile('tests/fixtures/rotation_data.lua')()
        local options = { conditions = f.addon.conditionDefinitions }

        for _, condition in ipairs({
            { type = 'PRIMARY_TALENT_TREE', tree = 2 },
            { type = 'TALENT_TREE_POINTS', tree = 2, operator = 'EQUALS', value = 0 },
        }) do
            local body = { switch = condition, rotation = {}, cooldowns = {} }
            local result = data.ValidateBody(body, options)
            assert(result.valid and result.supported)
            condition.tree = nil
            assert(not data.ValidateBody(body, options).valid, 'missing talent tree accepted')
        end
    end
)

finish()
