-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The recommendation preview has no title bar or close button: it is only its
-- icons and their padded background. Unlocked, the body moves it and a hover
-- grip resizes it; a right-click menu locks, unlocks or opens General. Only
-- Preview Spells shows (>0) or hides (0) it.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(options)
    options = options or {}
    local f = F.new()
    dofile('tests/fixtures/native_ui.lua')(f.env)
    local a = f.addon
    a.db.profile.preview_spells = options.spells or 2
    a.db.profile.preview_opacity = 1

    for key, value in pairs(options.profile or {}) do
        a.db.profile[key] = value
    end

    a.Platform.GetSpellInfo = function(_, id) return { name = 'Spell ' .. id, iconID = id + 10 } end
    local masque

    if options.masque then
        masque = { adds = 0, removes = 0, members = {} }

        masque.group = {
            AddButton = function(_, button, regions)
                masque.adds = masque.adds + 1
                masque.members[button] = regions
            end,
            RemoveButton = function(_, button)
                masque.removes = masque.removes + 1
                masque.members[button] = nil
            end,
            ReSkin = function() end,
        }

        local lib = f.env.LibStub

        f.env.LibStub = function(name, silent)
            if name == 'Masque' then
                return { Group = function() return masque.group end }, 110210
            end

            return lib(name, silent)
        end

        f.env.C_AddOns = { GetAddOnMetadata = function() return '12.1.0' end }
        f.load('Integrations/masque.lua')
    end

    f.load('UI/preview.lua')
    return f, a, masque
end

local function counters(w)
    local c = { moves = 0, stops = 0, sizes = 0 }

    w.frame.StartMoving = function()
        c.moves = c.moves + 1
    end

    w.frame.StopMovingOrSizing = function()
        c.stops = c.stops + 1
    end

    w.frame.StartSizing = function(_, corner)
        assert(corner == 'BOTTOMRIGHT')
        c.sizes = c.sizes + 1
    end

    return c
end

