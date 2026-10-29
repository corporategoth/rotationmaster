-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Direct Set Mark execution, marker names and rotation-editor unit choices.
local _, addon = ...
local platform = addon.Platform

-- Game names are read through this table, not as globals: they are probes, and a client that lacks one must read as
-- "no" (see Platform/raid_marks.lua).
local env = getfenv and getfenv(1) or _G

-- ============================================================================
-- The whitelists
-- ============================================================================

-- The units offered by the editor, in order. Saved values are validated against this list.
local ACTION_UNITS = { 'player', 'target', 'focus', 'mouseover', 'pet', 'targettarget', 'focustarget' }
local UNIT_ORDINAL = {}

for ordinal, token in ipairs(ACTION_UNITS) do
    UNIT_ORDINAL[token] = ordinal
end

-- The units that exist only where the client has a focus target.
local FOCUS_UNITS = { focus = true, focustarget = true }

-- What a step's action can say: a mark's name, or none to clear the mark.
local NONE = 'none'
local HIGHEST_UNSET = 'highest_unset'
local MARK_NUMBER = { [NONE] = 0 }

for key, index in pairs(platform.RaidMarks.index) do
    MARK_NUMBER[key] = index
end

-- The key of each mark number 0 to 8, none first.
local MARK_KEY = { [0] = NONE }

for index, key in ipairs(platform.RaidMarks.keys) do
    MARK_KEY[index] = key
end

-- The pseudo spell id of a (unit, mark) pair: far above every real spell id, so no spell is ever mistaken for one.
local ACTION_BASE = 1073741824
local ACTION_SPAN = 16

-- Static data for the files that build the editor and the buttons. units lists the whitelisted tokens, marks maps a
-- step's action word to its number (none is 0). Read only.
platform.RaidMarkActions = { units = ACTION_UNITS, marks = MARK_NUMBER, none = NONE, highestUnset = HIGHEST_UNSET }

-- Attempts to set the chosen raid mark directly through the client API.
-- @param step table  The Set Mark step, with a unit token and mark name.
-- @return boolean  True when the call completed without a Lua error; false otherwise.
function platform:TrySetRaidMark(step)
    -- Retail and Forever reject addon-driven SetRaidTarget calls as protected actions.
    local family = self:GetClientFamily()

    if family == 'retail' or family == 'forever' then
        return false
    end
    if type(step) ~= 'table' or type(step.unit) ~= 'string' or type(step.action) ~= 'string' then
        return false
    end

    local mark = MARK_NUMBER[step.action]
    local setMark = env.SetRaidTarget

    if step.action == HIGHEST_UNSET then
        for _, index in ipairs(self.RaidMarks.priority) do
            local _, reason = self:ResolveRaidMarkUnit(self.RaidMarks.keys[index])

            if reason == 'no-marked-unit' then
                mark = index
                break
            end

            if reason and reason ~= 'no-token' then
                return false
            end
        end
    end

    if not UNIT_ORDINAL[step.unit] or mark == nil or type(setMark) ~= 'function' then
        return false
    end

    return pcall(setMark, step.unit, mark)
end

-- ============================================================================
-- Identity
-- ============================================================================

-- Builds the pseudo spell id of a (unit, mark) pair.
-- @param unit string  One of the whitelisted unit tokens; any other value, including nil, answers nil.
-- @param mark number  0 to clear the mark, 1 (star) to 8 (skull); a non-integer or out-of-range value answers nil.
-- @return number|nil  The pseudo spell id; nil when either argument is not on the whitelist.
function platform:GetMarkActionId(unit, mark)
    local ordinal = type(unit) == 'string' and UNIT_ORDINAL[unit]

    if not ordinal or type(mark) ~= 'number' or mark < 0 or mark > 8 or mark % 1 ~= 0 then
        return nil
    end

    return ACTION_BASE + ordinal * ACTION_SPAN + mark
end

-- Splits a pseudo spell id back into its unit and mark.
-- @param id any  Any value; a real spell id, a non-number or a non-integer answers nil.
-- @return string|nil  The whitelisted unit token; nil when id is not a Set Mark pseudo id.
-- @return number|nil  The mark, 0 to 8; nil together with the unit.
function platform:DecodeMarkActionId(id)
    if type(id) ~= 'number' or id < ACTION_BASE or id % 1 ~= 0 then
        return nil
    end

    local offset = id - ACTION_BASE
    local unit = ACTION_UNITS[(offset - offset % ACTION_SPAN) / ACTION_SPAN]
    local mark = offset % ACTION_SPAN

    if not unit or mark > 8 then
        return nil
    end

    return unit, mark
