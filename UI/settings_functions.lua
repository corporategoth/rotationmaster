-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Settings > Functions page: the roster of Built In helper functions and custom functions with its New, Duplicate,
-- Import/Export and Compare actions, plus the helpers that name, find and open a function source. It builds the left
-- roster and delegates the editor to UI/function_source_pane.lua; it never saves a function itself.
-- Loaded from RotationMaster.toc after UI/settings_conditions.lua and before UI/function_bindings.lua. Custom functions
-- live in addon.db.global.custom_functions (saved data); Built In ones come from addon.builtinFunctions and are
-- read-only. Value-binding helpers are not functions to the user and are always left out of the roster.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Function sources and names
-- ============================================================================

-- Returns a fresh source for a new custom function (name, namespace, empty arguments and `return nil` code).
-- @return table  The new function source.
function addon:NewFunctionSource()
    return {
        name = 'newFunction',
        namespace = 'custom',
        description = L['Describe what this function does.'],
        args = {},
        returns = {},
        code = 'return nil',
        bindings = {},
    }
end

-- Restricts a function name edit box to identifier characters: typed text is stripped to letters, digits and
-- underscores with no leading digit, and the cursor is kept at the same logical place. The box's previous change
-- handler still runs afterwards.
-- @param form table  The settings form; supplies the Guard that drops events from a stale drawing.
-- @param input table  The edit box.
function addon:ConfigureFunctionNameInput(form, input)
    input:SetMaxLetters(128)
    local changed = input:GetScript('OnTextChanged')

    -- Filters typed text to identifier characters (keeping the cursor at the same logical place), then runs the box's
    -- previous change handler.
    -- @param control table  The edit box.
    -- @param user boolean  True when the change came from typing.
    self:SetUIScript(input, 'OnTextChanged', form:Guard(function(control, user)
        if user then
            local text = control:GetText()
            local cursor = control:GetCursorPosition()
            local filtered = text:gsub('[^A-Za-z_0-9]', ''):gsub('^%d+', '')

            if filtered ~= text then
                local before = text:sub(1, cursor):gsub('[^A-Za-z_0-9]', ''):gsub('^%d+', '')
                control:SetText(filtered)
                control:SetCursorPosition(#before)
            end
        end

        if changed then
            changed(control, user)
        end
    end))
end

-- Returns an unused name for a copy of a function: its editor name with `_copy` (shortened to leave room), then
-- `_copy2`, `_copy3` and so on until no existing function uses it.
-- @param id string  The function id.
-- @param source table  The function source.
-- @return string  The unused name.
function addon:DuplicateFunctionName(id, source)
    local base = self:FunctionEditorName(id, source):sub(1, 116) .. '_copy'
    local name = base
    local n = 2
    local used = {}

    for key, value in pairs(self.db.global.custom_functions or {}) do
        used[self:FunctionEditorName(key, value)] = true
    end

    while used[name] do
        name = base .. n
        n = n + 1
    end

    return name
end

-- Returns the source table for a function and whether it is read-only (a Built In). A value binding is not a function
-- to the user, so it counts as unknown.
-- @param id string  The function id.
-- @return table|nil  The source; nil when `id` is unknown or is a value binding.
-- @return boolean|nil  True for a Built In (read-only), false for a custom function; nil when the first value is nil.
function addon:FunctionSource(id)
    local custom = (self.db.global.custom_functions or {})[id]

    if custom then
        return custom, false
    end

    local builtin = (self.builtinFunctions or {})[id]

    if builtin and not builtin.valueBinding then
        return builtin.source, true
    end
end

-- Starts a new custom function in the pane under a new generated id, after any unapplied edits have been resolved.
-- @param p table  The settings pane.
-- @param source table|nil  A source to copy; nil uses the blank template.
function addon:OpenNewFunction(p, source)
    p:RequestLeave(function()
        if not p.active then
            return
        end

        p.functionID = nil
        p.newFunctionID = 'FUNCTION_' .. self:uuid():gsub('-', '_')
        p.newFunctionSource = self:CopySettingsData(source or self:NewFunctionSource())
        p.functionSource = 'custom'
        p.functionNamespaceFilter = '*'
        p:Draw()
    end)
end

-- Opens the settings window on the Functions page with a function selected (used by the go-to-definition links). With a
-- pane open, the jump waits for navigation to be approved, so a cancelled jump changes nothing.
-- @param id string  The function id.
-- @return table|nil  The settings window; nil when `id` is unknown.
function addon:ShowFunctionSource(id)
    local source = self:FunctionSource(id)

    if not source then
        return
    end

    local shell = self.configWindow
    local pane = shell and shell.pane

    if pane and pane.RequestLeave then
        -- Queue the selection only after navigation is approved. A cancelled
        -- symbol jump must not silently take effect during a later resize.
        pane:RequestLeave(function()
            self.configFunctionSelection = id
            self:ShowConfig('Functions')
        end)

        return shell
    end

    self.configFunctionSelection = id
    return self:ShowConfig('Functions')
end

-- Returns the sorted list of namespaces in use by Built In and custom functions.
-- @return table[]  The namespaces, each { value = name, text = name }.
function addon:FunctionNamespaces()
    local names = {}

    for id, record in pairs(self.builtinFunctions or {}) do
        if not record.valueBinding then
            names[self:FunctionNamespace(id, record.source)] = true
        end
    end

    for id, value in pairs(self.db.global.custom_functions or {}) do
        names[self:FunctionNamespace(id, value)] = true
    end

    local ordered = {}

    for name in pairs(names) do
        ordered[#ordered + 1] = name
    end

    table.sort(ordered)
    local entries = {}

    for _, name in ipairs(ordered) do
        entries[#entries + 1] = { value = name, text = name }
    end

    return entries
end

-- ============================================================================
-- The Functions page
-- ============================================================================

-- Draws the Functions page into the settings pane: the filtered, sorted roster, the roster actions and the inline
-- editor for the selected (or newly created) function. Runs on every redraw, so it reads the current registry and saved
-- functions each time and keeps the selection in pane fields (functionID, newFunctionSource and the filters).
-- @param p table  The settings pane.
-- @return any  What the inline function editor builder returns; nothing when no function is shown.
function addon:BuildFunctionSettings(p)
    self:InstallInlineFunctionNavigation(p)

    -- A pending jump from ShowFunctionSource: select that function, widen the filters so it is visible, and consume it.
    if self.configFunctionSelection then
        p.functionID = self.configFunctionSelection
        p.functionSource = 'all'
        p.functionNamespaceFilter = '*'
        p.newFunctionID = nil
        p.newFunctionSource = nil
        self.configFunctionSelection = nil
    end

    local custom = self.db.global.custom_functions or {}
    local entries = {}
    local selected
    local namespaceSet = {}
    local namespaces = { { value = '*', text = L['All namespaces'] } }

    for _, entry in ipairs(self:FunctionNamespaces()) do
        namespaceSet[entry.value] = true
        namespaces[#namespaces + 1] = entry
    end

    p.functionNamespaceFilter = p.functionNamespaceFilter or '*'

    if p.functionNamespaceFilter ~= '*' and not namespaceSet[p.functionNamespaceFilter] then
        p.functionNamespaceFilter = '*'
    end

    -- Adds a roster entry for a function unless the source or namespace filter hides it; an entry whose function is
    -- unavailable is marked invalid with the reason.
    -- @param id string  The function id.
    -- @param source table  The function source.
    -- @param builtin boolean  True for a Built In function.
    local function add(id, source, builtin)
        if p.functionSource == 'builtin' and not builtin or p.functionSource == 'custom' and builtin then
            return
        end
        if p.functionNamespaceFilter ~= '*' and self:FunctionNamespace(id, source) ~= p.functionNamespaceFilter then
            return
        end

        local available, why = self:FunctionAvailable(id)

        entries[#entries + 1] = {
            value = id,
            text = self:FunctionQualifiedName(id, source),
            search = id .. ' ' .. self:FunctionQualifiedName(id, source) .. ' ' .. (source.description or ''),
            custom = not builtin,
            invalid = not available,
            disabled = source.disabled == true,
            validationMessage = not available and string.format(L['Function unavailable: %s'], why) or nil,
        }

        if p.functionID == id then
            selected = true
        end
    end

    p.functionSource = p.functionSource or 'all'

    for id, record in pairs(self.builtinFunctions or {}) do
        if not record.valueBinding then
            add(id, record.source, true)
        end
    end

    for id, source in pairs(custom) do
        add(id, source, false)
    end

    table.sort(entries, function(a, b)
        if a.text == b.text then
            return a.value < b.value
        end

        return a.text < b.text
    end)

    if not selected and not p.newFunctionSource then
        p.functionID = entries[1] and entries[1].value
    end

    p:UseRoster(
        entries,
        p.functionID,
        function(id)
            p:RequestLeave(function()
                p.functionID = id
                p.newFunctionSource = nil
                p.newFunctionID = nil
                p:Draw()
            end)
        end,
        {
            newText = L['New'],
            new = function()
                self:OpenNewFunction(p)
            end,
            categories = namespaces,
            category = p.functionNamespaceFilter,
            chooseCategory = function(value)
                p:RequestLeave(function()
                    p.functionNamespaceFilter = value
                    p.functionID = nil
                    p.newFunctionSource = nil
                    p.newFunctionID = nil
                    p:Draw()
                end)
            end,
            sources = {
                { value = 'all', text = L['All'] },
                { value = 'builtin', text = L['Built In'] },
                { value = 'custom', text = L['Custom'] },
            },
            source = p.functionSource,
            chooseSource = function(value)
                p:RequestLeave(function()
                    p.functionSource = value
                    p.functionID = nil
                    p.newFunctionSource = nil
                    p.newFunctionID = nil
                    p:Draw()
                end)
            end,
        }
    )

    local source, readOnly = self:FunctionSource(p.functionID)
    local comparisons = {}

    for id, record in pairs(self.builtinFunctions or {}) do
        if id ~= p.functionID and not record.valueBinding then
            comparisons[#comparisons + 1] = { value = id, text = self:FunctionQualifiedName(id, record.source) }
        end
    end

    for id, value in pairs(custom) do
        if id ~= p.functionID then
            comparisons[#comparisons + 1] = { value = id, text = self:FunctionQualifiedName(id, value) }
        end
    end

    table.sort(comparisons, function(a, b)
        if a.text == b.text then
            return a.value < b.value
        end

        return a.text < b.text
    end)

    p:SetRosterActions({
        { key = 'new_function', text = L['New'], icon = 'plus', action = p.roster.options.new },
        {
            key = 'duplicate_function',
            text = L['Duplicate'],
            icon = 'copy',
            enabled = source ~= nil,
            action = function()
                local copy = self:CopySettingsData(source)
                copy.name = self:DuplicateFunctionName(p.functionID, copy)
                self:OpenNewFunction(p, copy)
            end,
        },
        {
            key = 'transfer',
            text = L['Import/Export'],
            icon = 'transfer',
            action = function()
                if self.ShowFunctionBundleTransfer then
                    self:ShowFunctionBundleTransfer(
                        p,
                        p.functionID,
                        p.inlineFunction and p.inlineFunction:PendingSource() or source
                    )
                end
            end,
        },
        {
            key = 'compare',
            text = L['Compare'],
            icon = 'compare',
            enabled = source ~= nil and #comparisons > 0,
            -- Opens a menu of the other functions to compare the selected one with and shows the comparison window for
            -- the choice.
            action = function()
                local selected = p.functionID

                p:ShowChoices(p.fields.compare, comparisons, function(id)
                    local other = self:FunctionSource(id)

                    if id ~= selected and source and other then
                        self:ShowCollectionComparison(
                            p,
                            'profile',
                            { name = source.name or selected, profile = source },
                            { name = other.name or id, profile = other }
                        )
                    end
                end)
            end,
        },
    })

    if p.newFunctionSource or source then
        return self:BuildInlineFunction(
            p,
            p.newFunctionID or p.functionID,
            p.newFunctionSource or source,
            readOnly and not p.newFunctionSource
        )
    end

    p:Text(L['Add a function or duplicate a packaged helper to edit its source.'])
end
