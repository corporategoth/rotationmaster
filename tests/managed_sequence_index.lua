-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function find(fn, name, seen)
    if type(fn) ~= 'function' then
        return
    end

    seen = seen or {}

    if seen[fn] then
        return
    end

    seen[fn] = true

    for i = 1, 100 do
        local key, value = debug.getupvalue(fn, i)

        if not key then
            break
        end

        if key == name then
            return value
        end
    end

    for i = 1, 100 do
        local key, value = debug.getupvalue(fn, i)

        if not key then
            break
        end

        local result = find(value, name, seen)

        if result then
            return result
        end
    end
end

local function calls(fn, callback)
    local count = 0
    local old, mask, step = debug.gethook()
    local enabled = jit and jit.status()

    if jit then
        jit.off()
        jit.flush()
    end

    debug.sethook(function(event)
        if event == 'call' and debug.getinfo(2, 'f').func == fn then
            count = count + 1
        end
    end, 'c')

    local ok, why = pcall(callback)
    debug.sethook(old, mask, step)

    if enabled then
        jit.on()
    end

    assert(ok, why)
    return count
end

local function action(id)
    return { id = id, type = 'spell', action = 403, conditions = {} }
end

local function body(id)
    return { rotation = { action(id) }, cooldowns = {} }
end

