local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local restore=dofile('tests/fixtures/restore_cpu_preview_context.lua');local baseline=restore(nil,true)
local function read(path)local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local cpu=read('tests/cpu.lua');local at=assert(cpu:find("test('module is idle",1,true));local make=assert(loadstring(cpu:sub(1,at-1)..'return fixture','@real-cpu-preview-fixture'))()
local function fixture(old)
 local previous=loadfile
 if old then loadfile=function(path)if path=='Diagnostics/cpu.lua'then return assert(loadstring(baseline,'@'..path))end;return previous(path)end end
 local ok,f,a,s=pcall(make);loadfile=previous;assert(ok,f)
 f.load('UI/preview.lua');a.db.profile.preview_spells=3;a.db.profile.preview_opacity=1
 a.Platform.GetSpellInfo=function()return{iconID=42}end
 return f,a,s
end
local function has(text,part)assert(type(text)=='string'and text:find(part,1,true),'missing '..part)end
local function private(text)for _,secret in ipairs({'SECRET_PREVIEW','PRIVATE_PLAYER','spell:403','table:','function:','0x'})do assert(not text:find(secret,1,true),'private value leaked: '..secret)end end
local start='Standalone preview start: ';local ending='Standalone preview end: '
local omission='Standalone preview context omitted to keep report bounded.'
local function split(text)local at=text:find('\n'..start,1,true)or text:find('\n'..omission,1,true);return at and text:sub(1,at-1)or text,at and text:sub(at+1)end
local function capture(a,s)assert(a:StartCPUProfile());s:complete();return assert(a:GetCPUProfileReport())end
local function window(a)local w=a:CreateNativePreviewWindow();w:AddRecommendation(403);return w end

