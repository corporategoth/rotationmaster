-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Restore only the3 active main selections, retaining the post-CPU-slash source.
local selections = {
    { 'getCached = addon.Functions.cache.getCached', 'getCached = addon.getCached' },
    { 'addon.Functions.cache.ReportCacheStats(addon)', 'addon:ReportCacheStats()' },
    { 'self.Functions.collections.deepcopy(value)', 'self.deepcopy(value)' },
}

return function(text, hash)
    assert(type(text) == 'string' and type(hash) == 'function', 'main inverse requires source and hash')

    for _, entry in ipairs(selections) do
        local first, last = text:find(entry[1], 1, true)
        assert(first and not text:find(entry[1], last + 1, true), 'unexpected main qualification count/body')
        text = text:sub(1, first - 1) .. entry[2] .. text:sub(last + 1)
    end

    assert(hash(text) == '4e3a4815', 'main differs beyond3 selections from frozen CPU-slash source')
    return text
end
