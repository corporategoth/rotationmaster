-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Owned parsers capture standard match/sub at load; later native method
-- mutations no longer define their grammar or invalidate their index.
local pass, fail = 0, 0

local function test(name, fn)
    local ok, why = pcall(fn)

    if ok then
        pass = pass + 1
        print('PASS ' .. name)
    else
        fail = fail + 1
        print('FAIL ' .. name .. ': ' .. tostring(why))
    end
end

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local function once(text, old, new)
    local a, b = text:find(old, 1, true)
    assert(a, 'test fixture anchor missing')
    assert(not text:find(old, b + 1, true), 'test fixture anchor repeated')
    return text:sub(1, a - 1) .. new .. text:sub(b + 1)
end

local function copy(t)
    local r = {}

    for k, v in pairs(t) do
        r[k] = v
    end

    return r
end

local function equal(a, b)
    assert(type(a) == type(b))

    if type(a) ~= 'table' then
        assert(a == b, tostring(a) .. ' / ' .. tostring(b))
        return
    end

    for k, v in pairs(a) do
        equal(v, b[k])
    end

    for k in pairs(b) do
        assert(a[k] ~= nil, 'extra field ' .. tostring(k))
    end
end

local function count(fn, callback)
    local calls = 0
    local hook, mask, step = debug.gethook()
    local compiling = jit and jit.status()

    if jit then
        jit.off()
        jit.flush()
    end

    debug.sethook(function(event)
        if event == 'call' and debug.getinfo(2, 'f').func == fn then
            calls = calls + 1
        end
    end, 'c')

    local ok, value = pcall(callback)

    if hook then
        debug.sethook(hook, mask, step)
    else
        debug.sethook()
    end

    if compiling then
        jit.on()
    end

    assert(ok, value)
    return calls, value
end

-- Reuse the actual current main/Shaman fixture. Only initialization is changed:
-- the fixture's native raw slots are installed first, then global string is
-- copied before modules load. Native getmetatable and literal methods stay real.
local fixture = read('tests/fixtures/rotation_execution.lua')

fixture = once(
    fixture,
    "local startup=read('tests/startup.lua')",
    [=[local startup=read('tests/startup.lua')
startup=once(startup,'    env._G = env','    env._G = env\n    do local methods={};for k,v in pairs(string)do methods[k]=v end;env.string=methods end')]=]
)

fixture = once(
    fixture,
    "'math','table','string'})do assert(rawget(c.e,key)==_G[key]",
    "'math','table'})do assert(rawget(c.e,key)==_G[key]"
)

local make = assert(loadstring(fixture, '@distinct-native-string-fixture'))()
local nativeMeta = getmetatable('')
local nativeMethods = rawget(nativeMeta, '__index')
assert(type(nativeMethods) == 'table', 'host requires table-valued native string methods')

local function main(target, old)
    local c = make({ target = target }, old)

    assert(
        c.e.string ~= nativeMethods
            and rawget(nativeMeta, '__index') == nativeMethods
            and c.e.getmetatable == getmetatable
    )

    return c
end

for _, target in ipairs({ false, true }) do
    test('actual main distinct global string reuses warmed index target=' .. tostring(target), function()
        local c = main(target)

        local n = count(c.a.RotationData.IndexRotationSteps, function()
            for i = 1, 3 do
                c.tick()
            end
        end)

        assert(n == 0, 'distinct global string forces warm public index calls=' .. n .. '; expected0')
    end)
end

local function selected()
    return { status = 'match' }
end

local function visit()
    return false
end

local function body()
    return { rotation = { { id = 'literal-methods', type = 'spell', conditions = {} } } }
end

test('public sequence stays fresh with a distinct global string library', function()
    local c = main(true)
    local a = c.a
    local b = body()

    assert(
        count(a.RotationData.IndexRotationSteps, function()
            for i = 1, 2 do
                assert(a:EvaluateRotationSequence(b, selected, visit).status == 'selected')
            end
        end) == 2
    )

    assert(
        count(a.RotationData.CheckPortable, function()
            for i = 1, 2 do
                assert(a.RotationData.IndexRotationSteps(b))
            end
        end) == 2
    )
end)

local function unit()
    local e = copy(_G)
    e._G = e
    e.string = copy(nativeMethods)
    local a = { db = { profile = {} } }

    for _, path in ipairs({ 'Data/plain.lua', 'Data/rotation_tree.lua', 'Core/rotation_sequence.lua' }) do
        local fn = assert(loadstring(read(path), '@' .. path))
        setfenv(fn, e)
        fn('rotationmaster', a)
    end

    local before, run

    a:BindRotationSequenceReader(function(b, r)
        before, run = b, r
    end)

    local function invoke(b, ev, vi)
        local proof = before(a)
        local method = a.EvaluateRotationSequence
        return run(a, proof, method, b, ev or selected, vi or visit)
    end

    return a, e, invoke
