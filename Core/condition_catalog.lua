-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The live condition catalog: which condition tags exist, how pickers group, order and filter them, and how a tag is
-- described to the editor. It reads the registry tables Core/conditions.lua owns (addon.conditionDefinitions and
-- addon.conditionSpecials) and the active profile's grouping and disabled lists; it registers nothing and draws
-- nothing.
-- Whether a condition works on this client is decided by Core/condition_support.lua, which listConditions consults.
-- Loaded from RotationMaster.toc right after Core/condition_runtime.lua.

local _, addon = ...
local pairs = pairs

-- Live catalog/query/dispatch services, independent of options rendering.
-- Load after Core/conditions.lua; retain its original registry identities.
local conditions = addon.conditionDefinitions
local special = addon.conditionSpecials

-- ============================================================================
-- Picker groups and lists
-- ============================================================================

-- Finds the user-defined picker group that lists a condition tag.
-- @param value string|nil  The condition tag.
-- @return string|nil  The id of the group that lists the tag, or "DEFAULT" when no group does; nil for a nil tag.
--
-- Groups come from the current profile, so the answer follows the active profile.
function addon:findConditionGroup(value)
    if not value then
        return nil
    end

    local profile = addon.db.profile

    for _, v in pairs(profile.condition_groups) do
        if v.conditions then
            for _, cond in pairs(v.conditions) do
                if value == cond then
                    return v.id
                end
            end
        end
    end

    return "DEFAULT"
end

-- Returns the ordered list of condition tags a picker shows for a group.
-- @param group string  "SWITCH" or "ANNOUNCEMENT" (the profile's chosen subsets plus every special), "CUSTOM" (the
--   user's custom conditions), "ALL", "DEFAULT" (conditions in no group) or a group id.
-- @param nohide boolean|nil  True to keep the conditions this client cannot support and the user-disabled ones.
-- @param store table|nil  The database to read (profile and global); defaults to the live database.
-- @return string[]  The condition tags in picker order.
--
-- Unless nohide is set, conditions this client cannot support and user-disabled ones are left out. The list is rebuilt
-- on every call and not cached.
function addon:listConditions(group, nohide, store)
    store = store or addon.db
    local profile = store.profile
    local global = store.global

    local rv = {}

    if group == "SWITCH" or group == "ANNOUNCEMENT" then
        local selected = profile.switch_conditions

        if group == "ANNOUNCEMENT" then
            selected = profile.announcement_conditions
        end

        for _, cond in pairs(type(selected) == "table" and selected or {}) do
            if special[cond] then
                table.insert(rv, cond)
            elseif conditions[cond] then
                table.insert(rv, cond)
            end
        end

        for cond, _ in pairs(special) do
            if not addon.index(rv, cond) then
                table.insert(rv, cond)
            end
        end
    elseif group == "CUSTOM" then
        for key, _ in pairs(global.custom_conditions) do
            table.insert(rv, key)
        end
    else
        local skipped = {}

        for _, v in pairs(profile.condition_groups) do
            if v.conditions then
                if group == "DEFAULT" then
                    for _, cond in pairs(v.conditions) do
                        skipped[cond] = true
                    end
                elseif group == v.id or group == "ALL" then
                    for _, cond in pairs(v.conditions) do
                        if special[cond] then
                            table.insert(rv, cond)
                        elseif conditions[cond] then
                            table.insert(rv, cond)
                        end

                        skipped[cond] = true
                    end
                end
            end
        end

        if group == "DEFAULT" or group == "ALL" then
            for _, cond in pairs(profile.other_conditions_order) do
                if not (group == "ALL" and skipped[cond]) then
                    if special[cond] then
                        table.insert(rv, cond)
                    elseif conditions[cond] then
                        table.insert(rv, cond)
                    end

                    skipped[cond] = true
                end
            end

            for cond, _ in pairs(special) do
                if not skipped[cond] then
                    table.insert(rv, cond)
                end
            end

            for cond, _ in pairs(conditions) do
                if not skipped[cond] and (nohide or not addon.index(profile.disabled_conditions, cond)) then
                    table.insert(rv, cond)
                end
            end
        end
    end

    -- Pickers hide conditions that cannot work on this client. Saved trees
    -- that already use one still show it, marked unavailable, as incomplete.
    if not nohide and addon.GetConditionSupport then
        local kept = {}

        for _, cond in ipairs(rv) do
            if special[cond] or not addon:GetConditionSupport(cond, conditions[cond]) then
                kept[#kept + 1] = cond
            end
        end

        rv = kept
    end

    if group == "ALL" or group == "CUSTOM" then
        -- Sort order for the ALL and CUSTOM lists: by description.
        -- @param lhs string  The first condition tag.
        -- @param rhs string  The second condition tag.
        -- @return boolean  True when `lhs` sorts before `rhs`.
        table.sort(rv, function(lhs, rhs)
            local ldesc, rdesc

            if special[lhs] then
                ldesc = special[lhs].desc
            else
                ldesc = conditions[lhs].description
            end

            if special[rhs] then
                rdesc = special[rhs].desc
            else
                rdesc = conditions[rhs].description
            end

            return ldesc < rdesc
        end)
    end

    return rv
end

-- ============================================================================
-- Describing a condition
-- ============================================================================

-- Describes a condition tag (special or registered) for the editor.
-- @param type string|nil  The condition tag.
-- @return string|number|nil  The condition's icon; nothing when the tag is nil or unknown.
-- @return string|nil  The condition's description.
-- @return string|function|nil  The help: "" for a special, otherwise the condition's help callback.
-- @return table|nil  The condition's field schema.
--
-- Callers use the empty result to tell whether a tag still exists.
function addon:describeCondition(type)
    if type ~= nil then
        if special[type] then
            return special[type].icon, special[type].desc, "", special[type].fields
        end
        if conditions[type] then
            return conditions[type].icon, conditions[type].description, conditions[type].help, conditions[type].fields
        end
    end
end

-- Lets a condition draw its own extra widget into the editor pane.
-- @param parent table  The container the widget is drawn into.
-- @param spec number  The specialization ID or talent group in use.
-- @param value table|nil  The condition value, whose `type` names the condition.
--
-- Does nothing for a condition without a widget (the common case) or an unknown tag.
function addon:widgetCondition(parent, spec, value)
    if
        value ~= nil and value.type ~= nil and conditions[value.type] ~= nil and conditions[value.type].widget ~= nil
    then
        conditions[value.type].widget(parent, spec, value)
    end
end
