local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color = color

-- From constants
local operators = addon.operators

-- From utils
local compare, compareString, nullable, isin, getCached, getRetryCached, round =
    addon.compare, addon.compareString, addon.nullable, addon.isin, addon.getCached, addon.getRetryCached, addon.round

local helpers = addon.help_funcs
local CreateText, Gap = helpers.CreateText, helpers.Gap

local function get_item_array(items)
    local itemsets = addon.db.char.itemsets
    local global_itemsets = addon.db.global.itemsets

    if type(items) == "string" then
        local itemset
        if itemsets[items] ~= nil then
            itemset = itemsets[items]
        elseif global_itemsets[items] ~= nil then
            itemset = global_itemsets[items]
        end
        if itemset ~= nil then
            return itemset.items
        else
            return nil
        end
    else
        return items
    end
end

local function get_item_desc(items)
    local itemsets = addon.db.char.itemsets
    local global_itemsets = addon.db.global.itemsets

    if type(items) == "string" then
        if itemsets[items] ~= nil then
            return string.format(L["a %s item set item"], color.WHITE .. itemsets[items].name .. color.RESET)
        elseif global_itemsets[items] ~= nil then
            return string.format(L["a %s item set item"], color.CYAN .. global_itemsets[items].name .. color.RESET)
        end
    elseif items and #items > 0 then
        local link = select(2, getRetryCached(addon.longtermCache, GetItemInfo, items[1])) or items[1]
        if #items > 1 then
            return string.format(L["%s or %d others"], link, #items-1)
        else
            return link
        end
    end
    return nil
end

addon:RegisterCondition(L["Spells / Items"], "EQUIPPED", {
    description = L["Have Item Equipped"],
    icon = "Interface\\Icons\\Ability_warrior_shieldbash",
    valid = function(_, value)
        return value.item ~= nil
    end,
    evaluate = function(value)
        for _, item in pairs(get_item_array(value.item)) do
            if getCached(addon.combatCache, IsEquippedItem, item) then
                return true
            end
        end
        return false
    end,
    print = function(_, value)
        return string.format(L["you have %s equipped"], nullable(get_item_desc(value.item), L["<item>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, value,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)
    end,
    help = function(frame)
        addon.layout_condition_itemwidget_help(frame)
    end
})

addon:RegisterCondition(L["Spells / Items"], "CARRYING", {
    description = L["Have Item In Bags"],
    icon = "Interface\\Icons\\inv_misc_bag_07",
    valid = function(_, value)
        return (value.item ~= nil and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local itemid = addon:FindFirstItemOfItems(cache, get_item_array(value.item), false)
        local count = 0
        if itemid and addon.bagContents[itemid] then
            count = addon.bagContents[itemid].count
        end
        return compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        return compareString(value.operator,
                string.format(L["the number of %s you are carrying"], nullable(get_item_desc(value.item), L["<item>"])),
                nullable(value.value, L["<quantity>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, value,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Quantity"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_itemwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Have Item In Bags"], L["Quantity"],
            "The quantity of " .. color.BLIZ_YELLOW .. L["Item"] .. color.RESET .. " you are carrying in your bags.")
    end
})

addon:RegisterCondition(L["Spells / Items"], "ITEM", {
    description = L["Item Available"],
    icon = "Interface\\Icons\\Inv_drink_05",
    valid = function(_, value)
        return value.item ~= nil
    end,
    evaluate = function(value, cache, evalStart) -- Cooldown until the spell is available
        local itemId = addon:FindFirstItemOfItems(cache, get_item_array(value.item), true)
        if itemId == nil and value.notcarrying then
            itemId = addon:FindFirstItemInItems(get_item_array(value.item))
        end
        if itemId ~= nil then
            local minlevel = select(5, getRetryCached(addon.longtermCache, GetItemInfo, itemId))
            -- Can't use it as we are too low level!
            if minlevel > getCached(cache, UnitLevel, "player") then
                return false
            end
            local start, duration = getCached(cache, GetI, _, _, _, _, castertemCooldown, itemId)
            if start == 0 and duration == 0 then
                return true
            else
                -- A special spell that shows if the GCD is active ...
                local gcd_start, gcd_duration = getCached(cache, GetSpellCooldown, 61304)
                if gcd_start ~= 0 and gcd_duration ~= 0 then
                    local time = GetTime()
                    local gcd_remain = round(gcd_duration - (time - gcd_start), 3)
                    local remain = round(duration - (time - start), 3)
                    if (remain <= gcd_remain) then
                        return true
                        -- We factor in a fuzziness because we don't know exactly when the spell cooldown calls
                        -- were made, so we say any value between now and the evaluation start is essentially 0
                    elseif (remain - gcd_remain <= time - evalStart) then
                        return true
                    else
                        return false
                    end
                end
                return false
            end
        else
            return false
        end
    end,
    print = function(_, value)
        return string.format(L["%s is available"], nullable(get_item_desc(value.item), L["<item>"])) ..
                (value.carrying and L[", even if you do not currently have one"] or "")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, value,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local notcarring = AceGUI:Create("CheckBox")
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
        addon.layout_condition_itemwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end
})

addon:RegisterCondition(L["Spells / Items"], "ITEM_RANGE", {
    description = L["Item In Range"],
    icon = "Interface\\Icons\\inv_misc_bandage_13",
    valid = function(_, value)
        return value.item ~= nil
    end,
    evaluate = function(value, cache)
        local itemId = addon:FindFirstItemOfItems(cache, get_item_array(value.item), true)
        if itemId == nil and value.notcarrying then
            itemId = addon:FindFirstItemInItems(get_item_array(value.item))
        end
        if itemId ~= nil then
            return (getCached(cache, IsItemInRange, itemId, "target") == 1)
        end
        return false
    end,
    print = function(_, value)
        return string.format(L["%s is in range"], nullable(get_item_desc(value.item), L["<item>"])) ..
            (value.carrying and L[", even if you do not currently have one"] or "")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, value,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local notcarring = AceGUI:Create("CheckBox")
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
        addon.layout_condition_itemwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end
})

addon:RegisterCondition(L["Spells / Items"], "ITEM_COOLDOWN", {
    description = L["Item Cooldown"],
    icon = "Interface\\Icons\\Spell_holy_sealofsacrifice",
    valid = function(_, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.item ~= nil and value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache) -- Cooldown until the spell is available
        local itemId = addon:FindFirstItemOfItems(cache, get_item_array(value.item), true)
        if itemId == nil and value.notcarrying then
            itemId = addon:FindFirstItemInItems(get_item_array(value.item))
        end
        if itemId ~= nil then
            local cooldown = 0
            local start, duration = getCached(cache, GetItemCooldown, itemId)
            if start ~= 0 and duration ~= 0 then
                cooldown = round(duration - (GetTime() - start), 3)
                if (cooldown < 0) then cooldown = 0 end
            end
            return compare(value.operator, cooldown, value.value)
        end
        return false
    end,
    print = function(_, value)
        return string.format(L["the %s"],
            compareString(value.operator, string.format(L["cooldown on %s"], nullable(get_item_desc(value.item), L["<item>"])),
                                string.format(L["%s seconds"], nullable(value.value)))) ..
                (value.carrying and L[", even if you do not currently have one"] or "")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, value,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local notcarring = AceGUI:Create("CheckBox")
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
        addon.layout_condition_itemwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Item Cooldown"], L["Seconds"],
            "The number of seconds before you can use the top item found in " .. color.BLIZ_YELLOW .. L["Item Set"] ..
            color.RESET .. ".  If you are not carrying any item in the item set, this condition will not be " ..
            "successful (regardless of the " .. color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end
})
