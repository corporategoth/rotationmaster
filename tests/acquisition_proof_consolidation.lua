-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local value=h:read('*a');h:close();return value end
local prefix=assert(read('tests/active_runtime_plan.lua'):match('^(.-)\ntest%('))
local fixture,change=assert(loadstring(prefix..'\nreturn fixture,change','@acquisition-proof-fixture'))()
local function find(value,name,seen)
 if type(value)~='function'and type(value)~='table'then return end;seen=seen or {};if seen[value]then return end;seen[value]=true
 if type(value)=='function'then
  for i=1,100 do local n,v=debug.getupvalue(value,i);if not n then break end;if n==name then return v end end
  for i=1,100 do local n,v=debug.getupvalue(value,i);if not n then break end;local got=find(v,name,seen);if got then return got end end
 else for _,v in pairs(value)do local got=find(v,name,seen);if got then return got end end end
end
local function calls(fn,run)
 local n=0;local old,mask,step=debug.gethook();local enabled=jit and jit.status();if jit then jit.off();jit.flush()end
 debug.sethook(function(event)if event=='call'and debug.getinfo(2,'f').func==fn then n=n+1 end end,'c')
 local ok,why=pcall(run);debug.sethook(old,mask,step);if enabled then jit.on()end;assert(ok,why);return n
end
local function acquired(target)
 local c,a,get=fixture(target);local b,full,t,h,_,_,notified=get(a,0,a.currentRotation)
 assert(h and b and full()and notified(),'real scoped saved-copy plan did not admit')
 return c,a,get,b,full,t,notified
end
-- b55cca0e: a cached completed plan skips the preliminary prior-plan authority check, so a warm acquisition performs only the
-- fresh full Scope entry proof (docs/architecture/runtime-revisions.md); it used to perform that one and the preliminary one.
test('warm acquisition uses one full selected Store proof and keeps returned publication proof',function()
 for _,target in ipairs({false,true})do
  local _,a,get,body,full,token=acquired(target);local guard=assert(find(full,'guard'));local nextFull
  local count=calls(guard,function()local b,f,t,h=get(a,0,a.currentRotation);assert(h and b==body and t==token);nextFull=f end)
  assert(count==1,'warm acquisition full selected Store proofs='..count..', expected 1')
  assert(calls(guard,function()assert(nextFull())end)==1,'returned publication guard lost full Store proof')
 end
end)
test('native level eligibility remains fresh once per warm acquisition and content plan stays stable',function()
 local c,a,get,body,_,token=acquired(true);local original=c.e.UnitLevel;local count=0
 c.e.UnitLevel=function(unit)count=count+1;return original(unit)end
 for i=1,3 do local b,full,t,h=get(a,0,a.currentRotation);assert(h and b==body and t==token and full())end
 assert(count==3,'native level calls='..count)
end)
test('changed selected Store schema version from native context rejects acquisition',function()
 local c,a,get=acquired(true);local native=c.e.UnitLevel;local changed=false
 c.e.UnitLevel=function(unit)if not changed then changed=true;a.db.profile.rotationStore.version=2 end;return native(unit)end
 local b,full,_,h=get(a,0,a.currentRotation);assert(changed and b==nil and(not h or not full()),'changed raw schema version survived context tail proof')
end)
test('same-key active operation during native context never refreshes the old acquisition stamp',function()
 local c,a,get,body=acquired(true);local native=c.e.UnitLevel;local changed=false
 c.e.UnitLevel=function(unit)if not changed then changed=true;local op=assert(a:BeginActiveRotationTransition());assert(a:CommitActiveRotationTransition(op,0,a.currentRotation,body))end;return native(unit)end
 local b,full,_,h=get(a,0,a.currentRotation);assert(changed and b==nil and h and not full(),'same-key operation acquired fresh authority for an old request')
end)
test('nested acquisition during native context retires only the older request',function()
 local c,a,get=acquired(true);local native=c.e.UnitLevel;local entered=false;local nestedFull,nestedNotified
 c.e.UnitLevel=function(unit)
  if not entered then entered=true;local b,f,_,h,_,_,n=get(a,0,a.currentRotation);assert(h and b and f()and n());nestedFull,nestedNotified=f,n end
  return native(unit)
 end
 local b,full,_,h=get(a,0,a.currentRotation)
 assert(entered and h and b==nil and not full()and nestedFull()and nestedNotified(),'older acquisition revoked or replaced nested authority')
end)
test('context primitive replacement declines before invoking changed eligibility helper',function()
 for _,name in ipairs({'type','ipairs'})do
  local c,a,get,_,full=acquired(true);local native=c.e.UnitLevel;local original=c.e[name];local eligible=assert(find(full,'planEligible'));local count=0;local changed=false
  c.e.UnitLevel=function(unit)if not changed then changed=true;c.e[name]=function(...)if debug.getinfo(2,'f').func==eligible then count=count+1 end;return original(...)end end;return native(unit)end
  local b=get(a,0,a.currentRotation);assert(changed and b==nil and count==0,name..' replacement was invoked '..count..' times')
 end
end)
test('changed private eligibility source environment declines before its callbacks receive input',function()
 local c,a,get,_,full=acquired(true);local eligible=assert(find(full,'planEligible'));local env={};for k,v in pairs(c.e)do env[k]=v end
 local calls=0;env.ipairs=function(...)calls=calls+1;return ipairs(...)end;env.type=function(...)calls=calls+1;return type(...)end
 setfenv(eligible,env);local b=get(a,0,a.currentRotation);assert(b==nil and calls==0,'changed eligibility environment consumed private input')
end)
test('invalid cached plan rebuilds after a managed content edit and profile replacement declines',function()
 local _,a,get,body,_,token=acquired(true);change(a,function(b)b.description='Acquisition successor'end)
 local b,full,t,h=get(a,0,a.currentRotation);assert(h and b and full()and b~=body and t~=token and b.description=='Acquisition successor')
 a.db.profile=a.RotationData.CopyData(a.db.profile);local nextBody,_,_,handled=get(a,0,a.currentRotation);assert(nextBody==nil and not handled)
end)
test('public context override remains outside the private acquisition route',function()
 local _,a,get=acquired(true);local n=0;a.GetRotationContext=function()n=n+1;error('public context')end
 local b,_,_,handled=get(a,0,a.currentRotation);assert(b==nil and not handled and n==0,'private preparation invoked public context override')
end)
finish()
