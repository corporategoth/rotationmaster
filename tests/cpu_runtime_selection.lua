-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Capture boundaries only: classify the selection representation, never its ID.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local h = assert(io.open('tests/cpu_runtime.lua'))
local source = h:read('*a')
h:close()
local prefix = assert(source:match('^(.-)\ntest%('))
local setup = assert(loadstring(prefix .. '\nreturn setup', '@runtime-selection-real-capture'))()

local function has(text, needle)
    assert(text:find(needle, 1, true), needle .. ' missing: ' .. text)
end

local function done(a, s)
    s.now = 110
    s.timers[1].fn()
    return a:GetCPURuntimeCaptureReport()
end

test('capture records scoped/raw/none at both boundaries without recording saved identifiers', function()
    local cases = {
        { value = '\1rm:rotation:93849831', start = 'scoped', last = 'private-rotation-UUID', ending = 'raw' },
        { value = 'private-old-UUID', start = 'raw', ending = 'none' },
        { start = 'none', last = '\1rm:rotation:25', ending = 'scoped' },
        { value = {}, start = 'unavailable', last = false, ending = 'unavailable' },
    }

    for _, case in ipairs(cases) do
        local _, a, s = setup()
        a.currentRotation = case.value
        assert(a:StartCPURuntimeCapture())
        a:EvaluateNextAction()
        a.currentRotation = case.last
        local text = done(a, s)
        has(text, 'Selected key: start=' .. case.start .. '; end=' .. case.ending)

        assert(
            not text:find('private-', 1, true) and not text:find('93849831', 1, true) and not text:find('\1', 1, true)
        )
    end
end)

test('selection is read only at explicit capture start/finish, never per poll or report view', function()
    local f, a, s = setup()
    local reads = 0

    f.env.rawget = function(t, k)
        if t == a and k == 'currentRotation' then
            reads = reads + 1
        end

        return rawget(t, k)
    end

    a.currentRotation = '\1rm:rotation:123'
    a:GetCPURuntimeCaptureReport()
    a:EvaluateNextAction()
    assert(reads == 0)
    assert(a:StartCPURuntimeCapture())
    local started = reads
    assert(started > 0 and started <= 2)

    for _ = 1, 9 do
        a:EvaluateNextAction()
        a:GetCPURuntimeCaptureReport()
    end

    assert(reads == started, 'hot dispatch/report read selection')
    has(done(a, s), 'Selected key: start=scoped; end=scoped')
    assert(reads > started and reads <= 4)
    local ended = reads

    for _ = 1, 3 do
        a:GetCPURuntimeCaptureReport()
        a:EvaluateNextAction()
    end

    assert(reads == ended)
end)

test('inherited selection is not queried and restricted or changed values stay unavailable', function()
    local f, a, s = setup()
    local prior = getmetatable(a)
    local calls = 0

    setmetatable(a, {
        __index = function(_, k)
            if k == 'currentRotation' then
                calls = calls + 1
                error('selection getter ran')
            end

            if type(prior) == 'table' and type(prior.__index) == 'table' then
                return prior.__index[k]
            end
        end,
    })

    assert(a:StartCPURuntimeCapture())
    has(done(a, s), 'Selected key: start=none; end=none')
    assert(calls == 0)
    local f, b, t = setup()
    b.currentRotation = 'secret-selection'
    f.env.issecretvalue = function(v) return v == 'secret-selection' end
    assert(b:StartCPURuntimeCapture())
    has(done(b, t), 'Selected key: start=unavailable; end=unavailable')
    local f, c, u = setup()
    c.currentRotation = 'changing-selection'

    f.env.issecretvalue = function(v)
        if v == 'changing-selection' then
            c.currentRotation = '\1rm:rotation:3'
        end

        return false
    end

    assert(c:StartCPURuntimeCapture())
    has(done(c, u), 'Selected key: start=unavailable; end=scoped')
end)

test('selection readability reentry retires a starting capture without replacing newer evaluator', function()
    local f, a, s = setup()
    local newer = function() return 'newer' end
    a.currentRotation = 'reentry-selection'

    f.env.issecretvalue = function(v)
        if v == 'reentry-selection' then
            a.currentRotation = nil
            a.EvaluateNextAction = newer
            a:CancelCPURuntimeCapture()
        end

        return false
    end

    assert(not a:StartCPURuntimeCapture())
    assert(a.EvaluateNextAction == newer and not a:IsCPURuntimeCaptureRunning())
    assert(s.measures == 0 and s.calls == 0)
end)

finish()
