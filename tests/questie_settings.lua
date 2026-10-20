-- Production startup/settings wiring, with native frames and provider calls recorded.
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local prefix=assert(read('tests/startup.lua'):match('^(.-)\ntest%('))
local startup,initialize=assert(loadstring(prefix..'\nreturn fixture,initialize','@questie/startup'))()
local passed=0
local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end
local function fixture(enabled)
 local env,a,load=startup(true,true);local frames,trace={},{}
 env.CreateFrame=function(kind)
  assert(kind=='Frame');local f={events={}};frames[#frames+1]=f
  function f:RegisterEvent(event)self.events[event]=true end
  function f:UnregisterEvent(event)self.events[event]=nil end
  function f:SetScript(event,callback)assert(event=='OnEvent');self.callback=callback end
  return f
 end
 local made=0;local on=false
 a.Integrations={NewQuestie=function()
  made=made+1;local s={}
  function s:SetEnabled(value)on=value;trace[#trace+1]={'enabled',value};return true end
  function s:Refresh()trace[#trace+1]={'refresh'}end
  function s:GetStatus()return{state=on and 'available' or 'disabled',reason='ready',version='12.1.0',versionStatus='source-tested',family='tbc',familyContract='declared-unverified',nativeAcceptance='unverified',coverage='recent-update-receipts-only'}end
  return s
 end}
 a.augmentDefaults=function(_,defaults)defaults.profile.questie_enabled=enabled==true end
 load('main.lua');local augment=a.augmentDefaults
 -- initialize() supplies ordinary startup stubs; retain the preference seeder.
 local original=a.OnInitializeInternal
 a.OnInitializeInternal=function(self)self.augmentDefaults=augment;return original(self)end
 initialize(a)
 return env,a,load,frames,trace,function()return made end
end
local function page(a,load)
 load('UI/settings_draft.lua');load('UI/settings_integrations.lua');load('UI/settings_collections.lua')
 a.StockSettings={DraftProfile=function(profile)return profile end}
 a.ListLuaEditorProviders=function()return{{value='auto',text='Automatic'}}end
 a.ListIntegrationStatus=function()return{{id='loaded',name='Loaded provider',version='1.2.3',state='loaded',detail='Loaded receipt'},
 {id='missing',name='Missing provider',state='missing'},{id='connected',name='Connected provider',version='2',state='connected'}}end
 a.RemoveAllCurrentGlows=function()end;a.ButtonFetch=function()end
 local p={generation=1,edits={},fields={},actions={},texts={}}
 function p:Valid()return true end
 function p:Heading(text)self.texts[#self.texts+1]=text end
 function p:Text(text)self.texts[#self.texts+1]=text end
 function p:Choice()end
 function p:Check(key,label,value,callback)self[key]={value=value,callback=callback}end
 function p:Button(key,label,callback)self.actions[key]=callback end
 function p:Actions(entries)for _,entry in ipairs(entries)do self.actions[entry.key]=entry.action end end
 function p:Message(text)error(text)end
 function p:Draw()self.draws=(self.draws or 0)+1 end
 function p:SetWidth()end;function p:SetHeight()end
 function p:Open(build)build(self)end
 a:InstallSettingsDraft(p)
 local parent={GetWidth=function()return 900 end,GetHeight=function()return 700 end}
 a:OpenNativeSettings(parent,'Integrations',p)
 return p
end

test('default-disabled startup creates one service and no frame or polling work',function()
 local _,a,_,frames,trace,made=fixture(false)
 assert(type(a.SyncQuestieIntegration)=='function','missing integration lifecycle')
 assert(made()==1 and #frames==0 and #trace==1 and trace[1][2]==false)
 a:SyncQuestieIntegration();assert(made()==1 and #frames==0 and #trace==1)
 assert(a.db.profile.questie_enabled==false)
end)
test('saved enabled preference binds one independent late-load event owner',function()
 local _,a,_,frames,trace,made=fixture(true)
 assert(made()==1 and #frames==1 and frames[1].events.ADDON_LOADED)
 local before=#trace;frames[1].callback(frames[1],'ADDON_LOADED','OtherAddon');assert(#trace==before)
 frames[1].callback(frames[1],'ADDON_LOADED','Questie');assert(trace[#trace][1]=='refresh')
 a.UnregisterAllEvents=function()end;a:UnregisterAllEvents();assert(frames[1].events.ADDON_LOADED)
 a:SyncQuestieIntegration();assert(made()==1 and #frames==1)
 a.db.profile.questie_enabled=false;a:SyncQuestieIntegration();assert(not frames[1].events.ADDON_LOADED)
 before=#trace;frames[1].callback(frames[1],'ADDON_LOADED','Questie');assert(#trace==before)
 a.db.profile.questie_enabled=true;a:SyncQuestieIntegration();assert(made()==1 and #frames==1 and frames[1].events.ADDON_LOADED)
end)
test('checkbox changes remain draft-only until Apply and Discard cannot enable',function()
 local _,a,load,frames,trace=fixture(false);local p=page(a,load)
 p.questie_enabled.callback(true);assert(not a.db.profile.questie_enabled and #frames==0 and #trace==1)
 assert(p:IsSettingsDraftDirty());p:DiscardSettingsDraft();assert(not a.db.profile.questie_enabled and #frames==0)
 p=page(a,load);p.questie_enabled.callback(true);assert(p:SaveSettingsDraft())
 assert(a.db.profile.questie_enabled and #frames==1 and frames[1].events.ADDON_LOADED)
 p=page(a,load);p.questie_enabled.callback(false);assert(p:SaveSettingsDraft());assert(not a.db.profile.questie_enabled and not frames[1].events.ADDON_LOADED)
end)
test('saved profile replacement and final imported overlay synchronize without service recreation',function()
 local _,a,load,frames,_,made=fixture(false)
 a.InitializeScopedRotationStorage=function()return true end
 load('Core/rotation_lifecycle.lua')
 a.db.profile={questie_enabled=true};assert(a:RefreshRotationProfileStorage());assert(#frames==1 and frames[1].events.ADDON_LOADED)
 a.db.profile={questie_enabled=false};assert(a:RefreshRotationProfileStorage());assert(not frames[1].events.ADDON_LOADED)
 -- Imported overlay follows a reset callback; final refresh must see final data.
 a.db.profile.questie_enabled=true;assert(a:RefreshRotationProfileStorage());assert(frames[1].events.ADDON_LOADED and made()==1)
end)
test('settings renders cached adapter evidence and explicit refresh without provider globals',function()
 local env,a,load,_,trace=fixture(true)
 env.Questie=setmetatable({},{__index=function()error('UI read provider')end})
 local p=page(a,load);local text=table.concat(p.texts,'\n')
 assert(text:find('12.1.0',1,true) and text:find('source',1,true) and text:find('unverified',1,true))
 assert(text:find('receipt',1,true) and text:find('tbc',1,true))
 local before=#trace;p.actions.questie_refresh();assert(#trace==before+1 and trace[#trace][1]=='refresh' and p.draws==1)
end)
test('missing adapter remains a disabled-safe settings status',function()
 local _,a,load=startup(true,true);load('main.lua');initialize(a)
 assert(a:GetQuestieIntegrationStatus().state=='unavailable')
 assert(a:SyncQuestieIntegration()==false)
 local p=page(a,load);assert(table.concat(p.texts,'\n'):find('unavailable',1,true))
end)
test('one inventory shows missing supported addons and distinguishes loaded from connected',function()
 local _,a,load=fixture(false);local p=page(a,load);local text=table.concat(p.texts,'\n')
 assert(text:find('Loaded provider (version 1.2.3): Loaded; connection not confirmed.',1,true))
 assert(text:find('Missing provider: Not loaded.',1,true) and text:find('Connected provider (version 2): Connected',1,true))
 assert(text:find('Loaded receipt',1,true))
end)
test('Questie metadata stays literal in native settings text',function()
 local _,a,load=fixture(false)
 a.GetQuestieIntegrationStatus=function()return{state='missing',version='|Tprivate-path|t',family='tbc',versionStatus='unverified',familyContract='declared-unverified'}end
 local p=page(a,load);assert(table.concat(p.texts,'\n'):find('||Tprivate-path||t',1,true))
end)
test('actual AceDB profile switch copy and reset synchronize the same service',function()
 local source=assert(read('tests/rotation_scope_runtime.lua'):match('^(.-)\ntest%('))
 local runtime=assert(loadstring(source..'\nreturn fixture','@questie/profile-fixture'))()
 local env,a=runtime();local made=0;local enabled
 env.CreateFrame=function()return{SetScript=function()end,RegisterEvent=function()end,UnregisterEvent=function()end}end
 a.Integrations={NewQuestie=function()made=made+1;return{SetEnabled=function(_,v)enabled=v;return true end,GetStatus=function()return{state='disabled'}end}end}
 a:InitializeQuestieIntegration();assert(enabled==false and made==1)
 a.DestroyAllGlows=function()end;a.RefreshConfiguration=function()end;a.EnableRotation=function()end
 a.db.profile.questie_enabled=true;a:SyncQuestieIntegration();assert(enabled)
 a.db:SetProfile('Other');assert(not enabled and made==1)
 a.db:CopyProfile('Default');assert(enabled and made==1)
 a.db:ResetProfile();assert(not enabled and made==1)
end)
test('Questie profile preference round-trips as a boolean and rejects malformed imports',function()
 local source=assert(read('tests/rotation_scope_runtime.lua'):match('^(.-)\ntest%('))
 local runtime=assert(loadstring(source..'\nreturn fixture','@questie/transfer-fixture'))()
 local _,a,_,_,_,_,load=runtime();load('UI/settings_draft.lua');load('Core/profile_data.lua')
 for _,value in ipairs({false,true})do
  local original={questie_enabled=value};local restored=assert(a:ProfileFromPortable(a:ProfileToPortable(original)))
  assert(restored.questie_enabled==value and a:ValidateProfileTransfer(restored),'Questie profile boolean not portable')
 end
 for _,value in ipairs({'true',1,{}})do assert(not a:ValidateProfileTransfer({questie_enabled=value}))end
end)
test('actual corrected adapter loads late through production event wiring and retires profile receipts',function()
 local env,a,load=startup(true,true);local frame;local loaded=false;local probes=0
 env.CreateFrame=function()
  frame={events={}};function frame:RegisterEvent(event)self.events[event]=true end
  function frame:UnregisterEvent(event)self.events[event]=nil end
  function frame:SetScript(_,fn)self.callback=fn end;return frame
 end
 local metadata=env.C_AddOns.GetAddOnMetadata
 env.C_AddOns.GetAddOnMetadata=function(name,key)if name=='Questie' then return '12.1.0' end;return metadata(name,key)end
 env.C_AddOns.IsAddOnLoaded=function(name)if name=='Questie' then probes=probes+1;return loaded end;return false end
 a.Platform.CanReadValue=function()return true end
 a.Platform.GetClientInfo=function()return{family='tbc'}end
 load(arg[1] or 'Integrations/questie.lua')
 local service;local factory=a.Integrations.NewQuestie
 a.Integrations.NewQuestie=function()service=factory();return service end
 load('main.lua');initialize(a);assert(probes==0 and a:GetQuestieIntegrationStatus().state=='disabled')
 a.db.profile.questie_enabled=true;a:SyncQuestieIntegration();assert(a:GetQuestieIntegrationStatus().state=='missing')
 local readyCalls,updateCalls,update=0,0
 local api={isReady=true,Enums={QuestUpdateTriggerReason={QUEST_ACCEPTED=1,QUEST_UPDATED=2,QUEST_TURNED_IN=3,QUEST_ABANDONED=4}}}
 api.RegisterOnReady=function(callback)readyCalls=readyCalls+1;callback()end
 api.RegisterForQuestUpdates=function(callback)updateCalls=updateCalls+1;update=callback end
 env.Questie={API=api};loaded=true;frame.callback(frame,'ADDON_LOADED','Questie')
 assert(a:GetQuestieIntegrationStatus().state=='available' and readyCalls==1 and updateCalls==1)
 update(42,nil,1);assert(service:GetRecentUpdate(42).status=='available')
 a.db.profile={questie_enabled=false};a:SyncQuestieIntegration();assert(service:GetRecentUpdate(42).status=='unavailable')
 local before=probes;update(42,nil,2);assert(probes==before)
 a.db.profile={questie_enabled=true};a:SyncQuestieIntegration();assert(readyCalls==1 and updateCalls==1)
 assert(service:GetRecentUpdate(42).status=='unavailable','old profile receipt survived re-enable')
end)
print(passed..' Questie wiring groups passed')
