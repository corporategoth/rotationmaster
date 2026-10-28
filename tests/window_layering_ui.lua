-- Window layering through the real RM windows: every popup type opened from every kind of parent it has in the
-- addon, over the client's frame-ordering model (tests/fixtures/layer_model.lua), under both readings of Raise().
-- tests/window_layering.lua covers the registry itself with synthetic windows.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function sourcePrefix(path)
    local h = assert(io.open(path))
    local source = h:read('*a')
    h:close()
    return assert(source:match('^(.-)\ntest%('))
end

-- The condition editor suite's world (real editor, canvas, cards, type picker, help), plus the real settings window.
local editorFixture = assert(loadstring(
    sourcePrefix('tests/condition_editor_ui.lua') .. '\nreturn fixture',
    '@condition-editor-fixture'
))()

-- The settings pages suite's world (real forms, prompts, transfers, pickers).
local pagesFixture = assert(loadstring(
    sourcePrefix('tests/settings_pages.lua') .. '\nreturn fixture',
    '@settings-pages-fixture'
))()

local function layered(f, raise)
    f.env.UISpecialFrames = {}
    return dofile('tests/fixtures/layer_model.lua')(f.env, { raise = raise })
end

local function configWorld(raise)
    local f = editorFixture()
    local a = f.addon
    local model = layered(f, raise)
    local create = model.create
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

        p:SetWidth(parent:GetWidth())
        p:SetHeight(parent:GetHeight())
        p.frame:Show()
        return p
    end

    f.load('UI/settings_transfer.lua')
    f.load('UI/config.lua')
    local shell = a:ShowConfig('Rotations')
    return f, a, model, shell
end

local function covers(model, popup, window, except)
    local ok, node = model.coversWindow(popup, window, except)

    assert(
        ok,
        'popup (level '
            .. popup.layer.level
            .. ') is beneath content of the window it came from (level '
            .. tostring(node and node.layer.level)
            .. ')'
    )
end

local function each(name, body)
    for _, raise in ipairs({ 'siblings', 'strata' }) do
        test(name .. ' [' .. raise .. ' raise]', function()
            body(raise)
        end)
    end
end

local function number()
    return { type = 'NUMBER', number = 7 }
end

each(
    'the condition editor opens above the settings window, whichever way the settings window was clicked since',
    function(raise)
        local f, a, model, config = configWorld(raise)
        local editor = assert(a:ShowConditionEditor(1, 0, number(), function() end))
        covers(model, editor.frame, config.frame)

        -- Click the settings window (its content and a control inside it): the editor must not end up beneath it.
        for _, target in ipairs({ config.content, config.footer, config.frame }) do
            model.click(target)
            a:SyncWindowLayers()
            covers(model, editor.frame, config.frame)

            assert(
                f.env.RotationMasterFrontmostDialog == editor.frame,
                'Escape would close the settings window under the editor'
            )
        end

        -- Edit another condition while one is open: the open editor is brought forward, not left beneath.
        model.click(config.content)
        assert(a:ShowConditionEditor(2, 0, number(), function() end) == editor)
        covers(model, editor.frame, config.frame)
        -- Closed and opened again after the settings window was raised.
        editor.cancel:Click()
        model.click(config.content)
        assert(a:ShowConditionEditor(1, 0, number(), function() end) == editor)
        covers(model, editor.frame, config.frame)
    end
)

each('Help opened from the editor, and from the settings window, stays above the window it came from', function(raise)
    local f, a, model, config = configWorld(raise)
    local editor = assert(a:ShowConditionEditor(1, 0, number(), function() end))
    local help = assert(a:ShowWorkbenchHelp('Topic', { { title = 'A', text = 'b' } }, 'Rotation Master'))
    covers(model, help.frame, editor.frame)
    covers(model, help.frame, config.frame)

    for _, target in ipairs({ editor.frame, config.content }) do
        model.click(target)
        a:SyncWindowLayers()
        covers(model, help.frame, editor.frame)
        covers(model, help.frame, config.frame)
    end

    -- A second Help topic replaces the first inside the same (still visible) window.
    model.click(editor.frame)
    assert(a:ShowWorkbenchHelp('Other', { { title = 'C', text = 'd' } }, 'Rotation Master') == help)
    covers(model, help.frame, editor.frame)
end)

