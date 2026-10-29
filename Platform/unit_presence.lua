-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for "does this unit token exist" (UnitExists). Returns `boolean, nil` or `nil, reason`; the value
-- passes platform:CanReadValue first. Works on any identified client family rather than only the probe and restricted
-- policies, and reads no other unit fact. Loaded from RotationMaster.toc after Platform/creature_type.lua.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; the reader is a Built In
-- helper, so its body is frozen.
local _, addon = ...
local platform = addon.Platform

-- Answers whether a selected unit or group-unit assignment exists.
-- @param unit string  Unit token or group-unit kind.
-- @return boolean|nil  Whether it exists; nil when the observation is unavailable.
-- @return string|nil  The reason an observation is unavailable.
function platform:GetUnitExistence(unit)
    if not self:CanReadValue(unit) or type(unit) ~= 'string' or unit == '' then
        return nil, 'invalid-unit'
    end

    if addon.groupUnitKinds and addon.groupUnitKinds[unit] then
        local token, reason = self:ResolveGroupUnit(unit)

        if token then
            return true
        end
        if reason == 'no-marked-unit' or reason == 'no-assigned-unit' then
            return false
        end
        if reason == 'no-token' then
            return true
        end

        return nil, reason or 'unit-data-unavailable'
    end

    if type(UnitExists) ~= 'function' then
        return nil, 'missing-api'
    end

    local ok, exists = pcall(UnitExists, unit)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(exists) then
        return nil, 'restricted-value'
    end
    if exists == nil or exists == false then
        return false
    end
    if exists == true or exists == 1 then
        return true
    end

    return nil, 'invalid-api-result'
end

-- Reads whether a unit token exists (UnitExists).
-- @param unit string  The unit token to read; must be a non-empty string.
-- @return boolean|nil  True or false for whether the unit exists; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Public presence is independent of enemy-combat observation policy. Only a readable Boolean false establishes
-- absence; no additional unit facts apply.
function platform:GetUnitPresenceObservation(unit)
    if not self:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if self:GetClientFamily()=='unknown' then return nil,'unsupported-client' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local ok,exists=pcall(UnitExists,unit)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    return exists
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitPresenceObservation" then return addon.Platform.GetUnitPresenceObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_presence.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_presence.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
