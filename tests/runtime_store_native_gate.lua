-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local nativeMeta,nativeType=getmetatable,type
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function up(fn,key,seen)
 seen=seen or {};if seen[fn]then return end;seen[fn]=true
 for i=1,120 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==key then return v end end
 for i=1,120 do local k,v=debug.getupvalue(fn,i);if not k then break end;if type(v)=='function'then local r=up(v,key,seen);if r~=nil then return r end end end
end
local function fixture(scope)
 local data=dofile('tests/fixtures/rotation_data.lua')();local calls={};local originalClass=data.IsRotationClassToken
 data.IsRotationClassToken=function(value)calls[#calls+1]=value;return originalClass(value)end
 local hidden={};local env=setmetatable({getmetatable=function(value)if nativeType(value)=='string'then return hidden end;return nativeMeta(value)end},{__index=_G})
 local chunk=assert(loadfile('Data/rotation_store.lua'));setfenv(chunk,env);chunk('rotationmaster',{RotationData=data})
 local body={name='Chosen',switch={},rotation={{id='step',type='spell',action=403,conditions={}}},cooldowns={}}
 local state={version=1,classes={SHAMAN={[0]={chosen={body=body}}}},characters={['A - Realm']={class='SHAMAN',specs={[0]={chosen={body=data.CopyData(body)}}}}},legacy={}}
 local c={class='SHAMAN',character='A - Realm'};local a={scope=scope or'class',class='SHAMAN',owner=scope=='character'and c.character or c.class,spec=0,id='chosen'}
 local reader;local store,why,makeGuard=data.NewRotationStore({state=state,fallbackID='Default',bindInternalReader=function(r)reader=r end});assert(store,why)
 local ok,_,seal=reader:Read(a,c,function()return true end);assert(ok)
 return {data=data,state=state,c=c,a=a,reader=reader,store=store,guard=assert(makeGuard(reader,seal,c)),seal=seal,env=env,hidden=hidden,calls=calls}
end
local rawMake=dofile('tests/fixtures/rotation_execution.lua')
local function actual(target,hidden)
 local original=loadfile
 if hidden then loadfile=function(path,...)
  local chunk=original(path,...);if path~='Data/rotation_store.lua'then return chunk end
  return function(...)
   local env=getfenv(1);local meta=env.getmetatable;local view={}
   local storeEnv=setmetatable({getmetatable=function(value)if nativeType(value)=='string'then return view end;return meta(value)end},{__index=env})
   setfenv(chunk,storeEnv);return chunk(...)
  end
 end end
 local ok,c=pcall(rawMake,{target=target,buttons=true});loadfile=original;assert(ok,c)
 c.e.GetBuildInfo=function()return'2.5.5','12345'end;return c
end
local function fullChecks(c)
 local line,wanted=0
 for s in(read('Data/rotation_store.lua')..'\n'):gmatch('(.-)\n')do line=line+1;if s:find('function reader:IsCurrent(',1,true)then wanted=line;break end end
 local compiling=jit and jit.status();if jit then jit.off();jit.flush()end
 local n=0;debug.sethook(function()local i=debug.getinfo(2,'S');if i.source=='@Data/rotation_store.lua'and i.linedefined==wanted then n=n+1 end end,'c')
 local ok,why=pcall(c.tick);debug.sethook();if compiling then jit.on()end;assert(ok,why);assert(not c.a.adviceErrorReport);return n
end
local function same(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end

test('hidden native string metatable admits the private class and character guard',function()
 for _,scope in ipairs({'class','character'})do local f=fixture(scope)
  assert(f.env.getmetatable('')==f.hidden and rawget(f.hidden,'__index')==nil)
  assert(f.guard()==true,'hidden native metatable forced full selected-store fallback: '..scope)
 end
end)
test('fresh context and address validators match full reader scalar callback ordering',function()
 for _,scope in ipairs({'class','character'})do local f=fixture(scope)
  for i=#f.calls,1,-1 do f.calls[i]=nil end;assert(f.reader:IsCurrent(f.seal,f.c));local baseline=table.concat(f.calls,',')
  for i=#f.calls,1,-1 do f.calls[i]=nil end;assert(f.guard()==true);assert(table.concat(f.calls,',')==baseline,'validator callbacks omitted or reordered')
 end
end)
test('actual whole poll uses three full read checks under hidden native metadata',function()
 for _,target in ipairs({false,true})do local c=actual(target,true);assert(fullChecks(c)==3,'private native-shaped route was not taken')end
end)
test('public reader method replacement invalidates the lane rather than proving it by omission',function()
 local f=fixture();local current=f.reader.IsCurrent;local calls=0
 f.reader.IsCurrent=function(...)calls=calls+1;return current(...)end
 assert(f.guard()==nil and calls==0);assert(f.reader:IsCurrent(f.seal,f.c)and calls==1)
end)
test('retired not-ready and stale-epoch admission preserve skipped validation callbacks',function()
 for _,kind in ipairs({'retired','not-ready','epoch'})do local f=fixture()
  if kind=='retired'then f.reader:Retire()elseif kind=='epoch'then assert(f.store:Refresh())
  else local found=false;for i=1,120 do local k=debug.getupvalue(f.guard,i);if not k then break end;if k=='readerState'then debug.setupvalue(f.guard,i,'binding');found=true;break end end;assert(found)end
  for i=#f.calls,1,-1 do f.calls[i]=nil end;assert(not f.reader:IsCurrent(f.seal,f.c));local expected=#f.calls
  assert(expected==(kind=='epoch'and 1 or 0),'full-reader order changed')
  for i=#f.calls,1,-1 do f.calls[i]=nil end
  local poison={};setmetatable(f.calls,{__newindex=function(t,k,v)if k>expected then error(poison,0)end;rawset(t,k,v)end})
  local ok,value=pcall(f.guard);assert(ok and value==false and #f.calls==expected,'private admission invoked callbacks skipped by full reader: '..kind)
 end
end)
test('raw structural and header mutations still retire class and character records',function()
 local mutations={function(f)f.state.version=2 end,function(f)f.state.classes=f.data.CopyData(f.state.classes)end,
  function(f)local root=f.a.scope=='class'and f.state.classes or f.state.characters;root[f.a.owner]=f.data.CopyData(root[f.a.owner])end,
  function(f)local root=f.a.scope=='class'and f.state.classes or f.state.characters;local map=f.a.scope=='class'and root[f.a.owner]or root[f.a.owner].specs;map[0]=f.data.CopyData(map[0])end,
  function(f)local root=f.a.scope=='class'and f.state.classes or f.state.characters;local map=f.a.scope=='class'and root[f.a.owner]or root[f.a.owner].specs;map[0].chosen.body=f.data.CopyData(map[0].chosen.body)end,
  function(f)local root=f.a.scope=='class'and f.state.classes or f.state.characters;local map=f.a.scope=='class'and root[f.a.owner]or root[f.a.owner].specs;map[0].chosen.extra=true end}
 for _,scope in ipairs({'class','character'})do for _,mutate in ipairs(mutations)do local f=fixture(scope);mutate(f);assert(f.guard()==false and not f.reader:IsCurrent(f.seal,f.c))end end
end)
test('managed replace delete refresh and retirement invalidate the private lane',function()
 for _,kind in ipairs({'replace','delete','refresh','retire'})do local f=fixture()
  if kind=='refresh'then assert(f.store:Refresh())elseif kind=='retire'then f.reader:Retire()
  else local value,token=assert(f.store:Get(f.a,f.c));local plan
   if kind=='replace'then value.body.name='Changed';plan=assert(f.store:PlanReplace(f.a,value,f.c,token))else plan=assert(f.store:PlanDelete(f.a,f.c,token))end
   assert(f.store:Commit(plan,f.c))
  end
  assert(f.guard()==false and not f.reader:IsCurrent(f.seal,f.c),kind)
 end
end)
test('receiver-sensitive string find is evaluated for actual address and character values',function()
 local meta=assert(nativeMeta(''));local index=assert(rawget(meta,'__index'));local old=assert(rawget(index,'find'))
 for _,refused in ipairs({'chosen','A - Realm'})do local f=fixture();local ok,why=pcall(function()
  rawset(index,'find',function(receiver,pattern,...)if receiver==refused then return nil end;return old(receiver,pattern,...)end)
  assert(f.guard()==false and not f.reader:IsCurrent(f.seal,f.c),'actual string receiver was not validated')
 end);rawset(index,'find',old);assert(ok,why)end
end)
test('validator reentry happens before final reader and raw state witnesses',function()
 for _,kind in ipairs({'refresh','body'})do for phase=1,3 do local f=fixture();local isClass=assert(up(f.guard,'originalClass'));local env=getfenv(isClass);local fired=false;local calls=0
  setfenv(isClass,setmetatable({type=function(v)if v=='SHAMAN'then calls=calls+1 end;if not fired and calls==phase then fired=true;if kind=='refresh'then assert(f.store:Refresh())else f.state.classes.SHAMAN[0].chosen.body=f.data.CopyData(f.state.classes.SHAMAN[0].chosen.body)end end;return env.type(v)end},{__index=env}))
  local ok,value=pcall(f.guard);setfenv(isClass,env);assert(ok and fired and value==false,kind)
 end end
end)
test('fresh receiver validation preserves thrown object identity',function()
 local f=fixture();local object={};local meta=assert(nativeMeta(''));local index=assert(rawget(meta,'__index'));local old=assert(rawget(index,'find'))
 rawset(index,'find',function(receiver,pattern,...)if receiver=='chosen'then error(object,0)end;return old(receiver,pattern,...)end)
 local ok,value=pcall(f.guard);local readerOK,readerValue=pcall(f.reader.IsCurrent,f.reader,f.seal,f.c);rawset(index,'find',old)
 assert(not ok and value==object and not readerOK and readerValue==object)
end)
test('changed primitive dispatch retains the public-reader fallback',function()
 for _,name in ipairs({'type','pairs','getmetatable','rawget'})do local f=fixture();local original=f.env[name]
  f.env[name]=function(...)return original(...)end;assert(f.guard()==nil and f.reader:IsCurrent(f.seal,f.c),name)
 end
end)
test('fresh context and private address shape remain fully validated',function()
 local cases={function(f)f.c.character=''end,function(f)f.c.class='MAGE'end,function(f)f.a.extra=true end,
  function(f)f.a.id=''end,function(f)f.a.spec=0/0 end,function(f)f.a.owner='Other'end}
 for index,change in ipairs(cases)do local f=fixture();f.a=assert(up(f.guard,'a'));change(f);assert(f.guard()==false and not f.reader:IsCurrent(f.seal,f.c),'private shape case '..index)end
end)
test('hidden and ordinary metadata retain actual native query and advice traces',function()
 for _,target in ipairs({false,true})do local a,b=actual(target,false),actual(target,true)
  a.reset(true);b.reset(true);local left,right={},{}
  for i=1,3 do a.tick();b.tick();left[i]={a.a.currentSpell,a.a.currentRotation};right[i]={b.a.currentSpell,b.a.currentRotation}end
  local ac,at=a.snapshot();local bc,bt=b.snapshot();assert(same(ac,bc)and same(at,bt)and same(left,right),'query/order/advice trace differs')
 end
end)
finish()
