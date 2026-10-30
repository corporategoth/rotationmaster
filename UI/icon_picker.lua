-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Paged icon chooser window used when an author picks an icon for a custom condition (UI/custom_condition_editor.lua).
-- It lists icon groups (a short built-in set, the addon's own artwork, spells the player knows and the client's macro
-- icon lists), filters by name, and hands the chosen texture path to the caller's `choose` callback. It owns only the
-- window; it never stores the icon, and it stops responding whenever the owner stops being valid. Loaded in the UI/
-- block of RotationMaster.toc after UI/condition_unit.lua; needs addon.Artwork (Data/artwork.lua), addon.SpellCatalog
-- and the category icon check in Core/category_data.lua.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Icon catalog
-- ============================================================================

-- Builds the list of icon groups for one picker opening. Sources are fixed sets, the addon artwork, the player's
-- indexed spells, and the client macro icon lists (included only when the client exposes them and the icon passes
-- IsCategoryIcon). Rebuilt on every open so newly learned spells appear.
-- @return table[]  Groups shaped { name = string, icons = { { texture = string|number, name = string } } }.
local function catalogs()
    local groups = {}
    local labels = {}

    local names = {
        Combat = L['Combat'],
        Swords = L['Swords'],
        Shield = L['Shield'],
        Healing = L['Healing'],
        Spells = L['Spells'],
        Lightning = L['Lightning'],
        Buffs = L['Buffs'],
        Fire = L['Fire'],
        Nature = L['Nature'],
        Items = L['Items'],
        Potions = L['Potions'],
        Weapon = L['Weapon'],
        Armor = L['Armor'],
        Food = L['Food'],
        Groups = L['Groups'],
        Group = L['Group'],
        Location = L['Location'],
        Book = L['Book'],
        Question = L['Question'],
    }

    for _, group in ipairs({
        {
            'Combat',
            { 'Swords', 'Ability_DualWield' },
            { 'Shield', 'Ability_Warrior_DefensiveStance' },
            { 'Healing', 'Spell_Holy_Heal' },
        },
        {
            'Spells',
            { 'Lightning', 'Spell_Nature_Lightning' },
            { 'Buffs', 'Spell_Holy_PowerWordShield' },
            { 'Fire', 'Spell_Fire_FlameBolt' },
            { 'Nature', 'Spell_Nature_Rejuvenation' },
        },
        {
            'Items',
            { 'Potions', 'INV_Potion_54' },
            { 'Weapon', 'INV_Weapon_ShortBlade_01' },
            { 'Armor', 'INV_Chest_Chain_07' },
            { 'Food', 'INV_Misc_Food_15' },
        },
        {
            'Groups',
            { 'Group', 'Spell_Holy_PrayerOfHealing02' },
            { 'Location', 'INV_Misc_Map_01' },
            { 'Book', 'INV_Misc_Book_09' },
            { 'Question', 'INV_Misc_QuestionMark' },
        },
    }) do
        local row = { name = names[group[1]], icons = {} }

        for i = 2, #group do
            local entry = group[i]
            local texture = 'Interface\\Icons\\' .. entry[2]
            row.icons[#row.icons + 1] = { texture = texture, name = names[entry[1]] }
            labels[texture] = names[entry[1]]
        end

        groups[#groups + 1] = row
    end

    local originals = { name = L['Rotation Master'], icons = {} }

    for _, entry in ipairs(addon.Artwork.icons) do
        originals.icons[#originals.icons + 1] = entry
        labels[entry.texture] = entry.name
    end

    for _, entry in ipairs({
        { 'combat', L['Combat'] },
        { 'character', L['Character'] },
        { 'spell', L['Spells'] },
        { 'buff', L['Buffs'] },
        { 'debuff', L['Debuffs'] },
        { 'item', L['Items'] },
        { 'weapon', L['Weapon'] },
        { 'spatial', L['Spatial'] },
        { 'resources', L['Resources'] },
        { 'pet', L['Pet'] },
        { 'talent', L['Talent'] },
        { 'casting', L['Casting'] },
        { 'logic', L['Logic'] },
        { 'totem', L['Totem'] },
        { 'environment', L['Environment'] },
        { 'time', L['Time'] },
    }) do
        local texture = 'Interface\\AddOns\\' .. addon_name .. '\\Assets\\Conditions\\' .. entry[1]
        originals.icons[#originals.icons + 1] = { texture = texture, name = entry[2] }
        labels[texture] = entry[2]
    end

    groups[#groups + 1] = originals
    local known = { name = L['Known spells'], icons = {} }
    local seen = {}

    for _, entry in ipairs(addon.SpellCatalog:GetIndexedSpells()) do
        if entry.icon and not seen[entry.icon] then
            seen[entry.icon] = true
            known.icons[#known.icons + 1] = { texture = entry.icon, name = entry.name }
            labels[entry.icon] = entry.name
        end
    end

    if #known.icons > 0 then
        groups[#groups + 1] = known
    end

    for _, source in ipairs({
        { L['Game icons'], C_Macro and C_Macro.GetMacroIcons or GetMacroIcons },
        { L['Item icons'], C_Macro and C_Macro.GetMacroItemIcons or GetMacroItemIcons },
    }) do
        if type(source[2]) == 'function' then
            local values = {}
            local ok, returned = pcall(source[2], values)

            if ok then
                if type(returned) == 'table' then
                    values = returned
                end

                local row = { name = source[1], icons = {} }
                local unique = {}

                for _, texture in ipairs(values) do
                    if addon:IsCategoryIcon(texture) and not unique[texture] then
                        unique[texture] = true

                        local name = labels[texture]
                            or type(texture) == 'string' and (texture:match('([^\\/]+)$') or L['Game icon']):gsub(
                                '_',
                                ' '
                            )
                            or L['Game icon']

                        row.icons[#row.icons + 1] = { texture = texture, name = name }
                    end
                end

                if #row.icons > 0 then
                    groups[#groups + 1] = row
                end
            end
        end
    end

    return groups
end

-- ============================================================================
-- Picker window
-- ============================================================================

-- Opens (or reuses) the single icon picker window.
-- @param current string|number|nil  The texture to mark as selected.
-- @param choose function  Called once as choose(texture) on a click; the window then closes.
-- @param ownerValid function  Returns whether the opener is still alive; every callback is dropped once it returns
--   false or the window is reopened.
-- @return table  The window record.
function addon:ShowWorkbenchIconPicker(current, choose, ownerValid)
    local d = self.iconPicker

    if not d then
        d = { frame = CreateFrame('Frame', nil, UIParent), buttons = {}, categoryButtons = {} }
        self.iconPicker = d
        local frame = d.frame
        frame:SetSize(630, 430)
        frame:SetPoint('CENTER')
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        self:MakeWindowOpaque(frame)
        d.title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        d.chrome = self:CreateWorkbenchDialogChrome(frame, d.title)
        d.close = self:CreateWorkbenchIconButton(frame, 'close', L['Close'])
        d.close:SetPoint('TOPRIGHT', -5, -5)

        self:SetUIScript(d.close, 'OnClick', function()
            frame:Hide()
        end)

        d.search = self:CreateWorkbenchEditBox(frame)
        self:AttachWorkbenchSearchHint(d.search)
        d.search:SetPoint('TOPLEFT', 166, -38)
        d.search:SetSize(432, 24)
        d.prev = self:CreateWorkbenchIconButton(frame, 'up', L['Previous'])
        d.prev.icon:SetRotation(math.pi / 2)
        d.prev:SetPoint('BOTTOMRIGHT', -60, 28)
        d.next = self:CreateWorkbenchIconButton(frame, 'down', L['Next'])
        d.next.icon:SetRotation(math.pi / 2)
        d.next:SetPoint('BOTTOMRIGHT', -30, 28)
        d.pageLabel = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        d.pageLabel:SetPoint('BOTTOMLEFT', 166, 32)

        self:SetUIScript(frame, 'OnHide', function()
            d.search:ClearFocus()
        end)

        self:SetUIScript(frame, 'OnMouseUp', function(_, button)
            if button == 'RightButton' then
                frame:Hide()
            end
        end)

        frame:Hide()
    end

    -- The serial changes on every open, so scripts left over from an earlier opening see valid() as false.
    d.serial = (d.serial or 0) + 1
    local serial = d.serial
    local selectedCategory, page = 1, 1
    d.categories = catalogs()
    d.search:SetText('')

    -- True while this opening is current, the window is shown and the opener is still valid.
    -- @return boolean  True when callbacks may act.
    local function valid()
        return d.serial == serial and d.frame:IsShown() and ownerValid()
    end

    -- Redraws the current page of matches for the selected category and search text (54 icons per page, 9 per row).
    -- Each draw bumps d.revision so a click handler from an earlier draw cannot choose an icon that has since moved.
    local function draw()
        if not valid() then
            return
        end

        d.revision = (d.revision or 0) + 1
        local revision = d.revision
        d.matches = {}
        local query = (d.search:GetText() or ''):lower()

        for _, entry in ipairs(d.categories[selectedCategory].icons) do
            if entry.name:lower():find(query, 1, true) then
                d.matches[#d.matches + 1] = entry
            end
        end

        local pages = math.max(1, math.ceil(#d.matches / 54))
        page = math.min(page, pages)
        d.pageLabel:SetText(string.format(L['Page %d of %d'], page, pages))

        if page > 1 then
            d.prev:Enable()
        else
            d.prev:Disable()
        end

        if page < pages then
            d.next:Enable()
        else
            d.next:Disable()
        end

        for i = 1, 54 do
            local entry = d.matches[(page - 1) * 54 + i]
            local button = d.buttons[i]

            if entry then
                if not button then
                    button = addon:CreateWorkbenchButton(d.frame, '', 44)
                    button.icon = button:CreateTexture(nil, 'ARTWORK')
                    button.icon:SetAllPoints(button)
                    d.buttons[i] = button
                end

                button:ClearAllPoints()
                button:SetPoint('TOPLEFT', 166 + ((i - 1) % 9) * 48, -74 - math.floor((i - 1) / 9) * 48)
                button:SetSize(40, 40)
                button.icon:SetTexture(entry.texture)
                button:SetSelected(entry.texture == current)
                button.tooltip = entry.name
                button:Show()

                addon:SetUIScript(button, 'OnClick', function()
                    if valid() and d.revision == revision then
                        d.frame:Hide()
                        choose(entry.texture)
                    end
                end)
            elseif button then
                button:Hide()
            end
        end

        for i, button in ipairs(d.categoryButtons) do
            button:SetSelected(i == selectedCategory)
        end
    end

    for i, category in ipairs(d.categories) do
        local button = d.categoryButtons[i]

        if not button then
            button = self:CreateWorkbenchButton(d.frame, '', 136)
            d.categoryButtons[i] = button
        end

        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', 12, -38 - (i - 1) * 28)
        button:SetText(category.name)
        button:Show()

        self:SetUIScript(button, 'OnClick', function()
            if valid() then
                selectedCategory = i
                page = 1
                draw()
            end
        end)
    end

    for i = #d.categories + 1, #d.categoryButtons do
        d.categoryButtons[i]:Hide()
    end

    self:SetUIScript(d.search, 'OnTextChanged', function(_, user)
        if user and valid() then
            page = 1
            draw()
        end
    end)

    self:SetUIScript(d.search, 'OnEscapePressed', function()
        d.frame:Hide()
    end)

    self:SetUIScript(d.prev, 'OnClick', function()
        if valid() then
            page = math.max(1, page - 1)
            draw()
        end
    end)

    self:SetUIScript(d.next, 'OnClick', function()
        if valid() then
            page = page + 1
            draw()
        end
    end)

    d.chrome:SetContext(L['Select Icon'], L['Category'], self.pretty_name)
    d.frame:Show()
    self:OpenPopup(d)
    draw()
    d.search:SetFocus()
    return d
end
