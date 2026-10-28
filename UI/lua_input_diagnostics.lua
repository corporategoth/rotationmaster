-- Input diagnostics for the Lua code editor control: a rolling trace of edit box events (cursor, text, focus, mouse)
-- and a plain-text report of the control's frames, focus owners, line-number gutter and LuaWorkbench overlay state,
-- shown through `/rm debug editor` (Diagnostics/glow.lua). It must never include source text: reports carry counts and
-- byte lengths only. Every client query goes through `read` so a missing or failing method reads as 'unavailable'
-- instead of raising. The control is attached by UI/lua_editor.lua and Integrations/lua_workbench.lua, which call
-- `InstallLuaInputDiagnostics` when it exists; this file loads just before them (after UI/lua_input_probe.lua) and
-- shows a report through `addon:ShowConditionText`.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Report helpers
-- ============================================================================

-- Calls `object:method()` under pcall and returns the result as a string.
-- @param object table|nil  The object to ask.
-- @param method string  The method name.
-- @return string  The result as text, or 'unavailable' when the object or method is missing, the call fails, or the
--   result is not a string, number or boolean (so a secret or userdata value never leaks into a report).
local function read(object, method)
    if not object or type(object[method]) ~= 'function' then
        return 'unavailable'
    end

    local ok, value = pcall(object[method], object)

    if not ok or type(value) ~= 'string' and type(value) ~= 'number' and type(value) ~= 'boolean' then
        return 'unavailable'
    end

    return tostring(value)
end

