local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local owner = {}
    assert(loadfile('Core/dependency_revisions.lua'))('test', owner)
    return owner
end

local function bind(owner)
    local read, advance
    assert(type(owner.BindRotationExecutionGeneration) == 'function', 'execution generation handoff missing')

    assert(owner:BindRotationExecutionGeneration(function(r, a)
        read, advance = r, a
    end))

    assert(type(read) == 'function' and type(advance) == 'function')
    return read, advance
end

test('multiple startup producers share a stable private execution token', function()
    local owner = fixture()
    local read, advance = bind(owner)
    local second, nextAdvance = bind(owner)
    local token = read()
    assert(type(token) == 'table' and second() == token)

    for i = 1, 20 do
        assert(read() == token and second() == token, 'reading advanced execution')
    end

    assert(read == second and advance == nextAdvance, 'producer handoff replaced clock closures')
end)

test('every explicit execution advance retires all previous tokens without ABA', function()
    local owner = fixture()
    local read, advance = bind(owner)
    local seen = { [read()] = true }

    for i = 1, 200 do
        local token = advance()
        assert(type(token) == 'table' and read() == token and not seen[token], 'execution token repeated')
        seen[token] = true
    end
end)

test('dependency notification advances execution while preserving dependency reader epochs', function()
    local owner = fixture()
    local read = bind(owner)
    local dependency

    assert(owner:BindRotationDependencyReader(function(r)
        dependency = r
    end))

    local execution = read()
    local stamp, epoch = dependency(owner)
    assert(owner:InvalidateRotationDependencies('condition', 'LEVEL'))
    local nextStamp, nextEpoch = dependency(owner)
    assert(read() ~= execution and nextStamp ~= stamp and nextEpoch == epoch + 1)

    local ok, why = owner:BindRotationDependencyReader(function()
        error('dependency binder reused')
    end)

    assert(ok == nil and why == 'dependency-reader-already-bound')
end)

test('foreign owners and invalid startup callbacks cannot acquire or advance the clock', function()
    local owner = fixture()
    local read = bind(owner)
    local token = read()
    local calls = 0

    local ok, why = owner.BindRotationExecutionGeneration({}, function()
        calls = calls + 1
    end)

    assert(ok == nil and why == 'foreign-dependency-owner' and calls == 0 and read() == token)
    ok, why = owner:BindRotationExecutionGeneration({})
    assert(ok == nil and why == 'invalid-execution-generation-binder' and read() == token)
    ok, why = owner.InvalidateRotationDependencies({})
    assert(ok == nil and why == 'foreign-dependency-owner' and read() == token)
end)

test('separate addon owners keep independent execution clocks', function()
    local first, second = fixture(), fixture()
    local read, advance = bind(first)
    local other, nextOther = bind(second)
    local firstToken, secondToken = read(), other()
    assert(firstToken ~= secondToken)
    advance()
    assert(read() ~= firstToken and other() == secondToken)
    firstToken = read()
    assert(second:InvalidateRotationDependencies())
    assert(other() ~= secondToken and read() == firstToken)
    secondToken = other()
    nextOther()
    assert(other() ~= secondToken and read() == firstToken)
end)

finish()
