-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Change detection for the rotation editor: compares a baseline with a working copy so unsaved fields and step cards
-- can be marked. Pure data comparison; it owns no state and must not write to either table or draw anything.
-- Loaded from RotationMaster.toc after Core/condition_editor.lua and before Core/rotation_editor.lua; uses
-- addon.RotationData (Data/) to index steps by their stable ids.

local _, addon = ...

-- Deep structural equality for saved-data tables; used by the editors to decide whether a working copy differs from its
-- baseline.
-- @param a any  The first value.
-- @param b any  The second value.
-- @param seen table|nil  The cycle guard shared across the recursion; callers leave it nil.
-- @return boolean  True when both sides hold the same keys and values.
--
-- Cycle-safe through `seen`.
function addon:UnsavedDataEqual(a, b, seen)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= 'table' then
        return a == b
    end

    seen = seen or {}

    if seen[a] == b then
        return true
    end

    seen[a] = b

    for key, value in pairs(a) do
        if not self:UnsavedDataEqual(value, b[key], seen) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end

-- Compares a rotation before and after editing so the editor can mark exactly what carries unsaved edits.
-- @param before table|nil  The baseline rotation; nil is treated as empty.
-- @param after table|nil  The working-copy rotation; nil is treated as empty.
-- @return table  A changed flag per field (name, switch, description, metadata, tags, priority) plus `cards`, a table
--   keyed by step id that is true for a new or modified step.
function addon:RotationUnsavedState(before, after)
    before = before or {}
    after = after or {}
    local result = { cards = {} }

    for _, field in ipairs({ 'name', 'switch', 'description', 'metadata', 'tags', 'priority' }) do
        result[field] = not self:UnsavedDataEqual(before[field], after[field])
    end

    local old = self.RotationData.IndexRotationSteps(before, { allowMissingIds = true })
    local current = self.RotationData.IndexRotationSteps(after)

    -- A card is moved when it changed parent or arm, or fell out of the longest run of its siblings that kept their
    -- relative order. Cards that merely shifted because something else moved (or because an ancestor moved) are not.
    local moved = {}
    local groups, order = {}, {}

    for _, row in ipairs(current and current.rows or {}) do
        local previous = old and old.byId[row.step.id]

        if previous then
            local sameParent = previous.parentId == row.parentId
                and previous.arm == row.arm
                and previous.section == row.section

            if sameParent then
                local key = tostring(row.section) .. '|' .. tostring(row.parentId) .. '|' .. tostring(row.arm)

                if not groups[key] then
                    groups[key] = {}
                    order[#order + 1] = key
                end

                groups[key][#groups[key] + 1] = { id = row.step.id, rank = previous.ordinal or 0 }
            else
                moved[row.step.id] = true
            end
        end
    end

    -- Marks every sibling outside the longest increasing run of baseline ranks (the fewest cards that moved).
    for _, key in ipairs(order) do
        local items = groups[key]
        local tails, link = {}, {}

        for index, item in ipairs(items) do
            local low, high = 1, #tails

            while low <= high do
                local mid = math.floor((low + high) / 2)

                if items[tails[mid]].rank < item.rank then
                    low = mid + 1
                else
                    high = mid - 1
                end
            end

            tails[low] = index
            link[index] = low > 1 and tails[low - 1] or nil
        end

        local keep = {}
        local at = tails[#tails]

        while at do
            keep[at] = true
            at = link[at]
        end

        for index, item in ipairs(items) do
            if not keep[index] then
                moved[item.id] = true
            end
        end
    end

    for _, row in ipairs(current and current.rows or {}) do
        local previous = old and old.byId[row.step.id]

        result.cards[row.step.id] = not previous
            or not self:UnsavedDataEqual(previous.step, row.step)
            or moved[row.step.id] == true
    end

    return result
end
