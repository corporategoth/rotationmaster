local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local inverse, old, repaired = dofile('tests/fixtures/restore_beyond_melee_presence.lua')

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local function fixture(legacy)
    local f = F.new()
    local a, e = f.addon, f.env
    local s = { exists = true, inRange = false, trace = {} }

    e.UnitExists = function(...)
        assert(select('#', ...) == 1 and (...) == 'target')
        s.trace[#s.trace + 1] = 'exists'

        if s.throws then
            error('existence failure')
        end

        return s.exists
    end

    local function ranged(...)
        assert(select('#', ...) == 2 and select(2, ...) == 'target')
        s.trace[#s.trace + 1] = 'range'
        assert((...) == (legacy and 'Localized Attack' or 6603))
        return s.inRange
    end

    if legacy then
        e.GetSpellInfo = function(id, ...)
            assert(id == 6603 and select('#', ...) == 0)
            s.trace[#s.trace + 1] = 'metadata'
            return 'Localized Attack', nil, 1, 0, 0, 0, 6603
        end

        e.IsSpellInRange = ranged
    else
        e.C_Spell = { IsSpellInRange = ranged }
    end

    for _, path in ipairs({
        'Platform/spells.lua', 'Platform/range.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua',
        'Data/rotation_tree.lua', 'Core/rotation_sequence.lua', 'Conditions/common.lua', 'Conditions/range.lua',
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

    return f, a, s
end

local function node(tag)
    return { type = tag or 'BEYOND_MELEE', unit = 'target' }
end

local function unknown(a, v, reason)
    assert(a:validateCondition(v, 0), 'invalid unavailable fixture')

    for _, n in ipairs({
        v,
        { type = 'NOT', value = v },
        { type = 'AND', value = { v } },
        { type = 'OR', value = { { type = 'NOT', value = v } } },
    }) do
        local result = a:evaluateConditionResult(n)
        assert(result.status == 'unavailable', 'required presence became ' .. result.status)

        if reason then
            assert(result.reason == reason, result.reason)
        end
    end

    for _, guard in ipairs({ v, { type = 'NOT', value = v } }) do
        local selected

        local result = a:EvaluateRotationSequence({
            rotation = {
                {
                    id = 'guard',
                    type = 'branch',
                    conditions = guard,
                    onTrue = { { id = 'yes', type = 'spell', action = 403 } },
                    onFalse = { { id = 'no', type = 'spell', action = 403 } },
                },
            },
        }, function(n) return a:evaluateConditionResult(n) end, function(n)
            selected = n.id
        end)

        assert(result.status == 'unavailable' and selected == nil, 'unknown selected a branch')
    end
end

local function known(a, v, yes)
    assert(a:validateCondition(v, 0))
    assert(a:evaluateConditionResult(v).status == (yes and 'match' or 'no-match'))
    assert(a:evaluateConditionResult({ type = 'NOT', value = v }).status == (yes and 'no-match' or 'match'))
end

test('nil required presence remains unavailable in actual authored engine groups and both branch arms', function()
    local _, a, s = fixture()
    s.exists = nil
    unknown(a, node(), 'unit-data-unavailable')

    for _, v in ipairs(s.trace) do
        assert(v == 'exists', 'nil presence queried range')
    end
end)

test('known absence remains false and lazily skips native range and optional providers', function()
    for _, legacy in ipairs({ false, true }) do
        local _, a, s = fixture(legacy)
        s.exists = false
        known(a, node(), false)

        for _, v in ipairs(s.trace) do
            assert(v == 'exists')
        end
    end
end)

test('normal true and historical numeric one preserve selected native args order and decisions', function()
    for _, legacy in ipairs({ false, true }) do
        for _, present in ipairs({ true, 1 }) do
            for _, inRange in ipairs({ false, true }) do
                local _, a, s = fixture(legacy)
                s.exists = present
                s.inRange = inRange
                known(a, node(), not inRange)

                assert(
                    table.concat(s.trace, ',')
                        == (legacy and 'exists,metadata,range,exists,metadata,range' or 'exists,range,exists,range')
                )
            end
        end
    end
end)

test('existing missing failed restricted and malformed guards remain unavailable', function()
    local f, a, s = fixture()
    s.throws = true
    unknown(a, node(), 'api-error')
    s.throws = nil
    f.env.UnitExists = nil
    unknown(a, node(), 'missing-api')
    f.env.UnitExists = function() return s.exists end
    local opaque = {}
    s.exists = opaque
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    unknown(a, node(), 'restricted-value')

    for _, v in ipairs({ 0, 2, 'true', {} }) do
        s.exists = v
        unknown(a, node(), 'invalid-api-result')
    end
end)

test('existing range estimate fallback and uncertain result retain their selected provider meaning', function()
    local f, a, s = fixture()
    s.inRange = nil
    local low, high = 5, 8
    local calls = 0

    f.libraries['LibRangeCheck-3.0'].GetRange = function(self, unit, visible, ...)
        assert(
            self == f.libraries['LibRangeCheck-3.0'] and unit == 'target' and visible == true and select('#', ...) == 0
        )

        calls = calls + 1
        return low, high
    end

    known(a, node(), true)
    low, high = 0, 5
    known(a, node(), false)
    low, high = 0, 8
    unknown(a, node(), 'range-uncertain')
    assert(calls > 0)
end)

test('direct evaluation stays uncached and preserves live Platform receiver full tuples and family scope', function()
    local f, a, s = fixture()
    local fn = a.conditionDefinitions.BEYOND_MELEE.evaluate
    local cache = {}
    assert(fn(node(), cache))
    assert(fn(node(), cache))
    assert(table.concat(s.trace, ',') == 'exists,range,exists,range')
    local platform = a.Platform

    platform.IsBeyondMeleeRange = function(self, unit, ...)
        assert(self == platform and unit == 'target' and select('#', ...) == 0)
        return nil, 'range-override', 17
    end

    local x, y, z = fn(node(), cache)
    assert(x == nil and y == 'range-override' and z == 17)
    f.env.WOW_PROJECT_ID = 999
    platform.IsBeyondMeleeRange = function() return true end
    assert(fn(node(), cache) == true, 'added unsupported-family policy')
end)

test('the range module keeps an empty private getter and no private binding', function()
    local _, a = fixture()
    local module = a.builtinSourceModules['Conditions/range.lua']
    assert(type(module) == 'function' and module('anything') == nil)

    for id in pairs(a.builtinFunctions) do
        assert(not id:find('builtin:Conditions/range.lua:', 1, true), 'invented private range binding')
    end
end)

test(
    'current actual editable source has unavailable presence while complete saved raw source retains old semantics',
    function()
        local _, a, s = fixture()
        local source = a:GetBuiltinConditionSource('BEYOND_MELEE')
        assert(source.evaluate == repaired, 'catalog pending BEYOND_MELEE repair')
        local before = a:CopySettingsData(source)
        a:RegisterCondition('COPY', assert(a:CompileCustomCondition('COPY', source)))
        s.exists = nil
        unknown(a, node('COPY'), 'unit-data-unavailable')
        local raw = a:CopySettingsData(source)
        raw.evaluate = inverse(raw.evaluate, true)
        assert(a:FunctionSourceHash(raw) == '8dc16d18', 'complete historical source changed')
        local stored = a:CopySettingsData(raw)
        a.db.global.custom_conditions = { RAW = raw }
        a:RegisterCondition('RAW', assert(a:CompileCustomCondition('RAW', raw)))
        known(a, node('RAW'), false)
        s.exists = false
        known(a, node('COPY'), false)
        s.exists = true
        known(a, node('COPY'), true)
        known(a, node('RAW'), true)

        assert(
            a:SettingsDataEqual(raw, stored)
                and a:SettingsDataEqual(source, before)
                and a.db.global.custom_conditions.RAW == raw
        )
    end
)

finish()
