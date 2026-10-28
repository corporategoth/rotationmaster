-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Visual markers for editor controls: a red border for invalid data and an amber left rail for unsaved changes, plus
-- the rotation pane's unsaved-state refresh. The two markers are separate on purpose so validation and unsaved state
-- never share a meaning. It only draws and reads the draft; the comparison itself is addon:RotationUnsavedState in
-- Core/unsaved_changes.lua, and nothing here saves or discards. Loaded in the UI/ block of RotationMaster.toc after
-- UI/drag_presentation.lua.
local _, addon = ...

-- Shows or hides a red border on `control` and records the validation message. Safe on nil; textures are created the
-- first time a control is marked invalid.
function addon:SetWorkbenchInvalid(control, invalid, message)
    if not control then
        return
    end

    control.rmInvalid = invalid == true
    control.rmValidationMessage = invalid and message or nil

    if invalid and not control.invalidBorder then
        control.invalidBorder = {}

        for _, edge in ipairs({
            { 'TOPLEFT', 'TOPRIGHT', true },
            { 'BOTTOMLEFT', 'BOTTOMRIGHT', true },
            { 'TOPLEFT', 'BOTTOMLEFT', false },
            { 'TOPRIGHT', 'BOTTOMRIGHT', false },
        }) do
            local line = control:CreateTexture(nil, 'OVERLAY')
            line:SetPoint(edge[1])
            line:SetPoint(edge[2])
            line:SetColorTexture(1, .2, .2, 1)

            if edge[3] then
                line:SetHeight(1)
            else
                line:SetWidth(1)
            end

            control.invalidBorder[#control.invalidBorder + 1] = line
        end
    end

    for _, line in ipairs(control.invalidBorder or {}) do
        if invalid then
            line:Show()
        else
            line:Hide()
        end
    end
end

-- A separate amber rail preserves the meaning of validation/negation borders.
-- Shows or hides the amber unsaved rail on `control` (safe on nil); the texture is created on first use.
function addon:SetWorkbenchUnsaved(control, changed)
    if not control then
        return
    end

    control.rmUnsaved = changed == true

    if not control.unsavedMark then
        control.unsavedMark = control:CreateTexture(nil, 'OVERLAY')
        control.unsavedMark:SetPoint('TOPLEFT', control, 'TOPLEFT', 1, -2)
        control.unsavedMark:SetPoint('BOTTOMLEFT', control, 'BOTTOMLEFT', 1, 2)
        control.unsavedMark:SetWidth(3)
        control.unsavedMark:SetColorTexture(1, .7, .15, .95)
    end

    if changed then
        control.unsavedMark:Show()
    else
        control.unsavedMark:Hide()
    end
end

-- Adds RefreshUnsaved to the rotation editor pane and extends its UpdateHistory so every history change also
-- refreshes the markers. Call once after the pane's own UpdateHistory exists.
function addon:InstallRotationUnsaved(pane)
    local history = pane.UpdateHistory

    -- Compares the saved baseline with the draft plus any not yet staged field edits and marks the name, switch,
    -- priority, identifier, info button, changed cards and the metadata dialog's fields. Read-only rotations are never
    -- marked. A no-op when the pane is inactive or has no workspace.
    function pane:RefreshUnsaved()
        if not self.active or not self.workspace then
            return
        end

        local baseline = self.workspace.session:Baseline()
        local current = self.workspace:Snapshot()
        local state = addon:RotationUnsavedState(baseline, current)
        self.unsavedState = state
        local writable = not self.workspace.readOnly

        addon:SetWorkbenchUnsaved(
            self.name,
            writable and (state.name or self.nameDirty and self.name:GetText() ~= (baseline.name or ''))
        )

        addon:SetWorkbenchUnsaved(self.switch, writable and state.switch)
        local description = self.descriptionDirty and self.description:GetText() or current.description or ''
        local metadata = self.metadataDirty and self.metadataDraft or current.metadata

        if baseline.metadata == nil and type(metadata) == 'table' and next(metadata) == nil then
            metadata = nil
        end

        local tags = self:EffectiveTags(current)

        if self.tagsDirty then
            tags = addon.RotationData.ParseRotationTags(self.tags:GetText())
        end

        local raw = self.priority:GetText()
        local priority = current.priority or 0

        if self.priorityDirty then
            priority = raw == '' and 0 or tonumber(raw)
        end

        local details = description ~= (baseline.description or '')
            or not addon:UnsavedDataEqual(metadata, baseline.metadata)
            or not addon:UnsavedDataEqual(tags, self:EffectiveTags(baseline))

        -- Priority is in the header beside Enabled, with its own marker.
        addon:SetWorkbenchUnsaved(self.priority, writable and priority ~= (baseline.priority or 0))

        if self.identifier then
            addon:SetWorkbenchUnsaved(
                self.identifier,
                writable
                    and self.identifierDirty == true
                    and self.identifier:GetText():lower() ~= (baseline.identifier or '')
            )
        end

        local scopeChanged = self:BaselineScope() ~= nil and self:EffectiveScope() ~= self:BaselineScope()
        addon:SetWorkbenchUnsaved(self.info, writable and (details or scopeChanged))
        local index = addon.RotationData.IndexRotationSteps(current)
        local pendingCards = {}

        for id, fields in pairs(self.view.pendingFields or {}) do
            if next(fields) and index and index.byId[id] then
                local path = index.byId[id].path

                for _, row in ipairs(index.rows) do
                    if #row.path <= #path then
                        local ancestor = true

                        for i, key in ipairs(row.path) do
                            if key ~= path[i] then
                                ancestor = false
                                break
                            end
                        end

                        if ancestor then
                            pendingCards[row.step.id] = true
                        end
                    end
                end
            end
        end

        for _, card in ipairs(self.canvas.cards) do
            if card.model and card.frame:IsShown() then
                local dirty = state.cards[card.model.id] or pendingCards[card.model.id]
                addon:SetWorkbenchUnsaved(card.frame, writable and dirty)
            end
        end

        local dialog = self.metadataWindow

        if dialog and dialog:Valid() then
            local metadata = self.metadataDirty and self.metadataDraft or current.metadata or {}

            if type(metadata) ~= 'table' then
                metadata = {}
            end

            local original = type(baseline.metadata) == 'table' and baseline.metadata or {}

            for key, input in pairs(dialog.fields) do
                local dirty

                if key == 'description' then
                    dirty = (self.descriptionDirty and self.description:GetText() or current.description or '')
                        ~= (baseline.description or '')
                elseif key == 'tags' then
                    dirty = not addon:UnsavedDataEqual(tags, self:EffectiveTags(baseline))
                elseif key == 'priority' then
                    dirty = priority ~= (baseline.priority or 0)
                elseif key == 'scope' then
                    dirty = scopeChanged
                else
                    dirty = not addon:UnsavedDataEqual(metadata and metadata[key], original[key])
                end

                addon:SetWorkbenchUnsaved(input, writable and dirty)

                if key == 'tags' and dialog.tagPicker then
                    addon:SetWorkbenchUnsaved(dialog.tagPicker.frame, writable and dirty)
                end
            end
        end
    end

    -- The pane's original history update followed by an unsaved-marker refresh.
    function pane:UpdateHistory()
        history(self)
        self:RefreshUnsaved()
    end
end
