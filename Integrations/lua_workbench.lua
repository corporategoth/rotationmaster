local addon_name, rm = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

local moduleOrder = {
    'BufferedPaste', 'LuaEditor', 'Analysis', 'LuaConsole', 'UI', 'Search', 'Organization', 'Helpers', 'Navigation',
    'DebugProbe', 'DebugCompiler', 'Debugger', 'DebugUI', 'APIHelp', 'KnowledgeBase', 'Inspector', 'Autocomplete',
    'EditorActions', 'Snippets', 'Automation'
}

local function editorPreferences()
    local installed = type(_G.LuaWorkbench) == 'table' and _G.LuaWorkbench.db
    local source = type(installed) == 'table' and type(installed.options) == 'table' and installed.options or {}
    local result = {}

    for _, key in ipairs({
        'autocomplete',
        'autoIndent',
        'autoPairs',
        'apiHelp',
        'debugReadOnly',
        'indentWidth',
        'outputLimit',
    }) do
        local value = source[key]
        if type(value) == 'boolean' or type(value) == 'number' then result[key] = value end
    end

    return result
end

-- Cleanup retires the lease first and finishes independent native resources
-- even if one optional provider/debugger cleanup fails.
local function cleanup()
    local failed, why

    local function attempt(callback, ...)
        local ok, result = pcall(callback, ...)
        if not ok and not failed then failed, why = true, result end
        return ok
    end

    local function finish()
        if failed then error(why, 0) end
    end

    return attempt, finish
end

local function inactive()
    return false
end