end

-- Tells whether a number is the pseudo spell id of a Set Mark step.
-- @param id any  A value from the bar index or a step.
-- @return boolean  True when id decodes to a (unit, mark) pair.
function platform:IsMarkActionId(id)
    return self:DecodeMarkActionId(id) ~= nil
end

-- Tells whether a unit can be offered for a Set Mark step on this client.
-- @param unit any  A saved unit field.
-- @return boolean  True when unit is on the whitelist and the client has it (focus needs a focus target).
function platform:IsMarkActionUnit(unit)
    if type(unit) ~= 'string' or not UNIT_ORDINAL[unit] then
        return false
    end
    if FOCUS_UNITS[unit] and self.IsFocusUnitSupported and self:IsFocusUnitSupported() == false then
        return false
    end

    return true
end

-- Lists the units the editor offers for a Set Mark step on this client. Allocates; not for the poll.
-- @return string[]  The whitelisted unit tokens this client supports, in editor order.
function platform:GetMarkActionUnits()
    local units = {}

    for _, token in ipairs(ACTION_UNITS) do
        if self:IsMarkActionUnit(token) then
            units[#units + 1] = token
        end
    end

    return units
end

-- Turns a saved Set Mark step into its pseudo spell id.
-- @param step table  A rotation step; step.unit is a unit token and step.action a mark name or none. Anything that is
--   not a table answers 'invalid-mark-step'.
-- @return number|nil  The pseudo spell id; nil on failure.
-- @return string|nil  The reason code when the first return is nil: 'invalid-mark-step' when either field is not on
--   the whitelist, 'unsupported-unit' when the unit is not available on this client; nil otherwise.
function platform:GetMarkStepActionId(step)
    if type(step) ~= 'table' then
        return nil, 'invalid-mark-step'
    end

    local unit, action = step.unit, step.action
    local mark = type(action) == 'string' and MARK_NUMBER[action]
    local ordinal = type(unit) == 'string' and UNIT_ORDINAL[unit]

    if step.action == HIGHEST_UNSET then
        mark = 9
    end

    if mark == false or mark == nil or not ordinal then
        return nil, 'invalid-mark-step'
    end
    if not self:IsMarkActionUnit(unit) then
        return nil, 'unsupported-unit'
    end

    return ACTION_BASE + ordinal * ACTION_SPAN + mark
end

-- Gives the localized name of a mark.
-- @param mark number  0 for none, 1 (star) to 8 (skull).
-- @return string|nil  The game's own name (RAID_TARGET_N, or NONE for 0), else the English name; nil outside 0 to 8 and
--   for a non-integer.
function platform:GetRaidMarkName(mark)
    if type(mark) ~= 'number' or mark < 0 or mark > 8 or mark % 1 ~= 0 then
        return nil
    end

    if mark == 0 then
        local label = env.NONE
        return type(label) == 'string' and label or 'None'
    end

    local label = env['RAID_TARGET_' .. mark]

    if type(label) == 'string' and label ~= '' then
        return label
    end

    local key = MARK_KEY[mark]
    return key:sub(1, 1):upper() .. key:sub(2)
end

-- Gives the texture of a mark.
-- @param mark number  0 for none, 1 (star) to 8 (skull).
-- @return string  The game's raid target icon; the generic question mark for none and out-of-range numbers.
function platform:GetRaidMarkTexture(mark)
    if type(mark) == 'number' and mark >= 1 and mark <= 8 and mark % 1 == 0 then
        return 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_' .. mark
    end

    return 'Interface\\Icons\\INV_Misc_QuestionMark'
end

-- Describes a pseudo spell id the way GetSpellInfo describes a spell, so the preview window and reports can name it.
-- @param id any  A number; a real spell id answers nil.
-- @return table|nil  { name = string, iconID = string, mark = number, unit = string } for a Set Mark id (name is the
--   mark's name, iconID its texture); nil otherwise.
function platform:GetMarkActionInfo(id)
    local unit, mark = self:DecodeMarkActionId(id)

    if not unit then
        return nil
    end

    return { name = self:GetRaidMarkName(mark), iconID = self:GetRaidMarkTexture(mark), mark = mark, unit = unit }
end
