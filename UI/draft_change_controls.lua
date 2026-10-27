local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

local function enable(button, value)
    if value then
        button:Enable()
    else
        button:Disable()
    end
end

function addon:InstallRotationChangeReview(pane)
    function pane:ReviewSnapshot(metadataOnly)
        local snapshot = self.workspace:Snapshot()
        local pending = {}
        if not metadataOnly and self.nameDirty then snapshot.name = self.name:GetText() end
        if self.descriptionDirty then snapshot.description = self.description:GetText() end
        if self.metadataDirty then snapshot.metadata = addon.RotationData.CopyData(self.metadataDraft) end

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

        if not metadataOnly then self:ReviewPendingFields(snapshot, pending) end
        return snapshot, pending
    end

    pane.viewChanges = addon:CreateViewChangesButton(pane.frame, pane.apply, function()
        if not pane.active or pane.workspace.readOnly then return end
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

    function pane:UpdateHistory()
        history(self)
        enable(self.viewChanges, not self.workspace.readOnly and self:HasUnsavedChanges())
    end

    local dialog = pane.metadataWindow

    dialog.viewChanges = addon:CreateViewChangesButton(dialog.frame, dialog.apply, function()
        if not dialog:Valid() or pane.workspace.readOnly then return end
        local workspace, generation = pane.workspace, pane.generation
        local after, pending = pane:ReviewSnapshot(true)
        local before = workspace.session:Baseline()

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

    function pane:RefreshUnsaved()
        refreshed(self)
        enable(dialog.viewChanges, self.info.rmUnsaved and not self.workspace.readOnly)
    end
end

function addon:InstallConditionChangeReview(shell)
    shell.viewChanges = addon:CreateViewChangesButton(shell.frame, shell.apply, function()
        local active = shell.active
        if not active or active.readOnly then return end
        local pending = {}

        for _, card in ipairs(shell.canvas.cards) do
            if card.pane then addon:PendingWidgetChanges(card.pane, pending) end
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

    function shell:UpdateHistoryButtons()
        update(self)
        local active = self.active

        local dirty = active
            and not addon:UnsavedDataEqual(active.comparisonBaseline or active.session:Baseline(), active.working)

        if active then
            for _, card in ipairs(self.canvas.cards) do
                if card.pane and #addon:PendingWidgetChanges(card.pane) > 0 then dirty = true end
            end
        end

        enable(self.viewChanges, active and not active.readOnly and dirty)
    end
end

function addon:InstallSettingsChangeReview(p)
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

    function p:CreationActions(...)
        creation(self, ...)

        local button = self:Acquire('viewChangesButtons', function()
            return addon:CreateViewChangesButton(self.frame, self.fields.apply, function() end)
        end)

        button:SetParent(self.frame)
        button:ClearAllPoints()
        button:SetPoint('RIGHT', self.fields.apply, 'LEFT', -6, 0)
        self.fields.viewChanges = button
        addon:SetUIScript(button, 'OnClick', self:Guard(function() self:ReviewSettingsChanges() end))
    end

    local refresh = p.RefreshUnsaved

    function p:RefreshUnsaved()
        if refresh then refresh(self) end

        if self.fields.viewChanges then
            enable(self.fields.viewChanges, self:IsCreationDirty() or self:IsSettingsDraftDirty())
        end
    end
end

function addon:InstallCustomChangeReview(dialog)
    local p = dialog.form
    dialog.viewChanges = dialog.viewChanges or addon:CreateViewChangesButton(dialog.frame, dialog.apply, function() end)

    addon:SetUIScript(dialog.viewChanges, 'OnClick', function()
        if not dialog.OwnerValid or not dialog.OwnerValid() then return end
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

    function dialog:UpdateActions()
        update(self)
        enable(self.viewChanges, self:IsDirty())
    end
end
