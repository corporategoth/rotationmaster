-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Actual diagnostic OnDisable and actual native cast adapter; boundary doubles
-- are inherited from the reviewed adapter fixture, not replacement services.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local prefix = assert(read('tests/analytics_capture_controls.lua'):match('^(.-)\ntest%('))
local fixture = assert(loadstring(prefix .. '\nreturn fixture', '@cast-disable-fixture'))()

local function rootFixture()
    local f, a = fixture()
    local chunk = assert(loadfile('Diagnostics/cpu.lua'))
    setfenv(chunk, f.env)
    chunk('rotationmaster', a)
    return f, a
end

local function cleared(f)
    assert(f.service:GetStatus().phase ~= 'running', 'addon shutdown left cast collection running')
    assert(next(f.events) == nil and f.scripts.OnEvent == nil, 'addon shutdown leaked cast subscriptions')
    assert(f.service:GetSnapshot() == nil, 'addon shutdown retained private capture data')
end

test('actual addon shutdown clears active native receipts before embedded timer teardown', function()
    local f, a = rootFixture()
    assert(a:RunCastCaptureAction('start'))
    f:emit('UNIT_SPELLCAST_START', 'player', 'PRIVATE_GUID', 403)
    local timer = f.timers[1]
    a:OnDisable()
    cleared(f)
    assert(timer.cancelled)
    timer.fn()
    cleared(f)
    assert(not a:RunCastCaptureAction('report'))
end)

test('actual shutdown during pending native startup cannot publish an active UI lease', function()
    for _, name in ipairs({ 'client', 'time', 'CreateFrame', 'SetScript', 'RegisterUnitEvent', 'ScheduleTimer' }) do
        local f, a = rootFixture()

        f.hooks[name] = function()
            f.hooks[name] = nil
            a:OnDisable()
        end

        assert(not a:RunCastCaptureAction('start'), name)
        cleared(f)
        assert(not a:RunCastCaptureAction('stop'))
    end
end)

test('shutdown clears casts started by CPU cancellation reentry and never starts either diagnostic at load', function()
    local f, a = rootFixture()
    assert(f.calls == 0 and #f.timers == 0)

    -- Cancellation callbacks may run user-facing completion hooks. If one starts
    -- a cast diagnostic, shutdown must clear it after CPU cancellation returns.
    a.CancelCPUProfile = function()
        assert(a:RunCastCaptureAction('start'))
    end

    a:OnDisable()
    cleared(f)
    assert(f.timers[1].cancelled)
end)

test('shutdown remains callable without the optional UI control module', function()
    local f, a = rootFixture()
    a.ClearCastCaptureForDisable = nil
    a:OnDisable()
    assert(f.calls == 0)
end)

finish()
