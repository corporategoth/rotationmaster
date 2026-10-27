local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
-- Reuse the actual startup loader; only native APIs and the raw native global
-- shape are supplied here. Every owner/handoff/main/CPU module is real.
local startup=assert(read('tests/startup.lua'):match('(local function fixture%(modern, absentThreat%).-)\nlocal function initialize'))
startup=startup:gsub('fixture%(modern, absentThreat%)','fixture(modern, absentThreat, configure, noCPU)',1)
startup=startup:gsub('    env%._G = env','    env._G = env\n    for _,key in ipairs({"type","pairs","ipairs","getfenv","getmetatable","rawget","rawequal","next","math","table","string","pcall","tostring"}) do env[key]=_G[key] end',1)
local loadLine="    load('Data/plain.lua');load('Data/rotation_revision.lua');load('Data/tags.lua');load('Data/rotation_tree.lua');load('Data/validation.lua');load('Core/rotation_sequence.lua');load('Core/rotation_selection.lua')"
local first,last=assert(startup:find(loadLine,1,true));startup=startup:sub(1,first-1)..[[    if not noCPU then load('Diagnostics/cpu.lua') end
    if configure then configure('plain',env,addon) end
    load('Data/plain.lua');load('Data/rotation_revision.lua');load('Data/tags.lua')
    if configure then configure('tree',env,addon) end
    load('Data/rotation_tree.lua');load('Data/validation.lua')
    if configure then configure('sequence',env,addon) end
    load('Core/rotation_sequence.lua');load('Core/rotation_selection.lua')]]..startup:sub(last+1)
