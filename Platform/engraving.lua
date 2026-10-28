-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for Season of Discovery rune engraving (C_Engraving on Classic Era).
-- Owns the `value or nil, reason` readers for whether engraving is readable, the runes engraved on the player's
-- equipped items and the runes the character knows; it must not engrave or target anything. The namespace is absent
-- outside Classic Era, so every reader reports "missing-api" there. Core/build_context.lua reads the engraved runes
-- once per change. Loaded from RotationMaster.toc after Platform/talent_tree.lua; needs Platform/client.lua.
local _, addon = ...
local platform = addon.Platform

-- Season of Discovery rune engraving (C_Engraving, Classic Era 1.15 with the
-- engraving ruleset active).
--
-- Contract (Blizzard's generated API documentation, Gethe/wow-ui-source
-- classic_era, Interface/AddOns/Blizzard_APIDocumentationGenerated/
-- EngravingInfoDocumentation.lua, read 2026-10-23):
--   C_Engraving.IsEngravingEnabled() -> bool
--   C_Engraving.GetNumRunesKnown(equipmentSlot: InventoryType?) -> known, max
--   C_Engraving.GetRuneCategories(shouldFilter, ownedOnly) -> InventoryType[]
--   C_Engraving.GetRunesForCategory(category, ownedOnly) -> EngravingData[]
--   C_Engraving.GetRuneForEquipmentSlot(equipmentSlot: luaIndex) -> EngravingData?
--   C_Engraving.IsEquipmentSlotEngravable(equipmentSlot) -> bool
--   C_Engraving.IsRuneEquipped(skillLineAbilityID) -> bool
--   C_Engraving.RefreshRunesList()
--   EngravingData = {skillLineAbilityID, itemEnchantmentID, name, iconTexture,
--     equipmentSlot (InventoryType), level, learnedAbilitySpellIDs: number[]}
--   events ENGRAVING_MODE_CHANGED, ENGRAVING_TARGETING_MODE_CHANGED, RUNE_UPDATED
-- Blizzard_EngravingUI names a category with C_Item.GetItemInventorySlotInfo
-- and refreshes on PLAYER_EQUIPMENT_CHANGED and NEW_RECIPE_LEARNED. Shipped
-- addons note that GetNumRunesKnown reports max 0 until the rune list has
-- loaded after login, and that the Phase 7 shoulder "runes" are not
-- C_Engraving engravings at all (they override Soul Engraving 1219955).
--
-- The namespace is absent outside the Classic Era client and inert there on
-- realms without engraving. Every call is feature-detected and protected;
-- results are value, reason: nil plus "missing-api", "engraving-unavailable",
-- "rune-data-pending", "api-error", "restricted-value" or
-- "invalid-api-result" when nothing usable could be read.

local SLOT_FIRST, SLOT_LAST = 1, 19
local refreshRequested = false

-- Looks up a C_Engraving function.
-- @param name string  The function name.
-- @return function|nil  The function; nil when the namespace or the function does not exist.
local function method(name)
    local namespace = C_Engraving

    if type(namespace) ~= 'table' then
        return nil
    end

    local fn = namespace[name]

    if type(fn) == 'function' then
        return fn
    end
end

-- Whether a value is a readable positive whole number (a rune, slot or spell id).
-- @param value any  The value to test.
-- @return boolean  True for such a number.
local function identifier(value)
    return platform:CanReadValue(value)
        and type(value) == 'number'
        and value > 0
        and value < math.huge
        and value % 1 == 0
end

-- Calls the named C_Engraving function under pcall.
-- @param name string  The C_Engraving function name.
-- @param ... any  The arguments passed to the function.
-- @return boolean  True when the call succeeded.
-- @return any  The first result of the function; the reason code ("missing-api", "api-error" or "restricted-value")
--   when the first return is false.
-- @return any|nil  The second result of the function; nil when the call failed.
local function protected(name, ...)
    local fn = method(name)

    if not fn then
        return false, 'missing-api'
    end

    local ok, first, second = pcall(fn, ...)

    if not ok then
        return false, 'api-error'
    end
    if not platform:CanReadValue(first) or not platform:CanReadValue(second) then
        return false, 'restricted-value'
    end

    return true, first, second
end

-- Tells whether engraving can be read at all.
-- @return boolean|nil  True when the API exists, the realm has engraving and the rune list has loaded; nil otherwise.
-- @return string|nil  The reason code when the first return is nil ("rune-data-pending" while the list loads); nil
--   otherwise.
--
-- A not-yet-loaded list asks the client to load it once per session and stays unavailable until it has.
function platform:GetEngravingAvailability()
    local ok, enabled = protected('IsEngravingEnabled')

    if not ok then
        return nil, enabled
    end
    if enabled ~= true then
        return nil, 'engraving-unavailable'
    end

    local okCount, _, maximum = protected('GetNumRunesKnown')

    if okCount and type(maximum) == 'number' and maximum == 0 then
        if not refreshRequested and method('RefreshRunesList') then
            refreshRequested = true
            pcall(method('RefreshRunesList'))
        end

        return nil, 'rune-data-pending'
    end

    return true
end

