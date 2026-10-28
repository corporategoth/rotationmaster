-- Strict test-only inverse. Runtime and saved sources never call this.
local original = [[    evaluate = function(value)
        local count = 0
        for _, entity in pairs(addon.unitsInRange) do
            if entity.enemy and entity.threat and entity.threat >= value.threat - 1 then
                count = count + 1
            end
        end
        return Functions.values.compare(value.operator, count, value.value)
    end,]]

local repaired = [[    evaluate = function(value, cache)
        local count,reason=addon:GetConditionThreatCount(value.threat-1,cache)
        if count==nil then return nil,reason end
        return Functions.values.compare(value.operator, count, value.value)
    end,]]

local oldBindings = {
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.collections.deepcopy"] = "builtin:Functions/collections.lua:deepcopy",
    ["Functions.collections.keys"] = "builtin:Functions/collections.lua:keys",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.playerize"] = "builtin:utils.lua:playerize",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["color"] = "builtin:Conditions/combat.lua:color",
    ["helpers"] = "builtin:Conditions/combat.lua:helpers",
}

local oldParameters = { 'value' }
local oldBody = assert(original:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
local newBody = assert(repaired:match('^    evaluate = function%([^\n]*%)(.*)end,$'))

return function(text, callback)
    if callback then
        assert(text == newBody, 'unexpected repaired THREAT_COUNT callback bytes')
        return oldBody, oldBody, newBody, oldBindings, oldParameters
    end

    local first = assert(text:find(repaired, 1, true), 'exact THREAT_COUNT repair missing')
    assert(not text:find(repaired, first + 1, true), 'multiple THREAT_COUNT repairs')

    return text:sub(1, first - 1) .. original .. text:sub(first + #repaired),
        oldBody,
        newBody,
        oldBindings,
        oldParameters
end
