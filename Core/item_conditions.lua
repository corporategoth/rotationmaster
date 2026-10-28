-- Item condition runtime: validates an item reference (one item set name, or a list of item ids/names), resolves a
-- reference to its item list, and evaluates the EQUIPPED, CARRYING, ITEM, ITEM_RANGE and ITEM_COOLDOWN conditions that
-- Conditions/item.lua declares. Owns no saved data (item sets live in db.profile.itemsets and db.global.itemsets) and
-- never calls a game API itself: every read goes through Platform adapters via the evaluation cache, returning
-- nil and a reason when a value is unavailable. Loaded from the Core condition-service group of RotationMaster.toc,
-- before Core/itemset_services.lua and Core/item_sets.lua, which build on the list helpers here.
local _, addon = ...
local platform = addon.Platform

-- ============================================================================
-- Reference validation
-- ============================================================================

-- Reports whether a value is a real, non-negative, non-infinite number.
-- @param value any  The value to test.
-- @return boolean  True for such a number; NaN, negatives, infinities and non-numbers give false.
local function finite(value)
    return type(value) == 'number' and value == value and value >= 0 and value < math.huge
end

-- Reports whether a value is one acceptable item-list entry.
-- @param value any  The candidate entry.
-- @return boolean  True for a positive integer item id, or a non-empty item name string of at most 1024 bytes.
local function item(value)
    return type(value) == 'number' and finite(value) and value > 0 and value % 1 == 0
        or type(value) == 'string' and #value > 0 and #value <= 1024
end

-- Reports whether a value is a usable item reference.
-- @param value any  The candidate reference.
-- @return boolean  True for a short string (at most 128 bytes) naming an item set, or a plain (no metatable) dense list
--   of at most 512 entries, each passing item().
--
-- Bounds the size of anything a saved condition can make us walk.
function addon:IsConditionItemReference(value)
    if type(value) == 'string' then
        return #value > 0 and #value <= 128
    end
    if type(value) ~= 'table' or getmetatable(value) ~= nil then
        return false
    end

    local count, largest = 0, 0

    for key, entry in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 or key > 512 or not item(entry) then
            return false
        end

        count = count + 1
        largest = math.max(largest, key)
    end

    return count == largest
end

-- ============================================================================
-- Item list resolution
-- ============================================================================

-- Resolves an item reference to its item list.
-- @param reference string|table  An item set name or an item list.
-- @return table|nil  The list: a table reference is returned as is, a string is looked up as an item set (per-character
--   sets first and then global ones); nil when it cannot be resolved.
-- @return string|nil  'invalid-item-reference' or 'item-set-unavailable' when the first return is nil; nil otherwise.
function addon:GetConditionItemList(reference)
    if not self:IsConditionItemReference(reference) then
        return nil, 'invalid-item-reference'
    end
    if type(reference) == 'table' then
        return reference
    end

    local personal, global = self.db.profile.itemsets, self.db.global.itemsets

    if personal ~= nil and type(personal) ~= 'table' or global ~= nil and type(global) ~= 'table' then
        return nil, 'item-set-unavailable'
    end

    local source = (personal or {})[reference]

    if source == nil then
        source = (global or {})[reference]
    end

    if type(source) ~= 'table' or type(source.items) ~= 'table' or not self:IsConditionItemReference(source.items) then
        return nil, 'item-set-unavailable'
    end

    return source.items
end

-- Calls a Platform reader through the evaluation cache so one poll asks the game for each answer at most once.
-- @param cache table|nil  The evaluation cache.
-- @param method function  The Platform method to call; the Platform is passed as its self.
-- @param ... any  The remaining arguments for the method.
-- @return any  The reader's results, passed through from the cache (value, or nil then a reason).
local function read(cache, method, ...)
    return addon.Functions.cache.getCached(cache, method, platform, ...)
end

-- Picks the item a condition should judge: the first list entry that is carried (or, with `equipped`, worn).
-- @param list table  A resolved item list.
-- @param cache table|nil  The evaluation cache.
-- @param equipped boolean|nil  True to also accept an entry that is worn.
-- @param notcarrying boolean|nil  True to fall back to the first entry when nothing is held.
-- @return number|nil  The item id; nil when a read is unavailable, or when nothing is held and `notcarrying` is not
--   set.
-- @return number|nil  The carried count (0 for a worn item or the notcarrying fallback); nil when a read is
--   unavailable.
-- @return string|nil  The reason when a read is unavailable; only returned (as a third value) in that case.
--
-- When nothing is held it returns the first entry only if `notcarrying` is set, with a count of 0, so conditions can
-- still describe an item the player lacks.
local function selectItem(list, cache, equipped, notcarrying)
    local first

    for _, entry in ipairs(list) do
        local id, reason = read(cache, platform.GetItemID, entry)

        if not id then
            return nil, nil, reason
        end

        first = first or id
        local count, why = read(cache, platform.GetItemCount, id)

        if count == nil then
            return nil, nil, why
        end
        if count > 0 then
            return id, count
        end

        if equipped then
            local present, problem = read(cache, platform.IsItemEquipped, id)

            if present == nil then
                return nil, nil, problem
            end
            if present then
                return id, 0
            end
        end
    end

    return notcarrying and first or nil, 0
end

