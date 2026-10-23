local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function pack(...)return{n=select('#',...),...}end
local function fixture(initial)
 local a={};local e=setmetatable(initial or{},{__index=_G});e._G=e
 e.LibStub=function(name)assert(name=='AceLocale-3.0');return{GetLocale=function()return setmetatable({},{__index=function(_,key)return key end})end}end
 local load=assert(loadfile('Functions/cache.lua'));setfenv(load,e);load('rotationmaster',a)
 local c=a.Functions.cache;a.getCached,a.getRetryCached=c.getCached,c.getRetryCached
 local selectMode;a:BindCacheDiagnosticDispatcher(function(select)selectMode=select end)
 return a,e,assert(selectMode),a.builtinSourceModules['Functions/cache.lua']
end
local function sameTuple(actual,expected)
 assert(actual.n==expected.n,'return arity changed');for i=1,expected.n do assert(rawequal(actual[i],expected[i]),'tuple value changed')end
end
test('selected direct observations never enter the unchanged cached implementation',function()
 local a,_,selectMode,getter=fixture();local internal=getter('getCachedInternal');local public,retry=a.getCached,a.getRetryCached
 assert(selectMode(true));assert(a.getCached==public and a.getRetryCached==retry and getter('getCachedInternal')==internal)
 local internalCalls,callbackCalls=0,0
 local function hook(event)if event=='call'and debug.getinfo(2,'f').func==internal then internalCalls=internalCalls+1 end end
 local previousHook,previousMask,previousCount=debug.gethook()
 local jitWasEnabled=jit and jit.status()
 if jit then jit.off()end
 debug.sethook(hook,'c')
 local ok,why=pcall(function()
  local function callback()callbackCalls=callbackCalls+1;return callbackCalls end
  assert(public({},callback)==1 and retry({},callback)==2)
 end)
 debug.sethook(previousHook,previousMask,previousCount)
 if jit and jitWasEnabled then jit.on()end
 assert(ok,why);assert(callbackCalls==2)
 assert(internalCalls==0,'direct observations still entered cached implementation '..internalCalls..' times')
end)
test('direct callbacks preserve argument and result nilarity and never inspect cache',function()
 local a,_,selectMode=fixture();assert(selectMode(true))
 local opaque={};local cache=setmetatable({},{__index=function()error('cache read')end,__newindex=function()error('cache write')end})
 for _,method in ipairs({a.getCached,a.getRetryCached})do
  for _,result in ipairs({{n=0},{n=1,nil},{n=1,false},{n=5,nil,opaque,nil,false,nil}})do
   local function callback(...)sameTuple(pack(...),{n=4,opaque,nil,false,nil});return unpack(result,1,result.n)end
   sameTuple(pack(method(cache,callback,opaque,nil,false,nil)),result)
  end
 end
end)
test('string callbacks resolve live captured globals once and nonfunctions return no values',function()
 local a,e,selectMode=fixture();assert(selectMode(true));local reads=0
 local oldMeta=getmetatable(e);local inherited=oldMeta.__index
 oldMeta.__index=function(_,key)if key=='DIRECT_TEST'then reads=reads+1;return function(value)return value,reads end end;return inherited[key]end
 sameTuple(pack(a.getCached({},'DIRECT_TEST',7)),{n=2,7,1})
 e.DIRECT_TEST=function(value)return value+1 end;sameTuple(pack(a.getRetryCached({},'DIRECT_TEST',7)),{n=1,8});assert(reads==1)
 for _,value in ipairs({false,12,{}})do sameTuple(pack(a.getCached({},value)),{n=0})end
 sameTuple(pack(a.getCached({},'ABSENT_DIRECT_CALLBACK')),{n=0})
end)
test('errors propagate unchanged and nested direct calls cannot consume supplied caches',function()
 local a,_,selectMode=fixture();assert(selectMode(true));local marker={};local cache={}
 local ok,why=pcall(a.getCached,cache,function()error(marker,0)end);assert(not ok and rawequal(why,marker)and next(cache)==nil)
 sameTuple(pack(a.getRetryCached(cache,function(value)return a.getCached(cache,function(...)return ... end,value,nil)end,9)),{n=2,9,nil})
 assert(next(cache)==nil)
end)
test('preload type capture and dynamic global lookup order remain unchanged',function()
 local realType=type;local seen={};local e={type=function(value)seen[#seen+1]=value;return realType(value)end}
 local a,env,selectMode=fixture(e);assert(selectMode(true));seen={}
 local fn=function(value)return value end;env.DIRECT_ORDER=fn
 env.type=function()error('adopted later global type')end
 assert(a.getCached({},'DIRECT_ORDER',11)==11)
 assert(#seen==2 and seen[1]=='DIRECT_ORDER'and seen[2]==fn)
 env.DIRECT_ORDER=function()error('fresh callback',0)end
 local ok,why=pcall(a.getCached,{},'DIRECT_ORDER');assert(not ok and why=='fresh callback')
end)
test('cached selection and original generated getter retain independent memoization semantics',function()
 local a,_,selectMode,getter=fixture();local internal=getter('getCachedInternal');assert(selectMode(false))
 local count=0;local function callback()count=count+1;return count end
 local cache={};assert(a.getCached(cache,callback)==1 and a.getCached(cache,callback)==1 and count==1)
 local b,_,direct,get=fixture();local owned=get('getCachedInternal');assert(direct(true))
 assert(get('getCachedInternal')==owned)
 cache={};assert(owned(cache,true,callback)==2 and owned(cache,true,callback)==2 and count==2)
 assert(b.getCached(cache,callback)==3 and b.getCached(cache,callback)==4 and count==4)
end)
finish()
