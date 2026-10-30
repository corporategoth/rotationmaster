-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The editor's spell pickers on every client family: the spellbook ("Spell")
-- view lists what the character can cast for the rotation's specialization,
-- and a spell picked from either view is stored and shown again.
--
-- The Retail model follows Blizzard's generated 12.x documentation
-- (Gethe/wow-ui-source live, Blizzard_APIDocumentationGenerated):
-- SpellBookDocumentation.lua (SpellBookItemInfo: actionID = base spell,
-- spellID = override or nil for non-spells, itemType, isPassive, isOffSpec,
-- skillLineIndex; SpellBookSkillLineInfo: itemIndexOffset, numSpellBookItems,
-- isGuild, shouldHide, specID?, offSpecID?), SpellBookConstantsDocumentation.lua
-- (SpellBookSkillLineIndex General=1 Class=2 MainSpec=3 OffSpecStart=4;
-- SpellBookItemType None=0 Spell=1 FutureSpell=2 PetAction=3 Flyout=4;
-- SpellBookSpellBank Player=0 Pet=1), SpellDocumentation.lua (C_Spell.GetSpellInfo
-- returns a SpellInfo table, nil when not found) and
-- Blizzard_SharedXML/UnitUtil.lua IsInitialSpec (below level 10 the active
-- specialization index is greater than GetNumSpecializations()).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local RETAIL, ERA, TBC, MISTS, FOREVER = 1, 2, 5, 19, 18

local MONK = {
    [100780] = { name = 'Tiger Palm' },
    [100784] = { name = 'Blackout Kick' },
    [109132] = { name = 'Roll' },
    [107428] = { name = 'Rising Sun Kick' },
    [467307] = { name = 'Rushing Wind Kick' },
    [113656] = { name = 'Fists of Fury' },
    [121253] = { name = 'Keg Smash' },
    [115175] = { name = 'Soothing Mist' },
    [6603] = { name = 'Auto Attack' },
    [125439] = { name = 'Revive Battle Pets' },
    [83958] = { name = 'Mobile Banking' },
    [157411] = { name = 'Windwalking' },
    [116645] = { name = 'Teachings of the Monastery' },
    [101545] = { name = 'Flying Serpent Kick' },
    [1] = { name = 'Zen Flight' },
}

local function spellRecord(id)
    local data = MONK[id]

    if not data then
        return nil
    end

    return {
        name = data.name,
        iconID = 1000 + id % 997,
        originalIconID = 1000 + id % 997,
        castTime = 0,
        minRange = 0,
        maxRange = 5,
        spellID = id,
    }
end

-- Retail: no global GetSpellInfo/GetSpellLink (moved to C_Spell in 11.0).
local function retailSpellAPI(env)
    env.GetSpellInfo = nil
    env.GetSpellLink = nil
    local byName = {}

    for id, data in pairs(MONK) do
        byName[data.name:lower()] = id
    end

    local function resolve(value)
        if type(value) == 'number' then
            return value
        end
        if type(value) == 'string' then
            return tonumber(value:match('|Hspell:(%d+)')) or byName[value:lower()]
        end
    end

    env.C_Spell = {
        GetSpellInfo = function(value) return spellRecord(resolve(value)) end,
        GetSpellLink = function(value)
            local id = resolve(value)
            return MONK[id] and ('|cff71d5ff|Hspell:' .. id .. ':0|h[' .. MONK[id].name .. ']|h|r') or nil
        end,
        GetSpellSubtext = function(value) return MONK[resolve(value)] and '' or nil end,
    }
end

