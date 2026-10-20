local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local restore=dofile('tests/fixtures/restore_main_qualifiers.lua')
local restoreUnused=dofile('tests/fixtures/restore_main_unused_capture.lua')
local function pack(...) return {n=select('#',...),...} end
local function fixture(failCache)
 local rawLoad=loadfile;local calls={early=0,middle=0,late=0,sites={},caches={}};local nativeCache
 local function cacheSpy(phase)
  return function(...)
   local info=debug.getinfo(2,'Sl');if info and info.source=='@main.lua' then
    calls[phase]=calls[phase]+1;calls.sites[info.currentline]=true;assert(type((...))=='table' and select('#',...)>=3,'cache argument tuple changed');calls.caches[(...)]=true
    if failCache then error(failCache) end
   end
   return nativeCache(...)
  end
 end
 _G.loadfile=function(path,...)
  if path~='main.lua' and path~='init.lua' then return rawLoad(path,...) end
  local chunk=assert(rawLoad(path))
  return function(name,a)
   if path=='main.lua' then
    nativeCache=a.Functions.cache.getCached;a.Functions.cache.getCached=cacheSpy('early')
    for _,alias in ipairs({'getCached','ReportCacheStats','deepcopy'}) do local old=a[alias]
     a[alias]=function(...) local caller=debug.getinfo(2,'S');assert(not caller or caller.source~='@main.lua','LEGACY_MAIN_ALIAS_'..alias);return old(...) end
    end
   end
   setfenv(chunk,getfenv(1));local result=chunk(name,a)
   if path=='init.lua' then local lifecycle=assert(a.InstallRotationProfileLifecycle);a.InstallRotationProfileLifecycle=function(...) a.Functions.cache.getCached=cacheSpy('middle');return lifecycle(...) end end
   return result
  end
 end
 local result=pack(pcall(function()
  local h=assert(io.open('tests/rotation_scope_runtime.lua'));local source=h:read('*a');h:close();local prefix=assert(source:match('^(.-)\nlocal function gate'))
  local make=assert(loadstring(prefix..'\nreturn fixture','@main-namespace-real-runtime'))();return make()
 end))
 _G.loadfile=rawLoad;assert(result[1],result[2])
 local env,a,events=result[2],result[3],result[4]
 return env,a,events,calls,cacheSpy
end
local function roster(e,a)
 a.units={target=true};e.UnitGUID=function(unit) assert(unit=='target');return 'target-guid' end;e.UnitName=function(unit) assert(unit=='target');return 'Target' end
 e.UnitExists=function(unit) assert(unit=='target');return true end;e.UnitCanAttack=function(player,unit) assert(player=='player' and unit=='target');return true end
 e.UnitIsEnemy=e.UnitCanAttack;e.UnitThreatSituation=function(player,unit) assert(player=='player' and unit=='target');return 2 end
