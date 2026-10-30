-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Restore exactly the unused capture origin against the post-main3 baseline.
local current = 'local isin, starts_with, isint = addon.Functions.values.isin, addon.Functions.text.starts_with, addon.Functions.values.isint'
local old = 'local isin, starts_with, isint = addon.Functions.values.isin, addon.Functions.text.starts_with, addon.isint'

return function(text, hash)
    assert(type(text) == 'string' and type(hash) == 'function', 'unused main inverse requires source and hash')
    local first, last = text:find(current, 1, true)
    assert(first and not text:find(current, last + 1, true), 'unexpected unused main capture count/body')
    text = text:sub(1, first - 1) .. old .. text:sub(last + 1)
    assert(hash(text) == 'b92a4db5', 'main differs beyond unused capture origin from ad20b47')
    return text
end
