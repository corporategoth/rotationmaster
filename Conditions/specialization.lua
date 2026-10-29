-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- SPECIALIZATION: the condition that tests the player's talent specialization, plus the specialization tables and name
-- lookups other modules use (addon:GetSpecializationName and addon:GetSpecializationClassToken, called by
-- Core/rotation_selection.lua and Core/imports.lua), and the one-time seeding that adds SPECIALIZATION and WEAPON_TYPE
-- to existing profiles (addon:InstallLoadoutConditions, called from addon:init in init.lua). The player's
-- specialization is not read here: addon:GetPlayerSpecializationObservation (Core/build_context.lua) caches it until a
-- talent or specialization notification. Loaded from the Conditions group of RotationMaster.toc, after
-- Conditions/engraving.lua. The callback and helper bodies are frozen: saved custom conditions bind to their exact
-- text, and the generated block at the end is written by tools/generate_builtin_sources.py.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- SPECIALIZATION: the player's talent specialization, saved as the game's
-- specialization ID so one condition reads the same on every client.
--   Retail, Mists of Pandaria Classic: the active specialization ID.
--   Era, TBC, Wrath (talent trees): the primary talent tree, the unique tree
--     with the most points. Feral and Guardian both mean Feral Combat there.
--   Forever: its specialization API names one specialization per class (the
--     trees are trait groups), so a spec of your own class is unavailable.
-- A specialization of another class is false everywhere. No specialization
-- yet, tied or unspent trees and unreadable values are unavailable, including
-- under NOT. The observation is cached by Core/build_context.lua until a
-- talent or specialization notification, so evaluation reads no native API.
local Functions = {
    presentation = { nullable = addon.Functions.presentation.nullable },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/specialization.lua"] = {
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
}

-- ============================================================================
-- Specialization tables
-- ============================================================================

-- Game specialization IDs: class token, talent tree on tree clients (nil
-- where the class or spec has no tree), and the English name used where the
-- client cannot name the specialization itself.
local SPECS = {
    [71] = { "WARRIOR", 1, "Arms" },
    [72] = { "WARRIOR", 2, "Fury" },
    [73] = { "WARRIOR", 3, "Protection" },
    [65] = { "PALADIN", 1, "Holy" },
    [66] = { "PALADIN", 2, "Protection" },
    [70] = { "PALADIN", 3, "Retribution" },
    [253] = { "HUNTER", 1, "Beast Mastery" },
    [254] = { "HUNTER", 2, "Marksmanship" },
    [255] = { "HUNTER", 3, "Survival" },
    [259] = { "ROGUE", 1, "Assassination" },
    [260] = { "ROGUE", 2, "Combat" },
    [261] = { "ROGUE", 3, "Subtlety" },
    [256] = { "PRIEST", 1, "Discipline" },
    [257] = { "PRIEST", 2, "Holy" },
    [258] = { "PRIEST", 3, "Shadow" },
    [250] = { "DEATHKNIGHT", 1, "Blood" },
    [251] = { "DEATHKNIGHT", 2, "Frost" },
    [252] = { "DEATHKNIGHT", 3, "Unholy" },
    [262] = { "SHAMAN", 1, "Elemental" },
    [263] = { "SHAMAN", 2, "Enhancement" },
    [264] = { "SHAMAN", 3, "Restoration" },
    [62] = { "MAGE", 1, "Arcane" },
    [63] = { "MAGE", 2, "Fire" },
    [64] = { "MAGE", 3, "Frost" },
    [265] = { "WARLOCK", 1, "Affliction" },
    [266] = { "WARLOCK", 2, "Demonology" },
    [267] = { "WARLOCK", 3, "Destruction" },
    [268] = { "MONK", nil, "Brewmaster" },
    [269] = { "MONK", nil, "Windwalker" },
    [270] = { "MONK", nil, "Mistweaver" },
    [102] = { "DRUID", 1, "Balance" },
    [103] = { "DRUID", 2, "Feral" },
    [104] = { "DRUID", 2, "Guardian" },
    [105] = { "DRUID", 3, "Restoration" },
    [577] = { "DEMONHUNTER", nil, "Havoc" },
    [581] = { "DEMONHUNTER", nil, "Vengeance" },
    [1480] = { "DEMONHUNTER", nil, "Devourer" },
    [1467] = { "EVOKER", nil, "Devastation" },
    [1468] = { "EVOKER", nil, "Preservation" },
    [1473] = { "EVOKER", nil, "Augmentation" },
    -- Retail's initial specializations ("No specialization", Platform/specializations.lua INITIAL_SPECS),
    -- so the Built In premades for that stage can switch on them without a client lookup.
    [1446] = { "WARRIOR", nil, "Initial" },
    [1451] = { "PALADIN", nil, "Initial" },
    [1448] = { "HUNTER", nil, "Initial" },
    [1453] = { "ROGUE", nil, "Initial" },
    [1452] = { "PRIEST", nil, "Initial" },
    [1455] = { "DEATHKNIGHT", nil, "Initial" },
    [1444] = { "SHAMAN", nil, "Initial" },
    [1449] = { "MAGE", nil, "Initial" },
    [1454] = { "WARLOCK", nil, "Initial" },
    [1450] = { "MONK", nil, "Initial" },
    [1447] = { "DRUID", nil, "Initial" },
    [1456] = { "DEMONHUNTER", nil, "Initial" },
    [1465] = { "EVOKER", nil, "Initial" },
}

