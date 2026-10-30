-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Actual profiler objects plus a controlled native snapshot provider. No replay.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function tuple(...)
    return { n = select('#', ...), ... }
end

local names = {
    'RM:environment:start',
    'RM:environment:stop',
    'RM:rotation:start',
    'RM:rotation:stop',
    'RM:cooldowns:start',
    'RM:cooldowns:stop',
}

local function has(text, s)
    assert(type(text) == 'string' and text:find(s, 1, true), s .. ' missing from report')
end

local function setup(mode)
    local f = F.new()
    local a, e = f.addon, f.env
    local s = { calls = 0, marks = 0, measures = 0, events = {}, now = 100, timers = {} }
    f.load('profiler.lua')
    a.evaluationProfile = a:ProfiledCode()
    s.root = a.evaluationProfile
    s.child = s.root.child
    a.IsCPUProfileRunning = function() return false end
    e.GetTimePreciseSec = function() return s.now end

    a.ScheduleTimer = function(_, fn)
        local t = { fn = fn }
        s.timers[#s.timers + 1] = t
        return t
    end

    a.CancelTimer = function(_, t)
        t.cancelled = true
    end

    a.EvaluateNextAction = function(self, ...)
        assert(self == a)
        s.calls = s.calls + 1
        local p = self.evaluationProfile

        for _, name in ipairs({ 'environment', 'rotation', 'cooldowns' }) do
            p:child(name):start()
            p:child(name):stop()
        end

        return 'RM', nil, false, nil
    end

    s.original = a.EvaluateNextAction
    local provider = { IsEnabled = function() return true end }

    provider.AddMeasuredCallEvent = function(name)
        s.marks = s.marks + 1

        s.events[#s.events + 1] = {
            name = name,
            elapsedMilliseconds = #s.events * .1 + .1,
            allocatedBytes = (#s.events + 1) * 10,
            deallocatedBytes = (#s.events + 1) * 5,
        }
    end

    provider.MeasureCall = function(fn, ...)
        s.measures = s.measures + 1
        s.events = {}
        local r = tuple(fn(...))

        if mode then
            mode(s, a, e, provider)
        end

        return { elapsedMilliseconds = 1, allocatedBytes = 100, deallocatedBytes = 50, events = s.events }, unpack(
            r,
            1,
            r.n
        )
    end

    e.C_AddOnProfiler = provider
    s.provider = provider
    local h = io.open('Diagnostics/cpu_runtime.lua')

    if h then
        h:close()
        f.load('Diagnostics/cpu_runtime.lua')
    end

    assert(type(a.StartCPURuntimeCapture) == 'function', 'runtime capture backend missing')
    return f, a, s
end

local function done(a, s)
    s.now = 110
    s.timers[1].fn()
    return a:GetCPURuntimeCaptureReport()
end

test(
    'six ordered native markers partition one actual dispatch without changing child identities or return tuple',
    function()
        local _, a, s = setup()
        local child = s.child
        local existing = child(s.root, 'environment')
        assert(a:StartCPURuntimeCapture())
        local r = tuple(a:EvaluateNextAction(nil, false))

        assert(
            r.n == 4
                and r[1] == 'RM'
                and r[2] == nil
                and r[3] == false
                and r[4] == nil
                and s.calls == 1
                and s.measures == 1
                and s.marks == 6
        )

        assert(s.root.children.environment == existing)

        for i, n in ipairs(names) do
            assert(s.events[i].name == n)
        end

        local text = done(a, s)
        assert(s.root.child == child)
        has(text, 'Phases: complete=1; unavailable=0')
        has(text, 'selection+macro | time=0.100 ms | allocatedBytes=10 | deallocatedBytes=5')
        has(text, 'publication+tail | time=0.400 ms | allocatedBytes=40 | deallocatedBytes=20')
        has(text, 'native marker overhead is included')
        a:EvaluateNextAction()
        assert(s.marks == 6)
    end
)

test('profiler reset during capture keeps real child method delegation and emits six more markers', function()
    local _, a, s = setup()
    assert(a:StartCPURuntimeCapture())
    a:EvaluateNextAction()
    local previous = s.root.children.environment
    s.root:reset()
    a:EvaluateNextAction()
    assert(s.root.children.environment ~= previous and s.calls == 2 and s.marks == 12)
    has(done(a, s), 'Phases: complete=2; unavailable=0')
end)

test('temporary child wrapper preserves zero arguments nil holes return arity and receiver', function()
    local _, a, s = setup()
    local calls = {}
    local original = s.child

    s.root.child = function(self, ...)
        assert(self == s.root)
        calls[#calls + 1] = tuple(...)

        if select('#', ...) == 0 then
            return 'empty', nil, false, nil
        end

        return original(self, ...), nil, false, nil
    end

    assert(a:StartCPURuntimeCapture())
    local r = tuple(s.root:child())
    assert(r.n == 4 and r[1] == 'empty' and r[2] == nil and r[3] == false and r[4] == nil and calls[1].n == 0)
    local v = tuple(s.root:child('environment', nil, 7, nil))
    assert(v.n == 4 and v[1] == s.root.children.environment and v[3] == false)
    assert(calls[2].n == 4 and calls[2][2] == nil and calls[2][3] == 7 and calls[2][4] == nil and s.marks == 0)
    assert(a:CancelCPURuntimeCapture())
end)

test('missing or throwing marker provider leaves gameplay and total measurement usable', function()
    for _, mode in ipairs({ 'absent', 'throw' }) do
        local _, a, s = setup()

        if mode == 'absent' then
            s.provider.AddMeasuredCallEvent = nil
        else
            s.provider.AddMeasuredCallEvent = function()
                error('PRIVATE_MARKER_FAILURE', 0)
            end
        end

        assert(a:StartCPURuntimeCapture())
        a:EvaluateNextAction()
        local text = done(a, s)
        assert(s.calls == 1 and s.measures == 1 and s.root.child == s.child)
        has(text, 'measured=1')
        has(text, 'Phases: complete=0; unavailable=1')
        assert(not text:find('PRIVATE_', 1, true))
    end
end)

test('incomplete and extra child call sequence excludes phases without skipping evaluator calls', function()
    for _, mode in ipairs({ 'early', 'extra', 'wrong' }) do
        local _, a, s = setup()
        local original = a.EvaluateNextAction

        a.EvaluateNextAction = function(self, ...)
            if mode == 'early' then
                s.calls = s.calls + 1
                return
            end

            if mode == 'extra' then
                self.evaluationProfile:child('extra')
            end
            if mode == 'wrong' then
                self.evaluationProfile:child('rotation')
            end

            return original(self, ...)
        end

        assert(a:StartCPURuntimeCapture())
        a:EvaluateNextAction()
        assert(s.calls == 1)
        local text = done(a, s)
        has(text, 'measured=1')
        has(text, 'Phases: complete=0; unavailable=1')
    end
end)

test('wrong marker name count or cumulative snapshot cannot invent phase differences', function()
    for _, kind in ipairs({
        'name', 'missing', 'extra', 'negative', 'nan', 'backwards', 'past-total', 'alloc-backwards', 'alloc-negative',
        'free-nan', 'free-past-total'
    }) do
        local _, a, s = setup(function(state)
            local events = state.events

            if kind == 'name' then
                events[2].name = 'OTHER'
            elseif kind == 'missing' then
                table.remove(events)
            elseif kind == 'extra' then
                events[7] = events[6]
            elseif kind == 'negative' then
                events[2].elapsedMilliseconds = -1
            elseif kind == 'nan' then
                events[2].elapsedMilliseconds = 0 / 0
            elseif kind == 'backwards' then
                events[2].elapsedMilliseconds = 0
            elseif kind == 'past-total' then
                events[6].elapsedMilliseconds = 2
            elseif kind == 'alloc-backwards' then
                events[2].allocatedBytes = 0
            elseif kind == 'alloc-negative' then
                events[2].allocatedBytes = -1
            elseif kind == 'free-nan' then
                events[2].deallocatedBytes = 0 / 0
            else
                events[6].deallocatedBytes = 51
            end
        end)

        assert(a:StartCPURuntimeCapture())
        a:EvaluateNextAction()
        local text = done(a, s)
        has(text, 'measured=1')
        has(text, 'Phases: complete=0; unavailable=1')
        assert(s.calls == 1)
    end
end)

test('opaque byte snapshots preserve phase time and explicitly withhold byte arithmetic', function()
    local opaque = setmetatable({}, {
        __tostring = function()
            error('opaque tostring')
        end,
    })

    local _, a, s = setup(function(state)
        for _, v in ipairs(state.events) do
            v.allocatedBytes = opaque
            v.deallocatedBytes = opaque
        end
    end)

    assert(a:StartCPURuntimeCapture())
    a:EvaluateNextAction()
    local text = done(a, s)
    has(text, 'Phases: complete=1; unavailable=0')
    has(text, 'environment | time=0.100 ms | allocatedBytes=unavailable | deallocatedBytes=unavailable')
end)

test('restricted native event name or list is excluded before comparison or length arithmetic', function()
    for _, kind in ipairs({ 'name', 'list' }) do
        local f, a, s = setup()
        f.env.canaccessvalue = function(value) return value ~= (kind == 'name' and names[1] or s.events) end
        assert(a:StartCPURuntimeCapture())
        a:EvaluateNextAction()
        local text = done(a, s)
        has(text, 'measured=1')
        has(text, 'Phases: complete=0; unavailable=1')
        assert(s.calls == 1)
    end
end)

test('safe integer byte differences are computed before summation near the exact arithmetic limit', function()
    local _, a, s = setup()
    local safe = 9007199254740991

    s.provider.MeasureCall = function(fn, ...)
        s.measures = s.measures + 1
        s.events = {}
        local r = tuple(fn(...))
        local total = s.measures == 1 and safe - 1 or 11

        for i, event in ipairs(s.events) do
            local v = s.measures == 1 and (i == 1 and 0 or safe - 1) or (i == 1 and 10 or 11)
            event.allocatedBytes = v
            event.deallocatedBytes = v
        end

        return { elapsedMilliseconds = 1, allocatedBytes = total, deallocatedBytes = total, events = s.events }, unpack(
            r,
            1,
            r.n
        )
    end

    assert(a:StartCPURuntimeCapture())
    a:EvaluateNextAction()
    a:EvaluateNextAction()
    local text = done(a, s)
    has(text, 'environment | time=0.200 ms | allocatedBytes=9007199254740991 | deallocatedBytes=9007199254740991')
end)

test('marker replacement during callback invalidates phases and retains newer root method on completion', function()
    local _, a, s = setup()
    local newer = function(self, name, ...) return s.child(self, name, ...) end
    local mark = s.provider.AddMeasuredCallEvent

    s.provider.AddMeasuredCallEvent = function(name)
        mark(name)
        s.root.child = newer
    end

    assert(a:StartCPURuntimeCapture())
    a:EvaluateNextAction()
    assert(s.calls == 1 and s.root.child == newer)
    has(done(a, s), 'Phases: complete=0; unavailable=1')
    assert(s.root.child == newer)
end)

test('replaced profiler root is not decorated mid-capture and original owned root is restored', function()
    local _, a, s = setup()
    assert(a:StartCPURuntimeCapture())
    local newer = a:ProfiledCode()
    local child = newer.child
    a.evaluationProfile = newer
    a:EvaluateNextAction()
    local text = done(a, s)
    assert(s.calls == 1 and s.marks == 0 and s.root.child == s.child and newer.child == child)
    has(text, 'Phases: complete=0; unavailable=1')
end)

test('cancellation restores only owned child wrapper and no marker is emitted outside capture', function()
    local _, a, s = setup()
    assert(a:StartCPURuntimeCapture())
    local wrapper = s.root.child
    assert(wrapper ~= s.child)
    assert(a:CancelCPURuntimeCapture())
    assert(s.root.child == s.child)
    wrapper(s.root, 'environment')
    a:EvaluateNextAction()
    assert(s.marks == 0 and s.calls == 1)
end)

test('original child thrown object propagates exactly once without replay or stale phase acceptance', function()
    local _, a, s = setup()
    local object = {}
    local calls = 0

    s.root.child = function()
        calls = calls + 1
        error(object, 0)
    end

    local child = s.root.child
    assert(a:StartCPURuntimeCapture())
    local ok, err = pcall(a.EvaluateNextAction, a)

    assert(
        not ok
            and err == object
            and calls == 1
            and s.calls == 1
            and s.root.child == child
            and not a:IsCPURuntimeCaptureRunning()
    )
end)

test('nested legitimate evaluation remains once each and phase attribution is withheld', function()
    local _, a, s = setup()
    local original = a.EvaluateNextAction
    local entered = false

    a.EvaluateNextAction = function(self, ...)
        if not entered then
            entered = true
            self:EvaluateNextAction()
        end

        return original(self, ...)
    end

    assert(a:StartCPURuntimeCapture())
    a:EvaluateNextAction()
    assert(s.calls == 2 and s.measures == 1)
    has(done(a, s), 'Phases: complete=0; unavailable=1')
end)

test(
    'actual initialized main and real buttons preserve every native query order and advice in both target states',
    function()
        local fixture = dofile('tests/fixtures/rotation_execution.lua')

        local function equal(a, b)
            if type(a) ~= type(b) then
                return false
            end
            if type(a) ~= 'table' then
                return a == b
            end

            for k, v in pairs(a) do
                if not equal(v, b[k]) then
                    return false
                end
            end

            for k in pairs(b) do
                if a[k] == nil then
                    return false
                end
            end

            return true
        end

        for _, target in ipairs({ false, true }) do
            local function actual(capture)
                local c = fixture({ target = target, buttons = true })
                local a, e = c.a, c.e
                c.load('profiler.lua')
                a.evaluationProfile = a:ProfiledCode()
                local events, timer, marks = {}, nil, 0
                e.GetTimePreciseSec = function() return 100 end
                a.IsCPUProfileRunning = function() return false end

                a.ScheduleTimer = function(_, fn)
                    timer = fn
                    return {}
                end

                a.CancelTimer = function() end

                e.C_AddOnProfiler = {
                    IsEnabled = function() return true end,
                    AddMeasuredCallEvent = function(name)
                        marks = marks + 1

                        events[#events + 1] = {
                            name = name,
                            elapsedMilliseconds = #events * .1 + .1,
                            allocatedBytes = 0,
                            deallocatedBytes = 0,
                        }
                    end,
                    MeasureCall = function(fn, ...)
                        events = {}
                        local r = tuple(fn(...))

                        return { elapsedMilliseconds = 1, allocatedBytes = 0, deallocatedBytes = 0, events = events },
                            unpack(r, 1, r.n)
                    end,
                }

                c.load('Diagnostics/cpu_runtime.lua')

                if capture then
                    assert(a:StartCPURuntimeCapture())
                end

                c.reset(true)
                local advice = {}

                for i = 1, 67 do
                    c.tick()
                    advice[i] = { spell = a.currentSpell, item = a.currentItem, rotation = a.currentRotation }
                end

                local counts, trace = c.snapshot()
                assert(not a.adviceErrorReport and #a.Diagnostics:GetReports() == 0)

                if capture then
                    timer()
                    has(a:GetCPURuntimeCaptureReport(), 'Phases: complete=67; unavailable=0')
                    assert(marks == 402)
                end

                return { counts = counts, trace = trace, advice = advice }
            end

            assert(equal(actual(false), actual(true)), 'actual-main native call/order/advice changed')
        end
    end
)

finish()
