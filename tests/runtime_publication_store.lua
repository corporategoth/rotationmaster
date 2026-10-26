local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local rawMake=dofile('tests/fixtures/rotation_execution.lua')
local function make(options)local c=rawMake(options or {target=true,buttons=true});c.e.GetBuildInfo=function()return '2.5.5','12345'end;return c end
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function up(fn,key,seen)
 seen=seen or {};if seen[fn]then return end;seen[fn]=true
 for i=1,120 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==key then return v end end
 for i=1,120 do local k,v=debug.getupvalue(fn,i);if not k then break end;if type(v)=='function'then local r=up(v,key,seen);if r~=nil then return r end end end
end
local function currentPass()
 for level=2,30 do if not debug.getinfo(level)then break end
  for i=1,100 do local name,value=debug.getlocal(level,i);if not name then break end;if name=='runtimePass'and type(value)=='table'then return value end end
 end
end
local function mutate(c,fn)
 local a=c.a;local get=a.GetSpellIds;local changed=false
 a.GetSpellIds=function(self,...)
  local ids,items=get(self,...);if not changed then changed=true;fn(a)end;return ids,items
 end
 a.currentSpell=nil;c.tick();assert(changed,'action provider not exercised');return a.currentSpell
end
local function selected(a)
 local ref=assert(a:GetScopedRotationCoordinator():Resolve(0,a.currentRotation));local address=ref.address
 return a.db.profile.rotationStore.classes[address.class][address.spec][address.id],ref
end
local function withConstructor(fn)
 local original=loadfile;local injected=0
 loadfile=function(path,...)
  local chunk=original(path,...);if path~='Core/rotation_scope.lua'then return chunk end
  return function(name,addon)
   local construct=addon.RotationData.NewRotationStore
   addon.RotationData.NewRotationStore=function(options)
    local bind=options.bindInternalReader
    options.bindInternalReader=function(reader)
     reader.PublicationGuard=function()injected=injected+1;error('custom guard field must stay ignored')end
     bind(reader)
    end
    return construct(options)
   end
   setfenv(chunk,getfenv(1));return chunk(name,addon)
  end
 end
 local ok,c=pcall(make);loadfile=original;assert(ok,c);fn(c);assert(injected==0,'custom constructor injected an owned guard')
end

