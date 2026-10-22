-- Actual Store data and the private executor issuer; public guards stay eager.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local prefix=assert(read('tests/rotation_store_reader.lua'):match('^(.-)\ntest%('))
local model,state,address,ctx,record=assert(loadstring(prefix..'\nreturn model,state,address,ctx,record','@execution-store-fixture'))()
local function fixture(kind)
 local data=model();local s=state();local reader
 local service,why,public,execution=data.NewRotationStore({state=s,fallbackID='Default',bindInternalReader=function(r)reader=r end});assert(service,why)
 assert(type(execution)=='function','private execution guard issuer missing')
 local a=address(kind,kind=='character'and ctx.character or nil)
 local ok,_,seal=reader:Read(a,ctx,function(r)return r.body.name end);assert(ok)
 local notices=0;local fast=assert(execution(reader,seal,ctx,function()notices=notices+1 end));local eager=assert(public(reader,seal,ctx))
 assert(fast()and eager());return service,reader,s,a,fast,eager,data,function()return notices end,execution,seal
end
local function find(fn,name,seen)
 if type(fn)~='function'then return end;seen=seen or{};if seen[fn]then return end;seen[fn]=true
 for i=1,100 do local n,v=debug.getupvalue(fn,i);if not n then break end;if n==name then return v end end
 for i=1,100 do local n,v=debug.getupvalue(fn,i);if not n then break end;local got=find(v,name,seen);if got then return got end end
end
local function count(run)
 local calls={};local old,mask,n=debug.gethook();local enabled=jit and jit.status();if jit then jit.off();jit.flush()end
 debug.sethook(function(event)if event=='call'then local fn=debug.getinfo(2,'f').func;calls[fn]=(calls[fn]or 0)+1 end end,'c')
 local ok,why=pcall(run);debug.sethook(old,mask,n);if enabled then jit.on()end;assert(ok,why);return calls
end

