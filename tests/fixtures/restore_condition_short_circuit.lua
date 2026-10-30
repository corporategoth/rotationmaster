-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict inverse of the two decisive-prefix exits only. Existing historical
-- whole-module proofs run after this inverse and keep all prior byte assertions.
local changes = {
    {
        current = 'if value.type == "AND" and child.status == "no-match" then matched = false; break end',
        previous = 'if value.type == "AND" and child.status == "no-match" then matched = false end',
    },
    {
        current = 'if value.type == "OR" and child.status == "match" then matched = true; break end',
        previous = 'if value.type == "OR" and child.status == "match" then matched = true end',
    },
}

return function(text, path)
    assert(path == 'Core/conditions.lua', 'unknown condition short-circuit inverse path')

    for _, entry in ipairs(changes) do
        local first, last = text:find(entry.current, 1, true)
        assert(first, 'condition short-circuit block changed')
        assert(not text:find(entry.current, last + 1, true), 'condition short-circuit block repeated')
        text = text:sub(1, first - 1) .. entry.previous .. text:sub(last + 1)
    end

    return text
end
