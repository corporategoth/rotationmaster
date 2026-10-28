-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict test-only inverse; accept only the one reviewed replacement body.
local old = '\n'
    .. [=[        local inInstance, instanceType = Functions.cache.getCached(cache, IsInInstance)
        if value.value == "none" then return not inInstance end
        return inInstance and value.value == instanceType
    ]=]

local repaired = '\n'
    .. [=[        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetInstanceObservation, addon.Platform)
        if not record then return nil,reason end
        if value.value == "none" then return not record.inInstance end
        if not record.inInstance then return false end
        if record.instanceType==nil then return nil,record.instanceTypeReason end
        return value.value == record.instanceType
    ]=]

return function(text)
    assert(type(text) == 'string', 'instance inverse needs source text')
    local start, ending = text:find(repaired, 1, true)
    assert(start and not text:find(repaired, ending + 1, true), 'unexpected INSTANCE repair body/count')
    return text:sub(1, start - 1) .. old .. text:sub(ending + 1)
end,
    old,
    repaired
