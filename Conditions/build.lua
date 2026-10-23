local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Action context and build context conditions. They read the event-driven
-- caches (main.lua action context, Core/build_context.lua), never scan per
-- poll. Missing providers or pending data are unavailable, including under NOT.
local Functions={
    cache={getCached=addon.Functions.cache.getCached},
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable},
}
local Summary={
    phrase=addon.Functions.presentation.phrase,
    predicate=addon.Functions.presentation.predicate,
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/build.lua"]={
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Summary.phrase"]="builtin:Functions/presentation.lua:phrase",
    ["Summary.predicate"]="builtin:Functions/presentation.lua:predicate",
}

addon.actionContexts = {
    player = L["your own action bar"],
    vehicle = L["a vehicle"],
    possession = L["a possessed unit"],
    override = L["an override action bar"],
    petbattle = L["a pet battle"],
}
local actionContextOrder = { "player", "vehicle", "possession", "override", "petbattle" }

local function wholeNumber(value)
    return type(value)=="number" and value>0 and value<math.huge and value%1==0
end
local function setLabel(id)
    if not wholeNumber(id) then return nil end
    local name=addon.GetItemSetName and addon:GetItemSetName(id)
    if name then return string.format(L["%s (set %d)"], name, id) end
    return string.format(L["item set %d"], id)
end

-- Temporary weapon enchant: GetWeaponEnchantInfo returns has, expires,
-- charges, enchant ID for the main hand (1-4) and the off hand (5-8).
local function imbueObservation(value, cache)
    if type(GetWeaponEnchantInfo) ~= "function" then return nil, "missing-api" end
    ---@diagnostic disable-next-line: unbalanced-assignments
    local ok, main, _, _, mainID, off, _, _, offID = pcall(Functions.cache.getCached, cache, GetWeaponEnchantInfo)
    if not ok then return nil, "api-error" end
    local enchanted, id = main, mainID
    if value.offhand then enchanted, id = off, offID end
    if not addon.Platform:CanReadValue(enchanted) or not addon.Platform:CanReadValue(id) then return nil, "restricted-value" end
    if enchanted == nil or enchanted == false or enchanted == 0 then return false end
    if type(id) ~= "number" then return nil, "invalid-weapon-observation" end
    return id
end

addon:RegisterCondition("ACTION_CONTEXT", {
    description = L["Action Context"],
    icon = addon.Artwork.condition["ACTION_CONTEXT"],
    requiredFields = { "context" },
    fields = { context = "string" },
    valid = function(_, value)
        return value.context ~= nil and addon.actionContexts[value.context] ~= nil
    end,
    evaluate = function(value)
        if not addon.GetActionContext then return nil, "action-context-unavailable" end
        return addon:GetActionContext() == value.context
    end,
    print = function(_, value)
        return string.format(L["you {{!are|are not}} acting through %s"],
            Functions.presentation.nullable(addon.actionContexts[value.context], L["<action bar>"]))
    end,
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
    end
})

addon:RegisterCondition("SET_PIECES", {
    description = L["Item Set Pieces Equipped"],
    icon = addon.Artwork.condition["SET_PIECES"],
    requiredFields = { "set", "operator", "value" },
    fields = { set = "number", operator = "string", value = "number" },
    valid = function(_, value)
        return wholeNumber(value.set) and value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)
            and type(value.value) == "number" and value.value >= 0 and value.value < math.huge
    end,
    evaluate = function(value)
        if not addon.GetEquippedSetPieces then return nil, "build-context-unavailable" end
        local count, reason = addon:GetEquippedSetPieces(value.set)
        if count == nil then return nil, reason end
        return Functions.values.compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        return Summary.phrase(L["the number of {set} pieces you have equipped {comparison} {quantity}"], {
            set = Functions.presentation.nullable(setLabel(value.set), L["<item set>"]),
            comparison = Summary.predicate(value.operator, true),
            quantity = Functions.presentation.nullable(value.value, L["<quantity>"]),
        })
    end,
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
    end
})

if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
    addon:RegisterCondition("WEAPON_IMBUE", {
        description = L["Weapon Enchant Type"],
        icon = addon.Artwork.condition["WEAPON_IMBUE"],
        requiredFields = { "enchant" },
        fields = { offhand = "boolean", enchant = "number" },
        valid = function(_, value)
            return wholeNumber(value.enchant) and (value.offhand == nil or type(value.offhand) == "boolean")
        end,
        evaluate = function(value, cache)
            local id, reason = imbueObservation(value, cache)
            if id == nil then return nil, reason end
            return id == value.enchant
        end,
        print = function(_, value)
            return string.format(L["your %s weapon {{!has|does not have}} temporary enchant %s"],
                (value.offhand and L["off hand"] or L["main hand"]),
                Functions.presentation.nullable(value.enchant, L["<enchant>"]))
        end,
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
        end
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
