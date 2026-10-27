local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Select pure helpers from their actual owners for authored and cloned callbacks.
local Functions={
    values={isin=addon.Functions.values.isin},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString},
}
local Summary={
    phrase=addon.Functions.presentation.phrase,
    predicate=addon.Functions.presentation.predicate,
}
local Literal={phrase=addon.Functions.presentation.phrase}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/item.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Literal.phrase"]="builtin:Functions/presentation.lua:phrase",
    ["Summary.phrase"]="builtin:Functions/presentation.lua:phrase",
    ["Summary.predicate"]="builtin:Functions/presentation.lua:predicate",
}

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
    icon = addon.Artwork.condition["EQUIPPED"],
    requiredFields={'item'},
    fields = { item = { "string", { "string", "number" } } },
    valid = function(_, value)
        return addon:IsConditionItemReference(value.item) and (value.notcarrying==nil or type(value.notcarrying)=="boolean")
    end,
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("EQUIPPED",value,cache,now)
    end,
    print = function(_, value)
        return Literal.phrase(L["you {{!have|do not have}} {item} equipped"], {item = Functions.presentation.nullable(get_item_desc(value.item), L["<item>"])})
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
    icon = addon.Artwork.condition["CARRYING"],
    requiredFields={'item','operator','value'},
    fields = { item = { "string", { "string", "number" } }, operator = "string", value = "number" },
    valid = function(_, value)
        return (addon:IsConditionItemReference(value.item) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                type(value.value)=="number" and value.value>=0 and value.value<math.huge)
    end,
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("CARRYING",value,cache,now)
    end,
    print = function(_, value)
        return Summary.phrase(L["the number of {item} you are carrying {comparison} {quantity}"], {
            item = Functions.presentation.nullable(get_item_desc(value.item), L["<item>"]),
            comparison = Summary.predicate(value.operator, true),
            quantity = Functions.presentation.nullable(value.value, L["<quantity>"]),
        })
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
    icon = addon.Artwork.condition["ITEM"],
    requiredFields={'item'},
    fields = { item = { "string", { "string", "number" } }, notcarrying = "boolean" },
    valid = function(_, value)
        return addon:IsConditionItemReference(value.item) and (value.notcarrying==nil or type(value.notcarrying)=="boolean")
    end,
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("ITEM",value,cache,now)
    end,
    print = function(_, value)
        return Literal.phrase(L["{item} {{!is|is not}} available{carrying}"], {
            item = Functions.presentation.nullable(get_item_desc(value.item), L["<item>"]),
            carrying = value.notcarrying and L[", even if you do not currently have one"] or "",
        })
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
    icon = addon.Artwork.condition["ITEM_RANGE"],
    requiredFields={'item'},
    fields = { item = { "string", { "string", "number" } }, notcarrying = "boolean" },
    valid = function(_, value)
        return addon:IsConditionItemReference(value.item) and (value.notcarrying==nil or type(value.notcarrying)=="boolean")
    end,
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("ITEM_RANGE",value,cache,now)
    end,
    print = function(_, value)
        return Literal.phrase(L["{item} {{!is|is not}} in range{carrying}"], {
            item = Functions.presentation.nullable(get_item_desc(value.item), L["<item>"]),
            carrying = value.notcarrying and L[", even if you do not currently have one"] or "",
        })
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

-- The trinket slots ITEM_COOLDOWN can read instead of a named item (inventory slots 13 and 14).
local TRINKET_SLOTS = { [13] = L["Trinket 1"], [14] = L["Trinket 2"] }
local TRINKET_SLOT_ORDER = { 13, 14 }

-- Either an item (or item set) is named, or a trinket slot is chosen and the item is ignored.
addon:RegisterCondition("ITEM_COOLDOWN", {
    description = L["Item Cooldown"],
    icon = addon.Artwork.condition["ITEM_COOLDOWN"],
    requiredFields={'operator','value'},
    fields = { item = { "string", { "string", "number" } }, slot = "number", notcarrying = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        local source
        if value.slot ~= nil then source = Functions.values.isin(TRINKET_SLOTS, value.slot) else source = addon:IsConditionItemReference(value.item) end
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                source and (value.notcarrying==nil or type(value.notcarrying)=="boolean") and type(value.value)=="number" and value.value>=0 and value.value<math.huge)
    end,
    evaluate = function(value, cache, now)
        return addon:EvaluateItemCondition("ITEM_COOLDOWN",value,cache,now)
    end,
    print = function(_, value)
        if value.slot ~= nil then
            return Functions.presentation.compareString(value.operator,
                string.format(L["the cooldown on your %s"], Functions.presentation.nullable(TRINKET_SLOTS[value.slot], L["<trinket slot>"])),
                string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
        end
        return Summary.phrase(L["the cooldown on {item} {comparison} {duration}{carrying}"], {
            item = Functions.presentation.nullable(get_item_desc(value.item), L["<item>"]),
            comparison = Summary.predicate(value.operator, true),
            duration = string.format(L["%s seconds"], Functions.presentation.nullable(value.value)),
            carrying = value.notcarrying and L[", even if you do not currently have one"] or "",
        })
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
                function() return true end,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        -- Optional: read a trinket slot instead of the item above.
        local slot = addon:CreateConditionDropdown()
        slot:SetLabel(L["Trinket Slot"])
        slot:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then value.slot = nil else value.slot = v end
            top:SetStatusText(funcs:print(root, spec))
        end)
        slot.configure = function()
            local choices, order = { [""] = L["None (use the item above)"] }, { "" }
            for _, key in ipairs(TRINKET_SLOT_ORDER) do choices[key] = TRINKET_SLOTS[key]; order[#order + 1] = key end
            slot:SetList(choices, order)
            slot:SetValue(value.slot ~= nil and value.slot or "")
        end
        parent:AddChild(slot)

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
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Trinket Slot"] .. color.RESET .. " - " .. L["Help.Conditions.ITEM_COOLDOWN_SLOT"]))
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
do
    local function sourceGetter(name)
        if name=="TRINKET_SLOTS" then return TRINKET_SLOTS end
        if name=="TRINKET_SLOT_ORDER" then return TRINKET_SLOT_ORDER end
        if name=="color" then return color end
        if name=="get_item_desc" then return get_item_desc end
        if name=="helpers" then return helpers end
        if name=="itemHelp" then return itemHelp end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/item.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/item.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
