-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local addon = {}
local chunk = assert(loadfile('Data/plain.lua'))

local env = setmetatable({}, {
    __index = function(_, key)
        assert(
            key ~= 'LibStub' and key ~= 'GetTime' and key ~= 'CreateFrame',
            'portable data requested WoW/UI API ' .. key
        )

        return _G[key]
    end,
})

setfenv(chunk, env)
chunk('rotationmaster', addon)
local data = addon.RotationData

test('plain data copies nested values independently without changing inputs', function()
    local source = {
        id = 'rotation',
        disabled = false,
        revision = 1,
        body = { rotation = { { id = 'step', action = 403, conditions = {} } } },
    }

    assert(data.CheckPortable(source))
    local copy = assert(data.CopyData(source))
    assert(copy ~= source and copy.body ~= source.body and copy.disabled == false)
    copy.body.rotation[1].action = 974
    assert(source.body.rotation[1].action == 403)
end)

test('nonportable values and executable or metatable-backed structures are rejected', function()
    for _, value in ipairs({
        function() end,
        coroutine.create(function() end),
        io.stdout,
        setmetatable({}, {}),
        { body = function() end },
        { [{}] = 'key' },
        { [0] = 'zero' },
        { [-1] = 'negative' },
        { [1.5] = 'fractional' },
        { value = math.huge },
        { value = -math.huge },
        { value = 0 / 0 },
    }) do
        local ok, diagnostic = data.CheckPortable(value)
        assert(not ok and diagnostic.severity == 'error' and type(diagnostic.path) == 'string')
        local copy, reason = data.CopyData(value)
        assert(copy == nil and reason.code == diagnostic.code)
    end
end)

test('cycles fail with a path while repeated noncyclic references remain portable', function()
    local cycle = {}
    cycle.self = cycle
    local ok, diagnostic = data.CheckPortable(cycle)
    assert(not ok and diagnostic.code == 'data-cycle' and diagnostic.path == '$.self')
    local shared = { id = 'step' }
    assert(data.CheckPortable({ a = shared, b = shared }))
    local copy = assert(data.CopyData({ a = shared, b = shared }))
    assert(copy.a ~= shared and copy.a.id == 'step' and copy.b.id == 'step')
end)

test('excessive depth, string length, aggregate bytes and width fail before copying', function()
    local deep = {}
    local cursor = deep

    for _ = 1, 70 do
        cursor.next = {}
        cursor = cursor.next
    end

    local ok, diagnostic = data.CheckPortable(deep)
    assert(not ok and diagnostic.code == 'data-depth-limit')
    ok, diagnostic = data.CheckPortable({ value = string.rep('x', 262145) })
    assert(not ok and diagnostic.code == 'data-string-limit')
    local bytes = {}

    for i = 1, 10 do
        bytes[i] = string.rep('x', 200000)
    end

    ok, diagnostic = data.CheckPortable(bytes)
    assert(not ok and diagnostic.code == 'data-byte-limit')
    local wide = {}

    for i = 1, 100000 do
        wide[i] = i
    end

    local ticks = 0

    debug.sethook(function()
        ticks = ticks + 1
        assert(ticks < 5000, 'unbounded data traversal')
    end, '', 1000)

    local succeeded, result, reason = pcall(data.CheckPortable, wide)
    debug.sethook()
    assert(succeeded and result == false and reason.code == 'data-node-limit')
end)

finish()
