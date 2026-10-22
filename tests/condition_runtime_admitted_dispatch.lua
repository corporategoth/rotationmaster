-- Actual graph, enrolled callbacks and Diagnostics; only authority closures are controlled.
if jit then jit.off();jit.flush()end
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local prefix=assert(read('tests/condition_runtime.lua'):match('^(.-)\ntest%('))
local fixture,body,level,countCalls=assert(loadstring(prefix..'\nreturn fixture,body,level,countCalls','@admitted-condition-fixture'))()
test('managed dispatch replaces only repeated leaf postcallback full proofs',function()
 local f,_,prepare=fixture();local full=0;local kinds={};local root=level(40)
 local session=assert(prepare(f.addon,body(root),{},function()return true end,function()full=full+1;return true end,function(kind)kinds[kind]=(kinds[kind]or 0)+1;return true end))
 assert(full==0,'managed Prepare repeated full acquisition');assert(session:EvaluateBool(root))
 assert(full==0,'managed leaf repeated full source proof');assert(kinds.condition and kinds.condition>=4 and kinds.resume==3,'managed private dispatch/resume fences missing')
 assert(session:AfterOpaque()and full==0 and kinds.resume==4,'managed postenvironment authority changed')
end)
test('five argument callers retain original full callback and opaque boundaries',function()
 local f,_,prepare=fixture();local full=0;local root=level(40)
 local session=assert(prepare(f.addon,body(root),{},function()return true end,function()full=full+1;return true end));local before=full
 assert(session:EvaluateBool(root)and full==before+2);assert(session:AfterOpaque()and full==before+3)
end)
test('a denied resume latches the invocation and suppresses later independent roots',function()
 local allowed=true;local f,_,prepare=fixture(function(f)f.env.GetWeaponEnchantInfo=function()allowed=false;return true end end)
 local root={type='WEAPON'};local later={type='COMBAT',unit='player'};local b=body(root);b.cooldowns={{conditions=later}}
 local session=assert(prepare(f.addon,b,{},function()return true end,function()return true end,function()return allowed end))
 assert(session:EvaluateResult(root).status=='unavailable','denied managed resume accepted callback result');allowed=true
 assert(not session:IsCurrent(),'failed dispatch was revived')
 assert(countCalls(f.addon.conditionDefinitions.COMBAT.evaluate,function()assert(session:EvaluateResult(later).status=='unavailable')end)==0,'later private root ran after rejection')
end)
test('actual Diagnostic observer can deny dispatch before a private validator executes',function()
 local allowed=true;local f,s,prepare=fixture(function(f,state)
  local handler=function()end;f.env.geterrorhandler=function()if state.observe then state.observe()end;return handler end;f.env.seterrorhandler=function(value)handler=value end;f.load('Diagnostics/errors.lua')
 end)
 local root=level(40);local session=assert(prepare(f.addon,body(root),{},function()return true end,function()return true end,function()return allowed end));s.observe=function()allowed=false end
 assert(session:EvaluateResult(root).status=='unavailable','observer retirement did not stop private handoff')
 local stats=f.addon:GetConditionRuntimeDiagnostic();assert(stats.validatorCalls==0 and stats.leafEvaluations==0 and s.levelReads==0,'private callback ran after observer retirement')
end)
test('cached facts still check managed dispatch and cannot revive a rejected session',function()
 local f,s,prepare=fixture();local allowed=true;local root=level(40);local session=assert(prepare(f.addon,body(root),{},function()return true end,function()return true end,function()return allowed end))
 assert(session:EvaluateBool(root));local reads=s.levelReads;allowed=false
 assert(session:EvaluateResult(root).status=='unavailable','cached private result bypassed managed dispatch');allowed=true
 assert(not session:IsCurrent()and session:EvaluateResult(root).status=='unavailable'and s.levelReads==reads)
end)
test('managed lease never replaces actual provider source certificates',function()
 local f,_,prepare=fixture();local root={type='BUFF',unit='player',spell=324};local session=assert(prepare(f.addon,body(root),{},function()return true end,function()return true end,function()return true end));local escaped=false
 f.addon.EvaluateAuraCondition=function(_,value)escaped=true;value.ESCAPED=true;return true end
 assert(session:EvaluateResult(root).status=='unavailable'and not escaped and not root.ESCAPED)
end)
test('reentrant resume cannot retire the newer session or publish the older result',function()
 local f,_,prepare,retire=fixture();local root=level(40);local b=body(root);local token={};local nested;local once=false;local armed=false
 local session=assert(prepare(f.addon,b,token,function()return true end,function()return true end,function(kind)
  if kind=='resume'and armed and not once then once=true;nested=assert(prepare(f.addon,b,token,function()return true end,function()return true end,function()return true end))end
  return not once
 end))
 armed=true
 assert(session:EvaluateResult(root).status=='unavailable'and nested and nested:IsCurrent(),'old callback resumed over newer request')
 assert(not retire(f.addon,session)and nested:EvaluateBool(root),'old cleanup damaged nested session')
end)

test('five argument callers retain mandatory Prepare or opaque full rejection',function()
 local f,_,prepare=fixture();local root=level(40);local b=body(root);local allowed=false
 assert(prepare(f.addon,b,{},function()return true end,function()return allowed end)==nil,'legacy route bypassed final Prepare full rejection')
 allowed=true;local session=assert(prepare(f.addon,b,{},function()return true end,function()return allowed end));allowed=false
 assert(not session:AfterOpaque()and not session:IsCurrent(),'legacy route bypassed postenvironment full rejection')
end)

finish()
