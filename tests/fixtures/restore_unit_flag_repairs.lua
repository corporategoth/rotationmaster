-- In-memory inverse for historical byte proofs only. Each approved flag
-- evaluator must occur exactly once; no product file is written or relaxed.
return function(source)
    for _,entry in ipairs({{'combat','UnitAffectingCombat, value.unit'},{'enemy','UnitIsEnemy, "player", value.unit'}}) do
        local repaired='\n        return Functions.cache.getCached(cache, addon.Platform.GetUnitFlagObservation, addon.Platform, value.unit, "'..entry[1]..'")\n    '
        local original='\n        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end\n        return Functions.cache.getCached(cache, '..entry[2]..')\n    '
        local start=assert(source:find(repaired,1,true),'approved '..entry[1]..' flag repair missing')
        assert(not source:find(repaired,start+1,true),'flag repair occurs more than once: '..entry[1])
        source=source:sub(1,start-1)..original..source:sub(start+#repaired)
    end
    return source
end
