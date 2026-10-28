-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(slots)
    local f = F.new()
    dofile('tests/fixtures/native_ui.lua')(f.env)
    local a = f.addon
    a.db.profile.preview_spells = slots or 0
    a.db.profile.preview_opacity = 1
    local queries = 0

    a.Platform.GetSpellInfo = function(_, id)
        queries = queries + 1
        return { iconID = id + 10 }
    end

    a.Platform.GetItemDisplayInfo = function(_, id)
        queries = queries + 1
        return { iconID = id + 20 }
    end

    a.ScheduleTimer = function()
        error('sample scheduled timer')
    end

    a.ScheduleRepeatingTimer = a.ScheduleTimer
    f.load('UI/preview.lua')
    return f, a, function() return queries end
end

local function api(a)
    assert(
        type(a.IsPreviewSampleEnabled) == 'function' and type(a.SetPreviewSampleEnabled) == 'function',
        'sample toggle API missing'
    )
end

local function visible(w)
    local n = 0

    for _, icon in ipairs(w.icons) do
        if icon:IsShown() then
            n = n + 1
        end
    end

    return n
end

test('sample toggle is transient immediately paints default three slots while saved preview stays off', function()
    local _, a, queries = fixture()
    api(a)
    local before = a:CopySettingsData(a.db.profile)
    assert(not a:IsPreviewSampleEnabled() and a:SetPreviewSampleEnabled(true) == true)
    local w = a.nextWindow
    assert(w and w:Valid() and w.frame:IsShown() and w.slots == 3 and w.count == 0 and visible(w) == 3)

    for _, icon in ipairs(w.icons) do
        assert(
            icon.sample and icon.spellId == nil and icon.itemId == nil and type(icon.texture:GetTexture()) == 'string'
        )
    end

    assert(queries() == 0 and a:SettingsDataEqual(before, a.db.profile))
    assert(a:SetPreviewSampleEnabled(false) == false and not a.nextWindow and not w.frame:IsShown())
    assert(a:SettingsDataEqual(before, a.db.profile))
end)

test('real advice replaces all samples and disabling mode leaves real configured preview intact', function()
    local _, a, queries = fixture(3)
    api(a)
    a:SetPreviewSampleEnabled(true)
    local w = a.nextWindow
    w:AddRecommendation(403)
    assert(w.count == 1 and visible(w) == 1 and not w.icons[1].sample and w.icons[1].spellId == 403 and queries() == 1)

    assert(
        a:SetPreviewSampleEnabled(false) == false
            and a.nextWindow == w
            and w.count == 1
            and w.icons[1]:IsShown()
            and w.icons[1].spellId == 403
    )

    a:SetPreviewSampleEnabled(true)
    assert(w.count == 1 and visible(w) == 1 and w.icons[1].spellId == 403)
    w:ReleaseChildren()
    w:PauseLayout()
    w:ResumeLayout()
    w:DoLayout()
    assert(w.count == 0 and visible(w) == 3 and w.icons[1].sample)
end)

test('publication batching never mixes sample icons with partial real advice or refills disabled mode', function()
    local _, a = fixture(5)
    api(a)
    a:SetPreviewSampleEnabled(true)
    local w = a.nextWindow
    w:ReleaseChildren()
    w:PauseLayout()
    assert(visible(w) == 0)
    w:AddRecommendation(403)
    w:AddRecommendation(8042)
    w:ResumeLayout()
    w:DoLayout()
    assert(w.count == 2 and visible(w) == 2 and not w.icons[3]:IsShown())
    w:ReleaseChildren()
    w:PauseLayout()
    a:SetPreviewSampleEnabled(false)
    w:ResumeLayout()
    w:DoLayout()
    assert(w.count == 0 and visible(w) == 0)
end)

