-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for two Boolean unit states, dead or ghost (UnitIsDeadOrGhost) and friendly to the player
-- (UnitIsFriend), selected by a closed `kind`. Returns `boolean, nil` or `nil, reason`; game values pass
-- platform:CanReadValue first. Only the probe and restricted combat-data policies read. Loaded from
-- RotationMaster.toc after Platform/unit_flags.lua.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; the reader is a Built In
-- helper, so its body is frozen.
local _, addon = ...
local platform = addon.Platform

-- Unit absence is unavailable, including under NOT: never infer a living or
-- friendly recipient from a missing mouseover. Observations expire each pass.
-- kind is "dead" or "friendly". Returns the state, or nil and a reason; a unit that does not exist is the
-- "unit-data-unavailable" reason, unlike Platform/unit_flags.lua where absence is false.
function platform:GetUnitStateObservation(unit, kind)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if kind~='dead' and kind~='friendly' then return nil,'invalid-unit-state-query' end
    local existsAPI=UnitExists
    if type(existsAPI)~='function' then return nil,'missing-api' end
    local existsOK,exists=pcall(existsAPI,unit)
    if not existsOK then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil or exists==false then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    local api
    if kind=='dead' then api=UnitIsDeadOrGhost else api=UnitIsFriend end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,result
    if kind=='friendly' then ok,result=pcall(api,'player',unit)
    else ok,result=pcall(api,unit) end
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(result) then return nil,'restricted-value' end
    if result==nil then return nil,'unit-state-unavailable' end
    if type(result)~='boolean' then return nil,'invalid-api-result' end
    return result
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitStateObservation" then return addon.Platform.GetUnitStateObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_states.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_states.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
