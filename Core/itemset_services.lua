-- Runtime services for item sets: whether a set is still referenced by a rotation or a button binding, the secure
-- macro buttons that /use each set's items on a unit, and the name/value list the condition editor offers. Owns no
-- saved data (item sets live in db.profile.itemsets and db.global.itemsets, bindings in db.char.bindings) and no
-- window; the editing UI is UI/settings_items.lua and UI/item_list_popup.lua. Loaded from the Core condition-service
-- group of RotationMaster.toc, after Core/item_conditions.lua. addon.itemSetButtons is created in main.lua.
local _, addon = ...
local CreateFrame, UIParent = CreateFrame, UIParent
local pairs, color = pairs, color
local units = addon.units

-- Runtime ItemSet services; legacy UI and secure-action policy remain unchanged.

-- Walks a legacy condition tree (NOT / AND / OR around leaves) and returns true when an item condition names the item
-- set `id`. Only string items count; a numeric item id is never a set reference.
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
        elseif
            cond.type == "EQUIPPED"
            or cond.type == "CARRYING"
            or cond.type == "ITEM"
            or cond.type == "ITEM_RANGE"
            or cond.type == "ITEM_COOLDOWN"
        then
            if type(cond.item) == "string" and cond.item == id then
                return true
            end
        end
    end

    return false
end

-- ============================================================================
-- Usage scan
-- ============================================================================

-- True when item set `id` is referenced by a button binding or by any stored rotation. With the scoped rotation store
-- the scan is conservative: an unreadable store, a very deep or very large record counts as "in use". Without it, it
-- walks db.profile.rotations the legacy way. The usage scan has no caller outside tests in this tree.
function addon:ItemSetInUse(id)
    local bindings = self.db.char.bindings
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        if bindings[id] ~= nil then
            return true
        end

        local records = scoped:StoredRecords()

        if not records then
            return true
        end

        local seen, count = {}, 0

        local function uses(value, depth)
            if type(value) ~= 'table' then
                return false
            end

            depth = depth or 0

            if depth > 64 then
                return true
            end
            if seen[value] then
                return false
            end

            seen[value] = true
            count = count + 1

            if count > 20000 then
                return true
            end

            for key, child in pairs(value) do
                if child == id and (key == 'action' or key == 'item') then
                    return true
                end
                if type(child) == 'table' and uses(child, depth + 1) then
                    return true
                end
            end

            return false
        end

        for _, row in ipairs(records) do
            for _, component in pairs(row.record) do
                if uses(component) then
                    return true
                end
            end
        end

        -- Recovery archives have unknown profile ownership. Keep their item-set
        -- references reserved rather than silently breaking an eventual adoption.
        for _, char in pairs(self.db.sv and self.db.sv.char or {}) do
            if type(char) == 'table' and char.rotations and uses(char.rotations) then
                return true
            end
        end

        return false
    end

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

-- ============================================================================
-- Secure buttons
-- ============================================================================

-- Rebuilds the hidden secure macro buttons for item set `id`, one per unit key in addon.units, each named
-- RM_<set name>_<unit> with a macro that /uses every item in the set against that unit. A deleted set removes its
-- buttons; a renamed set replaces them because the global frame name changes. Callers are the settings page and the
-- PLAYER_ENTERING_WORLD and PLAYER_REGEN_ENABLED handlers in main.lua, never the poll.
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
            -- Group unit types (maintank ...) are not unit tokens a macro can target.
            if not (addon.groupUnitKinds and addon.groupUnitKinds[key]) then
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
                    -- Item strings are data (imports, saved variables): one line each,
                    -- and no control character, separator or bracket that could end it.
                    if type(item) == "number" or type(item) == "string" then
                        local safe = tostring(item):gsub("[%z\1-\31\127;%[%]|\\]", "")

                        if safe ~= "" then
                            macrotext = macrotext .. "/use [@" .. key .. "] item:" .. safe .. "\n"
                        end
                    end
                end

                button:SetAttribute("macrotext", macrotext)
            end
        end
    end
end

-- ============================================================================
-- Editor lists
-- ============================================================================

-- Legacy six-argument entry point; forwards to the native owner OpenItemListPopup (UI/item_list_popup.lua).
function addon:item_list_popup(name, editbox, items, isvalid, update, onclose, options)
    return self:OpenItemListPopup(name, editbox, items, isvalid, update, onclose, options)
end

-- Builds the item set choices for a dropdown: returns a value-to-label table and a sorted key list. Personal sets come
-- first by name, then global sets (labeled in cyan), then the empty key "" labeled `empty` for the Custom choice.
function addon:get_item_list(empty)
    local itemsets = self.db.profile.itemsets
    local global_itemsets = self.db.global.itemsets

    local selects = {}
    local sorted = {}

    for k, v in pairs(itemsets) do
        if type(v) == "table" and type(v.name) == "string" then
            selects[k] = v.name
            table.insert(sorted, k)
        end
    end

    table.sort(sorted, function(lhs, rhs)
        return selects[lhs] < selects[rhs]
    end)

    local sorted2 = {}

    for k, v in pairs(global_itemsets) do
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
