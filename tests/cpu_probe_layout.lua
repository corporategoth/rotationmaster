-- Real General form/layout with modeled7px font metrics, not native clipping proof.
local function read(path)local f=assert(io.open(path));local text=f:read('*a');f:close();return text end
local prefix=assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))
local fixture=assert(loadstring(prefix..'\nreturn fixture','@cpu-probe-layout-fixture'))()
local test,finish=dofile('tests/fixtures/addon.lua').suite()
local keys={'cpu_capture','cpu_report','cpu_cancel','cpu_probe'}
local observedColumns={}
local function geometry(width,translated)
 local f,parent=fixture();local a=f.addon;parent:SetSize(width,600)
 if translated then f.libraries['AceLocale-3.0']:GetLocale('rotationmaster')['Native profiler probe']='Translated native profiler capability'end
 local calls=0;a.RunCPUProfileAction=function()calls=calls+1;return true,''end
 a.RunCastCaptureAction=function()return true,''end;a.GetCastCaptureStatusText=function()return'Cast capture idle'end
 local p=a:OpenNativeSettings(parent,'General');assert(calls==0,'drawing invokes diagnostics')
 local available=p.columnSingle and math.min(760,p.fullWidth)or p.columnWidth;local rects={};local minimum=120
 for _,key in ipairs(keys)do
  local b=assert(p.fields[key],'missing '..key);local extent=b:GetFontString():GetStringWidth()+20;minimum=math.max(minimum,extent)
  assert(extent<=b:GetWidth(),key..' caption clipped at width'..width)
  local anchor=assert(b.point);assert(anchor[1]=='TOPLEFT'and type(anchor[2])=='number'and type(anchor[3])=='number')
  rects[#rects+1]={key=key,left=anchor[2],right=anchor[2]+b:GetWidth(),top=-anchor[3],bottom=-anchor[3]+b:GetHeight()}
  assert(anchor[2]>=0 and anchor[2]+b:GetWidth()<=available+.01,key..' outside column')
 end
 local columns=available>=minimum*4+12 and 4 or available>=minimum*2+4 and 2 or 1;observedColumns[columns]=true
 for i,r in ipairs(rects)do local expectedX=((i-1)%columns)*((available-(columns-1)*4)/columns+4);assert(math.abs(r.left-expectedX)<.01,'grid columns differ from measured captions');assert(r.top==rects[1].top+math.floor((i-1)/columns)*28,'grid row mismatch')end
 for i=1,#rects do for j=i+1,#rects do local a,b=rects[i],rects[j];assert(not(a.left<b.right and b.left<a.right and a.top<b.bottom and b.top<a.bottom),'CPU buttons overlap')end end
 local cast=assert(p.fields.cast_capture);local lastBottom=0;for _,r in ipairs(rects)do lastBottom=math.max(lastBottom,r.bottom)end;assert(-cast.point[3]>=lastBottom,'next diagnostics overlap CPU grid')
 p:Release()
end
for _,width in ipairs({380,1000,1400,1800})do test('CPU four-button measured geometry at parent'..width,function()geometry(width,false)end)end
for _,width in ipairs({380,1800,2800})do test('localized CPU probe caption adapts at parent'..width,function()geometry(width,true)end)end
test('measured CPU geometry exercises4twoand1column layouts',function()assert(observedColumns[4]and observedColumns[2]and observedColumns[1])end)
test('probe dispatch is explicit and bypasses pending edits without changing live or draft settings',function()
 local f,parent=fixture();local a=f.addon;a.db.profile.poll=.15;local calls=0
 a.RunCPUProfileAction=function(...)assert(select('#',...)==2 and select(1,...)==a and select(2,...)=='probe');calls=calls+1;return true,'capability report'end
 local p=a:OpenNativeSettings(parent,'General');local b=assert(p.fields.cpu_probe,'missing probe');assert(calls==0)
 local edit=p:Edit('invalid','Unrelated','',function()return nil end,function()error('must not flush')end);edit:SetText('invalid');edit.scripts.OnTextChanged(edit,true)
 local before=a:CopySettingsData(p:SettingsData());local live=a:CopySettingsData(a.db.profile);local dirty=p:IsSettingsDraftDirty()
 b:Click();assert(calls==1 and p.message:GetText()=='capability report');assert(a:SettingsDataEqual(before,p:SettingsData())and a:SettingsDataEqual(live,a.db.profile));assert(p:IsSettingsDraftDirty()==dirty)
 local stale=b.scripts.OnClick;p:Release();stale();assert(calls==1)
end)
test('probe callbacks reject replaced page and profile leases',function()
 for _,mode in ipairs({'redraw','profile'})do
  local f,parent=fixture();local a=f.addon;local calls=0;a.RunCPUProfileAction=function()calls=calls+1;return true,''end
  local p=a:OpenNativeSettings(parent,'General');local callback=assert(p.fields.cpu_probe,'missing probe').scripts.OnClick
  if mode=='redraw'then p:Draw()else a.db.profile={}end
  callback();assert(calls==0,mode..' stale probe executed')
 end
end)
test('CPU action reentry cannot message a retired General page',function()
 for _,mode in ipairs({'release','profile'})do
  local f,parent=fixture();local a=f.addon;local p;local calls,messages=0,0
  a.RunCPUProfileAction=function()calls=calls+1;if mode=='release'then p:Release()else a.db.profile={}end;return true,'retired'end
  p=a:OpenNativeSettings(parent,'General');p.Message=function()messages=messages+1 end
  assert(p.fields.cpu_probe,'missing probe'):Click();assert(calls==1 and messages==0,mode..' late message')
 end
end)
test('probe has one localized authored Help row in actual CPU control order',function()
 local f,parent=fixture();local a=f.addon;local L=f.libraries['AceLocale-3.0']:GetLocale('rotationmaster')
 assert(f.translations['Native profiler probe']=='Native profiler probe','missing caption locale')
 assert(type(f.translations['Help.General.cpu_probe'])=='string'and not f.translations['Help.General.cpu_probe']:find('Help.General',1,true),'missing authored probe help')
 L['Native profiler probe']='Translated probe';L['Help.General.cpu_probe']='Translated inert capability help'
 local p=a:OpenNativeSettings(parent,'General');assert(p.fields.cpu_probe and p.fields.cpu_probe:GetText()=='Translated probe')
 local rows,count={},0;for i,r in ipairs(a:GetGeneralOptionHelp())do rows[r.id]={i=i,row=r};if r.id=='cpu_probe'then count=count+1;assert(r.title=='Translated probe'and r.text=='Translated inert capability help')end end
 assert(count==1 and rows.cpu_probe.i==rows.cpu_cancel.i+1);assert(not p.fields.cpu_probe_help)
end)
test('probe report states and both command usage keys have explicit locale entries',function()
 local f=fixture();local L=f.libraries['AceLocale-3.0']:GetLocale('rotationmaster')
 for _,key in ipairs({'Callback arguments','Callback calls','Callback returns','Capability probe only; no evaluator or gameplay was measured.',
  'Native profiler probe','Native profiler probe is already running.','Native profiler probe is unavailable while CPU capture is running.',
  'Native profiler probe is unavailable.','Usage: /rm cpu [start|report|cancel|probe]','call completed','call failed','disabled','enabled','exact',
  'malformed','mismatch','more than one','not run','present','restricted','unavailable (context changed)','absent','unavailable','Native acceptance: unverified'})do
  assert(type(f.translations[key])=='string'and #f.translations[key]>0,'missing explicit locale '..key)
 end
 assert(L['Usage: /rm cpu [start|report|cancel]']=='Usage: /rm cpu [start|report|cancel|probe]','legacy command help omits probe')
end)
finish()
