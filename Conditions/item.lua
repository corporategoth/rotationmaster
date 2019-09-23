local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tonumber = tonumber

-- From constants
local operators = addon.operators

-- From utils
local compare, compareString, nullable, isin, getCached, round, isint =
    addon.compare, addon.compareString, addon.nullable, addon.isin, addon.getCached, addon.round, addon.isint

local function get_item_array(items)
    local itemsets = addon.db.char.itemsets
    local global_itemsets = addon.db.global.itemsets

    if type(items) == "string" then
        local itemset = nil
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
        local link = select(2, GetItemInfo(items[1])) or items[1]
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
    valid = function(spec, value)
        return value.item ~= nil
    end,
    evaluate = function(value, cache, evalStart)
        for _, item in pairs(get_item_array(value.item)) do
            if getCached(addon.combatCache, IsEquippedItem, item) then
                return true
            end
        end
        return false
    end,
    print = function(spec, value)
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
})

addon:RegisterCondition(L["Spells / Items"], "CARRYING", {
    description = L["Have Item In Bags"],
    icon = "Interface\\Icons\\inv_misc_bag_07",
    valid = function(spec, value)
        return (value.item ~= nil and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        local count = 0
        for _, item in pairs(get_item_array(value.item)) do
            for i=0,4 do
                for j=1,getCached(addon.combatCache, GetContainerNumSlots, i) do
                    local _, qty, _, _, _, _, _, _, _, itemId = getCached(cache, GetContainerItemInfo, i, j);
                    if itemId ~= nil then
                        if isint(item) then
                            if tonumber(item) == itemId then
                                count = count + qty
                            end
                        else
                            local itemName = getCached(addon.longtermCache, GetItemInfo, itemId)
                            if item == itemName then
                                count = count + qty
                            end
                        end
                    end
                end
            end
            if count > 0 then
                break
            end
        end
        return compare(value.operator, count, value.value)
    end,
    print = function(spec, value)
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
})

addon:RegisterCondition(L["Spells / Items"], "ITEM", {
    description = L["Item Available"],
    icon = "Interface\\Icons\\Inv_drink_05",
    valid = function(spec, value)
        return value.item ~= nil
    end,
    evaluate = function(value, cache, evalStart) -- Cooldown until the spell is available
        local itemId
        for _, item in pairs(get_item_array(value.item)) do
            for i=0,20 do
                local inventoryId = getCached(addon.combatCache, GetInventoryItemID, "player", i)
                if inventoryId ~= nil then
                    if isint(item) then
                        if tonumber(item) == inventoryId then
                            itemId = inventoryId
                            break
                        end
                    else
                        local itemName = getCached(addon.longtermCache, GetItemInfo, inventoryId)
                        if itemName == item then
                            itemId = inventoryId
                            break
                        end
                    end
                end
            end
            if itemId ~= nil then
                break
            end
        end
        if itemId == nil then
            for _, item in pairs(get_item_array(value.item)) do
                for i=0,4 do
                    for j=1,getCached(addon.combatCache, GetContainerNumSlots, i) do
                        local inventoryId = getCached(cache, GetContainerItemID, i, j);
                        if inventoryId ~= nil then
                            if isint(item) then
                                if tonumber(item) == inventoryId then
                                    itemId = inventoryId
                                    break
                                end
                            else
                                local itemName = getCached(addon.longtermCache, GetItemInfo, inventoryId)
                                if item == itemName then
                                    itemId = inventoryId
                                    break
                                end
                            end
                        end
                    end
                    if itemId ~= nil then
                        break
                    end
                end
                if itemId ~= nil then
                    break
                end
            end
        end
        if itemId ~= nil then
            local minlevel = select(5, getCached(addon.longtermCache, GetItemInfo, itemId))
            -- Can't use it as we are too low level!
            if minlevel > getCached(cache, UnitLevel, "player") then
                return false
            end
            local start, duration = getCached(cache, GetItemCooldown, itemId)
            if start == 0 and duration == 0 then
                return true
            else
                -- A special spell that shows if the GCD is active ...
                local gcd_start, gcd_duration, gcd_enabled = getCached(cache, GetSpellCooldown, 61304)
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
    print = function(spec, value)
        return string.format(L["%s is available"], nullable(get_item_desc(value.item), L["<item>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, value,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)
    end,
})

addon:RegisterCondition(L["Spells / Items"], "ITEM_COOLDOWN", {
    description = L["Item Cooldown"],
    icon = "Interface\\Icons\\Spell_holy_sealofsacrifice",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.item ~= nil and value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart) -- Cooldown until the spell is available
        local itemId
        for _, item in pairs(get_item_array(value.item)) do
            for i=0,20 do
                local inventoryId = getCached(addon.combatCache, GetInventoryItemID, "player", i)
                if inventoryId ~= nil then
                    if isint(item) then
                        if tonumber(item) == inventoryId then
                            itemId = inventoryId
                            break
                        end
                    else
                        local itemName = getCached(addon.longtermCache, GetItemInfo, inventoryId)
                        if itemName == item then
                            itemId = inventoryId
                            break
                        end
                    end
                end
            end
            if itemId ~= nil then
                break
            end
        end
        if itemId == nil then
            for _, item in pairs(get_item_array(value.item)) do
                for i=0,4 do
                    for j=1,getCached(addon.combatCache, GetContainerNumSlots, i) do
                        local inventoryId = getCached(cache, GetContainerItemID, i, j);
                        if inventoryId ~= nil then
                            if isint(item) then
                                if tonumber(item) == inventoryId then
                                    itemId = inventoryId
                                    break
                                end
                            else
                                local itemName = getCached(addon.longtermCache, GetItemInfo, inventoryId)
                                if item == itemName then
                                    itemId = inventoryId
                                    break
                                end
                            end
                        end
                    end
                    if itemId ~= nil then
                        break
                    end
                end
                if itemId ~= nil then
                    break
                end
            end
        end
        local cooldown = 0
        if itemId ~= nil then
            local start, duration = getCached(cache, GetItemCooldown, itemId)
            if start ~= 0 and duration ~= 0 then
                cooldown = round(duration - (GetTime() - start), 3)
                if (cooldown < 0) then cooldown = 0 end
            end
        end
        return compare(value.operator, cooldown, value.value)
    end,
    print = function(spec, value)
        return string.format(L["the %s"],
            compareString(value.operator, string.format(L["cooldown on %s"], nullable(get_item_desc(value.item), L["<item>"])),
                                string.format(L["%s seconds"], nullable(value.value))))
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
    end,
})
