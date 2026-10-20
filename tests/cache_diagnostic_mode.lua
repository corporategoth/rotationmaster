local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local modePath=arg and arg[1] or 'Diagnostics/cache_mode.lua'
local function read(path)local h=io.open(path);if not h then return end;local text=h:read('*a');h:close();return text end
local module=read(modePath)
local function loadMode(f)
 if module then local fn=assert(loadstring(module,'@Diagnostics/cache_mode.lua'));setfenv(fn,f.env);fn('rotationmaster',f.addon)end
end
local function pack(...)return{n=select('#',...),...}end
local function equal(a,b)assert(type(a)==type(b));if type(a)~='table'then assert(a==b);return end;for k,v in pairs(a)do equal(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function fixture(direct,configure)
 local f=F.new();local a,e=f.addon,f.env;local global={diagnosticCacheBypass=direct};e.RotationMasterDB={global=global};a.db.global=global
 local old={getCached=a.Functions.cache.getCached,getRetryCached=a.Functions.cache.getRetryCached,internal=a.builtinSourceModules['Functions/cache.lua']('getCachedInternal')}
 if configure then configure(f,old)end
 local saved,ready=e.RotationMasterDB,a.db;e.RotationMasterDB=nil;a.db=nil
 loadMode(f);f.load('utils.lua')
 e.RotationMasterDB=saved;a.db=ready
 if a.InitializeCacheDiagnosticMode then a:InitializeCacheDiagnosticMode(type(ready)=='table' and rawget(ready,'global') or nil)end
 return f,a,e,old
end
local function registry(f)
 for _,path in ipairs({'Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'})do f.load(path)end
 f.env.loadstring=function(text,name)local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env)end;return fn,why end
end
local function mode(a,loaded,requested,pending)local l,r,p=a:GetCacheDiagnosticMode();assert(l==loaded and r==requested and p==pending,'loaded/requested/pending mismatch')end
local function lateStartup(direct)
 local source=assert(read('tests/startup.lua'))
 local function once(text,from,to)local first,last=assert(text:find(from,1,true));assert(not text:find(from,last+1,true));return text:sub(1,first-1)..to..text:sub(last+1)end
 local common=assert(source:match('(local function fixture%(modern, absentThreat%).-)\ntest%('))
 local persistent=assert(source:match('(local function persistentFixture%(saved,folder,scoped%).-)\n%-%- WoW SavedVariables'))
 persistent=once(persistent,'    for key,value in pairs(saved or {}) do env[key]=value end','    env.RotationMasterDB=nil')
 if not persistent:find("load('Diagnostics/cache_mode.lua')",1,true)then persistent=once(persistent,"load('Functions/cache.lua');load('Functions/trends.lua')","load('Functions/cache.lua');load('Diagnostics/cache_mode.lua');load('Functions/trends.lua')")end
 persistent=once(persistent,'    addon:OnInitialize()','    local captured={cached=addon.Functions.cache.getCached,retry=addon.Functions.cache.getRetryCached,internal=addon.builtinSourceModules["Functions/cache.lua"]("getCachedInternal")}\n    for key,value in pairs(saved or {}) do env[key]=value end\n    addon:OnInitialize()\n    addon.lateCacheReferences=captured')
 local make=assert(loadstring(common..'\n'..persistent..'\nreturn persistentFixture','@actual-late-sv-cache-startup'))()
 return make({RotationMasterDB={global={diagnosticCacheBypass=direct}}})
