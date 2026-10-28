-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Exact inverse of only TIME_IN_COMBAT.evaluate from checkpoint087a686.
local original = [=[    evaluate = function(value, _, evalStart)
        if addon.combatStart ~= nil then
            return Functions.values.compare(value.operator, (evalStart - addon.combatStart), value.value)
        end
        return false
    end,]=]

local repaired = [=[    evaluate = function(value, _, evalStart)
        local start=addon.combatStart
        if not addon.Platform:CanReadValue(start) then return nil,'restricted-value' end
        if start==nil then return false end
        if type(start)~='number' or start~=start or start>=math.huge or start<=-math.huge then return nil,'invalid-combat-start' end
        if not addon.Platform:CanReadValue(evalStart) then return nil,'restricted-value' end
        if type(evalStart)~='number' or evalStart~=evalStart or evalStart>=math.huge or evalStart<=-math.huge then return nil,'invalid-combat-time' end
        local elapsed=evalStart-start
        if not addon.Platform:CanReadValue(elapsed) then return nil,'restricted-value' end
        if elapsed~=elapsed or elapsed>=math.huge or elapsed<=-math.huge then return nil,'invalid-combat-elapsed' end
        return Functions.values.compare(value.operator,elapsed,value.value)
    end,]=]

local oldBody = assert(original:match('^    evaluate = function%b()(.*)end,$'))
local newBody = assert(repaired:match('^    evaluate = function%b()(.*)end,$'))

return function(text, body)
    assert(type(text) == 'string', 'expected combat time source')

    if body then
        assert(text == newBody, 'unexpected TIME_IN_COMBAT evaluate bytes')
        return oldBody
    end

    local first, last = text:find(repaired, 1, true)
    assert(first and not text:find(repaired, last + 1, true), 'unexpected TIME_IN_COMBAT repair count/bytes')
    return text:sub(1, first - 1) .. original .. text:sub(last + 1)
end,
    oldBody,
    newBody
