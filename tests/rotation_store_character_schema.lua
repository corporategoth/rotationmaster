-- Actual current Store/main; no replacement of gameplay/publication identities.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(p)local h=assert(io.open(p));local s=h:read('*a');h:close();return s end
local function hash(s)local n=5381;for i=1,#s do n=(n*33+s:byte(i))%4294967296 end;return string.format('%08x',n)end
local current=read('Data/rotation_store.lua')
local baseline=current
if current:find('local characterBucketFields=',1,true)then baseline=dofile('tests/fixtures/restore_rotation_store_character_schema.lua')(current,'Data/rotation_store.lua')end
assert(#baseline==40987 and hash(baseline)=='9d678565','wrong whole Store predecessor')
local rawLoad=loadfile
local rawMake=dofile('tests/fixtures/rotation_execution.lua')
local function arm(old,callback)
 local loaded
 loadfile=function(path,...)
  if path=='Data/rotation_store.lua'then local text=old and baseline or current;loaded=text;return assert(loadstring(text,'@'..path))end
  return rawLoad(path,...)
 end
 local ok,a,b=pcall(callback);loadfile=rawLoad;assert(ok,a);assert(loaded==(old and baseline or current),'wrong actual source arm');return a,b
end
local function make(scope,target,old)
 return arm(old,function()
  local c=rawMake({target=target,buttons=true});c.e.GetBuildInfo=function()return'2.5.5','12345'end
  local coordinator=assert(c.a:GetScopedRotationCoordinator());local ref=assert(coordinator:Resolve(0,c.a.currentRotation));assert(ref.address.scope=='class')
  if scope=='character'then local record,token=assert(c.a:GetRotationRecordSnapshot(0,ref));local moved=assert(c.a:CommitRotationDraft(ref,token,record,'character'));assert(moved.address.scope=='character'and coordinator:Resolve(0,c.a.currentRotation).address.scope=='character')end
  for i=1,5 do c.tick()end;return c
 end)
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
  local c=make('character',target);local maps,calls=allocations(c);assert(calls==(target and 13 or 14),'character guard route not exercised');assert(maps==0,'character allowlist allocated '..maps..' maps per poll')
 end)
