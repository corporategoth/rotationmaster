-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local h = assert(io.open('tests/settings_pages.lua'))
    local source = h:read('*a')
    h:close()
    local prefix = assert(source:match('^(.-)\ntest%('))

    prefix = prefix:gsub(
        '    local codecData,codecDeps=[^\n]+\n',
        "    for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/diff.lua','Data/import_session.lua'})do f.load(path)end\n"
    )

    return assert(loadstring(prefix .. '\nreturn fixture()', '@help-settings-fixture'))()
end

local function tooltip(f)
    local t = {}

    function t:SetOwner(c)
        self.owner = c
    end

    function t:IsOwned(c)
        return self.owner == c
    end

    function t:SetText(v)
        self.text = v
    end

    function t:AddLine(v)
        self.line = v
    end

    function t:Show()
        self.visible = true
    end

    function t:Hide()
        self.visible = false
        self.owner = nil
    end

    f.env.GameTooltip = t
    return t
end

test('read-only Help route leaves invalid pending text focus draft and history unchanged', function()
    local f, parent = fixture()
    local a = f.addon
    assert(a.OpenWorkbenchHelp, 'missing read-only Help route')
    local p = a:OpenNativeSettings(parent, 'General')
    local c = p.fields.poll_value
    c:SetText('bad')
    c.scripts.OnTextChanged(c, true)
    c:SetFocus()
    c:HighlightText(1, 2)
    local history, flush = 0, 0

    p.WithSettingsHistory = function()
        history = history + 1
        error('Help history')
    end

    p.FlushEdits = function()
        flush = flush + 1
        error('Help flush')
    end

    local saved = a.db.profile.poll
    local dirty = p:IsSettingsDraftDirty()

    local d = a:OpenWorkbenchHelp({
        heading = 'General',
        sections = function() return a:WorkbenchPageHelp('General') end,
        valid = function() return p:Valid(p.generation) end,
    })

    assert(
        d
            and c:GetText() == 'bad'
            and c:HasFocus()
            and c.selection[1] == 1
            and c.selection[2] == 2
            and saved == a.db.profile.poll
            and dirty == p:IsSettingsDraftDirty()
            and history == 0
            and flush == 0
    )
end)

test('reentrant or retired document construction cannot overwrite newer Help', function()
    local f = fixture()
    local a = f.addon
    assert(a.OpenWorkbenchHelp, 'missing read-only Help route')
    local live = true

    assert(
        not a:OpenWorkbenchHelp({
            heading = 'Old',
            valid = function() return live end,
            sections = function()
                a:OpenWorkbenchHelp({ heading = 'New', sections = { { title = 'New', text = 'New' } } })
                return { { text = 'Old' } }
            end,
        })
    )

    assert(a.helpWindow.heading == 'New')

    assert(
        not a:OpenWorkbenchHelp({
            heading = 'Retired',
            valid = function() return live end,
            sections = function()
                live = false
                return {}
            end,
        }) and a.helpWindow.heading == 'New'
    )
end)

test('explicit brief binding preserves native hover and retires stale pooled handlers', function()
    local f, parent = fixture()
    local a = f.addon
    assert(a.BindWorkbenchHelp, 'missing shared Help binding')
    local t = tooltip(f)
    local c = a:CreateWorkbenchButton(parent, 'Value')
    local old = 0

    a:SetUIScript(c, 'OnEnter', function()
        old = old + 1
        t:SetOwner(c)
        t:SetText('Native hyperlink')
    end)

    local valid = true
    local clear = a:BindWorkbenchHelp(c, { brief = 'Meaning', valid = function() return valid end })
    local stale = c:GetScript('OnEnter')
    stale(c)
    assert(old == 1 and t.text == 'Native hyperlink' and t.line == 'Meaning')
    clear()
    a:BindWorkbenchHelp(c, { brief = 'New', valid = function() return true end })
    stale(c)
    assert(old == 1)
    c:GetScript('OnEnter')(c)
    assert(old == 2 and t.line == 'New')
    valid = false
end)

test('form briefs explain interactions without history or field commits and retire on release', function()
    local f, parent = fixture()
    local a = f.addon
    local t = tooltip(f)
    local p = a:CreateSettingsForm(parent)
    local changed = 0

    p:Open(function(form)
        form:Edit('x', 'Amount', '', tonumber, function()
            changed = changed + 1
        end)
    end)

    local c = p.fields.x
    assert(c:GetScript('OnEnter'), 'missing pooled field brief')

    p.WithSettingsHistory = function()
        error('hover history')
    end

    c:GetScript('OnEnter')(c)
    assert(t.text and changed == 0)
    local stale = c:GetScript('OnEnter')
    p:Release()
    t.text = nil
    stale(c)
    assert(t.text == nil and changed == 0)
end)

