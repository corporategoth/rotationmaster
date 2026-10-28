local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local fallback = 'Condition summary unavailable: invalid template or values.'

local function fixture()
    local f = F.new()

    for _, path in ipairs({
        'Data/plain.lua',
        'Data/tags.lua',
        'Core/conditions.lua',
        'Conditions/spatial_stats.lua',
    }) do
        f.load(path)
    end

    return f, f.addon, f.addon.Functions.presentation
end

local function summary(a, result, negated)
    a:RegisterCondition('TEMPLATE_TEST', { print = function() return result end })

    return a:printCondition(
        negated and { type = 'NOT', value = { type = 'TEMPLATE_TEST' } } or { type = 'TEMPLATE_TEST' },
        0
    )
end

test('named summaries keep scalar values opaque and preserve literal braces percent links and colors', function()
    local _, a, p = fixture()
    assert(type(p.phrase) == 'function', 'named phrase helper missing')
    local literal = '|cff00ff00|Hplayer:Alice|h[Alice 50% {{!x|y}} {unit}]|h|r'

    local phrase = p.phrase('{{{{literal}}}} {name} {{!is|is not}} {n} {zero} {flag}', {
        name = literal,
        n = 12.5,
        zero = 0,
        flag = false,
    })

    assert(summary(a, phrase) == '{{literal}} ' .. literal .. ' is 12.5 0 false')
    assert(summary(a, phrase, true) == '{{literal}} ' .. literal .. ' is not 12.5 0 false')
end)

test('named predicate selection matches primary and qualifier rules under translations and double NOT', function()
    local _, a, p = fixture()
    assert(type(p.predicate) == 'function', 'typed predicate helper missing')

    local phrase = p.phrase('{qualifier} {q} {{is|is not}} {name} {outer} {v}', {
        qualifier = 'health',
        q = p.predicate('LESSTHAN'),
        name = 'you',
        outer = p.predicate('GREATERTHAN', true),
        v = 2,
    })

    assert(summary(a, phrase, true) == 'health is less than is you is not greater than 2')
    local translated = p.phrase('{v} {outer} — {name}', { v = 2, outer = p.predicate('EQUALS', true), name = 'Alice' })
    assert(summary(a, translated, true) == '2 is not equal to — Alice')
    local double = { type = 'NOT', value = { type = 'NOT', value = { type = 'TEMPLATE_TEST' } } }
    assert(a:printCondition(double, 0) == summary(a, translated))
    local unmarked = p.phrase('{first} / {second}', { first = p.predicate('EQUALS'), second = p.predicate('LESSTHAN') })
    assert(summary(a, unmarked, true) == 'is not equal to / is less than')
    assert(summary(a, p.phrase('hello {name}', { name = 'Alice' }), true) == 'not (hello Alice)')
end)

test('all operator predicates retain captured positive map live negative map and unknown fallback', function()
    local _, a, p = fixture()
    assert(type(p.predicate) == 'function', 'typed predicate helper missing')

    for op, positive in pairs(a.operators) do
        local phrase = p.phrase('L {op} R', { op = p.predicate(op, true) })
        assert(summary(a, phrase) == 'L ' .. positive .. ' R')
        assert(summary(a, phrase, true) == 'L ' .. a.negatedOperators[op] .. ' R')
    end

    local original = a.operators
    original.EQUALS = 'same'
    a.operators = { EQUALS = 'foreign' }
    a.negatedOperators = { EQUALS = 'different' }
    assert(summary(a, p.phrase('{op}', { op = p.predicate('EQUALS') }), true) == 'different')

    assert(
        summary(a, p.phrase('{op}', { op = p.predicate('UNKNOWN') }), true)
            == 'not (' .. p.nullable(nil, '<operator>') .. ')'
    )
end)