local function fixture(observeRows)
    local env = {}

    for key, value in pairs(_G) do
        env[key] = value
    end

    env._G = env

    if observeRows then
        env.rowMapIterations = 0

        env.ipairs = function(list)
            if type(list) == 'table' and type(list[1]) == 'table' and list[1].section == 'rotation' then
                env.rowMapIterations = env.rowMapIterations + 1
            end

            return ipairs(list)
        end
    end

    local a = { db = { profile = {} } }

    for _, path in ipairs({ 'Data/plain.lua', 'Data/rotation_tree.lua', 'Core/rotation_sequence.lua' }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk('rotationmaster', a)
    end

    local run, method

    a:BindRotationSequenceReader(function(_, invoke, _, owned)
        run, method = invoke, owned
    end)

    local data = a.RotationData
    local index, copy, portable = data.IndexRotationSteps, data.CopyData, data.CheckPortable

    local function lease()
        local db, profile = a.db, a.db.profile
        local alive = true

        return function(kind)
            if not alive or a.db ~= db or a.db.profile ~= profile then
                return false
            end
            if kind == 'sequence' or kind == 'pathcopy' or kind == 'iterator' then
                return a.EvaluateRotationSequence == method
                    and getfenv(method) == env
                    and data.IndexRotationSteps == index
                    and data.CopyData == copy
                    and data.CheckPortable == portable
                    and env.ipairs == ipairs
                    and env.type == type
                    and env.getfenv == getfenv
            end

            return true
        end,
            function()
                alive = false
            end
    end

    local function invoke(value, guard, evaluate, visit)
        local seen = {}

        local result = run(
            a,
            method,
            a.EvaluateRotationSequence,
            value,
            evaluate or function() return { status = 'match' } end,
            visit or function(step, ordinal, path)
                seen[#seen + 1] = { step.id, ordinal, path }
                return true
            end,
            guard
        )

        return result, seen
    end

    return a, env, invoke, lease, assert(find(run, 'readIndex'))
end

test('managed immutable body reuses its index without warm graph scans or materialization', function()
    local _, _, invoke, lease, read = fixture()
    local b = body('one')
    local guard = lease()

    assert(
        calls(read, function()
            local result, seen = invoke(b, guard)
            assert(result.status == 'complete' and seen[1][1] == 'one')
        end) == 1
    )

    local changed = assert(find(read, 'unchanged'))
    local materialize = assert(find(read, 'materialize'))

    assert(
        calls(read, function()
            for i = 1, 7 do
                local result, seen = invoke(b, lease())
                assert(result.status == 'complete' and seen[1][1] == 'one')
            end
        end) == 0,
        'warm managed dispatch reread its immutable graph'
    )

    assert(
        calls(changed, function()
            assert(invoke(b, lease()).status == 'complete')
        end) == 0
    )

    assert(
        calls(materialize, function()
            assert(invoke(b, lease()).status == 'complete')
        end) == 0
    )
end)

test('different private body or profile builds a separate correct map', function()
    local a, _, invoke, lease, read = fixture()
    local first, second = body('first'), body('second')
    assert(invoke(first, lease()).status == 'complete')

    assert(
        calls(read, function()
            local result, seen = invoke(second, lease())
            assert(result.status == 'complete' and seen[1][1] == 'second')
        end) == 1
    )

    a.db.profile = {}

    assert(
        calls(read, function()
            local result, seen = invoke(second, lease())
            assert(result.status == 'complete' and seen[1][1] == 'second')
        end) == 1
    )

    a.db = { profile = {} }

    assert(
        calls(read, function()
            local result, seen = invoke(second, lease())
            assert(result.status == 'complete' and seen[1][1] == 'second')
        end) == 1
    )
end)

test('managed map retains nested paths and unchosen branch control flow', function()
    local _, _, invoke, lease, read = fixture()

    local b = {
        rotation = {
            {
                id = 'branch',
                type = 'branch',
                mode = 'evaluate',
                conditions = {},
                onTrue = { action('yes') },
                onFalse = { action('no') },
            },
            action('tail'),
        },
        cooldowns = {},
    }

    local evaluate = function() return { status = 'no-match' } end
    local result, seen = invoke(b, lease(), evaluate)
    assert(result.status == 'complete' and #seen == 2 and seen[1][1] == 'no' and seen[2][1] == 'tail')

    assert(
        calls(read, function()
            local _, warm = invoke(b, lease(), evaluate)
            assert(table.concat(warm[1][3], '/') == 'rotation/1/onFalse/1' and warm[1][2] == 3)
        end) == 0
    )
end)

test('failed or malformed cold managed build never admits a reusable partial map', function()
    local _, _, invoke, lease, read = fixture()

    local b = {
        rotation = { { id = 'bad', type = 'branch', mode = 'true', onTrue = { action('one') } } },
        cooldowns = {},
    }

    assert(invoke(b, lease()).status == 'unavailable')
    b.rotation[1].onFalse = {}

    assert(
        calls(read, function()
            local result, seen = invoke(b, lease())
            assert(result.status == 'complete' and seen[1][1] == 'one')
        end) == 1
    )
end)

test('stale outer lease cannot retire or overwrite a newer nested managed map', function()
    local _, _, invoke, lease, read = fixture()
    local first, second = body('outer'), body('nested')
    local normal, invalidate = lease()
    local entered = false

    local outer = function(kind)
        if not entered then
            entered = true
            assert(invoke(second, lease()).status == 'complete')
            invalidate()
        end

        return normal(kind)
    end

    assert(invoke(first, outer).status == 'unavailable')

    assert(
        calls(read, function()
            local result, seen = invoke(second, lease())
            assert(result.status == 'complete' and seen[1][1] == 'nested')
        end) == 0,
        'old failed invocation retired the newer cached map'
    )
end)

test('revocation after cold index read cannot publish a completed managed map', function()
    local _, _, invoke, lease, read = fixture()
    local b = body('revoked')
    local normal, revoke = lease()
    local fired = false

    local guard = function(kind)
        if kind == 'resume' and not fired then
            fired = true
            revoke()
        end

        return normal(kind)
    end

    assert(invoke(b, guard).status == 'unavailable' and fired)

    assert(
        calls(read, function()
            assert(invoke(b, lease()).status == 'complete')
        end) == 1,
        'revoked cold build became a warm managed map'
    )
end)

test('nested different body cannot replace the outer invocation local row map', function()
    local _, _, invoke, lease, read = fixture()
    local a = { rotation = { action('a-one'), action('a-two') }, cooldowns = {} }
    local b = body('b-one')
    local visited = {}

    local result = invoke(a, lease(), nil, function(step)
        visited[#visited + 1] = step.id

        if step.id == 'a-one' then
            assert(invoke(b, lease()).status == 'complete')
        end

        return true
    end)

    assert(result.status == 'complete' and #visited == 2 and visited[2] == 'a-two', 'outer resumed with nested row map')

    assert(
        calls(read, function()
            local _, seen = invoke(b, lease())
            assert(seen[1][1] == 'b-one')
        end) == 0,
        'outer return overwrote newer nested map'
    )
end)

test('source replacement and revoked managed lease cannot use a warm private map', function()
    for _, kind in ipairs({ 'index', 'copy', 'iterator', 'method', 'revoked' }) do
        local a, env, invoke, lease = fixture()
        local b = body('one')
        assert(invoke(b, lease()).status == 'complete')
        local guard, revoke = lease()
        local calls = 0

        local unknown = function()
            calls = calls + 1
            error('unknown receiver')
        end

        if kind == 'index' then
            a.RotationData.IndexRotationSteps = unknown
        elseif kind == 'copy' then
            a.RotationData.CopyData = unknown
        elseif kind == 'iterator' then
            env.ipairs = unknown
        elseif kind == 'method' then
            a.EvaluateRotationSequence = unknown
        else
            revoke()
        end

        local result, seen = invoke(b, guard)
        assert(result.status == 'unavailable' and #seen == 0 and calls == 0, kind .. ' admitted a warm private map')
    end
end)

test('ordinary invalid callback is rejected before row-map iterator dispatch', function()
    local _, env, invoke = fixture(true)
    local result = invoke(body('one'), nil, 42)
    assert(result.status == 'unavailable' and result.diagnostic.code == 'invalid-sequence-callback')
    assert(env.rowMapIterations == 0, 'ordinary callback validation moved after row-map iteration')
end)

test('ordinary mutable route still rechecks and path aliases never poison managed maps', function()
    local a, _, invoke, lease, read = fixture()
    local b = body('one')
    assert(invoke(b, lease()).status == 'complete')

    assert(
        calls(read, function()
            assert(invoke(b, nil).status == 'complete')
        end) == 1,
        'ordinary route used the managed cache'
    )

    local original = a.RotationData.CopyData
    local retained

    a.RotationData.CopyData = function(path)
        retained = path
        return original(path)
    end

    assert(invoke(b, nil).status == 'complete')
    retained[1] = 'poison'
    a.RotationData.CopyData = original
    local _, seen = invoke(b, lease())
    assert(seen[1][3][1] == 'rotation', 'ordinary path escaped into private managed map')
    b.rotation[2] = action('added')
    local result, ordinary = invoke(b, nil)
    assert(result.status == 'complete' and #ordinary == 2, 'ordinary mutable tree was not reindexed')
end)

finish()
