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

test('completed capture refreshes attribution only at start and end while retaining all samples',function()
 local _,a,s=setup();assert(a:StartMemoryCapture());for i=1,600 do tick(a,s,i)end
 assert(s.updates==2,'intermediate detailed rows still force expensive attribution scans')
 assert(s.reads==601 and not a:IsMemoryCaptureRunning());local r=a:GetMemoryCaptureReport()
 has(r,'heap samples=601; detailed samples=21');has(r,'Explicit attribution refreshes=2; successful=2; failed=0')
 has(r,'scan total=4.000 ms');has(r,'t=600.000 s');has(r,'attribution=refreshed');has(r,'addonKiB boundary start=500.000; end=500.000')
end)
test('intermediate attribution stays explicitly cached with unknown age even when external value changes',function()
 local _,a,s=setup();assert(a:StartMemoryCapture());s.addonKB=777;tick(a,s,30)
 assert(s.updates==1,'cached row triggered a refresh');a:StopMemoryCapture();local r=a:GetMemoryCaptureReport()
 has(r,'t=30.000 s heapKiB=1000.000 addonKiB=777.000 fresh=no');has(r,'attribution=cached age=unknown')
end)
test('drifting detail cadence reserves one final refreshed row beyond the last periodic detail',function()
 local _,a,s=setup();assert(a:StartMemoryCapture());for i=1,19 do tick(a,s,i*31)end
 assert(s.updates==1);tick(a,s,600.25);assert(s.updates==2)
 has(a:GetMemoryCaptureReport(),'t=600.250 s');has(a:GetMemoryCaptureReport(),'detailed samples=21')
 local reads,updates=s.reads,s.updates;s.timers[2].fn();s.timers[1].fn();assert(s.reads==reads and s.updates==updates)
end)
test('timeout provides a final refresh once even when repeating callback has not reached duration',function()
 local _,a,s=setup();assert(a:StartMemoryCapture());tick(a,s,580);s.now=601;s.timers[2].fn()
 assert(s.updates==2 and not a:IsMemoryCaptureRunning());has(a:GetMemoryCaptureReport(),'t=601.000 s')
 s.timers[2].fn();assert(s.updates==2)
end)
test('timeout at same sampled instant adds final attribution without another heap measurement',function()
 local _,a,s=setup();assert(a:StartMemoryCapture());tick(a,s,599);local reads=s.reads;s.timers[2].fn()
 assert(s.updates==2 and s.reads==reads);has(a:GetMemoryCaptureReport(),'t=599.000 s')
end)
test('failed final refresh is bounded and preserves the cheap heap and detailed counts',function()
 local _,a,s=setup();assert(a:StartMemoryCapture());s.onUpdate=function()error('DO_NOT_EXPOSE')end
 for i=1,600 do tick(a,s,i)end;assert(s.updates==2);local r=a:GetMemoryCaptureReport()
 has(r,'heap samples=601; detailed samples=21');has(r,'successful=1; failed=1');has(r,'addonKiB boundary start=500.000; end=unavailable');assert(not r:find('DO_NOT_EXPOSE',1,true))
end)
test('final refresh reentry retires only old capture and cannot finish newer owner',function()
 local _,a,s=setup();assert(a:StartMemoryCapture());local once=false
 s.onUpdate=function()if not once then once=true;a:StopMemoryCapture();assert(a:StartMemoryCapture())end end
 tick(a,s,600);assert(once and a:IsMemoryCaptureRunning());s.onUpdate=nil;a:StopMemoryCapture()
end)
test('cancel and report reads never add boundary refresh work',function()
 local _,a,s=setup();assert(a:StartMemoryCapture());tick(a,s,30);assert(s.updates==1)
 a:StopMemoryCapture();local before=s.updates;for i=1,10 do a:GetMemoryCaptureReport()end
 assert(s.updates==before and before==1)
end)
finish()
