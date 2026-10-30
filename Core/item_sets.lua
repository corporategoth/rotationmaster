-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Item set lookups: given an item reference (an item set name or a literal list, see Core/item_conditions.lua), find
-- the first item, a specific item, or the first item the player carries or wears. Used by the action-bar binding code
-- in main.lua and the item set settings page. Owns no saved data and never reads the game directly: identities, counts
-- and equipment come from Platform adapters and return nil and a reason when unavailable. Loaded from the Core group of
-- RotationMaster.toc, after Core/item_conditions.lua and Core/itemset_services.lua.
local _, addon = ...
local platform = addon.Platform

-- Validates a reference as an item list.
-- @param items any  The candidate item list; callers pass the already-resolved list.
-- @return table|nil  The same list when valid; nil otherwise.
-- @return string|nil  'invalid-item-reference' when the first return is nil; nil otherwise.
--
-- Unlike GetConditionItemList it does not resolve a set name.
local function list(items)
    if type(items) ~= 'table' or not addon:IsConditionItemReference(items) then
        return nil, 'invalid-item-reference'
    end

    return items
end

-- Calls a Platform reader through the evaluation cache so repeated asks in one pass reach the game once.
-- @param cache table|nil  The evaluation cache.
-- @param method function  The Platform method to call; the Platform is passed as its self.
-- @param ... any  The remaining arguments for the method.
-- @return any  The reader's results, passed through from the cache (value, or nil then a reason).
local function read(cache, method, ...)
    return addon.Functions.cache.getCached(cache, method, platform, ...)
end

-- Returns the identity of the first item of an item list.
-- @param items table  A resolved item list.
-- @return number|nil  The item id of the first entry; nil when the list is empty or the identity is unavailable.
-- @return string|nil  The reason when the list is invalid or the identity is unavailable; nil otherwise.
--
-- First-defined identity is useful for previews even without ownership. Do not store failed name resolution in a
-- long-lived cache: item metadata loads later.
function addon:FindFirstItemInItems(items)
    local entries, reason = list(items)

    if not entries then
        return nil, reason
    end
    if entries[1] ~= nil then
        return platform:GetItemID(entries[1])
    end
end

-- Same as FindFirstItemInItems, for an item set identified by name or id.
-- @param id string|number  The item set name or id.
-- @return number|nil  The item id of the set's first entry; nil when unavailable.
-- @return string|nil  The reason when the set cannot be resolved or the identity is unavailable; nil otherwise.
function addon:FindFirstItemInItemSet(id)
    local entries, reason = self:GetConditionItemList(id)

    if not entries then
        return nil, reason
    end

    return self:FindFirstItemInItems(entries)
end

-- Looks for an item among the entries of an item list.
-- @param items table  A resolved item list.
-- @param item number|string  The item to look for, by id or name.
-- @return number|nil  The numeric id of `item` when it matches an entry; nil when it is not in the list or cannot be
--   read.
-- @return string|nil  The reason when an entry's identity cannot be read yet (name lookups can fail until item data
--   loads); nil otherwise.
function addon:FindItemInItems(items, item)
    local entries, reason = list(items)

    if not entries then
        return nil, reason
    end

    local wanted, why = platform:GetItemID(item)

    if not wanted then
        return nil, why
    end

    local unavailable

    for _, entry in ipairs(entries) do
        local candidate, problem = platform:GetItemID(entry)

        if candidate == wanted then
            return wanted
        end

        unavailable = unavailable or problem
    end

    return nil, unavailable
end

-- Same as FindItemInItems, for an item set identified by name or id.
-- @param id string|number  The item set name or id.
-- @param item number|string  The item to look for, by id or name.
-- @return number|nil  The numeric id of `item` when it is in the set; nil otherwise.
-- @return string|nil  The reason when the set cannot be resolved or an entry cannot be read; nil otherwise.
function addon:FindItemInItemSet(id, item)
    local entries, reason = self:GetConditionItemList(id)

    if not entries then
        return nil, reason
    end

    return self:FindItemInItems(entries, item)
end

-- Finds the first entry of an item list that the player carries, or wears.
-- @param cache table|nil  The evaluation cache; a fresh table is used when it is nil.
-- @param items table  A resolved item list.
-- @param equipped boolean|nil  True to count only items the player wears; otherwise carried items count.
-- @return number|nil  The id of the first entry the player has; nil when none, or when a read is unavailable.
-- @return string|nil  The reason as soon as one read is unavailable (a partial answer would pick the wrong item); nil
--   otherwise.
--
-- Bag counts are read once per call.
function addon:FindFirstItemOfItems(cache, items, equipped)
    local entries, reason = list(items)

    if not entries then
        return nil, reason
    end

    cache = cache or {}
    local counts

    for _, entry in ipairs(entries) do
        local candidate, why = read(cache, platform.GetItemID, entry)

        if not candidate then
            return nil, why
        end

        if equipped then
            local worn, problem = read(cache, platform.IsItemEquipped, candidate)

            if worn == nil then
                return nil, problem
            end
            if worn then
                return candidate
            end
        end

        if not counts then
            local problem
            counts, problem = read(cache, platform.GetBagItemCounts)

            if not counts then
                return nil, problem
            end
        end

        if counts[candidate] then
            return candidate
        end
    end
end

-- Same as FindFirstItemOfItems, for an item set identified by name or id.
-- @param cache table|nil  The evaluation cache; a fresh table is used when it is nil.
-- @param id string|number  The item set name or id.
-- @param equipped boolean|nil  True to count only items the player wears.
-- @return number|nil  The id of the first entry the player has; nil when none, or when a read is unavailable.
-- @return string|nil  The reason when the set cannot be resolved or a read is unavailable; nil otherwise.
function addon:FindFirstItemOfItemSet(cache, id, equipped)
    local entries, reason = self:GetConditionItemList(id)

    if not entries then
        return nil, reason
    end

    return self:FindFirstItemOfItems(cache, entries, equipped)
end
