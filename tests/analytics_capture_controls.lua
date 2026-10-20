local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function prefix(path,name)return assert(loadstring(assert(read(path):match('^(.-)\ntest%('))..'\nreturn '..name,'@controls-fixture:'..path))()end
local native=prefix('tests/platform_analytics_casts.lua','fixture')
local settings=prefix('tests/settings_pages.lua','fixture')
local function fixture(options)
 local f=native(options);local a=f.addon;f.env=getfenv(f.service.Start);local L=setmetatable({},{__index=function(_,k)return k end})
 f.env.LibStub=function(name)assert(name=='AceLocale-3.0');return{GetLocale=function()return L end}end
 f.shown={};function a:ShowConditionText(text,title)f.shown[#f.shown+1]={text=text,title=title}end
 local chunk=loadfile('UI/analytics_capture.lua');assert(chunk,'cast capture controls module missing');setfenv(chunk,f.env);chunk('rotationmaster',a)
 assert(a.RunCastCaptureAction and a.ClearCastCaptureForDisable,'cast capture controls missing')
 return f,a
end
local function contains(s,text)assert(type(s)=='string'and s:find(text,1,true),'missing '..text)end
local function clean(f)assert(next(f.events)==nil and f.scripts.OnEvent==nil,'native subscriptions leaked')end

test('controls load and cached status perform no native work; start is explicit thirty seconds',function()
 local f,a=fixture();assert(f.calls==0);contains(a:GetCastCaptureStatusText(),'idle');assert(f.calls==0)
 assert(a:RunCastCaptureAction('start'));assert(f.timers[1].duration==30);contains(a:GetCastCaptureStatusText(),'running')
 assert(not a:RunCastCaptureAction('start'));assert(#f.timers==1);a:ClearCastCaptureForDisable();clean(f)
end)
test('stop shows normalized receipts without private identities or invented scoring',function()
 local f,a=fixture();assert(a:RunCastCaptureAction('start'));f:emit('UNIT_SPELLCAST_SENT','player','PRIVATE_TARGET','PRIVATE_GUID',403);f.now=101;f:emit('UNIT_SPELLCAST_SUCCEEDED','player','PRIVATE_GUID',403)
 assert(a:RunCastCaptureAction('stop'));assert(a:RunCastCaptureAction('report'));local s=f.shown[1].text
 contains(s,'UNIT_SPELLCAST');contains(s,'70006');contains(s,'403');contains(s,'Records: 2');contains(s,'Scoring: unavailable')
 assert(not s:find('PRIVATE',1,true)and not s:find('percentage',1,true)and not s:find('agreement=',1,true));clean(f)
end)
test('timer finishes after configuration is absent and report remains available',function()
 local f,a=fixture();assert(a:RunCastCaptureAction('start'));f.now=130;f.timers[1].fn();assert(a:RunCastCaptureAction('report'));contains(f.shown[1].text,'Records: 0');clean(f)
 assert(a:RunCastCaptureAction('start'));assert(a:RunCastCaptureAction('stop'));clean(f)
end)
test('report refuses active or missing capture and clear removes completed data',function()
 local f,a=fixture();assert(not a:RunCastCaptureAction('report'));assert(not a:RunCastCaptureAction('stop'));assert(a:RunCastCaptureAction('start'));assert(not a:RunCastCaptureAction('report'));assert(#f.shown==0)
 assert(a:RunCastCaptureAction('stop'));assert(a:RunCastCaptureAction('clear'));assert(not a:RunCastCaptureAction('report'));clean(f)
end)
test('bounded report shows only two hundred rows and explicit omitted count',function()
 local f,a=fixture();assert(a:RunCastCaptureAction('start'));for i=1,205 do f:emit('UNIT_SPELLCAST_SUCCEEDED','player','key'..i,403)end;assert(a:RunCastCaptureAction('stop'));assert(a:RunCastCaptureAction('report'))
 local text=f.shown[1].text;contains(text,'Records: 205');contains(text,'Rows omitted: 5');assert(not text:find('seq=201',1,true));contains(text,'seq=200');assert(#text<40000)
end)
test('native errors give fixed feedback without raw exception data or fake score',function()
 local f,a=fixture();f.throw='client';local ok,message=a:RunCastCaptureAction('start');assert(not ok and not message:find('PRIVATE',1,true));assert(a:RunCastCaptureAction('report'));local text=f.shown[1].text;contains(text,'unavailable');assert(not text:find('PRIVATE',1,true));clean(f)
end)
test('foreign receiver and unknown action do not affect accepted capture',function()
 local f,a=fixture();assert(a:RunCastCaptureAction('start'));local count=f.calls;assert(not a.RunCastCaptureAction({},'clear'));assert(not a.ClearCastCaptureForDisable({}));assert(not a:RunCastCaptureAction('garbage'));assert(f.calls==count and f.service:GetStatus().phase=='running');a:ClearCastCaptureForDisable();clean(f)
end)
test('disable during Start retires returned lease and no resource can survive',function()
 for _,name in ipairs({'client','time','CreateFrame','SetScript','RegisterUnitEvent','ScheduleTimer'})do
  local f,a=fixture();f.hooks[name]=function()f.hooks[name]=nil;a:ClearCastCaptureForDisable()end
  assert(not a:RunCastCaptureAction('start'),name);assert(f.service:GetStatus().phase~='running');assert(not a:RunCastCaptureAction('stop'));clean(f)
 end
end)
test('clear callback during Stop cannot publish report or resurrect data',function()
 local f,a=fixture();assert(a:RunCastCaptureAction('start'));f.hooks.time=function()f.hooks.time=nil;a:ClearCastCaptureForDisable()end
 assert(not a:RunCastCaptureAction('stop'));assert(not a:RunCastCaptureAction('report'));assert(#f.shown==0);clean(f)
end)
test('replaced service and replaced methods refuse retained action ownership',function()
 local f,a=fixture();assert(a:RunCastCaptureAction('start'));a.Analytics.NativeCasts={};local count=f.calls;assert(not a:RunCastCaptureAction('stop'));assert(not a:RunCastCaptureAction('clear'));assert(f.calls==count);a:ClearCastCaptureForDisable();clean(f)
 f,a=fixture();local called=false;f.service.Start=function()called=true;return{}end;assert(not a:RunCastCaptureAction('start'));assert(not called and f.calls==0)
end)
test('Clear and nested Start during pre-frame startup preserve the newer UI lease',function()
 local f,a=fixture();local nested
 f.hooks.client=function()f.hooks.client=nil;assert(a:RunCastCaptureAction('clear'));nested=a:RunCastCaptureAction('start')end
 local ok,message,current=a:RunCastCaptureAction('start');assert(not ok and current==false and message=='');assert(nested and f.service:GetStatus().phase=='running')
 assert(a:RunCastCaptureAction('stop'),'new UI lease was clobbered');clean(f)
end)
test('report presentation reentry retires its feedback and preserves replacement capture',function()
 local f,a=fixture();assert(a:RunCastCaptureAction('start'));assert(a:RunCastCaptureAction('stop'))
 a.ShowConditionText=function()assert(a:RunCastCaptureAction('clear'));assert(a:RunCastCaptureAction('start'))end
 local ok,message,current=a:RunCastCaptureAction('report');assert(not ok and current==false and message=='');assert(a:RunCastCaptureAction('stop'));clean(f)
end)
test('report window failure is fixed feedback and does not lock later actions',function()
 local f,a=fixture();assert(a:RunCastCaptureAction('start'));assert(a:RunCastCaptureAction('stop'));a.ShowConditionText=function()error('PRIVATE_WINDOW_ERROR')end
 local ok,message=a:RunCastCaptureAction('report');assert(not ok and not message:find('PRIVATE',1,true));assert(a:RunCastCaptureAction('start'));a:ClearCastCaptureForDisable();clean(f)
end)
if pcall(require,'bit') then test('General controls bypass pending draft and released callbacks cannot restart capture',function()
 local f,parent=settings();local a=f.addon;local calls={};a.RunCastCaptureAction=function(_,action)calls[#calls+1]=action;return true,'Done'end;a.GetCastCaptureStatusText=function()return'Cast status: idle'end
 local p=a:OpenNativeSettings(parent,'General');local input=p:Edit('invalid_cast_probe','Probe','',function()return nil end,function()error('must not flush')end)
 input:SetText('pending');input.scripts.OnTextChanged(input,true);local dirty=p:IsSettingsDraftDirty();local profile=a.db.profile
 for _,key in ipairs({'cast_capture','cast_stop','cast_report','cast_clear'})do assert(p.fields[key],'missing '..key);p.fields[key]:Click()end
 assert(table.concat(calls,',')=='start,stop,report,clear'and a.db.profile==profile and p:IsSettingsDraftDirty()==dirty and input:GetText()=='pending')
 local stale=p.fields.cast_capture.scripts.OnClick;p:Release();stale();assert(#calls==4)
end) end
finish()
