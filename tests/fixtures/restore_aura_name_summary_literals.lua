-- Exact additive inverse of six aura print callbacks; baseline5d00bff.
local old = {
    ["BUFF"] = "\n        return string.format(Functions.presentation.playerize(value.unit, L[\"%s {{!have|do not have}} %s\"], L[\"%s {{!has|does not have}} %s\"]),\n                Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n                string.format(value.ownbuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<buff>\"])))\n    ",
    ["BUFF_REMAIN"] = "\n        return string.format(Functions.presentation.playerize(value.unit, L[\"%s {{!have|do not have}} %s where %s\"], L[\"%s {{!have|do not have}} %s where %s\"]),\n            Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n                string.format(value.ownbuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<buff>\"])),\n                Functions.presentation.compareString(value.operator, L[\"the remaining time\"], string.format(L[\"%s seconds\"], Functions.presentation.nullable(value.value))))\n    ",
    ["BUFF_STACKS"] = "\n        return Functions.presentation.nullable(addon.unitsPossessive[value.unit], L[\"<unit>\"]) .. \" \" ..\n                Functions.presentation.compareString(value.operator, string.format(L[\"stacks of %s\"],\n                string.format(value.ownbuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<buff>\"]))),\n                Functions.presentation.nullable(value.value))\n    ",
    ["DEBUFF"] = "\n        return string.format(Functions.presentation.playerize(value.unit, L[\"%s {{!have|do not have}} %s\"], L[\"%s {{!has|does not have}} %s\"]),\n            Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            string.format(value.owndebuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<debuff>\"])))\n    ",
    ["DEBUFF_REMAIN"] = "\n        return string.format(Functions.presentation.playerize(value.unit, L[\"%s {{!have|do not have}} %s where %s\"], L[\"%s {{!have|do not have}} %s where %s\"]),\n            Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            string.format(value.owndebuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<debuff>\"])),\n            Functions.presentation.compareString(value.operator, L[\"the remaining time\"], string.format(L[\"%s seconds\"], Functions.presentation.nullable(value.value))))\n    ",
    ["DEBUFF_STACKS"] = "\n        return Functions.presentation.nullable(addon.unitsPossessive[value.unit], L[\"<unit>\"]) .. \" \" ..\n                Functions.presentation.compareString(value.operator, string.format(L[\"stacks of %s\"],\n                string.format(value.owndebuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<debuff>\"]))),\n                Functions.presentation.nullable(value.value))\n    ",
}

local repaired = {
    ["BUFF"] = "\n        return AuraLiteral.phrase(Functions.presentation.playerize(value.unit, L[\"{unit} {{!have|do not have}} {aura}\"], L[\"{unit} {{!has|does not have}} {aura}\"]), {\n            unit = Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            aura = string.format(value.ownbuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<buff>\"])),\n        })\n    ",
    ["BUFF_REMAIN"] = "\n        return AuraSummary.phrase(Functions.presentation.playerize(value.unit, L[\"{unit} {{!have|do not have}} {aura} where {remaining} {comparison} {duration}\"], L[\"{unit} {{!has|does not have}} {aura} where {remaining} {comparison} {duration}\"]), {\n            unit = Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            aura = string.format(value.ownbuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<buff>\"])),\n            remaining = L[\"the remaining time\"],\n            comparison = AuraSummary.predicate(value.operator),\n            duration = string.format(L[\"%s seconds\"], Functions.presentation.nullable(value.value)),\n        })\n    ",
    ["BUFF_STACKS"] = "\n        return AuraSummary.phrase(L[\"the number of stacks of {aura} on {unit} {comparison} {quantity}\"], {\n            unit = Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            aura = string.format(value.ownbuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<buff>\"])),\n            comparison = AuraSummary.predicate(value.operator, true),\n            quantity = Functions.presentation.nullable(value.value),\n        })\n    ",
    ["DEBUFF"] = "\n        return AuraLiteral.phrase(Functions.presentation.playerize(value.unit, L[\"{unit} {{!have|do not have}} {aura}\"], L[\"{unit} {{!has|does not have}} {aura}\"]), {\n            unit = Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            aura = string.format(value.owndebuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<debuff>\"])),\n        })\n    ",
    ["DEBUFF_REMAIN"] = "\n        return AuraSummary.phrase(Functions.presentation.playerize(value.unit, L[\"{unit} {{!have|do not have}} {aura} where {remaining} {comparison} {duration}\"], L[\"{unit} {{!has|does not have}} {aura} where {remaining} {comparison} {duration}\"]), {\n            unit = Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            aura = string.format(value.owndebuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<debuff>\"])),\n            remaining = L[\"the remaining time\"],\n            comparison = AuraSummary.predicate(value.operator),\n            duration = string.format(L[\"%s seconds\"], Functions.presentation.nullable(value.value)),\n        })\n    ",
    ["DEBUFF_STACKS"] = "\n        return AuraSummary.phrase(L[\"the number of stacks of {aura} on {unit} {comparison} {quantity}\"], {\n            unit = Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            aura = string.format(value.owndebuff and L[\"your own %s\"] or \"%s\", (value.spell and addon:AuraSpellLabel(value) or L[\"<debuff>\"])),\n            comparison = AuraSummary.predicate(value.operator, true),\n            quantity = Functions.presentation.nullable(value.value),\n        })\n    ",
}

