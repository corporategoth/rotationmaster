local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

local function itemHelp(frame)
    addon.layout_condition_itemwidget_help(frame)
    frame:AddChild(helpers.Gap())
    frame:AddChild(helpers.CreateText(L["Item sets are checked in priority order. Bag counts use the first carried candidate, not the sum. Availability, range and cooldown checks use the first carried or equipped candidate. Missing or restricted observations stay unavailable, including under NOT."]))
end

local function get_item_desc(items)
    if not addon:IsConditionItemReference(items) then return nil end
    local itemsets = addon.db.profile.itemsets
    local global_itemsets = addon.db.global.itemsets
    if itemsets~=nil and type(itemsets)~='table' or global_itemsets~=nil and type(global_itemsets)~='table' then return nil end

    if type(items) == "string" then
        local set=(itemsets or {})[items];local tint=color.WHITE
        if set==nil then set=(global_itemsets or {})[items];tint=color.CYAN end
        if type(set)=='table' and type(set.name)=='string' then return string.format(L["a %s item set item"],tint..set.name..color.RESET) end
    elseif items and #items > 0 then
        local info=addon.Platform:GetItemMetadata(items[1])
        local link=info and (info.link or info.name) or items[1]
        if #items > 1 then
            return string.format(L["%s or %d others"], link, #items-1)
        else
            return link
        end
    end
    return nil
end

addon:RegisterCondition("EQUIPPED", {
    description = L["Have Item Equipped"],
    icon = "Interface\\Icons\\Ability_warrior_shieldbash",
    requiredFields={'item'},
    fields = { item = { "string", { "string", "number" } } },
    valid = function(_, value)
        return addon:IsConditionItemReference(value.item) and (value.notcarrying==nil or type(value.notcarrying)=="boolean")
    end,
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("EQUIPPED",value,cache,now)
    end,
    print = function(_, value)
        return string.format(L["you {{!have|do not have}} %s equipped"], addon.nullable(get_item_desc(value.item), L["<item>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)
    end,
    help = function(frame)
        itemHelp(frame)
    end
})

addon:RegisterCondition("CARRYING", {
    description = L["Have Item In Bags"],
    icon = "Interface\\Icons\\inv_misc_bag_07",
    requiredFields={'item','operator','value'},
    fields = { item = { "string", { "string", "number" } }, operator = "string", value = "number" },
    valid = function(_, value)
        return (addon:IsConditionItemReference(value.item) and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                type(value.value)=="number" and value.value>=0 and value.value<math.huge)
    end,
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("CARRYING",value,cache,now)
    end,
    print = function(_, value)
        return addon.compareString(value.operator,
                string.format(L["the number of %s you are carrying"], addon.nullable(get_item_desc(value.item), L["<item>"])),
                addon.nullable(value.value, L["<quantity>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Quantity"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        itemHelp(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Have Item In Bags"], L["Quantity"],
            "The quantity of " .. color.BLIZ_YELLOW .. L["Item"] .. color.RESET .. " you are carrying in your bags.")
    end
})

addon:RegisterCondition("ITEM", {
    description = L["Item Available"],
    icon = "Interface\\Icons\\Inv_drink_05",
    requiredFields={'item'},
    fields = { item = { "string", { "string", "number" } }, notcarrying = "boolean" },
    valid = function(_, value)
        return addon:IsConditionItemReference(value.item) and (value.notcarrying==nil or type(value.notcarrying)=="boolean")
    end,
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("ITEM",value,cache,now)
    end,
    print = function(_, value)
        return string.format(L["%s {{!is|is not}} available"], addon.nullable(get_item_desc(value.item), L["<item>"])) ..
                (value.notcarrying and L[", even if you do not currently have one"] or "")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
                function() return true end,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local notcarring = addon:CreateConditionCheckBox()
        notcarring:SetWidth(200)
        notcarring:SetLabel(L["Check If Not Carrying"])
        notcarring:SetValue(value.notcarrying)
        notcarring:SetCallback("OnValueChanged", function(_, _, v)
            value.notcarrying = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(notcarring)
    end,
    help = function(frame)
        itemHelp(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Item Available checks the required level and enabled item cooldown. An active cooldown qualifies only when it ends with the readable global cooldown. This condition does not bypass the action's implicit ownership, usability and range checks."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end
})

addon:RegisterCondition("ITEM_RANGE", {
    description = L["Item In Range"],
    icon = "Interface\\Icons\\inv_misc_bandage_13",
    requiredFields={'item'},
    fields = { item = { "string", { "string", "number" } }, notcarrying = "boolean" },
    valid = function(_, value)
        return addon:IsConditionItemReference(value.item) and (value.notcarrying==nil or type(value.notcarrying)=="boolean")
    end,
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("ITEM_RANGE",value,cache,now)
    end,
    print = function(_, value)
        return string.format(L["%s {{!is|is not}} in range"], addon.nullable(get_item_desc(value.item), L["<item>"])) ..
            (value.notcarrying and L[", even if you do not currently have one"] or "")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
                function() return true end,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local notcarring = addon:CreateConditionCheckBox()
        notcarring:SetWidth(200)
        notcarring:SetLabel(L["Check If Not Carrying"])
        notcarring:SetValue(value.notcarrying)
        notcarring:SetCallback("OnValueChanged", function(_, _, v)
            value.notcarrying = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(notcarring)
    end,
    help = function(frame)
        itemHelp(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end
})

addon:RegisterCondition("ITEM_COOLDOWN", {
    description = L["Item Cooldown"],
    icon = "Interface\\Icons\\Spell_holy_sealofsacrifice",
    requiredFields={'item','operator','value'},
    fields = { item = { "string", { "string", "number" } }, notcarrying = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                addon:IsConditionItemReference(value.item) and (value.notcarrying==nil or type(value.notcarrying)=="boolean") and type(value.value)=="number" and value.value>=0 and value.value<math.huge)
    end,
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("ITEM_COOLDOWN",value,cache,now)
    end,
    print = function(_, value)
        return string.format(L["the %s"],
            addon.compareString(value.operator, string.format(L["cooldown on %s"], addon.nullable(get_item_desc(value.item), L["<item>"])),
                                string.format(L["%s seconds"], addon.nullable(value.value)))) ..
                (value.notcarrying and L[", even if you do not currently have one"] or "")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
                function() return true end,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local notcarring = addon:CreateConditionCheckBox()
        notcarring:SetWidth(200)
        notcarring:SetLabel(L["Check If Not Carrying"])
        notcarring:SetValue(value.notcarrying)
        notcarring:SetCallback("OnValueChanged", function(_, _, v)
            value.notcarrying = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(notcarring)
    end,
    help = function(frame)
        itemHelp(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Item Cooldown"], L["Seconds"],
            "The number of seconds before you can use the top item found in " .. color.BLIZ_YELLOW .. L["Item Set"] ..
            color.RESET .. ".  If you are not carrying any item in the item set, this condition will not be " ..
            "successful (regardless of the " .. color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end
})

-- BEGIN GENERATED RM SOURCE BINDINGS
if addon.RegisterBuiltinSourceModule then
    addon:RegisterBuiltinSourceModule("Conditions/item.lua", function(name)
        if name=="color" then return color end
        if name=="get_item_desc" then return get_item_desc end
        if name=="helpers" then return helpers end
        if name=="itemHelp" then return itemHelp end
    end)
end
-- END GENERATED RM SOURCE BINDINGS