function rm:CreateLuaWorkbenchEngine(options)
    options = options or {}
    -- Only documented-looking scalar preferences cross this boundary. Never use
    -- the installed workspace's drafts, runtime debugger or mutable namespace.
    local settings = editorPreferences()
    local W = { current = options.id or 'RM', currentName = options.name or L['Custom condition'] }

    W.db = {
        options = settings,
        snippets = {},
        drafts = {},
        folders = {},
        folderBySnippet = {},
        clearOnRun = {},
        autoRun = {},
        helperModules = {},
        textSnippets = {},
        panelPositions = {},
        split = .65,
    }

    local engine = { embedded = true, L = {}, Workspace = W, embeddingOptions = options }
    -- Use upstream's own translations rather than translating its UI in RM.
    self.LuaWorkbenchModules.Localization(addon_name, engine)

    function W:UpdateStatus()
        if options.status then options.status(engine.Query.Console.statusText, engine.Query.Console.statusFailed) end
    end

    function W:NormalizeSource(text)
        return (text or ''):gsub('\r\n', '\n')
    end

    function W:StoreSource(text)
        return self:NormalizeSource(text)
    end

    function W:IsSnippetDirty(id)
        local draft, saved = self.db.drafts[id], self.db.snippets[id]
        return draft and (not saved or draft.source ~= saved.source) or false
    end

    function W:Capture()
        self.db.drafts[self.current] = { name = self.currentName, source = engine.Query.Console.source }
        self.dirty = self:IsSnippetDirty(self.current)
        self:UpdateStatus()
    end

    function W:HidePanels(except)
        if engine.Inspector then engine.Inspector:StopPicking() end

        for _, name in ipairs({ 'KnowledgeBase', 'Snippets', 'Navigation', 'Inspector', 'DebugUI' }) do
            local object = engine[name]

            for _, key in ipairs({ 'panel', 'snapshot', 'tooltip', 'copyPanel' }) do
                local panel = object and object[key]
                if panel and panel ~= except and panel.Hide then panel:Hide() end
            end
        end

        if self.contextMenu then self.contextMenu:Hide() end
    end

    function W:Select(id)
        if options.navigate then return options.navigate(id) end
        return false
    end

    function W:Show()
        if options.show then options.show() end
    end

    function W:ShowHelp()
        if options.help then options.help() end
    end

    function W:Layout()
        if engine.control then engine.control:Layout() end
    end

    function W:RunShortcut(key)
        if engine.DebugUI:Shortcut(key) then return true end
        if engine.Navigation:Shortcut(key) then return true end
        return false
    end

    for _, name in ipairs(moduleOrder) do
        local factory = self.LuaWorkbenchModules[name]
        if not factory then return nil, 'missing-editor-module:' .. name end
        factory(addon_name, engine)
    end

    local make = engine.Debugger.MakeEnvironment

    function engine.Debugger:MakeEnvironment(...)
        local environment = make(self, ...)

        for name, value in pairs(options.environment or {}) do
            environment[name] = value
            self.environmentBuiltinSets[environment][name] = true
        end

        local meta = getmetatable(environment)
        local previous = meta.__index

        meta.__index = function(table, key)
            if options.parameterNames and options.parameterNames[key] then return nil end
            if type(previous) == 'function' then return previous(table, key) end
            return previous and previous[key]
        end

        return environment
    end

    local event = engine.APIHelp.events
    local eventHandler = event and event:GetScript('OnEvent')
    local eventLease
    local stopDebugger = engine.Debugger.Stop

    function engine:Acquire()
        if self.closing then error('editor-release-in-progress', 0) end
        if self.released == false then return end
        self.released = false
        self.Workspace.db.options = editorPreferences()
        local lease = {}
        eventLease = lease

        -- Limited completion never subscribes or loads Blizzard API docs.
        if event and not options.limited then
            event:RegisterEvent('PLAYER_REGEN_ENABLED')

            event:SetScript('OnEvent', function(...)
                if not self.released and eventLease == lease and eventHandler then return eventHandler(...) end
            end)
        end
    end

    engine:Acquire()
    local refresh = engine.Query.Console.Refresh

    function engine.Query.Console:Refresh(...)
        if not engine.released then return refresh(self, ...) end
    end

    function engine:Release()
        if self.released then return end
        self.released = true
        self.closing = true
        eventLease = nil
        local attempt, finish = cleanup()

        if not attempt(self.Debugger.Stop, self.Debugger) and self.Debugger.Stop ~= stopDebugger then
            attempt(stopDebugger, self.Debugger)
        end

        attempt(self.DebugProbe.Stop, self.DebugProbe)
        attempt(self.Autocomplete.Hide, self.Autocomplete)
        attempt(self.Workspace.HidePanels, self.Workspace)

        if event then
            attempt(event.UnregisterAllEvents, event)
            attempt(event.SetScript, event, 'OnEvent', nil)
        end

        if self.Automation.probe then attempt(self.Automation.probe.UnregisterAllEvents, self.Automation.probe) end
        local input = self.Query.Console.input

        if input and input.editBox then
            attempt(self.Query.Editor.Detach, self.Query.Editor, input)
            attempt(input.editBox.ClearFocus, input.editBox)
            attempt(input.frame.Hide, input.frame)
        end

        self.closing = nil
        finish()
    end

    function engine:ResetLease()
        self.released = true
        eventLease = nil
        local attempt, finish = cleanup()
        local console, editor = self.Query.Console, self.Query.Editor
        local input = console.input
        self.rmContext = nil
        self.rmSymbols = {}
        if self.APIHelp.rmSyncSymbols then attempt(self.APIHelp.rmSyncSymbols, self.APIHelp) end
        local api = self.APIHelp
        api.rmUndocumented = nil
        api.source = nil
        api.paths = nil
        api.text = {}
        api.pending = nil
        api.pendingForce = nil
        local autocomplete = self.Autocomplete
        autocomplete.context, autocomplete.items, autocomplete.input, autocomplete.pending = nil, nil, nil, nil
        autocomplete.rmNameSymbols, autocomplete.rmNameSource, autocomplete.rmVisibleNames = nil, nil, nil
        self.Navigation.history = {}
        self.Navigation.held = nil
        self.Analysis.cache = {}
        self.Analysis.order = {}
        self.Analysis.tokenCount = 0
        self.Analysis.byteCount = 0
        editor.lexicalCache = nil
        editor.viewportLexicalCache = nil
        console.source = ''
        console.environment = nil
        console.linePositionCache = nil
        console.lines = {}
        console.characters = 0
        console.undoLines = nil
        console.undoDumpLineLimit = nil
        console.undoDumpCharacterLimit = nil
        console.dumpLineLimit = nil
        console.dumpCharacterLimit = nil
        console.statusText = nil
        console.statusFailed = nil
        console.lastError = nil

        for _, key in ipairs({
            'snippets', 'drafts', 'folders', 'folderBySnippet', 'clearOnRun', 'autoRun', 'helperModules',
            'textSnippets', 'debugBreakpoints'
        }) do
            W.db[key] = {}
        end

        W.db.startupDebug = nil
        W.current = 'RM'
        W.currentName = 'RM'
        W.dirty = nil
        W.f5Held = nil
        local debugger = self.Debugger
        debugger.breakpoints = {}
        debugger.breakpointSources = {}
        debugger.loadedBreakpointRecords = nil
        debugger.breakpointDB = nil
        debugger.source = nil
        debugger.scriptId = nil
        debugger.terminalLines = {}
        local probe = self.DebugProbe
        probe.source = nil
        probe.scriptId = nil
        probe.terminalLines = {}
        local ui = self.DebugUI
        ui.snapshotRecord = nil
        ui.snapshotLine = nil
        ui.snapshotMeasureCache = nil
        ui.drawerOpen = false
        ui.renderedVariables = nil
        local inspector = self.Inspector
        inspector.refs = {}
        inspector.root = nil
        inspector.target = nil
        inspector.history = {}
        inspector.rows = {}

        for _, row in ipairs(inspector.buttons or {}) do
            row.node = nil
            attempt(row.Hide, row)
            if row.text then attempt(row.text.SetText, row.text, '') end
        end

        self.Automation.environments = {}
        self.Automation.running = {}
        self.EditorActions.lineClipboard = nil

        -- A FontString or EditBox with no font raises "Font not set" from
        -- :SetText(), even for ''. One the editor never painted has none yet,
        -- so it gets the plain font first; it is being emptied, not shown.
        local function clearText(widget)
            if not widget then return end

            if widget.GetFont and widget.SetFontObject then
                local ok, font = pcall(widget.GetFont, widget)

                if not ok or not font then
                    attempt(widget.SetFontObject, widget, GameFontHighlightSmall or 'GameFontHighlightSmall')
                end
            end

            attempt(widget.SetText, widget, '')
        end

        local function clearInput(value)
            if not value then return end
            clearText(value.editBox)
            local state = value.queryEditor

            if state then
                clearText(state.overlay)

                for key in pairs(state) do
                    if key ~= 'overlay' and key ~= 'caret' and key ~= 'active' then state[key] = nil end
                end
            end
        end

        clearInput(ui.terminalOutput)
        clearText(ui.terminalInput)
        clearInput(ui.snapshotInput)
        clearText(ui.snapshotTitle)
        clearText(ui.snapshotMeasure)

        if probe.terminal then
            clearInput(probe.terminal.output)
            clearText(probe.terminal.input)
        end

        if probe.snapshot then clearInput(probe.snapshot.code) end
        if self.Navigation.snapshotInput then clearInput(self.Navigation.snapshotInput) end
        self.KnowledgeBase.history = {}

        if self.Snippets.panel then
            self.Snippets.panel.target = nil
            self.Snippets.panel.selected = nil
        end

        if W.contextMenu then
            for _, button in ipairs(W.contextMenu.buttons) do
                button.action = inactive
                button.tooltipText = nil
                clearText(button.text)
            end

            clearText(W.contextMenu.measure)
        end

        if input then
            input.debugHitLayout = nil
            local state = options.limited and input.queryEditor or input.queryEditorCache

            if state then
                clearText(state.overlay)

                for key in pairs(state) do
                    if key ~= 'overlay' and key ~= 'caret' and key ~= 'active' then state[key] = nil end
                end

                if options.limited then
                    state.source = ''
                    state.elapsed = 0
                end
            end

            local lines = input.queryLineNumberCache

            if lines then
                lines.source = nil
                lines.rmMetrics = nil
                lines.rmRender = nil
                lines.positions = nil
                lines.lineHeights = nil
                clearText(lines.measure)
            end

            -- Native completion keeps its accepted text-clearing order in the
            -- outer control; never emit a live OnTextChanged from this reset.
            if not options.limited then clearText(input.editBox) end
        end

        finish()
    end

    return engine
