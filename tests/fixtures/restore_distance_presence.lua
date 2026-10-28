-- Strict DISTANCE presence-prefix inverse; complete predecessor7f4dd7c.
local old = [====[        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
]====]

local repaired = [====[        local exists,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitPresenceObservation,addon.Platform,value.unit)
        if exists==nil then return nil,reason or 'unit-data-unavailable' end
        if exists==false then return false end
        if exists~=true then return nil,'invalid-api-result' end
]====]

return function(text, callback)
    assert(type(text) == 'string', 'expected DISTANCE source text')

    if not callback then
        text = dofile('tests/fixtures/restore_zone_cast_summary_literals.lua')(text, 'ZONE')
    end

    local first, last = text:find(repaired, 1, true)
    assert(first and not text:find(repaired, last + 1, true), 'missing or duplicate DISTANCE presence prefix')
    text = text:sub(1, first - 1) .. old .. text:sub(last + 1)

    if not callback then
        local h = 5381

        for i = 1, #text do
            h = (h * 33 + text:byte(i)) % 4294967296
        end

        assert(#text == 24993 and string.format('%08x', h) == '1c419c30', 'unrelated complete spatial source delta')
    end

    return text
end
