-- Exact test-only inverse for pet readiness. No runtime source or stored hash
-- is rewritten; unknown or repeated replacement bodies fail the proof.
local original={
    PET=[[    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, UnitExists, "pet")
    end,]],
    PET_NAME=[[    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, GetUnitName, "pet") == value.value
    end,]],
}
local repaired={
    PET=[[    evaluate = function(_, cache)
        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetPetObservation, addon.Platform, false)
        if not record then return nil,reason end
        return record.exists
    end,]],
    PET_NAME=[[    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetPetObservation, addon.Platform, true)
        if not record then return nil,reason end
        if not record.exists then return false end
        return record.name == value.value
    end,]],
}
return function(text,tag)
    if tag then
        assert(tag=='PET' or tag=='PET_NAME','invalid pet repair tag')
        local before=assert(repaired[tag]:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
        local after=assert(original[tag]:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
        assert(text==before,'unexpected repaired '..tag..' callback bytes')
        return after
    end
    for _,name in ipairs({'PET','PET_NAME'}) do
        local first=assert(text:find(repaired[name],1,true),'exact repaired '..name..' missing')
        assert(not text:find(repaired[name],first+1,true),'multiple repaired '..name..' bodies')
        text=text:sub(1,first-1)..original[name]..text:sub(first+#repaired[name])
    end
    return text
end
