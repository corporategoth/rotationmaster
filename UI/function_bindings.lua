local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- IDs remain explicit even when two modules capture the same local name.
function addon:FunctionBindingChoices()
    local entries={}
    for id,record in pairs(self.builtinFunctions or {}) do
        local origin=id:match('^builtin:(.*):[^:]+$') or id
        entries[#entries+1]={value=id,text=(record.callName or record.source.name or id)..' — '..origin}
    end
    for id,source in pairs(self.db.global.custom_functions or {}) do entries[#entries+1]={value=id,text=self:FunctionEditorName(id,source)..' — '..L['Custom']..' ('..id..')'} end
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
function addon:BuildFunctionBindingFields(form,owner)
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
    form:Button('function_bindings',string.format(L['Function bindings (%d)'],count),function() owner.bindingExpanded=not owner.bindingExpanded;refresh() end)
    if not owner.bindingExpanded then return end
    local targets=self:FunctionBindingChoices()
    form:Text(L['Choose a source helper and the local name used to call it in this Lua body. Renaming the local name does not rewrite code. Source modules distinguish helpers with the same name.'])
    local aliasWidth=math.max(80,form.width*.28);local labelY=form.y
    for index,caption in ipairs({L['Local name in code'],L['Source helper']}) do
        local label=form:Acquire('bindingLabels',function() return form.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall') end)
        label:ClearAllPoints();label:SetPoint('TOPLEFT',index==1 and 0 or aliasWidth+6,-labelY);label:SetSize(index==1 and aliasWidth or math.max(60,form.width-aliasWidth-40),18);label:SetJustifyH('LEFT');label:SetText(caption)
    end;form.y=labelY+20
    for index,originalAlias in ipairs(aliases) do
        local alias,id=originalAlias,bindings[originalAlias];local y=form.y
        local input=form:Edit('binding_alias_'..index,nil,alias,function(text)
            if text~=alias and bindings[text] then return nil end
            if self:NormalizeFunctionBindings({[text]=id},source.args) then return text end
        end,function(value) if value~=alias then mutate(function(values) values[value]=values[alias];values[alias]=nil end);alias=value end;owner:UpdateActions() end)
        input:ClearAllPoints();input:SetPoint('TOPLEFT',0,-y);input:SetWidth(aliasWidth);input:SetMultiLine(false);input:SetHeight(24);input:SetTextInsets(4,4,0,0);input:SetCursorPosition(0);input.rmFunctionValue=nil;input.rmFunctionBaseline=nil;input.tooltip=L['Local name in code'];input:Enable()
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
        local base=self:FunctionEditorName(id,value);local alias=base;local n=2;local used={addon=true,L=true};for _,arg in ipairs(source.args or {}) do used[arg.name]=true end
        while bindings[alias] or used[alias] do alias=base:sub(1,116)..n;n=n+1 end
        mutate(function(values) values[alias]=id end);refresh()
    end,'plus') end
end
