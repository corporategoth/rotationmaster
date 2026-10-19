-- Exact test-only inverse for the one POINT evaluator; no runtime source rewrites.
local original=[=[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local class
        if value.unit == "player" then
            class = select(2, Functions.cache.getCached(addon.longtermCache, UnitClass, value.unit))
        else
            class = select(2, Functions.cache.getCached(cache, UnitClass, value.unit))
        end
        if class ~= nil then
            local point = addon.points[class] or Enum.PowerType.ComboPoints
            local cur = Functions.cache.getCached(cache, UnitPower, value.unit, point)
            if value.value < 0 then
                local max = Functions.cache.getCached(cache, UnitPowerMax, value.unit, point)
                return Functions.values.compare(value.operator, (max-cur), -value.value)
            else
                return Functions.values.compare(value.operator, cur, value.value)
            end
        else
            return false
        end
    end,]=]
local repaired=[=[    evaluate = function(value, cache)
        local point,reason=addon:GetConditionPointResource(value.unit,cache)
        if point==nil then return nil,reason end
        if point==false then return false end
        local cur,why=Functions.cache.getCached(cache,addon.Platform.GetUnitPointPowerObservation,addon.Platform,value.unit,point,"current")
        if cur==nil then return nil,why end
        if value.value < 0 then
            local maximum,maximumReason=Functions.cache.getCached(cache,addon.Platform.GetUnitPointPowerObservation,addon.Platform,value.unit,point,"maximum")
            if maximum==nil then return nil,maximumReason end
            local deficit=maximum-cur
            if deficit~=deficit or deficit==math.huge or deficit==-math.huge then return nil,"invalid-point-deficit" end
            return Functions.values.compare(value.operator, deficit, -value.value)
        else
            return Functions.values.compare(value.operator, cur, value.value)
        end
    end,]=]
return function(text,callback)
    if callback then
        local before=assert(repaired:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
        local after=assert(original:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
        assert(text==before,'unexpected repaired POINT callback bytes')
        return after
    end
    local first=assert(text:find(repaired,1,true),'exact repaired POINT missing')
    assert(not text:find(repaired,first+1,true),'multiple repaired POINT bodies')
    return text:sub(1,first-1)..original..text:sub(first+#repaired)
end
