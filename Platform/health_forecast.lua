local _,addon=...
local platform=addon.Platform

local function finite(value)
    return type(value)=='number' and value==value and value<math.huge and value>-math.huge
end

local function readField(self,object,key)
    if not self:CanReadValue(object) then return nil,'restricted-value' end
    if type(object)~='table' then return nil,'invalid-api-result' end
    local ok,value=pcall(function() return object[key] end)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(value) then return nil,'restricted-value' end
    return value
end

local function providerValue(self,value)
    if not self:CanReadValue(value) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(value) then return nil,'restricted-value' end
    if value==nil or value==false then return nil end
    if not finite(value) or value<0 then return nil,'invalid-api-result' end
    return value
end

function platform:GetHealthForecastIdentityObservation(unit)
    if self:GetClientInfo().combatDataPolicy~='probe' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local ok,exists=pcall(UnitExists,unit)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return false end
    if type(UnitGUID)~='function' then return nil,'missing-api' end
    local success,guid=pcall(UnitGUID,unit)
    if not success then return nil,'api-error' end
    if not self:CanReadValue(guid) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(guid) then return nil,'restricted-value' end
    if guid==nil then return nil,'unit-guid-unavailable' end
    if type(guid)~='string' or guid=='' then return nil,'invalid-api-result' end
    return guid
end

function platform:GetHealthForecastValueObservation(unit,kind)
    if self:GetClientInfo().combatDataPolicy~='probe' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    local api
    if kind=='current' then api=UnitHealth
    elseif kind=='maximum' then api=UnitHealthMax
    else return nil,'invalid-health-forecast-query' end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,value=pcall(api,unit)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(value) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(value) then return nil,'restricted-value' end
    if value==nil then return nil,'health-data-unavailable' end
    if not finite(value) or value<0 then return nil,'invalid-api-result' end
    return value
end

function platform:GetHealthForecastProviderObservation(unit)
    if self:GetClientInfo().combatDataPolicy~='probe' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    local provider=_G.RealMobHealth
    if not self:CanReadValue(provider) then return nil,'restricted-value' end
    if provider==nil or provider==false then return {} end
    local api,why=readField(self,provider,'GetUnitHealth')
    if why then return nil,why end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,current,maximum=pcall(api,unit)
    if not ok then return nil,'api-error' end
    local value,reason=providerValue(self,current)
    if reason then return nil,reason end
    local max,maxReason=providerValue(self,maximum)
    if maxReason then return nil,maxReason end
    return {current=value,maximum=max}
end

function platform:GetHealthForecastTimeObservation()
    if type(GetTime)~='function' then return nil,'missing-api' end
    local ok,now=pcall(GetTime)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(now) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(now) then return nil,'restricted-value' end
    if not finite(now) then return nil,'invalid-forecast-time' end
    return now
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetHealthForecastIdentityObservation" then return addon.Platform.GetHealthForecastIdentityObservation end
        if name=="Platform_GetHealthForecastProviderObservation" then return addon.Platform.GetHealthForecastProviderObservation end
        if name=="Platform_GetHealthForecastTimeObservation" then return addon.Platform.GetHealthForecastTimeObservation end
        if name=="Platform_GetHealthForecastValueObservation" then return addon.Platform.GetHealthForecastValueObservation end
        if name=="finite" then return finite end
        if name=="providerValue" then return providerValue end
        if name=="readField" then return readField end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/health_forecast.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/health_forecast.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
