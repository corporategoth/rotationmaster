-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Inline custom condition pane: the right-hand editor in the settings window's Conditions page that opens, duplicates
-- and saves a custom (or read-only Built In) condition source next to the roster list. It adapts the stand-alone custom
-- condition editor (UI/custom_condition_editor.lua) to the settings pane `p` and its settings draft; it must not save
-- anything except through the draft transaction (p:SaveSettingsDraft) and addon:InstallCustomCondition.
-- Loaded from RotationMaster.toc near the end of the UI block, after UI/condition_source_preview.lua and before
-- UI/condition_entrypoints.lua; UI/settings_conditions.lua calls it when these functions exist and otherwise falls back
-- to the window-style editor. A saved condition's text is user code: this file never executes it.

local addon_name, addon = ...
local invalidateDependencies = addon.InvalidateRotationDependencies

if type(invalidateDependencies) ~= 'function' then
    invalidateDependencies = nil
end

local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Forgets the half-created "new condition" state on the pane.
-- @param p table  The settings pane.
local function clearNew(p)
    p.creatingCondition = nil
    p.newConditionKey = nil
    p.newConditionSource = nil
end

-- Wraps the pane's Layout, Draw, RequestLeave and Release (once per pane) so the embedded editor follows the pane's
-- size, survives a redraw with its unsaved draft, asks before the pane is left with unapplied edits, and is dropped on
-- release.
-- @param p table  The settings pane to wrap; a second call on the same pane does nothing.
--
-- The originals are captured and called, never replaced outright.
function addon:InstallInlineConditionNavigation(p)
    if p.inlineNavigation then
        return
    end

    p.inlineNavigation = true
    local leave, release, draw, layout = p.RequestLeave, p.Release, p.Draw, p.Layout

    -- Resizes the embedded editor to the pane's height after the pane lays out.
    function p:Layout()
        layout(self)
        local editor = self.inlineCondition

        if editor and not editor.closed and editor.OwnerValid() then
            editor:ResizeHeight(math.max(160, self.frame:GetHeight() - 34))
        end
    end

    -- Captures the open editor's unsaved draft before the pane redraws, but only when the redraw is for the same
    -- condition (or the same new source), so the editor resumes where it was instead of reloading from the registry.
    -- @return any  Whatever the pane's original Draw returns.
    function p:Draw()
        local editor = self.inlineCondition
        self.inlineResume = nil

        if
            editor
            and not editor.closed
            and editor.OwnerValid()
            and self.mode ~= 'categories'
            and editor.inlineSelection == self.condition
            and editor.inlineNewSource == self.newConditionSource
        then
            self.inlineResume = editor:CaptureDraft()
        end

        return draw(self)
    end

    -- Runs `callback` once it is safe to leave.
    -- @param callback function  Called when the pane may be left.
    -- @return boolean|any  False when it deferred to the confirmation; otherwise what the pane's original RequestLeave
    --   returns.
    --
    -- With unapplied edits it asks first: Apply then proceeds only if the pane is still the same drawing (same profile
    -- and global tables) and the apply succeeds; Discard drops the draft.
    function p:RequestLeave(callback)
        local editor = self.inlineCondition

        if editor and not editor.closed and editor:IsDirty() then
            local profile, global = self.profile, self.global

            self:ConfirmPending(function()
                if self.active and self.profile == profile and self.global == global and editor:Apply() then
                    callback()
                end
            end, function()
                if not self.active or self.profile ~= profile or self.global ~= global then
                    return
                end

                editor:Close()
                self.inlineCondition = nil
                self:DiscardSettingsDraft()
                clearNew(self)
                callback()
            end)

            return false
        end

        return leave(self, callback)
    end

    -- Drops the new-condition state and the editor reference after the pane's own release.
    function p:Release()
        clearNew(self)
        self.inlineResume = nil
        release(self)
        self.inlineCondition = nil
    end
end

