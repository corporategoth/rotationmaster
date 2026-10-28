-- Strict test-only inverse of the five approved live rounding qualifications.
-- tag selects one module/callback; callback mode accepts the evaluator body.
local arguments = {
    SPELL_COOLDOWN = 'cooldown.startTime + cooldown.duration - evalStart, 3',
    PETSPELL_COOLDOWN = 'cooldown.startTime + cooldown.duration - evalStart, 3',
    ANYSPELL_COOLDOWN = 'cooldown.startTime + cooldown.duration - evalStart, 3',
    RUNE_COOLDOWN = 'duration - (now - start), 3',
    TOTEM_REMAIN = 'seconds,3',
}

return function(source, tag, callback)
    local args = assert(arguments[tag], 'invalid rounding qualifier tag')
    local repaired = 'addon.Functions.values.round(' .. args .. ')'
    local original = 'addon.round(' .. args .. ')'
    local first = assert(source:find(repaired, 1, true), 'exact repaired ' .. tag .. ' rounding expression missing')
    assert(not source:find(repaired, first + 1, true), 'multiple repaired ' .. tag .. ' rounding expressions')

    if callback then
        assert(not source:find('RegisterCondition', 1, true), 'expected callback body')
    end

    return source:sub(1, first - 1) .. original .. source:sub(first + #repaired)
end
