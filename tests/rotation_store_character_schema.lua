-- Actual current Store/main; no replacement of gameplay/publication identities.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(p)local h=assert(io.open(p));local s=h:read('*a');h:close();return s end
local rawLoad=loadfile
local rawMake=dofile('tests/fixtures/rotation_execution.lua')
local function make(scope,target)
 do
  local c=rawMake({target=target,buttons=true});c.e.GetBuildInfo=function()return'2.5.5','12345'end
  local coordinator=assert(c.a:GetScopedRotationCoordinator());local ref=assert(coordinator:Resolve(0,c.a.currentRotation));assert(ref.address.scope=='class')
  if scope=='character'then local record,token=assert(c.a:GetRotationRecordSnapshot(0,ref));local moved=assert(c.a:CommitRotationDraft(ref,token,record,'character'));assert(moved.address.scope=='character'and coordinator:Resolve(0,c.a.currentRotation).address.scope=='character')end
  for i=1,5 do c.tick()end;return c
 end
end
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function withHook(fn,hook)
 local old,mask,count=debug.gethook();local compiling=jit and jit.status();if jit then jit.off();jit.flush()end
 debug.sethook(hook,'c');local ok,a,b=pcall(fn)
 if old then debug.sethook(old,mask,count)else debug.sethook()end;if compiling then jit.on()end;assert(ok,a);return a,b
end
local function allocations(c)
 local source=read('Data/rotation_store.lua');local line=0;local fieldLine
 for text in(source..'\n'):gmatch('(.-)\n')do line=line+1;if text:find('local function fields(',1,true)then fieldLine=line;break end end;assert(fieldLine)
 local seen={};local newMaps,calls,phase=0,0,'warm'
 local function hook(event)
  if event~='call'then return end;local i=debug.getinfo(2,'S');if i.source~='@Data/rotation_store.lua'or i.linedefined~=fieldLine then return end
  local _,allowed=debug.getlocal(2,2);if not rawget(allowed,'class')or not rawget(allowed,'specs')then return end
  assert(getmetatable(allowed)==nil);local count=0;for k,v in pairs(allowed)do assert((k=='class'or k=='specs')and v==true);count=count+1 end;assert(count==2)
  if phase=='measure'then calls=calls+1;if not seen[allowed]then newMaps=newMaps+1 end end;seen[allowed]=true
 end
 withHook(function()c.tick();phase='measure';c.tick()end,hook)
 return newMaps,calls
end
for _,target in ipairs({false,true})do
 test('character '..tostring(target)..' warm poll retains fresh bucket scans without per-poll allowlist tables',function()
  local c=make('character',target);local maps,calls=allocations(c);assert(calls==(target and 14 or 15),'character bucket scans per warm poll changed: '..calls)  -- 13/14 before the lean engine and the scope proofs (b55cca0e);assert(maps==0,'character allowlist allocated '..maps..' maps per poll')
 end)
end
test('class-scoped control has no character bucket scan or new allowlist map',function()
 for _,target in ipairs({false,true})do local c=make('class',target);local maps,calls=allocations(c);assert(maps==0 and calls==0)end
end)
local directSource=assert(read('tests/runtime_store_native_gate.lua'):match('^(.-)\ntest%('))
local direct=assert(loadstring(directSource..'\nreturn fixture','@character-schema-direct'))()
local function fixture(scope)return direct(scope)end
test('live bucket unknown keys wrong class and replaced specs still reject',function()
 do for _,mutation in ipairs({'extra','class','specs','meta'})do
  local f=fixture('character');assert(f.guard()==true);local bucket=f.state.characters[f.c.character]
  if mutation=='extra'then bucket.extra=true elseif mutation=='class'then bucket.class='MAGE'elseif mutation=='specs'then bucket.specs=f.data.CopyData(bucket.specs)else setmetatable(bucket,{})end
  assert(f.guard()==false and not f.reader:IsCurrent(f.seal,f.c),mutation)
 end end
end)
test('nested captured validator callbacks and managed writes retire the reader and guard',function()
 do
  local f=fixture('character');local entered=false;for i=#f.calls,1,-1 do f.calls[i]=nil end
  setmetatable(f.calls,{__newindex=function(t,k,v)rawset(t,k,v);if not entered then entered=true;assert(f.guard()==true);assert(f.store:Refresh())end end})
  assert(f.guard()==false and entered,'nested refresh did not retire old guard');assert(not f.reader:IsCurrent(f.seal,f.c))
  f=fixture('character');local value,token=assert(f.store:Get(f.a,f.c));value.body.name='Changed';assert(f.store:Commit(assert(f.store:PlanReplace(f.a,value,f.c,token)),f.c));assert(f.guard()==false and not f.reader:IsCurrent(f.seal,f.c))
 end
end)
finish()