-- Starts a new custom condition on the pane `p`, seeded with a copy of `source` or the empty template. Leaving the
-- current selection may first ask about unapplied edits.
-- @param p table  The settings pane.
-- @param key string|nil  The key for the new condition; nil lets the editor assign one.
-- @param source table|nil  The condition source to copy; nil uses the empty template.
function addon:OpenInlineCustomCondition(p, key, source)
    self:InstallInlineConditionNavigation(p)

    p:RequestLeave(function()
        if not p.active then
            return
        end

        p.creatingCondition = true
        p.newConditionKey = key
        p.newConditionSource = self:CopySettingsData(source or self.empty_condition)
        p.condition = nil
        p.conditionSource = 'custom'
        p.category = 'ALL'
        p:Draw()
    end)
end

-- Starts a new custom condition that is a copy of the pane's selected condition (custom or Built In), with a fresh key
-- and a "Copy of" description. Does nothing when the selection has no source.
-- @param p table  The settings pane.
function addon:DuplicateInlineCustomCondition(p)
    self:InstallInlineConditionNavigation(p)

    -- Runs once it is safe to leave: seeds the pane with the copied source under a fresh key and redraws.
    p:RequestLeave(function()
        if not p.active then
            return
        end

        local key = p.condition

        local source = self.db.global.custom_conditions[key] or self.GetBuiltinConditionSource
            and self:GetBuiltinConditionSource(key)

        if not source then
            return
        end

        p.creatingCondition = true
        p.newConditionKey = key:sub(1, 216) .. '_' .. self:uuid():gsub('-', '_')
        p.newConditionSource = self:CopySettingsData(source)
        p.newConditionSource.description = string.format(L['Copy of %s'], source.description)
        p.condition = nil
        p.conditionSource = 'custom'
        p.category = 'ALL'
        p:Draw()
    end)
end

