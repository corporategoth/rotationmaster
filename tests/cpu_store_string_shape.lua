-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local source = assert(read('tests/cpu.lua'):match('^(.-)\ntest%('))
local make = assert(loadstring(source .. '\nreturn fixture', '@store-shape-cpu-fixture'))()

local function fixture(observe)
    local f, a, s = make()
    local calls = 0

    f.env.getmetatable = function(value)
        if value == '' then
            calls = calls + 1
            return observe(calls, f, a, s)
        end

        return getmetatable(value)
    end

    return f, a, s, function() return calls end
end

local function has(text, part)
    assert(type(text) == 'string' and text:find(part, 1, true), 'missing ' .. part)
end

local function complete(a, s)
    assert(a:StartCPUProfile())
    s:complete()
    return assert(a:GetCPUProfileReport())
end

local function shape(which, body)
    return 'Store string shape ' .. which .. ': ' .. body
end

local positive = 'meta=table; index=table; raw-find=function; repeat-meta=1; repeat-index=1'

test('cold capture boundaries report actual copied string method table without globalstring requirement', function()
    local index = { find = string.find }
    assert(index ~= string)
    local meta = { __index = index }
    local f, a, s, calls = fixture(function() return meta end)
    assert(calls() == 0)
    local text = complete(a, s)
    has(text, shape('start', positive))
    has(text, shape('end', positive))
    has(text, 'Necessary shape only')
    has(text, 'does not prove private-store use')
    assert(calls() == 4 and #s.timers == 1)
end)

test('bad metatable or index kinds remain actual kinds without claiming qualification', function()
    for _, meta in ipairs({ 'protected', { __index = 'other' }, { __index = false } }) do
        local _, a, s = fixture(function() return meta end)
        local text = complete(a, s)
        local kind = type(meta) == 'table' and type(rawget(meta, '__index')) or 'nil'
        has(text, 'meta=' .. type(meta) .. '; index=' .. kind .. '; raw-find=nil')
    end
end)

test('proxyfind is not invoked or confused with rawfindfunction', function()
    local reads = 0

    local index = setmetatable({}, {
        __index = function()
            reads = reads + 1
            return string.find
        end,
    })

    local meta = { __index = index }
    local _, a, s = fixture(function() return meta end)
    local text = complete(a, s)
    has(text, 'index=table; raw-find=nil')
    assert(reads == 0)
end)

test('consecutive copied metatables and replaced index report distinct identity flags', function()
    local index = { find = string.find }
    local _, a, s = fixture(function() return { __index = index } end)
    local text = complete(a, s)
    has(text, 'repeat-meta=0; repeat-index=1')
    local meta = {}

    local _, a, s = fixture(function()
        meta.__index = { find = string.find }
        return meta
    end)

    local text = complete(a, s)
    has(text, 'repeat-meta=1; repeat-index=0')
end)

test('throwing or unreadable observations are unavailable without opaqueerrorcoercion', function()
    local _, a, s = fixture(function()
        error(
            setmetatable({}, {
                __tostring = function()
                    error('opaque coercion')
                end,
            }),
            0
        )
    end)

    local text = complete(a, s)
    has(text, shape('start', 'unavailable'))
    has(text, shape('end', 'unavailable'))
    assert(not text:find('opaque', 1, true))

    for _, slot in ipairs({ 'meta', 'index', 'find' }) do
        local index = { find = function() end }
        local meta = { __index = index }
        local f, a, s = fixture(function() return meta end)
        local opaque = slot == 'meta' and meta or slot == 'index' and index or index.find
        f.env.canaccessvalue = function(value) return not rawequal(value, opaque) end
        local text = complete(a, s)
        has(text, shape('start', 'unavailable'))
        has(text, shape('end', 'unavailable'))
    end
end)

test('idle report reads failedcapture cancel stale callback and completion never add polling', function()
    local meta = { __index = { find = string.find } }
    local f, a, s, calls = fixture(function() return meta end)
    a:GetCPUProfileReport()
    a:IsCPUProfileRunning()
    assert(calls() == 0)
    s.enabled = '0'
    assert(not a:StartCPUProfile())
    assert(calls() == 0)
    s.enabled = '1'
    assert(a:StartCPUProfile())
    assert(calls() == 2)
    local stale = s.timers[1]
    assert(a:CancelCPUProfile())
    stale.callback()
    assert(calls() == 2)
    local text = complete(a, s)
    local n = calls()

    for i = 1, 5 do
        a:GetCPUProfileReport()
        a:IsCPUProfileRunning()
        s.timers[#s.timers].callback()
    end

    assert(calls() == n and n == 6)
end)

test('cancellation during cold start keeps cancelledreport', function()
    local meta = { __index = { find = string.find } }
    local armed = true

    local _, a, s = fixture(function(_, _, a)
        if armed then
            armed = false
            assert(a:CancelCPUProfile())
        end

        return meta
    end)

    assert(a:StartCPUProfile())
    assert(not a:IsCPUProfileRunning())
    has(a:GetCPUProfileReport(), 'cancelled')
end)

test('new capture completed during cold end observation retains newerreport ownership', function()
    local meta = { __index = { find = string.find } }
    local entered = false
    local newer

    local _, a, s = fixture(function(_, _, a, s)
        if s.phase == 'finish' and not entered then
            entered = true
            assert(a:StartCPUProfile(1))
            s.now = s.now + 1
            s.timers[#s.timers].callback()
            newer = a:GetCPUProfileReport()
        end

        return meta
    end)

    assert(a:StartCPUProfile())
    s:complete()
    assert(entered and a:GetCPUProfileReport() == newer)
    has(newer, 'duration=1.000 s')
end)

finish()
