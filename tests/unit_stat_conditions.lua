local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local inverse, oldBody, newBody = dofile('tests/fixtures/restore_unit_stat_repairs.lua')

local function fixture(project)
    local f = F.new(project or 11, 2, 'MAGE')
    local a, e = f.addon, f.env
    local s = { exists = true, value = 42, calls = {} }
    a.delayed_condition = {}
    a.stats = { [1] = 'Strength', [2] = 'Agility', [3] = 'Stamina', [4] = 'Intellect', [5] = 'Spirit', [6] = 'Armor' }

    local function call(name, ...)
        s.calls[#s.calls + 1] = { name, n = select('#', ...), ... }

        if s.throw == name then
            error('native stat unavailable')
        end
    end

    e.UnitExists = function(...)
        assert(select('#', ...) == 1)
        call('exists', ...)
        return s.exists
    end

    e.UnitStat = function(...)
        assert(select('#', ...) == 2)
        call('stat', ...)
        return s.unused, s.value, s.unused, s.unused, s.unused
    end

    e.UnitArmor = function(...)
        assert(select('#', ...) == 1)
        call('armor', ...)
        return s.unused, s.value, s.unused, s.unused, s.unused
    end

    local file = io.open('Platform/unit_stat.lua')

    if file then
        file:close()
        f.load('Platform/unit_stat.lua')
    end

    for _, path in ipairs({
        'Diagnostics/errors.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua', 'Conditions/ext_stats.lua', 'Data/builtin_sources.lua',
        'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
    }) do
        f.load(path)
    end

    e.loadstring = function(text, name)
        local fn, why = loadstring(text, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    return f, a, s
end

local function node(stat, op, n, unit)
    return { type = 'STAT', stat = stat or 1, operator = op or 'NOTEQUALS', value = n or 0, unit = unit or 'player' }
end

local function unknown(a, v)
    assert(a.conditionDefinitions.STAT.valid(0, v), 'invalid STAT unknown fixture')

    for _, value in ipairs({
        v,
        { type = 'NOT', value = v },
        { type = 'AND', value = { v } },
        { type = 'OR', value = { { type = 'NOT', value = v } } },
    }) do
        local result = a:evaluateConditionResult(value)

        assert(
            result.status == 'unavailable' and result.reason ~= 'condition-callback-error',
            tostring(result.status) .. ':' .. tostring(result.reason)
        )
    end

    for _, guard in ipairs({ v, { type = 'NOT', value = v } }) do
        local body = {
            rotation = {
                {
                    id = 'guard',
                    type = 'branch',
                    conditions = guard,
                    onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                    onFalse = { { id = 'no', type = 'spell', action = 2 } },
                },
            },
        }

        assert(
            a:EvaluateRotationSequence(body, function(value) return a:evaluateConditionResult(value) end, function()
                error('unavailable STAT authorized branch')
            end).status == 'unavailable'
        )
    end

    assert(#a.Diagnostics:GetReports() == 0, 'observation failure quarantined the definition')
end

local function calls(s, name)
    local count = 0

    for _, call in ipairs(s.calls) do
        if call[1] == name then
            count = count + 1
        end
    end

    return count
end

test(
    'required nil malformed restricted missing and throwing facts remain unknown under all logical wrappers',
    function()
        for _, stat in ipairs({ 1, 6 }) do
            for _, fact in ipairs({ 'exists', 'value' }) do
                for _, mode in ipairs({ 'nil', 'missing', 'throw', 'restricted', false, '42', {}, 0 / 0, math.huge }) do
                    if not (fact == 'exists' and mode == false) then
                        local f, a, s = fixture()
                        local opaque = {}
                        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

                        if mode == 'missing' then
                            f.env[fact == 'exists' and 'UnitExists' or stat == 6 and 'UnitArmor' or 'UnitStat'] = nil
                        elseif mode == 'throw' then
                            s.throw = fact == 'exists' and 'exists' or stat == 6 and 'armor' or 'stat'
                        elseif mode == 'nil' then
                            s[fact] = nil
                        elseif mode == 'restricted' then
                            s[fact] = opaque
                        else
                            s[fact] = mode
                        end

                        unknown(a, node(stat))
                    end
                end
            end
        end
    end
)

test('known absence and finite zero signed fractional effective values keep comparison and branch controls', function()
    local _, a, s = fixture()
    s.exists = false
    assert(a:evaluateConditionResult(node()).status == 'no-match')
    assert(a:evaluateConditionResult({ type = 'NOT', value = node() }).status == 'match')
    s.exists = true

    for _, stat in ipairs({ 1, 6 }) do
        for _, value in ipairs({ 0, -3.5, 2.25 }) do
            s.value = value
            local v = node(stat, value == 0 and 'EQUALS' or 'NOTEQUALS', 0)
            assert(a:evaluateConditionResult(v).status == 'match')
            assert(a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'no-match')
        end
    end

    for _, present in ipairs({ false, true }) do
        for _, number in ipairs({ 0, 42 }) do
            for _, negated in ipairs({ false, true }) do
                s.exists = present
                s.value = number
                local v = node()
                local guard = negated and { type = 'NOT', value = v } or v
                local chosen

                local body = {
                    rotation = {
                        {
                            id = 'guard',
                            type = 'branch',
                            conditions = guard,
                            onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                            onFalse = { { id = 'no', type = 'spell', action = 2 } },
                        },
                    },
                }

                local result = a:EvaluateRotationSequence(
                    body,
                    function(value) return a:evaluateConditionResult(value) end,
                    function(row)
                        chosen = row.id
                        return true
                    end
                )

                local matching = present and number ~= 0

                if negated then
                    matching = not matching
                end

                assert(result.status == 'complete' and chosen == (matching and 'yes' or 'no'))
            end
        end
    end

    local v = node(1, 'NOTEQUALS', math.huge)
    s.exists = true
    s.value = 42

    assert(
        a.conditionDefinitions.STAT.valid(0, v) and a:evaluateConditionResult(v).status == 'match',
        'unchanged threshold validator/behavior was widened in STAT observation repair'
    )
end)

test('ordered exact native arguments and complete pass snapshots separate unit stat and receiver', function()
    local _, a, s = fixture()
    local eval = a.conditionDefinitions.STAT.evaluate
    local cache = {}
    assert(eval(node(1), cache))
    assert(eval(node(1), cache))

    assert(
        #s.calls == 2
            and s.calls[1][1] == 'exists'
            and s.calls[1][2] == 'player'
            and s.calls[2][1] == 'stat'
            and s.calls[2][2] == 'player'
            and s.calls[2][3] == 1
    )

    s.value = 0
    assert(eval(node(1), cache))
    assert(not eval(node(2), cache))
    assert(not eval(node(6), cache))
    assert(not eval(node(1, nil, nil, 'pet'), cache))
    assert(calls(s, 'exists') == 4 and calls(s, 'stat') == 3 and calls(s, 'armor') == 1)
    local p = a.Platform
    local other = setmetatable({}, { __index = p })
    local result = a.Functions.cache.getCached(cache, p.GetUnitStatObservation, other, 'player', 1)
    assert(result.value == 0 and calls(s, 'exists') == 5)
end)

test(
    'unknown snapshots and native errors recover on fresh or uncached passes without longterm failure storage',
    function()
        local _, a, s = fixture()
        local eval = a.conditionDefinitions.STAT.evaluate
        s.value = nil
        local cache = {}
        local result, why = eval(node(), cache)
        assert(result == nil and why)
        s.value = 42
        local again, reason = eval(node(), cache)
        assert(again == nil and reason == why and #s.calls == 2)
        assert(eval(node(), {}) and eval(node()))
        s.throw = 'stat'
        unknown(a, node())
        s.throw = nil
        assert(a:evaluateConditionResult(node()).status == 'match')
    end
)

test('unsupported policies stay unknown and unused tuple values never become required metadata', function()
    for _, project in ipairs({ 999 }) do
        local _, a, s = fixture(project)
        unknown(a, node())
        assert(#s.calls == 0)
    end

    local f, a, s = fixture()
    local opaque = {}
    s.unused = opaque
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    assert(a:evaluateConditionResult(node()).status == 'match' and a:evaluateConditionResult(node(6)).status == 'match')
end)

test(
    'actual current editable clone shares the adapter cache and saved raw source keeps its prior nil mismatch',
    function()
        local _, a, s = fixture()
        local source = assert(a:GetBuiltinConditionSource('STAT'))
        assert(source.evaluate == newBody, 'STAT catalog stale')
        local before = a:CopySettingsData(source)
        local clone = assert(a:CompileCustomCondition('COPY_STAT', source))
        a:RegisterCondition('COPY_STAT', clone)
        local cache = {}
        assert(a.conditionDefinitions.STAT.evaluate(node(), cache) and clone.evaluate(node(), cache))
        assert(#s.calls == 2)
        s.value = nil
        local v = node()
        v.type = 'COPY_STAT'
        unknown(a, v)
        local old = a:CopySettingsData(source)
        old.evaluate = oldBody
        local raw = assert(a:CompileCustomCondition('RAW_STAT', old))
        assert(raw.evaluate(node(), {}) == true)
        assert(a:SettingsDataEqual(source, before) and old.evaluate == oldBody)
    end
)

test('public adapter source clone keeps exact owner and live readability query and policy contracts', function()
    local f, a, s = fixture()
    local id = 'builtin:Platform/unit_stat.lua:Platform_GetUnitStatObservation'
    local record = assert(a.builtinFunctions[id], 'public stat catalog stale')
    assert(record.source.args[1].name == 'self' and #record.source.args == 3)
    assert(a:InstallCustomFunction('COPY_STAT_OBSERVATION', record.source))
    local fn = assert(a:ResolveFunctionBinding('COPY_STAT_OBSERVATION'))
    assert(fn(a.Platform, 'pet', 6).value == 42)
    local opaque = {}
    s.value = opaque
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    local result, why = fn(a.Platform, 'pet', 6)
    assert(result == nil and why == 'restricted-value')
    s.exists = false
    s.value = nil
    assert(fn(a.Platform, 'pet', 6).exists == false)
end)

finish()
