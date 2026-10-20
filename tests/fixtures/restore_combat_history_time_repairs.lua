-- Strict test-only inverse; no runtime or saved-source rewrite uses this.
local original=[=[    evaluate = function(value, _, evalStart)
        if addon.combatHistory[value.unit] ~= nil then
            for _, entry in pairs(addon.combatHistory[value.unit]) do
                if Functions.values.compare(value.operator, (evalStart - entry.time), value.value) and (value.action == entry.action or
                        (entry.severity ~= nil and value.action == (entry.action .. '_' .. entry.severity))) then
                    return true
                end
            end
        end
        return false
    end,]=]
local repaired=[=[    evaluate = function(value, _, evalStart)
        if addon.combatHistory[value.unit] ~= nil then
            for _, entry in pairs(addon.combatHistory[value.unit]) do
                local compare,operator=Functions.values.compare,value.operator
                if not addon.Platform:CanReadValue(evalStart) then return nil,'restricted-value' end
                if type(evalStart)~='number' or evalStart~=evalStart or evalStart>=math.huge or evalStart<=-math.huge then return nil,'invalid-combat-history-time' end
                if not addon.Platform:CanReadValue(entry) then return nil,'restricted-value' end
                if type(entry)~='table' then return nil,'invalid-combat-history-entry' end
                local timestamp=entry.time
                if not addon.Platform:CanReadValue(timestamp) then return nil,'restricted-value' end
                if type(timestamp)~='number' or timestamp~=timestamp or timestamp>=math.huge or timestamp<=-math.huge then return nil,'invalid-combat-history-time' end
                local elapsed=evalStart-timestamp
                if not addon.Platform:CanReadValue(elapsed) then return nil,'restricted-value' end
                if elapsed~=elapsed or elapsed>=math.huge or elapsed<=-math.huge then return nil,'invalid-combat-history-elapsed' end
                if compare(operator, elapsed, value.value) and (value.action == entry.action or
                        (entry.severity ~= nil and value.action == (entry.action .. '_' .. entry.severity))) then
                    return true
                end
            end
        end
        return false
    end,]=]
local oldBody=assert(original:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
local newBody=assert(repaired:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
local function inverse(text,callback)
    if callback then assert(text==newBody,'unexpected COMBAT_HISTORY_TIME callback bytes');return oldBody end
    local first=assert(text:find(repaired,1,true),'exact COMBAT_HISTORY_TIME repair missing')
    assert(not text:find(repaired,first+1,true),'multiple COMBAT_HISTORY_TIME repairs')
    return text:sub(1,first-1)..original..text:sub(first+#repaired)
end
return inverse,oldBody,newBody
