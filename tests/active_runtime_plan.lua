local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(target)
 -- The old measurement fixture loaded rotation_owner after Scope. Model its
 -- actual TOC position before Scope, without loading that producer twice.
 local loader=loadfile;local loaded={};local plans={}
 local mainPath=os.getenv('RM_ACTIVE_MAIN_SOURCE') or 'main.lua'
 _G.loadfile=function(path)
  if path=='main.lua' then
   local main=assert(loader(mainPath));local prepare=assert(loader('Core/active_runtime_plan.lua'))
   return function(name,owner)
    local env=getfenv(1);setfenv(prepare,env);prepare(name,owner)
    local acquire,register=owner:ConsumeActiveRuntimePlan();plans[owner]={acquire,register,owner.DispatchAnnouncement}
    owner.preparedRuntimeTrial=true
    setfenv(main,env);return main(name,owner)
   end
  end
  if path=='Core/rotation_scope.lua' or path=='Platform/rotation_owner.lua' then
   local original=assert(loader(path));local ownerChunk=assert(loader('Platform/rotation_owner.lua'))
   return function(name,owner)
    local env=getfenv(1)
    if not loaded[owner] then setfenv(ownerChunk,env);ownerChunk(name,owner);loaded[owner]=true end
    if path=='Core/rotation_scope.lua' then setfenv(original,env);return original(name,owner)end
   end
  end
  return loader(path)
 end
 -- Only the existing source-proof view is normalized; actual runtime chunks
 -- still come from loadfile above and execute the current Sequence source.
 local open=io.open
 io.open=function(path,mode)
  if path=='Core/rotation_sequence.lua' then
   local h=assert(open(path,mode));local text=h:read('*a');h:close()
   text=dofile('tests/fixtures/restore_active_runtime_plan.lua')(text,path)
   return {read=function()return text end,close=function()end}
  end
  return open(path,mode)
 end
 local ok,c=pcall(dofile('tests/fixtures/rotation_execution.lua'),{target=target==true,buttons=true});io.open=open;_G.loadfile=loader;assert(ok,c);local a=c.a
 c.e.LibStub('AceConsole-3.0').GetArgs=function(_,s)return s:match('^(%S+)'),(s:find(' ',1,true)or #s)+1 end
 a:HandleCommand('set Copy of Shaman: early leveling')
 -- The prior observation fixture replaces announcement delivery. Restore its
 -- actual source producer here: unknown callback consumers must not qualify.
 local held=assert(plans[a]);a.DispatchAnnouncement=held[3]
 local acquire,register=held[1],held[2]
 assert(type(acquire)=='function'and type(register)=='function','private plan handoff missing')
 register(a,a.GetSpellIds,a.EvaluateRotationSequence,c.e)
 return c,a,acquire
end
local function change(a,edit)
 local key=a.currentRotation;local record,token=assert(a:GetRotationRecordSnapshot(0,key));edit(record.body)
 local reference=assert(a:GetScopedRotationCoordinator():Resolve(0,key));assert(a:CommitRotationDraft(reference,token,record,'class'))
end
local function countCalls(fn,run)
 local n=0;local old,mask,step=debug.gethook();local enabled=jit and jit.status();if jit then jit.off();jit.flush()end
 debug.sethook(function(event)if event=='call'and debug.getinfo(2,'f').func==fn then n=n+1 end end,'c')
 local ok,why=pcall(run);debug.sethook(old,mask,step);if enabled then jit.on()end;assert(ok,why);return n
end
test('supported saved-copy polls reuse one prepared body and stable plan with fresh leases',function()
 for _,target in ipairs({false,true})do
  local _,a,acquire=fixture(target);local body,lease,token,handled=acquire(a,0,a.currentRotation)
  assert(handled and body and lease() and token,'actual saved copy did not admit')
  local original=a.AcquireRotationRuntimePass
  local oldLease=lease
  local calls=countCalls(original,function()
   for i=1,5 do local nextBody,nextLease,nextToken,nextHandled=acquire(a,0,a.currentRotation)
    assert(nextHandled and nextBody==body and nextToken==token and nextLease()and not oldLease(),'plan rebuilt or old poll survived')
    oldLease=nextLease
   end
  end)
  assert(calls==0,'warm plan rebuilt RuntimePass '..calls)
 end
end)
test('managed active content publication replaces plan and retires older poll authority',function()
 local _,a,acquire=fixture(true);local body,lease,token,handled=acquire(a,0,a.currentRotation);assert(handled and body and lease())
 local before=body.description;change(a,function(b)b.description='New managed active content'end)
 assert(not lease(),'old publication authority survived commit')
 local nextBody,nextLease,nextToken,nextHandled=acquire(a,0,a.currentRotation)
 assert(nextHandled and nextLease()and nextToken~=token and nextBody.description=='New managed active content'and body.description==before)
end)
test('public step consumer override declines before any execution body escapes',function()
 local _,a,acquire=fixture(true);local body,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and body)
 local calls=0;local original=a.GetSpellIds;a.GetSpellIds=function(self,step)calls=calls+1;return original(self,step)end
 local _,_,_,nextHandled=acquire(a,0,a.currentRotation);assert(not nextHandled and calls==0,'unknown step consumer received a private plan');assert(not lease())
end)
test('canonical body exposure retires the plan before returning mutable data',function()
 local _,a,acquire=fixture(true);local body,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and body)
 local raw=a:GetEditableRotation(0,a.currentRotation);assert(raw and not lease(),'exposure left old plan live')
 raw.description='Supported exposed write';local _,_,_,nextHandled=acquire(a,0,a.currentRotation);assert(not nextHandled,'exposed body rejoined managed plan')
