-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.load('Core/custom_authoring.lua')
    local file = io.open('Core/functions.lua')

    if file then
        file:close()
        f.load('Core/functions.lua')
    end

    f.env.loadstring = function(text, name)
        local fn, why = loadstring(text, name)

        if fn then
            setfenv(fn, f.env)
        end

        return fn, why
    end

    return f, f.addon
end

local function source(code, bindings)
    return {
        description = 'Example utility',
        args = { { name = 'value', type = 'number', description = 'Input value' } },
        returns = { { type = 'number', description = 'Result' } },
        code = code,
        bindings = bindings or {},
    }
end

test('custom utility functions compile on registration and share explicit named bindings', function()
    local f, a = fixture()
    assert(a.InstallCustomFunction, 'function registry missing')
    local compiles = 0
    local compiler = f.env.loadstring

    f.env.loadstring = function(...)
        compiles = compiles + 1
        return compiler(...)
    end

    assert(a:InstallCustomFunction('DOUBLE', source('return value * 2')))
    assert(a:InstallCustomFunction('PLUS', source('return twice(value) + 1', { twice = 'DOUBLE' })))
    local fn = assert(a:ResolveFunctionBinding('PLUS'))
    local before = compiles

    for i = 1, 20 do
        assert(fn(i) == i * 2 + 1)
    end

    assert(compiles == before)
    assert(a.db.global.custom_functions.DOUBLE.code == 'return value * 2')
end)

test('disabled dependencies make all transitive utility consumers unavailable and recover on enable', function()
    local _, a = fixture()
    assert(a:InstallCustomFunction('BASE', source('return value')))
    assert(a:InstallCustomFunction('OUTER', source('return inner(value)', { inner = 'BASE' })))
    local old = a:CopySettingsData(a.db.global.custom_functions.BASE)
    local disabled = a:CopySettingsData(old)
    disabled.disabled = true
    assert(a:InstallCustomFunction('BASE', disabled, old))
    assert(not a:FunctionAvailable('OUTER'))
    assert(not a:ResolveFunctionBinding('OUTER'))
    assert(a:InstallCustomFunction('BASE', old, disabled))
    assert(a:FunctionAvailable('OUTER'))
    assert(a:ResolveFunctionBinding('OUTER')(5) == 5)
end)

test('cycles invalid syntax and stale replacements cannot partially replace the registry', function()
    local _, a = fixture()
    assert(a:InstallCustomFunction('A', source('return value')))
    assert(a:InstallCustomFunction('B', source('return inner(value)', { inner = 'A' })))
    local previous = a:CopySettingsData(a.db.global.custom_functions.A)
    local registry = a.functionRegistry
    assert(not a:InstallCustomFunction('A', source('return other(value)', { other = 'B' }), previous))
    assert(a.functionRegistry == registry and a:ResolveFunctionBinding('B')(3) == 3)
    assert(not a:InstallCustomFunction('A', source('return )'), previous))
    assert(not a:InstallCustomFunction('A', source('return value+1'), {}))
    local broken = source('return )')
    broken.disabled = true
    assert(a:InstallCustomFunction('BROKEN', broken))
    assert(not a:FunctionAvailable('BROKEN'))
end)

test('packaged bindings stay read-only and lazy getters preserve live module state', function()
    local _, a = fixture()
    local number = 3

    assert(a:RegisterBuiltinFunction(
        'builtin:example',
        { description = 'Builtin helper', args = {}, returns = {}, code = 'return number' },
        function() return function() return number end end
    ))

    assert(a:InstallCustomFunction('USE', source('return original() + value', { original = 'builtin:example' })))
    number = 9
    assert(a:ResolveFunctionBinding('USE')(1) == 10)
    assert(not a:InstallCustomFunction('builtin:example', source('return 0')))
end)

test('shared dependency graphs are bounded and malformed saved registries fail closed', function()
    local _, a = fixture()
    a.db.global.custom_functions = { BASE = source('return value') }
    local previous = 'BASE'

    for i = 1, 12 do
        local id = 'L' .. i

        a.db.global.custom_functions[id] = source('return first(value)+second(value)', {
            first = previous,
            second = previous,
        })

        previous = id
    end

    a:InitializeFunctionRegistry()
    local calls = 0
    local available = a.FunctionAvailable

    a.FunctionAvailable = function(self, ...)
        calls = calls + 1
        return available(self, ...)
    end

    assert(a:FunctionAvailable(previous) and calls < 64, 'dependency traversal repeats the same graph exponentially')
    a.db.global.custom_functions = false
    a:InitializeFunctionRegistry()
    assert(not a:FunctionAvailable('BASE'))
end)