-- Builds the embedded editor for condition `key` with `source` on pane `p`. The options table defines the editor's
-- extra fields (the Hidden, Switch and Announcement flags and the category), how it is saved and how it is discarded.
-- @param p table  The settings pane.
-- @param key string|nil  The condition key; ignored (treated as nil) while a new condition is being created.
-- @param source table  The condition source to edit.
-- @param readOnly boolean|nil  True shows a Built In condition that can be inspected and duplicated but not changed.
-- @return table  The embedded editor (also stored as p.inlineCondition).
function addon:BuildInlineCustomCondition(p, key, source, readOnly)
    self:InstallInlineConditionNavigation(p)
    local token = p.generation
    local store = p:SettingsData()
    local profile = store.profile
    local isNew = p.creatingCondition == true

    if isNew then
        key = nil
        source = p.newConditionSource or self.empty_condition
    end

    local preferences = {
        hidden = self:SettingsContains(profile.disabled_conditions, key),
        switch = self:SettingsContains(profile.switch_conditions, key),
        announcement = self:SettingsContains(profile.announcement_conditions, key),
        category = 'DEFAULT',
    }

    for _, group in ipairs(profile.condition_groups or {}) do
        if self:SettingsContains(group.conditions, key) then
            preferences.category = group.id
            break
        end
    end

    -- True while the pane is still showing the drawing this editor was built for; every callback checks it.
    -- @return boolean  True when the pane drawing is current.
    local function valid()
        return p:Valid(token)
    end

    local geometry = self:GetWorkbenchRosterGeometry(p.frame:GetWidth(), p.frame:GetHeight())

    local options = {
        readOnly = readOnly,
        parent = p.frame,
        x = geometry.detailX,
        footer = p.frame,
        width = geometry.detailWidth - self:GetWorkbenchHelpReserve(p.frame),
        height = math.max(160, p.frame:GetHeight() - 34),
        editor = p.inlineEditorCache,
        resume = p.inlineResume,
    }

    p.inlineResume = nil

    -- Seeds the editor model with the new condition's key and the context (flags and category) baseline.
    -- @param model table  The editor model.
    options.initialize = function(model)
        if isNew and p.newConditionKey then
            model.key = p.newConditionKey
            model.baseline.key = model.key
            model.creationPending = true
        end

        model.context = self:CopySettingsData(preferences)
        model.baseline.context = self:CopySettingsData(preferences)
    end

    -- Closing the editor's owner: hides the settings window when this pane is its current pane, otherwise leaves and
    -- releases the pane.
    -- @param mouse boolean|nil  True when a right click caused it, so the shell does not reopen on that click.
    options.closeOwner = function(mouse)
        local shell = addon.configWindow

        if shell and shell.pane == p then
            if mouse then
                shell.rightDown = true
            end

            shell:Hide()
        else
            p:RequestLeave(function()
                p:Release()
            end)
        end
    end

    options.dirty = function() return p:IsSettingsDraftDirty() end

    -- Discards the settings draft and redraws the pane, if the drawing is still current.
    options.discard = function()
        if valid() then
            p:DiscardSettingsDraft()
            clearNew(p)
            p:Draw()
        end
    end

    -- Adds the three membership flags (Hidden, Switch, Announcement) and, for a saved editable condition, Delete.
    -- @param form table  The editor's form.
    -- @param d table  The editor (d.model holds the context).
    options.fields = function(form, d)
        local context = d.model.context
        local y = form.y

        local hidden = form:Check('hidden', L['Hidden'], context.hidden, function(value)
            d.model:Change(function(model)
                model.context.hidden = value
            end)

            d:UpdateActions()
        end)

        local switch = form:Check('switch', L['Switch Condition'], context.switch, function(value)
            d.model:Change(function(model)
                model.context.switch = value
            end)

            d:UpdateActions()
        end)

        local announcement = form:Check('announcement', L['Announcement Condition'], context.announcement, function(
            value
        )
            d.model:Change(function(model)
                model.context.announcement = value
            end)

            d:UpdateActions()
        end)

        announcement.tooltip = L['Show this condition in the announcement condition editor.']

        form.cleanups[#form.cleanups + 1] = function()
            announcement.tooltip = nil
        end

        -- The three flags share their row in thirds (the Enabled pill and
        -- Delete keep the right end) and wrap rather than clip when narrow.
        self:LayoutConditionFlags(hidden, switch, announcement, y, form.width - 148)
        form.y = y + hidden.rmFlagRowsHeight + 2

        if key and not readOnly then
            -- Delete button: asks for confirmation, then removes the saved custom condition and clears the selection.
            self:SettingsTopDelete(form, function()
                self:ConfirmSettingsDeletion(
                    p,
                    L['Delete this custom condition? Existing rotations using it will become unavailable.'],
                    function()
                        local ok, why = self:DeleteSavedCustomCondition(key)

                        if ok then
                            clearNew(p)
                            p.condition = nil
                        end

                        return ok, why
                    end
                )
            end)
        end
    end

    -- Adds the category row: a button that opens the category manager and a chooser to move the condition to another
    -- category.
    -- @param form table  The editor's form.
    -- @param d table  The editor (d.model holds the context and baseline).
    options.category = function(form, d)
        local context = d.model.context
        local savedCategory = d.model.baseline.context.category
        local groups = store.profile.condition_groups or {}
        local destinations = { { value = 'DEFAULT', text = L['Other'], icon = self:GetConditionCategoryIcon(nil) } }
        local current = L['Other']
        local icon = self:GetConditionCategoryIcon(nil)

        for _, group in ipairs(groups) do
            destinations[#destinations + 1] = {
                value = group.id,
                text = group.name or group.id,
                icon = self:GetConditionCategoryIcon(group),
            }

            if group.id == savedCategory then
                current = group.name or group.id
                icon = self:GetConditionCategoryIcon(group)
            end
        end

        -- Leaves the editor for the category manager, selecting the condition's saved category there.
        local function visitCategory()
            p:RequestLeave(function()
                if p.active then
                    p.mode = 'categories'
                    p.categorySelection = savedCategory
                    p:Draw()
                end
            end)
        end

        local categoryY = form:Row(L['Category'], 28)
        form.pool.labels[form.counts.labels]:SetWidth(168)
        local fieldWidth = (form.width - 182) / 2

        local category = form:Acquire('sourceCategory', function()
            return self:CreateWorkbenchButton(form.child, '', fieldWidth)
        end)

        form.fields.current_category = category
        category:ClearAllPoints()
        category:SetPoint('TOPLEFT', 174, -categoryY)
        category:SetText(current)

        -- Navigation must offer Discard even while a raw source field is invalid.
        self:SetUIScript(category, 'OnClick', function()
            if valid() then
                visitCategory()
            end
        end)

        category.categoryIcon = category.categoryIcon or category:CreateTexture(nil, 'ARTWORK')
        category.categoryIcon:SetPoint('LEFT', 3, 0)
        category.categoryIcon:SetSize(20, 20)
        category.categoryIcon:SetTexture(icon)
        category:SetWidth(fieldWidth)
        self:AlignWorkbenchTextLeft(category, 28)

        local moveLabel = form:Acquire('labels', function()
            return form.child:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        end)

        form.fields.moveLabel = moveLabel
        moveLabel:ClearAllPoints()
        moveLabel:SetPoint('TOPLEFT', 174 + fieldWidth + 8, -categoryY)
        moveLabel:SetSize(38, 24)
        moveLabel:SetText(L['Move'])
        moveLabel:SetJustifyH('LEFT')
        moveLabel:SetJustifyV('MIDDLE')

        local move = form:Choice('move_to', nil, context.category, destinations, function(value)
            if valid() then
                d.model:Change(function(model)
                    model.context.category = value
                end)

                form:Draw()
                d:UpdateActions()
            end
        end)

        move:ClearAllPoints()
        move:SetPoint('TOPLEFT', 174 + fieldWidth + 50, -categoryY)
        move:SetWidth(fieldWidth - 42)
        form.y = form.y - 30
    end

    -- Marks each context field that differs from its saved baseline as unsaved.
    -- @param d table  The editor.
    options.updateActions = function(d)
        for _, field in ipairs({ 'hidden', 'switch', 'announcement' }) do
            self:SetWorkbenchUnsaved(d.form.fields[field], d.model.context[field] ~= d.model.baseline.context[field])
        end

        self:SetWorkbenchUnsaved(d.form.fields.move_to, d.model.context.category ~= d.model.baseline.context.category)
    end

    -- Applies the editor: re-checks that nothing changed elsewhere, installs the condition, applies the context flags
    -- and category to the settings draft, and saves the draft.
    -- @param identifier string  The key of the condition being saved.
    -- @param value table  The edited condition source.
    -- @param expected table|nil  The condition definition that was registered when editing began.
    -- @param expectedSource table|nil  The saved source that existed when editing began.
    -- @return boolean  True on success.
    -- @return table|nil  On failure, a { reason = string } table naming why.
    --
    -- If the draft save fails after the condition was installed, the previous definition and source are put back so a
    -- half-applied save is never left behind.
    options.save = function(identifier, value, expected, expectedSource)
        if not valid() then
            return false, { reason = 'definition-changed' }
        end
        if InCombatLockdown and InCombatLockdown() then
            return false, { reason = L['Leave combat before applying these settings.'] }
        end

        -- Validate every owned settings baseline before registration. A trusted
        -- registration hook can fail; preferences are applied only after it succeeds.
        for scope, keys in pairs(p.transactionKeys) do
            for _, field in ipairs(keys) do
                if not self:SettingsDataEqual(
                    self.db[scope] and self.db[scope][field],
                    p.draftBaseline[scope][field]
                ) then
                    return false, { reason = L['Settings changed elsewhere. Cancel to reload them before applying.'] }
                end
            end
        end

        local previous = self:CopySettingsData(self.db.global.custom_conditions[identifier])
        local oldDefinition = self.conditionDefinitions[identifier]

        if oldDefinition ~= expected or expectedSource and not self:SettingsDataEqual(previous, expectedSource) then
            return false, { reason = 'definition-changed' }
        end
        if readOnly and not self:SettingsDataEqual(source, value) then
            return false, { reason = 'readonly-builtin' }
        end

        local changed = not readOnly and not self:SettingsDataEqual(previous, value)

        if changed then
            local ok, why = self:InstallCustomCondition(identifier, value, expected, expectedSource)

            if not ok then
                return false, why
            end
        end

        local saved = self:CopySettingsData(self.db.global.custom_conditions[identifier])
        p.draft.global.custom_conditions[identifier] = saved
        p.draftBaseline.global.custom_conditions = p.draftBaseline.global.custom_conditions or {}
        p.draftBaseline.global.custom_conditions[identifier] = self:CopySettingsData(saved)
        local context = p.inlineCondition.model.context
        local draft = p.draft.profile

        -- Makes `identifier` a member of `list` exactly when `enabled`.
        -- @param list table  The membership list in the settings draft.
        -- @param enabled boolean|nil  True to include the condition, otherwise exclude it.
        local function membership(list, enabled)
            if self:SettingsContains(list, identifier) ~= enabled then
                self:SettingsFlag(list, identifier, enabled)
            end
        end

        draft.disabled_conditions = draft.disabled_conditions or {}
        membership(draft.disabled_conditions, context.hidden)
        draft.switch_conditions = draft.switch_conditions or {}
        membership(draft.switch_conditions, context.switch)
        draft.announcement_conditions = draft.announcement_conditions or {}
        membership(draft.announcement_conditions, context.announcement)

        for _, group in ipairs(draft.condition_groups or {}) do
            group.conditions = group.conditions or {}
            membership(group.conditions, group.id == context.category)
        end

        if not p:SaveSettingsDraft() then
            -- This can occur if trusted registration code changes another owned
            -- namespace. Restore our source/registry rather than accepting half a save.
            if changed then
                local current = self.conditionDefinitions[identifier]

                if current and not current.disabled and current.on_unregister then
                    pcall(current.on_unregister, identifier)
                end

                self.db.global.custom_conditions[identifier] = previous
                self.conditionDefinitions[identifier] = oldDefinition
                self.conditionRegistryVersion = (self.conditionRegistryVersion or 0) + 1

                if invalidateDependencies then
                    invalidateDependencies(addon, 'condition', identifier)
                end
                if oldDefinition and not oldDefinition.disabled and oldDefinition.on_register then
                    pcall(oldDefinition.on_register, identifier)
                end
                if self.RefreshConditionConsumers then
                    self:RefreshConditionConsumers()
                end

                p.draft.global.custom_conditions[identifier] = self:CopySettingsData(previous)
                p.draftBaseline.global.custom_conditions[identifier] = self:CopySettingsData(previous)
            end

            return false, { reason = L['Settings changed elsewhere. Cancel to reload them before applying.'] }
        end

        return true
    end

    local d, owner = self:condition_edit_box(function(identifier)
        if not valid() then
            return
        end

        clearNew(p)
        p.condition = identifier
        p.conditionSource = readOnly and 'builtin' or 'custom'
        p.category = 'ALL'
        p:Draw()
    end, key, source, valid, options)

    p.inlineCondition = d
    p.inlineEditorCache = d
    d.inlineSelection = p.condition
    d.inlineNewSource = p.newConditionSource

    p.cleanups[#p.cleanups + 1] = function()
        self:CloseCustomConditionEditor(d, owner)

        if p.inlineCondition == d then
            p.inlineCondition = nil
        end
    end

    p.creationUsed = true
    p.creationUsedForNew = false
    p.y = 1
    p.scroll:Hide()
    -- The right pane owns its source actions; no duplicate page Apply row.
    return d
end
