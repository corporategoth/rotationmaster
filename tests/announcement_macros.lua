local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();local a,e=f.addon,f.env
 for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Diagnostics/errors.lua','Platform/spells.lua','Platform/communication.lua','Core/conditions.lua','Core/announcements.lua'})do
  if arg and arg[1] and (path=='Core/conditions.lua' or path=='Core/announcements.lua') then f.load(arg[1]..'/'..path)else f.load(path)end
 end
 local file=io.open('Core/macro_announcements.lua');if file then file:close();f.load('Core/macro_announcements.lua')end
 local outputs={};a.announce=function(_,text)outputs[#outputs+1]={text=text,destination='LOCAL'}end
 e.C_ChatInfo={SendChatMessage=function(text,destination,language,target)outputs[#outputs+1]={text=text,destination=destination,target=target,language=language}end}
 e.GetSpellInfo=function(id)if id==403 or id=='Lightning Bolt'then return 'Lightning Bolt',nil,1,nil,nil,nil,403 end end
 local units={target={name='Exact-Realm',guid='Player-1'},focus={name='Focus-Realm',guid='Player-2'}}
 e.UnitIsPlayer=function(unit)return units[unit]~=nil end;e.GetSpellLink=function(id)if id==403 or id=='Lightning Bolt'then return '|Hspell:403|h[Lightning Bolt]|h' end end
 e.UnitExists=function(unit)return units[unit]~=nil end;e.UnitName=function(unit)local u=units[unit];if u then return u.name end end;e.UnitGUID=function(unit)return units[unit]and units[unit].guid end
 e.C_Timer={After=function()error('macro output scheduled work')end};a.ScheduleTimer=function()error('macro output scheduled work')end
 a.db.profile.announces={{id='11111111-1111-1111-1111-111111111111',type='macro',identifier='pull',announce='local',value='Ready'}}
 return f,a,e,outputs,units
end
local function endpoint(e)local fn=rawget(e,'RM_Annouce');assert(type(fn)=='function','missing synchronous macro endpoint');assert(fn==rawget(e,'RM_Announce'),'macro aliases differ');return fn end
test('macro schema has an identifier and does not invent a stored action or cast event',function()
 local _,a=fixture();local entry=a.db.profile.announces[1];assert(a:IsValidAnnouncement(entry,true),'macro schema rejected identifier-only action')
 for _,identifier in ipairs({'','bad space','1bad',string.rep('a',65)})do entry.identifier=identifier;assert(not a:IsValidAnnouncement(entry))end
 entry.identifier='Exact_name-1.test';assert(a:IsValidAnnouncement(entry))
end)
test('both global aliases synchronously emit the configured current-profile message',function()
 local _,a,e,o=fixture();local fn=endpoint(e);local r=fn('pull');assert(r.chat and #o==1 and o[1].destination=='LOCAL');assert(not a.announced and not a.avail_announced,'macro wrote cast bookkeeping')
end)
test('macro Say Yell and Whisper use only the configured invocation route and exact supplied unit',function()
 local _,a,e,o=fixture();local fn=endpoint(e);local entry=a.db.profile.announces[1]
 for _,mode in ipairs({'say','yell','whisper'})do entry.announce=mode;entry.value='To {{target}}';local r=fn('pull','focus');assert(r.chat and o[#o].destination==mode:upper());if mode=='whisper'then assert(o[#o].target=='Focus-Realm')end end
 local before=#o;for _,mode in ipairs({'say','yell','whisper'})do local r=a:DispatchAnnouncement({announce=mode},'blocked');assert(not r.chat)end;assert(#o==before,'ordinary dispatch bypassed restricted chat boundary')
end)
test('unknown case ambiguous disabled and malformed identifiers cannot emit',function()
 local _,a,e,o=fixture();local fn=endpoint(e);assert(not fn('PULL').chat and #o==0);a.db.profile.announces[2]=a.RotationData.CopyData(a.db.profile.announces[1]);assert(not fn('pull').chat and #o==0)
 a.db.profile.announces[2]=nil;a.db.profile.announces[1].disabled=true;assert(not fn('pull').chat and #o==0)
end)
test('supplied unit and spell format exact substitutions without carrying observations to another invocation',function()
 local _,a,e,o=fixture();local fn=endpoint(e);local entry=a.db.profile.announces[1];entry.value='{{event}}: {{spell}} -> {{target}}'
 assert(fn('pull','focus',403).chat);assert(o[1].text=='Via Macro: |Hspell:403|h[Lightning Bolt]|h -> Focus-Realm')
 assert(not fn('pull').chat and #o==1,'missing arguments reused prior observations')
 entry.value='No optional placeholders';assert(fn('pull').chat and #o==2)
 for _,args in ipairs({{'missing',403},{'target',999},{false,403},{'target',false}})do assert(not fn('pull',args[1],args[2]).chat)end;assert(#o==2)
end)
test('Whisper requires the same readable supplied player unit and never selected-target fallback',function()
 local _,a,e,o=fixture();local fn=endpoint(e);a.db.profile.announces[1].announce='whisper'
 assert(not fn('pull').chat and #o==0);e.UnitIsPlayer=function()return false end;assert(not fn('pull','target').chat and #o==0)
 e.UnitIsPlayer=function()return true end;assert(fn('pull','focus').chat and o[1].target=='Focus-Realm')
end)
test('current condition API receives exact unit and recipient and retains no-match and unknown semantics',function()
 local _,a,e,o=fixture();local fn=endpoint(e);local entry=a.db.profile.announces[1];local seen={};local matcher=a.AnnouncementConditionMatches
 a.AnnouncementConditionMatches=function(self,config,recipient,current,unit)seen[#seen+1]={recipient=recipient,unit=unit};return matcher(self,config,recipient,current,unit)end
 a:RegisterCondition('MACRO_ALLOW',{fields={match='boolean'},valid=function()return true end,evaluate=function(v)return v.match end})
 entry.conditions={type='MACRO_ALLOW',match=true};assert(fn('pull','focus').chat and seen[1].unit=='focus' and seen[1].recipient=='Focus-Realm')
 entry.conditions.match=false;assert(not fn('pull','target').chat and #o==1 and seen[2].unit=='target' and seen[2].recipient=='Exact-Realm')
 entry.conditions={type='NOT',value={type='MISSING'}};assert(not fn('pull','focus').chat and #o==1)
end)

test('profile list entry registry and unit-identity mutation during condition callbacks retire output',function()
 for _,kind in ipairs({'profile','list','entry','registry','unit'})do
  local _,a,e,o,units=fixture();local fn=endpoint(e);local entry=a.db.profile.announces[1]
  a:RegisterCondition('MUTATE',{fields={},valid=function()return true end,evaluate=function()
   if kind=='profile'then a.db.profile={}elseif kind=='list'then a.db.profile.announces={}elseif kind=='entry'then entry.value='changed'elseif kind=='registry'then a.conditionRegistryVersion=(a.conditionRegistryVersion or 0)+1 else units.focus.guid='Player-new' end
   return true
  end});entry.conditions={type='MUTATE'};assert(not fn('pull','focus').chat and #o==0,kind..' emitted stale output')
 end
end)
test('a newer reentrant invocation wins and old output cannot continue',function()
 local _,a,e,o=fixture();local fn=endpoint(e);local entry=a.db.profile.announces[1]
 a.db.profile.announces[2]={id='22222222-2222-2222-2222-222222222222',type='macro',identifier='newer',announce='local',value='newer'}
 a:RegisterCondition('REENTER_MACRO',{fields={},valid=function()return true end,evaluate=function()assert(fn('newer').chat);return true end});entry.conditions={type='REENTER_MACRO'}
 assert(not fn('pull').chat and #o==1 and o[1].text=='newer')
end)
test('native errors do not retry another backend or schedule output',function()
 local _,a,e,o=fixture();local fn=endpoint(e);a.db.profile.announces[1].announce='say';local calls,fallback=0,0
 e.C_ChatInfo.SendChatMessage=function()calls=calls+1;error('native output refused')end;e.SendChatMessage=function()fallback=fallback+1 end
 local r=fn('pull');assert(not r.chat and calls==1 and fallback==0 and #o==0)
end)

test('disabled addon and disable during condition callback cannot emit',function()
 local _,a,e,o=fixture();local fn=endpoint(e);local enabled=false;a.IsEnabled=function()return enabled end
 assert(not fn('pull').chat and #o==0);enabled=true
 a:RegisterCondition('DISABLE_MACRO',{fields={},valid=function()return true end,evaluate=function()enabled=false;return true end});a.db.profile.announces[1].conditions={type='DISABLE_MACRO'}
 assert(not fn('pull').chat and #o==0)
end)
test('restricted unit spell and identifier observations never reach output',function()
 local _,a,e,o=fixture();local fn=endpoint(e);local secret={};e.issecretvalue=function(value)return value==secret end
 assert(not fn(secret).chat);assert(not fn('pull',secret).chat);assert(not fn('pull','target',secret).chat)
 e.UnitGUID=function()return secret end;assert(not fn('pull','target').chat and #o==0)
end)
test('restricted chat and independent sound are each attempted at most once',function()
 local f,a,e,o=fixture();local fn=endpoint(e);local sounds=0;e.PlaySoundFile=function()sounds=sounds+1;return true end;f.libraries['LibSharedMedia-3.0']={Fetch=function()return 'sound.ogg'end}
 local entry=a.db.profile.announces[1];entry.announce='say';entry.announce_sound='Chime';assert(fn('pull').sound and #o==1 and sounds==1)
 a:RegisterCondition('NO_OUTPUT',{fields={},valid=function()return true end,evaluate=function()return false end});entry.conditions={type='NO_OUTPUT'};assert(not fn('pull').chat and #o==1 and sounds==1)
end)

test('a newly ambiguous identifier inserted during conditions cannot emit from the old selection',function()
 local _,a,e,o=fixture();local fn=endpoint(e);local entry=a.db.profile.announces[1]
 a:RegisterCondition('DUPLICATE_MACRO',{fields={},valid=function()return true end,evaluate=function()local other=a.RotationData.CopyData(entry);other.id='22222222-2222-2222-2222-222222222222';a.db.profile.announces[2]=other;return true end});entry.conditions={type='DUPLICATE_MACRO'}
 assert(not fn('pull').chat and #o==0,'newly ambiguous identifier emitted')
end)

test('native target observation cannot change canonical addon enabledState after lifecycle callbacks',function()
 local _,a,e,o=fixture();local fn=endpoint(e);a.enabledState=true;a.IsEnabled=function(self)return self.enabledState end;a.db.profile.announces[1].announce='whisper'
 local inSend=false;local exists=e.UnitExists;e.C_ChatInfo=setmetatable({},{__index=function(_,key)if key=='SendChatMessage'then inSend=true;return function(...)o[#o+1]={...}end end end})
 e.UnitExists=function(unit)if inSend then a.enabledState=false end;return exists(unit)end
 assert(not fn('pull','focus').chat and #o==0,'canonical disabled state changed after the lifecycle witness')
end)

finish()