-- Names what a focused frame is in the editor's terms (code EditBox, ScrollFrame, container, none), or else walks up to
-- 12 parents so an unexpected focus owner can be identified from the report.
-- @param frame table|nil  The focused frame.
-- @param control table  The Lua editor control.
-- @return string  The role, or a "Type[name] > ..." path.
local function focusRole(frame, control)
    if frame == control.edit then
        return 'code EditBox'
    end
    if frame == control.scroll then
        return 'code ScrollFrame'
    end
    if frame == control.frame then
        return 'code container'
    end
    if not frame then
        return 'none'
    end

    local path = {}

    for _ = 1, 12 do
        path[#path + 1] = read(frame, 'GetObjectType') .. '[' .. read(frame, 'GetName') .. ']'

        if frame == control.frame then
            path[#path + 1] = 'code container'
            break
        end

        if type(frame.GetParent) ~= 'function' then
            break
        end

        frame = frame:GetParent()

        if not frame then
            break
        end
    end

    return table.concat(path, ' > ')
end

-- True when `code` is `control` or wraps it through the `.inner` chain (bounded at 8 levels, cycle-safe).
-- @param code any  The candidate wrapper.
-- @param control table  The control to look for.
-- @return boolean  True when it is the control or wraps it.
local function ownsControl(code, control)
    local seen = {}

    for _ = 1, 8 do
        if code == control then
            return true
        end
        if type(code) ~= 'table' or seen[code] then
            return false
        end

        seen[code] = true
        code = code.inner
    end

    return false
end

-- Finds which source editor (inline function, inline condition, custom condition dialog or Test owner) hosts `control`.
-- Falls back to a closed owner so the report can still say which editor the trace came from.
-- @param addon table  The addon.
-- @param control table  The Lua editor control.
-- @return table|nil  The owner; nil when none is found.
-- @return string|nil  The kind: 'function' or 'condition'.
-- @return boolean  True when it is an open owner that really holds the control.
local function sourceOwner(addon, control)
    local shell = addon.configWindow
    local pane = shell and shell.pane
    local candidates = {}

    -- Adds a candidate source editor owner of the given kind, ignoring a missing one.
    -- @param owner table|nil  The candidate.
    -- @param kind string  'function' or 'condition'.
    local function add(owner, kind)
        if owner then
            candidates[#candidates + 1] = { owner = owner, kind = kind }
        end
    end

    if pane then
        add(pane.inlineFunction, 'function')
        add(pane.inlineCondition, 'condition')
    end

    add(addon.nativeCustomConditionDialog, 'condition')

    if not shell then
        add(control.context and control.context.testOwner, 'condition')
    end

    local historical, fallback

    for _, entry in ipairs(candidates) do
        local owner = entry.owner
        local matches = ownsControl(owner.code, control)

        if matches and not owner.closed then
            return owner, entry.kind, true
        end

        if owner.closed then
            fallback = fallback or entry

            if matches then
                historical = historical or entry
            end
        end
    end

    local entry = historical or fallback

    if entry then
        return entry.owner, entry.kind, false
    end

    return nil, nil, false
end

-- ============================================================================
-- Input trace
-- ============================================================================

-- Attaches the input trace to a Lua editor control and remembers it as the one the report describes. Reports contain
-- counts, never source. Keep explicit diagnostic commands available without adding temporary test controls to the
-- editor chrome.
-- @param control table  The Lua editor control.
function addon:InstallLuaInputDiagnostics(control)
    self.luaInputEditor = control

    -- Clears the trace and every counter this file keeps on the control.
    function control:ResetInputTrace()
        self.inputTrace = {}
        self.inputCounts = {}
        self.inputPoll = nil
        self.layoutCounts = nil
        self.lineNumberCounts = nil
    end

    -- Appends one event to the 32-entry trace with the cursor, byte length and focus state. Consecutive identical polls
    -- are collapsed so the trace shows changes, not time passing. Records only key names, never typed text.
    -- @param event string  The event name, or 'poll'.
    -- @param ... any  The event's arguments.
    function control:ObserveInput(event, ...)
        if self.released then
            return
        end

        local edit = self.edit
        local raw = self.nativeGetText or edit.GetText
        local ok, value = pcall(raw, edit)
        local bytes = ok and type(value) == 'string' and #value or -1

        local state = 'cursor=' .. read(edit, 'GetCursorPosition') .. ' bytes=' .. bytes .. ' focus=' .. read(
            edit,
            'HasFocus'
        )

        if event == 'poll' and state == self.inputPoll then
            return
        end

        self.inputPoll = state
        self.inputCounts[event] = (self.inputCounts[event] or 0) + 1
        local detail = ''

        if event == 'OnCursorChanged' then
            local values = { ... }
            local coords = {}

            for i = 1, 4 do
                coords[i] = type(values[i]) == 'number' and string.format('%.2f', values[i]) or '?'
            end

            detail = ' rect=' .. table.concat(coords, ',')
        elseif event == 'OnTextChanged' then
            detail = ' user=' .. tostring((...))
        elseif event == 'OnMouseDown' or event == 'OnMouseUp' or event == 'OnArrowPressed' then
            local value = (...)

            if type(value) == 'string' and value:match('^[A-Za-z]+$') then
                detail = ' key=' .. value
            end
        end

        self.inputTrace[#self.inputTrace + 1] = event .. ' ' .. state .. detail

        if #self.inputTrace > 32 then
            table.remove(self.inputTrace, 1)
        end
    end

    control:ResetInputTrace()

    for _, event in ipairs({
        'OnMouseDown',
        'OnMouseUp',
        'OnTextSet',
        'OnTextChanged',
        'OnCursorChanged',
        'OnEditFocusGained',
        'OnEditFocusLost',
        'OnArrowPressed',
    }) do
        control.edit:HookScript(event, function(_, ...)
            control:ObserveInput(event, ...)
        end)
    end

    control.frame:HookScript('OnUpdate', function()
        control:ObserveInput('poll')
    end)
end

-- ============================================================================
-- Report
-- ============================================================================

-- Builds the multi-line diagnostics report for the most recent Lua editor control (open or closed): frame state, who
-- has mouse and keyboard focus, layout and gutter counters, the LuaWorkbench render state when that provider is in use,
-- the event counts and the trace. Contains no source text.
-- @return string  The report text, or a notice when no editor was opened this session.
function addon:LuaEditorInputReport()
    local control = self.luaInputEditor

    if not control then
        return L['No native Lua editor has been opened this session.']
    end

    local edit = control.edit

    local lines = {
        'Rotation Master native input diagnostics',
        'state='
            .. (control.released and 'closed' or 'open')
            .. ' provider='
            .. tostring(control.provider or 'native')
            .. ' highlighting='
            .. tostring(control.provider == 'LuaWorkbench' or control.syntax ~= nil),
        'cursor=' .. read(edit, 'GetCursorPosition') .. ' focus=' .. read(edit, 'HasFocus'),
        'enabled=' .. read(edit, 'IsEnabled') .. ' keyboard=' .. read(edit, 'IsKeyboardEnabled') .. ' mouse=' .. read(
            edit,
            'IsMouseEnabled'
        ),
        'arrowsRequireAlt=' .. read(edit, 'GetAltArrowKeyMode') .. ' blink=' .. read(edit, 'GetBlinkSpeed'),
        'width=' .. read(edit, 'GetWidth') .. ' height=' .. read(edit, 'GetHeight') .. ' alpha=' .. read(
            edit,
            'GetAlpha'
        ),
        'font=' .. read(edit, 'GetFont') .. ' scroll=' .. read(control.scroll, 'GetVerticalScroll'),
    }

    local mouse, keyboard

    if type(GetMouseFoci) == 'function' then
        local ok, list = pcall(GetMouseFoci)

        if ok and type(list) == 'table' then
            mouse = list[1]
        end
    elseif type(GetMouseFocus) == 'function' then
        local ok, value = pcall(GetMouseFocus)

        if ok then
            mouse = value
        end
    end

    if type(GetCurrentKeyBoardFocus) == 'function' then
        local ok, value = pcall(GetCurrentKeyBoardFocus)

        if ok then
            keyboard = value
        end
    end

    lines[#lines + 1] = 'mouseFocus=' .. focusRole(mouse, control)
    lines[#lines + 1] = 'keyboardFocus=' .. focusRole(keyboard, control)

    lines[#lines + 1] = 'code visible='
        .. read(control.frame, 'IsVisible')
        .. ' shown='
        .. read(control.frame, 'IsShown')
        .. ' edit visible='
        .. read(edit, 'IsVisible')

    local owner, kind, matches = sourceOwner(self, control)

    lines[#lines + 1] = 'matches source editor='
        .. tostring(matches)
        .. ' session='
        .. tostring(owner and owner.session or 'none')
        .. ' source editor='
        .. (owner and (owner.closed and 'closed' or 'active') or 'none')
        .. ' source kind='
        .. (kind or 'none')

    if control.released then
        lines[#lines + 1] = 'Closed editor: historical trace; reopen the editor to capture active input.'
    end

    if control.provider == 'LuaWorkbench' then
        lines[#lines + 1] = 'native layout counters=unavailable (LuaWorkbench overlay)'
    else
        local layout = control.layoutCounts or {}

        lines[#lines + 1] = 'layout calls='
            .. tostring(layout.calls or 0)
            .. ' skips='
            .. tostring(layout.skips or 0)
            .. ' editWidthWrites='
            .. tostring(layout.width or 0)
            .. ' contentSizeWrites='
            .. tostring(layout.content or 0)

        local origins = {}

        for _, name in ipairs({ 'set-text', 'text-changed', 'owner-size', 'line-number-setting', 'direct' }) do
            origins[#origins + 1] = name .. '=' .. tostring(layout.origins and layout.origins[name] or 0)
        end

        lines[#lines + 1] = 'layout origins=' .. table.concat(origins, ' ')

        if layout.ownerWidth then
            lines[#lines + 1] = 'last owner-size=' .. tostring(layout.ownerWidth) .. 'x' .. tostring(layout.ownerHeight)
        end
    end

    lines[#lines + 1] = 'arrowHook=' .. tostring(type(edit:GetScript('OnArrowPressed')) == 'function')

    lines[#lines + 1] = 'lineNumbers visible=' .. tostring(control.lineNumbersVisible) .. ' setting=' .. tostring(
        control.lineNumberSetting
    )

    local input = control.lineNumberInput
    local queue = control.lineNumberQueue
    local engine = control.engine or control.completionEngine
    local console = engine and engine.Query and engine.Query.Console
    lines[#lines + 1] = 'gutter queue=deferred pending=' .. tostring(queue ~= nil and queue.pending == true)

    lines[#lines + 1] = 'gutter attachment present='
        .. tostring(queue ~= nil)
        .. ' updaterMatch='
        .. tostring(queue ~= nil and console ~= nil and console.UpdateLineNumbers == queue.update)
        .. ' inputMatch='
        .. tostring(console ~= nil and console.input == input)
        .. ' editMatch='
        .. tostring(queue ~= nil and queue.edit == edit)
        .. ' stateMatch='
        .. tostring(queue ~= nil and queue.state ~= nil and input ~= nil and queue.state == input.queryLineNumbers)

    if control.provider == 'LuaWorkbench' then
        local painted = input and input.queryEditor
        local source
        local ok, value = pcall(control.nativeGetText or edit.GetText, edit)

        if ok and type(value) == 'string' then
            source = value
        end

        -- Returns the byte length of a string, or -1 when the value is not a string (never the text itself).
        -- @param value any  The value to measure.
        -- @return number  The length in bytes, or -1.
        local function bytes(value)
            return type(value) == 'string' and #value or -1
        end

        local overlay = painted and painted.overlay
        local overlayText

        if overlay and type(overlay.GetText) == 'function' then
            local success, text = pcall(overlay.GetText, overlay)

            if success then
                overlayText = text
            end
        end

        lines[#lines + 1] = 'provider render attached='
            .. tostring(painted ~= nil)
            .. ' pending='
            .. tostring(painted ~= nil and painted.pending == true)
            .. ' sourceBytes='
            .. bytes(source)
            .. ' renderBytes='
            .. bytes(painted and painted.renderSource)
            .. ' sourceMatch='
            .. tostring(source ~= nil and painted ~= nil and painted.renderSource == source)
            .. ' renderedBytes='
            .. bytes(painted and painted.renderedText)
            .. ' nativeText='
            .. tostring(painted and painted.nativeText == true)

        lines[#lines + 1] = 'overlay shown='
            .. read(overlay, 'IsShown')
            .. ' visible='
            .. read(overlay, 'IsVisible')
            .. ' alpha='
            .. read(overlay, 'GetAlpha')
            .. ' bytes='
            .. bytes(overlayText)
            .. ' width='
            .. read(overlay, 'GetWidth')
            .. ' height='
            .. read(overlay, 'GetHeight')
    end

    local gutter = control.lineNumberCounts

    if gutter then
        lines[#lines + 1] = 'gutter calls='
            .. gutter.calls
            .. ' flushes='
            .. gutter.flushes
            .. ' skips='
            .. gutter.skips
            .. ' renders='
            .. gutter.renders
            .. ' metricRebuilds='
            .. gutter.metrics
            .. ' reentries='
            .. gutter.reentries
            .. ' errors='
            .. gutter.errors
            .. ' detached='
            .. gutter.detached

        lines[#lines + 1] = 'gutter last render keys=' .. (gutter.lastRender or 'none')
        lines[#lines + 1] = 'gutter last metric keys=' .. (gutter.lastMetric or 'none')
    else
        lines[#lines + 1] = 'gutter counters=unavailable'
    end

    local state = input and (input.queryLineNumbers or input.queryLineNumberCache)

    -- Appends one line of size, scale, level, mouse and bounds for a gutter-related frame (all values read through
    -- `read`).
    -- @param label string  The frame's label in the report.
    -- @param frame table|nil  The frame.
    local function frameInfo(label, frame)
        lines[#lines + 1] = 'gutter '
            .. label
            .. ' width='
            .. read(frame, 'GetWidth')
            .. ' height='
            .. read(frame, 'GetHeight')
            .. ' scale='
            .. read(frame, 'GetEffectiveScale')
            .. ' level='
            .. read(frame, 'GetFrameLevel')
            .. ' mouse='
            .. read(frame, 'IsMouseEnabled')
            .. ' bounds='
            .. read(frame, 'GetLeft')
            .. ','
            .. read(frame, 'GetRight')
            .. ','
            .. read(frame, 'GetTop')
            .. ','
            .. read(frame, 'GetBottom')
    end

    -- Returns the result of `frame:method()`.
    -- @param frame table|nil  The frame.
    -- @param method string  The method name.
    -- @return any  The result; nil when the method is missing or fails.
    local function object(frame, method)
        if not frame or type(frame[method]) ~= 'function' then
            return nil
        end

        local ok, value = pcall(frame[method], frame)

        if ok then
            return value
        end
    end

    frameInfo('frame', state and state.gutter)
    frameInfo('container', control.frame)
    frameInfo('edit', edit)
    frameInfo('scroll', control.scroll)
    frameInfo('child', object(control.scroll, 'GetScrollChild'))
    frameInfo('edit parent', object(edit, 'GetParent'))
    local counts = {}

    for event, count in pairs(control.inputCounts) do
        counts[#counts + 1] = event .. '=' .. count
    end

    table.sort(counts)
    lines[#lines + 1] = table.concat(counts, ' ')

    for _, entry in ipairs(control.inputTrace) do
        lines[#lines + 1] = entry
    end

    return table.concat(lines, '\n')
end

-- Opens the report in the selectable text window so a tester can copy it.
function addon:ShowLuaEditorInputReport()
    self:ShowConditionText(self:LuaEditorInputReport(), L['Lua input diagnostics'])
end
