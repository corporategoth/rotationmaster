-- Test-only inverse for the three exact metadata repairs. Runtime sources and
-- saved-source hashes are never rewritten by this helper.
local original={
    class=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local _, englishClass = Functions.cache.getCached(cache, UnitClass, value.unit)
        return englishClass == value.value
    end,]],
    creature=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return (Functions.cache.getCached(cache, UnitCreatureType, value.unit) == addon.creatures[value.value])
    end,]],
    classification=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return (Functions.cache.getCached(cache, UnitClassification, value.unit) == value.value)
    end,]],
}
return function(text)
    for _,kind in ipairs({'class','creature','classification'}) do
        local repaired='    evaluate = function(value, cache)\n        local observed,reason=Functions.cache.getCached(cache, addon.Platform.GetUnitMetadataObservation, addon.Platform, value.unit, "'..kind..'")\n        if observed==nil then return nil,reason end\n        if observed==false then return false end\n        return observed == '..(kind=='creature' and 'addon.creatures[value.value]' or 'value.value')..'\n    end,'
        local first=assert(text:find(repaired,1,true),'exact repaired '..kind..' body missing')
        assert(not text:find(repaired,first+1,true),'multiple repaired '..kind..' bodies')
        text=text:sub(1,first-1)..original[kind]..text:sub(first+#repaired)
    end
    return text
end
