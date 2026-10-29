-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Validation and presentation of direct Set Mark steps.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local platform = addon.Platform

-- Tells why a rotation step cannot work on this client.
-- @param step any  Any rotation step; anything that is not a Set Mark step is supported.
-- @return string|nil  'invalid-mark-step' or 'unsupported-unit' for an invalid Set Mark step; nil otherwise.
function addon:GetStepSupport(step)
    if type(step) ~= 'table' or step.type ~= 'mark' then
        return nil
    end

    local id, reason = platform:GetMarkStepActionId(step)

    if not id then
        return reason
    end

    return nil
end

-- Describes a Set Mark step in words for cards, reports and tooltips.
-- @param step table  A rotation step of type mark; anything that is not a table reads as not filled in.
-- @return string  "Set Skull on your target", "Clear the mark on your target", or "Set Mark" while it is not filled in.
function addon:DescribeMarkStep(step)
    if type(step) ~= 'table' then
        return L['Set Mark']
    end

    local unit = type(step.unit) == 'string' and platform:IsMarkActionUnit(step.unit) and self.units[step.unit] or nil
    local mark = type(step.action) == 'string' and platform.RaidMarkActions.marks[step.action] or nil

    if unit and step.action == platform.RaidMarkActions.highestUnset then
        return string.format(L['Set %s on %s'], L['Highest priority unset'], unit)
    end
    if not unit or not mark then
        return L['Set Mark']
    end
    if mark == 0 then
        return string.format(L['Clear the mark on %s'], unit)
    end

    return string.format(L['Set %s on %s'], platform:GetRaidMarkName(mark), unit)
end

-- Gives the icon a Set Mark step shows on its card.
-- @param step table  A rotation step of type mark.
-- @return string  The chosen mark's icon, or the generic question mark while it is not filled in.
function addon:GetMarkStepIcon(step)
    local mark = type(step) == 'table' and type(step.action) == 'string' and platform.RaidMarkActions.marks[step.action]
    return platform:GetRaidMarkTexture(mark or 0)
end
