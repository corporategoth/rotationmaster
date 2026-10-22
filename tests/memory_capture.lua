local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function setup()
 local f=F.new();local a,e=f.addon,f.env;local s={now=0,heap=1000,addonKB=500,updates=0,reads=0,timers={},cost=0,finished=0}
 e.GetTimePreciseSec=function()return s.now end;e.debugprofilestop=function()return s.cost end
 e.collectgarbage=function(mode)assert(mode=='count','capture controlled GC');s.reads=s.reads+1;if s.onHeap then s.onHeap()end;return s.heap end
 e.UpdateAddOnMemoryUsage=function()s.updates=s.updates+1;s.cost=s.cost+2;if s.onUpdate then s.onUpdate()end end
 e.GetAddOnMemoryUsage=function(name)assert(name=='rotationmaster');return s.addonKB end
 a.ScheduleRepeatingTimer=function(_,fn,delay)local t={fn=fn,delay=delay,repeatTimer=true};s.timers[#s.timers+1]=t;if s.onSchedule then s.onSchedule(t)end;return t end
 a.ScheduleTimer=function(_,fn,delay)local t={fn=fn,delay=delay};s.timers[#s.timers+1]=t;return t end
 a.CancelTimer=function(_,t)t.cancelled=true;if s.onCancel then s.onCancel(t)end end
 a.GetRetainedMemoryDiagnostic=function()return {spellIDs=3,itemRecords=4,sequence=2}end
 a.OnMemoryCaptureFinished=function()s.finished=s.finished+1 end
 local file=io.open('Diagnostics/memory.lua');if file then file:close();f.load('Diagnostics/memory.lua')end
 assert(type(a.StartMemoryCapture)=='function','memory capture API missing')
 return f,a,s
end
local function has(text,needle)assert(type(text)=='string'and text:find(needle,1,true),needle..' missing')end
local function tick(a,s,at)s.now=at;s.timers[1].fn()end

test('load and report are passive; explicit capture installs only two bounded timers',function()local _,a,s=setup();assert(s.reads==0 and s.updates==0 and #s.timers==0);assert(a:GetMemoryCaptureReport()==nil);assert(a:StartMemoryCapture());assert(s.reads==1 and s.updates==1 and #s.timers==2);assert(s.timers[1].delay==1 and s.timers[2].delay==600);assert(not a:StartMemoryCapture());a:StopMemoryCapture()end)
test('ten minutes bounds samples and detailed rows with overhead and heap decreases',function()local _,a,s=setup();assert(a:StartMemoryCapture());for i=1,600 do s.heap=i<300 and 1000+i or 700+i;tick(a,s,i)end;assert(not a:IsMemoryCaptureRunning());assert(s.reads==601 and s.updates==21);local r=a:GetMemoryCaptureReport();has(r,'heap samples=601; detailed samples=21');has(r,'decreases=1');has(r,'scan total=42.000 ms');has(r,'spellIDs=3');assert(#r<16000 and s.finished==1 and s.timers[1].cancelled and s.timers[2].cancelled)end)
test('late timer captures actual samples instead of replaying missing seconds',function()local _,a,s=setup();assert(a:StartMemoryCapture());tick(a,s,600);has(a:GetMemoryCaptureReport(),'heap samples=2; detailed samples=2');assert(s.updates==2)end)
test('stop preserves one report and stale callbacks do no later work',function()local _,a,s=setup();assert(a:StartMemoryCapture());assert(a:StopMemoryCapture());local before=s.reads;local report=a:GetMemoryCaptureReport();s.timers[1].fn();s.timers[2].fn();assert(s.reads==before and a:GetMemoryCaptureReport()==report and not a:StopMemoryCapture());has(report,'cancelled')end)
test('native refresh failure or missing attribution retains wholeheap capture',function()for _,mode in ipairs({'absent','error','restricted'})do local f,a,s=setup();if mode=='absent'then f.env.UpdateAddOnMemoryUsage=nil elseif mode=='error'then s.onUpdate=function()error('SECRET_DETAIL')end else f.env.GetAddOnMemoryUsage=function()return {}end end;assert(a:StartMemoryCapture());tick(a,s,30);a:StopMemoryCapture();local r=a:GetMemoryCaptureReport();has(r,'addonKiB=unavailable');assert(not r:find('SECRET_DETAIL',1,true))end end)
test('unreadable heap or missing clock refuses without timers or GC controls',function()for _,mode in ipairs({'clock','heap','secret'})do local f,a,s=setup();if mode=='clock'then f.env.GetTimePreciseSec=nil;f.env.GetTime=nil elseif mode=='heap'then f.env.collectgarbage=nil else f.env.issecretvalue=function(v)return v==s.heap end end;assert(not a:StartMemoryCapture());assert(not a:IsMemoryCaptureRunning() and #s.timers==0)end end)
test('retained roots cap aggregate traversal and omit keys values and callbacks',function()local _,a,s=setup();a.unitsInRange={};for i=1,5000 do a.unitsInRange['SECRET_GUID'..i]={unit='SECRET_NAME'}end;a.spellHistory={{}};a.combatHistory={player={{},{}}};a.damageHistory={x={damage={{}},heals={{},{}}}};a.GetRetainedMemoryDiagnostic=function()return {spellIDs=3,callback=function()end,secret='SECRET_VALUE'}end;assert(a:StartMemoryCapture());a:StopMemoryCapture();local r=a:GetMemoryCaptureReport();has(r,'units=>=4096');has(r,'spellRows=1');has(r,'combatRows=2');has(r,'damageRows=1');has(r,'healRows=2');assert(not r:find('SECRET',1,true)and not r:find('callback',1,true))end)
test('native refresh reentry cannot publish into newer capture',function()local _,a,s=setup();local once=false;s.onUpdate=function()if not once then once=true;a:StopMemoryCapture();assert(a:StartMemoryCapture())end end;assert(not a:StartMemoryCapture());assert(a:IsMemoryCaptureRunning());a:StopMemoryCapture()end)
test('cancellation reentry preserves newer timer ownership',function()local _,a,s=setup();assert(a:StartMemoryCapture());local once=false;s.onCancel=function()if not once then once=true;assert(a:StartMemoryCapture())end end;a:StopMemoryCapture();assert(a:IsMemoryCaptureRunning());assert(not s.timers[3].cancelled and not s.timers[4].cancelled);s.onCancel=nil;a:StopMemoryCapture()end)
test('schedule reentry cancels only old returned timer',function()local _,a,s=setup();local once=false;s.onSchedule=function()if not once then once=true;a:StopMemoryCapture();assert(a:StartMemoryCapture())end end;assert(not a:StartMemoryCapture());assert(a:IsMemoryCaptureRunning() and s.timers[1].cancelled and not s.timers[2].cancelled);a:StopMemoryCapture()end)
test('readability and retained-provider failures withhold values without ending normal sampling',function()local _,a,s=setup();a.GetRetainedMemoryDiagnostic=function()error('SECRET_RETAINED')end;assert(a:StartMemoryCapture());tick(a,s,30);a:StopMemoryCapture();assert(not a:GetMemoryCaptureReport():find('SECRET',1,true))end)
test('report rendering does not remeasure heap attribution or retained state',function()local _,a,s=setup();assert(a:StartMemoryCapture());a:StopMemoryCapture();local reads,updates=s.reads,s.updates;for i=1,10 do a:GetMemoryCaptureReport()end;assert(s.reads==reads and s.updates==updates)end)
test('memory commands route capture stop and existing copyable modal',function()local f,a,s=setup();dofile('tests/fixtures/native_ui.lua')(f.env);f.load('UI/condition_text.lua');f.load('UI/cpu_profile.lua');a.print=function()end;assert(a:RunCPUProfileAction('memory'));assert(a:RunCPUProfileAction('memorystop'));assert(a:RunCPUProfileAction('memoryreport'));local d=assert(a.conditionTextWindow);has(d.edit:GetText(),'Rotation Master memory capture');d.copy:Click();assert(d.edit.focused and d.edit.selection[2]==-1);d.close:Click();assert(not d.frame:IsShown())end)
test('timeout still retires capture if captured clock becomes unavailable',function()local _,a,s=setup();assert(a:StartMemoryCapture());s.now=nil;s.timers[2].fn();assert(not a:IsMemoryCaptureRunning(),'clock failure left permanent timer');has(a:GetMemoryCaptureReport(),'invalid')end)
test('overlapping cumulative and runtime capture states stay explicit',function()local _,a,s=setup();a.IsCPUProfileRunning=function()return true end;a.IsCPURuntimeCaptureRunning=function()return false end;assert(a:StartMemoryCapture());a:StopMemoryCapture();has(a:GetMemoryCaptureReport(),'cpu=active runtime=inactive')end)
test('aggregate early limits mark all unfinished nested totals as lower bounds',function()local _,a,s=setup();a.damageHistory={};for i=1,3 do local rows={};for n=1,3000 do rows[n]={}end;a.damageHistory[i]={damage={{}},heals=rows}end;assert(a:StartMemoryCapture());a:StopMemoryCapture();has(a:GetMemoryCaptureReport(),'damageRows=>=2');has(a:GetMemoryCaptureReport(),'healRows=>=4096')end)
test('cancelled old capture never sends a newer capture report with old status',function()local _,a,s=setup();local statuses={};a.OnMemoryCaptureFinished=function(_,report,status)statuses[#statuses+1]={report,status}end;assert(a:StartMemoryCapture());local once=false;s.onCancel=function()if not once then once=true;assert(a:StartMemoryCapture());a:StopMemoryCapture()end end;a:StopMemoryCapture();assert(#statuses==1 and statuses[1][2]=='cancelled')end)
test('actual addon and AceTimer disable retires memory state before embedded timer cleanup',function()
 local f,a,s=setup();f.load('Diagnostics/cpu.lua')
 a.CancelAllTimers=function(self)assert(self==a);for _,timer in ipairs(s.timers)do self:CancelTimer(timer)end end
 local h=assert(io.open('Libs/AceTimer-3.0/AceTimer-3.0.lua'));local text=h:read('*a');h:close()
 local body=assert(text:match('function AceTimer:OnEmbedDisable%(target%)(.-)\nend'))
 local disableTimers=assert(loadstring('return function(self,target)'..body..'\nend','@actual-AceTimer-OnEmbedDisable'))()
 assert(a:StartMemoryCapture());a:OnDisable();disableTimers(nil,a)
 assert(not a:IsMemoryCaptureRunning(),'disabled addon retained active memory state after timers were cancelled')
 assert(a:GetMemoryCaptureReport());assert(a:StartMemoryCapture(),'capture failed to restart after enable');a:StopMemoryCapture()
end)
test('optional raw WTM spike changes correlate only with observed wholeheap-drop intervals',function()
 local f,a,s=setup();local record={spikes=2,lastSpikeAt=0};local forbidden=function()error('WTM methods must not run')end
 f.env.WoWTaskManager={Processes={byName={rotationmaster=record},Get=forbidden},Memory={SampleAddons=forbidden},SpikeDetector={Check=forbidden}}
 assert(a:StartMemoryCapture());record.spikes=3;record.lastSpikeAt=1;s.heap=700;tick(a,s,1)
 record.spikes=4;record.lastSpikeAt=2;s.heap=1100;tick(a,s,2);tick(a,s,30);a:StopMemoryCapture()
 local r=a:GetMemoryCaptureReport();has(r,'WTM/RM spike increases=2; overlapping observed heap-drop intervals=1');has(r,'WTM/RMspikes=4');assert(s.updates==2)
end)
test('missing WTM stays optional and replaced or reset counters do not fabricate spikes',function()
 local f,a,s=setup();assert(a:StartMemoryCapture());a:StopMemoryCapture();has(a:GetMemoryCaptureReport(),'WTM spike correlation: unavailable')
 f,a,s=setup()
 local map={rotationmaster={spikes=5}};f.env.WoWTaskManager={Processes={byName=map}};assert(a:StartMemoryCapture())
 map.rotationmaster.spikes=6;s.heap=700;tick(a,s,1)
 map.rotationmaster={spikes=1};s.heap=400;tick(a,s,2)
 map.rotationmaster=nil;s.heap=100;tick(a,s,3)
 map.rotationmaster={spikes=2};s.heap=1000;tick(a,s,4)
 map.rotationmaster.spikes=3;s.heap=700;tick(a,s,5);a:StopMemoryCapture()
 has(a:GetMemoryCaptureReport(),'WTM/RM spike increases=2; overlapping observed heap-drop intervals=2')
end)
test('disabled addon cannot start or resurrect a memory capture during cancellation',function()
 local _,a,s=setup();a.IsEnabled=function()return true end;assert(a:StartMemoryCapture())
 local attempts=0
 s.onCancel=function()attempts=attempts+1;local ok,why=a:StartMemoryCapture();assert(not ok and why=='addon-disabled')end
 a.IsEnabled=function()return false end;assert(a:StopMemoryCapture());assert(attempts==2 and not a:IsMemoryCaptureRunning())
 local ok,why=a:StartMemoryCapture();assert(not ok and why=='addon-disabled')
 a.IsEnabled=function()return true end;s.onCancel=nil;assert(a:StartMemoryCapture());a:StopMemoryCapture()
end)

finish()
