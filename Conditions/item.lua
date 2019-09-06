local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tostring, tonumber, pairs = tostring, tonumber, pairs
local floor = math.floor

-- From constants
local operators, units, unitsPossessive, classes, roles, debufftypes, zonepvp, instances, totems =
addon.operators, addon.units, addon.unitsPossessive, addon.classes, addon.roles, addon.debufftypes,
addon.zonepvp, addon.instances, addon.totems

-- From utils
local compare, compareString, nullable, keys, tomap, has, is, isin, cleanArray, deepcopy, getCached, round =
addon.compare, addon.compareString, addon.nullable, addon.keys, addon.tomap, addon.has,
addon.is, addon.isin, addon.cleanArray, addon.deepcopy, addon.getCached, addon.round

addon:RegisterCondition("EQUIPPED", {
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

        local icon_group = addon:Widget_ItemWidget(spec, value,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)
    end,
})

addon:RegisterCondition("CARRYING", {
    description = L["Have Item In Bags"],
    icon = "Interface\\Icons\\inv_misc_bag_07",
    valid = function(spec, value)
        return value.item ~= nil
    end,
    evaluate = function(value, cache, evalStart)
        for i=0,4 do
            for j=1,getCached(addon.combatCache, GetContainerNumSlots, i) do
                local itemId = getCached(addon.combatCache, GetContainerItemID, i, j);
                if itemId ~= nil then
                    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice =
                    getCached(addon.longtermCache, GetItemInfo, itemId)
                    if value.item == itemName then
                        return true
                    end
                end
            end
        end
        return false
    end,
    print = function(spec, value)
        local link = value.item and (select(2, GetItemInfo(value.item)) or value.item)
        return string.format(L["you are carrying %s"], nullable(link, L["<item>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(spec, value,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)
    end,
})

addon:RegisterCondition("ITEM", {
    description = L["Item Available"],
    icon = "Interface\\Icons\\Inv_drink_05",
    valid = function(spec, value)
        return value.item ~= nil
    end,
    evaluate = function(value, cache, evalStart) -- Cooldown until the spell is available
        local itemId
        for i=0,20 do
            local inventoryId = getCached(addon.combatCache, GetInventoryItemID, "player", i)
            if inventoryId then
                local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice =
                getCached(addon.longtermCache, GetItemInfo, inventoryId)
                if itemName == value.item then
                    itemId = inventoryId
                    break
                end
            end
        end
        if itemId == nil then
            for i=0,4 do
                for j=1,getCached(addon.combatCache, GetContainerNumSlots, i) do
                    local inventoryId = getCached(addon.combatCache, GetContainerItemID, i, j);
                    if inventoryId ~= nil then
                        local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice =
                        getCached(addon.longtermCache, GetItemInfo, inventoryId)
                        if value.item == itemName then
                            itemId = inventoryId
                        end
                    end
                end
            end
        end
        if itemId ~= nil then
            local start, duration, enabled = getCached(cache, GetItemCooldown, itemId)
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

        local icon_group = addon:Widget_ItemWidget(spec, value,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)
    end,
})

addon:RegisterCondition("ITEM_COOLDOWN", {
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
            if inventoryId then
                local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice =
                getCached(addon.longtermCache, GetItemInfo, inventoryId)
                if itemName == value.item then
                    itemId = inventoryId
                    break
                end
            end
        end
        if itemId == nil then
            for i=0,4 do
                for j=1,getCached(addon.combatCache, GetContainerNumSlots, i) do
                    local inventoryId = getCached(addon.combatCache, GetContainerItemID, i, j);
                    if inventoryId ~= nil then
                        local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice =
                        getCached(addon.longtermCache, GetItemInfo, inventoryId)
                        if value.item == itemName then
                            itemId = inventoryId
                        end
                    end
                end
            end
        end
        local cooldown = 0
        if itemId ~= nil then
            local start, duration, enabled = getCached(cache, GetItemCooldown, itemId)
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

        local icon_group = addon:Widget_ItemWidget(spec, value,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)
        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
})
