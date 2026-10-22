-- Public borrow uses resolved identity; private generation is observed, never mutated.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
if arg[1]=='v2-only'then local run=test;test=function(name,callback)
 if name:find('unmapped unselected',1,true)or name:find('whole Scope inverse',1,true)then run(name,callback)end
end end
local function read(p)local h=assert(io.open(p));local s=h:read('*a');h:close();return s end
local prefix=assert(read('tests/active_runtime_plan.lua'):match('^(.-)\ntest%('))
local fixture=assert(loadstring(prefix..'\nreturn fixture','@public-borrow-fixture'))()
local function clock(acquire)
 for i=1,80 do local name,value=debug.getupvalue(acquire,i);if name=='readExecutionGeneration'then return value end end
 error('source-owned scalar generation reader missing')
end
local function selected()
 local c,a,acquire=fixture(false);local b,full,_,handled,_,_,notified=acquire(a,0,a.currentRotation)
 assert(handled and b and full()and notified(),'actual saved-copy plan did not qualify')
 return c,a,acquire,full,notified,assert(a:GetScopedRotationCoordinator():Resolve(0,a.currentRotation))
end
for _,form in ipairs({'scoped-key','stable-reference','bare-custom-id','Candidates','Cleanup-reference','GetRuntime-reference'})do
 test('selected public custom borrow notifies for '..form,function()
  local _,a,_,full,notified,ref=selected();local pass=assert(a:AcquireRotationRuntimePass(0));assert(notified(),'pass construction retired selected request')
  local body
  if form=='Candidates'then body=assert(pass:Candidates())[a.currentRotation]
  elseif form=='Cleanup-reference'then body=a:GetRotationForCleanup(0,ref)
  elseif form=='GetRuntime-reference'then body=a:GetRuntimeRotation(0,ref)
  else body=pass:Get(form=='scoped-key'and a.currentRotation or form=='stable-reference'and ref or ref.address.id)end
  assert(type(body)=='table'and not full(),'public selected body was not borrowed')
  assert(not notified(),'selected '..form..' borrow failed to notify before return')
 end)
end
test('builtin stable-reference borrow notifies its actual selected canonical key',function()
 local _,a,acquire=fixture(false);local readClock=clock(acquire);local coord=assert(a:GetScopedRotationCoordinator())
 local ref={kind='builtin',id='rm.tbc.shaman.starter'};local key=coord:Key(ref);local view=assert(a:GetDefaultRotation(ref.id))
 local op=assert(a:BeginActiveRotationTransition());assert(a:CommitActiveRotationTransition(op,0,key,view.envelope.body))
 local before=readClock();local pass=assert(a:AcquireRotationRuntimePass(0));assert(readClock()==before)
 assert(type(pass:Get(ref))=='table','actual builtin public borrow missing')
 assert(readClock()~=before,'selected builtin reference did not notify')
end)
test('unrelated public builtin borrow preserves selected custom execution',function()
 local _,a,acquire,full,notified=selected();local readClock=clock(acquire);local before=readClock()
 local pass=assert(a:AcquireRotationRuntimePass(0));assert(type(pass:Get({kind='builtin',id='rm.tbc.shaman.starter'}))=='table')
 assert(readClock()==before and notified()and full(),'unrelated builtin borrow retired selected body')
end)
test('unrelated public custom borrow preserves selected custom execution',function()
 local _,a,acquire=fixture(false);local other=assert(a:CloneDefaultRotation(0,'rm.tbc.shaman.starter','Unrelated borrowed copy',{scope='class'}))
 local b,full,_,handled,_,_,notified=acquire(a,0,a.currentRotation);assert(handled and b and full()and notified())
 local ref=assert(a:GetScopedRotationCoordinator():Resolve(0,other));local readClock=clock(acquire);local before=readClock()
 assert(type(assert(a:AcquireRotationRuntimePass(0)):Get(ref))=='table')
 assert(readClock()==before and notified()and full(),'unrelated custom borrow retired selected body')
end)
test('repeated borrowed asset access preserves body identity without redundant notification',function()
 local _,a,acquire,_,notified,ref=selected();local pass=assert(a:AcquireRotationRuntimePass(0));local first=assert(pass:Get(ref));assert(not notified())
 local readClock=clock(acquire);local before=readClock();assert(pass:Get(ref)==first and readClock()==before,'already borrowed asset notified again')
end)
test('unmapped unselected reference borrow neither creates a key nor adds a copy callback',function()
 local _,a=fixture(false);local id=assert(a:DuplicateCustomRotation(0,a.currentRotation,'Unselected borrowed control'))
 local ref=assert(a:GetScopedRotationCoordinator():Resolve(0,id));assert(a:BindRotationProfile())
 local original=a.RotationData.CopyData;local copies=0
 a.RotationData.CopyData=function(value)
  if type(value)=='table'and value.kind=='custom'and type(value.address)=='table'and value.address.id==id then copies=copies+1 end
  return original(value)
 end
 local pass=assert(a:AcquireRotationRuntimePass(0));local first=assert(pass:Get(ref));local firstCopies=copies
 assert(pass:Get(ref)==first,'public runtime alias changed')
 assert(firstCopies==1 and copies-firstCopies==1,'borrow created a visible key or added a CopyData callback')
 local beforeKey=copies;assert(a:GetScopedRotationCoordinator():Key(ref))
 assert(copies==beforeKey+1,'borrow eagerly allocated the formerly unmapped visible key')
end)
test('whole Scope inverse admits only the exact two-predicate successor',function()
 local now=read('Core/rotation_scope.lua');local inverse=dofile('tests/fixtures/restore_runtime_public_borrow_notification.lua')
 local pipe=assert(io.popen('git show 840e7a5bd0e87b75c7aa1f2be51560a3eb0e7e6d:Core/rotation_scope.lua'));local before=pipe:read('*a');assert(pipe:close())
 assert(inverse(now,'Core/rotation_scope.lua')==before and inverse(before,'Core/rotation_scope.lua')==before)
 local changed=now:sub(1,5)..'X'..now:sub(7);assert(#changed==#now and inverse(changed,'Core/rotation_scope.lua')==changed)
 assert(inverse(now..'\n','Core/rotation_scope.lua')==now..'\n'and inverse(now,'unrelated.lua')==now)
end)
finish()
