local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function setup(mode)
    local f = F.new()
    local a, e = f.addon, f.env
    local s = { now = 100, calls = 0, coarse = 0, resets = 0 }

    e.GetTime = function()
        s.coarse = s.coarse + 1
        return 100
    end

    e.GetTimePreciseSec = function()
        s.calls = s.calls + 1
        return s.now
    end

    e.debugprofilestart = function()
        s.resets = s.resets + 1
        error('must not reset shared clock')
    end

    if mode == 'debug' then
        e.GetTimePreciseSec = nil

        e.debugprofilestop = function()
            s.calls = s.calls + 1
            return s.now
        end
    elseif mode == 'coarse' then
        e.GetTimePreciseSec = nil
        e.debugprofilestop = nil
    elseif mode == 'absent' then
        e.GetTimePreciseSec = nil
        e.debugprofilestop = nil
        e.GetTime = nil
    end

    f.load('profiler.lua')
    return a, s, e
end

local function has(text, value)
    assert(type(text) == 'string' and text:find(value, 1, true), value .. ' missing')
end

local function close(a, b)
    assert(math.abs(a - b) < .00000001, tostring(a) .. ' != ' .. tostring(b))
end

test('continuous precise clock resolves same-frame work and reports milliseconds', function()
    local a, s = setup()
    local p = a:ProfiledCode()
    assert(s.calls == 0)
    p:start()
    s.now = 100.000003
    p:stop()
    assert(p.count == 1 and s.calls == 2 and s.coarse == 0)
    close(p.total, .000003)
    has(p:report(), '0.003 ms')
    assert(not p:report():find('[clock=', 1, true))
end)

test('cumulative count total min average and maximum preserve seconds in public fields', function()
    local a, s = setup()
    local p = a:ProfiledCode()
    p:start()
    s.now = 100.001
    p:stop()
    p:start()
    s.now = 100.004
    p:stop()
    assert(p.count == 2)
    close(p.total, .004)
    close(p.min, .001)
    close(p.max, .003)
    local r = p:report()
    has(r, 'total=4.000 ms')
    has(r, 'min=1.000 ms')
    has(r, 'avg=2.000 ms')
    has(r, 'max=3.000 ms')
end)

test('children keep their API and detailed output labels inclusive timing', function()
    local a, s = setup()
    local p = a:ProfiledCode()
    p:start()
    local c = p:child('environment')
    assert(c == p:child('environment'))
    c:start()
    s.now = 100.001
    c:stop()
    s.now = 100.005
    p:stop()
    has(p:report(true), 'environment[')
    has(p:report(true), 'inclusive')
    has(p:report(true), '1.000 ms')
    assert(not p:report(false):find('environment', 1, true))
end)

test('debug profiling stopwatch is continuous fallback without resetting shared state', function()
    local a, s = setup('debug')
    local p = a:ProfiledCode()
    p:start()
    close(p.startTime, .1)
    s.now = 100.125
    p:stop()
    close(p.total, .000125)
    has(p:report(), '0.125 ms')
    assert(not p:report():find('[clock=', 1, true))
    assert(s.resets == 0)
end)

test('coarse frame clock fallback keeps report free of clock implementation labels', function()
    local a, s = setup('coarse')
    local p = a:ProfiledCode()
    p:start()
    p:stop()
    assert(p.count == 1 and p.total == 0)
    assert(not p:report():find('[clock=', 1, true))
    has(p:report(), '0.000 ms')
end)

test('missing clocks remain unavailable rather than fabricate zero measurements', function()
    local a = setup('absent')
    local p = a:ProfiledCode()
    p:start()
    p:stop()
    assert(p.count == 0)
    has(p:report(), 'unavailable')
end)

test('negative or nonfinite clock observations never enter cumulative totals', function()
    for _, bad in ipairs({ 99, math.huge, false }) do
        local a, s = setup()
        local p = a:ProfiledCode()
        p:start()
        s.now = bad
        p:stop()
        assert(p.count == 0 and p.total == 0)
        has(p:report(), 'unavailable')
        s.now = 200
        p:start()
        s.now = 200.002
        p:stop()
        assert(p.count == 1)
        close(p.total, .002)
    end
end)

test('explicit false profiler is clock-free and cheap through child chains', function()
    local a, s = setup()
    local p = a:ProfiledCode(false)

    for i = 1, 20 do
        p:start()
        p:child('environment'):start()
        p:child('environment'):stop()
        p:stop()
    end

    assert(s.calls == 0 and s.coarse == 0 and p.count == 0 and p:report(true) == nil and p:child('ignored') == p)
end)

test('default and explicit true collection do not depend on log-level settings', function()
    local a, s = setup()
    a.db.profile.loglevel = 2

    for _, p in ipairs({ a:ProfiledCode(), a:ProfiledCode(true) }) do
        p:start()
        s.now = s.now + .001
        p:stop()
        assert(p.count == 1)
    end
end)

test('stop uses the same clock selected by start even when public slot changes', function()
    local a, s, e = setup()
    local p = a:ProfiledCode()
    p:start()
    e.GetTimePreciseSec = function() return 900 end
    s.now = 100.002
    p:stop()
    close(p.total, .002)
end)

test('reset clears accumulated and pending measurements without reading a clock', function()
    local a, s = setup()
    local p = a:ProfiledCode()
    p:start()
    s.now = 100.001
    p:stop()
    p:child('rotation')
    p:start()
    local before = s.calls
    p:reset()
    p:stop()
    assert(p.count == 0 and p.total == 0 and next(p.children) == nil and p:report() == nil and s.calls == before)
end)

finish()
