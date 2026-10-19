local _,addon=...
local CreateFrame,UIParent=CreateFrame,UIParent
local pairs,color=pairs,color
local units=addon.units

-- Runtime ItemSet services; legacy UI and secure-action policy remain unchanged.

local function CondIsItem(cond, id)
    if cond then
        if cond.type == "NOT" then
            return CondIsItem(cond.value, id)
        elseif cond.type == "AND" or cond.type == "OR" then
            for _, v in pairs(cond.value) do
                if CondIsItem(v, id) then
                    return true
                end
            end
        elseif cond.type == "EQUIPPED" or cond.type == "CARRYING" or cond.type == "ITEM" or
               cond.type == "ITEM_RANGE" or cond.type == "ITEM_COOLDOWN" then
            if type(cond.item) == "string" and cond.item == id then
                return true
            end
        end
    end
    return false
end

function addon:ItemSetInUse(id)
    local bindings = self.db.char.bindings
    local rotations = self.db.profile.rotations

    if bindings[id] ~= nil then
        return true
    end

    for _, rots in pairs(rotations) do
        for _, rot in pairs(rots) do
            if rot.cooldowns then
                for _, cond in pairs(rot.cooldowns) do
                    if cond.type == "item" and type(cond.action) == "string" and cond.action == id then
                        return true
                    end
                    if CondIsItem(cond.conditions, id) then
                        return true
                    end
                end
            end
            if rot.rotation then
                for _, cond in pairs(rot.rotation) do
                    if cond.type == "item" and type(cond.action) == "string" and cond.action == id then
                        return true
                    end
                    if CondIsItem(cond.conditions, id) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function addon:UpdateItemSetButtons(id)
    local itemsets = self.db.profile.itemsets
    local global_itemsets = self.db.global.itemsets

    local itemset
    if itemsets[id] ~= nil then
        itemset = itemsets[id]
    elseif global_itemsets[id] ~= nil then
        itemset = global_itemsets[id]
    end

    if not itemset then
        if addon.itemSetButtons[id] then
            for key, button in pairs(addon.itemSetButtons[id]) do
                button:SetParent(nil)
                addon.itemSetButtons[id][key] = nil
                _G[button:GetName()] = nil
            end
            addon.itemSetButtons[id] = nil
        end
    else
        local prefix = "RM_" .. itemset.name:gsub("%W", "")
        if not addon.itemSetButtons[id] then
            addon.itemSetButtons[id] = {}
        end

        for key, _ in pairs(units) do
            local button = addon.itemSetButtons[id][key]
            if button and button:GetName() ~= prefix .. "_" .. key then
                button:SetParent(nil)
                _G[button:GetName()] = nil
                button = nil
            end

            if not button then
                button = CreateFrame("Button", prefix .. "_" .. key, UIParent, "SecureActionButtonTemplate")
                button:Hide()
                button:SetAttribute("type", "macro")
                addon.itemSetButtons[id][key] = button
            end

            local macrotext = ""
            for _, item in pairs(itemset.items) do
                macrotext = macrotext .. "/use [@" .. key .. "] item:" .. item .. "\n"
            end
            button:SetAttribute("macrotext", macrotext)
        end
    end
end

function addon:item_list_popup(name, editbox, items, isvalid, update, onclose, options)
    return self:OpenItemListPopup(name, editbox, items, isvalid, update, onclose, options)
end

function addon:get_item_list(empty)
    local itemsets = self.db.profile.itemsets
    local global_itemsets = self.db.global.itemsets

    local selects = {}
    local sorted = {}
    for k,v in pairs(itemsets) do
        if type(v)=="table" and type(v.name)=="string" then
            selects[k] = v.name
            table.insert(sorted, k)
        end
    end
    table.sort(sorted, function(lhs, rhs)
        return selects[lhs] < selects[rhs]
    end)

    local sorted2 = {}
    for k,v in pairs(global_itemsets) do
        selects[k] = color.CYAN .. v.name .. color.RESET
        table.insert(sorted2, k)
    end
    table.sort(sorted2, function(lhs, rhs)
        return selects[lhs] < selects[rhs]
    end)
    for _, v in ipairs(sorted2) do
        table.insert(sorted, v)
    end

    selects[""] = empty
    table.insert(sorted, "")

    return selects, sorted
end
