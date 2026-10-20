-- Restore only this allocation change before existing whole-module proofs.
local replacements={
 {current=[[local matchedOutcome,unmatchedOutcome={status="match"},{status="no-match"}
local function outcome(status, reason, path)
    if status=="match" then return matchedOutcome end
    if status=="no-match" then return unmatchedOutcome end
    return {status=status, reason=reason, path=path}
end]],previous=[[local function outcome(status, reason, path)
    return {status=status, reason=reason, path=path}
end]]},
 {current=[[function addon:evaluateConditionResult(value, context)
    local result=evaluate(value, {}, GetTime(), {active={}, count=0, context=context}, 0, "condition")
    if result==matchedOutcome or result==unmatchedOutcome then return {status=result.status} end
    return result
end]],previous=[[function addon:evaluateConditionResult(value, context)
    return evaluate(value, {}, GetTime(), {active={}, count=0, context=context}, 0, "condition")
end]]},
}
return function(text,path)
    assert(path=='Core/conditions.lua','unknown condition outcome inverse path')
    for _,entry in ipairs(replacements) do
        local first,last=text:find(entry.current,1,true)
        assert(first,'condition outcome block changed')
        assert(not text:find(entry.current,last+1,true),'condition outcome block repeated')
        text=text:sub(1,first-1)..entry.previous..text:sub(last+1)
    end
    return text
end
