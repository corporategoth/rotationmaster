local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(p)
    local h = assert(io.open(p))
    local s = h:read('*a')
    h:close()
    return s
end

local function prefix(p, name)
    local s = assert(read(p):match('^(.-)\ntest%('))
    return assert(loadstring(s .. '\nreturn ' .. name, '@cache-opt-in-fixture:' .. p))()
end

local late = prefix('tests/cache_mode_lifecycle.lua', 'fixture')
local lateWithoutSaved = prefix('tests/cache_mode_lifecycle.lua', 'make')
local settingsSource = assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))
-- General never exports/imports. Load its real data types without the unrelated
-- codec fixture's LuaJIT-only bit dependency, leaving production UI untouched.
local codec = "local codecData,codecDeps=dofile('tests/fixtures/codec.lua')();a.RotationData=codecData;a.NewRotationCodec=function() return codecData.NewCodec(codecDeps) end"
local first, last = assert(settingsSource:find(codec, 1, true))

settingsSource = settingsSource:sub(1, first - 1)
    .. "a.RotationData={};for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua'})do f.load(path)end"
    .. settingsSource:sub(last + 1)

local settings = assert(loadstring(settingsSource .. '\nreturn fixture', '@cache-opt-in-general-fixture'))()
local runtime = prefix('tests/cpu_runtime.lua', 'setup')

local function modes(a, loaded, requested, pending)
    local x, y, z = a:GetCacheDiagnosticMode()

    assert(
        x == loaded and y == requested and z == pending,
        'unexpected modes ' .. tostring(x) .. '/' .. tostring(y) .. '/' .. tostring(z)
    )
end

local function has(s, x)
    assert(type(s) == 'string' and s:find(x, 1, true), 'missing ' .. x)
end

local function module(value)
    local f = F.new()
    local a = f.addon
    a.db.global.diagnosticCacheBypass = value
    f.load('Diagnostics/cache_mode.lua')
    assert(a:InitializeCacheDiagnosticMode(a.db.global))
    return f, a
end

test('actual late SavedVariables with absent setting selects direct without writing a preference', function()
    local _, fresh = lateWithoutSaved({})
    modes(fresh, 'direct', 'direct', false)
    assert(rawget(fresh.db.global, 'diagnosticCacheBypass') == nil)
    local _, a = late(nil)
    modes(a, 'direct', 'direct', false)
    assert(rawget(a.db.global, 'diagnosticCacheBypass') == nil)
    local calls = 0

    local fn = function()
        calls = calls + 1
        return calls
    end

    local cache = {}
    assert(a.getCached(cache, fn) == 1 and a.getCached(cache, fn) == 2 and next(cache) == nil)
end)

test('explicit legacy Boolean choices keep meaning across initialization and reload', function()
    for _, value in ipairs({ false, true }) do
        local _, a = late(value)
        local expected = value and 'direct' or 'cached'
        modes(a, expected, expected, false)
        assert(rawget(a.db.global, 'diagnosticCacheBypass') == value)
    end

    local _, a = module(nil)
    assert(a:SetCacheDiagnosticMode('cached'))
    modes(a, 'direct', 'cached', true)
    local _, b = module(a.db.global.diagnosticCacheBypass)
    modes(b, 'cached', 'cached', false)
    assert(b:SetCacheDiagnosticMode('direct'))
    modes(b, 'cached', 'direct', true)
    local _, c = module(b.db.global.diagnosticCacheBypass)
    modes(c, 'direct', 'direct', false)
end)

test('malformed absent or inherited preference follows direct default without invoking metadata', function()
    for _, v in ipairs({ 0, 'false', {} }) do
        local _, a = module(v)
        modes(a, 'direct', 'direct', false)
        assert(a.db.global.diagnosticCacheBypass == v)
    end

    local f = F.new()
    local a = f.addon
    local reads = 0

    a.db.global = setmetatable({}, {
        __index = function()
            reads = reads + 1
            return false
        end,
    })

    f.load('Diagnostics/cache_mode.lua')
    assert(a:InitializeCacheDiagnosticMode(a.db.global))
    modes(a, 'direct', 'direct', false)
    assert(reads == 0)
end)

