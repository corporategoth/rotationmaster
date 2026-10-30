-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict test-only inverse of the four remaining item summary prints.
-- Frozen92c8fe8 CARRYING-fixed item module: FunctionSourceHash50f07ef7.
local tags = { 'EQUIPPED', 'ITEM', 'ITEM_RANGE', 'ITEM_COOLDOWN' }

local old = {
    ["EQUIPPED"] = "\n        return string.format(L[\"you {{!have|do not have}} %s equipped\"], Functions.presentation.nullable(get_item_desc(value.item), L[\"<item>\"]))\n    ",
    ["ITEM"] = "\n        return string.format(L[\"%s {{!is|is not}} available\"], Functions.presentation.nullable(get_item_desc(value.item), L[\"<item>\"])) ..\n                (value.notcarrying and L[\", even if you do not currently have one\"] or \"\")\n    ",
    ["ITEM_RANGE"] = "\n        return string.format(L[\"%s {{!is|is not}} in range\"], Functions.presentation.nullable(get_item_desc(value.item), L[\"<item>\"])) ..\n            (value.notcarrying and L[\", even if you do not currently have one\"] or \"\")\n    ",
    ["ITEM_COOLDOWN"] = "\n        return string.format(L[\"the %s\"],\n            Functions.presentation.compareString(value.operator, string.format(L[\"cooldown on %s\"], Functions.presentation.nullable(get_item_desc(value.item), L[\"<item>\"])),\n                                string.format(L[\"%s seconds\"], Functions.presentation.nullable(value.value)))) ..\n                (value.notcarrying and L[\", even if you do not currently have one\"] or \"\")\n    ",
}

local repaired = {
    ["EQUIPPED"] = "\n        return Literal.phrase(L[\"you {{!have|do not have}} {item} equipped\"], {item = Functions.presentation.nullable(get_item_desc(value.item), L[\"<item>\"])})\n    ",
    ["ITEM"] = "\n        return Literal.phrase(L[\"{item} {{!is|is not}} available{carrying}\"], {\n            item = Functions.presentation.nullable(get_item_desc(value.item), L[\"<item>\"]),\n            carrying = value.notcarrying and L[\", even if you do not currently have one\"] or \"\",\n        })\n    ",
    ["ITEM_RANGE"] = "\n        return Literal.phrase(L[\"{item} {{!is|is not}} in range{carrying}\"], {\n            item = Functions.presentation.nullable(get_item_desc(value.item), L[\"<item>\"]),\n            carrying = value.notcarrying and L[\", even if you do not currently have one\"] or \"\",\n        })\n    ",
    ["ITEM_COOLDOWN"] = "\n        if value.slot ~= nil then\n            return Functions.presentation.compareString(value.operator,\n                string.format(L[\"the cooldown on your %s\"], Functions.presentation.nullable(TRINKET_SLOTS[value.slot], L[\"<trinket slot>\"])),\n                string.format(L[\"%s seconds\"], Functions.presentation.nullable(value.value)))\n        end\n        return Summary.phrase(L[\"the cooldown on {item} {comparison} {duration}{carrying}\"], {\n            item = Functions.presentation.nullable(get_item_desc(value.item), L[\"<item>\"]),\n            comparison = Summary.predicate(value.operator, true),\n            duration = string.format(L[\"%s seconds\"], Functions.presentation.nullable(value.value)),\n            carrying = value.notcarrying and L[\", even if you do not currently have one\"] or \"\",\n        })\n    ",
}

local declaration = "local Literal={phrase=addon.Functions.presentation.phrase}\n"
local binding = "    [\"Literal.phrase\"]=\"builtin:Functions/presentation.lua:phrase\",\n"
local added = {}

for _, tag in ipairs({ 'EQUIPPED', 'ITEM', 'ITEM_RANGE' }) do
    added[tag] = { ['Literal.phrase'] = 'builtin:Functions/presentation.lua:phrase' }
end

added.ITEM_COOLDOWN = {
    ['Summary.phrase'] = 'builtin:Functions/presentation.lua:phrase',
    ['Summary.predicate'] = 'builtin:Functions/presentation.lua:predicate',
}

local function replaceOnce(text, from, to, label)
    local a, b = text:find(from, 1, true)
    assert(a and not text:find(from, b + 1, true), 'missing or duplicate ' .. label)
    return text:sub(1, a - 1) .. to .. text:sub(b + 1)
end

local function copy(value)
    if type(value) ~= 'table' then
        return value
    end

    local result = {}

    for key, entry in pairs(value) do
        result[copy(key)] = copy(entry)
    end

    return result
end

local function inverse(value, tag, mode)
    if mode == 'export' then
        assert(
            repaired[tag]
                and type(value) == 'table'
                and value.print == repaired[tag]
                and type(value.bindings) == 'table',
            'unexpected complete item export'
        )

        for key, id in pairs(added[tag]) do
            assert(value.bindings[key] == id, 'unexpected selected summary binding')
        end

        local result = copy(value)
        result.print = old[tag]

        -- The English-key migration changed this help callback after the archived export.
        -- Reconstruct the historical source, including its original locale key, for its frozen hash.
        if tag == 'ITEM_COOLDOWN' then
            result.help = replaceOnce(
                result.help,
                'L["Choose a trinket slot to read whatever is equipped there, so one rotation works for every trinket; the item above is then ignored. An empty slot is false, and a trinket with no on-use effect is unavailable."]',
                'L["Help.Conditions.ITEM_COOLDOWN_SLOT"]',
                'historical trinket help key'
            )
        end

        for key in pairs(added[tag]) do
            result.bindings[key] = nil
        end

        return result
    end

    assert(type(value) == 'string')

    if mode == true then
        assert(repaired[tag] and value == repaired[tag], 'unexpected item print body')
        return old[tag]
    end

    assert(tag == nil, 'whole inverse accepts only the complete module')

    for _, name in ipairs(tags) do
        value = replaceOnce(
            value,
            'print = function(_, value)' .. repaired[name] .. 'end,',
            'print = function(_, value)' .. old[name] .. 'end,',
            name .. ' print'
        )
    end

    value = replaceOnce(value, declaration, '', 'Literal declaration')
    value = replaceOnce(value, binding, '', 'Literal selection')
    local hash = 0

    for i = 1, #value do
        hash = (hash * 33 + value:byte(i)) % 4294967296
    end

    assert(#value == 13656 and string.format('%08x', hash) == '0a325d41', 'unrelated item module delta')
    return value
end

return inverse, old, repaired, added
