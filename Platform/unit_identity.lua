-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for "are these two unit tokens the same unit" (UnitExists on the first, then UnitIsUnit). Returns
-- `boolean, nil` or `nil, reason`; game values pass platform:CanReadValue first. Only the probe and restricted
-- combat-data policies read. Loaded from RotationMaster.toc after Platform/runes.lua; consumed by the unit-identity
-- condition in Conditions/character.lua.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; the reader is a Built In
-- helper, so its body is frozen.
local _, addon = ...
local platform = addon.Platform

-- Reads whether two unit tokens are the same unit (UnitExists on the first, then UnitIsUnit).
-- @param unit string  The first unit token; must be a non-empty string.
-- @param otherunit string  The second unit token; must be a non-empty string.
-- @return boolean|nil  False when the first unit does not exist, otherwise the UnitIsUnit result; nil when it cannot
--   be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Preserves the original first-unit existence check and ordered comparison. The second token is passed to UnitIsUnit
-- without an extra existence query.
function platform:GetUnitIdentityObservation(unit, otherunit)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(otherunit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' or type(otherunit)~='string' or otherunit=='' then return nil,'invalid-unit' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOk,exists=pcall(UnitExists,unit)
    if not existsOk then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return false end
    if type(UnitIsUnit)~='function' then return nil,'missing-api' end
    local ok,same=pcall(UnitIsUnit,unit,otherunit)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(same) then return nil,'restricted-value' end
    if same==nil then return nil,'unit-identity-unavailable' end
    if type(same)~='boolean' then return nil,'invalid-api-result' end
    return same
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitIdentityObservation" then return addon.Platform.GetUnitIdentityObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_identity.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_identity.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