test('condition callbacks share utility bindings and disabled dependencies stay unavailable through NOT', function()
    local f, a = fixture()
    f.load('Core/conditions.lua')
    assert(a:InstallCustomFunction('READY', source('return true')))

    local condition = {
        description = 'Helper condition',
        icon = 'Interface\\Icons\\INV_Misc_QuestionMark',
        fields = {},
        valid = 'return true',
        evaluate = 'return ready(1)',
        print = 'return "Helper"',
        widget = '',
        help = '',
        on_register = '',
        on_unregister = '',
        bindings = { ready = 'READY' },
    }

    local definition, why = a:CompileCustomCondition('HELPER', condition)
    assert(definition, why and why.reason)
    a:RegisterCondition('HELPER', definition)
    assert(a:evaluateConditionResult({ type = 'HELPER' }).status == 'match')
    local saved = a:CopySettingsData(a.db.global.custom_functions.READY)
    local disabled = a:CopySettingsData(saved)
    disabled.disabled = true
    assert(a:InstallCustomFunction('READY', disabled, saved))
    assert(a:evaluateConditionResult({ type = 'NOT', value = { type = 'HELPER' } }).status == 'unavailable')
    assert(a:InstallCustomFunction('READY', saved, disabled))
    assert(a:evaluateConditionResult({ type = 'HELPER' }).status == 'match')
end)

test('saved unavailable consumers survive registration and recover lifecycle when helpers are enabled', function()
    local f, a = fixture()
    f.load('Core/conditions.lua')
    f.load('Core/custom_condition_services.lua')
    local helper = source('return true')
    helper.disabled = true
    assert(a:InstallCustomFunction('READY', helper))

    local c = {
        description = 'Dependent',
        icon = 134400,
        fields = {},
        evaluate = 'return ready(1)',
        valid = 'return true',
        print = 'return "Dependent"',
        widget = '',
        help = '',
        on_register = 'addon.registered=(addon.registered or 0)+1',
        on_unregister = 'addon.unregistered=(addon.unregistered or 0)+1',
        bindings = { ready = 'READY' },
    }

    a.db.global.custom_conditions = { DEPENDENT = c }
    assert(a:register_custom_condition('DEPENDENT', c))
    assert(a.conditionDefinitions.DEPENDENT and not a.registered)
    local enabled = a:CopySettingsData(helper)
    enabled.disabled = nil
    assert(a:InstallCustomFunction('READY', enabled, helper))
    assert(a.registered == 1 and a:evaluateConditionResult({ type = 'DEPENDENT' }).status == 'match')
    assert(a:InstallCustomFunction('READY', helper, enabled))

    assert(
        a.unregistered == 1
            and a:evaluateConditionResult({ type = 'NOT', value = { type = 'DEPENDENT' } }).status == 'unavailable'
    )

    local disabled = a:CopySettingsData(c)
    disabled.disabled = true
    assert(a:InstallCustomCondition('DEPENDENT', disabled, a.conditionDefinitions.DEPENDENT, c))
    assert(a.unregistered == 1)
end)

test('wrapper escape text cannot run while compiling a function registry', function()
    local f, a = fixture()
    local injected = source('end, (function() previewExecuted=true end)(), function()')
    local checked = a:ValidateCustomFunctionSource('ESCAPE', injected)
    local registry = a:BuildFunctionRegistry({ ESCAPE = injected })

    assert(
        not checked and not f.env.previewExecuted and registry.ESCAPE.problem and not registry.ESCAPE.fn,
        'function body escaped the compile-only boundary'
    )
end)

test('explicit utility bindings also have a private functions namespace and retain export identities', function()
    local _, a = fixture()
    assert(a:InstallCustomFunction('DOUBLE', source('return value * 2')))
    assert(a:InstallCustomFunction('PLUS', source('return functions.twice(value)+twice(value)', { twice = 'DOUBLE' })))
    assert(a:ResolveFunctionBinding('PLUS')(3) == 12)
    local root = a.db.global.custom_functions.PLUS
    assert(root.bindings.twice == 'DOUBLE' and not a.functions)
end)

test('legacy functions parameters and aliases are never overwritten by the helper namespace', function()
    local _, a = fixture()
    local src = source('return functions(value)', { functions = 'DOUBLE' })
    assert(a:InstallCustomFunction('DOUBLE', source('return value * 2')))
    assert(a:InstallCustomFunction('LEGACY', src))
    assert(a:ResolveFunctionBinding('LEGACY')(3) == 6)
    local argument = source('return functions(value)')
    argument.args = { { name = 'functions', type = 'function' }, { name = 'value', type = 'number' } }
    assert(a:InstallCustomFunction('PARAM', argument))
    assert(a:ResolveFunctionBinding('PARAM')(function(v) return v + 2 end, 3) == 5)
end)

