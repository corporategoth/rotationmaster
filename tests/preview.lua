-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    dofile('tests/fixtures/native_ui.lua')(f.env)
    local a = f.addon
    a.db.profile.preview_spells = 3
    a.db.profile.preview_opacity = 1
    a.Platform.GetSpellInfo = function(_, id) return { name = 'Spell ' .. id, iconID = id + 10 } end

    f.env.C_Item = {
        GetItemInfo = function(id) return 'Item ' .. id, nil, nil, nil, nil, nil, nil, nil, nil, id + 20 end,
    }

    local h = io.open('UI/preview.lua')

    if h then
        h:close()
        f.load('UI/preview.lua')
    end

    return f, a
end

test('native preview fits square icons in either direction and resizes with fixed proportions', function()
    local _, a = fixture()
    assert(a.CreateNativePreviewWindow, 'native preview missing')
    local w = a:CreateNativePreviewWindow()
    assert(w.frame:GetWidth() == 200 and w.frame:GetHeight() == 72 and not w.status)
    w:AddRecommendation(403)
    w:AddRecommendation(8042)
    assert(w.icons[1]:GetWidth() == 64 and w.icons[1].texture:GetTexture() == 413)
    w:Resize(296, 104)

    assert(
        w.iconSize == 96 and w.frame:GetWidth() == 296 and w.frame:GetHeight() == 104 and w.icons[1]:GetWidth() == 96
    )

    a.db.profile.preview_vertical = true
    w:Configure()
    assert(w.frame:GetWidth() == 104 and w.frame:GetHeight() == 296)
    assert(w.icons[2].point[4] == 4 and w.icons[2].point[5] == -100)
end)

test('transparent and locked previews retain icons without blank mouse intercepts or resize callbacks', function()
    local _, a = fixture()
    assert(a.CreateNativePreviewWindow)
    local w = a:CreateNativePreviewWindow()
    w:AddRecommendation(403)
    local moves, resizes = 0, 0

    w.frame.StartMoving = function()
        moves = moves + 1
    end

    w.frame.StartSizing = function()
        resizes = resizes + 1
    end

    a.db.profile.preview_locked = true
    w:Configure()
    w.frame.scripts.OnDragStart(w.frame)
    w.icons[1].scripts.OnDragStart(w.icons[1])
    w.grip.scripts.OnMouseDown(w.grip, 'LeftButton')
    assert(moves == 0 and resizes == 0 and not w.frame.mouseEnabled)
    a.db.profile.preview_opacity = 0
    w:Configure()

    assert(
        not w.header
            and not w.grip:IsShown()
            and w.icons[1]:IsShown()
            and w.icons[1]:GetAlpha() == 1
            and w.frame:GetHeight() == 64
    )
end)

test('native preview pools icons handles item identity and rejects stale profile callbacks', function()
    local f, a = fixture()
    assert(a.CreateNativePreviewWindow)
    local w = a:CreateNativePreviewWindow()
    w:AddRecommendation(6603, 123)
    local icon = w.icons[1]
    assert(icon.itemId == 123 and icon.texture:GetTexture() == 143)
    w:ReleaseChildren()
    assert(not icon:IsShown() and not icon.scripts.OnEnter)
    w:AddRecommendation(403)
    assert(w.icons[1] == icon and not icon.itemId)
    local lock = w:MenuEntries()[2].func
    a.db.profile = { preview_spells = 2 }
    lock()
    assert(a.db.profile.preview_locked == nil)
    w:Release()
    assert(not w.frame:IsShown() and not icon.scripts.OnEnter)
    w = a:CreateNativePreviewWindow()
    assert(w.active and w.profile == a.db.profile and not w.close and a.nextWindow == w)
end)

