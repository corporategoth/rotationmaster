-- Platform adapter for a unit's actual level (UnitExists, UnitLevel). Returns a record or `nil, reason`; game values
-- pass platform:CanReadValue and canaccessvalue first. Works on any identified client family, not only the probe and
-- restricted policies. Must not return effective or scaled levels. Loaded from RotationMaster.toc after
-- Platform/health_forecast.lua; the level conditions in Core/level_conditions.lua and Conditions/character.lua use it.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; finite and the reader are
-- Built In helpers, so their bodies are frozen.
local _, addon = ...
local platform = addon.Platform

-- True for a number that is neither NaN nor infinite.
local function finite(value)
    return type(value)=='number' and value==value and value<math.huge and value>-math.huge
end

-- Actual public unit levels are distinct from effective/scaled levels. Negative
-- sentinels do not reveal an exact level and must not enter numeric predicates.
-- Returns { exists = false } or { exists = true, level = n } with a positive integer level, or nil and a reason (a
-- negative level, which UnitLevel reports for unknown-level units, is "level-data-unavailable").
function platform:GetUnitLevelObservation(unit)
    if not self:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if self:GetClientFamily()=='unknown' then return nil,'unsupported-client' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOk,exists=pcall(UnitExists,unit)
    if not existsOk then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return {exists=false} end
    if type(UnitLevel)~='function' then return nil,'missing-api' end
    local levelOk,level=pcall(UnitLevel,unit)
    if not levelOk then return nil,'api-error' end
    if not self:CanReadValue(level) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(level) then return nil,'restricted-value' end
    if level==nil then return nil,'level-data-unavailable' end
    if not finite(level) then return nil,'invalid-api-result' end
    if level<0 then return nil,'level-data-unavailable' end
    if level==0 or level%1~=0 then return nil,'invalid-api-result' end
    return {exists=true,level=level}
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitLevelObservation" then return addon.Platform.GetUnitLevelObservation end
        if name=="finite" then return finite end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_level.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_level.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
