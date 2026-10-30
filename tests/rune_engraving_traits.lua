-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery rune engraving (RUNE_ENGRAVED, Platform/engraving.lua)
-- and trait talents on Retail and Forever (TALENT layout "traits", Forever's
-- trees for TALENT_TREE_POINTS / PRIMARY_TALENT_TREE, Platform/talents.lua).
-- Both read event-invalidated caches in Core/build_context.lua. C_Engraving
-- is modelled from Blizzard's generated API documentation (Gethe/wow-ui-source
-- classic_era EngravingInfoDocumentation.lua); C_ClassTalents/C_Traits from
-- the forever branch (ca8368f2) SharedTraits/ClassTalents documentation and
-- the Camelot ClassTalentsFrame tree headers.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function base(project, expansion)
    local f = F.new(project, expansion, 'MAGE')
    local e = f.env
    local s = { frames = {}, calls = {} }

    local function hit(name)
        s.calls[name] = (s.calls[name] or 0) + 1
    end

    s.hit = hit
    -- Wrap the native UI fixture's frames so event registrations can be fired.
    local native = e.CreateFrame

    e.CreateFrame = function(...)
        local frame = native(...)
        frame.events = {}
        s.frames[#s.frames + 1] = frame
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

    e.C_Spell = {
        GetSpellInfo = function(id) return { spellID = id, name = 'Spell ' .. id, iconID = id + 1 } end,
        GetSpellLink = function(id) return '[Spell ' .. id .. ']' end,
    }

    local function fire(event, ...)
        for _, frame in ipairs(s.frames) do
            if frame.events[event] and frame.onEvent then
                frame.onEvent(frame, event, ...)
            end
        end
    end

    return f, e, s, fire
end

local function loadAll(f)
    for _, path in ipairs({
        'Platform/spells.lua', 'Platform/talents.lua', 'Platform/engraving.lua', 'Core/build_context.lua',
        'Core/conditions.lua', 'Conditions/common.lua', 'Conditions/character.lua', 'Conditions/talent.lua',
        'Conditions/engraving.lua'
    }) do
        f.load(path)
    end

    f.addon.definitions = f.addon.conditionDefinitions or f.addon.definitions
    return f.addon
end

-- C_Engraving: two engravable slots (chest 5, hands 10). Chest carries
-- Living Bomb (rune 6729, spell 400613); hands carries a passive rune
-- (rune 6800, Hot Streak 400624).
local function engraving(s, state)
    local hit = s.hit

    local runes = {
        living = {
            skillLineAbilityID = 6729,
            itemEnchantmentID = 6729,
            name = 'Living Bomb',
            iconTexture = 236220,
            equipmentSlot = 5,
            level = 1,
            learnedAbilitySpellIDs = { 400613 },
        },
        hot = {
            skillLineAbilityID = 6800,
            itemEnchantmentID = 6800,
            name = 'Hot Streak',
            iconTexture = 236218,
            equipmentSlot = 10,
            level = 1,
            learnedAbilitySpellIDs = { 400624 },
        },
        regen = {
            skillLineAbilityID = 6801,
            itemEnchantmentID = 6801,
            name = 'Regeneration',
            iconTexture = 1,
            equipmentSlot = 10,
            level = 1,
            learnedAbilitySpellIDs = {},
        },
    }

    state.slots = state.slots or { [5] = runes.living, [10] = runes.hot }
    state.max = state.max or 12

    return {
        IsEngravingEnabled = function()
            hit('enabled')

            if state.enabledError then
                error('blocked')
            end

            return state.enabled ~= false
        end,
        GetNumRunesKnown = function()
            hit('count')
            return 3, state.max
        end,
        RefreshRunesList = function()
            hit('refresh')
        end,
        IsEquipmentSlotEngravable = function(slot)
            hit('engravable')
            return slot == 5 or slot == 10
        end,
        GetRuneForEquipmentSlot = function(slot)
            hit('slot')

            if state.slotError then
                error('blocked')
            end

            return state.slots[slot]
        end,
        GetRuneCategories = function(filter, owned)
            assert(filter == false and owned == true)
            return { 5, 10 }
        end,
        GetRunesForCategory = function(category, owned)
            assert(owned == true)
            hit('category')

            if category == 5 then
                return { runes.living }
            end

            return { runes.hot, runes.regen }
        end,
    },
        runes
end

local function era(state)
    local f, e, s, fire = base(2, 0)
    state = state or {}
    local api, runes = engraving(s, state)
    e.C_Engraving = api
    e.C_Item = { GetItemInventorySlotInfo = function(category) return category == 5 and 'Chest' or 'Hands' end }
    local a = loadAll(f)
    return a, e, s, fire, state, runes, f
end

local function node(tag, value)
    value.type = tag
    return value
end

local function status(a, value, negated)
    local result = a:evaluateConditionResult(negated and { type = 'NOT', value = value } or value)
    return result.status, result.reason
end

test(
    'engraving reader: missing namespace, disabled realm, pending list and failures are reasons, never values',
    function()
        local f, e, s = base(5, 1)
        f.load('Platform/talents.lua')
        f.load('Platform/engraving.lua')
        local p = f.addon.Platform
        e.C_Engraving = nil

        for _, name in ipairs({ 'GetEngravedRunes', 'GetKnownRunes', 'GetEngravingAvailability' }) do
            local value, why = p[name](p)
            assert(value == nil and why == 'missing-api', name .. ' ' .. tostring(why))
        end

        local state = { enabled = false }
        e.C_Engraving = engraving(s, state)
        local value, why = p:GetEngravedRunes()
        assert(value == nil and why == 'engraving-unavailable', tostring(why))
        state.enabled = true
        state.max = 0
        value, why = p:GetEngravedRunes()
        assert(value == nil and why == 'rune-data-pending' and s.calls.refresh == 1)
        p:GetEngravedRunes()
        assert(s.calls.refresh == 1, 'rune list refresh requested more than once')
        state.max = 12
        local engraved = assert(p:GetEngravedRunes())

        assert(
            engraved.byRune[6729] == 5
                and engraved.bySpell[400613] == 5
                and engraved.byRune[6800] == 10
                and engraved.bySpell[400624] == 10
        )

        assert(engraved.byRune[6801] == nil and s.calls.slot == 2, 'non-engravable slots were read')
        state.slotError = true
        value, why = p:GetEngravedRunes()
        assert(value == nil and why == 'api-error')
        state.slotError = nil
        local opaque = state.slots[5]
        e.canaccessvalue = function(v) return v ~= opaque end
        value, why = p:GetEngravedRunes()
        assert(value == nil and why == 'restricted-value', 'secret record: ' .. tostring(why))
        e.canaccessvalue = nil
        state.slots[5] = { skillLineAbilityID = 'x' }
        value, why = p:GetEngravedRunes()
        assert(value == nil and why == 'invalid-api-result')
    end
)

test('RUNE_ENGRAVED is true, false and unavailable by rune and by taught spell, and NOT keeps unavailable', function()
    local a, e, s, fire, state = era()
    assert(status(a, node('RUNE_ENGRAVED', { rune = 6729 })) == 'match')
    assert(status(a, node('RUNE_ENGRAVED', { spell = 400624 })) == 'match', 'passive rune by its spell')
    assert(status(a, node('RUNE_ENGRAVED', { spell = 412510 })) == 'no-match')
    assert(status(a, node('RUNE_ENGRAVED', { rune = 6801 }), true) == 'match', 'NOT of an absent rune')
    state.enabled = false
    fire('ENGRAVING_MODE_CHANGED', false)
    local st, why = status(a, node('RUNE_ENGRAVED', { rune = 6729 }), true)
    assert(st == 'unavailable' and why == 'engraving-unavailable', tostring(why))

    -- Other editions: no namespace at all.
    for _, edition in ipairs({ { 5, 1 }, { 1, 12 }, { 18, 12 }, { 19, 4 } }) do
        local f = base(edition[1], edition[2])
        local other = loadAll(f)
        assert(other.definitions.RUNE_ENGRAVED, 'condition not registered on ' .. edition[1])

        local result = other:evaluateConditionResult({
            type = 'NOT',
            value = node('RUNE_ENGRAVED', { spell = 400613 }),
        })

        assert(
            result.status == 'unavailable' and result.reason == 'missing-api',
            edition[1] .. ' ' .. tostring(result.reason)
        )
    end
end)

test('the engraved set is read once per change and refreshed by equipment and rune notifications', function()
    local a, e, s, fire, state, runes = era()
    local value = node('RUNE_ENGRAVED', { spell = 400613 })
    assert(status(a, value) == 'match')
    local reads = s.calls.slot

    for _ = 1, 50 do
        status(a, value)
        status(a, node('RUNE_ENGRAVED', { rune = 6800 }))
    end

    assert(s.calls.slot == reads, 'engraved runes re-read without a notification')
    state.slots[5] = nil
    fire('PLAYER_EQUIPMENT_CHANGED', 5, true)
    assert(status(a, value) == 'no-match' and s.calls.slot == reads + 2)
    state.slots[5] = runes.living
    fire('RUNE_UPDATED', runes.living)
    assert(status(a, value) == 'match')
    state.slots[5] = nil
    fire('UNIT_INVENTORY_CHANGED', 'player')
    assert(status(a, value) == 'no-match')
    state.slots[5] = runes.living
    fire('NEW_RECIPE_LEARNED', 1)
    assert(status(a, value) == 'match')
end)

test('a rune list still loading stays unavailable and resolves without a notification once loaded', function()
    local a, e, s, fire, state = era({ max = 0 })
    local st, why = status(a, node('RUNE_ENGRAVED', { rune = 6729 }), true)
    assert(st == 'unavailable' and why == 'rune-data-pending')
    state.max = 12
    assert(status(a, node('RUNE_ENGRAVED', { rune = 6729 })) == 'match', 'pending list never retried')
end)

test('secret engraving values are unavailable on a restricted client', function()
    local a, e, s, fire, state = era()
    e.canaccessvalue = function(v) return v ~= 400613 end
    fire('RUNE_UPDATED')
    local st, why = status(a, node('RUNE_ENGRAVED', { rune = 6729 }), true)
    assert(st == 'unavailable' and why == 'restricted-value', tostring(why))
end)

test('RUNE_ENGRAVED validation, summaries and help', function()
    local a = era()
    local d = a.definitions.RUNE_ENGRAVED
    assert(d.valid(0, { rune = 6729 }) and d.valid(0, { spell = 400613 }))

    for _, bad in ipairs({
        {},
        { rune = 6729, spell = 400613 },
        { rune = 0 },
        { rune = 1.5 },
        { spell = -1 },
        { spell = '400613' },
        { rune = math.huge },
    }) do
        assert(not d.valid(0, bad))
    end

    assert(d.print(0, { rune = 6729 }):find('Living Bomb', 1, true), 'known rune not named')
    assert(d.print(0, { spell = 999999 }):find('Spell 999999', 1, true), 'unknown rune spell not named')
    local f = base(1, 12)
    local other = loadAll(f)
    local text = other.definitions.RUNE_ENGRAVED.print(0, { rune = 4242 })
    assert(text:find('4242', 1, true), 'raw rune id missing: ' .. text)
    local help = f.widget('help')
    other.definitions.RUNE_ENGRAVED.help(help)
    assert(#F.text(help) > 100)
end)

local function editor(f, tag, value)
    local parent, top = f.widget('parent'), f.widget('top')
    top:SetUserData('root', value)
    top:SetUserData('funcs', { print = function() return 'Updated condition' end })
    parent:SetUserData('top', top)
    f.addon.definitions[tag].widget(parent, 0, value)
    return parent, top
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

test('rune editor picks a known rune by slot, saves its spell, and accepts manual IDs for shared rotations', function()
    local a, e, s, fire, state, runes, f = era()
    local value = {}
    local parent, top = editor(f, 'RUNE_ENGRAVED', value)
    local slot = assert(child(parent, 'Equipment Slot'))
    local rune = assert(child(parent, 'Rune'))
    slot.configure()
    assert(slot.list[1] == 'Chest' and slot.list[2] == 'Hands')
    slot:Fire('OnValueChanged', 2)
    rune.configure()
    assert(rune.list[1] == 'Hot Streak' and rune.list[2] == 'Regeneration')
    rune:Fire('OnValueChanged', 1)
    assert(value.spell == 400624 and value.rune == nil and top.statusText == 'Updated condition')
    assert(a.definitions.RUNE_ENGRAVED.valid(0, value))
    rune:Fire('OnValueChanged', 2)
    assert(value.rune == 6801 and value.spell == nil, 'a rune without a spell keeps its rune ID')
    local spellBox = assert(child(parent, 'Rune Spell ID'))
    spellBox:Fire('OnEnterPressed', '400613')
    assert(value.spell == 400613 and value.rune == nil and a.definitions.RUNE_ENGRAVED.valid(0, value))
    spellBox:Fire('OnEnterPressed', 'junk')
    assert(value.spell == 400613, 'junk replaced a valid ID')
    local runeBox = assert(child(parent, 'Rune ID'))
    runeBox:Fire('OnEnterPressed', '6729')
    assert(value.rune == 6729 and value.spell == nil)
    -- Reopening selects the saved rune.
    parent = editor(f, 'RUNE_ENGRAVED', { spell = 400624 })
    slot = child(parent, 'Equipment Slot')
    slot.configure()
    assert(slot.value == 2)
    -- A client without engraving still opens and keeps a manual ID.
    local g = base(1, 12)
    loadAll(g)
    local kept = { rune = 6729 }
    local other = editor(g, 'RUNE_ENGRAVED', kept)
    assert(F.text(other):find('cannot engrave', 1, true) and kept.rune == 6729)
end)

-- Trait model. Forever: config 7, tree 850, groups Arcane 11 / Fire 12 /
-- Frost 13 (returned out of display order). Nodes: 101 Improved Fireball
-- (Fire, 5 ranks), 102 a choice node (entries 2021 / 2022), 103 a hero node
-- in subtree 90 (Retail only), 104 an unspent Arcane talent.
local function traitsModel(s, state)
    local hit = s.hit
    state.points = state.points or { 5, 20, 0 }

    state.nodes = state.nodes or {
        [101] = {
            ID = 101,
            posX = 1,
            posY = 1,
            entryIDs = { 2011 },
            isVisible = true,
            activeRank = 3,
            maxRanks = 5,
            activeEntry = { entryID = 2011, rank = 3 },
            groupIDs = { 12 },
        },
        [102] = {
            ID = 102,
            posX = 2,
            posY = 1,
            entryIDs = { 2021, 2022 },
            isVisible = true,
            activeRank = 1,
            maxRanks = 1,
            activeEntry = { entryID = 2022, rank = 1 },
            groupIDs = { 13 },
        },
        [103] = {
            ID = 103,
            posX = 1,
            posY = 9,
            entryIDs = { 2031 },
            isVisible = true,
            activeRank = 1,
            maxRanks = 1,
            activeEntry = { entryID = 2031, rank = 1 },
            groupIDs = {},
            subTreeID = 90,
            subTreeActive = false,
        },
        [104] = {
            ID = 104,
            posX = 1,
            posY = 1,
            entryIDs = { 2041 },
            isVisible = true,
            activeRank = 0,
            maxRanks = 2,
            groupIDs = { 11 },
        },
    }

    local traits = {
        GetConfigInfo = function(config)
            hit('config')
            assert(config == 7)
            return { ID = 7, type = 1, name = 'Loadout', treeIDs = { 850 } }
        end,
        GetTreeNodes = function(tree)
            assert(tree == 850)
            return { 101, 102, 103, 104 }
        end,
        GetNodeInfo = function(config, id)
            hit('node')
            assert(config == 7)

            if state.nodeError then
                error('blocked')
            end

            local info = state.nodes[id]

            if info then
                return info
            end

            return { ID = 0, activeRank = 0, maxRanks = 0, entryIDs = {} }
        end,
        GetEntryInfo = function(_, entry) return { definitionID = entry + 1000, maxRanks = 1, type = 1 } end,
        GetDefinitionInfo = function(definition) return { spellID = definition + 5000 } end,
        GetSubTreeInfo = function(_, sub) return { name = 'Hero ' .. sub } end,
    }

    if state.groups ~= false then
        traits.GetGroupDisplayInfoByTreeID = function(tree)
            hit('groups')
            assert(tree == 850)

            return {
                { groupID = 12, treeID = 850, skillLineID = 2, orderIndex = 2, displayName = 'Fire', icon = 2 },
                { groupID = 11, treeID = 850, skillLineID = 1, orderIndex = 1, displayName = 'Arcane', icon = 1 },
                { groupID = 13, treeID = 850, skillLineID = 3, orderIndex = 3, displayName = 'Frost', icon = 3 },
            }
        end

        traits.GetGroupCurrencyInfo = function(config, ids)
            hit('spent')
            assert(config == 7 and #ids == 3)
            local out = {}

            for index, id in ipairs({ 11, 12, 13 }) do
                out[#out + 1] = {
                    traitNodeGroupID = id,
                    currencyInfos = { { traitCurrencyID = 1, quantity = 0, spent = state.points[index] } },
                }
            end

            return out
        end
    end

    return {
        GetActiveConfigID = function()
            hit('active')
            return state.config == nil and 7 or state.config
        end,
    },
        traits
end

local function traitsClient(project, state)
    local f, e, s, fire = base(project, 12)
    state = state or {}
    e.C_ClassTalents, e.C_Traits = traitsModel(s, state)
    local a = loadAll(f)
    return a, e, s, fire, state, f
end

local function talent(nodeID, operator, rank, entry)
    return node('TALENT', { layout = 'traits', node = nodeID, entry = entry, operator = operator, value = rank })
end

test('traits reader: active config, Forever trees in display order, node state and its failures', function()
    local _, e, s, _, state, f = traitsClient(18)
    local p = f.addon.Platform
    local config, tree = p:GetActiveTraitConfig()
    assert(config == 7 and tree == 850)
    local groups = assert(p:GetTraitTreeGroups())
    assert(groups[1].name == 'Arcane' and groups[2].name == 'Fire' and groups[3].name == 'Frost')
    assert(groups[1].pointsSpent == 5 and groups[2].pointsSpent == 20 and groups[3].pointsSpent == 0)

    assert(
        p:GetTalentTreeCount() == 3
            and p:GetTalentTreeInfo(2).name == 'Fire'
            and p:GetTalentTreeInfo(2).pointsSpent == 20
    )

    assert(p:GetPrimaryTalentTree().index == 2)
    local st = assert(p:GetTraitNodeState(7, 101))
    assert(st.rank == 3 and st.entry == 2011 and st.maxRanks == 5)
    assert(p:GetTraitNodeState(7, 103).rank == 0, 'an unchosen hero subtree counted')
    local value, why = p:GetTraitNodeState(7, 999)
    assert(value == nil and why == 'talent-node-unavailable')
    state.nodeError = true
    value, why = p:GetTraitNodeState(7, 101)
    assert(value == nil and why == 'api-error')
    state.nodeError = nil
    state.config = false
    e.C_ClassTalents.GetActiveConfigID = function() return nil end
    value, why = p:GetActiveTraitConfig()
    assert(value == nil and why == 'talent-config-unavailable')
    -- Classic clients do not take the traits path.
    local g = base(2, 0)
    g.load('Platform/talents.lua')
    value, why = g.addon.Platform:GetActiveTraitConfig()
    assert(value == nil and why == 'talent-layout-mismatch')
end)

for _, edition in ipairs({ { 18, 'Forever' }, { 1, 'Retail' } }) do
    test(
        edition[2] .. ' TALENT compares a node rank, a choice entry and stays unavailable under NOT when unreadable',
        function()
            local a, e, s, fire, state = traitsClient(edition[1])
            assert(status(a, talent(101, 'GREATERTHANOREQUALS', 3)) == 'match')
            assert(status(a, talent(101, 'EQUALS', 5)) == 'no-match')
            assert(status(a, talent(102, 'GREATERTHANOREQUALS', 1, 2022)) == 'match', 'chosen entry')
            assert(status(a, talent(102, 'GREATERTHANOREQUALS', 1, 2021)) == 'no-match', 'unchosen entry has rank zero')
            assert(status(a, talent(103, 'GREATERTHANOREQUALS', 1)) == 'no-match', 'unchosen hero subtree')
            local st, why = status(a, talent(999, 'GREATERTHAN', 0), true)
            assert(st == 'unavailable' and why == 'talent-node-unavailable', tostring(why))
            local opaque = {}
            state.nodes[101].activeRank = opaque
            e.canaccessvalue = function(v) return v ~= opaque end
            fire('TRAIT_CONFIG_UPDATED', 7)
            st, why = status(a, talent(101, 'GREATERTHAN', 0), true)
            assert(st == 'unavailable' and why == 'restricted-value', 'secret rank: ' .. tostring(why))
        end
    )
end

test('trait ranks are read once per talent change and refresh on trait notifications', function()
    local a, e, s, fire, state = traitsClient(18)
    local value = talent(101, 'GREATERTHANOREQUALS', 3)
    assert(status(a, value) == 'match')
    local reads = s.calls.node

    for _ = 1, 50 do
        status(a, value)
        status(a, talent(999, 'GREATERTHAN', 0))
    end

    assert(s.calls.node == reads + 1, 'node re-read without a notification: ' .. (s.calls.node - reads))
    state.nodes[101].activeRank = 0
    fire('TRAIT_CONFIG_UPDATED', 7)
    assert(status(a, value) == 'no-match')
    state.nodes[101].activeRank = 5
    fire('PLAYER_TALENT_UPDATE')
    assert(status(a, value) == 'match')
    state.nodes[103].subTreeActive = true
    fire('TRAIT_SUB_TREE_CHANGED', 7, 90)
    assert(status(a, talent(103, 'EQUALS', 1)) == 'match')
end)

test('Forever TALENT_TREE_POINTS and PRIMARY_TALENT_TREE read the three trees; Retail has none', function()
    local a, e, s, fire, state = traitsClient(18)
    assert(status(a, node('TALENT_TREE_POINTS', { tree = 2, operator = 'GREATERTHANOREQUALS', value = 20 })) == 'match')
    assert(status(a, node('TALENT_TREE_POINTS', { tree = 3, operator = 'EQUALS', value = 0 })) == 'match')

    assert(
        status(a, node('PRIMARY_TALENT_TREE', { tree = 2 })) == 'match'
            and status(a, node('PRIMARY_TALENT_TREE', { tree = 1 })) == 'no-match'
    )

    local st, why = status(a, node('TALENT_TREE_POINTS', { tree = 4, operator = 'EQUALS', value = 0 }), true)
    assert(st == 'unavailable' and why == 'talent-tree-unavailable')
    local calls = s.calls.spent

    for _ = 1, 20 do
        status(a, node('PRIMARY_TALENT_TREE', { tree = 2 }))
    end

    assert(s.calls.spent == calls, 'trees re-read per evaluation')
    state.points = { 20, 20, 0 }
    fire('TRAIT_TREE_CURRENCY_INFO_UPDATED', 850)
    st, why = status(a, node('PRIMARY_TALENT_TREE', { tree = 2 }), true)
    assert(st == 'unavailable' and why == 'ambiguous-primary-talent-tree')
    state.points = { 0, 0, 0 }
    fire('TRAIT_CONFIG_UPDATED', 7)
    st, why = status(a, node('PRIMARY_TALENT_TREE', { tree = 1 }), true)
    assert(st == 'unavailable' and why == 'no-talents-spent')

    assert(
        status(a, node('TALENT_TREE_POINTS', { tree = 1, operator = 'EQUALS', value = 0 })) == 'match',
        'an unspent tree is a real zero'
    )

    local r = traitsClient(1, { groups = false })
    st, why = status(r, node('TALENT_TREE_POINTS', { tree = 1, operator = 'EQUALS', value = 0 }), true)
    assert(st == 'unavailable' and why == 'missing-api', tostring(why))
    st = status(r, node('PRIMARY_TALENT_TREE', { tree = 1 }), true)
    assert(st == 'unavailable')
end)

test('classic clients keep their talent paths and leave a traits reference unavailable', function()
    local f, e = base(2, 0)
    e.GetNumTalentTabs = function() return 3 end
    e.GetNumTalents = function() return 2 end
    e.GetTalentTabInfo = function(tree) return 'Tree ' .. tree, 1, tree == 2 and 5 or 0 end
    e.GetTalentInfo = function() return 'Improved Fireball', 1, 1, 1, 2, 5, true, 0, false, false, false, 101 end
    local a = loadAll(f)
    assert(status(a, node('TALENT', { tree = 1, talent = 1, operator = 'EQUALS', value = 2 })) == 'match')
    assert(status(a, node('PRIMARY_TALENT_TREE', { tree = 2 })) == 'match')
    local st, why = status(a, talent(101, 'GREATERTHAN', 0), true)
    assert(st == 'unavailable' and why == 'talent-layout-mismatch', tostring(why))
end)

test('TALENT traits validation and summaries', function()
    local a = traitsClient(18)
    local d = a.definitions.TALENT

    assert(
        d.valid(0, { layout = 'traits', node = 101, operator = 'EQUALS', value = 1 }) and d.valid(0, {
            layout = 'traits',
            node = 102,
            entry = 2022,
            operator = 'GREATERTHAN',
            value = 0,
        })
    )

    for _, bad in ipairs({
        { layout = 'traits', node = 0, operator = 'EQUALS', value = 1 },
        { layout = 'traits', node = 101, entry = 1.5, operator = 'EQUALS', value = 1 },
        { layout = 'traits', node = 101, operator = 'TYPO', value = 1 },
        { layout = 'traits', node = 101, operator = 'EQUALS', value = 65 },
        { layout = 'traits', node = 101, tree = 1, operator = 'EQUALS', value = 1 },
        { tree = 1, talent = 1, node = 101, operator = 'EQUALS', value = 1 },
        { layout = 'grid', value = 3, node = 101 },
    }) do
        assert(not d.valid(0, bad), 'accepted a malformed traits reference')
    end

    assert(
        d.valid(0, { tree = 1, talent = 1, operator = 'EQUALS', value = 2 }) and d.valid(0, {
            layout = 'grid',
            value = 3,
        }),
        'older layouts rejected'
    )

    assert(
        d.print(0, { layout = 'traits', node = 101, operator = 'EQUALS', value = 1 }):find('Spell 8011', 1, true),
        'talent not named'
    )

    assert(
        d.print(0, { layout = 'traits', node = 102, entry = 2021, operator = 'EQUALS', value = 1 }):find(
            'Spell 8021',
            1,
            true
        ),
        'choice entry not named'
    )

    local f = base(2, 0)
    local classic = loadAll(f)

    assert(classic.definitions.TALENT.print(0, { layout = 'traits', node = 4242, operator = 'EQUALS', value = 1 }):find(
        '4242',
        1,
        true
    ))

    local help = f.widget('help')
    classic.definitions.TALENT.help(help)
    assert(F.text(help):find('Retail and Forever', 1, true))
end)

test(
    'trait editor groups talents by tree, writes node, entry and a rank on an explicit choice, and keeps manual IDs',
    function()
        local a, e, s, fire, state, f = traitsClient(18)
        local value = { tree = 1, talent = 2, operator = 'EQUALS', value = 2 }
        local parent, top = editor(f, 'TALENT', value)

        assert(
            F.text(parent):find('another talent layout', 1, true) and value.tree == 1,
            'viewing converted an old reference'
        )

        local trees = assert(child(parent, 'Talent Tree'))
        trees.configure()

        assert(
            trees.list[1] == 'Arcane'
                and trees.list[2] == 'Fire'
                and trees.list[3] == 'Frost'
                and trees.list[4] == 'Hero talents: Hero 90'
        )

        local picker = assert(child(parent, 'Talent'))
        trees:Fire('OnValueChanged', 3)
        picker.configure()

        assert(
            picker.list[1].text == 'Spell 8021 (choice)'
                and picker.list[2].text == 'Spell 8022 (choice)'
                and picker.list[1].icon,
            'talent list shows name and icon'
        )

        picker:Fire('OnValueChanged', 2)

        assert(
            value.layout == 'traits'
                and value.node == 102
                and value.entry == 2022
                and value.tree == nil
                and value.talent == nil
        )

        assert(
            value.operator == 'GREATERTHANOREQUALS'
                and value.value == 1
                and a.definitions.TALENT.valid(0, value)
                and top.statusText == 'Updated condition'
        )

        trees:Fire('OnValueChanged', 2)
        picker.configure()
        picker:Fire('OnValueChanged', 1)

        assert(
            value.node == 101 and value.entry == nil and value.operator == 'GREATERTHANOREQUALS',
            'a later pick reset the chosen rank'
        )

        local nodeBox = assert(child(parent, 'Talent Node ID'))
        nodeBox:Fire('OnEnterPressed', '4242')
        assert(value.node == 4242 and a.definitions.TALENT.valid(0, value))
        nodeBox:Fire('OnEnterPressed', 'abc')
        assert(value.node == 4242)
        local entryBox = assert(child(parent, 'Choice Entry ID'))
        entryBox:Fire('OnEnterPressed', '77')
        assert(value.entry == 77)
        entryBox:Fire('OnEnterPressed', '')
        assert(value.entry == nil)
        -- Reopening selects the saved talent; hero talents group by subtree on Retail.
        parent = editor(f, 'TALENT', { layout = 'traits', node = 101, operator = 'EQUALS', value = 1 })
        trees = child(parent, 'Talent Tree')
        trees.configure()
        assert(trees.value == 2)
        local r, _, _, _, _, g = traitsClient(1, { groups = false })
        parent = editor(g, 'TALENT', {})
        trees = assert(child(parent, 'Talent Tree'))
        trees.configure()

        assert(
            trees.list[1] == 'Class and specialization talents' and trees.list[2] == 'Hero talents: Hero 90',
            tostring(trees.list[1]) .. '/' .. tostring(trees.list[2])
        )
    end
)

test('RUNE_ENGRAVED joins the Character category and Switch picker once per profile', function()
    local f = base(2, 0)
    local a = loadAll(f)
    f.load('Core/unit_state_conditions.lua')

    local profile = {
        condition_groups = { { id = 'b8136123-2bda-4230-a77a-89ea2aed3a1a', conditions = { 'TALENT' } } },
        switch_conditions = { 'CLASS' },
    }

    a:InitializeUnitStateConditions(nil, { profile = profile })

    local function has(list)
        local n = 0

        for _, tag in ipairs(list) do
            if tag == 'RUNE_ENGRAVED' then
                n = n + 1
            end
        end

        return n
    end

    assert(
        profile.engravingConditionsSeeded
            and has(profile.condition_groups[1].conditions) == 1
            and has(profile.switch_conditions) == 1
    )

    for i = #profile.switch_conditions, 1, -1 do
        if profile.switch_conditions[i] == 'RUNE_ENGRAVED' then
            table.remove(profile.switch_conditions, i)
        end
    end

    a:InitializeUnitStateConditions(nil, { profile = profile })

    assert(
        has(profile.switch_conditions) == 0 and has(profile.condition_groups[1].conditions) == 1,
        'a removed choice came back'
    )

    f.load('Data/plain.lua')

    assert(
        a:ValidateProfileTransfer({ engravingConditionsSeeded = true })
            and not a:ValidateProfileTransfer({ engravingConditionsSeeded = 'yes' })
    )
end)

finish()
