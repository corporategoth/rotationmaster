local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tonumber = tonumber

-- From constants
local operators = addon.operators

-- From utils
local compare, compareString, nullable, isin, getCached, round, isint =
    addon.compare, addon.compareString, addon.nullable, addon.isin, addon.getCached, addon.round, addon.isint

addon:RegisterCondition(L["Spells / Items"], "EQUIPPED", {
    description = L["Have Item Equipped"],
    icon = "Interface\\Icons\\Ability_warrior_shieldbash",
    valid = function(spec, value)
        return value.item ~= nil
    end,
    evaluate = function(value, cache, evalStart)
        return getCached(addon.combatCache, IsEquippedItem, value.item)
    end,
    print = function(spec, value)
        local link = value.item and (select(2, GetItemInfo(value.item)) or value.item)
        return string.format(L["you have %s equipped"], nullable(link, L["<item>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(value,
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
        for i=0,4 do
            for j=1,getCached(addon.combatCache, GetContainerNumSlots, i) do
                local _, qty, _, _, _, _, _, _, _, itemId = getCached(cache, GetContainerItemInfo, i, j);
                if itemId ~= nil then
                    if isint(value.item) then
                        if tonumber(value.item) == itemId then
                            count = count + qty
                        end
                    else
                        local itemName = getCached(addon.longtermCache, GetItemInfo, itemId)
                        if value.item == itemName then
                            count = count + qty
                        end
                    end
                end
            end
        end
        return compare(value.operator, count, value.value)
    end,
    print = function(spec, value)
        local link = value.item and (select(2, GetItemInfo(value.item)) or value.item)
        return compareString(value.operator,
                string.format(L["the number of %s you are carrying"], nullable(link, L["<item>"])),
                nullable(value.value, L["<quantity>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(value,
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
        for i=0,20 do
            local inventoryId = getCached(addon.combatCache, GetInventoryItemID, "player", i)
            if inventoryId ~= nil then
                if isint(value.item) then
                    if tonumber(value.item) == inventoryId then
                        itemId = inventoryId
                        break
                    end
                else
                    local itemName = getCached(addon.longtermCache, GetItemInfo, inventoryId)
                    if itemName == value.item then
                        itemId = inventoryId
                        break
                    end
                end
            end
        end
        if itemId == nil then
            for i=0,4 do
                for j=1,getCached(addon.combatCache, GetContainerNumSlots, i) do
                    local inventoryId = getCached(cache, GetContainerItemID, i, j);
                    if inventoryId ~= nil then
                        if isint(value.item) then
                            if tonumber(value.item) == inventoryId then
                                itemId = inventoryId
                                break
                            end
                        else
                            local itemName = getCached(addon.longtermCache, GetItemInfo, inventoryId)
                            if value.item == itemName then
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
        local link = value.item and (select(2, GetItemInfo(value.item)) or value.item)
        return string.format(L["%s is available"], nullable(link, L["<item>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(value,
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
        for i=0,20 do
            local inventoryId = getCached(addon.combatCache, GetInventoryItemID, "player", i)
            if inventoryId ~= nil then
                if isint(value.item) then
                    if tonumber(value.item) == inventoryId then
                        itemId = inventoryId
                        break
                    end
                else
                    local itemName = getCached(addon.longtermCache, GetItemInfo, inventoryId)
                    if itemName == value.item then
                        itemId = inventoryId
                        break
                    end
                end
            end
        end
        if itemId == nil then
            for i=0,4 do
                for j=1,getCached(addon.combatCache, GetContainerNumSlots, i) do
                    local inventoryId = getCached(cache, GetContainerItemID, i, j);
                    if inventoryId ~= nil then
                        if isint(value.item) then
                            if tonumber(value.item) == inventoryId then
                                itemId = inventoryId
                                break
                            end
                        else
                            local itemName = getCached(addon.longtermCache, GetItemInfo, inventoryId)
                            if value.item == itemName then
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
        local link = value.item and (select(2, GetItemInfo(value.item)) or value.item)
        return string.format(L["the %s"],
            compareString(value.operator, string.format(L["cooldown on %s"], nullable(link, L["<item>"])),
                                string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(value,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
})
