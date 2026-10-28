local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local a = f.addon
    f.env.C_CVar = { GetCVar = function() return '40' end }
    f.load('Platform/range.lua')
    f.load('Core/conditions.lua')
    f.load('Conditions/common.lua')
    f.load('Conditions/spatial.lua')
    f.load('Data/builtin_sources.lua')
    f.load('Core/builtin_sources.lua')
    f.load('Core/custom_authoring.lua')
    f.load('Core/function_data.lua')

    f.env.loadstring = function(text, name)
        local fn, why = loadstring(text, name)

        if fn then
            setfenv(fn, f.env)
        end

        return fn, why
    end

    return f, a
end

local ids = { compare = 'builtin:utils.lua:compare', isin = 'builtin:utils.lua:isin' }
local oldHashes = { compare = '2ba9a7b2', isin = 'f9e139f6' }

local function consumer(id)
    return {
        name = 'consumer',
        description = 'Legacy consumer',
        args = {},
        returns = { { type = 'boolean' } },
        code = 'return legacy("EQUALS",0,0)',
        bindings = { legacy = id },
    }
end

test(
    'canonical values own the real helper implementations while every legacy API and binding remains callable',
    function()
        local f, a = fixture()
        local values = assert(a.Functions and a.Functions.values, 'canonical values owner missing')

        for name, id in pairs(ids) do
            assert(a[name] == values[name] and a:ResolveFunctionBinding(id) == values[name], 'legacy helper detached')
            assert(a.builtinSourceModules['utils.lua'](name) == values[name], 'legacy module getter disappeared')
            local record = assert(a.builtinFunctions[id])
            assert(record.source.namespace == 'Functions.values' and record.source.name == name)

            assert(
                a.BuiltinSourceCatalog.modules['Functions/values.lua'].bindings[name].bindingID == id,
                'stable ID changed with physical ownership'
            )

            assert(
                not a.builtinFunctions['builtin:Functions/values.lua:' .. name],
                'ownership move created a second public identity'
            )

            assert(
                record.source.code:find('%S') and not record.source.code:find('addon.Functions', 1, true),
                'source became a forwarding implementation'
            )
        end

        local legacy = consumer(ids.compare)
        legacy.code = 'return addon.compare("EQUALS",false,false) and addon.isin({key=false},"key")'
        legacy.bindings = {}
        assert(a:InstallCustomFunction('LEGACY_ADDON_API', legacy))
        assert(a:ResolveFunctionBinding('LEGACY_ADDON_API')())
        assert(not f.env.Functions, 'canonical owner leaked into the client global environment')
    end
)

test('all comparison operators false map members nil arguments and warnings retain their original semantics', function()
    local _, a = fixture()
    local values = assert(a.Functions and a.Functions.values, 'canonical values owner missing')

    local checks = {
        LESSTHAN = { 1, 2, true },
        LESSTHANOREQUALS = { 2, 2, true },
        GREATERTHAN = { 3, 2, true },
        GREATERTHANOREQUALS = { 2, 2, true },
        EQUALS = { false, false, true },
        NOTEQUALS = { false, true, true },
        DIVISIBLE = { 6, 3, true },
    }

    for operator, args in pairs(checks) do
        assert(
            values.compare(operator, args[1], args[2]) == args[3] and a.compare(operator, args[1], args[2]) == args[3]
        )
    end

    assert(
        values.compare('EQUALS', nil, nil) and values.isin({ present = false }, 'present') and not values.isin({}, nil)
    )

    local warning

    a.warn = function(_, format, operator)
        warning = { format, operator }
    end

    assert(values.compare('UNKNOWN', 1, 2) == nil and warning[1] == 'Invalid Operator %s' and warning[2] == 'UNKNOWN')
end)

