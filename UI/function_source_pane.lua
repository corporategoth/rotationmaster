local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local actionLabels={codeUndo=L['Undo'],codeRedo=L['Redo'],codeReset=L['Reset'],syntax=L['Check syntax']}
local function enable(control,enabled) if enabled then control:Enable() else control:Disable() end end
local function splitType(value)
    local parts,nullable={},false
    for part in tostring(value or 'any'):gmatch('[^|]+') do
        part=part:match('^%s*(.-)%s*$');if part=='nil' then nullable=true else parts[#parts+1]=part end
    end
    if #parts==0 and nullable then return 'nil',false end
    return #parts>0 and table.concat(parts,' | ') or 'any',nullable
end
local function typeChoices(addon,current)
    local names={};for _,name in ipairs({'any','boolean','number','string','table','function','thread','userdata','nil'}) do names[name]=true end
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
    return self:FunctionQualifiedName(id,source)..'('..table.concat(args,', ')..')'..(#returns>0 and ' -> '..table.concat(returns,', ') or '')
end
function addon:BuildInlineFunction(p,key,source,readOnly)
    local d=p.functionEditorCache or {frame=self:TrackWorkbenchSize(CreateFrame('Frame',nil,p.frame))};p.functionEditorCache=d;p.inlineFunction=d
    local resume=p.functionResume;p.functionResume=nil
    d.closed=false;d.key=key;d.readOnly=readOnly==true;d.value=self:CopySettingsData(source);if not d.readOnly then d.value.code=self:NormalizeLuaSourceForEditor(d.value.code);if self.FunctionEditorName then d.value.name=self:FunctionEditorName(key,d.value) end end;d.codeExpanded=false;d.metadataCollapsed={};d.baseline=self:CopySettingsData(d.value);d.expected=self:CopySettingsData((self.db.global.custom_functions or {})[key]);d.isNew=p.newFunctionSource~=nil;d.undo={};d.redo={};d.validationInput=nil;d.contextInput=nil;d.session=(d.session or 0)+1
    if resume then for field,value in pairs(resume) do d[field]=value end end
    local token,session=p.generation,d.session
    local function valid() return not d.closed and d.session==session and p:Valid(token) end;d.OwnerValid=valid
    local geometry=self:GetWorkbenchRosterGeometry(p.frame:GetWidth(),p.frame:GetHeight())
    d.frame:SetParent(p.frame);d.frame:ClearAllPoints();d.frame:SetPoint('TOPLEFT',geometry.detailX,0);d.frame:SetSize(geometry.detailWidth-self:GetWorkbenchHelpReserve(p.frame),math.max(160,p.frame:GetHeight()-36))
    d.form=d.form or self:CreateSettingsForm(d.frame);local form=d.form;form.unsavedDefaults={};form:SetWidth(d.frame:GetWidth());form:SetHeight(d.frame:GetHeight())
    function d:PendingSource() local value=addon:CopySettingsData(self.value);if not self.readOnly and self.code and not self.code.released then value.code=self.code:GetText() end;return value end
    function d:CaptureDraft()
        local raw={};for _,record in ipairs(form.edits) do if record.dirty then for name,control in pairs(form.fields) do if control==record.control then raw[name]=record.control:GetText() end end end end
        return {value=self:PendingSource(),baseline=self.baseline,expected=self.expected,isNew=self.isNew,undo=self.undo,redo=self.redo,pendingRaw=raw,codeExpanded=self.codeExpanded,metadataCollapsed=self.metadataCollapsed}
    end
    function d:IsDirty()
        if self.readOnly then return false end
        if self.isNew or not addon:SettingsDataEqual(self:PendingSource(),self.baseline) then return true end
        for _,record in ipairs(form.edits) do if record.dirty and record.control:GetText()~=record.baseline then return true end end;return false
    end
    function d:Flush() return valid() and form:FlushEdits() end
    function d:CodeChanged()
        if self.loading or self.readOnly or not self.code then return end
        local text=self.code:GetText();if text~=self.value.code then if not self.pendingFunctionBinding then self.undo[#self.undo+1]=self.value.code;self.redo={} end;self.value.code=text;while #self.undo>100 do table.remove(self.undo,1) end end;self:UpdateActions()
    end
    function d:SetCode(text) self.loading=true;self.code:SetText(self.readOnly and addon.FormatLuaSourceDisplay and addon:FormatLuaSourceDisplay(text) or text);self.loading=false;self.value.code=text end
    function d:TravelCode(redo)
        if not valid() or self.readOnly then return end
        local from,to=redo and self.redo or self.undo,redo and self.undo or self.redo
        if #from>0 then
            local entry=table.remove(from)
            if type(entry)=='table' and entry.kind=='function-completion' then to[#to+1]=addon:TravelFunctionCompletion(self,entry)
            else to[#to+1]=self.code:GetText();self:SetCode(entry) end
            self:UpdateActions()
        end
    end
    function d:UpdateSignature()
        if not self.signature then return end
        local text=addon:FunctionSignature(self.key,self.value)
        local width=math.max(1,form.width)
        if self.signature:GetText()==text and math.abs(self.signature:GetWidth()-width)<.1 then return end
        local oldHeight=self.signature:GetHeight();self.signature:SetWidth(width);self.signature:SetText(text);self.signature:SetHeight(0)
        local height=math.max(20,self.signature:GetStringHeight());self.signature:SetHeight(height)
        local delta=height-oldHeight
        if delta~=0 and self.code and self.codeTop then
            self.codeTop=self.codeTop+delta
            self.code.frame:ClearAllPoints();self.code.frame:SetPoint('TOPLEFT',0,-self.codeTop)
            self.code.frame:SetHeight(math.max(220,self.frame:GetHeight()-self.codeTop-30))
            form.y=self.codeTop+self.code.frame:GetHeight()+12;form.child:SetHeight(math.max(1,form.y));form.scroll:UpdateWorkbenchScroll()
        end
    end
    function d:UpdateActions()
        if not valid() or not self.apply then return end
        self:UpdateSignature()
        local dirty=self:IsDirty();enable(self.apply,dirty);enable(self.viewChanges,dirty);enable(self.codeUndo,not self.readOnly and #self.undo>0);enable(self.codeRedo,not self.readOnly and #self.redo>0);enable(self.codeReset,not self.readOnly and self.code:GetText()~=self.baseline.code)
        addon:SetWorkbenchUnsaved(self.code.frame,not self.readOnly and self.code:GetText()~=self.baseline.code);addon:SetWorkbenchUnsaved(form.fields.definition_enabled,not not self.value.disabled~=not not self.baseline.disabled)
        for _,record in ipairs(form.edits) do addon:SetWorkbenchUnsaved(record.control,not self.readOnly and (record.control:GetText()~=record.baseline or record.control.rmFunctionValue~=nil and not addon:SettingsDataEqual(record.control.rmFunctionValue(),record.control.rmFunctionBaseline))) end
        for _,control in ipairs(form.functionTypeFields or {}) do addon:SetWorkbenchUnsaved(control,not self.readOnly and control.rmFunctionTypeValue()~=control.rmFunctionTypeBaseline) end
        for _,field in ipairs({'args','returns'}) do addon:SetWorkbenchUnsaved(form.fields['section_'..field],not self.readOnly and not addon:SettingsDataEqual(self.value[field],self.baseline[field])) end
        for field,view in pairs(form.functionMetadataViews or {}) do for index,row in ipairs(view.rows) do addon:SetWorkbenchUnsaved(row,not self.readOnly and not addon:SettingsDataEqual(self.value[field][index],self.baseline[field] and self.baseline[field][index])) end end
        addon:RefreshFunctionBindingMarkers(form,self)
        local current=self:PendingSource();local context=addon:CopySettingsData(current);context.code=nil;context.registryRevision=addon.functionRegistryVersion or 0
        if self.code.SetContext and not addon:SettingsDataEqual(context,self.contextInput) then self.contextInput=context;self.code:SetContext({kind='function',id=self.key,name=self.value.name,source=current,bindFunction=function(id,alias) return addon:BindEditorFunction(self,id,alias) end}) end
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
        if self.pendingFunctionBinding then self.pendingFunctionBinding:rollback() end
        if self.code then self.code:Release() end;form:Release();self.frame:Hide()
        for _,control in ipairs({self.apply,self.cancel,self.viewChanges,self.codeExpand,form.message}) do if control then control:Hide() end end
        addon:SetUIScript(self.frame,'OnUpdate',nil)
    end
    function d:Apply()
        if not valid() or self.readOnly or not self:Flush() then return false end
        if InCombatLockdown and InCombatLockdown() then form:Message(L['Leave combat before applying these settings.']);return false end
        local ok,why
        ok,why=addon:InstallCustomFunction(self.key,self:PendingSource(),self.expected)
        if not ok then form:Message(string.format(L['Function unavailable: %s'],tostring(why)));return false end
        p:DiscardSettingsDraft();clearNew(p);p.functionID=self.key;p.functionNamespaceFilter=addon:FunctionNamespace(self.key,self.value);self:Close();p:Draw();return true
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
    local function description(key,caption,value,changed,left,width,compact)
        local y=form.y;local input=form:Edit(key,caption,value,nil,changed)
        if left then input:ClearAllPoints();input:SetPoint('TOPLEFT',left,-y);input:SetWidth(width) end
        input:SetMultiLine(true);input:SetTextInsets(5,5,compact and 4 or 5,compact and 4 or 5);input:SetCursorPosition(0)
        local measure=form:Acquire('functionDescriptionMeasure',function() return form.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall') end)
        measure:SetWidth(math.max(40,input:GetWidth()-10));measure:SetWordWrap(true);measure:SetText(value or '');measure:SetHeight(0)
        local height=math.max(28,measure:GetStringHeight()+(compact and 8 or 12));measure:Hide();input:SetHeight(height);form.y=y+height+(compact and 2 or 4)
        enable(input,not d.readOnly);return input
    end
    local function metadata(field,caption,values)
        local function factory()
            if field=='returns' then return {type='any',description=''} end
            local used={};for _,entry in ipairs(values) do used[entry.name]=true end;local n=1;while used['argument'..n] do n=n+1 end
            return {name='argument'..n,type='any',description=''}
        end
        local function confirmOrderChange(apply)
            if d.isNew then apply() else form:Confirm(field=='args' and L['Changing argument order can break existing callers. Rotation Master will not rewrite their Lua code. Continue?'] or L['Changing return documentation order does not rewrite return statements or existing callers. Review the Lua body and callers for the new order. Continue?'],apply) end
        end
        local function append()
            local gap=#values+1
            if field=='args' and values[#values] and values[#values].name=='...' then gap=#values end
            local function apply()
                if not valid() or d.readOnly then return end
                table.insert(values,gap,factory());d.metadataCollapsed[field]=false;refresh()
            end
            if gap<=#values then confirmOrderChange(apply) else apply() end
        end
        local viewKey='function_'..field
        local function beginInsert()
            if d.readOnly or not valid() or not d:Flush() then return end
            if d.metadataCollapsed[field] then d.metadataCollapsed[field]=false;refresh() end
            local view=form.ordered and form.ordered[viewKey];if view and view.BeginInsert then view:BeginInsert(factory,field=='args' and L['Argument'] or L['Return']) end
        end
        -- The collapsible section title and Add share the list's header row.
        local header={heading={text=caption,key='section_'..field,collapsed=d.metadataCollapsed[field],toggle=function() if d:Flush() then d.metadataCollapsed[field]=not d.metadataCollapsed[field];refresh() end end},
            add={key='add_'..field,text=field=='args' and L['Argument'] or L['Return'],enabled=not d.readOnly,click=append,beginDrag=beginInsert}}
        local view=form:OrderedCollection(viewKey,values,function(index) return field=='args' and (values[index].name or L['Argument']) or (values[index].type or L['Return']) end,function(rowForm,index,record,row)
            local prefix=(field=='args' and 'arg_' or 'return_')..index..'_'
            form.fields[field..'_up_'..index]=row.up;form.fields[field..'_down_'..index]=row.down;form.fields[field..'_delete_'..index]=row.remove
            local top,width=form.y,form.width;local isArgument=field=='args';local wide=width>=(isArgument and 370 or 220)
            local base,nullable=splitType(record.type)
            local function setType(nextBase,nextNullable) record.type=nextBase..(nextNullable and nextBase~='nil' and ' | nil' or '');refresh() end
            -- Nullable is only as wide as its box and caption, right-aligned so
            -- it sits against the card's help icon.
            local nullableY=wide and top or top+(isArgument and 56 or 28)
            form.y=nullableY
            local check=form:Check(prefix..'nullable',L['Nullable'],nullable,function(value) setType(base,value) end)
            local caption=check:GetFontString();caption:SetWidth(200)
            local captionWidth=math.min(120,math.max(30,math.ceil(caption:GetStringWidth() or 0)+2));local checkWidth=22+captionWidth
            caption:SetWidth(captionWidth);check:SetWidth(checkWidth);check:ClearAllPoints();check:SetPoint('TOPLEFT',math.max(0,width-checkWidth),-nullableY)
            local inlineRight=wide and width-checkWidth-6 or width
            fieldLabel(L['Type'],top,30)
            local choose=form:Choice(prefix..'type',nil,base,typeChoices(addon,base),function(value) setType(value,nullable) end)
            local typeWidth=wide and (isArgument and math.min(140,math.floor(width*.25)) or inlineRight-34) or width-34
            choose:ClearAllPoints();choose:SetPoint('TOPLEFT',34,-top);choose:SetWidth(math.max(40,typeWidth));addon:AlignWorkbenchTextLeft(choose,26);choose:GetFontString():SetWordWrap(false);choose.tooltip=L['Type'];enable(choose,not d.readOnly)
            choose.rmFunctionTypeValue=function() return record.type end;choose.rmFunctionTypeBaseline=d.baseline[field] and d.baseline[field][index] and d.baseline[field][index].type
            if isArgument then
                local nameY=wide and top or top+28;local nameLabelX=wide and 34+typeWidth+6 or 0;local nameX=nameLabelX+38
                local nameLabel=fieldLabel(L['Name'],nameY,34);nameLabel:ClearAllPoints();nameLabel:SetPoint('TOPLEFT',nameLabelX,-nameY)
                form.y=nameY
                local input=form:Edit(prefix..'name',nil,record.name or '',nil,function(value) record.name=value;d:UpdateActions() end)
                input:SetMultiLine(false);input:SetHeight(24);input:SetTextInsets(4,4,0,0);input:SetCursorPosition(0);input:ClearAllPoints();input:SetPoint('TOPLEFT',nameX,-nameY);input:SetWidth(math.max(40,inlineRight-nameX));input.tooltip=L['Argument name'];enable(input,not d.readOnly)
                input.rmFunctionValue=function() return record.name end;input.rmFunctionBaseline=d.baseline[field] and d.baseline[field][index] and d.baseline[field][index].name
            end
            enable(check,not d.readOnly and base~='nil');form.y=nullableY+28
            check.rmFunctionTypeValue=function() return record.type end;check.rmFunctionTypeBaseline=choose.rmFunctionTypeBaseline;form.functionTypeFields[#form.functionTypeFields+1]=choose;form.functionTypeFields[#form.functionTypeFields+1]=check
            fieldLabel(L['Description'],form.y)
            local input=description(prefix..'description',nil,record.description or '',function(value) record.description=value;d:UpdateActions() end,70,math.max(40,form.width-70),true)
            input.rmFunctionValue=function() return record.description end;input.rmFunctionBaseline=d.baseline[field] and d.baseline[field][index] and d.baseline[field][index].description
            form.fields[prefix..'help']=row.help
            addon:SetUIScript(row.help,'OnClick',form:Guard(function()
                local sections={{title=L['Type'],text=L['Type and Nullable describe the values accepted or returned by this function. They document the contract; they do not rewrite or validate values in the Lua body.']},{title=L['Description'],text=L['Describe this value for function documentation, completion and hover help. Changes remain in the draft until Apply.']}}
                if isArgument then sections[#sections+1]={title=L['Name'],text=L['The argument name is the local parameter available in the Lua body. Use a valid Lua identifier. Renaming this documentation does not rewrite references in the code.']} end
                sections[#sections+1]={title=L['Card controls'],text=isArgument and L['Drag a card to reorder arguments; Ctrl-drag includes following arguments. Up and down move one position. Duplicate copies the argument with a unique name; the trash can removes it. Reordering a saved function requires confirmation because existing callers are not rewritten.'] or L['Drag a card to reorder return documentation; Ctrl-drag includes following returns. Up and down move one position. Duplicate copies the documented return value; the trash can removes it. Return order in this list does not rewrite return statements or callers.']}
                addon:ShowWorkbenchHelp(isArgument and L['Argument'] or L['Return'],sections,addon:FunctionQualifiedName(d.key,d.value))
            end))
            form.fields[prefix..'duplicate']=row.duplicate
            addon:SetUIScript(row.duplicate,'OnClick',form:Guard(function()
                if d.readOnly or not d:Flush() then return end
                local copy=addon:CopySettingsData(record);local position=index+1
                if isArgument then
                    local used={};for _,entry in ipairs(values) do used[entry.name]=true end
                    local base=record.name=='...' and 'argument_copy' or addon:FunctionEditorName('argument',record):sub(1,118)..'_copy';local name,n=base,2
                    while used[name] do name=base..n;n=n+1 end;copy.name=name;if record.name=='...' then position=index end
                end
                table.insert(values,position,copy);refresh()
            end))
            form.fields[prefix..'remove']=row.remove
        end,function() if not d.readOnly then if d.code then d.value.code=d.code:GetText() end;d:UpdateActions() end end,{heading=header.heading,add=header.add,help=true,duplicate=true,prefix=field=='args' and 'arg_' or 'return_',readOnly=d.readOnly,confirmReorder=confirmOrderChange,confirmInsert=function(apply,gap)
            if gap<=#values then confirmOrderChange(apply) else apply() end
        end})
        form.functionMetadataViews[field]=view
    end
    form:Open(function(f)
        f.functionTypeFields={};f.functionMetadataViews={};d.invocationText=nil
        f.width=math.max(240,d.frame:GetWidth()-34);f.child:SetWidth(f.width)
        f:Heading(d.readOnly and L['Built-in function'] or L['Custom function'])
        local available,problem=addon:AreFunctionBindingsAvailable(d.value.bindings)
        if d.value.disabled or not available then local warning=f:Text(string.format(L['Function unavailable: %s'],d.value.disabled and 'disabled-function' or problem));warning:SetTextColor(1,.35,.35) end
        if not d.readOnly then
            local pill=f:Acquire('functionEnable',function() return addon:CreateWorkbenchPill(f.child,'',88) end);f.fields.definition_enabled=pill;pill:ClearAllPoints();pill:SetPoint('TOPRIGHT',-28,-4);pill:SetWidth(88);pill:SetText(d.value.disabled and L['Disabled'] or L['Enabled']);pill:SetSelected(not d.value.disabled)
            addon:SetUIScript(pill,'OnClick',f:Guard(function() if d:Flush() then d.value.disabled=not d.value.disabled;refresh() end end))
            if not d.isNew then addon:SettingsTopDelete(f,function()
                local id=d.key
                addon:ConfirmSettingsDeletion(p,L['Delete this function? Existing dependents will become unavailable.'],function()
                    local current=(addon.db.global.custom_functions or {})[id];if not current then return false,'function-changed' end
                    local ok,why=addon:RemoveCustomFunction(id,addon:CopySettingsData(current));if ok then clearNew(p);p.functionID=nil end;return ok,why
                end)
            end) end
        end
        if not d.codeExpanded then
            local function setNamespace(value)
                -- Choosing the displayed legacy default does not materialize
                -- absent metadata and create an otherwise empty edit.
                if not (value=='functions' and (d.value.namespace==nil or d.value.namespace=='')) then d.value.namespace=value end
                d:UpdateActions()
            end
            local input=f:Edit('namespace',L['Namespace'],addon:FunctionNamespace(d.key,d.value),function(value) return addon:IsFunctionNamespace(value) and value or nil end,setNamespace)
            input:SetMultiLine(false);input:SetHeight(24);input:SetTextInsets(4,4,0,0);input:SetCursorPosition(0);input.rmFunctionValue=function() return d.value.namespace end;input.rmFunctionBaseline=d.baseline.namespace;enable(input,not d.readOnly)
            if not d.readOnly and addon.AttachWorkbenchEditSuggestions and addon.FunctionNamespaces then
                addon:AttachWorkbenchEditSuggestions(f,input,addon:FunctionNamespaces(),setNamespace,valid)
            end
            input=f:Edit('name',L['Name'],d.value.name or '',not d.readOnly and function(value) if addon:IsCustomFunctionIdentifier(value) then return value end end or nil,function(value) d.value.name=value;d:UpdateActions() end)
            input:SetMultiLine(false);input:SetHeight(24);input:SetTextInsets(4,4,0,0);input:SetCursorPosition(0);input.rmFunctionValue=function() return d.value.name end;input.rmFunctionBaseline=d.baseline.name;enable(input,not d.readOnly)
            if not d.readOnly and addon.ConfigureFunctionNameInput then addon:ConfigureFunctionNameInput(f,input) end
            input=description('description',L['Description'],d.value.description or '',function(value) d.value.description=value;d:UpdateActions() end);input.rmFunctionValue=function() return d.value.description end;input.rmFunctionBaseline=d.baseline.description
            metadata('args',L['Arguments'],d.value.args);metadata('returns',L['Returns'],d.value.returns)
        end
        local actionY=f.y;local bindingLayout
        f.y=actionY+28
        addon:BuildFunctionBindingFields(f,d,{header=function(button)
            bindingLayout=addon:GetFunctionBindingToolbarGeometry(f.width,button,actionY)
            return bindingLayout
        end})
        for index,entry in ipairs({{'codeUndo','Undo','undo'},{'codeRedo','Redo','redo'},{'codeReset','Reset'},{'syntax','Check syntax'}}) do
            local button=f:Acquire('functionActions',function() return addon:CreateWorkbenchButton(f.child,'',index==4 and 120 or 68) end);d[entry[1]]=button;button:ClearAllPoints();button:SetPoint('TOPLEFT',index==4 and bindingLayout.syntaxX or (index-1)*74,-(index==4 and bindingLayout.syntaxY or actionY));button:SetWidth(index==4 and 120 or 68);button:SetText(actionLabels[entry[1]])
            addon:SetUIScript(button,'OnClick',function()
                if not valid() then return end
                if entry[1]=='codeUndo' or entry[1]=='codeRedo' then d:TravelCode(entry[1]=='codeRedo')
                elseif entry[1]=='codeReset' then if not d.readOnly then d.undo[#d.undo+1]=d.code:GetText();d.redo={};d:SetCode(d.baseline.code);d:UpdateActions() end
                elseif d:Flush() then local candidate=d:PendingSource();candidate.disabled=false;local checked,why=addon:ValidateCustomFunctionSource(d.readOnly and 'READONLY_HELPER' or key,candidate);f:Message(checked and L['Syntax checked. No custom code was executed.'] or tostring(why),not not checked) end
            end)
        end
        d.signature=f:Text(addon:FunctionSignature(key,d.value));local codeTop=f.y;d.codeTop=codeTop
        local preference=addon.db.profile.lua_editor or 'auto'
        d.code=addon:AcquireSourceLuaEditor(d,f.child,function() if valid() then d:CodeChanged() end end,valid,preference)
        d.code:SetReadOnly(d.readOnly);d.code.frame:SetParent(f.child);d.code.frame:ClearAllPoints();d.code.frame:SetPoint('TOPLEFT',0,-codeTop);d.code.frame:SetSize(f.width,math.max(220,d.frame:GetHeight()-codeTop-30));d.code.frame:Show();d:SetCode(d.value.code);d:UpdateSignature();codeTop=d.codeTop
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
    self:SetUIScript(d.viewChanges,'OnClick',function() if valid() then local pending={};for _,record in ipairs(form.edits) do if record.dirty then pending[#pending+1]={label=L['Fields'],before=record.baseline,after=record.control:GetText()} end end;addon:ShowWorkbenchDraftChanges(d,'profile',d.baseline,d:PendingSource(),valid,nil,pending) end end)
    form.message:SetParent(p.frame);form.message:ClearAllPoints();form.message:SetPoint('BOTTOMLEFT',geometry.detailX,4);form.message:SetPoint('RIGHT',d.viewChanges,'LEFT',-8,0);form.message:SetHeight(20);form.message:Show()
    p.cleanups[#p.cleanups+1]=function() d:Close() end
    self:SetUIScript(d.frame,'OnUpdate',function() if not valid() then d:Close() else d:UpdateActions() end end)
    d.frame:Show();p.creationUsed=true;p.creationUsedForNew=false;p.y=1;p.scroll:Hide();d:UpdateActions();return d
end
