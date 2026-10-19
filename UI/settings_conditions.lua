local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:BuildConditionSettings(p)
    local store=p:SettingsData()
    if p.mode=='categories' then return self:BuildConditionCategorySettings(p) end
    local profile=store.profile;local groups=profile.condition_groups or {};local definitions=self:CopySettingsData(self.conditionDefinitions or {});local custom=store.global.custom_conditions or {}
    for tag,definition in pairs(custom) do if not definitions[tag] then definitions[tag]={description=definition.description,icon=definition.icon} end end
    local categories={{value='ALL',text=L['All'],icon='Interface\\Icons\\INV_Misc_Book_09'},{value='SWITCH',text=L['Switch']}}
    if p.category=='CUSTOM' or p.category=='BUILTIN' then p.conditionSource=p.category=='CUSTOM' and 'custom' or 'builtin';p.category='ALL' end
    p.conditionSource=p.conditionSource or 'all'
    local groupIndex
    for i,group in ipairs(groups) do categories[#categories+1]={value=group.id,text=group.name or group.id,icon=self:GetConditionCategoryIcon(group)};if group.id==p.category then groupIndex=i end end
    categories[#categories+1]={value='DEFAULT',text=L['Other']};if p.category~='ALL'  and p.category~='SWITCH' and p.category~='DEFAULT' and not groupIndex then p.category='ALL' end
    local tags=self:listConditions(p.category,true,store);local entries={};local seen={}
    if p.category=='ALL' then for tag in pairs(custom) do local exists=false;for _,value in ipairs(tags) do if value==tag then exists=true end end;if not exists then tags[#tags+1]=tag end end end
    for _,tag in ipairs(tags) do if not (self.db.global.custom_conditions and self.db.global.custom_conditions[tag] and not custom[tag]) and (p.conditionSource=='all' or (p.conditionSource=='custom')==(custom[tag]~=nil)) and not seen[tag] and (definitions[tag] or (self.conditionSpecials or {})[tag]) then local d=definitions[tag] or self.conditionSpecials[tag];entries[#entries+1]={value=tag,text=d.description or d.desc or tag};seen[tag]=true end end
    if not seen[p.condition] and not p.creatingCondition then p.condition=entries[1] and entries[1].value end
    for _,entry in ipairs(entries) do entry.icon=custom[entry.value] and custom[entry.value].icon or self:GetConditionIcon(entry.value);entry.search=entry.value;entry.custom=custom[entry.value]~=nil end
    if self.ValidateCustomConditionSource then for _,entry in ipairs(entries) do if entry.custom then
        local checked,why=self:ValidateCustomConditionSource(entry.value,custom[entry.value],true)
        entry.invalid=not checked;entry.validationMessage=not checked and string.format(L['Invalid condition: %s'],why and (why.detail or why.reason) or L['Invalid custom condition.']) or nil
        entry.disabled=custom[entry.value].disabled==true
        if entry.disabled then entry.invalid=true;entry.validationMessage=L['This condition definition is disabled. Rotations using it are unavailable.']..(entry.validationMessage and '\n'..entry.validationMessage or '') end
    end end end
    local ordered
    if p.category=='SWITCH' or p.category=='DEFAULT' or groupIndex then ordered=tags end
    local function orderChanged(list) if p.category=='SWITCH' then profile.switch_conditions=list elseif p.category=='DEFAULT' then profile.other_conditions_order=list elseif groupIndex then groups[groupIndex].conditions=list end end
    local function navigate(fn) if self.BuildInlineCustomCondition then p:RequestLeave(fn) else fn() end end
    p:UseRoster(entries,p.condition,function(value) navigate(function() p.condition=value;p.creatingCondition=nil;p:Draw() end) end,{order=ordered,orderChanged=orderChanged,categories=categories,category=p.category,chooseCategory=function(value) navigate(function() p.category=value;p.condition=nil;p.creatingCondition=nil;p:Draw() end) end,sources={{value='all',text=L['All']},{value='builtin',text=L['Built In']},{value='custom',text=L['Custom']}},source=p.conditionSource,chooseSource=function(value) navigate(function() p.conditionSource=value;p.condition=nil;p.creatingCondition=nil;p:Draw() end) end,newText=L['Add'],new=function() if self.OpenInlineCustomCondition then self:OpenInlineCustomCondition(p,nil) else self:OpenSettingsCustomCondition(p,nil) end end,manage=function() navigate(function() p.mode='categories';p.categorySelection=nil;p:Draw() end) end})
    local compareCandidates={}
    for key,value in pairs(custom) do if key~=p.condition then compareCandidates[#compareCandidates+1]={value=key,text=value.description or key} end end
    table.sort(compareCandidates,function(a,b) return a.text<b.text end)
    p:SetRosterActions({{key='add_custom',text=L['Add'],icon='plus',action=p.roster.options.new},
        {key='duplicate_custom',text=L['Duplicate'],icon='copy',enabled=custom[p.condition]~=nil or self.GetBuiltinConditionSource and self:GetBuiltinConditionSource(p.condition)~=nil,action=function()
            if self.DuplicateInlineCustomCondition then self:DuplicateInlineCustomCondition(p);return end
            local tag=p.condition;local copy=self:CopySettingsData(custom[tag]);local key=tag:sub(1,216)..'_'..self:uuid():gsub('-','_');custom[key]=copy;p:RunSettingsEffect('custom_'..key,function() self:register_custom_condition(key,copy) end);p.condition=key;p.category='ALL';p.conditionSource='custom';p:Draw()
        end},
        {key='transfer',text=L['Import/Export'],icon='transfer',enabled=custom[p.condition]~=nil,action=function()
            local dialog=p.inlineCondition or self:OpenSettingsCustomCondition(p,p.condition,custom[p.condition])
            ---@cast dialog any
            if dialog then dialog.transfer:Click() end
        end},
        {key='compare',text=L['Compare'],icon='compare',enabled=custom[p.condition]~=nil and #compareCandidates>0,action=function()
            local first=p.condition
            p:ShowChoices(p.fields.compare,compareCandidates,function(key)
                if key~=first and custom[first] and custom[key] then self:ShowCollectionComparison(p,'profile',{name=custom[first].description,profile=custom[first]},{name=custom[key].description,profile=custom[key]}) end
            end)
        end}},true)
    local builtinSource=not custom[p.condition] and self.GetBuiltinConditionSource and self:GetBuiltinConditionSource(p.condition)
    if self.BuildInlineCustomCondition and (p.creatingCondition or custom[p.condition] or builtinSource) then return self:BuildInlineCustomCondition(p,p.condition,custom[p.condition] or builtinSource,type(builtinSource)=='table') end
    p:Heading(L['Conditions'])
    local tag=p.condition;local definition=definitions[tag] or (self.conditionSpecials or {})[tag]
    if tag and definition then
        p:Text(definition.description or definition.desc or tag);p:Text(custom[tag] and L['Custom condition'] or L['Built-in condition']);p:Text(L['Identifier']..': '..tag)
        for _,entry in ipairs(entries) do if entry.value==tag and entry.invalid then local problem=p:Text(entry.validationMessage);problem:SetTextColor(1,.3,.3) end end
        local special=(self.conditionSpecials or {})[tag]~=nil
        local hidden=p:Check('hidden',L['Hidden'],self:SettingsContains(profile.disabled_conditions,tag),function(value) profile.disabled_conditions=profile.disabled_conditions or {};self:SettingsFlag(profile.disabled_conditions,tag,value) end);if special then hidden:Disable() end
        local switch=p:Check('switch',L['Switch Condition'],self:SettingsContains(profile.switch_conditions,tag),function(value) profile.switch_conditions=profile.switch_conditions or {};self:SettingsFlag(profile.switch_conditions,tag,value) end);if special then switch:Disable() end
        local destinations={};local current='DEFAULT'
        for _,group in ipairs(groups) do destinations[#destinations+1]={value=group.id,text=group.name or group.id};if self:SettingsContains(group.conditions,tag) then current=group.id end end;destinations[#destinations+1]={value='DEFAULT',text=L['Other']}
        local assigned=current;local categoryName=L['Other'];for _,entry in ipairs(destinations) do if entry.value==assigned then categoryName=entry.text end end
        local categoryButton=p:Button('current_category',L['Category']..': '..categoryName,function() p.mode='categories';p.categorySelection=assigned;p:Draw() end)
        local assignedGroup;for _,group in ipairs(groups) do if group.id==assigned then assignedGroup=group end end
        categoryButton.categoryIcon=categoryButton.categoryIcon or categoryButton:CreateTexture(nil,'ARTWORK');categoryButton.categoryIcon:SetSize(20,20);categoryButton.categoryIcon:SetPoint('LEFT',3,0);categoryButton.categoryIcon:SetTexture(self:GetConditionCategoryIcon(assignedGroup));categoryButton.categoryIcon:Show();self:AlignWorkbenchTextLeft(categoryButton,28)
        local pending=p.pendingMove and p.pendingMove.tag==tag and p.pendingMove.destination or current
        local y=p.y;local move=p:Choice('move_to',L['Move To'],pending,destinations,function(destination) p.pendingMove={tag=tag,destination=destination};p:Draw() end);move:SetWidth(math.max(60,p.width-326));if special then move:Disable() end
        local apply=p:Button('apply_move',L['Apply'],function()
            local destination=p.pendingMove and p.pendingMove.tag==tag and p.pendingMove.destination
            if not destination then return end
            for _,group in ipairs(groups) do group.conditions=group.conditions or {};self:SettingsFlag(group.conditions,tag,false);if group.id==destination then group.conditions[#group.conditions+1]=tag end end
            profile.other_conditions_order=profile.other_conditions_order or {};self:SettingsFlag(profile.other_conditions_order,tag,destination=='DEFAULT');p.pendingMove=nil;p.category='ALL';p.condition=tag;p:Draw()
        end);apply:ClearAllPoints();apply:SetPoint('TOPRIGHT',0,-y);apply:SetWidth(100);p.y=p.y-28;if special or pending==current then apply:Disable() end
        if custom[tag] then
            local source=custom[tag];local enabledY=p.y
            local toggle=p:Toggle('definition_enabled',nil,not source.disabled,L['Disabled'],L['Enabled'],function(value)
                if value then
                    local checked,why=self:ValidateCustomConditionSource(tag,source,true)
                    if not checked then p:Draw();p:Message(string.format(L['Invalid condition: %s'],why and (why.detail or why.reason) or L['Invalid custom condition.']));return end
                end
                local original=self:CopySettingsData(p.draftBaseline and p.draftBaseline.global.custom_conditions[tag] or self.db.global.custom_conditions[tag]);local expected=self.conditionDefinitions[tag]
                source.disabled=not value
                p:RunSettingsEffect('custom_'..tag,function()
                    local ok,why=self:InstallCustomCondition(tag,source,expected,source)
                    if not ok then self.db.global.custom_conditions[tag]=original;p:Message(string.format(L['Invalid condition: %s'],why and (why.detail or why.reason) or L['Invalid custom condition.'])) end
                end);p:Draw()
            end)
            toggle:ClearAllPoints();toggle:SetPoint('TOPRIGHT',-28,-4);toggle:SetWidth(84);p.y=enabledY
            p:Actions({{key='edit_custom',text=L['Edit'],icon='info',action=function() self:OpenSettingsCustomCondition(p,tag,custom[tag]) end},
                })
            p.fields.delete_custom=self:SettingsTopDelete(p,function()
                self:ConfirmSettingsDeletion(p,L['Delete this custom condition? Existing rotations using it will become unavailable.'],function()
                    local ok,why=self:DeleteSavedCustomCondition(tag);if ok then p.condition=nil end;return ok,why
                end)
            end)
        end
    end
end
function addon:BuildConditionCategorySettings(p)
    local store=p:SettingsData()
    local profile=store.profile;local groups=profile.condition_groups or {};local definitions=self.conditionDefinitions or {}
    local entries={};local index
    for i,group in ipairs(groups) do entries[#entries+1]={value=group.id,text=group.name or group.id,icon=self:GetConditionCategoryIcon(group)};if group.id==p.categorySelection then index=i end end
    if not index and not p.creatingCategory and p.categorySelection~='SWITCH' and p.categorySelection~='DEFAULT' then p.categorySelection=groups[1] and groups[1].id or 'DEFAULT';index=groups[1] and 1 end
    entries[#entries+1]={value='SWITCH',text=L['Switch']};entries[#entries+1]={value='DEFAULT',text=L['Other']}
    p:UseRoster(entries,p.creatingCategory and nil or p.categorySelection,function(id) p.categorySelection=id;p.creatingCategory=false;p:Draw() end,{order=groups,newText=L['New'],new=function() p.creatingCategory=true;p:Draw() end,manageText=L['Manage conditions'],manage=function() p.mode=nil;p:Draw() end})
    p:SetRosterActions({{key='new_category',text=L['New'],icon='plus',action=p.roster.options.new},{key='transfer',text=L['Import/Export'],icon='transfer',enabled=not p.creatingCategory and p.categorySelection~=nil,action=function() if p.categoryTransfer then p.categoryTransfer() end end}},true)
    p:Heading(L['Manage categories'])
    if p.creatingCategory or not p.categorySelection then
        p.newGroupName=p.newGroupName or '';p:Edit('new_group_name',L['Name'],p.newGroupName,nil,function(text) p.newGroupName=text end)
        p:CreationActions(function()
            if not self:SettingsNonempty(p.newGroupName) then p:Message(L['Enter a name first.']);return end
            local id=self:uuid();profile.condition_groups=profile.condition_groups or {};profile.condition_groups[#profile.condition_groups+1]={id=id,name=p.newGroupName,conditions={}};p.newGroupName='';p.categorySelection=id;p.creatingCategory=false;p:Draw()
        end,function() p.creatingCategory=false;p.newGroupName=nil;p:Draw() end);p.fields.add_group=p.fields.apply;return
    end
    local category=p.categorySelection;local group=index and groups[index]
    if group then
        p:Edit('group_name',L['Name'],group.name or '',function(text) return self:SettingsNonempty(text) end,function(text) group.name=text;for _,entry in ipairs(p.roster.entries) do if entry.value==group.id then entry.text=text end end;p:RefreshRoster() end)
        local y=p:Row(L['Icon'],40);local icon=p:Acquire('categoryIcon',function() local button=self:CreateWorkbenchButton(p.child,'',32);button.image=button:CreateTexture(nil,'ARTWORK');button.image:SetAllPoints(button);return button end)
        icon:ClearAllPoints();icon:SetPoint('TOPLEFT',220,-y);icon:SetSize(32,32);icon.image:SetTexture(self:GetConditionCategoryIcon(group));p.fields.category_icon=icon
        self:SetUIScript(icon,'OnClick',p:Guard(function() if not p:FlushEdits() then return end
            local token=p.generation;local picker=self:ShowWorkbenchIconPicker(group.icon,p:Guard(function(texture) if p:FlushEdits() then group.icon=texture;p:Draw() end end),function() return p:Valid(token) end);local serial=picker.serial
            p.cleanups[#p.cleanups+1]=function() if picker.serial==serial then picker.frame:Hide() end end
        end))
    else p:Text(L['Built-in category']) end
    local tags=self:listConditions(category,true,store);local cols=math.max(1,math.floor(p.width/240));local cellWidth=(p.width-8*(cols-1))/cols;local top=p.y
    for i,tag in ipairs(tags) do
        local definition=definitions[tag] or (self.conditionSpecials or {})[tag];local custom=(store.global.custom_conditions or {})[tag]~=nil
        local cell=p:Acquire('categoryMembers',function() local button=self:CreateWorkbenchButton(p.child,'',cellWidth);button.image=button:CreateTexture(nil,'ARTWORK');button.image:SetSize(24,24);button.image:SetPoint('LEFT',3,0);return button end)
        cell:ClearAllPoints();cell:SetPoint('TOPLEFT',((i-1)%cols)*(cellWidth+8),-top-math.floor((i-1)/cols)*32);cell:SetSize(cellWidth,28);cell:SetText(definition and (definition.description or definition.desc) or tag);self:AlignWorkbenchTextLeft(cell,34);cell.image:SetTexture(self:GetConditionIcon(tag));cell:GetFontString():SetTextColor(custom and .92 or .4,custom and .94 or .7,custom and .96 or 1);p.fields['member_'..tag]=cell
        self:SetUIScript(cell,'OnClick',p:Guard(function() if p:FlushEdits() then p.mode=nil;p.category=category;p.conditionSource='all';p.condition=tag;p:Draw() end end))
    end
    p.y=top+math.ceil(#tags/cols)*32+8
    p.categoryTransfer=function()
        local codec=self:NewRotationCodec();local exported,why=codec:Encode({format='RM-ConditionCategory',version=1,name=group and group.name,icon=group and group.icon,conditions=tags});if not exported then p:Message(why);return end
        self:ShowSettingsTextTransfer(p,L['Conditions'],exported,function(text,settings)
            local parsed,errorText=self:ParseConditionCategoryImport(text,codec);if not parsed then return false,errorText end;local candidate=parsed.conditions
            local destination=category;local target=group
            if settings.mode=='new' then local id=self:uuid();target={id=id,name=settings.name,conditions={}};profile.condition_groups=profile.condition_groups or {};profile.condition_groups[#profile.condition_groups+1]=target;destination=id;p.categorySelection=id end
            if destination=='SWITCH' then profile.switch_conditions=candidate elseif destination=='DEFAULT' then
                for _,other in ipairs(groups) do for _,value in ipairs(candidate) do self:SettingsFlag(other.conditions or {},value,false) end end
                profile.other_conditions_order=candidate
            else
                for _,value in ipairs(candidate) do self:SettingsFlag(profile.other_conditions_order or {},value,false) end
                for _,other in ipairs(groups) do if other~=target then for _,value in ipairs(candidate) do self:SettingsFlag(other.conditions or {},value,false) end end end;target.conditions=candidate;if parsed.metadata then target.icon=parsed.icon end
            end;return true
        end,{canReplace=true,selectedName=group and group.name or category=='SWITCH' and L['Switch'] or L['Other'],fallbackName=L['Imported category'],originalName=function(input) local parsed=self:ParseConditionCategoryImport(input,codec);return parsed and parsed.name end})
    end
    if group then p.fields.delete_category=self:SettingsTopDelete(p,function()
        self:ConfirmSettingsDeletion(p,L['Delete this category? Its conditions will remain available under Other.'],function()
            for i,current in ipairs(self.db.profile.condition_groups or {}) do if current.id==category then
                table.remove(self.db.profile.condition_groups,i);if p.category==category then p.category='DEFAULT' end;p.categorySelection=nil;return true
            end end;return false,'category-changed'
        end)
    end) end
end
function addon:OpenSettingsCustomCondition(p,key,condition)
    if p.transactionKeys and p:IsSettingsDraftDirty() then p:Message(L['Apply or discard current settings before opening the custom code editor.']);return end
    local token=p.generation
    local dialog,owner=self:condition_edit_box(p:Guard(function(newKey) if p.draft then p.draft.global.custom_conditions=self:CopySettingsData(self.db.global.custom_conditions);p.draftBaseline.global.custom_conditions=self:CopySettingsData(self.db.global.custom_conditions) end;p.condition=newKey;p.category='ALL';p.conditionSource='custom';p:Draw() end),key,condition and self.deepcopy(condition) or nil,function() return p:Valid(token) end)
    if dialog then p.cleanups[#p.cleanups+1]=function() addon:CloseCustomConditionEditor(dialog,owner) end end
    return dialog,owner
end