-- Slots per skill line; t = item type (1 spell, 2 future, 3 pet action, 4 flyout).
local function retailBook(options)
    options = options or {}

    local lines = {
        {
            name = 'General',
            items = {
                { t = 1, id = 6603 },
                { t = 1, id = 125439 },
                { t = 1, id = 83958, passive = true },
                { t = 4, action = 4 },
            },
        },
        {
            name = 'Monk',
            items = {
                { t = 1, id = 100780 },
                { t = 1, id = 100784 },
                { t = 1, id = 109132 },
                { t = 2, id = 101545 },
                { t = 1, id = 157411, passive = true },
            },
        },
    }

    if options.spec then
        lines[#lines + 1] = { name = 'Spec', specID = options.spec, items = options.specItems or {} }

        for _, off in ipairs(options.offspecs or {}) do
            lines[#lines + 1] = { name = 'Off', offSpecID = off.id, shouldHide = true, items = off.items }
        end
    end

    local slots, offset = {}, 0

    for index, line in ipairs(lines) do
        line.offset = offset

        for position, item in ipairs(line.items) do
            slots[offset + position] = { item = item, line = line, index = index }
        end

        offset = offset + #line.items
    end

    return lines, slots
end

local function installRetail(env, options)
    options = options or {}
    retailSpellAPI(env)
    env.Enum.SpellBookSpellBank = { Player = 0, Pet = 1 }
    env.Enum.SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 }
    env.Enum.SpellBookSkillLineIndex = { General = 1, Class = 2, MainSpec = 3, OffSpecStart = 4 }
    local lines, slots = retailBook(options)

    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return #lines end,
        GetSpellBookSkillLineInfo = function(index)
            local line = lines[index]

            if not line then
                return nil
            end

            return {
                name = line.name,
                iconID = 1,
                itemIndexOffset = line.offset,
                numSpellBookItems = #line.items,
                isGuild = false,
                shouldHide = line.shouldHide == true,
                specID = line.specID,
                offSpecID = line.offSpecID,
            }
        end,
        GetSpellBookItemInfo = function(slot, bank)
            if bank == 1 then
                return nil
            end

            local entry = slots[slot]

            if not entry then
                return nil
            end

            local item = entry.item

            if options.malformed and options.malformed(slot, item) then
                return options.malformed(slot, item)
            end
            if item.t == 4 then
                return {
                    actionID = item.action,
                    itemType = 4,
                    name = 'Flyout',
                    subName = '',
                    iconID = 1,
                    isPassive = false,
                    isOffSpec = false,
                    skillLineIndex = entry.index,
                }
            end

            return {
                actionID = item.base or item.id,
                spellID = item.id,
                itemType = item.t,
                name = MONK[item.id].name,
                subName = '',
                iconID = 1,
                isPassive = item.passive == true,
                isOffSpec = entry.line.offSpecID ~= nil,
                skillLineIndex = entry.index,
            }
        end,
        HasPetSpells = function() return nil end,
    }

    -- Monk specializations: Brewmaster 268, Windwalker 269, Mistweaver 270;
    -- index 5 is the initial specialization (1450) below level 10.
    local specs = { 268, 269, 270 }
    local names = { [268] = 'Brewmaster', [269] = 'Windwalker', [270] = 'Mistweaver', [1450] = 'Initial' }
    local index = options.specIndex or 5

    env.C_SpecializationInfo = {
        GetSpecialization = function() return index end,
        GetSpecializationInfo = function(i) return i == 5 and 1450 or specs[i], names[i == 5 and 1450 or specs[i]] end,
        GetNumSpecializationsForClassID = function(classID)
            assert(classID == 10)
            return 3
        end,
    }

    env.GetSpecializationInfoForClassID = function(classID, i)
        assert(classID == 10)
        return specs[i], names[specs[i]], '', 1
    end

    env.UnitClass = function() return 'Monk', 'MONK', 10 end
end

local function retailFixture(options)
    local f = F.new(RETAIL, 11, 'MONK')
    installRetail(f.env, options)
    f.load('Platform/spells.lua')
    f.load('Platform/spellbook.lua')
    local a = f.addon
    local selection = assert(a.Platform:GetRotationSpecialization())
    a.currentSpec = selection.key
    return f, a
end

