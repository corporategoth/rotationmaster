-- Exact inverse for historical byte/hash proofs; never used by runtime code.
return function(source,callback)
    local repaired=[[    evaluate = function(value, cache)
        local observed,reason=Functions.cache.getCached(cache, addon.Platform.GetUnitThreatObservation, addon.Platform, value.unit)
        if observed==nil then return nil,reason end
        if observed==false then return false end
        return observed >= value.threat - 1
    end,]]
    local original=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local enemy = Functions.cache.getCached(cache, UnitIsEnemy, "player", value.unit)
        if enemy then
            local rv = Functions.cache.getCached(cache, UnitThreatSituation, "player", value.unit)
            if rv ~= nil and rv >= value.threat - 1 then
                return true
            else
                return false
            end
        else
            return false
        end
    end,]]
    if callback then
        local before=assert(repaired:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
        local after=assert(original:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
        assert(source==before,'unexpected repaired threat callback bytes')
        return after
    end
    local first=assert(source:find(repaired,1,true),'approved threat repair missing')
    assert(not source:find(repaired,first+1,true),'ambiguous threat repair')
    return source:sub(1,first-1)..original..source:sub(first+#repaired)
end
