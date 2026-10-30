-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Historical canonical-consumer regression. Current bounded forecast behavior
-- is exercised by health_forecast_conditions.lua; restore only its two bodies.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local inverse, oldBodies, newBodies = dofile('tests/fixtures/restore_trend_consumer_qualifiers.lua')
local restoreForecast = dofile('tests/fixtures/restore_health_forecast_repairs.lua')
local branches = dofile('tests/fixtures/catalog_inventory.lua').branches
local tags = { 'TT_HEALTH', 'TT_HEALTHPCT' }

local function fixture(case)
    local f = F.new(unpack(case and case[1] or { 11, 2, 'MAGE' }))
    local a, e = f.addon, f.env

    local s = {
        unit = 'target',
        exists = true,
        guid = 'GUID-target',
        health = 70,
        maximum = 100,
        calls = {},
        now = 100,
    }

    local function call(name, ...)
        assert(select('#', ...) == 1 and select(1, ...) == s.unit, 'forecast native actor or arity changed')
        s.calls[#s.calls + 1] = name

        if s.throw == name then
            error('NATIVE_TREND_CONSUMER_ERROR')
        end
    end

    e.UnitExists = function(...)
        call('exists', ...)
        return s.exists
    end

    e.UnitGUID = function(...)
        call('guid', ...)
        return s.guid
    end

    e.UnitHealth = function(...)
        call('health', ...)
        return s.health
    end

    e.UnitHealthMax = function(...)
        call('maximum', ...)
        return s.maximum
    end

    e.GetTime = function(...)
        assert(select('#', ...) == 0)
        return s.now
    end

    s.history = {
        damage = { { time = 100, value = 10 }, { time = 99, value = 12 }, { time = 97, value = 8 } },
        heals = { { time = 100, value = 2 }, { time = 97, value = 3 } },
    }

    a.damageHistory = { [s.guid] = s.history }
    a.db.profile.damage_history = 10

    for _, path in ipairs({
        'Diagnostics/errors.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua', 'Conditions/stats.lua', 'Data/builtin_sources.lua', 'Core/builtin_sources.lua',
        'Core/custom_authoring.lua', 'Core/function_data.lua'
    }) do
        if path == 'Conditions/stats.lua' then
            local h = assert(io.open(path))
            local text = h:read('*a')
            h:close()
            local chunk = assert(loadstring(restoreForecast(text), '@' .. path))
            setfenv(chunk, e)
            chunk('rotationmaster', a)
        else
            f.load(path)

            if path == 'Data/builtin_sources.lua' then
                for _, tag in ipairs(tags) do
                    local callback = assert(a.BuiltinSourceCatalog.conditions[tag].callbacks.evaluate)
                    callback.code = restoreForecast(callback.code, tag, true)
                end
            end
        end
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

local function node(tag, health, seconds, mode)
    return {
        type = tag,
        unit = 'target',
        operator = 'EQUALS',
        health = tag == 'TT_HEALTHPCT' and (health or 50) / 100 or health or 50,
        value = seconds or 2,
        mode = mode,
    }
end

local function pack(...)
    return { n = select('#', ...), ... }
end

local function poison(a)
    a.calculate_trend = function()
        error('LEGACY_TREND_ALIAS_MUST_NOT_RUN')
    end
end

local function valid(a, v)
    assert(a.conditionDefinitions[v.type].valid(0, v), 'fixture must pass real forecast validator')
end

local function spy(a, s, mode, trend, seconds)
    a.Functions.trends.calculate = function(...)
        assert(
            select('#', ...) == 4 and select(1, ...) == s.history and select(2, ...) == nil,
            'canonical trend receiver/history/window changed'
        )

        assert(
            select(3, ...) == (mode == 'noheals') and select(4, ...) == (mode == 'nodmg'),
            'stream mode flags changed'
        )

        s.trends = (s.trends or 0) + 1
        return trend, seconds
    end
end

local function sourceOf(fn)
    local info = debug.getinfo(fn, 'S')
    local lines = {}

    for line in io.lines(info.source:sub(2)) do
        lines[#lines + 1] = line
    end

    return '\n' .. table.concat(lines, '\n', info.linedefined + 1, info.lastlinedefined - 1) .. '\n'
end

test('both forecast callbacks use live canonical four-argument trend dispatch on every registration branch', function()
    for _, case in ipairs(branches) do
        local _, a, s = fixture(case)
        poison(a)

        for _, tag in ipairs(tags) do
            for _, mode in ipairs({ 'both', 'noheals', 'nodmg', 'future' }) do
                local v = node(tag, 50, 2, mode)
                valid(a, v)
                spy(a, s, mode, -10, 3)
                local result = pack(a.conditionDefinitions[tag].evaluate(v, {}))
                assert(result.n == 1 and result[1] == true, 'canonical forecast dispatch failed')
                spy(a, s, mode, -5, 3)
                v.value = 4

                assert(
                    a.conditionDefinitions[tag].evaluate(v, {}) == true,
                    'canonical member was captured instead of live'
                )
            end
        end
    end
end)

test('forecast direction arithmetic truthiness age gate and single-result returns stay exact', function()
    local cases = {
        { -10, 3, 50, 2, true },
        { 10, 3, 90, 2, true },
        { 10, 3, 50, 0, true },
        { -10, 3, 90, 0, true },
        { 0, 3, 50, 0, true },
        { false, 3, 50, 0, false },
        { nil, 3, 50, 0, false },
        { -10, 2, 50, 2, false },
        { -10, 2.1, 50, 2, true },
        { 0 / 0, 3, 50, 0, true },
    }

    for _, tag in ipairs(tags) do
        local _, a, s = fixture()
        poison(a)

        for _, case in ipairs(cases) do
            local v = node(tag, case[3], case[4])
            valid(a, v)
            spy(a, s, nil, case[1], case[2])
            local r = pack(a.conditionDefinitions[tag].evaluate(v, {}))
            assert(r.n == 1 and r[1] == case[5], 'forecast arithmetic/gate changed')
        end

        for _, rate in ipairs({ -10, 0 }) do
            spy(a, s, nil, rate, nil)

            assert(
                not pcall(a.conditionDefinitions[tag].evaluate, node(tag), {}),
                'nil required seconds became a fallback'
            )
        end

        spy(a, s, nil, false, nil)
        assert(a.conditionDefinitions[tag].evaluate(node(tag), {}) == false, 'false trend began reading unused seconds')
    end
end)

test('forecast shortcuts keep observation order maximum laziness and caller cache ownership', function()
    for _, tag in ipairs(tags) do
        local _, a, s = fixture()
        poison(a)
        spy(a, s, nil, -10, 3)
        local eval = a.conditionDefinitions[tag].evaluate
        local v = node(tag)
        valid(a, v)
        local cache = {}

        assert(
            eval(v, cache) and eval(v, cache) and s.trends == 2,
            'trend acquired a new cache or stopped running per callback'
        )

        local expected = tag == 'TT_HEALTH' and 'exists,guid,health' or 'exists,guid,health,maximum'
        assert(table.concat(s.calls, ',') == expected, 'native order/shared cache changed')

        assert(
            eval(v, {}) and table.concat(s.calls, ',') == expected .. ',' .. expected,
            'new caller cache reused native observations'
        )

        s.calls = {}
        s.trends = 0
        s.health = 50
        v.value = 0
        assert(eval(v, {}) == true and s.trends == 0, 'equal-health shortcut queried trend')
        s.health = 70
        s.exists = false
        s.calls = {}
        assert(eval(v, {}) == false and table.concat(s.calls, ',') == 'exists', 'known absence queried more facts')
        s.exists = true
        s.guid = nil
        s.calls = {}
        assert(eval(v, {}) == false and table.concat(s.calls, ',') == 'exists,guid', 'missing identity queried health')
    end

    local _, a, s = fixture()
    poison(a)
    spy(a, s, nil, 10, 3)
    local v = node('TT_HEALTH', -10, 2)
    valid(a, v)

    assert(
        a.conditionDefinitions.TT_HEALTH.evaluate(v, {}) == true
            and table.concat(s.calls, ',') == 'exists,guid,health,maximum',
        'deficit target/maximum order changed'
    )
end)

test('percentage forecast retains exact optional RealMobHealth dot-call and native fallbacks', function()
    local f, a, s = fixture()
    poison(a)
    spy(a, s, nil, -15, 3)

    f.env.RealMobHealth = {
        GetUnitHealth = function(...)
            assert(select('#', ...) == 1 and select(1, ...) == 'target', 'RealMobHealth receiver changed')
            s.calls[#s.calls + 1] = 'realmob'
            return 80, 100
        end,
    }

    assert(
        a.conditionDefinitions.TT_HEALTHPCT.evaluate(node('TT_HEALTHPCT'), {}) == true
            and table.concat(s.calls, ',') == 'exists,guid,realmob',
        'optional observation order changed'
    )

    s.calls = {}
    spy(a, s, nil, -10, 3)

    f.env.RealMobHealth.GetUnitHealth = function()
        s.calls[#s.calls + 1] = 'realmob'
        return false, 100
    end

    assert(
        a.conditionDefinitions.TT_HEALTHPCT.evaluate(node('TT_HEALTHPCT'), {}) == true
            and table.concat(s.calls, ',') == 'exists,guid,realmob,health',
        'partial optional tuple changed fallback'
    )
end)

test('forecast canonical and native errors propagate without invented availability or extra results', function()
    for _, tag in ipairs(tags) do
        local _, a, s = fixture()
        poison(a)
        local v = node(tag)
        valid(a, v)

        a.Functions.trends.calculate = function()
            error('CANONICAL_TREND_CONSUMER_ERROR')
        end

        local ok, why = pcall(a.conditionDefinitions[tag].evaluate, v, {})
        assert(not ok and tostring(why):find('CANONICAL_TREND_CONSUMER_ERROR', 1, true), 'helper error changed')
        local r = a:evaluateConditionResult(v)

        assert(
            r.status == 'unavailable' and r.reason == 'condition-callback-error',
            'existing callback-error policy changed'
        )

        s.throw = 'health'
        ok, why = pcall(a.conditionDefinitions[tag].evaluate, v, {})
        assert(not ok and tostring(why):find('NATIVE_TREND_CONSUMER_ERROR', 1, true), 'native error changed')
    end
end)

test('actual trend services retain their exact formulas bodies tuples and three live legacy round calls', function()
    local f, a, s = fixture()
    local current, old = a.Functions.trends.calculate, a.Functions.trends.calculateOld

    assert(
        a:FunctionSourceHash(sourceOf(current)) == '49b34bf5' and a:FunctionSourceHash(sourceOf(old)) == 'ced8840f',
        'trend helper bodies changed'
    )

    assert(current == a.calculate_trend and old == a.calculate_trend_old, 'direct legacy aliases changed')
    local round = a.round
    local rounds = 0

    a.Functions.values.round = function()
        error('canonical round replaced legacy authority')
    end

    a.round = function(...)
        assert(select('#', ...) == 1)
        rounds = rounds + 1
        return round(...)
    end

    local r = pack(current(s.history))

    assert(
        r.n == 2 and math.abs(r[1] + 223 / 34) < 1e-10 and r[2] == 3 and rounds == 5,
        'current formula/round arity changed'
    )

    r = pack(old({ { time = 100, value = 80, max = 100 } }))
    assert(r.n == 1 and r[1] == 0 and rounds == 6, 'legacy algorithm round authority changed')
    poison(a)
    local v = node('TT_HEALTH', 50, 4)
    v.operator = 'LESSTHAN'

    assert(
        a.conditionDefinitions.TT_HEALTH.evaluate(v, {}) == true,
        'actual canonical trend formula no longer feeds forecast'
    )

    a.round = function()
        error('LIVE_LEGACY_ROUND')
    end

    for _, fn in ipairs({ current, old }) do
        local ok, why = pcall(fn, fn == current and s.history or { { time = 100, value = 80, max = 100 } })
        assert(not ok and tostring(why):find('LIVE_LEGACY_ROUND', 1, true))
    end
end)

if arg[1] ~= '--runtime-only' then
    test(
        'historical restored actual source copies use canonical trend while archived exact raw sources retain legacy authority',
        function()
            for _, tag in ipairs(tags) do
                local _, a, s = fixture()
                local source = assert(a:GetBuiltinConditionSource(tag))
                assert(source.evaluate == newBodies[tag], 'current forecast source catalog stale')
                local copy = assert(a:CompileCustomCondition('COPY_' .. tag, source))
                local rawSource = a:CopySettingsData(source)
                rawSource.evaluate = oldBodies[tag]
                local hashes = { TT_HEALTH = '3c6d7b43', TT_HEALTHPCT = '6d896c48' }
                assert(a:FunctionSourceHash(rawSource) == hashes[tag], 'prequalification archived source changed')
                local before = a:CopySettingsData(rawSource)
                a.db.global.custom_conditions = { ['RAW_' .. tag] = rawSource }
                local raw = assert(a:CompileCustomCondition('RAW_' .. tag, rawSource))
                local v = node(tag)

                a.calculate_trend = function(...)
                    assert(
                        select('#', ...) == 4
                            and select(1, ...) == s.history
                            and select(2, ...) == nil
                            and select(3, ...) == false
                            and select(4, ...) == false
                    )

                    return -10, 3
                end

                a.Functions.trends.calculate = function()
                    error('raw source crossed canonical boundary')
                end

                assert(raw.evaluate(v, {}) == true)
                poison(a)
                spy(a, s, nil, -10, 3)

                assert(
                    copy.evaluate(v, {}) and a.conditionDefinitions[tag].evaluate(v, {}),
                    'current copied consumer followed legacy alias'
                )

                spy(a, s, nil, -5, 3)
                v.value = 4
                assert(copy.evaluate(v, {}), 'new copy captured canonical member')
                local ok, why = pcall(raw.evaluate, v, {})

                assert(
                    not ok and tostring(why):find('LEGACY_TREND_ALIAS_MUST_NOT_RUN', 1, true),
                    'raw alias lookup was rewritten'
                )

                assert(
                    a:SettingsDataEqual(before, rawSource)
                        and a.db.global.custom_conditions['RAW_' .. tag] == rawSource,
                    'archived saved source mutated'
                )

                local expectedBindings = source.bindings

                assert(
                    a:SettingsDataEqual(expectedBindings, rawSource.bindings)
                        and a:SettingsDataEqual(source.fields, rawSource.fields)
                        and a:SettingsDataEqual(source.parameters, rawSource.parameters),
                    'source metadata/bindings changed'
                )
            end
        end
    )
end

finish()
