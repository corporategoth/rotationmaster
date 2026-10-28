local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project, expansion, class)
    local f = F.new(project or 11, expansion or 2, class or 'DEATHKNIGHT')
    local a, e = f.addon, f.env

    local s = {
        now = 100,
        types = { 1, 2, 1, 2, 3, 3 },
        rows = {
            { 98, 5, true },
            { 98, 5, true },
            { 99, 4, false },
            { 98, 5, true },
            { 98, 5, true },
            { 98, 5, true },
        },
        calls = {},
        clocks = 0,
    }

    local function call(name, ...)
        s.calls[#s.calls + 1] = { name, n = select('#', ...), ... }

        if s.throw == name then
            error('native rune failure')
        end
    end

    e.GetTime = function(...)
        assert(select('#', ...) == 0)
        call('clock', ...)
        s.clocks = s.clocks + 1

        if s.throwClockAt == s.clocks then
            error('rune callback clock failed')
        end

        return s.now
    end

    e.GetRuneType = function(...)
        assert(select('#', ...) == 1)
        local i = ...
        assert(i >= 1 and i <= 6)
        call('type', ...)
        return s.types[i]
    end

    e.GetRuneCooldown = function(...)
        assert(select('#', ...) == 1)
        local i = ...
        call('cooldown', ...)
        local row = s.rows[i]

        if row then
            return unpack(row, 1, row.n or 3)
        end
    end

    local file = io.open('Platform/runes.lua')

    if file then
        file:close()
        f.load('Platform/runes.lua')
    end

    for _, path in ipairs({
        'Diagnostics/errors.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua', 'Conditions/stats.lua', 'Data/builtin_sources.lua', 'Core/builtin_sources.lua',
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

    s.calls = {}
    return f, a, s
end

local function node(tag, op, n, rune)
    return {
        type = tag or 'RUNE',
        operator = op or 'EQUALS',
        value = n == nil and ((tag == 'RUNE_COOLDOWN') and 3 or 1) or n,
        rune = rune or 1,
    }
end

local function unknown(a, v, reset)
    assert(a.conditionDefinitions[v.type].valid(0, v), 'invalid rune fields in unknown fixture')

    for _, n in ipairs({
        v,
        { type = 'NOT', value = v },
        { type = 'AND', value = { v } },
        { type = 'OR', value = { { type = 'NOT', value = v } } },
    }) do
        if reset then
            reset()
        end

        local r = a:evaluateConditionResult(n)

        assert(
            r.status == 'unavailable'
                and r.reason ~= 'invalid-condition-fields'
                and r.reason ~= 'condition-callback-error',
            'rune unknown became ' .. r.status .. ':' .. tostring(r.reason)
        )
    end

    for _, n in ipairs({ v, { type = 'NOT', value = v } }) do
        if reset then
            reset()
        end

        local body = {
            rotation = {
                {
                    id = 'guard',
                    type = 'branch',
                    conditions = n,
                    onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                    onFalse = { { id = 'no', type = 'spell', action = 2 } },
                },
            },
        }

        assert(
            a:EvaluateRotationSequence(body, function(x) return a:evaluateConditionResult(x) end, function()
                error('unknown rune selected action')
            end).status == 'unavailable'
        )
    end
end

local function clone(a, tag)
    local source = assert(a:GetBuiltinConditionSource(tag))
    assert(source.evaluate:find('addon.Platform.GetRuneTypeObservation', 1, true), 'rune catalog stale')
    a:RegisterCondition('COPY_' .. tag, assert(a:CompileCustomCondition('COPY_' .. tag, source)))
    return source
end

test('unknown type facts cannot authorize either predicate through NOT groups or branches', function()
    for _, mode in ipairs({ 'missing', 'nil', 'throw', 'restricted', false, 0, -1, .5, '1', {}, math.huge, 0 / 0 }) do
        for _, tag in ipairs({ 'RUNE', 'RUNE_COOLDOWN' }) do
            local f, a, s = fixture()
            local opaque = {}
            f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

            if mode == 'missing' then
                f.env.GetRuneType = nil
            elseif mode == 'nil' then
                s.types[6] = nil
            elseif mode == 'throw' then
                s.throw = 'type'
            elseif mode == 'restricted' then
                s.types[6] = opaque
            else
                s.types[6] = mode
            end

            unknown(a, node(tag))
        end
    end
end)

test('ready and timing are independently required from one selected cooldown record', function()
    local f, a, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    s.rows[1] = { opaque, nil, true, n = 3 }
    assert(a:evaluateConditionResult(node()).status == 'match')
    unknown(a, node('RUNE_COOLDOWN'))
    f, a, s = fixture()
    s.rows[1][3] = nil
    unknown(a, node())
    assert(a:evaluateConditionResult(node('RUNE_COOLDOWN')).status == 'match')

    for _, mode in ipairs({ 'missing', 'throw', 'nil', 0, 'true', opaque }) do
        f, a, s = fixture()
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

        if mode == 'missing' then
            f.env.GetRuneCooldown = nil
        elseif mode == 'throw' then
            s.throw = 'cooldown'
        elseif mode == 'nil' then
            s.rows[1] = nil
        else
            s.rows[1][3] = mode
        end

        unknown(a, node())
    end
end)

test('only selected timing fields are required and finite signed fractional timing retains exact arithmetic', function()
    for _, field in ipairs({ 1, 2 }) do
        for _, mode in ipairs({ 'nil', 'restricted', 'string', 'infinite', 'nan' }) do
            local f, a, s = fixture()
            local opaque = {}
            f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

            if mode == 'nil' then
                s.rows[1][field] = nil
            elseif mode == 'restricted' then
                s.rows[1][field] = opaque
            elseif mode == 'string' then
                s.rows[1][field] = '1'
            elseif mode == 'infinite' then
                s.rows[1][field] = math.huge
            else
                s.rows[1][field] = 0 / 0
            end

            unknown(a, node('RUNE_COOLDOWN'))
            assert(a:evaluateConditionResult(node()).status == 'match')
        end
    end

    local _, a, s = fixture()
    s.rows[1] = { 0, 0, true }
    s.rows[3][2] = nil
    unknown(a, node('RUNE_COOLDOWN'))
    s.rows[3] = { 0, 0, nil, n = 3 }
    unknown(a, node())
    local _, a, s = fixture()
    s.rows[2] = { {}, {}, {} }
    s.rows[1] = { 101, 2, nil, n = 3 }
    s.rows[3] = { 101, 4, nil, n = 3 }
    assert(a.conditionDefinitions.RUNE_COOLDOWN.evaluate(node('RUNE_COOLDOWN', 'EQUALS', 3), {}))
    s.rows[1] = { 100, .1234, nil, n = 3 }
    s.rows[3] = { 100, .9999, nil, n = 3 }
    assert(a.conditionDefinitions.RUNE_COOLDOWN.evaluate(node('RUNE_COOLDOWN', 'EQUALS', .123), {}))
    s.rows[1] = { 0, 0, false }
    s.rows[3] = { 0, 0, false }
    assert(a.conditionDefinitions.RUNE_COOLDOWN.evaluate(node('RUNE_COOLDOWN', 'EQUALS', 0), {}))
    assert(a.conditionDefinitions.RUNE.evaluate(node('RUNE', 'EQUALS', 0), {}))
end)

test(
    'known no selected type means zero count and false cooldown for every operator despite unused clock failure',
    function()
        for _, op in ipairs({
            'EQUALS',
            'NOTEQUALS',
            'GREATERTHAN',
            'LESSTHAN',
            'GREATERTHANOREQUALS',
            'LESSTHANOREQUALS',
        }) do
            local _, a, s = fixture()
            s.types = { 2, 2, 2, 2, 5, 5 }
            s.throw = 'clock'
            s.rows = {}
            local v = node('RUNE_COOLDOWN', op, 0)
            assert(a.conditionDefinitions.RUNE_COOLDOWN.valid(0, v))

            assert(
                a.conditionDefinitions.RUNE_COOLDOWN.evaluate(v, {}) == false,
                'no-match cooldown depended on operator/clock'
            )

            assert(#s.calls == 7 and s.calls[1][1] == 'clock')

            for i = 1, 6 do
                assert(s.calls[i + 1][1] == 'type' and s.calls[i + 1][2] == i)
            end
        end

        local _, a, s = fixture()
        s.types = { 2, 2, 2, 2, 5, 5 }
        assert(a:evaluateConditionResult(node('RUNE', 'EQUALS', 0)).status == 'match')

        assert(
            a:evaluateConditionResult({ type = 'NOT', value = node('RUNE_COOLDOWN', 'NOTEQUALS', 0) }).status == 'match'
        )

        local selected

        local body = {
            rotation = {
                {
                    id = 'guard',
                    type = 'branch',
                    conditions = node('RUNE_COOLDOWN', 'GREATERTHAN', 0),
                    onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                    onFalse = { { id = 'no', type = 'spell', action = 2 } },
                },
            },
        }

        a:EvaluateRotationSequence(body, function(x) return a:evaluateConditionResult(x) end, function(x)
            selected = x.id
            return true
        end)

        assert(selected == 'no')
    end
)

test('matching cooldown requires finite fresh clock and finite raw and rounded arithmetic', function()
    for _, mode in ipairs({ 'nil', 'restricted', 'throw', 'string', 'infinite', 'raw-overflow', 'round-overflow' }) do
        local f, a, s = fixture()
        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

        if mode == 'nil' then
            s.now = nil
        elseif mode == 'restricted' then
            s.now = opaque
        elseif mode == 'throw' then
            s.throwClockAt = 2
        elseif mode == 'string' then
            s.now = '100'
        elseif mode == 'infinite' then
            s.now = math.huge
        elseif mode == 'raw-overflow' then
            s.rows[1] = { 1e308, 1e308, true }
            s.now = -1e308
        else
            s.rows[1] = { 0, 1e308, true }
        end

        -- Engine has its own clock; isolate callback-only throw for each evaluation.
        unknown(
            a,
            node('RUNE_COOLDOWN'),
            mode == 'throw' and function()
                s.clocks = 0
            end or nil
        )
    end
end)

test('exact Death identity complete scans rounding clamp and minimum preserve known quantities', function()
    local _, a, s = fixture()
    s.types = { 4, 2, 4, 2, 5, 5 }
    assert(a.conditionDefinitions.RUNE.evaluate(node('RUNE', 'EQUALS', 0), {}) == true)
    assert(a.conditionDefinitions.RUNE.evaluate(node('RUNE', 'EQUALS', 1, 4), {}) == true)
    s.calls = {}
    s.rows[1] = { 100.0004, 0, false }
    s.rows[3] = { 99, 4.2346, true }
    assert(a.conditionDefinitions.RUNE_COOLDOWN.evaluate(node('RUNE_COOLDOWN', 'EQUALS', 0, 4), {}) == true)
    assert(#s.calls == 9 and s.calls[1][1] == 'clock' and s.calls[9][2] == 6)
    s.rows[1] = { 99, 5, true }
    s.rows[3] = { 99, 6, true }
    assert(a.conditionDefinitions.RUNE_COOLDOWN.evaluate(node('RUNE_COOLDOWN', 'EQUALS', 4, 4), {}) == true)
    s.rows[1] = { -1, -.5, false }
    s.rows[3] = { -1, -1, false }
    assert(a.conditionDefinitions.RUNE_COOLDOWN.evaluate(node('RUNE_COOLDOWN', 'EQUALS', 0, 4), {}) == true)
end)

test('count and cooldown share partial native tuples by pass while clock stays fresh', function()
    local _, a, s = fixture()
    local c = {}
    assert(a.conditionDefinitions.RUNE.evaluate(node(), c))
    assert(a.conditionDefinitions.RUNE_COOLDOWN.evaluate(node('RUNE_COOLDOWN'), c))
    assert(#s.calls == 9)
    s.now = 101
    s.types[1] = 4
    s.rows[1] = { 0, 0, false }
    assert(a.conditionDefinitions.RUNE_COOLDOWN.evaluate(node('RUNE_COOLDOWN', 'EQUALS', 2), c))
    assert(#s.calls == 10 and s.calls[10][1] == 'clock')
    assert(a.conditionDefinitions.RUNE.evaluate(node('RUNE', 'EQUALS', 0), {}))
    local f
    f, a, s = fixture()
    s.rows[1][3] = nil
    c = {}
    local value, why = a.conditionDefinitions.RUNE.evaluate(node(), c)
    assert(value == nil and why)
    s.rows[1][3] = true
    local again, reason = a.conditionDefinitions.RUNE.evaluate(node(), c)
    assert(again == nil and reason == why)

    assert(
        a.conditionDefinitions.RUNE.evaluate(node(), {}) == true
            and a.conditionDefinitions.RUNE.evaluate(node()) == true
    )
end)

test('family expansion class registration remains exact and unsupported runtime policy makes no rune calls', function()
    for _, case in ipairs({
        { 1, 12, 'DEATHKNIGHT', false },
        { 18, 12, 'DEATHKNIGHT', true },
        { 2, 0, 'DEATHKNIGHT', false },
        { 5, 1, 'DEATHKNIGHT', false },
        { 5, 2, 'DEATHKNIGHT', true },
        { 11, 2, 'DEATHKNIGHT', true },
        { 14, 3, 'DEATHKNIGHT', true },
        { 19, 4, 'DEATHKNIGHT', true },
        { 11, 2, 'MAGE', false },
        { 999, 2, 'DEATHKNIGHT', true },
    }) do
        local _, a, s = fixture(case[1], case[2], case[3])

        assert(
            (a.conditionDefinitions.RUNE ~= nil) == case[4] and (a.conditionDefinitions.RUNE_COOLDOWN ~= nil) == case[4]
        )

        if case[4] and case[1] == 999 then
            unknown(a, node())
            unknown(a, node('RUNE_COOLDOWN'))

            for _, call in ipairs(s.calls) do
                assert(call[1] == 'clock')
            end
        end
    end
end)

test('current editable copies share normalized methods and failed cache snapshots then recover', function()
    local _, a, s = fixture()

    for _, tag in ipairs({ 'RUNE', 'RUNE_COOLDOWN' }) do
        clone(a, tag)
    end

    local c = {}
    assert(a.conditionDefinitions.RUNE.evaluate(node(), c))
    assert(a.conditionDefinitions.COPY_RUNE.evaluate(node('COPY_RUNE'), c))
    assert(a.conditionDefinitions.COPY_RUNE_COOLDOWN.evaluate(node('COPY_RUNE_COOLDOWN', 'EQUALS', 3), c))
    assert(#s.calls == 9)
    s.types[6] = nil
    unknown(a, node('COPY_RUNE'))
    unknown(a, node('COPY_RUNE_COOLDOWN', 'EQUALS', 3))
    s.types[6] = 3
    assert(a:evaluateConditionResult(node('COPY_RUNE')).status == 'match')
end)

test('public editable helper clones resolve private guards and actual partial observation ownership', function()
    local f, a, s = fixture()

    for _, name in ipairs({ 'GetRuneTypeObservation', 'GetRuneCooldownObservation', 'GetRuneEvaluationTime' }) do
        local alias = 'Platform_' .. name
        local id = 'builtin:Platform/runes.lua:' .. alias
        local record = assert(a.builtinFunctions[id], 'rune helper catalog absent')

        assert(
            a:ResolveFunctionBinding(id) == a.Platform[name]
                and a.builtinSourceModules['Platform/runes.lua'](alias) == a.Platform[name]
        )

        assert(a:InstallCustomFunction('COPY_' .. name, a:CopySettingsData(record.source)))
        local fn = a:ResolveFunctionBinding('COPY_' .. name)
        local value

        if name == 'GetRuneEvaluationTime' then
            value = fn(a.Platform)
        else
            value = fn(a.Platform, 1)
            local bad, why = fn(a.Platform, 0)
            assert(bad == nil and why == 'invalid-rune-index')
        end

        assert(value ~= nil)
    end
end)

test('archived raw callback keeps old nil-ready and no-type operator semantics without source rewriting', function()
    local _, a, s = fixture()

    for _, tag in ipairs({ 'RUNE', 'RUNE_COOLDOWN' }) do
        local source = assert(a:GetBuiltinConditionSource(tag))
        source.evaluate = dofile('tests/fixtures/restore_rune_repairs.lua')(source.evaluate, tag)
        local before = a:CopySettingsData(source)
        local d = assert(a:CompileCustomCondition('SAVED_' .. tag, source))
        a:RegisterCondition('SAVED_' .. tag, d)

        if tag == 'RUNE' then
            s.rows[1][3] = nil
            assert(d.evaluate(node(tag, 'EQUALS', 0), {}) == true)
            s.rows[1][3] = true
        else
            s.types = { 2, 2, 2, 2, 3, 3 }
            assert(d.evaluate(node(tag, 'NOTEQUALS', 0), {}) == true)
        end

        assert(a:SettingsDataEqual(before, source))
    end
end)

finish()
