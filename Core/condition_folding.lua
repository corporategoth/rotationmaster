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

-- Threshold conditions the game can evaluate at draw time (Platform/gates.lua), with the gate kind each becomes.
local GATE_KINDS = { HEALTHPCT = 'health', POWERPCT = 'power' }

-- The gate operator for each comparison; equality has no step curve.
local GATE_OPERATORS = {
    LESSTHAN = 'LESSTHAN',
    LESSTHANOREQUALS = 'LESSTHAN',
    GREATERTHAN = 'GREATERTHAN',
    GREATERTHANOREQUALS = 'GREATERTHAN',
}

-- The opposite gate operator, for a NOT.
local INVERSE = { LESSTHAN = 'GREATERTHAN', GREATERTHAN = 'LESSTHAN' }

-- Returns the display gate a condition tree amounts to, when the whole tree is one health or power percent threshold
-- (or NOT of one) that the game can evaluate for us: "target health below 20%" becomes the gate the step option
-- "Shown by the game when" stores.
-- @param tree any  A (folded) condition tree.
-- @return table|nil  { unit, kind, operator, value = percent }; nil when the tree is anything else.
function addon:GetConditionDisplayGate(tree)
    local negate = false

    -- An AND or OR of one child (the editor's root group) means that child; NOT flips the comparison.
    while type(tree) == 'table' and not tree.disabled do
        if (tree.type == 'AND' or tree.type == 'OR') and type(tree.value) == 'table' and #tree.value == 1 then
            tree = tree.value[1]
        elseif tree.type == 'NOT' then
            negate, tree = not negate, tree.value
        else
            break
        end
    end

    if type(tree) ~= 'table' or tree.disabled or not GATE_KINDS[tree.type] then
        return nil
    end

    local operator = GATE_OPERATORS[tree.operator]

    if
        not operator or type(tree.unit) ~= 'string' or type(tree.value) ~= 'number' or tree.value < 0 or tree.value > 1
    then
        return nil
    end

    return {
        unit = tree.unit,
        kind = GATE_KINDS[tree.type],
        operator = negate and INVERSE[operator] or operator,
        value = tree.value * 100,
    }
end

-- Restriction notes (Core/condition_restrictions.lua) that mean the game hides a condition in combat.
local HIDDEN_IN_COMBAT = { restricted = true, combat = true, always = true, identity = true, cast = true }

-- Reports whether the player is in combat.
-- @return boolean  True in combat lockdown or while the game says the player is in combat.
local function inCombat()
    if type(InCombatLockdown) == 'function' and InCombatLockdown() then
        return true
    end

    if type(UnitAffectingCombat) == 'function' then
        local ok, affecting = pcall(UnitAffectingCombat, 'player')
        return ok and addon.Platform:CanReadValue(affecting) and affecting == true
    end

    return false
end

-- Reports whether the map restriction (dungeons and raids) is active.
-- @return boolean  True while the game applies it.
local function mapRestricted()
    local actions, types = C_RestrictedActions, Enum and Enum.AddOnRestrictionType

    if type(actions) ~= 'table' or type(actions.IsAddOnRestrictionActive) ~= 'function' or type(types) ~= 'table' then
        return false
    end

    local ok, active = pcall(actions.IsAddOnRestrictionActive, types.Map)
    return ok and addon.Platform:CanReadValue(active) and active == true
end

-- Reports whether any leaf of a tree reads data the game hides now.
-- @param node any  A condition node.
-- @param map boolean  Whether the map restriction is active.
-- @return boolean  True when a leaf carries a hiding restriction.
local function hides(node, map)
    if type(node) ~= 'table' or node.disabled then
        return false
    end

    if node.type == 'AND' or node.type == 'OR' then
        for _, child in ipairs(type(node.value) == 'table' and node.value or {}) do
            if hides(child, map) then
                return true
            end
        end

        return false
    end

    if node.type == 'NOT' then
        return hides(node.value, map)
    end

    for _, note in ipairs(addon:GetConditionRestrictions(node.type, node) or {}) do
        if HIDDEN_IN_COMBAT[note] or note == 'map' and map then
            return true
        end
    end

    return false
end

-- Reports whether a cooldown should be left out while in combat: on Retail and Forever, in combat, its conditions
-- (after folding) read something the game hides then. Such a cooldown is treated as if it were not defined, so no
-- fallback or guess lights it; out of combat, and where everything reads, it is evaluated as usual.
-- @param conditions table|nil  The cooldown's condition tree.
-- @return boolean  True when the cooldown is left out now.
function addon:IsCooldownHiddenInCombat(conditions)
    if not self.GetConditionRestrictions or self.Platform:GetCombatDataPolicy() ~= 'restricted' or not inCombat() then
        return false
    end

    local folded = self:FoldInvariantConditions(conditions)

    if type(folded) ~= 'table' then
        return false
    end

    return hides(folded, mapRestricted())
end
