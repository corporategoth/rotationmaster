-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict additive inverse of only3 named literal summaries, baseline5d00bff.
local old = {
    ["CASTING_SPELL"] = "\n        return string.format(Functions.presentation.playerize(value.unit, L[\"%s {{!are|are not}} currently casting %s\"], L[\"%s {{!is|is not}} currently casting %s\"]),\n            Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]), Functions.presentation.nullable(value.spell, L[\"<spell>\"]))\n    ",
    ["CHANNELING_SPELL"] = "\n        return string.format(Functions.presentation.playerize(value.unit, L[\"%s {{!are|are not}} currently channeling %s\"], L[\"%s {{!is|is not}} currently casting %s\"]),\n            Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]), Functions.presentation.nullable(value.spell, L[\"<spell>\"]))\n    ",
    ["ZONE"] = "\n        return string.format(L[\"{{!in|not in}} %s\"], Functions.presentation.nullable(value.value, L[\"<zone>\"]))\n    ",
}

local repaired = {
    ["ZONE"] = "\n        return LiteralSummary.phrase(L[\"{{!in|not in}} {zone}\"], {zone = Functions.presentation.nullable(value.value, L[\"<zone>\"])})\n    ",
    ["CASTING_SPELL"] = "\n        return LiteralSummary.phrase(Functions.presentation.playerize(value.unit, L[\"{unit} {{!are|are not}} currently casting {spell}\"], L[\"{unit} {{!is|is not}} currently casting {spell}\"]), {\n            unit = Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            spell = Functions.presentation.nullable(value.spell, L[\"<spell>\"]),\n        })\n    ",
    ["CHANNELING_SPELL"] = "\n        return LiteralSummary.phrase(Functions.presentation.playerize(value.unit, L[\"{unit} {{!are|are not}} currently channeling {spell}\"], L[\"{unit} {{!is|is not}} currently casting {spell}\"]), {\n            unit = Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            spell = Functions.presentation.nullable(value.spell, L[\"<spell>\"]),\n        })\n    ",
}

local paths = {
    ["CASTING_SPELL"] = "Conditions/casting.lua",
    ["CHANNELING_SPELL"] = "Conditions/channeling.lua",
    ["ZONE"] = "Conditions/spatial.lua",
}

local pins = {
    ZONE = { 25217, "e5ce283d" },
    CASTING_SPELL = { 8772, "3d3752c8" },
    CHANNELING_SPELL = { 8850, "c91c2f6c" },
}

local declaration = 'local LiteralSummary={phrase=addon.Functions.presentation.phrase}\n'
local selection = '    ["LiteralSummary.phrase"]="builtin:Functions/presentation.lua:phrase",\n'
local binding = 'builtin:Functions/presentation.lua:phrase'

local function once(text, from, to, label)
    local first, last = text:find(from, 1, true)
    assert(first and not text:find(from, last + 1, true), 'missing or duplicate ' .. label)
    return text:sub(1, first - 1) .. to .. text:sub(last + 1)
end

local function copy(v)
    if type(v) ~= 'table' then
        return v
    end

    local result = {}

    for k, value in pairs(v) do
        result[copy(k)] = copy(value)
    end

    return result
end

local function inverse(value, tag, mode)
    assert(paths[tag], 'unexpected summary tag')

    if tag == 'CHANNELING_SPELL' and mode ~= true then
        value = dofile('tests/fixtures/restore_channeling_summary_wording.lua')(value, tag, mode)
    end

    if mode == 'export' then
        assert(
            type(value) == 'table'
                and value.print == repaired[tag]
                and type(value.bindings) == 'table'
                and value.bindings['LiteralSummary.phrase'] == binding,
            'unexpected complete named summary export'
        )

        local result = copy(value)
        result.print = old[tag]
        result.bindings['LiteralSummary.phrase'] = nil
        return result
    end

    assert(type(value) == 'string')

    if mode == true then
        assert(value == repaired[tag], 'unexpected complete named summary print')
        return old[tag]
    end

    assert(mode == nil, 'unexpected inverse mode')

    value = once(
        value,
        'print = function(_, value)' .. repaired[tag] .. 'end,',
        'print = function(_, value)' .. old[tag] .. 'end,',
        tag .. ' print'
    )

    value = once(value, declaration, '', 'LiteralSummary declaration')
    value = once(value, selection, '', 'LiteralSummary selected leaf')
    local h = 0

    for i = 1, #value do
        h = (h * 33 + value:byte(i)) % 4294967296
    end

    assert(
        #value == pins[tag][1] and string.format('%08x', h) == pins[tag][2],
        'unrelated complete ' .. paths[tag] .. ' delta'
    )

    return value
end

return inverse, old, repaired, paths
