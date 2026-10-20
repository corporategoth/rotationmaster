local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
-- Replay the exact pre-inclusive module to compare every old report byte and
-- query boundary. The new report block alone is removed; unrelated edits fail.
local function loadHistoricalCPU(f)
 local h=assert(io.open('Diagnostics/cpu.lua'));local source=h:read('*a');h:close()
 local first=source:find('   -- BEGIN INCLUSIVE CPU SCOPES\n',1,true)
 if first then
  local marker='   -- END INCLUSIVE CPU SCOPES\n';local last=assert(source:find(marker,first,true))
  assert(not source:find('   -- BEGIN INCLUSIVE CPU SCOPES\n',first+1,true))
  source=source:sub(1,first-1)..source:sub(last+#marker)
 end
 local hash=0;for i=1,#source do hash=(hash*33+source:byte(i))%4294967296 end
 assert(#source==16258 and string.format('%08x',hash)=='69259678','unrelated CPU module baseline change')
 local chunk=assert(loadstring(source,'@Diagnostics/cpu.lua'));setfenv(chunk,f.env);chunk('rotationmaster',f.addon)
end
local function fixture(historical)
 local f=F.new();local a,e=f.addon,f.env;local s={now=100,enabled='1',phase='start',rows={},timers={},queries={},total={10,50},updates=0,native={},fnIDs={},fnCount=0}
 a.EvaluateNextAction=function() end;a.EvaluateNextActionInternal=a.EvaluateNextAction;s.hot=a.EvaluateNextAction
 a.conditionDefinitions={SAFE_TAG={valid=function() return true end,evaluate=function() return true end},ROW_OWNER_PRIVATE_TEST={customCode=true,code='SECRET_SOURCE_TEXT',evaluate=function() end,valid=function() end}}
 a.BuiltinSourceCatalog={conditions={SAFE_TAG={}}};a.db.profile.poll=.1;a.db.profile.live_config_update=.2
 e.GetTimePreciseSec=function(...) s.native[#s.native+1]='clock';assert(select('#',...)==0);return s.now end
 e.GetCVar=function(...) s.native[#s.native+1]='cvar';assert(select('#',...)==1 and (...)=='scriptProfile');return s.enabled end
 e.UpdateAddOnCPUUsage=function(...) s.native[#s.native+1]='update';assert(select('#',...)==0);s.updates=s.updates+1;if s.throwUpdate then error('SECRET_SOURCE_TEXT') end end
 e.GetAddOnCPUUsage=function(...) s.native[#s.native+1]='total';assert(select('#',...)==1 and (...)=='rotationmaster');if s.throwTotal then error('SECRET_SOURCE_TEXT') end;return s.total[s.phase=='start' and 1 or 2] end
 e.GetFunctionCPUUsage=function(...) assert(select('#',...)==2);local fn,inclusive=...;assert(type(fn)=='function' and type(inclusive)=='boolean');s.queries[#s.queries+1]={fn,inclusive};if not s.fnIDs[fn]then s.fnCount=s.fnCount+1;s.fnIDs[fn]=s.fnCount end;s.native[#s.native+1]='function:'..s.fnIDs[fn]..':'..tostring(inclusive)
  if s.throwFunction==fn then error('SECRET_SOURCE_TEXT') end
  local row=s.rows[fn];if not row then return 0,0 end;local value=row[s.phase=='start' and 1 or 2];return value[inclusive and 2 or 1],value[3],nil
 end
 e.InCombatLockdown=function() return s.combat or false end
 e.SetCVar=function() error('profiler wrote CVar') end;e.ResetCPUUsage=function() error('profiler reset shared counters') end;e.hooksecurefunc=function() error('profiler installed global hook') end
 function a:ScheduleTimer(callback,delay) local token={callback=callback,delay=delay};s.timers[#s.timers+1]=token;if s.scheduleError then error('SECRET_SOURCE_TEXT') end;return token end
 function a:CancelTimer(token) token.cancelled=true end
 function s:complete() self.now=self.now+10;self.phase='finish';self.timers[#self.timers].callback() end
 if historical then loadHistoricalCPU(f)else local file=io.open('Diagnostics/cpu.lua');if file then file:close();f.load('Diagnostics/cpu.lua')end end
 assert(type(a.StartCPUProfile)=='function','native CPU profiler API absent')
 return f,a,s
end
local function contains(text,part) assert(type(text)=='string' and text:find(part,1,true),'report missing '..part..': '..tostring(text)) end
local function private(text) for _,secret in ipairs({'SECRET_SOURCE_TEXT','ROW_OWNER_PRIVATE_TEST','Player-1234','rotation:private-owner'}) do assert(not text:find(secret,1,true),'profile leaked source or owner values') end end
local function rejected(a,why,duration) local ok,reason=a:StartCPUProfile(duration);assert(ok==false and reason==why,tostring(reason)..' expected '..why);assert(not a:IsCPUProfileRunning()) end

test('module is idle and refuses disabled profiling without changing global counters or functions',function()
 local f,a,s=fixture();assert(#s.timers==0 and #s.queries==0 and s.updates==0 and not a:IsCPUProfileRunning());local text,why=a:GetCPUProfileReport();assert(text==nil and why=='not-captured');local hot=a.EvaluateNextAction
 s.enabled='0';rejected(a,'script-profile-disabled');assert(a.EvaluateNextAction==hot and #s.timers==0 and #s.queries==0 and s.updates==0)
 f.env.GetFunctionCPUUsage=nil;s.enabled='1';rejected(a,'missing-function-cpu-api');assert(#s.timers==0)
end)
test('namespaced addon counters work without globals and selected API changes invalidate the boundary',function()
 local f,a,s=fixture();f.env.C_AddOns={GetAddOnCPUUsage=f.env.GetAddOnCPUUsage,UpdateAddOnCPUUsage=f.env.UpdateAddOnCPUUsage};f.env.GetAddOnCPUUsage=nil;f.env.UpdateAddOnCPUUsage=nil;assert(a:StartCPUProfile());s:complete();contains(a:GetCPUProfileReport(),'addon CPU=40.000 ms')
 local f,a,s=fixture();f.env.C_AddOns={GetAddOnCPUUsage=f.env.GetAddOnCPUUsage,UpdateAddOnCPUUsage=f.env.UpdateAddOnCPUUsage};assert(a:StartCPUProfile());f.env.C_AddOns.GetAddOnCPUUsage=function() return 50 end;s:complete();contains(a:GetCPUProfileReport(),'invalid');contains(a:GetCPUProfileReport(),'profiling-api-changed')
end)
test('missing malformed restricted and throwing prerequisites never schedule work',function()
 for _,mode in ipairs({'clock-missing','clock-throw','clock-restricted','total-restricted','cvar-nil','cvar-restricted','all-function-invalid','timer-missing','addon-api-missing'}) do
  local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
  local expected
  if mode=='clock-missing' then f.env.GetTimePreciseSec=nil;f.env.GetTime=nil;expected='missing-clock-api'
  elseif mode=='clock-throw' then f.env.GetTimePreciseSec=function() error('SECRET_SOURCE_TEXT') end;expected='clock-error'
  elseif mode=='clock-restricted' then s.now=opaque;expected='invalid-clock'
  elseif mode=='total-restricted' then s.total[1]=opaque;expected='invalid-addon-cpu-counter'
  elseif mode=='cvar-nil' then s.enabled=nil;expected='invalid-script-profile-result'
  elseif mode=='cvar-restricted' then s.enabled=opaque;expected='restricted-script-profile'
  elseif mode=='all-function-invalid' then f.env.GetFunctionCPUUsage=function() return 0,nil end;expected='function-cpu-unavailable'
  elseif mode=='timer-missing' then a.CancelTimer=nil;expected='missing-timer-api'
  else f.env.GetAddOnCPUUsage=nil;expected='missing-addon-cpu-api' end
  rejected(a,expected);assert(#s.timers==0)
 end
end)
test('capture duration is bounded and one native cumulative snapshot is taken per exact deduplicated pointer and mode',function()
 local _,a,s=fixture();for _,duration in ipairs({0,-1,61,math.huge,0/0,'10',{},false}) do rejected(a,'invalid-duration',duration) end
 assert(a:StartCPUProfile());assert(s.timers[1].delay==10 and s.updates==1 and a:IsCPUProfileRunning());contains(a:GetCPUProfileReport(),'running');local ok,why=a:StartCPUProfile();assert(not ok and why=='already-running' and #s.timers==1)
 local seen={};for _,q in ipairs(s.queries) do local key=q[2] and 'inclusive' or 'exclusive';seen[q[1]]=seen[q[1]] or {};assert(not seen[q[1]][key],'pointer was queried through an alias twice');seen[q[1]][key]=true end;assert(seen[s.hot].inclusive and seen[s.hot].exclusive)
end)
test('report computes hand checked exclusive inclusive calls and addon deltas and captures only boundary state',function()
 local _,a,s=fixture();s.rows[s.hot]={{8,20,10},{20,50,16}};local shown=true;a.configWindow={frame={IsShown=function() return shown end}};assert(a:StartCPUProfile());shown=false;s.combat=true;a.db.profile.poll=.05;a.db.profile.live_config_update=.4;local callback
 a.OnCPUProfileFinished=function(_,text,status) callback={text,status} end;s:complete();assert(not a:IsCPUProfileRunning() and s.updates==2);local text=a:GetCPUProfileReport();contains(text,'exclusive=12.000 ms');contains(text,'inclusive=30.000 ms');contains(text,'calls=6');contains(text,'mean=2.000 ms');contains(text,'addon CPU=40.000 ms');contains(text,'start config=shown combat=false poll=0.1');contains(text,'end config=hidden combat=true poll=0.05');contains(text,'overlap');assert(callback[1]==text and callback[2]=='complete');private(text)
end)
test('cancellation retires only the owned capture and stale timers cannot finish a later capture',function()
 local _,a,s=fixture();assert(a:StartCPUProfile(3));local old=s.timers[1];assert(a:CancelCPUProfile() and old.cancelled and not a:IsCPUProfileRunning());contains(a:GetCPUProfileReport(),'cancelled');assert(a:StartCPUProfile(5));old.callback();assert(a:IsCPUProfileRunning());s:complete();assert(not a:IsCPUProfileRunning());local ok,why=a:CancelCPUProfile();assert(not ok and why=='not-running')
end)
test('addon disable retires the capture before embedded timer cleanup and inactive disable does no work',function()
 local _,a,s=fixture();assert(type(a.OnDisable)=='function','CPU capture has no addon disable lifecycle callback');a:OnDisable();assert(#s.timers==0 and #s.queries==0 and s.updates==0)
 assert(a:StartCPUProfile());local old=s.timers[1];local queries=#s.queries;a:OnDisable();assert(not a:IsCPUProfileRunning() and old.cancelled);contains(a:GetCPUProfileReport(),'cancelled');old.callback();assert(#s.queries==queries)
 assert(a:StartCPUProfile());old.callback();assert(a:IsCPUProfileRunning());s:complete();local report=a:GetCPUProfileReport();queries=#s.queries;a:OnDisable();assert(a:GetCPUProfileReport()==report and #s.queries==queries)
end)
test('native clock total and profile failures invalidate a capture honestly without error text or idle retries',function()
 for _,mode in ipairs({'clock-back','clock-nil','clock-infinite','total-back','total-error','profile-off','update-error','clock-replaced'}) do
  local f,a,s=fixture();assert(a:StartCPUProfile());s.phase='finish';s.now=110
  if mode=='clock-back' then s.now=99 elseif mode=='clock-nil' then s.now=nil elseif mode=='clock-infinite' then s.now=math.huge elseif mode=='total-back' then s.total[2]=9 elseif mode=='total-error' then s.throwTotal=true elseif mode=='profile-off' then s.enabled='0' elseif mode=='update-error' then s.throwUpdate=true else f.env.GetTimePreciseSec=function() return 110 end end
  s.timers[1].callback();assert(not a:IsCPUProfileRunning());local text=a:GetCPUProfileReport();contains(text,'invalid');private(text);assert(#s.timers==1)
 end
end)
test('invalid or replaced function observations are unavailable rows rather than fabricated timings',function()
 for _,mode in ipairs({'reset','nil','nan','negative','fractional-calls','throw','replaced','restricted'}) do
  local f,a,s=fixture();s.rows[s.hot]={{8,20,10},{20,50,16}};assert(a:StartCPUProfile())
  if mode=='reset' then s.rows[s.hot][2][1]=7 elseif mode=='nil' then s.rows[s.hot][2][1]=nil elseif mode=='nan' then s.rows[s.hot][2][2]=0/0 elseif mode=='negative' then s.rows[s.hot][2][3]=-1 elseif mode=='fractional-calls' then s.rows[s.hot][2][3]=16.5 elseif mode=='throw' then s.throwFunction=s.hot elseif mode=='replaced' then a.EvaluateNextAction=function() end else local opaque={};s.rows[s.hot][2][1]=opaque;f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end end
  s:complete();local text=a:GetCPUProfileReport();contains(text,'unavailable');contains(text,'Runtime.EvaluateNextAction');assert(not text:find('exclusive=12.000 ms',1,true));private(text)
 end
end)
test('namespace and condition replacement invalidate the originally selected live reference',function()
 for _,kind in ipairs({'platform','condition'}) do local _,a,s=fixture();local fn=kind=='platform' and a.Platform.GetClientInfo or a.conditionDefinitions.SAFE_TAG.evaluate;s.rows[fn]={{1,1,1},{10,10,2}};assert(a:StartCPUProfile())
  if kind=='platform' then a.Platform={GetClientInfo=function() end} else a.conditionDefinitions.SAFE_TAG={evaluate=function() end} end
  s:complete();local text=a:GetCPUProfileReport();contains(text,(kind=='platform' and 'Platform.GetClientInfo' or 'Condition.SAFE_TAG.evaluate')..' | unavailable: function-replaced')
 end
end)
test('prerequisite and baseline errors create no timer and can recover on a subsequent request',function()
 for _,mode in ipairs({'clock','total','update','cvar','scheduler'}) do
  local f,a,s=fixture();if mode=='clock' then s.now=0/0 elseif mode=='total' then s.total[1]=-1 elseif mode=='update' then s.throwUpdate=true elseif mode=='cvar' then f.env.GetCVar=function() error('SECRET_SOURCE_TEXT') end else s.scheduleError=true end
  local ok,why=a:StartCPUProfile();assert(ok==false and type(why)=='string' and not a:IsCPUProfileRunning());private(why)
 end
 local _,a,s=fixture();s.enabled='0';assert(not a:StartCPUProfile());s.enabled='1';assert(a:StartCPUProfile());s:complete();contains(a:GetCPUProfileReport(),'complete')
end)
test('derived CPU rates stay finite and report explains selected coverage and unequal snapshot boundaries',function()
 local _,a,s=fixture();s.now=0;assert(a:StartCPUProfile());s.now=1e-320;s.phase='finish';s.timers[1].callback();contains(a:GetCPUProfileReport(),'invalid')
 local _,a,s=fixture();assert(a:StartCPUProfile());s:complete();local text=a:GetCPUProfileReport();contains(text,'selected coverage');contains(text,'snapshot boundaries');contains(text,'overhead')
end)
test('top report ranks measured function costs and clips lower rows without losing unavailable notices',function()
 local _,a,s=fixture();for i=1,30 do local key=string.format('PROFILE_TEST_%02d',i);local fn=function() end;a.BuiltinSourceCatalog.conditions[key]={};a.conditionDefinitions[key]={evaluate=fn};s.rows[fn]={{0,0,0},{i,i*2,i}} end
 assert(a:StartCPUProfile());s:complete();local text=a:GetCPUProfileReport();local high=assert(text:find('Condition.PROFILE_TEST_30.evaluate',1,true));local low=assert(text:find('Condition.PROFILE_TEST_11.evaluate',1,true));assert(high<low and not text:find('Condition.PROFILE_TEST_10.evaluate',1,true));contains(text,'mean=1.000 ms')
end)
test('selection and report stay bounded with anonymous custom callbacks and hostile completion notifications',function()
 local _,a,s=fixture();for i=1,1000 do a.Platform['Probe'..i]=function() end;a.conditionDefinitions['PRIVATE_OWNER_'..i]={customCode=true,evaluate=function() end,valid=function() end} end
 local before={};for k,v in pairs(a.Platform) do before[k]=v end;a.OnCPUProfileFinished=function() error('SECRET_SOURCE_TEXT') end;assert(a:StartCPUProfile());assert(#s.queries<=768);s:complete();local text=a:GetCPUProfileReport();private(text);assert(not text:find('PRIVATE_OWNER_',1,true));assert(#text<16000);for k,v in pairs(before) do assert(a.Platform[k]==v) end;local queries=#s.queries;s.timers[1].callback();assert(#s.queries==queries and not a:IsCPUProfileRunning())
end)
test('structural validator call counts remain visible below the top timing cutoff including zero',function()
 local _,a,s=fixture();local envelope=function() end;local body=function() end;local index=function() end
 a.RotationData={ValidateEnvelope=envelope,ValidateBody=body,IndexRotationSteps=index}
 s.rows[envelope]={{1,2,10},{1,2,10}};s.rows[body]={{1,2,10},{1,2,13}};s.rows[index]={{0,0,2},{0,0,2}}
 for i=1,30 do local key='HOT_'..i;local fn=function() end;a.BuiltinSourceCatalog.conditions[key]={};a.conditionDefinitions[key]={evaluate=fn};s.rows[fn]={{0,0,0},{i,i*2,i}} end
 assert(a:StartCPUProfile());s:complete();local text=a:GetCPUProfileReport()
 contains(text,'Structural validation calls: ValidateEnvelope=0; ValidateBody=3')
 contains(text,'Execution indexing calls: IndexRotationSteps=0')
 assert(not text:find('RotationData.ValidateEnvelope |',1,true),'zero validator unexpectedly in top timings')
end)
test('structural validator summaries preserve unavailable observations and exact pointer deduplication',function()
 for _,mode in ipairs({'missing','replaced','throw','alias'}) do
  local _,a,s=fixture();local fn=function() end;a.RotationData={ValidateEnvelope=fn,ValidateBody=mode=='alias' and fn or function() end,IndexRotationSteps=fn}
  s.rows[fn]={{1,2,10},{2,3,14}};if mode=='missing' then a.RotationData.ValidateEnvelope=nil end
  assert(a:StartCPUProfile());if mode=='replaced' then a.RotationData.ValidateEnvelope=function() end elseif mode=='throw' then s.throwFunction=fn end
  local count=0;for _,q in ipairs(s.queries) do if q[1]==fn then count=count+1 end end
  if mode=='alias' then assert(count==2,'aliased validators queried twice') end
  s:complete();local text=a:GetCPUProfileReport()
  contains(text,'Structural validation calls: ValidateEnvelope='..(mode=='alias' and '4' or 'unavailable'))
  contains(text,'Execution indexing calls: IndexRotationSteps='..((mode=='alias' or mode=='missing') and '4' or 'unavailable'))
  if mode=='alias' then contains(text,'ValidateBody=4');contains(text,'shared functions overlap') end
  private(text)
 end
end)

local inclusiveHeading='Inclusive scopes (top 10; includes descendants; overlapping, not additive):'
local function inclusiveSection(text)
 local first=assert(text:find(inclusiveHeading,1,true),'inclusive scope section absent')
 return text:sub(first+#inclusiveHeading+1),text:sub(1,first-2)
end
local function measuredRows(a,s,metric)
 local parent=function()end;a.GetRotationValidationStamp=parent;a.GetRotationValidationOptions=parent
 s.rows[parent]={{0,0,0},{.01,87,100}}
 for i=1,31 do local key=string.format('HOT_%02d',i);local fn=function()end;a.BuiltinSourceCatalog.conditions[key]={};a.conditionDefinitions[key]={evaluate=fn};s.rows[fn]={{0,0,0},{metric or i,metric or i+1,1}}end
 return parent
end
local function compareCapture(metric,replaceAlias)
 local captures={}
 for _,historical in ipairs({true,false})do
  local _,a,s=fixture(historical);measuredRows(a,s,metric);assert(a:StartCPUProfile())
  if replaceAlias then a.GetRotationValidationOptions=function()end end
  s:complete();local report=a:GetCPUProfileReport();local count=#s.native
  a:GetCPUProfileReport();a:IsCPUProfileRunning();s.timers[1].callback();assert(#s.native==count,'idle or stale report queried native API')
  captures[#captures+1]={text=report,native=table.concat(s.native,'|'),queries=#s.queries}
 end
 assert(captures[1].native==captures[2].native and captures[1].queries==captures[2].queries,'inclusive report changed native query order/count')
 return captures[1].text,captures[2].text
end
test('inclusive scopes expose a hidden expensive parent using the same aliased snapshots and unchanged exclusive report',function()
 local old,new=compareCapture();local section,prefix=inclusiveSection(new);assert(prefix==old,'old report bytes changed')
 assert(not old:find('Runtime.GetRotationValidationStamp |',1,true),'parent is not hidden in exclusive baseline')
 contains(section,'Runtime.GetRotationValidationStamp | inclusive=87.000 ms | exclusive=0.010 ms | calls=100')
 assert(section:find('Runtime.GetRotationValidationStamp |',1,true)<section:find('Condition.HOT_31.evaluate',1,true))
 assert(not section:find('Runtime.GetRotationValidationOptions',1,true),'alias created another scope')
 local _,rows=section:gsub(' | inclusive=','');assert(rows==10 and #new<16000);private(new)
end)
test('inclusive scope ties rank by exclusive cost then existing safe label',function()
 local _,a,s=fixture()
 for _,row in ipairs({{'TIE_A',2},{'TIE_B',2},{'TIE_C',3}})do local fn=function()end;a.BuiltinSourceCatalog.conditions[row[1]]={};a.conditionDefinitions[row[1]]={evaluate=fn};s.rows[fn]={{0,0,0},{row[2],100,1}}end
 assert(a:StartCPUProfile());s:complete();local section=inclusiveSection(a:GetCPUProfileReport())
 assert(section:find('Condition.TIE_C.evaluate',1,true)<section:find('Condition.TIE_A.evaluate',1,true))
 assert(section:find('Condition.TIE_A.evaluate',1,true)<section:find('Condition.TIE_B.evaluate',1,true))
end)
test('inclusive scopes omit unavailable alias rows and retain every old notice before the new heading',function()
 local old,new=compareCapture(nil,true);local section,prefix=inclusiveSection(new);assert(prefix==old)
 contains(old,'Runtime.GetRotationValidationStamp | unavailable: function-replaced')
 assert(not section:find('Runtime.GetRotationValidationStamp',1,true));private(new)
end)
test('inclusive append clips only new rows below16000 bytes while preserving near-limit old report',function()
 local old,new=compareCapture(1e200);local section,prefix=inclusiveSection(new)
 assert(prefix==old and #old<16000 and #new<16000 and #new>#old)
 contains(section,'Additional inclusive scopes omitted to keep report bounded.')
 local _,rows=section:gsub(' | inclusive=','');assert(rows>0 and rows<10,'near-bound control did not clip new rows')
end)
test('inclusive report leaves an already oversized accepted finite baseline byte-exact without growth',function()
 local old,new=compareCapture(1e308);assert(#old>=16000,'oversized existing report control absent')
 assert(new==old and not new:find(inclusiveHeading,1,true),'new section grew or truncated old oversized report')
end)

finish()
