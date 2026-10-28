local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local env = {}

    for k, v in pairs(_G) do
        env[k] = v
    end

    env._G = env
    local a = { db = { profile = {} } }

    for _, path in ipairs({ 'Data/plain.lua', 'Data/rotation_tree.lua', 'Core/rotation_sequence.lua' }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk('rotationmaster', a)
    end

    local run, owned

    a:BindRotationSequenceReader(function(_, invoke, _, method)
        run, owned = invoke, method
    end)

    local data = a.RotationData
    local copy, index, portable = data.CopyData, data.IndexRotationSteps, data.CheckPortable

    local function lease()
        local db, profile = a.db, a.db.profile
        local alive = true

        return function(kind)
            if not alive or a.db ~= db or a.db.profile ~= profile then
                return false
            end
            if kind == 'sequence' or kind == 'pathcopy' or kind == 'iterator' then
                return a.EvaluateRotationSequence == owned
                    and getfenv(owned) == env
                    and data.CopyData == copy
                    and data.IndexRotationSteps == index
                    and data.CheckPortable == portable
                    and env.type == type
                    and env.ipairs == ipairs
                    and env.getfenv == getfenv
            end

            return true
        end,
            function()
                alive = false
            end
    end

    local function invoke(body, guard, evaluate, visit)
        return run(
            a,
            owned,
            a.EvaluateRotationSequence,
            body,
            evaluate or function() return { status = 'match' } end,
            visit or function() return true end,
            guard
        )
    end

    return a, env, invoke, lease, copy, portable
end

local function action(id)
    return { id = id, type = 'spell', action = 403, conditions = {} }
end

local function tree()
    return {
        rotation = {
            { id = 'branch', type = 'branch', conditions = {}, onTrue = { action('inside') }, onFalse = {} },
            { id = 'stop', type = 'stop', conditions = {} },
        },
        cooldowns = {},
    }
end

local function calls(target, callback)
    local count = 0
    local old, mask, step = debug.gethook()
    local on = jit and jit.status()

    if jit then
        jit.off()
        jit.flush()
    end

    debug.sethook(function(event)
        if event == 'call' and debug.getinfo(2, 'f').func == target then
            count = count + 1
        end
    end, 'c')

    local ok, why = pcall(callback)
    debug.sethook(old, mask, step)

    if on then
        jit.on()
    end

    assert(ok, why)
    return count
end

test('warm managed check and visit copy private paths without generic portable traversal', function()
    local _, _, invoke, lease, copy, portable = fixture()
    local b = tree()
    assert(invoke(b, (lease())).status == 'stopped')

    assert(
        calls(copy, function()
            assert(invoke(b, (lease())).status == 'stopped')
        end) == 0,
        'managed paths still invoke generic CopyData'
    )

    assert(
        calls(portable, function()
            assert(invoke(b, (lease())).status == 'stopped')
        end) == 0,
        'warm managed path revalidates portable data'
    )
end)

test('managed check and visitor each get a fresh detached dense path across polls', function()
    local _, _, invoke, lease = fixture()
    local b = tree()
    local retained = {}
    local expected = { 'rotation/1', 'rotation/1/onTrue/1', 'rotation/2' }

    for poll = 1, 3 do
        local seen = 0

        local function record(path)
            seen = seen + 1
            assert(table.concat(path, '/') == expected[seen])
            assert(getmetatable(path) == nil)

            for _, old in ipairs(retained) do
                assert(path ~= old, 'path reused across callbacks or polls')
            end

            retained[#retained + 1] = path
            path[1] = 'mutated'
            path[2] = 99
            path.extra = true
        end

        local result = invoke(
            b,
            lease(),
            function(_, context)
                record(context.stepPath)
                return { status = 'match' }
            end,
            function(_, _, path)
                record(path)
                return true
            end
        )

        assert(result.status == 'stopped' and seen == 3)
    end

    assert(b.rotation[1].id == 'branch' and b.rotation[2].id == 'stop')
end)

test('nested execution cannot share or poison the outer path array', function()
    local _, _, invoke, lease = fixture()
    local outer = tree()
    local inner = { rotation = { action('nested') }, cooldowns = {} }
    local nested = false
    local outerPath

    local result = invoke(
        outer,
        lease(),
        function(_, context)
            assert(context.stepPath[1] == 'rotation')
            context.stepPath[1] = 'outer mutation'
            return { status = 'match' }
        end,
        function(step, _, path)
            assert(step.id == 'inside' and table.concat(path, '/') == 'rotation/1/onTrue/1')
            outerPath = path

            if not nested then
                nested = true

                assert(
                    invoke(inner, lease(), nil, function(_, _, other)
                        assert(other ~= path and table.concat(other, '/') == 'rotation/1')
                        other[1] = 'nested mutation'
                        return true
                    end).status == 'complete'
                )
            end

            assert(table.concat(outerPath, '/') == 'rotation/1/onTrue/1')
            return true
        end
    )

    assert(result.status == 'stopped' and nested)
    assert(invoke(outer, (lease())).status == 'stopped')
end)

test('managed path guard refusal invokes neither copying nor external callbacks', function()
    local _, _, invoke, lease, copy = fixture()
    local b = tree()
    assert(invoke(b, (lease())).status == 'stopped')
    local ordinary = lease()
    local evaluated, visited = 0, 0

    local guard = function(kind)
        if kind == 'pathcopy' then
            return false
        end

        return ordinary(kind)
    end

    assert(
        calls(copy, function()
            local result = invoke(
                b,
                guard,
                function()
                    evaluated = evaluated + 1
                    return { status = 'match' }
                end,
                function()
                    visited = visited + 1
                end
            )

            assert(result.status == 'unavailable' and result.suppressAttack)
        end) == 0
    )

    assert(evaluated == 0 and visited == 0)
end)

test('revoked callback continuation stops before the next private path handoff', function()
    local _, _, invoke, lease = fixture()
    local b = tree()
    local guard, revoke = lease()
    local visited = 0

    local result = invoke(
        b,
        guard,
        function()
            revoke()
            return { status = 'match' }
        end,
        function()
            visited = visited + 1
            return true
        end
    )

    assert(result.status == 'unavailable' and visited == 0)
end)

test('ordinary path copies still dispatch the actual public CopyData once per receiver', function()
    local a, _, invoke = fixture()
    local b = tree()
    local original = a.RotationData.CopyData
    local seen = {}
    local calls = 0

    a.RotationData.CopyData = function(path)
        calls = calls + 1
        local result = original(path)
        result.publicMarker = true
        return result
    end

    local result = invoke(
        b,
        nil,
        function(_, context)
            assert(context.stepPath.publicMarker)
            seen[#seen + 1] = 'check'
            return { status = 'match' }
        end,
        function(_, _, path)
            assert(path.publicMarker)
            seen[#seen + 1] = 'visit'
            return true
        end
    )

    assert(result.status == 'stopped' and calls == 3 and table.concat(seen, ',') == 'check,visit,check')
end)

test('ordinary CopyData error remains before evaluate or visit callback', function()
    for _, branch in ipairs({ true, false }) do
        local a, _, invoke = fixture()
        local b = branch and tree() or { rotation = { action('only') }, cooldowns = {} }
        local called = 0
        local marker = {}

        a.RotationData.CopyData = function()
            error(marker, 0)
        end

        local ok, err = pcall(
            invoke,
            b,
            nil,
            function()
                called = called + 1
            end,
            function()
                called = called + 1
            end
        )

        assert(not ok and err == marker and called == 0)
    end
end)

test('changed public copy producer still rejects a managed private handoff', function()
    local a, _, invoke, lease = fixture()
    local b = tree()
    assert(invoke(b, (lease())).status == 'stopped')
    local called = 0

    a.RotationData.CopyData = function()
        called = called + 1
        error('must not receive private path')
    end

    assert(invoke(b, (lease())).status == 'unavailable' and called == 0)
end)

finish()
