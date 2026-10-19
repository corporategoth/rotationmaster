-- Test-only exact inverse for old byte/hash proofs. No runtime state changes.
return function(source,kinds)
    local apis={stealthed='IsStealthed',control='HasFullControl',outdoors='IsOutdoors'}
    for _,kind in ipairs(kinds) do
        local repaired='        return Functions.cache.getCached(cache, addon.Platform.GetPlayerFlagObservation, addon.Platform, "'..kind..'")'
        local start=assert(source:find(repaired,1,true),'approved player flag repair missing: '..kind)
        assert(not source:find(repaired,start+1,true),'ambiguous player flag repair: '..kind)
        source=source:sub(1,start-1)..'        return Functions.cache.getCached(cache, '..assert(apis[kind])..')'..source:sub(start+#repaired)
    end
    return source
end