end
test('all9 real staged cache consumers retain late initializer capture and native argument identity',function()
 local e,a,events,calls,cacheSpy=fixture();roster(e,a);assert(calls.early==0 and calls.middle==0)
 a.Functions.cache.getCached=cacheSpy('late');a:EvaluateNextActionInternal();a:EvaluateNextActionInternal()
 assert(a.currentSpell==403 and #events>0 and a.unitsInRange['target-guid'].threat==2,'real staged advice did not run')
 assert(calls.early==0 and calls.late==0 and calls.middle==10,'captured helper moved to module load or became a live lookup')
 local sites,caches=0,0;for _ in pairs(calls.sites) do sites=sites+1 end;for _ in pairs(calls.caches) do caches=caches+1 end
 assert(sites==9 and caches==2,'consumer coverage or evaluation-pass cache lifetime changed')
end)
test('periodic report keeps the addon receiver gate warning reset order and live member',function()
 local e,a=fixture();local logs={};a.debug=function(_,format,...) logs[#logs+1]={format,...} end
 local report=a.Functions.cache.ReportCacheStats;local count=0
 a.Functions.cache.ReportCacheStats=function(...) assert(select('#',...)==1 and (...)==a,'report receiver changed');count=count+1;return report(...) end
 e.GetTime=function() return 115 end;a:EvaluateNextActionInternal();assert(count==0 and a.lastCacheReport==100,'15second boundary changed')
 e.GetTime=function() return 116 end;a:EvaluateNextActionInternal();assert(count==1 and a.lastCacheReport==116)
 local found=false;for _,line in ipairs(logs) do if line[1]=='Cache hit rate at %.02f%%' then assert(type(line[2])=='number');found=true end end;assert(found,'actual cache warning changed')
 a.Functions.cache.ReportCacheStats=function(...) assert(select('#',...)==1 and (...)==a);count=count+1;return report(...) end
 e.GetTime=function() return 132 end;a:EvaluateNextActionInternal();assert(count==2,'canonical report was captured')
end)
test('actual cast callback shallow copy keeps source nested identity dispatch and pre-copy dedup',function()
 local _,a=fixture();a.debug=function() end;local leaf=a.Functions.collections.deepcopy;local copied,dispatched=0,0;local items={1};local nested={kept=true}
 local record=setmetatable({id='namespace-item',type='item',item=items,event='SUCCEEDED',announce='local',value='Used {{item}}',metadata=nested},{})
 a.db.profile.announces={record};a.announced={};a.spellHistory={};a.events={SUCCEEDED='Succeeded'}
 a.Functions.collections.deepcopy=function(...) assert(select('#',...)==1 and (...)==record);copied=copied+1;local out=leaf(...);assert(out~=record and getmetatable(out)==nil and out.item==items and out.metadata==nested);return out end
 a.GetSpellIds=function(_,entry) assert(entry~=record and entry.action==items and entry.item==items);return {403},{1} end
 a.Platform.GetItemDisplayInfo=function(_,id) assert(id==1);return {link='item:1'} end
 a.DispatchAnnouncement=function(_,entry,text) assert(entry.action==items and entry.metadata==nested and text=='Used item:1');dispatched=dispatched+1 end
 a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','namespace-cast',403);a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','namespace-cast',403)
 assert(copied==1 and dispatched==1 and record.action==nil and record.item==items and getmetatable(record)~=nil,'source or dedup order changed')
 a.Functions.collections.deepcopy=function(...) assert(select('#',...)==1 and (...)==record);copied=copied+10;return leaf(...) end
 a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','namespace-next',403);assert(copied==11 and dispatched==2 and record.action==nil)
 local other=setmetatable({Functions={collections={deepcopy=function(...) assert(select('#',...)==1 and (...)==record);copied=copied+100;return leaf(...) end}},announced={},spellHistory={}},{__index=a})
 other:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','other-owner',403);assert(copied==111 and dispatched==3,'copy used lexical addon instead of actual event owner')
end)
test('canonical failures retain staged advice and cast mutation boundaries',function()
 local marker={};local e,a,events=fixture(marker);roster(e,a);local ok,why=pcall(a.EvaluateNextActionInternal,a);assert(not ok and why==marker and #events==0 and a.currentSpell==nil,'cache error published advice or changed error identity')
 local e,a,events=fixture();local resets=0;a.evaluationProfile.reset=function() resets=resets+1 end;a.Functions.cache.ReportCacheStats=function(...) assert((...)==a);error(marker) end
 e.GetTime=function() return 116 end;ok,why=pcall(a.EvaluateNextActionInternal,a);assert(not ok and why==marker and #events>0 and a.lastCacheReport==100 and resets==0,'post-publish reporting error moved/reset state')
 local _,a=fixture();a.debug=function() end;a.events={SUCCEEDED='Succeeded'};a.spellHistory={};a.announced={};local record={id='failed-copy',type='spell',spell=403,event='SUCCEEDED',announce='local',value='Cast'};a.db.profile.announces={record}
 a.Functions.collections.deepcopy=function(...) assert(select('#',...)==1 and (...)==record);error(marker) end
 a.DispatchAnnouncement=function() error('copy error reached dispatch') end;ok,why=pcall(a.UNIT_SPELLCAST_SUCCEEDED,a,'UNIT_SPELLCAST_SUCCEEDED','player','failed',403)
 assert(not ok and why==marker and record.action==nil and a.announced['failed-copy']==nil and #a.spellHistory==0,'copy error consumed cast/history or mutated source')
end)
test('actual cpu command uses bundled argument parser for start report cancel and no argument',function()
 local h=assert(io.open('tests/startup.lua'));local source=h:read('*a');h:close();local prefix=source:sub(1,assert(source:find('\nlocal function initialize',1,true))-1)
 local make=assert(loadstring(prefix..'\nreturn fixture','@cpu-command-actual-main-fixture'))();local e,a,load=make(true,true)
 local fallback=e.LibStub;e.LibStub=false;load('Libs/LibStub/LibStub.lua');local lib=e.LibStub
 setmetatable(lib,{__call=function(self,name,silent) if self.libs[name] then return self:GetLibrary(name,silent) end;return fallback(name,silent) end});load('Libs/AceConsole-3.0/AceConsole-3.0.lua');load('main.lua')
 local seen;a.RunCPUProfileAction=function(self,...) assert(self==a);seen=pack(...) end
 for _,case in ipairs({{'cpu start','start'},{'cpu report','report'},{'cpu cancel','cancel'},{'cpu',false}}) do a:HandleCommand(case[1]);assert(seen and seen.n==2 and seen[1]==(case[2] or nil) and seen[2]==1e9,'cpu command argument routing changed') end
end)
test('strict inverse retains postslash main bytes unused capture aliases and existing source contracts',function()
 local f=F.new();f.load('Core/function_data.lua');local a=f.addon;local function hash(text) return a:FunctionSourceHash(text) end
 local h=assert(io.open('main.lua'));local text=h:read('*a');h:close();text=dofile('tests/fixtures/restore_rotation_execution_index.lua')(text,'main.lua');local active=restoreUnused(text,hash);local old=restore(active,hash)
 assert(hash(old)=='4e3a4815' and not pcall(restore,old,hash) and not pcall(restore,active..active,hash) and not pcall(restore,active..'\n-- unrelated change\n',hash))
 f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');assert(not a.BuiltinSourceCatalog.modules['main.lua'] and not a.builtinFunctions['builtin:Functions/cache.lua:ReportCacheStats'])
 assert(a.getCached==a.Functions.cache.getCached and a.ReportCacheStats==a.Functions.cache.ReportCacheStats and a.deepcopy==a.Functions.collections.deepcopy and a.isint==a.Functions.values.isint,'direct compatibility aliases changed')
end)
finish()
