local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- Both authoring surfaces edit explicit binding data. Alias edits never search
-- or replace Lua source, and target identity stays independent of display name.
function addon:BuildFunctionBindingFields(form,owner)
    local source=owner.model and owner.model.value or owner.value;local bindings=source.bindings or {}
    local count=0;local aliases={};for alias in pairs(bindings) do count=count+1;aliases[#aliases+1]=alias end;table.sort(aliases)
    local function refresh()
        if owner.FlushCode then owner:FlushCode() elseif owner.code then owner.value.code=owner.code:GetText() end
        form:Draw();owner:UpdateActions()
    end
    local function mutate(change)
        if owner.model then owner.model:Change(function(model) model.value.bindings=model.value.bindings or {};change(model.value.bindings) end)
        else source.bindings=source.bindings or {};change(source.bindings) end
    end
    form:Button('function_bindings',string.format(L['Function bindings (%d)'],count),function() owner.bindingExpanded=not owner.bindingExpanded;refresh() end)
    if not owner.bindingExpanded then return end
    local targets={}
    for id,record in pairs(self.builtinFunctions or {}) do targets[#targets+1]={value=id,text=record.source.name or id} end
    for id,value in pairs(self.db.global.custom_functions or {}) do targets[#targets+1]={value=id,text=value.name or id} end
    table.sort(targets,function(a,b) if a.text==b.text then return a.value<b.value end;return a.text<b.text end)
    if not owner.readOnly then form:Text(L['Aliases are local names in your Lua body. Changing an alias does not rewrite the body.']) end
    for index,originalAlias in ipairs(aliases) do
        local alias,id=originalAlias,bindings[originalAlias]
        if owner.readOnly then form:Text(alias..' → '..id)
        else
            local y=form.y;local aliasWidth=math.max(80,form.width*.28)
            local input=form:Edit('binding_alias_'..index,nil,alias,function(text)
                if text~=alias and bindings[text] then return nil end
                if self:NormalizeFunctionBindings({[text]=id},source.args) then return text end
            end,function(value) if value~=alias then mutate(function(values) values[value]=values[alias];values[alias]=nil end);alias=value end;owner:UpdateActions() end)
            input:ClearAllPoints();input:SetPoint('TOPLEFT',0,-y);input:SetWidth(aliasWidth);input.tooltip=L['Alias']
            local choices=self:CopySettingsData(targets);local found=false;for _,entry in ipairs(choices) do if entry.value==id then found=true end end;if not found then choices[#choices+1]={value=id,text=id} end
            local target=form:Choice('binding_target_'..index,nil,id,choices,function(value) mutate(function(values) values[alias]=value end);refresh() end)
            target:ClearAllPoints();target:SetPoint('TOPLEFT',aliasWidth+6,-y);target:SetWidth(math.max(60,form.width-aliasWidth-40));target.tooltip=L['Function']
            local remove=form:Button('binding_remove_'..index,L['Remove binding'],function() mutate(function(values) values[alias]=nil end);refresh() end,'trash')
            remove:ClearAllPoints();remove:SetPoint('TOPRIGHT',0,-y);remove:SetWidth(26);form.y=y+30
        end
    end
    if not owner.readOnly then form:Button('add_binding',L['Add binding'],function()
        local n=1;while bindings['helper'..n] do n=n+1 end
        mutate(function(values) values['helper'..n]=targets[1] and targets[1].value or 'MISSING' end);refresh()
    end,'plus') end
end
