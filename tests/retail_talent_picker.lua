-- Retail TALENT: the talent picker and the evaluation, driven with a Retail class
-- tree modeled on Blizzard's generated API documentation and talent window
-- (tests/fixtures/retail_traits.lua). No real client was available: this proves
-- the addon against that model, not against the game.
local F = dofile('tests/fixtures/addon.lua')
local Tree = dofile('tests/fixtures/retail_traits.lua')
local test, finish = F.suite()

local function client(state, options)
    options = options or {}
    local f = F.new(1, 12, 'MAGE')
    local e = f.env
    local frames = {}
    local native = e.CreateFrame

    e.CreateFrame = function(...)
        local frame = native(...)
        frame.events = {}
        frames[#frames + 1] = frame
        local setScript = frame.SetScript

        function frame:SetScript(kind, fn)
            if kind == 'OnEvent' then
                self.onEvent = fn
            end

            if setScript then
                return setScript(self, kind, fn)
            end
        end

        function frame:RegisterEvent(event)
            self.events[event] = true
        end

        function frame:RegisterUnitEvent(event)
            self.events[event] = true
        end

        return frame
    end

    local model = Tree.install(e, state)

    for _, path in ipairs({
        'Platform/spells.lua',
        'Platform/talents.lua',
        'Core/build_context.lua',
        'Core/conditions.lua',
        'Conditions/common.lua',
        'Conditions/character.lua',
        'Conditions/talent.lua',
    }) do
        f.load(path)
    end

    f.addon.definitions = f.addon.conditionDefinitions or f.addon.definitions

    local function fire(event, ...)
        for _, frame in ipairs(frames) do
            if frame.events[event] and frame.onEvent then
                frame.onEvent(frame, event, ...)
            end
        end
    end

    return f, f.addon, e, fire, model
end

local function status(a, value, negated)
    local result = a:evaluateConditionResult(negated and { type = 'NOT', value = value } or value)
    return result.status, result.reason
end

local function talent(node, operator, rank, entry, spell)
    return {
        type = 'TALENT',
        layout = 'traits',
        node = node,
        entry = entry,
        spell = spell,
        operator = operator,
        value = rank,
    }
end

local function names(group)
    local out = {}

    for index, t in ipairs(group.talents) do
        out[index] = t.name
    end

    return out
end

local function has(list, name)
    for _, v in ipairs(list) do
        if v == name then
            return true
        end
    end

    return false
end

local function groupNamed(groups, name)
    for _, g in ipairs(groups) do
        if g.name == name then
            return g
        end
    end
end

local function child(parent, label)
    for _, w in ipairs(parent.children) do
        if (w.caption and w.caption:GetText() or w.label) == label then
            return w
        end

        if w.children then
            local inner = child(w, label)

            if inner then
                return inner
            end
        end
    end
end

-- The block the pickers sit in: the icon first, then the two lists, then the tree button.
local function block(parent)
    for _, w in ipairs(parent.children) do
        if w.layout == 'RM-IconRows' then
            return w
        end
    end
end

local function entryNamed(picker, name)
    for index, entry in ipairs(picker.list) do
        if entry.text == name then
            return index
        end
    end
end

local function editor(f, value, spec)
    local parent, top = f.widget('parent'), f.widget('top')
    top:SetUserData('root', value)
    top:SetUserData('funcs', { print = function() return 'Updated condition' end })
    parent:SetUserData('top', top)
    f.addon.definitions.TALENT.widget(parent, spec or 0, value)
    return parent, top
end

local ARCANE, FIRE, FROST = Tree.SPECS.Arcane, Tree.SPECS.Fire, Tree.SPECS.Frost

test(
    'the played specialization lists its class and specialization talents and only its own hero trees, by name with icon',
    function()
        local f, a = client({ spec = FIRE })
        local p = a.Platform
        local groups, meta = p:GetTraitTalents()
        assert(groups, tostring(meta))
        assert(meta.source == 'active')

        assert(
            #groups == 3 and groups[1].name == nil and groups[2].name == 'Frostfire' and groups[3].name == 'Sunfury',
            #groups
        )

        local main = names(groups[1])

        for _, wanted in ipairs({
            'Arcane Intellect', 'Blink', 'Shimmer', 'Ice Block', 'Pyroblast', 'Combustion', 'Phoenix Flames',
            'Kindling', "Alexstrasza's Fury"
        }) do
            assert(has(main, wanted), 'missing ' .. wanted)
        end

        for _, other in ipairs({ 'Arcane Surge', 'Arcane Missiles', 'Frozen Orb', 'Glacial Spike' }) do
            assert(not has(main, other), 'another specialization listed: ' .. other)
        end

        for _, group in ipairs(groups) do
            for _, t in ipairs(group.talents) do
                assert(t.name and t.icon and t.spellID and t.node, 'a talent lacks name, icon, spell or node')
            end
        end

        assert(groupNamed(groups, 'Spellslinger') == nil, 'a hero tree this specialization cannot choose was listed')
        assert(has(names(groups[2]), 'Frostfire Bolt') and has(names(groups[3]), 'Sunfury Execution'))
        assert(meta.hero and #meta.hero == 2)
    end
)

test(
    'choice nodes list each entry, tiered nodes list one talent, and the hero selection node is not a talent',
    function()
        local f, a = client({ spec = FIRE })
        local groups = a.Platform:GetTraitTalents()
        local shimmer, blink, tier, kindling

        for _, t in ipairs(groups[1].talents) do
            if t.name == 'Shimmer' then
                shimmer = t
            elseif t.name == 'Blink' then
                blink = t
            elseif t.name:find('Improved Frost Nova', 1, true) then
                tier = t
            elseif t.name == 'Kindling' then
                kindling = t
            end
        end

        assert(
            shimmer
                and blink
                and shimmer.node == 2002
                and blink.node == 2002
                and shimmer.entry
                and blink.entry
                and shimmer.entry ~= blink.entry
        )

        assert(kindling and kindling.node == 2204 and kindling.entry)
        assert(tier and tier.node == 2004 and tier.entry == nil, 'a tiered node became a choice')
        local count = 0

        for _, t in ipairs(groups[1].talents) do
            if t.node == 2004 then
                count = count + 1
            end
        end

        assert(count == 1, 'tiered node listed ' .. count .. ' times')

        for _, group in ipairs(groups) do
            for _, t in ipairs(group.talents) do
                assert(t.node ~= 2400, 'hero selection node listed')
            end
        end
    end
)

test(
    'hero talents of subtrees the specialization cannot choose are dropped even when the client reports them visible',
    function()
        local f, a = client({ spec = FIRE, leakHero = true })
        local groups = a.Platform:GetTraitTalents()

        assert(
            groupNamed(groups, 'Spellslinger') == nil and groupNamed(groups, 'Frostfire') and groupNamed(
                groups,
                'Sunfury'
            )
        )

        -- Without the client's answer the visible nodes are all there is to go on.
        f, a = client({ spec = FIRE, leakHero = true })

        f.env.C_ClassTalents.GetHeroTalentSpecsForClassSpec = function()
            error('unavailable')
        end

        assert(groupNamed(a.Platform:GetTraitTalents(), 'Spellslinger'), 'no fallback without the hero list')
    end
)

test(
    'another specialization is read from the view loadout, never in combat, and the played one never touches it',
    function()
        local state = { spec = FIRE }
        local f, a, e = client(state)
        local p = a.Platform
        local groups, meta = p:GetTraitTalents(FROST)
        assert(groups, tostring(meta))

        assert(
            meta.source == 'view'
                and state.viewSpec == FROST
                and state.viewLevel >= 80
                and state.calls.InitializeViewLoadout == 1
        )

        local main = names(groups[1])

        assert(
            has(main, 'Frozen Orb')
                and has(main, 'Glacial Spike')
                and has(main, 'Blink')
                and not has(main, 'Pyroblast')
                and not has(main, 'Arcane Surge')
        )

        assert(
            groupNamed(groups, 'Frostfire') and groupNamed(groups, 'Spellslinger') and not groupNamed(groups, 'Sunfury')
        )

        p:GetTraitTalents(FIRE)
        assert(state.calls.InitializeViewLoadout == 1, 'the played specialization used the view loadout')
        p:GetTraitTalents()
        assert(state.calls.InitializeViewLoadout == 1)
        state.combat = true
        local value, why = p:GetTraitTalents(ARCANE)
        assert(value == nil and why == 'in-combat' and state.calls.InitializeViewLoadout == 1, tostring(why))
        assert(p:GetTraitTalents(), 'the played specialization is listable in combat')
        state.combat = false

        for _, bad in ipairs({ 0, -1, 1.5 }) do
            assert(p:GetTraitTalents(bad) ~= nil, 'an invalid specialization should fall back to the played one')
        end

        e.C_ClassTalents.GetTraitTreeForSpec = function() return nil end
        value, why = p:GetTraitTalents(ARCANE)
        assert(value == nil and why == 'talent-tree-unavailable', tostring(why))

        e.C_ClassTalents.GetTraitTreeForSpec = function()
            error('gone')
        end

        value, why = p:GetTraitTalents(ARCANE)
        assert(value == nil and why == 'api-error', tostring(why))
        e.C_ClassTalents.InitializeViewLoadout = nil
        e.C_ClassTalents.GetTraitTreeForSpec = function() return Tree.TREE end
        value, why = p:GetTraitTalents(ARCANE)
        assert(value == nil and why == 'missing-api', tostring(why))
    end
)

test('an unreadable or failing talent API is a reason, never an empty list or a guess', function()
    local state = { spec = FIRE }
    local f, a, e = client(state)
    local p = a.Platform
    local opaque = {}
    e.canaccessvalue = function(v) return v ~= opaque end
    local nodes = e.C_Traits.GetTreeNodes
    e.C_Traits.GetTreeNodes = function(...) return opaque end
    local value, why = p:GetTraitTalents()
    assert(value == nil and why == 'restricted-value', tostring(why))
    e.C_Traits.GetTreeNodes = nodes
    state.errors = { GetNodeInfo = true }
    value, why = p:GetTraitTalents()
    assert(value == nil and why == 'api-error', 'failing node reads should be a reason: ' .. tostring(why))
    state.errors = nil
    state.noConfig = true
    value, why = p:GetTraitTalents()
    assert(value == nil and why == 'talent-config-unavailable', tostring(why))
    state.noConfig = false
    e.C_Traits.GetDefinitionInfo = function() return { spellID = opaque } end
    value, why = p:GetTraitTalents()
    assert(value == nil and why == 'restricted-value', 'secret spell IDs must not be listed: ' .. tostring(why))
end)

test(
    'TALENT compares ranks for the played specialization: purchased, granted, choice entry, tiers and hero trees',
    function()
        local state = { spec = FIRE }
        local f, a, e, fire = client(state)
        assert(status(a, talent(2201, 'EQUALS', 1)) == 'match', 'a granted talent has rank one')
        assert(status(a, talent(2203, 'EQUALS', 2)) == 'match' and status(a, talent(2203, 'EQUALS', 1)) == 'no-match')
        assert(status(a, talent(2202, 'GREATERTHANOREQUALS', 1)) == 'match')
        local entry2002, entry2204 = Tree.entryID({ id = 2002 }, 2), Tree.entryID({ id = 2204 }, 2)
        assert(status(a, talent(2002, 'GREATERTHANOREQUALS', 1, entry2002)) == 'match', 'chosen choice entry')

        assert(
            status(a, talent(2002, 'GREATERTHANOREQUALS', 1, Tree.entryID({ id = 2002 }, 1))) == 'no-match',
            'unchosen choice entry'
        )

        assert(status(a, talent(2204, 'EQUALS', 1, entry2204)) == 'match')
        assert(status(a, talent(2411, 'EQUALS', 1)) == 'match', 'the chosen hero tree')

        assert(
            status(a, talent(2431, 'EQUALS', 1)) == 'no-match' and status(a, talent(2431, 'EQUALS', 0)) == 'match',
            'an unchosen hero tree has rank zero'
        )

        -- Talents of the other specializations are real talents the character does not have.
        assert(
            status(a, talent(2301, 'EQUALS', 0)) == 'match' and status(a, talent(2301, 'GREATERTHAN', 0)) == 'no-match'
        )

        assert(status(a, talent(2301, 'GREATERTHAN', 0), true) == 'match', 'NOT of another specialization\'s talent')
        local st, why = status(a, talent(999999, 'GREATERTHAN', 0), true)
        assert(st == 'unavailable' and why == 'talent-node-unavailable', tostring(why))
    end
)

test(
    'evaluation reads each node once per talent change, in and out of combat, and keeps secrets unavailable',
    function()
        local state = { spec = FIRE }
        local f, a, e, fire = client(state)
        local value = talent(2202, 'GREATERTHANOREQUALS', 1)
        assert(status(a, value) == 'match')
        local reads = state.calls.GetNodeInfo

        for _ = 1, 50 do
            status(a, value)
        end

        assert(state.calls.GetNodeInfo == reads, 'node re-read without a talent change')
        state.purchased[2202] = nil
        fire('TRAIT_CONFIG_UPDATED', Tree.ACTIVE)
        assert(status(a, value) == 'no-match')
        state.purchased[2202] = 1
        fire('PLAYER_TALENT_UPDATE')
        assert(status(a, value) == 'match')
        state.spec = FROST
        state.purchased = { [2301] = 1 }
        fire('PLAYER_SPECIALIZATION_CHANGED', 'player')

        assert(
            status(a, talent(2301, 'EQUALS', 1)) == 'match' and status(a, value) == 'no-match',
            'spec change not followed'
        )

        local opaque = {}
        e.canaccessvalue = function(v) return v ~= opaque end
        state.purchased = { [2301] = { rank = opaque, entry = 1 } }
        fire('TRAIT_CONFIG_UPDATED', Tree.ACTIVE)
        local st, why = status(a, talent(2301, 'GREATERTHAN', 0), true)
        assert(st == 'unavailable' and why == 'restricted-value', tostring(why))
    end
)

test('a saved spell finds the talent again when the node ID is no longer its own', function()
    local state = { spec = FIRE }
    local f, a, e, fire = client(state)
    local COMBUSTION, KINDLING = 190319, 155148
    -- Node IDs renumbered: the saved ones are gone or hold something else.
    assert(status(a, talent(777777, 'EQUALS', 1, nil, COMBUSTION)) == 'match', 'missing node')
    assert(status(a, talent(2203, 'EQUALS', 1, nil, COMBUSTION)) == 'match', 'node now holds another talent')

    assert(
        status(a, talent(2301, 'EQUALS', 0, nil, COMBUSTION)) == 'no-match',
        'the moved talent is read, not the old node (rank 1, not 0)'
    )

    assert(status(a, talent(2204, 'EQUALS', 1, 424242, KINDLING)) == 'match', 'renumbered choice entry')
    local st, why = status(a, talent(777777, 'GREATERTHAN', 0, nil, 999), true)
    assert(st == 'unavailable' and why == 'talent-node-unavailable', tostring(why))
    -- A reference that still holds does not build the index.
    local before = state.calls.GetTreeNodes or 0

    assert(
        status(a, talent(2202, 'EQUALS', 1, nil, COMBUSTION)) == 'match' and (state.calls.GetTreeNodes or 0) == before,
        'index built for a valid reference'
    )

    -- The index is rebuilt after a talent change.
    state.purchased[2202] = nil
    fire('TRAIT_CONFIG_UPDATED')
    assert(status(a, talent(777777, 'EQUALS', 0, nil, COMBUSTION)) == 'match')
    -- Reading failures are reasons, not a search.
    state.errors = { GetNodeInfo = true }
    fire('TRAIT_CONFIG_UPDATED')
    st, why = status(a, talent(2202, 'EQUALS', 1, nil, COMBUSTION), true)
    assert(st == 'unavailable' and why == 'api-error', tostring(why))
end)

test(
    'stored references: old node/entry values stay valid and evaluate as before; a spell is optional and checked',
    function()
        local state = { spec = FIRE }
        local f, a = client(state)
        local d = a.definitions.TALENT
        local old = { type = 'TALENT', layout = 'traits', node = 2202, operator = 'GREATERTHANOREQUALS', value = 1 }

        local choice = {
            type = 'TALENT',
            layout = 'traits',
            node = 2002,
            entry = Tree.entryID({ id = 2002 }, 2),
            operator = 'EQUALS',
            value = 1,
        }

        assert(d.valid(0, old) and d.valid(0, choice))
        assert(a:evaluateCondition(old) and a:evaluateCondition(choice))
        local withSpell = { layout = 'traits', node = 2202, spell = 190319, operator = 'EQUALS', value = 1 }
        assert(d.valid(0, withSpell))

        for _, bad in ipairs({ { spell = 0 }, { spell = 1.5 }, { spell = 'x' }, { spell = 2 ^ 40 } }) do
            local v = { layout = 'traits', node = 2202, operator = 'EQUALS', value = 1 }

            for k, x in pairs(bad) do
                v[k] = x
            end

            assert(not d.valid(0, v), 'accepted a malformed spell')
        end

        assert(d.fields.spell == 'number')
        local text = d.print(0, withSpell)
        assert(text:find('Combustion', 1, true), text)
        -- A node gone from the tree is still named by its spell.
        text = d.print(0, { layout = 'traits', node = 777777, spell = 190319, operator = 'EQUALS', value = 1 })
        assert(text:find('Combustion', 1, true), text)
        text = d.print(0, { layout = 'traits', node = 777777, operator = 'EQUALS', value = 1 })
        assert(text:find('777777', 1, true), text)
    end
)

test(
    'editing a rotation for another specialization shows that specialization\'s talents, grouped under headings, with icons, and the played one\'s on request',
    function()
        local state = { spec = FIRE }
        local f, a, e = client(state)
        local value = {}
        local parent, top = editor(f, value, FROST)
        assert(state.viewSpec == FROST, 'the rotation\'s specialization was not loaded')
        local specs = assert(child(parent, 'Specialization'))
        specs.configure()

        assert(
            specs.value == FROST and #specs.order == 3 and specs.list[FIRE].text == 'Fire' and specs.list[FIRE].icon,
            'specialization list'
        )

        assert(child(parent, 'Talent Tree') == nil, 'the hero trees are headings of the one list, not another list')
        local picker = assert(child(parent, 'Talent'))
        picker.configure()
        assert(not picker.disabled, 'the talent list starts disabled')
        local headings = {}

        for index, entry in ipairs(picker.list) do
            assert(entry.text, 'list entry without a name')

            if entry.header then
                assert(entry.disabled and entry.icon == nil, 'a heading can be picked')
                headings[#headings + 1] = entry.text
            else
                assert(entry.icon, 'list entry without icon: ' .. entry.text)
            end
        end

        assert(
            table.concat(headings, '|')
                == 'Class and specialization talents|Hero talents: Frostfire|Hero talents: Spellslinger',
            table.concat(headings, '|')
        )

        assert(picker.list[1].header and picker.list[2].header == nil, 'the first heading is not first')
        local frostOrb = assert(entryNamed(picker, 'Frozen Orb'))
        assert(#picker.order == #picker.list)
        picker:Fire('OnValueChanged', frostOrb)

        assert(
            value.layout == 'traits'
                and value.node == 2301
                and value.entry == nil
                and value.spell == 84714
                and value.tree == nil
                and value.talent == nil
        )

        assert(
            value.operator == 'GREATERTHANOREQUALS'
                and value.value == 1
                and a.definitions.TALENT.valid(0, value)
                and top.statusText == 'Updated condition'
        )

        -- The default comparison is shown, not only stored.
        local operator, rank =
            parent.children[#parent.children].children[1], parent.children[#parent.children].children[2]

        operator.configure()

        assert(
            operator.value == 'GREATERTHANOREQUALS' and tostring(rank.text) == '1',
            'defaults picked for the talent are not displayed: ' .. tostring(operator.value) .. ' ' .. tostring(
                rank.text
            )
        )

        -- Switching to the played specialization reloads the list.
        specs:Fire('OnValueChanged', FIRE)
        picker.configure()
        local combustion = entryNamed(picker, 'Combustion')
        assert(combustion and picker.value == nil)
        assert(value.node == 2301, 'viewing another list changed the saved talent')
        -- A hero talent is under its own heading; a choice is written with its entry.
        local kindling

        for index, entry in ipairs(picker.list) do
            if entry.text:find('Kindling', 1, true) then
                kindling = index
            end
        end

        picker:Fire('OnValueChanged', kindling)
        assert(value.node == 2204 and value.entry and value.spell == 155148)
        picker:Fire('OnValueChanged', assert(entryNamed(picker, 'Frostfire Bolt')))
        assert(value.node == 2411 and value.spell == 431044 and value.entry == nil)
        -- A hand-typed node no longer goes with the spell of the picked talent.
        local nodeBox = assert(child(parent, 'Talent Node ID'))
        nodeBox:Fire('OnEnterPressed', '2202')
        assert(value.node == 2202 and value.spell == nil)
        local entryBox = assert(child(parent, 'Choice Entry ID'))
        entryBox:Fire('OnEnterPressed', '77')
        assert(value.entry == 77 and value.spell == nil)
    end
)

test(
    'reopening a saved talent selects it; a talent of another specialization still opens, named, and the list follows the rotation',
    function()
        local state = { spec = FIRE }
        local f, a = client(state)
        local value = { layout = 'traits', node = 2203, spell = 257541, operator = 'EQUALS', value = 2 }
        local parent = editor(f, value, FIRE)
        local picker = child(parent, 'Talent')
        picker.configure()
        assert(picker.list[picker.value].text == 'Phoenix Flames' and not picker.list[picker.value].header)
        parent = editor(f, { layout = 'traits', node = 2301, spell = 84714, operator = 'EQUALS', value = 1 }, FIRE)
        picker = child(parent, 'Talent')
        picker.configure()
        assert(picker.value == nil and #picker.order > 0, 'a talent of another specialization broke the list')
        assert(picker.disabled == false)
        parent = editor(f, { layout = 'traits', node = 2301, spell = 84714, operator = 'EQUALS', value = 1 }, FROST)
        picker = child(parent, 'Talent')
        picker.configure()
        assert(picker.list[picker.value].text == 'Frozen Orb')

        assert(a.definitions.TALENT.print(FIRE, {
            layout = 'traits',
            node = 2301,
            spell = 84714,
            operator = 'EQUALS',
            value = 1,
        }):find('Frozen Orb', 1, true))
    end
)

test('the picker says why the talents cannot be listed, with the reason, and keeps node IDs usable', function()
    local state = { spec = FIRE, combat = true }
    local f, a = client(state)
    local value = {}
    local parent = editor(f, value, FROST)
    assert(F.text(parent):find('during combat', 1, true), F.text(parent))
    local picker = child(parent, 'Talent')
    picker.configure()
    assert(picker.disabled == true)
    local nodeBox = assert(child(parent, 'Talent Node ID'))
    nodeBox:Fire('OnEnterPressed', '2301')
    assert(value.node == 2301 and a.definitions.TALENT.valid(0, value))
    state.combat = false
    f = client({ spec = FIRE, errors = { GetTreeNodes = true } })
    parent = editor(f, {}, FIRE)
    assert(F.text(parent):find('cannot be listed right now (api-error)', 1, true), F.text(parent))
    f = client({ spec = FIRE, errors = { GetConfigInfo = true } })
    parent = editor(f, {}, FIRE)
    assert(F.text(parent):find('(api-error)', 1, true), F.text(parent))
    -- With no active config yet (right after login) the played specialization is read like another one.
    f = client({ spec = FIRE, noConfig = true })
    parent = editor(f, {}, FIRE)

    assert(
        F.text(parent):find('right now', 1, true) == nil,
        'the played specialization could not be listed without an active config'
    )
end)

test('a rotation for another class gets no list of your talents, only the node IDs', function()
    local f, a = client({ spec = FIRE })
    a.activeRotationEditor = { workspace = { RotationClass = function() return 'WARRIOR' end } }
    local value = {}
    local parent = editor(f, value, FIRE)
    assert(F.text(parent):find('only for your own class', 1, true), F.text(parent))
    local picker = child(parent, 'Talent')
    picker.configure()
    assert(picker.disabled == true and #picker.order == 0)
    local nodeBox = assert(child(parent, 'Talent Node ID'))
    nodeBox:Fire('OnEnterPressed', '2301')
    assert(value.node == 2301 and a.definitions.TALENT.valid(0, value))
    a.activeRotationEditor = { workspace = { RotationClass = function() return 'MAGE' end } }
    picker = child(editor(f, {}, FIRE), 'Talent')
    picker.configure()
    assert(not picker.disabled and #picker.order > 0, 'the player\'s own class lost its list')
end)

test('the icon is the left column of a two-row block: specialization above, talent below, then the rest', function()
    local state = { spec = FIRE }
    local f, a = client(state)
    local value = { layout = 'traits', node = 2203, spell = 257541, operator = 'EQUALS', value = 2 }
    local parent = editor(f, value, FIRE)
    local box = assert(block(parent))
    local kinds = {}

    for index, w in ipairs(box.children) do
        kinds[index] = w.type
    end

    assert(kinds[1] == 'RM-ConditionIcon' and kinds[2] == 'RM-Selector' and kinds[3] == 'RM-Selector', table.concat(
        kinds,
        ','
    ))

    assert(box.children[2].caption:GetText() == 'Specialization' and box.children[3].caption:GetText() == 'Talent')
    local icon = box.children[1]

    assert(
        icon.image:GetTexture() == 257541 + 100000,
        'the icon does not show the saved talent: ' .. tostring(icon.image:GetTexture())
    )

    -- Nothing chosen: a placeholder, not an empty box; choosing fills it.
    local empty = {}
    parent = editor(f, empty, FIRE)
    box = assert(block(parent))
    icon = box.children[1]
    assert(icon.image:GetTexture() == 'Interface\\Icons\\INV_Misc_QuestionMark', tostring(icon.image:GetTexture()))
    local picker = child(parent, 'Talent')
    picker.configure()
    picker:Fire('OnValueChanged', assert(entryNamed(picker, 'Pyroblast')))
    assert(icon.image:GetTexture() == 11366 + 100000, 'choosing a talent did not fill the icon')

    -- Nothing else sits between the specialization and the talent lists.
    for index, w in ipairs(parent.children) do
        if w == box then
            assert(parent.children[index + 1].label == nil or parent.children[index + 1].type == 'RM-ConditionLabel')
        end
    end
end)

test(
    'class and specialization talents are told apart by the talent window\'s columns, with a gap, else kept together',
    function()
        local f, a = client({ spec = FIRE, scale = 100 })
        local groups = assert(a.Platform:GetTraitTalents())

        assert(
            groups[1].kind == 'class'
                and groups[2].kind == 'spec'
                and groups[3].kind == 'hero'
                and groups[4].kind == 'hero',
            groups[1].kind .. '/' .. tostring(groups[2].kind)
        )

        assert(
            has(names(groups[1]), 'Blink') and not has(names(groups[1]), 'Pyroblast'),
            'a specialization talent listed as a class talent'
        )

        assert(
            has(names(groups[2]), 'Pyroblast')
                and has(names(groups[2]), 'Combustion')
                and not has(names(groups[2]), 'Blink')
        )

        local parent = editor(f, {}, FIRE)
        local picker = child(parent, 'Talent')
        picker.configure()
        local headings = {}

        for _, entry in ipairs(picker.list) do
            if entry.header then
                headings[#headings + 1] = entry.text
            end
        end

        assert(
            table.concat(headings, '|')
                == 'Class talents|Specialization talents|Hero talents: Frostfire|Hero talents: Sunfury',
            table.concat(headings, '|')
        )

        -- No gap between the two (overlapping columns): one group, not a guess.
        f, a = client({ spec = FIRE })
        groups = assert(a.Platform:GetTraitTalents())
        assert(groups[1].kind == 'talents' and has(names(groups[1]), 'Blink') and has(names(groups[1]), 'Pyroblast'))
    end
)

test(
    'a hero subtree the client does not name keeps its talents together, apart from the class and specialization talents',
    function()
        local f, a, e = client({ spec = FIRE, scale = 100 })
        local info = e.C_Traits.GetSubTreeInfo

        e.C_Traits.GetSubTreeInfo = function(config, sub)
            local record = info(config, sub)

            if record and sub == 41 then
                record.name = nil
            end

            return record
        end

        local groups = assert(a.Platform:GetTraitTalents())

        assert(
            groups[1].kind == 'class'
                and groups[2].kind == 'spec'
                and groups[3].kind == 'hero'
                and groups[3].name == nil
                and groups[3].talents[1].name == 'Frostfire Bolt',
            groups[3].kind
        )

        assert(
            not has(names(groups[1]), 'Frostfire Bolt') and not has(names(groups[2]), 'Frostfire Bolt'),
            'hero talents leaked into the plain groups'
        )

        local parent = editor(f, {}, FIRE)
        local picker = child(parent, 'Talent')
        picker.configure()
        local headings = {}

        for _, entry in ipairs(picker.list) do
            if entry.header then
                headings[#headings + 1] = entry.text
            end
        end

        assert(headings[3] == 'Hero Talents' and headings[4] == 'Hero talents: Sunfury', table.concat(headings, '|'))
    end
)

test(
    'the hero trees follow the specialization even when the client names none; icons are the talent window\'s',
    function()
        local state = { spec = FIRE }
        local f, a, e = client(state)
        -- "Returns nothing if none available" (GetHeroTalentSpecsForClassSpec is MayReturnNothing).
        e.C_ClassTalents.GetHeroTalentSpecsForClassSpec = function() end
        local groups = assert(a.Platform:GetTraitTalents())
        assert(groupNamed(groups, 'Frostfire') and groupNamed(groups, 'Sunfury'), 'hero trees lost')
        -- Each specialization has its own selection node, visible only to it (TalentFrameUtil.GetFirstAvailableSubTreeSelectionNode):
        -- the fixture's one node answers with the entries of the specialization shown.
        local nodeInfo = e.C_Traits.GetNodeInfo

        e.C_Traits.GetNodeInfo = function(config, id)
            local info = nodeInfo(config, id)

            if id == 2400 and info.ID == 2400 then
                local own, keep = {}, {}

                for _, sub in ipairs(Tree.heroOf[FIRE]) do
                    own[sub] = true
                end

                for position, sub in ipairs({ 41, 42, 43 }) do
                    if own[sub] then
                        keep[#keep + 1] = Tree.entryID({ id = 2400 }, position)
                    end
                end

                info.entryIDs = keep
            end

            return info
        end

        e.C_Traits.GetHeroTalentSpecsForClassSpec = function() end
        groups = assert(a.Platform:GetTraitTalents())

        assert(
            groupNamed(groups, 'Frostfire')
                and groupNamed(groups, 'Sunfury')
                and not groupNamed(groups, 'Spellslinger'),
            'hero trees not taken from the selection node'
        )

        e.C_Traits.GetNodeInfo = nodeInfo

        -- The talent window shows the spell's original icon (TalentButtonUtil.CalculateIconTexture), the override first.
        e.C_Spell.GetSpellInfo = function(id)
            local s = Tree.spells[id]

            if s then
                return { spellID = id, name = s.name, iconID = s.icon + 1, originalIconID = s.icon }
            end
        end

        local pyroblast

        for _, t in ipairs(assert(a.Platform:GetTraitTalents())[1].talents) do
            if t.name == 'Pyroblast' then
                pyroblast = t
            end
        end

        assert(
            pyroblast and pyroblast.icon == 11366 + 100000,
            'the original icon is the talent window\'s: ' .. tostring(pyroblast and pyroblast.icon)
        )

        local definition = e.C_Traits.GetDefinitionInfo

        e.C_Traits.GetDefinitionInfo = function(id)
            local info = definition(id)

            if info and info.spellID == 11366 then
                info.overrideIcon = 777
                info.overrideName = 'Hot Rock'
            end

            return info
        end

        for _, t in ipairs(assert(a.Platform:GetTraitTalents())[1].talents) do
            if t.spellID == 11366 then
                pyroblast = t
            end
        end

        assert(pyroblast.icon == 777 and pyroblast.name == 'Hot Rock', 'a definition\'s override must win')
        -- A spell nobody can name: nothing is listed and the reason says so.
        e.C_Spell.GetSpellInfo = function() return nil end
        e.C_Traits.GetDefinitionInfo = definition
        local value, why = a.Platform:GetTraitTalents()
        assert(value == nil and why == 'talent-entry-unavailable', tostring(why))
    end
)

test('another specialization is never read while the talent window shows someone else\'s build', function()
    local state = { spec = FIRE }
    local f, a, e = client(state)
    local p = a.Platform
    e.PlayerSpellsFrame = { IsShown = function() return true end, IsInspecting = function() return true end }
    local value, why = p:GetTraitTalents(FROST)
    assert(value == nil and why == 'talent-window-inspecting' and not state.calls.InitializeViewLoadout, tostring(why))
    assert(p:GetTraitTalents(), 'the played specialization needs no view')
    e.PlayerSpellsFrame = { IsShown = function() return true end, IsInspecting = function() return false end }
    assert(p:GetTraitTalents(FROST) and state.calls.InitializeViewLoadout == 1)
    e.PlayerSpellsFrame = nil
    assert(p:GetTraitTalents(ARCANE) and state.calls.InitializeViewLoadout == 2, 'the lists need no Blizzard window')
end)

test('the tree button is off while the lists could not be filled, and on once they can', function()
    local f, a = client({ spec = FIRE, errors = { GetTreeNodes = true } })
    local e = f.env
    a.OpenTalentTree = function() end
    a.Platform.HasTalentTreeProvider = function() return true end
    local parent = editor(f, {}, FIRE)
    local box = assert(block(parent))
    local button = box.children[#box.children]

    assert(
        button.type == 'RM-ConditionButton' and button.disabled == true,
        'the tree button is on although nothing is listed'
    )

    f, a = client({ spec = FIRE })
    a.OpenTalentTree = function() end
    a.Platform.HasTalentTreeProvider = function() return true end
    parent = editor(f, {}, FIRE)
    box = assert(block(parent))
    button = box.children[#box.children]
    assert(button.type == 'RM-ConditionButton' and not button.disabled and button:GetUserData('side') == true)
end)

test('Forever and the classic clients keep their pickers: one tree per class, no specialization list', function()
    local f = F.new(18, 12, 'MAGE')
    local e = f.env
    Tree.install(e, { spec = FIRE })

    for _, path in ipairs({
        'Platform/spells.lua',
        'Platform/talents.lua',
        'Core/build_context.lua',
        'Core/conditions.lua',
        'Conditions/common.lua',
        'Conditions/character.lua',
        'Conditions/talent.lua',
    }) do
        f.load(path)
    end

    f.addon.definitions = f.addon.conditionDefinitions or f.addon.definitions
    local groups, meta = f.addon.Platform:GetTraitTalents(FROST)

    assert(
        groups and meta.source == 'active' and f.env.C_ClassTalents.InitializeViewLoadout and true,
        'Forever has one tree per class'
    )

    local parent = editor(f, {}, FROST)
    assert(child(parent, 'Specialization') == nil)
end)

finish()
