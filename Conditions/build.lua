-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In conditions about which bar you act through and what you are wearing: ACTION_CONTEXT (your own bar, a
-- vehicle, a possessed unit, an override bar or a pet battle), SET_PIECES (compares the number of equipped pieces of an
-- item set) and WEAPON_IMBUE (the temporary enchant ID on the main or off hand). ACTION_CONTEXT reads
-- addon:GetActionContext (main.lua) and SET_PIECES reads the cached build snapshot (Core/build_context.lua), so
-- neither scans per poll; a missing provider or pending item data is unavailable (nil, reason), also under NOT.
-- WEAPON_IMBUE reads the game through imbueObservation, which passes every value through Platform:CanReadValue. The
-- weapon-enchant timers and stacks are in Conditions/weapon.lua. Loaded from RotationMaster.toc after
-- Conditions/equipment.lua. Callback and helper bodies are hashed by saved copies and bundles: never add or change
-- text inside a function body, and leave the generated block at the end alone.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Action context and build context conditions. They read the event-driven
-- caches (main.lua action context, Core/build_context.lua), never scan per
-- poll. Missing providers or pending data are unavailable, including under NOT.
local Functions = {
    cache = { getCached = addon.Functions.cache.getCached },
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = { nullable = addon.Functions.presentation.nullable },
}

local Summary = {
    phrase = addon.Functions.presentation.phrase,
    predicate = addon.Functions.presentation.predicate,
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/build.lua"] = {
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Summary.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["Summary.predicate"] = "builtin:Functions/presentation.lua:predicate",
}

-- ============================================================================
-- Helpers
-- ============================================================================

-- Display labels for the bars you can act through, keyed by the context name addon:GetActionContext returns. Public
-- on addon so other files can list them.
addon.actionContexts = {
    player = L["your own action bar"],
    vehicle = L["a vehicle"],
    possession = L["a possessed unit"],
    override = L["an override action bar"],
    petbattle = L["a pet battle"],
}

-- The order the editor lists the action contexts in.
local actionContextOrder = { "player", "vehicle", "possession", "override", "petbattle" }

-- True for a positive whole number (a set ID or an enchant ID).
local function wholeNumber(value)
    return type(value)=="number" and value>0 and value<math.huge and value%1==0
end

-- Display label for an item set ID: its name and ID when the game exposes a name, otherwise "item set N". Returns nil
-- for something that is not a valid ID.
local function setLabel(id)
    if not wholeNumber(id) then return nil end
    local name=addon.GetItemSetName and addon:GetItemSetName(id)
    if name then return string.format(L["%s (set %d)"], name, id) end
    return string.format(L["item set %d"], id)
end

-- Temporary weapon enchant: GetWeaponEnchantInfo returns has, expires,
-- charges, enchant ID for the main hand (1-4) and the off hand (5-8). The
-- Platform reader composes the same tuple from Retail's C_PaperDollInfo.
-- Returns the temporary enchant ID on the hand chosen by value.offhand, false when that hand has none, or nil and a
-- reason ("missing-api", "api-error", "restricted-value" when the client hides the values, or
-- "invalid-weapon-observation"). The game call is cached per poll through `cache`; the editor passes a throwaway
-- table.
local function imbueObservation(value, cache)
    local reader = GetWeaponEnchantInfo
    if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then reader = addon.Platform.ComposedWeaponEnchantInfo end
    if type(reader) ~= "function" then return nil, "missing-api" end
    ---@diagnostic disable-next-line: unbalanced-assignments
    local ok, main, _, _, mainID, off, _, _, offID = pcall(Functions.cache.getCached, cache, reader)
    if not ok then return nil, "api-error" end
    local enchanted, id = main, mainID
    if value.offhand then enchanted, id = off, offID end
    if not addon.Platform:CanReadValue(enchanted) or not addon.Platform:CanReadValue(id) then return nil, "restricted-value" end
    if enchanted == nil or enchanted == false or enchanted == 0 then return false end
    if type(id) ~= "number" then return nil, "invalid-weapon-observation" end
    return id
end

-- ============================================================================
-- Action context
-- ============================================================================

