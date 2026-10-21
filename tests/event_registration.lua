-- Missing subscriptions exercise actual enable and AceEvent/CallbackHandler dispatch.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local make=dofile('tests/fixtures/rotation_execution.lua')
local added={UNIT_EXITED_VEHICLE=true,PLAYER_TALENT_UPDATE=true,ACTIVE_TALENT_GROUP_CHANGED=true}
local function fixture(options)
 options=options or {};local c=make({target=true,buttons=true});local a,e=c.a,c.e
 e.securecallfunction=function(fn,...)return fn(...)end
 local frames={};local create=e.CreateFrame
 e.CreateFrame=function(...)
  local frame=create(...);frame.events={}
  function frame:RegisterEvent(event)assert(not options.invalid or not added[event],'unsupported native event registered');self.events[event]=true end
  function frame:UnregisterEvent(event)self.events[event]=nil end
  frames[#frames+1]=frame;return frame
 end
 c.load('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua');c.load('Libs/AceEvent-3.0/AceEvent-3.0.lua')
 local ace=e.LibStub('AceEvent-3.0');ace:Embed(a);local frame=assert(ace.frame)
 assert(type(frame.RegisterEvent)=='function'and type(frame:GetScript('OnEvent'))=='function')
 local seen={skills=0,switches=0,fetches=0,timers=0,evaluations=0,enabled=0}
 a.UpdateSpecSpells=function()seen.skills=seen.skills+1 end
 a.UpdateAutoSwitch=function()end;a.SwitchRotation=function()seen.switches=seen.switches+1 end
 a.ButtonFetch=function()seen.fetches=seen.fetches+1 end
 a.EnableRotationTimer=function()seen.timers=seen.timers+1 end;a.EvaluateNextAction=function()seen.evaluations=seen.evaluations+1 end
 a.EnableRotation=function()seen.enabled=seen.enabled+1 end;a.RefreshPreviewWindow=nil
 if options.family then local get=a.Platform.GetClientInfo;a.Platform.GetClientInfo=function(self)local value=get(self);value.family=options.family;return value end end
 if options.capability=='missing'then e.C_EventUtils=nil
 elseif options.capability=='no-method'then e.C_EventUtils={}
 else e.C_EventUtils={IsEventValid=function(event)
  if added[event]then
   if options.onValid then options.onValid(a,event)end
   if options.capability=='throws'then error('unavailable capability')end
   if options.capability=='nonboolean'then return {}end
   if options.invalid then return false end
  end
  return true
 end}end
 local function fire(event,...)if frame.events[event]then frame:GetScript('OnEvent')(frame,event,...)end end
 return c,a,e,frame,seen,fire
end
test('TBC talent and group subscriptions dispatch existing skill refresh handlers',function()
 local _,a,_,frame,seen,fire=fixture();a:enable();assert(frame.events.PLAYER_TALENT_UPDATE and frame.events.ACTIVE_TALENT_GROUP_CHANGED,'missing TBC talent subscriptions')
 local before=seen.skills;a.longtermCache={old=true};fire('PLAYER_TALENT_UPDATE');assert(seen.skills==before+1 and a.longtermCache.old==nil)
 before=seen.skills;fire('ACTIVE_TALENT_GROUP_CHANGED',2,1);assert(seen.skills==before+1 and not a.adviceErrorReport)
end)
test('vehicle exit dispatch ignores pet and restores player timer and advice',function()
 local _,a,_,frame,seen,fire=fixture();a:enable();assert(frame.events.UNIT_EXITED_VEHICLE,'missing vehicle exit subscription')
 local timers,evaluations=seen.timers,seen.evaluations;fire('UNIT_EXITED_VEHICLE','pet');assert(seen.timers==timers and seen.evaluations==evaluations)
 fire('UNIT_EXITED_VEHICLE','player');assert(seen.timers==timers+1 and seen.evaluations==evaluations+1 and not a.adviceErrorReport)
end)
test('invalid optional native names are skipped while old spell subscription still dispatches',function()
 local _,a,_,frame,seen,fire=fixture({invalid=true});a:enable()
 for event in pairs(added)do assert(not frame.events[event],'registered unsupported optional event')end
 local skills=seen.skills;fire('SPELLS_CHANGED');assert(seen.skills==skills+1 and seen.enabled==1 and not a.adviceErrorReport)
end)
test('missing throwing and malformed capability skips only the new subscriptions',function()
 for _,kind in ipairs({'missing','no-method','throws','nonboolean'})do
  local _,a,_,frame,seen=fixture({capability=kind});a:enable();for event in pairs(added)do assert(not frame.events[event],kind..' capability granted subscription')end
  assert(frame.events.SPELLS_CHANGED and frame.events.PLAYER_LEVEL_UP and seen.enabled==1 and not a.adviceErrorReport)
 end
end)
test('TBC optional talents do not add new talent subscriptions to Era',function()
 local _,a,_,frame=fixture({family='era'});a:enable();assert(not frame.events.PLAYER_TALENT_UPDATE and not frame.events.ACTIVE_TALENT_GROUP_CHANGED);assert(frame.events.UNIT_EXITED_VEHICLE)
end)
test('disable unregisters optional events and enable subscribes again',function()
 local _,a,_,frame,_,fire=fixture();a:enable();assert(frame.events.UNIT_EXITED_VEHICLE);a:disable()
 for event in pairs(added)do assert(not frame.events[event],'disabled listener survived')end
 a:enable();for event in pairs(added)do assert(frame.events[event],'reenable lost optional event')end;fire('UNIT_EXITED_VEHICLE','player');assert(not a.adviceErrorReport)
end)
test('validity callback retirement prevents subsequent registration and enable work',function()
 local retired=false
 local _,a,_,frame,seen=fixture({onValid=function(owner)if not retired then retired=true;owner:disable()end end});a:enable()
 assert(retired,'capability was never checked');for event in pairs(added)do assert(not frame.events[event],'stale enable registered after callback retirement')end
 assert(seen.skills==0 and seen.enabled==0,'stale enable continued after capability callback')
end)
test('capability method lookup retirement prevents even invoking returned validator',function()
 local _,a,e,frame,seen=fixture();local retired,called=false,false
 e.C_EventUtils=setmetatable({},{__index=function(_,key)
  assert(key=='IsEventValid');retired=true;a:disable()
  return function()called=true;return true end
 end})
 a:enable();assert(retired,'capability getter was not reached');assert(not called,'retired enable invoked validator returned by getter')
 for event in pairs(added)do assert(not frame.events[event],'retired lookup registered optional event')end
 assert(seen.skills==0 and seen.enabled==0,'retired lookup continued enabling')
end)
test('strict optional-event inverse preserves source proof and rejects unrelated edits',function()
 local restore=dofile('tests/fixtures/restore_event_registration.lua');local f=assert(io.open('main.lua'));local source=f:read('*a');f:close();source=dofile('tests/fixtures/restore_runtime_publication_store.lua')(source,'main.lua');local old=restore(source,'main.lua')
 assert(old~=source and not pcall(restore,old,'main.lua'))
 assert(not pcall(restore,source..source,'main.lua')and not pcall(restore,source..'\n-- unrelated\n','main.lua'))
end)
finish()
