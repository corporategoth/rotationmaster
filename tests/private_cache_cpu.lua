local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function once(s,old,new)local a,b=assert(s:find(old,1,true));assert(not s:find(old,b+1,true));return s:sub(1,a-1)..new..s:sub(b+1)end
local baseline=dofile('tests/fixtures/restore_private_cache_cpu.lua')(read('Diagnostics/cpu.lua'))
-- Reuse the real CPU harness and its exact external native API boundary. Source
-- owner, lifecycle, source getters and the cache implementation stay real.
local source=read('tests/cpu.lua');local at=assert(source:find("test('module is idle",1,true));source=source:sub(1,at-1)
source=once(source,'local function fixture(historical,prePrivate)','local function fixture(configure,old)')
source=once(source," if prePrivate then loadPrePrivateCPU(f)elseif historical then loadHistoricalCPU(f)else local file=io.open('Diagnostics/cpu.lua');if file then file:close();f.load('Diagnostics/cpu.lua')end end",[[ if configure then configure(f,a,s)end
 if old then local chunk=assert(loadstring(BASELINE,'@Diagnostics/cpu.lua'));setfenv(chunk,e);chunk('rotationmaster',a)else f.load('Diagnostics/cpu.lua')end]])
local make=assert(loadstring('local BASELINE=...\n'..source..'return fixture','@private-cache-cpu-fixture'))(baseline)
local heading='Private cache helpers (native counters; shared functions overlap):'
local function contains(s,x)assert(type(s)=='string'and s:find(x,1,true),'missing '..x)end
local function absent(s,x)assert(not s:find(x,1,true),'unexpected '..x)end
local function helpers(a)local getter=rawget(rawget(a,'builtinSourceModules'),'Functions/cache.lua');return getter('getCachedInternal'),getter('packResults'),getter end
local function private(s)for _,value in ipairs({'SECRET_SOURCE_TEXT','ROW_OWNER_PRIVATE_TEST','Player-1234','rotation:private-owner','function:','table:','0x'})do absent(s,value)end end
local function split(s)local at=s:find('\n'..heading,1,true);return at and s:sub(1,at-1)or s,at and s:sub(at+1)end
local function capture(configure,old,change)
 local f,a,s=make(configure,old);assert(a:StartCPUProfile());if change then change(f,a,s)end;s:complete();return a:GetCPUProfileReport(),s,f,a
end
local function nativeCount(s,fn)local n=0;for _,q in ipairs(s.queries)do if q[1]==fn then n=n+1 end end;return n end
local function cost(f,a,s)local internal,pack=helpers(a);s.privateInternal,s.privatePack=internal,pack;s.rows[internal]={{10,20,100},{22,50,106}};s.rows[pack]={{0,0,0},{0,0,0}}end

