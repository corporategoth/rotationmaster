local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local order={'evaluate','valid','print','widget','help','on_register','on_unregister'}
local labels={evaluate=L['Evaluate'],valid=L['Validate'],print=L['Summary'],widget=L['Fields UI'],help=L['Help'],on_register=L['On register'],on_unregister=L['On unregister']}
local function reason(why)
    return string.format(L['Check %s: %s'],why and (labels[why.callback] or why.field) or L['Definition'],why and (why.detail or why.reason) or L['Invalid custom condition.'])
end
function addon:condition_edit_box(update,key,source,saveAllowed)
    local d=self.nativeCustomConditionDialog
    if d and not d.closed then if d.OwnerValid and not d.OwnerValid() then d:Close() else d:Show();return d,d.owner end end
    d=d or {frame=CreateFrame('Frame',nil,UIParent),nativeCustomEditor=true}
    self.nativeCustomConditionDialog=d;d.closed=false;d.update=update;d.selected='evaluate';d.session=(d.session or 0)+1;local session=d.session;local frame=d.frame
    frame:SetSize(960,740);frame:SetPoint('CENTER');frame:EnableMouse(true);frame:SetToplevel(true);frame:SetClampedToScreen(true);self:MakeWindowOpaque(frame)
    d.title=d.title or frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=d.chrome or self:CreateWorkbenchDialogChrome(frame,d.title)
    d.close=d.close or self:CreateWorkbenchIconButton(frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5)
    d.help=d.help or self:CreateWorkbenchHelpButton(frame,L['Help']);d.help:SetPoint('TOPRIGHT',-28,-4)
    d.body=d.body or CreateFrame('Frame',nil,frame);d.body:SetPoint('TOPLEFT',12,-34);d.body:SetSize(936,642)
    d.form=d.form or self:CreateSettingsForm(d.body);local p=d.form
    local profile,global=self.db.profile,self.db.global
    local function valid() return d.session==session and not d.closed and d.owner and d.owner.active and addon.db.profile==profile and addon.db.global==global and (not saveAllowed or saveAllowed()) end
    d.OwnerValid=valid
    d.owner=self:OwnCustomConditionDialog(d,nil,valid)
    d.originalKey=key;d.expected=(self.conditionDefinitions or {})[key];d.expectedSource=key and self:CopySettingsData((global.custom_conditions or {})[key]);d.model=self:NewCustomConditionDraft(key,source or self.empty_condition)
    function d:SetCallback(event,callback) self[event]=callback end
    function d:Show() if valid() then self.frame:Show();addon:RegisterWindowForEscape(self) end end
    function d:HideForChild() self.frame:Hide() end
    function d:FlushCode()
        if self.code then self.model:SetFunction(self.selected,self.code:GetText()) end
    end
    function d:Flush()
        if not valid() or not p:FlushEdits() then return false end;self:FlushCode();return true
    end
    function d:IsDirty()
        if self.model:IsDirty() or self.code and self.code:GetText()~=self.model.value[self.selected] then return true end
        for _,edit in ipairs(p.edits) do if edit.dirty then return true end end;return false
    end
    function d:UpdateActions()
        if self.closed then return end
        if #self.model.undo>0 or self.code and self.code:GetText()~=self.model.value[self.selected] then self.undo:Enable() else self.undo:Disable() end
        if #self.model.redo>0 then self.redo:Enable() else self.redo:Disable() end
        if self:IsDirty() then self.apply:Enable() else self.apply:Disable() end
        local before=self.model.baseline;local current=self.model.value
        for _,entry in ipairs({{'identifier',self.model.key,before.key},{'description',current.description,before.value.description},{'schema',addon:FormatCustomFieldSchema(current.fields),addon:FormatCustomFieldSchema(before.value.fields)},{'icon',current.icon,before.value.icon}}) do
            local input=p.fields[entry[1]];local dirty=not addon:UnsavedDataEqual(entry[2],entry[3]);for _,record in ipairs(p.edits) do if record.control==input and record.dirty then dirty=input:GetText()~=tostring(entry[3] or '') end end;addon:SetWorkbenchUnsaved(input,dirty)
        end
        if self.code then addon:SetWorkbenchUnsaved(self.code.frame,self.code:GetText()~=(before.value[self.selected] or '')) end
        for name,button in pairs(self.functionTabs or {}) do addon:SetWorkbenchUnsaved(button,current[name]~=before.value[name] or name==self.selected and self.code and self.code:GetText()~=(before.value[name] or '')) end
    end
    function d:Close()
        if self.closed then return end;self.closed=true;self.owner.active=false
        local children={};for child in pairs(self.owner.widgets) do if child~=self then children[#children+1]=child end end
        for _,child in ipairs(children) do child:Hide() end
        if self.ownedPicker and self.ownedPicker.serial==self.ownedPickerSerial then self.ownedPicker.frame:Hide() end
        if self.ownedHelp and self.ownedHelp.sections==self.ownedHelpSections then self.ownedHelp:Hide() end
        self.ownedPicker=nil;self.ownedHelp=nil;self.ownedHelpSections=nil
        if self.code then pcall(self.code.Release,self.code) end;p:Release();self.frame:Hide()
        if self.OnRelease then self:OnRelease() end
        addon:SetUIScript(self.frame,'OnUpdate',nil)
        self.OwnerValid=nil;self.model=nil;self.expected=nil;self.expectedSource=nil;self.update=nil;p.builder=nil;p.edits={};p.fields={};p.profile=nil;p.global=nil;p.char=nil
        if self.rmCustomTransferForm and self.rmCustomTransferForm.textDialog then local transfer=self.rmCustomTransferForm.textDialog;transfer.input:SetText('');transfer.options=nil end
    end
    function d:Apply()
        if not self:Flush() then return false end
        local identifier=self.model.key
        if identifier==self.originalKey and not addon:SettingsDataEqual((global.custom_conditions or {})[identifier],self.expectedSource) then p:Message(L['The custom condition changed elsewhere. Reopen it before saving.']);return false end
        local expected=identifier==self.originalKey and self.expected or nil
        local ok,why=addon:InstallCustomCondition(identifier,self.model.value,expected,identifier==self.originalKey and self.expectedSource or nil)
        if not ok then p:Message(reason(why));return false end
        local notify=self.update;self.model:MarkSaved();self:Close();notify(identifier);return true
    end
    function d:Hide()
        if self.closed then return end
        if not valid() then self:Close();return end
        if not self:IsDirty() then self:Close();return end
        p:ConfirmPending(function() self:Apply() end,function() self:Close() end);p.prompt.frame:SetParent(UIParent);addon:RegisterWindowForEscape(p.prompt)
    end
    function d:SelectFunction(name)
        if not valid() or not addon.CustomConditionCallbacks[name] or not self:Flush() then return end;self.selected=name;p:Draw();self:UpdateActions()
    end
    d.undo=d.undo or self:CreateWorkbenchHistoryButton(frame,'undo',L['Undo']);d.undo:SetPoint('BOTTOMLEFT',12,28)
    d.redo=d.redo or self:CreateWorkbenchHistoryButton(frame,'redo',L['Redo']);d.redo:SetPoint('BOTTOMLEFT',86,28)
    d.syntax=d.syntax or self:CreateWorkbenchButton(frame,L['Check syntax'],122);d.syntax:SetPoint('BOTTOMLEFT',164,28)
    d.transfer=d.transfer or self:CreateWorkbenchButton(frame,L['Import/Export'],126);d.transfer:SetPoint('BOTTOMLEFT',292,28)
    d.apply=d.apply or self:CreateWorkbenchButton(frame,L['Apply'],100);d.apply:SetPoint('BOTTOMRIGHT',-120,28)
    d.cancel=d.cancel or self:CreateWorkbenchButton(frame,L['Cancel'],100);d.cancel:SetPoint('BOTTOMRIGHT',-12,28)
    addon:SetUIScript(d.undo,'OnClick',function() if valid() and d:Flush() and d.model:Undo() then p:Draw();d:UpdateActions() end end)
    addon:SetUIScript(d.redo,'OnClick',function() if valid() and d:Flush() and d.model:Redo() then p:Draw();d:UpdateActions() end end)
    addon:SetUIScript(d.apply,'OnClick',function() if valid() then d:Apply() end end);addon:SetUIScript(d.cancel,'OnClick',function() if valid() then d:Close() end end);addon:SetUIScript(d.close,'OnClick',function() if valid() then d:Hide() end end)
    addon:SetUIScript(d.syntax,'OnClick',function() if valid() and d:Flush() then local ok,why=addon:ValidateCustomConditionSource(d.model.key,d.model.value,d.model.key==d.originalKey and d.expectedSource~=nil);p:Message(ok and L['Syntax checked. No custom code was executed.'] or reason(why)) end end)
    addon:SetUIScript(d.transfer,'OnClick',function() if valid() and d:Flush() then addon:ShowCustomConditionTransfer(d,update,d.model.key,d.model.value) end end)
    addon:SetUIScript(d.help,'OnClick',function() if valid() then d.ownedHelp=addon:ShowWorkbenchHelp(L['Custom condition'],{
        {title=L['Editing code'],text=L['Function tabs edit separate callbacks. Changes stay in a draft. Check syntax compiles every callback without running it. Apply registers the callbacks and can run registration code. Cancel discards the draft. Undo and Redo work across function tabs.']},
        {title=L['Field schema'],text=L['Declare named fields, primitive types, nested records and unions. Example: { spell = { string, number }, unit = string, tests = condition[] }. Schema text is parsed as data and never evaluated as Lua.']},
        {title=L['Trusted code'],text=L['Custom Lua has the same access as the addon. Only import code you trust. Syntax validation cannot establish that a callback is safe or correct. Existing custom widget callbacks still use their original UI contract.']}},frame);d.ownedHelpSections=d.ownedHelp.sections end end)
    p:Open(function(form)
        d.chrome:SetContext(L['Rotation Master']..': '..(d.model.value.description~='' and d.model.value.description or L['Custom condition']),L['Custom condition'],d.model.key)
        form:Edit('identifier',L['Identifier'],d.model.key,function(text) return text:match('^[A-Z0-9_]+$') and text end,function(text) d.model:Change(function(model) model.key=text end) end)
        if d.originalKey then form.fields.identifier:EnableMouse(false) end
        form:Edit('description',L['Description'],d.model.value.description,nil,function(text) d.model:Change(function(model) model.value.description=text end) end)
        local icon=form:Button('icon',L['Choose icon'],function()
            if not d:Flush() then return end
            d.ownedPicker=addon:ShowWorkbenchIconPicker(d.model.value.icon,function(texture) if valid() and d:Flush() then d.model:Change(function(model) model.value.icon=texture end);p:Draw() end end,valid)
            d.ownedPickerSerial=d.ownedPicker.serial
        end)
        icon.texture=icon.texture or icon:CreateTexture(nil,'ARTWORK');icon.texture:SetTexture(d.model.value.icon);icon.texture:SetSize(24,24);icon.texture:SetPoint('LEFT',4,0);addon:AlignWorkbenchTextLeft(icon,34)
        form:Edit('schema',L['Field schema'],addon:FormatCustomFieldSchema(d.model.value.fields) or '',function(text) return addon:ParseCustomFieldSchema(text) end,function(fields) d.model:Change(function(model) model.value.fields=fields end) end)
        form.fields.schema:SetMaxLetters(32768);form.fields.schema:SetText(addon:FormatCustomFieldSchema(d.model.value.fields) or '')
        local y=form:Row(nil,28)
        d.functionTabs={}
        for i,name in ipairs(order) do
            local button=form:Acquire('functionTabs',function() return addon:CreateWorkbenchButton(form.child,'',102) end);button:ClearAllPoints();button:SetPoint('TOPLEFT',(i-1)*106,-y);button:SetSize(102,24);button:SetText(labels[name]);d.functionTabs[name]=button;button:SetSelected(name==d.selected);addon:SetUIScript(button,'OnClick',form:Guard(function() d:SelectFunction(name) end))
        end
        form:Text('function('..addon.CustomConditionCallbacks[d.selected]..')')
        if not d.code then d.code=addon:CreateWorkbenchLuaEditor(form.child,function() if valid() then d:UpdateActions() end end,valid) elseif d.code.released then d.code:Acquire(function() if valid() then d:UpdateActions() end end,valid) end
        d.code.frame:ClearAllPoints();d.code.frame:SetPoint('TOPLEFT',0,-form.y);d.code.frame:SetSize(form.width,310);d.code.frame:Show();d.code:SetText(d.model.value[d.selected]);form.y=form.y+318
        form.cleanups[#form.cleanups+1]=function() if d.code then if d.code.edit then d.code.edit:ClearFocus() end;d.code.frame:Hide() end end
    end)
    addon:SetUIScript(frame,'OnUpdate',function() if not valid() then d:Close() else d:UpdateActions() end end)
    addon:InstallCustomChangeReview(d);frame:Show();addon:RegisterWindowForEscape(d);d:UpdateActions();return d,d.owner
end
function addon:LayoutCustomConditionEditor(parent,update,key,source)
    if not parent.nativeCustomEditor then return end
    parent:FlushCode();parent.model:Change(function(model) model.key=key;model.value=self:CopySettingsData(source) end);parent.update=update;parent.form:Draw();parent:UpdateActions()
end
