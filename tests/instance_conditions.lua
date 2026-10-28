-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local inverse, old, repaired = dofile('tests/fixtures/restore_instance_repairs.lua')

local function fixture(project)
    local f = F.new(project)
    local a, e = f.addon, f.env
    local s = { inside = true, kind = 'party', calls = 0 }

    e.IsInInstance = function(...)
        assert(select('#', ...) == 0)
        s.calls = s.calls + 1

        if s.throw then
            error('native instance failure')
        end

        return s.inside, s.kind
    end

    local file = io.open('Platform/instance.lua')

    if file then
        file:close()
        f.load('Platform/instance.lua')
    end

    for _, path in ipairs({
        'Diagnostics/errors.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua', 'Conditions/misc.lua', 'Data/builtin_sources.lua', 'Core/builtin_sources.lua',
        'Core/custom_authoring.lua', 'Core/function_data.lua'
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

local function node(mode, tag)
    return { type = tag or 'INSTANCE', value = mode }
end

local function unknown(a, value)
    assert(a.conditionDefinitions[value.type].valid(0, value), 'probe must pass current validator')

    for _, v in ipairs({
        value,
        { type = 'NOT', value = value },
        { type = 'AND', value = { value } },
        { type = 'OR', value = { { type = 'NOT', value = value } } },
    }) do
        local result = a:evaluateConditionResult(v)

        assert(
            result.status == 'unavailable' and result.reason ~= 'invalid-condition-fields',
            'unknown instance became actionable: ' .. tostring(result.status)
        )
    end

    local body = {
        rotation = {
            {
                id = 'guard',
                type = 'branch',
                conditions = value,
                onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                onFalse = { { id = 'no', type = 'spell', action = 2 } },
            },
        },
    }

    assert(
        a:EvaluateRotationSequence(body, function(v) return a:evaluateConditionResult(v) end, function()
            error('unknown instance selected branch')
        end).status == 'unavailable'
    )
end

test('missing failed malformed and restricted primary facts stay unavailable under NOT groups and branches', function()
    for _, mode in ipairs({ 'missing', 'nil', 'throw', 'restricted', 0, 'true', {} }) do
        for _, selected in ipairs({ 'none', 'party' }) do
            local f, a, s = fixture()
            local opaque = {}
            f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

            if mode == 'missing' then
                f.env.IsInInstance = nil
            elseif mode == 'nil' then
                s.inside = nil
            elseif mode == 'throw' then
                s.throw = true
            elseif mode == 'restricted' then
                s.inside = opaque
            else
                s.inside = mode
            end

            unknown(a, node(selected))
        end
    end
end)

test('known membership short circuits unused type while inside comparisons require available type', function()
    local f, a, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, entry in ipairs({ {}, { value = false }, { value = 0 }, { value = {} }, { value = opaque } }) do
        s.kind = entry.value
        unknown(a, node('party'))
        unknown(a, node(nil))

        assert(
            a:evaluateConditionResult(node('none')).status == 'no-match'
                and a:evaluateConditionResult({ type = 'NOT', value = node('none') }).status == 'match'
        )
    end

    s.inside = false
    s.kind = opaque

    f.env.canaccessvalue = function(v)
        assert(not rawequal(v, opaque), 'outside type inspected')
        return true
    end

    assert(
        a:evaluateConditionResult(node('none')).status == 'match'
            and a:evaluateConditionResult(node('party')).status == 'no-match'
            and a:evaluateConditionResult(node(nil)).status == 'no-match'
    )
end)

test('empty future and ordinary type strings retain exact comparisons without inferred scenario', function()
    for _, project in ipairs({ 1, 18, 2, 5, 11, 14, 19 }) do
        local _, a, s = fixture(project)

        for _, kind in ipairs({ 'none', 'party', 'raid', 'pvp', 'arena', 'scenario', '', 'future' }) do
            s.kind = kind

            for _, selected in ipairs({ 'none', 'party', 'raid', 'pvp', 'arena', 'scenario' }) do
                local v = node(selected)
                assert(a.conditionDefinitions.INSTANCE.valid(0, v))
                local want = selected ~= 'none' and selected == kind
                assert(a:evaluateConditionResult(v).status == (want and 'match' or 'no-match'))
            end
        end
    end
end)

test('one pass shares a partial tuple across modes while self and fresh passes stay isolated', function()
    local _, a, s = fixture()
    local evaluate = a.conditionDefinitions.INSTANCE.evaluate
    local cache = {}
    s.kind = nil
    local value, why = evaluate(node('party'), cache)
    assert(value == nil and why == 'instance-type-unavailable' and s.calls == 1)
    assert(evaluate(node('none'), cache) == false and s.calls == 1)
    s.kind = 'party'
    value, why = evaluate(node('party'), cache)
    assert(value == nil and why == 'instance-type-unavailable' and s.calls == 1)
    assert(evaluate(node('party'), {}) == true and s.calls == 2)
    local other = setmetatable({}, { __index = a.Platform })

    assert(
        a.Functions.cache.getCached(cache, a.Platform.GetInstanceObservation, other).instanceType == 'party'
            and s.calls == 3
    )

    assert(
        evaluate(node('party')) == true
            and evaluate(node('party')) == true
            and s.calls == 5
            and next(a.longtermCache) == nil
    )
end)

test('transient failures recover without quarantine and unknown families never query', function()
    local _, a, s = fixture()
    s.throw = true
    unknown(a, node('none'))
    s.throw = nil
    assert(a:evaluateConditionResult(node('party')).status == 'match')
    local _, b, state = fixture(999)
    unknown(b, node('none'))
    assert(state.calls == 0)
end)

test('current exported callback and public helper clones use their actual source ownership', function()
    local f, a, s = fixture()
    local source = assert(a:GetBuiltinConditionSource('INSTANCE'))
    local _, _, _, instanceEvaluate = dofile('tests/fixtures/restore_instance_details.lua')
    assert(source.evaluate == instanceEvaluate, 'INSTANCE catalog stale')
    local copy = assert(a:CompileCustomCondition('COPY_INSTANCE', source))
    a:RegisterCondition('COPY_INSTANCE', copy)
    local cache = {}

    assert(
        copy.evaluate(node('party'), cache) == true
            and a.conditionDefinitions.INSTANCE.evaluate(node('party'), cache) == true
            and s.calls == 1
    )

    s.kind = nil
    unknown(a, node('party', 'COPY_INSTANCE'))
    assert(a:evaluateConditionResult(node('none', 'COPY_INSTANCE')).status == 'no-match')
    local id = 'builtin:Platform/instance.lua:Platform_GetInstanceObservation'
    local record = assert(a.builtinFunctions[id], 'public instance observer missing')

    assert(
        a:ResolveFunctionBinding(id) == a.Platform.GetInstanceObservation
            and a.builtinSourceModules['Platform/instance.lua']('Platform_GetInstanceObservation')
                == a.Platform.GetInstanceObservation
    )

    assert(
        #record.source.args == 1 and record.source.args[1].type == 'RMPlatform' and next(record.source.bindings) == nil
    )

    assert(a:InstallCustomFunction('COPY_INSTANCE_OBSERVATION', a:CopySettingsData(record.source)))
    local fn = a:ResolveFunctionBinding('COPY_INSTANCE_OBSERVATION')
    assert(fn(a.Platform).instanceTypeReason == 'instance-type-unavailable')
    s.inside = false
    assert(fn(a.Platform).inInstance == false)
end)

test('saved raw callbacks remain exact and retain their historical missing observation behavior', function()
    local _, a, s = fixture()
    local source = assert(a:GetBuiltinConditionSource('INSTANCE'))
    source.evaluate = old
    local before = a:CopySettingsData(source)
    local raw = assert(a:CompileCustomCondition('RAW_INSTANCE', source))
    a:RegisterCondition('RAW_INSTANCE', raw)
    s.inside = nil
    assert(raw.evaluate(node('none'), {}) == true)
    s.inside = true
    s.kind = nil
    assert(raw.evaluate(node(nil), {}) == true)
    assert(a:SettingsDataEqual(before, source), 'raw saved source changed')
end)

finish()