test(
    'sample tooltip has no spell or item hyperlink and stale callbacks cannot follow later advice or leases',
    function()
        local f, a = fixture(2)
        api(a)
        local labels, links = 0, 0

        f.env.GameTooltip = {
            IsOwned = function() return true end,
            Hide = function() end,
            SetOwner = function() end,
            SetText = function(_, text)
                assert(text == 'Sample icon')
                labels = labels + 1
            end,
            SetHyperlink = function()
                links = links + 1
            end,
        }

        a:SetPreviewSampleEnabled(true)
        local w = a.nextWindow
        local enter = w.icons[1].scripts.OnEnter
        enter()
        assert(labels == 1 and links == 0)
        w:AddRecommendation(403)
        enter()
        assert(labels == 1 and links == 0)
        w.icons[1].scripts.OnEnter()
        assert(links == 1)
        w:Release()
        enter()
        assert(labels == 1)
        a:CreateNativePreviewWindow()
        enter()
        assert(labels == 1)
    end
)

test('profile replacement and release invalidate sample state and old callbacks', function()
    local _, a = fixture(2)
    api(a)
    a:SetPreviewSampleEnabled(true)
    local w = a.nextWindow
    local old = a.db.profile
    local stale = w:MenuEntries()[2].func
    a.db.profile = { preview_spells = 0 }
    assert(not a:IsPreviewSampleEnabled())
    a:RefreshPreviewWindow()
    assert(not a.nextWindow)
    a:SetPreviewSampleEnabled(true)
    local fresh = a.nextWindow
    stale()
    assert(a:IsPreviewSampleEnabled() and fresh:Valid() and a.db.profile.preview_locked == nil)
    fresh:Release()
    assert(not a:IsPreviewSampleEnabled())
    a:SetPreviewSampleEnabled(true)
    assert(a.nextWindow == fresh and fresh:Valid() and fresh.frame:IsShown())
    fresh:Release()
    a:RefreshPreviewWindow()
    assert(not a.nextWindow)
    a.db.profile = old
    assert(not a:IsPreviewSampleEnabled())
    a:SetPreviewSampleEnabled(true)
    assert(not a.nextWindow.close)
    a:SetPreviewSampleEnabled(false)
    assert(not a:IsPreviewSampleEnabled() and a.nextWindow and a.nextWindow.sampleCount == 0)
end)

test('samples honor configured geometry opacity and pooled Masque surfaces without fake metadata', function()
    local _, a, queries = fixture(4)
    api(a)
    local attaches = 0
    a.db.profile.preview_vertical = true
    a.db.profile.preview_icon_size = 80
    a.db.profile.preview_opacity = 0

    a.ConfigureMasquePreview = function(_, w)
        attaches = attaches + 1

        for i = 1, w.slots do
            local icon = w:EnsureIcon(i)
            icon.masqueOwner = {}

            icon.masqueSurface = {
                texture = {
                    SetTexture = function(self, v)
                        self.value = v
                    end,
                },
            }
        end
    end

    a.ResizeMasquePreviewIcon = function() end
    a:SetPreviewSampleEnabled(true)
    local w = a.nextWindow

    assert(
        w.slots == 4 and w.frame:GetWidth() == 80 and w.frame:GetHeight() == 320 and not w.header and visible(w) == 4
    )

    for _, icon in ipairs(w.icons) do
        assert(icon.masqueSurface.texture.value == icon.texture:GetTexture() and icon:GetAlpha() == 1)
    end

    local before = attaches

    for i = 1, 3 do
        w:ReleaseChildren()
        w:PauseLayout()
        w:ResumeLayout()
        w:DoLayout()
    end

    assert(attaches == before and queries() == 0)
end)

test('cold refresh honors a temporary sample window and invalid setter values retain state', function()
    local _, a = fixture()
    api(a)
    a:SetPreviewSampleEnabled(true)
    local w = a.nextWindow
    a:RefreshPreviewWindow()
    assert(a.nextWindow == w and w.slots == 3 and w.count == 0)
    assert(a:SetPreviewSampleEnabled('true') == true and a:IsPreviewSampleEnabled())
    a:SetPreviewSampleEnabled(false)
    assert(a:SetPreviewSampleEnabled(nil) == false and not a:IsPreviewSampleEnabled())
end)

