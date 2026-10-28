-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Exact test-only inverse for the one approved TT_HEALTH target field guard.
local old = [=[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local target = Functions.cache.getCached(cache, UnitGUID, value.unit)
        if target then
            local health = Functions.cache.getCached(cache, UnitHealth, value.unit)

            local target_health = value.health
            if value.value < 0 then
                local max = Functions.cache.getCached(cache, UnitHealthMax, value.unit)
                target_health = target_health + max
            end
            if health == target_health then
                return Functions.values.compare(value.operator, 0, value.value)
            elseif addon.damageHistory[target] then
                local trend, seconds = addon.calculate_trend(addon.damageHistory[target], nil, value.mode == "noheals", value.mode == "nodmg")
                if trend and seconds > 2 then
                    local ttt = 0 -- Time Til Target
                    if trend < 0 then
                        if target_health < health then
                            ttt = (health - target_health) / -trend
                        end
                    elseif trend > 0 then
                        if target_health > health then
                            ttt = (target_health - health) / trend
                        end
                    end
                    return Functions.values.compare(value.operator, ttt, value.value)
                end
            end
        end
        return false
    end,]=]

local repaired = [=[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local target = Functions.cache.getCached(cache, UnitGUID, value.unit)
        if target then
            local health = Functions.cache.getCached(cache, UnitHealth, value.unit)

            local target_health = value.health
            if value.health < 0 then
                local max = Functions.cache.getCached(cache, UnitHealthMax, value.unit)
                target_health = target_health + max
            end
            if health == target_health then
                return Functions.values.compare(value.operator, 0, value.value)
            elseif addon.damageHistory[target] then
                local trend, seconds = addon.calculate_trend(addon.damageHistory[target], nil, value.mode == "noheals", value.mode == "nodmg")
                if trend and seconds > 2 then
                    local ttt = 0 -- Time Til Target
                    if trend < 0 then
                        if target_health < health then
                            ttt = (health - target_health) / -trend
                        end
                    elseif trend > 0 then
                        if target_health > health then
                            ttt = (target_health - health) / trend
                        end
                    end
                    return Functions.values.compare(value.operator, ttt, value.value)
                end
            end
        end
        return false
    end,]=]

local oldBody = assert(old:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
local repairedBody = assert(repaired:match('^    evaluate = function%([^\n]*%)(.*)end,$'))

return function(text, tag)
    if tag then
        assert(tag == 'TT_HEALTH' and text == repairedBody, 'unexpected TT_HEALTH evaluator body/tag')
        return oldBody
    end

    local first, last = text:find(repaired, 1, true)
    assert(first and not text:find(repaired, last + 1, true), 'unexpected TT_HEALTH evaluator count')
    return text:sub(1, first - 1) .. old .. text:sub(last + 1)
end,
    oldBody,
    repairedBody
