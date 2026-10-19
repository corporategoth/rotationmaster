local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- IDs remain explicit even when two modules capture the same local name.
function addon:FunctionInvocation(id,source,original)
    local builtin=self.builtinFunctions and self.builtinFunctions[id]
    local callable=original and builtin and builtin.callName or self:FunctionQualifiedName(id,source)
    local args={};for index,arg in ipairs(source.args or {}) do
        if not (index==1 and arg.name=='self' and callable:find(':',1,true)) then args[#args+1]=builtin and index==1 and arg.name=='self' and (builtin.callName and builtin.callName:match('^(.*):[^:]+$') or 'addon') or arg.name end
    end
    return callable..'('..table.concat(args,', ')..')'
end
-- Completion adds a stable dependency only after the user accepts a suggestion.
-- Source insertion then updates actions/context; avoid re-entering completion here.
function addon:BindEditorFunction(owner,id,alias)
    local function reject(reason) if owner.form and owner.form.Message then owner.form:Message(string.format(L['Function unavailable: %s'],reason)) end;return false end
    if owner.readOnly or owner.pendingFunctionBinding or not owner.OwnerValid or not owner.OwnerValid() or owner.key==id and not owner.model then return reject('unavailable-editor') end
    local source=owner.model and owner.model.value or owner.value
    if not source then return reject('function-binding-conflict') end
    local arguments=source.args or {{name='value'},{name='cache'},{name='evalStart'},{name='spec'},{name='parent'},{name='frame'},{name='tag'}}
    local bindings=self:CopySettingsData(source.bindings or {})
    if bindings[alias] and bindings[alias]~=id then return reject('function-binding-conflict') end
    bindings[alias]=id
    if not self:NormalizeFunctionBindings(bindings,arguments) then return reject('invalid-function-bindings') end
    local available,why=self:FunctionAvailable(id);if not available then return reject(why or 'missing-function') end
    local before=source.bindings;local previous=before and before[alias];local text=owner.code:GetText();local session=owner.session
    local transaction={};owner.pendingFunctionBinding=transaction;source.bindings=bindings
    local function valid() return owner.session==session and owner.OwnerValid and owner.OwnerValid() and owner.pendingFunctionBinding==transaction end
    function transaction:rollback()
        if self.finished then return end;self.finished=true
        source.bindings=before
        local current=valid();if owner.pendingFunctionBinding==transaction then owner.pendingFunctionBinding=nil end
        if current then owner:SetCode(text);owner:UpdateActions() end
    end
    function transaction:commit()
        if self.finished then return false end
        if not valid() then self:rollback();return false end
        local entry={kind='function-completion',text=text,alias=alias,binding=previous,bindingsMissing=before==nil,modelDepth=owner.model and #owner.model.undo or 0}
        local state=owner.model and owner:CodeState() or owner
        state.undo[#state.undo+1]=entry;state.redo={}
        local function length(value) return #(type(value)=='table' and value.text or value) end
        local bytes=0;if owner.model then for _,value in ipairs(state.undo) do bytes=bytes+length(value) end end
        while #state.undo>100 or owner.model and bytes>4194304 do local removed=table.remove(state.undo,1);if owner.model then bytes=bytes-length(removed) end end
        if owner.model then state.text=owner.code:GetText() else owner.value.code=owner.code:GetText() end
        self.finished=true;owner.pendingFunctionBinding=nil;owner:UpdateActions();return true
    end
    return transaction
end
function addon:TravelFunctionCompletion(owner,entry)
    local source=owner.model and owner.model.value or owner.value;local bindings=source.bindings
    local inverse={kind='function-completion',text=owner.code:GetText(),alias=entry.alias,binding=bindings and bindings[entry.alias],bindingsMissing=bindings==nil,modelDepth=entry.modelDepth}
    bindings=self:CopySettingsData(bindings or {});bindings[entry.alias]=entry.binding
    source.bindings=bindings
    if entry.bindingsMissing and next(bindings)==nil then source.bindings=nil end
    owner:SetCode(entry.text);return inverse
end
function addon:PreferFunctionCodeHistory(owner,redo)
    local state=owner:CodeState();local history=redo and state.redo or state.undo
    for index=#history,1,-1 do local entry=history[index]
        if type(entry)=='table' and entry.kind=='function-completion' then
            return redo and #owner.model.undo>=entry.modelDepth or not redo and #owner.model.undo<=entry.modelDepth
        end
    end
    return false
end
function addon:FunctionBindingChoices()
    local entries={}
    for id,record in pairs(self.builtinFunctions or {}) do
        local origin=id:match('^builtin:(.*):[^:]+$') or id
        entries[#entries+1]={value=id,text=self:FunctionQualifiedName(id,record.source)..' — '..origin}
    end
    for id,source in pairs(self.db.global.custom_functions or {}) do entries[#entries+1]={value=id,text=self:FunctionQualifiedName(id,source)..' — '..L['Custom']..' ('..id..')'} end
    table.sort(entries,function(a,b) if a.text==b.text then return a.value<b.value end;return a.text<b.text end)
    -- Public call paths can repeat too; retain a unique, searchable identity.
    local counts={};for _,entry in ipairs(entries) do counts[entry.text]=(counts[entry.text] or 0)+1 end
    for _,entry in ipairs(entries) do if counts[entry.text]>1 then entry.text=entry.text..' ('..entry.value..')' end end
    return entries
end
function addon:RefreshFunctionBindingMarkers(form,owner)
    local source=owner.model and owner.model.value or owner.value
    local baseline=owner.model and owner.model.baseline.value or owner.baseline or {}
    local dirty=not owner.readOnly and not self:SettingsDataEqual(source.bindings or {},baseline.bindings or {})
    self:SetWorkbenchUnsaved(form.fields.function_bindings,dirty)
    for key,control in pairs(form.fields) do if key:match('^binding_alias_') or key:match('^binding_target_') then self:SetWorkbenchUnsaved(control,dirty) end end
end
function addon:BuildFunctionBindingFields(form,owner,options)
    options=options or {}
    local source=owner.model and owner.model.value or owner.value;local bindings=source.bindings or {}
    local count=0;local aliases={};for alias in pairs(bindings) do count=count+1;aliases[#aliases+1]=alias end;table.sort(aliases)
    local function refresh()
        if not owner.readOnly then
            if owner.FlushCode then owner:FlushCode() elseif owner.code then owner.value.code=owner.code:GetText() end
        end
        form:Draw();owner:UpdateActions()
    end
    local function mutate(change)
        if owner.readOnly then return end
        if owner.model then owner.model:Change(function(model) model.value.bindings=model.value.bindings or {};change(model.value.bindings) end)
        else source.bindings=source.bindings or {};change(source.bindings) end
    end
    local y=form.y
    local button=form:Button('function_bindings',string.format(options.header and L['Bindings (%d)'] or L['Function bindings (%d)'],count),function() owner.bindingExpanded=not owner.bindingExpanded;refresh() end)
    if options.header then local header=type(options.header)=='function' and options.header(button) or options.header;button:ClearAllPoints();button:SetPoint('TOPLEFT',header.x,-header.y);button:SetWidth(header.width);form.y=math.max(y,header.y+28) end
    if not owner.bindingExpanded then return end
    local targets=self:FunctionBindingChoices()
    if not options.hideDescription then form:Text(L['Choose a source helper and its name in this Lua body, such as custom.ready or utils.getCached. Namespaces are private to this callback. Renaming a binding does not rewrite code.']) end
    local aliasWidth=math.max(80,form.width*.28);local labelY=form.y
    for index,caption in ipairs({L['Name in code'],L['Source helper']}) do
        local label=form:Acquire('bindingLabels',function() return form.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall') end)
        label:ClearAllPoints();label:SetPoint('TOPLEFT',index==1 and 0 or aliasWidth+6,-labelY);label:SetSize(index==1 and aliasWidth or math.max(60,form.width-aliasWidth-40),18);label:SetJustifyH('LEFT');label:SetText(caption)
    end;form.y=labelY+20
    for index,originalAlias in ipairs(aliases) do
        local alias,id=originalAlias,bindings[originalAlias];local y=form.y
        local input=form:Edit('binding_alias_'..index,nil,alias,function(text)
            if text~=alias and bindings[text] then return nil end
            if self:NormalizeFunctionBindings({[text]=id},source.args) then return text end
        end,function(value) if value~=alias then mutate(function(values) values[value]=values[alias];values[alias]=nil end);alias=value end;owner:UpdateActions() end)
        input:ClearAllPoints();input:SetPoint('TOPLEFT',0,-y);input:SetWidth(aliasWidth);input:SetMultiLine(false);input:SetHeight(24);input:SetTextInsets(4,4,0,0);input:SetCursorPosition(0);input.rmFunctionValue=nil;input.rmFunctionBaseline=nil;input.tooltip=L['Name in code'];input:Enable()
        local choices=self:CopySettingsData(targets);local found=false;for _,entry in ipairs(choices) do if entry.value==id then found=true end end;if not found then choices[#choices+1]={value=id,text=id} end
        local target=form:Choice('binding_target_'..index,nil,id,choices,function(value) mutate(function(values) values[alias]=value end);refresh() end)
        target:ClearAllPoints();target:SetPoint('TOPLEFT',aliasWidth+6,-y);target:SetWidth(math.max(60,form.width-aliasWidth-40));target.tooltip=L['Source helper']
        if owner.readOnly then input:Disable();target:Disable()
        else
            local remove=form:Button('binding_remove_'..index,L['Remove binding'],function() mutate(function(values) values[alias]=nil end);refresh() end,'trash')
            remove:ClearAllPoints();remove:SetPoint('TOPRIGHT',0,-y);remove:SetWidth(26)
        end;form.y=y+30
    end
    if not owner.readOnly then form:Button('add_binding',L['Add binding'],function()
        local id=targets[1] and targets[1].value or 'MISSING';local record=self.builtinFunctions and self.builtinFunctions[id];local value=record and record.source or (self.db.global.custom_functions or {})[id]
        local base=self:FunctionQualifiedName(id,value);local alias=base;local n=2;local used={addon=true,L=true};for _,arg in ipairs(source.args or {}) do used[arg.name]=true end
        while bindings[alias] or used[alias] do alias=base:sub(1,116)..n;n=n+1 end
        mutate(function(values) values[alias]=id end);refresh()
    end,'plus') end
end