test('Enable observation cache checkbox shows requested cached state and saves independently from draft', function()
    local f, parent = settings()
    local a = f.addon
    local requested = 'direct'
    local count = 0
    a.GetCacheDiagnosticMode = function() return 'direct', requested, requested ~= 'direct' end

    a.SetCacheDiagnosticMode = function(_, v)
        requested = v
        count = count + 1
        return true
    end

    local p = a:OpenNativeSettings(parent, 'General')
    local c = assert(p.fields.cpu_cache_bypass)
    assert(not c:GetChecked())
    has(c:GetText(), 'Enable observation cache')
    has(c.tooltip, 'allocation')

    local input = p:Edit('invalid_probe', 'Probe', '', function() return nil end, function()
        error('cache switch flushed draft')
    end)

    input:SetText('bad')
    input.scripts.OnTextChanged(input, true)
    local dirty = p:IsSettingsDraftDirty()
    c:Click()
    assert(requested == 'cached' and c:GetChecked() and count == 1)
    has(c:GetText(), 'pending')
    assert(p:IsSettingsDraftDirty() == dirty and input:GetText() == 'bad')
    c:Click()
    assert(requested == 'direct' and not c:GetChecked() and count == 2)
    has(c:GetText(), 'reload')
    local click = c.scripts.OnClick
    p:Release()
    click()
    assert(count == 2)
end)

test('actual General Apply and Discard preserve the independently saved cache choice', function()
    local f, parent = settings()
    local a = f.addon
    a.db.profile.poll = .15
    f.load('Diagnostics/cache_mode.lua')
    assert(a:InitializeCacheDiagnosticMode(a.db.global))
    modes(a, 'direct', 'direct', false)
    local p = a:OpenNativeSettings(parent, 'General')
    p:SettingsData().profile.poll = .2
    p.fields.cpu_cache_bypass:Click()
    assert(a.db.global.diagnosticCacheBypass == false)
    modes(a, 'direct', 'cached', true)
    assert(p:SaveSettingsDraft())
    assert(a.db.profile.poll == .2 and a.db.global.diagnosticCacheBypass == false)
    p:Draw()
    p:SettingsData().profile.poll = .3
    p.fields.cpu_cache_bypass:Click()
    assert(a.db.global.diagnosticCacheBypass == true)
    p:DiscardSettingsDraft()
    p:Draw()

    assert(
        a.db.profile.poll == .2
            and a.db.global.diagnosticCacheBypass == true
            and not p.fields.cpu_cache_bypass:GetChecked()
    )

    modes(a, 'direct', 'direct', false)
end)

test(
    'cache full Help uses positive option label and explains default/reload independently of compiled facts',
    function()
        local f, parent = settings()
        local a = f.addon
        a.GetCacheDiagnosticMode = function() return 'cached', 'cached', false end
        a.SetCacheDiagnosticMode = function() return true end
        local p = a:OpenNativeSettings(parent, 'General')
        assert(p.fields.cpu_cache_bypass:GetChecked())
        local row

        for _, v in ipairs(a:GetGeneralOptionHelp()) do
            if v.id == 'cpu_cache_bypass' then
                row = v
            end
        end

        assert(row and row.title == 'Enable observation cache')
        has(row.text, 'default')
        has(row.text, 'getCached')
        has(row.text, 'reload')
        has(row.text, 'condition')
    end
)

test('runtime report snapshots actual cache mode only at capture boundaries', function()
    local _, a, s = runtime()
    local mode = 'direct'
    local calls = 0

    a.GetCacheDiagnosticMode = function()
        assert(not s.insideMeasure, 'cache mode read inside native measured dispatch')
        calls = calls + 1
        return mode
    end

    local measure = s.provider.MeasureCall

    s.provider.MeasureCall = function(...)
        s.insideMeasure = true
        local result = { measure(...) }
        s.insideMeasure = false
        return unpack(result)
    end

    assert(calls == 0 and a:StartCPURuntimeCapture())
    assert(calls == 1)

    for i = 1, 4 do
        a:EvaluateNextAction()
    end

    assert(calls == 1)
    mode = 'cached'
    s.now = 110
    s.timers[1].fn()
    assert(calls == 2)
    has(a:GetCPURuntimeCaptureReport(), 'Observation cache: start=direct; end=cached')
    a:GetCPURuntimeCaptureReport()
    assert(calls == 2)
end)

test('runtime report withholds failed restricted malformed and replaced cache mode providers', function()
    for _, case in ipairs({ 'throw', 'restricted', 'malformed', 'replace' }) do
        local f, a, s = runtime()
        local opaque = {}
        local secret = 'PRIVATE_CACHE_MODE'

        a.GetCacheDiagnosticMode = function()
            if case == 'throw' then
                error(secret)
            elseif case == 'malformed' then
                return opaque
            elseif case == 'replace' then
                a.GetCacheDiagnosticMode = function() return 'cached' end
                return 'direct'
            end

            return 'direct'
        end

        if case == 'restricted' then
            f.env.canaccessvalue = function(v) return v ~= 'direct' end
        end

        assert(a:StartCPURuntimeCapture())
        a:EvaluateNextAction()
        s.now = 110
        s.timers[1].fn()
        local report = a:GetCPURuntimeCaptureReport()
        has(report, 'Observation cache: start=unavailable; end=unavailable')
        assert(not report:find(secret, 1, true))
    end
end)

finish()