end

local function warm()
    local a, e, invoke = unit()
    local b = body()
    assert(invoke(b).status == 'selected')

    assert(
        count(a.RotationData.IndexRotationSteps, function()
            invoke(b)
        end) == 0,
        'distinct-table fixture did not warm'
    )

    return a, e, invoke, b
end

local function mutation(key, value)
    local a, _, invoke, b = warm()
    local container = (key == 'match' or key == 'sub') and nativeMethods or nativeMeta
    local old = rawget(container, key)
    rawset(container, key, value)

    local ok, why = pcall(function()
        assert(
            count(a.RotationData.IndexRotationSteps, function()
                assert(invoke(b).status == 'selected')
            end) == 0,
            'native mutation affected captured parser'
        )
    end)

    rawset(container, key, old)
    assert(ok, why)

    assert(
        count(a.RotationData.IndexRotationSteps, function()
            invoke(b)
            invoke(b)
        end) == 0,
        'native restoration affected captured parser'
    )
end

local originalMatch, originalSub = nativeMethods.match, nativeMethods.sub

test('actual native match replacement leaves captured parser unchanged', function()
    mutation('match', function(...) return originalMatch(...) end)
end)

test('actual native sub replacement leaves captured parser unchanged', function()
    mutation('sub', function(...) return originalSub(...) end)
end)

test('actual native method-table replacement leaves captured parser unchanged', function()
    mutation('__index', copy(nativeMethods))
end)

test('actual native functional method lookup leaves captured parser unchanged', function()
    mutation('__index', function(_, key) return nativeMethods[key] end)
end)

test('actual native protected fake metatable view leaves captured parser unchanged', function()
    mutation('__metatable', { __index = nativeMethods })
end)

test('unconsumed global string replacement or members do not invoke getters or retire cache', function()
    local a, e, invoke, b = warm()

    e.string.match = function()
        error('global string.match invoked')
    end

    e.string.sub = function()
        error('global string.sub invoked')
    end

    e.string = copy(e.string)

    assert(
        count(a.RotationData.IndexRotationSteps, function()
            for i = 1, 3 do
                assert(invoke(b).status == 'selected')
            end
        end) == 0
    )
end)

for _, slot in ipairs({ 'type', 'pairs', 'ipairs', 'getmetatable', 'getfenv', 'table', 'math', 'string' }) do
    test('inherited protected ' .. slot .. ' has exactly public getter count', function()
        local a, e, invoke, b = warm()
        local original = e[slot]
        local reads = 0
        e[slot] = nil

        setmetatable(e, {
            __index = function(_, key)
                if key == slot then
                    reads = reads + 1
                    return original
                end

                return _G[key]
            end,
            __metatable = { __index = _G },
        })

        local actual = invoke(b)
        local got = reads
        reads = 0
        local expected = a:EvaluateRotationSequence(b, selected, visit)
        equal(actual, expected)
        assert(got == reads, slot .. ' proof added getter reads')

        if slot == 'string' then
            assert(reads == 0, 'literal method path consumed global string')
        end
    end)
end

test('changed public index function environment falls back exactly and recovers', function()
    local a, e, invoke, b = warm()
    local fn = a.RotationData.IndexRotationSteps
    local alternative = copy(e)
    local hits = 0

    alternative.type = function(v)
        hits = hits + 1
        return type(v)
    end

    setfenv(fn, alternative)
    local actual

    assert(
        count(fn, function()
            actual = invoke(b)
        end) == 1
    )

    local got = hits
    hits = 0
    local expected = a:EvaluateRotationSequence(b, selected, visit)
    equal(actual, expected)
    assert(got == hits and got > 0)
    setfenv(fn, e)

    assert(
        count(fn, function()
            invoke(b)
            invoke(b)
        end) == 1
    )
end)

test('function-valued native lookup does not control captured parser operations', function()
    local gets = 0
    local original = rawget(nativeMeta, '__index')

    rawset(nativeMeta, '__index', function(_, key)
        gets = gets + 1
        return nativeMethods[key]
    end)

    local ok, why = pcall(function()
        local a, _, invoke = unit()
        local b = body()
        gets = 0

        assert(
            count(a.RotationData.IndexRotationSteps, function()
                invoke(b)
                invoke(b)
            end) == 1
        )

        local got = gets
        gets = 0
        a:EvaluateRotationSequence(b, selected, visit)
        a:EvaluateRotationSequence(b, selected, visit)
        assert(got == gets and got == 0)
    end)

    rawset(nativeMeta, '__index', original)
    assert(ok, why)
end)

print(pass .. ' passed, ' .. fail .. ' failed')

if fail > 0 then
    os.exit(1)
end
