local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local order={'evaluate','valid','print','widget','help','on_register','on_unregister'}
local labels={evaluate=L['Evaluate'],valid=L['Validate'],print=L['Summary'],widget=L['Fields UI'],help=L['Help'],on_register=L['On register'],on_unregister=L['On unregister']}
local function reason(why)
    return string.format(L['Check %s: %s'],why and (labels[why.callback] or why.field) or L['Definition'],why and (why.detail or why.reason) or L['Invalid custom condition.'])
end
function addon:condition_edit_box(update,key,source,saveAllowed,embedded)
    local d
    if embedded then d=embedded.editor else d=self.nativeCustomConditionDialog;if d and d.isEmbedded then d=nil end end
    if d and not d.closed then if d.OwnerValid and not d.OwnerValid() then d:Close() else d:Show();return d,d.owner end end
    d=d or {frame=CreateFrame('Frame',nil,embedded and embedded.parent or UIParent),nativeCustomEditor=true}
    d.embedded=embedded;d.isEmbedded=embedded~=nil;if embedded then embedded.editor=d end
    self.nativeCustomConditionDialog=d;d.closed=false;d.suspended=nil;d.validationRequested=false;d.codeHistory={};d.update=update;d.selected='evaluate';d.session=(d.session or 0)+1;local session=d.session;local frame=d.frame
    frame:ClearAllPoints();frame:EnableMouse(true)
    if embedded then
        frame:SetParent(embedded.parent);frame:SetSize(embedded.width,embedded.height);frame:SetPoint('TOPLEFT',embedded.x or 0,0)
    else
        frame:SetSize(960,740);frame:SetPoint('CENTER');frame:SetToplevel(true);frame:SetClampedToScreen(true);self:MakeWindowOpaque(frame)
        d.title=d.title or frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=d.chrome or self:CreateWorkbenchDialogChrome(frame,d.title)
    end
    d.close=d.close or self:CreateWorkbenchIconButton(frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5)
    d.help=d.help or self:CreateWorkbenchHelpButton(frame,L['Help']);d.help:SetPoint('TOPRIGHT',-28,-4)
    if embedded then d.close:Hide();d.help:SetPoint('TOPRIGHT',-4,-30) else d.close:Show() end
    d.body=d.body or CreateFrame('Frame',nil,frame);d.body:ClearAllPoints();d.body:SetPoint('TOPLEFT',embedded and 0 or 12,embedded and 0 or -34);d.body:SetSize(frame:GetWidth()-(embedded and 0 or 24),frame:GetHeight()-(embedded and 0 or 70))
    d.form=d.form or self:CreateSettingsForm(d.body);local p=d.form;p.fixedViewport=true;p:SetWidth(d.body:GetWidth());p:SetHeight(d.body:GetHeight())
    local profile,global=self.db.profile,self.db.global
    local function valid() return d.session==session and not d.closed and d.owner and d.owner.active and addon.db.profile==profile and addon.db.global==global and (not saveAllowed or saveAllowed()) end
    d.OwnerValid=valid
    d.owner=self:OwnCustomConditionDialog(d,nil,valid)
    d.originalKey=key;d.expected=(self.conditionDefinitions or {})[key];d.expectedSource=key and self:CopySettingsData((global.custom_conditions or {})[key]);d.model=self:NewCustomConditionDraft(key,self:PrepareCustomConditionEditorSource(source or self.empty_condition))
    local resume=embedded and embedded.resume
    if resume then
        d.model=resume.model;d.selected=resume.selected;d.codeHistory=resume.codeHistory;d.originalKey=resume.originalKey;d.expected=resume.expected;d.expectedSource=resume.expectedSource;d.validationRequested=resume.validationRequested;d.pendingRaw=resume.raw
    elseif embedded and embedded.initialize then embedded.initialize(d.model) end
    function d:SetCallback(event,callback) self[event]=callback end
    function d:ShowFooter(shown)
        for _,button in ipairs({self.apply,self.cancel,self.viewChanges}) do if shown then button:Show() else button:Hide() end end
    end
    function d:Show() if valid() then self.suspended=nil;self.frame:Show();self:ShowFooter(true);if not self.embedded then addon:RegisterWindowForEscape(self) end end end
    function d:HideForChild() self.suspended=true;self:ShowFooter(false);self.frame:Hide() end
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
    function d:CaptureDraft()
        self:FlushCode();local raw={}
        for _,record in ipairs(p.edits) do if record.dirty then
            for key,control in pairs(p.fields) do if control==record.control then raw[key]=control:GetText();break end end
        end end
        local schema=self.schemaEditor and self.schemaEditor.active and self.schemaEditor:CaptureDraft() or nil
        return {model=self.model,selected=self.selected,codeHistory=self.codeHistory,originalKey=self.originalKey,expected=self.expected,expectedSource=self.expectedSource,validationRequested=self.validationRequested,raw=raw,schema=schema}
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
        if self.schemaEditor and self.schemaEditor.active and self.schemaEditor:IsDirty() then return true end
        if self.embedded and self.embedded.dirty and self.embedded.dirty() then return true end
        if not addon:SettingsDataEqual({key=self.model.key,value=self:PendingSource(),context=self.model.context},self.model.baseline) then return true end
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
        if not addon:IsCustomConditionIdentifier(input.key,input.key==self.originalKey and self.expectedSource~=nil) then why={field='identifier',reason=L['Use letters, numbers and underscores for the condition identifier.']}
        else checked,why=addon:ValidateCustomConditionSource(input.key,source,input.key==self.originalKey and self.expectedSource~=nil) end
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
        if self.codeReset then
            local state=self:CodeState()
            if self.code:GetText()~=(self.model.baseline.value[self.selected] or '') then self.codeReset:Enable() else self.codeReset:Disable() end
            if #state.undo>0 then self.codeUndo:Enable() else self.codeUndo:Disable() end
            if #state.redo>0 then self.codeRedo:Enable() else self.codeRedo:Disable() end
        end
        addon:SetWorkbenchUnsaved(p.fields.schemaGraph,not addon:SettingsDataEqual(current.fields,before.value.fields) or not addon:SettingsDataEqual(current.fieldOrder,before.value.fieldOrder))
        if self.embedded and self.embedded.updateActions then self.embedded.updateActions(self) end
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
        for _,button in ipairs({self.apply,self.cancel,self.viewChanges}) do button:Hide() end
        if self.OnRelease then self:OnRelease() end
        addon:SetUIScript(self.frame,'OnUpdate',nil)
        self.OwnerValid=nil;self.codeHistory=nil;self.model=nil;self.expected=nil;self.expectedSource=nil;self.validationInput=nil;self.update=nil;self.embedded=nil;p.builder=nil;p.edits={};p.fields={};p.profile=nil;p.global=nil;p.char=nil
        if self.rmCustomTransferForm and self.rmCustomTransferForm.textDialog then local transfer=self.rmCustomTransferForm.textDialog;transfer.input:SetText('');transfer.options=nil end
    end
    function d:Apply()
        if self.schemaEditor and self.schemaEditor.active and not self.schemaEditor:Apply() then return false end
        if self.suspended then return false end
        self.validationRequested=true
        if not self:Flush() then self:UpdateActions();return false end
        self:UpdateActions()
        local identifier=self.model.key
        if identifier==self.originalKey and not addon:SettingsDataEqual((global.custom_conditions or {})[identifier],self.expectedSource) then p:Message(L['The custom condition changed elsewhere. Reopen it before saving.']);return false end
        local expected=identifier==self.originalKey and self.expected or nil
        local save=self.embedded and self.embedded.save
        local ok,why
        if save then ok,why=save(identifier,self:PendingSource(),expected,identifier==self.originalKey and self.expectedSource or nil)
        else ok,why=addon:InstallCustomCondition(identifier,self:PendingSource(),expected,identifier==self.originalKey and self.expectedSource or nil) end
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
        self.signature:SetText('function('..addon.CustomConditionCallbacks[name]..')');self:LayoutDocumentation()
        for key,button in pairs(self.functionTabs) do button:SetSelected(key==name) end
        self:UpdateActions()
    end
    function d:OpenSchema(fields,fieldOrder,childResume)
        return addon:ShowFieldSchemaEditor(self,fields,fieldOrder,function(value,ordered)
            if valid() then self.model:Change(function(model) model.value.fields=value;model.value.fieldOrder=ordered end);p:Draw();self:UpdateActions() end
        end,valid,childResume)
    end
    d.undo=d.undo or self:CreateWorkbenchHistoryButton(frame,'undo',L['Undo']);d.undo:SetPoint('BOTTOMLEFT',12,28)
    d.redo=d.redo or self:CreateWorkbenchHistoryButton(frame,'redo',L['Redo']);d.redo:SetPoint('BOTTOMLEFT',86,28)
    d.syntax=d.syntax or self:CreateWorkbenchButton(frame,L['Check syntax'],122);d.syntax:SetPoint('BOTTOMLEFT',164,28)
    d.transfer=d.transfer or self:CreateWorkbenchButton(frame,L['Import/Export'],126);d.transfer:SetPoint('BOTTOMLEFT',292,28)
    d.apply=d.apply or self:CreateWorkbenchButton(frame,L['Apply'],100);d.apply:SetPoint('BOTTOMRIGHT',-120,28)
    d.cancel=d.cancel or self:CreateWorkbenchButton(frame,L['Cancel'],100);d.cancel:SetPoint('BOTTOMRIGHT',-12,28)
    addon:SetUIScript(d.undo,'OnClick',function() if valid() and d:Flush() then if #d.model.undo>0 then if d:TravelModel(false) then p:Draw();d:UpdateActions() end else d:TravelCode(false) end end end)
    addon:SetUIScript(d.redo,'OnClick',function() if valid() and d:Flush() then if #d.model.redo>0 then if d:TravelModel(true) then p:Draw();d:UpdateActions() end else d:TravelCode(true) end end end)
    addon:SetUIScript(d.apply,'OnClick',function() if valid() then d:Apply() end end);addon:SetUIScript(d.cancel,'OnClick',function() if valid() then d:Close();if embedded and embedded.discard then embedded.discard() end end end);addon:SetUIScript(d.close,'OnClick',function() if valid() then d:Hide() end end)
    addon:SetUIScript(d.syntax,'OnClick',function() if not valid() then return end;d.validationRequested=true;if d:Flush() then local ok,why=addon:ValidateCustomConditionSource(d.model.key,d:PendingSource(),d.model.key==d.originalKey and d.expectedSource~=nil);p:Message(ok and L['Syntax checked. No custom code was executed.'] or reason(why)) end end)
    addon:SetUIScript(d.transfer,'OnClick',function() if valid() and d:Flush() then addon:ShowCustomConditionTransfer(d,update,d.model.key,d:PendingSource()) end end)
    addon:SetUIScript(d.help,'OnClick',function() if valid() then d.ownedHelp=addon:ShowWorkbenchHelp(L['Custom condition'],{
        {title=L['Editing code'],text=L['Each callback keeps its own pending text while switching tabs. Undo and Redo edit that callback buffer. Reset restores its last saved code, or the template for a new condition, and can be undone. The main Apply saves and registers all callback buffers and metadata; Discard drops the whole draft. Leaving with changes offers Apply, Discard or Cancel. Check syntax runs no callbacks.']},
        {title=labels[d.selected],text=addon:CustomConditionDocumentation(d.selected)},
        {title=L['Field schema'],text=L['Edit fields opens a graphical schema draft. Add, name, reorder or remove fields, choose primitive or nested types, and edit nested fields. Apply stages the schema and its field order. Advanced exposes the equivalent raw schema, parsed as data without executing Lua.']},
        {title=L['Trusted code'],text=L['Custom Lua has the same access as the addon. Only import code you trust. Syntax validation cannot establish that a callback is safe or correct. Existing custom widget callbacks still use their original UI contract.']}},frame);d.ownedHelpSections=d.ownedHelp.sections end end)
    p:Open(function(form)
        form.width=d.body:GetWidth();form.child:SetWidth(form.width);form:Layout()
        if d.chrome and not embedded then d.chrome:SetContext(L['Rotation Master']..': '..(d.model.value.description~='' and d.model.value.description or L['Custom condition']),L['Custom condition'],d.model.key) end
        if embedded and embedded.fields then embedded.fields(form,d) end
        local availability=form:Acquire('sourceAvailability',function() return addon:CreateWorkbenchPill(form.child,'',96) end)
        availability:SetText(d.model.value.disabled and L['Disabled'] or L['Enabled']);availability:SetSelected(not d.model.value.disabled);form.fields.definition_enabled=availability
        addon:SetUIScript(availability,'OnClick',function() if valid() and d:Flush() then d.model:Change(function(model) model.value.disabled=not model.value.disabled end);p:Draw();d:UpdateActions() end end)
        availability:ClearAllPoints();if form.fields.delete then availability:SetPoint('RIGHT',form.fields.delete,'LEFT',-6,0) else availability:SetPoint('TOPRIGHT',-4,-4) end
        if not embedded then form:Row(nil,24) end
        local identityY=form.y
        form:Edit('identifier',L['Identifier'],d.model.key,function(text) return addon:IsCustomConditionIdentifier(text,text==d.originalKey and d.expectedSource~=nil) and text or nil end,function(text) d.model:Change(function(model) model.key=text end) end)
        local identifierLabel=form.pool.labels[form.counts.labels]
        identifierLabel:ClearAllPoints();identifierLabel:SetPoint('TOPLEFT',64,-identityY);identifierLabel:SetWidth(104)
        local identifier=form.fields.identifier
        identifier:ClearAllPoints();identifier:SetPoint('TOPLEFT',174,-identityY);identifier:SetWidth(form.width-174)
        identifier:SetMaxLetters(d.model.key==d.originalKey and d.expectedSource and math.max(256,#d.originalKey) or 256)
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
        if d.originalKey and d.model.key==d.originalKey then identifier:EnableMouse(false) end
        local descriptionY=form.y
        form:Edit('description',L['Description'],d.model.value.description,nil,function(text) d.model:Change(function(model) model.value.description=text end) end)
        local descriptionLabel=form.pool.labels[form.counts.labels]
        descriptionLabel:ClearAllPoints();descriptionLabel:SetPoint('TOPLEFT',64,-descriptionY);descriptionLabel:SetWidth(104)
        form.fields.description:ClearAllPoints();form.fields.description:SetPoint('TOPLEFT',174,-descriptionY);form.fields.description:SetWidth(form.width-174)
        local icon=form:Acquire('sourceIcon',function() return addon:CreateWorkbenchButton(form.child,'',52) end);form.fields.icon=icon;icon.tooltip=L['Choose icon'];icon:ClearAllPoints();icon:SetPoint('TOPLEFT',0,-identityY);icon:SetSize(52,52)
        addon:SetUIScript(icon,'OnClick',function()
            if not valid() then return end
            if not d:Flush() then return end
            d.ownedPicker=addon:ShowWorkbenchIconPicker(d.model.value.icon,function(texture) if valid() and d:Flush() then d.model:Change(function(model) model.value.icon=texture end);p:Draw() end end,valid)
            d.ownedPickerSerial=d.ownedPicker.serial
        end)
        icon.texture=icon.texture or icon:CreateTexture(nil,'ARTWORK');icon.texture:SetTexture(d.model.value.icon);icon.texture:SetAllPoints(icon)
        if embedded and embedded.category then embedded.category(form,d) end
        addon:BuildCustomSourceFields(form,d)
        local tabWidth=(form.width-3*(#order-1))/#order;local y=form:Row(nil,26)
        d.functionTabs={}
        for i,name in ipairs(order) do
            local button=form:Acquire('functionTabs',function() return addon:CreateWorkbenchButton(form.child,'',tabWidth) end);button:ClearAllPoints();button:SetPoint('TOPLEFT',(i-1)*(tabWidth+3),-y);button:SetSize(tabWidth,22);button:SetText(labels[name]);button.tooltip=labels[name];d.functionTabs[name]=button;button:SetSelected(name==d.selected);addon:SetUIScript(button,'OnClick',form:Guard(function() d:SelectFunction(name) end))
            local caption=button:GetFontString();caption:SetFontObject('GameFontHighlightSmall')
            if caption.GetFont and caption:GetStringWidth()>tabWidth-6 then local font,size=caption:GetFont();caption:SetFont(font,math.max(8,size*(tabWidth-6)/caption:GetStringWidth()),'') end
        end
        local actionY=form.y
        for index,entry in ipairs({{'codeUndo','undo',L['Undo']},{'codeRedo','redo',L['Redo']},{'codeReset',nil,L['Reset']}}) do
            local control=form:Acquire('callbackActions',function() return entry[2] and addon:CreateWorkbenchHistoryButton(form.child,entry[2],entry[3]) or addon:CreateWorkbenchButton(form.child,entry[3],68) end)
            control:ClearAllPoints();control:SetPoint('TOPLEFT',(index-1)*74,-actionY);control:SetWidth(68);control:SetText(entry[3]);d[entry[1]]=control
            addon:SetUIScript(control,'OnClick',function()
                if not valid() then return end
                if entry[1]=='codeUndo' or entry[1]=='codeRedo' then d:TravelCode(entry[1]=='codeRedo')
                else
                    d.loadingCode=true;d.code:SetText(d.model.baseline.value[d.selected] or '');d.loadingCode=false;d:CodeChanged()
                end
            end)
        end
        d.signature=form:Acquire('callbackSignature',function() local text=form.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');text:SetJustifyH('LEFT');return text end);d.signature:SetText('function('..addon.CustomConditionCallbacks[d.selected]..')')
        d.documentation=form:Acquire('callbackDocs',function() local text=form.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');text:SetJustifyH('LEFT');text:SetWordWrap(true);return text end)
        d.documentationTop=form.y
        function d:LayoutDocumentation()
            self.documentation:ClearAllPoints();self.documentation:SetPoint('TOPLEFT',0,-self.documentationTop);self.documentation:SetWidth(form.width-30);self.documentation:SetText(addon:CustomConditionDocumentation(self.selected));self.documentation:SetHeight(0)
            self.compactDocumentation=form.frame:GetHeight()-(self.documentationTop+self.documentation:GetStringHeight()+56+24)<100
            if self.compactDocumentation then self.documentation:SetText(addon.CustomConditionCallbackDocs[self.selected].description) end
            if embedded then self.help:SetParent(form.child);self.help:ClearAllPoints();self.help:SetPoint('TOPRIGHT',0,-self.documentationTop) end
            local actionTop=self.documentationTop+self.documentation:GetStringHeight()+8
            for index,control in ipairs({self.codeUndo,self.codeRedo,self.codeReset}) do control:ClearAllPoints();control:SetPoint('TOPLEFT',(index-1)*74,-actionTop) end
            self.syntax:SetParent(form.child);self.syntax:ClearAllPoints();self.syntax:SetPoint('TOPLEFT',222,-actionTop);self.syntax:Show()
            local signatureTop=actionTop+26
            self.signature:ClearAllPoints();self.signature:SetPoint('TOPLEFT',0,-signatureTop);self.signature:SetWidth(form.width);self.signature:SetHeight(18)
            local codeTop=signatureTop+22
            local codeHeight=math.max(60,form.frame:GetHeight()-codeTop-24)
            if self.code then self.code.frame:ClearAllPoints();self.code.frame:SetPoint('TOPLEFT',0,-codeTop);self.code.frame:SetSize(form.width,codeHeight) end
            form.y=codeTop+codeHeight;form.child:SetHeight(form.y+12);form.scroll:Hide()
        end
        local preference=addon.db.profile.lua_editor or 'auto'
        if d.code and (d.code.preference~=preference or d.code.released and not d.code.Acquire) then d.code:Release();d.code=nil end
        if not d.code then d.code=addon:CreateWorkbenchLuaEditor(form.child,function() if valid() then d:CodeChanged() end end,valid);d.code.preference=preference elseif d.code.released then d.code:Acquire(function() if valid() then d:CodeChanged() end end,valid) end
        if d.code.SetCloseHandler then d.code:SetCloseHandler(function(mouse)
            if not valid() then return end
            if embedded and embedded.closeOwner then embedded.closeOwner(mouse) else d:Hide() end
        end) end
        d.code.frame:ClearAllPoints();d.code.frame:SetPoint('TOPLEFT',0,-form.y);d.code.frame:SetSize(form.width,310);d.code.frame:Show();d:SetCode(d:CodeState().text);d:LayoutDocumentation()
        if d.pendingRaw then
            for _,record in ipairs(form.edits) do for key,text in pairs(d.pendingRaw) do if form.fields[key]==record.control then record.control:SetText(text);record.dirty=true end end end
            d.pendingRaw=nil
        end
        form.cleanups[#form.cleanups+1]=function() if d.code then if d.code.edit then d.code.edit:ClearFocus() end;d.code.frame:Hide() end end
    end)
    function d:ResizeHeight(height)
        if math.abs(self.frame:GetHeight()-height)<.1 then return end
        self.frame:SetHeight(height);self.body:SetHeight(height-(self.embedded and 0 or 70));self.form:SetHeight(self.body:GetHeight());self:LayoutDocumentation()
    end
    addon:SetUIScript(frame,'OnUpdate',function() if not valid() then d:Close() else d:UpdateActions() end end)
    addon:InstallCustomChangeReview(d)
    d.undo:Hide();d.redo:Hide();d.apply:Show();d.cancel:Show();d.viewChanges:Show()
    if embedded then
        local footer=embedded.footer or frame;d.apply:SetParent(footer);d.cancel:SetParent(footer);d.viewChanges:SetParent(footer);d.transfer:Hide()
        d.apply:ClearAllPoints();d.apply:SetPoint('BOTTOMRIGHT',-108,4);d.cancel:ClearAllPoints();d.cancel:SetPoint('BOTTOMRIGHT',-8,4);d.cancel:SetWidth(92);d.cancel:SetText(L['Discard'])
        d.viewChanges:ClearAllPoints();d.viewChanges:SetPoint('RIGHT',d.apply,'LEFT',-6,0)
    else d.transfer:Show();d.cancel:SetText(L['Cancel']);addon:RegisterWindowForEscape(d) end
    frame:Show();d:UpdateActions()
    if resume and resume.schema then d:OpenSchema(d.model.value.fields,d.model.value.fieldOrder,resume.schema) end
    return d,d.owner
end
function addon:LayoutCustomConditionEditor(parent,update,key,source)
    if not parent.nativeCustomEditor then return end
    parent:FlushCode();parent.codeHistory={};parent.model:Change(function(model) model.key=key;model.value=self:PrepareCustomConditionEditorSource(source) end);parent.update=update;parent.form:Draw();parent:UpdateActions()
end
