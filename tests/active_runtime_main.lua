-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Main-loop protocol controls. Fake private producers test routing/lifetime only;
-- actual plan admission, graph correctness and native cost have separate suites.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local make=dofile('tests/fixtures/rotation_execution.lua')
local nativeLoadfile,nativeGetfenv,nativeSetfenv=loadfile,getfenv,setfenv
local function fixture(prepared)
 local state={mode='decline',current=true,acquires=0,prepares=0,booleans=0,results=0,retires=0,registrations=0,token={}}
 _G.loadfile=function(path)
  local chunk=assert(nativeLoadfile(path=='main.lua' and arg[1] or path))
  if path~='main.lua' then return chunk end
  return function(name,a)
   local env=nativeGetfenv(1);nativeSetfenv(chunk,env)
   if prepared==false then a.preparedRuntimeEnabled=false end
   a.ConsumeActiveRuntimePlan=function(owner)
    assert(owner==a)
    return function(self,spec,key)
     assert(self==a and spec==a.currentSpec and key==a.currentRotation);state.acquires=state.acquires+1
     if state.mode=='decline' then return nil,nil,nil,false end
     local body=state.body;if state.mode=='unavailable' then body=nil end
     state.fullLease=function()state.fullChecks=(state.fullChecks or 0)+1;return state.current end
     return body,state.fullLease,state.token,true,state.views,state.cheapLease,state.notifiedLease
    end,function(self,spellIds,sequence,environment)
     assert(self==a and spellIds==a.GetSpellIds and type(environment)=='table')
     state.registrations=state.registrations+1
    end
   end
   a.ConsumeConditionRuntime=function(owner)
    assert(owner==a)
    return function(self,body,token,current,fullCurrent)
     assert(self==a and body==state.body and token==state.token and current());state.prepares=state.prepares+1
     state.receivedCheap,state.receivedFull=current,fullCurrent
     if state.onPrepare then return state.onPrepare(self) end
     local session={
      AfterOpaque=function()if state.onFence then return state.onFence()end;return state.current end,
      EvaluateBool=function(_,value,context)state.booleans=state.booleans+1;return a:evaluateCondition(value,context)end,
      EvaluateResult=function(_,value,context)state.results=state.results+1;return a:evaluateConditionResult(value,context)end,
     }
     state.session=session;return session
    end,function(owner,previous)assert(owner==a);state.retires=state.retires+1;state.retiredSession=previous;return not state.rejectRetire end
   end
   return chunk(name,a)
  end
 end
 local ok,c=pcall(make,{target=false});_G.loadfile=nativeLoadfile;assert(ok,c)
 state.body=assert(c.a:GetRuntimeRotation(c.a.currentSpec,c.a.currentRotation))
 state.acquires,state.prepares,state.booleans,state.results,state.retires=0,0,0,0,0
 return c,state
end

