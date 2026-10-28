-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Function dependencies ("bindings") for the custom condition editor and the custom function editor: the alias-to-
-- function-id map a source saves in `source.bindings`, the toolbar button and rows that edit it, and the undo entries a
-- code-completion binding leaves in the editor history. Validation and storage are in Core/functions.lua; this file
-- never writes saved data directly, it goes through owner.model:Change or the owner's working copy. Used by
-- UI/custom_condition_editor.lua and UI/function_source_pane.lua. Loaded from RotationMaster.toc after
-- UI/settings_functions.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Naming and completion
-- ============================================================================

-- Returns the call text for function `id` (for example `functions.double(value)`), built from `source.args`.
-- @param id string  The function ID.
-- @param source table  The function source; source.args lists its arguments.
-- @param original boolean|nil  True makes a Built In method keep its own `addon:Name(...)` form instead of the
--   dependency-qualified one.
-- @return string  The call text.
--
-- IDs remain explicit even when two modules capture the same local name.
function addon:FunctionInvocation(id, source, original)
    local builtin = self.builtinFunctions and self.builtinFunctions[id]
    local callable = original and builtin and builtin.callName or self:FunctionQualifiedName(id, source)
    local args = {}

    for index, arg in ipairs(source.args or {}) do
        if not (index == 1 and arg.name == 'self' and callable:find(':', 1, true)) then
            args[#args + 1] = builtin
                and index == 1
                and arg.name == 'self'
                and (builtin.callName and builtin.callName:match('^(.*):[^:]+$') or 'addon')
                or arg.name
        end
    end

    return callable .. '(' .. table.concat(args, ', ') .. ')'
end

-- Starts binding function `id` under `alias` for the editor `owner`. The caller inserts the completion text, then calls
-- transaction:commit() (records an undo entry) or transaction:rollback() (restores the previous bindings and code). The
-- transaction goes stale if the editor session changes, and then rolls itself back.
-- @param owner table  The custom condition or function editor.
-- @param id string  The function ID to bind.
-- @param alias string  The name the code will use for it.
-- @return table|boolean  A transaction { commit(), rollback() }; false (after showing the reason in the form) when the
--   editor is read-only, busy or the alias conflicts.
--
-- Completion adds a stable dependency only after the user accepts a suggestion. Source insertion then updates
-- actions/context; avoid re-entering completion here.
function addon:BindEditorFunction(owner, id, alias)
    -- Shows `reason` in the form and returns false, the uniform failure result of this function.
    -- @param reason string  The reason code.
    -- @return boolean  Always false.
    local function reject(reason)
        if owner.form and owner.form.Message then
            owner.form:Message(string.format(L['Function unavailable: %s'], reason))
        end

        return false
    end

    if
        owner.readOnly
        or owner.pendingFunctionBinding
        or not owner.OwnerValid
        or not owner.OwnerValid()
        or owner.key == id and not owner.model
    then
        return reject('unavailable-editor')
    end

    local source = owner.model and owner.model.value or owner.value

    if not source then
        return reject('function-binding-conflict')
    end

    local arguments = source.args or {
        { name = 'value' },
        { name = 'cache' },
        { name = 'evalStart' },
        { name = 'spec' },
        { name = 'parent' },
        { name = 'frame' },
        { name = 'tag' },
    }

    local bindings = self:CopySettingsData(source.bindings or {})

    if bindings[alias] and bindings[alias] ~= id then
        return reject('function-binding-conflict')
    end

    bindings[alias] = id

    if not self:NormalizeFunctionBindings(bindings, arguments) then
        return reject('invalid-function-bindings')
    end

    local available, why = self:FunctionAvailable(id)

    if not available then
        return reject(why or 'missing-function')
    end

    local before = source.bindings
    local previous = before and before[alias]
    local text = owner.code:GetText()
    local session = owner.session
    local transaction = {}
    owner.pendingFunctionBinding = transaction
    source.bindings = bindings

    -- True while this transaction is still the editor's current one in the same session.
    -- @return boolean|nil  Truthy while the transaction may still act.
    local function valid()
        return owner.session == session
            and owner.OwnerValid
            and owner.OwnerValid()
            and owner.pendingFunctionBinding == transaction
    end

    -- Restores the bindings saved before the call and puts the code text back; idempotent.
    function transaction:rollback()
        if self.finished then
            return
        end

        self.finished = true
        source.bindings = before
        local current = valid()

        if owner.pendingFunctionBinding == transaction then
            owner.pendingFunctionBinding = nil
        end

        if current then
            owner:SetCode(text)
            owner:UpdateActions()
        end
    end

    -- Pushes a 'function-completion' undo entry (bounded to 100 entries, and 4 MiB of text for model-backed editors)
    -- and keeps the new binding.
    -- @return boolean  True when kept; false (after rolling back) if the editor changed meanwhile, or when the
    --   transaction already finished.
    function transaction:commit()
        if self.finished then
            return false
        end

        if not valid() then
            self:rollback()
            return false
        end

        local entry = {
            kind = 'function-completion',
            text = text,
            alias = alias,
            binding = previous,
            bindingsMissing = before == nil,
            modelDepth = owner.model and #owner.model.undo or 0,
        }

        local state = owner.model and owner:CodeState() or owner
        state.undo[#state.undo + 1] = entry
        state.redo = {}

        -- Byte size of an undo entry: a code-completion entry carries its text, a plain entry is the text itself.
        -- @param value string|table  An undo entry.
        -- @return number  Its size in bytes.
        local function length(value)
            return #(type(value) == 'table' and value.text or value)
        end

        local bytes = 0

        if owner.model then
            for _, value in ipairs(state.undo) do
                bytes = bytes + length(value)
            end
        end

        while #state.undo > 100 or owner.model and bytes > 4194304 do
            local removed = table.remove(state.undo, 1)

            if owner.model then
                bytes = bytes - length(removed)
            end
        end

        if owner.model then
            state.text = owner.code:GetText()
        else
            owner.value.code = owner.code:GetText()
        end

        self.finished = true
        owner.pendingFunctionBinding = nil
        owner:UpdateActions()
        return true
    end

    return transaction
end

-- ============================================================================
-- History
-- ============================================================================

-- Undo or redo of a 'function-completion' entry: restores its code text and its alias binding. Removes the whole
-- bindings table again when the entry says it did not exist before.
-- @param owner table  The editor.
-- @param entry table  The function-completion entry to travel.
-- @return table  The inverse entry for the opposite stack.
function addon:TravelFunctionCompletion(owner, entry)
    local source = owner.model and owner.model.value or owner.value
    local bindings = source.bindings

    local inverse = {
        kind = 'function-completion',
        text = owner.code:GetText(),
        alias = entry.alias,
        binding = bindings and bindings[entry.alias],
        bindingsMissing = bindings == nil,
        modelDepth = entry.modelDepth,
    }

    bindings = self:CopySettingsData(bindings or {})
    bindings[entry.alias] = entry.binding
    source.bindings = bindings

    if entry.bindingsMissing and next(bindings) == nil then
        source.bindings = nil
    end

    owner:SetCode(entry.text)
    return inverse
end

-- True when the newest function-completion entry in the code undo (or redo) stack must be travelled before any model
-- step: the model has not moved past the depth recorded in that entry. Keeps the two histories in their original order.
-- @param owner table  The editor with a model.
-- @param redo boolean|nil  True to look at the redo stack, otherwise the undo stack.
-- @return boolean  True when the code history goes first.
function addon:PreferFunctionCodeHistory(owner, redo)
    local state = owner:CodeState()
    local history = redo and state.redo or state.undo

    for index = #history, 1, -1 do
        local entry = history[index]

        if type(entry) == 'table' and entry.kind == 'function-completion' then
            return redo and #owner.model.undo >= entry.modelDepth or not redo and #owner.model.undo <= entry.modelDepth
        end
    end

    return false
end

-- ============================================================================
-- Dependency rows
-- ============================================================================

-- Returns the sorted list of every function a binding may target (Built In and custom). Labels that still collide get
-- the id appended so every entry is distinguishable in a search.
-- @return table[]  Entries shaped { value = functionId, text = label }.
function addon:FunctionBindingChoices()
    local entries = {}

    for id, record in pairs(self.builtinFunctions or {}) do
        local origin = id:match('^builtin:(.*):[^:]+$') or id
        entries[#entries + 1] = { value = id, text = self:FunctionQualifiedName(id, record.source) .. ' — ' .. origin }
    end

    for id, source in pairs(self.db.global.custom_functions or {}) do
        entries[#entries + 1] = {
            value = id,
            text = self:FunctionQualifiedName(id, source) .. ' — ' .. L['Custom'] .. ' (' .. id .. ')',
        }
    end

    table.sort(entries, function(a, b)
        if a.text == b.text then
            return a.value < b.value
        end

        return a.text < b.text
    end)

    -- Public call paths can repeat too; retain a unique, searchable identity.
    local counts = {}

    for _, entry in ipairs(entries) do
        counts[entry.text] = (counts[entry.text] or 0) + 1
    end

    for _, entry in ipairs(entries) do
        if counts[entry.text] > 1 then
            entry.text = entry.text .. ' (' .. entry.value .. ')'
        end
    end

    return entries
end

-- Marks the Dependencies button and every alias/target control as unsaved when the bindings differ from the baseline.
-- @param form table  The settings form.
-- @param owner table  The editor.
function addon:RefreshFunctionBindingMarkers(form, owner)
    local source = owner.model and owner.model.value or owner.value
    local baseline = owner.model and owner.model.baseline.value or owner.baseline or {}
    local dirty = not owner.readOnly and not self:SettingsDataEqual(source.bindings or {}, baseline.bindings or {})
    self:SetWorkbenchUnsaved(form.fields.function_bindings, dirty)

    for key, control in pairs(form.fields) do
        if key:match('^binding_alias_') or key:match('^binding_target_') then
            self:SetWorkbenchUnsaved(control, dirty)
        end
    end
end

-- One compact geometry contract for condition and utility-function toolbars: the Dependencies button rectangle and the
-- syntax button origin, dropping to a second row when the toolbar is too narrow.
-- @param width number  The toolbar width.
-- @param button Button  The Dependencies button, measured for its label width.
-- @param top number  The toolbar's Y offset.
-- @return table  { x, y, width, syntaxX, syntaxY, bottom }.
function addon:GetFunctionBindingToolbarGeometry(width, button, top)
    local bindingWidth = math.max(90, math.ceil(button:GetFontString():GetStringWidth()) + 24)
    local narrow = width < 348 + bindingWidth
    local x = narrow and 0 or 222
    local y = top + (narrow and 28 or 0)
    bindingWidth = math.min(bindingWidth, math.max(90, width - (narrow and 126 or 348)))
    return { x = x, y = y, width = bindingWidth, syntaxX = x + bindingWidth + 6, syntaxY = y, bottom = y + 28 }
end

-- Adds the Dependencies button and, when expanded, one row per alias to `form` for the editor `owner`. Edits go through
-- owner.model:Change when the editor has a model, else straight to the working source, then redraw the form.
-- @param form table  The settings form.
-- @param owner table  The editor.
-- @param options table|nil  options.header (a rectangle or a function of the button) places the button in a toolbar
--   instead of its own row.
function addon:BuildFunctionBindingFields(form, owner, options)
    options = options or {}
    local source = owner.model and owner.model.value or owner.value
    local bindings = source.bindings or {}
    local count = 0
    local aliases = {}

    for alias in pairs(bindings) do
        count = count + 1
        aliases[#aliases + 1] = alias
    end

    table.sort(aliases)

    -- Commits the code box into the working source (so the redraw does not drop typed code), then redraws.
    local function refresh()
        if not owner.readOnly then
            if owner.FlushCode then
                owner:FlushCode()
            elseif owner.code then
                owner.value.code = owner.code:GetText()
            end
        end

        form:Draw()
        owner:UpdateActions()
    end

    -- Applies `change(bindings)` to the editor's bindings table; ignored while the editor is read-only.
    -- @param change function  Called with the bindings table to modify.
    local function mutate(change)
        if owner.readOnly then
            return
        end

        if owner.model then
            owner.model:Change(function(model)
                model.value.bindings = model.value.bindings or {}
                change(model.value.bindings)
            end)
        else
            source.bindings = source.bindings or {}
            change(source.bindings)
        end
    end

    local y = form.y

    local button = form:Button('function_bindings', string.format(L['Dependencies (%d)'], count), function()
        owner.bindingExpanded = not owner.bindingExpanded
        refresh()
    end)

    if options.header then
        local header = type(options.header) == 'function' and options.header(button) or options.header
        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', header.x, -header.y)
        button:SetWidth(header.width)
        form.y = math.max(y, header.y + 28)
    end

    if not owner.bindingExpanded then
        return
    end

    local targets = self:FunctionBindingChoices()
    local aliasWidth = math.max(80, form.width * .28)
    local labelY = form.y

    for index, caption in ipairs({ L['Name in code'], L['Source helper'] }) do
        local label = form:Acquire('bindingLabels', function()
            return form.child:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        end)

        label:ClearAllPoints()
        label:SetPoint('TOPLEFT', index == 1 and 0 or aliasWidth + 6, -labelY)
        label:SetSize(index == 1 and aliasWidth or math.max(60, form.width - aliasWidth - 40), 18)
        label:SetJustifyH('LEFT')
        label:SetText(caption)
    end

    form.y = labelY + 20

    for index, originalAlias in ipairs(aliases) do
        local alias, id = originalAlias, bindings[originalAlias]
        local y = form.y

        local input = form:Edit(
            'binding_alias_' .. index,
            nil,
            alias,
            function(text)
                if text ~= alias and bindings[text] then
                    return nil
                end
                if self:NormalizeFunctionBindings({ [text] = id }, source.args) then
                    return text
                end
            end,
            function(value)
                if value ~= alias then
                    mutate(function(values)
                        values[value] = values[alias]
                        values[alias] = nil
                    end)

                    alias = value
                end

                owner:UpdateActions()
            end
        )

        input:ClearAllPoints()
        input:SetPoint('TOPLEFT', 0, -y)
        input:SetWidth(aliasWidth)
        input:SetMultiLine(false)
        input:SetHeight(24)
        input:SetTextInsets(4, 4, 0, 0)
        input:SetCursorPosition(0)
        input.rmFunctionValue = nil
        input.rmFunctionBaseline = nil
        input.tooltip = L['Name in code']
        input:Enable()
        local choices = self:CopySettingsData(targets)
        local found = false

        for _, entry in ipairs(choices) do
            if entry.value == id then
                found = true
            end
        end

        if not found then
            choices[#choices + 1] = { value = id, text = id }
        end

        local caption = id

        for _, entry in ipairs(choices) do
            if entry.value == id then
                caption = entry.text
                break
            end
        end

        local target = form:Button('binding_target_' .. index, caption, function()
            if self.ShowFunctionSource then
                self:ShowFunctionSource(id)
            end
        end)

        target:ClearAllPoints()
        target:SetPoint('TOPLEFT', aliasWidth + 6, -y)
        target:SetWidth(math.max(30, form.width - aliasWidth - 72))
        target.tooltip = L['View source']

        -- Navigation must permit Discard even while a raw alias is invalid.
        self:SetUIScript(target, 'OnClick', form:Guard(function()
            if self.ShowFunctionSource then
                self:ShowFunctionSource(id)
            end
        end))

        if self.FunctionSource and self:FunctionSource(id) and self.ShowFunctionSource then
            target:Enable()
        else
            target:Disable()
        end

        local remap = form:Acquire('bindingRemaps', function()
            return self:CreateWorkbenchIconButton(form.child, 'chevron-down', L['Change source helper'])
        end)

        remap:ClearAllPoints()
        remap:SetPoint('TOPRIGHT', -32, -y)
        remap:SetSize(24, 24)
        form.fields['binding_remap_' .. index] = remap

        -- Change source helper button: lets the player pick another function for this alias.
        self:SetUIScript(remap, 'OnClick', form:Guard(function()
            if form:FlushEdits() then
                form:ShowChoices(
                    remap,
                    choices,
                    function(value)
                        mutate(function(values)
                            values[alias] = value
                        end)

                        refresh()
                    end,
                    true
                )
            end
        end))

        if owner.readOnly then
            input:Disable()
            remap:Disable()
        else
            remap:Enable()

            local remove = form:Button(
                'binding_remove_' .. index,
                L['Remove dependency'],
                function()
                    mutate(function(values)
                        values[alias] = nil
                    end)

                    refresh()
                end,
                'trash'
            )

            remove:ClearAllPoints()
            remove:SetPoint('TOPRIGHT', 0, -y)
            remove:SetWidth(26)
        end

        form.y = y + 30
    end

    if not owner.readOnly then
        form:Button(
            'add_binding',
            L['Add dependency'],
            -- Add dependency button: binds the first available function under a fresh, unused alias.
            function()
                local id = targets[1] and targets[1].value or 'MISSING'
                local record = self.builtinFunctions and self.builtinFunctions[id]
                local value = record and record.source or (self.db.global.custom_functions or {})[id]
                local base = self:FunctionQualifiedName(id, value)
                local alias = base
                local n = 2
                local used = { addon = true, L = true }

                for _, arg in ipairs(source.args or {}) do
                    used[arg.name] = true
                end

                while bindings[alias] or used[alias] do
                    alias = base:sub(1, 116) .. n
                    n = n + 1
                end

                mutate(function(values)
                    values[alias] = id
                end)

                refresh()
            end,
            'plus'
        )
    end
end
