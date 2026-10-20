local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local restore=dofile('tests/fixtures/restore_cpu_validation_scopes.lua')
local function read(p)local h=assert(io.open(p));local s=h:read('*a');h:close();return s end
local source=read('tests/cpu.lua');local prefix=assert(source:match('^(.-)\ntest%('));local make=assert(loadstring(prefix..'\nreturn fixture','@validation-cpu-real-fixture'))()
local specs={{'references','Core/rotation_references.lua','GetRotationValidationStamp',4},{'library','Core/rotation_library.lua','InitializeRotationLibrary',2},{'scope','Core/rotation_scope.lua','BindRotationProfile',1}}
local labels={'references.observe','references.sameEntries','references.sameItemsets','references.proofGlobals','library.ensure','library.eligible','scope.same'}
local heading='Private validation scopes (native counters; shared functions overlap):'
local function has(s,x)assert(type(s)=='string'and s:find(x,1,true),'missing '..x)end
local function private(s)for _,v in ipairs({'SECRET_SOURCE_TEXT','PRIVATE_SCOPE','Player-1234','function:','table:','0x'})do assert(not s:find(v,1,true),'private value '..v)end end
local function fixture(options)
 options=options or{};local previous=loadfile
 if options.old then loadfile=function(path)if path=='Diagnostics/cpu.lua'then return assert(loadstring(restore(nil,path,true),'@'..path))end;return previous(path)end end
 local ok,f,a,s=pcall(make);loadfile=previous;assert(ok,f)
 local bind=a.BindCPUValidationScopeDiagnostic;s.bind=bind;s.groups={};s.fns={};s.readers={}
 -- Test-only interception observes actual lexical objects supplied by real footer code.
 a.BindCPUValidationScopeDiagnostic=function(owner,name,anchor,reader)
  local funcs={reader()};s.groups[name]={anchor=anchor,reader=reader,funcs=funcs}
  if options.reader then reader=options.reader(name,reader,f,a,s)end
  if bind then return bind(owner,name,anchor,reader)end
 end
 for _,p in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua'})do f.load(p)end
 for i,spec in ipairs(specs)do if not options.limit or i<=options.limit then f.load(spec[2])end end
 a.BindCPUValidationScopeDiagnostic=nil -- remove only our test interceptor
 for _,spec in ipairs(specs)do local g=s.groups[spec[1]];if g then for _,fn in ipairs(g.funcs)do s.fns[#s.fns+1]=fn end;s.readers[#s.readers+1]=g.reader end end
 return f,a,s
end
local function complete(a,s)assert(a:StartCPUProfile());s:complete();return assert(a:GetCPUProfileReport())end
local function cost(s)
 assert(#s.fns==7,'actual module footer functions missing')
 for i,fn in ipairs(s.fns)do s.rows[fn]={{i,2*i,10*i},{i+3,2*i+5,10*i+2}}end
end
local function split(text)local at=text:find('\n'..heading,1,true)or text:find('\nPrivate validation scopes omitted',1,true);return at and text:sub(1,at-1)or text,at and text:sub(at+1)end
local function count(s,fn)local n=0;for _,q in ipairs(s.queries)do if q[1]==fn then n=n+1 end end;return n end

test('seven actual lexical helpers have fixed deltas outside all old rankings and report bytes',function()
 local _,old,os=fixture({old=true});cost(os);local baseline=complete(old,os)
 local _,a,s=fixture();cost(s);local text=complete(a,s);local before,section=split(text);assert(section,'new appendix missing');assert(before==baseline,'old report changed')
 for _,label in ipairs(labels)do has(section,'Validation.'..label..' | exclusive=3.000 ms | inclusive=5.000 ms | calls=2')end
 has(section,'aliases=7; available=7; unavailable=0');has(section,'excluded from rankings');has(section,'not additive');private(text)
 assert(#s.queries==#os.queries+28);for _,fn in ipairs(s.fns)do assert(count(s,fn)==4)end
 local ids={};for _,fn in ipairs(s.fns)do ids[tostring(s.fnIDs[fn])]=true end
 local native={};for _,entry in ipairs(s.native)do local id=entry:match('^function:(%d+):');if not id or not ids[id]then native[#native+1]=entry end end
 assert(table.concat(native,'|')==table.concat(os.native,'|'),'old complete native query order changed')
end)
test('collection invokes no measured helper and idle report reads remain inert',function()
 local _,a,s=fixture();cost(s);local calls={};for _,fn in ipairs(s.fns)do calls[fn]=0 end
 local hook,mask,n=debug.gethook();local jitOn=jit and jit.status();if jit then jit.off();jit.flush()end
 debug.sethook(function(event)if event=='call'then local fn=debug.getinfo(2,'f').func;if calls[fn]then calls[fn]=calls[fn]+1 end end end,'c')
 local ok,why=pcall(function()assert(#s.queries==0);a:GetCPUProfileReport();a:IsCPUProfileRunning();complete(a,s);local before=#s.queries
  for i=1,10 do a:GetCPUProfileReport();a:IsCPUProfileRunning();s.timers[1].callback()end;assert(#s.queries==before)
  for _,fn in ipairs(s.fns)do assert(calls[fn]==0,'diagnostics executed a measured helper')end
 end)
 if hook then debug.sethook(hook,mask,n)else debug.sethook()end;if jitOn then jit.on()end;assert(ok,why)
end)
test('installer uses captured addon receiver and retires after all three registrations',function()
 local f,a,s=fixture();assert(type(s.bind)=='function','startup installer absent');assert(not s.bind({},'references',function()end,function()end))
 local _,empty,es=fixture({limit=0});assert(not es.bind({},'references',empty.GetRotationValidationStamp,function()end));assert(es.bind(empty,'references',empty.GetRotationValidationStamp,function()return function()end,function()end,function()end,function()end end),'foreign attempt consumed startup registration')
 local newer=function()return 'newer' end;empty.BindCPUValidationScopeDiagnostic=newer;assert(not empty:StartCPUProfile(0));assert(empty.BindCPUValidationScopeDiagnostic==newer and not es.bind(empty,'scope',function()end,function()end),'retirement overwrote a newer installer or reopened state')
 assert(not s.bind(a,'UNKNOWN',function()end,function()end));assert(not s.bind(a,'references',s.groups.references.anchor,s.groups.references.reader));assert(a.BindCPUValidationScopeDiagnostic==nil)
 -- No sampler present: literal footer blocks are optional and original methods load normally.
 local bare=F.new();for _,p in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua','Core/rotation_scope.lua'})do bare.load(p)end
 assert(type(bare.addon.GetRotationValidationStamp)=='function'and type(bare.addon.BindRotationProfile)=='function')
end)
test('direct startup order registers all three owners and removes the real installer',function()
 local f,a,s=make();local bind=assert(a.BindCPUValidationScopeDiagnostic)
 for _,p in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_references.lua','Core/rotation_library.lua','Core/rotation_scope.lua'})do f.load(p)end
 assert(a.BindCPUValidationScopeDiagnostic==nil and not bind(a,'scope',a.BindRotationProfile,function()end))
 local text=complete(a,s);has(text,'aliases=7; available=7; unavailable=0')
end)
test('first refused attempt permanently retires zero and partial group registration',function()
 for _,limit in ipairs({0,1,2})do local _,a,s=fixture({limit=limit});local bind=assert(s.bind);s.enabled='0';local ok,why=a:StartCPUProfile();assert(not ok and why=='script-profile-disabled')
  assert(#s.queries==0);for _,spec in ipairs(specs)do assert(not bind(a,spec[1],function()end,function()end))end
  s.enabled='1';local text=complete(a,s);has(text,heading);has(text,'unavailable: unbound')
 end
end)
test('raw anchor replacement is unavailable without getters or querying a replacement',function()
 local _,a,s=fixture();cost(s);assert(a:StartCPUProfile());local gets=0;a.GetRotationValidationStamp=nil
 setmetatable(a,{__index=function()gets=gets+1;error('PRIVATE_SCOPE')end});s:complete();local text=a:GetCPUProfileReport();assert(gets==0)
 for i=1,4 do has(text,'Validation.'..labels[i]..' | unavailable: owner-changed');assert(count(s,s.fns[i])==2)end
 private(text)
end)
test('source reload invalidates old owner group and never adopts newly registered functions',function()
 local f,a,s=fixture();cost(s);assert(a:StartCPUProfile());local old=s.fns[1];f.load('Core/rotation_references.lua');s:complete()
 local text=a:GetCPUProfileReport();has(text,'Validation.references.observe | unavailable: owner-changed');assert(count(s,old)==2 and a.BindCPUValidationScopeDiagnostic==nil)
end)
test('existing public pointer aliases reuse the exact start and finish snapshots',function()
 local _,a,s=fixture();cost(s);a.EvaluateNextAction=s.fns[1];a.EvaluateNextActionInternal=s.fns[1]
 local text=complete(a,s);has(text,'Validation.references.observe | exclusive=3.000 ms | inclusive=5.000 ms | calls=2');assert(count(s,s.fns[1])==4,'alias resampled')
end)
test('cap384 counts every unique old cache activity and private pointer without displacing old rows',function()
 local function fill(a)for i=1,512 do a.conditionDefinitions['CAP_'..i]={evaluate=function()end,valid=function()end}end end
 local _,a,s=fixture();cost(s);fill(a);local text=complete(a,s);has(text,'unavailable: selection-limit');for _,fn in ipairs(s.fns)do assert(count(s,fn)==0)end
 local _,b,t=fixture({old=true});cost(t);fill(b);local old=complete(b,t);assert(split(text)==old and #s.queries==#t.queries)
 local seen,n={},0;for _,q in ipairs(s.queries)do if not seen[q[1]]then n=n+1;seen[q[1]]=true end end;assert(n<=384,'all-unique capture cap exceeded')
end)
test('private cache and activity occupy the aggregate cap before any new helper',function()
 local _,a,s=fixture();cost(s)
 for i=1,310 do a.conditionDefinitions['CAP_ONE_'..i]={evaluate=function()end}end
 local callbacks={overlay=function()end,pixel=function()end,autocast=function()end,blizzard=function()end}
 assert(a:BindCPUActivityDiagnostic('visual',function()return{callbacks=callbacks}end))
 local text=complete(a,s);for _,fn in ipairs(s.fns)do assert(count(s,fn)==0,'private scope displaced old cache/activity selection')end
 local seen,n={},0;for _,q in ipairs(s.queries)do if not seen[q[1]]then seen[q[1]]=true;n=n+1 end end;assert(n==384)
 assert(count(s,callbacks.overlay)==4 and count(s,callbacks.pixel)==0,'old activity boundary changed');has(text,'Validation.references.observe | unavailable: selection-limit')
end)
test('actual activity alias shares the same native start and finish record',function()
 local _,a,s=fixture();cost(s);assert(a:BindCPUActivityDiagnostic('visual',function()return{callbacks={overlay=s.fns[1]}}end))
 local text=complete(a,s);assert(count(s,s.fns[1])==4,'activity alias resampled');has(text,'Validation.references.observe | exclusive=3.000 ms | inclusive=5.000 ms | calls=2')
end)
test('zero counters stay zero while native failures resets and restricted numbers stay unavailable',function()
 for _,mode in ipairs({'zero','throw','reset','restricted'})do local f,a,s=fixture();cost(s)
  if mode=='zero'then s.rows[s.fns[1]]={{0,0,0},{0,0,0}}end;assert(a:StartCPUProfile())
  if mode=='throw'then s.throwFunction=s.fns[1]elseif mode=='reset'then s.rows[s.fns[1]][2][1]=0 elseif mode=='restricted'then local opaque={};s.rows[s.fns[1]][2][1]=opaque;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end end
  s:complete();local text=a:GetCPUProfileReport();if mode=='zero'then has(text,'Validation.references.observe | exclusive=0.000 ms | inclusive=0.000 ms | calls=0')else has(text,'Validation.references.observe | unavailable:')end;private(text)
 end
end)
test('cancelled stale invalid and refused captures do not query private scope ends',function()
 local _,a,s=fixture();cost(s);assert(a:StartCPUProfile());local before=#s.queries;assert(a:CancelCPUProfile());s.timers[1].callback();a:GetCPUProfileReport();assert(#s.queries==before)
 for _,fn in ipairs(s.fns)do assert(count(s,fn)==2)end
 local _,b,t=fixture();cost(t);assert(b:StartCPUProfile());t.now=99;t.phase='finish';t.timers[1].callback();for _,fn in ipairs(t.fns)do assert(count(t,fn)==2)end
end)
test('synchronous scheduler and timer failures preserve original return report and bounded samples',function()
 for _,mode in ipairs({'sync','throw','nil'})do
  local _,a,s=fixture();cost(s);local completed;a.OnCPUProfileFinished=function(_,text)completed=text end;a.ScheduleTimer=function(_,callback)
   if mode=='throw'then error('PRIVATE_SCOPE')elseif mode=='nil'then return nil end
   s.now=110;s.phase='finish';callback();return{}
  end
  local ok,why=a:StartCPUProfile();if mode=='sync'then assert(ok and not a:IsCPUProfileRunning());has(completed,heading);local text,reason=a:GetCPUProfileReport();assert(text==nil and reason=='not-captured','original synchronous postcallback clearing changed');for _,fn in ipairs(s.fns)do assert(count(s,fn)==4)end
  else assert(not ok and why=='timer-error'and not a:IsCPUProfileRunning());for _,fn in ipairs(s.fns)do assert(count(s,fn)==2)end end
 end
end)
test('cancellation during new exclusive snapshot prevents its inclusive and all later scope queries',function()
 local f,a,s=fixture();cost(s);local query=f.env.GetFunctionCPUUsage;local fired=false
 f.env.GetFunctionCPUUsage=function(fn,inclusive)local x,y=query(fn,inclusive);if not fired and fn==s.fns[1]then fired=true;assert(a:CancelCPUProfile())end;return x,y end
 assert(a:StartCPUProfile());assert(not a:IsCPUProfileRunning());assert(#s.timers==0,'retired scope setup scheduled an old timer');has(a:GetCPUProfileReport(),'cancelled');assert(count(s,s.fns[1])==1);for i=2,7 do assert(count(s,s.fns[i])==0)end
end)
test('provider cancellation retires setup before querying any returned function',function()
 local fired=false;local _,a,s=fixture({reader=function(name,reader,f,a)
  if name~='references'then return reader end
  return function()if not fired then fired=true;assert(a:CancelCPUProfile())end;return reader()end
 end});cost(s);assert(a:StartCPUProfile());assert(not a:IsCPUProfileRunning());assert(#s.timers==0,'cancelled provider scheduled an old timer');has(a:GetCPUProfileReport(),'cancelled');for _,fn in ipairs(s.fns)do assert(count(s,fn)==0)end
end)
test('newer capture begun inside scope end query prevents any retired scope query or cleanup',function()
 local f,a,s=fixture();cost(s);local query=f.env.GetFunctionCPUUsage;local fired=false
 f.env.GetFunctionCPUUsage=function(fn,inclusive)local x,y=query(fn,inclusive);if s.phase=='finish'and not fired and fn==s.fns[1]then fired=true;s.phase='start';assert(a:StartCPUProfile())end;return x,y end
 assert(a:StartCPUProfile());s:complete();assert(a:IsCPUProfileRunning(),'older completion retired newer capture')
 -- first start2, first end-exclusive1, newer start2; no old end-inclusive after reentry.
 assert(count(s,s.fns[1])==5);for i=2,7 do assert(count(s,s.fns[i])==4)end
 s:complete();assert(not a:IsCPUProfileRunning());has(a:GetCPUProfileReport(),heading)
end)
test('completed replacement inside new start queries preserves its report and sole timer',function()
 local f,a,s=fixture();cost(s);local query=f.env.GetFunctionCPUUsage;local fired,newer=false,nil;local callbacks={}
 a.OnCPUProfileFinished=function(_,text,status)callbacks[#callbacks+1]={text,status}end
 f.env.GetFunctionCPUUsage=function(fn,inclusive)
  local x,y=query(fn,inclusive)
  if not fired and fn==s.fns[1]then fired=true;assert(a:CancelCPUProfile());assert(a:StartCPUProfile());s:complete();newer=assert(a:GetCPUProfileReport())end
  return x,y
 end
 assert(a:StartCPUProfile());assert(newer and a:GetCPUProfileReport()==newer,'old Start erased the newer completed report')
 assert(#s.timers==1 and #callbacks==2 and callbacks[1][2]=='cancelled'and callbacks[2][2]=='complete','old setup created a timer/callback after replacement')
end)
test('completed replacement inside new appendix prevents old report and callback publication',function()
 local f,a,s=fixture();cost(s);local query=f.env.GetFunctionCPUUsage;local fired,newer=false,nil;local callbacks={}
 a.OnCPUProfileFinished=function(_,text,status)callbacks[#callbacks+1]={text,status}end
 f.env.GetFunctionCPUUsage=function(fn,inclusive)
  local x,y=query(fn,inclusive)
  if s.phase=='finish'and not fired and fn==s.fns[1]then
   fired=true;s.phase='start';assert(a:StartCPUProfile());s:complete();newer=assert(a:GetCPUProfileReport())
  end
  return x,y
 end
 assert(a:StartCPUProfile());s:complete();assert(newer and a:GetCPUProfileReport()==newer,'old finish overwrote the newer completed report')
 assert(#callbacks==1 and callbacks[1][1]==newer,'old finish published after replacement')
end)
test('reentry in preexisting activity and context stages retains exact baseline behavior',function()
 local function scenario(old,kind)
  local _,a,s=fixture({old=old});cost(s);local fired=false;local callbacks={};a.OnCPUProfileFinished=function(_,text,status)callbacks[#callbacks+1]={split(text),status}end
  if kind=='activity'then assert(a:BindCPUActivityDiagnostic('visual',function()if not fired then fired=true;assert(a:CancelCPUProfile())end;return{}end))
  else local calls=0;a.GetCacheDiagnosticMode=function()calls=calls+1;if calls==2 and not fired then fired=true;s.phase='start';assert(a:StartCPUProfile());s:complete()end;return 'cached','cached',false end end
  assert(a:StartCPUProfile());if kind=='context'then s:complete()end
  local text,reason=a:GetCPUProfileReport();return{text=text and split(text),reason=reason,timers=#s.timers,callbacks=callbacks}
 end
 for _,kind in ipairs({'activity','context'})do local old,current=scenario(true,kind),scenario(false,kind)
  assert(current.text==old.text and current.reason==old.reason and current.timers==old.timers,kind..' legacy reentry changed')
  assert(#current.callbacks==#old.callbacks);for i,row in ipairs(current.callbacks)do assert(row[1]==old.callbacks[i][1]and row[2]==old.callbacks[i][2],kind..' old callback changed')end
 end
end)
test('foreign capture receiver and nonliteral failed providers never expose arbitrary source',function()
 local _,a,s=fixture();cost(s);local foreign={};for k,v in pairs(a)do foreign[k]=v end;assert(a.StartCPUProfile(foreign));s:complete()
 local text=a:GetCPUProfileReport();has(text,'unavailable: owner-changed');for _,fn in ipairs(s.fns)do assert(count(s,fn)==0)end
 for _,mode in ipairs({'throw','malformed','restricted'})do
  local f,b,t=fixture({reader=function(name,reader,f)
   if name~='references'then return reader end
   if mode=='throw'then return function()error('PRIVATE_SCOPE')end elseif mode=='malformed'then return function()return{}end end
   local opaque={};f.env.canaccessvalue=function(v)return v~=opaque end;return function()return opaque,opaque,opaque,opaque end
  end});local report=complete(b,t);has(report,'Validation.references.observe | unavailable:');private(report)
 end
end)
test('near and oversized reports preserve old bytes and bound only the appended scope section',function()
 for _,value in ipairs({1e180,1e270,1e308})do
  local function scenario(old)local _,a,s=fixture({old=old});cost(s);s.rows[s.hot]={{0,0,0},{value,value,3}};return complete(a,s)end
  local before=scenario(true);local text=scenario(false);if #before>=15999 then assert(text==before)else assert(text:sub(1,#before)==before and #text<16000)end
 end
end)
test('four strict whole-module inverses restore actual baseline and reject unrelated or old input',function()
 for _,path in ipairs({'Core/rotation_references.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Diagnostics/cpu.lua'})do
  local source=read(path);if path~='Diagnostics/cpu.lua' then source=dofile('tests/fixtures/restore_revision_changes.lua')(source,path) end;local old=restore(source,path);assert(old==restore(nil,path,true)and old~=source)
  assert(not pcall(restore,source..'\n-- unrelated',path));assert(not pcall(restore,old,path));assert(not pcall(restore,source..source,path))
 end
end)
finish()
