-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Real General form/layout with modeled 7px font metrics, not native clipping proof.
-- Diagnostics are four capture columns (CPU, Runtime, Memory, Casts): a capture
-- button above its report button. The native profiler probe has no button; it
-- stays a /rm perf probe command.
local function read(path)
    local f = assert(io.open(path))
    local text = f:read('*a')
    f:close()
    return text
end

local prefix = assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))
local fixture = assert(loadstring(prefix .. '\nreturn fixture', '@cpu-probe-layout-fixture'))()
local test, finish = dofile('tests/fixtures/addon.lua').suite()

local columns = {
    { 'cpu_capture', 'cpu_report' },
    { 'cpu_runtime_capture', 'cpu_runtime_report' },
    { 'memory_capture', 'memory_report' },
    { 'cast_capture', 'cast_report' },
}

local observedColumns = {}

local function page(width, translated)
    local f, parent = fixture()
    local a = f.addon
    parent:SetSize(width, 600)

    if translated then
        f.libraries['AceLocale-3.0']:GetLocale(
            'rotationmaster'
        )['Stop runtime capture'] = 'Translated stop of the native runtime capture'
    end

    local calls = 0

    a.RunCPUProfileAction = function()
        calls = calls + 1
        return true, ''
    end

    a.StartCPURuntimeCapture = function()
        error('drawing must not capture')
    end

    a.StartMemoryCapture = function()
        error('drawing must not capture')
    end

    a.RunCastCaptureAction = function()
        calls = calls + 1
        return true, ''
    end

    local p = a:OpenNativeSettings(parent, 'General')
    assert(calls == 0, 'drawing invokes diagnostics')
    return f, a, p
end

local function geometry(width, translated)
    local f, a, p = page(width, translated)
    local available = p.columnSingle and p.fullWidth or p.columnWidth
    local blocks = {}

    for _, keys in ipairs(columns) do
        local top, bottom = assert(p.fields[keys[1]], 'missing ' .. keys[1]), assert(
            p.fields[keys[2]],
            'missing ' .. keys[2]
        )

        for _, b in ipairs({ top, bottom }) do
            assert(b:GetFontString():GetStringWidth() + 20 <= b:GetWidth() + .01, 'caption clipped at width' .. width)
        end

        local t, r = top.point, bottom.point
        assert(t[1] == 'TOPLEFT' and r[1] == 'TOPLEFT')

        assert(
            t[2] == r[2] and r[3] == t[3] - 28 and top:GetWidth() == bottom:GetWidth(),
            'report is not stacked under its capture'
        )

        assert(t[2] >= 0 and t[2] + top:GetWidth() <= available + .01, keys[1] .. ' outside column')

        blocks[#blocks + 1] = {
            left = t[2],
            right = t[2] + top:GetWidth(),
            top = -t[3],
            bottom = -r[3] + bottom:GetHeight(),
        }
    end

    local used = 0

    for _, b in ipairs(blocks) do
        if b.top == blocks[1].top then
            used = used + 1
        end
    end

    observedColumns[used] = true

    for i = 1, #blocks do
        for j = i + 1, #blocks do
            local x, y = blocks[i], blocks[j]

            assert(
                not (x.left < y.right and y.left < x.right and x.top < y.bottom and y.top < x.bottom),
                'capture columns overlap'
            )
        end
    end

    for _, key in ipairs({ 'cpu_cancel', 'cpu_probe', 'memory_stop', 'cast_stop', 'cast_clear' }) do
        assert(not p.fields[key], key .. ' should be gone')
    end

    p:Release()
end

for _, width in ipairs({ 380, 1000, 1400, 1800 }) do
    test('capture columns measured geometry at parent' .. width, function()
        geometry(width, false)
    end)
end

for _, width in ipairs({ 380, 1800, 2800 }) do
    test('localized capture caption adapts at parent' .. width, function()
        geometry(width, true)
    end)
end

test('capture geometry exercises four, two and one column layouts', function()
    assert(observedColumns[4] and observedColumns[2] and observedColumns[1], 'missing column counts')
end)

