-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local id = 'builtin:Conditions/spatial.lua:protectedRead'

local function fixture()
    local f = F.new()
    local a, e = f.addon, f.env
    local s = { calls = 0, positions = true, units = { player = { x = 0, y = 0 }, party1 = { x = 3, y = 4 } } }

    local function observed()
        s.calls = s.calls + 1
    end

    e.Enum.PowerType.Mana = 0

    e.UnitExists = function(unit)
        observed()
        return s.units[unit] ~= nil
    end

    e.IsInRaid = function()
        observed()
        return false
    end

    e.IsInGroup = function()
        observed()
        return true
    end

    e.UnitPlayerOrPetInParty = function(unit)
        observed()
        return s.units[unit] ~= nil
    end

    e.UnitPosition = function(unit)
        observed()
        local u = s.units[unit]

        if u and s.positions then
            return u.y, u.x, 0, 1
        end
    end

    e.UnitHealth = function()
        observed()
        return 50
    end

    e.UnitHealthMax = function()
        observed()
        return 100
    end

    e.UnitPower = function(_, power)
        assert(power == 0)
        observed()
        return 20
    end

    e.UnitPowerMax = function(_, power)
        assert(power == 0)
        observed()
        return 100
    end

    f.libraries['LibRangeCheck-3.0'].GetRange = function()
        observed()
        return 5, 15
    end

    for _, path in ipairs({
        'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua', 'Core/rotation_sequence.lua',
        'Core/conditions.lua', 'Conditions/common.lua', 'Conditions/spatial.lua', 'Conditions/spatial_stats.lua',
        'Data/builtin_sources.lua', 'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
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

local function read(a)
    return assert(a.Functions.cache.protectedRead, 'private protected cache reader has no cache owner')
end

local function pack(...)
    return { n = select('#', ...), ... }
end

local function equal(a, actual, expected)
    assert(a:SettingsDataEqual(actual, expected), 'tuple arity or value changed')
end

local function copied(a)
    assert(a:InstallCustomFunction('COPY_PRIVATE_PROTECTED', a:CopySettingsData(a.builtinFunctions[id].source)))
    return assert(a:ResolveFunctionBinding('COPY_PRIVATE_PROTECTED'))
end

test('protected cache reader has one physical owner addon-only capture and exact legacy source identity', function()
    local _, a = fixture()
    local fn = read(a)

    assert(
        debug.getinfo(fn, 'S').source == '@Functions/cache.lua',
        'helper body still physically belongs to condition module'
    )

    local capture, value = debug.getupvalue(fn, 1)

    assert(
        capture == 'addon' and value == a and debug.getupvalue(fn, 2) == nil,
        'original global type or pcall became captured'
    )

    local old = a.builtinSourceModules['Conditions/spatial.lua']
    local owner = a.builtinSourceModules['Functions/cache.lua']

    assert(
        old('protectedRead') == fn and owner('protectedRead') == fn and a:ResolveFunctionBinding(id) == fn,
        'owner and original getter differ'
    )

    assert(
        not a.builtinFunctions['builtin:Functions/cache.lua:protectedRead'],
        'ownership move created a duplicate identity'
    )

    local record = assert(a.builtinFunctions[id])
    assert(not record.public and not record.callName and not record.valueBinding)

    assert(
        a:FunctionSourceHash(record.source) == 'cc49d134'
            and record.source.namespace == 'Conditions.spatial'
            and record.source.description == 'Packaged helper from Conditions/spatial.lua.'
    )

    assert(
        record.source.code
            == '\n    if type(method)~="function" then return false,"missing-api" end\n    return pcall(addon.getCached,cache,method,...)\n'
            and next(record.source.bindings) == nil
    )

    assert(
        a.builtinFunctions['builtin:Conditions/spatial.lua:booleanRead'].source.bindings.protectedRead == id,
        'condition helper capture was redirected to a new identity'
    )
end)

test('outer protection preserves zero nil false and trailing tuple slots with shared cache identity', function()
    local _, a = fixture()
    local actual, clone = read(a), copied(a)

    local methods = {
        function() end,
        function() return nil end,
        function() return nil, nil end,
        function() return false, 0 end,
        function() return nil, 'reason', nil, 7, nil end,
    }

    for _, method in ipairs(methods) do
        local calls = 0

        local fn = function(...)
            calls = calls + 1
            assert(select('#', ...) == 3 and select(1, ...) == nil and select(2, ...) == 9 and select(3, ...) == nil)
            return method()
        end

        local cache = {}
        local wanted = pack(pcall(method))
        equal(a, pack(actual(cache, fn, nil, 9, nil)), wanted)
        equal(a, pack(clone(cache, fn, nil, 9, nil)), wanted)
        assert(calls == 1, 'compiled reader split the observation cache')
        equal(a, pack(actual(nil, fn, nil, 9, nil)), wanted)
        equal(a, pack(clone(nil, fn, nil, 9, nil)), wanted)
        assert(calls == 3, 'nil cache unexpectedly memoized the observation')
    end
end)

test('missing methods and thrown observations preserve errors without successful cache entries', function()
    local _, a = fixture()
    local actual, clone = read(a), copied(a)

    for _, fn in ipairs({ actual, clone }) do
        for _, entry in ipairs({ {}, { value = false }, { value = 'GetTime' }, { value = {} } }) do
            equal(a, pack(fn({}, entry.value)), { n = 2, false, 'missing-api' })
        end

        local cache = {}
        local calls = 0

        local failed = function()
            calls = calls + 1
            error('native private observation failed', 0)
        end

        for _ = 1, 2 do
            local result = pack(fn(cache, failed))

            assert(
                result.n == 2
                    and result[1] == false
                    and result[2] == 'native private observation failed'
                    and cache[failed] == nil
            )
        end

        assert(calls == 2, 'failed observation was cached')
    end
end)

test('moved and compiled bodies retain live global type pcall and legacy addon cache dispatch', function()
    local f, a = fixture()
    local actual, clone = read(a), copied(a)
    local types, protections, dispatches = 0, 0, 0
    local nativeType, nativePcall = type, pcall

    local method = function()
        error('legacy cache override must own dispatch')
    end

    a.getCached = function(cache, fn, ...)
        dispatches = dispatches + 1

        assert(
            cache == nil
                and fn == method
                and select('#', ...) == 2
                and select(1, ...) == 'argument'
                and select(2, ...) == nil
        )

        return nil, 'live override', nil
    end

    f.env.type = function(value)
        types = types + 1
        return nativeType(value)
    end

    f.env.pcall = function(fn, ...)
        protections = protections + 1
        assert(fn == a.getCached)
        return nativePcall(fn, ...)
    end

    for _, fn in ipairs({ actual, clone }) do
        local result = pack(fn(nil, method, 'argument', nil))

        assert(
            result.n == 4
                and result[1] == true
                and result[2] == nil
                and result[3] == 'live override'
                and result[4] == nil
        )
    end

    assert(types == 2 and protections == 2 and dispatches == 2, 'global or legacy dispatch became a frozen capture')
end)

test('historical dependency requirements import with the exact old hash and no compatibility relaxation', function()
    local _, a = fixture()
    read(a)

    local source = {
        description = 'Historical private helper consumer',
        args = {},
        returns = {},
        bindings = { helper = id },
        code = 'return helper(nil,function() return nil,"tail",nil end)',
    }

    local bundle = assert(a:BuildFunctionBundle('function', 'SAVED_PRIVATE_CONSUMER', source, false))
    assert(#bundle.requirements == 1 and bundle.requirements[1].id == id and bundle.requirements[1].hash == 'cc49d134')
    local plan = assert(a:PlanFunctionBundleImport(bundle))
    assert(plan.valid and a:ApplyFunctionBundleImport(plan))
    equal(a, pack(a:ResolveFunctionBinding('SAVED_PRIVATE_CONSUMER')()), { n = 4, true, nil, 'tail', nil })

    for _, change in ipairs({
        function(s)
            s.code = s.code .. ' '
        end,
        function(s)
            s.namespace = 'Functions.cache'
        end,
        function(s)
            s.args[1].type = 'string'
        end,
        function(s)
            s.description = s.description .. ' changed'
        end,
    }) do
        local altered = a:CopySettingsData(a.builtinFunctions[id].source)
        change(altered)
        bundle.requirements[1].hash = a:FunctionSourceHash(altered)

        assert(
            not assert(a:PlanFunctionBundleImport(bundle)).valid,
            'private identity ownership relaxed an old requirement hash'
        )
    end
end)

test(
    'all original proximity consumers and compiled scan reuse observations and keep uncertain branches unavailable',
    function()
        local _, a, s = fixture()
        read(a)
        local source = assert(a:GetBuiltinConditionSource('PROXIMITY'))
        local copy = assert(a:CompileCustomCondition('COPY_PRIVATE_SCAN', source))
        local settings = { unit = 'player', distance = 10, operator = 'EQUALS', value = 2 }
        local cache = {}
        local visits = {}

        assert(a.proximity_eval(settings, cache, function(_, unit)
            visits[unit] = (visits[unit] or 0) + 1
        end))

        local observations = s.calls

        assert(
            copy.evaluate(settings, cache)
                and a.conditionDefinitions.PROXIMITY.evaluate(settings, cache)
                and s.calls == observations
                and visits.player == 1
                and visits.party1 == 1
        )

        for _, tag in ipairs({
            'PROXIMITY', 'PROXIMITY_HEALTH', 'PROXIMITY_HEALTH_COUNT', 'PROXIMITY_HEALTHPCT',
            'PROXIMITY_HEALTHPCT_COUNT', 'PROXIMITY_MANA', 'PROXIMITY_MANA_COUNT', 'PROXIMITY_MANAPCT',
            'PROXIMITY_MANAPCT_COUNT'
        }) do
            local value = {
                type = tag,
                unit = 'player',
                distance = 10,
                operator = 'GREATERTHAN',
                value = 0,
                operation = 'minimum',
                healthoperator = 'GREATERTHAN',
                health = .1,
                manaoperator = 'GREATERTHAN',
                mana = .1,
            }

            assert(a:evaluateConditionResult(value).status == 'match', tag .. ' original consumer changed')
            s.positions = false
            assert(a:evaluateConditionResult({ type = 'NOT', value = value }).status == 'unavailable')

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
                    error('uncertain proximity selected a branch')
                end).status == 'unavailable'
            )

            s.positions = true
        end
    end
)

test(
    'actual collector rejects invalid ownership declarations getters and mismapped captured implementations',
    function()
        local function collect(change, manifestChange)
            local wrapped = {
                new = function(...)
                    local f = F.new(...)
                    local load = f.load

                    f.load = function(path)
                        local result = load(path)

                        if path == 'Conditions/spatial.lua' and change then
                            change(f)
                        end

                        return result
                    end

                    return f
                end,
            }

            local env = setmetatable({
                dofile = function(path)
                    if path == 'tests/fixtures/addon.lua' then
                        return wrapped
                    end

                    local value = dofile(path)

                    if path == 'tools/condition_ownership.lua' and manifestChange then
                        manifestChange(value)
                    end

                    return value
                end,
                print = function() end,
            }, { __index = _G })

            local tool = assert(loadfile('tools/collect_builtin_sources.lua'))
            setfenv(tool, env)
            return pcall(tool)
        end

        local function rejects(change, manifestChange, reason)
            local ok, why = collect(change, manifestChange)

            assert(
                not ok and tostring(why):find(reason, 1, true),
                'collector accepted invalid private ownership: ' .. tostring(why)
            )
        end

        local ok, why = collect()
        assert(ok, why)

        for _, mutation in ipairs({
            function(m)
                m.protectedRead.module = 'Conditions/spatial.lua'
            end,
            function(m)
                m.protectedRead.member = 'Functions.cache.getCached'
            end,
            function(m)
                m.protectedRead.bindingID = 'builtin:Functions/cache.lua:protectedRead'
            end,
            function(m)
                m.protectedRead.namespace = 'Functions.cache'
            end,
            function(m)
                m.protectedRead.description = 'Changed helper description'
            end,
            function(m)
                m.protectedRead.captureBindings.other = id
            end,
            function(m)
                m.unreviewed = {}
            end,
            function(m)
                m.protectedRead = nil
            end,
        }) do
            rejects(nil, mutation, 'condition ownership manifest invalid')
        end

        for _, module in ipairs({ 'Functions/cache.lua', 'Conditions/spatial.lua' }) do
            for _, mode in ipairs({ 'missing', 'proxy', 'foreign' }) do
                rejects(function(f)
                    local getter = f.addon.builtinSourceModules[module]
                    local original = f.addon.Functions.cache.protectedRead

                    local replacement = mode == 'proxy' and function(...) return original(...) end
                        or mode == 'foreign' and f.addon.Functions.cache.getCached
                        or nil

                    f.addon.builtinSourceModules[module] = function(name)
                        if name == 'protectedRead' then
                            return replacement
                        end

                        return getter(name)
                    end
                end, nil, 'condition ownership getter mismatch: protectedRead')
            end
        end

        rejects(function(f)
            local getters = f.addon.builtinSourceModules
            local original = f.addon.Functions.cache.protectedRead
            local captured = getters['Conditions/spatial.lua']('booleanRead')
            local changed = false

            for index = 1, 20 do
                local name = debug.getupvalue(captured, index)

                if not name then
                    break
                end

                if name == 'protectedRead' then
                    debug.setupvalue(captured, index, f.addon.Functions.cache.getCached)
                    changed = true
                    break
                end
            end

            assert(changed, 'native protectedRead capture was not found')
            local getter = getters['Conditions/spatial.lua']

            getters['Conditions/spatial.lua'] = function(name)
                if name == 'protectedRead' then
                    return original
                end

                return getter(name)
            end
        end, nil, 'condition ownership capture mismatch: Conditions/spatial.lua:protectedRead')

        rejects(function(f)
            local factory = assert(loadstring(
                'local extra=...;return function(...) return extra(...) end',
                '@Functions/cache.lua'
            ))

            local replacement = factory(f.addon.Functions.cache.protectedRead)
            f.addon.Functions.cache.protectedRead = replacement

            for _, module in ipairs({ 'Functions/cache.lua', 'Conditions/spatial.lua' }) do
                local getter = f.addon.builtinSourceModules[module]

                f.addon.builtinSourceModules[module] = function(name)
                    if name == 'protectedRead' then
                        return replacement
                    end

                    return getter(name)
                end
            end
        end, nil, 'cache ownership capture declaration missing: extra')
    end
)

finish()