test('malformed untrusted oversized and missing values produce the same bounded localized fallback', function()
    local f, a, p = fixture()
    assert(type(p.phrase) == 'function', 'named phrase helper missing')
    f.translations[fallback] = 'Résumé indisponible'

    local hostile = setmetatable({}, {
        __index = function()
            error('metamethod executed')
        end,
        __pairs = function()
            error('pairs executed')
        end,
    })

    local cases = {
        p.phrase('{missing}', {}),
        p.phrase('{bad-name}', {}),
        p.phrase('{{!is}}', {}),
        p.phrase('{x}', { x = {} }),
        p.phrase('{x}', hostile),
        p.phrase('{x}', { x = math.huge }),
        p.phrase('}', {}),
        p.phrase(string.rep('x', 64001), {}),
        p.phrase('{x}', { x = string.rep('x', 64001) }),
        {},
        p.predicate('EQUALS'),
    }

    for _, result in ipairs(cases) do
        assert(summary(a, result) == 'Résumé indisponible')
        assert(summary(a, result, true) == 'Résumé indisponible')
    end

    assert(summary(a, p.phrase(string.rep('{x}', 4097), { x = 'a' })) == 'Résumé indisponible')
    assert(summary(a, p.phrase('{x}{x}', { x = string.rep('x', 32001) })) == 'Résumé indisponible')
    assert(#summary(a, p.phrase('{x}', { x = string.rep('x', 64000) })) == 64000)
    local values = { x = 'initial' }
    local phrase = p.phrase('{x}', values)
    values.x = 'changed'
    assert(summary(a, phrase) == 'initial')
    phrase.template = 'forged'
    assert(summary(a, phrase) == 'initial')
end)

test('ordinary custom strings keep legacy phrase behavior and unavailable leaves stay unavailable under NOT', function()
    local _, a = fixture()
    assert(summary(a, 'you {{!are|are not}} here', true) == 'you are not here')

    a:RegisterCondition('UNAVAILABLE_TEMPLATE', {
        print = function()
            error('must not print')
        end,
        disabled = true,
    })

    local result = a:evaluateConditionResult({ type = 'NOT', value = { type = 'UNAVAILABLE_TEMPLATE' } })
    assert(result.status == 'unavailable')
end)

test('new phrase fallback also handles protected value tables and malformed generic negation translations', function()
    local f, a, p = fixture()
    assert(summary(a, p.phrase('{x}', setmetatable({ x = 'bad' }, { __metatable = false }))) == fallback)
    f.translations['not (%s)'] = 'not %d'
    assert(summary(a, p.phrase('hello', {}), true) == fallback)
end)

local tags = {
    'PROXIMITY_HEALTH',
    'PROXIMITY_HEALTH_COUNT',
    'PROXIMITY_HEALTHPCT',
    'PROXIMITY_HEALTHPCT_COUNT',
    'PROXIMITY_MANA',
    'PROXIMITY_MANA_COUNT',
    'PROXIMITY_MANAPCT',
    'PROXIMITY_MANAPCT_COUNT',
}

local function sample(tag)
    return {
        type = tag,
        unit = 'player',
        operation = 'average',
        operator = 'GREATERTHAN',
        value = tag:find('_COUNT', 1, true) and 2 or .5,
        distance = 12.5,
        healthoperator = 'LESSTHAN',
        manaoperator = 'LESSTHAN',
        health = .5,
        mana = .5,
    }
end

test('eight registered summaries preserve fractional and missing distances without format exceptions', function()
    local _, a = fixture()

    for _, tag in ipairs(tags) do
        local node = sample(tag)
        local text = a:printCondition(node, 0)
        assert(text:find('within 12.5 yards', 1, true), tag .. ' rounded distance: ' .. text)
        node.distance = nil
        local ok, missing = pcall(a.printCondition, a, node, 0)
        assert(ok and missing:find('<distance>', 1, true), tag .. ' missing distance failed')
    end
end)

test(
    'spatial counts keep qualifiers positive while opaque translated percent and unit values remain literal',
    function()
        local _, a = fixture()
        a.operators.LESSTHAN = 'is less than 100% of'
        a.units.player = '|Hplayer:A|h[A 50% {{!x|y}}]|h'

        for _, tag in ipairs(tags) do
            local node = sample(tag)
            local positive = a:printCondition(node, 0)
            local negative = a:printCondition({ type = 'NOT', value = node }, 0)
            local double = a:printCondition({ type = 'NOT', value = { type = 'NOT', value = node } }, 0)

            assert(
                double == positive and positive:find(a.units.player, 1, true) and negative:find(
                    a.units.player,
                    1,
                    true
                ),
                tag .. ' data changed'
            )

            assert(negative:find('is not greater than', 1, true), tag .. ' outer negation lost')

            if tag:find('_COUNT', 1, true) then
                assert(
                    negative:find('is less than 100% of', 1, true) and not negative:find('is not less', 1, true),
                    tag .. ' qualifier negated'
                )
            end
        end
    end
)

-- Exact pre-template print source retained to exercise saved bundle compatibility.
local legacyPrint = {
    ["PROXIMITY_HEALTH"] = "\
        local conditionstr = string.format(\
                ((value.value ~= nil and value.value < 0) and\
                        L[\"The %s health defecit of %s members%s within %d yards of %s\"] or\
                        L[\"The %s health of %s members%s within %d yards of %s\"]),\
                Functions.presentation.nullable(value.operation, L[\"<operation>\"]),\
                (value.samegroup and PARTY or L[\"Raid or Party\"]),\
                (value.includepets and \" (\" .. L[\"including pets\"] .. \")\" or \"\"),\
                Functions.presentation.nullable(value.distance, L[\"<distance>\"]),\
                Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]))\
        if value.value ~= nil and value.value < 0 then\
            return Functions.presentation.compareString(value.operator, conditionstr, -value.value)\
        else\
            return Functions.presentation.compareString(value.operator, conditionstr, Functions.presentation.nullable(value.value))\
        end\
    ",
    ["PROXIMITY_HEALTH_COUNT"] = "\
        local conditionstr\
        if value.health ~= nil and value.health < 0 then\
            conditionstr = Functions.presentation.compareString(value.healthoperator, L[\"%s health defecit\"], -value.health)\
        else\
            conditionstr = Functions.presentation.compareString(value.healthoperator, L[\"%s health\"], Functions.presentation.nullable(value.health))\
        end\
        return Functions.presentation.compareString(value.operator,\
                string.format(conditionstr,\
                        string.format(L[\"The number %s members%s within %d yards of %s whose\"],\
                                (value.samegroup and PARTY or L[\"Raid or Party\"]),\
                                (value.includepets and \" (\" .. L[\"including pets\"] .. \")\" or \"\"),\
                                Functions.presentation.nullable(value.distance, L[\"<distance>\"]),\
                                Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]))),\
                Functions.presentation.nullable(value.value),true)\
    ",
    ["PROXIMITY_HEALTHPCT"] = "\
        local v = value.value\
        if v ~= nil then\
            v = v * 100\
        end\
        return Functions.presentation.compareString(value.operator,\
                string.format(\
                        L[\"The %s health percentage of %s members%s within %d yards of %s\"],\
                        Functions.presentation.nullable(value.operation, L[\"<operation>\"]),\
                        (value.samegroup and PARTY or L[\"Raid or Party\"]),\
                        (value.includepets and \" (\" .. L[\"including pets\"] .. \")\" or \"\"),\
                        Functions.presentation.nullable(value.distance, L[\"<distance>\"]),\
                        Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"])),\
                Functions.presentation.nullable(v) .. '%')\
    ",
    ["PROXIMITY_HEALTHPCT_COUNT"] = "\
        local v = value.health\
        if v ~= nil then\
            v = v * 100\
        end\
        return Functions.presentation.compareString(value.operator,\
                Functions.presentation.compareString(value.healthoperator,\
                        string.format(L[\"The number %s members%s within %d yards of %s whose health percentage\"],\
                                (value.samegroup and PARTY or L[\"Raid or Party\"]),\
                                (value.includepets and \" (\" .. L[\"including pets\"] .. \")\" or \"\"),\
                                Functions.presentation.nullable(value.distance, L[\"<distance>\"]),\
                                Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"])),\
                        Functions.presentation.nullable(v) .. \"%\"),\
                Functions.presentation.nullable(value.value),true)\
    ",
    ["PROXIMITY_MANA"] = "\
        local conditionstr = string.format(\
                ((value.value ~= nil and value.value < 0) and\
                        L[\"The %s mana defecit of %s members%s within %d yards of %s\"] or\
                        L[\"The %s mana of %s members%s within %d yards of %s\"]),\
                Functions.presentation.nullable(value.operation, L[\"<operation>\"]),\
                (value.samegroup and PARTY or L[\"Raid or Party\"]),\
                (value.includepets and \" (\" .. L[\"including pets\"] .. \")\" or \"\"),\
                Functions.presentation.nullable(value.distance, L[\"<distance>\"]),\
                Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]))\
        if value.value ~= nil and value.value < 0 then\
            return Functions.presentation.compareString(value.operator, conditionstr, -value.value)\
        else\
            return Functions.presentation.compareString(value.operator, conditionstr, Functions.presentation.nullable(value.value))\
        end\
    ",
    ["PROXIMITY_MANA_COUNT"] = "\
        local conditionstr\
        if value.mana ~= nil and value.mana < 0 then\
            conditionstr = Functions.presentation.compareString(value.manaoperator, L[\"%s mana defecit\"], -value.mana)\
        else\
            conditionstr = Functions.presentation.compareString(value.manaoperator, L[\"%s mana\"], Functions.presentation.nullable(value.mana))\
        end\
        return Functions.presentation.compareString(value.operator,\
                string.format(conditionstr,\
                        string.format(L[\"The number %s members%s within %d yards of %s whose\"],\
                                (value.samegroup and PARTY or L[\"Raid or Party\"]),\
                                (value.includepets and \" (\" .. L[\"including pets\"] .. \")\" or \"\"),\
                                Functions.presentation.nullable(value.distance, L[\"<distance>\"]),\
                                Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]))),\
                Functions.presentation.nullable(value.value),true)\
    ",
    ["PROXIMITY_MANAPCT"] = "\
        local v = value.value\
        if v ~= nil then\
            v = v * 100\
        end\
        return Functions.presentation.compareString(value.operator,\
                string.format(\
                        L[\"The %s mana percentage of %s members%s within %d yards of %s\"],\
                        Functions.presentation.nullable(value.operation, L[\"<operation>\"]),\
                        (value.samegroup and PARTY or L[\"Raid or Party\"]),\
                        (value.includepets and \" (\" .. L[\"including pets\"] .. \")\" or \"\"),\
                        Functions.presentation.nullable(value.distance, L[\"<distance>\"]),\
                        Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"])),\
                Functions.presentation.nullable(v) .. '%')\
    ",
    ["PROXIMITY_MANAPCT_COUNT"] = "\
        local v = value.mana\
        if v ~= nil then\
            v = v * 100\
        end\
        return Functions.presentation.compareString(value.operator,\
                Functions.presentation.compareString(value.manaoperator,\
                        string.format(L[\"The number %s members%s within %d yards of %s whose mana percentage\"],\
                                (value.samegroup and PARTY or L[\"Raid or Party\"]),\
                                (value.includepets and \" (\" .. L[\"including pets\"] .. \")\" or \"\"),\
                                Functions.presentation.nullable(value.distance, L[\"<distance>\"]),\
                                Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"])),\
                        Functions.presentation.nullable(v) .. \"%\"),\
                Functions.presentation.nullable(value.value),true)\
    ",
}

