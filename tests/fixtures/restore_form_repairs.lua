-- Exact test-only inverse for the one FORM evaluator; no runtime aliases.
local original=[=[    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, GetShapeshiftForm) == value.value
    end,]=]
local repaired=[=[    evaluate = function(value, cache)
        local form,reason=Functions.cache.getCached(cache, addon.Platform.GetPlayerFormObservation, addon.Platform)
        if form==nil then return nil,reason end
        return form == value.value
    end,]=]
return function(text,tag)
    if tag then
        assert(tag=='FORM','invalid form repair tag')
        local before=assert(repaired:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
        local after=assert(original:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
        assert(text==before,'unexpected repaired FORM callback bytes')
        return after
    end
    local first=assert(text:find(repaired,1,true),'exact repaired FORM missing')
    assert(not text:find(repaired,first+1,true),'multiple repaired FORM bodies')
    return text:sub(1,first-1)..original..text:sub(first+#repaired)
end
