-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Responsive workbench layout: shared row distribution, the list/detail
-- divider, list rows that match their column, and the window size bounds.
-- Geometry is proved with tests/fixtures/layout_audit.lua, which resolves the
-- native anchors and reports any drawn control outside its pane.
local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local audit = dofile('tests/fixtures/layout_audit.lua')
local test, finish = F.suite()

local function browserFixture(product, expansion, realCustom)
    local f = F.new(product, expansion)
    local a = f.addon
    f.env.NEW = 'New'
    a.loadAllDefaults = true  -- registers a foreign-class pack on purpose
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    local data, envelope, validation = make()
    a.RotationData = data
    a.conditionDefinitions = validation.conditions
    f.load('Data/catalog.lua')
    f.load('Data/diff.lua')
    f.load('Core/rotation_library.lua')
    local tags = io.open('Core/rotation_tags.lua')

    if tags then
        tags:close()
        f.load('Core/rotation_tags.lua')
    end

    a.GetRotationContext = function(_, spec)
        return {
            family = 'tbc',
            class = 'SHAMAN',
            level = 11,
            spec = spec,
            actionContext = 'player',
            combatDataPolicy = 'probe',
        }
    end

    local counter = 0

    a.uuid = function()
        counter = counter + 1
        return 'new-' .. counter
    end

    local pack = envelope()
    pack.nameKey = 'Twin'
    pack.descriptionKey = 'Contains % [ brackets'
    pack.applicability.maxLevel = 19
    assert(a:RegisterDefaultRotation(pack))
    local other = envelope()
    other.id = 'other-pack'
    other.nameKey = 'Other default'
    other.applicability.class = 'MAGE'
    assert(a:RegisterDefaultRotation(other))

    a.db.profile.rotations = {
        [0] = { one = { name = 'Twin', rotation = {} }, two = { name = 'Twin', rotation = {} } },
        [1] = { third = { name = 'Secondary custom', rotation = {} } },
    }

    a.db.profile.enable = false
    a.db.char = { specs = { [1] = 'Primary', [2] = 'Secondary' } }
    a.db.profile.itemsets = {}
    a.db.global.effects = {}
    assert(a:InitializeRotationLibrary())
    assert(a:SetDefaultRotationEnabled(other.id, false))
    a.Platform.GetSpellInfo = function(_, id) return { spellID = id, name = 'Lightning Bolt' } end
    a.Platform.GetSpellLink = function() return '|Hspell:403|h[Lightning Bolt]|h' end
    a.printCondition = function() return 'Readable condition' end
    f.load('UI/defaults.lua')
    f.load('UI/rotation_reference.lua')
    f.load('UI/settings_setup.lua')
    local nativeEditor

    if realCustom then
        a.validateCondition = function() return true end
        a.GetImportValidationOptions = function() return { conditions = a.conditionDefinitions } end
        a.UpdateAutoSwitch = function() end
        a.SwitchRotation = function() end
        a.EvaluateNextAction = function() end

        for _, path in ipairs({
            'Platform/spells.lua', 'Data/rotation_draft.lua', 'Core/rotation_editor.lua', 'Core/rotation_workspace.lua',
            'Core/rotation_canvas.lua', 'UI/window.lua', 'UI/rotation_cards.lua', 'UI/rotation_canvas.lua',
            'UI/color_picker.lua', 'UI/rotation_effect_fields.lua', 'UI/rotation_fields.lua',
            'UI/rotation_navigation.lua', 'UI/rotation_metadata.lua', 'UI/rotation_view.lua', 'UI/rotation_editor.lua'
        }) do
            f.load(path)
        end

        nativeEditor = a.CreateRotationEditor
    end

    local editors = {}

    -- Native pane fixture isolates the roster; the name/apply case below uses
    -- the actual native editor and the reference case uses native reference controls.
    a.CreateRotationEditor = function(self, parent, spec, id, onSelect)
        if nativeEditor then
            local pane, why = nativeEditor(self, parent, spec, id, onSelect)

            if pane then
                editors[#editors + 1] = { pane = pane, spec = spec, id = id, select = onSelect }
            end

            return pane, why
        end

        local pane = self:CreateConditionGroup()
        pane.frame:SetParent(parent)
        pane:SetWidth(parent:GetWidth())
        pane:SetHeight(parent:GetHeight())
        pane.workspace = { pending = false }

        pane.clone = {
            action = function()
                local builtin = self:GetDefaultIdForRuntime(spec, id)
                local source = self:GetEditableRotation(spec, id)
                local title = source and source.name or id
                local name = 'Copy of ' .. title

                local generated = builtin and self:CloneDefaultRotation(spec, builtin, name)
                    or self:DuplicateCustomRotation(spec, id, name)

                if generated then
                    onSelect(spec, generated)
                end
            end,
        }

        local release = pane.Release

        function pane:Release()
            self.released = true
            self.Release = nil
            return release(self)
        end

        editors[#editors + 1] = { pane = pane, spec = spec, id = id, select = onSelect }
        local builtin = self:GetDefaultIdForRuntime(spec, id)

        if builtin then
            self:CreateDefaultRotationOptions(pane, spec, builtin, function(generated)
                onSelect(spec, generated)
            end)
        else
            local label = self:CreateConditionLabel()
            label:SetText('custom editor')
            pane:AddChild(label)
        end

        return pane
    end

    dofile('tests/fixtures/rotation_header_backend.lua')(a, f.env.DEFAULT, f.env.NEW)
    f.load('UI/rotation_browser.lua')
    return f, pack, editors, create, frames
end

local function settingsFixture()
    local f = F.new()
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    a.pretty_name = 'Rotation Master'
    a.name = 'rotationmaster'
    a.configPaneGeneration = 1
    a.RotationData = make()

    for _, path in ipairs({
        'Platform/spells.lua', 'Data/catalog.lua', 'Data/rotation_store.lua', 'Core/rotation_library.lua',
        'Core/rotation_scope.lua', 'Core/rotation_migration.lua', 'Help/general.lua', 'Help/conditions.lua',
        'Help/effects.lua', 'Help/itemsets.lua', 'Help/announce.lua', 'UI/window.lua', 'UI/help.lua',
        'UI/icon_picker.lua', 'UI/color_picker.lua', 'UI/settings_roster_order.lua', 'UI/settings_layout.lua',
        'UI/settings_ordered.lua', 'UI/settings_draft.lua', 'UI/settings_history.lua', 'UI/settings_unsaved.lua',
        'UI/settings_form.lua', 'UI/settings_transfer.lua', 'UI/cpu_profile.lua', 'UI/settings_general.lua',
        'UI/settings_profiles.lua', 'UI/collection_compare.lua', 'UI/settings_collections.lua',
        'UI/settings_announces.lua', 'UI/settings_effects.lua', 'UI/settings_items.lua', 'UI/settings_conditions.lua'
    }) do
        local h = io.open(path)

        if h then
            h:close()
            f.load(path)
        end
    end

    return f, frames, create
end

local function pointer(f)
    local state = { x = 0, down = true }
    f.env.GetCursorPosition = function() return state.x, 0 end
    f.env.IsMouseButtonDown = function() return state.down end
    return state
end

-- No client frames run here, so the coalesced relayout is flushed at once.
local function drag(splitter, state, delta, a)
    state.down = true
    state.x = 0
    splitter.scripts.OnMouseDown(splitter, 'LeftButton')
    state.x = delta
    splitter.scripts.OnUpdate(splitter, .01)
    state.down = false
    splitter.scripts.OnUpdate(splitter, .01)
    assert(not splitter.drag and splitter.scripts.OnUpdate == nil, 'divider drag did not end on release')

    if a then
        a:FlushWorkbenchReflow()
    end
end

local function rightEdge(root, frame)
    return audit.resolver(root)(frame).right
end

test('same-row controls share the row evenly and wrap instead of overflowing', function()
    local f = F.new()
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    local parent = create('Frame')
    local controls = {}

    for i = 1, 3 do
        controls[i] = a:CreateWorkbenchButton(parent, 'B' .. i, 50)
    end

    for _, width in ipairs({ 120, 300, 900 }) do
        parent:SetSize(width, 100)
        local height, each, columns = a:LayoutWorkbenchRow(controls, 0, 0, width)
        assert(columns == 3 and height == 28 and math.abs(each - (width - 8) / 3) < .001, 'row did not share ' .. width)

        for _, control in ipairs(controls) do
            assert(control:GetWidth() == each)
        end

        audit.assertContained(parent, frames, 'row at ' .. width)
    end

    parent:SetSize(200, 100)
    local height, each, columns = a:LayoutWorkbenchRow(controls, 0, 0, 200, { minimum = 90 })
    assert(columns == 2 and height == 56 and each == 98 and controls[3].point[3] == -28, 'narrow row did not wrap')
    audit.assertContained(parent, frames, 'wrapped row')
    local owner = create('Frame')
    owner:SetSize(300, 200)
    local prompt = create('Frame', nil, owner)
    assert(a:FitWorkbenchPrompt(prompt, owner, 430) == 284 and prompt:GetWidth() == 284)
    owner:SetSize(900, 200)
    assert(a:FitWorkbenchPrompt(prompt, owner, 430) == 430)
end)

test('captions follow later button resizes and labeled buttons bound their text', function()
    local f = F.new()
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    local parent = create('Frame')
    parent:SetSize(400, 100)

    local choice = a:CreateWorkbenchLabeledIconButton(
        parent,
        'chevron-down',
        'A very long selected value that would not fit',
        300
    )

    choice:SetPoint('TOPLEFT', 0, 0)
    a:AlignWorkbenchTextLeft(choice, 26)
    choice:SetWidth(120)
    local label = choice:GetFontString()
    assert(label:GetWidth() == 90, 'aligned caption kept a stale width')
    choice:SetSize(200, 20)
    assert(label:GetWidth() == 170)
    audit.assertContained(parent, frames, 'aligned caption', { captions = true })
    -- A caller that narrows the caption itself keeps that width.
    label:SetWidth(60)
    choice:SetWidth(180)
    assert(label:GetWidth() == 60)
    local plain = a:CreateWorkbenchLabeledIconButton(parent, 'plus', 'Another label far longer than its button', 80)
    plain:SetPoint('TOPLEFT', 0, -30)
    local caption = plain:GetFontString()
    local first, x = caption:GetPoint(1)
    local second, rx = caption:GetPoint(2)

    assert(
        first == 'LEFT' and x == 24 and second == 'RIGHT' and rx == -4,
        'labeled button caption is not bounded by its button'
    )

    audit.assertContained(parent, frames, 'labeled caption', { captions = true })
end)

test('divider geometry clamps to the sidebar and detail minima and persists globally', function()
    local f = F.new()
    local a = f.addon
    local layout = a.WorkbenchLayout
    assert(layout.windowMinWidth == 800 and layout.sidebarMin == 200 and layout.detailMin == 440)
    local g = a:GetWorkbenchRosterGeometry(776, 600)
    assert(g.sidebarWidth == 210 and g.detailX == 228 and g.detailWidth == 548, 'default split changed')
    a:SetWorkbenchSidebarPreference(5)
    g = a:GetWorkbenchRosterGeometry(776, 600)
    assert(g.sidebarWidth == layout.sidebarMin)
    a:SetWorkbenchSidebarPreference(5000)
    g = a:GetWorkbenchRosterGeometry(776, 600)

    assert(
        g.detailWidth == layout.detailMin and g.sidebarWidth + layout.splitGap + g.detailWidth == 776,
        'detail minimum not kept'
    )

    g = a:GetWorkbenchRosterGeometry(1600, 600)
    assert(g.sidebarWidth == 800, 'list may not take more than half the page')
    a:SetWorkbenchSidebarPreference(333.4)
    assert(a.db.global.workbenchSidebarWidth == 333)
    a:SetWorkbenchSidebarPreference(0 / 0)
    a:SetWorkbenchSidebarPreference(-4)
    assert(a.db.global.workbenchSidebarWidth == 333)
    a:SetWorkbenchSidebarPreference(nil)
    assert(a.db.global.workbenchSidebarWidth == nil and a:GetWorkbenchRosterGeometry(1000, 600).sidebarWidth == 260)
    a.db.global.workbenchSidebarWidth = 'bad'
    assert(a:GetWorkbenchRosterGeometry(1000, 600).sidebarWidth == 260)
end)

local function browserScene(f, width, height)
    local a = f.addon

    a.db.profile.rotations[0].one.rotation = {
        { id = 's1', type = 'spell', action = 403, ranked = true, conditions = {} },
        { id = 's2', type = 'item', action = { 1, 2 }, conditions = {} },
        {
            id = 'b1',
            type = 'branch',
            conditions = {},
            onTrue = { { id = 's3', type = 'spell', action = 403, conditions = {} } },
            onFalse = {},
        },
    }

    local host = f.env.CreateFrame('Frame')
    host:SetSize(width, height)
    local browser = a:CreateRotationBrowser(host, { spec = 0, id = 'one' })

    for _, id in ipairs({ 's1', 's2', 'b1', 's3' }) do
        browser.pane.view.cardStates[id] = 'expanded'
    end

    browser.pane:Render()
    return host, browser
end

local function assertBrowser(_, browser, frames, message)
    local host = browser.frame
    local cards = {}

    for _, card in ipairs(browser.pane.canvas.cards) do
        cards[card.frame] = true
    end

    audit.assertContained(host, frames, message, {
        captions = true,
        container = function(frame) return cards[frame] end,
        horizontalScroll = { [browser.pane.canvas.frame] = true },
    })

    local side = browser.left:GetWidth()

    assert(
        browser.detail.point[4] == side + 18
            and browser.detail:GetWidth() == host:GetWidth() - side - 18
            and browser.pane.frame:GetWidth() == browser.detail:GetWidth(),
        message .. ': detail does not follow the split'
    )

    local bar = browser.list.workbenchBar
    local reserve = bar:IsShown() and 14 or 0

    assert(
        browser.list:GetWidth() == side - reserve and browser.listChild:GetWidth() == side - reserve,
        message .. ': list does not fill its column'
    )

    for _, row in ipairs(browser.rowButtons) do
        if row.browserLease then
            assert(row:GetWidth() == browser.listChild:GetWidth(), message .. ': row narrower than its list')
        end
    end

    if bar:IsShown() then
        assert(math.abs(rightEdge(host, bar) - side) < .01, message .. ': scroll bar is not at the column edge')
    end
end

test('rotation list rows fill their column and the divider resizes both panes within their minima', function()
    local f, _, _, _, frames = browserFixture(nil, nil, true)
    local a = f.addon
    f.load('UI/help.lua')
    local state = pointer(f)
    local host, browser = browserScene(f, 1000, 640)
    assertBrowser(host, browser, frames, 'default split')
    assert(browser.left:GetWidth() == 260 and #browser.rowButtons > 0)
    local splitter = browser.splitter
    assert(splitter:IsShown() and splitter.point[4] == 264, 'divider is not in the pane gap')
    drag(splitter, state, 100, a)

    assert(
        browser.left:GetWidth() == 360 and a.db.global.workbenchSidebarWidth == 360,
        'drag did not move or persist the divider'
    )

    assertBrowser(host, browser, frames, 'after widening the list')
    drag(splitter, state, -5000, a)
    assert(browser.left:GetWidth() == 200, 'drag passed the list minimum')
    assertBrowser(host, browser, frames, 'list minimum')
    drag(splitter, state, 5000, a)
    assert(browser.left:GetWidth() == 500 and browser.detail:GetWidth() == 482, 'drag passed the page limit')
    assertBrowser(host, browser, frames, 'list maximum')
    -- Whole-window resizing keeps the preference but never the detail minimum.
    browser:SetWidth(776)
    assert(browser.left:GetWidth() == 318 and browser.detail:GetWidth() == 440)
    assertBrowser(host, browser, frames, 'narrow window')
    browser:SetWidth(1600)
    assert(browser.left:GetWidth() == 500)
    assertBrowser(host, browser, frames, 'wide window')
    -- A short list scrolls; its bar then takes the reserve at the column edge.
    browser:SetHeight(220)
    assert(browser.list.workbenchBar:IsShown(), 'short list did not scroll')
    assertBrowser(host, browser, frames, 'scrolling list')
    browser:SetHeight(900)
    assert(not browser.list.workbenchBar:IsShown())
    assertBrowser(host, browser, frames, 'tall list')
    splitter.scripts.OnDoubleClick(splitter)
    assert(a.db.global.workbenchSidebarWidth == nil and browser.left:GetWidth() == 270, 'double-click did not reset')
    local selected = browser.selected
    local other

    for _, row in ipairs(browser.rowButtons) do
        if row.browserLease and row.browserEntry.key ~= selected then
            other = row
            break
        end
    end

    other:Click()

    assert(
        browser.selected == other.browserEntry.key and browser.selected ~= selected and browser.pane,
        'selection broke after resizing'
    )

    assertBrowser(host, browser, frames, 'after selection')
end)

local function itemSetsPage(f, create, width)
    local a = f.addon
    a.db.global.itemsets = {}
    a.db.profile.itemsets = {}

    for i = 1, 30 do
        a.db.global.itemsets['set' .. i] = { name = string.format('Set %02d', i), items = { i } }
    end

    local parent = create('Frame')
    parent:SetSize(width, 600)
    local p = a:OpenNativeSettings(parent, 'ItemSets')
    p.roster.rows[1]:Click()
    return parent, p
end

local function assertRoster(parent, p, frames, message)
    audit.assertContained(parent, frames, message, { captions = true })
    local r = p.roster
    local side = r.frame:GetWidth()
    local reserve = r.scroll.workbenchBar:IsShown() and 14 or 0

    assert(
        r.scroll:GetWidth() == side - reserve and r.child:GetWidth() == side - reserve,
        message .. ': roster does not fill its column'
    )

    for _, row in ipairs(r.rows) do
        if row.rosterLease then
            assert(row:GetWidth() == r.child:GetWidth(), message .. ': roster row narrower than its list')
        end
    end

    if r.scroll.workbenchBar:IsShown() then
        assert(
            math.abs(rightEdge(parent, r.scroll.workbenchBar) - side) < .01,
            message .. ': roster bar is not at the column edge'
        )
    end

    assert(
        p.scroll.point[2] == side + 18 and p.width == p.scroll:GetWidth(),
        message .. ': detail does not follow the split'
    )
end

test('settings rosters fill their column and the divider redraws the detail form', function()
    local f, frames, create = settingsFixture()
    local a = f.addon
    local state = pointer(f)
    local parent, p = itemSetsPage(f, create, 1000)
    assert(p.roster.scroll.workbenchBar:IsShown(), '30 sets should scroll')
    assertRoster(parent, p, frames, 'default')
    local before = p.width
    drag(p.roster.splitter, state, 120, a)

    assert(
        p.roster.frame:GetWidth() == 380 and p.width == before - 120 and a.db.global.workbenchSidebarWidth == 380,
        'settings divider did not redraw the detail'
    )

    assertRoster(parent, p, frames, 'wider list')
    drag(p.roster.splitter, state, -5000, a)
    assert(p.roster.frame:GetWidth() == 200)
    assertRoster(parent, p, frames, 'list minimum')
    drag(p.roster.splitter, state, 5000, a)
    assert(p.roster.frame:GetWidth() == 500)
    assertRoster(parent, p, frames, 'list maximum')
    parent:SetSize(776, 600)
    p:SetWidth(776)
    a:FlushWorkbenchReflow()
    assert(p.roster.frame:GetWidth() == 318)
    assertRoster(parent, p, frames, 'narrow page')
    parent:SetSize(1600, 600)
    p:SetWidth(1600)
    a:FlushWorkbenchReflow()
    assert(p.roster.frame:GetWidth() == 500)
    assertRoster(parent, p, frames, 'wide page')
    p.roster.rows[3]:Click()
    assertRoster(parent, p, frames, 'after selection')
    -- A divider drag redraws the detail but carries an invalid pending input.
    local key

    for name, control in pairs(p.fields) do
        for _, record in ipairs(p.edits) do
            if record.control == control and record.parse('not an item') == nil then
                key = name
            end
        end
    end

    assert(key, 'Item Sets has no validated input to edit')
    local edit = p.fields[key]
    edit:SetText('not an item')
    edit.scripts.OnTextChanged(edit, true)
    local side = p.roster.frame:GetWidth()
    drag(p.roster.splitter, state, -100, a)
    edit = p.fields[key]
    local dirty = false

    for _, record in ipairs(p.edits) do
        if record.control == edit then
            dirty = record.dirty
        end
    end

    assert(
        p.roster.frame:GetWidth() == side - 100 and edit:GetText() == 'not an item' and dirty and edit.textColor[2] < 1,
        'divider drag lost an invalid input'
    )
end)

test('settings pages keep every control inside at the minimum window and both divider extremes', function()
    for _, preference in ipairs({ false, 1, 99999 }) do
        for _, width in ipairs({ 776, 1200 }) do
            for _, key in ipairs({ 'General', 'Effects', 'ItemSets', 'Announces' }) do
                local f, frames, create = settingsFixture()
                local a = f.addon
                a.RemoveAllCurrentGlows = function() end
                a.HideGlow = function() end
                a.Glow = function() end

                a.db.profile.announces = {
                    {
                        type = 'spell',
                        spell = 403,
                        ranked = true,
                        event = 'SUCCEEDED',
                        announce = 'local',
                        value = 'Cast',
                    },
                }

                a.db.global.effects = {
                    pulse = { name = 'Pulse', type = 'pulse', frequency = .25, sequence = { 1, .5 } },
                    dazzle = { name = 'Dazzle', type = 'dazzle', sequence = { { r = 1, g = 1, b = 1, a = 1 } } },
                }

                a.db.profile.effect = 'pulse'
                a.db.global.itemsets = { potions = { name = 'Potions', items = { 1, 2 } } }
                a.db.global.workbenchSidebarWidth = preference or nil
                local parent = create('Frame')
                parent:SetSize(width, 600)
                local p = a:OpenNativeSettings(parent, key)

                if p.roster and p.roster.rows[1] and p.roster.rows[1]:IsShown() then
                    p.roster.rows[1]:Click()
                end

                audit.assertContained(parent, frames, key .. ' at ' .. width .. ' with list ' .. tostring(preference), {
                    captions = true,
                })
            end
        end
    end
end)

test('the configuration window keeps its minimum size and fits the screen', function()
    local function shell(options)
        local f = F.new()
        local a = f.addon
        local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)

        if options.legacy then
            local make = f.env.CreateFrame

            f.env.CreateFrame = function(...)
                local frame = make(...)
                frame.SetResizeBounds = nil

                function frame:SetMinResize(w, h)
                    self.minResize = { w, h }
                end

                function frame:SetMaxResize(w, h)
                    self.maxResize = { w, h }
                end

                return frame
            end
        end

        a.OpenNativeSettings = function(_, parent)
            local p = { frame = create('Frame', nil, parent) }
            p.frame:SetPoint('TOPLEFT', 0, 0)

            function p:SetWidth(v)
                self.frame:SetWidth(v)
            end

            function p:SetHeight(v)
                self.frame:SetHeight(v)
            end

            function p:Release()
                self.frame:Hide()
            end

            p:SetWidth(parent:GetWidth())
            p:SetHeight(parent:GetHeight())
            return p
        end

        a.pretty_name = 'Rotation Master'
        a.name = 'rotationmaster'
        a.SetupOptions = function() end
        a.db.global.uiScale = options.scale or 1

        if options.screen then
            f.env.UIParent:SetSize(options.screen[1], options.screen[2])
        end

        f.load('UI/window.lua')
        f.load('UI/help.lua')
        f.load('UI/config.lua')
        return a:ShowConfig('General'), frames
    end

    local s, frames = shell({})
    assert(s.frame.resizeBounds[1] == 800 and s.frame.resizeBounds[2] == 500, 'native minimum not declared')
    s.frame:SetSize(500, 300)
    assert(s.frame:GetWidth() == 800 and s.frame:GetHeight() == 500, 'window shrank below its minimum')
    assert(s.pane.frame:GetWidth() == s.content:GetWidth() and s.content:GetWidth() == 776)
    audit.assertContained(s.frame, frames, 'minimum window', { captions = true })
    s.frame:SetSize(1500, 900)
    assert(s.pane.frame:GetWidth() == 1476, 'pane did not follow a wider window')
    local legacy = shell({ legacy = true })
    assert(legacy.frame.minResize[1] == 800 and legacy.frame.minResize[2] == 500, 'older clients get no minimum')
    local scaled = shell({ scale = 1.3, screen = { 1366, 768 } })

    assert(
        scaled.frame:GetWidth() == math.floor(1366 / 1.3) and scaled.frame:GetHeight() == math.floor(768 / 1.3),
        'window larger than the screen'
    )

    assert(scaled.frame.resizeBounds[3] == math.floor(1366 / 1.3))
end)

test('a divider drag keeps an inline function editor and its unsaved code in the detail pane', function()
    local f = F.new()
    local a = f.addon
    local frames = dofile('tests/fixtures/native_ui.lua')(f.env)
    a.db.char = {}
    a.db.global.custom_functions = {}
    a.RotationData = make()

    for _, path in ipairs({
        'Core/function_data.lua', 'UI/settings_history.lua', 'UI/settings_unsaved.lua', 'UI/settings_layout.lua',
        'UI/settings_ordered.lua', 'UI/settings_roster_order.lua', 'UI/settings_form.lua',
        'UI/settings_collections.lua', 'UI/settings_transfer.lua', 'UI/lua_input_probe.lua',
        'UI/lua_input_diagnostics.lua', 'UI/lua_editor.lua', 'UI/settings_functions.lua', 'UI/function_bindings.lua',
        'UI/function_source_pane.lua', 'UI/function_bundle_transfer.lua'
    }) do
        local file = io.open(path)

        if file then
            file:close()
            f.load(path)
        end
    end

    local state = pointer(f)
    local host = f.env.CreateFrame('Frame')
    host:SetSize(1000, 600)

    a.db.global.custom_functions.A = {
        name = 'LongFunctionName',
        description = 'Documentation',
        args = { { name = 'value', type = 'number', description = 'Input value' } },
        returns = { { type = 'number', description = 'Result' } },
        code = 'return value',
    }

    local p = a:OpenNativeSettings(host, 'Functions')
    local d = p.inlineFunction
    d.code.edit:SetText('return value + 1')
    d.code.edit.scripts.OnTextChanged(d.code.edit, true)
    d:UpdateActions()

    for _, delta in ipairs({ 150, -5000 }) do
        drag(p.roster.splitter, state, delta, a)
        d = p.inlineFunction
        local side = p.roster.frame:GetWidth()

        assert(
            d.frame.point[2] == side + 18 and d.frame:GetWidth() == 1000 - side - 18,
            'inline editor did not follow the divider'
        )

        assert(d.code:GetText() == 'return value + 1' and d:IsDirty(), 'divider drag lost unsaved code')
        audit.assertContained(host, frames, 'functions after drag ' .. delta, { captions = true })
    end
end)

finish()
