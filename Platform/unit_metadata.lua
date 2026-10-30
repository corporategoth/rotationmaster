-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for unit metadata strings: class file name (UnitClass), creature type name (UnitCreatureType) and
-- classification token (UnitClassification), selected by a closed `kind`. Returns `string, nil`, `false` for an
-- absent unit, or `nil, reason`; game values pass platform:CanReadValue first. Only the probe and restricted
-- combat-data policies read. Loaded from RotationMaster.toc after Platform/unit_identity.lua.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; the reader is a Built In
-- helper, so its body is frozen.
local _, addon = ...
local platform = addon.Platform

-- Reads one unit metadata string: class file name, creature type name or classification token.
-- @param unit string  The unit token to read; must be a non-empty string.
-- @param kind string  Which string: "class" (UnitClass, second return), "creature" (UnitCreatureType, the localized
--   name) or "classification" (UnitClassification).
-- @return string|false|nil  The readable non-empty string; false when the unit does not exist; nil when it cannot be
--   read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Native metadata identities are kept; unused tuple fields do not determine availability.
function platform:GetUnitMetadataObservation(unit, kind)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if kind~='class' and kind~='creature' and kind~='classification' then return nil,'invalid-unit-metadata-query' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOk,exists=pcall(UnitExists,unit)
    if not existsOk then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return false end
    local api
    if kind=='class' then api=UnitClass
    elseif kind=='creature' then api=UnitCreatureType
    else api=UnitClassification end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,observed
    if kind=='class' then ok,observed=pcall(function() return select(2,api(unit)) end)
    else ok,observed=pcall(api,unit) end
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(observed) then return nil,'restricted-value' end
    if observed==nil then return nil,'unit-metadata-unavailable' end
    if type(observed)~='string' or observed=='' then return nil,'invalid-api-result' end
    return observed
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitMetadataObservation" then return addon.Platform.GetUnitMetadataObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_metadata.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_metadata.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