test('explicit compatibility startup keeps the previous path despite installed prepared producers',function()
 local c,s=fixture(false);s.mode='plan';c.reset(true);c.tick();local native=c.snapshot()
 assert(s.acquires==0 and s.prepares==0,'prepared executor ignored the startup compatibility override')
 assert((native.SendMessage or 0)>0,'ordinary evaluation did not publish')
 c.a.preparedRuntimeEnabled=true;c.tick()
 assert(s.acquires==0,'startup-only executor flag changed a running evaluator')
 assert(#c.a.Diagnostics:GetReports()==0)
end)
test('source-owned consumers register once and declined acquisition keeps legacy condition route',function()
 local c,s=fixture();assert(s.registrations==1,'missing source consumer handoff');c.tick()
 assert(s.acquires==1 and s.prepares==0 and s.results==0 and s.booleans==0)
end)
test('admitted main invocation routes branch and upkeep predicates through its lexical session',function()
 local c,s=fixture();s.mode='plan';c.tick()
 assert(s.acquires==1 and s.prepares==1 and s.results>0 and s.booleans>0,'compiled session was bypassed')
 assert(#c.a.Diagnostics:GetReports()==0)
end)
test('unsupported tree reacquires legacy body before any condition callback',function()
 local c,s=fixture();s.mode='plan';s.onPrepare=function()return nil end
 local a=c.a;local acquire=a.AcquireRotationRuntimePass;local calls=0
 a.AcquireRotationRuntimePass=function(self,...)calls=calls+1;return acquire(self,...)end
 c.tick();assert(s.prepares==1 and calls>0 and s.booleans==0 and s.results==0,'unsupported input did not return to legacy route')
 assert(#a.Diagnostics:GetReports()==0)
end)
test('stale prepare cannot disable a reentrant newer selection or run old condition callbacks',function()
 local c,s=fixture();local a=c.a;s.mode='plan';local disables=0
 a.DisableRotation=function()disables=disables+1 end
 s.onPrepare=function(self)s.current=false;self.currentRotation='NEWER';return nil end
 c.tick();assert(a.currentRotation=='NEWER' and disables==0 and s.results==0 and s.booleans==0)
end)
test('handled unavailable acquisition with stale lease aborts instead of disabling',function()
 local c,s=fixture();s.mode='unavailable';s.current=false;local disables=0
 c.a.DisableRotation=function()disables=disables+1 end;c.tick()
 assert(s.acquires==1 and s.prepares==0 and disables==0)
end)
test('disabling the selected rotation retires its condition runtime',function()
 local c,s=fixture();c.a.DestroyAllGlows=function()end
 c.a:DisableRotation();assert(s.retires==1,'condition subscriptions retained on disable')
end)
test('publication rejects a fast lease retired during condition evaluation without a legacy pass',function()
 local c,s=fixture();s.mode='plan'
 s.onPrepare=function()
  return {AfterOpaque=function()return true end,EvaluateBool=function()s.current=false;return false end,EvaluateResult=function()s.current=false;return {status='no-match'}end}
 end
 c.reset(true);c.tick();local native=c.snapshot()
 assert((native.SendMessage or 0)==0 and (native.GlowClear or 0)==0,'retired fast plan published advice')
end)
test('post preparation authority rejection skips all compiled leaves and publication',function()
 local c,s=fixture();s.mode='plan';local fences=0
 s.onFence=function()fences=fences+1;return false end
 c.reset(true);c.tick();local native=c.snapshot()
 assert(fences==1 and s.booleans==0 and s.results==0 and (native.SendMessage or 0)==0,'authority rejection resumed work')
 assert(#c.a.Diagnostics:GetReports()==0,'authority boundary threw')
end)
test('legacy fallback retires exactly the preceding session before resuming ordinary callbacks',function()
 local c,s=fixture();s.mode='plan';c.tick();local session=s.session;assert(session)
 s.mode='decline';c.reset(true);c.tick();local native=c.snapshot()
 assert(s.retiredSession==session,'fallback did not identify its previous session')
 assert((native.SendMessage or 0)>0,'legacy evaluation did not continue')
end)
test('rejected stale cleanup cannot resume legacy evaluation or publication',function()
 local c,s=fixture();s.mode='plan';c.tick();s.mode='decline';s.rejectRetire=true
 local calls=0;local acquire=c.a.AcquireRotationRuntimePass
 c.a.AcquireRotationRuntimePass=function(...)calls=calls+1;return acquire(...)end
 c.reset(true);c.tick();local native=c.snapshot()
 assert(calls==0 and (native.SendMessage or 0)==0,'stale cleanup resumed old work')
end)
test('fast cooldown publication uses detached style views without passing private condition roots',function()
 local c,s=fixture();s.mode='plan';s.views={};local expected={};local seen=0
 for _,cond in pairs(s.body.cooldowns)do local view={id=cond.id};s.views[cond]=view;expected[view]=true end
 c.a.GlowCooldown=function(_,_,_,cond)assert(expected[cond],'private cooldown condition escaped');seen=seen+1 end
 c.tick();assert(seen>0 and #c.a.Diagnostics:GetReports()==0)
end)
test('missing fast style mapping never falls back to publishing a private condition',function()
 for _,empty in ipairs({false,true})do
  local c,s=fixture();s.mode='plan';if empty then s.views={}end;local seen=0
  c.a.GlowCooldown=function()seen=seen+1 end;c.tick();assert(seen==0,'private fallback escaped')
 end
end)
test('successful source-owned Prepare needs only the notification ticket before environment work',function()
 local c,s=fixture();s.mode='plan';s.notifiedLease=function()return s.current end
 s.onPrepare=function()
  assert(s.receivedFull(),'simulated owned Prepare final fence rejected')
  return {AfterOpaque=function()
   assert(s.fullChecks==2,'main repeated full authority after the successful Prepare fence')
   return false
  end}
 end
 c.tick();assert(#c.a.Diagnostics:GetReports()==0,'duplicate post-Prepare proof or callback error')
end)
test('condition preparation receives separate cheap continuation and full publication fences',function()
 local c,s=fixture();s.mode='plan';s.cheapLease=function()return s.current end;c.tick()
 assert(s.prepares==1 and s.receivedCheap==s.cheapLease,'condition path repeated full publication admission')
 assert(s.receivedFull==s.fullLease and s.receivedFull~=s.receivedCheap,'opaque callback lost its full publication fence')
end)
finish()
