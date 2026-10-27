-- Layered inverse for the trinket slot of ITEM_COOLDOWN: the block of Conditions/item.lua
-- that registers ITEM_COOLDOWN (with the trinket slot locals before it) is replaced by the
-- registration as it was before the slot option (its print body is the current one, which
-- restore_item_neighbor_summary_literals then inverts), and the two generated getter lines
-- for the new locals are dropped. Apply it before that older inverse.
local current=[==[
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

]==]
local previous=[==[
addon:RegisterCondition("ITEM_COOLDOWN", {
    description = L["Item Cooldown"],
    icon = addon.Artwork.condition["ITEM_COOLDOWN"],
    requiredFields={'item','operator','value'},
    fields = { item = { "string", { "string", "number" } }, notcarrying = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                addon:IsConditionItemReference(value.item) and (value.notcarrying==nil or type(value.notcarrying)=="boolean") and type(value.value)=="number" and value.value>=0 and value.value<math.huge)
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

]==]
local getter=[==[
        if name=="TRINKET_SLOTS" then return TRINKET_SLOTS end
        if name=="TRINKET_SLOT_ORDER" then return TRINKET_SLOT_ORDER end
]==]
local function swap(text,from,to,what)
    local start,ending=text:find(from,1,true)
    assert(start and not text:find(from,ending+1,true),'unexpected ITEM_COOLDOWN slot '..what..'/count')
    return text:sub(1,start-1)..to..text:sub(ending+1)
end
return function(text)
    assert(type(text)=='string','item slot inverse needs source text')
    return swap(swap(text,current,previous,'block'),getter,'','getter')
end,previous,current