test('actual source-owned helpers expose exact deltas and legitimate zero outside old rankings',function()
 local old,os= capture(cost,true);local text,s= capture(cost);local prefix,appendix=split(text);assert(appendix,'private helper measurements missing');assert(prefix==old,'old report rows or counters changed')
 contains(appendix,'Functions.cache.getCachedInternal | exclusive=12.000 ms | inclusive=30.000 ms | calls=6')
 contains(appendix,'Functions.cache.packResults | exclusive=0.000 ms | inclusive=0.000 ms | calls=0');contains(appendix,'all callers');private(text)
 contains(appendix,'aliases=2; available=2; unavailable=0');contains(appendix,'excluded from rankings above')
 assert(nativeCount(s,s.privateInternal)==4 and nativeCount(s,s.privatePack)==4,'private snapshots missing or duplicated')
 assert(#s.queries==#os.queries+8,'more than eight additional function queries')
 local filtered={};for _,value in ipairs(s.native)do if not value:match('^function:'..s.fnIDs[s.privateInternal]..':')and not value:match('^function:'..s.fnIDs[s.privatePack]..':')then filtered[#filtered+1]=value end end
 assert(table.concat(filtered,'|')==table.concat(os.native,'|'),'old native query order changed')
end)
test('private source failure does not poison a shared old public row or execute replacement getters',function()
 local replacementCalls=0
 local function setup(f,a,s)cost(f,a,s);a.EvaluateNextAction=s.privateInternal;a.EvaluateNextActionInternal=s.privateInternal end
 local old=capture(setup,true)
 local text,s=capture(setup,false,function(_,a)a.builtinSourceModules['Functions/cache.lua']=function()replacementCalls=replacementCalls+1;error('SECRET_SOURCE_TEXT')end end)
 local prefix,appendix=split(text);assert(appendix,'private unavailable view missing');assert(prefix==old,'private resolver changed old public row availability');contains(appendix,'unavailable: source-reader-changed');contains(appendix,'aliases=2; available=0; unavailable=2');assert(replacementCalls==0)
 assert(nativeCount(s,s.privateInternal)==4,'aliased pointer resampled');private(text)
end)
test('shared private aliases reuse one snapshot while source views stay separate',function()
 local text,s=capture(function(f,a,s)
  local internal=helpers(a);s.privateInternal=internal;s.rows[internal]={{0,0,0},{5,9,3}}
  a.EvaluateNextAction=internal;a.EvaluateNextActionInternal=internal
  a.builtinSourceModules['Functions/cache.lua']=function(name)assert(name=='getCachedInternal'or name=='packResults');return internal end
 end)
 local _,appendix=split(text);assert(appendix,'private aliases absent');contains(appendix,'Functions.cache.getCachedInternal | exclusive=5.000 ms | inclusive=9.000 ms | calls=3');contains(appendix,'Functions.cache.packResults | exclusive=5.000 ms | inclusive=9.000 ms | calls=3');assert(nativeCount(s,s.privateInternal)==4)
end)
test('missing source anchor at load stays unavailable without authenticating a replacement',function()
 local original,calls
 local f,a,s=make(function(_,a)local modules=a.builtinSourceModules;original=modules['Functions/cache.lua'];modules['Functions/cache.lua']=nil end)
 a.builtinSourceModules['Functions/cache.lua']=function(...)calls=(calls or 0)+1;return original(...)end
 assert(a:StartCPUProfile());s:complete();local _,appendix=split(a:GetCPUProfileReport());assert(appendix,'missing-reader status absent');contains(appendix,'unavailable: source-reader-unavailable');assert(calls==nil)
end)
test('selection cap preserves all old rows and truncation with explicit private limits',function()
 local function setup(_,a)for i=1,512 do a.conditionDefinitions['OWNER_PRIVATE_'..i]={evaluate=function()end,valid=function()end}end end
 local old,os=capture(setup,true);local text,s=capture(setup);local prefix,appendix=split(text);assert(prefix==old,'private selection displaced old rows');assert(appendix,'selection-limit status absent');contains(appendix,'unavailable: selection-limit');assert(#s.queries==#os.queries and #s.queries<=1536)
end)
test('cancellation stale timers and report access add no private resolution or native sampling',function()
 local f,a,s=make(cost);assert(a:StartCPUProfile());assert(nativeCount(s,s.privateInternal)==2 and nativeCount(s,s.privatePack)==2,'start missing private samples');local queries=#s.queries
 local stale=s.timers[1];assert(a:CancelCPUProfile());stale.callback();a:GetCPUProfileReport();a:IsCPUProfileRunning();assert(#s.queries==queries and not a:IsCPUProfileRunning())
end)
test('captured source getter is boundary-only and neither helper is invoked by collection',function()
 local f,a,s=make(cost);local internal,pack,getter=helpers(a);local counts={[internal]=0,[pack]=0,[getter]=0}
 local previous,mask,amount=debug.gethook();local compiling=jit and jit.status();if jit then jit.off();jit.flush()end
 debug.sethook(function(event)if event=='call'then local fn=debug.getinfo(2,'f').func;if counts[fn]then counts[fn]=counts[fn]+1 end end end,'c')
 local ok,why=pcall(function()
  a:GetCPUProfileReport();s.enabled='0';assert(not a:StartCPUProfile());assert(counts[getter]==0);s.enabled='1';assert(a:StartCPUProfile());assert(counts[getter]==2)
  s:complete();assert(counts[getter]==4 and counts[internal]==0 and counts[pack]==0)
  local before=#s.queries;a:GetCPUProfileReport();s.timers[1].callback();a:IsCPUProfileRunning();assert(#s.queries==before and counts[getter]==4)
 end)
 if previous then debug.sethook(previous,mask,amount)else debug.sethook()end;if compiling then jit.on()end;assert(ok,why)
end)
test('raw source reader guards reject root and inherited changes without getter callbacks',function()
 for _,mode in ipairs({'root','inherited'})do
  local f,a,s=make(cost);local gets=0
  if mode=='root'then a.builtinSourceModules=setmetatable({},{__index=function()gets=gets+1;error('SECRET_SOURCE_TEXT')end})
  else a.builtinSourceModules['Functions/cache.lua']=nil;setmetatable(a.builtinSourceModules,{__index=function()gets=gets+1;error('SECRET_SOURCE_TEXT')end})end
  assert(a:StartCPUProfile());s:complete();local _,appendix=split(a:GetCPUProfileReport());contains(appendix,'unavailable: source-reader-changed');assert(gets==0);private(appendix)
 end
end)
test('throwing malformed and restricted getter results are fixed private-only unavailable states',function()
 for _,mode in ipairs({'throw','malformed','restricted'})do
  local f,a,s=make(function(f,a,s)
   local internal,pack=helpers(a);s.privateInternal=internal
   if mode=='restricted'then f.env.canaccessvalue=function(value)return value~=internal end
   else a.builtinSourceModules['Functions/cache.lua']=function(name)if name=='packResults'then return pack end;if mode=='throw'then error('SECRET_SOURCE_TEXT')end;return {}end end
  end)
  assert(a:StartCPUProfile());s:complete();local text=a:GetCPUProfileReport();local _,appendix=split(text);contains(appendix,'Functions.cache.getCachedInternal | unavailable: '..(mode=='throw'and 'source-reader-error'or 'invalid-source-function'));assert(nativeCount(s,s.privateInternal)==0);private(text)
 end
end)
test('returned private pointer changes invalidate only their view without querying replacement functions',function()
 local current,original,other
 local f,a,s=make(function(_,a,s)
  original,other=helpers(a);current=original;s.privateInternal=original;s.rows[original]={{0,0,0},{4,7,3}}
  a.builtinSourceModules['Functions/cache.lua']=function(name)return name=='getCachedInternal'and current or other end
 end)
 assert(a:StartCPUProfile());local replacement=function()error('SECRET_SOURCE_TEXT')end;current=replacement;s:complete();local _,appendix=split(a:GetCPUProfileReport());contains(appendix,'Functions.cache.getCachedInternal | unavailable: function-replaced');assert(nativeCount(s,original)==2 and nativeCount(s,replacement)==0)
end)
test('private alias can sample its unchanged function when old public refs were replaced',function()
 local function setup(_,a,s)cost(nil,a,s);a.EvaluateNextAction=s.privateInternal;a.EvaluateNextActionInternal=s.privateInternal end
 local function change(_,a)a.EvaluateNextAction=function()end;a.EvaluateNextActionInternal=a.EvaluateNextAction end
 local old=capture(setup,true,change);local text,s=capture(setup,false,change);local prefix,appendix=split(text);assert(prefix==old)
 contains(appendix,'Functions.cache.getCachedInternal | exclusive=12.000 ms | inclusive=30.000 ms | calls=6');assert(nativeCount(s,s.privateInternal)==4)
end)
test('native failures resets and invalid private counters never become zero or abort the old report',function()
 for _,mode in ipairs({'throw','reset','nil'})do
  local f,a,s=make(cost);assert(a:StartCPUProfile())
  if mode=='throw'then s.throwFunction=s.privateInternal
  elseif mode=='reset'then s.rows[s.privateInternal][2][1]=9
  else s.rows[s.privateInternal][2][3]=nil end
  s:complete();local text=a:GetCPUProfileReport();contains(text,'CPU profile: complete');local _,appendix=split(text)
  contains(appendix,'Functions.cache.getCachedInternal | unavailable: '..(mode=='throw'and 'function-cpu-query-error'or mode=='reset'and 'function-cpu-counter-reset'or 'invalid-function-cpu-counter'));private(text)
 end
end)
test('direct and cached rows include real archived callers sharing the original implementations',function()
 for _,direct in ipairs({false,true})do
  local counts,internal,pack
  local f,a,s=make(function(f,a,s)
   internal,pack=helpers(a);counts={[internal]=0,[pack]=0};f.load('Diagnostics/cache_mode.lua');a.db.global.diagnosticCacheBypass=direct;assert(a:InitializeCacheDiagnosticMode(a.db.global))
   local query=f.env.GetFunctionCPUUsage;f.env.GetFunctionCPUUsage=function(fn,inc)local value,calls=query(fn,inc);if counts[fn]then return 0,counts[fn]end;return value,calls end
  end)
  local previous,mask,amount=debug.gethook();local compiling=jit and jit.status();if jit then jit.off();jit.flush()end
  debug.sethook(function(event)if event=='call'then local fn=debug.getinfo(2,'f').func;if counts[fn]then counts[fn]=counts[fn]+1 end end end,'c')
  local ok,why=pcall(function()
   assert(a:StartCPUProfile());local calls=0;local fn=function()calls=calls+1;return calls end;local cache={};for i=1,3 do a.getCached(cache,fn)end
   local archived={};internal(archived,true,fn);internal(archived,true,fn);s:complete();local _,appendix=split(a:GetCPUProfileReport())
   contains(appendix,'Functions.cache.getCachedInternal | exclusive=0.000 ms | inclusive=0.000 ms | calls=5')
   contains(appendix,'Functions.cache.packResults | exclusive=0.000 ms | inclusive=0.000 ms | calls='..(direct and 1 or 2))
   assert(calls==(direct and 4 or 2));assert(a.builtinSourceModules['Functions/cache.lua']('getCachedInternal')==internal)
  end)
  if previous then debug.sethook(previous,mask,amount)else debug.sethook()end;if compiling then jit.on()end;assert(ok,why)
 end
end)
test('oversized old report is retained byte-exact without appendix growth',function()
 local function setup(f,a,s)
  for i=1,30 do local key=string.format('HOT_%02d',i);local fn=function()end;a.conditionDefinitions[key]={evaluate=fn,valid=fn};s.rows[fn]={{0,0,0},{1e308,1e308,3}}end
 end
 local old=capture(setup,true);assert(#old>=16000,'oversized positive control missing');local text=capture(setup);assert(text==old,'already oversized old report grew')
end)
test('near-limit reports append only a complete private section or a bounded omission notice',function()
 local notice='Private cache helpers omitted to keep report bounded.'
 for _,power in ipairs({180,220})do
  local function setup(_,a,s)for i=1,30 do local key=string.format('HOT_%02d',i);local fn=function()end;a.conditionDefinitions[key]={evaluate=fn,valid=fn};s.rows[fn]={{0,0,0},{10^power,10^power,3}}end end
  local old=capture(setup,true);local text=capture(setup);assert(#old<16000 and #text<16000);absent(text,heading)
  if #old+1+#notice<16000 then assert(text==old..'\n'..notice)else assert(text==old)end
 end
end)
test('synchronous completion samples exactly two boundaries and leaves no retired source work',function()
 local getterCalls,completed=0
 local f,a,s=make(function(_,a,s)
  local internal,pack,getter=helpers(a);a.builtinSourceModules['Functions/cache.lua']=function(alias)getterCalls=getterCalls+1;return getter(alias)end
  s.rows[internal]={{0,0,0},{1,2,4}};s.rows[pack]={{0,0,0},{0,0,0}}
  a.ScheduleTimer=function(_,callback)s.now=110;s.phase='finish';callback();return {}end
  a.OnCPUProfileFinished=function(_,text,status)assert(status=='complete');completed=text end
 end)
 assert(getterCalls==0 and a:StartCPUProfile());contains(completed,heading);assert(getterCalls==4 and not a:IsCPUProfileRunning())
 local before=#s.queries;a:GetCPUProfileReport();assert(#s.queries==before and getterCalls==4)
end)
test('strict appendix inverse preserves the entire fc06db4 CPU module',function()
 local restore=dofile('tests/fixtures/restore_private_cache_cpu.lua');local current=read('Diagnostics/cpu.lua');assert(restore(current)==baseline)
 assert(not pcall(restore,current..'\n')and not pcall(restore,once(current,"local cacheSourceEqual=rawequal","local cacheSourceEqual=function()return true end")),'inverse accepted altered feature or unrelated source')
end)
finish()
