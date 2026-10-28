-- Exact inverse of only the authorized STAT evaluator; unrelated ECS stays pinned.
local original = [=[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local cur
        if value.stat <= 5 then
            cur = select(2, Functions.cache.getCached(cache, UnitStat, value.unit, value.stat))
        else
            cur = select(2, Functions.cache.getCached(cache, UnitArmor, value.unit))
        end
        return Functions.values.compare(value.operator, cur, value.value)
    end,]=]

local repaired = [=[    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitStatObservation,addon.Platform,value.unit,value.stat)
        if record==nil then return nil,reason end
        if not record.exists then return false end
        return Functions.values.compare(value.operator,record.value,value.value)
    end,]=]

local oldBody = assert(original:match('^    evaluate = function%b()(.*)end,$'))
local newBody = assert(repaired:match('^    evaluate = function%b()(.*)end,$'))

return function(text, body)
    if body then
        assert(text == newBody, 'unexpected STAT evaluate bytes')
        return oldBody
    end

    local first, last = text:find(repaired, 1, true)
    assert(first and not text:find(repaired, last + 1, true), 'unexpected STAT repair count/bytes')
    return text:sub(1, first - 1) .. original .. text:sub(last + 1)
end,
    oldBody,
    newBody
