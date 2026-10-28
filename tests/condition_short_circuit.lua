-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(diagnostics)
    local f = F.new()
    f.load('Core/conditions.lua')

    if diagnostics then
        f.load('Diagnostics/errors.lua')
    end

    local a = f.addon
    local calls = {}

    local function leaf(tag, result, reason)
        a:RegisterCondition(tag, {
            fields = {},
            valid = function()
                calls[#calls + 1] = tag .. '.valid'
                return true
            end,
            evaluate = function()
                calls[#calls + 1] = tag .. '.evaluate'
                return result, reason
            end,
        })
    end

    leaf('YES', true)
    leaf('NO', false)
    return f, a, calls, leaf
end

local function group(kind, ...)
    return { type = kind, value = { ... } }
end

local function node(tag)
    return { type = tag }
end

local function status(a, value, wanted)
    local r = a:evaluateConditionResult(value)
    assert(r.status == wanted, r.status .. ' ~= ' .. wanted)
    return r
end

test('AND false skips later validation evaluator and gameplay query callbacks', function()
    local f, a, calls = fixture()

    f.env.NativeProbe = function()
        error('skipped native query')
    end

    a:RegisterCondition('EXPLODE', {
        valid = function()
            f.env.NativeProbe()
            error('skipped valid')
        end,
        evaluate = function()
            error('skipped evaluator')
        end,
    })

    status(a, group('AND', node('NO'), node('EXPLODE')), 'no-match')
    assert(table.concat(calls, ',') == 'NO.valid,NO.evaluate')
end)

test('OR true skips later validation evaluator and gameplay query callbacks', function()
    local _, a, calls = fixture()

    a:RegisterCondition('EXPLODE', {
        valid = function()
            error('skipped valid')
        end,
        evaluate = function()
            error('skipped evaluator')
        end,
    })

    status(a, group('OR', node('YES'), node('EXPLODE')), 'match')
    assert(table.concat(calls, ',') == 'YES.valid,YES.evaluate')
end)

test('nondecisive prefixes retain left to right callback order through the decisive child', function()
    for _, row in ipairs({ { 'AND', 'YES', 'NO', 'no-match' }, { 'OR', 'NO', 'YES', 'match' } }) do
        local _, a, calls = fixture()
        status(a, group(row[1], node(row[2]), node(row[3]), node('MISSING')), row[4])

        assert(
            table.concat(calls, ',')
                == row[2] .. '.valid,' .. row[2] .. '.evaluate,' .. row[3] .. '.valid,' .. row[3] .. '.evaluate'
        )
    end
end)

test('NOT inverts a decisive prefix while skipped unknown siblings stay unvisited', function()
    local _, a = fixture()
    status(a, { type = 'NOT', value = group('AND', node('NO'), node('MISSING')) }, 'match')
    status(a, { type = 'NOT', value = group('OR', node('YES'), node('MISSING')) }, 'no-match')
end)

test('encountered unavailable stops before later decisive values and cannot become NOT true', function()
    for _, kind in ipairs({ 'AND', 'OR' }) do
        local _, a, calls, leaf = fixture()
        local reason = {}
        leaf('UNKNOWN', nil, reason)
        local tree = group(kind, node('UNKNOWN'), node(kind == 'AND' and 'NO' or 'YES'))
        local r = status(a, tree, 'unavailable')
        assert(r.reason == reason and r.path == 'condition.value[1]')
        assert(table.concat(calls, ',') == 'UNKNOWN.valid,UNKNOWN.evaluate')
        status(a, { type = 'NOT', value = tree }, 'unavailable')
    end
end)

test('nested groups preserve decisive order and skip unneeded subtrees', function()
    local _, a, calls = fixture()

    local tree = group(
        'AND',
        group('OR', node('NO'), node('YES'), node('MISSING')),
        { type = 'NOT', value = group('AND', node('NO'), node('MISSING')) },
        node('YES')
    )

    status(a, tree, 'match')

    assert(
        table.concat(calls, ',')
            == 'NO.valid,NO.evaluate,YES.valid,YES.evaluate,NO.valid,NO.evaluate,YES.valid,YES.evaluate'
    )
end)

test('empty identities disabled nodes and legacy nil predicates retain their values', function()
    local _, a, _, leaf = fixture()
    leaf('NIL', nil)
    status(a, group('AND'), 'match')
    status(a, group('OR'), 'no-match')
    status(a, { type = 'NOT', value = node('NIL') }, 'match')
    status(a, group('OR', { type = 'MISSING', disabled = true }, node('MISSING')), 'match')
end)

test('current child list density keys and width remain validated before any callback', function()
    local _, a, calls = fixture()
    local wide = {}

    for i = 1, 4096 do
        wide[i] = node('NO')
    end

    for _, children in ipairs({
        { [1] = node('NO'), [3] = node('MISSING') },
        { [1] = node('YES'), bad = node('MISSING') },
        wide,
    }) do
        local r = status(a, { type = 'AND', value = children }, 'unavailable')

        assert(
            r.reason == 'sparse-condition-list' or r.reason == 'invalid-condition-list' or r.reason == 'condition-limit'
        )

        assert(#calls == 0)
    end
end)

test('skipped child cycles depth invalid flags and nested invalid lists are not evaluated', function()
    local _, a = fixture()
    local cycle = { type = 'NOT' }
    cycle.value = cycle
    local deep = node('YES')

    for i = 1, 70 do
        deep = { type = 'NOT', value = deep }
    end

    for _, child in ipairs({
        cycle,
        deep,
        { type = 'AND', value = { bad = true } },
        { type = 'YES', disabled = 'false' },
    }) do
        status(a, group('AND', node('NO'), child), 'no-match')
        status(a, group('OR', node('YES'), child), 'match')
    end

    status(a, cycle, 'unavailable')
    status(a, deep, 'unavailable')
end)

test('reached callback errors retain diagnostics quarantine and original path', function()
    local _, a, _, leaf = fixture(true)
    local calls = 0

    a:RegisterCondition('BROKEN', {
        valid = function() return true end,
        evaluate = function()
            calls = calls + 1
            error('reached failure')
        end,
    })

    local tree = group('AND', node('YES'), node('BROKEN'), node('NO'))
    local r = status(a, tree, 'unavailable')
    assert(r.reason == 'condition-callback-error' and r.path == 'condition.value[2]')
    status(a, tree, 'unavailable')
    assert(calls == 1)
    assert(#a.Diagnostics:GetReports() == 1)
    leaf('BROKEN', false)
    status(a, tree, 'no-match')
end)

test('unprotected reached thrown objects propagate unchanged but skipped errors do not throw', function()
    local _, a = fixture()
    local marker = {}

    a:RegisterCondition('THROW', {
        valid = function()
            error(marker)
        end,
        evaluate = function()
            error('unreachable')
        end,
    })

    local ok, err = pcall(a.evaluateConditionResult, a, group('AND', node('YES'), node('THROW')))
    assert(not ok and err == marker)
    status(a, group('AND', node('NO'), node('THROW')), 'no-match')
end)

test('reached siblings retain shared cache and timestamp while separate roots stay independent', function()
    local _, a = fixture()
    local caches, times = {}, {}

    a:RegisterCondition('RECORD', {
        valid = function() return true end,
        evaluate = function(_, cache, start)
            caches[#caches + 1] = cache
            times[#times + 1] = start
            return true
        end,
    })

    local tree = group('AND', node('RECORD'), node('RECORD'))
    status(a, tree, 'match')
    status(a, tree, 'match')
    assert(caches[1] == caches[2] and caches[3] == caches[4] and caches[1] ~= caches[3])

    for _, v in ipairs(times) do
        assert(v == 100)
    end
end)

finish()
