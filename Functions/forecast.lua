-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Checked health-history forecast: forecast.calculate turns damage and heal history into a signed rate per second
-- for the health-forecast conditions (Core/health_forecast_conditions.lua), returning nil plus a reason instead of a
-- guess when anything cannot be read, is not finite or exceeds the work budget (docs/health-forecasting.md).
-- Loaded from RotationMaster.toc after Functions/trends.lua. It must not touch the profile or the clock: the window and
-- the time are arguments. Restricted clients: every consumed value goes through platform:CanReadValue first.
-- The older Functions/trends.lua formulas stay untouched because saved custom source binds to them.
-- The function bodies are recorded as Built In helpers and are frozen: saved copies hash their exact text.
local _, addon = ...
local forecast = {}
addon.Functions = addon.Functions or {}
addon.Functions.forecast = forecast

-- Returns true when the value is a readable, finite number; otherwise false and a reason code ('restricted-value' or
-- 'invalid-forecast-number'). Guards every number before arithmetic so a secret or NaN value cannot reach it.
local function finite(platform, value)
    if not platform:CanReadValue(value) then return false,'restricted-value' end
    if type(value)~='number' or value~=value or value>=math.huge or value<=-math.huge then return false,'invalid-forecast-number' end
    return true
end

-- Reads object[key] under pcall after checking both the table and the value are readable. Returns the value, or nil and
-- a reason code ('restricted-value', 'invalid-forecast-history' or 'forecast-history-error'). A metatable that throws
-- therefore becomes an unavailable result instead of an error.
local function readField(platform, object, key)
    if not platform:CanReadValue(object) then return nil,'restricted-value' end
    if type(object)~='table' then return nil,'invalid-forecast-history' end
    local ok,value=pcall(function() return object[key] end)
    if not ok then return nil,'forecast-history-error' end
    if not platform:CanReadValue(value) then return nil,'restricted-value' end
    return value
end

-- A new checked kernel. Published trends.calculate and its aliases remain
-- untouched for saved source. Work bounds are RM policy, not a native limit.
-- Takes the platform (readability authority), the history table with damage and heals rows of time/value, the
-- weighting window, the two skip flags (a skipped stream is never read) and the clock snapshot. Returns rate and the
-- larger stream age, or nil, nil and a reason code. The inner scan visits at most 4096 rows plus accumulation bins
-- across both streams combined.
function forecast.calculate(platform, history, window, noheals, nodmg, now)
    if type(platform)~='table' or type(platform.CanReadValue)~='function' then return nil,nil,'invalid-forecast-platform' end
    if not platform:CanReadValue(history) or not platform:CanReadValue(noheals) or not platform:CanReadValue(nodmg) then return nil,nil,'restricted-value' end
    if type(history)~='table' then return nil,nil,'invalid-forecast-history' end
    if type(noheals)~='boolean' or type(nodmg)~='boolean' then return nil,nil,'invalid-forecast-mode' end
    local valid,reason=finite(platform,window)
    if not valid then return nil,nil,reason end
    valid,reason=finite(platform,now)
    if not valid then return nil,nil,reason end
    local work=0
    local function scan(name,skip)
        if skip then return 0,0,0 end
        local rows,why=readField(platform,history,name)
        if why then return nil,nil,nil,why end
        if type(rows)~='table' then return nil,nil,nil,'invalid-forecast-stream' end
        local maxoffs,data=0,{}
        for _,row in ipairs(rows) do
            work=work+1
            if work>4096 then return nil,nil,nil,'forecast-work-budget' end
            local time,problem=readField(platform,row,'time')
            if problem then return nil,nil,nil,problem end
            local good,numberReason=finite(platform,time)
            if not good then return nil,nil,nil,numberReason end
            local diff=now-time
            good,numberReason=finite(platform,diff)
            if not good then return nil,nil,nil,numberReason end
            local scale=window-diff
            local functions,namespaceReason=readField(platform,addon,'Functions')
            if namespaceReason then return nil,nil,nil,namespaceReason end
            if type(functions)~='table' then return nil,nil,nil,'forecast-round-unavailable' end
            local values
            values,namespaceReason=readField(platform,functions,'values')
            if namespaceReason then return nil,nil,nil,namespaceReason end
            if type(values)~='table' then return nil,nil,nil,'forecast-round-unavailable' end
            local round
            round,namespaceReason=readField(platform,values,'round')
            if namespaceReason then return nil,nil,nil,namespaceReason end
            if type(round)~='function' then return nil,nil,nil,'forecast-round-unavailable' end
            local ok,rounded=pcall(round,diff)
            if not ok then return nil,nil,nil,'forecast-round-error' end
            good,numberReason=finite(platform,rounded)
            if not good then return nil,nil,nil,numberReason end
            maxoffs=rounded
            if maxoffs>window then break end
            local amount,amountReason=readField(platform,row,'value')
            if amountReason then return nil,nil,nil,amountReason end
            if amount~=nil and amount~=false then
                good,numberReason=finite(platform,amount)
                if not good then return nil,nil,nil,numberReason end
                good,numberReason=finite(platform,scale)
                if not good then return nil,nil,nil,numberReason end
                local product=amount*scale
                good,numberReason=finite(platform,product)
                if not good then return nil,nil,nil,numberReason end
                local value=(data[maxoffs] or 0)+product
                good,numberReason=finite(platform,value)
                if not good then return nil,nil,nil,numberReason end
                data[maxoffs]=value
            end
        end
        local bins=maxoffs<0 and 0 or math.floor(maxoffs)+1
        if bins>4096-work then return nil,nil,nil,'forecast-work-budget' end
        work=work+bins
        local total,count=0,0
        for i=0,maxoffs do
            total=total+(data[i] or 0)
            local good,numberReason=finite(platform,total)
            if not good then return nil,nil,nil,numberReason end
            local scale=window-i
            good,numberReason=finite(platform,scale)
            if not good then return nil,nil,nil,numberReason end
            count=count+scale
            good,numberReason=finite(platform,count)
            if not good then return nil,nil,nil,numberReason end
        end
        return total,count,maxoffs
    end
    local damageTotal,damageCount,damageSeconds,damageReason=scan('damage',nodmg)
    if damageReason then return nil,nil,damageReason end
    local healTotal,healCount,healSeconds,healReason=scan('heals',noheals)
    if healReason then return nil,nil,healReason end
    local damageRate=damageCount>0 and -damageTotal/damageCount or 0
    valid,reason=finite(platform,damageRate)
    if not valid then return nil,nil,reason end
    local healRate=healCount>0 and healTotal/healCount or 0
    valid,reason=finite(platform,healRate)
    if not valid then return nil,nil,reason end
    local rate=damageRate+healRate
    valid,reason=finite(platform,rate)
    if not valid then return nil,nil,reason end
    return rate,damageSeconds>healSeconds and damageSeconds or healSeconds
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Forecast_calculate" then return addon.Functions.forecast.calculate end
        if name=="finite" then return finite end
        if name=="readField" then return readField end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Functions/forecast.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Functions/forecast.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
