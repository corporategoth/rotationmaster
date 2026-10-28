local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local validate = dofile('tests/fixtures/declarations.lua')

test('declarations accept primitives, unions, nested arrays and records', function()
    assert(validate({
        unit = 'string',
        own = 'boolean',
        count = 'number',
        value = { 'string', { 'string', 'number' } },
        other = { 'string', { name = 'string', count = 'number' } },
        condition = 'condition',
        children = 'condition[]',
    }))

    assert(validate({}))
end)

test('declaration typos and ambiguous shapes are rejected with a field path', function()
    local cases = {
        { spell = 'nubmer' },
        { spell = 42 },
        { spell = {} },
        { spell = { 'string', false } },
        { spell = { [1] = 'string', [3] = 'number' } },
        { spell = { [1] = 'string', name = 'number' } },
        { ['bad field'] = 'number' },
    }

    for _, fields in ipairs(cases) do
        local ok, reason, path = validate(fields)
        assert(not ok and type(reason) == 'string' and type(path) == 'string')
    end
end)

test('cyclic and excessive schemas are bounded', function()
    local cycle = {}
    cycle[1] = cycle
    assert(not validate({ value = cycle }))
    local depth = 'string'

    for _ = 1, 70 do
        depth = { depth }
    end

    assert(not validate({ value = depth }))
    local wide = {}

    for i = 1, 5000 do
        wide['field' .. i] = 'string'
    end

    assert(not validate(wide))
end)

finish()
