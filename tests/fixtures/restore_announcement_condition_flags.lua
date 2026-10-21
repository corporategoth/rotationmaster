local outer=dofile('tests/fixtures/restore_final_composition.lua')
-- Closed additive inverse to the complete 6a676575 predecessor.
local deltas={
 [ [==[
Core/condition_catalog.lua]==] ]={
  {[==[
    if group == "SWITCH" or group == "ANNOUNCEMENT" then
        local selected=profile.switch_conditions
        if group=="ANNOUNCEMENT" then selected=profile.announcement_conditions end
        for _, cond in pairs(type(selected)=="table" and selected or {}) do
]==],[==[
    if group == "SWITCH" then
        for _, cond in pairs(profile.switch_conditions) do
]==]},
 },
 [ [==[
Core/profile_data.lua]==] ]={
  {[==[
        elseif key=='switch_conditions' or key=='announcement_conditions' or key=='disabled_conditions' or key=='other_conditions_order' then if not dense(item,stringValue) then return false end
]==],[==[
        elseif key=='switch_conditions' or key=='disabled_conditions' or key=='other_conditions_order' then if not dense(item,stringValue) then return false end
]==]},
 },
 [ [==[
Help/conditions.lua]==] ]={
  {[==[
        {title=L["Announcement Condition"],text=L["Offer this condition type when editing announcement conditions. This flag is independent of Switch Condition and does not remove or invalidate conditions already saved in announcements."]},
]==],[==[
]==]},
 },
 [ [==[
Locales/enUS.lua]==] ]={
  {[==[

L['Announcement Condition'] = true
L['Announcement'] = true
L['Show this condition in the announcement condition editor.'] = true
L['Offer this condition type when editing announcement conditions. This flag is independent of Switch Condition and does not remove or invalidate conditions already saved in announcements.'] = true
]==],[==[
]==]},
  {[==[
L["Help.Announces.conditions"] = "Optional conditions use the Announcement condition list and All, Any and Not groups. They run only when this announcement's spell and event match. Only a matching result allows its message or sound; unavailable data skips the announcement. In Group can check the Spell recipient recorded for this cast, including click casting, without using your selected target. Missing or ambiguous recipients skip that check. Apply in the condition editor updates the announcement draft; Apply on Announces saves it. Cancel or Discard abandons draft changes."
]==],[==[
L["Help.Announces.conditions"] = "Optional conditions use the Switch condition list and All, Any and Not groups. They run only when this announcement's spell and event match. Only a matching result allows its message or sound; unavailable data skips the announcement. In Group can check the Spell recipient recorded for this cast, including click casting, without using your selected target. Missing or ambiguous recipients skip that check. Apply in the condition editor updates the announcement draft; Apply on Announces saves it. Cancel or Discard abandons draft changes."
]==]},
 },
 [ [==[
UI/condition_editor.lua]==] ]={
  {[==[
        local picker=addon:CreateConditionTypePicker(window,self.userdata.announcement and "ANNOUNCEMENT" or active.index and active.index>0 and "ALL" or "SWITCH",node and node.type,
]==],[==[
        local picker=addon:CreateConditionTypePicker(window,active.index and active.index>0 and "ALL" or "SWITCH",node and node.type,
]==]},
 },
 [ [==[
UI/condition_source_pane.lua]==] ]={
  {[==[
        draft.announcement_conditions=draft.announcement_conditions or {};membership(draft.announcement_conditions,context.announcement)
]==],[==[
]==]},
  {[==[
        for _,field in ipairs({'hidden','switch','announcement'}) do self:SetWorkbenchUnsaved(d.form.fields[field],d.model.context[field]~=d.model.baseline.context[field]) end
]==],[==[
        for _,field in ipairs({'hidden','switch'}) do self:SetWorkbenchUnsaved(d.form.fields[field],d.model.context[field]~=d.model.baseline.context[field]) end
]==]},
  {[==[
        local announcement=form:Check('announcement',L['Announcement Condition'],context.announcement,function(value) d.model:Change(function(model) model.context.announcement=value end);d:UpdateActions() end);announcement.tooltip=L['Show this condition in the announcement condition editor.'];form.cleanups[#form.cleanups+1]=function() announcement.tooltip=nil end
]==],[==[
]==]},
  {[==[
    local preferences={hidden=self:SettingsContains(profile.disabled_conditions,key),switch=self:SettingsContains(profile.switch_conditions,key),announcement=self:SettingsContains(profile.announcement_conditions,key),category='DEFAULT'}
]==],[==[
    local preferences={hidden=self:SettingsContains(profile.disabled_conditions,key),switch=self:SettingsContains(profile.switch_conditions,key),category='DEFAULT'}
]==]},
 },
 [ [==[
UI/settings_collections.lua]==] ]={
  {[==[
    local scopes={Integrations={profile={'lua_editor','lua_editor_disabled','lua_native_highlighting','lua_line_numbers','questie_enabled','preview_masque'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','announcement_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}
]==],[==[
    local scopes={Integrations={profile={'lua_editor','lua_editor_disabled','lua_native_highlighting','lua_line_numbers','questie_enabled','preview_masque'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}
]==]},
 },
 [ [==[
UI/settings_conditions.lua]==] ]={
  {[==[
        local announcement=p:Check('announcement',L['Announcement Condition'],self:SettingsContains(profile.announcement_conditions,tag),function(value) profile.announcement_conditions=profile.announcement_conditions or {};self:SettingsFlag(profile.announcement_conditions,tag,value) end);announcement.tooltip=L['Show this condition in the announcement condition editor.'];p.cleanups[#p.cleanups+1]=function() announcement.tooltip=nil end;if special then announcement:Disable() end
]==],[==[
]==]},
  {[==[
    if p.category=='SWITCH' or p.category=='ANNOUNCEMENT' or p.category=='DEFAULT' or groupIndex then ordered=tags end
    local function orderChanged(list) if p.category=='SWITCH' then profile.switch_conditions=list elseif p.category=='ANNOUNCEMENT' then profile.announcement_conditions=list elseif p.category=='DEFAULT' then profile.other_conditions_order=list elseif groupIndex then groups[groupIndex].conditions=list end end
]==],[==[
    if p.category=='SWITCH' or p.category=='DEFAULT' or groupIndex then ordered=tags end
    local function orderChanged(list) if p.category=='SWITCH' then profile.switch_conditions=list elseif p.category=='DEFAULT' then profile.other_conditions_order=list elseif groupIndex then groups[groupIndex].conditions=list end end
]==]},
  {[==[
    categories[#categories+1]={value='DEFAULT',text=L['Other'],icon=self:GetConditionCategoryIcon(nil)};if p.category~='ALL'  and p.category~='SWITCH' and p.category~='ANNOUNCEMENT' and p.category~='DEFAULT' and not groupIndex then p.category='ALL' end
]==],[==[
    categories[#categories+1]={value='DEFAULT',text=L['Other'],icon=self:GetConditionCategoryIcon(nil)};if p.category~='ALL'  and p.category~='SWITCH' and p.category~='DEFAULT' and not groupIndex then p.category='ALL' end
]==]},
  {[==[
    local categories={{value='ALL',text=L['All'],icon=self:GetConditionCategoryIcon({id='ALL'})},{value='SWITCH',text=L['Switch'],icon=self:GetConditionCategoryIcon({id='SWITCH'})},{value='ANNOUNCEMENT',text=L['Announcement'],icon=self:GetConditionCategoryIcon({id='SWITCH'})}}
]==],[==[
    local categories={{value='ALL',text=L['All'],icon=self:GetConditionCategoryIcon({id='ALL'})},{value='SWITCH',text=L['Switch'],icon=self:GetConditionCategoryIcon({id='SWITCH'})}}
]==]},
 },
 [ [==[
init.lua]==] ]={
  {[==[
    self:InstallAnnouncementConditionPreferences()
]==],[==[
]==]},
  {[==[
-- Optional picker preferences have no AceDB defaults: logout must preserve an
-- explicit empty list. Only absent fields receive this cold, bounded seed.
local announcementPreferenceOwner={}
local defaultAnnouncementConditions={'AND','OR','NOT','COMBAT','GROUP','ENEMY','DEAD','FRIENDLY','LEVEL','SELF_LEVEL','PVP','ZONEPVP','ZONE','INSTANCE','OUTDOORS','STEALTHED','FORM','CLASS','CLASS_GROUP','CREATURE','CLASSIFICATION','PET','PET_NAME','ROLE'}
local function seedAnnouncementPreferences(profile)
    if type(profile)=='table' and rawget(profile,'announcement_conditions')==nil then
        profile.announcement_conditions=deepcopy(defaultAnnouncementConditions)
    end
end
function addon:InstallAnnouncementConditionPreferences()
    local db=self.db
    if not db then return end
    if announcementPreferenceOwner.db~=db then
        announcementPreferenceOwner.db=db
        local function changed(_,currentDB)
            if currentDB==addon.db and currentDB==announcementPreferenceOwner.db then seedAnnouncementPreferences(currentDB.profile) end
        end
        for _,event in ipairs({'OnNewProfile','OnProfileChanged','OnProfileCopied','OnProfileReset'}) do
            db.RegisterCallback(announcementPreferenceOwner,event,changed)
        end
    end
    for _,profile in pairs(db.sv and db.sv.profiles or {}) do seedAnnouncementPreferences(profile) end
    seedAnnouncementPreferences(db.profile)
end

]==],[==[
]==]},
 },
 [ [==[
validate.lua]==] ]={
  {[==[
        validate_basic("profile:" .. profile, data, profile_template, fix,{announcement_conditions=true,stockTargets=true,rotationStore=true,rotationFallbackID=true,rotations=addon.InitializeScopedRotationStorage~=nil,rotationLibrary=addon.InitializeScopedRotationStorage~=nil})
]==],[==[
        validate_basic("profile:" .. profile, data, profile_template, fix,{stockTargets=true,rotationStore=true,rotationFallbackID=true,rotations=addon.InitializeScopedRotationStorage~=nil,rotationLibrary=addon.InitializeScopedRotationStorage~=nil})
]==]},
 },
}
return function(text,path)
 text=outer(text,path,'flag')
 for _,delta in ipairs(deltas[path] or {}) do
  local first,last=text:find(delta[1],1,true);assert(first and not text:find(delta[1],last+1,true),"Announcement flag inverse drift: "..path)
  text=text:sub(1,first-1)..delta[2]..text:sub(last+1)
 end
 return text
end
