-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Change detection for the rotation editor: compares a baseline with a working copy so unsaved fields and step cards
-- can be marked. Pure data comparison; it owns no state and must not write to either table or draw anything.
-- Loaded from RotationMaster.toc after Core/condition_editor.lua and before Core/rotation_editor.lua; uses
-- addon.RotationData (Data/) to index steps by their stable ids.

local _, addon = ...

-- Deep structural equality for saved-data tables (cycle-safe through `seen`); true when both sides hold the same keys
-- and values. Used by the editors to decide whether a working copy differs from its baseline.
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

-- Compares a rotation before and after editing. Returns a table with a changed flag per field (name, switch,
-- description, metadata, tags, priority) and `cards[stepId]`, true for a new or modified step, so the editor can mark
-- exactly what carries unsaved edits.
function addon:RotationUnsavedState(before, after)
    before = before or {}
    after = after or {}
    local result = { cards = {} }

    for _, field in ipairs({ 'name', 'switch', 'description', 'metadata', 'tags', 'priority' }) do
        result[field] = not self:UnsavedDataEqual(before[field], after[field])
    end

    local old = self.RotationData.IndexRotationSteps(before, { allowMissingIds = true })
    local current = self.RotationData.IndexRotationSteps(after)

    for _, row in ipairs(current and current.rows or {}) do
        local previous = old and old.byId[row.step.id]

        result.cards[row.step.id] = not previous
            or not self:UnsavedDataEqual(previous.step, row.step)
            or not self:UnsavedDataEqual(previous.path, row.path)
    end

    return result
end
