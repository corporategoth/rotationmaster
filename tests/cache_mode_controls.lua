local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local function fixtureFrom(path,name)
 local prefix=assert(read(path):match('^(.-)\ntest%('));return assert(loadstring(prefix..'\nreturn '..name,'@cache-mode-fixture:'..path))()
end
local settings=fixtureFrom('tests/settings_pages.lua','fixture')
local cpu=fixtureFrom('tests/cpu.lua','fixture')
local function contains(text,part)assert(type(text)=='string' and text:find(part,1,true),'missing '..part)end

test('General cache diagnostic is immediate requested state without applying or flushing a draft',function()
 local f,parent=settings();local a=f.addon;local requested='cached';local calls=0
 a.GetCacheDiagnosticMode=function()return 'cached',requested,requested~='cached'end
 a.SetCacheDiagnosticMode=function(self,value)assert(self==a);requested=value;calls=calls+1;return true end
 local p=a:OpenNativeSettings(parent,'General');local control=assert(p.fields.cpu_cache_bypass,'cache diagnostic checkbox missing')
 assert(control:GetChecked() and not p:IsSettingsDraftDirty())
 local input=p:Edit('invalid_probe','Probe','',function()return nil end,function()error('diagnostic flushed edits')end)
 input:SetText('bad');input.scripts.OnTextChanged(input,true);local before=p:IsSettingsDraftDirty()
 control:Click();assert(requested=='direct' and calls==1 and not control:GetChecked())
 assert(p:IsSettingsDraftDirty()==before and input:GetText()=='bad')
 contains(control:GetText(),'pending');contains(control.tooltip,'reload');local stale=control.scripts.OnClick;p:Release();stale();assert(calls==1)
end)
test('General distinguishes loaded cache state from the next reload request and includes ordered Help',function()
 local f,parent=settings();local a=f.addon
 a.GetCacheDiagnosticMode=function()return 'direct','cached',true end;a.SetCacheDiagnosticMode=function()return true end
 local p=a:OpenNativeSettings(parent,'General');assert(assert(p.fields.cpu_cache_bypass):GetChecked())
 local control=p.fields.cpu_cache_bypass;contains(control:GetText(),'Enable observation cache');contains(control:GetText(),'pending');contains(control.tooltip,'reload')
 local help=a:GetGeneralOptionHelp();local cacheAt,captureAt
 for i,row in ipairs(help)do if row.id=='cpu_cache_bypass'then cacheAt=i;contains(row.text,'getCached')elseif row.id=='cpu_capture'then captureAt=i end end
 assert(cacheAt and captureAt and cacheAt<captureAt,'diagnostic Help order differs from page')
end)
test('copyable CPU capture identifies loaded mode and pending request at each boundary',function()
 local _,a,s=cpu();local requested='direct'
 a.GetCacheDiagnosticMode=function()return 'cached',requested,requested~='cached'end
 assert(a:StartCPUProfile());requested='cached';s:complete();local report=a:GetCPUProfileReport()
 contains(report,'start config=');contains(report,'observation-cache=cached requested=direct reload=true')
 contains(report,'observation-cache=cached requested=cached reload=false')
end)
test('CPU mode fields fail closed to fixed unavailable labels without exposing provider errors',function()
 for _,mode in ipairs({'throw','bad'})do
  local _,a,s=cpu();a.GetCacheDiagnosticMode=function()if mode=='throw'then error('SECRET_CACHE_DATA')end;return {},'SECRET_CACHE_DATA',{}end
  assert(a:StartCPUProfile());s:complete();local report=a:GetCPUProfileReport();contains(report,'observation-cache=unavailable')
  assert(not report:find('SECRET_CACHE_DATA',1,true))
 end
end)
test('CPU mode snapshots reject unreadable mode or pending flags before formatting',function()
 for _,position in ipairs({1,2,3})do
  local f,a,s=cpu();local values={'direct','cached',false};local hidden=values[position]
  f.env.canaccessvalue=function(value)return not rawequal(value,hidden)end
  a.GetCacheDiagnosticMode=function()return unpack(values,1,3)end
  assert(a:StartCPUProfile());s:complete();contains(a:GetCPUProfileReport(),'observation-cache=unavailable')
 end
end)
finish()
