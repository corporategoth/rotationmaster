-- Historical policy regression before captured parser operations; current behavior
-- is exercised by parser_string_operations.lua and rotation_execution_index.lua.
-- Private proof is source-owned and pure under trusted standard-at-load natives.
-- Effectful replacement private installers are outside that existing boundary;
-- no assertion here claims equivalence for arbitrary substituted proof callbacks.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return dofile('tests/fixtures/parser_string_history.lua')(s,path) end
local restore=dofile('tests/fixtures/restore_index_unsupported_binding.lua')
local current=read('Data/rotation_tree.lua')
local baseline=current:find('    local reader=read\n',1,true) and restore(current) or current
local actualMeta=getmetatable('');local actualMethods=rawget(actualMeta,'__index');local protection=rawget(actualMeta,'__metatable')
assert(type(actualMeta)=='table'and type(actualMethods)=='table','host standard string metatable unavailable')
local function reset()rawset(actualMeta,'__metatable',protection);rawset(actualMeta,'__index',actualMethods)end
local function shape(kind)
 reset();if kind=='table'then return end
 if kind=='function'then rawset(actualMeta,'__index',function(_,key)return actualMethods[key]end)
 else local descriptor={};if kind=='false'then descriptor.__index=false elseif kind=='number'then descriptor.__index=17 end;rawset(actualMeta,'__metatable',descriptor)end
end
local function checked(name,body)test(name,function()local ok,why=pcall(body);reset();assert(ok,why)end)end
local function count(fn,callback)
 local n=0;local previous,mask,amount=debug.gethook();local compiling=jit and jit.status();if jit then jit.off();jit.flush()end
 debug.sethook(function(event)if event=='call'and debug.getinfo(2,'f').func==fn then n=n+1 end end,'c')
 local result={pcall(callback)};if previous then debug.sethook(previous,mask,amount)else debug.sethook()end;if compiling then jit.on()end
 assert(result[1],result[2]);return n
end
local function equal(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b);return end
 for key,value in pairs(a)do equal(value,b[key])end;for key in pairs(b)do assert(a[key]~=nil)end
end
local function unit(old)
 local e={};for k,v in pairs(_G)do e[k]=v end;e._G=e;local a={}
 local function load(path,text)local fn=assert(loadstring(text or read(path),'@'..path));setfenv(fn,e);fn('rotationmaster',a)end
 load('Data/plain.lua');local proof;a:BindRotationPortableReader(function(fn)proof=fn end)
 load('Data/rotation_tree.lua',old and baseline or current)
 local reader,retire,status;a:BindRotationExecutionIndexReader(function(r,x,s)reader,retire,status=r,x,s end)
 return {a=a,e=e,reader=reader,retire=retire,status=status,proof=proof,profile={},db={}}
end
local function invoke(c,body)return c.reader(body,c.profile,c.a.RotationData,c.db)end
local function body()return {rotation={{id='first',type='spell',action=403,conditions={}}}}end
checked('unsupported captured shapes bind denial without repeating doomed portable ownership checks',function()
 for _,kind in ipairs({'nil','false','number','function'})do
  shape(kind);local c=unit();local b=body()
  assert(count(c.proof,function()for i=1,3 do assert(invoke(c,b)==false)end end)==0,'unsupported binding repeated portable proof')
  reset();assert(count(c.proof,function()assert(invoke(c,b)==false)end)==0,'later string restoration changed captured capability')
 end
end)
local make=dofile('tests/fixtures/rotation_execution.lua')
local function main(old,target)
 local original=loadfile
 loadfile=function(path)
  if path=='Data/rotation_tree.lua'then return assert(loadstring(old and baseline or current,'@'..path))end
  if path=='Data/plain.lua'then return assert(loadstring(read(path)..'\naddon.__testPortableProof=portableOwned\n','@'..path))end
  return original(path)
 end
 local ok,c=pcall(make,{target=target});loadfile=original;assert(ok,c);return c