local pins = { buffs = { 12019, "b9fea0f1" }, debuffs = { 14478, "d725d7fb" } }
local declaration = 'local AuraLiteral={phrase=addon.Functions.presentation.phrase}\nlocal AuraSummary={phrase=addon.Functions.presentation.phrase,predicate=addon.Functions.presentation.predicate}\n'
local selections = '    ["AuraLiteral.phrase"]="builtin:Functions/presentation.lua:phrase",\n    ["AuraSummary.phrase"]="builtin:Functions/presentation.lua:phrase",\n    ["AuraSummary.predicate"]="builtin:Functions/presentation.lua:predicate",\n'

local function once(s, from, to, label)
    local first, last = s:find(from, 1, true)
    assert(first and not s:find(from, last + 1, true), 'missing or duplicate ' .. label)
    return s:sub(1, first - 1) .. to .. s:sub(last + 1)
end

local function copy(v)
    if type(v) ~= 'table' then
        return v
    end

    local t = {}

    for k, x in pairs(v) do
        t[copy(k)] = copy(x)
    end

    return t
end

-- Compose only the six aura print repairs on an already detached catalog.
local catalogLines = {
    ["BUFF"] = { evaluate = 32, help = 71, print = 35, valid = 29, widget = 40 },
    ["BUFF_REMAIN"] = { evaluate = 91, help = 129, print = 94, valid = 86, widget = 100 },
    ["BUFF_STACKS"] = { evaluate = 152, help = 190, print = 155, valid = 147, widget = 161 },
    ["DEBUFF"] = { evaluate = 30, help = 63, print = 33, valid = 27, widget = 38 },
    ["DEBUFF_REMAIN"] = { evaluate = 83, help = 121, print = 86, valid = 78, widget = 92 },
    ["DEBUFF_STACKS"] = { evaluate = 144, help = 182, print = 147, valid = 139, widget = 153 },
    ["DISPELLABLE"] = { evaluate = 204, help = 254, print = 207, valid = 200, widget = 213 },
    ["STEALABLE"] = { evaluate = 211, help = 226, print = 214, valid = 208, widget = 217 },
}

local catalogOwners = {
    ["Conditions/buffs.lua"] = {
        "c03fa7679babdf5f69f583cab5cfd7f26fa9988c883a8a8d346695f33bd1ca1b",
        "f033c39921e8bff5a466af58fc29da2b4c2eb6bec550ff7dd117279f3118b47d",
    },
    ["Conditions/debuffs.lua"] = {
        "6f1d3760e302d9cc5c85e53c31e1a08361c2e644b38bde334e5133ae9a544b4d",
        "004f698ad080b58cd75af16f154b3e450f800c4ca4ae9607a3357ea846737b75",
    },
}