test('preview count direction axis resizing and saved movement remain consistent across profiles', function()
    local f, a = fixture()
    local profile = a.db.profile

    for n = 1, 5 do
        for _, vertical in ipairs({ false, true }) do
            profile.preview_spells = n
            profile.preview_vertical = vertical
            profile.preview_icon_size = 64
            local w = a:CreateNativePreviewWindow()

            assert(
                w.frame:GetWidth() == (vertical and 1 or n) * 64 + 8
                    and w.frame:GetHeight() == (vertical and n or 1) * 64 + 8
            )

            w:Resize(w.frame:GetWidth(), (vertical and n or 1) * 80 + 8)
            assert(w.iconSize == 80)
        end
    end

    local w = a.nextWindow
    w.frame.GetPoint = function() return 'TOPLEFT', f.env.UIParent, 'TOPLEFT', 100, -50 end
    w.frame.scripts.OnDragStart(w.frame)
    w.frame.scripts.OnDragStop(w.frame)
    assert(profile.preview_window.xoffs == 100 and profile.preview_window.yoffs == -50)
    w:Release()
    w = a:CreateNativePreviewWindow()
    assert(w.frame.point[1] == 'TOPLEFT' and w.frame.point[4] == 100 and w.frame.point[5] == -50)
    local stale = w.frame.scripts.OnDragStop
    w.frame.scripts.OnDragStart(w.frame)
    a.db.profile = { preview_spells = 1 }
    stale()
    assert(not a.db.profile.preview_window)
    a:RefreshPreviewWindow()
    assert(a.nextWindow.profile == a.db.profile)
    a.db.profile.preview_spells = 0
    a:RefreshPreviewWindow()
    assert(not a.nextWindow and not w.frame:IsShown())
end)

local function geometrySpy(w)
    local writes = {}

    local function watch(object, keys, prefix)
        for _, key in ipairs(keys) do
            local original = object[key]

            object[key] = function(...)
                writes[prefix .. '.' .. key] = (writes[prefix .. '.' .. key] or 0) + 1
                return original(...)
            end
        end
    end

    watch(w.frame, { 'SetSize' }, 'frame')

    for i, icon in ipairs(w.icons) do
        watch(icon, { 'ClearAllPoints', 'SetPoint', 'SetSize', 'SetAlpha' }, 'icon' .. i)
    end

    return function()
        local count = 0

        for _, value in pairs(writes) do
            count = count + value
        end

        return count
    end
end

