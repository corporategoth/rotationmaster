-- Health forecast reader for the health-until-target conditions in Conditions/stats.lua. Owns
-- addon:GetConditionHealthForecast, which turns a unit's current health, a target and the recorded damage history into
-- an ETA in seconds; the arithmetic itself lives in Functions/forecast.lua. Draws nothing and stores nothing. Runs only
-- under the 'probe' and 'restricted' combat-data policies, and every game value passes platform:CanReadValue before it
-- is compared, so a hidden value gives nil and a reason, never a guess. Loaded from the Core condition-service group of
-- RotationMaster.toc. The helpers and the function body are frozen: saved custom conditions bind to their exact text,
-- so only the comments outside function bodies may change, and the generated block at the end is not edited by hand.
local _, addon = ...

-- Returns true when `value` is a readable, finite number, otherwise false and a reason code ('restricted-value' when
-- the client hides it). Does not test the sign; callers reject negatives themselves.
local function finite(platform, value)
    if not platform:CanReadValue(value) then return false,'restricted-value' end
    if type(value)~='number' or value~=value or value>=math.huge or value<=-math.huge then return false,'invalid-health-forecast-number' end
    return true
end

-- Reads object[key] under pcall after checking both the table and the result are readable. Returns the value (which may
-- be nil), or nil and a reason; a missing key is not an error, so callers test the reason, not the value.
local function readField(platform, object, key)
    if not platform:CanReadValue(object) then return nil,'restricted-value' end
    if type(object)~='table' then return nil,'invalid-health-forecast-data' end
    local ok,value=pcall(function() return object[key] end)
    if not ok then return nil,'health-forecast-data-error' end
    if not platform:CanReadValue(value) then return nil,'restricted-value' end
    return value
end

-- Reads a unit's 'current' or 'maximum' health through the cached Platform observation. Returns a finite non-negative
-- number, or nil and a reason ('missing-api' when this client has no such adapter).
local function nativeValue(self, unit, kind, cache)
    local platform=self.Platform
    if type(platform.GetHealthForecastValueObservation)~='function' then return nil,'missing-api' end
    local value,why=addon.Functions.cache.getCached(cache,platform.GetHealthForecastValueObservation,platform,unit,kind)
    if not platform:CanReadValue(value) then return nil,'restricted-value' end
    if value==nil then return nil,why or 'health-data-unavailable' end
    local valid,reason=finite(platform,value)
    if not valid then return nil,reason end
    if value<0 then return nil,'invalid-health-forecast-number' end
    return value
end

