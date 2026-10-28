-- View changes buttons for the editors' draft workflows. Each Install function adds a button beside Apply and wraps the
-- owner's refresh method so the button is enabled only while there is something unsaved. The diff itself is built and
-- shown by UI/draft_changes.lua; this file only snapshots the current draft against its baseline and collects pending
-- edits that are not yet in the draft. Loaded from RotationMaster.toc after UI/draft_changes.lua; the editors call it.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Enables or disables button according to value.
-- @param button Button  The button to change.
-- @param value boolean|nil  True to enable, otherwise disable.
local function enable(button, value)
    if value then
        button:Enable()
    else
        button:Disable()
    end
end

-- Adds the View changes button to the rotation editor pane and to its metadata window, and chains the pane's
-- UpdateHistory and RefreshUnsaved to keep both enabled correctly. Called once per pane, after the unsaved tracking.
-- @param pane table  The rotation editor pane.
function addon:InstallRotationChangeReview(pane)
    -- Builds the snapshot of the rotation as the editor currently shows it.
    -- @param metadataOnly boolean|nil  True leaves out the name and the step fields.
    -- @return table  The workspace snapshot overlaid with edits still sitting in the text fields.
    -- @return table[]  The pending list of { label, before, after } for fields whose text does not yet parse (so they
    --   cannot enter the snapshot).
    function pane:ReviewSnapshot(metadataOnly)
        local snapshot = self.workspace:Snapshot()
        local pending = {}

        if not metadataOnly and self.nameDirty then
            snapshot.name = self.name:GetText()
        end
        if self.descriptionDirty then
            snapshot.description = self.description:GetText()
        end
        if self.metadataDirty then
            snapshot.metadata = addon.RotationData.CopyData(self.metadataDraft)
        end

        if self.tagsDirty then
            local tags = addon.RotationData.ParseRotationTags(self.tags:GetText())

            if tags then
                snapshot.tags = tags
            else
                pending[#pending + 1] = {
                    label = L['Tags'],
                    before = addon.RotationData.FormatRotationTags(self:EffectiveTags(snapshot)),
                    after = self.tags:GetText(),
                }
            end
        end

        if self.priorityDirty then
            local raw = self.priority:GetText()
            local value = raw == '' and 0 or tonumber(raw)

            if value and addon.RotationData.GetRotationPriority(value) ~= nil then
                snapshot.priority = value
            else
                pending[#pending + 1] = { label = L['Switch priority'], before = snapshot.priority or 0, after = raw }
            end
        end

        if self.identifierDirty and self.identifier then
            local identifier = addon.RotationData.NormalizeRotationIdentifier(self.identifier:GetText())

            if identifier and not self.identifierProblem then
                snapshot.identifier = identifier
            else
                pending[#pending + 1] = {
                    label = L['Identifier'],
                    before = snapshot.identifier or '',
                    after = self.identifier:GetText(),
                }
            end
        end

        local beforeScope = self:BaselineScope()
        local afterScope = self:EffectiveScope()

        if beforeScope ~= nil and beforeScope ~= afterScope then
            pending[#pending + 1] = {
                label = L['Applies to'],
                before = beforeScope == 'character' and L['This character'] or L['Class'],
                after = afterScope == 'character' and L['This character'] or L['Class'],
            }
        end

        if not metadataOnly then
            self:ReviewPendingFields(snapshot, pending)
        end

        return snapshot, pending
    end

    -- View changes button handler for the pane: opens the draft diff of the whole rotation against its baseline, valid
    -- only while the same pane drawing and workspace are current.
    pane.viewChanges = addon:CreateViewChangesButton(pane.frame, pane.apply, function()
        if not pane.active or pane.workspace.readOnly then
            return
        end

        local workspace, generation = pane.workspace, pane.generation
        local after, pending = pane:ReviewSnapshot()

        addon:ShowWorkbenchDraftChanges(
            pane,
            'rotation',
            workspace.session:Baseline(),
            after,
            function()
                return pane.active
                    and pane.generation == generation
                    and pane.workspace == workspace
                    and workspace:ValidTarget()
            end,
            workspace.spec,
            pending
        )
    end)

    local history = pane.UpdateHistory

    -- Chains the pane's history refresh so the button follows the unsaved state; read-only rotations never enable it.
    function pane:UpdateHistory()
        history(self)
        enable(self.viewChanges, not self.workspace.readOnly and self:HasUnsavedChanges())
    end

    local dialog = pane.metadataWindow

    -- View changes button handler for the metadata window: compares the description, metadata, tags and priority
    -- against the baseline.
    dialog.viewChanges = addon:CreateViewChangesButton(dialog.frame, dialog.apply, function()
        if not dialog:Valid() or pane.workspace.readOnly then
            return
        end

        local workspace, generation = pane.workspace, pane.generation
        local after, pending = pane:ReviewSnapshot(true)
        local before = workspace.session:Baseline()

        -- Reduces a rotation body to the fields the metadata window edits, so the comparison shows only those.
        -- @param body table  A rotation body.
        -- @return table  { description, metadata, tags, priority }.
        local function metadata(body)
            return {
                description = body.description,
                metadata = body.metadata,
                tags = pane:EffectiveTags(body),
                priority = body.priority or 0,
            }
        end

        addon:ShowWorkbenchDraftChanges(
            dialog,
            'profile',
            metadata(before),
            metadata(after),
            function() return dialog:Valid() and pane.workspace == workspace and pane.generation == generation end,
            workspace.spec,
            pending
        )
    end)

    local refreshed = pane.RefreshUnsaved

    -- Chains the unsaved-state refresh so the metadata window's button follows the pane's unsaved flag.
    function pane:RefreshUnsaved()
        refreshed(self)
        enable(dialog.viewChanges, self.info.rmUnsaved and not self.workspace.readOnly)
    end
end

-- Adds the View changes button to the condition editor shell. The diff is the working condition against its baseline (a
-- comparison baseline when one is set) plus pending edits from every open card pane.
-- @param shell table  The condition editor shell.
function addon:InstallConditionChangeReview(shell)
    -- View changes button handler: opens the draft diff for the condition being edited.
    shell.viewChanges = addon:CreateViewChangesButton(shell.frame, shell.apply, function()
        local active = shell.active

        if not active or active.readOnly then
            return
        end

        local pending = {}

        for _, card in ipairs(shell.canvas.cards) do
            if card.pane then
                addon:PendingWidgetChanges(card.pane, pending)
            end
        end

        addon:ShowWorkbenchDraftChanges(
            shell,
            'condition',
            active.comparisonBaseline or active.session:Baseline(),
            addon.RotationData.CopyData(active.working),
            function() return shell.active == active and shell.frame:IsShown() end,
            active.spec,
            pending
        )
    end)

    local update = shell.UpdateHistoryButtons

    -- Chains the history button refresh; dirty also counts pending widget edits not yet written to the working copy.
    function shell:UpdateHistoryButtons()
        update(self)
        local active = self.active

        local dirty = active
            and not addon:UnsavedDataEqual(active.comparisonBaseline or active.session:Baseline(), active.working)

        if active then
            for _, card in ipairs(self.canvas.cards) do
                if card.pane and #addon:PendingWidgetChanges(card.pane) > 0 then
                    dirty = true
                end
            end
        end

        enable(self.viewChanges, active and not active.readOnly and dirty)
    end
end

-- Adds the View changes button to a settings pane (create form or settings draft).
-- @param p table  The pane from UI/settings_form.lua.
function addon:InstallSettingsChangeReview(p)
    -- Opens the draft diff for the pane: the transaction keys of the settings draft, or the creation state against its
    -- baseline, plus every dirty text field as a pending row labeled from its unsaved binding.
    -- @return any  What addon:ShowWorkbenchDraftChanges returns.
    function p:ReviewSettingsChanges()
        local before, after

        if self.draft then
            before = addon:CopySettingsData(self.draftBaseline)
            after = {}

            for scope, keys in pairs(self.transactionKeys) do
                after[scope] = {}

                for _, key in ipairs(keys) do
                    after[scope][key] = addon:CopySettingsData(self.draft[scope][key])
                end
            end
        else
            before = addon:CopySettingsData(self.creationBaseline or {})
            after = addon:CopySettingsData(self:CreationState())
        end

        local pending = {}

        for _, record in ipairs(self.edits) do
            if record.dirty then
                local key, label, baseline

                for name, binding in pairs(self.unsavedBindings or {}) do
                    if binding.control == record.control or self.fields[name .. '_value'] == record.control then
                        key = name
                        label = binding.caption
                        baseline = binding.baseline
                        break
                    end
                end

                pending[#pending + 1] = {
                    label = label or key and key:gsub('_', ' ') or L['Fields'],
                    before = baseline ~= nil and baseline or record.baseline,
                    after = record.control:GetText(),
                }
            end
        end

        local token = self.generation

        return addon:ShowWorkbenchDraftChanges(
            self,
            'profile',
            before,
            after,
            function() return self:Valid(token) end,
            nil,
            pending
        )
    end

    local creation = p.CreationActions

    -- Chains the creation row so the View changes button sits left of Apply; the button is acquired from the pane's
    -- pool.
    -- @param ... any  The arguments of the original CreationActions.
    function p:CreationActions(...)
        creation(self, ...)

        local button = self:Acquire('viewChangesButtons', function()
            return addon:CreateViewChangesButton(self.frame, self.fields.apply, function() end)
        end)

        button:SetParent(self.frame)
        button:ClearAllPoints()
        button:SetPoint('RIGHT', self.fields.apply, 'LEFT', -6, 0)
        self.fields.viewChanges = button

        addon:SetUIScript(button, 'OnClick', self:Guard(function()
            self:ReviewSettingsChanges()
        end))
    end

    local refresh = p.RefreshUnsaved

    -- Chains the pane's unsaved refresh so the button is enabled while a creation or settings draft is dirty.
    function p:RefreshUnsaved()
        if refresh then
            refresh(self)
        end
        if self.fields.viewChanges then
            enable(self.fields.viewChanges, self:IsCreationDirty() or self:IsSettingsDraftDirty())
        end
    end
end

-- Adds the View changes button to the custom condition dialog, comparing its saved definition with the pending source
-- and field edits as { identifier, definition, preferences }.
-- @param dialog table  The custom condition editor dialog.
function addon:InstallCustomChangeReview(dialog)
    local p = dialog.form
    dialog.viewChanges = dialog.viewChanges or addon:CreateViewChangesButton(dialog.frame, dialog.apply, function() end)

    -- View changes button handler: opens the draft diff of the saved definition against the pending source and dirty
    -- field edits.
    addon:SetUIScript(dialog.viewChanges, 'OnClick', function()
        if not dialog.OwnerValid or not dialog.OwnerValid() then
            return
        end

        local before = addon:CopySettingsData(dialog.model.baseline)
        local after = dialog.model:Snapshot()
        after.value = dialog:PendingSource()
        local pending = {}

        for _, record in ipairs(p.edits) do
            if record.dirty then
                pending[#pending + 1] = {
                    label = L['Fields'],
                    before = record.baseline,
                    after = record.control:GetText(),
                }
            end
        end

        -- Maps a custom condition record to the definition shape shown in the diff.
        -- @param value table  { key, value, context }.
        -- @return table  { identifier, definition, preferences }.
        local function definition(value)
            return { identifier = value.key, definition = value.value, preferences = value.context }
        end

        local session = dialog.session

        addon:ShowWorkbenchDraftChanges(
            dialog,
            'profile',
            definition(before),
            definition(after),
            function() return dialog.session == session and dialog.OwnerValid and dialog.OwnerValid() end,
            nil,
            pending
        )
    end)

    local update = dialog.UpdateActions

    -- Chains the dialog's action refresh so the button is enabled while the dialog is dirty.
    function dialog:UpdateActions()
        update(self)
        enable(self.viewChanges, self:IsDirty())
    end
end
