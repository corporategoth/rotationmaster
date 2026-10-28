-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict test-only inverse of exactly GLYPH.print metadata from242faee.
local old = '\n'
    .. [=[
            local link = value.item and select(2, GetItemInfo(value.item)) or nil
            return string.format(L["you {{!have|do not have}} %s glyph"], Functions.presentation.nullable(link, L["<glyph>"]))
        ]=]

local repaired = '\n'
    .. [=[
            local info = value.item and addon.Platform:GetItemDisplayInfo(value.item) or nil
            local link = info and info.link or nil
            return string.format(L["you {{!have|do not have}} %s active"], Functions.presentation.nullable(link, L["<glyph>"]))
        ]=]

local signature = 'print = function(_, value)'

local function inverse(text, callback)
    assert(type(text) == 'string', 'glyph metadata inverse needs text')

    if callback then
        assert(text == repaired, 'unexpected GLYPH print body')
        return old
    end

    local from, to = signature .. repaired .. 'end,', signature .. old .. 'end,'
    local first, last = text:find(from, 1, true)
    assert(first and not text:find(from, last + 1, true), 'unexpected GLYPH print callback count')
    return text:sub(1, first - 1) .. to .. text:sub(last + 1)
end

return inverse, old, repaired