-- Estimates the seconds until `unit` reaches `healthTarget` at its recent damage/healing rate. `healthTarget` is an
-- absolute amount (negative means that much below maximum), or a fraction of maximum when `percentage` is true; `mode`
-- is 'noheals', 'nodmg' or anything else for both; `cache` is the evaluation-pass cache (nil reads afresh). Returns the
-- ETA (0 when already at the target or when the rate is flat or moves away from it), false when the unit is gone or
-- no estimate exists (no history, or 2 seconds or less of it), or nil and a reason when a required value is
-- unavailable.
function addon:GetConditionHealthForecast(unit, healthTarget, percentage, mode, cache)
    local platform=self.Platform
    local policy=platform:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not platform:CanReadValue(unit) or not platform:CanReadValue(percentage) or not platform:CanReadValue(cache) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' or type(percentage)~='boolean' then return nil,'invalid-health-forecast-query' end
    if cache~=nil and type(cache)~='table' then return nil,'invalid-health-forecast-cache' end
    if type(platform.GetHealthForecastIdentityObservation)~='function' then return nil,'missing-api' end
    local guid,identityReason=addon.Functions.cache.getCached(cache,platform.GetHealthForecastIdentityObservation,platform,unit)
    if not platform:CanReadValue(guid) then return nil,'restricted-value' end
    if guid==nil then return nil,identityReason or 'unit-guid-unavailable' end
    if guid==false then return false end
    if type(guid)~='string' or guid=='' then return nil,'invalid-health-forecast-identity' end
    local current,maximum
    if percentage then
        if type(platform.GetHealthForecastProviderObservation)~='function' then return nil,'missing-api' end
        local provider,why=platform:GetHealthForecastProviderObservation(unit)
        if not platform:CanReadValue(provider) then return nil,'restricted-value' end
        if provider==nil then return nil,why or 'health-provider-unavailable' end
        current,why=readField(platform,provider,'current')
        if why then return nil,why end
        maximum,why=readField(platform,provider,'maximum')
        if why then return nil,why end
        if current==nil or current==false then current,why=nativeValue(self,unit,'current',cache);if current==nil then return nil,why end end
        if maximum==nil or maximum==false then maximum,why=nativeValue(self,unit,'maximum',cache);if maximum==nil then return nil,why end end
    else
        local why;current,why=nativeValue(self,unit,'current',cache)
        if current==nil then return nil,why end
    end
    local valid,reason=finite(platform,current)
    if not valid then return nil,reason end
    if current<0 then return nil,'invalid-health-forecast-number' end
    valid,reason=finite(platform,healthTarget)
    if not valid then return nil,reason end
    local target=healthTarget
    if percentage then
        valid,reason=finite(platform,maximum)
        if not valid then return nil,reason end
        if maximum<0 then return nil,'invalid-health-forecast-number' end
        target=maximum*healthTarget
    elseif healthTarget<0 then
        local why;maximum,why=nativeValue(self,unit,'maximum',cache)
        if maximum==nil then return nil,why end
        target=target+maximum
    end
    valid,reason=finite(platform,target)
    if not valid then return nil,reason end
    if current==target then return 0 end
    local history,why=readField(platform,self.damageHistory,guid)
    if why then return nil,why end
    if history==nil or history==false then return false end
    if type(history)~='table' then return nil,'invalid-forecast-history' end
    if not platform:CanReadValue(mode) then return nil,'restricted-value' end
    local noheals,nodmg=mode=='noheals',mode=='nodmg'
    local profile,profileReason=readField(platform,self.db,'profile')
    if profileReason then return nil,profileReason end
    local window,windowReason=readField(platform,profile,'damage_history')
    if windowReason then return nil,windowReason end
    valid,reason=finite(platform,window)
    if not valid then return nil,reason end
    if type(platform.GetHealthForecastTimeObservation)~='function' then return nil,'missing-api' end
    local now,timeReason=platform:GetHealthForecastTimeObservation()
    if not platform:CanReadValue(now) then return nil,'restricted-value' end
    if now==nil then return nil,timeReason or 'forecast-time-unavailable' end
    valid,reason=finite(platform,now)
    if not valid then return nil,reason end
    local functions=self.Functions.forecast
    if type(functions)~='table' or type(functions.calculate)~='function' then return nil,'forecast-kernel-unavailable' end
    local ok,rate,seconds,forecastReason=pcall(functions.calculate,platform,history,window,noheals,nodmg,now)
    if not ok then return nil,'forecast-kernel-error' end
    if not platform:CanReadValue(forecastReason) then return nil,'restricted-value' end
    if forecastReason~=nil then return nil,forecastReason end
    if not platform:CanReadValue(rate) then return nil,'restricted-value' end
    if rate==nil or rate==false then return false end
    valid,reason=finite(platform,rate)
    if not valid then return nil,reason end
    valid,reason=finite(platform,seconds)
    if not valid then return nil,reason end
    if seconds<=2 then return false end
    local eta=0
    local distance,divisor
    if rate<0 and target<current then distance=current-target;divisor=-rate
    elseif rate>0 and target>current then distance=target-current;divisor=rate end
    if distance~=nil then
        valid,reason=finite(platform,distance)
        if not valid then return nil,reason end
        eta=distance/divisor
    end
    valid,reason=finite(platform,eta)
    if not valid then return nil,reason end
    return eta
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="GetConditionHealthForecast" then return addon.GetConditionHealthForecast end
        if name=="finite" then return finite end
        if name=="nativeValue" then return nativeValue end
        if name=="readField" then return readField end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Core/health_forecast_conditions.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Core/health_forecast_conditions.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
