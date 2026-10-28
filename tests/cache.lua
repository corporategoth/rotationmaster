-- LuaJIT supplies bit operations for the actual bundled CRC16 reproduction.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local f = F.new()
local a = f.addon
local lib = f.libraries.LibCompress
f.env.bit = require('bit')
f.env.sort = table.sort
f.env.UIParent = {}

f.env.CreateFrame = function()
    return {
        SetScript = function() end,
        Hide = function() end,
        Show = function() end,
        IsShown = function() return false end,
    }
end

f.env.LibStub = setmetatable({
    NewLibrary = function(_, name)
        assert(name == 'LibCompress')
        return lib
    end,
}, { __call = function(_, name) return assert(f.libraries[name]) end })

f.load('Libs/LibCompress/LibCompress.lua')

local function pack(...)
    return { n = select('#', ...), ... }
end

test('distinct IDs with the real vendored CRC16 collision never share an observation', function()
    local seen, left, right = {}
    local platform = a.Platform

    for id = 1, 65537 do
        local crc = lib:fcs16update(lib:fcs16init(), tostring(platform))
        crc = lib:fcs16final(lib:fcs16update(crc, tostring(id)))

        if seen[crc] then
            left, right = seen[crc], id
            break
        end

        seen[crc] = id
    end

    assert(left and right, 'CRC16 reproduction did not find a collision')
    local cache = {}
    local observe = function(_, id) return id end
    assert(a.getCached(cache, observe, platform, left) == left)

    assert(
        a.getCached(cache, observe, platform, right) == right,
        'distinct identifiers reused the same hashed observation'
    )
end)

test('argument type boundaries and arity including trailing nil remain distinct', function()
    local cache = {}
    local calls = 0

    local fn = function(...)
        calls = calls + 1
        return calls, select('#', ...)
    end

    local queries = {
        { n = 1, 1 },
        { n = 1, '1' },
        { n = 2, 1, 23 },
        { n = 2, 12, 3 },
        { n = 1, 1 },
        { n = 2, 1, nil },
        { n = 0 },
        { n = 1, nil },
        { n = 2, nil, nil },
    }

    for i, args in ipairs(queries) do
        local result, arity = a.getCached(cache, fn, unpack(args, 1, args.n))
        assert(arity == args.n, 'argument arity lost')
        assert(result == (i == 5 and 1 or i < 5 and i or i - 1), 'typed argument tuples collided')
    end

    assert(calls == 8)
end)

test('table arguments use identity without tostring or equality metamethods', function()
    local meta = {
        __tostring = function()
            error('cache must not stringify tables')
        end,
        __eq = function()
            error('cache must not compare table content')
        end,
    }

    local left, right = setmetatable({}, meta), setmetatable({}, meta)
    local count = 0

    local fn = function(value)
        count = count + 1
        return value
    end

    local cache = {}

    assert(
        rawequal(a.getCached(cache, fn, left), left) and rawequal(a.getCached(cache, fn, right), right) and count == 2
    )

    assert(rawequal(a.getCached(cache, fn, left), left) and count == 2)
end)

test('cached false nil void and trailing-nil result arity are retained exactly', function()
    for _, result in ipairs({
        { n = 0 },
        { n = 1, nil },
        { n = 1, false },
        { n = 3, nil, 'reason', nil },
        { n = 3, 1, nil, nil },
    }) do
        local calls = 0

        local fn = function()
            calls = calls + 1
            return unpack(result, 1, result.n)
        end

        local cache = {}

        for i = 1, 2 do
            local got = pack(a.getCached(cache, fn))
            assert(got.n == result.n, 'return arity was lost')

            for j = 1, got.n do
                assert(got[j] == result[j])
            end
        end

        assert(calls == 1, 'nil or false was not cached')
    end
end)

test('retry cache retries void or all-nil while caching false and nil-plus-reason', function()
    for _, result in ipairs({ { n = 0 }, { n = 2, nil, nil }, { n = 1, false }, { n = 3, nil, 'reason', nil } }) do
        local calls = 0

        local fn = function()
            calls = calls + 1
            return unpack(result, 1, result.n)
        end

        local cache = {}
        a.getRetryCached(cache, fn, 1)
        a.getRetryCached(cache, fn, 1)
        assert(calls == (result[1] == nil and result[2] == nil and 2 or 1), 'retry-cache result policy changed')

        if result[1] == nil and result[2] == nil then
            assert(next(cache) == nil, 'retry misses retained empty paths')
        end
    end
end)

test('global-name callbacks support uncached dispatch aliases and callback replacement', function()
    local calls = 0

    local original = function(value)
        calls = calls + 1
        return value
    end

    f.env.CACHE_FIXTURE = original
    assert(a.getCached(nil, 'CACHE_FIXTURE', 7) == 7 and calls == 1)
    local cache = {}
    assert(a.getCached(cache, 'CACHE_FIXTURE', 8) == 8)

    assert(
        a.getCached(cache, original, 8) == 8 and calls == 2,
        'function and global-name aliases did not share an observation'
    )

    f.env.CACHE_FIXTURE = function(value) return value + 1 end
    assert(a.getCached(cache, 'CACHE_FIXTURE', 8) == 9, 'a replaced global reused the former callback result')
end)

test('exceptions and uncacheable arguments are retried and clearing a cache resets observations', function()
    local calls = 0

    local fn = function(value)
        calls = calls + 1

        if calls == 1 then
            error('transient')
        end

        return value
    end

    local cache = {}
    assert(not pcall(a.getCached, cache, fn, 1))
    assert(next(cache) == nil, 'a thrown call retained empty paths')
    assert(a.getCached(cache, fn, 1) == 1 and calls == 2)
    assert(a.getCached({}, fn, 1) == 1 and calls == 3)
    local nan = 0 / 0
    a.getCached(cache, fn, nan)
    a.getCached(cache, fn, nan)
    assert(calls == 5)

    local opaque = setmetatable({}, {
        __tostring = function()
            error('opaque argument inspected')
        end,
    })

    f.env.canaccessvalue = function(value) return not rawequal(value, opaque) end

    assert(
        rawequal(a.getCached(cache, fn, opaque), opaque)
            and rawequal(a.getCached(cache, fn, opaque), opaque)
            and calls == 7
    )
end)

finish()
