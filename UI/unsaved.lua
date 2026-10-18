local _,addon=...
-- A separate amber rail preserves the meaning of validation/negation borders.
function addon:SetWorkbenchUnsaved(control,changed)
    if not control then return end
    control.rmUnsaved=changed==true
    if not control.unsavedMark then
        control.unsavedMark=control:CreateTexture(nil,'OVERLAY');control.unsavedMark:SetPoint('TOPLEFT',control,'TOPLEFT',1,-2);control.unsavedMark:SetPoint('BOTTOMLEFT',control,'BOTTOMLEFT',1,2);control.unsavedMark:SetWidth(3);control.unsavedMark:SetColorTexture(1,.7,.15,.95)
    end
    if changed then control.unsavedMark:Show() else control.unsavedMark:Hide() end
end
function addon:InstallRotationUnsaved(pane)
    local history=pane.UpdateHistory
    function pane:RefreshUnsaved()
        if not self.active or not self.workspace then return end
        local baseline=self.workspace.session:Baseline();local current=self.workspace:Snapshot();local state=addon:RotationUnsavedState(baseline,current);self.unsavedState=state
        local writable=not self.workspace.readOnly
        addon:SetWorkbenchUnsaved(self.name,writable and (state.name or self.nameDirty and self.name:GetText()~=(baseline.name or '')))
        addon:SetWorkbenchUnsaved(self.switch,writable and state.switch)
        local description=self.descriptionDirty and self.description:GetText() or current.description or ''
        local metadata=self.metadataDirty and self.metadataDraft or current.metadata;if baseline.metadata==nil and type(metadata)=='table' and next(metadata)==nil then metadata=nil end
        local tags=self:EffectiveTags(current);if self.tagsDirty then tags=addon.RotationData.ParseRotationTags(self.tags:GetText()) end
        local raw=self.priority:GetText();local priority=current.priority or 0;if self.priorityDirty then priority=raw=='' and 0 or tonumber(raw) end
        local details=description~=(baseline.description or '') or not addon:UnsavedDataEqual(metadata,baseline.metadata) or not addon:UnsavedDataEqual(tags,self:EffectiveTags(baseline)) or priority~=(baseline.priority or 0)
        addon:SetWorkbenchUnsaved(self.info,writable and details)
        local index=addon.RotationData.IndexRotationSteps(current)
        local pendingCards={}
        for id,fields in pairs(self.view.pendingFields or {}) do if next(fields) and index and index.byId[id] then
            local path=index.byId[id].path
            for _,row in ipairs(index.rows) do if #row.path<=#path then local ancestor=true;for i,key in ipairs(row.path) do if key~=path[i] then ancestor=false;break end end;if ancestor then pendingCards[row.step.id]=true end end end
        end end
        for _,card in ipairs(self.canvas.cards) do if card.model and card.frame:IsShown() then
            local dirty=state.cards[card.model.id] or pendingCards[card.model.id]
            addon:SetWorkbenchUnsaved(card.frame,writable and dirty)
        end end
        local dialog=self.metadataWindow
        if dialog and dialog:Valid() then
            local metadata=self.metadataDirty and self.metadataDraft or current.metadata or {};if type(metadata)~='table' then metadata={} end;local original=type(baseline.metadata)=='table' and baseline.metadata or {}
            for key,input in pairs(dialog.fields) do
                local dirty
                if key=='description' then dirty=(self.descriptionDirty and self.description:GetText() or current.description or '')~=(baseline.description or '')
                elseif key=='tags' then dirty=not addon:UnsavedDataEqual(tags,self:EffectiveTags(baseline))
                elseif key=='priority' then dirty=priority~=(baseline.priority or 0)
                else dirty=not addon:UnsavedDataEqual(metadata and metadata[key],original[key]) end
                addon:SetWorkbenchUnsaved(input,writable and dirty);if key=='tags' and dialog.tagPicker then addon:SetWorkbenchUnsaved(dialog.tagPicker.frame,writable and dirty) end
            end
        end
    end
    function pane:UpdateHistory() history(self);self:RefreshUnsaved() end
end