end

function rm:CreateLuaWorkbenchControl(parent, changed, valid)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(600, 300)

    local c = {
        frame = frame,
        provider = 'LuaWorkbench',
        changed = changed,
        valid = valid,
        setting = false,
        context = {},
        environment = { addon = self, L = L },
    }

    local engine = assert(self:CreateLuaWorkbenchEngine({
        id = 'RM',
        environment = c.environment,
        status = function(text, failed)
            if c.status then
                c.status:SetText(text or '')
                c.status:SetTextColor(failed and 1 or .5, failed and .3 or .85, .5)
            end
        end,
        show = function()
            if c.showOwner then c.showOwner() end
        end,
        help = function()
            self:ShowWorkbenchHelp(
                L['Lua editor'],
                {
                    {
                        title = L['Run current buffer'],
                        text = L['Play runs the current buffer once without debugging. Condition callbacks use the fields configured in Test; functions use Test arguments. Returns, printed output and full errors are available in Output. Running does not apply source changes or replace the live callback.'],
                    },
                    {
                        title = L['Debug current buffer'],
                        text = L['The Debug button starts a separate session and pauses at the first executable line or breakpoint. Continue resumes execution, Step over advances past the current operation, and Step into enters instrumented script functions. Native functions cannot be stepped into. Stop ends the session. F5 continues, F10 steps over, F11 steps into, and Shift+F5 stops.'],
                    },
                    {
                        title = L['Debugger terminal'],
                        text = L['The debugger terminal appears below the code while debugging. When paused, enter expressions or assignments to inspect or change the current variables. The drawer button hides or shows the terminal. Output provides a copyable report of printed output, terminal evaluations and complete errors.'],
                    },
                },
                frame
            )
        end,
    }))

    c.engine = engine
    engine.control = c
    local UI, W, C, E = engine.UI, engine.Workspace, engine.Query.Console, engine.Query.Editor

    -- The embedded library's stand-alone panels hang from UIParent at DIALOG strata, which is below every RM
    -- window. Whenever one is opened, lay it out with the RM windows, above the editor it came from.
    for _, spec in ipairs({
        { engine.Inspector, 'Show', 'panel' },
        { engine.DebugProbe, 'ShowTerminal', 'terminal' },
        { engine.DebugProbe, 'ShowSnapshot', 'snapshot' },
        { engine.DebugProbe, 'BuildPanel', 'panel' },
    }) do
        local object, method, field = spec[1], spec[2], spec[3]
        local original = object and object[method]

        if type(original) == 'function' then
            object[method] = function(self, ...)
                local function after(...)
                    local panel = self[field]

                    if type(panel) == 'table' and panel.IsShown and panel:IsShown() then
                        rm:OpenPopup({ frame = panel }, frame, { escape = false })
                    end

                    return ...
                end

                return after(original(self, ...))
            end
        end
    end

    W.window = frame
    W.helpFrame = {}
    UI.colors.background = { .055, .06, .065, 1 }
    UI.colors.panel = { .09, .10, .11, 1 }
    UI.colors.hover = { .15, .17, .18, 1 }
    local baseEditor = UI.Editor

    function UI:Editor(owner, label, readonly)
        local input = baseEditor(self, owner, label, readonly)
        input.editBox:SetFont('Interface\\AddOns\\' .. addon_name .. '\\Fonts\\Inconsolata-Regular.ttf', 12, '')
        return input
    end

    function UI:Scroll(owner)
        local scroll = rm:CreateWorkbenchScrollFrame(owner)
        scroll.bar = scroll.workbenchBar
        return scroll
    end

    local input = UI:Editor(frame, '')
    input.editBox:SetText('')
    C.input = input
    c.edit = input.editBox
    c.scroll = input.scrollFrame
    input.frame:SetAllPoints(frame)
    c.status = input.frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    c.status:SetPoint('BOTTOMLEFT', 6, 3)
    c.status:SetPoint('BOTTOMRIGHT', -6, 3)
    c.status:SetHeight(18)
    c.status:SetJustifyH('LEFT')
    c.status:SetJustifyV('MIDDLE')
    c.status:SetText('')
    c.arguments = rm:CreateWorkbenchEditBox(input.frame)
    c.arguments:SetText('{}')
    c.arguments:SetPoint('TOPLEFT', 88, -2)
    c.arguments:SetPoint('RIGHT', input.frame, 'RIGHT', -168, 0)
    c.arguments:SetHeight(22)
    c.argumentLabel = input.frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    c.argumentLabel:SetPoint('TOPLEFT', 4, -7)
    c.argumentLabel:SetText(L['Test arguments'])
    c.play = UI:Button(input.frame, 'play', engine.L.queryLuaRun or L['Run test'], function() c:Run() end)
    c.play:SetPoint('TOPRIGHT', -3, -1)
    engine.DebugUI:Build(c.play)
    -- The editor's nested ScrollFrame/EditBox owns a higher native frame level
    -- than sibling controls unless we explicitly lift the debugger chrome.
    engine.DebugUI.toolbar:SetFrameLevel(c.edit:GetFrameLevel() + 10)
    engine.DebugUI.dock:SetFrameLevel(c.edit:GetFrameLevel() + 10)
    c.knowledge = rm:CreateWorkbenchIconButton(input.frame, 'search', L['API knowledge'])
    c.knowledge:SetPoint('RIGHT', W.debugButton, 'LEFT', -2, 0)

    rm:SetUIScript(c.knowledge, 'OnClick', function()
        if not c.released and valid() then engine.KnowledgeBase:Show() end
    end)

    c.output = rm:CreateWorkbenchButton(input.frame, L['Output'], 64)
    c.output:SetPoint('RIGHT', c.knowledge, 'LEFT', -4, 0)
    c.output.tooltip = L['View and copy full debugger output and errors.']

    function c:ShowDebugOutput()
        return rm:ShowLuaDebugOutput(self)
    end

    rm:SetUIScript(c.output, 'OnClick', function() c:ShowDebugOutput() end)

    local function fullError(value)
        if issecretvalue and issecretvalue(value) then return '<secret>' end
        local ok, text = pcall(tostring, value)
        return ok and text or L['Unavailable']
    end

    local fail = engine.Debugger.Fail

    function engine.Debugger:Fail(value)
        c.debugError = fullError(value)
            .. (self.line and '\n' .. tostring(W.current) .. ':' .. tostring(self.line) or '')

        return fail(self, value)
    end

    local report = C.ReportError

    function C:ReportError(value, stack)
        c.debugError = fullError(value) .. (stack and '\n' .. fullError(stack) or '')
        return report(self, value, stack)
    end

    function c:CloseDebugSurface()
        if self.debugSurface then
            self.debugSurface:Close()
            self.debugSurface = nil
        end
    end

    local stop = engine.Debugger.Stop

    function engine.Debugger:Stop()
        local result = stop(self)
        if not c.startingDebug then c:CloseDebugSurface() end
        return result
    end

    function c:InvokeWithSurface(callback, ...)
        local surface = self.debugSurface
        if not surface then return pcall(callback, ...) end
        return rm:WithConditionWidgetObservation(function(widget) surface:Guard(widget) end, pcall, callback, ...)
    end

    local resume = engine.Debugger.Resume

    function engine.Debugger:Resume(...)
        local ok, result = c:InvokeWithSurface(resume, self, ...)
        if not ok then self:Fail(result) end
    end

    function engine.DebugUI:Start()
        return c:Debug()
    end

    function engine.DebugUI:Menu(owner)
        W:OpenMenu(owner, {
            { text = engine.L.debugStart, action = function() c:Debug() end },
            {
                text = engine.L.debugBreakpoint,
                action = function() self:ToggleLine(C:GetLinePosition(C.source, c.edit:GetCursorPosition())) end,
            },
            { text = engine.L.debugStop, action = function() engine.Debugger:Stop() end },
        })
    end

    rm:SetUIScript(W.debugButton, 'OnClick', function() c:Debug() end)

    function c:PrepareExecution()
        if self.released or not valid() then return false end
        engine.Debugger:Stop()
        self.debugError = nil
        C:SetStatus(nil)
        local source = self.context.source or {}
        local names, arguments = {}, {}

        if self.context.kind == 'condition' then
            local owner = self.context.testOwner
            local callback = self.context.callback or 'evaluate'

            if not owner or not owner.OwnerValid or not owner.OwnerValid() then
                C:SetStatus(L['Set values in Test before running or debugging this condition.'], true)
                return false
            end

            source = owner:PendingSource()

            if callback == 'evaluate' or callback == 'valid' or callback == 'print' then
                local values, why = rm:ConditionTestValues(owner)

                if not values then
                    C:SetStatus(why or L['Set values in Test before running or debugging this condition.'], true)
                    return false
                end

                arguments = callback == 'evaluate' and { values, {}, GetTime() } or { rm.currentSpec or 0, values }
            elseif callback == 'widget' or callback == 'help' then
                local surface = rm:CreateConditionDebugSurface(owner, callback)

                if not surface then
                    C:SetStatus(L['Unavailable'], true)
                    return false
                end

                self.debugSurface = surface

                surface.onClose = function()
                    if c.debugSurface == surface then
                        c.debugSurface = nil
                        engine.Debugger:Stop()
                    end
                end

                arguments = callback == 'widget' and { surface.parent, rm.currentSpec or 0, surface.values } or {
                    surface.parent,
                }
            else
                arguments = { owner.model.key }
            end
        else
            local parse, why = loadstring('return ' .. self.arguments:GetText(), '@RotationMaster:test-arguments')

            if not parse then
                C:SetStatus(why, true)
                return false
            end

            local environment = setmetatable({ addon = rm, L = L }, { __index = _G })
            setfenv(parse, environment)
            local ok, value = pcall(parse)

            if not ok or type(value) ~= 'table' then
                C:SetStatus(ok and L['Test arguments must be a Lua table.'] or tostring(value), true)
                return false
            end

            arguments = value
        end

        if self.context.kind == 'function' then
            for _, entry in ipairs(source.args or {}) do
                names[#names + 1] = entry.name
            end
        else
            for name in (rm.CustomConditionCallbacks[self.context.callback or 'evaluate'] or ''):gmatch('[%w_]+') do
                names[#names + 1] = name
            end
        end

        for name in pairs(self.environment) do
            self.environment[name] = nil
        end

        self.environment.addon = rm
        self.environment.L = L
        engine.embeddingOptions.parameterNames = {}

        for i, name in ipairs(names or {}) do
            if name ~= '...' then
                self.environment[name] = arguments[i]
                engine.embeddingOptions.parameterNames[name] = true
            end
        end

        -- Build exactly the private locals/namespaces used by the live
        -- compiler. Only this generated binding prelude executes here; user
        -- callback bodies are still deferred to the explicit Run/Debug action.
        local prelude, bindingError = rm:FunctionBindingPrelude(source.bindings, table.concat(names, ','))

        if not prelude then
            self:CloseDebugSurface()
            C:SetStatus(bindingError, true)
            return false
        end

        local roots = {}

        for alias in pairs(source.bindings or {}) do
            roots[alias:match('^[^.]+')] = true
        end

        if not engine.embeddingOptions.parameterNames.functions and not (source.bindings or {}).functions then
            roots.functions = true
        end

        local returns = {}

        for root in pairs(roots) do
            returns[#returns + 1] = '[' .. string.format('%q', root) .. ']=' .. root
        end

        table.sort(returns)

        local chunk, compileError = loadstring(
            'return function(addon)\n' .. prelude .. '\nreturn {' .. table.concat(returns, ',') .. '} end',
            '@RotationMaster:editor-bindings'
        )

        if not chunk then
            self:CloseDebugSurface()
            C:SetStatus(compileError, true)
            return false
        end

        local ok, bound = pcall(function() return chunk()(rm) end)

        if not ok then
            self:CloseDebugSurface()
            C:SetStatus(fullError(bound), true)
            return false
        end

        for root in pairs(roots) do
            self.environment[root] = bound[root]
            engine.embeddingOptions.parameterNames[root] = true
        end

        -- Packaged callbacks can have legacy parameter aliases. Those locals
        -- are declared after the binding prelude in the live compiler, so they
        -- take precedence over an identically named private namespace here too.
        if self.context.kind ~= 'function' then
            for alias, canonical in pairs(rm:CustomConditionParameterAliases(
                source,
                self.context.callback or 'evaluate'
            )) do
                self.environment[alias] = self.environment[canonical]
                engine.embeddingOptions.parameterNames[alias] = true
            end
        end

        return arguments, names
    end

    local startInvocation = engine.Debugger.StartInvocation

    function engine.Debugger:StartInvocation(item)
        -- Named parameters live in the prepared environment. A chunk's `...`
        -- must contain only the declared variadic tail, not those parameters.
        if c.startArguments and not item.callback then item.args = c.startArguments end
        return startInvocation(self, item)
    end

    function c:Debug()
        local arguments, names = self:PrepareExecution()
        if not arguments then return false end
        self.startArguments = { n = 0 }

        if names[#names] == '...' then
            local count = arguments.n or #arguments
            self.startArguments.n = math.max(0, count - #names + 1)

            for index = #names, count do
                self.startArguments[index - #names + 1] = arguments[index]
            end
        end

        engine.DebugUI.drawerOpen = true
        self.startingDebug = true
        local ok, result = pcall(engine.Debugger.Start, engine.Debugger, W.current, self:GetText())
        self.startingDebug = nil
        self.startArguments = nil

        if not ok or not result then
            self:CloseDebugSurface()

            if not ok then
                C:SetStatus(fullError(result), true)
                self.debugError = fullError(result)
            end

            return false
        end

        return result
    end

    function c:Run()
        if self.released or not valid() then return false end
        -- Compile the standalone buffer before creating render resources or
        -- preparing user arguments; checking source never executes its body.
        local chunk, why = loadstring(self:GetText(), '@RotationMaster:run:' .. tostring(W.current))

        if not chunk then
            C:ReportError(why)
            self:ShowDebugOutput()
            return false
        end

        local arguments, names = self:PrepareExecution()
        if not arguments then return false end

        for index, name in ipairs(names) do
            if
                type(name) ~= 'string'
                or not name:match('^[A-Za-z_][A-Za-z_0-9]*$') and not (name == '...' and index == #names)
            then
                self:CloseDebugSurface()
                C:ReportError('invalid-function-arguments')
                self:ShowDebugOutput()
                return false
            end
        end

        -- The body was checked independently above, so it cannot escape this
        -- wrapper and execute while the callable is being constructed.
        local factory, errorText = loadstring(
            'return function(' .. table.concat(names, ',') .. ')\n' .. self:GetText() .. '\nend',
            '@RotationMaster:run:' .. tostring(W.current)
        )

        if not factory then
            self:CloseDebugSurface()
            C:ReportError(errorText)
            self:ShowDebugOutput()
            return false
        end

        local environment = {
            print = function(...) C:Write(...) end,
            dump = function(...) C:DumpArguments(nil, ...) end,
            DevTools_Dump = function(...) C:Dump(...) end,
        }

        for name, value in pairs(self.environment) do
            environment[name] = value
        end

        setmetatable(environment, {
            __index = function(_, key)
                if engine.embeddingOptions.parameterNames[key] then return nil end
                return _G[key]
            end,
        })

        setfenv(factory, environment)
        chunk = factory()

        local function pack(...)
            return { n = select('#', ...), ... }
        end

        local results = pack(self:InvokeWithSurface(chunk, unpack(arguments, 1, arguments.n or #arguments)))

        if not results[1] then
            C:ReportError(results[2])
            self:ShowDebugOutput()
            return false
        end

        -- Named condition summaries are transient tokens, not useful raw table
        -- output. Render only that callback's first structured return; preserve
        -- legacy strings, extra returns and ordinary function table inspection.
        if
            results.n > 1
            and self.context.kind == 'condition'
            and self.context.callback == 'print'
            and type(results[2]) == 'table'
            and rm.RenderConditionSummary
        then
            results[2] = rm:RenderConditionSummary(results[2], false)
        end

        if results.n > 1 then C:Write('return', unpack(results, 2, results.n)) end

        if self.debugSurface then
            C:SetStatus(L['Preview rendered. Use Output for printed messages.'], false)
        else
            C:SetStatus(engine.L.queryLuaComplete, false)
            self:ShowDebugOutput()
        end

        return true
    end

    local updateLabel = C.UpdateEditorLabel

    function C:UpdateEditorLabel()
        updateLabel(self)
        input.label:Hide()
    end

    function c:UpdateDebugAvailability()
        local owner = self.context.testOwner
        local state = owner and owner.conditionTestState

        local needsValues = self.context.kind == 'condition'
            and (self.context.callback == 'evaluate'
                or self.context.callback == 'valid'
                or self.context.callback == 'print')

        local ready = not needsValues
            or owner and owner.OwnerValid and owner.OwnerValid() and state and state.configured

        -- Keep actions clickable so prerequisites can be explained rather than
        -- silently dropping native clicks on disabled buttons.
        if not self.play:IsEnabled() then self.play:Enable() end
        if not W.debugButton:IsEnabled() then W.debugButton:Enable() end
        ready = not not ready

        if self.executionReady ~= ready then
            local why = L['Set values in Test before running or debugging this condition.']
            if ready and C.statusText == why then C:SetStatus(nil) end
            self.executionReady = ready
            UI:Tooltip(self.play, ready and (engine.L.queryLuaRun or L['Run test']) or why)
            UI:Tooltip(W.debugButton, ready and engine.L.debugStart or why)
        end
    end

    local function differs(current, wanted)
        return math.abs(current - wanted) > .1
    end

    function engine.DebugUI:Layout()
        if not self.toolbar then return end
        local active = engine.Debugger.armed == true
        self.toolbar:SetShown(active)

        if not self.rmAnchors then
            self.rmAnchors = true
            self.toolbar:ClearAllPoints()
            self.toolbar:SetPoint('TOPLEFT', 6, -28)
            self.toolbar:SetPoint('TOPRIGHT', -6, -28)
            self.dock:ClearAllPoints()
            self.dock:SetPoint('BOTTOMLEFT', 6, 24)
            self.dock:SetPoint('BOTTOMRIGHT', -6, 24)
        end

        local top = active and 60 or 28
        local height = math.min(180, math.max(80, input.frame:GetHeight() * .4))
        local drawer = active and self.drawerOpen and input.frame:GetHeight() - top - height - 24 >= 32
        self.dock:SetShown(drawer == true)
        if differs(self.dock:GetHeight(), height) then self.dock:SetHeight(height) end
        local terminalWidth = math.max(120, input.frame:GetWidth() * .62 - 16)

        if differs(self.terminalOutput.frame:GetWidth(), terminalWidth) then
            self.terminalOutput.frame:SetWidth(terminalWidth)
        end

        local bottom = drawer and height + 28 or 28
        local changed = self.rmTop ~= top or self.rmBottom == nil or differs(self.rmBottom, bottom)

        if self.rmTop ~= top then
            self.rmTop = top
            input.scrollBG:SetPoint('TOPLEFT', input.frame, 'TOPLEFT', 6, -top)
        end

        if self.rmBottom == nil or differs(self.rmBottom, bottom) then
            self.rmBottom = bottom
            input.scrollBG:SetPoint('BOTTOMRIGHT', input.frame, 'BOTTOMRIGHT', -16, bottom)
        end

        c.arguments:SetShown(not active and c.context.kind ~= 'condition')
        c.argumentLabel:SetShown(not active)
        return changed
    end

    function c:Layout()
        if self.released or self.layingOut then return end
        self.layingOut = true
        local width, height = frame:GetWidth(), frame:GetHeight()

        local resized = self.layoutWidth == nil or differs(self.layoutWidth, width) or differs(
            self.layoutHeight,
            height
        )

        if resized then self.layoutWidth, self.layoutHeight = width, height end

        -- The input keeps its construction-time anchors. Repeated size writes
        -- invalidate native multiline layout even when the host has not moved.
        if differs(input.frame:GetWidth(), width) or differs(input.frame:GetHeight(), height) then
            input.frame:SetSize(width, height)
        end

        local changed = engine.DebugUI:Layout()

        if resized or changed or self.lineNumberSetting ~= (rm.db.profile.lua_line_numbers ~= false) then
            if self.RefreshLineNumbers then
                self:RefreshLineNumbers()
            else
                C:UpdateLineNumbers()
            end
        end

        local label = self.context.kind == 'condition' and L['Arguments from Test'] or L['Test arguments']
        if self.argumentLabel:GetText() ~= label then self.argumentLabel:SetText(label) end
        self:UpdateDebugAvailability()
        self.layingOut = nil
    end

    for _, control in ipairs({
        c.play,
        W.debugButton,
        engine.DebugUI.stopButton,
        c.knowledge,
        c.output,
        c.arguments,
    }) do
        control:SetFrameLevel(c.edit:GetFrameLevel() + 12)
    end

    input.changed = function(text)
        if c.released or not valid() then return end
        C.source = text
        C.lastError = nil
        engine.DebugUI:SourceChanged(text)
        W:Capture()
        C:UpdateLineNumbers()
        if not c.setting and changed then changed(text) end
    end

    function c:GetText()
        return input:GetText()
    end

    function c:SetText(text)
        if self.released then return end
        self.setting = true
        engine.Debugger:Stop()
        local readonly = input.readonly
        input.readonly = false
        E:SetSource(input, text or '', 0)
        input.readonly = readonly
        C.source = text or ''
        self.setting = false
    end

    function c:SetReadOnly(value)
        input.readonly = value == true

        if input.readonly then
            self.edit:ClearFocus()
            self.edit:Disable()
        else
            self.edit:Enable()
        end
    end

    function c:SetCloseHandler(callback)
        self.closeRequested = callback
    end

    function c:SetContext(context)
        self.context = context or {}
        local source = self.context.source or {}

        local signature = {
            kind = self.context.kind,
            id = self.context.id,
            callback = self.context.callback,
            args = source.args,
            returns = source.returns,
            bindings = source.bindings,
            fields = source.fields,
            parameters = source.parameters,
            revision = rm.functionRegistryVersion,
        }

        if rm:SettingsDataEqual(signature, self.contextSignature) then return end
        self.contextSignature = rm:CopySettingsData(signature)
        if rm.ApplyLuaContextSymbols then rm:ApplyLuaContextSymbols(engine, self.context, false) end
        W.current = self.context.id or 'RM'
        W.currentName = self.context.name or W.current

        local defaults = self.context.kind == 'condition'
            and self.context.callback == 'evaluate'
            and '{ {}, {}, GetTime() }'
            or '{}'

        self.arguments:SetText(defaults)
        W.db.snippets[W.current] = { name = W.currentName, source = self:GetText() }
        W.db.drafts[W.current] = { name = W.currentName, source = self:GetText() }
        self:Layout()
    end

    local pendingPaintElapsed = 0
    local attachMouseUp

    function c:Acquire(callback, ownerValid)
        if self.closing then error('editor-release-in-progress', 0) end
        changed, valid = callback, ownerValid
        self.changed, self.valid = callback, ownerValid
        if not self.released then return end
        self.layingOut = nil
        self.released = false
        self.readOnly = false
        input.readonly = false
        self.edit:Enable()

        if self.ResetInputTrace then
            rm.luaInputEditor = self
            self:ResetInputTrace()
        end

        self.layoutWidth, self.layoutHeight, self.executionReady = nil, nil, nil
        pendingPaintElapsed = 0
        self.edit:SetFont('Interface\\AddOns\\' .. addon_name .. '\\Fonts\\Inconsolata-Regular.ttf', 12, '')
        engine:Acquire()
        E:Attach(input)
        attachMouseUp()
        if self.RefreshLineNumbers then self:RefreshLineNumbers() end
        engine.APIHelp:Load()
        input.frame:Show()
        self.frame:Show()
        self:Layout()
    end

    function c:Release()
        if self.released then return end
        self.released = true
        self.closing = true
        self.changed = nil
        self.valid = inactive
        changed = nil
        valid = inactive
        self.closeRequested = nil
        self.showOwner = nil
        self.context = {}
        self.contextSignature = nil
        self.debugError = nil
        self.startArguments = nil
        local attempt, finish = cleanup()

        if self.ReleaseLineNumbers then
            attempt(self.ReleaseLineNumbers, self)
        else
            attempt(C.DetachLineNumbers, C)
        end

        attempt(engine.Release, engine)
        attempt(self.CloseDebugSurface, self)
        self.setting = true
        attempt(engine.ResetLease, engine)
        self.setting = false

        for key in pairs(self.environment) do
            self.environment[key] = nil
        end

        self.environment.addon = rm
        self.environment.L = L
        engine.embeddingOptions.parameterNames = nil
        attempt(self.arguments.SetText, self.arguments, '{}')
        attempt(self.status.SetText, self.status, '')

        if self.outputWindow then
            attempt(self.outputWindow.Hide, self.outputWindow)
            self.outputWindow.text = ''
            self.outputWindow.setting = true
            attempt(self.outputWindow.input.SetText, self.outputWindow.input, '')
            self.outputWindow.setting = false
            attempt(self.outputWindow.measure.SetText, self.outputWindow.measure, '')
        end

        attempt(frame.Hide, frame)
        self.closing = nil
        finish()
    end

    self:SetUIScript(c.edit, 'OnEscapePressed', function()
        if c.closeRequested then
            c.edit:ClearFocus()
            c.closeRequested(false)
        end
    end)

    self:SetUIScript(c.edit, 'OnKeyDown', function(_, key) W:RunShortcut(key) end)

    self:SetUIScript(c.edit, 'OnKeyUp', function(_, key)
        engine.DebugUI:KeyUp(key)
        engine.Navigation.held = nil
        W.f5Held = nil
    end)

    self:SetUIScript(c.edit, 'OnMouseDown', function(_, button)
        if button == 'RightButton' and c.closeRequested then
            c.edit:ClearFocus()
            c.closeRequested(true)
        end
    end)

    -- Layer ownership in attach order, then unwind gutter before editor on
    -- release. Toggling the gutter must restore the active editor handlers.
    E:Attach(input)
    self:SetUIScript(frame, 'OnSizeChanged', function() c:Layout() end)

    self:SetUIScript(frame, 'OnUpdate', function(_, elapsed)
        if c.released or not valid() then return end
        c:UpdateDebugAvailability()

        if c.RefreshLineNumbers and c.lineNumberSetting ~= (rm.db.profile.lua_line_numbers ~= false) then
            c:RefreshLineNumbers()
        end

        -- Upstream uses its caret clock to debounce painting. Native cursor
        -- notifications can reset that clock continuously while text is dirty.
        local state = input.queryEditor

        if state and state.pending then
            pendingPaintElapsed = pendingPaintElapsed + elapsed

            if pendingPaintElapsed >= .08 then
                pendingPaintElapsed = 0
                E:Paint(input)
            end
        else
            pendingPaintElapsed = 0
        end

        engine.DebugUI:HoverUpdate(elapsed)
    end)

    -- Hook the completed provider handler; later SetScript would erase it.
    if rm.InstallLuaLineNumberControl then
        rm:InstallLuaLineNumberControl(c, C, input)
        c:RefreshLineNumbers()
    else
        C:AttachLineNumbers(input)
    end

    self:SetUIScript(frame, 'OnHide', function()
        engine.Debugger:Stop()
        engine.Autocomplete:Hide()
        W:HidePanels()
        if c.outputWindow then c.outputWindow:Hide() end
    end)

    attachMouseUp = function()
        local mouseUp = c.edit:GetScript('OnMouseUp')

        rm:SetUIScript(c.edit, 'OnMouseUp', function(edit, button)
            if mouseUp then mouseUp(edit, button) end

            if
                not c.released
                and valid()
                and button == 'LeftButton'
                and IsControlKeyDown
                and IsControlKeyDown()
                and rm.NavigateLuaSymbol
            then
                rm:NavigateLuaSymbol(engine, input, c:GetText(), edit:GetCursorPosition())
            end
        end)
    end

    attachMouseUp()
    if self.InstallLuaInputDiagnostics then self:InstallLuaInputDiagnostics(c) end
    engine.APIHelp:Load()
    c:Layout()
    return c
end

function rm:IsLuaWorkbenchIntegrationAvailable()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if type(loaded) ~= 'function' then return false end
    local ok, value = pcall(loaded, '!!!LuaWorkbench')
    return ok and value == true and type(_G.LuaWorkbench) == 'table'
end

local ownedWorkbenchControl = rm.CreateLuaWorkbenchControl
local workbenchProvider

function rm:DiscoverLuaEditorIntegrations()
    if not self.RegisterLuaEditorProvider then return end

    if self:IsLuaWorkbenchIntegrationAvailable() then
        if not workbenchProvider then
            workbenchProvider = function(parent, changed, valid)
                if not self:IsLuaWorkbenchIntegrationAvailable() then return nil end
                local create = self.CreateLuaWorkbenchControl
                return create(self, parent, changed, valid), create == ownedWorkbenchControl and create or nil
            end
        end

        self:RegisterLuaEditorProvider('LuaWorkbench', workbenchProvider)
    end
end