local function lineCount(s)
    local _, n = s:gsub('\n', '')
    return n
end

local function catalogInverse(value)
    for path, hashes in pairs(catalogOwners) do
        assert(value.modules[path].hash == hashes[2], 'unexpected current aura catalog owner')

        for tag, positions in pairs(catalogLines) do
            local record = value.conditions[tag]

            if record.module == path then
                for name, line in pairs(positions) do
                    local shift = 5

                    for selected, body in pairs(repaired) do
                        if value.conditions[selected].module == path and catalogLines[selected].print < line then
                            shift = shift + lineCount(body) - lineCount(old[selected])
                        end
                    end

                    assert(record.callbacks[name].line == line + shift, 'unexpected aura callback location')
                    record.callbacks[name].line = line
                end
            end
        end

        value.modules[path].hash = hashes[1]
    end

    for tag, body in pairs(repaired) do
        local row = value.conditions[tag].callbacks.print
        assert(row.code == body, 'unexpected current aura catalog print')
        row.code = old[tag]
        local present = tag == 'BUFF' or tag == 'DEBUFF'
        local phrase = present and 'AuraLiteral.phrase' or 'AuraSummary.phrase'
        assert(row.bindings[phrase] == 'builtin:Functions/presentation.lua:phrase')
        row.bindings[phrase] = nil

        if not present then
            assert(row.bindings['AuraSummary.predicate'] == 'builtin:Functions/presentation.lua:predicate')
            row.bindings['AuraSummary.predicate'] = nil
        end
    end

    return value
end

local function inverse(value, tag, mode)
    if mode == 'catalog' then
        return catalogInverse(value)
    end

    if mode == 'export' then
        assert(
            old[tag] and type(value) == 'table' and value.print == repaired[tag] and type(value.bindings) == 'table',
            'unexpected complete aura export'
        )

        local predicate = tag:find('_', 1, true) ~= nil

        assert(
            value.bindings[predicate and 'AuraSummary.phrase' or 'AuraLiteral.phrase']
                == 'builtin:Functions/presentation.lua:phrase',
            'unexpected phrase selection'
        )

        assert(
            value.bindings[predicate and 'AuraLiteral.phrase' or 'AuraSummary.phrase'] == nil,
            'unused phrase root captured'
        )

        assert(
            value.bindings['AuraSummary.predicate']
                == (predicate and 'builtin:Functions/presentation.lua:predicate' or nil),
            'unexpected predicate selection'
        )

        local t = copy(value)
        t.print = old[tag]
        t.bindings['AuraLiteral.phrase'] = nil
        t.bindings['AuraSummary.phrase'] = nil
        t.bindings['AuraSummary.predicate'] = nil
        return t
    end

    assert(type(value) == 'string')

    if mode == true then
        assert(old[tag] and value == repaired[tag], 'unexpected complete aura print')
        return old[tag]
    end

    assert(mode == nil and pins[tag], 'expected complete aura module kind')

    local tags = tag == 'buffs' and { 'BUFF', 'BUFF_REMAIN', 'BUFF_STACKS' } or {
        'DEBUFF',
        'DEBUFF_REMAIN',
        'DEBUFF_STACKS',
    }

    for _, name in ipairs(tags) do
        value = once(
            value,
            'print = function(_, value)' .. repaired[name] .. 'end,',
            'print = function(_, value)' .. old[name] .. 'end,',
            name .. ' print'
        )
    end

    value = once(value, declaration, '', 'AuraSummary declaration')
    value = once(value, selections, '', 'AuraSummary selected leaves')
    local hash = 0

    for i = 1, #value do
        hash = (hash * 33 + value:byte(i)) % 4294967296
    end

    assert(
        #value == pins[tag][1] and string.format('%08x', hash) == pins[tag][2],
        'unrelated complete ' .. tag .. ' module delta'
    )

    return value
end

return inverse, old, repaired
