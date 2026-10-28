-- Built In condition WEAPON_TYPE: what is equipped in the main hand, off hand or ranged slot (a category such as
-- two-handed weapon or shield, or one weapon subclass such as daggers). It reads the equipment snapshot through
-- addon:GetEquippedWeaponSlot (Core/build_context.lua), so an evaluation calls no native API and uses only item class
-- IDs, never localized names; the one game call here is the editor's weapon subclass name lookup, which passes through
-- Platform:CanReadValue. A slot or item data the snapshot cannot supply makes the condition unavailable (nil, reason),
-- also under NOT. Loaded from RotationMaster.toc after Conditions/weapon.lua. Callback and helper bodies are hashed by
-- saved copies and bundles: never add or change text inside a function body, and leave the generated block at the end
-- alone.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

local Functions = {
    presentation = { nullable = addon.Functions.presentation.nullable },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/equipment.lua"] = {
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
}

-- ============================================================================
-- Item classes and choices
-- ============================================================================

-- WEAPON_TYPE: what is equipped in the main hand, off hand or ranged slot.
-- It reads item class, subclass and equip location IDs (never localized
-- names) from the equipment snapshot in Core/build_context.lua, which is
-- rebuilt only on PLAYER_EQUIPMENT_CHANGED / UNIT_INVENTORY_CHANGED, so an
-- evaluation calls no native API. An empty slot is a real answer; a slot the
-- client does not have (the ranged slot from Mists of Pandaria on) or item
-- data it cannot classify is unavailable, including under NOT.
local WEAPON_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
local ARMOR_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4
local SHIELD_SUBCLASS = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Shield or 6

local slots = {
    mainhand = L["Main Hand"],
    offhand = L["Off Hand"],
    ranged = L["Ranged"],
}

local slotOrder = { "mainhand", "offhand", "ranged" }

-- Categories by equip location token (INVTYPE_*), plus empty and shield.
local kinds = {
    empty = L["Nothing equipped"],
    weapon = L["Any weapon"],
    onehand = L["One-handed weapon"],
    twohand = L["Two-handed weapon"],
    ranged = L["Ranged weapon"],
    shield = L["Shield"],
    holdable = L["Held in off hand"],
}

local kindOrder = { "empty", "weapon", "onehand", "twohand", "ranged", "shield", "holdable" }
local ONEHAND = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true }
local RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }

-- Enum.ItemWeaponSubclass IDs offered in the editor; the client supplies the
-- names (GetItemSubClassInfo), English is the fallback.
local subclassNames = {
    [0] = "One-Handed Axes",
    [1] = "Two-Handed Axes",
    [2] = "Bows",
    [3] = "Guns",
    [4] = "One-Handed Maces",
    [5] = "Two-Handed Maces",
    [6] = "Polearms",
    [7] = "One-Handed Swords",
    [8] = "Two-Handed Swords",
    [9] = "Warglaives",
    [10] = "Staves",
    [13] = "Fist Weapons",
    [15] = "Daggers",
    [16] = "Thrown",
    [18] = "Crossbows",
    [19] = "Wands",
    [20] = "Fishing Poles",
}

local subclassOrder = {15, 13, 0, 4, 7, 9, 1, 5, 8, 6, 10, 2, 3, 18, 16, 19, 20}

-- ============================================================================
-- Matching
-- ============================================================================

-- True for a whole number from 0 to 31, the range of weapon subclass IDs.
-- @param value any  The value to test.
-- @return boolean  True when value is a number in that range with no fractional part.
local function subclassID(value)
    return type(value) == "number" and value >= 0 and value <= 31 and value % 1 == 0
end

-- Builds the display name of a weapon subclass for the editor and the readable summary.
-- @param id number  The Enum.ItemWeaponSubclass ID.
-- @return string  The client's own name when readable, otherwise the localized English fallback from subclassNames,
--     otherwise "weapon type N".
local function subclassName(id)
    local fn = C_Item and C_Item.GetItemSubClassInfo or GetItemSubClassInfo
    if type(fn) == "function" then
        local ok, name = pcall(fn, WEAPON_CLASS, id)
        if ok and addon.Platform:CanReadValue(name) and type(name) == "string" and name ~= "" then return name end
    end
    return subclassNames[id] and L[subclassNames[id]] or string.format(L["weapon type %d"], id)
end

-- Tests an equipment record for one slot against the saved kind or weapon subclass.
-- @param value table  The saved condition fields; reads kind and subclass.
-- @param record table|false  The slot record as addon:GetEquippedWeaponSlot returns it: a table, or false for an empty
--     slot.
-- @return boolean|nil  True when the item matches, false when it does not; nil when the item cannot be classified yet.
-- @return string|nil  The reason code when the first value is nil ("item-data-unavailable", the record's own
--     typeReason, or "invalid-weapon-type"); nil otherwise.
local function matches(value, record)
    if record == false then return value.kind == "empty" end
    if value.kind == "empty" then return false end
    if record.classID == nil then return nil, record.typeReason or "item-data-unavailable" end
    if value.subclass ~= nil then
        return record.classID == WEAPON_CLASS and record.subClassID == value.subclass
    end
    local kind = value.kind
    if kind == "shield" then return record.classID == ARMOR_CLASS and record.subClassID == SHIELD_SUBCLASS end
    if kind == "weapon" then return record.classID == WEAPON_CLASS end
    if record.equipLoc == nil then return nil, "item-data-unavailable" end
    if kind == "holdable" then return record.equipLoc == "INVTYPE_HOLDABLE" end
    if record.classID ~= WEAPON_CLASS then return false end
    if kind == "onehand" then return ONEHAND[record.equipLoc] == true end
    if kind == "twohand" then return record.equipLoc == "INVTYPE_2HWEAPON" end
    if kind == "ranged" then return RANGED[record.equipLoc] == true end
    return nil, "invalid-weapon-type"
