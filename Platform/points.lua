local _,addon=...
local platform=addon.Platform

-- POINT has its own explicit secondary-resource selection policy. These reads
-- neither choose the primary power bar nor redirect the configured unit.
function platform:GetUnitPointIdentityObservation(unit,includeClass)
    if self:GetCombatDataPolicy()~='probe' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(includeClass) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if type(includeClass)~='boolean' then return nil,'invalid-point-identity-query' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOK,exists=pcall(UnitExists,unit)
    if not existsOK then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return {exists=false} end
    if not includeClass then return {exists=true} end
    if type(UnitClass)~='function' then return nil,'missing-api' end
    local ok,_,class=pcall(UnitClass,unit)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(class) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(class) then return nil,'restricted-value' end
    if class==nil then return nil,'point-class-unavailable' end
    if type(class)~='string' or class=='' then return nil,'invalid-api-result' end
    return {exists=true,class=class}
end

function platform:GetUnitPointPowerObservation(unit,powerType,kind)
    if self:GetCombatDataPolicy()~='probe' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(powerType) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if type(powerType)~='number' or powerType~=powerType or powerType<0 or powerType==math.huge or powerType%1~=0 then return nil,'invalid-point-power-query' end
    if kind~='current' and kind~='maximum' then return nil,'invalid-point-power-query' end
    local api
    if kind=='current' then api=UnitPower else api=UnitPowerMax end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,result=pcall(api,unit,powerType)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(result) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(result) then return nil,'restricted-value' end
    if result==nil then return nil,'point-power-unavailable' end
    if type(result)~='number' or result~=result or result==math.huge or result==-math.huge then return nil,'invalid-api-result' end
    return result
end

-- Explicit player/target combo transport. Other units/resources use the observer above.
function platform:GetPlayerComboPointObservation(powerType,kind)
    local info=self:GetClientInfo()
    if info.combatDataPolicy~='probe' then return nil,'unsupported-policy' end
    local family
    if self:CanReadValue(info) and type(info)=='table' then family=rawget(info,'family') end
    if not self:CanReadValue(family) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(family) then return nil,'restricted-value' end
    if family~='tbc' then return nil,'unsupported-point-transport' end
    if not self:CanReadValue(powerType) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(powerType)~='number' or powerType~=powerType or powerType<0 or powerType==math.huge or powerType%1~=0 then return nil,'invalid-point-power-query' end
    if kind~='current' and kind~='maximum' then return nil,'invalid-point-power-query' end
    local api
    if kind=='current' then api=GetComboPoints else api=UnitPowerMax end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,result
    if kind=='current' then ok,result=pcall(api,'player','target') else ok,result=pcall(api,'player',powerType) end
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(result) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(result) then return nil,'restricted-value' end
    if result==nil then return nil,'point-power-unavailable' end
    if type(result)~='number' or result~=result or result==math.huge or result==-math.huge then return nil,'invalid-api-result' end
    return result
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetPlayerComboPointObservation" then return addon.Platform.GetPlayerComboPointObservation end
        if name=="Platform_GetUnitPointIdentityObservation" then return addon.Platform.GetUnitPointIdentityObservation end
        if name=="Platform_GetUnitPointPowerObservation" then return addon.Platform.GetUnitPointPowerObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/points.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/points.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
