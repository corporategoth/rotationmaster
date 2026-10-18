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
    self.nativeCustomConditionDialog=d;d.closed=false;d.validationRequested=false;d.codeHistory={};d.update=update;d.selected='evaluate';d.session=(d.session or 0)+1;local session=d.session;local frame=d.frame
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
    function d:CodeState()
        local state=self.codeHistory[self.selected]
        if not state then state={text=self.model.value[self.selected],undo={},redo={}};self.codeHistory[self.selected]=state end
        return state
    end
    function d:CodeChanged()
        if self.loadingCode or not self.code then return end
        local state=self:CodeState();local text=self.code:GetText()
        if text~=state.text then
            state.undo[#state.undo+1]=state.text;state.redo={};state.text=text
            local bytes=0;for _,value in ipairs(state.undo) do bytes=bytes+#value end
            while #state.undo>100 or bytes>4194304 do bytes=bytes-#table.remove(state.undo,1) end
        end
        self:UpdateActions()
    end
    function d:SetCode(text)
        self.loadingCode=true;self.code:SetText(text);self.loadingCode=false;self:CodeState().text=text
    end
    function d:TravelCode(redo)
        local state=self:CodeState();local from=redo and state.redo or state.undo;local to=redo and state.undo or state.redo
        if #from==0 then return end
        to[#to+1]=self.code:GetText();self:SetCode(table.remove(from));self:UpdateActions()
    end
    function d:FlushCode()
        if self.code then self:CodeState().text=self.code:GetText() end
    end
    function d:PendingSource()
        self:FlushCode();local source=addon:CopySettingsData(self.model.value)
        for name,state in pairs(self.codeHistory) do source[name]=state.text end
        return source
    end
    function d:CommitCode()
        local source=self:PendingSource();for name in pairs(addon.CustomConditionCallbacks) do self.model:SetFunction(name,source[name]) end
    end
    function d:TravelModel(redo)
        local before=addon:CopySettingsData(self.model.value)
        if not self.model:Travel(redo) then return false end
        for name,state in pairs(self.codeHistory) do if state.text==before[name] then state.text=self.model.value[name] end end
        return true
    end
    function d:Flush()
        if not valid() or not p:FlushEdits() then return false end;self:FlushCode();return true
    end
    function d:IsDirty()
        if self.model:IsDirty() then return true end
        local source=self:PendingSource();for name in pairs(addon.CustomConditionCallbacks) do if source[name]~=self.model.baseline.value[name] then return true end end
        for _,edit in ipairs(p.edits) do if edit.dirty then return true end end;return false
    end
    function d:UpdateValidation()
        if not self.code then return end
        local input={disabled=self.model.value.disabled,selected=self.selected,requested=self.validationRequested,key=p.fields.identifier:GetText(),description=p.fields.description:GetText(),schema=p.fields.schema:GetText(),icon=self.model.value.icon}
        for name in pairs(addon.CustomConditionCallbacks) do input[name]=name==self.selected and self.code:GetText() or self.codeHistory[name] and self.codeHistory[name].text or self.model.value[name] end
        if addon:SettingsDataEqual(input,self.validationInput) then return end
        self.validationInput=addon:CopySettingsData(input)
        local source=addon:CopySettingsData(self.model.value);source.description=input.description;source.fields=addon:ParseCustomFieldSchema(input.schema)
        for name in pairs(addon.CustomConditionCallbacks) do source[name]=input[name] end
        local checked,why
        if not addon:IsCustomConditionIdentifier(input.key,self.expectedSource~=nil) then why={field='identifier',reason=L['Use letters, numbers and underscores for the condition identifier.']}
        else checked,why=addon:ValidateCustomConditionSource(input.key,source,self.expectedSource~=nil) end
        local message=not checked and reason(why) or nil
        local callbackErrors={}
        for name,button in pairs(self.functionTabs or {}) do
            local compiled,syntax=addon:CompileCustomConditionCallback(input.key,name,input[name]);callbackErrors[name]=not compiled and syntax or nil
            addon:SetWorkbenchInvalid(button,not compiled,syntax);button.tooltip=not compiled and syntax or nil
        end
        addon:SetWorkbenchInvalid(self.code.frame,callbackErrors[self.selected]~=nil,callbackErrors[self.selected])
        for _,field in ipairs({'identifier','description','schema','icon'}) do addon:SetWorkbenchInvalid(p.fields[field],self.validationRequested and not checked and why and (why.field==field or field=='schema' and why.field=='fields'),message) end
    end
    function d:UpdateActions()
        if self.closed then return end
        if #self.model.undo>0 or #self:CodeState().undo>0 then self.undo:Enable() else self.undo:Disable() end
        if #self.model.redo>0 or #self:CodeState().redo>0 then self.redo:Enable() else self.redo:Disable() end
        if self:IsDirty() then self.apply:Enable() else self.apply:Disable() end
        local before=self.model.baseline;local current=self.model.value
        for _,entry in ipairs({{'definition_enabled',not current.disabled,not before.value.disabled},{'identifier',self.model.key,before.key},{'description',current.description,before.value.description},{'schema',addon:FormatCustomFieldSchema(current.fields),addon:FormatCustomFieldSchema(before.value.fields)},{'icon',current.icon,before.value.icon}}) do
            local input=p.fields[entry[1]];local dirty=not addon:UnsavedDataEqual(entry[2],entry[3]);for _,record in ipairs(p.edits) do if record.control==input and record.dirty then dirty=input:GetText()~=tostring(entry[3] or '') end end;addon:SetWorkbenchUnsaved(input,dirty)
        end
        if self.code then addon:SetWorkbenchUnsaved(self.code.frame,self.code:GetText()~=(before.value[self.selected] or '')) end
        for name,button in pairs(self.functionTabs or {}) do addon:SetWorkbenchUnsaved(button,(self.codeHistory[name] and self.codeHistory[name].text or current[name])~=before.value[name]) end
        if self.codeApply then
            local state=self:CodeState();local pending=self.code:GetText()~=self.model.value[self.selected]
            if pending then self.codeApply:Enable();self.codeCancel:Enable() else self.codeApply:Disable();self.codeCancel:Disable() end
            if #state.undo>0 then self.codeUndo:Enable() else self.codeUndo:Disable() end
            if #state.redo>0 then self.codeRedo:Enable() else self.codeRedo:Disable() end
        end
        self:UpdateValidation()
    end
    function d:Close()
        if self.closed then return end;self.closed=true;self.owner.active=false
        local children={};for child in pairs(self.owner.widgets) do if child~=self then children[#children+1]=child end end
        for _,child in ipairs(children) do child:Hide() end
        if self.schemaEditor and self.schemaEditor.active then self.schemaEditor:Close() end
        if self.ownedPicker and self.ownedPicker.serial==self.ownedPickerSerial then self.ownedPicker.frame:Hide() end
        if self.ownedHelp and self.ownedHelp.sections==self.ownedHelpSections then self.ownedHelp:Hide() end
        self.ownedPicker=nil;self.ownedHelp=nil;self.ownedHelpSections=nil
        if self.code then pcall(self.code.Release,self.code) end;p:Release();self.frame:Hide()
        if self.OnRelease then self:OnRelease() end
        addon:SetUIScript(self.frame,'OnUpdate',nil)
        self.OwnerValid=nil;self.codeHistory=nil;self.model=nil;self.expected=nil;self.expectedSource=nil;self.validationInput=nil;self.update=nil;p.builder=nil;p.edits={};p.fields={};p.profile=nil;p.global=nil;p.char=nil
        if self.rmCustomTransferForm and self.rmCustomTransferForm.textDialog then local transfer=self.rmCustomTransferForm.textDialog;transfer.input:SetText('');transfer.options=nil end
    end
    function d:Apply()
        self.validationRequested=true
        if not self:Flush() then self:UpdateActions();return false end
        self:UpdateActions()
        local identifier=self.model.key
        if identifier==self.originalKey and not addon:SettingsDataEqual((global.custom_conditions or {})[identifier],self.expectedSource) then p:Message(L['The custom condition changed elsewhere. Reopen it before saving.']);return false end
        local expected=identifier==self.originalKey and self.expected or nil
        local ok,why=addon:InstallCustomCondition(identifier,self:PendingSource(),expected,identifier==self.originalKey and self.expectedSource or nil)
        if not ok then p:Message(reason(why));self:UpdateActions();return false end
        self:CommitCode();local notify=self.update;self.model:MarkSaved();self:Close();notify(identifier);return true
    end
    function d:Hide()
        if self.closed then return end
        if not valid() then self:Close();return end
        if not self:IsDirty() then self:Close();return end
        p:ConfirmPending(function() self:Apply() end,function() self:Close() end);p.prompt.frame:SetParent(UIParent);addon:RegisterWindowForEscape(p.prompt)
    end
    function d:SelectFunction(name)
        if not valid() or not addon.CustomConditionCallbacks[name] then return end
        self:FlushCode();self.selected=name;self:SetCode(self:CodeState().text)
        self.signature:SetText('function('..addon.CustomConditionCallbacks[name]..')')
        for key,button in pairs(self.functionTabs) do button:SetSelected(key==name) end
        self:UpdateActions()
    end
    d.undo=d.undo or self:CreateWorkbenchHistoryButton(frame,'undo',L['Undo']);d.undo:SetPoint('BOTTOMLEFT',12,28)
    d.redo=d.redo or self:CreateWorkbenchHistoryButton(frame,'redo',L['Redo']);d.redo:SetPoint('BOTTOMLEFT',86,28)
    d.syntax=d.syntax or self:CreateWorkbenchButton(frame,L['Check syntax'],122);d.syntax:SetPoint('BOTTOMLEFT',164,28)
    d.transfer=d.transfer or self:CreateWorkbenchButton(frame,L['Import/Export'],126);d.transfer:SetPoint('BOTTOMLEFT',292,28)
    d.apply=d.apply or self:CreateWorkbenchButton(frame,L['Apply'],100);d.apply:SetPoint('BOTTOMRIGHT',-120,28)
    d.cancel=d.cancel or self:CreateWorkbenchButton(frame,L['Cancel'],100);d.cancel:SetPoint('BOTTOMRIGHT',-12,28)
    addon:SetUIScript(d.undo,'OnClick',function() if valid() and d:Flush() then if #d.model.undo>0 then if d:TravelModel(false) then p:Draw();d:UpdateActions() end else d:TravelCode(false) end end end)
    addon:SetUIScript(d.redo,'OnClick',function() if valid() and d:Flush() then if #d.model.redo>0 then if d:TravelModel(true) then p:Draw();d:UpdateActions() end else d:TravelCode(true) end end end)
    addon:SetUIScript(d.apply,'OnClick',function() if valid() then d:Apply() end end);addon:SetUIScript(d.cancel,'OnClick',function() if valid() then d:Close() end end);addon:SetUIScript(d.close,'OnClick',function() if valid() then d:Hide() end end)
    addon:SetUIScript(d.syntax,'OnClick',function() if not valid() then return end;d.validationRequested=true;if d:Flush() then local ok,why=addon:ValidateCustomConditionSource(d.model.key,d:PendingSource(),d.model.key==d.originalKey and d.expectedSource~=nil);p:Message(ok and L['Syntax checked. No custom code was executed.'] or reason(why)) end end)
    addon:SetUIScript(d.transfer,'OnClick',function() if valid() and d:Flush() then addon:ShowCustomConditionTransfer(d,update,d.model.key,d:PendingSource()) end end)
    addon:SetUIScript(d.help,'OnClick',function() if valid() then d.ownedHelp=addon:ShowWorkbenchHelp(L['Custom condition'],{
        {title=L['Editing code'],text=L['Each callback keeps its own pending text while switching tabs. Its Apply stages the code; its Cancel restores the staged code. The callback Undo and Redo buttons edit its buffer. The main Apply saves and registers the whole condition; the main Cancel discards the whole draft. Check syntax runs no callbacks.']},
        {title=L['Field schema'],text=L['Edit fields opens a graphical schema draft. Add, name, reorder or remove fields, choose primitive or nested types, and edit nested fields. Apply stages the schema and its field order. Advanced exposes the equivalent raw schema, parsed as data without executing Lua.']},
        {title=L['Trusted code'],text=L['Custom Lua has the same access as the addon. Only import code you trust. Syntax validation cannot establish that a callback is safe or correct. Existing custom widget callbacks still use their original UI contract.']}},frame);d.ownedHelpSections=d.ownedHelp.sections end end)
    p:Open(function(form)
        d.chrome:SetContext(L['Rotation Master']..': '..(d.model.value.description~='' and d.model.value.description or L['Custom condition']),L['Custom condition'],d.model.key)
        form:Toggle('definition_enabled',L['Availability'],not d.model.value.disabled,L['Disabled'],L['Enabled'],function(value) d:FlushCode();d.model:Change(function(model) model.value.disabled=not value end);p:Draw();d:UpdateActions() end)
        form:Edit('identifier',L['Identifier'],d.model.key,function(text) return addon:IsCustomConditionIdentifier(text,d.expectedSource~=nil) and text or nil end,function(text) d.model:Change(function(model) model.key=text end) end)
        local identifier=form.fields.identifier
        identifier:SetMaxLetters(d.expectedSource and math.max(256,#d.originalKey) or 256)
        local changed=identifier:GetScript('OnTextChanged')
        addon:SetUIScript(identifier,'OnTextChanged',function(control,user)
            if user and valid() then
                local text=control:GetText();local filtered=text:gsub('[^A-Za-z0-9_]','')
                if filtered~=text then
                    local cursor=control:GetCursorPosition();local before=text:sub(1,cursor):gsub('[^A-Za-z0-9_]','')
                    control:SetText(filtered);control:SetCursorPosition(#before)
                end
            end
            if changed then changed(control,user) end
        end)
        if d.originalKey then identifier:EnableMouse(false) end
        form:Edit('description',L['Description'],d.model.value.description,nil,function(text) d.model:Change(function(model) model.value.description=text end) end)
        local icon=form:Button('icon',L['Choose icon'],function()
            if not d:Flush() then return end
            d.ownedPicker=addon:ShowWorkbenchIconPicker(d.model.value.icon,function(texture) if valid() and d:Flush() then d.model:Change(function(model) model.value.icon=texture end);p:Draw() end end,valid)
            d.ownedPickerSerial=d.ownedPicker.serial
        end)
        icon.texture=icon.texture or icon:CreateTexture(nil,'ARTWORK');icon.texture:SetTexture(d.model.value.icon);icon.texture:SetSize(24,24);icon.texture:SetPoint('LEFT',4,0);addon:AlignWorkbenchTextLeft(icon,34)
        form:Edit('schema',L['Field schema'],addon:FormatCustomFieldSchema(d.model.value.fields) or '',function(text) return addon:ParseCustomFieldSchema(text) end,function(fields) d.model:Change(function(model) model.value.fields=fields;model.value.fieldOrder=nil end) end)
        form.fields.schema:SetMaxLetters(32768);form.fields.schema:SetText(addon:FormatCustomFieldSchema(d.model.value.fields) or '')
        local schema=form.fields.schema;local schemaY=form.y-28
        local graph=form:Button('schemaGraph',L['Edit fields'],function()
            d:FlushCode()
            local parsed=addon:ParseCustomFieldSchema(schema:GetText());if not parsed then form:Message(L['Invalid custom condition.']);return end
            local fieldOrder=addon:SettingsDataEqual(parsed,d.model.value.fields) and d.model.value.fieldOrder or nil
            addon:ShowFieldSchemaEditor(d,parsed,fieldOrder,function(fields,order)
                if valid() then d.model:Change(function(model) model.value.fields=fields;model.value.fieldOrder=order end);p:Draw();d:UpdateActions() end
            end,valid)
        end)
        graph:ClearAllPoints();graph:SetPoint('TOPLEFT',220,-schemaY);graph:SetWidth(math.max(80,form.width-312));form.y=form.y-28
        local advanced=form:Button('advancedSchema',L['Advanced'],function() d.advancedSchema=not d.advancedSchema;if d.advancedSchema then schema:Show();graph:Hide() else schema:Hide();graph:Show() end end)
        advanced:ClearAllPoints();advanced:SetPoint('TOPRIGHT',0,-schemaY);advanced:SetWidth(84);form.y=form.y-28;schema:SetWidth(math.max(80,form.width-312))
        if d.advancedSchema then graph:Hide() else schema:Hide() end
        local y=form:Row(nil,28)
        d.functionTabs={}
        for i,name in ipairs(order) do
            local button=form:Acquire('functionTabs',function() return addon:CreateWorkbenchButton(form.child,'',102) end);button:ClearAllPoints();button:SetPoint('TOPLEFT',(i-1)*106,-y);button:SetSize(102,24);button:SetText(labels[name]);d.functionTabs[name]=button;button:SetSelected(name==d.selected);addon:SetUIScript(button,'OnClick',form:Guard(function() d:SelectFunction(name) end))
        end
        local actionY=form:Row(nil,28)
        for index,entry in ipairs({{'codeUndo','undo',L['Undo']},{'codeRedo','redo',L['Redo']},{'codeApply',nil,L['Apply']},{'codeCancel',nil,L['Cancel']}}) do
            local control=form:Acquire('callbackActions',function() return entry[2] and addon:CreateWorkbenchHistoryButton(form.child,entry[2],entry[3]) or addon:CreateWorkbenchButton(form.child,entry[3],68) end)
            control:ClearAllPoints();control:SetPoint('TOPLEFT',(index-1)*74,-actionY);control:SetWidth(68);control:SetText(entry[3]);d[entry[1]]=control
            addon:SetUIScript(control,'OnClick',function()
                if not valid() then return end
                if entry[1]=='codeUndo' or entry[1]=='codeRedo' then d:TravelCode(entry[1]=='codeRedo')
                elseif entry[1]=='codeCancel' then d:SetCode(d.model.value[d.selected]);d.codeHistory[d.selected]={text=d.model.value[d.selected],undo={},redo={}};d:UpdateActions()
                else
                    local ok,why=addon:CompileCustomConditionCallback(d.model.key,d.selected,d.code:GetText())
                    if not ok then form:Message(why);d:UpdateActions();return end
                    d.model:SetFunction(d.selected,d.code:GetText());d:UpdateActions()
                end
            end)
        end
        d.signature=form:Text('function('..addon.CustomConditionCallbacks[d.selected]..')')
        local preference=addon.db.profile.lua_editor or 'auto'
        if d.code and (d.code.preference~=preference or d.code.released and not d.code.Acquire) then d.code:Release();d.code=nil end
        if not d.code then d.code=addon:CreateWorkbenchLuaEditor(form.child,function() if valid() then d:CodeChanged() end end,valid);d.code.preference=preference elseif d.code.released then d.code:Acquire(function() if valid() then d:CodeChanged() end end,valid) end
        d.code.frame:ClearAllPoints();d.code.frame:SetPoint('TOPLEFT',0,-form.y);d.code.frame:SetSize(form.width,310);d.code.frame:Show();d:SetCode(d:CodeState().text);form.y=form.y+318
        form.cleanups[#form.cleanups+1]=function() if d.code then if d.code.edit then d.code.edit:ClearFocus() end;d.code.frame:Hide() end end
    end)
    addon:SetUIScript(frame,'OnUpdate',function() if not valid() then d:Close() else d:UpdateActions() end end)
    addon:InstallCustomChangeReview(d);frame:Show();addon:RegisterWindowForEscape(d);d:UpdateActions();return d,d.owner
end
function addon:LayoutCustomConditionEditor(parent,update,key,source)
    if not parent.nativeCustomEditor then return end
    parent:FlushCode();parent.codeHistory={};parent.model:Change(function(model) model.key=key;model.value=self:CopySettingsData(source) end);parent.update=update;parent.form:Draw();parent:UpdateActions()
end