test('qualified utility bindings build private nested namespaces while preserving legacy aliases', function()
    local f, a = fixture()
    assert(a:InstallCustomFunction('DOUBLE', source('return value * 2')))

    local src = source('return myTools.level.ready(value)+functions.twice(value)+twice(value)', {
        ['myTools.level.ready'] = 'DOUBLE',
        twice = 'DOUBLE',
    })

    src.name = 'ready'
    src.namespace = 'custom.group'
    assert(a:InstallCustomFunction('ROOT', src))
    assert(a:ResolveFunctionBinding('ROOT')(3) == 18)

    assert(
        not f.env.myTools and not a.myTools and not f.env.functions,
        'binding prelude installed global namespace tables'
    )

    assert(
        a:FunctionNamespace('ROOT', src) == 'custom.group'
            and a:FunctionQualifiedName('ROOT', src) == 'custom.group.ready'
    )

    local legacy = source('return value')
    legacy.name = 'ready'
    assert(a:FunctionQualifiedName('LEGACY', legacy) == 'functions.ready')
end)

test('namespace paths reject collisions keywords library roots and excessive nesting', function()
    local _, a = fixture()

    assert(
        a:IsFunctionNamespace('custom.tools')
            and not a:IsFunctionNamespace('math')
            and not a:IsFunctionNamespace('tools..ready')
    )

    for _, bindings in ipairs({
        { ['addon.ready'] = 'X' },
        { ['L.ready'] = 'X' },
        { ['math.ready'] = 'X' },
        { ['_G.ready'] = 'X' },
        { ['value.ready'] = 'X' },
        { ['tools.end'] = 'X' },
        { ['tools..ready'] = 'X' },
        { ['tools.ready.more'] = 'X', ['tools.ready'] = 'Y' },
        { tools = 'X', ['tools.ready'] = 'Y' },
        { ready = 'X', ['functions.ready'] = 'Y' },
        { ['a.b.c.d.e.f.g.h.i'] = 'X' },
    }) do
        assert(not a:NormalizeFunctionBindings(bindings, { { name = 'value' } }), 'invalid binding path accepted')
    end

    assert(
        a:NormalizeFunctionBindings({ ready = 'X', ['functions.ready'] = 'X' }),
        'equivalent legacy namespace path rejected'
    )

    local src = source('return value')
    src.namespace = 'tools.end'
    assert(not a:ValidateCustomFunctionSource('INVALID', src))
    src.namespace = 'custom'
    assert(a:ValidateCustomFunctionSource('VALID', src))
end)

test('different namespaces allow identical callable names and binding paths survive metadata edits', function()
    local _, a = fixture()
    local one = source('return value+1')
    one.name = 'ready'
    one.namespace = 'custom.one'
    local two = source('return value+2')
    two.name = 'ready'
    two.namespace = 'custom.two'
    assert(a:InstallCustomFunction('ONE', one))
    assert(a:InstallCustomFunction('TWO', two))

    assert(a:InstallCustomFunction('ROOT', source('return old.one(value)+old.two(value)', {
        ['old.one'] = 'ONE',
        ['old.two'] = 'TWO',
    })))

    local renamed = a:CopySettingsData(one)
    renamed.namespace = 'different'
    renamed.name = 'changed'
    assert(a:InstallCustomFunction('ONE', renamed, one))
    assert(a:ResolveFunctionBinding('ROOT')(3) == 9 and a.db.global.custom_functions.ROOT.bindings['old.one'] == 'ONE')
end)

test('qualified bindings reject legacy callback parameter aliases', function()
    local _, a = fixture()

    local c = {
        description = 'Example',
        icon = 134400,
        fields = {},
        evaluate = 'return candidate.ready(1)',
        valid = 'return true',
        print = 'return "Example"',
        widget = '',
        help = '',
        on_register = '',
        on_unregister = '',
        parameters = { evaluate = { 'candidate', 'cache' } },
        bindings = { ['candidate.ready'] = 'READY' },
    }

    assert(
        not a:ValidateCustomConditionSource('BAD', c, false, true),
        'legacy callback parameter was overwritten by a namespace'
    )

    c.parameters = nil
    assert(a:ValidateCustomConditionSource('VALID', c, false, true), 'unshadowed qualified binding was rejected')

    for _, parameters in ipairs({ false, 'bad', { evaluate = 42 } }) do
        c.parameters = parameters
        local ok, value = pcall(a.ValidateCustomConditionSource, a, 'BAD', c, false, true)
        assert(ok and not value, 'malformed callback parameters threw during namespace validation')
    end
end)

test('builtin module namespaces use actual callable member names without changing stable IDs', function()
    local f, a = fixture()
    f.load('Data/builtin_sources.lua')
    f.load('Core/builtin_sources.lua')
    f.load('Platform/spells.lua')
    local id = 'builtin:Platform/spells.lua:Platform_IsSpellReady'
    local entry = assert(a.builtinFunctions[id])
    assert(entry.source.name == 'IsSpellReady' and entry.source.namespace == 'Platform.spells')

    assert(
        a:FunctionQualifiedName(id, entry.source) == 'Platform.spells.IsSpellReady'
            and a:ResolveFunctionBinding(id) == a.Platform.IsSpellReady
    )

    local utility = assert(a.builtinFunctions['builtin:utils.lua:getCached'])
    assert(a:FunctionQualifiedName('builtin:utils.lua:getCached', utility.source) == 'Functions.cache.getCached')
end)

finish()
