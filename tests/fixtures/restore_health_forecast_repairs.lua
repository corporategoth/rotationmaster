-- Strict test-only inverse: exactly two approved TT evaluator bodies from ad20b47.
local original, repaired = {}, {}

original["TT_HEALTH"] = [=[    evaluate = function(value, cache)
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
                local trend, seconds = addon.Functions.trends.calculate(addon.damageHistory[target], nil, value.mode == "noheals", value.mode == "nodmg")
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

repaired["TT_HEALTH"] = [=[    evaluate = function(value, cache)
        local eta,reason=addon:GetConditionHealthForecast(value.unit,value.health,false,value.mode,cache)
        if not addon.Platform:CanReadValue(eta) then return nil,'restricted-value' end
        if eta==nil then return nil,reason end
        if eta==false then return false end
        if type(eta)~='number' or eta~=eta or eta>=math.huge or eta<=-math.huge then return nil,'invalid-health-forecast-eta' end
        local threshold=value.value
        if not addon.Platform:CanReadValue(threshold) then return nil,'restricted-value' end
        if type(threshold)~='number' or threshold~=threshold or threshold>=math.huge or threshold<=-math.huge then return nil,'invalid-health-forecast-threshold' end
        return Functions.values.compare(value.operator,eta,threshold)
    end,]=]

original["TT_HEALTHPCT"] = [=[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local target = Functions.cache.getCached(cache, UnitGUID, value.unit)
        if target then
            local health, maxhealth
            if RealMobHealth then
                health, maxhealth = RealMobHealth.GetUnitHealth(value.unit)
            end
            if not health then
                health = Functions.cache.getCached(cache, UnitHealth, value.unit)
            end
            if not maxhealth then
                maxhealth = Functions.cache.getCached(cache, UnitHealthMax, value.unit)
            end

            local target_health = (maxhealth * value.health)
            if health == target_health then
                return Functions.values.compare(value.operator, 0, value.value)
            elseif addon.damageHistory[target] then
                local trend, seconds = addon.Functions.trends.calculate(addon.damageHistory[target], nil, value.mode == "noheals", value.mode == "nodmg")
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

repaired["TT_HEALTHPCT"] = [=[    evaluate = function(value, cache)
        local eta,reason=addon:GetConditionHealthForecast(value.unit,value.health,true,value.mode,cache)
        if not addon.Platform:CanReadValue(eta) then return nil,'restricted-value' end
        if eta==nil then return nil,reason end
        if eta==false then return false end
        if type(eta)~='number' or eta~=eta or eta>=math.huge or eta<=-math.huge then return nil,'invalid-health-forecast-eta' end
        local threshold=value.value
        if not addon.Platform:CanReadValue(threshold) then return nil,'restricted-value' end
        if type(threshold)~='number' or threshold~=threshold or threshold>=math.huge or threshold<=-math.huge then return nil,'invalid-health-forecast-threshold' end
        return Functions.values.compare(value.operator,eta,threshold)
    end,]=]

local oldBodies, newBodies = {}, {}
local order = { 'TT_HEALTH', 'TT_HEALTHPCT' }

for _, tag in ipairs(order) do
    oldBodies[tag] = assert(original[tag]:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
    newBodies[tag] = assert(repaired[tag]:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
end

local oldBindings = {
    ["TT_HEALTH"] = {
        ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
        ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
        ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
        ["Functions.values.compare"] = "builtin:utils.lua:compare",
        ["Functions.values.isin"] = "builtin:utils.lua:isin",
        ["color"] = "builtin:Conditions/stats.lua:color",
        ["helpers"] = "builtin:Conditions/stats.lua:helpers",
    },
    ["TT_HEALTHPCT"] = {
        ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
        ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
        ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
        ["Functions.values.compare"] = "builtin:utils.lua:compare",
        ["Functions.values.isin"] = "builtin:utils.lua:isin",
        ["color"] = "builtin:Conditions/stats.lua:color",
        ["helpers"] = "builtin:Conditions/stats.lua:helpers",
    },
}

return function(text, tag, callback)
    assert(type(text) == 'string', 'expected forecast source')

    if callback then
        assert(newBodies[tag] and text == newBodies[tag], 'unexpected forecast callback body/tag')
        return oldBodies[tag]
    end

    assert(tag == nil or repaired[tag], 'unexpected forecast tag')

    for _, selected in ipairs(tag and { tag } or order) do
        local first, last = text:find(repaired[selected], 1, true)
        assert(first and not text:find(repaired[selected], last + 1, true), 'unexpected forecast evaluator count/body')
        text = text:sub(1, first - 1) .. original[selected] .. text:sub(last + 1)
    end

    return text
end,
    oldBodies,
    newBodies,
    oldBindings
