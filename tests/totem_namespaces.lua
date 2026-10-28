-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local tags = { 'TOTEM', 'TOTEM_SPELL', 'TOTEM_REMAIN', 'TOTEM_SPELL_REMAIN' }
local groups = { compare = 'values', nullable = 'presentation', compareString = 'presentation' }

local expected = {
    TOTEM = { print = { nullable = 1 } },
    TOTEM_SPELL = { print = { nullable = 1 } },
    TOTEM_REMAIN = { evaluate = { compare = 1 }, print = { nullable = 2, compareString = 1 } },
    TOTEM_SPELL_REMAIN = { print = { nullable = 2, compareString = 1 } },
}

local privateHashes = {
    observe = 'e59e23eb',
    remaining = 'b96f5341',
    element = '5fbfedcc',
    amount = '3bd67a6b',
    specific = 'fdeca8ba',
    findSpecific = 'f753db9d',
    platform = 'c9ee8d33',
    color = 'b1a3d66a',
    helpers = 'f15cbb60',
}

local function fixture(extended, class)
    local f = F.new(nil, nil, class)
    local a, e = f.addon, f.env

    local state = {
        now = 100,
        count = 4,
        calls = {},
        unknown = {},
        metadata = true,
        records = { [2] = { true, 'Stoneskin Totem', 90, 15, 136098, 2, 8071 } },
    }

    e.BOOKTYPE_SPELL = 'spell'
    e.BOOKTYPE_PET = 'pet'
    e.GetTime = function() return state.now end

    e.GetNumTotemSlots = function()
        state.calls.count = (state.calls.count or 0) + 1
        return state.count
    end

    e.GetTotemInfo = function(slot)
        state.calls[slot] = (state.calls[slot] or 0) + 1

        if state.throw then
            error('native totem failed')
        end

        if state.unknown[slot] then
            return nil
        end

        local record = state.records[slot] or { false, '', 0, 0, 0 }
        return unpack(record, 1, extended and 7 or 5)
    end

    e.C_Spell = {
        GetSpellInfo = function(id)
            if not state.metadata then
                return
            end
            if id == 8071 or id == 8154 then
                return { spellID = id, name = 'Stoneskin Totem', subtext = id == 8071 and 'Rank 1' or 'Rank 2' }
            end
            if id == 5394 then
                return { spellID = id, name = 'Healing Stream Totem' }
            end
        end,
    }

    for _, path in ipairs({
        'Platform/spells.lua', 'Platform/totems.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua',
        'Data/rotation_tree.lua', 'Core/rotation_sequence.lua', 'Conditions/common.lua', 'Conditions/totem.lua',
        'Data/builtin_sources.lua', 'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
    }) do
        f.load(path)
    end

    e.loadstring = function(code, name)
        local fn, why = loadstring(code, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    return f, a, state
end

local function value(tag, ranked)
    local base = tag:gsub('^COPY_', '')

    return {
        type = tag,
        spell = (base == 'TOTEM' or base == 'TOTEM_REMAIN') and 2 or 8071,
        operator = 'LESSTHAN',
        value = 6,
        ranked = ranked,
    }
end

local function copies(a)
    local result = {}

    for _, tag in ipairs(tags) do
        local copy = assert(a:CompileCustomCondition('COPY_' .. tag, assert(a:GetBuiltinConditionSource(tag))))
        a:RegisterCondition('COPY_' .. tag, copy)
        result[tag] = copy
    end

    return result
end

local function count(text, pattern)
    local _, n = text:gsub(pattern, '')
    return n
end

local function helper(a, name)
    return a:ResolveFunctionBinding('builtin:Conditions/totem.lua:' .. name)
end

test('totem callbacks select exactly nine direct canonical pure calls while local helpers stay legacy', function()
    local f, a = fixture(true)

    local declared = assert(
        a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/totem.lua'],
        'totem canonical leaves missing'
    )

    local leaves = 0
    local total = 0

    for path in pairs(declared) do
        leaves = leaves + 1
        assert(not path:find('getCached', 1, true) and not path:find('isin', 1, true))
    end

    assert(leaves == 4)
    assert(declared['Functions.collections.keys'] == 'builtin:Functions/collections.lua:keys')

    for name, group in pairs(groups) do
        local path = 'Functions.' .. group .. '.' .. name

        assert(
            declared[path] == 'builtin:utils.lua:' .. name
                and a:ResolveFunctionBinding(declared[path]) == a.Functions[group][name]
        )
    end

    for _, tag in ipairs(tags) do
        local source = assert(a:GetBuiltinConditionSource(tag))
        assert(not source.bindings.Functions)

        for callback, counts in pairs(expected[tag]) do
            for name, group in pairs(groups) do
                local path = 'Functions.' .. group .. '.' .. name
                local n = count(source[callback], path:gsub('%.', '%%.') .. '%(')
                assert(n == (counts[name] or 0), tag .. '.' .. callback .. ' ' .. name .. ' count changed')
                total = total + n
                assert(not source[callback]:find('addon.' .. name .. '(', 1, true))
            end
        end
    end

    assert(total == 9 and not f.env.Functions)
end)

test('all original private helper hashes capture identities and getter names remain exact', function()
    local _, a = fixture(true)

    for name, hash in pairs(privateHashes) do
        local id = 'builtin:Conditions/totem.lua:' .. name
        local record = assert(a.builtinFunctions[id])
        assert(a:FunctionSourceHash(record.source) == hash, 'private source contract changed: ' .. name)
        assert(helper(a, name) == a.builtinSourceModules['Conditions/totem.lua'](name))
    end

    assert(a.builtinFunctions['builtin:Conditions/totem.lua:observe'].source.code:find('addon.getCached(', 1, true))
    assert(a.builtinFunctions['builtin:Conditions/totem.lua:amount'].source.code:find('addon.isin(', 1, true))
    assert(a.builtinFunctions['builtin:Conditions/totem.lua:findSpecific'].source.code:find('addon.compare(', 1, true))
end)

test('Shaman class guard still runs before canonical binding or getter registration', function()
    local _, a = fixture(true, 'WARRIOR')

    for _, tag in ipairs(tags) do
        assert(not a.conditionDefinitions[tag])
    end

    assert(
        not (a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/totem.lua'])
            and not a.builtinSourceModules['Conditions/totem.lua']
    )
end)

test('actual registered totem clones preserve validators summary wording rank options and operators', function()
    for _, extended in ipairs({ true, false }) do
        local _, a = fixture(extended)
        local clones = copies(a)

        for _, tag in ipairs(tags) do
            for _, spell in ipairs({ 1, 2, 4, 8071, 8154, 5394, 0, -1, 1.5 }) do
                for _, operator in ipairs({
                    'LESSTHAN',
                    'LESSTHANOREQUALS',
                    'GREATERTHAN',
                    'GREATERTHANOREQUALS',
                    'EQUALS',
                    'NOTEQUALS',
                    'DIVISIBLE',
                    'UNKNOWN',
                }) do
                    for _, ranked in ipairs({ false, true, 'invalid' }) do
                        local node = value(tag, ranked)
                        node.spell = spell
                        node.operator = operator
                        assert(a.conditionDefinitions[tag].valid(0, node) == clones[tag].valid(0, node))

                        for _, negated in ipairs({ false, true }) do
                            assert(
                                a.conditionDefinitions[tag].print(0, node, negated) == clones[tag].print(
                                    0,
                                    node,
                                    negated
                                )
                            )
                        end
                    end
                end
            end
        end

        local node = value('TOTEM')

        assert(
            a.conditionDefinitions.TOTEM.print(0, node) == a.totems[2] .. ' totem is active'
                and clones.TOTEM.print(0, node, true) == a.totems[2] .. ' totem is not active'
        )
    end
end)

test('current native and legacy tuples rank identity later matches and shared caches stay equivalent', function()
    for _, extended in ipairs({ true, false }) do
        local _, a, state = fixture(extended)
        local clones = copies(a)

        for _, tag in ipairs(tags) do
            local node = value(tag, false)
            local cache = {}
            local actual, why = a.conditionDefinitions[tag].evaluate(node, cache, 100)
            local before = a:CopySettingsData(state.calls)
            local copied, reason = clones[tag].evaluate(node, cache, 100)
            assert(actual == true and copied == actual and reason == why and a:SettingsDataEqual(before, state.calls))
        end

        local exact = value('TOTEM_SPELL', true)
        local actual, reason = clones.TOTEM_SPELL.evaluate(exact, {}, 100)

        if extended then
            assert(actual == true and reason == nil)
        else
            assert(actual == nil and reason == 'totem-rank-unavailable')
        end

        state.records[2] = { true, 'Stoneskin Totem', 90, 15, 1, 1, 8154 }
        assert(clones.TOTEM_SPELL.evaluate(value('TOTEM_SPELL', false), {}, 100) == true)

        if extended then
            assert(clones.TOTEM_SPELL.evaluate(exact, {}, 100) == false)
        end

        state.unknown[1] = true
        assert(clones.TOTEM_SPELL.evaluate(value('TOTEM_SPELL', false), {}, 100) == true)
        local absent = value('TOTEM_SPELL')
        absent.spell = 5394
        assert(clones.TOTEM_SPELL.evaluate(absent, {}, 100) == nil)
        state.count = 5
        state.records[5] = { true, 'Healing Stream Totem', 90, 15, 1, 1, 5394 }
        assert(clones.TOTEM_SPELL.evaluate(absent, {}, 100) == true)
    end
end)

test('cached nil tuples omitted timestamps and nil methods preserve their existing call-time contracts', function()
    local f, a, state = fixture(true)
    local clones = copies(a)
    local source = a.builtinFunctions['builtin:Conditions/totem.lua:observe'].source
    assert(a:InstallCustomFunction('COPY_TOTEM_OBSERVE', a:CopySettingsData(source)))
    local observe = helper(a, 'observe')
    local compiled = a:ResolveFunctionBinding('COPY_TOTEM_OBSERVE')
    local calls = 0

    local method = function(receiver, input)
        assert(receiver == a.Platform)
        calls = calls + 1
        return nil, 'unavailable', input
    end

    local cache = {}
    local x, y, z = observe(cache, method, 'tail')
    assert(x == nil and y == 'unavailable' and z == 'tail')
    x, y, z = compiled(cache, method, 'tail')
    assert(x == nil and y == 'unavailable' and z == 'tail' and calls == 1)
    observe(nil, method, 'tail')
    assert(calls == 2)
    local node = value('TOTEM_REMAIN')
    node.operator = 'GREATERTHAN'
    node.value = 3
    cache = {}
    assert(clones.TOTEM_REMAIN.evaluate(node, cache, nil) == true)
    state.now = 104

    assert(
        clones.TOTEM_REMAIN.evaluate(node, cache, nil) == false
            and a.conditionDefinitions.TOTEM_REMAIN.evaluate(node, cache, nil) == false
    )

    assert(select('#', observe({}, nil)) == 0 and select('#', compiled({}, nil)) == 0)
    a.Platform.GetTotemInfo = nil
    local actual, why = a.conditionDefinitions.TOTEM.evaluate(value('TOTEM'), {}, nil)
    local copied, reason = clones.TOTEM.evaluate(value('TOTEM'), {}, nil)
    assert(actual == nil and copied == nil and why == nil and reason == nil)
end)

test('empty expired zero-slot missing restricted and failed observations retain NOT and branch semantics', function()
    for _, extended in ipairs({ true, false }) do
        local f, a, state = fixture(extended)
        copies(a)

        for _, tag in ipairs(tags) do
            local node = value(tag)
            node.type = 'COPY_' .. tag
            state.throw = true
            assert(a:evaluateConditionResult({ type = 'NOT', value = node }).status == 'unavailable')

            local body = {
                rotation = {
                    {
                        id = 'guard',
                        type = 'branch',
                        conditions = node,
                        onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                        onFalse = { { id = 'no', type = 'spell', action = 2 } },
                    },
                    { id = 'tail', type = 'spell', action = 3 },
                },
            }

            assert(
                a:EvaluateRotationSequence(body, function(v) return a:evaluateConditionResult(v) end, function()
                    error('unknown totem selected an action')
                end).status == 'unavailable'
            )
        end

        state.throw = false
        state.records = {}

        for _, tag in ipairs(tags) do
            local node = value(tag)
            node.type = 'COPY_' .. tag
            assert(a:evaluateConditionResult({ type = 'NOT', value = node }).status == 'match')
        end

        state.count = 0
        assert(a:evaluateConditionResult({ type = 'NOT', value = value('COPY_TOTEM_SPELL') }).status == 'match')
        state.count = 4
        state.records[2] = { true, 'Stoneskin Totem', 90, 0, 1, 1, 8071 }
        assert(a:evaluateConditionResult(value('COPY_TOTEM')).status == 'no-match')
        f.env.GetTotemInfo = nil
        assert(a:evaluateConditionResult({ type = 'NOT', value = value('COPY_TOTEM') }).status == 'unavailable')
    end

    local f, a, state = fixture(true)
    copies(a)
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    state.records[2][3] = opaque
    assert(a:evaluateConditionResult({ type = 'NOT', value = value('COPY_TOTEM') }).status == 'unavailable')
end)

test('legacy saved pure helpers and cache aliases remain callable', function()
    local _, a = fixture(true)

    assert(a:InstallCustomFunction('LEGACY_TOTEM_HELPERS', {
        description = 'Legacy totem helper consumer',
        args = {},
        returns = {},
        bindings = {},
        code = 'return addon.compare("EQUALS",1,1),addon.isin({x=false},"x"),addon.nullable(false),addon.getCached(nil,function() return nil,"tail" end)',
    }))

    local compared, included, nullable, missing, tail = a:ResolveFunctionBinding('LEGACY_TOTEM_HELPERS')()
    assert(compared and included and nullable == false and missing == nil and tail == 'tail')
end)

finish()
