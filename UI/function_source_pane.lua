local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local actionLabels={codeUndo=L['Undo'],codeRedo=L['Redo'],codeReset=L['Reset'],syntax=L['Check syntax']}
local function enable(control,enabled) if enabled then control:Enable() else control:Disable() end end
local function splitType(value)
    local parts,nullable={},false
    for part in tostring(value or 'any'):gmatch('[^|]+') do
        part=part:match('^%s*(.-)%s*$');if part=='nil' then nullable=true else parts[#parts+1]=part end
    end
    return #parts>0 and table.concat(parts,' | ') or 'any',nullable
end
local function typeChoices(addon,current)
    local names={};for _,name in ipairs({'any','boolean','number','string','table','function','thread','userdata'}) do names[name]=true end
    local function collect(source)
        for _,field in ipairs({'args','returns'}) do for _,record in ipairs(source and source[field] or {}) do local base=splitType(record.type);names[base]=true;for part in base:gmatch('[^|]+') do names[part:match('^%s*(.-)%s*$')]=true end end end
    end
    for _,record in pairs(addon.builtinFunctions or {}) do collect(record.source) end
    for _,source in pairs(addon.db.global.custom_functions or {}) do collect(source) end
    names[current]=true;local sorted={};for name in pairs(names) do sorted[#sorted+1]=name end;table.sort(sorted)
    local entries={};for _,name in ipairs(sorted) do entries[#entries+1]={value=name,text=name} end;return entries
end
local function clearNew(p) p.newFunctionID=nil;p.newFunctionSource=nil;p.functionResume=nil end
function addon:InstallInlineFunctionNavigation(p)
    if p.functionNavigation then return end;p.functionNavigation=true
    local draw,leave,release,layout=p.Draw,p.RequestLeave,p.Release,p.Layout
    function p:Draw()
        local d=self.inlineFunction
        self.functionResume=d and not d.closed and d.OwnerValid() and d.key==(self.newFunctionID or self.functionID) and d:CaptureDraft() or nil
        return draw(self)
    end
    function p:RequestLeave(callback)
        local d=self.inlineFunction
        if d and not d.closed and d.OwnerValid() and d:IsDirty() then
            self:ConfirmPending(function() if d.OwnerValid() and d:Apply() then callback() end end,function()
                if not d.OwnerValid() then return end;d:Close();self.inlineFunction=nil;self:DiscardSettingsDraft();clearNew(self);callback()
            end);return false
        end
        return leave(self,callback)
    end
    function p:Layout() layout(self);local d=self.inlineFunction;if d and not d.closed and d.OwnerValid() then d.frame:SetHeight(math.max(160,self.frame:GetHeight()-36));d.form:SetHeight(d.frame:GetHeight());d.form:Layout() end end
    function p:Release() clearNew(self);release(self);self.inlineFunction=nil end
end
function addon:FunctionSignature(id,source)
    local args,returns={},{};for _,arg in ipairs(source.args or {}) do args[#args+1]=(arg.name or '?')..': '..(arg.type or '?') end
    for _,result in ipairs(source.returns or {}) do returns[#returns+1]=result.type or '?' end
    return (source.name or id)..'('..table.concat(args,', ')..')'..(#returns>0 and ' -> '..table.concat(returns,', ') or '')
end
function addon:BuildInlineFunction(p,key,source,readOnly)
    local d=p.functionEditorCache or {frame=CreateFrame('Frame',nil,p.frame)};p.functionEditorCache=d;p.inlineFunction=d
    local resume=p.functionResume;p.functionResume=nil
    d.closed=false;d.key=key;d.readOnly=readOnly==true;d.value=self:CopySettingsData(source);if not d.readOnly then d.value.code=self:NormalizeLuaSourceForEditor(d.value.code);if self.FunctionEditorName then d.value.name=self:FunctionEditorName(key,d.value) end end;d.codeExpanded=false;d.baseline=self:CopySettingsData(d.value);d.expected=self:CopySettingsData((self.db.global.custom_functions or {})[key]);d.isNew=p.newFunctionSource~=nil;d.deleting=false;d.undo={};d.redo={};d.validationInput=nil;d.contextInput=nil;d.session=(d.session or 0)+1
    if resume then for field,value in pairs(resume) do d[field]=value end end
    local token,session=p.generation,d.session
    local function valid() return not d.closed and d.session==session and p:Valid(token) end;d.OwnerValid=valid
    local geometry=self:GetWorkbenchRosterGeometry(p.frame:GetWidth(),p.frame:GetHeight())
    d.frame:SetParent(p.frame);d.frame:ClearAllPoints();d.frame:SetPoint('TOPLEFT',geometry.detailX,0);d.frame:SetSize(geometry.detailWidth,math.max(160,p.frame:GetHeight()-36))
    d.form=d.form or self:CreateSettingsForm(d.frame);local form=d.form;form.unsavedDefaults={};form:SetWidth(d.frame:GetWidth());form:SetHeight(d.frame:GetHeight())
    function d:PendingSource() local value=addon:CopySettingsData(self.value);if not self.readOnly and self.code and not self.code.released then value.code=self.code:GetText() end;return value end
    function d:CaptureDraft()
        local raw={};for _,record in ipairs(form.edits) do if record.dirty then for name,control in pairs(form.fields) do if control==record.control then raw[name]=record.control:GetText() end end end end
        return {value=self:PendingSource(),baseline=self.baseline,expected=self.expected,isNew=self.isNew,deleting=self.deleting,undo=self.undo,redo=self.redo,pendingRaw=raw,codeExpanded=self.codeExpanded}
    end
    function d:IsDirty()
        if self.readOnly then return false end
        if self.isNew or self.deleting or not addon:SettingsDataEqual(self:PendingSource(),self.baseline) then return true end
        for _,record in ipairs(form.edits) do if record.dirty and record.control:GetText()~=record.baseline then return true end end;return false
    end
    function d:Flush() return valid() and form:FlushEdits() end
    function d:CodeChanged()
        if self.loading or self.readOnly or not self.code then return end
        local text=self.code:GetText();if text~=self.value.code then self.undo[#self.undo+1]=self.value.code;self.redo={};self.value.code=text;while #self.undo>100 do table.remove(self.undo,1) end end;self:UpdateActions()
    end
    function d:SetCode(text) self.loading=true;self.code:SetText(self.readOnly and addon.FormatLuaSourceDisplay and addon:FormatLuaSourceDisplay(text) or text);self.loading=false;self.value.code=text end
    function d:TravelCode(redo)
        if not valid() or self.readOnly then return end
        local from,to=redo and self.redo or self.undo,redo and self.undo or self.redo
        if #from>0 then to[#to+1]=self.code:GetText();self:SetCode(table.remove(from));self:UpdateActions() end
    end
    function d:UpdateActions()
        if not valid() or not self.apply then return end
        local dirty=self:IsDirty();enable(self.apply,dirty);enable(self.viewChanges,dirty);enable(self.codeUndo,not self.readOnly and #self.undo>0);enable(self.codeRedo,not self.readOnly and #self.redo>0);enable(self.codeReset,not self.readOnly and self.code:GetText()~=self.baseline.code)
        addon:SetWorkbenchUnsaved(self.code.frame,not self.readOnly and self.code:GetText()~=self.baseline.code);addon:SetWorkbenchUnsaved(form.fields.definition_enabled,not not self.value.disabled~=not not self.baseline.disabled)
        for _,record in ipairs(form.edits) do addon:SetWorkbenchUnsaved(record.control,not self.readOnly and (record.control:GetText()~=record.baseline or record.control.rmFunctionValue~=nil and not addon:SettingsDataEqual(record.control.rmFunctionValue(),record.control.rmFunctionBaseline))) end
        for _,control in ipairs(form.functionTypeFields or {}) do addon:SetWorkbenchUnsaved(control,not self.readOnly and control.rmFunctionTypeValue()~=control.rmFunctionTypeBaseline) end
        addon:RefreshFunctionBindingMarkers(form,self)
        local current=self:PendingSource();local context=addon:CopySettingsData(current);context.code=nil
        if self.code.SetContext and not addon:SettingsDataEqual(context,self.contextInput) then self.contextInput=context;self.code:SetContext({kind='function',id=self.key,name=self.value.name,source=current}) end
        current.disabled=false
        local input={key=self.readOnly and 'READONLY_HELPER' or self.key,source=current,revision=addon.functionRegistryVersion or 0}
        if not addon:SettingsDataEqual(input,self.validationInput) then self.validationInput=addon:CopySettingsData(input);local checked,why=addon:ValidateCustomFunctionSource(input.key,current);self.validationChecked=checked~=nil;self.validationProblem=why end
        addon:SetWorkbenchInvalid(self.code.frame,not self.validationChecked,self.validationProblem)
    end
    -- The Functions draft owns its source baseline; generic profile bindings
    -- would otherwise reset metadata rails after each guarded callback.
    function form:RefreshUnsaved() if valid() then d:UpdateActions() end end
    function d:Close()
        if self.closed then return end;self.closed=true
        if self.code then self.code:Release() end;form:Release();self.frame:Hide()
        for _,control in ipairs({self.apply,self.cancel,self.viewChanges,self.codeExpand,form.message}) do if control then control:Hide() end end
        addon:SetUIScript(self.frame,'OnUpdate',nil)
    end
    function d:Apply()
        if not valid() or self.readOnly or not self:Flush() then return false end
        if InCombatLockdown and InCombatLockdown() then form:Message(L['Leave combat before applying these settings.']);return false end
        local ok,why
        if self.deleting then ok,why=addon:RemoveCustomFunction(self.key,self.expected) else ok,why=addon:InstallCustomFunction(self.key,self:PendingSource(),self.expected) end
        if not ok then form:Message(string.format(L['Function unavailable: %s'],tostring(why)));return false end
        p:DiscardSettingsDraft();clearNew(p);p.functionID=self.deleting and nil or self.key;self:Close();p:Draw();return true
    end
    local function refresh()
        if not valid() or not d:Flush() then return end
        if not d.readOnly then d.value.code=d.code:GetText() end
        form:Draw();d:UpdateActions()
    end
    local function fieldLabel(text,y,width)
        local label=form:Acquire('functionMetadataLabels',function() return form.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall') end)
        label:ClearAllPoints();label:SetPoint('TOPLEFT',0,-y);label:SetSize(width or 66,24);label:SetJustifyH('LEFT');label:SetJustifyV('MIDDLE');label:SetWordWrap(true);label:SetText(text);return label
    end
    local function description(key,caption,value,changed,left,width)
        local y=form.y;local input=form:Edit(key,caption,value,nil,changed)
        if left then input:ClearAllPoints();input:SetPoint('TOPLEFT',left,-y);input:SetWidth(width) end
        input:SetMultiLine(true);input:SetTextInsets(5,5,5,5);input:SetCursorPosition(0)
        local measure=form:Acquire('functionDescriptionMeasure',function() return form.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall') end)
        measure:SetWidth(math.max(40,input:GetWidth()-10));measure:SetWordWrap(true);measure:SetText(value or '');measure:SetHeight(0)
        local height=math.max(54,measure:GetStringHeight()+12);measure:Hide();input:SetHeight(height);form.y=y+height+8
        enable(input,not d.readOnly);return input
    end
    local function metadata(field,caption,values)
        form:Heading(caption)
        if field=='returns' then form:Text(L['Lua returns multiple values in order. Each row documents one result.']) end
        for index,record in ipairs(values) do
            local prefix=(field=='args' and 'arg_' or 'return_')..index..'_';local y=form.y
            if field=='args' then
                fieldLabel(L['Name'],y)
                local input=form:Edit(prefix..'name',nil,record.name or '',nil,function(value) record.name=value;d:UpdateActions() end)
                input:SetMultiLine(false);input:SetHeight(24);input:SetTextInsets(4,4,0,0);input:SetCursorPosition(0);input:ClearAllPoints();input:SetPoint('TOPLEFT',70,-y);input:SetWidth(math.max(80,form.width-158));input.tooltip=L['Argument name'];enable(input,not d.readOnly)
                input.rmFunctionValue=function() return record.name end;input.rmFunctionBaseline=d.baseline[field] and d.baseline[field][index] and d.baseline[field][index].name
            end
            local function move(offset) if not d:Flush() then return end;local value=table.remove(values,index);table.insert(values,index+offset,value);refresh() end
            local actions={{key=field..'_up_'..index,text=L['Move Up'],icon='up',enabled=not d.readOnly and index>1,action=function() move(-1) end},{key=field..'_down_'..index,text=L['Move Down'],icon='down',enabled=not d.readOnly and index<#values,action=function() move(1) end},{key=field..'_delete_'..index,text=L['Delete'],icon='trash',enabled=not d.readOnly,action=function() table.remove(values,index);refresh() end}}
            form:Actions(actions);for i,entry in ipairs(actions) do local control=form.fields[entry.key];control:ClearAllPoints();control:SetPoint('TOPLEFT',form.width-80+(i-1)*28,-y);control:SetWidth(24) end
            local typeY=y+28;fieldLabel(L['Type'],typeY)
            local base,nullable=splitType(record.type)
            local function setType(nextBase,nextNullable) record.type=nextBase..(nextNullable and ' | nil' or '');refresh() end
            local choose=form:Choice(prefix..'type',nil,base,typeChoices(addon,base),function(value) setType(value,nullable) end)
            choose:ClearAllPoints();choose:SetPoint('TOPLEFT',70,-typeY);choose:SetWidth(math.max(40,form.width-182));choose.tooltip=L['Type'];enable(choose,not d.readOnly)
            choose.rmFunctionTypeValue=function() return record.type end;choose.rmFunctionTypeBaseline=d.baseline[field] and d.baseline[field][index] and d.baseline[field][index].type
            local check=form:Check(prefix..'nullable',L['Nullable'],nullable,function(value) setType(base,value) end)
            check:ClearAllPoints();check:SetPoint('TOPLEFT',form.width-106,-typeY);check:SetWidth(102);check:GetFontString():SetWidth(80);enable(check,not d.readOnly)
            check.rmFunctionTypeValue=function() return record.type end;check.rmFunctionTypeBaseline=choose.rmFunctionTypeBaseline;form.functionTypeFields[#form.functionTypeFields+1]=choose;form.functionTypeFields[#form.functionTypeFields+1]=check
            form.y=typeY+28;fieldLabel(L['Description'],form.y)
            local input=description(prefix..'description',nil,record.description or '',function(value) record.description=value;d:UpdateActions() end,70,form.width-70)
            input.rmFunctionValue=function() return record.description end;input.rmFunctionBaseline=d.baseline[field] and d.baseline[field][index] and d.baseline[field][index].description
        end
        local add=form:Button('add_'..field,field=='args' and L['Add argument'] or L['Add return value'],function() values[#values+1]=field=='args' and {name='argument'..(#values+1),type='any',description=''} or {type='any',description=''};refresh() end,'plus');enable(add,not d.readOnly)
    end
    form:Open(function(f)
        f.functionTypeFields={}
        f.width=math.max(240,d.frame:GetWidth()-34);f.child:SetWidth(f.width)
        f:Heading(d.readOnly and L['Built-in function'] or L['Custom function']);f:Text(L['Identifier']..': '..d.key)
        local available,problem=addon:AreFunctionBindingsAvailable(d.value.bindings)
        if d.value.disabled or not available then local warning=f:Text(string.format(L['Function unavailable: %s'],d.value.disabled and 'disabled-function' or problem));warning:SetTextColor(1,.35,.35) end
        if not d.readOnly then
            local pill=f:Acquire('functionEnable',function() return addon:CreateWorkbenchPill(f.child,'',88) end);f.fields.definition_enabled=pill;pill:ClearAllPoints();pill:SetPoint('TOPRIGHT',-28,-4);pill:SetWidth(88);pill:SetText(d.value.disabled and L['Disabled'] or L['Enabled']);pill:SetSelected(not d.value.disabled)
            addon:SetUIScript(pill,'OnClick',f:Guard(function() if d:Flush() then d.value.disabled=not d.value.disabled;refresh() end end))
            if not d.isNew then addon:SettingsTopDelete(f,function() f:Confirm(L['Delete this function? Existing dependents will become unavailable.'],function() d.deleting=true;f:Message(L['Deletion staged. Apply to remove this function.']);d:UpdateActions() end) end) end
        end
        if not d.codeExpanded then
            local input=f:Edit('name',L['Name'],d.value.name or '',not d.readOnly and function(value) if addon:IsCustomFunctionIdentifier(value) then return value end end or nil,function(value) d.value.name=value;d:UpdateActions() end)
            input:SetMultiLine(false);input:SetHeight(24);input:SetTextInsets(4,4,0,0);input:SetCursorPosition(0);input.rmFunctionValue=function() return d.value.name end;input.rmFunctionBaseline=d.baseline.name;enable(input,not d.readOnly)
            if not d.readOnly and addon.ConfigureFunctionNameInput then addon:ConfigureFunctionNameInput(f,input) end
            input=description('description',L['Description'],d.value.description or '',function(value) d.value.description=value;d:UpdateActions() end);input.rmFunctionValue=function() return d.value.description end;input.rmFunctionBaseline=d.baseline.description
            metadata('args',L['Arguments'],d.value.args);metadata('returns',L['Returns'],d.value.returns)
            addon:BuildFunctionBindingFields(f,d)
            f:Text(d.readOnly and L['Packaged source is read-only. Duplicate it to create an editable custom function.'] or L['Arguments become Lua parameters. Bindings expose selected helpers under explicit local aliases. Editing an alias does not rewrite your Lua body.'])
        end
        local actionY=f.y;f.y=f.y+28
        for index,entry in ipairs({{'codeUndo','Undo','undo'},{'codeRedo','Redo','redo'},{'codeReset','Reset'},{'syntax','Check syntax'}}) do
            local button=f:Acquire('functionActions',function() return addon:CreateWorkbenchButton(f.child,'',index==4 and 120 or 68) end);d[entry[1]]=button;button:ClearAllPoints();button:SetPoint('TOPLEFT',(index-1)*74,-actionY);button:SetWidth(index==4 and 120 or 68);button:SetText(actionLabels[entry[1]])
            addon:SetUIScript(button,'OnClick',function()
                if not valid() then return end
                if entry[1]=='codeUndo' or entry[1]=='codeRedo' then d:TravelCode(entry[1]=='codeRedo')
                elseif entry[1]=='codeReset' then if not d.readOnly then d.undo[#d.undo+1]=d.code:GetText();d.redo={};d:SetCode(d.baseline.code);d:UpdateActions() end
                elseif d:Flush() then local candidate=d:PendingSource();candidate.disabled=false;local checked,why=addon:ValidateCustomFunctionSource(d.readOnly and 'READONLY_HELPER' or key,candidate);f:Message(checked and L['Syntax checked. No custom code was executed.'] or tostring(why),not not checked) end
            end)
        end
        d.signature=f:Text(addon:FunctionSignature(key,d.value));local codeTop=f.y
        local preference=addon.db.profile.lua_editor or 'auto'
        if d.code and d.code.preference~=preference then d.code:Release();d.code=nil end
        if not d.code then d.code=addon:CreateWorkbenchLuaEditor(f.child,function() if valid() then d:CodeChanged() end end,valid,preference);d.code.preference=preference elseif d.code.released then d.code:Acquire(function() if valid() then d:CodeChanged() end end,valid) end
        d.code:SetReadOnly(d.readOnly);d.code.frame:SetParent(f.child);d.code.frame:ClearAllPoints();d.code.frame:SetPoint('TOPLEFT',0,-codeTop);d.code.frame:SetSize(f.width,math.max(220,d.frame:GetHeight()-codeTop-30));d.code.frame:Show();d:SetCode(d.value.code)
        if d.code.SetCloseHandler then d.code:SetCloseHandler(function(mouse) local shell=addon.configWindow;if valid() and shell and shell.pane==p then if mouse then shell.rightDown=true end;shell:Hide() end end) end
        d.codeExpand=d.codeExpand or addon:CreateWorkbenchIconButton(d.code.frame,'expand-all',L['Expand code editor'])
        d.codeExpand:SetParent(d.code.frame);d.codeExpand:ClearAllPoints();d.codeExpand:SetPoint('BOTTOMRIGHT',-18,2);d.codeExpand:SetFrameLevel(d.code.frame:GetFrameLevel()+20);d.codeExpand.icon:SetTexture(addon:ControlTexture(d.codeExpanded and 'collapse-all' or 'expand-all'));d.codeExpand.tooltip=d.codeExpanded and L['Restore code editor'] or L['Expand code editor'];d.codeExpand:Show()
        addon:SetUIScript(d.codeExpand,'OnClick',function() if valid() and d:Flush() then d.codeExpanded=not d.codeExpanded;refresh();form.scroll.workbenchBar:SetValue(0);form.scroll:UpdateWorkbenchScroll() end end)
        f.y=codeTop+d.code.frame:GetHeight()+12
        if d.pendingRaw then for _,record in ipairs(f.edits) do for name,text in pairs(d.pendingRaw) do if f.fields[name]==record.control then record.control:SetText(text);record.dirty=true end end end;d.pendingRaw=nil end
        f.cleanups[#f.cleanups+1]=function() if d.code and d.code.edit then d.code.edit:ClearFocus() end end
    end)
    d.apply=d.apply or self:CreateWorkbenchButton(p.frame,L['Apply'],96);d.cancel=d.cancel or self:CreateWorkbenchButton(p.frame,L['Discard'],96)
    d.viewChanges=d.viewChanges or self:CreateViewChangesButton(p.frame,d.apply,function() end)
    for _,control in ipairs({d.apply,d.cancel,d.viewChanges}) do control:SetParent(p.frame);control:ClearAllPoints();control:Show() end
    d.cancel:SetPoint('BOTTOMRIGHT',-8,4);d.apply:SetPoint('RIGHT',d.cancel,'LEFT',-6,0);d.viewChanges:SetPoint('RIGHT',d.apply,'LEFT',-6,0)
    self:SetUIScript(d.apply,'OnClick',function() if valid() then d:Apply() end end)
    self:SetUIScript(d.cancel,'OnClick',function() if valid() then d:Close();clearNew(p);p:DiscardSettingsDraft();p:Draw() end end)
    self:SetUIScript(d.viewChanges,'OnClick',function() if valid() then local pending={};for _,record in ipairs(form.edits) do if record.dirty then pending[#pending+1]={label=L['Fields'],before=record.baseline,after=record.control:GetText()} end end;addon:ShowWorkbenchDraftChanges(d,'profile',d.baseline,d.deleting and {} or d:PendingSource(),valid,nil,pending) end end)
    form.message:SetParent(p.frame);form.message:ClearAllPoints();form.message:SetPoint('BOTTOMLEFT',geometry.detailX,4);form.message:SetPoint('RIGHT',d.viewChanges,'LEFT',-8,0);form.message:SetHeight(20);form.message:Show()
    p.cleanups[#p.cleanups+1]=function() d:Close() end
    self:SetUIScript(d.frame,'OnUpdate',function() if not valid() then d:Close() else d:UpdateActions() end end)
    d.frame:Show();p.creationUsed=true;p.creationUsedForNew=false;p.y=1;p.scroll:Hide();d:UpdateActions();return d
end
