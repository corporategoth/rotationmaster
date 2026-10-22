local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(p)local h=assert(io.open(p));local s=h:read('*a');h:close();return s end
local function fixture()
 local f=F.new();f.load('UI/cpu_profile.lua');local a=f.addon;local s={calls={},shown={},messages={}}
 a.warn=function()end;a.print=function(_,text)s.messages[#s.messages+1]=text end;a.ShowConditionText=function(_,text,title)s.shown[#s.shown+1]={text,title}end
 for _,name in ipairs({'StartCPUProfile','StartCPURuntimeCapture','StartMemoryCapture','StopCPUProfile','StopCPURuntimeCapture','CompleteMemoryCapture'})do a[name]=function(_,duration)s.calls[#s.calls+1]={name,duration};return true end end
 for _,name in ipairs({'GetCPUProfileReport','GetCPURuntimeCaptureReport','GetMemoryCaptureReport'})do a[name]=function()return name..' data'end end
 return f,a,s
end
test('all capture namespaces start with defaults or bounded numeric duration',function()
 for _,kind in ipairs({'cpu','runtime','memory'})do local _,a,s=fixture();assert(type(a.HandlePerformanceCommand)=='function','missing perf namespace')
  assert(a:HandlePerformanceCommand(kind));assert(s.calls[1][2]==(kind=='memory'and 600 or 10))
  assert(a:HandlePerformanceCommand(kind..' 30'));assert(s.calls[2][2]==30 and#s.shown==0)
 end
end)
test('invalid durations and extra arguments never invoke diagnostic APIs',function()
 local _,a,s=fixture();for _,cmd in ipairs({'cpu 0','cpu 61','runtime -1','runtime 61','memory 1801','memory 0','cpu nan','cpu 10 extra','casts','probe extra'})do
  assert(not a:HandlePerformanceCommand(cmd),cmd)
 end;assert(#s.calls==0 and#s.shown==0)
 assert(a:HandlePerformanceCommand('cpu 1')and a:HandlePerformanceCommand('runtime 60')and a:HandlePerformanceCommand('memory 1800'))
end)
test('stop finalizes once with notice and report alone opens copyable modal',function()
 for _,kind in ipairs({'cpu','runtime','memory'})do local _,a,s=fixture();assert(a:HandlePerformanceCommand(kind..' stop'));assert(#s.calls==1 and#s.shown==0)
  assert(a:HandlePerformanceCommand(kind..' report'));assert(#s.shown==1 and#s.calls==1)
 end
end)
test('failed stop and missing report keep the old report and do not pop up',function()
 local _,a,s=fixture();a.StopCPUProfile=function()return false,'not-running'end;a.GetCPUProfileReport=function()return nil,'not-captured'end
 assert(not a:HandlePerformanceCommand('cpu stop'));assert(not a:HandlePerformanceCommand('cpu report'));assert(#s.shown==0)
end)
test('legacy aliases retain default durations and explicit cancellation dispatch',function()
 local _,a,s=fixture();a.IsCPURuntimeCaptureRunning=function()return true end;a.CancelCPURuntimeCapture=function()s.cancelled=true;return true end
 assert(a:RunCPUProfileAction('start'));assert(s.calls[1][1]=='StartCPUProfile'and s.calls[1][2]==10)
 assert(a:RunCPUProfileAction('cancel')and s.cancelled and#s.shown==0)
end)
test('actual Main routes perf remainder and retains old cpu alias',function()
 local f,a,s=fixture();local source=read('main.lua');local first=assert(source:find('function addon:HandleCommand(str)',1,true));local last=assert(source:find('-- One optional-provider lifetime',first,true))
 local chunk=assert(loadstring('local addon,L,AceConsole=...\n'..source:sub(first,last-1)));setfenv(chunk,f.env)
 local L=f.env.LibStub('AceLocale-3.0'):GetLocale('rotationmaster');local console={GetArgs=function(_,text,_,pos)pos=pos or 1;local b,e,word=text:find('(%S+)',pos);return word,e and e+2 or#text+1 end}
 chunk(a,L,console);local routed;a.HandlePerformanceCommand=function(_,text)routed=text end;a:HandleCommand('perf runtime 30');assert(routed=='runtime 30')
 a.RunCPUProfileAction=function(_,text)routed='old:'..text end;a:HandleCommand('cpu report');assert(routed=='old:report')
end)
local function prefixFixture(path,name)local text=read(path);return assert(loadstring(assert(text:match('^(.-)\ntest%('))..'\nreturn '..name))()end
local runtime=prefixFixture('tests/cpu_runtime.lua','setup')
test('runtime duration changes deadline timer and report requested value',function()
 local _,a,s=runtime();assert(a:StartCPURuntimeCapture(30));assert(s.timers[1].delay==30);a:EvaluateNextAction();s.now=111;a:EvaluateNextAction();assert(a:IsCPURuntimeCaptureRunning(),'old ten-second deadline remained')
 s.now=130;s.timers[1].fn();local text=a:GetCPURuntimeCaptureReport();assert(not a:IsCPURuntimeCaptureRunning()and text:find('Requested=30 s',1,true)and text:find('actual=30.000 s',1,true))
end)
test('runtime manual stop preserves partial metrics and old cancel remains cancelled',function()
 local _,a,s=runtime();assert(a:StartCPURuntimeCapture(30));a:EvaluateNextAction();s.now=103;assert(a:StopCPURuntimeCapture());local text=a:GetCPURuntimeCaptureReport();assert(text:find('stopped',1,true)and text:find('measured=1',1,true)and s.timers[1].cancelled)
 local last=text;s.timers[1].fn();assert(a:GetCPURuntimeCaptureReport()==last)
 assert(a:StartCPURuntimeCapture());assert(a:CancelCPURuntimeCapture());assert(a:GetCPURuntimeCaptureReport():find('cancelled',1,true))
end)
local memory=prefixFixture('tests/memory_boundary_refresh.lua','setup')
test('custom memory duration keeps per-second heap and two boundary refreshes',function()
 local _,a,s=memory();assert(a:StartMemoryCapture(35));assert(s.timers[2].delay==35)
 for i=1,35 do s.now=i;s.timers[1].fn()end
 local text=a:GetMemoryCaptureReport();assert(not a:IsMemoryCaptureRunning()and s.updates==2 and s.reads==36 and text:find('requested=35 s',1,true))
 s.timers[2].fn();assert(s.updates==2)
end)
test('memory complete final-samples partial capture while legacy stop does not',function()
 local _,a,s=memory();assert(a:StartMemoryCapture(60));s.now=5;assert(a:CompleteMemoryCapture());local text=a:GetMemoryCaptureReport();assert(text:find('stopped',1,true)and text:find('actual=5.000 s',1,true)and s.updates==2)
 assert(a:StartMemoryCapture());local updates=s.updates;assert(a:StopMemoryCapture());assert(a:GetMemoryCaptureReport():find('cancelled',1,true)and s.updates==updates)
end)
test('memory long duration remains bounded and invalid durations leave sampler idle',function()
 local _,a,s=memory();for _,duration in ipairs({0,1801,'30',math.huge})do assert(not a:StartMemoryCapture(duration))end;assert(#s.timers==0 and s.updates==0)
 assert(a:StartMemoryCapture(1800));for i=1,1800 do s.now=i;s.timers[1].fn()end
 local text=a:GetMemoryCaptureReport();assert(text:find('heap samples=1801; detailed samples=61',1,true)and s.updates==2)
end)
local cpu=prefixFixture('tests/cpu.lua','fixture')
test('cumulative stop computes partial snapshot and never replays old timer',function()
 local _,a,s=cpu();assert(a:StartCPUProfile(30));s.now=105;s.phase='finish';assert(a:StopCPUProfile());local text=a:GetCPUProfileReport();assert(text:find('stopped',1,true)and text:find('duration=5.000 s',1,true)and text:find('addon CPU=40.000 ms',1,true))
 assert(s.timers[1].cancelled and not a:IsCPUProfileRunning());s.timers[1].callback();assert(a:GetCPUProfileReport()==text)
end)
test('memory completion called from a sampler callback retires without recursion',function()
 local _,a,s=memory();assert(a:StartMemoryCapture(60));s.now=1
 s.onHeap=function()s.onHeap=nil;assert(a:CompleteMemoryCapture())end
 s.timers[1].fn();assert(not a:IsMemoryCaptureRunning()and s.finished==1,'reentrant completion left sampler running')
 assert(a:GetMemoryCaptureReport():find('stopped',1,true))
end)
test('cumulative stop cancels only the captured timer if cancellation starts a newer capture',function()
 local _,a,s=cpu();local cancel=a.CancelTimer;local entered=false
 a.CancelTimer=function(self,t)cancel(self,t);if not entered then entered=true;assert(self:StartCPUProfile(5))end end
 assert(a:StartCPUProfile(30));s.now=105;s.phase='finish';assert(a:StopCPUProfile());assert(entered and a:IsCPUProfileRunning())
 s.timers[1].callback();assert(a:IsCPUProfileRunning(),'obsolete completion retired newer capture');a:CancelCPUProfile()
end)
test('namespace probe remains one inert callback with no capture or timer mutation',function()
 local make,good=prefixFixture('tests/cpu_native_probe.lua','fixture,good');local f,a,calls,shown=make();f.env.C_AddOnProfiler=good(calls)
 assert(a:HandlePerformanceCommand('probe'));assert(calls.measure==1 and calls.event==1 and calls.forbidden==0 and#shown==1)
 assert(shown[1].title=='Native profiler probe')
end)
test('exact diagnostics CLI inverse restores each predecessor and rejects same-length foreign bytes',function()
 local restore=dofile('tests/fixtures/restore_performance_commands.lua')
 for _,path in ipairs({'Diagnostics/cpu.lua','Diagnostics/cpu_runtime.lua','Diagnostics/memory.lua'})do
  local current=read(path);local before=restore(current,path)
  assert(before~=current and restore(before,path)==before)
  local changed=current:sub(1,-2)..(current:sub(-1)=='x'and'y'or'x')
  assert(not pcall(restore,changed,path),'accepted unrelated successor edit')
  changed=before:sub(1,-2)..(before:sub(-1)=='x'and'y'or'x')
  assert(not pcall(restore,changed,path),'accepted unrelated predecessor edit')
  assert(not pcall(restore,current:sub(1,-2),path),'accepted missing byte')
 end
end)
finish()