-- Snapshot ------------------------------------------------------------------
test('Retail 12.x spellbook: lines, future/flyout/passive items and the shared lines are read', function()
    local f, a = retailFixture()
    local book = a.Platform:GetSpellBookSnapshot()

    assert(
        book.player.complete and book.player.skipped == 0 and book.player.hasOtherItems,
        'book incomplete: ' .. tostring(book.player.reason)
    )

    local byID = {}

    for _, entry in ipairs(book.player.entries) do
        byID[entry.spellID] = entry
    end

    assert(
        byID[100784]
            and byID[100784].shared == true
            and byID[100784].isPassive == false
            and byID[100784].isOffSpec == false
    )

    assert(byID[83958].isPassive == true and byID[101545] == nil, 'passive or future spell misread')
    assert(book.pet.complete and #book.pet.entries == 0)
end)

test('one malformed item is skipped and counted instead of emptying the book', function()
    for _, bad in ipairs({
        function(slot)
            if slot == 5 then
                return { itemType = 'spell' }
            end
        end,  -- wrong type
        function(slot)
            if slot == 5 then
                return { itemType = 1, actionID = 100780, isPassive = false, isOffSpec = false }
            end
        end,  -- spellID nil
        function(slot)
            if slot == 5 then
                return { itemType = 1, spellID = 100780, actionID = 100780, isPassive = 'no', isOffSpec = false }
            end
        end,
        function(slot)
            if slot == 5 then
                error('native item failure')
            end
        end,
        function(slot)
            if slot == 5 then
                return 'not a table'
            end
        end,
    }) do
        local f, a = retailFixture({ malformed = bad })
        local book = a.Platform:GetSpellBookSnapshot()

        assert(
            book.player.complete and book.player.skipped == 1 and book.player.skipReason,
            'a single bad item failed the book: ' .. tostring(book.player.reason)
        )

        local found

        for _, entry in ipairs(book.player.entries) do
            if entry.spellID == 100784 then
                found = true
            end
        end

        assert(found, 'Blackout Kick lost to a neighbouring bad item')
    end
end)

test('documented-but-missing optional fields do not reject a spell: nil isOffSpec and nil actionID', function()
    local f, a = retailFixture({
        malformed = function(slot)
            if slot == 6 then
                return { itemType = 1, spellID = 100784, isPassive = false }
            end
        end,
    })

    local book = a.Platform:GetSpellBookSnapshot()
    assert(book.player.complete and book.player.skipped == 0)
    local entry

    for _, e in ipairs(book.player.entries) do
        if e.spellID == 100784 then
            entry = e
        end
    end

    assert(entry and entry.isOffSpec == false and entry.baseSpellID == nil)
end)

test('restricted single items are skipped; a book with nothing readable stays unavailable', function()
    local opaque = {}

    local f, a = retailFixture({
        malformed = function(slot)
            if slot == 6 then
                return { itemType = 1, spellID = opaque, actionID = opaque, isPassive = false, isOffSpec = false }
            end
        end,
    })

    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    local book = a.Platform:GetSpellBookSnapshot()
    assert(book.player.complete and book.player.skipped == 1 and book.player.skipReason == 'restricted-value')

    f, a = retailFixture({
        malformed = function()
            error('every item fails')
        end,
    })

    book = a.Platform:GetSpellBookSnapshot()
    assert(not book.player.complete and book.player.reason == 'api-error' and #book.player.entries == 0)
end)

test('a malformed skill line is skipped without discarding the other lines', function()
    local f, a = retailFixture()
    local info = f.env.C_SpellBook.GetSpellBookSkillLineInfo

    f.env.C_SpellBook.GetSpellBookSkillLineInfo = function(index)
        if index == 1 then
            return { itemIndexOffset = 'x' }
        end

        return info(index)
    end

    local book = a.Platform:GetSpellBookSnapshot()
    assert(book.player.complete and book.player.skipped == 1)
    local found

    for _, entry in ipairs(book.player.entries) do
        if entry.spellID == 100784 then
            found = true
        end
    end

    assert(found)
end)

-- Attribution and the Spells view --------------------------------------------
local function spellsView(a, spec, text)
    local rows, status = a.SpellCatalog:Search(text or '', { spec = spec, norank = true, limit = 100 })
    local ids = {}

    for _, row in ipairs(rows or {}) do
        ids[row.id] = true
    end

    return ids, status
end

test('a level-4 Monk (initial specialization) sees Blackout Kick in every specialization’s Spells view', function()
    local f, a = retailFixture()
    assert(a.currentSpec == 1450, 'fixture is not on the initial specialization')
    a:RefreshSpellCatalog()

    for _, spec in ipairs({ 268, 269, 270 }) do
        local ids, status = spellsView(a, spec)

        assert(
            ids[100784] and ids[100780] and ids[6603],
            'spec ' .. spec .. ' Spells view misses class spells: ' .. tostring(status.reason)
        )

        assert(not ids[83958] and not ids[101545], 'passive or future spell offered as an action')
        assert(a.isSpellOnSpec(spec, 100784) and a.getSpecSpellID(spec, 'Blackout Kick') == 100784)
    end

    assert(a.SpellCatalog:ResolveSelection('Blackout Kick', { spec = 269 }) == 100784)
end)

test('at level 80 class lines are shared, the active spec line and off-spec lines are not', function()
    local f, a = retailFixture({
        specIndex = 2,
        spec = 269,
        specItems = { { t = 1, id = 113656 } },
        offspecs = {
            { id = 268, items = { { t = 1, id = 121253 } } },
            { id = 270, items = { { t = 1, id = 115175 } } },
        },
    })

    assert(a.currentSpec == 269)
    a:RefreshSpellCatalog()
    local ww, bm, mw = spellsView(a, 269), spellsView(a, 268), spellsView(a, 270)
    assert(ww[100784] and bm[100784] and mw[100784], 'class spell not shared')
    assert(ww[113656] and not bm[113656] and not mw[113656], 'active spec spell leaked to other specs')
    assert(bm[121253] and not ww[121253] and mw[115175] and not ww[115175], 'off-spec line misattributed')
end)

test('override spells: the book lists the override and still accepts the base spell', function()
    local f, a = retailFixture({ specIndex = 2, spec = 269, specItems = { { t = 1, id = 467307, base = 107428 } } })
    a:RefreshSpellCatalog()
    local ids = spellsView(a, 269)
    assert(ids[467307] and ids[107428], 'override or its base missing from the Spells view')
    assert(a.SpellCatalog:ResolveSelection('107428', { spec = 269 }) == 107428)
    assert(a.isSpellOnSpec(269, 107428) and not a.isSpellOnSpec(268, 467307))
end)

test('talent-group and single-key clients keep their spellbook attribution unchanged', function()
    local f = F.new(MISTS, 5, 'MONK')
    local a = f.addon

    f.env.GetSpellInfo = function(id)
        local r = spellRecord(id)

        if r then
            return r.name, '', r.iconID, 0, 0, 5, id
        end
    end

    f.env.GetSpellLink = function(id) return '|Hspell:' .. id .. '|h' end
    f.env.GetNumSpellTabs = function() return 2 end

    f.env.GetSpellTabInfo = function(i)
        if i == 1 then
            return 'Monk', 1, 0, 2, false, 0
        end

        return 'Brewmaster', 1, 2, 1, false, 268
    end

    f.env.GetSpellBookItemInfo = function(slot) return 'SPELL', ({ 100780, 100784, 121253 })[slot] end
    f.env.IsPassiveSpell = function() return false end
    f.env.HasPetSpells = function() return nil end
    f.env.GetActiveTalentGroup = function() return 1 end
    f.env.GetNumTalentGroups = function() return 2 end
    f.env.UnitClass = function() return 'Monk', 'MONK', 10 end
    f.load('Platform/spells.lua')
    f.load('Platform/spellbook.lua')
    a.currentSpec = assert(a.Platform:GetRotationSpecialization()).key
    a:RefreshSpellCatalog()
    assert(a.currentSpec == 1 and a.specSpells[1][100784] and a.specSpells[268][121253])
    assert(a.specSpells[2] == nil, 'a talent group received another group’s spells')
end)

-- Picking and keeping a spell -------------------------------------------------
local function editorFixture(product, expansion, install, step)
    local f = F.new(product, expansion, 'MONK')
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    f.nativeFrames = frames
    dofile('tests/fixtures/spell_editbox.lua')(f, create)
    install(f.env)
    f.load('Platform/spells.lua')
    f.load('Platform/spellbook.lua')
    local selection = a.Platform:GetRotationSpecialization()
    a.currentSpec = selection and selection.key or 0
    a:RefreshSpellCatalog()
    local spec = step.spec or a.currentSpec

    a.db.profile.rotations = {
        [spec] = {
            mine = {
                name = 'Mine',
                switch = {},
                rotation = { { id = 'step', type = step.type, conditions = {} } },
                cooldowns = {},
            },
        },
    }

    a.configPaneGeneration = 1

    function a:GetEditableRotation(s, id)
        return self.db.profile.rotations[s] and self.db.profile.rotations[s][id]
    end

    function a:GetDefaultIdForRuntime() end

    function a:ListDefaultRotations()
        return {}
    end

    function a:GetImportValidationOptions()
        return {}
    end

    function a:validateCondition()
        return true
    end

    a.UpdateAutoSwitch = function() end
    a.SwitchRotation = function() end
    a.EvaluateNextAction = function() end

    for _, file in ipairs({
        'Platform/spells.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua', 'Data/rotation_draft.lua',
        'Data/validation.lua', 'Core/rotation_editor.lua', 'Core/rotation_workspace.lua', 'Core/rotation_tags.lua',
        'Core/rotation_canvas.lua', 'UI/window.lua'
    }) do
        f.load(file)
    end

    for _, file in ipairs({
        'UI/rotation_cards.lua', 'UI/rotation_canvas.lua', 'UI/color_picker.lua', 'UI/rotation_effect_fields.lua',
        'UI/rotation_fields.lua', 'UI/rotation_navigation.lua', 'UI/rotation_metadata.lua', 'UI/rotation_view.lua',
        'UI/rotation_editor.lua'
    }) do
        local h = io.open(file)

        if h then
            h:close()
            f.load(file)
        end
    end

    dofile('tests/fixtures/rotation_header_backend.lua')(a, f.env.DEFAULT, f.env.NEW)
    local parent = create('Frame')
    parent:SetSize(740, 600)
    local pane = assert(a:CreateRotationEditor(parent, spec, 'mine'))

    local function card()
        for _, c in ipairs(pane.canvas.cards) do
            if c.model and c.model.id == 'step' and c.frame:IsShown() then
                return c
            end
        end
    end

    card().action:Click()
    return f, a, pane, card, spec, parent
end

local function pick(card, query, want)
    local field = card().fieldControls.spell
    field:SetFocus()
    field.editbox:SetText(query)
    local popup = field.rmSpellPopup
    local row

    for _, candidate in ipairs(popup.rows) do
        if candidate:IsShown() and candidate.spellID == want then
            row = candidate
        end
    end

    assert(row, 'suggestions do not offer ' .. want .. ': ' .. tostring(popup.footer:GetText()))
    row.scripts.OnMouseDown(row, 'LeftButton')
end

local function legacyAPI(env)
    env.C_Spell = nil
    env.C_SpellBook = nil

    env.GetSpellInfo = function(value)
        local id = type(value) == 'number' and value or tonumber(value)

        if not id and type(value) == 'string' then
            for key, data in pairs(MONK) do
                if data.name:lower() == value:lower() then
                    id = key
                end
            end
        end

        local r = spellRecord(id)

        if r then
            return r.name, '', r.iconID, 0, 0, 5, id
        end
    end

    env.GetSpellLink = function(id) return MONK[id] and ('|Hspell:' .. id .. '|h[' .. MONK[id].name .. ']|h') end
    env.GetNumSpellTabs = function() return 1 end
    env.GetSpellTabInfo = function() return 'General', 1, 0, 2, false, 0 end
    env.GetSpellBookItemInfo = function(slot) return 'SPELL', ({ 100780, 100784 })[slot] end
    env.IsPassiveSpell = function() return false end
    env.HasPetSpells = function() return nil end
    env.GetActiveTalentGroup = function() return 1 end
    env.GetNumTalentGroups = function() return 2 end
end

local editions = {
    {
        name = 'Retail',
        product = RETAIL,
        expansion = 11,
        install = function(env)
            installRetail(env)
        end,
        spec = 269,
    },
    { name = 'Era', product = ERA, expansion = 0, install = legacyAPI },
    { name = 'TBC', product = TBC, expansion = 1, install = legacyAPI },
    { name = 'Mists', product = MISTS, expansion = 4, install = legacyAPI },
    {
        name = 'Forever',
        product = FOREVER,
        expansion = 0,
        install = function(env)
            installRetail(env, { specIndex = 1 })
            env.C_SpecializationInfo.GetNumSpecializationsForClassID = function() return 1 end

            env.GetSpecializationInfoForClassID = function(_, i)
                if i == 1 then
                    return 268, 'Monk', '', 1
                end
            end
        end,
    },
}

for _, edition in ipairs(editions) do
    test(edition.name .. ': a spell picked from Any Spell is stored, redrawn, saved and reopened', function()
        local f, a, pane, card, spec, parent = editorFixture(edition.product, edition.expansion, edition.install, {
            type = 'any',
            spec = edition.spec,
        })

        pick(card, 'Blackout', 100784)
        assert(pane.workspace:Snapshot().rotation[1].action == 100784, 'pick not stored')
        assert(card().fieldControls.spell:GetText() == 'Blackout Kick', 'field does not show the pick after redraw')
        pane:Render()
        assert(card().fieldControls.spell:GetText() == 'Blackout Kick')
        assert(pane:Apply() and a:GetEditableRotation(spec, 'mine').rotation[1].action == 100784, 'pick not saved')
        local reopened = assert(a:CreateRotationEditor(parent, spec, 'mine'))
        local c

        for _, candidate in ipairs(reopened.canvas.cards) do
            if candidate.model and candidate.model.id == 'step' and candidate.frame:IsShown() then
                c = candidate
            end
        end

        c.action:Click()

        for _, candidate in ipairs(reopened.canvas.cards) do
            if candidate.model and candidate.model.id == 'step' and candidate.frame:IsShown() then
                c = candidate
            end
        end

        assert(c.fieldControls.spell:GetText() == 'Blackout Kick', 'reopened field lost the pick')
    end)

    test(edition.name .. ': a spell picked from the Spells view is stored and kept', function()
        local f, a, pane, card = editorFixture(edition.product, edition.expansion, edition.install, {
            type = 'spell',
            spec = edition.spec,
        })

        pick(card, 'Blackout', 100784)

        assert(
            pane.workspace:Snapshot().rotation[1].action == 100784
                and card().fieldControls.spell:GetText() == 'Blackout Kick'
        )
    end)
end

test('Retail initial specialization: the Spell Available condition keeps a spellbook pick', function()
    local f = F.new(RETAIL, 11, 'MONK')
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    dofile('tests/fixtures/spell_editbox.lua')(f, create)
    installRetail(f.env)

    f.env.GameTooltip = {
        IsOwned = function() return false end,
        IsVisible = function() return false end,
        Hide = function() end,
    }

    for _, path in ipairs({
        'Platform/spells.lua',
        'Platform/spellbook.lua',
        'Conditions/common.lua',
        'Conditions/spell.lua',
    }) do
        f.load(path)
    end

    a.currentSpec = a.Platform:GetRotationSpecialization().key
    a:RefreshSpellCatalog()
    local top = f.widget('top')
    top:SetUserData('root', {})
    top:SetUserData('funcs', { print = function() return '' end })
    local parent = f.widget('parent')
    parent:SetUserData('top', top)
    local value = { type = 'SPELL_AVAIL' }
    a.definitions.SPELL_AVAIL.widget(parent, 269, value)
    local field

    local function find(w)
        for _, c in ipairs(w.children or {}) do
            if c.rmSpellSearchActive then
                field = c
            end

            find(c)
        end
    end

    find(parent)
    field:SetFocus()
    field.editbox:SetText('Blackout')
    local row = field.rmSpellPopup.rows[1]
    assert(row.spellID == 100784, 'Blackout Kick not offered in the Spells view')
    row.scripts.OnMouseDown(row, 'LeftButton')
    assert(value.spell == 100784 and field:GetText() == 'Blackout Kick', 'condition cleared a spellbook pick')
end)

test('Retail: the right-click insert offers a recent cast from the spellbook in a Spells field', function()
    local f, a, pane, card = editorFixture(
        RETAIL,
        11,
        function(env)
            installRetail(env)
        end,
        { type = 'spell', spec = 269 }
    )

    a.spellHistory = { { spell = 100784, time = 1 } }
    local field = card().fieldControls.spell
    field.editbox.scripts.OnMouseDown(field.editbox, 'RightButton')
    local row = field.rmSpellPopup.rows[1]
    assert(row:IsShown() and row.spellID == 100784, 'recent cast not offered')
    row.scripts.OnMouseDown(row, 'LeftButton')
    assert(pane.workspace:Snapshot().rotation[1].action == 100784)
end)

-- Retail's own click handling ------------------------------------------------
-- Blizzard_Game/Mainline/EventImplementation.lua ClearCurrentKeyboardFocus, run
-- on every left GLOBAL_MOUSE_DOWN before the pressed frame's OnMouseDown: the
-- focused EditBox is cleared unless it is the mouse focus or reports
-- HasStickyFocus(). honourSticky=false models a client that clears anyway.
local function press(f, field, target, honourSticky)
    f.env.GetMouseFoci = function() return { target } end
    local editbox = field.editbox

    if editbox:HasFocus() then
        local sticky = honourSticky ~= false and editbox.HasStickyFocus and editbox:HasStickyFocus()

        if not sticky and target ~= editbox then
            editbox:ClearFocus()
        end
    end

    -- A frame under a hidden parent is not visible and receives no mouse.
    local function visible(frame)
        while frame do
            if not frame:IsShown() then
                return false
            end

            frame = frame:GetParent()
        end

        return true
    end

    if visible(target) and target.scripts and target.scripts.OnMouseDown then
        target.scripts.OnMouseDown(target, 'LeftButton')
    end
    if visible(target) and target.scripts and target.scripts.OnMouseUp then
        target.scripts.OnMouseUp(target, 'LeftButton')
    end
end

local function suggestion(field, want)
    for _, row in ipairs(field.rmSpellPopup.rows) do
        if row:IsShown() and row.spellID == want then
            return row
        end
    end
end

test('Retail: clicking a suggestion survives the global focus clear (the Any Spell list pick)', function()
    local f, a, pane, card = editorFixture(
        RETAIL,
        11,
        function(env)
            installRetail(env)
        end,
        { type = 'any', spec = 269 }
    )

    local field = card().fieldControls.spell
    field:SetFocus()
    field.editbox:SetText('Blackout')
    local row = assert(suggestion(field, 100784))
    f.env.GetMouseFoci = function() return { row } end
    assert(field.editbox:HasStickyFocus(), 'field does not keep focus while the pointer is on its list')
    press(f, field, row)
    assert(pane.workspace:Snapshot().rotation[1].action == 100784, 'list pick lost to the focus clear')
    assert(card().fieldControls.spell:GetText() == 'Blackout Kick')
end)

test('Retail: a client that clears focus anyway still lets the pressed suggestion commit', function()
    local f, a, pane, card = editorFixture(
        RETAIL,
        11,
        function(env)
            installRetail(env)
        end,
        { type = 'any', spec = 269 }
    )

    local field = card().fieldControls.spell
    field:SetFocus()
    field.editbox:SetText('Blackout')
    press(f, field, assert(suggestion(field, 100784)), false)

    assert(
        pane.workspace:Snapshot().rotation[1].action == 100784
            and card().fieldControls.spell:GetText() == 'Blackout Kick'
    )
end)

test('Retail: a press on the list but not a row, or anywhere else, still cancels the unfinished text', function()
    local f, a, pane, card = editorFixture(
        RETAIL,
        11,
        function(env)
            installRetail(env)
        end,
        { type = 'any', spec = 269 }
    )

    local field = card().fieldControls.spell
    local popup = field.rmSpellPopup
    field:SetFocus()
    field.editbox:SetText('Blackout')
    press(f, field, popup, false)

    assert(
        not popup:IsShown() and field:GetText() == '' and pane.workspace:Snapshot().rotation[1].action == nil,
        'footer press left the list open or committed'
    )

    field:SetFocus()
    field.editbox:SetText('Blackout')
    assert(popup:IsShown())
    local elsewhere = f.env.CreateFrame('Button')
    elsewhere:Show()
    f.env.GetMouseFoci = function() return { elsewhere } end
    assert(not field.editbox:HasStickyFocus(), 'focus kept for a press outside the list')
    press(f, field, elsewhere)
    assert(not popup:IsShown() and field:GetText() == '' and pane.workspace:Snapshot().rotation[1].action == nil)
end)

test('Retail: dragging a spell onto the field still stores it', function()
    local f, a, pane, card = editorFixture(
        RETAIL,
        11,
        function(env)
            installRetail(env)
        end,
        { type = 'any', spec = 269 }
    )

    f.env.GetCursorInfo = function() return 'spell', 6, 'spell', 100784 end
    f.env.ClearCursor = function() end
    local field = card().fieldControls.spell
    field.editbox.scripts.OnReceiveDrag(field.editbox)

    assert(
        pane.workspace:Snapshot().rotation[1].action == 100784
            and card().fieldControls.spell:GetText() == 'Blackout Kick'
    )
end)

test('released fields give the pooled EditBox back without the sticky-focus hook', function()
    local f, a, pane, card = editorFixture(
        RETAIL,
        11,
        function(env)
            installRetail(env)
        end,
        { type = 'any', spec = 269 }
    )

    local field = card().fieldControls.spell
    local editbox = field.editbox
    assert(type(editbox.HasStickyFocus) == 'function')
    a:ReleaseConditionWidget(field)
    assert(editbox.HasStickyFocus == nil, 'sticky-focus hook leaked into the input pool')
end)

finish()
