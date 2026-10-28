-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict test-only inverse of the single reviewed zone PvP callback repair.
local old = '\n'
    .. [=[        local pvpType = Functions.cache.getCached(cache, GetZonePVPInfo)
        return value.value == pvpType
    ]=]

local repaired = '\n'
    .. [=[        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetZonePVPObservation, addon.Platform)
        if not record then return nil,reason end
        return value.value == record.pvpType
    ]=]

return function(text, callback)
    assert(type(text) == 'string', 'zone PvP inverse needs source text')

    if callback then
        assert(text == repaired, 'unexpected ZONEPVP callback body')
        return old
    end

    local first, last = text:find(repaired, 1, true)
    assert(first and not text:find(repaired, last + 1, true), 'unexpected ZONEPVP repair body/count')
    return text:sub(1, first - 1) .. old .. text:sub(last + 1)
end,
    old,
    repaired