test('real main empty and populated publication batches keep sample art outside advice state', function()
    local make = dofile('tests/fixtures/rotation_execution.lua')

    for _, target in ipairs({ false, true }) do
        local c = make({ target = target, buttons = true })
        c.load('UI/preview.lua')
        local a = c.a
        assert(a.db.profile.preview_spells == 0)
        a:SetPreviewSampleEnabled(true)
        local w = a.nextWindow
        c.tick()

        if target then
            assert(
                w.count == 1
                    and w.sampleCount == 0
                    and visible(w) == 1
                    and w.icons[1].spellId == 403
                    and a.currentSpell == 403
            )
        else
            assert(w.count == 0 and w.sampleCount == 3 and visible(w) == 3 and a.currentSpell == nil)
        end

        local spell = a.currentSpell
        local history = a.spellHistory
        a:SetPreviewSampleEnabled(false)

        assert(
            not a.nextWindow
                and a.db.profile.preview_spells == 0
                and a.currentSpell == spell
                and a.spellHistory == history
        )
    end
end)

for _, mode in ipairs({ 'disabled', 'missing', 'inactive' }) do
    test('actual main ' .. mode .. ' rotation path retains samples outside advice state', function()
        local make = dofile('tests/fixtures/rotation_execution.lua')
        local c = make({ target = true, buttons = true, inactive = mode == 'inactive' })
        c.load('UI/preview.lua')
        local a = c.a

        if mode == 'inactive' then  -- fixture startup enabled advice before disabling its timer
            a.currentSpell = nil
        end

        a:SetPreviewSampleEnabled(true)
        local w = a.nextWindow

        if mode ~= 'inactive' then
            c.tick()
            assert(w.count == 1 and a.currentSpell == 403)
        end

        if mode == 'disabled' then
            a:DisableRotation()
        elseif mode == 'missing' then
            a.currentRotation = 'missing-sample-test-rotation'
            c.tick()
        else
            a:EvaluateNextActionInternal()
        end

        assert(
            a.currentRotation == nil and a.currentSpell == nil and not a.rotationTimer,
            'rotation must remain stopped'
        )

        assert(
            a:IsPreviewSampleEnabled() and w:Valid() and w.count == 0 and w.sampleCount == 3 and visible(w) == 3,
            'empty stopped publisher erased samples: ' .. mode
        )

        for _, icon in ipairs(w.icons) do
            assert(icon.sample and icon.spellId == nil and icon.itemId == nil)
        end

        assert(not w.title, 'the preview has no title bar')
        c.tick()
        assert(w.sampleCount == 3 and visible(w) == 3, 'stopped timer must not be needed to refill samples')
        a:SetPreviewSampleEnabled(false)
        assert(not a.nextWindow and a.db.profile.preview_spells == 0)
    end)
end

test('actual Masque lifecycle skins static sample art once and empty batches add no provider work', function()
    local f = assert(io.open('tests/masque_preview.lua'))
    local s = f:read('*a')
    f:close()
    local setup = assert(s:match('^(.-)\ntest%('))
    local make = assert(loadstring(setup .. '\nreturn fixture', '@sample-masque-fixture'))()
    local _, a, p = make()
    a.db.profile.preview_masque = true
    a:SetPreviewSampleEnabled(true)
    local w = a.nextWindow
    assert(p.adds == 3 and p.groups == 1 and visible(w) == 3 and w.count == 0)

    for _, icon in ipairs(w.icons) do
        assert(icon.masqueOwner and icon.masqueSurface.texture:GetTexture() == icon.texture:GetTexture())
    end

    local discoveries = p.discoveries

    for i = 1, 4 do
        w:ReleaseChildren()
        w:PauseLayout()
        w:ResumeLayout()
        w:DoLayout()
    end

    assert(p.adds == 3 and p.reskins == 0 and p.removes == 0 and p.discoveries == discoveries)
    w:AddRecommendation(403)
    assert(w.count == 1 and visible(w) == 1 and w.icons[1].masqueSurface.texture:GetTexture() == 413)
end)

finish()
