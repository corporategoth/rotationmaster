-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
-- Registers the raid mark unit types (skull, cross, square, moon, triangle, diamond, circle, star and anymark) with the
-- unit lists constants.lua built, next to the group unit types (main tank, group leader ...). Like those they have no
-- token of their own: Core/group_unit_resolution.lua swaps in the token of the unit that carries the mark when a
-- condition is evaluated, so every unit-aware condition works on them unchanged. A kind is always recognized (a saved
-- one stays recognized on a client that cannot resolve it); the pickers list it only where the client can read marks.
-- Loaded from RotationMaster.toc straight after constants.lua, before any Conditions/ file reads addon.units.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local platform = addon.Platform

-- Adds the mark unit types to addon.groupUnitKinds, and to addon.units and addon.unitsPossessive where the client can
-- read marks. Safe to run again (the unit tables are rebuilt by constants.lua when it is reloaded).
local function register()
    local kinds = addon.groupUnitKinds

    if type(kinds) ~= 'table' or type(addon.units) ~= 'table' or type(addon.unitsPossessive) ~= 'table' then
        return
    end
    if not platform or type(platform.IsRaidMarkUnitKind) ~= 'function' then
        return
    end

    local marks = platform.RaidMarks

    for index, key in ipairs(marks.keys) do
        kinds[key] = true

        if platform:GetGroupUnitSupport(key) == nil then
            local name = platform:GetRaidMarkName(index)
            addon.units[key] = string.format(L['the %s-marked unit'], name)
            addon.unitsPossessive[key] = string.format(L["the %s-marked unit's"], name)
        end
    end

    kinds.anymark = true

    if platform:GetGroupUnitSupport('anymark') == nil then
        addon.units.anymark = L['the highest-priority marked unit']
        addon.unitsPossessive.anymark = L["the highest-priority marked unit's"]
    end
end

register()