each('dropdown menus, the condition type picker and full-text reports open above the editor that owns them', function(
    raise
)
    local f, a, model, config = configWorld(raise)
    local editor = assert(a:ShowConditionEditor(1, 0, number(), function() end))
    local menu = a:CreateWorkbenchSelector()

    menu:Open(
        editor.apply,
        { { value = 1, text = 'One' }, { value = 2, text = 'Two' } },
        nil,
        function() end,
        function() return true end
    )

    covers(model, menu.frame, editor.frame)
    covers(model, menu.frame, config.frame)
    model.click(editor.frame)
    a:SyncWindowLayers()
    covers(model, menu.frame, editor.frame)
    menu:Hide()

    if a.ShowConditionText then
        local text = assert(a:ShowConditionText('A long condition expression', 'Full text'))
        covers(model, text.frame, editor.frame)
        model.click(editor.frame)
        a:SyncWindowLayers()
        covers(model, text.frame, editor.frame)
        -- Shown again while still visible, after the editor was clicked.
        model.click(editor.frame)
        a:ShowConditionText('Another expression', 'Full text')
        covers(model, text.frame, editor.frame)
    end

    local card = editor.canvas.cards[1]

    if card and card.typeButton then
        card.typeButton:Click()
        local host = card.picker and card.picker.host or editor.picker and editor.picker.host

        if host and host:IsShown() then
            covers(model, host, editor.frame, { host })
        end
    end
end)

each('a text report opened over the editor and a report opened over the settings window are both in front', function(
    raise
)
    local f, a, model, config = configWorld(raise)
    local report = a:CreateWorkbenchTextReport()
    report:SetReport('Report', 'text', nil)
    covers(model, report.frame, config.frame)
    local editor = assert(a:ShowConditionEditor(1, 0, number(), function() end))
    model.click(config.content)
    a:SyncWindowLayers()
    covers(model, editor.frame, config.frame)
    -- The report was open first, so it is beneath the editor opened later: that is the newest-in-front rule.
    assert(model.over(editor.frame, report.frame))
    report:SetReport('Report again', 'more', nil)
    covers(model, report.frame, editor.frame)
end)

each('settings prompts, transfer windows, pickers and comparisons open above the page that owns them', function(raise)
    local f, parent = pagesFixture()
    local a = f.addon
    local model = layered(f, raise)
    local window = model.ensure(parent)
    a:OpenPopup({ frame = window }, nil, { kind = 'window' })
    window:Show()
    local p = a:CreateSettingsForm(parent)
    p:Open(function() end)

    local function check(name, frame, except)
        local ok, node = model.coversWindow(frame, window, except or { frame })

        assert(
            ok,
            name
                .. ' is beneath the settings window ('
                .. frame.layer.level
                .. ' vs '
                .. tostring(node and node.layer.level)
                .. ')'
        )

        model.click(window)
        a:SyncWindowLayers()
        ok, node = model.coversWindow(frame, window, except or { frame })

        assert(
            ok,
            name
                .. ' fell beneath the settings window after it was clicked ('
                .. frame.layer.level
                .. ' vs '
                .. tostring(node and node.layer.level)
                .. ')'
        )
    end

    p:Confirm('Sure?', function() end)
    check('confirm prompt', p.prompt.frame)
    p.prompt.frame:Hide()
    local transfer = a:ShowSettingsTextTransfer(p, 'Transfer', 'Data', function() return true end)
    check('text transfer', transfer.frame)
    -- Opened again while visible, after the page was clicked.
    model.click(window)
    a:ShowSettingsTextTransfer(p, 'Transfer', 'Data', function() return true end)
    check('text transfer, again', transfer.frame)
    transfer.frame:Hide()
    local left, right = { name = 'Same', type = 'pixel', lines = 8 }, { name = 'Same', type = 'pixel', lines = 9 }
    local compare = a:ShowCollectionComparison(p, 'effect', left, right)
    check('collection comparison', compare.frame)
    compare.frame:Hide()
    local picker = a:CreateWorkbenchColorPicker(parent)
    picker:Open({ r = 1, g = 0, b = 0, a = 1 }, function() end, function() return true end, parent)
    check('color picker', picker.frame)
    model.click(window)
    picker:Open({ r = 0, g = 1, b = 0, a = 1 }, function() end, function() return true end, parent)
    check('color picker, again', picker.frame)
    picker:Close(false)

    if a.ShowWorkbenchIconPicker then
        local picker = a:ShowWorkbenchIconPicker(nil, function() end, function() return true end)
        check('icon picker', picker.frame)
        model.click(window)
        a:ShowWorkbenchIconPicker(nil, function() end, function() return true end)
        check('icon picker, again', picker.frame)
    end
end)

