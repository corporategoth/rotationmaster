local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local make=dofile('tests/fixtures/rotation_execution.lua')
local function up(fn,key,seen)
 seen=seen or {};if seen[fn]then return end;seen[fn]=true
 for i=1,120 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==key then return v end end
 for i=1,120 do local k,v=debug.getupvalue(fn,i);if not k then break end;if type(v)=='function'then local r=up(v,key,seen);if r~=nil then return r end end end
end
local check=test
local function context()return{family='tbc',class='SHAMAN',spec=0,actionContext='player',level=11,build=123,combatDataPolicy='probe',ignored='outside'}end
check('public context ownership does not attest mutable private reader Context result freshness',function()
 local c=make({target=false});local a=c.a;local reader=assert(up(a:GetScopedRotationCoordinator().RuntimePass,'libraryReader'));assert(reader:OwnsContext(a.GetRotationContext))
 local value=context();reader.Context=function()return value,true end
 local p=assert(a:AcquireRotationRuntimePass(0));assert(p:IsCurrent());value.ignored='changed';assert(p:IsCurrent(),'ignored fields entered eligibility equality');value.level=12
 local ok,why=p:IsCurrent();assert(not ok and why=='rotation-context-changed','retained context alias bypassed frozen baseline')
end)
check('public override cannot assert freshness by returning true and nil holes remain first-result only',function()
 local c=make({target=false});local a=c.a;local value=context();local calls=0
 a.GetRotationContext=function(self,spec)assert(self==a and spec==0);calls=calls+1;return value,true,nil,'not authority'end
 local p=assert(a:AcquireRotationRuntimePass(0));assert(p:IsCurrent());value.level=12;local ok,why=p:IsCurrent();assert(not ok and why=='rotation-context-changed'and calls>=3)
end)
check('live and inherited ipairs preserve fresh projection callback at each check',function()
 for _,inherited in ipairs({false,true})do
  local c=make({target=false});local a,e=c.a,c.e;local calls=0;local native=ipairs
  local fn=function(t)if t[1]=='family'and t[7]=='combatDataPolicy'then calls=calls+1 end;return native(t)end
  -- The override is in place before the pass exists: a pass whose private context proof was taken with the native iterator
  -- cannot be checked again through a replaced one (it fails closed), so the public path is the one under test.
  if inherited then local mt=getmetatable(e);local old=mt and mt.__index;rawset(e,'ipairs',nil);setmetatable(e,{__index=function(t,k)if k=='ipairs'then return fn end;if type(old)=='function'then return old(t,k)elseif type(old)=='table'then return old[k]end end})else e.ipairs=fn end
  local p=assert(a:AcquireRotationRuntimePass(0));calls=0
  assert(p:IsCurrent());assert(p:IsCurrent());assert(calls==2,'fresh projection iterator callback skipped')
 end
end)
check('generic equality continues to detect a baseline escaped through live pairs',function()
 local c=make({target=false});local a,e=c.a,c.e;local p=assert(a:AcquireRotationRuntimePass(0));local baseline;local native=pairs
 e.pairs=function(t)if rawget(t,'family')=='tbc'and rawget(t,'actionContext')=='player'then baseline=baseline or t end;return native(t)end
 assert(p:IsCurrent());assert(baseline);e.pairs=native;baseline.level=-100;local ok,why=p:IsCurrent();assert(not ok and why=='rotation-context-changed')
end)
check('public client-info override cannot forge freshness for its retained mutable result',function()
 local c=make({target=false});local a=c.a;local value=context();local calls=0
 a.Platform.GetClientInfo=function(self)assert(self==a.Platform);calls=calls+1;return value,true end
 local p=assert(a:AcquireRotationRuntimePass(0));assert(p:IsCurrent());value.ignored='outside changed';assert(p:IsCurrent());value.family='different'
 local ok,why=p:IsCurrent();assert(not ok and why=='rotation-context-changed'and calls>=3)
end)
check('projection and dispatch environment overrides retain their existing callback path',function()
 for _,which in ipairs({'eligibilityContext','rotationContext'})do
  local c=make({target=false});local a=c.a;local p=assert(a:AcquireRotationRuntimePass(0));local helper=assert(up(p.IsCurrent,which));local env=getfenv(helper);local calls=0
  if which=='eligibilityContext'then setfenv(helper,setmetatable({ipairs=function(t)calls=calls+1;return ipairs(t)end},{__index=env}))
  else setfenv(helper,setmetatable({type=function(v)calls=calls+1;return type(v)end},{__index=env}))end
  -- A helper whose environment was replaced after the pass forfeits the private context proof: the pass fails closed, but the
  -- replaced environment is still the one the helper runs in.
  p:IsCurrent();assert(calls>0,'helper environment callbacks skipped')
 end
end)
check('owned fresh eligibility observations avoid a duplicate projection allocation without caching facts',function()
 local c=make({target=false});local a=c.a;local p=assert(a:AcquireRotationRuntimePass(0));local observe=assert(up(p.IsCurrent,'eligibilityContext'))
 local compiled=jit and jit.status();if jit then jit.off();jit.flush()end
 collectgarbage('collect');collectgarbage('stop');local before=collectgarbage('count')
 for i=1,256 do observe()end
 local gross=collectgarbage('count')-before;collectgarbage('restart');if compiled then jit.on()end
 assert(gross<200,'duplicate fresh eligibility projection allocates '..gross..'KiB')
 local state=11;c.e.UnitLevel=function()return state end
 local first=observe();state=12;local second=observe()
 assert(first~=second and first.level==11 and second.level==12,'fresh native observation retained or aliased')
end)
check('changed private context callback keeps exact receiver argument and thrown identity',function()
 local c=make({target=false});local a=c.a;local reader=assert(up(a:GetScopedRotationCoordinator().RuntimePass,'libraryReader'));local object={};local calls=0
 reader.Context=function(self,spec)assert(self==reader and spec==0);calls=calls+1;error(object,0)end
 local ok,why=pcall(a.AcquireRotationRuntimePass,a,0);assert(not ok and why==object and calls==1)
end)
check('strict source inverse retains prior full-module authority and rejects missing duplicate unrelated deltas',function()
 local inverse=dofile('tests/fixtures/restore_runtime_context_projection.lua')
 for _,path in ipairs({'Platform/client.lua','Core/rotation_library.lua','Core/rotation_scope.lua'})do
  local h=assert(io.open(path));local text=h:read('*a');h:close();local old=inverse(text,path)
  assert(old~=text and not pcall(inverse,old,path)and not pcall(inverse,text..text,path)and not pcall(inverse,text..'\n-- unrelated\n',path))
 end
end)
finish()