end)
test('active identity copy remains pristine and diagnostics expose only detached scalar counters',function()
 local _,a,acquire=fixture(true);local before=a:GetActiveRuntimePlanDiagnostic();assert(before.plansBuilt==0)
 local body,lease,token,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
 local read,copy;a:BindActiveRotationPublication(function(_,_,_,_,r,c)read,copy=r,c end)
 local handle=assert(read(a,0,a.currentRotation));local original=assert(copy(a,handle));assert(body~=original)
 body.description='Execution-only control';assert(copy(a,handle).description==original.description,'active identity body escaped')
 local one=a:GetActiveRuntimePlanDiagnostic();assert(one.plansBuilt==1 and one.reused==0 and one.currentRoute=='managed')
 one.plansBuilt=999;assert(a:GetActiveRuntimePlanDiagnostic().plansBuilt==1)
 assert(acquire(a,0,a.currentRotation));local two=a:GetActiveRuntimePlanDiagnostic();assert(two.plansBuilt==1 and two.reused==1)
 a.GetSpellIds=function()error('must not dispatch')end;local _,_,_,handled=acquire(a,0,a.currentRotation);assert(not handled)
 local final=a:GetActiveRuntimePlanDiagnostic();assert(final.declined==1 and final.currentRoute=='fallback')
 for _,v in pairs(final)do assert(type(v)=='number'or type(v)=='string','diagnostic leaked plan data')end
end)
test('dependency publication and owner profile retirement invalidate old leases and plan identities',function()
 local _,a,acquire=fixture(true);local body,lease,token,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
 a:InvalidateRotationDependencies('effect','changed');assert(not lease())
 local nextBody,nextLease,nextToken,nextHandled=acquire(a,0,a.currentRotation);assert(nextHandled and nextBody and nextLease()and nextToken~=token)
 a.db.profile=a.RotationData.CopyData(a.db.profile);assert(not nextLease());local _,_,_,handled=acquire(a,0,a.currentRotation);assert(not handled)
end)
test('foreign and stale selection requests cannot revoke a newer valid poll',function()
 local _,a,acquire=fixture(true);local body,lease,token,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
 local _,_,_,foreign=acquire({},0,a.currentRotation);assert(not foreign and lease())
 local none,stale,_,handled=acquire(a,1,a.currentRotation);assert(handled and none==nil and not stale()and lease())
end)
test('same-selection semantic no-op reuses content plan but a new operation retires the old poll',function()
 local _,a,acquire=fixture(true);local body,lease,token,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
 local pending=a:BeginActiveRotationTransition();assert(not lease(),'new operation did not retire old request')
 assert(a:CommitActiveRotationTransition(pending,0,a.currentRotation,body))
 local nextBody,nextLease,nextToken,nextHandled=acquire(a,0,a.currentRotation)
 assert(nextHandled and nextLease()and nextToken==token and nextBody==body,'semantic no-op rebuilt content plan')
end)
test('raw selected body-root replacement cannot pair new Store validation with stale active content',function()
 local _,a,acquire=fixture(true);local body,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
 local r=assert(a:GetScopedRotationCoordinator():Resolve(0,a.currentRotation)).address
 local record=a.db.profile.rotationStore.classes[r.owner][r.spec][r.id]
 local replacement=a.RotationData.CopyData(record.body);replacement.description='Replacement body root';record.body=replacement
 assert(not lease(),'old selected root retained authority')
 local stale,_,_,nextHandled=acquire(a,0,a.currentRotation)
 assert(not nextHandled and stale==nil,'new plan paired stale active body with replacement Store root')
end)
test('supplied active snapshot inconsistent with Store stays on the legacy route',function()
 local _,a,acquire=fixture(true)
 local actual,lease,_,admitted=acquire(a,0,a.currentRotation);assert(admitted and lease())
 local other=a.RotationData.CopyData(actual);other.description='Different activation body'
 local operation=a:BeginActiveRotationTransition();assert(a:CommitActiveRotationTransition(operation,0,a.currentRotation,other))
 local body,_,_,handled=acquire(a,0,a.currentRotation)
 assert(not handled and body==nil,'private active body differed from the actual validated Store body')
end)
test('same-key operation renewed from eligibility callback retires callback-capable decline',function()
 local c,a,acquire=fixture(true);local body,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
 local level=c.e.UnitLevel;local calls=0
 c.e.UnitLevel=function(...) calls=calls+1;a:BeginActiveRotationTransition();return level(...) end
 local none,current,_,nextHandled=acquire(a,0,a.currentRotation)
 assert(calls>0 and nextHandled and none==nil and type(current)=='function'and not current(),'renewed operation resumed legacy decline')
end)
test('public body helper overrides decline before receiving the private execution body',function()
 do
  local c,a,acquire=fixture(true);local _,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
  local calls=0;c.e.ipairs=function(t)calls=calls+1;return ipairs(t)end
  local _,_,_,nextHandled=acquire(a,0,a.currentRotation);assert(not nextHandled and calls==0 and not lease(),'unknown sequence iterator admitted')
 end
 for _,name in ipairs({'CopyData','CheckPortable','IndexRotationSteps'})do
  local _,a,acquire=fixture(true);local body,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
  local calls=0;a.RotationData[name]=function()calls=calls+1;error('private data escaped')end
  local nextBody,_,_,nextHandled=acquire(a,0,a.currentRotation)
  assert(not nextHandled and nextBody==nil and calls==0 and not lease(),'unknown data helper admitted: '..name)
 end
end)
test('per-poll level eligibility is refreshed without replacing the content plan',function()
 local c,a,acquire=fixture(true);local body,lease,token,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
 c.e.UnitLevel=function()return 60 end
 local none,current,nextToken,nextHandled=acquire(a,0,a.currentRotation)
 assert(nextHandled and none==nil and current()and nextToken==token and not lease(),'fresh level did not suppress unavailable plan')
 c.e.UnitLevel=function()return 11 end
 local nextBody,nextLease,lastToken,lastHandled=acquire(a,0,a.currentRotation)
 assert(lastHandled and nextBody==body and nextLease()and lastToken==token and not current())
end)
test('ordinary public RuntimePass remains fresh and does not borrow the private execution copy',function()
 local _,a,acquire=fixture(true);local body,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
 local calls=0;local method=a.GetRotationValidationOptions
 a.GetRotationValidationOptions=function(self)calls=calls+1;return method(self)end
 local pass=assert(a:AcquireRotationRuntimePass(0));local public=assert(pass:Get(a.currentRotation))
 assert(calls>0 and public~=body and not lease(),'public getter did not retain fresh legacy dispatch')
end)
test('sequence, announcement, disabled-dependency and context overrides preserve eager dispatch',function()
 for _,name in ipairs({'EvaluateRotationSequence','DispatchAnnouncement','HasDisabledRotationDependency','GetRotationOwnerContext','GetRotationContext','AcquireRotationRuntimePass'})do
  local _,a,acquire=fixture(true);local body,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
  local calls=0;a[name]=function()calls=calls+1;error('unexpected private dispatch')end
  local nextBody,_,_,nextHandled=acquire(a,0,a.currentRotation)
  assert(not nextHandled and nextBody==nil and calls==0 and not lease(),'unknown consumer admitted: '..name)
 end
end)
test('public consumer environment replacement and dependency map defaults retain eager fallback',function()
 do
  local _,a,acquire=fixture(true);local _,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
  local fn=a.GetSpellIds;local before=getfenv(fn);setfenv(fn,setmetatable({},{__index=before}))
  local _,_,_,nextHandled=acquire(a,0,a.currentRotation);assert(not nextHandled and not lease())
 end
 do
  local _,a,acquire=fixture(true);local _,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
  setmetatable(a.db.profile.itemsets,{__index=function(t,k)local v={items={}};rawset(t,k,v);return v end})
  local _,_,_,nextHandled=acquire(a,0,a.currentRotation);assert(not nextHandled and not lease())
 end
end)
test('profile rebind and active disable retire prepared execution bodies',function()
 local _,a,acquire=fixture(true);local _,lease,token,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
 assert(a:BindRotationProfile());assert(not lease(),'rebound coordinator kept old lease')
 local body,current,nextToken,nextHandled=acquire(a,0,a.currentRotation)
 assert(not nextHandled or body and current()and nextToken~=token,'rebind reused old content authority')
 local pending=a:BeginActiveRotationTransition();assert(a:RetireActiveRotationTransition(pending));assert(not lease()and(not current or not current()),'disabled active selection kept lease')
 local _,_,_,lastHandled=acquire(a,0,a.currentRotation);assert(not lastHandled,'disabled selection rebuilt a managed plan')
end)
test('all seven changed existing modules reconstruct exact closed predecessor bytes',function()
 local restore=dofile('tests/fixtures/restore_active_runtime_plan.lua')
 for _,path in ipairs({'Core/rotation_active.lua','Core/rotation_references.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Core/announcements.lua','Core/rotation_sequence.lua','buttons.lua'})do
  local h=assert(io.open(path));local source=h:read('*a');h:close()
  local before=restore(nil,path,'before');assert(type(before)=='string'and #before>0 and before~=source)
  assert(restore(source,path)==before)
  local edit=source:sub(1,7)..(source:sub(8,8)=='X'and'Y'or'X')..source:sub(9)
  assert(#edit==#source and not pcall(restore,edit,path),'same-length unrelated source accepted: '..path)
  local at=assert(source:find('local',1,true));local x,y,z=source:byte(at,at+2)
  local collision=source:sub(1,at-1)..string.char(x+1,y-2,z+1)..source:sub(at+3)
  local function adler(text)local a,b=1,0;for i=1,#text do a=(a+text:byte(i))%65521;b=(b+a)%65521 end;return a+b*65536 end
  assert(#collision==#source and adler(collision)==adler(source)and not pcall(restore,collision,path),'same-length checksum collision accepted')
  assert(not pcall(restore,before:sub(1,7)..'X'..before:sub(9),path),'unrelated predecessor accepted')
 end
 assert(not pcall(restore,'x','Core/unknown.lua'))
end)
test('public RuntimePass mutable body changes ordinary advice and retires managed admission',function()
 local c,a,acquire=fixture(true);c.tick();local original=a.currentSpell
 local body,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
 local pass=assert(a:AcquireRotationRuntimePass(0));local public=assert(pass:Get(a.currentRotation));assert(public~=body)
 local changed=0
 for _,step in ipairs(public.rotation)do if step.action==403 then step.action=8042;changed=changed+1 end end
 assert(changed>0,'fixture lacked primary action');c.tick()
 assert(original==403 and a.currentSpell==8042,'public runtime mutation did not change actual legacy advice: '..tostring(original)..'→'..tostring(a.currentSpell))
 local _,_,_,nextHandled=acquire(a,0,a.currentRotation);assert(not nextHandled and not lease(),'borrowed mutable runtime asset remained privately eligible')
end)
test('supported Auto command and automatic candidate selection remain privately eligible',function()
 local _,a,acquire=fixture(true);local expected=a.currentRotation
 change(a,function(body)body.priority=100;body.switch={type='NOT',value={type='COMBAT',unit='player'}}end)
 a:UpdateAutoSwitch();a:HandleCommand('set auto')
 assert(a.currentRotation==expected and not a.manualRotation,'actual Auto command selected another source')
 local body,lease,_,handled=acquire(a,0,a.currentRotation)
 assert(handled and body and lease(),'source-owned automatic candidate acquisition marked a public borrow')
end)
test('public candidate and cleanup body borrows retire old plans before return',function()
 for _,mode in ipairs({'candidates','cleanup'})do
  local _,a,acquire=fixture(true);local _,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
  local coordinator=a:GetScopedRotationCoordinator();local returned
  if mode=='candidates'then returned=assert(a:AcquireRotationRuntimePass(0)):Candidates(false)[a.currentRotation]
  else returned=coordinator:Cleanup(0,a.currentRotation)end
  assert(returned and not lease(),'public '..mode..' borrow did not retire prior authority')
  local _,_,_,nextHandled=acquire(a,0,a.currentRotation);assert(not nextHandled)
 end
end)
test('owned cooldown publisher receives exact reusable style views detached from execution data',function()
 local _,a,acquire=fixture(false);local shared={r=.2,g=.3,b=.4,a=1};local effect=assert(next(a.db.global.effects))
 change(a,function(body)for _,row in ipairs(body.cooldowns)do row.color=shared;row.effect=effect end end)
 local body,lease,token,handled,views=acquire(a,0,a.currentRotation);assert(handled and lease()and type(views)=='table','missing presentation views')
 local allowed={id=true,effect=true,color=true,magnification=true,setpoint=true,xoffs=true,yoffs=true,angle=true}
 for _,row in ipairs(body.cooldowns)do
  local view=assert(views[row]);assert(view~=row and view.color~=row.color)
  for key in pairs(view)do assert(allowed[key],'private field projected: '..key)end
  for key in pairs(allowed)do if key~='color'then assert(view[key]==row[key])end end
  assert(view.conditions==nil and view.action==nil and view.type==nil)
 end
 local one,two=body.cooldowns[1],body.cooldowns[2];assert(one.color==two.color and views[one].color==views[two].color,'shared source color alias split')
 local again,nextLease,nextToken,nextHandled,nextViews=acquire(a,0,a.currentRotation)
 assert(nextHandled and nextLease()and again==body and nextToken==token and nextViews==views and nextViews[one]==views[one])
end)
test('nested graphics mutations preserve sibling and later eager color observations without touching private inputs',function()
 local c,a,acquire=fixture(false);local shared={r=.2,g=.3,b=.4,a=1};local effect=assert(next(a.db.global.effects))
 change(a,function(body)for _,row in ipairs(body.cooldowns)do row.color=shared;row.effect=effect;row.id=row.id..'-style' end end)
 local body,lease,_,handled,views=acquire(a,0,a.currentRotation);assert(handled and lease()and views)
 local one,two=body.cooldowns[1],body.cooldowns[2];local seen={}
 a.Glow=function(_,_,_,_,color)seen[#seen+1]=color;if #seen==1 then color.r=.75 else assert(color.r==.75,'sibling lost prior mutation')end end
 a:GlowCooldown(one.action,true,views[one]);a:GlowCooldown(two.action,true,views[two]);assert(#seen==2 and seen[1]==seen[2])
 assert(one.color.r==.2 and two.color.r==.2,'nested callback reached private execution color')
 local nextBody,nextLease,_,nextHandled,nextViews=acquire(a,0,a.currentRotation)
 assert(nextHandled and nextLease()and nextBody==body and nextViews[one].color.r==.75,'next poll lost mutable presentation state')
 local retained;a.GlowCooldown=function(_,_,_,condition)retained=condition end
 local none,_,_,admitted=acquire(a,0,a.currentRotation);assert(not admitted and none==nil and not nextLease(),'unknown cooldown publisher admitted')
 c.tick();assert(retained and retained.action and retained.conditions and retained.color.r==.75,'eager fallback lost original mutable condition/color semantics')
 for _,row in ipairs(body.cooldowns)do assert(row~=retained,'unknown publisher received private condition')end
end)
test('restoring the original publisher cannot readmit stale private data after legacy condition mutation',function()
 local c,a,acquire=fixture(false);local body,lease,_,handled=acquire(a,0,a.currentRotation);assert(handled and lease())
 local original=a.GlowCooldown;local retained
 a.GlowCooldown=function(_,_,_,condition)
  if condition then retained=condition;condition.action=8042;condition.conditions={type='AND',value={}}end
 end
 local none,_,_,admitted=acquire(a,0,a.currentRotation);assert(not admitted and none==nil and not lease())
 c.tick();assert(retained and retained.action==8042,'legacy mutable full-condition callback did not execute')
 for _,row in ipairs(body.cooldowns)do assert(row~=retained and row.action~=8042,'legacy callback changed private execution')end
 a.GlowCooldown=original
 local stale,_,_,nextHandled=acquire(a,0,a.currentRotation)
 assert(not nextHandled and stale==nil,'restored publisher readmitted stale active content')
 local canonical=assert(a:GetRotationRecordSnapshot(0,a.currentRotation)).body
 for _,row in ipairs(canonical.cooldowns)do assert(row.action~=8042,'legacy runtime mutation changed canonical storage')end
 assert(a.BindActiveRuntimePresentationSource==nil,'presentation receiver remained public after producer load')
end)
finish()
