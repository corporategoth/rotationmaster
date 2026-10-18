local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:SettingsEntries(values)
    local entries={};for id,value in pairs(values or {}) do if type(value)=='table' then entries[#entries+1]={value=id,text=type(value.name)=='string' and value.name or tostring(id)} end end
    table.sort(entries,function(a,b) if a.text==b.text then return tostring(a.value)<tostring(b.value) end;return a.text<b.text end);return entries
end
function addon:SettingsNonempty(text) if type(text)=='string' and text:find('%S') then return text end end
function addon:SettingsPositiveID(text) local n=tonumber(text);if n and n>0 and n==math.floor(n) then return n end end
function addon:SettingsFlag(list,value,enabled)
    for i=#list,1,-1 do if list[i]==value then table.remove(list,i) end end
    if enabled then list[#list+1]=value end
end
function addon:SettingsContains(list,value) for _,entry in ipairs(list or {}) do if entry==value then return true end end;return false end
function addon:SettingsOrderControls(p,prefix,list,i,changed)
    local function move(destination) local value=table.remove(list,i);table.insert(list,destination,value);changed();p:Draw() end
    p:Actions({{key=prefix..'top',text=L['Move to Top'],icon='chevron-double-down',enabled=i>1,action=function() move(1) end},
        {key=prefix..'up',text=L['Move Up'],icon='up',enabled=i>1,action=function() move(i-1) end},
        {key=prefix..'down',text=L['Move Down'],icon='down',enabled=i<#list,action=function() move(i+1) end},
        {key=prefix..'bottom',text=L['Move to Bottom'],icon='chevron-double-down',enabled=i<#list,action=function() move(#list) end},
        {key=prefix..'remove',text=L['Delete'],icon='trash',action=function() table.remove(list,i);changed();p:Draw() end}})
end
function addon:OpenNativeSettings(parent,key,cached)
    local builders={General=self.BuildGeneralSettings,Profiles=self.BuildProfileSettings,About=self.BuildAboutSettings,
        Announces=self.BuildAnnounceSettings,Effects=self.BuildEffectSettings,ItemSets=self.BuildItemSettings,Conditions=self.BuildConditionSettings}
    local build=builders[key];if not build then return end
    local p=cached or self:CreateSettingsForm(parent)
    local scopes={Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}
    p.settingsKey=key;p.historyEnabled=key=='ItemSets';p.transactionKeys=scopes[key];p:SetWidth(parent:GetWidth());p:SetHeight(parent:GetHeight());p:Open(function(form) build(self,form) end);return p
end

function addon:CollectionFooter(p,kind,values,current,duplicate,transfer)
    local candidates={};for _,entry in ipairs(self:SettingsEntries(values)) do if entry.value~=current then candidates[#candidates+1]=entry end end
    p:SetRosterActions({{key='new_collection',text=L['New'],icon='plus',action=p.roster.options.new},duplicate,transfer,
        {key='compare',text=L['Compare'],icon='compare',enabled=values[current]~=nil and #candidates>0,action=function()
            p:ShowChoices(p.fields.compare,candidates,function(id) p.fields.compare:SetText(L['Compare']);if id~=current and values[id] and values[current] then self:ShowCollectionComparison(p,kind,values[current],values[id]) end end)
        end}})
end
function addon:SettingsTopDelete(p,action)
    local c=p:Acquire('rootDelete',function() return self:CreateWorkbenchIconButton(p.child,'trash',L['Delete']) end);c:ClearAllPoints();c:SetPoint('TOPRIGHT',0,-4);c.icon:SetVertexColor(1,.25,.25,1);c:Enable();p.fields.delete=c
    self:SetUIScript(c,'OnClick',p:Guard(function() if p:FlushEdits() then action() end end));return c
end