test('warm private execution fences do not repeat schema address or visibility validation',function()
 for _,kind in ipairs({'class','character'})do
  local _,_,_,_,fast,eager=fixture(kind);local calls=count(function()for i=1,20 do assert(fast())end end)
  for _,name in ipairs({'plain','fields','validAddress','privateContext','sameContext','visible'})do
   local fn=assert(find(eager,name),name);assert(not calls[fn],'execution fence repeated '..name)
  end
 end
end)
test('irrelevant added metadata stays outside private execution while public schema checks remain',function()
 local _,_,s,a,fast,eager=fixture();s.unusedMetadata=true;s.classes[a.owner][a.spec][a.id].unusedMetadata=true
 assert(fast(),'unconsumed metadata invalidated the admitted execution');assert(not eager(),'public full schema validation changed')
end)
test('private issuer still rejects an invalid schema before admitting an execution lease',function()
 local _,reader,s,_,_,_,_,_,issuer,seal=fixture();s.unexpected=true
 assert(not issuer(reader,seal,ctx),'invalid cold schema admitted')
end)
test('relevant raw roots records components version and table metatables retire private fences',function()
 for _,kind in ipairs({'class','character'})do
  for _,change in ipairs({'classes','characters','legacy','bucket','specs','rows','record','body','origin','imported','comparison','version','state-meta','root-meta','bucket-meta','rows-meta','record-meta','body-meta','context'})do
   local _,_,s,a,fast=fixture(kind);local root=kind=='class'and s.classes or s.characters;local bucket=root[a.owner];local map=kind=='class'and bucket or bucket.specs;local rows=map[a.spec];local r=rows[a.id]
   if change=='classes'or change=='characters'or change=='legacy'then s[change]={}
   elseif change=='bucket'then root[a.owner]={}
   elseif change=='specs'then if kind=='character'then bucket.specs={}else map[a.spec]={}end
   elseif change=='rows'then map[a.spec]={}
   elseif change=='record'then rows[a.id]={body=r.body}
   elseif change=='version'then s.version=2
   elseif change=='state-meta'then setmetatable(s,{})
   elseif change=='root-meta'then setmetatable(root,{})
   elseif change=='bucket-meta'then setmetatable(bucket,{})
   elseif change=='rows-meta'then setmetatable(rows,{})
   elseif change=='record-meta'then setmetatable(r,{})
   elseif change=='body-meta'then setmetatable(r.body,{})
   elseif change=='context'then local old=ctx.character;ctx.character='Other';assert(not fast());ctx.character=old
   else r[change]={}end
   if change~='context'then assert(not fast(),kind..'/'..change..' survived')end
  end
 end
end)
test('managed selected writes notify and retire while unrelated writes preserve private execution',function()
 local service,_,_,a,fast,_,_,notices=fixture();local other=address('class','MAGE','other','MAGE');local c={class='MAGE',character='Other'}
 assert(not service:Commit({},ctx));assert(service:Commit(assert(service:PlanCreate(other,record('Other'),c)),c));assert(fast()and notices()==0)
 local snapshot,token=service:Get(a,ctx);snapshot.body.name='Updated';assert(service:Commit(assert(service:PlanReplace(a,snapshot,ctx,token)),ctx))
 assert(not fast()and notices()==1)
end)
test('retained class validator environment changes cannot authorize private execution',function()
 local _,_,_,_,fast,_,data=fixture();local validator=assert(find(data.NewRotationStore,'isClass'));local env=getfenv(validator)
 setfenv(validator,setmetatable({type=function()return'invalid'end},{__index=env}));local result=fast();setfenv(validator,env);assert(not result)
end)
test('actual string receiver find and index changes cannot authorize private execution',function()
 for _,kind in ipairs({'find','index-table','index-function'})do
  local _,_,_,_,fast=fixture();local mt=getmetatable('');local index=mt.__index;local original=index.find
  if kind=='find'then index.find=function()return nil end
  elseif kind=='index-table'then local other={};for k,v in pairs(index)do other[k]=v end;other.find=function()return nil end;mt.__index=other
  else mt.__index=function(_,key)if key=='find'then return function()return nil end end;return rawget(index,key)end end
  local result=fast();mt.__index=index;index.find=original;assert(not result,kind..' source mutation survived')
 end
end)
test('optional environment inspection never queries native string functions or prevents Store loading',function()
 local data=dofile('tests/fixtures/rotation_data.lua')();local a={RotationData=data};assert(loadfile('Data/catalog.lua'))('rotationmaster',a)
 local inspected=0;local original=getfenv
 local env=setmetatable({getfenv=function(fn)
  if fn==string.find then inspected=inspected+1;error('native C environment unavailable')end
  return original(fn)
 end},{__index=_G})
 local chunk=assert(loadfile('Data/rotation_store.lua'));setfenv(chunk,env);assert(pcall(chunk,'rotationmaster',a))
 local reader;local service,why,_,issuer=data.NewRotationStore({state=state(),fallbackID='Default',bindInternalReader=function(r)reader=r end});assert(service,why)
 local ok,_,seal=reader:Read(address(),ctx,function(r)return r.body.name end);assert(ok)
 local fast=assert(issuer(reader,seal,ctx));assert(fast()and inspected==0)
end)
test('unavailable optional class environment certificate retains the ordinary Store path',function()
 local data=dofile('tests/fixtures/rotation_data.lua')();local a={RotationData=data};assert(loadfile('Data/catalog.lua'))('rotationmaster',a)
 local original=getfenv;local validator=data.IsRotationClassToken
 local env=setmetatable({getfenv=function(fn)if fn==validator then error('environment unavailable')end;return original(fn)end},{__index=_G})
 local chunk=assert(loadfile('Data/rotation_store.lua'));setfenv(chunk,env);assert(pcall(chunk,'rotationmaster',a))
 local reader;local service,why,public,issuer=data.NewRotationStore({state=state(),fallbackID='Default',bindInternalReader=function(r)reader=r end});assert(service,why)
 local ok,_,seal=reader:Read(address(),ctx,function(r)return r.body.name end);assert(ok)
 assert(assert(public(reader,seal,ctx))());assert(not issuer(reader,seal,ctx))
end)
test('hidden string metatable index still supports the bounded private execution fence',function()
 local data=dofile('tests/fixtures/rotation_data.lua')();local a={RotationData=data};assert(loadfile('Data/catalog.lua'))('rotationmaster',a)
 local original=getmetatable;local hidden={}
 local env=setmetatable({getmetatable=function(v)if type(v)=='string'then return hidden end;return original(v)end},{__index=_G})
 local chunk=assert(loadfile('Data/rotation_store.lua'));setfenv(chunk,env);chunk('rotationmaster',a)
 local reader;local service,why,_,issuer=data.NewRotationStore({state=state(),fallbackID='Default',bindInternalReader=function(r)reader=r end});assert(service,why)
 local ok,_,seal=reader:Read(address(),ctx,function(r)return r.body.name end);assert(ok)
 local fast=assert(issuer(reader,seal,ctx));assert(fast(),'hidden native string index forced schema fallback')
end)
finish()
