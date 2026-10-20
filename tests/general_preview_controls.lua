local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local make=assert(loadstring(assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))..'\nreturn fixture','@general-preview-fixture'))()
local function fixture(options)
 options=options or{};local f,parent=make();local a=f.addon
 a.db.profile.preview_masque=options.enabled==true
 local lib=f.env.LibStub;f.env.LibStub=function(name,silent)if name=='Masque'then if options.missing then return nil end;return{}end;return lib(name,silent)end
 local calls={refresh=0,settings=0,sample=0};local sample=false
 a.RefreshPreviewWindow=function()calls.refresh=calls.refresh+1 end
 a.ToggleMasqueSettings=function()calls.settings=calls.settings+1;return true end
 a.IsPreviewSampleEnabled=function()return sample end
 a.SetPreviewSampleEnabled=function(_,value)sample=value==true;calls.sample=calls.sample+1;return sample end
 a.db.global.diagnosticCacheBypass=options.direct==true
 f.load('Diagnostics/cache_mode.lua');assert(a:InitializeCacheDiagnosticMode(a.db.global))
 local p=a:OpenNativeSettings(parent,'General');return f,a,p,calls
end
local function text(p,wanted)for _,t in ipairs(p.pool.text or{})do if t:IsShown()and t:GetText()==wanted then return t end end end
test('General separates History and Preview and documents visible preview controls',function()
 local _,a,p=fixture();assert(text(p,'History')and text(p,'Preview'));assert(not text(p,'History and preview'))
 local found={};for _,row in ipairs(a:GetGeneralOptionHelp())do found[row.id]=true end
 assert(found.preview_masque and found.masque_settings and found.preview_sample)
end)
test('General Masque preference stages and applies through its own transaction',function()
 local _,a,p,c=fixture();assert(p.fields.preview_masque,'General Masque control missing')
 p.fields.preview_masque:Click();assert(not a.db.profile.preview_masque and p:SettingsData().profile.preview_masque and c.refresh==0)
 assert(p:IsSettingsDraftDirty());p.fields.apply:Click();assert(a.db.profile.preview_masque and c.refresh==1)
 p.fields.preview_masque:Click();assert(a.db.profile.preview_masque);p:DiscardSettingsDraft();p:Draw();assert(p.fields.preview_masque:GetChecked()and c.refresh==1)
end)
test('General refuses a concurrent saved Masque change and retires released controls',function()
 local _,a,p,c=fixture();assert(p.fields.preview_masque);p.fields.preview_masque:Click()
 a.db.profile.preview_masque=nil;assert(not p:SaveSettingsDraft());assert(a.db.profile.preview_masque==nil and c.refresh==0)
 local stale=p.fields.preview_masque.scripts.OnClick;p:Release();stale();assert(c.refresh==0)
end)
test('missing Masque disables new opt in but permits removal of a saved opt in',function()
 local _,_,p=fixture({missing=true});assert(p.fields.preview_masque and not p.fields.preview_masque:IsEnabled());assert(not p.fields.masque_settings:IsEnabled())
 local _,a,q=fixture({missing=true,enabled=true});assert(q.fields.preview_masque:IsEnabled());q.fields.preview_masque:Click();assert(q:SaveSettingsDraft()and a.db.profile.preview_masque==false)
end)
test('Masque settings and sample Preview are explicit actions independent of invalid pending input',function()
 local _,a,p,c=fixture();assert(p.fields.masque_settings and p.fields.preview_sample)
 local input=p:Edit('unrelated','Unrelated','',function()return nil end,function()error('must not flush')end)
 input:SetText('invalid');input.scripts.OnTextChanged(input,true);local dirty=p:IsSettingsDraftDirty()
 p.fields.masque_settings:Click();assert(c.settings==1 and c.refresh==0)
 p.fields.preview_sample:Click();assert(c.sample==1 and a:IsPreviewSampleEnabled())
 p.fields.preview_sample:Click();assert(c.sample==2 and not a:IsPreviewSampleEnabled())
 assert(p:IsSettingsDraftDirty()==dirty and a.db.profile.preview_masque==false)
 local stale=p.fields.masque_settings.scripts.OnClick;p:Release();stale();assert(c.settings==1)
end)
test('cache checkbox alone distinguishes active saved mode from a pending reload',function()
 local _,a,p=fixture();local control=p.fields.cpu_cache_bypass;assert(control)
 assert(control:GetText()=='Bypass observation cache (requires restart)'and not control:GetChecked())
 control:Click();local loaded,requested,pending=a:GetCacheDiagnosticMode()
 assert(loaded=='cached'and requested=='direct'and pending and control:GetChecked())
 assert(control:GetText()=='Bypass observation cache (pending)')
 control:Click();assert(control:GetText()=='Bypass observation cache (requires restart)'and not control:GetChecked())
 for _,t in ipairs(p.pool.text or{})do assert(not(t:GetText()or''):find('Observation cache:',1,true)and not(t:GetText()or''):find('Next reload:',1,true))end
end)
test('cache save failure and released click preserve mode and caption',function()
 local _,a,p=fixture();local control=p.fields.cpu_cache_bypass;a.SetCacheDiagnosticMode=function()return false end
 control:Click();assert(not control:GetChecked()and control:GetText()=='Bypass observation cache (requires restart)')
 local stale=control.scripts.OnClick;local calls=0;a.SetCacheDiagnosticMode=function()calls=calls+1 end;p:Release();stale();assert(calls==0)
end)
test('loaded bypass is checked and requesting caching reports pending without a second text row',function()
 local _,a,p=fixture({direct=true});local control=p.fields.cpu_cache_bypass
 assert(control:GetChecked()and control:GetText()=='Bypass observation cache (requires restart)')
 control:Click();local loaded,requested,pending=a:GetCacheDiagnosticMode()
 assert(loaded=='direct'and requested=='cached'and pending and not control:GetChecked())
 assert(control:GetText()=='Bypass observation cache (pending)')
end)
test('additive General inverse preserves original full-file historical proofs',function()
 local inverse=dofile('tests/fixtures/restore_masque_preview.lua')
 for _,path in ipairs({'UI/settings_collections.lua','UI/settings_integrations.lua'})do
  local source=read(path);assert(type(inverse(path,source))=='string')
  assert(not pcall(inverse,path,source..'-- unrelated\n'))
 end
end)
test('real General actions paint transient samples and dispatch Masque without applying the draft',function()
 local f,a,p=fixture();p:DiscardSettingsDraft();a.db.profile.preview_spells=0;p:Draw()
 f.load('Integrations/masque.lua');f.load('UI/preview.lua')
 local calls=0;f.env.SlashCmdList={MASQUE=function(...)assert(select('#',...)==1 and(...)=='');calls=calls+1 end}
 local dirty=p:IsSettingsDraftDirty();p.fields.preview_sample:Click();local window=a.nextWindow
 assert(a:IsPreviewSampleEnabled()and window:Valid()and window.sampleCount==3 and window.count==0 and window.title:GetText()=='Preview')
 assert(a.db.profile.preview_spells==0 and p:IsSettingsDraftDirty()==dirty)
 p.fields.masque_settings:Click();assert(calls==1 and not a.db.profile.preview_masque)
 local stale=p.fields.preview_sample.scripts.OnClick;p:Release();stale();assert(a:IsPreviewSampleEnabled())
 a:SetPreviewSampleEnabled(false);assert(not a.nextWindow and a.db.profile.preview_spells==0)
end)
finish()