test('unchanged preview refresh performs no geometry writes while metadata and hover stay fresh', function()
    local f, a = fixture()
    local w = a:CreateNativePreviewWindow()

    for i = 1, 3 do
        w:AddRecommendation(400 + i)
    end

    w:ReleaseChildren()
    w:AddRecommendation(403)
    w:DoLayout()
    local writes = geometrySpy(w)
    local metadata, tooltip = 0, {}
    local texture = 1000

    a.Platform.GetSpellInfo = function(_, id)
        metadata = metadata + 1
        return { iconID = texture + id }
    end

    f.env.GameTooltip = {
        IsOwned = function() return true end,
        Hide = function()
            tooltip[#tooltip + 1] = 'hide'
        end,
        SetOwner = function()
            tooltip[#tooltip + 1] = 'owner'
        end,
        SetHyperlink = function(_, value)
            tooltip[#tooltip + 1] = value
        end,
    }

    for i = 1, 10 do
        w:ReleaseChildren()
        w:PauseLayout()
        w:AddRecommendation(403)
        w:ResumeLayout()
        w:DoLayout()
    end

    assert(writes() == 0, 'unchanged preview native writes=' .. writes())
    assert(metadata == 10 and w.count == 1 and w.icons[1]:IsShown() and not w.icons[2]:IsShown())
    assert(w.icons[1].texture:GetTexture() == 1403)
    texture = 2000
    w:ReleaseChildren()
    w:AddRecommendation(8042)
    w:DoLayout()
    assert(metadata == 11 and w.icons[1].texture:GetTexture() == 10042 and writes() == 0)
    w.icons[1].scripts.OnEnter()
    assert(tooltip[#tooltip] == 'spell:8042')
    local before = #tooltip
    w.icons[1].scripts.OnLeave()
    assert(#tooltip == before + 1 and tooltip[#tooltip] == 'hide')
end)

test('new unanchored and multiply anchored icons get one exact owned anchor', function()
    local _, a = fixture()
    local w = a:CreateNativePreviewWindow()
    w:AddRecommendation(403)
    local icon = w.icons[1]
    assert(icon:GetNumPoints() == 1)
    local getter = icon.GetPoint

    for _, multiple in ipairs({ false, true }) do
        icon:ClearAllPoints()

        if multiple then
            icon:SetPoint('TOPLEFT', w.frame, 'TOPLEFT', 1, 2)
            icon:SetPoint('BOTTOMRIGHT', w.frame, 'BOTTOMRIGHT', 3, 4)
            assert(icon:GetNumPoints() == 2)
        end

        icon.GetPoint = function()
            error('layout read an absent or ambiguous anchor')
        end

        w:DoLayout()
        icon.GetPoint = getter
        local point, parent, relative, x, y = icon:GetPoint(1)

        assert(
            icon:GetNumPoints() == 1
                and point == 'TOPLEFT'
                and parent == w.frame
                and relative == 'TOPLEFT'
                and x == 4
                and y == -4
        )
    end

    -- SetPoint replaces a same-name anchor; it does not append duplicates.
    icon:SetPoint('TOPLEFT', w.frame, 'TOPLEFT', 9, 10)
    assert(icon:GetNumPoints() == 1)
    w:DoLayout()
    local _, _, _, x, y = icon:GetPoint()
    assert(x == 4 and y == -4)
end)

test('layout repairs actual frame icon anchor size and alpha disturbances then settles', function()
    local f, a = fixture()
    local w = a:CreateNativePreviewWindow()
    w:AddRecommendation(403)
    local icon = w.icons[1]
    a.db.profile.preview_locked = true
    w:Configure()
    w.frame:SetSize(999, 888)
    assert(w.frame:GetWidth() == 200 and w.frame:GetHeight() == 72)
    icon:SetSize(7, 8)
    icon:SetAlpha(.3)
    icon:ClearAllPoints()
    icon:SetPoint('TOPLEFT', f.env.UIParent, 'CENTER', 1, 2)
    w:DoLayout()
    local point, parent, relative, x, y = icon:GetPoint(1)
    assert(point == 'TOPLEFT' and parent == w.frame and relative == 'TOPLEFT' and x == 4 and y == -4)
    assert(icon:GetWidth() == 64 and icon:GetHeight() == 64 and icon:GetAlpha() == 1 and not w.title)
    local writes = geometrySpy(w)
    w:DoLayout()
    assert(writes() == 0)
end)

test('geometry tolerance settles floating readback while alpha text and meaningful changes remain exact', function()
    local _, a = fixture()
    local w = a:CreateNativePreviewWindow()
    w:AddRecommendation(403)
    local icon = w.icons[1]
    w.frame.width = w.frame.width + .05
    w.frame.height = w.frame.height - .05
    icon.width = icon.width + .05
    icon.height = icon.height - .05
    icon:SetPoint('TOPLEFT', w.frame, 'TOPLEFT', 4.05, -4.05)
    local writes = geometrySpy(w)
    w:DoLayout()
    assert(writes() == 0, 'small native float differences caused geometry writes')
    icon:SetAlpha(.999)
    local previous = writes()
    w:DoLayout()
    assert(writes() == previous + 1 and icon:GetAlpha() == 1)
    w.frame.width = 201
    icon.width = 65
    icon:SetPoint('TOPLEFT', w.frame, 'TOPLEFT', 5, -4)
    w:DoLayout()
    assert(w.frame:GetWidth() == 200 and icon:GetWidth() == 64)
    local _, _, _, x = icon:GetPoint()
    assert(x == 4)
end)

test('empty previews hide all slots and metadata changes do not cache recommendation results', function()
    local _, a = fixture()
    local w = a:CreateNativePreviewWindow()

    for i = 1, 3 do
        w:AddRecommendation(400 + i)
    end

    w:ReleaseChildren()
    w:DoLayout()
    assert(w.count == 0 and w.frame:GetWidth() == 200 and w.frame:GetHeight() == 72)

    for _, icon in ipairs(w.icons) do
        assert(not icon:IsShown() and not icon.scripts.OnEnter and not icon.scripts.OnLeave)
    end

    local calls = 0

    a.Platform.GetItemDisplayInfo = function(_, id)
        calls = calls + 1
        return { iconID = id + calls }
    end

    for i = 1, 2 do
        w:ReleaseChildren()
        w:AddRecommendation(6603, 123)
    end

    assert(
        calls == 2
            and w.icons[1].spellId == 6603
            and w.icons[1].itemId == 123
            and w.icons[1].texture:GetTexture() == 125
    )

    a.db.profile.preview_spells = 1
    w:Configure()
    w:AddRecommendation(403)
    assert(w.count == 1 and not w.icons[2]:IsShown())
end)

test('provider error and reentrant reacquisition preserve refresh recovery without batching state', function()
    local _, a = fixture()
    local w = a:CreateNativePreviewWindow()
    w:AddRecommendation(403)
    local original = a.Platform.GetSpellInfo
    local marker = {}

    a.Platform.GetSpellInfo = function()
        error(marker)
    end

    local ok, why = pcall(w.AddRecommendation, w, 8042)
    assert(not ok and why == marker and w.count == 2 and w.icons[2])
    a.Platform.GetSpellInfo = original
    w:ReleaseChildren()
    w:AddRecommendation(403)
    assert(w.count == 1 and w.icons[1]:IsShown() and not w.icons[2]:IsShown())
    local once = false

    a.Platform.GetSpellInfo = function(self, id)
        if not once then
            once = true
            w:Release()
            assert(a:CreateNativePreviewWindow() == w)
        end

        return original(self, id)
    end

    w:ReleaseChildren()
    w:AddRecommendation(8042)
    w:DoLayout()
    assert(once and w.active and a.nextWindow == w)
    a.Platform.GetSpellInfo = original
    w:ReleaseChildren()
    w:AddRecommendation(403)
    w:DoLayout()
    assert(w.count == 1 and w.icons[1].spellId == 403 and w.icons[1]:IsShown() and not w.layouting)
end)

test('failed needed geometry writes retry and do not leave a stale layout success', function()
    for _, after in ipairs({ false, true }) do
        local _, a = fixture()
        local w = a:CreateNativePreviewWindow()
        w:AddRecommendation(403)
        local set = w.frame.SetSize
        local once = false
        local marker = {}

        w.frame.SetSize = function(...)
            if not once then
                once = true

                if after then
                    set(...)
                end

                error(marker)
            end

            return set(...)
        end

        a.db.profile.preview_icon_size = 80
        local ok, why = pcall(w.Configure, w)
        assert(not ok and why == marker)
        w:DoLayout()

        assert(
            w.layouting == false
                and w.frame:GetWidth() == 248
                and w.frame:GetHeight() == 88
                and w.icons[1]:GetWidth() == 80
        )

        local writes = geometrySpy(w)
        w:DoLayout()
        assert(writes() == 0)
    end
end)

test('release stale callbacks and profile reacquisition retain their current lease behavior', function()
    local _, a = fixture()
    local w = a:CreateNativePreviewWindow()
    w:AddRecommendation(403)
    local stale = w:MenuEntries()[2].func
    w:Release()
    local writes = geometrySpy(w)
    w:DoLayout()
    assert(writes() == 0 and not w.active and not w.frame:IsShown())
    a.db.profile = { preview_spells = 2, preview_icon_size = 80 }
    a:RefreshPreviewWindow()
    assert(a.nextWindow == w and w.profile == a.db.profile)
    stale()
    assert(w.active and a.nextWindow == w and a.db.profile.preview_spells == 2 and a.db.profile.preview_locked == nil)
    w:AddRecommendation(8042)
    assert(w.count == 1 and w.icons[1].spellId == 8042 and w.icons[1]:GetWidth() == 80)
end)

finish()