test('real authored condition callbacks export qualified private helper dependencies and clone equivalently', function()
    local f, a = fixture()
    local source = assert(a:GetBuiltinConditionSource('DISTANCE_COUNT'))

    assert(
        source.valid:find('Functions.values.isin', 1, true) and source.evaluate:find(
            'Functions.values.compare',
            1,
            true
        ),
        'authored callbacks still use the addon utility namespace'
    )

    assert(
        source.bindings['Functions.values.isin'] == ids.isin
            and source.bindings['Functions.values.compare'] == ids.compare
    )

    assert(source.bindings.Functions == nil, 'collector captured an opaque namespace table')
    local copy = assert(a:CompileCustomCondition('COPY_DISTANCE_COUNT', source))
    local value = { enemy = true, distance = 10, operator = 'EQUALS', value = 0 }

    assert(
        copy.valid(0, value) and copy.evaluate(value, {}) == a.conditionDefinitions.DISTANCE_COUNT.evaluate(value, {})
    )

    value.operator = 'UNKNOWN'
    assert(copy.valid(0, value) == false)
    assert(not f.env.Functions and not f.env.functions, 'compiled bindings leaked namespace globals')

    for name, id in pairs(ids) do
        local record = a.builtinFunctions[id]
        assert(a:InstallCustomFunction('COPY_' .. name, a:CopySettingsData(record.source)))
    end

    assert(a:ResolveFunctionBinding('COPY_compare')('EQUALS', false, false))
    assert(a:ResolveFunctionBinding('COPY_isin')({ key = false }, 'key'))
end)

test(
    'collector rejects a declared qualified helper whose actual implementation does not match its stable identity',
    function()
        local broken = {
            new = function(...)
                local f = F.new(...)
                local load = f.load

                f.load = function(path)
                    local result = load(path)

                    if path == 'Conditions/spatial.lua' then
                        f.addon.builtinCallbackBindings[path]['Functions.values.compare'] = ids.isin
                    end

                    return result
                end

                return f
            end,
        }

        local env = setmetatable({
            dofile = function(path)
                if path == 'tests/fixtures/addon.lua' then
                    return broken
                end

                return dofile(path)
            end,
            print = function() end,
        }, { __index = _G })

        local tool = assert(loadfile('tools/collect_builtin_sources.lua'))
        setfenv(tool, env)
        local ok, why = pcall(tool)

        assert(
            not ok and tostring(why):find('qualified callback binding identity mismatch', 1, true),
            'collector accepted an alias-only or mismatched namespace'
        )
    end
)

test(
    'collector rejects duplicate public registry identities even when they reference the same implementation',
    function()
        local env = setmetatable({
            dofile = function(path)
                local result = dofile(path)

                if path == 'tools/public_helpers.lua' then
                    result.duplicateCompare = result.compare
                end

                return result
            end,
            print = function() end,
        }, { __index = _G })

        local tool = assert(loadfile('tools/collect_builtin_sources.lua'))
        setfenv(tool, env)
        local ok, why = pcall(tool)

        assert(
            not ok and tostring(why):find('duplicate public helper identity', 1, true),
            'collector accepted ambiguous public metadata for one registry identity'
        )
    end
)