-- Copies one EngravingData record.
-- @param data table  The native EngravingData record.
-- @return table|nil  { rune (skillLineAbilityID), name, icon, category (InventoryType), level, spells (the learned
--   spell ids) }; nil when data is restricted or lacks a rune id.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
local function rune(data)
    if not platform:CanReadValue(data) then
        return nil, 'restricted-value'
    end
    if type(data) ~= 'table' then
        return nil, 'invalid-api-result'
    end

    for _, key in ipairs({
        'skillLineAbilityID',
        'name',
        'iconTexture',
        'equipmentSlot',
        'level',
        'learnedAbilitySpellIDs',
    }) do
        if not platform:CanReadValue(data[key]) then
            return nil, 'restricted-value'
        end
    end

    if not identifier(data.skillLineAbilityID) then
        return nil, 'invalid-api-result'
    end

    local spells = {}

    if type(data.learnedAbilitySpellIDs) == 'table' then
        for index = 1, #data.learnedAbilitySpellIDs do
            local spell = data.learnedAbilitySpellIDs[index]

            if not platform:CanReadValue(spell) then
                return nil, 'restricted-value'
            end

            if identifier(spell) then
                spells[#spells + 1] = spell
            end
        end
    end

    return {
        rune = data.skillLineAbilityID,
        name = type(data.name) == 'string' and data.name ~= '' and data.name or nil,
        icon = data.iconTexture,
        category = identifier(data.equipmentSlot) and data.equipmentSlot or nil,
        level = identifier(data.level) and data.level or nil,
        spells = spells,
    }
end

-- Lists every rune engraved on the player's equipped items as two lookups.
-- @return table|nil  { byRune, bySpell }: byRune[skillLineAbilityID] and bySpell[learned spell id], each giving the
--   inventory slot; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Read once per change by Core/build_context.lua. Any slot that cannot be read fails the whole read so that a
-- partial map is never mistaken for a complete one.
function platform:GetEngravedRunes()
    local available, why = self:GetEngravingAvailability()

    if not available then
        return nil, why
    end

    local get = method('GetRuneForEquipmentSlot')

    if not get then
        return nil, 'missing-api'
    end

    local engravable = method('IsEquipmentSlotEngravable')
    local result = { byRune = {}, bySpell = {} }

    for slot = SLOT_FIRST, SLOT_LAST do
        local check = true

        if engravable then
            local ok, value = pcall(engravable, slot)

            if not ok then
                return nil, 'api-error'
            end
            if not self:CanReadValue(value) then
                return nil, 'restricted-value'
            end

            check = value == true
        end

        if check then
            local ok, data = pcall(get, slot)

            if not ok then
                return nil, 'api-error'
            end
            if not self:CanReadValue(data) then
                return nil, 'restricted-value'
            end

            if data ~= nil then
                local record, reason = rune(data)

                if not record then
                    return nil, reason
                end

                result.byRune[record.rune] = slot

                for _, spell in ipairs(record.spells) do
                    result.bySpell[spell] = slot
                end
            end
        end
    end

    return result
end

-- Lists the character's known runes for the editor, grouped by equipment category in the game's order.
-- @return table[]|nil  The groups { category, name, runes = { record... } }; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Builds a fresh table of records on every call.
function platform:GetKnownRunes()
    local available, why = self:GetEngravingAvailability()

    if not available then
        return nil, why
    end

    local ok, categories = protected('GetRuneCategories', false, true)

    if not ok then
        return nil, categories
    end
    if type(categories) ~= 'table' then
        return nil, 'invalid-api-result'
    end

    local slotName = C_Item and C_Item.GetItemInventorySlotInfo or GetItemInventorySlotInfo
    local groups = {}

    for index = 1, #categories do
        local category = categories[index]

        if not self:CanReadValue(category) then
            return nil, 'restricted-value'
        end

        if identifier(category) then
            local okRunes, list = protected('GetRunesForCategory', category, true)

            if not okRunes then
                return nil, list
            end
            if type(list) ~= 'table' then
                return nil, 'invalid-api-result'
            end

            local name

            if type(slotName) == 'function' then
                local okName, text = pcall(slotName, category)

                if okName and self:CanReadValue(text) and type(text) == 'string' and text ~= '' then
                    name = text
                end
            end

            local group = { category = category, name = name, runes = {} }

            for position = 1, #list do
                local record = rune(list[position])

                if record then
                    group.runes[#group.runes + 1] = record
                end
            end

            groups[#groups + 1] = group
        end
    end

    return groups
end

-- Finds a known rune by rune id or by one of its learned spell ids, for names and icons in summaries.
-- @param runeID number|nil  The rune id (skillLineAbilityID) to match.
-- @param spellID number|nil  A learned spell id to match.
-- @return table|nil  The rune record; nil when the character does not know it.
-- @return table|nil  The record's category group; nil when the first return is nil.
--
-- Rebuilds the known-rune list on every call.
function platform:FindKnownRune(runeID, spellID)
    local groups = self:GetKnownRunes()

    for _, group in ipairs(groups or {}) do
        for _, record in ipairs(group.runes) do
            if runeID ~= nil and record.rune == runeID then
                return record, group
            end

            if spellID ~= nil then
                for _, spell in ipairs(record.spells) do
                    if spell == spellID then
                        return record, group
                    end
                end
            end
        end
    end
end