test('top tabs keep navigation briefs without Help icons while window and pane Help remain available', function()
    local f = fixture()
    local a = f.addon
    a.SetupOptions = function() end
    f.load('UI/config.lua')
    local shell = a:ShowConfig('General')
    local p = shell.pane
    local c = p.fields.poll_value
    c:SetText('bad')
    c.scripts.OnTextChanged(c, true)
    c:SetFocus()
    local t = tooltip(f)
    assert(#shell.tabs == 9)

    for _, tab in ipairs(shell.tabs) do
        assert(not tab.help, 'top-level tab still has Help: ' .. tab.section)
        tab:GetScript('OnEnter')(tab)
        assert(t.visible and t.text, 'tab navigation brief missing')
        tab:GetScript('OnLeave')(tab)
    end

    assert(shell.pageHelp and shell.pageHelp:IsShown(), 'missing active pane Help')
    shell.pageHelp:Click()
    assert(a.helpWindow.heading == 'General' and c:GetText() == 'bad' and c:HasFocus())
    shell.help:Click()

    assert(
        a.helpWindow.heading == 'Workbench Help'
            and shell.section == 'General'
            and shell.pane == p
            and c:GetText() == 'bad'
            and c:HasFocus()
    )

    local text = ''

    for _, entry in ipairs(a.helpWindow.sections) do
        text = text .. entry.text
    end

    assert(text:find('Scale', 1, true) and text:find('tabs', 1, true))
    local tab = shell.tabs[1]
    local stale = tab:GetScript('OnEnter')
    shell:RefreshTabs()
    t:Hide()
    stale(tab)
    assert(not t.visible, 'stale tab hover reopened')

    for _, current in ipairs(shell.tabs) do
        assert(not current.help)
    end

    local open = a.OpenNativeSettings

    a.OpenNativeSettings = function(self, parent, key, reuse)
        if key == 'General' or key == 'Announces' then
            return open(self, parent, key, reuse)
        end

        local pane = { frame = f.env.CreateFrame('Frame', nil, parent) }

        function pane:SetWidth(n)
            self.frame:SetWidth(n)
        end

        function pane:SetHeight(n)
            self.frame:SetHeight(n)
        end

        function pane:Release()
            self.frame:Hide()
        end

        pane.frame:Show()
        return pane
    end

    -- The page "?" sits in the content's top-right corner on the first row; it adds no row of its own.
    local corner = shell.paneHeader.point

    assert(
        corner[1] == 'TOPRIGHT'
            and corner[2] == shell.content
            and corner[3] == 'TOPRIGHT'
            and corner[4] == 0
            and corner[5] == 0,
        'page Help is not in the content corner'
    )

    assert(
        shell.paneHeader:GetWidth() == 20
            and shell.pageHelp:GetWidth() == 20
            and shell.pageHelp.icon:GetWidth() == 18
            and shell.content.rmHelpReserve >= shell.pageHelp:GetWidth()
    )

    local stalePage = shell.pageHelp:GetScript('OnClick')
    shell:SelectSection('Profiles', true)
    a.helpWindow:Hide()
    stalePage()
    assert(not a.helpWindow.frame:IsShown(), 'old pane Help reopened after navigation')

    for _, entry in ipairs(shell.tabs) do
        shell:SelectSection(entry.section, true)
        local pane = shell.pane
        local existing = pane.fields and pane.fields.announce_help
        local help = existing or shell.pageHelp
        assert(help:IsShown(), 'missing ' .. entry.section .. ' pane Help')

        if existing then
            assert(not shell.pageHelp:IsShown(), 'duplicate Announces page Help')

            assert(
                shell.paneHeader:GetHeight() >= 1 and shell.paneHeaderHeight == 0,
                'existing Help created an unusable zero-height anchor'
            )
        end

        assert(
            shell.content.point[2] == shell.frame and shell.content.point[3] == 'TOPLEFT',
            'pane content depends on a hidden helper anchor'
        )

        help:Click()

        assert(
            a.helpWindow.heading == (entry.section == 'ItemSets' and 'Item Sets' or entry.section),
            'wrong pane topic ' .. entry.section
        )
    end

    shell:SelectSection('General', true)
    shell.pane:Draw()
    shell.pageHelp:Click()
    assert(a.helpWindow.heading == 'General', 'same-page redraw retired page Help')
    local page = a.WorkbenchPageHelp
    local nested = false

    a.WorkbenchPageHelp = function(self, key)
        if key == 'General' and not nested then
            nested = true
            shell:SelectSection('Profiles', true)
            shell.pageHelp:Click()
        end

        return page(self, key)
    end

    shell.pageHelp:Click()

    assert(
        nested and a.helpWindow.heading == 'Profiles' and shell.helpDialog and shell.helpDialog.heading == 'Profiles',
        'older pane Help request replaced newer owner'
    )

    local retired = shell.pageHelp:GetScript('OnClick')
    a.db.profile = {}
    a.helpWindow:Hide()
    retired()
    assert(not a.helpWindow.frame:IsShown(), 'old profile page Help reopened')
end)

test('gold Help factory and optional dialog descriptor use20button18icon read-only route', function()
    local f, parent = fixture()
    local a = f.addon
    local c = a:CreateWorkbenchHelpButton(parent, 'Help')
    assert(c:GetWidth() == 20 and c.icon:GetWidth() == 18)
    local title = parent:CreateFontString()
    local live = true

    local chrome = a:CreateWorkbenchDialogChrome(parent, title, {
        heading = 'Dialog topic',
        sections = { { text = 'Only Help' } },
        valid = function() return live end,
    })

    assert(chrome.help)
    chrome.help:Click()
    assert(a.helpWindow.heading == 'Dialog topic')
    local stale = chrome.help:GetScript('OnClick')
    live = false
    a:OpenWorkbenchHelp({ heading = 'Newer', sections = {} })
    stale()
    assert(a.helpWindow.frame:IsShown() and a.helpWindow.heading == 'Newer')
end)

test('mounted Help releases only its own widgets on reentry new document and close', function()
    local f = fixture()
    local a = f.addon
    assert(a.OpenWorkbenchHelp, 'missing read-only Help route')
    local released = {}

    local function mount(id)
        return {
            height = 30,
            Release = function()
                released[id] = (released[id] or 0) + 1
            end,
        }
    end

    a:OpenWorkbenchHelp({
        heading = 'One',
        sections = {},
        render = function(parent, current, y, width)
            assert(current() and width == 490 and y == 0)
            return mount('one')
        end,
    })

    a:OpenWorkbenchHelp({
        heading = 'Two',
        sections = {},
        render = function()
            a:OpenWorkbenchHelp({ heading = 'Three', sections = {}, render = function() return mount('three') end })
            return mount('two')
        end,
    })

    assert(a.helpWindow.heading == 'Three' and released.one == 1 and released.two == 1 and not released.three)
    a.helpWindow:Hide()
    assert(released.three == 1)
    a:OpenWorkbenchHelp({ heading = 'Four', sections = {}, render = function() return mount('four') end })
    a:ShowWorkbenchHelp('Legacy', {})
    assert(released.four == 1 and a.helpWindow.heading == 'Legacy')
end)

test('renderer failures do not revive old output or leak a returned invalid mount', function()
    local f = fixture()
    local a = f.addon
    assert(a.OpenWorkbenchHelp, 'missing read-only Help route')
    local release = 0

    a:OpenWorkbenchHelp({
        heading = 'Owned',
        sections = {},
        render = function()
            return {
                height = 10,
                Release = function()
                    release = release + 1
                end,
            }
        end,
    })

    assert(
        not a:OpenWorkbenchHelp({
            heading = 'Invalid',
            sections = {},
            render = function()
                return {
                    height = -1,
                    Release = function()
                        release = release + 1
                    end,
                }
            end,
        })
    )

    assert(release == 2 and not a.helpWindow.frame:IsShown())

    assert(
        not a:OpenWorkbenchHelp({
            heading = 'Throw',
            sections = function()
                error('expected failure')
            end,
        })
    )

    assert(not a.helpWindow.frame:IsShown())
end)

test('existing reference and color hover preserve native content without settings history', function()
    local f, parent = fixture()
    local a = f.addon
    local t = tooltip(f)

    function t:SetHyperlink(v)
        self.link = v
    end

    local p = a:CreateSettingsForm(parent)

    p:Open(function(form)
        form:Spell('spell', 'Spell', 403, function()
            error('change')
        end)

        form:Color('color', 'Color', { r = 1, g = 0, b = 0, a = 1 }, function()
            error('color change')
        end)
    end)

    p.WithSettingsHistory = function()
        error('hover entered settings history')
    end

    p.updateStockObservationActions = function()
        error('hover refreshed stock')
    end

    p.fields.spell:GetScript('OnEnter')(p.fields.spell)
    assert(t.link == 'spell:403')
    p.fields.spell:GetScript('OnLeave')(p.fields.spell)
    local color = p.fields.color
    color:GetScript('OnEnter')(color)
    color:GetScript('OnLeave')(color)
end)

test('failed document callback retires previous widget ownership without replacing a later request', function()
    local f = fixture()
    local a = f.addon
    local released = 0

    a:OpenWorkbenchHelp({
        heading = 'Old',
        sections = {},
        render = function()
            return {
                height = 10,
                Release = function()
                    released = released + 1
                end,
            }
        end,
    })

    assert(
        not a:OpenWorkbenchHelp({
            heading = 'Failure',
            sections = function()
                error('expected')
            end,
        })
    )

    assert(released == 1 and not a.helpWindow.frame:IsShown())
end)

test('owner-invalid Help retires on existing chrome observer and old request cannot close newer Help', function()
    local f = fixture()
    local a = f.addon
    local live = true
    local released = 0

    local old = a:OpenWorkbenchHelp({
        heading = 'Owner',
        valid = function() return live end,
        sections = {},
        render = function()
            return {
                height = 10,
                Release = function()
                    released = released + 1
                end,
            }
        end,
    })

    live = false
    local watcher = assert(a.helpWindow.frame.rmRightClickWatcher)
    watcher:GetScript('OnUpdate')(watcher)
    assert(not a.helpWindow.frame:IsShown() and released == 1)
    a:OpenWorkbenchHelp({ heading = 'Newer', sections = {} })
    old:Hide()
    assert(a.helpWindow.frame:IsShown() and a.helpWindow.heading == 'Newer')
end)

test('new document opened by chrome callback retains its own visible rows', function()
    local f = fixture()
    local a = f.addon
    a:OpenWorkbenchHelp({ heading = 'Warm', sections = {} })
    local d = a.helpWindow
    local original = d.chrome.SetContext
    local nested = false

    d.chrome.SetContext = function(self, ...)
        original(self, ...)

        if not nested then
            nested = true
            a:OpenWorkbenchHelp({ heading = 'Newer', sections = { { title = 'New-title', text = 'New-body' } } })
        end
    end

    a:OpenWorkbenchHelp({ heading = 'Obsolete', sections = { { title = 'Old-title', text = 'Old-body' } } })
    assert(d.heading == 'Newer' and d.frame:IsShown())

    assert(
        d.rows[1]:GetText() == 'New-title' and d.rows[2]:GetText() == 'New-body',
        'obsolete document overwrote newer visible rows'
    )
end)

test('mount release accessor reentry cannot overwrite newer mounted ownership', function()
    local f = fixture()
    local a = f.addon
    local oldReleased, newReleased = 0, 0
    local switched = false

    local newer = {
        height = 9,
        Release = function()
            newReleased = newReleased + 1
        end,
    }

    local old = setmetatable({ height = 7 }, {
        __index = function(_, key)
            if key == 'Release' then
                if not switched then
                    switched = true
                    a:OpenWorkbenchHelp({ heading = 'Newer', sections = {}, render = function() return newer end })
                end

                return function()
                    oldReleased = oldReleased + 1
                end
            end
        end,
    })

    a:OpenWorkbenchHelp({ heading = 'Obsolete', sections = {}, render = function() return old end })
    assert(a.helpWindow.heading == 'Newer' and a.helpWindow.mount == newer, 'old mount overwrote newer owned mount')
    assert(oldReleased == 1 and newReleased == 0)
    a.helpWindow:Hide()
    assert(newReleased == 1)
end)

test('mount Release is consumed once and retained across document lifetime', function()
    local f = fixture()
    local a = f.addon
    local reads, released = 0, 0

    local mount = setmetatable({ height = 5 }, {
        __index = function(_, key)
            if key == 'Release' then
                reads = reads + 1
                assert(reads == 1, 'Release accessor read again')

                return function()
                    released = released + 1
                end
            end
        end,
    })

    assert(a:OpenWorkbenchHelp({ sections = {}, render = function() return mount end }))
    a.helpWindow:Hide()
    assert(reads == 1 and released == 1)
end)

test('height accessor failure still releases the already returned mount exactly once', function()
    local f = fixture()
    local a = f.addon
    local released = 0

    local mount = setmetatable({
        Release = function()
            released = released + 1
        end,
    }, {
        __index = function(_, key)
            if key == 'height' then
                error('unreadable height')
            end
        end,
    })

    assert(not a:OpenWorkbenchHelp({ sections = {}, render = function() return mount end }))
    assert(released == 1 and not a.helpWindow.frame:IsShown())
end)

finish()
