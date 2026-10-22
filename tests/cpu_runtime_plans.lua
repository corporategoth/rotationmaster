-- Boundary-only scalar diagnostics qualify the path measured by native capture.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local h=assert(io.open('tests/cpu_runtime.lua'));local source=h:read('*a');h:close()
local setup=assert(loadstring(assert(source:match('^(.-)\ntest%('))..'\nreturn setup','@runtime-plan-real-capture'))()
local function has(text,value)assert(text:find(value,1,true),value..' missing: '..text)end
local function done(a,s)s.now=110;s.timers[1].fn();return a:GetCPURuntimeCaptureReport()end
local function providers(a)
 local p={plansBuilt=1,reused=2,declined=3,currentRoute='managed'}
 local c={compiles=1,legacyFallback=2,leafEvaluations=3,validatorCalls=4,stableHits=5,eventInvalidations=6,active=true}
 local reads=0
 a.GetActiveRuntimePlanDiagnostic=function()reads=reads+1;return p end
 a.GetConditionRuntimeDiagnostic=function()reads=reads+1;return c end
 return p,c,function()return reads end
end

test('runtime reports detached boundary routes and nonnegative counter deltas only',function()
 local _,a,s=setup();local p,c,reads=providers(a)
 assert(a:StartCPURuntimeCapture());assert(reads()==2)
 p.plansBuilt=2;p.reused=12;p.declined=5;c.compiles=2;c.stableHits=25;c.leafEvaluations=13
 for _=1,3 do a:EvaluateNextAction();a:GetCPURuntimeCaptureReport()end;assert(reads()==2,'hot dispatch read diagnostics')
 local text=done(a,s);assert(reads()==4)
 has(text,'Active runtime plan: start=managed; end=managed; plansBuilt=1; reused=10; declined=2')
 has(text,'Condition runtime: start=true; end=true; compiles=1; legacyFallback=0; leafEvaluations=10; validatorCalls=0; stableHits=20; eventInvalidations=0')
 a:GetCPURuntimeCaptureReport();assert(reads()==4)
end)
test('missing failing replaced or decreasing diagnostics withhold affected observations',function()
 for _,mode in ipairs({'missing','throw','replace','decrease'})do
  local _,a,s=setup();local p,c=providers(a)
  if mode=='missing'then a.GetActiveRuntimePlanDiagnostic=nil end
  if mode=='throw'then a.GetActiveRuntimePlanDiagnostic=function()error('PRIVATE_FAILURE')end end
  assert(a:StartCPURuntimeCapture())
  if mode=='replace'then a.GetActiveRuntimePlanDiagnostic=function()return p end end
  if mode=='decrease'then p.reused=1 end
  local text=done(a,s)
  if mode=='decrease'then has(text,'reused=unavailable')else has(text,'Active runtime plan: start='..(mode=='replace'and'managed'or'unavailable')..'; end=unavailable')end
  assert(not text:find('PRIVATE_FAILURE',1,true));has(text,'Condition runtime: start=true; end=true')
 end
end)
test('diagnostic records use raw scalar fields and never serialize private payloads',function()
 local _,a,s=setup();local calls=0
 a.GetActiveRuntimePlanDiagnostic=function()return setmetatable({currentRoute='PRIVATE_PAYLOAD',plansBuilt={private='PRIVATE_PAYLOAD'}},{__index=function()calls=calls+1;error('inherited field')end})end
 assert(a:StartCPURuntimeCapture());local text=done(a,s);assert(calls==0 and not text:find('PRIVATE_PAYLOAD',1,true))
 has(text,'Active runtime plan: start=unavailable; end=unavailable; plansBuilt=unavailable')
end)
finish()