local function sourceFixture()
    local f, a, p = fixture()
    f.env.PARTY = 'Party'

    for _, path in ipairs({
        'Platform/range.lua',
        'Conditions/common.lua',
        'Conditions/spatial.lua',
        'Data/builtin_sources.lua',
        'Core/builtin_sources.lua',
        'Core/custom_authoring.lua',
        'Core/function_data.lua',
    }) do
        f.load(path)
    end

    f.env.loadstring = function(code, name)
        local fn, why = loadstring(code, name)

        if fn then
            setfenv(fn, f.env)
        end

        return fn, why
    end

    return f, a, p
end

local function wrapNode(node, kind)
    if kind == 1 then
        return { type = 'NOT', value = node }
    elseif kind == 2 then
        return { type = 'NOT', value = { type = 'NOT', value = node } }
    end

    return node
end

test('actual extracted compiled public helpers share canonical phrase and predicate authority', function()
    local _, a, p = sourceFixture()

    for _, name in ipairs({ 'phrase', 'predicate' }) do
        local id = 'builtin:Functions/presentation.lua:' .. name
        local builtin = assert(a.builtinFunctions[id], 'generated ' .. name .. ' metadata missing')

        assert(
            builtin.source.namespace == 'Functions.presentation' and a:InstallCustomFunction(
                'COPY_SUMMARY_' .. name,
                a:CopySettingsData(builtin.source)
            )
        )
    end

    local phrase = assert(a:ResolveFunctionBinding('COPY_SUMMARY_phrase'))
    local predicate = assert(a:ResolveFunctionBinding('COPY_SUMMARY_predicate'))

    assert(
        summary(a, phrase('{name} {op}', { name = 'Alice {{!x|y}} 50%', op = predicate('EQUALS', true) }), true)
            == 'Alice {{!x|y}} 50% is not equal to'
    )

    assert(summary(a, p.phrase('{op}', { op = predicate('LESSTHAN') }), true) == 'is not less than')
    assert(summary(a, phrase('{op}', { op = p.predicate('LESSTHAN') }), true) == 'is not less than')
    assert(summary(a, { template = '{op}', values = { op = predicate('LESSTHAN') } }) == fallback)
end)

