-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Right-click insertion into spell and item fields: the target's or focus's
-- current cast, recent casts and equipped trinkets, committed exactly like a
-- chosen suggestion, in the condition and card editors' reference inputs and
-- in settings-page reference fields.
local F = dofile('tests/fixtures/addon.lua')

local function read(path)
    local h = assert(io.open(path))
    local text = h:read('*a')
    h:close()
    return text
end

local prefix = assert(read('tests/spell_search_ui.lua'):match('^(.-)\ntest%('))
local fixture = assert(loadstring(prefix .. '\nreturn fixture', '@reference-insert-fixture'))()
local test, finish = F.suite()

local function game(f, options)
    local env = f.env
    options = options or {}
    env.UnitExists = function(unit) return options[unit] ~= nil end

    env.UnitCastingInfo = function(unit)
        local o = options[unit]

        if o and o.cast then
            return 'Cast', '', 1, 0, 1, false, 'guid', false, o.cast
        end
    end

    env.UnitChannelInfo = function(unit)
        local o = options[unit]

        if o and o.channel then
            return 'Channel', '', 1, 0, 1, false, false, o.channel
        end
    end

    env.GetInventoryItemID = function(_, slot) return (options.trinkets or {})[slot] end
    f.addon.spellHistory = options.history or {}
end

