local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.load('Core/conditions.lua')
    local a = f.addon

    for _, row in ipairs({ { 'YES', true }, { 'NO', false } }) do
        local result = row[2]

        a:RegisterCondition(row[1], {
            fields = {},
            valid = function() return true end,
            evaluate = function() return result end,
        })
    end

    return a
end

test('public condition results remain fresh through Boolean composition and caller mutation', function()
    local a = fixture()

    local values = {
        { type = 'YES' },
        { type = 'NO' },
        { type = 'AND', value = {} },
        { type = 'OR', value = {} },
        { type = 'NOT', value = { type = 'NO' } },
        { type = 'YES', disabled = true },
    }

    for _, value in ipairs(values) do
        local first = a:evaluateConditionResult(value)
        local status = first.status
        first.status = 'poison'
        first.reason = 'poison'
        first.path = 'poison'
        setmetatable(first, {})
        local second = a:evaluateConditionResult(value)
        assert(second ~= first and getmetatable(second) == nil and second.status == status)
        assert(second.reason == nil and second.path == nil)
    end

    local first = a:evaluateConditionResult(nil)
    first.status = 'poison'
    assert(a:evaluateConditionResult(nil).status == 'match')
end)

test('nested calls cannot mutate pending Boolean results and callbacks retain one cache and timestamp', function()
    local a = fixture()
    local observedCache, observedStart, calls
    calls = 0

    a:RegisterCondition('REENTER', {
        fields = {},
        valid = function() return true end,
        evaluate = function(_, cache, start)
            calls = calls + 1

            if observedCache then
                assert(cache == observedCache and start == observedStart)
            end

            observedCache, observedStart = cache, start
            local inner = a:evaluateConditionResult({ type = 'NOT', value = { type = 'NO' } })
            inner.status = 'poison'
            inner.reason = 'poison'
            return false
        end,
    })

    -- False OR prefixes keep both nested callbacks reached after short-circuiting.
    local result = a:evaluateConditionResult({
        type = 'OR',
        value = { { type = 'NO' }, { type = 'REENTER' }, { type = 'REENTER' } },
    })

    assert(result.status == 'no-match' and calls == 2 and observedStart == 100)
end)

test('unavailable reasons paths and thrown identities retain their original values', function()
    local a = fixture()
    local reason = {}
    local marker = {}

    a:RegisterCondition('UNKNOWN', {
        fields = {},
        valid = function() return true end,
        evaluate = function() return nil, reason end,
    })

    local tree = { type = 'AND', value = { { type = 'YES' }, { type = 'UNKNOWN' } } }
    local first = a:evaluateConditionResult(tree)
    assert(first.status == 'unavailable' and first.reason == reason and first.path == 'condition.value[2]')
    first.status = 'poison'
    first.reason = 'poison'
    local second = a:evaluateConditionResult(tree)
    assert(second ~= first and second.reason == reason and second.status == 'unavailable')

    a:RegisterCondition('THROW', {
        fields = {},
        valid = function()
            error(marker)
        end,
        evaluate = function()
            error('unreachable')
        end,
    })

    local ok, err = pcall(a.evaluateConditionResult, a, { type = 'THROW' })
    assert(not ok and err == marker)
end)

test('large callback-free Boolean trees avoid allocating a result record for every internal node', function()
    local compiling = jit and jit.status()

    if jit then
        jit.off()
        jit.flush()
    end

    local a = fixture()
    local value = { type = 'AND', value = {} }

    for i = 1, 256 do
        value.value[i] = { type = 'NO', disabled = true }
    end

    for i = 1, 16 do
        assert(a:evaluateConditionResult(value).status == 'match')
    end

    collectgarbage('collect')
    collectgarbage('stop')
    local before = collectgarbage('count')

    for i = 1, 32 do
        assert(a:evaluateConditionResult(value).status == 'match')
    end

    local allocated = (collectgarbage('count') - before) / 32
    collectgarbage('restart')

    if compiling then
        jit.on()
    end

    assert(allocated < 10, 'callback-free Boolean evaluation allocated ' .. allocated .. ' KiB')
end)

finish()
