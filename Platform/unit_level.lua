local _,addon=...
local platform=addon.Platform

local function finite(value)
    return type(value)=='number' and value==value and value<math.huge and value>-math.huge
end

-- Actual public unit levels are distinct from effective/scaled levels. Negative
-- sentinels do not reveal an exact level and must not enter numeric predicates.
function platform:GetUnitLevelObservation(unit)
    if not self:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if self:GetClientInfo().family=='unknown' then return nil,'unsupported-client' end
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