test(
    'actual extracted eight Built In clones and historical source bundles preserve ordinary summaries and NOT',
    function()
        local f, a = sourceFixture()

        for _, tag in ipairs(tags) do
            local source = assert(a:GetBuiltinConditionSource(tag))
            assert(source.print:find('Functions.presentation.phrase', 1, true), 'stale spatial catalog')
            local copy = assert(a:CompileCustomCondition('COPY_TEMPLATE_' .. tag, source))
            a:RegisterCondition('COPY_TEMPLATE_' .. tag, copy)
            local old = a:CopySettingsData(source)
            old.print = legacyPrint[tag]
            old.bindings['Functions.presentation.phrase'] = nil
            old.bindings['Functions.presentation.predicate'] = nil
            old.bindings['Functions.presentation.compareString'] = 'builtin:utils.lua:compareString'
            local bundle = assert(a:BuildFunctionBundle('condition', 'SAVED_TEMPLATE_' .. tag, old))
            local plan = assert(a:PlanFunctionBundleImport(bundle))
            assert(plan.valid and a:ApplyFunctionBundleImport(plan))

            for _, op in ipairs({ 'LESSTHAN', 'EQUALS', 'GREATERTHAN', 'NOTEQUALS' }) do
                for _, negative in ipairs({ false, true }) do
                    local node = sample(tag)
                    node.distance = 10
                    node.operator = op
                    node.samegroup = true
                    node.includepets = true

                    if negative and not tag:find('PCT', 1, true) then
                        if tag:find('_COUNT', 1, true) then
                            node.health = -.5
                            node.mana = -.5
                        else
                            node.value = -.5
                        end
                    end

                    for kind = 0, 2 do
                        local expected = a:printCondition(wrapNode(node, kind), 0)
                        local cloned = a:CopySettingsData(node)
                        cloned.type = 'COPY_TEMPLATE_' .. tag
                        assert(a:printCondition(wrapNode(cloned, kind), 0) == expected, tag .. ' summary differs')
                        -- A saved pre-template bundle keeps its own (older) wording; it must still
                        -- render, and a double NOT must read like the positive leaf.
                        local saved = a:CopySettingsData(node)
                        saved.type = 'SAVED_TEMPLATE_' .. tag
                        local text = a:printCondition(wrapNode(saved, kind), 0)

                        assert(
                            type(text) == 'string' and text ~= '' and not text:find(fallback, 1, true),
                            tag .. ' saved bundle summary failed'
                        )

                        if kind == 2 then
                            assert(text == a:printCondition(saved, 0), tag .. ' saved bundle double NOT differs')
                        end
                    end
                end
            end

            local pending = sample(tag)
            pending.type = 'COPY_TEMPLATE_' .. tag
            pending.distance = nil
            assert(a:printCondition(pending, 0):find('<distance>', 1, true))
        end

        assert(not f.env.Functions)
    end
)