-- The order the editor lists specializations in when the client cannot list them itself. The Initial entries are not in
-- it, so the editor never offers them as a choice.
local SPEC_ORDER = {
    71, 72, 73, 65, 66, 70, 253, 254, 255, 259, 260, 261, 256, 257, 258, 250, 251, 252, 262, 263, 264, 62, 63, 64, 265,
    266, 267, 268, 269, 270, 102, 103, 104, 105, 577, 581, 1480, 1467, 1468, 1473
}

-- Class token to the numeric class ID the client's specialization-choice reader takes.
local CLASS_IDS = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    DEATHKNIGHT = 6,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
    MONK = 10,
    DRUID = 11,
    DEMONHUNTER = 12,
    EVOKER = 13,
}

-- ============================================================================
-- Specialization helpers
-- ============================================================================

-- True for a positive whole number that could be a specialization ID.
-- @param value any  The value to test.
-- @return boolean  True when value is a number greater than 0, below math.huge, with no fractional part.
local function specID(value)
    return type(value)=="number" and value>0 and value<math.huge and value%1==0
end

-- Finds the class a specialization belongs to, from the SPECS table first, else from the client.
-- @param id number  The specialization ID.
-- @return string|nil  The class token; nil when neither the table nor the client knows the ID.
local function specClass(id)
    local known=SPECS[id]
    if known then return known[1] end
    local display=addon.Platform.GetSpecializationDisplay and addon.Platform:GetSpecializationDisplay(id)
    return display and display.class
end

-- Builds the display name of a specialization ID, and its icon when the client supplies one.
-- @param id any  The specialization ID; anything that is not one gives nil.
-- @return string|nil  The name: "No specialization" for Retail's "Initial" entries, otherwise the client's own name,
--     then the localized English table name, then a generic label; nil when id is not a specialization ID.
-- @return string|number|nil  The icon, only when the client supplied one; nil otherwise.
local function specName(id)
    if not specID(id) then return nil end
    local listed=SPECS[id]
    if listed and listed[3]=="Initial" then return L["No specialization"] end
    local display=addon.Platform.GetSpecializationDisplay and addon.Platform:GetSpecializationDisplay(id)
    if display then return display.name,display.icon end
    local known=SPECS[id]
    if known then return L[known[3]] end
    return string.format(L["specialization %d"],id)
end

-- Reads the player's class token.
-- @return string|nil  The class token; nil when UnitClass fails or the value is hidden.
local function playerClass()
    local ok,_,class=pcall(UnitClass,"player")
    if ok and addon.Platform:CanReadValue(class) and type(class)=="string" then return class end
end

