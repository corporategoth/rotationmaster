local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local inverse, old, repaired, added = dofile('tests/fixtures/restore_ecs_summary_literals.lua')
local literal = 'Scout {{!USER|OTHER}} 50% {comparison}'
local specs = { { 'ECS_STAT', 'MeleeAttackPower', 42, 'Melee' }, { 'ECS_STAT_PCT', 'SpellHasteBonus', .25, 'Spell' } }
local keys = { ECS_STAT = '{stat} {comparison} {value}', ECS_STAT_PCT = '{stat} {comparison} {value}%' }
local archivedHashes = { ECS_STAT = '07e386bd', ECS_STAT_PCT = 'e39dded1' }

local function fixture(label, rootLabel)
    local f = F.new()
    local a, e = f.addon, f.env
    local s = { calls = 0, imports = 0, power = 42, percent = '25%' }

    local data = {
        GetStatInfo = function(...)
            assert(select('#', ...) == 1, 'GetStatInfo received implicit self')
            s.calls = s.calls + 1

            if s.fail then
                error('controlled ECS provider failure')
            end

            local stat = ...

            if stat == 'MeleeAttackPower' then
                return s.power
            elseif stat == 'SpellHasteBonus' then
                return s.percent
            end
        end,
    }

    e.ECSLoader = {
        ImportModule = function(self, name)
            assert(self == e.ECSLoader and name == 'Data')
            s.imports = s.imports + 1
            return data
        end,
    }

    e.ExtendedCharacterStats = {
        profile = {
            melee = {
                refName = 'MeleeHeader',
                text = rootLabel or 'Melee',
                power = { refName = 'MeleeAttackPower', text = label or 'Attack Power' },
            },
            spell = {
                refName = 'SpellHeader',
                text = rootLabel or 'Spell',
                haste = { refName = 'SpellHasteBonus', text = label or 'Haste Bonus' },
            },
        },
    }

    a.delayed_condition = {}

    for _, path in ipairs({
        'Diagnostics/errors.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua', 'Conditions/common.lua', 'Conditions/ext_stats.lua', 'Data/builtin_sources.lua',
        'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
    }) do
        f.load(path)
    end

    for tag, definition in pairs(a.delayed_condition.ExtendedCharacterStats) do
        a:RegisterCondition(tag, definition)
    end

    e.loadstring = function(text, name)
        local fn, why = loadstring(text, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    return f, a, s, e.ExtendedCharacterStats.profile
end

local function node(spec, tag, operator, value)
    return {
        type = tag or spec[1],
        stat = spec[2],
        operator = operator or 'EQUALS',
        value = value == nil and spec[3] or value,
    }
end

local function render(a, v)
    return a:printCondition(v, 0), a:printCondition({ type = 'NOT', value = v }, 0), a:printCondition({
        type = 'NOT',
        value = { type = 'NOT', value = v },
    }, 0)
end

local function register(a, tag, source)
    a:RegisterCondition(tag, assert(a:CompileCustomCondition(tag, source)))
end

local function archive(a, tag)
    local source = assert(a:GetBuiltinConditionSource(tag))

    if source.print == old[tag] then
        return a:CopySettingsData(source)
    end

    return inverse(source, tag, 'export')
end

test('both builtin and editable summaries preserve accepted provider labels through NOT and double NOT', function()
    for _, label in ipairs({
        literal,
        '{{a|b}} {{!one|two}}',
        '100% %s {stat}',
        '|cff123456{{!Hot|Cold}}|r',
        '|Hspell:403|h[{{!A|B}}]|h',
        '',
    }) do
        local _, a = fixture(label)

        for _, spec in ipairs(specs) do
            register(a, 'COPY_' .. spec[1], a:GetBuiltinConditionSource(spec[1]))

            for _, tag in ipairs({ spec[1], 'COPY_' .. spec[1] }) do
                local v = node(spec, tag)
                assert(a:validateCondition(v, 0))
                local p, n, d = render(a, v)

                assert(
                    p:find(label, 1, true) and n:find(label, 1, true) and d == p,
                    'provider label was reparsed: ' .. p .. ' / ' .. n
                )

                assert(
                    p:find(' is equal to ', 1, true) and n:find(' is not equal to ', 1, true),
                    'wrong comparison negated'
                )
            end
        end
    end
end)

test('parent and leaf profile labels remain opaque as one complete stat subject', function()
    local parent = 'Group {{!A|B}} 100%'
    local leaf = 'Leaf {{yes|no}} {value}'
    local _, a = fixture(leaf, parent)

    for _, spec in ipairs(specs) do
        register(a, 'COPY_' .. spec[1], a:GetBuiltinConditionSource(spec[1]))

        for _, tag in ipairs({ spec[1], 'COPY_' .. spec[1] }) do
            local p, n = render(a, node(spec, tag))

            assert(
                p:find(parent .. ' -> ' .. leaf, 1, true) and n:find(parent .. ' -> ' .. leaf, 1, true) and n:find(
                    ' is not equal to ',
                    1,
                    true
                )
            )
        end
    end
end)

test('all operators keep literal labels and captured positive live negative wording', function()
    local _, a = fixture(literal)

    for _, spec in ipairs(specs) do
        register(a, 'COPY_' .. spec[1], a:GetBuiltinConditionSource(spec[1]))

        for op in pairs(a.operators) do
            local positive = a.operators[op]
            a.operators[op] = 'POS_' .. op
            a.negatedOperators[op] = 'NEG_' .. op

            for _, tag in ipairs({ spec[1], 'COPY_' .. spec[1] }) do
                local p, n = render(a, node(spec, tag, op))

                assert(
                    p:find(literal, 1, true) and n:find(literal, 1, true) and p:find('POS_' .. op, 1, true) and n:find(
                        'NEG_' .. op,
                        1,
                        true
                    )
                )
            end

            a.operators[op] = positive
        end
    end
end)

test('whole translated templates reorder slots without parsing label markers', function()
    local f, a = fixture(literal)

    for _, spec in ipairs(specs) do
        f.translations[keys[spec[1]]] = '{comparison} :: {value} :: {stat} :: 50%'
        register(a, 'COPY_' .. spec[1], a:GetBuiltinConditionSource(spec[1]))

        for _, tag in ipairs({ spec[1], 'COPY_' .. spec[1] }) do
            local p, n = render(a, node(spec, tag))

            assert(
                p:find('is equal to :: ', 1, true) == 1
                    and n:find('is not equal to :: ', 1, true) == 1
                    and p:find(literal, 1, true)
                    and n:find(literal, 1, true)
            )
        end
    end
end)

test('ordinary labels and missing placeholders retain exact archived positive and negative prose', function()
    for _, label in ipairs({ 'Attack Power', 'Haste Bonus', '50% power', '' }) do
        local _, a = fixture(label)

        for _, spec in ipairs(specs) do
            register(a, 'ARCHIVE_' .. spec[1], archive(a, spec[1]))

            for op in pairs(a.operators) do
                if a.operators[op] then
                    for _, missing in ipairs({ false, true }) do
                        local current = node(spec, nil, op)

                        if missing then
                            current.stat = nil
                            current.value = nil
                        end

                        local prior = a:CopySettingsData(current)
                        prior.type = 'ARCHIVE_' .. spec[1]
                        local p, n, d = render(a, current)
                        local x, y, z = render(a, prior)
                        assert(p == x and n == y and d == z, 'ordinary archived wording changed')
                    end
                end
            end
        end
    end
end)

test('current copies expose only two selected summary leaves and archive full sources stay exact', function()
    local _, a = fixture(literal)

    for _, spec in ipairs(specs) do
        local tag = spec[1]
        local source = a:GetBuiltinConditionSource(tag)
        local before = a:CopySettingsData(source)
        assert(source.print == repaired[tag], 'current generated print catalog pending')

        for name, id in pairs(added) do
            assert(source.bindings[name] == id)
        end

        assert(source.bindings.ECSLabels == nil, 'opaque helper table escaped')
        local prior = archive(a, tag)
        assert(a:FunctionSourceHash(prior) == archivedHashes[tag], 'archived complete export hash changed')
        a.db.global.custom_conditions = a.db.global.custom_conditions or {}
        a.db.global.custom_conditions['ARCHIVE_' .. tag] = prior
        register(a, 'ARCHIVE_' .. tag, prior)
        local p, n = render(a, node(spec, 'ARCHIVE_' .. tag))

        assert(
            not p:find(literal, 1, true) and not n:find(literal, 1, true) and n:find('Scout OTHER', 1, true),
            'archived behavior was silently fixed'
        )

        assert(a:SettingsDataEqual(source, before) and a.db.global.custom_conditions['ARCHIVE_' .. tag] == prior)
    end
end)

test('printing adds no provider queries imports or profile value source writes', function()
    local _, a, s, profile = fixture(literal)

    for _, spec in ipairs(specs) do
        register(a, 'COPY_' .. spec[1], a:GetBuiltinConditionSource(spec[1]))
    end

    local before = a:CopySettingsData(profile)
    local calls, imports = s.calls, s.imports

    for _, spec in ipairs(specs) do
        for _, tag in ipairs({ spec[1], 'COPY_' .. spec[1] }) do
            local v = node(spec, tag)
            local copy = a:CopySettingsData(v)
            render(a, v)
            assert(a:SettingsDataEqual(v, copy))
        end
    end

    assert(s.calls == calls and s.imports == imports and imports == 1 and a:SettingsDataEqual(profile, before))
end)

test('provider observations NOT unavailable and actual branch dispatch remain unchanged', function()
    local _, a, s = fixture(literal)

    for _, spec in ipairs(specs) do
        register(a, 'COPY_' .. spec[1], a:GetBuiltinConditionSource(spec[1]))

        for _, tag in ipairs({ spec[1], 'COPY_' .. spec[1] }) do
            local v = node(spec, tag)

            assert(
                a:evaluateConditionResult(v).status == 'match'
                    and a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'no-match'
            )

            local selected

            local body = {
                rotation = {
                    {
                        id = 'gate',
                        type = 'branch',
                        conditions = v,
                        onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                        onFalse = { { id = 'no', type = 'spell', action = 2 } },
                    },
                },
            }

            local result = a:EvaluateRotationSequence(
                body,
                function(n) return a:evaluateConditionResult(n) end,
                function(n)
                    selected = n.id
                    return true
                end
            )

            assert(result.status == 'complete' and selected == 'yes')
            s.fail = true

            assert(
                a:evaluateConditionResult(v).status == 'unavailable'
                    and a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'unavailable'
            )

            s.fail = false
        end
    end
end)

test('oversized accepted provider labels retain match and existing bounded summary fallback', function()
    local _, a = fixture(string.rep('x', 64000))

    for _, spec in ipairs(specs) do
        local v = node(spec)
        assert(a:validateCondition(v, 0) and a:evaluateConditionResult(v).status == 'match')
        local p, n = render(a, v)
        assert(p == 'Condition summary unavailable: invalid template or values.' and n == p)
    end
end)

finish()