-- ACTION_CONTEXT: true when the bar you are acting through (your own, a vehicle, a possessed unit, an override bar or a
-- pet battle) is the chosen one. Stores `context`. Returns `nil, "action-context-unavailable"` when main.lua's reader
-- is missing.
addon:RegisterCondition("ACTION_CONTEXT", {
    description = L["Action Context"],
    icon = addon.Artwork.condition["ACTION_CONTEXT"],
    requiredFields = { "context" },
    fields = { context = "string" },
    -- Valid once one of the listed action contexts is chosen.
    valid = function(_, value)
        return value.context ~= nil and addon.actionContexts[value.context] ~= nil
    end,
    -- Unavailable only when addon:GetActionContext does not exist; otherwise compares the current context.
    evaluate = function(value)
        if not addon.GetActionContext then return nil, "action-context-unavailable" end
        return addon:GetActionContext() == value.context
    end,
    -- Readable summary naming the chosen bar.
    print = function(_, value)
        return string.format(L["you {{!are|are not}} acting through %s"],
            Functions.presentation.nullable(addon.actionContexts[value.context], L["<action bar>"]))
    end,
    -- widget builds the action context dropdown; help explains each context.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local context = addon:CreateConditionDropdown()
        context:SetLabel(L["Action Context"])
        context:SetCallback("OnValueChanged", function(_, _, v)
            value.context = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        context.configure = function()
            context:SetList(addon.actionContexts, actionContextOrder)
            if value.context ~= nil then context:SetValue(value.context) end
        end
        parent:AddChild(context)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches the bar you are acting through: your own, a vehicle, a possessed (mind controlled) unit, an override bar, or a pet battle. Vehicles and override bars exist from Wrath, pet battles only on Retail."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["A rotation of your own is used only on your own bar unless its switch condition requires another action context with this condition; it is then used, and its buttons found, while that bar is up."]))
    end,
})

-- ============================================================================
-- Equipment
-- ============================================================================

-- SET_PIECES: compares the number of equipped pieces of one game item set with a number. Stores `set` (the item set
-- ID), `operator` and `value`. Returns `nil, reason` while any equipped item's metadata is still loading
-- ("item-data-pending"), so a count is never understated, or when the build snapshot is unavailable.
addon:RegisterCondition("SET_PIECES", {
    description = L["Item Set Pieces Equipped"],
    icon = addon.Artwork.condition["SET_PIECES"],
    requiredFields = { "set", "operator", "value" },
    fields = { set = "number", operator = "string", value = "number" },
    -- Valid with a set ID, a known operator and a finite, non-negative number.
    valid = function(_, value)
        return wholeNumber(value.set) and value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)
            and type(value.value) == "number" and value.value >= 0 and value.value < math.huge
    end,
    -- Unavailable ("build-context-unavailable", or the snapshot's own reason such as "item-data-pending") when the
    -- count cannot be known; a set with no equipped pieces counts 0.
    evaluate = function(value)
        if not addon.GetEquippedSetPieces then return nil, "build-context-unavailable" end
        local count, reason = addon:GetEquippedSetPieces(value.set)
        if count == nil then return nil, reason end
        return Functions.values.compare(value.operator, count, value.value)
    end,
    -- Readable summary naming the set and the comparison.
    print = function(_, value)
        return Summary.phrase(L["the number of {set} pieces you have equipped {comparison} {quantity}"], {
            set = Functions.presentation.nullable(setLabel(value.set), L["<item set>"]),
            comparison = Summary.predicate(value.operator, true),
            quantity = Functions.presentation.nullable(value.value, L["<quantity>"]),
        })
    end,
    -- widget builds a set ID box, a dropdown of the sets you are wearing and an operator-and-pieces control; help
    -- explains the set ID and the count.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local equipped, order = {}, {}
        local sets = addon.GetEquippedSets and addon:GetEquippedSets()
        for id, count in pairs(sets or {}) do
            equipped[id] = string.format(L["%s, %d equipped"], setLabel(id), count)
            order[#order + 1] = id
        end
        table.sort(order)

        local setID = addon:CreateConditionEditBox()
        local picker = addon:CreateConditionDropdown()
        setID:SetLabel(L["Item Set ID"])
        if value.set ~= nil then setID:SetText(tostring(value.set)) end
        setID:SetCallback("OnEnterPressed", function(_, _, v)
            local number = tonumber(v)
            value.set = wholeNumber(number) and number or nil
            if picker.SetValue then picker:SetValue(value.set) end
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(setID)

        picker:SetLabel(L["Equipped Sets"])
        picker:SetCallback("OnValueChanged", function(_, _, v)
            value.set = v
            setID:SetText(tostring(v))
            top:SetStatusText(funcs:print(root, spec))
        end)
        picker.configure = function()
            picker:SetList(equipped, order)
            if equipped[value.set] then picker:SetValue(value.set) end
        end
        parent:AddChild(picker)

        local operator_group = addon:Widget_OperatorWidget(value, L["Pieces"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Item Set ID"] .. color.RESET .. " - " ..
            L["The game's item set (for example a tier set). Sets you are wearing are offered in the list; the count is taken from your equipped items' metadata and stays unavailable while any of it is still loading."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Item Set Pieces Equipped"], L["Pieces"],
            L["The number of pieces of that set you have equipped."])
    end,
})

-- ============================================================================
-- Temporary weapon enchant
-- ============================================================================

-- Every client, Retail included (Shaman imbues); see Conditions/weapon.lua.
do
    -- WEAPON_IMBUE: true when the temporary enchant on the main hand (or the off hand, when `offhand` is set) is the
    -- chosen enchant ID. False when that hand has no temporary enchant or a different one. Stores `offhand` and
    -- `enchant`. Returns `nil, reason` when imbueObservation cannot read the enchant.
    addon:RegisterCondition("WEAPON_IMBUE", {
        description = L["Weapon Enchant Type"],
        icon = addon.Artwork.condition["WEAPON_IMBUE"],
        requiredFields = { "enchant" },
        fields = { offhand = "boolean", enchant = "number" },
        -- Valid with an enchant ID and, if present, a boolean off hand flag.
        valid = function(_, value)
            return wholeNumber(value.enchant) and (value.offhand == nil or type(value.offhand) == "boolean")
        end,
        -- Unavailable when the weapon enchant API is missing, errors, or returns hidden or malformed values.
        evaluate = function(value, cache)
            local id, reason = imbueObservation(value, cache)
            if id == nil then return nil, reason end
            return id == value.enchant
        end,
        -- Readable summary naming the hand and the enchant ID.
        print = function(_, value)
            return string.format(L["your %s weapon {{!has|does not have}} temporary enchant %s"],
                (value.offhand and L["off hand"] or L["main hand"]),
                Functions.presentation.nullable(value.enchant, L["<enchant>"]))
        end,
        -- widget builds an off hand checkbox, an enchant ID box and a line showing the enchant currently on that hand;
        -- help explains the enchant ID.
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local offhand = addon:CreateConditionCheckBox()
            offhand:SetWidth(100)
            offhand:SetLabel(L["Off Hand"])
            offhand:SetValue(value.offhand and true or false)
            offhand:SetCallback("OnValueChanged", function(_, _, v)
                value.offhand = v
                top:SetStatusText(funcs:print(root, spec))
            end)
            parent:AddChild(offhand)

            local enchant = addon:CreateConditionEditBox()
            enchant:SetLabel(L["Enchant ID"])
            if value.enchant ~= nil then enchant:SetText(tostring(value.enchant)) end
            enchant:SetCallback("OnEnterPressed", function(_, _, v)
                local number = tonumber(v)
                value.enchant = wholeNumber(number) and number or nil
                top:SetStatusText(funcs:print(root, spec))
            end)
            parent:AddChild(enchant)

            local current = imbueObservation(value, {})
            local label = addon:CreateConditionLabel()
            label:SetFullWidth(true)
            label:SetText(type(current) == "number" and string.format(L["Currently: temporary enchant %d"], current)
                or L["Currently: no temporary enchant"])
            parent:AddChild(label)
        end,
        help = function(frame)
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Enchant ID"] .. color.RESET .. " - " ..
                L["The temporary enchant on the weapon: a poison, oil, sharpening stone or weapon imbue. The current enchant ID of the selected hand is shown below the field."]))
        end,
    })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="actionContextOrder" then return actionContextOrder end
        if name=="color" then return color end
        if name=="helpers" then return helpers end
        if name=="imbueObservation" then return imbueObservation end
        if name=="setLabel" then return setLabel end
        if name=="wholeNumber" then return wholeNumber end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/build.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/build.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
