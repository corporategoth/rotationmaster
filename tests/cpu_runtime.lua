-- Fail-first controls: replaying/skipping evaluation, changing result tuples,
-- retaining wrappers, or measuring outside explicit capture must fail here.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function tuple(...) return {n=select('#',...),...} end
local function setup()
 local f=F.new();local a,e=f.addon,f.env;local s={calls=0,measures=0,enabled=0,timers={},finished={},now=100}
 e.GetTimePreciseSec=function()return s.now end
 a.IsCPUProfileRunning=function()return false end
 a.ScheduleTimer=function(_,fn,delay)local t={fn=fn,delay=delay};s.timers[#s.timers+1]=t;return t end
 a.CancelTimer=function(_,t)t.cancelled=true end
 a.OnCPURuntimeCaptureFinished=function(_,text,status)assert(not a:IsCPURuntimeCaptureRunning());s.finished[#s.finished+1]={text,status}end
 a.EvaluateNextAction=function(self,...)assert(self==a);s.calls=s.calls+1;s.args=tuple(...);return 'RM',nil,false,nil end;s.original=a.EvaluateNextAction
 local provider={IsEnabled=function()s.enabled=s.enabled+1;return true end}
 provider.MeasureCall=function(fn,...)s.measures=s.measures+1;local r=tuple(fn(...));return {elapsedMilliseconds=.25,allocatedBytes=12,deallocatedBytes='4'},unpack(r,1,r.n)end
 e.C_AddOnProfiler=provider;s.provider=provider
 local h=io.open('Diagnostics/cpu_runtime.lua');if h then h:close();f.load('Diagnostics/cpu_runtime.lua')end
 assert(type(a.StartCPURuntimeCapture)=='function','runtime capture API missing')
 return f,a,s
end
local function has(text,needle)assert(type(text)=='string' and text:find(needle,1,true),needle..' missing from report')end
local function complete(a,s)s.now=110;s.timers[1].fn();return a:GetCPURuntimeCaptureReport()end

test('idle load and report do not query provider or schedule work',function()
 local _,a,s=setup();assert(s.enabled==0 and s.measures==0 and #s.timers==0);assert(a:GetCPURuntimeCaptureReport()==nil)
 a:EvaluateNextAction();assert(s.calls==1 and s.measures==0 and a.EvaluateNextAction==s.original)
end)
test('ten second capture measures actual dispatch once and preserves nil holes and aggregates',function()
 local _,a,s=setup();assert(a:StartCPURuntimeCapture(10));assert(#s.timers==1 and s.timers[1].delay==10)
 local r=tuple(a:EvaluateNextAction(nil,7,nil));assert(r.n==4 and r[1]=='RM' and r[2]==nil and r[3]==false and r[4]==nil)
 assert(s.args.n==3 and s.args[2]==7 and s.calls==1 and s.measures==1)
 a:EvaluateNextAction();local text=complete(a,s);assert(a.EvaluateNextAction==s.original and not a:IsCPURuntimeCaptureRunning())
 has(text,'measured=2');has(text,'total=0.500');has(text,'average=0.250');has(text,'max=0.250');has(text,'allocatedBytes=24');has(text,'deallocatedBytes=8');assert(#text<=15999)
 a:EvaluateNextAction();a:GetCPURuntimeCaptureReport();assert(s.measures==2 and s.calls==3 and #s.finished==1)
end)
test('missing disabled throwing restricted and replaced capability refuse without changing evaluator',function()
 for _,mode in ipairs({'absent','disabled','throw','partial','restricted','replace'})do
  local f,a,s=setup()
  if mode=='absent'then f.env.C_AddOnProfiler=nil elseif mode=='disabled'then s.provider.IsEnabled=function()return false end
  elseif mode=='throw'then s.provider.IsEnabled=function()error('SECRET_API_ERROR')end elseif mode=='partial'then s.provider.MeasureCall=nil
  elseif mode=='restricted'then f.env.canaccessvalue=function(v)return v~=s.provider end
  else s.provider.IsEnabled=function()s.provider.MeasureCall=function()end;return true end end
  assert(not a:StartCPURuntimeCapture());assert(a.EvaluateNextAction==s.original and not a:IsCPURuntimeCaptureRunning() and s.calls==0)
  local text=a:GetCPURuntimeCaptureReport();assert(not text or not text:find('SECRET',1,true))
 end
end)
test('native errors before and after entry never skip or replay gameplay',function()
 for _,after in ipairs({false,true})do
  local _,a,s=setup();s.provider.MeasureCall=function(fn,...)s.measures=s.measures+1;if after then fn(...)end;error('SECRET_NATIVE_ERROR')end
  assert(a:StartCPURuntimeCapture());local r=tuple(a:EvaluateNextAction());assert(s.calls==1 and r.n==4 and r[1]=='RM' and r[3]==false)
  assert(a.EvaluateNextAction==s.original and not a:IsCPURuntimeCaptureRunning());local text=a:GetCPURuntimeCaptureReport();has(text,'invalid');assert(not text:find('SECRET',1,true))
 end
end)
test('zero duplicate deferred and forged callbacks cannot execute gameplay twice',function()
 for _,mode in ipairs({'zero','duplicate','deferred','forged'})do
  local _,a,s=setup();local later
  s.provider.MeasureCall=function(fn,...)
   if mode=='zero'or mode=='deferred'then later=fn;return {elapsedMilliseconds=1,allocatedBytes=0,deallocatedBytes=0}end
   local r=tuple(fn(...));if mode=='duplicate'then fn(...)end
   if mode=='forged'then return {},'FORGED'end
   return {elapsedMilliseconds=1,allocatedBytes=0,deallocatedBytes=0},unpack(r,1,r.n)
  end
  assert(a:StartCPURuntimeCapture());local r=tuple(a:EvaluateNextAction());assert(s.calls==1 and r.n==4 and r[1]=='RM' and r[3]==false)
  if later then later(a);assert(s.calls==1)end;assert(not a:IsCPURuntimeCaptureRunning());has(a:GetCPURuntimeCaptureReport(),'invalid')
 end
end)
test('unexpected original thrown object is rethrown intact after native swallows or throws',function()
 for _,mode in ipairs({'return','throw'})do
  local _,a,s=setup();local object={};a.EvaluateNextAction=function()s.calls=s.calls+1;error(object,0)end;local original=a.EvaluateNextAction
  s.provider.MeasureCall=function(fn,...)fn(...);if mode=='throw'then error('NATIVE')end;return {}end
  assert(a:StartCPURuntimeCapture());local ok,err=pcall(a.EvaluateNextAction,a);assert(not ok and rawequal(err,object) and s.calls==1 and a.EvaluateNextAction==original and not a:IsCPURuntimeCaptureRunning())
 end
end)
test('legitimate recursive evaluator dispatch remains once each without nested measurement',function()
 local _,a,s=setup();a.EvaluateNextAction=function(self)s.calls=s.calls+1;if s.calls==1 then self:EvaluateNextAction()end;return 9 end
 assert(a:StartCPURuntimeCapture());assert(a:EvaluateNextAction()==9 and s.calls==2 and s.measures==1);complete(a,s)
end)
test('cancel disable ownership and stale wrappers never overwrite newer evaluator or measure late',function()
 local _,a,s=setup();assert(a:StartCPURuntimeCapture());local stale=a.EvaluateNextAction;local newer=function()return 'new'end;a.EvaluateNextAction=newer
 assert(a:CancelCPURuntimeCapture());assert(a.EvaluateNextAction==newer);stale(a);assert(s.calls==1 and s.measures==0);s.timers[1].fn();assert(#s.finished==1)
 local _,b,t=setup();assert(b:StartCPURuntimeCapture());assert(b:CancelCPURuntimeCapture());assert(b.EvaluateNextAction==t.original and t.timers[1].cancelled)
end)
test('cancel from native before entry makes current dispatch unmeasured and closes saved callback',function()
 local _,a,s=setup();local delayed;s.provider.MeasureCall=function(fn,...)delayed=fn;assert(a:CancelCPURuntimeCapture());return {}end
 assert(a:StartCPURuntimeCapture());a:EvaluateNextAction();assert(s.calls==1 and s.measures==0);delayed(a);assert(s.calls==1 and #s.finished==1)
end)
test('late provider replacement retires capture and preserves normal dispatch',function()
 local f,a,s=setup();assert(a:StartCPURuntimeCapture());f.env.C_AddOnProfiler={};a:EvaluateNextAction();assert(s.calls==1 and s.measures==0 and not a:IsCPURuntimeCaptureRunning())
end)
test('opaque malformed and overflow allocation metrics never become invented byte totals',function()
 for _,bytes in ipairs({{},'18446744073709551615',-1,1.5,9007199254740992})do
  local _,a,s=setup();s.provider.MeasureCall=function(fn,...)local r=tuple(fn(...));return {elapsedMilliseconds=.1,allocatedBytes=bytes,deallocatedBytes=bytes},unpack(r,1,r.n)end
  assert(a:StartCPURuntimeCapture());a:EvaluateNextAction();local text=complete(a,s);has(text,'allocatedBytes=unavailable');has(text,'deallocatedBytes=unavailable');assert(s.calls==1)
 end
end)
test('512 measured dispatches bound memory and restore before next normal call',function()
 local _,a,s=setup();assert(a:StartCPURuntimeCapture());for _=1,513 do a:EvaluateNextAction()end
 assert(s.calls==513 and s.measures==512 and not a:IsCPURuntimeCaptureRunning() and a.EvaluateNextAction==s.original);has(a:GetCPURuntimeCaptureReport(),'measured=512')
end)
test('mutual exclusion and setup timer reentry leave no orphan wrapper',function()
 local _,a,s=setup();a.IsCPUProfileRunning=function()return true end;assert(not a:StartCPURuntimeCapture() and a.EvaluateNextAction==s.original)
 local _,b,t=setup();b.ScheduleTimer=function(_,fn)fn();return {}end;assert(not b:StartCPURuntimeCapture());assert(not b:IsCPURuntimeCaptureRunning() and b.EvaluateNextAction==t.original)
 local _,c,u=setup();c.ScheduleTimer=function()error('timer')end;assert(not c:StartCPURuntimeCapture() and c.EvaluateNextAction==u.original and not c:IsCPURuntimeCaptureRunning())
end)
-- Reuse real scoped main + real store/publisher fixture, not a replacement evaluator.
local function real()
 local h=assert(io.open('tests/rotation_scope_runtime.lua'));local source=h:read('*a');h:close()
 local prefix=assert(source:match('^(.-)\ntest%('));local make=assert(loadstring(prefix..'\nreturn fixture','@runtime-capture-real-main'))()
 local e,a,events,body,reference,save,load=make();local s={now=100,timers={}};e.GetTimePreciseSec=function()return s.now end
 a.ScheduleTimer=function(_,fn,delay)local t={fn=fn,delay=delay};s.timers[#s.timers+1]=t;return t end;a.CancelTimer=function(_,t)t.cancelled=true end
 a.IsCPUProfileRunning=function()return false end
 e.C_AddOnProfiler={IsEnabled=function()return true end,MeasureCall=function(fn,...)local r=tuple(fn(...));return {elapsedMilliseconds=.3,allocatedBytes=0,deallocatedBytes=0},unpack(r,1,r.n)end}
 load('Diagnostics/errors.lua');load('Diagnostics/cpu_runtime.lua');return e,a,events,body,reference,save,s,load
end
test('actual main publisher outputs and retirement semantics match ordinary dispatch',function()
 local _,a,events=real();a:EvaluateNextAction();local want=events;local _,b,got=real();assert(b:StartCPURuntimeCapture());b:EvaluateNextAction()
 assert(#want==#got and a.currentSpell==b.currentSpell);for i=1,#want do for k,v in pairs(want[i])do assert(got[i][k]==v)end end
 local _,c,retired=real();c.GlowNextSpell=function()c.db.profile=c.RotationData.CopyData(c.db.profile);assert(c:BindRotationProfile())end
 assert(c:StartCPURuntimeCapture());c:EvaluateNextAction();assert(#retired==1 and retired[1][1]=='preview-clear')
end)
test('actual Diagnostics.Call error still invokes original advice shutdown exactly once',function()
 local _,a,_,_,_,_,_,load=real();local throws,stops=0,0
 a.EvaluateNextActionInternal=function()throws=throws+1;error('CONTROLLED_EVALUATOR_FAILURE',0)end
 local stop=a.StopAdviceForError;a.StopAdviceForError=function(self,id)stops=stops+1;return stop(self,id)end
 assert(a:StartCPURuntimeCapture());a:EvaluateNextAction();assert(throws==1 and stops==1 and a.adviceErrorReport~=nil and #a.Diagnostics:GetReports()>=1)
 a:EvaluateNextAction();assert(throws==1 and stops==1)
end)
test('real cumulative capture and native capture exclude each other and disable cancels both',function()
 local h=assert(io.open('tests/cpu.lua'));local source=h:read('*a');h:close()
 local make=assert(loadstring(assert(source:match('^(.-)\ntest%('))..'\nreturn fixture','@native-cumulative-fixture'))()
 local f,a,s=make();f.env.C_AddOnProfiler={IsEnabled=function()return true end,MeasureCall=function()error('not used')end};f.load('Diagnostics/cpu_runtime.lua')
 assert(a:StartCPURuntimeCapture());local ok,why=a:StartCPUProfile();assert(not ok and why=='native-runtime-capture-running');assert(a:CancelCPURuntimeCapture())
 assert(a:StartCPUProfile());assert(not a:StartCPURuntimeCapture());a:OnDisable();assert(not a:IsCPUProfileRunning())
 assert(a:StartCPURuntimeCapture());a:OnDisable();assert(not a:IsCPURuntimeCaptureRunning() and a.EvaluateNextAction==s.hot)
end)
test('readability reentry cannot cause native call after capture retirement',function()
 local f,a,s=setup();assert(a:StartCPURuntimeCapture());local once=true
 f.env.canaccessvalue=function(v)if once then once=false;assert(a:CancelCPURuntimeCapture())end;return true end
 a:EvaluateNextAction();assert(s.calls==1 and s.measures==0 and not a:IsCPURuntimeCaptureRunning())
end)
test('provider callback cannot replace actual receiver or intercepted argument holes',function()
 local _,a,s=setup();s.provider.MeasureCall=function(fn)local r=tuple(fn({},'WRONG'));return {elapsedMilliseconds=.1,allocatedBytes=0,deallocatedBytes=0},unpack(r,1,r.n)end
 assert(a:StartCPURuntimeCapture());local r=tuple(a:EvaluateNextAction(nil,7,nil));assert(s.calls==1 and s.args.n==3 and s.args[1]==nil and s.args[2]==7 and s.args[3]==nil and r.n==4 and r[1]=='RM')
 assert(not a:IsCPURuntimeCaptureRunning());has(a:GetCPURuntimeCaptureReport(),'invalid')
end)
test('startup cancellation publishes one bounded report and delayed completion reports actual duration',function()
 local _,a,s=setup();s.provider.IsEnabled=function()assert(a:CancelCPURuntimeCapture());return true end
 assert(not a:StartCPURuntimeCapture());assert(not a:IsCPURuntimeCaptureRunning() and a.EvaluateNextAction==s.original and #s.finished==1);has(a:GetCPURuntimeCaptureReport(),'cancelled')
 local _,b,t=setup();assert(b:StartCPURuntimeCapture());b:EvaluateNextAction();t.now=112.5;t.timers[1].fn();has(b:GetCPURuntimeCaptureReport(),'actual=12.500 s')
end)
test('native callback returns only a sentinel while private original tuple forwards intact',function()
 local _,a,s=setup();local object={};a.EvaluateNextAction=function()s.calls=s.calls+1;return object,nil,false,nil end
 s.provider.MeasureCall=function(fn,...)local r=tuple(fn(...));assert(r.n==1 and r[1]=='RM:runtime','native saw gameplay return tuple');return {elapsedMilliseconds=.1,allocatedBytes=0,deallocatedBytes=0},r[1]end
 assert(a:StartCPURuntimeCapture());local r=tuple(a:EvaluateNextAction());assert(r.n==4 and rawequal(r[1],object)and r[2]==nil and r[3]==false and r[4]==nil and s.calls==1 and a:IsCPURuntimeCaptureRunning())
end)
finish()