test(
    'summary migration preserves native runtime results and unavailable negation for fresh and historical clones',
    function()
        local f, a = sourceFixture()
        local e = f.env
        local units = { player = { health = 50, mana = 30 }, party1 = { health = 20, mana = 10 } }
        local missing = false
        e.IsInRaid = function() return false end
        e.IsInGroup = function() return true end
        e.UnitExists = function(unit) return units[unit] ~= nil end
        e.UnitPlayerOrPetInParty = function(unit) return units[unit] ~= nil end
        e.UnitPlayerOrPetInRaid = function() return false end

        e.UnitPosition = function(unit)
            if units[unit] then
                return 0, unit == 'player' and 0 or 5, 0, 1
            end
        end

        e.UnitHealth = function(unit) return not missing and units[unit].health or nil end
        e.UnitHealthMax = function() return 100 end
        e.UnitPower = function(unit) return not missing and units[unit].mana or nil end
        e.UnitPowerMax = function() return 100 end

        for _, tag in ipairs(tags) do
            local source = assert(a:GetBuiltinConditionSource(tag))
            a:RegisterCondition('ENGINE_COPY_' .. tag, assert(a:CompileCustomCondition('ENGINE_COPY_' .. tag, source)))
            source.print = legacyPrint[tag]
            source.bindings['Functions.presentation.phrase'] = nil
            source.bindings['Functions.presentation.predicate'] = nil
            source.bindings['Functions.presentation.compareString'] = 'builtin:utils.lua:compareString'
            a:RegisterCondition('ENGINE_OLD_' .. tag, assert(a:CompileCustomCondition('ENGINE_OLD_' .. tag, source)))

            for _, mode in ipairs({ 'match', 'no-match', 'unavailable' }) do
                missing = mode == 'unavailable'
                local node = sample(tag)
                node.value = 0
                node.operator = mode == 'no-match' and 'LESSTHAN' or 'GREATERTHAN'
                node.healthoperator = 'GREATERTHAN'
                node.manaoperator = 'GREATERTHAN'
                node.health = .1
                node.mana = .1

                for kind = 0, 2 do
                    local baseline = a:evaluateConditionResult(wrapNode(node, kind))

                    if missing then
                        assert(baseline.status == 'unavailable', tag .. ' unavailable became actionable')
                    elseif kind == 0 then
                        assert(baseline.status == mode, tag .. ' runtime vector did not cover ' .. mode)
                    end

                    for _, prefix in ipairs({ 'ENGINE_COPY_', 'ENGINE_OLD_' }) do
                        local copy = a:CopySettingsData(node)
                        copy.type = prefix .. tag
                        local result = a:evaluateConditionResult(wrapNode(copy, kind))

                        assert(
                            result.status == baseline.status and result.reason == baseline.reason,
                            tag .. ' runtime changed'
                        )
                    end
                end
            end
        end
    end
)

