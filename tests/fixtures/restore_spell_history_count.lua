-- Strict inverses of the two count-history evaluators from b135a21.
local old = {
    SPELL_HISTORY = '\n'
        .. [=[
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        for idx, entry in pairs(addon.spellHistory) do
            return entry.spell == spellid and Functions.values.compare(value.operator, idx, value.value)
        end
        return false
    ]=],
    PETSPELL_HISTORY = '\n'
        .. [=[
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        for idx, entry in pairs(addon.spellHistory) do
            return entry.spell == spellid and Functions.values.compare(value.operator, idx, value.value)
        end
        return false
    ]=],
}

local repaired = {
    SPELL_HISTORY = '\n'
        .. [=[
        local spellid, reason = addon:Widget_GetSpellId(value.spell, value.ranked)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        for idx, entry in pairs(addon.spellHistory) do
            local matches = entry.spell == spellid and Functions.values.compare(value.operator, idx, value.value)
            if matches ~= false then return matches end
        end
        return false
    ]=],
    PETSPELL_HISTORY = '\n'
        .. [=[
        local spellid, reason = addon:Widget_GetSpellId(value.spell, false)
        if not spellid then return nil, reason or "spell-data-unavailable" end
        local known, knownReason = Functions.cache.getCached(cache, addon.Platform.IsSpellKnown, addon.Platform, spellid, true)
        if known == nil then return nil, knownReason end
        if not known then return false end
        for idx, entry in pairs(addon.spellHistory) do
            local matches = entry.spell == spellid and Functions.values.compare(value.operator, idx, value.value)
            if matches ~= false then return matches end
        end
        return false
    ]=],
}

local signatures = {
    SPELL_HISTORY = 'evaluate = function(value)',
    PETSPELL_HISTORY = 'evaluate = function(value, cache)',
}

local paths = { ['Conditions/spell.lua'] = 'SPELL_HISTORY', ['Conditions/petspell.lua'] = 'PETSPELL_HISTORY' }

local function inverse(text, tag, callback)
    assert(type(text) == 'string', 'spell count inverse requires text')
    tag = paths[tag] or tag

    if callback then
        assert(repaired[tag] and text == repaired[tag], 'unexpected spell count evaluate body')
        return old[tag]
    end

    if not tag then
        for name, body in pairs(repaired) do
            if text:find(signatures[name] .. body .. 'end,', 1, true) then
                assert(not tag, 'ambiguous count module')
                tag = name
            end
        end
    end

    assert(repaired[tag], 'unknown or missing count module')
    local from, to = signatures[tag] .. repaired[tag] .. 'end,', signatures[tag] .. old[tag] .. 'end,'
    local first, last = text:find(from, 1, true)
    assert(first and not text:find(from, last + 1, true), 'missing or duplicate spell count evaluate')
    return text:sub(1, first - 1) .. to .. text:sub(last + 1)
end

return inverse, old, repaired
