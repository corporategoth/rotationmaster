-- Strict test-only inverse of exactly two canonical trend consumer expressions.
-- Full module mode restores both entire evaluator blocks once; callback mode
-- requires the exact evaluator body and its tag. No general alias rewriting.
local original = {
    TT_HEALTH = [=[    evaluate = function(value, cache)
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
    end,]=],
    TT_HEALTHPCT = [=[    evaluate = function(value, cache)
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
    end,]=],
}

local repaired, oldBodies, newBodies = {}, {}, {}
local order = { 'TT_HEALTH', 'TT_HEALTHPCT' }

for _, tag in ipairs(order) do
    local block, count = original[tag]:gsub('addon%.calculate_trend%(', 'addon.Functions.trends.calculate(')
    assert(count == 1, 'invalid trend consumer fixture')
    repaired[tag] = block
    oldBodies[tag] = assert(original[tag]:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
    newBodies[tag] = assert(block:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
end

return function(text, tag, callback)
    assert(type(text) == 'string', 'expected trend consumer source')

    if callback then
        assert(newBodies[tag] and text == newBodies[tag], 'unexpected trend evaluator body/tag')
        return oldBodies[tag]
    end

    assert(tag == nil or repaired[tag], 'unexpected trend consumer tag')

    for _, selected in ipairs(tag and { tag } or order) do
        local first, last = text:find(repaired[selected], 1, true)

        assert(
            first and not text:find(repaired[selected], last + 1, true),
            'unexpected ' .. selected .. ' evaluator count/body'
        )

        text = text:sub(1, first - 1) .. original[selected] .. text:sub(last + 1)
    end

    return text
end,
    oldBodies,
    newBodies