end
test('class-scoped control has no character bucket scan or new allowlist map',function()
 for _,target in ipairs({false,true})do local c=make('class',target);local maps,calls=allocations(c);assert(maps==0 and calls==0)end
end)
test('distinct complete source arms preserve67 actual whole-poll native traces and advice in all four routes',function()
 assert(current~=baseline and current:find('local characterBucketFields=',1,true),'candidate actual source not loaded')
 for _,scope in ipairs({'class','character'})do for _,target in ipairs({false,true})do
  local a,b=make(scope,target,true),make(scope,target,false);a.reset(true);b.reset(true)
  for i=1,67 do a.tick();b.tick();assert(a.a.currentSpell==b.a.currentSpell and a.a.currentRotation==b.a.currentRotation and not a.a.adviceErrorReport and not b.a.adviceErrorReport);assert(equal(a.a.avail_announced,b.a.avail_announced)and equal(a.a.announced,b.a.announced)and equal(a.a.spellHistory,b.a.spellHistory)and equal(a.a.combatHistory,b.a.combatHistory)and equal(a.a.damageHistory,b.a.damageHistory))end
  local an,at=a.snapshot();local bn,bt=b.snapshot();assert(equal(an,bn)and equal(at,bt),'native count/order drift: '..scope..'/'..tostring(target))
 end end
end)
local directSource=assert(read('tests/runtime_store_native_gate.lua'):match('^(.-)\ntest%('))
local direct=assert(loadstring(directSource..'\nreturn fixture','@character-schema-direct'))()
local function fixture(old,scope)return arm(old,function()return direct(scope)end)end
test('live bucket unknown keys wrong class and replaced specs still reject both source arms',function()
 for _,old in ipairs({true,false})do for _,mutation in ipairs({'extra','class','specs','meta'})do
  local f=fixture(old,'character');assert(f.guard()==true);local bucket=f.state.characters[f.c.character]
  if mutation=='extra'then bucket.extra=true elseif mutation=='class'then bucket.class='MAGE'elseif mutation=='specs'then bucket.specs=f.data.CopyData(bucket.specs)else setmetatable(bucket,{})end
  assert(f.guard()==false and not f.reader:IsCurrent(f.seal,f.c),mutation)
 end end
end)
test('nested captured validator callbacks and managed writes retain reader and guard retirement parity',function()
 for _,old in ipairs({true,false})do
  local f=fixture(old,'character');local entered=false;for i=#f.calls,1,-1 do f.calls[i]=nil end
  setmetatable(f.calls,{__newindex=function(t,k,v)rawset(t,k,v);if not entered then entered=true;assert(f.guard()==true);assert(f.store:Refresh())end end})
  assert(f.guard()==false and entered,'nested refresh did not retire old guard');assert(not f.reader:IsCurrent(f.seal,f.c))
  f=fixture(old,'character');local value,token=assert(f.store:Get(f.a,f.c));value.body.name='Changed';assert(f.store:Commit(assert(f.store:PlanReplace(f.a,value,f.c,token)),f.c));assert(f.guard()==false and not f.reader:IsCurrent(f.seal,f.c))
 end
end)
test('live primitive callback traces arguments mutations and thrown objects agree without allowlist escape',function()
 local nativeType,nativePairs,nativeMeta=type,pairs,getmetatable
 local poison={}
 local function observe(old,scope,mutation)
  local data=dofile('tests/fixtures/rotation_data.lua')();local active=false;local trace={};local allowlistEscaped=false
  local state={version=1,classes={SHAMAN={[0]={chosen={body={name='Chosen',switch={},rotation={},cooldowns={}}}}}},characters={['A - Realm']={class='SHAMAN',specs={[0]={chosen={body={name='Chosen',switch={},rotation={},cooldowns={}}}}}}},legacy={}}
  local c={class='SHAMAN',character='A - Realm'};local a={scope=scope,class='SHAMAN',owner=scope=='class'and'SHAMAN'or c.character,spec=0,id='chosen'}
  local watched=scope=='class'and state or state.characters[c.character]
  local function label(v)
   if nativeType(v)~='table'then return nativeType(v)..':'..tostring(v)end
   if rawget(v,'class')==true and rawget(v,'specs')==true then allowlistEscaped=true end
   if v==state then return'state'elseif v==c then return'context'elseif v==watched then return'bucket'end
   if rawget(v,'scope')then return'address'elseif rawget(v,'class')and rawget(v,'character')then return'context'end;return'table'
  end
  local function hit(kind,v)
   if not active then return end;trace[#trace+1]=kind..':'..label(v)
   if kind=='pairs'and v==watched then if mutation=='extra'then watched.extra=true elseif mutation=='throw'then error(poison,0)end end
  end
  local env=setmetatable({type=function(v)hit('type',v);return nativeType(v)end,pairs=function(v)hit('pairs',v);return nativePairs(v)end,getmetatable=function(v)hit('meta',v);return nativeMeta(v)end},{__index=_G})
  local class=data.IsRotationClassToken;data.IsRotationClassToken=function(v)hit('class',v);return class(v)end
  local chunk=assert(loadstring(old and baseline or current,'@Data/rotation_store.lua'));setfenv(chunk,env);chunk('rotationmaster',{RotationData=data})
  local reader;local store,why,makeGuard=data.NewRotationStore({state=state,fallbackID='Default',bindInternalReader=function(value)reader=value end});assert(store,why)
  local ok,_,seal=reader:Read(a,c,function()return true end);assert(ok);local guard=assert(makeGuard(reader,seal,c));active=true
  local success,value=pcall(guard);active=false;assert(not allowlistEscaped,'private schema passed to an ordinary callback')
  if mutation=='throw'then assert(not success and rawequal(value,poison),'original callback error changed')elseif mutation=='extra'then assert(success and value==false)else assert(success and value==true)end
  return trace
 end
 for _,scope in ipairs({'class','character'})do for _,mutation in ipairs({'steady','extra','throw'})do assert(equal(observe(true,scope,mutation),observe(false,scope,mutation)),scope..'/'..mutation)end end
end)
test('strict inverse restores the complete predecessor and rejects old duplicate missing unrelated inputs',function()
 local restore=dofile('tests/fixtures/restore_rotation_store_character_schema.lua');assert(restore(current,'Data/rotation_store.lua')==baseline)
 assert(not pcall(restore,baseline,'Data/rotation_store.lua'))
 assert(not pcall(restore,current..'\n-- unrelated','Data/rotation_store.lua'))
 local declaration='local characterBucketFields={class=true,specs=true}\n';local a,b=assert(current:find(declaration,1,true));assert(not pcall(restore,current:sub(1,a-1)..current:sub(b+1),'Data/rotation_store.lua'));assert(not pcall(restore,current:sub(1,b)..declaration..current:sub(b+1),'Data/rotation_store.lua'))
end)
finish()