test('actual standalone preview shown with config hidden is a canonical boundary observation',function()
 local _,a,s=fixture();a.configWindow={frame={IsShown=function()return false end}};window(a)
 local text=capture(a,s);has(text,'start config=hidden');has(text,start..'selected=canonical shown=1 active=1 setting=3 slots=3 recommendations=1 profile=current');private(text)
end)
test('hidden active released and uncreated preview states remain distinct',function()
 local _,a,s=fixture();has(capture(a,s),start..'selected=none')
 local w=window(a);w:Hide();has(capture(a,s),start..'selected=canonical shown=0 active=1')
 w:Release();a.nextWindow=nil;has(capture(a,s),start..'selected=none')
end)
test('custom selected tables and inherited owner fields receive no member callbacks',function()
 local _,a,s=fixture();local calls=0;a.nextWindow=setmetatable({},{__index=function()calls=calls+1;error('SECRET_PREVIEW')end})
 has(capture(a,s),start..'selected=custom');assert(calls==0)
 local _,a,s=fixture();setmetatable(a,{__index=function(_,key)if key=='nativePreviewWindow'or key=='nextWindow'then calls=calls+1;error('SECRET_PREVIEW')end end})
 has(capture(a,s),start..'selected=none');assert(calls==0)
end)
test('protected shown lookup and call failures stay unknown without leaking errors',function()
 for _,mode in ipairs({'missing','getter','method','truthy'})do
  local _,a,s=fixture();local w=window(a)
  if mode=='missing'then w.frame={}elseif mode=='getter'then w.frame=setmetatable({},{__index=function()error('SECRET_PREVIEW')end})
  elseif mode=='method'then w.frame.IsShown=function()error('SECRET_PREVIEW')end else w.frame.IsShown=function()return 'SECRET_PREVIEW'end end
  local text=capture(a,s);has(text,'selected=canonical shown=?');private(text)
 end
end)
test('restricted markers counts and visibility never become false or private text',function()
 local f,a,s=fixture();local w=window(a);local secret={};f.env.canaccessvalue=function(value)return not rawequal(value,secret)end
 w.count=secret;w.frame.IsShown=function()return secret end
 local text=capture(a,s);has(text,'shown=?');has(text,'recommendations=?');private(text)
 w.nativePreview=secret;has(capture(a,s),start..'selected=unavailable')
end)
test('counts use only readable bounded integers and profile identity never invokes equality',function()
 local _,a,s=fixture();local w=window(a);w.count=-1;w.slots=6;a.db.profile.preview_spells='SECRET_PREVIEW'
 local text=capture(a,s);has(text,'setting=? slots=? recommendations=?');private(text)
 local equal=0;local mt={__eq=function()equal=equal+1;error('SECRET_PREVIEW')end};setmetatable(a.db.profile,mt);w.profile=setmetatable({},mt)
 has(capture(a,s),'profile=different');assert(equal==0)
end)
test('shown getters changing selection profile frame or lease fields invalidate mixed snapshots',function()
 for _,mode in ipairs({'selection','profile','frame','active','count','slots','setting','generation'})do
  local _,a,s=fixture();local w=window(a);local invoked=false
  w.frame.IsShown=function()
   if not invoked then invoked=true
    if mode=='selection'then a.nextWindow=nil elseif mode=='profile'then a.db.profile={}elseif mode=='frame'then w.frame={}
    elseif mode=='active'then w.active=false elseif mode=='count'then w.count=2 elseif mode=='slots'then w.slots=4 elseif mode=='generation'then w.generation=w.generation+1 else a.db.profile.preview_spells=5 end
   end;return true
  end
  has(capture(a,s),start..'selected=unavailable')
 end
end)
test('visibility getter retirement prevents invoking its returned stale method',function()
 for _,mode in ipairs({'rebind','cancel'})do
  local _,a,s=fixture();local w=window(a);local calls=0
  w.frame=setmetatable({},{__index=function(_,key)
   if key=='IsShown'then
    if mode=='rebind'then a.nextWindow=nil else assert(a:CancelCPUProfile())end
    return function()calls=calls+1;return true end
   end
  end})
  assert(a:StartCPUProfile());assert(calls==0,'stale returned visibility method invoked')
  if mode=='cancel'then assert(not a:IsCPUProfileRunning());has(a:GetCPUProfileReport(),'cancelled')else s:complete();has(a:GetCPUProfileReport(),start..'selected=unavailable')end
 end
end)
test('start and end snapshots are independent and report access does no visibility work',function()
 local _,a,s=fixture();local w=window(a);local calls=0;local shown=w.frame.IsShown;w.frame.IsShown=function(...)calls=calls+1;return shown(...)end
 assert(a:StartCPUProfile());assert(calls==1);w:Hide();s:complete();assert(calls==2)
 local text=a:GetCPUProfileReport();has(text,start..'selected=canonical shown=1');has(text,ending..'selected=canonical shown=0')
 a:GetCPUProfileReport();a:IsCPUProfileRunning();s.timers[1].callback();assert(calls==2)
end)
test('idle refusal cancellation and stale timers never sample extra preview state',function()
 local _,a,s=fixture();local w=window(a);local calls=0;w.frame.IsShown=function()calls=calls+1;return true end
 a:GetCPUProfileReport();s.enabled='0';assert(not a:StartCPUProfile());assert(calls==0)
 s.enabled='1';assert(a:StartCPUProfile());assert(calls==1);local old=s.timers[1];assert(a:CancelCPUProfile());old.callback();a:GetCPUProfileReport();assert(calls==1)
end)
test('synchronous completion samples end only and cancellation during start snapshot stays retired',function()
 local _,a,s=fixture();local w=window(a);local calls=0;w.frame.IsShown=function()calls=calls+1;return true end
 local reported;a.OnCPUProfileFinished=function(_,text)reported=text end
 a.ScheduleTimer=function(_,callback)s.now=s.now+10;s.phase='finish';callback();return {}end
 assert(a:StartCPUProfile());assert(calls==1);has(reported,start..'selected=unavailable');has(reported,ending..'selected=canonical')
 local _,a,s=fixture();local w=window(a);local calls=0;w.frame.IsShown=function()calls=calls+1;assert(a:CancelCPUProfile());return true end
 assert(a:StartCPUProfile());assert(not a:IsCPUProfileRunning()and calls==1);has(a:GetCPUProfileReport(),'cancelled');s.timers[1].callback();assert(calls==1)
end)
local function compare(metric)
 local results={}
 for _,old in ipairs({true,false})do
  local _,a,s=fixture(old);window(a)
  if metric then for i=1,31 do local id='BOUND_'..i;local fn=function()end;a.BuiltinSourceCatalog.conditions[id]={};a.conditionDefinitions[id]={evaluate=fn};s.rows[fn]={{0,0,0},{metric,metric,1}}end end
  local text=capture(a,s);results[#results+1]={text=text,native=table.concat(s.native,'|'),queries=#s.queries}
 end
 assert(results[1].native==results[2].native and results[1].queries==results[2].queries,'preview changes native counter query order/count')
 local prefix,suffix=split(results[2].text);assert(prefix==results[1].text,'old report bytes/ranks/counts changed')
 return results[1].text,results[2].text,suffix
end
test('appended context preserves every prior report byte ranking selection and counter query',function()
 local old,current,suffix=compare();assert(suffix and current:sub(1,#old)==old and #current<16000);has(suffix,start);has(suffix,ending);private(current)
end)
test('append budget never grows oversized old reports and clips only the new context',function()
 local near=0
 for _,metric in ipairs({1e180,1e190,1e200,1e210,1e220,1e240,1e280,1e308})do
  local old,current,suffix=compare(metric)
  if #old>=16000 then assert(current==old and not suffix,'oversized old report changed')else assert(#current<16000 and #current>=#old);if suffix and suffix:find(omission,1,true)then near=near+1 end end
 end
 assert(near>0,'no near-bound omitted context control')
end)
test('strict inverse restores the whole frozen source and rejects unrelated edits',function()
 local current=read('Diagnostics/cpu.lua');assert(restore(current)==baseline);assert(not pcall(restore,current..'\n-- unrelated')and not pcall(restore,baseline))
end)
finish()