test(
    'exact previous namespace hashes import without weakening executable documentation or dependency checks',
    function()
        local _, a = fixture()

        for name, id in pairs(ids) do
            local record = a.builtinFunctions[id]
            local old = a:CopySettingsData(record.source)
            old.namespace = 'utils'

            assert(
                a:FunctionSourceHash(old) == oldHashes[name],
                'migration changed the historical source body or documentation'
            )

            local root = consumer(id)

            if name == 'isin' then
                root.code = 'return legacy({key=false},"key")'
            end

            local bundle = assert(a:BuildFunctionBundle('function', 'LEGACY_' .. name, root, false))
            assert(#bundle.requirements == 1)
            bundle.requirements[1].hash = oldHashes[name]
            local plan = assert(a:PlanFunctionBundleImport(bundle))
            assert(plan.valid, 'unchanged legacy dependency was rejected')

            for _, field in ipairs({ 'code', 'description', 'args', 'returns', 'bindings', 'name' }) do
                local changed = a:CopySettingsData(old)

                if field == 'code' then
                    changed.code = changed.code .. '\nreturn false'
                elseif field == 'description' then
                    changed.description = changed.description .. ' changed'
                elseif field == 'args' then
                    changed.args[1].description = 'changed argument'
                elseif field == 'returns' then
                    changed.returns[1].description = 'changed return'
                elseif field == 'name' then
                    changed.name = 'differentName'
                else
                    changed.bindings = { unexpected = 'CUSTOM' }
                end

                local invalid = a:CopySettingsData(bundle)
                invalid.requirements[1].hash = a:FunctionSourceHash(changed)

                assert(
                    not assert(a:PlanFunctionBundleImport(invalid)).valid,
                    'hash compatibility ignored changed ' .. field
                )
            end

            local legacy = a:CopySettingsData(old)
            legacy.namespace = nil
            local preNamespace = a:CopySettingsData(bundle)
            preNamespace.requirements[1].hash = a:FunctionSourceHash(legacy)
            assert(assert(a:PlanFunctionBundleImport(preNamespace)).valid, 'pre-namespace legacy requirement regressed')
            assert(a:ApplyFunctionBundleImport(plan))
            assert(a:ResolveFunctionBinding('LEGACY_' .. name)())
        end
    end
)

test(
    'Distance protects the canonical cache function reference and preserves both range results across real clones',
    function()
        local f, a = fixture()
        local reads = { exists = 0, range = 0 }
        local bounds = { nil, 10 }
        local checker = f.libraries['LibRangeCheck-3.0']

        f.env.UnitExists = function(unit)
            assert(unit == 'target')
            reads.exists = reads.exists + 1
            return true
        end

        checker.GetRange = function(self, unit)
            assert(self == checker and unit == 'target')
            reads.range = reads.range + 1
            return bounds[1], bounds[2]
        end

        local source = assert(a:GetBuiltinConditionSource('DISTANCE'))

        assert(
            source.evaluate:find('pcall(Functions.cache.getCached, cache, rcf, value.unit)', 1, true),
            'protected cache reference still uses legacy API'
        )

        local copy = assert(a:CompileCustomCondition('COPY_DISTANCE', source))
        local previous = a:CopySettingsData(source)
        previous.evaluate = previous.evaluate:gsub('Functions%.cache%.getCached', 'addon.getCached')
        local old = assert(a:CompileCustomCondition('OLD_DISTANCE', previous))
        local value = { unit = 'target', value = 10 }
        local cache = {}

        for _, definition in ipairs({ a.conditionDefinitions.DISTANCE, copy, old }) do
            assert(definition.evaluate(value, cache) == true)
        end

        assert(
            reads.exists == 1 and reads.range == 1,
            'canonical reference split cache identity or dropped the second nil-prefixed result'
        )

        bounds = { 5, 15 }

        for _, definition in ipairs({ a.conditionDefinitions.DISTANCE, copy, old }) do
            assert(definition.evaluate(value, {}) == false)
        end

        bounds = { nil, 10 }
        assert(copy.evaluate(value, {}) == true)
        assert(a:FunctionSourceHash(a.builtinFunctions['builtin:Conditions/spatial.lua:rcf'].source) == 'a7ab75e4')

        assert(
            a:FunctionSourceHash(a.builtinFunctions['builtin:Conditions/spatial.lua:protectedRead'].source)
                == 'cc49d134'
        )
    end
)

test('Distance canonical protected cache preserves unavailable reasons and negation on failed observations', function()
    local f, a = fixture()
    f.env.UnitExists = function() return true end
    local state = {}
    local opaque = {}
    f.env.canaccessvalue = function(value) return not rawequal(value, opaque) end

    f.libraries['LibRangeCheck-3.0'].GetRange = function()
        if state.fail then
            error('range failed')
        end

        return nil, state.upper
    end

    local copy = assert(a:CompileCustomCondition('COPY_DISTANCE', a:GetBuiltinConditionSource('DISTANCE')))
    a:RegisterCondition('COPY_DISTANCE', copy)

    for _, entry in ipairs({
        { upper = nil, reason = 'range-unavailable' },
        { upper = opaque, reason = 'restricted-value' },
        { upper = -1, reason = 'invalid-range-result' },
        { fail = true, reason = 'range-provider-error' },
    }) do
        state = entry

        for _, definition in ipairs({ a.conditionDefinitions.DISTANCE, copy }) do
            local result, why = definition.evaluate({ unit = 'target', value = 10 }, {})
            assert(result == nil and why == entry.reason)
        end

        assert(
            a:evaluateConditionResult({
                type = 'NOT',
                value = { type = 'COPY_DISTANCE', unit = 'target', value = 10 },
            }).status == 'unavailable'
        )
    end
end)

finish()
