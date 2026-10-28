local function read(path)
    local f = assert(io.open(path))
    local s = f:read('*a')
    f:close()
    return s
end

local prefix = assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))
local fixture = assert(loadstring(prefix .. '\nreturn fixture'))()
local test, finish = dofile('tests/fixtures/addon.lua').suite()
local keys = { 'cpu_capture', 'cpu_report', 'cpu_runtime_capture', 'cpu_runtime_report', 'cast_capture', 'cast_report' }

for _, width in ipairs({ 380, 1000, 1400, 1800, 2800 }) do
    test('runtime diagnostics capture-column geometry at parent' .. width, function()
        local f, parent = fixture()
        local a = f.addon
        parent:SetSize(width, 600)

        a.StartCPURuntimeCapture = function()
            error('drawing must not capture')
        end

        a.GetCPURuntimeCaptureReport = function() return 'runtime report' end
        a.IsCPURuntimeCaptureRunning = function() return false end
        a.RunCastCaptureAction = function() return true, '' end
        a.GetCastCaptureStatusText = function() return 'idle' end
        local called = {}

        a.RunCPUProfileAction = function(_, action)
            called[#called + 1] = action
            return true, ''
        end

        local p = a:OpenNativeSettings(parent, 'General')
        local widthAvailable = p.columnSingle and p.fullWidth or p.columnWidth
        local rects = {}

        for _, key in ipairs(keys) do
            local b = assert(p.fields[key], 'missing ' .. key)
            assert(b:GetFontString():GetStringWidth() + 20 <= b:GetWidth(), 'caption clipped')
            local v = b.point

            rects[#rects + 1] = {
                left = v[2],
                right = v[2] + b:GetWidth(),
                top = -v[3],
                bottom = -v[3] + b:GetHeight(),
            }

            assert(v[2] >= 0 and v[2] + b:GetWidth() <= widthAvailable + .01)
        end

        for i = 1, #rects do
            for j = i + 1, #rects do
                local x, y = rects[i], rects[j]

                assert(
                    not (x.left < y.right and y.left < x.right and x.top < y.bottom and y.top < x.bottom),
                    'controls overlap'
                )
            end
        end

        assert(#called == 0)
        p.fields.cpu_runtime_capture:Click()
        p.fields.cpu_runtime_report:Click()
        assert(called[1] == 'runtime' and called[2] == 'runtimereport')
        local stale = p.fields.cpu_runtime_capture.scripts.OnClick
        p:Release()
        stale()
        assert(#called == 2)
    end)
end

test('runtime controls have authored help without requiring a settings Apply', function()
    local f, parent = fixture()
    local a = f.addon
    a.StartCPURuntimeCapture = function() end
    local p = a:OpenNativeSettings(parent, 'General')
    local found = {}

    for _, row in ipairs(a:GetGeneralOptionHelp()) do
        found[row.id] = row
    end

    for _, id in ipairs({ 'cpu_runtime_capture', 'cpu_runtime_report' }) do
        local r = assert(found[id], id .. ' help missing')
        assert(type(r.text) == 'string' and not r.text:find('Help.General.', 1, true))
    end

    local live = a:CopySettingsData(a.db.profile)
    local draft = a:CopySettingsData(p:SettingsData())
    a.RunCPUProfileAction = function() return true, '' end
    p.fields.cpu_runtime_capture:Click()
    assert(a:SettingsDataEqual(live, a.db.profile) and a:SettingsDataEqual(draft, p:SettingsData()))
end)

finish()