end

-- ============================================================================
-- Weapon type condition
-- ============================================================================

-- WEAPON_TYPE: true when the item in the chosen slot is of the chosen category (`kind`) or weapon subclass
-- (`subclass`, which excludes `kind`). An empty slot is a real answer (true only for "Nothing equipped"). Stores
-- `slot`, `kind` and `subclass`. Returns `nil, reason` when the slot does not exist on this client (the ranged slot
-- from Mists of Pandaria on), the build snapshot is unavailable ("build-context-unavailable") or the item is not
-- classified.
addon:RegisterCondition("WEAPON_TYPE", {
    description = L["Weapon Type"],
    icon = addon.Artwork.condition["WEAPON_TYPE"],
    requiredFields = { "slot" },
    fields = { slot = "string", kind = "string", subclass = "number" },
    -- Checks that the saved fields of the WEAPON_TYPE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a listed slot and either a listed kind or a weapon subclass ID, never both.
    valid = function(_, value)
        if slots[value.slot] == nil then return false end
        if value.subclass ~= nil then return value.kind == nil and subclassID(value.subclass) end
        return kinds[value.kind] ~= nil
    end,
    -- Decides whether the item in the chosen slot is of the chosen category or weapon subclass; an empty slot is true
    -- only for "Nothing equipped".
    -- @param value table  The saved condition fields.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Reads the slot record from the build snapshot and hands it to `matches`; unavailable cases are listed above.
    evaluate = function(value)
        if not addon.GetEquippedWeaponSlot then return nil, "build-context-unavailable" end
        local record, reason = addon:GetEquippedWeaponSlot(value.slot)
        if record == nil then return nil, reason end
        return matches(value, record)
    end,
    -- Builds the readable rule summary for the WEAPON_TYPE condition.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary naming the slot and the category or weapon subclass.
    print = function(_, value)
        local what
        if value.subclass ~= nil then what = subclassName(value.subclass) else what = kinds[value.kind] end
        return string.format(L["your %s slot {{!holds|does not hold}} %s"],
            Functions.presentation.nullable(slots[value.slot], L["<slot>"]),
            Functions.presentation.nullable(what, L["<weapon type>"]))
    end,
    -- Builds the editor controls for the WEAPON_TYPE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The current specialization (addon.currentSpec).
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the slot dropdown and one dropdown that lists the categories and then the weapon subclasses (a
    -- subclass is saved as `subclass`, a category as `kind`); help draws the help page and examples.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local function update() top:SetStatusText(funcs:print(root, spec)) end

        local slot = addon:CreateConditionDropdown()
        slot:SetLabel(L["Slot"])
        slot:SetCallback("OnValueChanged", function(_, _, v) value.slot = v;update() end)
        slot.configure = function() slot:SetList(slots, slotOrder);slot:SetValue(value.slot) end
        parent:AddChild(slot)

        -- One list: categories first, then weapon subclasses. A subclass is
        -- saved as its numeric ID, a category as its key.
        local choices, order = {}, {}
        for _, key in ipairs(kindOrder) do choices[key] = kinds[key];order[#order + 1] = key end
        for _, id in ipairs(subclassOrder) do
            local key = "subclass:" .. id
            choices[key] = subclassName(id);order[#order + 1] = key
        end
        local kind = addon:CreateConditionDropdown()
        kind:SetLabel(L["Weapon Type"])
        kind:SetCallback("OnValueChanged", function(_, _, v)
            local id = type(v) == "string" and tonumber(v:match("^subclass:(%d+)$"))
            if id then value.kind, value.subclass = nil, id else value.kind, value.subclass = v, nil end
            update()
        end)
        kind.configure = function()
            kind:SetList(choices, order)
            kind:SetValue(value.subclass ~= nil and ("subclass:" .. value.subclass) or value.kind)
        end
        parent:AddChild(kind)
    end,
    -- Builds the help page for the WEAPON_TYPE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.WEAPON_TYPE"]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Help.Conditions.WEAPON_TYPE.examples"]))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="ARMOR_CLASS" then return ARMOR_CLASS end
        if name=="ONEHAND" then return ONEHAND end
        if name=="RANGED" then return RANGED end
        if name=="SHIELD_SUBCLASS" then return SHIELD_SUBCLASS end
        if name=="WEAPON_CLASS" then return WEAPON_CLASS end
        if name=="helpers" then return helpers end
        if name=="kindOrder" then return kindOrder end
        if name=="kinds" then return kinds end
        if name=="matches" then return matches end
        if name=="slotOrder" then return slotOrder end
        if name=="slots" then return slots end
        if name=="subclassID" then return subclassID end
        if name=="subclassName" then return subclassName end
        if name=="subclassNames" then return subclassNames end
        if name=="subclassOrder" then return subclassOrder end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/equipment.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/equipment.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
