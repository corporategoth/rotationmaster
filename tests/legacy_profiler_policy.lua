-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(level)
    local f = F.new()
    local a = f.addon
    local reads = 0
    a.db.profile.loglevel = level

    f.env.GetTimePreciseSec = function()
        reads = reads + 1
        return reads * .01
    end

    f.load('profiler.lua')
    local consume = assert(a.ConsumeLegacyEvaluationProfilerPolicy, 'missing owned profiler policy')
    local initialize, report = consume(a)
    assert(initialize and report)
    return f, a, initialize, report, function() return reads end
end

local function poll(root)
    root:start()

    for _, name in ipairs({ 'environment', 'rotation', 'cooldowns' }) do
        root:child(name):start()
        root:child(name):stop()
    end

    root:stop()
end

test('default and silent use NOOP with six child markers and no legacy clocks', function()
    for _, level in ipairs({ 1, 2 }) do
        local f, a, init, report, reads = fixture(level)
        init(a)
        local root = a.evaluationProfile
        local names = {}
        local child = root.child

        root.child = function(self, name)
            names[#names + 1] = name
            return child(self, name)
        end

        poll(root)
        assert(reads() == 0 and root.count == 0 and #names == 6 and not report(a))
    end
end)

test('debug and verbose retain full timing and nil public factory remains full', function()
    for _, level in ipairs({ 3, 4 }) do
        local f, a, init, report, reads = fixture(level)
        init(a)
        poll(a.evaluationProfile)
        assert(reads() == 8 and a.evaluationProfile.count == 1 and report(a))
        assert(a.evaluationProfile:report(true):find('inclusive', 1, true))
        local public = a:ProfiledCode()
        poll(public)
        assert(public.count == 1 and reads() == 16)
    end
end)

test('mode changes replace only an unmodified owned root and reset the report window', function()
    local f, a, init, report, reads = fixture(2)
    init(a)
    local initial = a.evaluationProfile
    a.db.profile.loglevel = 3
    assert(a:RefreshEvaluationProfilerPolicy())
    local full = a.evaluationProfile
    assert(full ~= initial and full.count == 0)
    poll(full)
    assert(reads() == 8)
    a.db.profile.loglevel = 1
    assert(a:RefreshEvaluationProfilerPolicy())
    assert(a.evaluationProfile ~= full and not report(a))
    poll(a.evaluationProfile)
    assert(reads() == 8)
end)

test('foreign factories and roots keep predecessor dispatch', function()
    local f, a, init, report = fixture(2)
    local args = {}
    local foreign = {}

    a.ProfiledCode = function(_, enabled)
        args[#args + 1] = { enabled }
        return foreign
    end

    init(a)
    assert(a.evaluationProfile == foreign and #args == 1 and args[1][1] == nil and report(a))
    a.db.profile.loglevel = 4
    assert(not a:RefreshEvaluationProfilerPolicy() and a.evaluationProfile == foreign)
    local f, a, init, report = fixture(2)
    init(a)
    a.evaluationProfile = foreign
    assert(not a:RefreshEvaluationProfilerPolicy() and report(a))
end)

test('native capture child wrapper survives changes until restored and footer retry', function()
    local f, a, init, report, reads = fixture(2)
    init(a)
    local root = a.evaluationProfile
    local child = root.child
    root.child = function(self, name) return child(self, name) end
    a.db.profile.loglevel = 3
    assert(not a:RefreshEvaluationProfilerPolicy() and a.evaluationProfile == root)
    poll(root)
    assert(reads() == 0)
    root.child = child
    assert(a:RefreshEvaluationProfilerPolicy() and a.evaluationProfile ~= root)
    poll(a.evaluationProfile)
    assert(reads() == 8)
end)

test('actual native runtime capture retains the root and restores six phase markers', function()
    local f, a, init, report = fixture(2)
    init(a)
    local root = a.evaluationProfile
    local child = root.child
    local events = {}

    a.EvaluateNextAction = function()
        poll(a.evaluationProfile)
    end

    a.IsCPUProfileRunning = function() return false end
    a.ScheduleTimer = function() return {} end
    a.CancelTimer = function() end

    f.env.C_AddOnProfiler = {
        IsEnabled = function() return true end,
        AddMeasuredCallEvent = function(name)
            events[#events + 1] = name
        end,
        MeasureCall = function(fn, ...)
            local value = fn(...)
            return { elapsedMilliseconds = .1, allocatedBytes = 0, deallocatedBytes = 0 }, value
        end,
    }

    f.load('Diagnostics/cpu_runtime.lua')
    assert(a:StartCPURuntimeCapture(10))
    assert(root.child ~= child)
    a.db.profile.loglevel = 3
    assert(not a:RefreshEvaluationProfilerPolicy() and a.evaluationProfile == root)
    a:EvaluateNextAction()
    assert(#events == 6 and events[1] == 'RM:environment:start' and events[6] == 'RM:cooldowns:stop')
    assert(a:CancelCPURuntimeCapture() and root.child == child and a.evaluationProfile == root)
    assert(a:RefreshEvaluationProfilerPolicy() and a.evaluationProfile ~= root)
end)

test('customized root methods are never overwritten', function()
    local f, a, init, report = fixture(2)
    init(a)
    local root = a.evaluationProfile
    root.report = function() return 'foreign' end
    a.db.profile.loglevel = 3
    assert(not a:RefreshEvaluationProfilerPolicy() and a.evaluationProfile == root and report(a))
end)

test('profile refresh is cold and imported final loglevel changes collection', function()
    local f, a, init, report, reads = fixture(2)
    init(a)
    a.InitializeScopedRotationStorage = function() return true end
    f.load('Core/rotation_lifecycle.lua')
    a.db.profile = { loglevel = 4 }
    assert(a:RefreshRotationProfileStorage())
    poll(a.evaluationProfile)
    assert(reads() == 8)
    a.db.profile.loglevel = 1
    assert(a:RefreshRotationProfileStorage())
    poll(a.evaluationProfile)
    assert(reads() == 8)
end)

test('nested refresh during clock capability discovery cannot overwrite the newer root', function()
    local f, a, init, report = fixture(2)
    init(a)
    local fired = false
    f.env.GetTimePreciseSec = nil

    setmetatable(f.env, {
        __index = function(_, key)
            if key == 'GetTimePreciseSec' and not fired then
                fired = true
                a.db.profile.loglevel = 1
                a:RefreshEvaluationProfilerPolicy()
            end

            return _G[key]
        end,
    })

    a.db.profile.loglevel = 3
    assert(not a:RefreshEvaluationProfilerPolicy())
    assert(fired and not report(a))
    poll(a.evaluationProfile)
    assert(a.evaluationProfile.count == 0)
end)

test('General loglevel edits switch only after Apply and Discard preserves live mode', function()
    local h = assert(io.open('tests/settings_pages.lua'))
    local source = h:read('*a')
    h:close()
    -- General logging never consumes the unrelated transfer codec. Keep this
    -- native-form fixture portable on Lua5.1 installations without external bit.
    local setup = assert(source:match('^(.-)\ntest%('))
    local first, last = assert(setup:find('    local codecData[^\n]*\n'))

    setup = setup:sub(1, first - 1)
        .. [=[    for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/export_text.lua','Data/codec.lua','Data/validation.lua','Data/diff.lua','Data/import_session.lua'})do f.load(path)end
]=]
        .. setup:sub(last + 1)

    local make = assert(loadstring(setup .. '\nreturn fixture'))()
    local f, parent = make()
    local a = f.addon
    a.db.profile.loglevel = 2
    f.load('profiler.lua')
    local init = assert(a:ConsumeLegacyEvaluationProfilerPolicy())
    init(a)
    local root = a.evaluationProfile
    local p = a:OpenNativeSettings(parent, 'General')

    local function choose(value)
        p.fields.loglevel:Click()
        local wanted = a.loglevels[value]

        for _, row in ipairs(p.menu.rows) do
            if row:GetText() == wanted then
                row:Click()
                return
            end
        end

        error('missing loglevel')
    end

    choose(3)
    assert(a.db.profile.loglevel == 2 and a.evaluationProfile == root and p:IsSettingsDraftDirty())
    p.fields.cancel:Click()
    assert(a.db.profile.loglevel == 2 and a.evaluationProfile == root)
    choose(3)
    p.fields.apply:Click()
    assert(a.db.profile.loglevel == 3 and a.evaluationProfile ~= root)
    poll(a.evaluationProfile)
    assert(a.evaluationProfile.count == 1)
end)

finish()