end
for _,target in ipairs({false,true})do checked('actual Shaman unsupported binding preserves queries advice and public fresh indexing target='..tostring(target),function()
 shape('nil');local old,new=main(true,target),main(false,target);old.reset(true);new.reset(true)
 local before=count(old.a.RotationData.IndexRotationSteps,function()for i=1,3 do old.tick()end end)
 local after=count(new.a.RotationData.IndexRotationSteps,function()for i=1,3 do new.tick()end end)
 assert(before==3 and after==3,'unsupported path stopped public fresh indexing')
 local oq,ot=old.snapshot();local nq,nt=new.snapshot();equal(oq,nq);equal(ot,nt);assert(old.a.currentSpell==new.a.currentSpell)
 local oldProof=count(old.a.__testPortableProof,function()for i=1,3 do old.tick()end end)
 local newProof=count(new.a.__testPortableProof,function()for i=1,3 do new.tick()end end)
 assert(oldProof==3 and newProof==0,'doomed private proof calls not removed')
end)end
checked('supported reader keeps proof count fresh metadata and current graph invalidation',function()
 shape('table');local traces={}
 for _,old in ipairs({true,false})do
  local c=unit(old);local b=body();local calls=count(c.proof,function()
   local ok,first=invoke(c,b);assert(ok and first.rows[1].step==b.rotation[1]);local _,second=invoke(c,b);assert(second~=first and second.rows~=first.rows and second.rows[1].path~=first.rows[1].path)
   b.rotation[1].id='changed';local _,third=invoke(c,b);assert(third.rows[1].step.id=='changed')
   c.retire();assert(invoke(c,b))
  end)
  traces[#traces+1]=calls
 end
 assert(traces[1]==traces[2]and traces[1]==7,'supported hotpath proof dispatch changed')
end)
checked('supported live method environment and primitive mutations retain original fallback and recovery',function()
 shape('table');for _,old in ipairs({true,false})do
  local c=unit(old);local b=body();assert(invoke(c,b));local native=c.a.RotationData.IndexRotationSteps
  c.a.RotationData.IndexRotationSteps=function()error('must only fall back outside private reader')end;assert(invoke(c,b)==false);c.a.RotationData.IndexRotationSteps=native;assert(invoke(c,b))
  local env=getfenv(native);setfenv(native,{});assert(invoke(c,b)==false);setfenv(native,env);assert(invoke(c,b))
  local kind=c.e.type;c.e.type=function(...)return kind(...)end;assert(invoke(c,b)==false);c.e.type=kind;assert(invoke(c,b))
 end
end)
checked('bound denial retains exact arity retire identity status and independent repeated bindings',function()
 shape('nil');local c=unit();local binder=c.a.BindRotationExecutionIndexReader
 setfenv(binder,setmetatable({},{__index=function()error('unexpected binder global lookup')end}))
 binder({},function()error('foreign owner received binding')end)
 for i=1,2 do binder(c.a,function(reader,retire,status)
  local actual;for n=1,10 do local name,value=debug.getupvalue(reader,n);if not name then break end;if name=='retire'then actual=value end end;assert(actual==retire,'denial used another retirement closure')
  for _,ns in ipairs({c.a.RotationData,{},false})do assert(select('#',reader(nil,nil,ns,nil))==1 and reader(nil,nil,ns,nil)==false);retire()end
  local result=status(c.a.RotationData);assert(result.index.reason=='string-index-table'and result.index.capturedIndex=='other')
 end)end
end)
checked('unsupported public helpers retain exact live override errors and fresh dispatch',function()
 shape('nil');local c=unit();local b=body();local original=c.a.RotationData.CheckPortable;local marker={};local calls=0
 c.a.RotationData.CheckPortable=function(...)assert(select('#',...)==1 and (...)==b);calls=calls+1;return false,marker end
 local result,why=c.a.RotationData.IndexRotationSteps(b);assert(result==nil and why==marker and calls==1)
 c.a.RotationData.CheckPortable=function()error(marker)end;local ok,why=pcall(c.a.RotationData.IndexRotationSteps,b);assert(not ok and why==marker)
 c.a.RotationData.CheckPortable=original;assert(c.a.RotationData.IndexRotationSteps(b))
end)
checked('strict binding inverse preserves the complete b135 tree including unchanged supported reader',function()
 assert(restore(current)==baseline);assert(not pcall(restore,baseline)and not pcall(restore,current..'\n'))
 local duplicate=current..'\n'..current;assert(not pcall(restore,duplicate))
end)
reset();finish()
