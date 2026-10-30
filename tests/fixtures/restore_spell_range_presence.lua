-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict complete-body and complete-module inverses frozen from5fb3250.
local old = {
    ["SPELL_RANGE"] = "\n        if not Functions.cache.getCached(cache, UnitExists, \"target\") then return false end\n        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)\n        if not spellid then return nil, reason or \"spell-data-unavailable\" end\n        local range, why = Functions.cache.getCached(cache, addon.Platform.GetSpellRangeState, addon.Platform, spellid, \"target\", \"spell\")\n        if not range then return nil, why end\n        return range.applicable and range.inRange or false\n    ",
    ["PETSPELL_RANGE"] = "\n        if not Functions.cache.getCached(cache, UnitExists, \"target\") then return false end\n        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)\n        if not spellid then return nil, reason or \"spell-data-unavailable\" end\n        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)\n        if known == nil then return nil, knownReason end\n        if not known then return false end\n        local range, why = Functions.cache.getCached(cache, addon.Platform.GetSpellRangeState, addon.Platform, spellid, \"target\", \"pet\")\n        if not range then return nil, why end\n        return range.applicable and range.inRange or false\n    ",
    ["ANYSPELL_RANGE"] = "\n        if not Functions.cache.getCached(cache, UnitExists, \"target\") then return false end\n        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)\n        if not spellid then return nil, reason or \"spell-data-unavailable\" end\n        local range, why = Functions.cache.getCached(cache, addon.Platform.GetSpellRangeState, addon.Platform, spellid, \"target\", \"any\")\n        if not range then return nil, why end\n        return range.applicable and range.inRange or false\n    ",
}

local repaired = {
    ["SPELL_RANGE"] = "\n        local exists,presenceReason=Functions.cache.getCached(cache, addon.Platform.GetUnitPresenceObservation, addon.Platform, \"target\")\n        if exists==nil then return nil,presenceReason or 'unit-data-unavailable' end\n        if not exists then return false end\n        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)\n        if not spellid then return nil, reason or \"spell-data-unavailable\" end\n        local range, why = Functions.cache.getCached(cache, addon.Platform.GetSpellRangeState, addon.Platform, spellid, \"target\", \"spell\")\n        if not range then return nil, why end\n        return range.applicable and range.inRange or false\n    ",
    ["PETSPELL_RANGE"] = "\n        local exists,presenceReason=Functions.cache.getCached(cache, addon.Platform.GetUnitPresenceObservation, addon.Platform, \"target\")\n        if exists==nil then return nil,presenceReason or 'unit-data-unavailable' end\n        if not exists then return false end\n        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)\n        if not spellid then return nil, reason or \"spell-data-unavailable\" end\n        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)\n        if known == nil then return nil, knownReason end\n        if not known then return false end\n        local range, why = Functions.cache.getCached(cache, addon.Platform.GetSpellRangeState, addon.Platform, spellid, \"target\", \"pet\")\n        if not range then return nil, why end\n        return range.applicable and range.inRange or false\n    ",
    ["ANYSPELL_RANGE"] = "\n        local exists,presenceReason=Functions.cache.getCached(cache, addon.Platform.GetUnitPresenceObservation, addon.Platform, \"target\")\n        if exists==nil then return nil,presenceReason or 'unit-data-unavailable' end\n        if not exists then return false end\n        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)\n        if not spellid then return nil, reason or \"spell-data-unavailable\" end\n        local range, why = Functions.cache.getCached(cache, addon.Platform.GetSpellRangeState, addon.Platform, spellid, \"target\", \"any\")\n        if not range then return nil, why end\n        return range.applicable and range.inRange or false\n    ",
}

local modules = {
    ["Conditions/spell.lua"] = { tag = "SPELL_RANGE", bytes = 22248, hash = "987f42a5" },
    ["Conditions/petspell.lua"] = { tag = "PETSPELL_RANGE", bytes = 22429, hash = "1ff7b48c" },
    ["Conditions/anyspell.lua"] = { tag = "ANYSPELL_RANGE", bytes = 12888, hash = "118e0ba1" },
}

local function hash(text)
    local n = 5381

    for i = 1, #text do
        n = (n * 33 + text:byte(i)) % 4294967296
    end

    return string.format('%08x', n)
end

local function restore(text, tag, callback)
    assert(type(text) == 'string', 'expected full spell range source')
    local module = modules[tag]

    if module then
        tag = module.tag
    end

    if callback then
        assert(repaired[tag] and text == repaired[tag], 'unexpected complete spell range callback')
        return old[tag]
    end

    if not module then
        for path, record in pairs(modules) do
            if tag == record.tag or text:find(
                'evaluate = function(value, cache)' .. repaired[record.tag] .. 'end,',
                1,
                true
            ) then
                assert(not module, 'ambiguous range module')
                module = record
                tag = record.tag
            end
        end
    end

    assert(module, 'missing or unknown spell range module')

    local before, after =
        'evaluate = function(value, cache)' .. repaired[tag] .. 'end,',
        'evaluate = function(value, cache)' .. old[tag] .. 'end,'

    local first, last = text:find(before, 1, true)
    assert(first and not text:find(before, last + 1, true), 'missing or duplicate complete range evaluator')
    local previous = text:sub(1, first - 1) .. after .. text:sub(last + 1)
    assert(#previous == module.bytes and hash(previous) == module.hash, 'unrelated changes beyond range presence')
    return previous
end

return restore, old, repaired