-- Lists the specializations of one class for the editor, using the client's own names and icons where it has them, else
-- the SPECS table.
-- @param class string  The class token.
-- @return table  The choices, keyed by specialization ID: the name, or {text=name,icon=icon} when the client supplies
--     an icon.
-- @return number[]  The specialization IDs in display order.
local function classChoices(class)
    local choices,order={},{}
    local listed=CLASS_IDS[class] and addon.Platform.GetClassSpecializationChoices
        and addon.Platform:GetClassSpecializationChoices(CLASS_IDS[class])
    if listed and #listed>0 then
        for _,spec in ipairs(listed) do
            choices[spec.id]=spec.icon and {text=spec.name,icon=spec.icon} or spec.name
            order[#order+1]=spec.id
        end
        return choices,order
    end
    for _,id in ipairs(SPEC_ORDER) do
        if SPECS[id][1]==class then choices[id]=specName(id);order[#order+1]=id end
    end
    return choices,order
end

-- ============================================================================
-- Name and class lookups
-- ============================================================================

-- Gets the display name of a specialization ID, without the icon.
-- @param id any  The specialization ID.
-- @return string|nil  The display name; nil when the value is not an ID.
--
-- For rotation specializations (Core/rotation_selection.lua, Core/imports.lua).
function addon:GetSpecializationName(id)
    return (specName(id))
end

-- Gets the class token that owns a specialization ID.
-- @param id any  The specialization ID.
-- @return string|nil  The class token; nil when the value is not an ID or the class is unknown.
function addon:GetSpecializationClassToken(id)
    if specID(id) then
        return specClass(id)
    end
end

-- ============================================================================
-- SPECIALIZATION condition
-- ============================================================================

-- SPECIALIZATION tests the player's talent specialization. Returns false for a specialization of another class, and
-- nil and a reason when the specialization cannot be read (build-context-unavailable, class-unavailable,
-- unknown-specialization, or the observation's own reason such as no specialization chosen yet or tied trees). Stores
-- spec (a specialization ID).
addon:RegisterCondition("SPECIALIZATION", {
    description = L["Specialization"],
    icon = addon.Artwork.condition["SPECIALIZATION"],
    requiredFields = { "spec" },
    fields = { spec = "number" },
    -- Checks that the saved fields of the SPECIALIZATION condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a whole-number specialization ID.
    valid = function(_, value)
        return specID(value.spec)
    end,
    -- Reports whether the saved condition can work on this client.
    -- @param value any  The saved condition fields; anything but a table with a valid spec gives nil.
    -- @return string|nil  "specialization-unsupported" when the saved specialization belongs to your own class on
    --     Forever, where it can never be read; nil otherwise.
    --
    -- Client support (Core/condition_support.lua): Forever has no specializations, so one of your own class can never
    -- be read there; another class's specialization is an ordinary false.
    supported = function(value)
        if type(value) ~= "table" or not specID(value.spec) then return nil end
        if addon.Platform:GetClientFamily() ~= "forever" then return nil end
        local class = playerClass()
        if class == nil or (canaccessvalue and not canaccessvalue(class)) then return nil end
        if specClass(value.spec) == class then return "specialization-unsupported" end
    end,
    -- Decides whether the player's talent specialization is the chosen one; false for a specialization of another
    -- class.
    -- @param value table  The saved condition fields.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: build-context-unavailable (the context module is absent), unknown-specialization (no class, or no
    -- tree for the ID on a tree client), class-unavailable, or the reason the observation gives. On tree clients the
    -- saved ID is mapped to its tree index; elsewhere the IDs are compared directly.
    evaluate = function(value)
        if not addon.GetPlayerSpecializationObservation then return nil, "build-context-unavailable" end
        local mode, current, reason, class = addon:GetPlayerSpecializationObservation()
        local wanted = specClass(value.spec)
        if wanted == nil then return nil, "unknown-specialization" end
        if class == nil then return nil, "class-unavailable" end
        if wanted ~= class then return false end
        if current == nil then return nil, reason or "specialization-unavailable" end
        if mode == "tree" then
            local known = SPECS[value.spec]
            if not known or known[2] == nil then return nil, "unknown-specialization" end
            return known[2] == current
        end
        return current == value.spec
    end,
    -- Builds the readable rule summary for the SPECIALIZATION condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        return string.format(L["your specialization {{!is|is not}} %s"],
            Functions.presentation.nullable((specName(value.spec)), L["<specialization>"]))
    end,
    -- Builds the editor controls for the SPECIALIZATION condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: a class dropdown that filters the specialization dropdown; changing the class clears the specialization.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local selectedClass = specID(value.spec) and specClass(value.spec) or playerClass()

        local specPicker
        local class = addon:CreateConditionDropdown()
        class:SetLabel(L["Class"])
        class:SetCallback("OnValueChanged", function(_, _, v)
            if v == selectedClass then return end
            selectedClass, value.spec = v, nil
            local choices, order = classChoices(v)
            specPicker:SetList(choices, order)
            specPicker:SetValue(nil)
            top:SetStatusText(funcs:print(root, spec))
        end)
        class.configure = function()
            class:SetList(LOCALIZED_CLASS_NAMES_MALE, CLASS_SORT_ORDER)
            class:SetValue(selectedClass)
        end
        parent:AddChild(class)

        specPicker = addon:CreateConditionDropdown()
        specPicker:SetLabel(L["Specialization"])
        specPicker:SetCallback("OnValueChanged", function(_, _, v)
            value.spec = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        specPicker.configure = function()
            local choices, order = classChoices(selectedClass)
            specPicker:SetList(choices, order)
            specPicker:SetValue(value.spec)
        end
        parent:AddChild(specPicker)
    end,
    -- Builds the help page for the SPECIALIZATION condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the general text, then the per-edition notes.
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Your talent specialization. Choose a class, then one of its specializations; your own class is selected first, and other classes are offered for rotations shared between characters. A specialization of another class is always false."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Retail and Mists of Pandaria Classic compare your active specialization. Classic Era, Burning Crusade and Wrath compare your primary talent tree, the one tree with the most points; Feral and Guardian both mean Feral Combat there. Forever cannot tell its specializations apart this way. No specialization yet, tied or unspent trees and unreadable values are unavailable, including under NOT. The answer is cached until your talents or specialization change."]))
    end,
})

-- ============================================================================
-- Profile seeding
-- ============================================================================

-- Cold, one-time seed for profiles created before these predicates existed:
-- SPECIALIZATION joins Character, WEAPON_TYPE (Conditions/equipment.lua)
-- joins Items, and both join the Switch picker, once per profile under their
-- own flag. Removing them later stays saved; new and reset profiles get them
-- from the packaged defaults.
-- Each category value is the id of the condition group in the profile's condition_groups.
local loadoutSeeds = {
    { category = "b8136123-2bda-4230-a77a-89ea2aed3a1a", tag = "SPECIALIZATION" },
    { category = "fca4ff75-4085-458a-b5bf-27a6b52f2092", tag = "WEAPON_TYPE" },
}

-- Adds each seeded loadout condition tag to the profile's Switch picker list and its condition group, once.
-- @param _ any  Unused; the callback event name when called by AceDB.
-- @param db table|nil  The AceDB object; a nil database or a malformed profile is skipped rather than repaired.
--
-- The flag profile.loadoutConditionsSeeded is set afterwards and makes later calls do nothing.
function addon:InitializeLoadoutConditions(_, db)
    local profile = db and db.profile

    if type(profile) ~= "table" or profile.loadoutConditionsSeeded then
        return
    end

    -- Appends a tag to the list unless it is already there.
    -- @param list any  The array of condition tags to extend; anything but a table is ignored.
    -- @param tag string  The condition tag to add.
    local function append(list, tag)
        if type(list) ~= "table" then
            return
        end

        for _, existing in ipairs(list) do
            if existing == tag then
                return
            end
        end

        list[#list + 1] = tag
    end

    for _, seed in ipairs(loadoutSeeds) do
        append(profile.switch_conditions, seed.tag)

        for _, category in ipairs(type(profile.condition_groups) == "table" and profile.condition_groups or {}) do
            if type(category) == "table" and category.id == seed.category then
                append(category.conditions, seed.tag)
            end
        end
    end

    profile.loadoutConditionsSeeded = true
end

-- The key under which this module registers its AceDB callbacks.
local seedOwner = {}

-- Seeds the current profile now and again whenever a profile is created, reset, switched or copied, so every profile
-- gets the loadout conditions exactly once.
-- @param db table|nil  The AceDB object; anything without a RegisterCallback function is ignored.
--
-- Called once from addon:init with the AceDB object.
function addon:InstallLoadoutConditions(db)
    if type(db) ~= "table" or type(db.RegisterCallback) ~= "function" then
        return
    end

    for _, event in ipairs({ "OnNewProfile", "OnProfileReset", "OnProfileChanged", "OnProfileCopied" }) do
        db.RegisterCallback(seedOwner, event, function(_, currentDB)
            addon:InitializeLoadoutConditions(nil, currentDB)
        end)
    end

    self:InitializeLoadoutConditions(nil, db)
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="CLASS_IDS" then return CLASS_IDS end
        if name=="SPECS" then return SPECS end
        if name=="SPEC_ORDER" then return SPEC_ORDER end
        if name=="classChoices" then return classChoices end
        if name=="helpers" then return helpers end
        if name=="playerClass" then return playerClass end
        if name=="specClass" then return specClass end
        if name=="specID" then return specID end
        if name=="specName" then return specName end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/specialization.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/specialization.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
