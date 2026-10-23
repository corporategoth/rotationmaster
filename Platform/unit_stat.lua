local _,addon=...
local platform=addon.Platform
local function finite(value)
    return type(value)=='number' and value==value and value~=math.huge and value~=-math.huge
end

-- The selector range is RM's six authored choices. Only native return two is
-- consumed; its signed/fractional finite domain is not narrowed by UI display.
function platform:GetUnitStatObservation(unit,stat)
    if self:GetCombatDataPolicy()~='probe' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(stat) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if not finite(stat) or stat%1~=0 or stat<1 or stat>6 then return nil,'invalid-stat-query' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOk,exists=pcall(UnitExists,unit)
    if not existsOk then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return {exists=false} end
    local fn
    if stat==6 then fn=UnitArmor else fn=UnitStat end
    if type(fn)~='function' then return nil,'missing-api' end
    local ok,_,effective
    if stat==6 then ok,_,effective=pcall(fn,unit)
    else ok,_,effective=pcall(fn,unit,stat) end
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(effective) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(effective) then return nil,'restricted-value' end
    if effective==nil then return nil,'stat-data-unavailable' end
    if not finite(effective) then return nil,'invalid-api-result' end
    return {exists=true,value=effective}
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitStatObservation" then return addon.Platform.GetUnitStatObservation end
        if name=="finite" then return finite end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_stat.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_stat.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
