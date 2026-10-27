-- Platform adapter for unit health (UnitExists, UnitHealth, UnitHealthMax). Returns a record or `nil, reason`; game
-- values pass platform:CanReadValue and canaccessvalue before any comparison, because Retail and Forever make health
-- secret in combat (docs/restricted-clients.md) and a secret value is unavailable, never a number. Only the probe and
-- restricted combat-data policies read. Loaded from RotationMaster.toc after Platform/casting.lua.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; finite and the reader are
-- Built In helpers, so their bodies are frozen.
local _, addon = ...
local platform = addon.Platform

-- True for a number that is neither NaN nor infinite.
local function finite(value)
    return type(value)=='number' and value==value and value<math.huge and value>-math.huge
end

-- Request maximum only for predicates that need it. A readable false existence
-- is ordinary absence; nil or unreadable data never establishes absence.
-- Returns { exists = false }, or { exists = true, current = n } plus maximum = n when includeMaximum is true, or nil
-- and a reason. Callers cache the result per evaluation pass.
function platform:GetUnitHealthObservation(unit, includeMaximum)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(includeMaximum) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if includeMaximum~=nil and type(includeMaximum)~='boolean' then return nil,'invalid-health-query' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOk,exists=pcall(UnitExists,unit)
    if not existsOk then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return {exists=false} end
    if type(UnitHealth)~='function' then return nil,'missing-api' end
    local currentOk,current=pcall(UnitHealth,unit)
    if not currentOk then return nil,'api-error' end
    if not self:CanReadValue(current) then return nil,'restricted-value' end
    -- Keep the native proof visible at the arithmetic boundary; the platform
    -- guard above also covers older clients and the issecretvalue predicate.
    if canaccessvalue and not canaccessvalue(current) then return nil,'restricted-value' end
    if current==nil then return nil,'health-data-unavailable' end
    if not finite(current) or current<0 then return nil,'invalid-api-result' end
    local record={exists=true,current=current}
    if includeMaximum then
        if type(UnitHealthMax)~='function' then return nil,'missing-api' end
        local maximumOk,maximum=pcall(UnitHealthMax,unit)
        if not maximumOk then return nil,'api-error' end
        if not self:CanReadValue(maximum) then return nil,'restricted-value' end
        if canaccessvalue and not canaccessvalue(maximum) then return nil,'restricted-value' end
        if maximum==nil then return nil,'health-data-unavailable' end
        if not finite(maximum) or maximum<0 then return nil,'invalid-api-result' end
        record.maximum=maximum
    end
    return record
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitHealthObservation" then return addon.Platform.GetUnitHealthObservation end
        if name=="finite" then return finite end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_health.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_health.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