each(
    'the embedded editor\'s stand-alone panels (library strata DIALOG) open above the window that embeds the editor',
    function(raise)
        local f, a = dofile('tests/fixtures/lua_workbench.lua')()
        local model = layered(f, raise)
        -- The library builds these panels itself, in DIALOG; only their opening matters here.
        local real = a.LuaWorkbenchModules.Inspector

        a.LuaWorkbenchModules.Inspector = function(name, engine)
            real(name, engine)

            function engine.Inspector:Show()
                local panel = self.panel or f.env.CreateFrame('Frame', nil, f.env.UIParent)
                self.panel = panel
                panel:SetFrameStrata('DIALOG')
                panel:Show()
            end
        end

        local host = model.create('Frame', 'host', f.env.UIParent)
        a:OpenPopup({ frame = host }, nil, { kind = 'window' })
        host:SetFrameLevel(400)
        local deep = model.create('Frame', nil, host)
        deep:SetFrameLevel(host:GetFrameLevel() + 300)
        local code = a:CreateLuaWorkbenchControl(host, function() end, function() return true end)
        code.engine.Inspector:Show({}, 'value')
        local panel = code.engine.Inspector.panel

        assert(
            panel:GetFrameStrata() == 'FULLSCREEN_DIALOG' and model.over(panel, host) and model.over(panel, deep),
            'the Inspector opened beneath the window that embeds the editor'
        )

        model.click(host)
        a:SyncWindowLayers()
        assert(model.over(panel, host), 'the Inspector fell beneath its window after the window was clicked')
    end
)

-- No window creator sets its own strata, level or click-raise any more: that is the registry's job.
test('window creators leave strata, frame level and click-raise to the registry', function()
    local allowed = {
        ['UI/window.lua'] = true,
        ['UI/spell_search.lua'] = 'suggestion list in the tooltip strata',
        ['UI/controls.lua'] = 'drag ghost in the tooltip strata',
        ['UI/drag_presentation.lua'] = 'drag ghost restore',
        ['UI/preview.lua'] = 'in-game preview overlay, not a window',
        ['UI/talent_popup.lua'] = 'ring on a Blizzard talent button; restore of Blizzard strata and level',
    }

    local files = io.popen('ls UI/*.lua Integrations/*.lua')
    local offenders = {}

    for path in files:lines() do
        if not allowed[path] then
            local h = assert(io.open(path))
            local source = h:read('*a')
            h:close()

            for line in source:gmatch('[^\n]+') do
                if
                    line:find('SetFrameStrata', 1, true)
                    or line:find(':SetToplevel', 1, true)
                    or line:find(':Raise()', 1, true)
                    or line:find('RegisterWindowForEscape', 1, true)
                then
                    offenders[#offenders + 1] = path .. ': ' .. line:sub(1, 120)
                end
            end
        end
    end

    files:close()
    assert(#offenders == 0, 'ad-hoc window layering outside UI/window.lua:\n' .. table.concat(offenders, '\n'))
end)

finish()
