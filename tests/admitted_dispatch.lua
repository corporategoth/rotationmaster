local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(p)local f=assert(io.open(p));local s=f:read('*a');f:close();return s end
local prefix=assert(read('tests/acquisition_proof_consolidation.lua'):match('^(.-)\ntest%('))
local acquired,find,calls=assert(loadstring(prefix..'\nreturn acquired,find,calls','@admitted-dispatch-fixture'))()
local function prepared()
 local c,a,get=acquired(true);local b,full,_,handled,_,_,_,_,dispatch=get(a,0,a.currentRotation)
 assert(handled and b and full()and type(dispatch)=='function','missing admitted execution capability')
 return c,a,get,b,full,dispatch
end
test('admitted dispatch does not repeat selected Store or dependency authority walks',function()
 local _,_,_,_,full,dispatch=prepared();local store=assert(find(full,'guard'));local authority=assert(find(full,'runtimeAuthority'))
 assert(calls(store,function()for i=1,7 do assert(dispatch('condition')and dispatch('step')and dispatch('iterator'))end end)==0)
 assert(calls(authority,function()for i=1,7 do assert(dispatch('resume'))end end)==0)
 local continuation=assert(find(full,'continuationCurrent'))
 assert(calls(continuation,function()for i=1,7 do assert(dispatch('condition')and dispatch('resume'))end end)==14,'callback-free dispatch repeated ownership reads')
end)
test('managed notifications and owner replacements retire admitted execution immediately',function()
 for _,what in ipairs({'dependency','profile','key'})do local _,a,_,_,_,dispatch=prepared()
  if what=='dependency'then a:InvalidateRotationDependencies('effect','dispatch')elseif what=='profile'then a.db.profile={}else a.currentRotation='other'end
  assert(not dispatch('resume'),what)
 end
end)
test('unused producer source stays full-admission-only but real receivers remain fenced',function()
 local _,a,_,_,full,dispatch=prepared();local fn=a.RotationData.IsRotationClassToken;setfenv(fn,setmetatable({},{__index=getfenv(fn)}))
 assert(dispatch('resume')and not full(),'unused admission producer repeated during execution')
 a.GetSpellIds=function()error('unknown')end;assert(not dispatch('step'),'unknown step receiver admitted')
end)
test('private iteration and path copy source replacements are rejected before handoff',function()
 for _,what in ipairs({'pairs','ipairs','CopyData','CheckPortable'})do
  local c,a,_,_,_,dispatch=prepared();local leaseKind=(what=='pairs'or what=='ipairs')and'iterator'or'pathcopy'
  if a.RotationData[what]then a.RotationData[what]=function()error('unknown')end else c.e[what]=function()error('unknown')end end
  assert(not dispatch(leaseKind),what)
 end
end)
test('unnotified nested roots are caught by final full proof while immutable execution stays usable',function()
 local _,a,_,_,full,dispatch=prepared();a.db.profile.rotationStore={}
 assert(dispatch('resume')and not full(),'phase-specific raw mutation contract lost')
end)
test('legacy sequence captures condition metadata before custom CopyData callback',function()
 local original={};local step={id='before',type='stop',conditions=original};local row={section='rotation',step=step,path={'rotation',1},ordinal=1}
 local a={RotationData={IndexRotationSteps=function()return{rows={row}}end}}
 a.RotationData.CopyData=function(path)step.id='after';step.conditions={};return path end
 assert(loadfile('Core/rotation_sequence.lua'))('test',a)
 local seen;a:EvaluateRotationSequence({rotation={step}},function(conditions,context)seen=conditions;assert(context.stepId=='before');return{status='no-match'}end,function()error('unexpected visitor')end)
 assert(seen==original,'legacy CopyData changed already-evaluated condition argument')
end)
test('legacy sequence captures visitor ordinal before custom CopyData callback',function()
 local step={id='one',type='spell'};local row={section='rotation',step=step,path={'rotation',1},ordinal=1}
 local a={RotationData={IndexRotationSteps=function()return{rows={row}}end}}
 a.RotationData.CopyData=function(path)row.ordinal=99;return path end
 assert(loadfile('Core/rotation_sequence.lua'))('test',a)
 local seen;a:EvaluateRotationSequence({rotation={step}},function()error('unexpected evaluator')end,function(_,ordinal)seen=ordinal;return false end)
 assert(seen==1,'legacy CopyData changed already-evaluated ordinal argument')
end)
test('completed generation skips only the preliminary warm full proof',function()
 for _,target in ipairs({false,true})do
  local c,a,get,body,full=acquired(target);local store=assert(find(full,'guard'));local nextFull
  local n=calls(store,function()local b,f,_,handled=get(a,0,a.currentRotation);assert(handled and b==body);nextFull=f end)
  assert(n==1,'warm acquisition full selected Store proofs='..n..', expected one entry-tail proof')
  assert(calls(store,function()assert(nextFull())end)==1,'returned full publication proof was removed')
  local level=c.e.UnitLevel;local reads=0;c.e.UnitLevel=function(unit)reads=reads+1;return level(unit)end
  for i=1,3 do local b,f,_,h=get(a,0,a.currentRotation);assert(h and b==body and f())end
  assert(reads==3,'cached generation skipped fresh native eligibility')
 end
end)
test('managed content and dependency notifications rebuild before private reuse',function()
 for _,what in ipairs({'edit','dependency'})do
  local _,a,get,body,full=acquired(true);local selected=assert(find(full,'selected'));local token=selected.token
  if what=='dependency'then assert(a:InvalidateRotationDependencies('effect','cached-plan-test'))
  else
   local key=a.currentRotation;local record,issue=assert(a:GetRotationRecordSnapshot(0,key));record.body.description='Notified cached plan edit'
   assert(a:CommitRotationDraft(assert(a:GetScopedRotationCoordinator():Resolve(0,key)),issue,record,'class'))
  end
  local b,f,nextToken,handled=get(a,0,a.currentRotation)
  assert(handled and b and f()and nextToken~=token and b~=body,what..' reused the prior private graph')
 end
end)
test('raw body-root replacement keeps explicit refresh recovery and never returns stale private data',function()
 local _,a,get,body=acquired(true);local key=a.currentRotation
 local address=assert(a:GetScopedRotationCoordinator():Resolve(0,key)).address
 local record=a.db.profile.rotationStore.classes[address.owner][address.spec][address.id]
 record.body=assert(a.RotationData.CopyData(record.body))
 local nextBody,_,_,handled=get(a,0,key)
 assert(not handled and nextBody==nil,'stale private body returned after entry-tail root rejection')
 local fallback=find(a.EvaluateNextActionInternal,'acquireEvaluationPass')
 local pass;if fallback then pass=fallback(a,0)else pass=a:AcquireRotationRuntimePass(0)end
 local legacy,reason;if pass then legacy,reason=pass:Get(key)end
 assert(legacy==nil and reason=='stale-store-index','raw edit bypassed the predecessor explicit-refresh contract: '..tostring(reason))
 assert(a:BindRotationProfile(),'explicit profile refresh could not recover valid raw replacement')
 local fresh,full,_,nextHandled=get(a,0,a.currentRotation)
 assert(nextHandled and fresh and fresh~=body and full(),'generation-invalidating refresh did not recover a fresh private body')
end)
test('nested fresh acquisition never lets the superseded entry publish its stamp',function()
 local c,a,get=acquired(true);local native=c.e.UnitLevel;local entered=false;local nestedFull
 c.e.UnitLevel=function(unit)
  if not entered then entered=true;local b,f,_,h=get(a,0,a.currentRotation);assert(h and b and f());nestedFull=f end
  return native(unit)
 end
 local body,full,_,handled=get(a,0,a.currentRotation)
 assert(entered and handled and body==nil and not full()and nestedFull(),'older entry refreshed or retired nested acquisition')
 c.e.UnitLevel=native
 local store=assert(find(nestedFull,'guard'))
 assert(calls(store,function()local b,f,_,h=get(a,0,a.currentRotation);assert(h and b and f)end)==1,'older entry overwrote nested completed generation')
end)
finish()
