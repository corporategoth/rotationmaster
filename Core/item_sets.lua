-- Item set lookups: given an item reference (an item set name or a literal list, see Core/item_conditions.lua), find
-- the first item, a specific item, or the first item the player carries or wears. Used by the action-bar binding code
-- in main.lua and the item set settings page. Owns no saved data and never reads the game directly: identities, counts
-- and equipment come from Platform adapters and return nil and a reason when unavailable. Loaded from the Core group of
-- RotationMaster.toc, after Core/item_conditions.lua and Core/itemset_services.lua.
local _, addon = ...
local platform = addon.Platform

-- Validates a reference as an item list and returns it, or nil and 'invalid-item-reference'. Unlike
-- GetConditionItemList it does not resolve a set name, so callers pass the already-resolved list.
local function list(items)
    if type(items) ~= 'table' or not addon:IsConditionItemReference(items) then return nil, 'invalid-item-reference' end
    return items
end

-- Calls a Platform reader through the evaluation cache so repeated asks in one pass reach the game once.
local function read(cache, method, ...)
    return addon.Functions.cache.getCached(cache, method, platform, ...)
end

-- First-defined identity is useful for previews even without ownership. Do not
-- store failed name resolution in a long-lived cache: item metadata loads later.
function addon:FindFirstItemInItems(items)
    local entries, reason = list(items)
    if not entries then return nil, reason end
    if entries[1] ~= nil then return platform:GetItemID(entries[1]) end
end

-- Same as FindFirstItemInItems, for an item set identified by name or id.
function addon:FindFirstItemInItemSet(id)
    local entries, reason = self:GetConditionItemList(id)
    if not entries then return nil, reason end
    return self:FindFirstItemInItems(entries)
end

-- Returns the numeric id of `item` when it matches an entry of `items`, nil when it is not in the list, or nil and a
-- reason when an entry's identity cannot be read yet (name lookups can fail until item data loads).
function addon:FindItemInItems(items, item)
    local entries, reason = list(items)
    if not entries then return nil, reason end
    local wanted, why = platform:GetItemID(item)
    if not wanted then return nil, why end
    local unavailable

    for _, entry in ipairs(entries) do
        local candidate, problem = platform:GetItemID(entry)
        if candidate == wanted then return wanted end
        unavailable = unavailable or problem
    end

    return nil, unavailable
end

-- Same as FindItemInItems, for an item set identified by name or id.
function addon:FindItemInItemSet(id, item)
    local entries, reason = self:GetConditionItemList(id)
    if not entries then return nil, reason end
    return self:FindItemInItems(entries, item)
end

-- Returns the id of the first entry of `items` the player carries, or wears when `equipped` is true, nil when none,
-- or nil and a reason as soon as one read is unavailable (a partial answer would pick the wrong item). `cache` is the
-- evaluation cache; a fresh table is used when it is nil. Bag counts are read once per call.
function addon:FindFirstItemOfItems(cache, items, equipped)
    local entries, reason = list(items)
    if not entries then return nil, reason end
    cache = cache or {}
    local counts

    for _, entry in ipairs(entries) do
        local candidate, why = read(cache, platform.GetItemID, entry)
        if not candidate then return nil, why end

        if equipped then
            local worn, problem = read(cache, platform.IsItemEquipped, candidate)
            if worn == nil then return nil, problem end
            if worn then return candidate end
        end

        if not counts then
            local problem
            counts, problem = read(cache, platform.GetBagItemCounts)
            if not counts then return nil, problem end
        end

        if counts[candidate] then return candidate end
    end
end

-- Same as FindFirstItemOfItems, for an item set identified by name or id.
function addon:FindFirstItemOfItemSet(cache, id, equipped)
    local entries, reason = self:GetConditionItemList(id)
    if not entries then return nil, reason end
    return self:FindFirstItemOfItems(cache, entries, equipped)
end