end
test('actual main finalizes late SavedVariables through real AceDB after all files captured public helpers',function()
 local _,a=lateStartup(true);mode(a,'direct','direct',false);local old=a.lateCacheReferences
 assert(a.getCached==old.cached and a.getRetryCached==old.retry and a.Functions.cache.getCached==old.cached)
 assert(a.builtinSourceModules['Functions/cache.lua']('getCachedInternal')==old.internal)
 for _,helper in ipairs({old.cached,old.retry})do local calls=0;local cache={};local fn=function()calls=calls+1;return nil,'reason',nil end
  equal(pack(helper(cache,fn)),{n=3,nil,'reason',nil});equal(pack(helper(cache,fn)),{n=3,nil,'reason',nil});assert(calls==2 and next(cache)==nil,'pre-initialization wrapper still memoizes')
 end
end)
test('source handoff retires before initialization and absent or malformed ready scope does not consume selection',function()
 local f=F.new();local a,e=f.addon,f.env;local retired=a.BindCacheDiagnosticDispatcher;e.RotationMasterDB=nil;a.db=nil;loadMode(f)
 assert(a.BindCacheDiagnosticDispatcher==nil,'temporary dispatch handoff remained exposed')
 retired(a,function()error('retired handoff reused')end)
 local initialize=assert(a.InitializeCacheDiagnosticMode,'one-shot initializer absent')
 assert(not initialize({},{}));for _,bad in ipairs({false,7,'direct'})do assert(not initialize(a,bad))end;assert(not initialize(a,nil))
 local global={diagnosticCacheBypass=true};a.db={global=global};assert(initialize(a,global));mode(a,'direct','direct',false)
 assert(a:SetCacheDiagnosticMode('cached'));assert(initialize(a,global));mode(a,'direct','cached',true)
end)
test('file-scope stale direct request never selects before late ready cached scope',function()
 local f=F.new();local a,e=f.addon,f.env;e.RotationMasterDB={global={diagnosticCacheBypass=true}};a.db=nil;loadMode(f);f.load('utils.lua');mode(a,'cached','direct',true)
 local helper=a.getCached;local global={diagnosticCacheBypass=false};a.db={global=global};assert(a:InitializeCacheDiagnosticMode(global));mode(a,'cached','cached',false)
 assert(a.getCached==helper);local calls=0;local fn=function()calls=calls+1;return calls end;local cache={};assert(helper(cache,fn)==1 and helper(cache,fn)==1)
end)
test('selection finalizes before dispatch and unavailable capability never reports direct',function()
 local f=F.new();local a=f.addon;local calls=0
 a.BindCacheDiagnosticDispatcher=function(self,consume)assert(self==a);consume(function(direct)
  calls=calls+1;assert(direct==true);assert(not a:InitializeCacheDiagnosticMode({diagnosticCacheBypass=false}));return true
 end)end
 loadMode(f);a.db.global.diagnosticCacheBypass=true;assert(a:InitializeCacheDiagnosticMode(a.db.global));mode(a,'direct','direct',false);assert(calls==1)
 assert(a:InitializeCacheDiagnosticMode({diagnosticCacheBypass=false}));assert(calls==1)
 local f=F.new();local a=f.addon;a.BindCacheDiagnosticDispatcher=nil;loadMode(f);a.db.global.diagnosticCacheBypass=true
 assert(not a:InitializeCacheDiagnosticMode(a.db.global));assert(not a:InitializeCacheDiagnosticMode(a.db.global));mode(a,'cached','direct',true)
end)
test('default module preserves original helper pointers aliases private owner and cache behavior',function()
 local _,a,_,old=fixture(false);assert(type(a.GetCacheDiagnosticMode)=='function','cache mode API absent');mode(a,'cached','cached',false)
 assert(a.Functions.cache.getCached==old.getCached and a.Functions.cache.getRetryCached==old.getRetryCached and a.getCached==old.getCached and a.getRetryCached==old.getRetryCached)
 assert(a.builtinSourceModules['Functions/cache.lua']('getCachedInternal')==old.internal)
 local calls=0;local fn=function()calls=calls+1;return nil,'reason',nil end;local cache={};equal(pack(a.getCached(cache,fn)),{n=3,nil,'reason',nil});equal(pack(a.getCached(cache,fn)),{n=3,nil,'reason',nil});assert(calls==1)
end)
test('direct helpers preserve all tuple slots and exact arguments without reading or writing supplied cache',function()
 local _,a,_,old=fixture(true);mode(a,'direct','direct',false);assert(a.getCached==old.getCached and a.getRetryCached==old.getRetryCached and a.getCached~=a.getRetryCached)
 local getter=a.builtinSourceModules['Functions/cache.lua'];local hits,misses=getter('cacheHits'),getter('cacheMisses')
 for _,call in ipairs({a.getCached,a.getRetryCached})do for _,tuple in ipairs({{n=0},{n=1,nil},{n=2,nil,nil},{n=1,false},{n=5,nil,'reason',nil,0,nil}})do
  local calls=0;local cache=setmetatable({marker=true},{__index=function()error('cache read')end,__newindex=function()error('cache write')end})
  local fn=function(...)calls=calls+1;assert(select('#',...)==3 and select(1,...)==nil and select(2,...)==9 and select(3,...)==nil);return unpack(tuple,1,tuple.n)end
  equal(pack(call(cache,fn,nil,9,nil)),tuple);equal(pack(call(cache,fn,nil,9,nil)),tuple);assert(calls==2 and cache.marker==true and next(cache)=='marker')
 end end
 assert(getter('cacheHits')==hits and getter('cacheMisses')==misses)
end)
test('direct mode reuses original global-name resolution receiver errors and nil-cache raw fast path',function()
 local _,a,e=fixture(true);mode(a,'direct','direct',false)
 for _,call in ipairs({a.getCached,a.getRetryCached})do
  e.DIAGNOSTIC_QUERY=function(self,...)assert(self==a.Platform and select('#',...)==1 and (...)==nil);return false,nil,7 end
  equal(pack(call({},'DIAGNOSTIC_QUERY',a.Platform,nil)),{n=3,false,nil,7});e.DIAGNOSTIC_QUERY=function()return'new'end;assert(call({},'DIAGNOSTIC_QUERY')=='new')
  for _,bad in ipairs({false,{},'MISSING_DIAGNOSTIC_QUERY'})do equal(pack(call({},bad)),{n=0})end
  local marker={};local ok,why=pcall(call,{},function()error(marker)end);assert(not ok and why==marker)
 end
end)
test('unchanged protected reader uses live direct alias and preserves outer protection and tuple arity',function()
 local _,a=fixture(true);mode(a,'direct','direct',false);local cache={};local calls=0
 local fn=function()calls=calls+1;return nil,'reason',nil end
 equal(pack(a.Functions.cache.protectedRead(cache,fn)),{n=4,true,nil,'reason',nil});equal(pack(a.Functions.cache.protectedRead(cache,fn)),{n=4,true,nil,'reason',nil});assert(calls==2 and next(cache)==nil)
 local marker={};equal(pack(a.Functions.cache.protectedRead(cache,function()error(marker)end)),{n=2,false,marker})
 equal(pack(a.Functions.cache.protectedRead(cache,'DIAGNOSTIC_QUERY')),{n=2,false,'missing-api'})
end)
test('direct bypass neither inspects argument readability nor consumes or clears old entries or custom data',function()
 local _,a,_,old=fixture(true);mode(a,'direct','direct',false);local calls=0;local fn=function(value)calls=calls+1;return value,calls end;local cache={custom={preserved=true}}
 local value={};assert(old.internal(cache,true,fn,value)==value);local paths=cache[fn];local custom=cache.custom
 a.Platform.CanReadValue=function()error('direct path inspected argument')end
 local x,n=a.getCached(cache,fn,value);assert(x==value and n==2);local _,m=a.getCached(cache,fn,0/0);assert(m==3)
 assert(cache[fn]==paths and cache.custom==custom and custom.preserved)
end)
test('request changes are allowed during capture and never change loaded dispatch or schedule reload',function()
 local _,a,e=fixture(false);mode(a,'cached','cached',false);local cached=a.getCached;local calls=0
 a.IsCPUProfileRunning=function()calls=calls+1;return true end;e.ReloadUI=function()error('implicit reload')end;e.SetCVar=function()error('CVar write')end
 assert(a:SetCacheDiagnosticMode('direct'));mode(a,'cached','direct',true);assert(a.getCached==cached and a.Functions.cache.getCached==cached and calls==0)
 assert(a:SetCacheDiagnosticMode('cached'));mode(a,'cached','cached',false);assert(a.getCached==cached)
 local _,b=fixture(true);local direct=b.getCached;assert(b:SetCacheDiagnosticMode('cached'));mode(b,'direct','cached',true);assert(b.getCached==direct)
end)
test('setter validates owner mode and ready raw database without partial mutation or lazy getter calls',function()
 local _,a=fixture(false);mode(a,'cached','cached',false);local global=a.db.global
 local ok,why=a.SetCacheDiagnosticMode({},'direct');assert(not ok and why=='invalid-owner');for _,value in ipairs({'DIRECT','',false,{},7})do ok,why=a:SetCacheDiagnosticMode(value);assert(not ok and why=='invalid-cache-mode' and global.diagnosticCacheBypass==false)end
 local getters=0;a.db=setmetatable({},{__index=function()getters=getters+1;return global end});ok,why=a:SetCacheDiagnosticMode('direct');assert(not ok and why=='cache-mode-unavailable' and getters==0 and global.diagnosticCacheBypass==false)
end)
test('late ready request uses strict raw Boolean without inherited or protected metadata callbacks',function()
 for _,value in ipairs({false,0,'true',{}})do
  local _,a=fixture(false,function(f)f.env.RotationMasterDB.global.diagnosticCacheBypass=value end);mode(a,'cached','cached',false)
 end
 local gets=0;local _,a=fixture(false,function(f)f.env.RotationMasterDB=setmetatable({},{__index=function()gets=gets+1;return{diagnosticCacheBypass=true}end,__metatable={global={diagnosticCacheBypass=true}}});f.addon.db.global={}end)
 mode(a,'cached','cached',false);assert(gets==0)
 local _,b=fixture(false,function(f)local global=setmetatable({},{__index=function()gets=gets+1;return true end,__newindex=function()error('setter invoked metadata')end});f.env.RotationMasterDB.global=global;f.addon.db.global=global end)
 mode(b,'cached','cached',false);assert(b:SetCacheDiagnosticMode('direct'));mode(b,'cached','direct',true);assert(gets==0)
end)
test('reload mode selection starts fresh without registry epochs tracking or mutation of old caller caches',function()
 local _,a=fixture(false);mode(a,'cached','cached',false);local calls=0;local fn=function()calls=calls+1;return calls end;local cache={};assert(a.getCached(cache,fn)==1 and a.getCached(cache,fn)==1);local oldEntry=cache[fn]
 assert(a:SetCacheDiagnosticMode('direct'));assert(a.getCached(cache,fn)==1);local _,b=fixture(a.db.global.diagnosticCacheBypass);mode(b,'direct','direct',false);assert(b.getCached({},fn)==2 and b.getCached({},fn)==3 and cache[fn]==oldEntry)
 assert(b:SetCacheDiagnosticMode('cached'));local _,c=fixture(b.db.global.diagnosticCacheBypass);mode(c,'cached','cached',false);local fresh={};assert(c.getCached(fresh,fn)==4 and c.getCached(fresh,fn)==4)
end)
test('built-in captured leaves and later condition clones bind early direct public dispatch',function()
 local f,a=fixture(true);mode(a,'direct','direct',false);f.load('Diagnostics/errors.lua');f.load('Core/conditions.lua');f.load('Conditions/combat.lua');registry(f)
 local leaf;for i=1,20 do local name,value=debug.getupvalue(a.conditionDefinitions.COMBAT.evaluate,i);if name=='Functions'then leaf=value.cache.getCached end end;assert(leaf==a.getCached)
 local source=assert(a:GetBuiltinConditionSource('COMBAT'));local copy=assert(a:CompileCustomCondition('DIRECT_COPY',source));local calls=0;a.Platform.GetUnitFlagObservation=function(self,unit,kind)assert(self==a.Platform and unit=='player' and kind=='combat');calls=calls+1;return true end
 local cache={};assert(a.conditionDefinitions.COMBAT.evaluate({unit='player'},cache));assert(copy.evaluate({unit='player'},cache));assert(calls==2 and next(cache)==nil)
end)
test('already captured built-in leaves and editable clones follow late direct dispatch without pointer changes',function()
 local f=F.new();local a,e=f.addon,f.env;e.RotationMasterDB=nil;local original=a.getCached;loadMode(f)
 for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Conditions/combat.lua'})do f.load(path)end;registry(f)
 local copy=assert(a:CompileCustomCondition('LATE_DIRECT_COPY',assert(a:GetBuiltinConditionSource('COMBAT'))))
 local leaf;for i=1,20 do local name,value=debug.getupvalue(a.conditionDefinitions.COMBAT.evaluate,i);if name=='Functions'then leaf=value.cache.getCached end end
 assert(leaf==original);a.db.global.diagnosticCacheBypass=true;assert(a:InitializeCacheDiagnosticMode(a.db.global));assert(a.getCached==original and leaf==a.getCached)
 local calls=0;a.Platform.GetUnitFlagObservation=function(self,unit,kind)assert(self==a.Platform and unit=='player'and kind=='combat');calls=calls+1;return true end
 local cache={};assert(a.conditionDefinitions.COMBAT.evaluate({unit='player'},cache));assert(copy.evaluate({unit='player'},cache));assert(calls==2 and next(cache)==nil)
end)
test('archived helper copies keep their exact source private dependencies and intentional own memoization',function()
 local f,a,_,old=fixture(true);mode(a,'direct','direct',false);registry(f)
 local getter=a.builtinSourceModules['Functions/cache.lua'];assert(getter('getCachedInternal')==old.internal)
 local source=a:CopySettingsData(a.builtinFunctions['builtin:utils.lua:getCached'].source);local before=a:CopySettingsData(source);assert(a:InstallCustomFunction('COPIED_CACHE',source));local copy=assert(a:ResolveFunctionBinding('COPIED_CACHE'))
 local calls=0;local fn=function()calls=calls+1;return calls end;local cache={};assert(copy(cache,fn)==1 and copy(cache,fn)==1 and calls==1);assert(a.getCached(cache,fn)==2 and calls==2)
 assert(a:SettingsDataEqual(source,before));source.namespace='utils';assert(a:FunctionSourceHash(source)=='8acb0039');assert(a:FunctionSourceHash(a.builtinFunctions['builtin:utils.lua:getCachedInternal'].source)=='30f6c84c')
 local bundle=assert(a:BuildFunctionBundle('function','COPIED_CACHE',nil,false));assert(a:PlanFunctionBundleImport(bundle).valid)
end)
test('actual normalized Shaman captures early direct mode and retains advice with stable native facts',function()
 assert(module,'cache mode module absent');local make=dofile('tests/fixtures/rotation_execution.lua');local normal=make({target=true})
 local original=loadfile
 loadfile=function(path)if path=='Functions/cache.lua'then return assert(loadstring("rawset(_G,'RotationMasterDB',{global={diagnosticCacheBypass=true}})\n"..assert(read(path))..'\ndo\n'..module..'\nend\n','@'..path))end;return original(path)end
 local ok,direct=pcall(make,{target=true});loadfile=original;assert(ok,direct);mode(direct.a,'direct','direct',false)
 normal.reset();direct.reset();for i=1,3 do normal.tick();direct.tick();assert(normal.a.currentSpell==direct.a.currentSpell)end
 local before=normal.snapshot();local after=direct.snapshot();assert(before.UnitCanAttack==9 and after.UnitCanAttack==15,'actual duplicate native reads not bypassed')
end)
finish()
