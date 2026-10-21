-- Explicit capability probe; native APIs modeled, real UI action/report path.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function pack(...)return{n=select('#',...),...}end
local function fixture(before)
 local f=F.new();local a,e=f.addon,f.env;local shown,printed={},{};local calls={enabled=0,measure=0,event=0,forbidden=0};local running=false
 a.IsCPUProfileRunning=function()return running end
 a.GetCPUProfileReport=function()return'unchanged CPU report bytes' end
 a.ShowConditionText=function(_,text,title)shown[#shown+1]={text=text,title=title}end
 a.print=function(_,message)printed[#printed+1]=message end
 for _,name in ipairs({'StartCPUProfile','CancelCPUProfile','ScheduleTimer','ScheduleRepeatingTimer','CancelTimer'})do a[name]=function()calls.forbidden=calls.forbidden+1;error('forbidden diagnostic mutation')end end
 for _,name in ipairs({'ResetCPUUsage','UpdateAddOnCPUUsage','GetFunctionCPUUsage','GetAddOnCPUUsage','GetScriptCPUUsage'})do e[name]=function()calls.forbidden=calls.forbidden+1;error('forbidden counter API')end end
 if before then before(f,a,calls)end
 f.load('UI/cpu_profile.lua')
 return f,a,calls,shown,printed,function(v)running=v end
end
local function good(calls)
 local measuring=false
 return{
  IsEnabled=function(...)assert(select('#',...)==0);calls.enabled=calls.enabled+1;return true end,
  MeasureCall=function(...)
   assert(select('#',...)==4);local fn,word,empty,flag=...;assert(type(fn)=='function'and word=='RM'and empty==nil and flag==false)
   calls.measure=calls.measure+1;measuring=true;local result=pack(fn(word,empty,flag));measuring=false
   assert(result.n==3 and result[1]=='RM'and result[2]==nil and result[3]==false)
   return{elapsedMilliseconds=.125,allocatedBytes=128,deallocatedBytes=0,events={{name='RM:probe'}}},unpack(result,1,result.n)
  end,
  AddMeasuredCallEvent=function(...)assert(measuring and select('#',...)==1 and(...)=='RM:probe');calls.event=calls.event+1 end,
 }
end
local function report(a,shown)
 local ok=a:RunCPUProfileAction('probe');assert(ok and#shown>0,'probe did not open its copyable report')
 local r=shown[#shown];assert(r.title=='Native profiler probe');assert(r.text:lower():find('capability',1,true)and r.text:find('unverified',1,true));assert(not r.text:find('PRIVATE',1,true)and not r.text:find('0x',1,true));return r.text
end
local function has(text,needle)assert(text:find(needle,1,true),'missing '..needle..' in '..text)end

test('module load idle and existing CPU report never touch profiler APIs or presence getters',function()
 local f,a,calls,shown=fixture(function(f,_,calls)
  f.env.C_AddOnProfiler=setmetatable({},{__index=function()calls.forbidden=calls.forbidden+1;error('provider getter')end})
 end)
 assert(calls.forbidden==0);assert(a:RunCPUProfileAction('report'));assert(shown[1].text=='unchanged CPU report bytes'and shown[1].title=='CPU profile'and calls.forbidden==0)
end)
test('absent and metatable-only provider capabilities give bounded copyable status without native work',function()
 local f,a,calls,shown=fixture();local text=report(a,shown);has(text,'C_AddOnProfiler: absent');assert(calls.measure==0 and calls.forbidden==0)
 f.env.C_AddOnProfiler=setmetatable({},{__index=function()error('must use raw member presence')end});text=report(a,shown);has(text,'MeasureCall: absent');assert(calls.measure==0)
end)
test('active capture refuses probe before provider access and leaves capture unchanged',function()
 local f,a,calls,shown,_,setRunning=fixture();f.env.C_AddOnProfiler=good(calls);setRunning(true)
 local ok=a:RunCPUProfileAction('probe');assert(not ok and#shown==0 and calls.enabled==0 and calls.measure==0 and calls.event==0 and calls.forbidden==0 and a:IsCPUProfileRunning())
end)
test('missing throwing or malformed running-state getter never permits a native probe',function()
 for _,getter in ipairs({false,function()error('PRIVATE running')end,function()return nil end,function()return 1 end})do
  local f,a,calls,shown=fixture();a.IsCPUProfileRunning=getter;f.env.C_AddOnProfiler=good(calls)
  assert(not a:RunCPUProfileAction('probe'));assert(calls.enabled==0 and calls.measure==0 and calls.forbidden==0 and#shown==0)
 end
end)
test('enabled provider measures only one inert exact-arity callback with hole and false returns',function()
 local f,a,calls,shown=fixture();f.env.C_AddOnProfiler=good(calls);local profile=a.db.profile;local getReport=a.GetCPUProfileReport
 local text=report(a,shown);has(text,'Callback calls: 1');has(text,'Callback arguments: exact');has(text,'Callback returns: exact');has(text,'elapsedMilliseconds: 0.125');has(text,'allocatedBytes: 128');has(text,'deallocatedBytes: 0')
 assert(calls.enabled==1 and calls.measure==1 and calls.event==1 and calls.forbidden==0 and a.db.profile==profile and a.GetCPUProfileReport==getReport and not a:IsCPUProfileRunning())
end)
test('disabled missing partial or malformed IsEnabled never causes measurement or event marking',function()
 for _,value in ipairs({false,'true',1,{}})do
  local f,a,calls,shown=fixture();local provider=good(calls);provider.IsEnabled=function(...)assert(select('#',...)==0);calls.enabled=calls.enabled+1;return value end;f.env.C_AddOnProfiler=provider;report(a,shown);assert(calls.measure==0 and calls.event==0 and calls.forbidden==0)
 end
 for _,method in ipairs({'IsEnabled','MeasureCall'})do local f,a,calls,shown=fixture();local provider=good(calls);provider[method]=nil;f.env.C_AddOnProfiler=provider;report(a,shown);assert(calls.measure==0 and calls.event==0)end
end)
test('provider failures do not echo errors and event marking is optional and contained',function()
 for _,method in ipairs({'IsEnabled','MeasureCall','AddMeasuredCallEvent'})do
  local f,a,calls,shown=fixture();local provider=good(calls);provider[method]=function()error('PRIVATE provider raw error')end;f.env.C_AddOnProfiler=provider;report(a,shown);assert(calls.forbidden==0)
 end
 local f,a,calls,shown=fixture();local provider=good(calls);provider.AddMeasuredCallEvent=nil;f.env.C_AddOnProfiler=provider;local text=report(a,shown);has(text,'Callback returns: exact');assert(calls.measure==1 and calls.event==0)
end)
test('opaque provider or enabled value is refused before unsafe comparison or dispatch',function()
 for _,phase in ipairs({'namespace','enabled','method'})do
  local f,a,calls,shown=fixture();local provider=good(calls);local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
  if phase=='namespace'then f.env.C_AddOnProfiler=opaque
  elseif phase=='enabled'then provider.IsEnabled=function()return opaque end;f.env.C_AddOnProfiler=provider
  else provider.MeasureCall=opaque;f.env.C_AddOnProfiler=provider end
  local text=report(a,shown);assert(calls.measure==0 and calls.event==0 and not text:find('exact',1,true))
 end
end)
test('plain decimal byte strings render while opaque objects and unsafe numbers stay unavailable',function()
 local private=setmetatable({},{__tostring=function()error('PRIVATE tostring must never run')end})
 local values={{'18446744073709551615','0'}, {private,function()end}, {math.huge,-1}, {'12 PRIVATE','-3'}, {0/0,9007199254740992}}
 for index,row in ipairs(values)do
  local f,a,calls,shown=fixture();local provider=good(calls);provider.MeasureCall=function(fn,...)
   calls.measure=calls.measure+1;local returns=pack(fn(...));return{elapsedMilliseconds=index==3 and private or .5,allocatedBytes=row[1],deallocatedBytes=row[2]},unpack(returns,1,returns.n)
  end;f.env.C_AddOnProfiler=provider;local text=report(a,shown)
  if index==1 then has(text,'allocatedBytes: 18446744073709551615');has(text,'deallocatedBytes: 0')else has(text,'allocatedBytes: unavailable');has(text,'deallocatedBytes: unavailable')end
 end
end)
test('malformed callback count arguments and result tuple are reported without inferred support',function()
 for _,mode in ipairs({'zero','twice','arguments','returns','no-result','metatable-fields'})do
  local f,a,calls,shown=fixture();local provider=good(calls);provider.AddMeasuredCallEvent=nil
  provider.MeasureCall=function(fn,...)
   calls.measure=calls.measure+1;local returns={n=3,'RM',nil,false}
   if mode=='twice'then fn(...);returns=pack(fn(...))elseif mode=='arguments'then returns=pack(fn('wrong',nil,false))elseif mode~='zero'then returns=pack(fn(...))end
   if mode=='returns'then returns={n=3,false,nil,'RM'}end
   local result={elapsedMilliseconds=.5,allocatedBytes=0,deallocatedBytes=0}
   if mode=='no-result'then result=nil elseif mode=='metatable-fields'then result=setmetatable({},{__index=function()error('PRIVATE metric getter')end})end
   return result,unpack(returns,1,returns.n)
  end;f.env.C_AddOnProfiler=provider;local text=report(a,shown)
  if mode=='zero'then has(text,'Callback calls: 0')elseif mode=='twice'then has(text,'Callback calls: more than one')elseif mode=='arguments'then has(text,'Callback arguments: mismatch')elseif mode=='returns'then has(text,'Callback returns: mismatch')elseif mode=='no-result'then has(text,'MeasureCall: malformed')else has(text,'elapsedMilliseconds: unavailable')end
  has(text,'elapsedMilliseconds: unavailable');has(text,'allocatedBytes: unavailable');has(text,'deallocatedBytes: unavailable')
 end
end)
test('late namespace or method replacement suppresses stale measurements and restores probe guard',function()
 for _,phase in ipairs({'enabled','measure','event'})do
  local f,a,calls,shown=fixture();local provider=good(calls);local old=provider[phase=='enabled'and'IsEnabled'or phase=='measure'and'MeasureCall'or'AddMeasuredCallEvent']
  if phase=='enabled'then provider.IsEnabled=function(...)f.env.C_AddOnProfiler={};return old(...)end
  elseif phase=='measure'then provider.MeasureCall=function(...)local result=pack(old(...));provider.MeasureCall=function()error('replacement')end;return unpack(result,1,result.n)end
  else provider.AddMeasuredCallEvent=function(...)f.env.C_AddOnProfiler={};return old(...)end end
  f.env.C_AddOnProfiler=provider;local text=report(a,shown);has(text,'context changed');assert(not text:find('elapsedMilliseconds: 0.125',1,true))
  f.env.C_AddOnProfiler=good(calls);has(report(a,shown),'Callback returns: exact')
 end
end)
test('native-boundary reentry cannot nest probes or measure after a capture starts',function()
 local f,a,calls,shown,_,setRunning=fixture();local provider=good(calls);local nested
 provider.IsEnabled=function()calls.enabled=calls.enabled+1;nested=a:RunCPUProfileAction('probe');setRunning(true);return true end
 f.env.C_AddOnProfiler=provider;report(a,shown);assert(nested==false and calls.enabled==1 and calls.measure==0 and calls.event==0 and calls.forbidden==0)
end)
test('profile retirement during native call prevents stale numeric report',function()
 local f,a,calls,shown=fixture();local provider=good(calls);local enabled=provider.IsEnabled
 provider.IsEnabled=function(...)a.db.profile={};return enabled(...)end;f.env.C_AddOnProfiler=provider
 local text=report(a,shown);has(text,'context changed');assert(calls.measure==0)
end)
test('actual shared copyable probe window reuses CPU report window and provider UI errors stay contained',function()
 local f,a,calls,shown=fixture();f.load('UI/condition_text.lua');f.env.C_AddOnProfiler=good(calls)
 assert(a:RunCPUProfileAction('probe'));local window=a.conditionTextWindow;assert(window and window.edit:GetText():find('allocatedBytes',1,true))
 window.copy:Click();assert(window.edit.focused and window.edit.selection[2]==-1);window.close:Click();assert(not window.frame:IsShown())
 assert(a:RunCPUProfileAction('probe')and a.conditionTextWindow==window);assert(a:RunCPUProfileAction('report'));assert(window.edit:GetText()=='unchanged CPU report bytes')
 a.ShowConditionText=function()error('PRIVATE UI')end;assert(not a:RunCPUProfileAction('probe'));assert(calls.forbidden==0)
end)
test('running getter cannot reenter a second probe before the busy lease is acquired',function()
 local f,a,calls,shown=fixture();f.env.C_AddOnProfiler=good(calls);local entered=false;local nested
 a.IsCPUProfileRunning=function()if not entered then entered=true;nested=a:RunCPUProfileAction('probe')end;return false end
 report(a,shown);assert(nested==false and calls.measure==1 and#shown==1)
end)
test('method replacement by final running getter is rechecked before captured measurement dispatch',function()
 local f,a,calls,shown=fixture();local provider=good(calls);f.env.C_AddOnProfiler=provider;local reads=0
 a.IsCPUProfileRunning=function()reads=reads+1;if reads==4 then provider.MeasureCall=function()error('PRIVATE replacement')end end;return false end
 local text=report(a,shown);assert(calls.measure==0);has(text,'context changed')
end)
test('provider reentry cannot start cancel or open another CPU report during probe',function()
 local f,a,calls,shown=fixture();local provider=good(calls);local actions={};local mutations=0
 a.StartCPUProfile=function()mutations=mutations+1;return true end;a.CancelCPUProfile=function()mutations=mutations+1;return true end
 a.GetCPUProfileReport=function()mutations=mutations+1;return'PRIVATE nested report'end
 provider.IsEnabled=function()calls.enabled=calls.enabled+1;for _,action in ipairs({'start','cancel','report'})do actions[action]=a:RunCPUProfileAction(action)end;return true end
 f.env.C_AddOnProfiler=provider;report(a,shown);assert(mutations==0 and#shown==1 and actions.start==false and actions.cancel==false and actions.report==false)
end)
finish()
