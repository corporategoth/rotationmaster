-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.load('UI/cpu_profile.lua')
    local a = f.addon
    local messages, shown = {}, {}

    a.print = function(_, v)
        messages[#messages + 1] = v
    end

    a.ShowConditionText = function(_, text, title)
        shown[#shown + 1] = { text, title }
    end

    return f, a, messages, shown
end

test('runtime capture action starts ten seconds without applying settings or starting cumulative capture', function()
    local _, a, messages = fixture()
    local profile = a.db.profile
    local count = 0

    a.StartCPURuntimeCapture = function(_, duration)
        assert(duration == 10)
        count = count + 1
        return true
    end

    a.StartCPUProfile = function()
        error('wrong capture')
    end

    local ok, text = a:RunCPUProfileAction('runtime')
    assert(ok and count == 1 and text:find('10', 1, true))
    assert(a.db.profile == profile and messages[#messages] == text)
end)

test('runtime report uses existing copyable window without probing or running gameplay', function()
    local _, a, _, shown = fixture()
    local reads = 0

    a.GetCPURuntimeCaptureReport = function()
        reads = reads + 1
        return 'Native runtime measurements'
    end

    a.StartCPURuntimeCapture = function()
        error('must not start')
    end

    assert(a:RunCPUProfileAction('runtimereport'))
    assert(reads == 1 and shown[1][1] == 'Native runtime measurements' and shown[1][2] == 'Runtime profile')
end)

test('runtime capture reports unavailable and running prerequisites honestly', function()
    for _, reason in ipairs({
        'missing-native-profiler',
        'profiler-disabled',
        'already-running',
        'cumulative-running',
        'timer-error',
    }) do
        local _, a, messages = fixture()
        a.StartCPURuntimeCapture = function() return false, reason end
        local ok, text = a:RunCPUProfileAction('runtime')
        assert(not ok and type(text) == 'string' and #text > 0 and messages[#messages] == text)
    end

    local _, a = fixture()
    assert(not a:RunCPUProfileAction('runtime'))
    assert(not a:RunCPUProfileAction('runtimereport'))
end)

test('shared cancel retires active runtime capture without cancelling cumulative capture', function()
    local _, a = fixture()
    local count = 0
    a.IsCPURuntimeCaptureRunning = function() return true end

    a.CancelCPURuntimeCapture = function()
        count = count + 1
        return true
    end

    a.CancelCPUProfile = function()
        error('wrong capture cancelled')
    end

    assert(a:RunCPUProfileAction('cancel'))
    assert(count == 1)
end)

test('shared cancel keeps original cumulative route when runtime capture is inactive', function()
    local _, a = fixture()
    local count = 0
    a.IsCPURuntimeCaptureRunning = function() return false end

    a.CancelCPURuntimeCapture = function()
        error('wrong capture cancelled')
    end

    a.CancelCPUProfile = function()
        count = count + 1
        return true
    end

    assert(a:RunCPUProfileAction('cancel'))
    assert(count == 1)
end)

test('native capability probe refuses active runtime capture before any provider call', function()
    local f, a = fixture()
    a.IsCPUProfileRunning = function() return false end
    a.IsCPURuntimeCaptureRunning = function() return true end

    f.env.C_AddOnProfiler = {
        IsEnabled = function()
            error('provider must not run')
        end,
        MeasureCall = function()
            error('must not measure')
        end,
    }

    local ok, text = a:RunCPUProfileAction('probe')
    assert(not ok and text:find('running', 1, true))
end)

test('runtime completion announces explicit report command without duplicating cancel messages', function()
    local _, a, messages = fixture()
    assert(type(a.OnCPURuntimeCaptureFinished) == 'function')
    a:OnCPURuntimeCaptureFinished('copyable', 'complete')
    assert(#messages == 1 and messages[1]:find('/rm perf runtime report', 1, true))
    a:OnCPURuntimeCaptureFinished('copyable', 'cancelled')
    assert(#messages == 1)
    a:OnCPURuntimeCaptureFinished('copyable', 'invalid')
    assert(#messages == 2)
end)

test('probe rechecks runtime capture witness after provider callbacks', function()
    for _, present in ipairs({ false, true }) do
        local f, a, _, shown = fixture()
        local active = false
        local measures = 0
        a.IsCPUProfileRunning = function() return false end

        if present then
            a.IsCPURuntimeCaptureRunning = function() return active end
        end

        f.env.C_AddOnProfiler = {
            IsEnabled = function()
                active = true

                if not present then
                    a.IsCPURuntimeCaptureRunning = function() return true end
                end

                return true
            end,
            MeasureCall = function(fn, ...)
                measures = measures + 1
                return { elapsedMilliseconds = .1, allocatedBytes = 0, deallocatedBytes = 0 }, fn(...)
            end,
        }

        assert(a:RunCPUProfileAction('probe'))
        assert(measures == 0, 'probe measured while runtime capture was activated')
        assert(shown[1][1]:find('context changed', 1, true))
    end
end)

finish()
