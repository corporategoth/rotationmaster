-- Native form/editor integration transitions; no provider implementation doubles.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
if arg and arg[1]=='--layout-only' then
 local run=test
 test=function(name,fn)
  if name=='grouped native cards expose independent enable and select controls'
   or name=='warm redraw reuses native cards and narrow columns remain contained'
   or name=='localized column headings share card anchors and controls stay within narrow cards'
   or name=='baseline editor choices stay outside addon cards and passive integrations have no invented controls' then run(name,fn)end
 end
end
local function nativeFixture()
 local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
 a.pretty_name='Rotation Master';a.name='rotationmaster';a.configPaneGeneration=1
 for _,path in ipairs({'UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/settings_collections.lua'})do f.load(path)end
 local ok=pcall(require,'bit')
 if ok then local data,deps=dofile('tests/fixtures/codec.lua')();a.RotationData=data;a.NewRotationCodec=function()return data.NewCodec(deps)end end
 if not a.RotationData then for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua'})do f.load(path)end end
 local parent=create('Frame');parent:SetSize(1000,600)
 return f,parent
end
local function fixture(available)
 local f,parent=nativeFixture();local a=f.addon;local availableNow=available~=false;local made=0
 f.load('UI/lua_editor.lua');f.load('UI/settings_integrations.lua');f.load('Core/profile_data.lua')
 a.db.profile.lua_editor='auto';a.LuaSyntax={enable=function()end,disable=function()end,decode=function(text)return text end}
 a.ListIntegrationStatus=function()return{{id='!!!LuaWorkbench',name='LuaWorkbench',version='1.2',state=availableNow and 'connected' or 'missing',detail='Editor provider'},
 {id='WowLua',name='WowLua',state='missing',detail='Detection only'}, {id='Questie',name='Questie',state='disabled',detail='Quest receipts'},
 {id='ExtendedCharacterStats',name='ExtendedCharacterStats',state='loaded',detail='Condition data'}, {id='WeakAuras',name='WeakAuras',state='loaded',detail='Notifications'},
 {id='Dominos',name='Dominos',state='loaded',detail='Action bars'}}end
 a.IsLuaWorkbenchIntegrationAvailable=function()return availableNow end
 a.GetQuestieIntegrationStatus=function()return{state='disabled',nativeAcceptance='unverified'}end
 a.SyncQuestieIntegration=function()made=made+1 end;a.RefreshQuestieIntegration=function()made=made+1 end
 a.DiscoverLuaEditorIntegrations=function()end
 a:RegisterLuaEditorProvider('LuaWorkbench',function(host,changed,valid)
  if not availableNow then return nil end
  return a:CreateWorkbenchLuaEditor(host,changed,valid,'plain')
 end)
 local p=a:OpenNativeSettings(parent,'Integrations')
 local function calls()return made end
 local function availability(v)availableNow=v end
 return f,a,parent,p,calls,availability
end
local function click(p,key)local c=assert(p.fields[key],key..' missing');c:Click()end
local function choice(p)return p:SettingsData().profile.lua_editor end
local function open(a,parent,preferred,owner)
 return a:AcquireSourceLuaEditor(owner or{},parent,function()end,function()return true end,preferred)
end

