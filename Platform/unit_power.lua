local _,addon=...
local platform=addon.Platform

local function finite(value)
    return type(value)=='number' and value==value and value<math.huge and value>-math.huge
end

-- Mana is an explicit resource even while another bar is active. Current mode
-- follows the numeric native type and preserves signed quantities such as Balance.
function platform:GetUnitPowerObservation(unit,resource,includeMaximum)
    if self:GetCombatDataPolicy()~='probe' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(resource) or not self:CanReadValue(includeMaximum) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if resource~='mana' and resource~='current' then return nil,'invalid-power-query' end
    if includeMaximum~=nil and type(includeMaximum)~='boolean' then return nil,'invalid-power-query' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOk,exists=pcall(UnitExists,unit)
    if not existsOk then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return {exists=false} end
    if not self:CanReadValue(Enum) then return nil,'restricted-value' end
    if type(Enum)~='table' then return nil,'power-type-unavailable' end
    local types=Enum.PowerType
    if not self:CanReadValue(types) then return nil,'restricted-value' end
    if type(types)~='table' then return nil,'power-type-unavailable' end
    local powerType
    if resource=='mana' then
        powerType=types.Mana
    else
        if type(UnitPowerType)~='function' then return nil,'missing-api' end
        local ok
        ok,powerType=pcall(UnitPowerType,unit)
        if not ok then return nil,'api-error' end
    end
    if not self:CanReadValue(powerType) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(powerType) then return nil,'restricted-value' end
    if powerType==nil then return nil,'power-type-unavailable' end
    if not finite(powerType) or powerType<0 or powerType%1~=0 then return nil,'invalid-api-result' end
    local known=false
    for _,id in pairs(types) do
        if self:CanReadValue(id) and type(id)=='number' and id==powerType then known=true;break end
    end
    if not known then return nil,'power-type-unavailable' end
    if type(UnitPower)~='function' then return nil,'missing-api' end
    local currentOk,current=pcall(UnitPower,unit,powerType)
    if not currentOk then return nil,'api-error' end
    if not self:CanReadValue(current) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(current) then return nil,'restricted-value' end
    if current==nil then return nil,'power-data-unavailable' end
    if not finite(current) or resource=='mana' and current<0 then return nil,'invalid-api-result' end
    local record={exists=true,powerType=powerType,current=current}
    if includeMaximum then
        if type(UnitPowerMax)~='function' then return nil,'missing-api' end
        local maximumOk,maximum=pcall(UnitPowerMax,unit,powerType)
        if not maximumOk then return nil,'api-error' end
        if not self:CanReadValue(maximum) then return nil,'restricted-value' end
        if canaccessvalue and not canaccessvalue(maximum) then return nil,'restricted-value' end
        if maximum==nil then return nil,'power-data-unavailable' end
        if not finite(maximum) or maximum<0 then return nil,'invalid-api-result' end
        record.maximum=maximum
    end
    return record
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitPowerObservation" then return addon.Platform.GetUnitPowerObservation end
        if name=="finite" then return finite end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/unit_power.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/unit_power.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
