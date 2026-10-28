-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local families = {
    cast = { 'CASTING', 'CASTING_SPELL', 'CASTING_REMAIN', 'CAST_INTERRUPTABLE' },
    channel = { 'CHANNELING', 'CHANNELING_SPELL', 'CHANNELING_REMAIN', 'CHANNEL_INTERRUPTABLE' },
}

local tags = {}

for _, kind in ipairs({ 'cast', 'channel' }) do
    for _, tag in ipairs(families[kind]) do
        tags[#tags + 1] = tag
    end
end

local function fixture(project)
    local f = F.new(project)
    local a, e = f.addon, f.env
    local s = { now = 100, exists = true, name = 'Arcane Missiles', ending = 103000, flag = false, calls = {} }

    local function call(key)
        s.calls[key] = (s.calls[key] or 0) + 1

        if s.throw == key then
            error('native ' .. key .. ' failed')
        end
    end

    e.GetTime = function()
        call('time')
        return s.now
    end

    e.UnitExists = function()
        call('exists')
        return s.exists
    end

    e.UnitCastingInfo = function()
        call('cast')
        return s.name, 'display', 1, 99000, s.ending, false, 'cast-guid', s.flag, 5143
    end

    e.UnitChannelInfo = function()
        call('channel')
        return s.name, 'display', 1, 99000, s.ending, false, s.flag, 5143, false, 0
    end

    for _, file in ipairs({
        'Platform/casting.lua', 'Diagnostics/errors.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua',
        'Data/rotation_tree.lua', 'Core/rotation_sequence.lua', 'Conditions/casting.lua', 'Conditions/channeling.lua',
        'Data/builtin_sources.lua', 'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
    }) do
        f.load(file)
    end

    e.loadstring = function(code, name)
        local fn, why = loadstring(code, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    return f, a, s
end

local function node(tag)
    return { type = tag, unit = 'target', spell = 'Arcane Missiles', operator = 'EQUALS', value = 3 }
end

local owners = {
    isin = 'values',
    compare = 'values',
    nullable = 'presentation',
    compareString = 'presentation',
    playerize = 'presentation',
    getCached = 'cache',
    deepcopy = 'collections',
}

local function identity(name)
    return 'builtin:' .. (name == 'deepcopy' and 'Functions/collections.lua' or 'utils.lua') .. ':' .. name
end

local function path(name)
    return 'Functions.' .. owners[name] .. '.' .. name
end

local function copies(a)
    local canonical, legacy = {}, {}

    for _, tag in ipairs(tags) do
        local source = assert(a:GetBuiltinConditionSource(tag))
        canonical[tag] = assert(a:CompileCustomCondition('COPY_' .. tag, source))
        a:RegisterCondition('COPY_' .. tag, canonical[tag])
        local old = a:CopySettingsData(source)

        for _, callback in ipairs({ 'valid', 'evaluate', 'print', 'widget', 'help' }) do
            if old[callback] then
                for name in pairs(owners) do
                    old[callback] = old[callback]:gsub(path(name):gsub('%.', '%%.') .. '%(', 'addon.' .. name .. '(')
                end
            end
        end

        legacy[tag] = assert(a:CompileCustomCondition('LEGACY_' .. tag, old))
        a:RegisterCondition('LEGACY_' .. tag, legacy[tag])
    end

    return canonical, legacy
end

local function checkUnknown(a, node)
    assert(a:evaluateConditionResult(node).status == 'unavailable')
    assert(a:evaluateConditionResult({ type = 'NOT', value = node }).status == 'unavailable')

    local body = {
        rotation = {
            {
                id = 'guard',
                type = 'branch',
                conditions = node,
                onTrue = { { id = 'yes', type = 'spell', action = 5143 } },
                onFalse = { { id = 'no', type = 'spell', action = 5143 } },
            },
        },
    }

    assert(
        a:EvaluateRotationSequence(body, function(v) return a:evaluateConditionResult(v) end, function()
            error('unknown cast selected an action')
        end).status == 'unavailable'
    )
end

test('cast families qualify exactly forty calls using seven existing owning leaves per module', function()
    local f, a = fixture()

    local wanted = {
        isin = 5,
        compare = 1,
        nullable = 6,
        compareString = 1,
        playerize = 2,
        getCached = 4,
        deepcopy = 1,
    }

    for kind, module in pairs({ cast = 'casting', channel = 'channeling' }) do
        local manifest = assert(
            a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/' .. module .. '.lua'],
            'casting canonical metadata missing'
        )

        local leaves = 0
        manifest = a:CopySettingsData(manifest)
        assert(manifest['LiteralSummary.phrase'] == 'builtin:Functions/presentation.lua:phrase')
        manifest['LiteralSummary.phrase'] = nil

        for alias, id in pairs(manifest) do
            leaves = leaves + 1
            local name = alias:match('([%w_]+)$')

            assert(
                alias == path(name)
                    and id == identity(name)
                    and a:ResolveFunctionBinding(id) == a.Functions[owners[name]][name]
            )
        end

        assert(leaves == 7)
        local totals = {}

        for _, tag in ipairs(families[kind]) do
            local source = assert(a:GetBuiltinConditionSource(tag))
            assert(not source.bindings.Functions)

            for _, callback in ipairs({ 'valid', 'evaluate', 'print', 'widget', 'help' }) do
                if source[callback] then
                    for name in pairs(owners) do
                        local _, n = source[callback]:gsub(path(name):gsub('%.', '%%.') .. '%(', '')
                        totals[name] = (totals[name] or 0) + n
                        assert(not source[callback]:find('addon.' .. name .. '(', 1, true))
                    end
                end
            end

            assert(
                source.evaluate:find(
                    'addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"' .. kind .. '"',
                    1,
                    true
                ),
                'repaired adapter arguments changed'
            )
        end

        local count = 0

        for name, n in pairs(wanted) do
            assert(totals[name] == n, module .. ' ' .. name .. ' call count changed')
            count = count + n
        end

        assert(count == 20)
    end

    assert(not f.env.Functions)
end)

test('original capture IDs hashes and source getter identities remain exact', function()
    local _, a = fixture()

    for module, hashes in pairs({
        casting = { color = '149792a5', helpers = 'c2ab875b' },
        channeling = { color = 'ad3e7907', helpers = 'f3eed23d' },
    }) do
        for name, hash in pairs(hashes) do
            local id = 'builtin:Conditions/' .. module .. '.lua:' .. name

            assert(
                a:FunctionSourceHash(a.builtinFunctions[id].source) == hash and a:ResolveFunctionBinding(id)
                    == a.builtinSourceModules['Conditions/' .. module .. '.lua'](name)
            )
        end
    end
end)

test('actual registered canonical and legacy-shaped callbacks agree on validators and summary wording', function()
    local _, a = fixture()
    local canonical, legacy = copies(a)

    for _, tag in ipairs(tags) do
        for _, unit in ipairs({ 'player', 'target', 'pet', 'missing' }) do
            for _, operator in ipairs({
                'EQUALS',
                'NOTEQUALS',
                'LESSTHAN',
                'LESSTHANOREQUALS',
                'GREATERTHAN',
                'GREATERTHANOREQUALS',
                'DIVISIBLE',
                'INVALID',
            }) do
                for _, amount in ipairs({ -1, 0, 1, 3, 1.5 }) do
                    local v = node(tag)
                    v.unit = unit
                    v.operator = operator
                    v.value = amount
                    local valid = a.conditionDefinitions[tag].valid(0, v)
                    assert(canonical[tag].valid(0, v) == valid and legacy[tag].valid(0, v) == valid)

                    for _, negated in ipairs({ false, true }) do
                        local wording = a.conditionDefinitions[tag].print(0, v, negated)

                        assert(
                            canonical[tag].print(0, v, negated) == wording
                                and legacy[tag].print(0, v, negated) == wording
                        )
                    end
                end
            end
        end
    end

    for _, tag in ipairs(tags) do
        local v = node(tag)
        v.spell = nil
        v.value = nil

        assert(
            canonical[tag].valid(0, v) == legacy[tag].valid(0, v) and canonical[tag].print(0, v) == legacy[tag].print(
                0,
                v
            )
        )
    end
end)

test('canonical and legacy clones share repaired adapter records and exact per-kind cache identity', function()
    local _, a, s = fixture()
    local canonical, legacy = copies(a)
    local cache = {}

    for _, tag in ipairs(tags) do
        local v = node(tag)
        local actual, why = a.conditionDefinitions[tag].evaluate(v, cache)
        local before = a:CopySettingsData(s.calls)
        local copied, reason = canonical[tag].evaluate(v, cache)
        local old, oldReason = legacy[tag].evaluate(v, cache)

        assert(
            actual == true
                and copied == actual
                and old == actual
                and why == reason
                and reason == oldReason
                and a:SettingsDataEqual(before, s.calls)
        )
    end

    assert(s.calls.cast == 1 and s.calls.channel == 1 and s.calls.exists == 2)
    local calls = 0

    local method = function(...)
        calls = calls + 1
        assert(select('#', ...) == 3)
        return nil, 'missing', nil, 'tail'
    end

    local function tuple(...)
        assert(select('#', ...) == 4)
        local first, why, third, tail = ...
        assert(first == nil and why == 'missing' and third == nil and tail == 'tail')
    end

    tuple(a.Functions.cache.getCached(cache, method, 'target', nil, 'cast'))
    tuple(a.getCached(cache, method, 'target', nil, 'cast'))
    assert(calls == 1)
    tuple(a.Functions.cache.getCached(nil, method, 'target', nil, 'cast'))
    assert(calls == 2 and select('#', a.Functions.cache.getCached({}, nil)) == 0)
end)

test(
    'field-level nil and restricted observations preserve repaired active-name and NOT-branch behavior in both clone forms',
    function()
        for _, mode in ipairs({
            'nil-fields',
            'restricted-fields',
            'missing-api',
            'nil-exists',
            'restricted-name',
            'policy',
        }) do
            local f, a, s = fixture()
            copies(a)
            local opaque = {}
            f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

            if mode == 'nil-fields' then
                s.ending = nil
                s.flag = nil
            elseif mode == 'restricted-fields' then
                s.ending = opaque
                s.flag = opaque
            elseif mode == 'missing-api' then
                f.env.UnitCastingInfo = nil
                f.env.UnitChannelInfo = nil
            elseif mode == 'nil-exists' then
                s.exists = nil
            elseif mode == 'restricted-name' then
                s.name = opaque
            else
                f.env.WOW_PROJECT_ID = 999
            end

            for _, tag in ipairs(tags) do
                for _, prefix in ipairs({ 'COPY_', 'LEGACY_' }) do
                    local v = node(tag)
                    v.type = prefix .. tag

                    if
                        (mode == 'nil-fields' or mode == 'restricted-fields')
                        and not tag:find('REMAIN', 1, true)
                        and not tag:find('INTERRUPTABLE', 1, true)
                    then
                        assert(a:evaluateConditionResult(v).status == 'match')
                        -- A secret name still proves the cast; only the spell named by text is unknown.
                    elseif mode == 'restricted-name' and not tag:find('SPELL', 1, true) then
                        assert(a:evaluateConditionResult(v).status == 'match', v.type)
                    else
                        checkUnknown(a, v)
                    end
                end
            end
        end

        local _, a, s = fixture()
        copies(a)
        s.name = nil

        for _, tag in ipairs(tags) do
            for _, prefix in ipairs({ 'COPY_', 'LEGACY_' }) do
                local v = node(tag)
                v.type = prefix .. tag
                assert(a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'match')
            end
        end
    end
)

test(
    'interruptibility widget clones preserve filtered unit copies and legacy helper aliases remain callable',
    function()
        local f, a = fixture()
        local canonical, legacy = copies(a)

        for _, tag in ipairs({ 'CAST_INTERRUPTABLE', 'CHANNEL_INTERRUPTABLE' }) do
            for _, definition in ipairs({ a.conditionDefinitions[tag], canonical[tag], legacy[tag] }) do
                local parent = f.widget('Group')
                local top = f.widget('Frame')
                top:SetUserData('root', {})
                top:SetUserData('funcs', { print = function() return 'summary' end })
                parent:SetUserData('top', top)
                local options

                a.Widget_UnitWidget = function(_, _, units)
                    options = units
                    return f.widget('Dropdown')
                end

                definition.widget(parent, 0, node(tag))

                assert(
                    options ~= a.units
                        and options.player == nil
                        and options.pet == nil
                        and options.target == a.units.target
                        and a.units.player ~= nil
                        and a.units.pet ~= nil
                )
            end
        end

        assert(a:InstallCustomFunction('SAVED_CAST_HELPERS', {
            description = 'Legacy cast helper API',
            args = {},
            returns = {},
            bindings = {},
            code = 'return addon.isin({x=false},"x"),addon.compare("EQUALS",1,1),addon.nullable(false),addon.deepcopy({x={}})',
        }))

        local present, compared, nullable, copy = a:ResolveFunctionBinding('SAVED_CAST_HELPERS')()
        assert(present and compared and nullable == false and type(copy.x) == 'table')
    end
)

finish()