test('owned main publication retains three full record checks per invocation',function()
 local c=make();local line=0;local wanted
 for text in(read('Data/rotation_store.lua')..'\n'):gmatch('(.-)\n')do line=line+1;if text:find('function reader:IsCurrent(',1,true)then wanted=line;break end end;assert(wanted)
 -- Count interpreted calls; an existing JIT trace may bypass call hooks.
 local compiling=jit and jit.status();if jit then jit.off();jit.flush()end
 local ok,why=pcall(function()
  for invocation=1,2 do
   local n=0;debug.sethook(function()local info=debug.getinfo(2,'S');if info.source=='@Data/rotation_store.lua'and info.linedefined==wanted then n=n+1 end end,'c')
   c.tick();debug.sethook();assert(not c.a.adviceErrorReport);assert(n==3,'full selected-record checks repeated during publication: '..n)
  end
 end)
 debug.sethook();if compiling then jit.on()end;assert(ok,why)
end)
test('raw selected body root and unexpected record field suppress already staged advice',function()
 for _,kind in ipairs({'body','field'})do local c=make();local result=mutate(c,function(a)local record=selected(a);if kind=='body'then record.body=a.RotationData.CopyData(record.body)else record.extra=true end end)
  assert(result==nil and not c.a.adviceErrorReport,kind)
 end
end)
test('managed selected replacement and first mutable exposure suppress stale advice',function()
 for _,kind in ipairs({'replace','first-exposure'})do local c=make();local result=mutate(c,function(a)
  if kind=='first-exposure'then assert(a:GetEditableRotation(0,a.currentRotation))
  else local _,ref=selected(a);local value,token=a:GetRotationRecordSnapshot(0,ref);value.body.description='Managed replacement';assert(a:CommitRotationDraft(ref,token,value))end
 end);assert(result==nil and not c.a.adviceErrorReport,kind)end
end)
test('previous editable and public runtime body exposure retains full content watcher',function()
 for _,method in ipairs({'GetEditableRotation','GetRuntimeRotation'})do local c=make();local a=c.a;local body=assert(a[method](a,0,a.currentRotation))
  assert(mutate(c,function()body.description='Mutable exposed value'end)==nil and not a.adviceErrorReport,method)
 end
end)
test('public acquisition override retains its full pass method calls',function()
 local c=make();local a=c.a;local acquire=a.AcquireRotationRuntimePass;local calls=0
 a.AcquireRotationRuntimePass=function(self,...)local p=assert(acquire(self,...));local current=p.IsCurrent;p.IsCurrent=function(...)calls=calls+1;return current(...)end;return p end
 c.tick();assert(not a.adviceErrorReport and a.currentSpell==403 and calls>=10,'public pass hook was bypassed')
end)
test('mutable owned pass IsCurrent replacement remains the publication authority',function()
 for _,throws in ipairs({false,true})do
  local c=make();local calls=0;local spell=mutate(c,function()local p=assert(currentPass());p.IsCurrent=function()calls=calls+1;if throws then error('custom pass failure')end;return nil,'custom retirement'end end)
  -- The replaced method is consulted at each publication fence (b55cca0e added the cheap continuation, so more than once).
  assert(spell==nil and calls>=1 and (not not c.a.adviceErrorReport)==throws,'owned guard bypassed replaced public method')
 end
end)
test('owned pass function environment replacement retains its throwing public route',function()
 local c=make();local calls=0;local current,previous
 local spell=mutate(c,function()
  current=assert(currentPass()).IsCurrent;previous=getfenv(current)
  setfenv(current,setmetatable({pairs=function()calls=calls+1;error('custom pass environment')end},{__index=previous}))
 end)
 setfenv(current,previous);assert(spell==nil and calls==1 and c.a.adviceErrorReport,'private guard bypassed public pass environment')
end)
test('constructor wrapper installed before Scope load ignores unrelated guard extension',function()
 local normal=make();normal.reset();normal.tick();local wanted=normal.snapshot().UnitClass
 withConstructor(function(c)
  c.reset();c.tick();assert(c.snapshot().UnitClass==wanted,'custom constructor duplicated base observations')
  assert(mutate(c,function(a)local record=selected(a);record.body=a.RotationData.CopyData(record.body)end)==nil and not c.a.adviceErrorReport)
 end)
end)
test('constructor wrapper installed after binding stays full when explicitly rebound',function()
 local c=make();local a=c.a;local construct=a.RotationData.NewRotationStore;local injected=0
 local wrapped=function(options)
  local bind=options.bindInternalReader
  options.bindInternalReader=function(reader)reader.PublicationGuard=function()injected=injected+1;return function()return true end end;bind(reader)end
  return construct(options)
 end
 setfenv(wrapped,getfenv(construct));a.RotationData.NewRotationStore=wrapped
 assert(a:BindRotationProfile());assert(mutate(c,function(owner)local record=selected(owner);record.body=owner.RotationData.CopyData(record.body)end)==nil)
 assert(injected==0 and not a.adviceErrorReport,'rebound custom constructor injected a guard')
end)
test('captured class validator still rejects a changed environment after public replacement',function()
 local c=make();local a=c.a;local validator=assert(up(a.RotationData.NewRotationStore,'isClass'));local previous=getfenv(validator);local public=a.RotationData.IsRotationClassToken
 local ok,why=pcall(function()
  local spell=mutate(c,function()
   a.RotationData.IsRotationClassToken=function(v)return v=='SHAMAN'end
   setfenv(validator,setmetatable({type=function()return 'invalid'end},{__index=previous}))
  end)
  assert(spell==nil and not a.adviceErrorReport,'captured validator decision omitted')
 end)
 setfenv(validator,previous);a.RotationData.IsRotationClassToken=public;assert(ok,why)
end)
test('retained class validator Refresh callbacks retire before publication witnesses',function()
 local c=make();local a=c.a;local validator=assert(up(a.RotationData.NewRotationStore,'isClass'));local previous=getfenv(validator);local public=a.RotationData.IsRotationClassToken;local changed=false
 local store=assert(up(a:GetScopedRotationCoordinator().StoredRecords,'store'))
 local ok,why=pcall(function()
  local spell=mutate(c,function()
   a.RotationData.IsRotationClassToken=function(v)return v=='SHAMAN'end
   setfenv(validator,setmetatable({type=function(value)
    if value=='SHAMAN'and not changed then changed=true;assert(store:Refresh())end
    return previous.type(value)
   end},{__index=previous}))
  end)
  assert(changed and spell==nil and not a.adviceErrorReport,'validator Refresh invalidated an already checked reader epoch')
 end)
 setfenv(validator,previous);a.RotationData.IsRotationClassToken=public;assert(ok,why)
end)
test('actual string index find and index replacements retain current validation',function()
 for _,kind in ipairs({'find','index-table','index-function'})do
  local c=make();local a=c.a;local owner=a.GetRotationOwnerContext;local held=assert(owner(a));a.GetRotationOwnerContext=function()return held end
  local meta=assert(getmetatable(''));local index=assert(rawget(meta,'__index'));assert(type(index)=='table');local find=assert(rawget(index,'find'))
  local ok,why=pcall(function()
   local spell=mutate(c,function()
    local refuse=function()return nil end
    if kind=='find'then
     -- A decoy global string alias must not hide the actual retained index.
     local decoy={};for k,v in pairs(c.e.string)do decoy[k]=v end;c.e.string=decoy;rawset(index,'find',refuse)
    elseif kind=='index-table'then local nextIndex={};for k,v in pairs(index)do nextIndex[k]=v end;nextIndex.find=refuse;rawset(meta,'__index',nextIndex)
    else rawset(meta,'__index',function(_,key)if key=='find'then return refuse end;return rawget(index,key)end)end
   end)
   assert(spell==nil and not a.adviceErrorReport,'actual string consumer decision omitted: '..kind)
  end)
  rawset(meta,'__index',index);rawset(index,'find',find);a.GetRotationOwnerContext=owner;assert(ok,why)
 end
end)
local function transportInjection(restored)
 local original=loadfile;local injections,guards=0,0
 loadfile=function(path,...)
  local chunk=original(path,...);if path~='Core/rotation_scope.lua'then return chunk end
  return function(...)
   local env=getfenv(1);local protected=env.pcall
   env.pcall=function(fn,...)
    local reader=...
    if type(reader)=='table'and type(reader.Read)=='function'and type(reader.IsCurrent)=='function'then
     injections=injections+1;if restored then env.pcall=protected end
     reader.PublicationGuard=function()guards=guards+1;return function()return true end end
    end
    return protected(fn,...)
   end
   setfenv(chunk,env);return chunk(...)
  end
 end
 local ok,c=pcall(make);loadfile=original;assert(ok,c)
 local spell=mutate(c,function(a)local record=selected(a);record.body=a.RotationData.CopyData(record.body)end)
 assert(injections>0,'control never observed internal reader binding')
 assert(spell==nil and guards==0 and not c.a.adviceErrorReport,'callback transport injected a guard and published a stale body root')
