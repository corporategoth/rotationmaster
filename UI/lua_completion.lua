-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Completion, hover and navigation for RM's reduced Lua editor. addon:InstallRMCodeCompletion attaches a limited
-- LuaWorkbench engine ('RM-native', RM's own declared arguments, fields and functions only) to one native editor
-- control `c` made by UI/lua_editor.lua; it never loads Blizzard API docs and holds no event frame of its own.
-- It owns the engine, the editor-input shim and the script wrappers on c.edit, and removes them again in
-- c:ReleaseCompletion; it must not touch the user's LuaWorkbench workspace or saved state.
-- Loaded after Integrations/lua_workbench.lua (which supplies CreateLuaWorkbenchEngine) and before UI/lua_editor.lua
-- calls it; a no-op when that integration or Core/lua_symbols.lua is missing.

local _, addon = ...

-- The reduced editor uses the same released parser/completion component, but
-- only RM's declared arguments, fields and functions enter its knowledge index.
-- Called once while a native editor control `c` is built; adds c.UpdateSymbols, c.ReleaseCompletion,
-- c.AcquireCompletion and c.completionEngine to it. Returns nothing, and leaves `c` untouched when the LuaWorkbench
-- engine is unavailable.
function addon:InstallRMCodeCompletion(c)
    if not self.CreateLuaWorkbenchEngine or not self.ApplyLuaContextSymbols then
        return
    end

    local ok, engine = pcall(self.CreateLuaWorkbenchEngine, self, { id = 'RM-native', limited = true })

    if not ok or not engine then
        return
    end

    engine.APIHelp.index = {}
    engine.APIHelp.catalog = {}
    engine.APIHelp.ready = true
    function engine.APIHelp:Load() end

    -- Limited completion never loads Blizzard docs, including after combat.
    -- Its reusable editor therefore needs no persistent API-load event frame.
    if engine.APIHelp.events then
        engine.APIHelp.events:UnregisterAllEvents()
        engine.APIHelp.events:SetScript('OnEvent', nil)
    end

    local E, A = engine.Query.Editor, engine.Autocomplete

    local input = {
        frame = c.frame,
        editBox = c.edit,
        scrollFrame = c.scroll,
        queryEditor = { source = '', elapsed = 0 },
    }

    engine.Query.Console.input = input

    -- Source text the engine reads for this editor, taken from the control so it matches what the user sees.
    function input:GetText()
        return c:GetText()
    end

    -- Painting is replaced by a no-op: the native control already renders and colors the text, so the engine must not
    -- draw over it.
    function E:Paint() end

    -- Rebuilds the identifier and call spans the engine uses for hover hit-testing, from the control's hidden measuring
    -- string. Skips the work when the text is unchanged since the last call.
    local function updateHoverGeometry(text)
        local state = input.queryEditor

        if state.renderSource == text then
            return
        end

        state.renderSource = text
        state.overlay = c.measure
        state.renderSpans = {}
        state.hoverAreas = nil
        c.measure:ClearAllPoints()
        c.measure:SetPoint('TOPLEFT', c.edit, 'TOPLEFT', 6, -4)
        c.measure:SetHeight(c.measure:GetStringHeight())
        c.measure:SetAlpha(0)
        c.measure:Show()

        for _, token in ipairs(E:Tokenize(text)) do
            if token.kind == 'identifier' or token.kind == 'call' then
                state.renderSpans[#state.renderSpans + 1] = {
                    kind = token.kind,
                    text = token.text,
                    source = token.start,
                    first = token.start,
                    last = token.finish,
                }
            end
        end
    end

    -- Called by the engine when it rewrites the source (for example after accepting a completion). Writes it back to
    -- the control, restores the cursor and reports the change to the owner like a keystroke, unless the control is
    -- released or the owner says it is no longer valid.
    function E:SetSource(_, text, cursor)
        c:SetText(text)
        c.edit:SetCursorPosition(cursor or #text)
        input.queryEditor.source = text

        if not c.released and c.valid() and c.changed then
            c.changed(text)
        end
    end

    -- Autocomplete is live only for this editor while it is held, writable and the owner still considers itself valid.
    function A:Enabled(value)
        return value == input and not c.released and not c.readOnly and c.valid()
    end

    local originals = {}
    local attached = false

    -- Replaces the EditBox script for `event` with callback(original, ...), remembering the previous script (or false)
    -- so ReleaseCompletion can restore it exactly.
    local function wrap(event, callback)
        local original = c.edit:GetScript(event)
        originals[event] = original or false
        addon:SetUIScript(c.edit, event, function(...) return callback(original, ...) end)
    end

    -- Installs the key, mouse and update wrappers once per acquisition. Each wrapper lets autocomplete consume the
    -- event first and otherwise falls through to the control's own handler.
    local function attachedHandler()
        if attached then
            return
        end

        attached = true

        wrap('OnKeyDown', function(original, frame, key)
            if A:Enabled(input) and A:Key(input, key) then
                return
            end
            if original then
                return original(frame, key)
            end
        end)

        wrap('OnKeyUp', function(original, frame, key)
            A:RestoreCursor(input)
            A.keySource, A.keyCursor, A.arrowKey, A.arrowOrigin = nil, nil, nil, nil

            if original then
                return original(frame, key)
            end
        end)

        wrap('OnChar', function(original, frame, char)
            if A.keySource and char == ' ' then
                local source, cursor = A.keySource, A.keyCursor
                A.keySource, A.keyCursor = nil, nil

                if frame:GetText() == source:sub(1, cursor) .. char .. source:sub(cursor + 1) then
                    E:SetSource(input, source, cursor)
                    return
                end
            end

            if original then
                return original(frame, char)
            end
        end)

        wrap('OnArrowPressed', function(original, frame, key)
            if A:Enabled(input) and A:Arrow(input, key) then
                return true
            end
            if original then
                return original(frame, key)
            end
        end)

        wrap('OnTabPressed', function(original, frame)
            if A:Enabled(input) and A:Accept(input) then
                return
            end

            if original then
                original(frame)
            else
                frame:Insert('    ')
            end
        end)

        wrap('OnEnterPressed', function(original, frame)
            if A:Enabled(input) and A:Accept(input) then
                return true
            end
            if original then
                return original(frame)
            end

            if not c.readOnly then
                frame:Insert('\n')
            end
        end)

        wrap('OnEscapePressed', function(original, frame)
            if
                A.input == input and (A.panel and A.panel:IsShown() or A.signaturePanel and A.signaturePanel:IsShown())
            then
                A:Hide()
                return
            end

            if original then
                return original(frame)
            end
        end)

        wrap('OnUpdate', function(original, frame, elapsed)
            if original then
                original(frame, elapsed)
            end

            if c.context then
                engine.Query.Console.source = c:GetText()
                A:Tick(input, elapsed)
                updateHoverGeometry(c:GetText())
                engine.DebugUI:HoverUpdate(elapsed)
            end
        end)

        wrap('OnCursorChanged', function(original, frame, x, y, width, height)
            input.cursorX, input.cursorY = x, y

            if original then
                return original(frame, x, y, width, height)
            end
        end)

        wrap('OnMouseUp', function(original, frame, button)
            if original then
                original(frame, button)
            end
            if button == 'LeftButton' and IsControlKeyDown and IsControlKeyDown() then
                addon:NavigateLuaSymbol(engine, input, c:GetText(), frame:GetCursorPosition())
            end
        end)

        wrap('OnEditFocusLost', function(original, ...)
            A:Hide()

            if original then
                return original(...)
            end
        end)
    end

    -- Pushes the owner's context (kind, id, callback, args, returns, bindings, fields) into the engine. Does nothing
    -- when that signature and the function registry revision are unchanged.
    function c:UpdateSymbols(context)
        self.context = context
        local source = context and context.source or {}

        local signature = {
            kind = context and context.kind,
            id = context and context.id,
            callback = context and context.callback,
            args = source.args,
            returns = source.returns,
            bindings = source.bindings,
            fields = source.fields,
            parameters = source.parameters,
            revision = addon.functionRegistryVersion,
        }

        if addon:SettingsDataEqual(signature, self.symbolSignature) then
            return
        end

        self.symbolSignature = addon:CopySettingsData(signature)
        engine.Workspace.current = context and context.id or 'RM-native'
        addon:ApplyLuaContextSymbols(engine, context, true)
    end

    -- Detaches the engine from the control: hides popups, restores every wrapped script and resets the engine lease.
    -- Every step runs even if an earlier one fails; the first failure is raised at the end.
    function c:ReleaseCompletion()
        self.context = nil
        self.symbolSignature = nil
        local failed, why

        local function attempt(callback, ...)
            local ok, result = pcall(callback, ...)

            if not ok and not failed then
                failed, why = true, result
            end
        end

        attempt(A.Hide, A)
        attempt(engine.DebugUI.HideTooltip, engine.DebugUI, nil, 'owner-closed')
        local scripts = originals
        originals = {}
        attached = false

        for event, script in pairs(scripts) do
            attempt(addon.SetUIScript, addon, self.edit, event, script or nil)
        end

        attempt(engine.ResetLease, engine)

        if failed then
            error(why, 0)
        end
    end

    -- Takes the engine lease again and reattaches the wrappers; used on first install and when a released editor is
    -- reused.
    function c:AcquireCompletion()
        engine:Acquire()
        attachedHandler()

        if self.context then
            self:UpdateSymbols(self.context)
        end
    end

    c.completionEngine = engine
    c:AcquireCompletion()
end