local function menuStubs(f)
    local m = { opened = 0, items = {} }
    f.env.UIDropDownMenu_CreateInfo = function() return {} end

    f.env.UIDropDownMenu_AddButton = function(info)
        m.items[#m.items + 1] = info
    end

    f.env.UIDropDownMenu_Initialize = function(frame, init, mode)
        m.frame, m.mode = frame, mode
        m.items = {}
        init()
    end

    f.env.ToggleDropDownMenu = function(level, _, frame, anchor)
        assert(level == 1 and frame == m.frame and anchor == 'cursor')
        m.opened = m.opened + 1
    end

    return m
end

test('the window has no title bar, title text or close button and reserves no title height', function()
    local _, a = fixture()
    local w = a:CreateNativePreviewWindow()
    w:AddRecommendation(403)
    assert(w.header == nil and w.title == nil and w.close == nil, 'header chrome still exists')

    for _, spells in ipairs({ 1, 2, 5 }) do
        for _, vertical in ipairs({ false, true }) do
            a.db.profile.preview_spells = spells
            a.db.profile.preview_vertical = vertical
            w:Configure()
            local long = spells * 64 + 8

            assert(
                w.frame:GetWidth() == (vertical and 72 or long) and w.frame:GetHeight() == (vertical and long or 72),
                'layout height includes a title'
            )
        end
    end

    a.db.profile.preview_vertical = false
    a.db.profile.preview_spells = 2
    w:Configure()
    local _, _, _, x, y = w.icons[1]:GetPoint(1)
    assert(x == 4 and y == -4, 'first icon is not at the padded top-left corner')
    -- Resizing divides the frame without subtracting a title.
    w:Resize(2 * 80 + 8, 80 + 8)
    assert(w.iconSize == 80 and w.frame:GetHeight() == 88)
    a.db.profile.preview_opacity = 0
    w:Configure()
    assert(w.frame:GetHeight() == 80 and select(5, w.icons[1]:GetPoint(1)) == 0)
end)

test('unlocked the body and the icons move the window and the drop saves its position', function()
    local f, a = fixture()
    local w = a:CreateNativePreviewWindow()
    w:AddRecommendation(403)
    local c = counters(w)
    assert(w.frame.mouseEnabled == true and w.frame.drags[1] == 'LeftButton', 'unlocked body is not a drag handle')
    w.frame.GetPoint = function() return 'TOPLEFT', f.env.UIParent, 'TOPLEFT', 120, -40 end
    w.frame.scripts.OnDragStart(w.frame)
    assert(c.moves == 1)
    w.frame.scripts.OnDragStop(w.frame)
    assert(c.stops == 1)
    local saved = a.db.profile.preview_window
    assert(saved.point == 'TOPLEFT' and saved.relpoint == 'TOPLEFT' and saved.xoffs == 120 and saved.yoffs == -40)
    local icon = w.icons[1]
    assert(icon.drags[1] == 'LeftButton')
    w.frame.GetPoint = function() return 'BOTTOMLEFT', f.env.UIParent, 'BOTTOMLEFT', 7, 8 end
    icon.scripts.OnDragStart(icon)
    icon.scripts.OnDragStop(icon)
    assert(c.moves == 2 and a.db.profile.preview_window.yoffs == 8)
    -- A stop without a start (e.g. a drag begun before unlocking) saves nothing.
    a.db.profile.preview_window = nil
    w.frame.scripts.OnDragStop(w.frame)
    assert(a.db.profile.preview_window == nil)
    -- Fully transparent: only icons remain, so the empty background passes the
    -- mouse through, but an unlocked window can still be dragged by an icon.
    a.db.profile.preview_opacity = 0
    w:Configure()
    assert(w.frame.mouseEnabled == false and not w.grip:IsShown())
    icon.scripts.OnDragStart(icon)
    assert(c.moves == 3)
    icon.scripts.OnDragStop(icon)
end)

test('locked the window ignores drags and the background lets clicks through', function()
    local f, a = fixture({ profile = { preview_locked = true } })
    local w = a:CreateNativePreviewWindow()
    w:AddRecommendation(403)
    local c = counters(w)
    assert(w.locked and w.frame.mouseEnabled == false, 'locked background intercepts the mouse')
    assert(not w.grip:IsShown())
    w.frame.scripts.OnDragStart(w.frame)
    w.icons[1].scripts.OnDragStart(w.icons[1])
    w.grip.scripts.OnMouseDown(w.grip, 'LeftButton')
    w.frame.scripts.OnDragStop(w.frame)
    w.icons[1].scripts.OnDragStop(w.icons[1])
    assert(c.moves == 0 and c.sizes == 0 and a.db.profile.preview_window == nil)
    -- Locking mid-drag stops the move and the drop is not saved.
    a.db.profile.preview_locked = false
    w:Configure()
    w.frame.scripts.OnDragStart(w.frame)
    assert(c.moves == 1)
    a.db.profile.preview_locked = true
    local stops = c.stops
    w:Configure()
    assert(c.stops == stops + 1)
    w.frame.GetPoint = function() return 'TOPLEFT', f.env.UIParent, 'TOPLEFT', 1, 1 end
    w.frame.scripts.OnDragStop(w.frame)
    assert(a.db.profile.preview_window == nil)
end)

test('the resize grip is unobtrusive: present when unlocked, visible only on hover', function()
    local _, a = fixture()
    local w = a:CreateNativePreviewWindow()
    local c = counters(w)
    assert(w.grip:IsShown() and w.grip:GetAlpha() == 0, 'grip is visible without hover')
    w.frame.scripts.OnEnter(w.frame)
    assert(w.grip:GetAlpha() == 1)
    w.frame.scripts.OnLeave(w.frame)
    assert(w.grip:GetAlpha() == 0)
    w.grip.scripts.OnEnter(w.grip)
    assert(w.grip:GetAlpha() == 1)
    w.grip.scripts.OnLeave(w.grip)
    assert(w.grip:GetAlpha() == 0)
    w.grip.scripts.OnMouseDown(w.grip, 'RightButton')
    assert(c.sizes == 0)
    w.grip.scripts.OnMouseDown(w.grip, 'LeftButton')
    assert(c.sizes == 1)
    w.grip.scripts.OnMouseUp(w.grip)
    assert(c.stops == 1)
    w.frame.scripts.OnEnter(w.frame)
    a.db.profile.preview_locked = true
    w:Configure()
    assert(not w.grip:IsShown() and w.grip:GetAlpha() == 0)
end)

test('right-click menu offers lock and settings only and never hides the window', function()
    local f, a = fixture()
    local m = menuStubs(f)
    local w = a:CreateNativePreviewWindow()
    w:AddRecommendation(403)
    local opened

    a.ShowConfig = function(_, section)
        opened = section
    end

    w.frame.scripts.OnMouseUp(w.frame, 'LeftButton')
    assert(m.opened == 0)
    w.frame.scripts.OnMouseUp(w.frame, 'RightButton')
    assert(m.opened == 1 and m.mode == 'MENU')

    assert(
        #m.items == 3
            and m.items[1].isTitle
            and m.items[2].text == 'Lock position and size'
            and m.items[2].checked == false
            and m.items[3].text == 'Open General settings'
    )

    for _, item in ipairs(m.items) do
        local text = tostring(item.text):lower()
        assert(not text:find('hide') and not text:find('close'), 'menu offers a way to hide the preview')
    end

    m.items[2].func()
    assert(a.db.profile.preview_locked == true and w.locked and w.frame.mouseEnabled == false)
    assert(a.db.profile.preview_spells == 2 and a.nextWindow == w and w.frame:IsShown() and w.icons[1]:IsShown())
    -- Locked, the background no longer takes the mouse; an icon still opens the menu to unlock.
    local icon = w.icons[1]
    assert(icon.clicks[1] == 'RightButtonUp')
    icon.scripts.OnClick(icon, 'LeftButton')
    assert(m.opened == 1)
    icon.scripts.OnClick(icon, 'RightButton')
    assert(m.opened == 2 and m.items[2].checked == true)
    m.items[2].func()
    assert(a.db.profile.preview_locked == false and not w.locked and w.frame.mouseEnabled == true)
    m.items[3].func()
    assert(opened == 'General' and a.nextWindow == w and w.frame:IsShown())
end)

test('visibility follows Preview Spells alone', function()
    local f, a = fixture({ spells = 0 })
    menuStubs(f)
    a:RefreshPreviewWindow()
    assert(not a.nextWindow)
    a.db.profile.preview_spells = 3
    a:RefreshPreviewWindow()
    local w = a.nextWindow
    assert(w and w.frame:IsShown())
    -- Every menu action leaves it shown and the setting untouched.
    a.ShowConfig = function() end

    for _, entry in ipairs(w:MenuEntries()) do
        if entry.func then
            entry.func()
        end
    end

    assert(a.nextWindow == w and w.frame:IsShown() and a.db.profile.preview_spells == 3)
    a.db.profile.preview_spells = 0
    a:RefreshPreviewWindow()
    assert(not a.nextWindow and not w.frame:IsShown())
    a.db.profile.preview_spells = 1
    a:RefreshPreviewWindow()
    assert(a.nextWindow and a.nextWindow.frame:IsShown())
    -- The retired close callback and its settings hook are gone.
    assert(a.preview_closed_func == nil)
end)

test('stale menu rows from a released window or replaced profile do nothing', function()
    local f, a = fixture()
    menuStubs(f)
    local w = a:CreateNativePreviewWindow()
    local opened = 0

    a.ShowConfig = function()
        opened = opened + 1
    end

    local entries = w:MenuEntries()
    w:Release()
    entries[2].func()
    entries[3].func()
    assert(a.db.profile.preview_locked ~= true and opened == 0)
    w = a:CreateNativePreviewWindow()
    entries = w:MenuEntries()
    a:RefreshPreviewWindow()
    a.db.profile = { preview_spells = 1 }
    entries[2].func()
    assert(a.db.profile.preview_locked == nil)
end)

test('positions saved with the old header shift once so the icons stay put', function()
    local cases = {
        { 'TOPLEFT', -50, -70 },
        { 'TOP', -50, -70 },
        { 'TOPRIGHT', -50, -70 },
        { 'LEFT', 30, 20 },
        { 'CENTER', 0, -10 },
        { 'RIGHT', 30, 20 },
        { 'BOTTOMLEFT', 90, 90 },
        { 'BOTTOM', 90, 90 },
        { 'BOTTOMRIGHT', 90, 90 },
    }

    for _, case in ipairs(cases) do
        local _, a = fixture({
            profile = { preview_window = { point = case[1], relpoint = 'BOTTOMLEFT', xoffs = 11, yoffs = case[2] } },
        })

        local w = a:CreateNativePreviewWindow()
        local p = a.db.profile

        assert(
            p.previewHeaderlessGeometry == true
                and p.preview_window.point == case[1]
                and p.preview_window.relpoint == 'BOTTOMLEFT'
                and p.preview_window.xoffs == 11
        )

        assert(p.preview_window.yoffs == case[3], case[1] .. ' yoffs ' .. tostring(p.preview_window.yoffs))
        assert(w.frame.point[1] == case[1] and w.frame.point[5] == case[3])
        -- Only once per profile: re-creating or refreshing never shifts again.
        w:Release()
        w = a:CreateNativePreviewWindow()
        a:RefreshPreviewWindow()
        assert(p.preview_window.yoffs == case[3])
    end

    -- At opacity zero the old layout reserved no header, so nothing moves.
    local _, a = fixture({
        profile = {
            preview_opacity = 0,
            preview_window = { point = 'TOPLEFT', relpoint = 'TOPLEFT', xoffs = 5, yoffs = -50 },
        },
    })

    a.db.profile.preview_opacity = 0
    a:CreateNativePreviewWindow()
    assert(a.db.profile.preview_window.yoffs == -50 and a.db.profile.previewHeaderlessGeometry == true)
    -- A profile without a saved position has nothing to shift and is not written.
    _, a = fixture()
    a.db.profile.preview_window = nil
    local w = a:CreateNativePreviewWindow()

    assert(
        a.db.profile.previewHeaderlessGeometry == nil
            and a.db.profile.preview_window == nil
            and w.frame.point[1] == 'CENTER'
            and w.frame.point[5] == 0
    )

    -- A position saved by a headerless drag is marked and kept as-is.
    local f
    f, a = fixture()
    w = a:CreateNativePreviewWindow()
    w.frame.GetPoint = function() return 'TOPLEFT', f.env.UIParent, 'TOPLEFT', 3, -9 end
    w.frame.scripts.OnDragStart(w.frame)
    w.frame.scripts.OnDragStop(w.frame)
    assert(a.db.profile.previewHeaderlessGeometry == true)
    w:Release()
    a:CreateNativePreviewWindow()
    assert(a.db.profile.preview_window.yoffs == -9)
    -- The saved icon size never included the header, so it is untouched.
    _, a = fixture({ profile = { preview_icon_size = 96 } })
    w = a:CreateNativePreviewWindow()
    assert(w.iconSize == 96 and w.frame:GetHeight() == 104)
end)

test('Masque skinning keeps working with and without the header and the new mouse handling', function()
    for _, enabled in ipairs({ false, true }) do
        local f, a, masque = fixture({ masque = true, profile = { preview_masque = enabled } })
        local m = menuStubs(f)
        local w = a:CreateNativePreviewWindow()
        w:AddRecommendation(403)
        w:AddRecommendation(8042)
        local icon = w.icons[1]

        if enabled then
            assert(
                masque.adds == 2
                    and icon.masqueSurface
                    and icon.masqueSurface.texture:GetTexture() == 413
                    and masque.members[icon.masqueSurface]
            )

            assert(icon.masqueSurface.mouseEnabled == false, 'Masque surface would steal the icon mouse')
        else
            assert(masque.adds == 0 and not icon.masqueSurface)
        end

        local c = counters(w)
        icon.scripts.OnDragStart(icon)
        icon.scripts.OnClick(icon, 'RightButton')
        assert(c.moves == 1 and m.opened == 1)
        w:Resize(2 * 80 + 8, 88)
        assert(w.iconSize == 80 and (not enabled or icon.masqueSurface:GetWidth() == 80))
        a.db.profile.preview_vertical = true
        w:Configure()
        assert(w.frame:GetHeight() == 2 * 80 + 8 and (not enabled or masque.members[icon.masqueSurface]))
        a.db.profile.preview_masque = not enabled
        w:Configure()
        assert(enabled and not next(masque.members) or not enabled and masque.adds == 2)
    end
end)

finish()
