local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function once(s,old,new)local a,b=s:find(old,1,true);assert(a,'fixture anchor missing');assert(not s:find(old,b+1,true),'fixture anchor repeated');return s:sub(1,a-1)..new..s:sub(b+1)end
local source=read('tests/startup.lua')
local common=assert(source:match('(local function fixture%(modern, absentThreat%).-)\ntest%('))
local persistent=assert(source:match('(local function persistentFixture%(saved,folder,scoped[,%a]*%).-)\n%-%- WoW SavedVariables'))
persistent=once(persistent,'    for key,value in pairs(saved or {}) do env[key]=value end','    env.RotationMasterDB=nil')
persistent=once(persistent,"load('Functions/cache.lua');load('Functions/trends.lua')","load('Functions/cache.lua');load('Diagnostics/cache_mode.lua');load('Functions/trends.lua')")
persistent=once(persistent,'    addon:OnInitialize()','    local beforeCache=addon.Functions.cache;local originalCached=beforeCache.getCached;local originalRetry=beforeCache.getRetryCached;local originalInternal=addon.builtinSourceModules["Functions/cache.lua"]("getCachedInternal")\n    if saved and saved.early then env.RotationMasterDB=saved.early end\n    for key,value in pairs(saved or {}) do if key~="early" then env[key]=value end end\n    addon:OnInitialize()\n    addon.__lateSVBefore={cached=originalCached,retry=originalRetry,internal=originalInternal}')
local make=assert(loadstring(common..'\n'..persistent..'\nreturn persistentFixture','@actual-late-savedvariables-startup'))()
local failed,passed=0,0
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(why))end end
local function fixture(direct)local e,a,s,load=make({RotationMasterDB={global={diagnosticCacheBypass=direct}}});return e,a,s,load end
test('late SavedVariables direct request is applied after actual main AceDB initialization',function()
 local _,a=fixture(true);local loaded,requested,pending=a:GetCacheDiagnosticMode();assert(loaded=='direct'and requested=='direct'and pending==false,'actual lateSV mode='..loaded..' requested='..requested..' pending='..tostring(pending))
 assert(a.getCached==a.__lateSVBefore.cached and a.getRetryCached==a.__lateSVBefore.retry,'public cached aliases/pointers replaced')
end)
test('already captured original public wrappers switch via owned dispatch at initialization',function()
 local _,a=fixture(true);local calls=0;local fn=function()calls=calls+1;return nil,'reason',nil end
 for _,helper in ipairs({a.__lateSVBefore.cached,a.__lateSVBefore.retry})do local cache={};local before=calls;helper(cache,fn);helper(cache,fn);assert(calls==before+2,'preinitialized wrapper still memoizes');assert(next(cache)==nil)end
end)
test('ordinary late default retains original public/private identities and memoization',function()
 local _,a=fixture(false);local loaded,requested,pending=a:GetCacheDiagnosticMode();assert(loaded=='cached'and requested=='cached'and pending==false)
 local old=a.__lateSVBefore;assert(a.getCached==old.cached and a.Functions.cache.getCached==old.cached and a.getRetryCached==old.retry)
 assert(a.builtinSourceModules['Functions/cache.lua']('getCachedInternal')==old.internal)
 local calls=0;local fn=function()calls=calls+1;return calls end;local cache={};assert(old.cached(cache,fn)==1 and old.cached(cache,fn)==1 and calls==1)
end)
test('direct preserves archived original private implementation identity and own memoization',function()
 local _,a=fixture(true);local old=a.__lateSVBefore;local internal=a.builtinSourceModules['Functions/cache.lua']('getCachedInternal');assert(internal==old.internal)
 local calls=0;local fn=function()calls=calls+1;return calls end;local cache={};assert(internal(cache,true,fn)==1 and internal(cache,true,fn)==1 and calls==1)
 local other={};assert(old.cached(other,fn)==2 and old.cached(other,fn)==3,'live wrapper did not bypass independently of archived internal')
end)
print(passed..' passed, '..failed..' failed');if failed>0 then os.exit(1)end