-- ============================================================================
-- Condition evaluation
-- ============================================================================

-- Evaluates ITEM_COOLDOWN for a trinket slot: the cooldown left on whatever is equipped in that slot.
-- @param self table  The addon.
-- @param value table  The condition value (slot, operator, value).
-- @param cache table|nil  The evaluation cache.
-- @param now number  The poll's GetTime value.
-- @return boolean|nil  The comparison result; false for an empty slot; nil when a read is unavailable.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- One rotation works for every trinket. The equipped item comes from the build context (refreshed on equipment changes,
-- so no native read per evaluation); its cooldown is read fresh through the same reader as an item named in the
-- condition. An empty slot is false; a trinket with no on-use effect has no cooldown to read and is unavailable, never
-- a confident zero.
local function slotCooldown(self, value, cache, now)
    if not self.GetEquippedSlotInfo then
        return nil, 'build-context-unavailable'
    end

    local equipped, reason = self:GetEquippedSlotInfo(value.slot)

    if equipped == nil then
        return nil, reason
    end
    if equipped == false then
        return false
    end

    local cooldown, problem = read(cache, platform.GetItemCooldown, equipped.itemID)

    if not cooldown then
        return nil, problem
    end
    if not cooldown.isEnabled then
        return nil, 'trinket-has-no-use-effect'
    end
    if not platform:CanReadValue(now) or not finite(now) then
        return nil, 'invalid-time'
    end

    local remaining = math.max(0, cooldown.startTime + cooldown.duration - now)

    if not finite(remaining) then
        return nil, 'invalid-api-result'
    end

    return self.Functions.values.compare(value.operator, self.Functions.values.round(remaining, 3), value.value)
end

-- Evaluates one item condition by tag for Conditions/item.lua.
-- @param tag string  The condition tag: EQUIPPED, CARRYING, ITEM, ITEM_RANGE or ITEM_COOLDOWN.
-- @param value table  The condition value (item, slot, operator, value, notcarrying).
-- @param cache table|nil  The evaluation cache.
-- @param now number  The poll's GetTime value; it must pass platform:CanReadValue before it is compared.
-- @return boolean|nil  The condition's answer; nil when any read is unavailable.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function addon:EvaluateItemCondition(tag, value, cache, now)
    if tag == 'ITEM_COOLDOWN' and value.slot ~= nil then
        return slotCooldown(self, value, cache, now)
    end

    local list, reason = self:GetConditionItemList(value.item)

    if not list then
        return nil, reason
    end

    if tag == 'EQUIPPED' then
        for _, entry in ipairs(list) do
            local equipped, why = read(cache, platform.IsItemEquipped, entry)

            if equipped == nil then
                return nil, why
            end
            if equipped then
                return true
            end
        end

        return false
    end

    if tag == 'CARRYING' then
        if #list == 0 then
            return self.Functions.values.compare(value.operator, 0, value.value)
        end

        local counts, why = read(cache, platform.GetBagItemCounts)

        if not counts then
            return nil, why
        end

        for _, entry in ipairs(list) do
            local id, problem = read(cache, platform.GetItemID, entry)

            if not id then
                return nil, problem
            end
            if counts[id] then
                return self.Functions.values.compare(value.operator, counts[id], value.value)
            end
        end

        return self.Functions.values.compare(value.operator, 0, value.value)
    end

    local id, _, why = selectItem(list, cache, true, value.notcarrying)

    if why then
        return nil, why
    end
    if not id then
        return false
    end

    if tag == 'ITEM_RANGE' then
        local range, problem = read(cache, platform.GetItemRangeState, id, 'target')

        if not range then
            return nil, problem
        end

        return range.applicable and range.inRange or false
    end

    if not platform:CanReadValue(now) or not finite(now) then
        return nil, 'invalid-time'
    end

    local cooldown, problem = read(cache, platform.GetItemCooldown, id)

    if not cooldown then
        return nil, problem
    end

    if tag == 'ITEM_COOLDOWN' then
        if not cooldown.isEnabled then
            return nil, 'item-cooldown-disabled'
        end

        local remaining = math.max(0, cooldown.startTime + cooldown.duration - now)

        if not finite(remaining) then
            return nil, 'invalid-api-result'
        end

        return self.Functions.values.compare(value.operator, self.Functions.values.round(remaining, 3), value.value)
    end

    if tag ~= 'ITEM' then
        return nil, 'unknown-item-condition'
    end

    local levelAllowed, levelReason = read(cache, platform.IsItemLevelAllowed, id)

    if levelAllowed == nil then
        return nil, levelReason
    end
    if not levelAllowed or not cooldown.isEnabled then
        return false
    end

    local expires = cooldown.startTime + cooldown.duration

    if not finite(expires) then
        return nil, 'invalid-api-result'
    end
    if cooldown.duration == 0 or expires <= now then
        return true
    end

    local gcd, gcdReason = read(cache, platform.GetGlobalCooldown)

    if not gcd then
        return nil, gcdReason
    end

    local gcdExpires = gcd.startTime + gcd.duration

    if not finite(gcdExpires) then
        return nil, 'invalid-api-result'
    end

    return gcd.isEnabled and gcd.duration > 0 and gcdExpires > now and expires <= gcdExpires + .001
end