test('grouped native cards expose independent enable and select controls',function()
 local _,_,_,p=fixture()
 assert(p.fields.integration_select_plain and p.fields.integration_select_auto)
 assert(p.fields.integration_enable_native and p.fields.integration_select_native)
 assert(p.fields.integration_enable_LuaWorkbench and p.fields.integration_select_LuaWorkbench)
 assert(not p.fields.integration_enable_WowLua and not p.fields.integration_enable_Dominos)
 assert(p.fields.integration_card_Questie and p.fields.questie_enabled)
end)
test('enable does not select; disabling selected moves to None and blocks selection',function()
 local _,a,_,p=fixture();click(p,'integration_select_LuaWorkbench');assert(choice(p)=='LuaWorkbench')
 click(p,'integration_enable_LuaWorkbench');assert(choice(p)=='plain' and p:SettingsData().profile.lua_editor_disabled.LuaWorkbench)
 click(p,'integration_select_LuaWorkbench');assert(choice(p)=='plain')
 click(p,'integration_enable_LuaWorkbench');assert(choice(p)=='plain' and not (p:SettingsData().profile.lua_editor_disabled or {}).LuaWorkbench)
 click(p,'integration_select_native');assert(choice(p)=='native');assert(a.db.profile.lua_editor=='auto')
 click(p,'integration_select_LuaWorkbench');assert(choice(p)=='LuaWorkbench')
end)
test('None is an always enabled baseline; Auto remains an explicit independent mode',function()
 local _,_,_,p=fixture();assert(not p.fields.integration_enable_plain and not p.fields.integration_enable_auto)
 click(p,'integration_select_plain');assert(choice(p)=='plain');click(p,'integration_select_auto');assert(choice(p)=='auto')
 click(p,'integration_enable_native');assert(choice(p)=='auto')
end)
test('Apply persists map and selection; Discard preserves saved settings',function()
 local _,a,_,p=fixture();click(p,'integration_enable_LuaWorkbench');assert(not a.db.profile.lua_editor_disabled)
 assert(p:IsSettingsDraftDirty());p:DiscardSettingsDraft();p:Draw();assert(not a.db.profile.lua_editor_disabled)
 click(p,'integration_enable_LuaWorkbench');click(p,'integration_select_native');assert(p:SaveSettingsDraft())
 assert(a.db.profile.lua_editor=='native' and a.db.profile.lua_editor_disabled.LuaWorkbench)
end)
test('saved Auto and explicit paths honor disabled providers including source-host acquisition',function()
 local _,a,parent=fixture();a.db.profile.lua_editor_disabled={LuaWorkbench=true}
 local c=open(a,parent,'auto');assert(c.provider=='native');c:Release()
 c=a:CreateWorkbenchLuaEditor(parent,function()end,function()return true end,'LuaWorkbench');assert(c.provider=='native' and not c.syntax,'disabled explicit provider did not use None');c:Release()
 a.db.profile.lua_editor_disabled.native=true
 c=open(a,parent,'auto');assert(c.provider=='native' and not c.syntax);c:Release()
 c=open(a,parent,'native');assert(not c.syntax);c:Release()
end)
test('available enabled external provider remains selected while missing entry refuses selection',function()
 local _,a,parent,p,_,availability=fixture();local c=open(a,parent,'auto');assert(c.provider=='LuaWorkbench');c:Release()
 availability(false);p:Draw();click(p,'integration_select_LuaWorkbench');assert(choice(p)=='auto')
 click(p,'integration_enable_LuaWorkbench');click(p,'integration_enable_LuaWorkbench');assert(choice(p)=='auto')
end)
test('registered custom extensions preserve selection and Auto without persisted enable inventions',function()
 local _,a,parent,p=fixture();a:RegisterLuaEditorProvider('A custom',function(host,changed,valid)return a:CreateWorkbenchLuaEditor(host,changed,valid,'plain')end)
 p:Draw();assert(p.fields['integration_select_A custom'] and not p.fields['integration_enable_A custom'])
 click(p,'integration_select_A custom');assert(choice(p)=='A custom')
 local c=open(a,parent,'auto');assert(c.provider=='A custom');c:Release()
end)
test('profile schema accepts closed true-only map and preserves portable copies',function()
 local f,a=fixture();assert(a:ValidateProfileTransfer({lua_editor_disabled={native=true,LuaWorkbench=true},lua_editor='plain'}))
 local v={lua_editor_disabled={LuaWorkbench=true},lua_editor='auto'};local wire=assert(a:ProfileToPortable(v));local restored=assert(a:ProfileFromPortable(wire));assert(restored.lua_editor_disabled.LuaWorkbench and restored.lua_editor=='auto')
 restored.lua_editor_disabled.LuaWorkbench=nil;assert(v.lua_editor_disabled.LuaWorkbench)
 for _,bad in ipairs({{LuaWorkbench=false},{other=true},{auto=true},{plain=true},{native=1},setmetatable({native=true},{})})do assert(not a:ValidateProfileTransfer({lua_editor_disabled=bad}))end
 assert(a:ValidateProfileTransfer({}) and a:ValidateProfileTransfer({lua_editor_disabled={}}))
end)
test('real codec profile roundtrip retains disabled entries without generated defaults',function()
 if not (bit or bit32)then print('SKIP real LibCompress codec: native bit library unavailable in this Lua VM');return end
 local _,a=fixture();local profile={lua_editor='plain',lua_editor_disabled={native=true,LuaWorkbench=true}}
 local codec=assert(a.NewRotationCodec());local encoded=assert(codec:Encode(a:ProfileToPortable(profile)));local decoded=assert(codec:Decode(encoded));local restored=assert(a:ProfileFromPortable(decoded.value));assert(restored.lua_editor_disabled.native and restored.lua_editor_disabled.LuaWorkbench and restored.lua_editor=='plain')
end)
test('pooled callbacks cannot edit a new owner or released form',function()
 local _,a,_,p=fixture();local old=assert(p.fields.integration_select_native).scripts.OnClick
 p:Draw();old();assert(choice(p)=='auto');a.db.profile={lua_editor='plain'};old();assert(a.db.profile.lua_editor=='plain');p:Release();old()
end)
test('Questie preference remains under its card and only Apply synchronizes',function()
 local _,a,_,p,calls=fixture();assert(calls()==0);click(p,'questie_enabled');assert(calls()==0 and not a.db.profile.questie_enabled)
 assert(p:SaveSettingsDraft());assert(calls()==1 and a.db.profile.questie_enabled)
end)
test('warm redraw reuses native cards and narrow columns remain contained',function()
 local _,_,_,p=fixture();local card=assert(p.fields.integration_card_Questie)
 for i=1,8 do p:Draw();assert(p.fields.integration_card_Questie==card)end
 p.frame:SetWidth(380);p:Draw();assert(p.width==340)
 for _,name in ipairs({'integration_select_native','integration_enable_native','integration_select_LuaWorkbench'})do local c=assert(p.fields[name]);assert(c:GetWidth()>0 and c:GetWidth()<=340)end
 p:Release();assert(not p.frame:IsShown())
end)
test('actual supported inventory stays complete without constructing editors or probing gameplay',function()
 local f,a,_,p=fixture();local calls=0
 f.env.IsAddOnLoaded=function()calls=calls+1;return false end
 f.env.GetAddOnMetadata=function()calls=calls+1;return '1.0' end
 a.Platform.CanReadValue=function()return true end
 f.load('Integrations/catalog.lua')
 a.CreateWorkbenchLuaEditor=function()error('page constructed editor')end
 a.ScheduleTimer=function()error('page scheduled timer')end
 p:Draw();assert(calls==38)
 for _,id in ipairs({'!!!LuaWorkbench','WowLua','ExtendedCharacterStats','MobInfo2','WeakAuras','Questie','ElvUI','Bartender4','ButtonForge','G15Buttons','SyncUI','LUI','Dominos','DiabolicUI','AzeriteUI','Neuron','FarmingBar','TotemTimers','SamyTotemTimers'})do
  assert(p.fields['integration_card_'..(id=='!!!LuaWorkbench' and 'editor_LuaWorkbench' or id)],id..' card missing')
 end
end)
test('new profile and reset use their own enable settings; active source is not forcibly retired',function()
 local _,a,parent,p=fixture();local owner={};local old=open(a,parent,'native',owner);assert(old.syntax)
 click(p,'integration_enable_native');assert(p:SaveSettingsDraft());assert(not old.released)
 local nextEditor=open(a,parent,'native',owner);assert(nextEditor~=old and not nextEditor.syntax)
 a.db.profile={lua_editor='native'};local fresh=open(a,parent,nil);assert(fresh.syntax);fresh:Release();nextEditor:Release()
end)
test('selected-disable draft owns both fields; conflict refuses partial publication and Discard restores both',function()
 local _,a,_,p=fixture();click(p,'integration_select_LuaWorkbench');assert(p:SaveSettingsDraft());p:Draw()
 click(p,'integration_enable_LuaWorkbench');assert(choice(p)=='plain' and p:SettingsData().profile.lua_editor_disabled.LuaWorkbench)
 a.db.profile.lua_editor_disabled={native=true}
 assert(not p:SaveSettingsDraft());assert(a.db.profile.lua_editor=='LuaWorkbench' and a.db.profile.lua_editor_disabled.native and not a.db.profile.lua_editor_disabled.LuaWorkbench)
 p:DiscardSettingsDraft();p:Draw();assert(choice(p)=='LuaWorkbench' and not p:SettingsData().profile.lua_editor_disabled.LuaWorkbench)
end)
test('localized column headings share card anchors and controls stay within narrow cards',function()
 local _,_,_,p=fixture();p.frame:SetWidth(380);p:Draw()
 local heading=p.pool.integrationHeadings
 assert(heading and #heading>=4)
 local card=p.fields.integration_card_editor_LuaWorkbench
 local select=p.fields.integration_select_LuaWorkbench
 assert(select:GetParent()==card and select:GetPoint()=='TOPLEFT')
 local x=select.point[2];assert(x>=0 and x+select:GetWidth()<=card:GetWidth())
 assert(p.fields.lua_line_numbers:GetParent()==p.child and p.fields.questie_refresh:GetParent()~=p.child)
end)
test('imported disabled selection displays None and enabling never silently selects it',function()
 local _,a,_,p=fixture();a.db.profile.lua_editor='LuaWorkbench';a.db.profile.lua_editor_disabled={LuaWorkbench=true}
 p:DiscardSettingsDraft();p:Draw();assert(not p.fields.integration_select_plain:IsEnabled())
 click(p,'integration_enable_LuaWorkbench');assert(choice(p)=='plain' and not (p:SettingsData().profile.lua_editor_disabled or {}).LuaWorkbench)
end)
test('custom registration display is inert and unavailable saved preference can escape to None',function()
 local _,a,_,p=fixture();a:RegisterLuaEditorProvider('custom|cffff0000\n',function()end);p:Draw()
 local labels=p.pool.integrationLabels;local found=false
 for _,label in ipairs(labels)do if label:GetText()=='custom||cffff0000?'then found=true end end;assert(found)
 a.db.profile.lua_editor='not-installed';p:DiscardSettingsDraft();p:Draw();click(p,'integration_select_plain');assert(choice(p)=='plain')
end)
test('Questie refresh is explicit, preserves pending editor changes and renders missing cached service safely',function()
 local _,a,_,p,calls=fixture();a.GetQuestieIntegrationStatus=nil;p:Draw()
 local found=false;for _,label in ipairs(p.pool.text or {})do if label:GetText()=='Questie adapter unavailable.'then found=true end end;assert(found)
 click(p,'integration_enable_LuaWorkbench');assert(p:IsSettingsDraftDirty() and calls()==0)
 click(p,'questie_refresh');assert(calls()==1 and p:IsSettingsDraftDirty() and not a.db.profile.lua_editor_disabled)
 p:DiscardSettingsDraft();p:Draw();assert(calls()==1)
end)
test('actual AceDB profile copy preserves disable map and reset returns to enabled defaults',function()
 local file=assert(io.open('tests/startup.lua'));local source=file:read('*a');file:close()
 local prefix=assert(source:match('^(.-)\ntest%('))
 local persistent=assert(source:match('(local function persistentFixture.-)\n%-%- WoW SavedVariables'))
 local create=assert(loadstring(prefix..'\n'..persistent..'\nreturn persistentFixture','@integration/AceDB'))()
 local _,a=create();a.db.profile.lua_editor='LuaWorkbench';a.db.profile.lua_editor_disabled={LuaWorkbench=true}
 a.db:SetProfile('Other');assert(not a.db.profile.lua_editor_disabled)
 a.db:CopyProfile('Default');assert(a.db.profile.lua_editor=='LuaWorkbench' and a.db.profile.lua_editor_disabled.LuaWorkbench)
 a.db:ResetProfile();assert(a.db.profile.lua_editor=='auto' and not a.db.profile.lua_editor_disabled)
end)
test('editor card preserves actual catalog loaded versus connected state alongside enabled selection',function()
 local f,a,_,p=fixture()
 f.env.IsAddOnLoaded=function(name)return name=='!!!LuaWorkbench'end
 f.env.GetAddOnMetadata=function()return '1.2.3'end
 a.Platform.CanReadValue=function()return true end
 f.load('Integrations/catalog.lua')
 local function text()
  local card=assert(p.fields.integration_card_editor_LuaWorkbench);local rows={}
  for _,label in ipairs(p.pool.integrationLabels or {})do if label:GetParent()==card then rows[#rows+1]=label:GetText()end end
  return table.concat(rows,'\n')
 end
 p:Draw();assert(text():find('1.2.3',1,true) and text():find('Loaded; connection not confirmed.',1,true))
 assert(not text():find('Connected',1,true),'registered provider invented connection')
 a.CreateLuaWorkbenchControl=function()error('card constructed editor')end;f.env.LuaWorkbench={}
 p:Draw();assert(text():find('Connected',1,true))
 click(p,'integration_enable_LuaWorkbench');assert(text():find('Disabled',1,true) and text():find('Connected',1,true),'enable state replaced actual connection status')
end)
test('baseline editor choices stay outside addon cards and passive integrations have no invented controls',function()
 local f,a,_,p=fixture();a.Platform.CanReadValue=function()return true end
 f.env.IsAddOnLoaded=function()return false end;f.env.GetAddOnMetadata=function()return nil end;f.load('Integrations/catalog.lua');p:Draw()
 assert(p.fields.integration_select_plain and p.fields.integration_select_auto and p.fields.integration_select_native and p.fields.integration_enable_native)
 assert(not p.fields.integration_card_editor_plain and not p.fields.integration_card_editor_auto and not p.fields.integration_card_editor_native and not p.fields.integration_card_editor_options,'baseline preference fabricated an addon card')
 assert(p.fields.integration_select_plain:GetParent()==p.child and p.fields.integration_enable_native:GetParent()==p.child)
 assert(p.fields.lua_line_numbers:GetParent()==p.child)
 for _,id in ipairs({'AceDB-3.0','AceGUI-3.0','LibCompress','LuaWorkbench-Embed','native','plain','auto'})do assert(not p.fields['integration_card_'..id])end
 for _,id in ipairs({'ExtendedCharacterStats','MobInfo2','WeakAuras','Dominos','WowLua'})do assert(not p.fields['integration_enable_'..id] and not p.fields['integration_select_'..id])end
 assert(p.fields.integration_enable_LuaWorkbench and p.fields.questie_enabled)
end)
finish()
