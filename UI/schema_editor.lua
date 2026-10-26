local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:ShowFieldSchemaEditor(owner,fields,fieldOrder,changed,ownerValid,resume,requiredFields)
    local d=owner.schemaEditor
    if d and d.active then d.frame:Show();addon:OpenPopup(d,owner);return d end
    d=d or {frame=CreateFrame('Frame',nil,UIParent),path={}};owner.schemaEditor=d;d.active=true;d.path={};d.serial=(d.serial or 0)+1;local serial=d.serial
    local frame=d.frame;frame:SetSize(760,540);frame:ClearAllPoints();frame:SetPoint('CENTER');frame:EnableMouse(true);frame:SetClampedToScreen(true);addon:MakeWindowOpaque(frame)
    d.title=d.title or frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=d.chrome or addon:CreateWorkbenchDialogChrome(frame,d.title);d.chrome:SetContext(L['Field schema'],L['Fields'],owner.model.key)
    d.close=d.close or addon:CreateWorkbenchIconButton(frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5)
    d.host=d.host or addon:TrackWorkbenchSize(CreateFrame('Frame',nil,frame));d.host:SetPoint('TOPLEFT',8,-64);d.host:SetSize(744,420)
    d.form=d.form or addon:CreateSettingsForm(d.host);local p=d.form
    local model,why=addon:NewFieldSchemaDraft(fields,fieldOrder,requiredFields)
    if not model then d.active=false;frame:Hide();owner.form:Message(string.format(L['Invalid field schema: %s'],why));return nil end
    d.model=resume and resume.model or model;d.path=resume and resume.path or {};d.requiresApply=resume and resume.requiresApply or model.requiredFieldsInvalid or false;local baseline=resume and resume.baseline or addon:CopySettingsData(d.model.root);d.baseline=baseline;d.folded=resume and resume.folded or {}
    function d:CaptureDraft()
        local raw,focus={},nil
        for _,record in ipairs(p.edits) do for key,control in pairs(p.fields) do if control==record.control then
            if record.dirty then raw[key]=control:GetText() end
            if control:HasFocus() then focus={key=key,cursor=control.GetCursorPosition and control:GetCursorPosition()} end;break
        end end end
        return {model=self.model,path=addon:CopySettingsData(self.path),baseline=addon:CopySettingsData(baseline),raw=raw,focus=focus,scroll=p.scroll.workbenchBar:GetValue(),requiresApply=self.requiresApply,folded=addon:CopySettingsData(self.folded)}
    end
    local function valid() return d.active and d.serial==serial and ownerValid() end
    function d:Close()
        if not self.active then return end;self.active=false;p:Release();frame:Hide();self.model=nil
        if ownerValid() then owner:Show() end
    end
    function d:IsDirty()
        local dirty=self.requiresApply or addon:GetFieldSchemaIndex(d.model,baseline).dirty;for _,record in ipairs(p.edits) do dirty=dirty or record.dirty end
        return dirty
    end
    function d:Hide()
        local dirty=self:IsDirty()
        if not valid() or not dirty then self:Close();return end
        p:ConfirmPending(function() self:Apply() end,function() self:Close() end)
    end
    function d:UpdateActions()
        if self.cardView then self.cardView:UpdateMarkers() end
        local dirty=self:IsDirty()
        if dirty then d.apply:Enable() else d.apply:Disable() end
        if #d.model.undo>0 then d.undo:Enable() else d.undo:Disable() end
        if #d.model.redo>0 then d.redo:Enable() else d.redo:Disable() end
    end
    function d:Apply()
        if not valid() or not p:FlushEdits() then return false end
        local value,order,required=d.model:Snapshot();if not value then p:Message(string.format(L['Invalid field schema: %s'],order));return false end
        changed(value,order,required);d:Close();return true
    end
    for i,entry in ipairs({{'undo','undo',L['Undo']},{'redo','redo',L['Redo']},{'apply',nil,L['Apply']},{'cancel',nil,L['Cancel']}}) do
        d[entry[1]]=d[entry[1]] or (entry[2] and addon:CreateWorkbenchHistoryButton(frame,entry[2],entry[3]) or addon:CreateWorkbenchButton(frame,entry[3],90))
        local b=d[entry[1]];b:ClearAllPoints();if i<3 then b:SetPoint('TOPLEFT',12+(i-1)*74,-34) else b:SetPoint('BOTTOMRIGHT',-12-(4-i)*98,24) end
        addon:SetUIScript(b,'OnClick',function()
            if not valid() then return end
            if i==4 then d:Close() elseif i==3 then d:Apply() elseif p:FlushEdits() and d.model:Travel(i==2) then p:Draw() end
        end)
    end
    d.add=d.add or addon:CreateWorkbenchLabeledIconButton(frame,'plus',L['Add field'],150);d.add:ClearAllPoints();d.add:SetPoint('TOPRIGHT',-12,-34)
    addon:SetUIScript(d.add,'OnClick',function() if valid() and p:FlushEdits() and d.model:Add({}) then p:Draw() end end)
    addon:SetUIScript(d.close,'OnClick',function() if valid() then d:Hide() end end)
    p:SetWidth(d.host:GetWidth());p:SetHeight(d.host:GetHeight())
    d.pendingRaw=resume and resume.raw;d.pendingFocus=resume and resume.focus;local restoredScroll=resume and resume.scroll
    p:Open(function(form)
        form.scroll:ClearAllPoints();form.scroll:SetPoint('TOPLEFT',0,0);form.scroll:SetSize(form.frame:GetWidth()-20,form.frame:GetHeight())
        form.fields.add=d.add
        form.message:SetParent(frame);form.message:ClearAllPoints();form.message:SetPoint('BOTTOMLEFT',12,26);form.message:SetPoint('RIGHT',d.apply,'LEFT',-8,0);form.message:SetHeight(20)
        addon:BuildFieldSchemaCards(form,d)
        d:UpdateActions()
    end)
    p.scroll.workbenchBar:SetValue(restoredScroll or 0)
    if d.model.requiredFieldsInvalid then p:Message(L['Required field references need review. Apply keeps the displayed root requirements.']) end
    addon:SetUIScript(frame,'OnUpdate',function() if not valid() then d:Close() else d:UpdateActions() end end)
    owner:HideForChild();frame:Show();addon:OpenPopup(d,owner);return d
end
