-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Folds the conditions that cannot change while a lean plan lives (main.lua: the plan is rebuilt on level, talent,
-- specialization, spell, equipment, form, vehicle and combat changes, and after a minute) into constants, so a poll only
-- evaluates what can change. "You know Water Shield" is read once per plan instead of every poll, and a step that can
-- never match under the current character (its conditions fold to false) costs nothing in combat. A leaf folds only when
-- it reads a definite answer now; an unavailable one stays in the tree, so restricted clients keep their semantics.
-- Loaded from the TOC after Core/conditions.lua; main.lua calls addon:FoldInvariantConditions when it records a plan.
local _, addon = ...

-- Conditions whose answer only changes on an event that rebuilds the lean plan.
local INVARIANT = {
    SPELL_KNOWN = true,
    TALENT = true,
    SPECIALIZATION = true,
    SELF_LEVEL = true,
}

-- Folds one node.
-- @param node table  A condition node.
-- @param stats table  Counters: folded (leaves replaced by a constant).
-- @return table|boolean  true or false when the node's answer is fixed; otherwise the node, or a simplified copy.
local function fold(node, stats)
    if type(node) ~= 'table' or node.disabled then
        return node
    end

    local kind = node.type

    if kind == 'AND' or kind == 'OR' then
        if type(node.value) ~= 'table' then
            return node
        end

        -- The evaluator walks children in order and stops at the first unavailable one, so an absorbing constant
        -- (false under AND, true under OR) decides the node only when nothing undecided comes before it. After an
        -- undecided child it stays as the original leaf, and the children after it, which the evaluator never reached,
        -- are dropped. Identity constants (true under AND, false under OR) never stop the walk and are removed.
        local absorbing = kind == 'OR'
        local kept, changed = {}, false

        for index, child in ipairs(node.value) do
            local result = fold(child, stats)

            if result == absorbing then
                if not kept[1] then
                    return absorbing
                end

                kept[#kept + 1] = child
                changed = changed or index < #node.value
                break
            end

            if result == not absorbing then
                changed = true
            else
                kept[#kept + 1] = result
                changed = changed or result ~= child
            end
        end

        if not kept[1] then
            return not absorbing
        end
        if not changed then
            return node
        end
        if not kept[2] then
            return kept[1]
        end

        return { type = kind, value = kept }
    end

    if kind == 'NOT' then
        local result = fold(node.value, stats)

        if result == true or result == false then
            return not result
        end
        if result == node.value then
            return node
        end

        return { type = 'NOT', value = result }
    end

    if not INVARIANT[kind] then
        return node
    end

    local ok, outcome = pcall(addon.evaluateConditionResult, addon, node)

    if not ok or type(outcome) ~= 'table' then
        return node
    end

    if outcome.status == 'match' then
        stats.folded = stats.folded + 1
        return true
    end

    if outcome.status == 'no-match' then
        stats.folded = stats.folded + 1
        return false
    end

    return node
end

-- Folds the plan-invariant leaves of a condition tree.
-- @param conditions table|nil  The step's condition tree.
-- @param stats table|nil  Counters to add to: folded (leaves replaced by a constant).
-- @return table|boolean|nil  true when the tree always matches under this plan, false when it never does, otherwise the
--   tree (unchanged when nothing folded) or a simplified copy that shares the untouched leaves.
function addon:FoldInvariantConditions(conditions, stats)
    if type(conditions) ~= 'table' or next(conditions) == nil then
        return conditions
    end

    return fold(conditions, stats or { folded = 0 })
end