local function rows(popup)
    local list = {}

    for _, row in ipairs(popup.rows) do
        if row:IsShown() then
            list[#list + 1] = row
        end
    end

    return list
end

test('right-click lists the target and focus casts and recent casts newest first, once each', function()
    local f = fixture()
    local a = f.addon

    game(f, {
        target = { cast = 974 },
        focus = { channel = 403 },
        history = { { spell = 529, time = 3 }, { spell = 974, time = 2 }, { spell = 529, time = 1 } },
    })

    local w = a:CreateSpellEditBox('Spell_EditBox')
    local chosen

    w:SetCallback('OnEnterPressed', function(_, _, id)
        chosen = id
    end)

    w.editbox.scripts.OnMouseDown(w.editbox, 'RightButton')
    local popup = w.rmSpellPopup
    local shown = rows(popup)
    assert(popup:IsShown() and #shown == 3, 'insert menu does not list three distinct spells')
    assert(shown[1].text:GetText() == 'Target casting: Earth Shield' and shown[1].spellID == 974)
    assert(shown[2].text:GetText():find('^Focus channeling: Lightning Bolt') and shown[2].spellID == 403)

    assert(
        shown[3].text:GetText():find('^Recently cast: Lightning Bolt') and shown[3].spellID == 529,
        'recent casts are not newest first'
    )

    shown[1].scripts.OnMouseDown(shown[1], 'LeftButton')

    assert(
        chosen == '974' and w:GetText() == 'Earth Shield' and not popup:IsShown(),
        'choosing an entry did not commit it like a suggestion'
    )

    w.editbox.scripts.OnMouseDown(w.editbox, 'RightButton')
    assert(popup:IsShown())
    w.editbox.scripts.OnMouseDown(w.editbox, 'RightButton')
    assert(not popup:IsShown(), 'right-click again did not close the menu')
end)

test('values the client will not let addons read are left out, and an empty menu says why', function()
    local f = fixture()
    local a = f.addon
    game(f, { target = { cast = 974 }, history = { { spell = 529, time = 1 } } })
    a.Platform.CanReadValue = function(_, value) return value ~= 974 end
    local w = a:CreateSpellEditBox('Spell_EditBox')
    w.editbox.scripts.OnMouseDown(w.editbox, 'RightButton')
    local shown = rows(w.rmSpellPopup)
    assert(#shown == 1 and shown[1].spellID == 529, 'an unreadable cast was offered')
    game(f, {})
    w.editbox.scripts.OnMouseDown(w.editbox, 'RightButton')
    w.editbox.scripts.OnMouseDown(w.editbox, 'RightButton')

    assert(
        #rows(w.rmSpellPopup) == 0 and w.rmSpellPopup.footer:GetText():find('Nothing to insert', 1, true),
        'an empty insert menu does not explain itself'
    )
end)

test('scoped spell fields offer only spells they accept', function()
    local f = fixture()
    local a = f.addon
    game(f, { history = { { spell = 974, time = 2 }, { spell = 403, time = 1 } } })
    local w = a:CreateSpellEditBox('Spec_EditBox')
    w:SetUserData('spec', 0)
    w.editbox.scripts.OnMouseDown(w.editbox, 'RightButton')
    local shown = rows(w.rmSpellPopup)
    assert(#shown == 1 and shown[1].spellID == 403, 'a spell outside the field scope was offered')
end)

test('item fields offer equipped trinkets and a left click still takes a cursor drop', function()
    local f = fixture()
    local a = f.addon

    f.env.GetItemInfo = function(id)
        local n = tonumber(id) == 1 and 'Water' or tonumber(id) == 2 and 'Bread'
        return n, nil, nil, nil, nil, nil, nil, nil, nil, n and tonumber(id) + 10
    end

    assert(a:UpdateReferenceItem(1) and a:UpdateReferenceItem(2))
    game(f, { trinkets = { [13] = 2, [14] = 1 } })
    local w = a:CreateItemEditBox('Item_EditBox')
    local chosen

    w:SetCallback('OnEnterPressed', function(_, _, id)
        chosen = id
    end)

    w.editbox.scripts.OnMouseDown(w.editbox, 'RightButton')
    local shown = rows(w.rmSpellPopup)

    assert(
        #shown == 2 and shown[1].text:GetText() == 'Trinket 1: Bread' and shown[2].text:GetText() == 'Trinket 2: Water',
        'trinkets are not offered in slot order'
    )

    shown[2].scripts.OnMouseDown(shown[2], 'LeftButton')
    assert(chosen == '1' and w:GetText() == 'Water')
    f.env.GetCursorInfo = function() return 'item', 2 end
    local cleared = false

    f.env.ClearCursor = function()
        cleared = true
    end

    w.editbox.scripts.OnMouseDown(w.editbox, 'LeftButton')
    assert(chosen == '2' and cleared, 'a left click no longer takes the cursor item')
end)

test('settings reference fields offer the same entries and stage the choice', function()
    local f = fixture()
    local a = f.addon
    f.load('UI/settings_form.lua')
    game(f, { target = { cast = 974 } })
    local parent = f.env.CreateFrame('Frame')
    parent:SetSize(900, 600)
    local p = a:CreateSettingsForm(parent)
    local value

    p:Open(function(form)
        form:Spell('spell', 'Spell', 403, nil, function(id)
            value = id
        end)
    end)

    local input = p.fields.spell
    input.scripts.OnMouseDown(input, 'RightButton')
    assert(p.menu and p.menu.frame:IsShown(), 'settings spell field has no insert menu')
    assert(input.rmOwnsRightClick, 'a settings reference field does not keep its right click from closing the window')
    local row

    for _, r in ipairs(p.menu.rows) do
        if r:IsShown() and (r:GetText() or ''):find('Target casting: Earth Shield', 1, true) then
            row = r
        end
    end

    assert(row, 'target cast missing from the settings insert menu')
    row:Click()

    assert(
        value == 974 and p.fields.spell:GetText():find('Earth Shield', 1, true),
        'settings insert did not stage the spell'
    )
end)

-- The close pollers (UI/config.lua for the main window, UI/window.lua for every dialog) fire on any new right-button press
-- whose mouse focus has the window as an ancestor. A field whose right click opens the insert menu, and the spell icon
-- whose right click clears the id, flag themselves `rmOwnsRightClick`, and both pollers leave those clicks to them.
local function pointer(f)
    local state = { down = false, focus = nil }
    f.env.IsMouseButtonDown = function() return state.down end
    rawset(f.env, 'GetMouseFoci', function() return { state.focus } end)
    return state
end

test('right-clicking a reference field or spell icon in the main window keeps the window open', function()
    local f = fixture()
    local a = f.addon
    game(f, { target = { cast = 974 } })
    local mouse = pointer(f)
    local _, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    a.pretty_name = 'Rotation Master'
    a.name = 'rotationmaster'
    a.SetupOptions = function() end
    a.BuildConfigurationPane = function() end

    a.OpenNativeSettings = function(_, parent)
        local p = { frame = create('Frame', nil, parent) }

        function p:SetWidth(v)
            self.frame:SetWidth(v)
        end

        function p:SetHeight(v)
            self.frame:SetHeight(v)
        end

        function p:Release()
            self.frame:Hide()
        end

        p.frame:Show()
        return p
    end

    f.load('UI/help.lua')

    if not a.CreateConditionIcon then
        f.load('UI/condition_icon.lua')
    end

    f.load('UI/spell_icon.lua')
    f.load('UI/config.lua')
    local shell = a:ShowConfig('General')
    local content = shell.content
    local field = a:CreateSpellEditBox('Spell_EditBox')
    field.frame:SetParent(content)
    local icon = a:CreateSpellActionIcon('spell', 403)
    icon.frame:SetParent(content)
    local cleared

    icon:SetCallback('OnEnterPressed', function(_, _, id)
        cleared = id
    end)

    local function press(target, button)
        mouse.focus = target
        content.scripts.OnUpdate()
        mouse.down = true

        if target.scripts.OnMouseDown then
            target.scripts.OnMouseDown(target, button)
        end

        content.scripts.OnUpdate()
        mouse.down = false
        content.scripts.OnUpdate()
    end

    press(field.editbox, 'RightButton')
    assert(field.rmSpellPopup:IsShown(), 'the insert menu did not open')
    assert(shell.frame:IsShown(), 'right-clicking a reference field closed the window')
    press(icon.frame, 'RightButton')
    icon.frame.scripts.OnClick(icon.frame, 'RightButton')

    assert(
        shell.frame:IsShown() and cleared == '',
        'right-clicking the spell icon closed the window or did not clear it'
    )

    press(content, 'RightButton')
    assert(not shell.frame:IsShown(), 'right-clicking plain content no longer closes the window')
    a:ReleaseConditionWidget(field)
    a:ReleaseConditionWidget(icon)

    assert(
        not field.editbox.rmOwnsRightClick and not icon.frame.rmOwnsRightClick,
        'a released control keeps the right-click flag'
    )
end)

test('right-clicking a reference field inside a dialog does not close the dialog; its plain body still does', function()
    local f = fixture()
    local a = f.addon
    game(f, { target = { cast = 974 } })
    local mouse = pointer(f)
    local dialog = f.env.CreateFrame('Frame', nil, f.env.UIParent)
    dialog:SetSize(400, 300)
    dialog:Show()
    a:EnableWorkbenchRightClickClose(dialog)
    local watcher = dialog.rmRightClickWatcher
    local field = a:CreateSpellEditBox('Spell_EditBox')
    field.frame:SetParent(dialog)

    local function press(target)
        mouse.focus = target
        watcher.scripts.OnUpdate()
        mouse.down = true

        if target.scripts and target.scripts.OnMouseDown then
            target.scripts.OnMouseDown(target, 'RightButton')
        end

        watcher.scripts.OnUpdate()
        mouse.down = false
        watcher.scripts.OnUpdate()
    end

    press(field.editbox)
    assert(field.rmSpellPopup:IsShown() and dialog:IsShown(), 'right-clicking a reference field closed its dialog')
    press(dialog)
    assert(not dialog:IsShown(), 'right-clicking the dialog body no longer closes it')
    a:ReleaseConditionWidget(field)
end)

finish()
