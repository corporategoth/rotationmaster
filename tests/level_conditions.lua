-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project)
    local a, e = f.addon, f.env
    local s = { player = 20, target = 23, playerExists = true, targetExists = true, calls = {} }

    local function call(key, unit)
        s.calls[key .. unit] = (s.calls[key .. unit] or 0) + 1

        if s.throw == key .. unit then
            error('native failed')
        end
    end

    e.UnitExists = function(unit)
        call('exists', unit)

        if unit == 'player' then
            return s.playerExists
        end

        return s.targetExists
    end

    e.UnitLevel = function(unit)
        call('level', unit)

        if unit == 'player' then
            return s.player
        end

        return s.target
    end

    e.UnitEffectiveLevel = function()
        error('wrong level API')
    end

    e.UnitClass = function() return 'Shaman', 'SHAMAN', 7 end
    a.longtermCache = {}

    for _, path in ipairs({ 'Platform/unit_level.lua', 'Core/level_conditions.lua' }) do
        local file = io.open(path)

        if file then
            file:close()
            f.load(path)
        end
    end

    for _, path in ipairs({
        'Diagnostics/errors.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua', 'Conditions/misc.lua', 'Conditions/character.lua', 'Data/builtin_sources.lua',
        'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
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

    return f, a, s
end

local function node(tag, relative)
    return {
        type = tag,
        unit = 'target',
        operator = 'EQUALS',
        value = tag == 'SELF_LEVEL' and 20 or relative and 3 or 23,
        relative = relative,
    }
end

local function unknown(a, v)
    assert(a:evaluateConditionResult(v).status == 'unavailable', v.type .. ' became known')

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'unavailable',
        v.type .. ' unknown became NOT match'
    )

    for _, kind in ipairs({ 'AND', 'OR' }) do
        assert(a:evaluateConditionResult({ type = kind, value = { v } }).status == 'unavailable')
    end

    local body = {
        rotation = {
            {
                id = 'guard',
                type = 'branch',
                conditions = v,
                onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                onFalse = { { id = 'no', type = 'spell', action = 2 } },
            },
        },
    }

    assert(
        a:EvaluateRotationSequence(body, function(value) return a:evaluateConditionResult(value) end, function()
            error('unknown level selected action')
        end).status == 'unavailable'
    )
end

local function clones(a)
    for _, tag in ipairs({ 'SELF_LEVEL', 'LEVEL' }) do
        a:RegisterCondition('COPY_' .. tag, assert(a:CompileCustomCondition('COPY_' .. tag, assert(
            a:GetBuiltinConditionSource(tag)
        ))))
    end
end

test('self absolute and relative levels retain operators offsets and known absence', function()
    local _, a, s = fixture()

    for _, operator in ipairs({
        'EQUALS',
        'NOTEQUALS',
        'LESSTHAN',
        'LESSTHANOREQUALS',
        'GREATERTHAN',
        'GREATERTHANOREQUALS',
        'DIVISIBLE',
    }) do
        for _, tag in ipairs({ 'SELF_LEVEL', 'LEVEL' }) do
            local v = node(tag)
            v.operator = operator

            assert(
                a.conditionDefinitions[tag].evaluate(v, {}) == a.compare(
                    operator,
                    tag == 'SELF_LEVEL' and 20 or 23,
                    v.value
                )
            )
        end

        for _, offset in ipairs({ -2, -.5, 0, 3, 5 }) do
            local v = node('LEVEL', true)
            v.operator = operator
            v.value = offset
            assert(a.conditionDefinitions.LEVEL.evaluate(v, {}) == a.compare(operator, 23, 20 + offset))
        end
    end

    a.longtermCache = {}
    s.targetExists = false
    s.calls = {}

    assert(
        a:evaluateConditionResult(node('LEVEL', true)).status == 'no-match'
            and a:evaluateConditionResult({ type = 'NOT', value = node('LEVEL', true) }).status == 'match'
    )

    assert(not s.calls.levelplayer and not s.calls.leveltarget)
    s.playerExists = false

    assert(
        a:evaluateConditionResult(node('SELF_LEVEL')).status == 'no-match'
            and a:evaluateConditionResult({ type = 'NOT', value = node('SELF_LEVEL') }).status == 'match'
    )
end)

test('missing failed restricted and unknown native level facts remain unavailable through NOT and branches', function()
    for _, mode in ipairs({
        'missing-api', 'throw-level', 'nil-level', 'negative-level', 'zero-level', 'fraction-level', 'infinite-level',
        'nan-level', 'string-level', 'restricted-level', 'missing-exists', 'nil-exists', 'invalid-exists',
        'throw-exists', 'restricted-exists'
    }) do
        for _, tag in ipairs({ 'SELF_LEVEL', 'LEVEL' }) do
            local f, a, s = fixture()
            local unit = tag == 'SELF_LEVEL' and 'player' or 'target'
            local opaque = {}
            f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

            if mode == 'missing-api' then
                f.env.UnitLevel = nil
            elseif mode == 'throw-level' then
                s.throw = 'level' .. unit
            elseif mode == 'nil-level' then
                s[unit] = nil
            elseif mode == 'negative-level' then
                s[unit] = -1
            elseif mode == 'zero-level' then
                s[unit] = 0
            elseif mode == 'fraction-level' then
                s[unit] = 2.5
            elseif mode == 'infinite-level' then
                s[unit] = math.huge
            elseif mode == 'nan-level' then
                s[unit] = 0 / 0
            elseif mode == 'string-level' then
                s[unit] = '20'
            elseif mode == 'restricted-level' then
                s[unit] = opaque
            elseif mode == 'missing-exists' then
                f.env.UnitExists = nil
            elseif mode == 'nil-exists' then
                s[unit .. 'Exists'] = nil
            elseif mode == 'invalid-exists' then
                s[unit .. 'Exists'] = 1
            elseif mode == 'throw-exists' then
                s.throw = 'exists' .. unit
            else
                s[unit .. 'Exists'] = opaque
            end

            unknown(a, node(tag))
        end
    end

    local _, a = fixture(999)
    unknown(a, node('SELF_LEVEL'))
    unknown(a, node('LEVEL'))
end)

test('relative comparisons require a real player level and a finite derived threshold', function()
    for _, level in ipairs({ -1, 0, 2.5, math.huge }) do
        local _, a, s = fixture()
        s.player = level
        unknown(a, node('LEVEL', true))
    end

    local _, a, s = fixture()
    s.player = nil
    unknown(a, node('LEVEL', true))
    s.player = 20
    assert(a:evaluateConditionResult(node('LEVEL', true)).status == 'match', 'unavailable player level cached forever')
    local v = node('LEVEL', true)
    v.value = math.huge
    unknown(a, v)
end)

test('only valid player levels live in longterm cache while unavailable tuples retry each pass', function()
    local _, a, s = fixture()
    local cache = {}
    assert(a.conditionDefinitions.SELF_LEVEL.evaluate(node('SELF_LEVEL'), cache))
    assert(a.conditionDefinitions.LEVEL.evaluate(node('LEVEL', true), cache))
    assert(s.calls.levelplayer == 1)
    s.player = 21
    s.target = 24
    local v = node('LEVEL', true)
    v.value = 4
    assert(a.conditionDefinitions.LEVEL.evaluate(v, {}))
    assert(s.calls.levelplayer == 1 and s.calls.leveltarget == 2)
    a.longtermCache = {}
    s.player = nil
    cache = {}
    local first, why = a.conditionDefinitions.SELF_LEVEL.evaluate(node('SELF_LEVEL'), cache)
    assert(first == nil and why == 'level-data-unavailable')
    s.player = 20
    local again, reason = a.conditionDefinitions.SELF_LEVEL.evaluate(node('SELF_LEVEL'), cache)
    assert(again == nil and reason == why and not a.longtermCache.conditionPlayerLevel)
    assert(a.conditionDefinitions.SELF_LEVEL.evaluate(node('SELF_LEVEL'), {}))
    assert(a.longtermCache.conditionPlayerLevel == 20)
    a.longtermCache = nil
    s.player = 22
    v = node('SELF_LEVEL')
    v.value = 22
    assert(a.conditionDefinitions.SELF_LEVEL.evaluate(v))
    assert(a.longtermCache == nil, 'old direct call forced a cache')
end)

test('shared helper validates exposed cached scalars and unit readability before reuse', function()
    local f, a, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, bad in ipairs({ 0, -1, 2.5, '20', false, {}, math.huge, 0 / 0, opaque }) do
        a.longtermCache = { conditionPlayerLevel = bad }
        local value, reason = a:GetConditionUnitLevel('player', {})
        assert(value == nil and reason and not s.calls.levelplayer)
    end

    a.longtermCache = { conditionPlayerLevel = 20 }
    local value, why = a:GetConditionUnitLevel(opaque, {})
    assert(value == nil and why == 'restricted-value' and not s.calls.levelplayer)
    f.env.WOW_PROJECT_ID = 999
    value, why = a:GetConditionUnitLevel('player', {})
    assert(value == nil and why == 'unsupported-client', 'cached level bypassed current client guard')
    f.env.WOW_PROJECT_ID = 5
    a.longtermCache = {}
    s.playerExists = false
    value = a:GetConditionUnitLevel('player', {})
    assert(value == false and not a.longtermCache.conditionPlayerLevel)
    s.playerExists = true
    assert(a:GetConditionUnitLevel('player', {}) == 20)
end)

test('relative summaries display unknown level without raw arithmetic or changed known wording', function()
    local _, a, s = fixture()
    local v = node('LEVEL', true)
    local words = a.conditionDefinitions.LEVEL.print(0, v)
    assert(words:find('23', 1, true))
    local known = words
    a.longtermCache = {}
    s.player = nil
    words = a.conditionDefinitions.LEVEL.print(0, v)
    assert(words:find('<level>', 1, true))
    s.player = 20
    assert(a.conditionDefinitions.LEVEL.print(0, v) == known)
    a.longtermCache = {}
    s.player = 0 / 0
    assert(a.conditionDefinitions.LEVEL.print(0, v):find('<level>', 1, true))
    v.relative = false
    assert(a.conditionDefinitions.LEVEL.print(0, v):find('3', 1, true))
end)

test('actual editable clones use repaired level helpers and saved original raw source remains executable', function()
    local _, a, s = fixture()
    clones(a)

    for _, tag in ipairs({ 'SELF_LEVEL', 'LEVEL' }) do
        local source = assert(a:GetBuiltinConditionSource(tag))
        assert(source.evaluate:find('addon:GetConditionUnitLevel', 1, true), 'level catalog is stale')
        local v = node(tag)
        v.type = 'COPY_' .. tag
        assert(a:evaluateConditionResult(v).status == 'match')
    end

    a.longtermCache = {}
    s.player = -1
    s.target = -1

    for _, tag in ipairs({ 'SELF_LEVEL', 'LEVEL' }) do
        local v = node(tag)
        v.type = 'COPY_' .. tag
        unknown(a, v)
    end

    local raw = assert(a:GetBuiltinConditionSource('SELF_LEVEL'))
    raw.parameters.evaluate = { 'value' }
    raw.evaluate = 'return addon.compare(value.operator,addon.getCached(addon.longtermCache,UnitLevel,"player"),value.value)'
    local saved = assert(a:CompileCustomCondition('SAVED_RAW_LEVEL', raw))
    local v = node('SELF_LEVEL')
    v.value = 0
    v.operator = 'LESSTHAN'
    assert(saved.evaluate(v) == true, 'saved raw custom callback was rewritten')
end)

test('public observation and shared cache helper clones resolve actual bodies and live platform guards', function()
    local f, a, s = fixture()

    for _, entry in ipairs({
        { 'Platform/unit_level.lua', 'Platform_GetUnitLevelObservation', a.Platform },
        { 'Core/level_conditions.lua', 'GetConditionUnitLevel', a },
    }) do
        local id = 'builtin:' .. entry[1] .. ':' .. entry[2]
        local source = a:CopySettingsData(assert(a.builtinFunctions[id], 'level helper catalog missing').source)
        assert(#source.description > 0 and source.args[1].name == 'self' and source.args[2].name == 'unit')
        assert(a:InstallCustomFunction('COPY_' .. entry[2], source))
        local fn = a:ResolveFunctionBinding('COPY_' .. entry[2])
        local r = fn(entry[3], 'target', {})
        assert(entry[3] == a and r == 23 or type(r) == 'table' and r.level == 23)

        if entry[3] == a.Platform then
            assert(source.bindings.finite == 'builtin:Platform/unit_level.lua:finite')
        end

        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
        s.target = opaque
        local result, why = fn(entry[3], 'target', {})
        assert(result == nil and why == 'restricted-value')
        s.target = 23
    end
end)

finish()