test('translated actual spatial templates reorder slots without expanding data or observing native state', function()
    local f, a = sourceFixture()
    local key = 'The {operation} health percentage of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}%'
    f.translations[key] = '{threshold}% {comparison} : {unit} — {distance}m ({operation}; {members}{pets})'
    a.units.player = 'Alice {comparison} {{!x|y}} 50%'
    local source = assert(a:GetBuiltinConditionSource('PROXIMITY_HEALTHPCT'))
    a:RegisterCondition('TRANSLATED_TEMPLATE', assert(a:CompileCustomCondition('TRANSLATED_TEMPLATE', source)))

    f.env.UnitHealth = function()
        error('summary observed native health')
    end

    f.env.UnitPosition = function()
        error('summary observed native position')
    end

    local node = sample('PROXIMITY_HEALTHPCT')
    local positive = '50% is greater than : ' .. a.units.player .. ' — 12.5m (average; Raid or Party)'
    assert(a:printCondition(node, 0) == positive)
    node.type = 'TRANSLATED_TEMPLATE'
    assert(a:printCondition(node, 0) == positive)

    assert(
        a:printCondition({ type = 'NOT', value = node }, 0)
            == '50% is not greater than : ' .. a.units.player .. ' — 12.5m (average; Raid or Party)'
    )
end)

finish()
