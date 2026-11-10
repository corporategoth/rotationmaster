-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local make = assert(loadstring(
    assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%(')) .. '\nreturn fixture',
    '@general-preview-fixture'
))()

local function fixture(options)
    options = options or {}
    local f, parent = make()
    local a = f.addon
    a.db.profile.preview_masque = options.enabled == true
    local lib = f.env.LibStub

    f.env.LibStub = function(name, silent)
        if name == 'Masque' then
            if options.missing then
                return nil
            end

            return {}
        end

        return lib(name, silent)
    end

    local calls = { refresh = 0, skin = 0, sample = 0 }
    local sample = false
    local skin = 'Blizzard Classic'

    a.RefreshPreviewWindow = function()
        calls.refresh = calls.refresh + 1
    end

    a.GetPreviewSkinChoices = function()
        return {
            { value = 'Blizzard Classic', text = 'Blizzard Classic' },
            { value = 'Test Skin', text = 'Test Skin' },
        },
            a.db.profile.preview_masque and not options.missing
    end

    a.GetPreviewSkin = function() return skin end

    a.SetPreviewSkin = function(_, id)
        calls.skin = calls.skin + 1
        skin = id
        return true
    end

    a.IsPreviewSampleEnabled = function() return sample end

    a.SetPreviewSampleEnabled = function(_, value)
        sample = value == true
        calls.sample = calls.sample + 1
        return sample
    end

    a.db.global.diagnosticCacheBypass = options.direct == true
    f.load('Diagnostics/cache_mode.lua')
    assert(a:InitializeCacheDiagnosticMode(a.db.global))
    local p = a:OpenNativeSettings(parent, options.page or 'Preview')
    return f, a, p, calls
end

local function text(p, wanted)
    for _, t in ipairs(p.pool.text or {}) do
        if t:IsShown() and t:GetText() == wanted then
            return t
        end
    end
end

local function choose(p, wanted)
    p.fields.preview_skin:Click()
    assert(p.menu and p.menu.frame:IsShown())

    for _, row in ipairs(p.menu.rows) do
        if row:GetText() == wanted then
            row:Click()
            return
        end
    end

    error('missing skin choice: ' .. wanted)
end

test('preview lock and unlock persist and update the same window immediately without Apply', function()
    for _, initial in ipairs({ false, true }) do
        local f, a, p = fixture()
        a.db.profile.preview_spells = 3
        a.db.profile.preview_locked = initial
        p:DiscardSettingsDraft()
        p:Draw()
        f.load('UI/preview.lua')
        a:RefreshPreviewWindow()
        local window = a.nextWindow

        for turn = 1, 2 do
            local wanted = initial

            if turn == 1 then
                wanted = not initial
            end

            p.fields.preview_locked:Click()
            assert(a.db.profile.preview_locked == wanted and window.locked == wanted and a.nextWindow == window)

            assert(
                p:SettingsData().profile.preview_locked == wanted and p.draftBaseline.profile.preview_locked == wanted
            )

            assert(
                not p:IsSettingsDraftDirty()
                    and not p.fields.apply:IsEnabled()
                    and not p.fields.preview_locked.rmUnsaved
            )

            assert(window.grip:IsShown() == not wanted)
        end
    end
end)

test('the preview right-click lock keeps an open General page field and draft in step', function()
    for _, initial in ipairs({ false, true }) do
        local f, a, p = fixture()
        a.db.profile.preview_spells = 2
        a.db.profile.preview_locked = initial
        p:DiscardSettingsDraft()
        p:Draw()
        f.load('UI/preview.lua')
        a:RefreshPreviewWindow()
        local window = a.nextWindow
        a.GlowClear = function() end
        p.fields.preview_target_health:Click()
        assert(p:IsSettingsDraftDirty())
        window:MenuEntries()[2].func()

        assert(
            a.db.profile.preview_locked == not initial
                and window.locked == not initial
                and a.nextWindow == window
                and window.frame:IsShown()
        )

        assert(
            p.fields.preview_locked:GetChecked() == not initial
                and p:SettingsData().profile.preview_locked == not initial
                and p.draftBaseline.profile.preview_locked == not initial
        )

        assert(not p.fields.preview_locked.rmUnsaved and p:IsSettingsDraftDirty())
        assert(p:SaveSettingsDraft() and a.db.profile.preview_locked == not initial, 'Apply wrote the old lock back')
        -- A released page no longer receives the menu's lock changes.
        p:Release()
        assert(a.previewLockChanged == nil)
        window:MenuEntries()[2].func()
        assert(a.db.profile.preview_locked == initial)
    end
end)

test('profiles carry the headerless preview migration flag as a Boolean only', function()
    local _, a = fixture()

    assert(
        a:ValidateProfileTransfer({ previewHeaderlessGeometry = true }) and a:ValidateProfileTransfer({
            previewHeaderlessGeometry = false,
        })
    )

    assert(not a:ValidateProfileTransfer({ previewHeaderlessGeometry = 'yes' }))
end)

test('immediate lock preserves unrelated invalid drafts and retires old click handlers', function()
    local _, a, p = fixture()
    p.fields.preview_target_health:Click()
    local draft = p:SettingsData().profile.preview_target_health

    local input = p:Edit('unrelated', 'Unrelated', '', function() return nil end, function()
        error('must not flush')
    end)

    input:SetText('invalid')
    input.scripts.OnTextChanged(input, true)
    p.fields.preview_locked:Click()
    assert(a.db.profile.preview_locked == true and p:IsSettingsDraftDirty())

    assert(
        p:SettingsData().profile.preview_target_health == draft
            and not a.db.profile.preview_target_health
            and input:GetText() == 'invalid'
    )

    local stale = p.fields.preview_locked.scripts.OnClick
    p:DiscardSettingsDraft()
    p:Draw()
    assert(p.fields.preview_locked:GetChecked() and not p:IsSettingsDraftDirty())
    stale()
    assert(a.db.profile.preview_locked == true)
    p.fields.preview_locked:Click()
    assert(a.db.profile.preview_locked == false and not p:IsSettingsDraftDirty())
    local closed = p.fields.preview_locked.scripts.OnClick
    p:Release()
    closed()
    assert(a.db.profile.preview_locked == false)
end)

test('General keeps History and the Preview tab holds the preview and forecast controls and their help', function()
    local _, a, general = fixture({ page = 'General' })
    assert(text(general, 'History') and not text(general, 'Preview') and not text(general, 'Forecast'))
    assert(not general.fields.preview_spells and not general.fields.forecast and not general.fields.preview_skin)

    local preview = a:OpenNativeSettings(general.frame:GetParent(), 'Preview')
    assert(text(preview, 'Preview') and text(preview, 'Forecast') and not text(preview, 'History'))
    assert(preview.fields.preview_spells and preview.fields.forecast and preview.fields.preview_skin)

    local general_help, preview_help = {}, {}

    for _, row in ipairs(a:GetGeneralOptionHelp()) do
        general_help[row.id] = true
    end

    for _, row in ipairs(a:GetPreviewOptionHelp()) do
        preview_help[row.id] = true
    end

    assert(not general_help.preview_skin and not general_help.preview_spells and not general_help.forecast)
    assert(preview_help.preview_skin and preview_help.preview_sample and preview_help.forecast)
    assert(not preview_help.preview_masque and not preview_help.masque_settings)
    assert(not preview.fields.preview_masque and not preview.fields.masque_settings)
end)

test('skin selection immediately uses provider authority and leaves unrelated General draft intact', function()
    local _, a, p, c = fixture({ enabled = true })
    p.fields.preview_target_health:Click()
    assert(p:IsSettingsDraftDirty())
    choose(p, 'Test Skin')
    assert(a:GetPreviewSkin() == 'Test Skin' and c.skin == 1 and c.refresh == 0)
    assert(a.db.profile.preview_masque and p:IsSettingsDraftDirty() and not a.db.profile.preview_target_health)
    p.fields.cancel:Click()
    assert(a:GetPreviewSkin() == 'Test Skin' and a.db.profile.preview_masque)
end)

test('missing or disabled integration has only native default and Preview still works', function()
    for _, options in ipairs({ {}, { missing = true, enabled = true } }) do
        local _, a, p, c = fixture(options)
        assert(p.fields.preview_skin:GetText() == 'Blizzard Classic' and not p.fields.preview_skin:IsEnabled())
        assert(p.fields.preview_sample:IsEnabled())
        p.fields.preview_sample:Click()
        assert(c.sample == 1 and a:IsPreviewSampleEnabled())
        assert(not p:IsSettingsDraftDirty())
    end
end)

test('skin and sample actions do not flush unrelated invalid pending inputs', function()
    local _, a, p, c = fixture({ enabled = true })

    local input = p:Edit('unrelated', 'Unrelated', '', function() return nil end, function()
        error('must not flush')
    end)

    input:SetText('invalid')
    input.scripts.OnTextChanged(input, true)
    choose(p, 'Test Skin')
    assert(c.skin == 1)
    p.fields.preview_sample:Click()
    assert(c.sample == 1 and a:IsPreviewSampleEnabled())
    p.fields.preview_sample:Click()
    assert(c.sample == 2 and not a:IsPreviewSampleEnabled())
end)

test('released skin menu and buttons cannot change provider or sample state', function()
    local _, a, p, c = fixture({ enabled = true })
    p.fields.preview_skin:Click()
    local row

    for _, candidate in ipairs(p.menu.rows) do
        if candidate:GetText() == 'Test Skin' then
            row = candidate
        end
    end

    assert(row)
    local chooseSkin = row.scripts.OnClick
    local sample = p.fields.preview_sample.scripts.OnClick
    p:Release()
    chooseSkin(row)
    sample()
    assert(c.skin == 0 and c.sample == 0)
end)

test('external skin notifications repaint the current dropdown and retire on page release', function()
    local _, a, p = fixture({ enabled = true })
    a.SetPreviewSkin(nil, 'Test Skin')
    a.previewSkinChanged()
    assert(p.fields.preview_skin:GetText() == 'Test Skin')
    local callback = a.previewSkinChanged
    p:Release()
    assert(a.previewSkinChanged == nil)
    callback()
end)

test('initial drawing provider retirement never publishes a skin listener', function()
    local _, a, p = fixture({ enabled = true })

    a.GetPreviewSkinChoices = function()
        p:Release()
        return { { value = 'Test Skin', text = 'Test Skin' } }, true
    end

    p:Draw()
    assert(not p.active and a.previewSkinChanged == nil)
end)

test('provider reentry retires the drawing before menu or message publication', function()
    for _, phase in ipairs({ 'choices', 'get', 'set' }) do
        local _, a, p = fixture({ enabled = true })

        if phase == 'choices' then
            a.GetPreviewSkinChoices = function()
                p:Release()
                return { { value = 'Test Skin', text = 'Test Skin' } }, true
            end
        elseif phase == 'get' then
            a.GetPreviewSkin = function()
                p:Release()
                return 'Test Skin'
            end
        else
            a.SetPreviewSkin = function()
                p:Release()
                return true
            end
        end

        if phase == 'set' then
            choose(p, 'Test Skin')
        else
            p.fields.preview_skin:Click()
        end

        assert(not p.active and not (p.menu and p.menu.frame:IsShown()), phase)
    end
end)

test('skin failure rereads actual selection and reports failure', function()
    local _, a, p, c = fixture({ enabled = true })
    a.SetPreviewSkin = function() return false end
    choose(p, 'Test Skin')
    assert(a:GetPreviewSkin() == 'Blizzard Classic' and p.fields.preview_skin:GetText() == 'Blizzard Classic')
    assert(p.message:GetText() == 'Preview skin is unavailable.')
end)

test('Skin dropdown and compact Preview button share a bounded row', function()
    local _, _, p = fixture({ enabled = true })
    local skin, button = p.fields.preview_skin, p.fields.preview_sample
    local _, sx, sy = skin:GetPoint()
    local _, bx, by = button:GetPoint()
    assert(sy == by and bx >= sx + skin:GetWidth() + 7 and bx + button:GetWidth() <= p.width + .1)
    assert(button:GetWidth() < 180 and skin:GetWidth() > 80)
end)

test(
    'General rows: Enable trio in thirds, captionless preview beside Effect and Magnification, pad under the swatch, Detailed Profiling after Log Level',
    function()
        local _, _, p = fixture({ page = 'General' })

        local function at(c)
            local _, x, y = c:GetPoint()
            return x, -y
        end

        local enable, disable, minimap = p.fields.enable, p.fields.disable_buttons, p.fields.minimap
        local width = enable:GetParent():GetWidth()
        local ex, ey = at(enable)
        local dx, dy = at(disable)
        local mx, my = at(minimap)

        assert(
            ey == dy and dy == my and ex == 0 and math.abs(dx - width / 3) <= 8 and math.abs(mx - 2 * width / 3) <= 8,
            'Enable, Disable Bar Highlighting and Minimap Icon do not share one row in thirds'
        )

        assert(minimap:GetWidth() <= width / 3 + .1, 'Minimap Icon overflows its third')
        assert(not text(p, 'Highlight preview'), 'the preview icon still has a caption')

        for _, t in ipairs(p.pool.labels or {}) do
            assert(not t:IsShown() or t:GetText() ~= 'Highlight preview', 'the preview icon still has a caption')
        end

        local preview = p.fields.preview
        local px, py = at(preview)
        local _, effectY = at(p.fields.effect)
        local _, magY = at(p.fields.magnification)

        assert(
            px <= 8 and py <= effectY + 6 and py + preview:GetHeight() >= magY + 12,
            'the preview icon does not span the Effect and Magnification rows'
        )

        local captions = {}

        for _, t in ipairs(p.pool.labels or {}) do
            if t:IsShown() and (t:GetText() == 'Effect' or t:GetText() == 'Magnification') then
                local x = at(t)
                captions[#captions + 1] = x
            end
        end

        assert(#captions == 2, 'Effect or Magnification lost its caption')

        for _, x in ipairs(captions) do
            assert(x >= px + preview:GetWidth() + 4, 'a caption overlaps the preview icon')
        end

        local sx = at(p.fields.color)
        local padX = at(p.fields.positionPad)
        assert(padX == sx, 'the anchor arrows do not line up with the Highlight Color swatch')
        local log, detail = p.fields.loglevel, p.fields.detailed_profiling
        local lx, ly = at(log)
        local cx, cy = at(detail)

        assert(
            math.abs(cy - ly) <= 4 and cx >= lx + log:GetWidth(),
            'Detailed Profiling is not after Log Level on its row'
        )

        assert(
            detail:GetWidth() <= 22 + 180 and cx + detail:GetWidth() <= detail:GetParent():GetWidth() + .1,
            'Detailed Profiling is wider than its caption'
        )
    end
)

-- Observations are read directly by default and the checkbox turns the cache ON (9d5c7bf7): checked means caching is requested.
test('cache checkbox alone distinguishes active saved mode from a pending reload', function()
    local _, a, p = fixture({ page = 'General' })
    local control = p.fields.cpu_cache_bypass
    assert(control)
    assert(control:GetText() == 'Enable observation cache (reload required)' and control:GetChecked())
    control:Click()
    local loaded, requested, pending = a:GetCacheDiagnosticMode()
    assert(loaded == 'cached' and requested == 'direct' and pending and not control:GetChecked())
    assert(control:GetText() == 'Enable observation cache (pending)')
    control:Click()
    assert(control:GetText() == 'Enable observation cache (reload required)' and control:GetChecked())

    for _, t in ipairs(p.pool.text or {}) do
        assert(
            not (t:GetText() or ''):find('Observation cache:', 1, true)
                and not (t:GetText() or ''):find('Next reload:', 1, true)
        )
    end
end)

test('cache save failure and released click preserve mode and caption', function()
    local _, a, p = fixture({ page = 'General' })
    local control = p.fields.cpu_cache_bypass
    a.SetCacheDiagnosticMode = function() return false end
    control:Click()
    assert(control:GetChecked() and control:GetText() == 'Enable observation cache (reload required)')
    local stale = control.scripts.OnClick
    local calls = 0

    a.SetCacheDiagnosticMode = function()
        calls = calls + 1
    end

    p:Release()
    stale()
    assert(calls == 0)
end)

test(
    'loaded direct reads show the cache unchecked and requesting caching reports pending without a second text row',
    function()
        local _, a, p = fixture({ direct = true, page = 'General' })
        local control = p.fields.cpu_cache_bypass
        assert(not control:GetChecked() and control:GetText() == 'Enable observation cache (reload required)')
        control:Click()
        local loaded, requested, pending = a:GetCacheDiagnosticMode()
        assert(loaded == 'direct' and requested == 'cached' and pending and control:GetChecked())
        assert(control:GetText() == 'Enable observation cache (pending)')
    end
)

test('real Skin dropdown updates existing sample surfaces and follows external Masque selection', function()
    local h = assert(io.open('tests/masque_skin_selection.lua'))
    local source = h:read('*a')
    h:close()
    local backend = assert(loadstring(assert(source:match('^(.-)\ntest%(')) .. '\nreturn fixture'))()
    local _, _, provider = backend()
    local f, a, p = fixture({ enabled = true })
    local lib = f.env.LibStub

    f.env.LibStub = function(name, silent)
        if name == 'Masque' then
            return provider.api, 110210
        end

        return lib(name, silent)
    end

    f.load('Integrations/masque.lua')
    f.load('UI/preview.lua')
    a.db.profile.preview_spells = 0
    p:DiscardSettingsDraft()
    p:Draw()
    p.fields.preview_sample:Click()
    local window = a.nextWindow
    local child = window.icons[1].masqueSurface
    assert(window.sampleCount == 3 and child and child:IsShown())
    local adds, removes = provider.adds, provider.removes
    choose(p, 'Round')
    assert(a.nextWindow == window and window.sampleCount == 3 and window.icons[1].masqueSurface == child)

    assert(
        child.texture.appliedSkin == 'Round'
            and provider.adds == adds
            and provider.removes == removes
            and not p:IsSettingsDraftDirty()
    )

    provider:external('Square')
    assert(p.fields.preview_skin:GetText() == 'Square' and child.texture.appliedSkin == 'Square')
    p.fields.preview_sample:Click()
    assert(not a.nextWindow and a.db.profile.preview_spells == 0)
end)

test('real General Preview action paints transient samples without applying the draft', function()
    local f, a, p = fixture()
    p:DiscardSettingsDraft()
    a.db.profile.preview_spells = 0
    p:Draw()
    f.load('Integrations/masque.lua')
    f.load('UI/preview.lua')
    local dirty = p:IsSettingsDraftDirty()
    p.fields.preview_sample:Click()
    local window = a.nextWindow

    assert(
        a:IsPreviewSampleEnabled()
            and window:Valid()
            and window.sampleCount == 3
            and window.count == 0
            and not window.title
    )

    assert(a.db.profile.preview_spells == 0 and p:IsSettingsDraftDirty() == dirty)
    local stale = p.fields.preview_sample.scripts.OnClick
    p:Release()
    stale()
    assert(a:IsPreviewSampleEnabled())
    a:SetPreviewSampleEnabled(false)
    assert(not a.nextWindow and a.db.profile.preview_spells == 0)
end)

test(
    'the Appearance section picks the painting from a list, shows it centered or the color for a plain box, and holds the look controls',
    function()
        local env, a, p = fixture()
        env.load('UI/preview.lua')
        p:Draw()
        local f = p.fields
        assert(f.preview_art and f.preview_art_image and not f.preview_color, 'a painting is previewed, not a color')

        -- The painting is a row of the five cells, centered across the page.
        local image = f.preview_art_image
        local cell = image.cells[1]:GetWidth()
        assert(image:GetWidth() == cell * 5 and image.point[2] == math.floor((p.fullWidth - cell * 5) / 2))
        assert(image.cells[1]:GetTexture():find('%-w1$') and image.cells[5]:GetTexture():find('%-w5$'))

        f.preview_art:Click()
        local rows = p.menu.rows
        local choices = {}

        for _, entry in ipairs(p.menu.entries or {}) do
            choices[#choices + 1] = entry.text
        end

        assert(#choices == 16, #choices)
        assert(choices[1]:find('^My class %(') and choices[16] == 'Solid background', choices[1] .. '/' .. choices[16])

        p.menu.changed('ROTATION_MASTER', 'Rotation Master')

        assert(
            p:SettingsData().profile.preview_art == 'ROTATION_MASTER'
                and p.fields.preview_art_image.cells[1]:GetTexture():find('rotation%-master%-w1$')
        )

        p.fields.preview_art:Click()

        p.menu.changed('solid', 'Solid background')

        assert(p:SettingsData().profile.preview_art == 'solid' and p:SettingsData().profile.preview_background == false)
        assert(p.fields.preview_color and not p.fields.preview_art_image, 'the color is chosen where the painting was')

        -- Appearance: background, opacity, title, target health, lock and direction come before the preview's own options.
        local function top(field)
            return -select(3, field:GetPoint())
        end

        assert(top(p.fields.preview_art) < top(p.fields.preview_opacity))
        assert(p.columnTop and p.columnTop > 0, 'the two columns start below the appearance section')

        for _, key in ipairs({
            'preview_title',
            'preview_target_health',
            'preview_locked',
            'preview_vertical',
            'preview_reset',
        }) do
            assert(p.fields[key], key)
            assert(top(p.fields[key]) < p.columnTop, key .. ' sits above the columns')
        end
    end
)

test(
    'General has Debugging under History, with one list of captures and reports, a time, Start and Show report',
    function()
        local _, a, first = fixture({ page = 'General' })
        local shown, started = {}, {}

        for _, name in ipairs({
            'RunGlowDiagnostic', 'ShowGlowDiagnostic', 'StopGlowWatch', 'RunPreviewDiagnostic', 'StopPreviewCapture',
            'RunTimelineDiagnostic', 'ShowTimelineDiagnostic', 'RunPremadeSpellDiagnostic', 'RunSecretsDiagnostic',
            'RunTalentDiagnostic', 'RunRaidMarkDiagnostic', 'ShowLuaEditorInputReport', 'StartCPURuntimeCapture',
            'StartMemoryCapture', 'RunCastCaptureAction'
        }) do
            a[name] = a[name] or function() end
        end

        a.RunGlowDiagnostic = function(_, seconds)
            started[#started + 1] = 'glow:' .. tostring(seconds)
        end

        a.RunPremadeSpellDiagnostic = function()
            shown[#shown + 1] = 'spells'
        end

        for _, name in ipairs({ 'IsGlowWatchRunning', 'IsPreviewCaptureRunning', 'IsTimelineWatchRunning' }) do
            a[name] = function() return false end
        end

        -- No glow report has been saved yet; the preview and timeline ones have.
        a.HasGlowReport = function() return false end
        a.HasPreviewReport = function() return true end
        a.HasTimelineReport = function() return true end
        local parent = first.frame:GetParent()
        parent:SetSize(1500, 900)

        -- Draws the page with an entry chosen and returns it.
        local function open(kind)
            a.diagnosticSelection = kind
            return a:OpenNativeSettings(parent, 'General')
        end

        local p = open('glow')
        local f = p.fields
        assert(f.diagnostic and f.diagnostic_seconds and f.diagnostic_start and f.diagnostic_report)

        -- The list holds every capture and report; Glow has no report saved, so its report button is off, and its time can be set.
        local names = {}

        f.diagnostic:Click()

        for _, entry in ipairs(p.menu.entries or {}) do
            names[entry.text] = true
        end

        for _, label in ipairs({
            'CPU report', 'Runtime report', 'Memory report', 'Cast report', 'Glow report', 'Preview report',
            'Timeline report', 'Premade spell report', 'Secret value probe', 'Talent diagnostic', 'Raid mark report',
            'Lua editor report'
        }) do
            assert(names[label], 'not in the list: ' .. label)
        end

        assert(
            not f.diagnostic_report:IsEnabled() and f.diagnostic_start:IsEnabled() and f.diagnostic_seconds:IsEnabled()
        )

        f.diagnostic_seconds:SetText('15')
        f.diagnostic_start:Click()
        assert(started[1] == 'glow:15', tostring(started[1]))

        -- A report that was saved enables the report button; the time of a fixed capture cannot be changed.
        p = open('preview')
        assert(p.fields.diagnostic_report:IsEnabled() and p.fields.diagnostic_seconds:GetText() == '20')
        p = open('cpu')
        assert(not p.fields.diagnostic_seconds:IsEnabled())

        -- A report that is not timed has no Start and no time, and its button makes and opens it.
        p = open('spells')
        assert(not p.fields.diagnostic_start:IsEnabled() and not p.fields.diagnostic_seconds:IsEnabled())
        assert(p.fields.diagnostic_report:IsEnabled())
        p.fields.diagnostic_report:Click()
        assert(shown[1] == 'spells')

        local history, debugging, effect = text(p, 'History'), text(p, 'Debugging Options'), text(p, 'Effect Options')
        assert(history and debugging and effect)
        assert(debugging:GetParent() == history:GetParent() and effect:GetParent() ~= history:GetParent())
        assert(-select(3, debugging:GetPoint()) > -select(3, history:GetPoint()), 'Debugging Options is under History')
    end
)

test('the forecast report lists what was learned per spell, a proc marked, and says when there is nothing', function()
    local f, a = fixture({ page = 'General' })
    f.load('UI/forecast_report.lua')
    local empty = table.concat(a:BuildForecastLearned(), '\n')
    assert(empty:find('Nothing has been learned yet', 1, true))

    a.db.global.forecast = {
        version = 1,
        base = { level = 60, mana = 1000 },
        spells = {
            [116] = {
                casts = 20,
                seen = {
                    [1] = { unit = 'target', duration = 8, n = 20 },
                    [2] = { unit = 'player', duration = 15, n = 3 },
                },
                damage = 123.4,
            },
            [9001] = { cooldown = 120 },
        },
    }

    local text = table.concat(a:BuildForecastLearned(), '\n')
    assert(text:find('(116): 20 casts watched', 1, true))
    assert(text:find('on the target', 1, true) and text:find('seen after 20 of 20 casts', 1, true))
    assert(text:find('on you', 1, true) and text:find('a proc, not projected', 1, true))
    assert(text:find('does about 123 damage', 1, true) and text:find('cooldown 120 seconds', 1, true))
    assert(text:find('Base mana at level 60: 1000', 1, true))
end)

test(
    'the forecast options each have a row, the learned data has a button, and classes the client lacks are named',
    function()
        local env, a, p = fixture()
        env.env.LOCALIZED_CLASS_NAMES_MALE = { MAGE = 'Magier' }
        env.load('UI/preview.lua')
        p:Draw()

        local function top(field)
            return -select(3, field:GetPoint())
        end

        local f = p.fields
        assert(top(f.forecast_delay) > top(f.forecast_percent), 'the seconds option has its own row')
        assert(f.forecast_learned and top(f.forecast_clear) == top(f.forecast_learned), 'Show and Forget share a row')

        f.preview_art:Click()
        local names = {}

        for _, entry in ipairs(p.menu.entries or {}) do
            names[entry.text] = true
        end

        assert(names.Magier and not names.Mage, 'the client names the classes it has')
        assert(names.Evoker and names['Demon Hunter'] and names['Death Knight'] and names['Rotation Master'])
    end
)

test(
    'the forecast panel lists only what was learned beyond the game tables, one spell at a time, with Forget for it',
    function()
        local env, a, p = fixture()
        env.load('UI/preview.lua')
        env.load('UI/forecast_report.lua')
        env.load('Core/forecast.lua')
        a.SpellEffectData = { forever = { rows = '1001=t:900:30' } }
        a.Platform.GetClientFamily = function() return 'forever' end
        a.Forecast:ResetEffects()

        a.db.global.forecast = {
            version = 1,
            base = { level = 60, mana = 1000 },
            spells = {
                -- Seen on every cast, as the tables say: nothing to show.
                [1001] = { casts = 20, seen = { [900] = { unit = 'target', duration = 30, n = 20 } } },
                -- Nothing learned at all.
                [1002] = { casts = 3 },
                -- Beyond the tables: a proc and the damage.
                [1003] = { casts = 20, seen = { [901] = { unit = 'player', duration = 8, n = 3 } }, damage = 55 },
                [1004] = { casts = 20, heal = 30 },
            },
        }

        local list = a:GetForecastLearnedSpells()
        assert(#list == 2 and list[1].id == 1003 and list[2].id == 1004, 'only spells with something beyond the tables')
        p:Draw()

        local f = p.fields
        assert(f.forecast_spell and f.forecast_forget_spell, 'a spell list and its Forget button')

        f.forecast_forget_spell:Click()

        assert(
            a.db.global.forecast.spells[1003] == nil and a.db.global.forecast.spells[1004] ~= nil,
            'only that spell is forgotten'
        )

        assert(a.db.global.forecast.spells[1001] ~= nil, 'the others are kept')

        a.db.global.forecast.spells[1004] = nil
        p:Draw()

        assert(
            not p.fields.forecast_spell and not p.fields.forecast_forget_spell,
            'nothing to pick when nothing is learned'
        )
    end
)

finish()