local make=assert(loadstring(startup..'\nreturn fixture','@diagnostic-startup-fixture'))()
local function fixture(configure,noCPU)
 local e,a,load=make(false,false,configure,noCPU);local s={now=100,queries={},native={},timers={},probes=0}
 a.db={profile={poll=.1,live_config_update=.2},global={}}
 local installer=a.BindCPUExecutionIndexDiagnostic
 if installer then a.BindCPUExecutionIndexDiagnostic=function(self,provider)
  s.provider=provider
  return installer(self,function()s.probes=s.probes+1;if s.override then return s.override() end;return provider()end)
 end end
 if configure then configure('main',e,a)end
 load('main.lua')
 e.GetTimePreciseSec=function()s.native[#s.native+1]='clock';return s.now end
 e.GetCVar=function()s.native[#s.native+1]='cvar';return s.enabled or '1'end
 e.UpdateAddOnCPUUsage=function()s.native[#s.native+1]='update'end
 e.GetAddOnCPUUsage=function()s.native[#s.native+1]='total';return s.now end
 e.GetFunctionCPUUsage=function(fn,inc)s.queries[#s.queries+1]={fn,inc};s.native[#s.native+1]=inc and 'inclusive' or 'exclusive';return 0,0 end
 function a:ScheduleTimer(callback,delay)local token={callback=callback,delay=delay};s.timers[#s.timers+1]=token;return token end
 function a:CancelTimer(token)token.cancelled=true end
 function s:complete()self.now=110;self.timers[#self.timers].callback();return a:GetCPUProfileReport()end
 return e,a,s
end
local function contains(text,part)assert(type(text)=='string' and text:find(part,1,true),'report missing '..part)end
local function private(text)for _,secret in ipairs({'SECRET_SOURCE','0x','private-owner','function:','table:'})do assert(not text:find(secret,1,true),'private diagnostic data leaked')end end
local function probe(s)assert(type(s.provider)=='function','private diagnostic handoff missing');return s.provider()end

test('actual native owner chain reports start/end captured facts in the copyable CPU report only',function()
 local _,a,s=fixture();assert(s.probes==0);assert(a.BindCPUExecutionIndexDiagnostic==nil and a.BindRotationSequenceReader==nil and a.BindRotationExecutionIndexReader==nil and a.BindRotationPortableReader==nil)
 assert(a:StartCPUProfile());assert(s.probes==1);a:GetCPUProfileReport();assert(s.probes==1)
 local text=s:complete();contains(text,'Execution index proof start: main=ready; sequence=ready; portable=ready; index=ready; parser-match=1; parser-sub=1');contains(text,'Execution index proof end: main=ready; sequence=ready; portable=ready; index=ready; parser-match=1; parser-sub=1');assert(s.probes==2 and #text<16000);private(text)
 local calls=#s.queries;a:GetCPUProfileReport();s.timers[1].callback();assert(s.probes==2 and #s.queries==calls)
end)
test('distinct standard string library captures report callable parser operations',function()
 local _,a,s=fixture(function(phase,e)if phase=='tree'then local clone={};for k,v in pairs(string)do clone[k]=v end;e.string=clone end end)
 local status=probe(s);assert(status.index.reason=='ready' and status.index.parserMatch==true and status.portable.parserSub==true)
 assert(a:StartCPUProfile());local text=s:complete();contains(text,'index=ready');contains(text,'parser-match=1; parser-sub=1');private(text)
end)
test('source status uses raw slots without invoking inherited protected getters or profile defaults',function()
 for _,key in ipairs({'type','pairs','ipairs','getmetatable','getfenv','math','table'})do
  local e,a,s=fixture();local native=e[key];local getters=0;e[key]=nil;setmetatable(e,{__metatable={__index={}},__index=function(_,k)if k==key then getters=getters+1;return native end;return _G[k]end})
  local status=probe(s);assert(getters==0,'diagnostic invoked inherited '..key);assert(status.portable.reason=='raw-'..key and status.portable.raw[key]==false)
  e[key]=false;status=probe(s);assert(getters==0 and status.portable.raw[key]==false)
 end
 local _,a,s=fixture();local getters=0;a.db=setmetatable({},{__index=function()getters=getters+1;return {private_owner='SECRET_SOURCE'}end});local status=probe(s);assert(status.sequence.reason=='profile' and getters==0)
end)
test('public environment changes remain observable and native string lookup is unconsumed',function()
 local _,a,s=fixture();local fn=a.EvaluateRotationSequence;local env=getfenv(fn);setfenv(fn,setmetatable({},{__index=env}));local status=probe(s);assert(status.sequence.reason=='public-env')
 local mt=getmetatable('');local old=rawget(mt,'__index');local getters=0
 local ok,why=pcall(function()
  mt.__index=function(_,key)getters=getters+1;return old[key]end
  local _,_,state=fixture();getters=0;local result=probe(state);assert(getters==0 and result.index.reason=='ready' and result.index.parserMatch==true and result.portable.parserSub==true)
 end)
 mt.__index=old;assert(ok,why)
end)
test('diagnostic failures and hostile returned fields are fixed source-free unavailable states',function()
 for _,mode in ipairs({'throw','hostile'})do local _,a,s=fixture();assert(type(s.provider)=='function','private diagnostic handoff missing')
  s.override=function()if mode=='throw'then error('SECRET_SOURCE private-owner')end;return setmetatable({main={reason='SECRET_SOURCE'},sequence={reason={}},portable={raw=setmetatable({},{__index=function()error('SECRET_SOURCE')end})},index={reason='ready',capturedIndex='SECRET_SOURCE',currentIndex={}}},{__index=function()error('SECRET_SOURCE')end})end
  assert(a:StartCPUProfile());local text=s:complete();contains(text,mode=='throw' and 'probe-unavailable' or 'unavailable');private(text);assert(#text<16000)
 end
end)
test('missing sampler or stale handoff is safe and capture cancellation never resamples',function()
 local _,a=fixture(nil,true);assert(a.BindCPUExecutionIndexDiagnostic==nil)
 local _,a,s=fixture();s.enabled='0';assert(not a:StartCPUProfile() and s.probes==0);s.enabled='1';assert(a:StartCPUProfile());local stale=s.timers[1];assert(s.probes==1);assert(not a:StartCPUProfile() and s.probes==1);a:CancelCPUProfile();stale.callback();a:GetCPUProfileReport();assert(s.probes==1)
 assert(a:StartCPUProfile());stale.callback();assert(s.probes==2);s:complete();assert(s.probes==3)
 local _,a,s=fixture(function(phase,_,owner)if phase=='main'then owner.BindRotationSequenceReader=nil end end);assert(a:StartCPUProfile());contains(s:complete(),'main=unbound')
end)
test('synchronous owned timer completion keeps the preexisting scheduler success contract',function()
 local _,a,s=fixture();local completed
 a.OnCPUProfileFinished=function(_,text,status)completed={text,status}end
 function a:ScheduleTimer(callback) s.now=110;callback();return {}end
 local ok,why=a:StartCPUProfile();assert(ok,why);assert(completed and completed[2]=='complete');assert(s.probes==1,'retired synchronous capture sampled a second start boundary');private(completed[1])
end)
test('diagnostic snapshots preserve old report bytes and native query pointer/mode order',function()
 local runs={}
 for _,disabled in ipairs({false,true})do local _,a,s=fixture(function(phase,_,owner)if disabled and phase=='main'then owner.BindCPUExecutionIndexDiagnostic=nil end end)
  assert(a:StartCPUProfile());local text=s:complete();runs[#runs+1]={text=text,queries=s.queries,native=table.concat(s.native,'|')}
 end
 local first=assert(runs[1].text:find('\nExecution index proof start:',1,true));local second=assert(runs[2].text:find('\nExecution index proof start:',1,true));assert(runs[1].text:sub(1,first-1)==runs[2].text:sub(1,second-1),'existing report prefix changed')
 assert(runs[1].native==runs[2].native and #runs[1].queries==#runs[2].queries,'diagnostic changed native query order/count')
 for i,row in ipairs(runs[1].queries)do assert(row[2]==runs[2].queries[i][2])end
end)
test('failed ownership projections never execute public data helpers, gameplay queries, or metatable callbacks',function()
 local e,a,s=fixture();local calls=0
 local function forbidden()calls=calls+1;error('SECRET_SOURCE unexpected execution')end
 a.RotationData.CheckPortable=forbidden;a.RotationData.IndexRotationSteps=forbidden;a.EvaluateRotationSequence=forbidden
 for _,name in ipairs({'GetTime','GetBuildInfo','GetLocale','UnitClass','UnitExists'})do e[name]=forbidden end
 local status=probe(s);assert(calls==0 and status.sequence.reason=='method' and status.portable.reason=='method' and status.index.reason=='portable-proof')
 local e,a,s=fixture();local mt=getmetatable('');local old=rawget(mt,'__index');local fake={}
 local ok,why=pcall(function() mt.__index=fake;local status=probe(s);assert(status.index.reason=='ready' and status.index.parserMatch==true)end)
 mt.__index=old;assert(ok,why)
end)
test('near-limit diagnostics append only complete bounded snapshots or a fixed omission notice',function()
 for _,exponent in ipairs({150,160,180,190,200})do
  local e,a,s=fixture();a.BuiltinSourceCatalog={conditions={}};a.conditionDefinitions={}
  for i=1,30 do local key=string.format('HOT_%02d',i);a.BuiltinSourceCatalog.conditions[key]={};a.conditionDefinitions[key]={evaluate=function()end}end
  local phase=false;e.GetFunctionCPUUsage=function()return phase and 10^exponent or 0,phase and 1 or 0 end
  assert(a:StartCPUProfile());phase=true;local text=s:complete();assert(#text<16000,'bounded old report grew beyond limit')
  local first=text:find('Execution index proof start:',1,true)
  if first then contains(text,'Execution index proof end:')else
   local notice='Execution index proof omitted to keep report bounded.'
   assert(text:find(notice,1,true) or #text+1+#notice>=16000,'omission notice missing despite sufficient budget')
  end
  private(text)
 end
end)
test('new diagnostic report bytes are bounded without truncating an oversized old report',function()
 local captures={}
 for _,disabled in ipairs({false,true})do
  local _,a,s=fixture(function(phase,_,owner)if disabled and phase=='main'then owner.BindCPUExecutionIndexDiagnostic=nil end end)
  a.BuiltinSourceCatalog={conditions={}};a.conditionDefinitions={}
  for i=1,30 do local key=string.format('HOT_%02d',i);local fn=function()end;a.BuiltinSourceCatalog.conditions[key]={};a.conditionDefinitions[key]={evaluate=fn}end
  s.scale=1e308
  -- Finite large native counters produce a valid oversized legacy report.
  local native=s.queries;local phase=false
  local e=getfenv(a.StartCPUProfile);e.GetFunctionCPUUsage=function(fn,inc)native[#native+1]={fn,inc};return phase and s.scale or 0,phase and 1 or 0 end
  assert(a:StartCPUProfile());phase=true;local text=s:complete();assert(#text>16000);assert(not text:find('Execution index proof',1,true));captures[#captures+1]=text
 end
 assert(captures[1]==captures[2],'oversized old report grew or changed')
end)
finish()
