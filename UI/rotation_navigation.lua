-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Rotation editor navigation guards, installed onto the editor pane: new-rotation bookkeeping, the dirty-field reset,
-- delete confirmation and the unsaved-changes prompt shown before the editor leaves a rotation. It owns only the two
-- prompt frames on the pane and decides nothing about saving; Apply and Discard go through the pane and workspace.
-- Loaded from RotationMaster.toc before UI/rotation_editor.lua, which calls addon:InstallRotationNavigation(pane).
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Adds the navigation methods to the editor pane. Every prompt callback re-checks that the pane, generation and
-- workspace are still the ones the prompt was opened for, because the editor can switch rotation while a prompt is up.
-- @param pane table  The rotation editor pane.
function addon:InstallRotationNavigation(pane)
    -- Tells whether this is a new rotation that was never saved (not the fallback).
    -- @return boolean  True for a pending, editable, non-fallback rotation.
    function pane:IsNewRotation()
        local workspace = self.workspace
        return workspace.pending == true and not workspace.fallback and not workspace.readOnly
    end

    -- Tells whether this is a new rotation nobody has typed into. Its identifier is filled in from its name on its own,
    -- which is not an edit.
    -- @return boolean  True when it is new and has no edits or pending fields.
    function pane:IsUntouchedNew()
        if not self:IsNewRotation() or self.workspace:IsDirty() then
            return false
        end

        return not (self.nameDirty
            or self.descriptionDirty
            or self.metadataDirty
            or self.tagsDirty
            or self.priorityDirty
            or self.scopeDirty
            or self.identifierEdited
            or self:HasPendingFields())
    end

    -- Clears every per-field dirty flag and pending field edit, after a save, discard or delete.
    function pane:ResetDirtyFields()
        self.nameDirty = false
        self.descriptionDirty = false
        self.metadataDirty = false
        self.tagsDirty = false
        self.priorityDirty = false
        self.identifierDirty = false
        self.identifierProblem = nil
        self.identifierEdited = false
        self.scopeDirty = false
        self.scopeDraft = nil
        self:ClearPendingFields()
    end

    -- Throws away a new, never saved rotation: it leaves the list, and the editor moves on to the fallback. No
    -- confirmation: nothing was saved.
    -- @return boolean|nil  True when discarded; nil when the pane is not showing a new rotation or the discard failed.
    -- @return string|nil  The reason when the first value is nil.
    function pane:DiscardNew()
        if not self.active or not self:IsNewRotation() then
            return nil, 'not-a-new-rotation'
        end

        local ok, why = addon:DiscardPendingRotation(self.workspace)

        if not ok then
            self:Message(why)
            return nil, why
        end

        if self.metadataWindow then
            self.metadataWindow:Close(true)
        end

        self:ResetDirtyFields()
        self:AfterDelete()
        return true
    end

    -- Deletes the current custom rotation after a confirmation prompt (none for a never-saved one, which is just
    -- discarded). Built In, read-only and fallback rotations are refused. The prompt frame is created once and reused.
    -- @return boolean|nil  For a never-saved rotation, what DiscardNew returns; otherwise nothing.
    -- @return string|nil  The reason when DiscardNew fails.
    function pane:ConfirmDelete()
        local workspace = self.workspace

        if not self.active or workspace.readOnly or workspace.fallback then
            return
        end

        -- A new rotation was never saved: there is nothing to confirm.
        if workspace.pending then
            return self:DiscardNew()
        end

        if not self.deletePrompt then
            local frame = CreateFrame('Frame', nil, self.frame)
            frame:SetSize(390, 110)
            frame:SetPoint('CENTER')
            frame:EnableMouse(true)
            local bg = frame:CreateTexture(nil, 'BACKGROUND')
            bg:SetAllPoints(frame)
            bg:SetColorTexture(.06, .07, .08, 1)
            local label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            label:SetPoint('TOPLEFT', 12, -12)
            label:SetWidth(366)
            label:SetWordWrap(true)
            label:SetText(L['Delete this custom rotation and its unsaved draft? This cannot be undone.'])
            local confirm = addon:CreateWorkbenchButton(frame, L['Delete'], 90)
            confirm:SetPoint('BOTTOMRIGHT', -110, 12)
            local cancel = addon:CreateWorkbenchButton(frame, L['Cancel'], 90)
            cancel:SetPoint('BOTTOMRIGHT', -12, 12)
            self.deletePrompt = { frame = frame, label = label, confirm = confirm, cancel = cancel }
            frame:Hide()
        end

        local deleteWidth = addon:FitWorkbenchPrompt(self.deletePrompt.frame, self.frame, 390)
        self.deletePrompt.label:SetWidth(math.max(1, deleteWidth - 24))
        local reference, expected

        if addon.GetRotationRecordSnapshot and workspace.TargetReference then
            reference = addon.RotationData.CopyData(workspace.reference)
            local record
            record, expected = addon:GetRotationRecordSnapshot(workspace.spec, reference)

            if not record then
                self:Message(expected)
                return
            end
        end

        local prompt = self.deletePrompt
        local token = self.generation

        -- Tells whether the delete prompt still belongs to this pane, generation and workspace.
        -- @return boolean  True while the prompt's buttons may act.
        local function valid()
            return pane.active
                and pane.generation == token
                and pane.workspace == workspace
                and prompt.frame:IsShown()
                and workspace:ValidTarget()
        end

        addon:SetUIScript(prompt.cancel, 'OnClick', function()
            if valid() then
                prompt.frame:Hide()
            end
        end)

        addon:SetUIScript(prompt.confirm, 'OnClick', function()
            if not valid() then
                return
            end

            local ok, why = addon:DeleteCustomRotation(workspace.spec, reference or workspace.id, expected)

            if not ok then
                pane:Message(why)
                return
            end

            prompt.frame:Hide()
            pane:RefreshAdvice()
            pane:AfterDelete()
        end)

        prompt.frame:Show()
        addon:OpenPopup(prompt, self)
    end

    -- Runs a callback when it is safe to leave the current rotation. When there are unsaved changes the Apply / Discard
    -- / Cancel prompt opens instead, and the callback runs only after the draft is applied or discarded.
    -- @param callback function  Called with no arguments once leaving is safe.
    -- @return boolean|nil  True when the callback ran at once; false when a prompt was opened (or the metadata flush
    --   failed); nil when the pane is released or callback is not a function.
    -- @return string|nil  'rotation-navigation-pending' when a prompt is open; 'invalid-metadata' or
    --   'rotation-pane-released' for the failures; nil when the callback ran.
    function pane:RequestLeave(callback)
        if not self.active or type(callback) ~= 'function' then
            return nil, 'rotation-pane-released'
        end

        if self.metadataWindow and self.metadataWindow.frame:IsShown() then
            if not self:FlushName() then
                return false, 'invalid-metadata'
            end

            self.metadataWindow:Close(true)
        end

        if not self:HasUnsavedChanges() or self:IsUntouchedNew() then
            callback()
            return true
        end

        if not self.leavePrompt then
            local frame = CreateFrame('Frame', nil, self.frame)
            frame:SetSize(420, 130)
            frame:SetPoint('CENTER')
            frame:EnableMouse(true)
            local background = frame:CreateTexture(nil, 'BACKGROUND')
            background:SetAllPoints(frame)
            background:SetColorTexture(.06, .07, .08, 1)
            local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
            title:SetPoint('TOPLEFT', 14, -14)
            title:SetText(L['Unsaved rotation changes'])
            local message = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            message:SetPoint('TOPLEFT', 14, -38)
            message:SetWidth(392)
            message:SetWordWrap(true)
            message:SetText(L['Apply this draft, discard its changes, or keep editing.'])
            self.leavePrompt = { frame = frame, message = message }

            for index, entry in ipairs({
                { 'apply', L['Apply'] },
                { 'discard', L['Discard'] },
                { 'cancel', L['Cancel'] },
            }) do
                local control = addon:CreateWorkbenchButton(frame, entry[2], 124)
                control:SetPoint('BOTTOMLEFT', 14 + (index - 1) * 134, 14)
                self.leavePrompt[entry[1]] = control
            end

            addon:SetUIScript(frame, 'OnHide', function()
                pane.pendingLeave = nil
            end)

            frame:Hide()
        end

        local prompt = self.leavePrompt
        -- The prompt covers the editor pane, so it shares the pane's width.
        local promptWidth = addon:FitWorkbenchPrompt(prompt.frame, self.frame, 420)
        prompt.message:SetWidth(math.max(1, promptWidth - 28))

        addon:LayoutWorkbenchRow({ prompt.apply, prompt.discard, prompt.cancel }, 14, 96, promptWidth - 28, {
            gap = 10,
        })

        local request = { callback = callback, generation = self.generation, workspace = self.workspace }
        self.pendingLeave = request

        -- Tells whether this leave request is still the pending one for the same generation and workspace.
        -- @return boolean  True while the prompt's buttons may act.
        local function valid()
            return pane.active
                and pane.pendingLeave == request
                and pane.generation == request.generation
                and pane.workspace == request.workspace
        end

        -- Applies the draft and, if that worked, closes the prompt and runs the callback; a failure is shown in the
        -- prompt.
        addon:SetUIScript(prompt.apply, 'OnClick', function()
            if not valid() then
                return
            end

            local ok, why = pane:Apply()

            if not ok then
                prompt.message:SetText(
                    L['The draft could not be applied. Complete the marked fields or Cancel to keep editing.']
                        .. ' '
                        .. tostring(why)
                )

                return
            end

            prompt.frame:Hide()
            callback()
        end)

        -- Discards the draft (a never-saved rotation is removed from the list), clears the dirty flags, closes the
        -- prompt and runs the callback.
        addon:SetUIScript(prompt.discard, 'OnClick', function()
            if not valid() then
                return
            end

            -- Discarding a new rotation that was never saved removes it from the list.
            local ok, why

            if pane:IsNewRotation() then
                ok, why = addon:DiscardPendingRotation(pane.workspace)
            else
                ok, why = pane.workspace:Discard()
            end

            if not ok then
                pane:Message(why)
                return
            end

            pane:ResetDirtyFields()
            prompt.frame:Hide()
            callback()
        end)

        addon:SetUIScript(prompt.cancel, 'OnClick', function()
            if valid() then
                prompt.frame:Hide()
            end
        end)

        prompt.message:SetText(L['Apply this draft, discard its changes, or keep editing.'])
        prompt.frame:Show()
        addon:OpenPopup(prompt, self)
        return false, 'rotation-navigation-pending'
    end
end
