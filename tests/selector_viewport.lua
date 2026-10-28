-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(n)
    local f = F.new()
    local frames = dofile('tests/fixtures/native_ui.lua')(f.env)
    f.load('UI/window.lua')
    local a = f.addon
    local anchor = f.env.CreateFrame('Button', nil, f.env.UIParent)
    anchor:SetWidth(420)
    local menu = a:CreateWorkbenchSelector()
    local entries = {}
    local chosen

    for i = 1, n do
        entries[i] = { value = i, text = string.format('Entry%05d', i) }
    end

    menu:Open(
        anchor,
        entries,
        nil,
        function(value)
            chosen = value
        end,
        function() return true end
    )

    return f, menu, entries, frames, anchor, function() return chosen end
end

local function rowFor(menu, id)
    for _, row in ipairs(menu.rows) do
        if row.menuLease and row.menuEntry.value == id then
            return row
        end
    end
end

test('selector retains4096 complete results with bounded warm viewport rows and final selection', function()
    local f, menu, entries, frames, anchor, selected = fixture(4096)
    assert(menu.matches and #menu.matches == 4096 and #menu.rows < 20, 'selector materialized every result')
    local stale = rowFor(menu, 1).scripts.OnClick
    local filters = 0
    local filter = menu.Refilter

    menu.Refilter = function(...)
        filters = filters + 1
        return filter(...)
    end

    for i = 0, 10 do
        menu.scroll.workbenchBar:SetValue(menu.scroll.workbenchBar.scrollRange * i / 10)
    end

    local warm = #frames

    for pass = 1, 2 do
        for i = 10, 0, -1 do
            menu.scroll.workbenchBar:SetValue(menu.scroll.workbenchBar.scrollRange * i / 10)
        end
    end

    assert(#frames == warm and filters == 0 and #menu.rows < 20, 'warm selector scrolling allocated or refiltered')
    menu.scroll.workbenchBar:SetValue(menu.scroll.workbenchBar.scrollRange)
    assert(rowFor(menu, 4096))
    stale()
    assert(not selected() and menu.frame:IsShown())
    rowFor(menu, 4096):Click()
    assert(selected() == 4096 and not menu.frame:IsShown())
end)

test('same-open selector filters retire old selections and delayed color repaints', function()
    local f, menu, entries, frames, anchor, selected = fixture(2)
    menu:Hide()
    local repaint

    entries = {
        {
            value = 1,
            text = 'Alpha',
            color = { r = 1, g = 0, b = 0 },
            chooseColor = function(_, paint)
                repaint = paint
            end,
        },
        { value = 2, text = 'Beta', color = { r = 0, g = 0, b = 1 }, chooseColor = function() end },
    }

    local chosen

    menu:Open(
        anchor,
        entries,
        nil,
        function(value)
            chosen = value
        end,
        function() return true end
    )

    local old = menu.rows[1].scripts.OnClick
    menu.rows[1].colorButton:Click()
    menu.search:SetText('Beta')
    menu.search.scripts.OnTextChanged(menu.search, true)
    old()
    assert(chosen == nil and menu.frame:IsShown(), 'old filtered row selected its previous value')
    repaint({ r = 0, g = 1, b = 0, a = 1 })
    local beta = assert(rowFor(menu, 2))

    assert(
        beta.colorButton.fill.color[3] == 1 and beta.colorButton.fill.color[2] == 0,
        'old color repaint changed recycled swatch'
    )

    menu:Release()
end)

test('actual tag color popup pins its anchor lease during selector scrolling and retires on close', function()
    local f, menu, entries, frames, anchor = fixture(1)
    menu:Release()
    local a = f.addon
    f.load('Data/plain.lua')
    f.load('Data/tags.lua')
    f.load('UI/color_picker.lua')
    local tags = {}

    for i = 1, 1000 do
        tags[i] = string.format('Tag%04d', i)
    end

    local colors = {}

    local picker = a:CreateRotationTagPicker(f.env.UIParent, {
        available = function() return tags end,
        color = function(tag) return colors[tag] or { r = 0, g = 0, b = 1, a = 1 } end,
        setColor = function(tag, value)
            colors[tag] = value
        end,
    })

    picker.input:SetText('Tag')
    picker:Suggest()
    menu = picker.menu
    local first = assert(rowFor(menu, 'Tag0001'))
    local lease = first.menuLease
    first.colorButton:Click()
    local child = picker.colorPicker
    -- This fixture's Hide dispatches only the script; model native hook ordering locally.
    local nativeHide = child.frame.Hide

    child.frame.Hide = function(self)
        local shown = self:IsShown()
        nativeHide(self)

        if shown then
            for _, hook in ipairs(self.hooks and self.hooks.OnHide or {}) do
                hook(self)
            end
        end
    end

    local hookCount = #child.frame.hooks.OnHide
    assert(child.frame:IsShown() and child.frame.point[2] == first.colorButton)
    menu.scroll.workbenchBar:SetValue(menu.scroll.workbenchBar.scrollRange)

    assert(
        first.menuLease == lease and first.menuEntry.value == 'Tag0001' and child.frame.point[2] == first.colorButton,
        'scroll recycled an active color child anchor'
    )

    assert(rowFor(menu, 'Tag1000') and #menu.rows < 22)
    local late = child.change
    late(1, 0, 0, 1)
    assert(colors.Tag0001.r == 1)
    child:Close(false)
    assert(colors.Tag0001.b == 1, 'explicit color cancellation did not roll back before retiring its session')
    late(0, 1, 0, 1)
    assert(colors.Tag0001.b == 1, 'closed color child changed its tag before the next menu update')
    menu.frame.scripts.OnUpdate()

    assert(
        not first.menuLease or first.menuEntry.value ~= 'Tag0001',
        'closed color child retained an offscreen row lease'
    )

    picker:Suggest()
    late(0, 1, 0, 1)
    assert(not colors.Tag0001 or colors.Tag0001.b == 1, 'old color child mutated a reopened selector session')

    for _ = 1, 100 do
        picker:Suggest()
        assert(rowFor(menu, 'Tag0001')).colorButton:Click()
        child:Close(false)
    end

    assert(#child.frame.hooks.OnHide == hookCount, 'reopening the same color child accumulated lifecycle hooks')
    first = assert(rowFor(menu, 'Tag0001'))
    first.colorButton:Click()
    local current = child.change
    current(1, 0, 0, 1)
    picker:Hide()
    assert(colors.Tag0001.r == 1 and not child.frame:IsShown(), 'hiding tag picker rolled back its accepted live color')
    current(0, 1, 0, 1)
    assert(colors.Tag0001.r == 1, 'hidden color session changed accepted data')
    picker:Release()
    assert(not child.frame:IsShown() and not menu.frame:IsShown())
end)

test('selector viewport binding failure retires a partial row and a later refresh recovers', function()
    local f, menu, entries, frames, anchor, selected = fixture(1000)
    local old = rowFor(menu, 1).scripts.OnClick
    local align = f.addon.AlignWorkbenchTextLeft
    local failed = false

    f.addon.AlignWorkbenchTextLeft = function(...)
        if not failed then
            failed = true
            error('injected selector binding failure')
        end

        return align(...)
    end

    local ok = pcall(menu.scroll.workbenchBar.SetValue, menu.scroll.workbenchBar, menu.scroll.workbenchBar.scrollRange)
    assert(not ok and failed and not menu.refreshing)
    f.addon.AlignWorkbenchTextLeft = align
    menu:RefreshViewport()
    old()
    assert(not selected() and rowFor(menu, 1000))
    menu:Release()
end)

test('legacy color callbacks may return unrelated scalar values without becoming child owners', function()
    local f, menu, entries, frames, anchor = fixture(1)
    menu:Hide()

    menu:Open(
        anchor,
        { { value = 1, text = 'Color', color = { r = 1, g = 0, b = 0 }, chooseColor = function() return true end } },
        nil,
        function() end,
        function() return true end
    )

    menu.rows[1].colorButton:Click()
    assert(menu.frame:IsShown())
    menu:Release()
end)

test('retired popup update cannot dismiss a newer anchor or alter its mouse and color child state', function()
    local f, menu, entries, frames, anchor = fixture(1)
    local update = menu.frame.scripts.OnUpdate
    local other = f.env.CreateFrame('Button')
    other:SetWidth(420)
    local child = f.env.CreateFrame('Frame')
    child:Hide()

    local owner = {
        frame = child,
        Close = function(self)
            self.frame:Hide()
        end,
    }

    entries = {
        {
            value = 1,
            text = 'Color',
            color = { r = 1, g = 0, b = 0 },
            chooseColor = function()
                child:Show()
                return owner
            end,
        },
    }

    menu:Open(other, entries, nil, function() end, function() return true end)
    menu.rows[1].colorButton:Click()
    local mouse = menu.mouseDown
    f.env.IsMouseButtonDown = function() return true end
    f.env.MouseIsOver = function(frame) return frame == other end
    update()

    assert(
        menu.frame:IsShown() and child:IsShown() and menu.mouseDown == mouse,
        'old popup update dismissed or changed the new popup lifetime'
    )

    menu:Release()
end)

finish()