test('capture dispatch is explicit and bypasses pending edits without changing live or draft settings', function()
    local f, parent = fixture()
    local a = f.addon
    a.db.profile.poll = .15
    local calls = {}

    a.RunCPUProfileAction = function(...)
        assert(select('#', ...) == 2 and select(1, ...) == a)
        calls[#calls + 1] = select(2, ...)
        return true, 'capture started'
    end

    local p = a:OpenNativeSettings(parent, 'General')
    local b = assert(p.fields.cpu_capture, 'missing capture')
    assert(#calls == 0)

    local edit = p:Edit('invalid', 'Unrelated', '', function() return nil end, function()
        error('must not flush')
    end)

    edit:SetText('invalid')
    edit.scripts.OnTextChanged(edit, true)
    local before = a:CopySettingsData(p:SettingsData())
    local live = a:CopySettingsData(a.db.profile)
    local dirty = p:IsSettingsDraftDirty()
    b:Click()
    assert(calls[1] == 'start' and p.message:GetText() == 'capture started')
    assert(a:SettingsDataEqual(before, p:SettingsData()) and a:SettingsDataEqual(live, a.db.profile))
    assert(p:IsSettingsDraftDirty() == dirty)
    local stale = b.scripts.OnClick
    p:Release()
    stale()
    assert(#calls == 1)
end)

test('capture callbacks reject replaced page and profile leases', function()
    for _, mode in ipairs({ 'redraw', 'profile' }) do
        local f, parent = fixture()
        local a = f.addon
        local calls = 0

        a.RunCPUProfileAction = function()
            calls = calls + 1
            return true, ''
        end

        local p = a:OpenNativeSettings(parent, 'General')
        local callback = assert(p.fields.cpu_capture, 'missing capture').scripts.OnClick

        if mode == 'redraw' then
            p:Draw()
        else
            a.db.profile = {}
        end

        callback()
        assert(calls == 0, mode .. ' stale capture executed')
    end
end)

test('CPU action reentry cannot message a retired General page', function()
    for _, mode in ipairs({ 'release', 'profile' }) do
        local f, parent = fixture()
        local a = f.addon
        local p
        local calls, messages = 0, 0

        a.RunCPUProfileAction = function()
            calls = calls + 1

            if mode == 'release' then
                p:Release()
            else
                a.db.profile = {}
            end

            return true, 'retired'
        end

        p = a:OpenNativeSettings(parent, 'General')

        p.Message = function()
            messages = messages + 1
        end

        assert(p.fields.cpu_capture, 'missing capture'):Click()
        assert(calls == 1 and messages == 0, mode .. ' late message')
    end
end)

test('the probe has neither a General button nor a page Help row and keeps its command', function()
    local f, parent = fixture()
    local a = f.addon
    local p = a:OpenNativeSettings(parent, 'General')
    assert(not p.fields.cpu_probe and not p.fields.cpu_cancel, 'retired buttons are still drawn')

    for _, row in ipairs(a:GetGeneralOptionHelp()) do
        assert(
            row.id ~= 'cpu_probe' and row.id ~= 'cpu_cancel' and row.id ~= 'memory_stop',
            'retired control still has page help: ' .. tostring(row.id)
        )
    end

    -- The command is the probe's only entry point; its usage line is checked with the other locale entries below. The page
    -- Help text of the retired probe, cancel and memory-stop controls (Help.General.cpu_probe, cpu_cancel, memory_stop) had no
    -- reader once their rows went, so those strings left the catalog and are not asserted.
    assert(type(a.HandlePerformanceCommand) == 'function', 'probe command lost')
end)

test('probe report states and the perf command usage have explicit locale entries', function()
    local f = fixture()
    local L = f.libraries['AceLocale-3.0']:GetLocale('rotationmaster')

    for _, key in ipairs({
        'Callback arguments', 'Callback calls', 'Callback returns',
        'Capability probe only; no evaluator or gameplay was measured.', 'Native profiler probe',
        'Native profiler probe is already running.',
        'Native profiler probe is unavailable while CPU capture is running.', 'Native profiler probe is unavailable.',
        "Usage: /rm perf cpu||runtime||memory [seconds||start||stop||report], or /rm perf probe", 'call completed',
        'call failed', 'disabled', 'enabled', 'exact', 'malformed', 'mismatch', 'more than one', 'not run', 'present',
        'restricted', 'unavailable (context changed)', 'absent', 'unavailable', 'Native acceptance: unverified'
    }) do
        assert(type(f.translations[key]) == 'string' and #f.translations[key] > 0, 'missing explicit locale ' .. key)
    end

    -- /rm cpu is gone (48d591d1); the one usage line names probe.
    assert(
        L["Usage: /rm perf cpu||runtime||memory [seconds||start||stop||report], or /rm perf probe"]:find(
            '/rm perf probe',
            1,
            true
        ),
        'perf usage omits probe'
    )
end)

finish()
