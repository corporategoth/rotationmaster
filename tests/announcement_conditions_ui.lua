local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function fixture()
 local prefix=assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))
 local f,parent=assert(loadstring(prefix..'\nreturn fixture()','@announcement-condition-ui'))();local a=f.addon
 for _,path in ipairs({'Data/condition_draft.lua','Core/conditions.lua','Core/condition_catalog.lua','Core/condition_editor.lua','Core/condition_canvas.lua','UI/condition_picker.lua','UI/condition_cards.lua','UI/condition_canvas.lua','UI/condition_editor.lua'})do f.load(path)end
 a:RegisterCondition('FLAG',{description='Flag',fields={match='boolean'},valid=function()return true end,evaluate=function()error('editor evaluated')end,print=function()return 'Flag' end})
 a.GetImportValidationOptions=function()return {conditions=a.conditionDefinitions}end
 local kind;a.listConditions=function(_,selection)kind=selection;return {'AND','OR','NOT','FLAG'}end
 a.UpdateAutoSwitch=function()error('announcement edit refreshed rotation')end;a.SwitchRotation=function()error('announcement edit switched rotation')end
 a.db.profile.announces={{id='a',type='spell',spell=547,event='START',announce='local',value='Saved'}}
 return f,a,parent,function()return kind end
end
test('announcement child uses Switch choices and keeps child Apply staged until parent Apply',function()
 local _,a,parent,kind=fixture();local p=a:OpenNativeSettings(parent,'Announces')
 p.fields.entry1conditions:Click();local shell=assert(a.compactConditionEditor)
 shell.canvas.cards[1].typeButton:Click();assert(shell:GetUserData('announcement')==true and shell.active.persistentOwner and kind()=='SWITCH');shell.openPicker:Dismiss()
 assert(shell.active.session:Command('Replace',{}, {type='FLAG',match=true}));shell.active.working=shell.active.session:Snapshot();shell:Render();shell.apply:Click()
 assert(not shell.active and a.db.profile.announces[1].conditions==nil and p:IsSettingsDraftDirty())
 p.fields.apply:Click();assert(a.db.profile.announces[1].conditions.type=='FLAG')
 p.fields.entry1conditions:Click();shell.cancel:Click();assert(a.db.profile.announces[1].conditions.match==true)
end)
test('cancel opening no conditions and parent Discard preserve absence and original data',function()
 local _,a,parent=fixture();local p=a:OpenNativeSettings(parent,'Announces');p.fields.entry1conditions:Click();local shell=a.compactConditionEditor;shell.cancel:Click()
 assert(not p:IsSettingsDraftDirty() and a.db.profile.announces[1].conditions==nil)
 p.fields.entry1conditions:Click();assert(shell.active.session:Command('Replace',{}, {type='FLAG',match=false}));shell.active.working=shell.active.session:Snapshot();shell:Render();shell.apply:Click();p.fields.cancel:Click()
 assert(a.db.profile.announces[1].conditions==nil and not p:IsSettingsDraftDirty())
end)
test('retired parent or replaced announcement rejects stale child Apply',function()
 local _,a,parent=fixture();local p=a:OpenNativeSettings(parent,'Announces');p.fields.entry1conditions:Click();local shell=a.compactConditionEditor
 assert(shell.active.session:Command('Replace',{}, {type='FLAG',match=true}));shell.active.working=shell.active.session:Snapshot();shell:Render()
 local replacement={id='b',type='spell',spell=547,event='START',announce='local',value='Other'}
 p:SettingsData().profile.announces[1]=replacement;shell.apply:Click();assert(replacement.conditions==nil and shell.active)
 p:Release();shell.apply:Click();assert(a.db.profile.announces[1].conditions==nil);shell.cancel:Click()
end)
test('in-place parent condition edits cannot be overwritten by a stale child',function()
 local _,a,parent=fixture();a.db.profile.announces[1].conditions={type='FLAG',match=false}
 local p=a:OpenNativeSettings(parent,'Announces');p.fields.entry1conditions:Click();local shell=a.compactConditionEditor
 assert(shell.active.session:Command('SetDisabled',{},true));shell.active.working=shell.active.session:Snapshot();shell:Render()
 p:SettingsData().profile.announces[1].conditions.match=true;shell.apply:Click()
 assert(shell.active and p:SettingsData().profile.announces[1].conditions.match==true);shell.cancel:Click()
end)
test('announcement trees survive codec and appear as readable comparison rows',function()
 local _,a=fixture();local entry=a.db.profile.announces[1];entry.conditions={type='NOT',value={type='FLAG',match=false}}
 local codec=a:NewRotationCodec();local text=assert(codec:Encode({format='RM-Announcement',version=1,announcement=entry}));local decoded=assert(codec:Decode(text)).value.announcement
 assert(a:IsValidAnnouncement(decoded) and decoded.conditions.value.match==false)
 local rows=a:CollectionComparisonRows('announcement',entry,{type='spell',spell=547,event='START',announce='local',value='Saved'},false)
 assert(#rows==1 and rows[1].label=='Conditions' and not rows[1].left:find('table:',1,true))
end)
finish()