end
test('callback transport cannot inject a selected publication guard',function()transportInjection(false)end)
test('callback transport restored before constructor return cannot inject a guard',function()transportInjection(true)end)
test('captured class validator rebind after Glow suppresses the next message',function()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function once(s,a,b)local x,y=assert(s:find(a,1,true));assert(not s:find(a,y+1,true));return s:sub(1,x-1)..b..s:sub(y+1)end
local source=read('tests/fixtures/rotation_execution.lua')
local anchor="local makePersistent=assert(loadstring(common..'\\n'..persistent..'\\nreturn persistentFixture','@external-toc-ordered-runtime'))()"
source=once(source,anchor,"persistent=once(persistent,\"load('Core/rotation_library.lua')\",\"load('Platform/rotation_owner.lua');load('Core/rotation_library.lua')\")\n"..anchor)
source=once(source,"'Platform/rotation_owner.lua',",'')
local factory=assert(loadstring(source,'@external-store-ordering-fixture'))()
local armed,mutated,originalClass,a=false,false
local baseLoad=loadfile
loadfile=function(path,...)
 local chunk=baseLoad(path,...)
 if path~='Data/rotation_store.lua' then return chunk end
 return function(name,addon)
  originalClass=addon.RotationData.IsRotationClassToken
  addon.RotationData.IsRotationClassToken=function(value)
   if armed then
    armed=false;mutated=true
    assert(a:BindRotationProfile(),'callback rebind failed')
   end
   return originalClass(value)
  end
  setfenv(chunk,getfenv(1));return chunk(name,addon)
 end
end
local ok,c=pcall(factory,{target=true,buttons=true});loadfile=baseLoad;assert(ok,c);a=c.a
-- Keep only Data's captured callback; public owner validation stays source-normal.
a.RotationData.IsRotationClassToken=originalClass
c.e.GetBuildInfo=function()return '2.5.5','12345'end
c.load('profiler.lua');a.evaluationProfile=a:ProfiledCode()
local now=100;c.e.GetTime=function()return now end
for i=1,32 do now=now+.15;a:EvaluateNextAction()end
a.lastCacheReport=now;assert(not a.adviceErrorReport)
local messages=0;local sawGlow=false
c.e.LibStub('AceEvent-3.0').SendMessage=function(_,name)if sawGlow and name=='ROTATIONMASTER_SPELL_UPDATE'then messages=messages+1 end end
a.IsGlowing=function()return false end
a.GlowNextSpell=function()
 local owned=false
 for depth=2,32 do if not debug.getinfo(depth)then break end;for i=1,140 do local key,value=debug.getlocal(depth,i);if not key then break end;if key=='publicationGuard'and type(value)=='function'then owned=true end end end
 assert(owned,'control did not enter private publication route')
 sawGlow=true;armed=true
end
now=now+.15;a:EvaluateNextAction()
assert(sawGlow and mutated,'retained captured validator control did not execute')
assert(messages==0,'retired read published after callback rebind')
assert(not a.adviceErrorReport,'callback rebind raised advice error')
end)
finish()
