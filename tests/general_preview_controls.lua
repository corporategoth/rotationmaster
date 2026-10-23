local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local make=assert(loadstring(assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))..'\nreturn fixture','@general-preview-fixture'))()
local function fixture(options)
 options=options or{};local f,parent=make();local a=f.addon
 a.db.profile.preview_masque=options.enabled==true
 local lib=f.env.LibStub;f.env.LibStub=function(name,silent)if name=='Masque'then if options.missing then return nil end;return{}end;return lib(name,silent)end
 local calls={refresh=0,skin=0,sample=0};local sample=false;local skin='Blizzard Classic'
 a.RefreshPreviewWindow=function()calls.refresh=calls.refresh+1 end
 a.GetPreviewSkinChoices=function()return{{value='Blizzard Classic',text='Blizzard Classic'},{value='Test Skin',text='Test Skin'}},a.db.profile.preview_masque and not options.missing end
 a.GetPreviewSkin=function()return skin end
 a.SetPreviewSkin=function(_,id)calls.skin=calls.skin+1;skin=id;return true end
 a.IsPreviewSampleEnabled=function()return sample end
 a.SetPreviewSampleEnabled=function(_,value)sample=value==true;calls.sample=calls.sample+1;return sample end
 a.db.global.diagnosticCacheBypass=options.direct==true
 f.load('Diagnostics/cache_mode.lua');assert(a:InitializeCacheDiagnosticMode(a.db.global))
 local p=a:OpenNativeSettings(parent,'General');return f,a,p,calls
end
local function text(p,wanted)for _,t in ipairs(p.pool.text or{})do if t:IsShown()and t:GetText()==wanted then return t end end end
local function choose(p,wanted)
 p.fields.preview_skin:Click();assert(p.menu and p.menu.frame:IsShown())
 for _,row in ipairs(p.menu.rows)do if row:GetText()==wanted then row:Click();return end end
 error('missing skin choice: '..wanted)
end
test('preview lock and unlock persist and update the same window immediately without Apply',function()
 for _,initial in ipairs({false,true})do
  local f,a,p=fixture();a.db.profile.preview_spells=3;a.db.profile.preview_locked=initial;p:DiscardSettingsDraft();p:Draw()
  f.load('UI/preview.lua');a:RefreshPreviewWindow();local window=a.nextWindow
  for turn=1,2 do
   local wanted=initial;if turn==1 then wanted=not initial end
   p.fields.preview_locked:Click()
   assert(a.db.profile.preview_locked==wanted and window.locked==wanted and a.nextWindow==window)
   assert(p:SettingsData().profile.preview_locked==wanted and p.draftBaseline.profile.preview_locked==wanted)
   assert(not p:IsSettingsDraftDirty()and not p.fields.apply:IsEnabled()and not p.fields.preview_locked.rmUnsaved)
   assert(window.grip:IsShown()==not wanted)
  end
 end
end)
test('immediate lock preserves unrelated invalid drafts and retires old click handlers',function()
 local _,a,p=fixture();p.fields.disable_buttons:Click();local draft=p:SettingsData().profile.disable_buttons
 local input=p:Edit('unrelated','Unrelated','',function()return nil end,function()error('must not flush')end)
 input:SetText('invalid');input.scripts.OnTextChanged(input,true)
 p.fields.preview_locked:Click();assert(a.db.profile.preview_locked==true and p:IsSettingsDraftDirty())
 assert(p:SettingsData().profile.disable_buttons==draft and not a.db.profile.disable_buttons and input:GetText()=='invalid')
 local stale=p.fields.preview_locked.scripts.OnClick;p:DiscardSettingsDraft();p:Draw()
 assert(p.fields.preview_locked:GetChecked()and not p:IsSettingsDraftDirty());stale();assert(a.db.profile.preview_locked==true)
 p.fields.preview_locked:Click();assert(a.db.profile.preview_locked==false and not p:IsSettingsDraftDirty())
 local closed=p.fields.preview_locked.scripts.OnClick;p:Release();closed();assert(a.db.profile.preview_locked==false)
end)
test('General separates History and Preview and only documents current preview controls',function()
 local _,a,p=fixture();assert(text(p,'History')and text(p,'Preview'));assert(not text(p,'History and preview'))
 local found={};for _,row in ipairs(a:GetGeneralOptionHelp())do found[row.id]=true end
 assert(found.preview_skin and found.preview_sample and not found.preview_masque and not found.masque_settings)
 assert(not p.fields.preview_masque and not p.fields.masque_settings)
end)
test('skin selection immediately uses provider authority and leaves unrelated General draft intact',function()
 local _,a,p,c=fixture({enabled=true});p.fields.disable_buttons:Click();assert(p:IsSettingsDraftDirty())
 choose(p,'Test Skin');assert(a:GetPreviewSkin()=='Test Skin'and c.skin==1 and c.refresh==0)
 assert(a.db.profile.preview_masque and p:IsSettingsDraftDirty()and not a.db.profile.disable_buttons)
 p.fields.cancel:Click();assert(a:GetPreviewSkin()=='Test Skin'and a.db.profile.preview_masque)
end)
test('missing or disabled integration has only native default and Preview still works',function()
 for _,options in ipairs({{}, {missing=true,enabled=true}})do
  local _,a,p,c=fixture(options);assert(p.fields.preview_skin:GetText()=='Blizzard Classic'and not p.fields.preview_skin:IsEnabled())
  assert(p.fields.preview_sample:IsEnabled());p.fields.preview_sample:Click();assert(c.sample==1 and a:IsPreviewSampleEnabled())
  assert(not p:IsSettingsDraftDirty())
 end
end)
test('skin and sample actions do not flush unrelated invalid pending inputs',function()
 local _,a,p,c=fixture({enabled=true})
 local input=p:Edit('unrelated','Unrelated','',function()return nil end,function()error('must not flush')end)
 input:SetText('invalid');input.scripts.OnTextChanged(input,true)
 choose(p,'Test Skin');assert(c.skin==1)
 p.fields.preview_sample:Click();assert(c.sample==1 and a:IsPreviewSampleEnabled())
 p.fields.preview_sample:Click();assert(c.sample==2 and not a:IsPreviewSampleEnabled())
end)
test('released skin menu and buttons cannot change provider or sample state',function()
 local _,a,p,c=fixture({enabled=true});p.fields.preview_skin:Click();local row
 for _,candidate in ipairs(p.menu.rows)do if candidate:GetText()=='Test Skin'then row=candidate end end
 assert(row);local chooseSkin=row.scripts.OnClick;local sample=p.fields.preview_sample.scripts.OnClick
 p:Release();chooseSkin(row);sample();assert(c.skin==0 and c.sample==0)
end)
test('external skin notifications repaint the current dropdown and retire on page release',function()
 local _,a,p=fixture({enabled=true});a.SetPreviewSkin(nil,'Test Skin');a.previewSkinChanged()
 assert(p.fields.preview_skin:GetText()=='Test Skin')
 local callback=a.previewSkinChanged;p:Release();assert(a.previewSkinChanged==nil);callback()
end)
test('initial drawing provider retirement never publishes a skin listener',function()
 local _,a,p=fixture({enabled=true});a.GetPreviewSkinChoices=function()p:Release();return{{value='Test Skin',text='Test Skin'}},true end
 p:Draw();assert(not p.active and a.previewSkinChanged==nil)
end)
test('provider reentry retires the drawing before menu or message publication',function()
 for _,phase in ipairs({'choices','get','set'})do
  local _,a,p=fixture({enabled=true})
  if phase=='choices'then a.GetPreviewSkinChoices=function()p:Release();return{{value='Test Skin',text='Test Skin'}},true end
  elseif phase=='get'then a.GetPreviewSkin=function()p:Release();return'Test Skin'end
  else a.SetPreviewSkin=function()p:Release();return true end end
  if phase=='set'then choose(p,'Test Skin')else p.fields.preview_skin:Click()end
  assert(not p.active and not(p.menu and p.menu.frame:IsShown()),phase)
 end
end)
test('skin failure rereads actual selection and reports failure',function()
 local _,a,p,c=fixture({enabled=true});a.SetPreviewSkin=function()return false end
 choose(p,'Test Skin');assert(a:GetPreviewSkin()=='Blizzard Classic'and p.fields.preview_skin:GetText()=='Blizzard Classic')
 assert(p.message:GetText()=='Preview skin is unavailable.')
end)
test('Skin dropdown and compact Preview button share a bounded row',function()
 local _,_,p=fixture({enabled=true});local skin,button=p.fields.preview_skin,p.fields.preview_sample
 local _,sx,sy=skin:GetPoint();local _,bx,by=button:GetPoint()
 assert(sy==by and bx>=sx+skin:GetWidth()+7 and bx+button:GetWidth()<=p.width+.1)
 assert(button:GetWidth()<180 and skin:GetWidth()>80)
end)
test('General rows: Enable trio in thirds, captionless preview beside Effect and Magnification, pad under the swatch, Detailed Profiling after Log Level',function()
 local _,_,p=fixture()
 local function at(c)local _,x,y=c:GetPoint();return x,-y end
 local enable,disable,minimap=p.fields.enable,p.fields.disable_buttons,p.fields.minimap
 local width=enable:GetParent():GetWidth();local ex,ey=at(enable);local dx,dy=at(disable);local mx,my=at(minimap)
 assert(ey==dy and dy==my and ex==0 and math.abs(dx-width/3)<=8 and math.abs(mx-2*width/3)<=8,'Enable, Disable Bar Highlighting and Minimap Icon do not share one row in thirds')
 assert(minimap:GetWidth()<=width/3+.1,'Minimap Icon overflows its third')
 assert(not text(p,'Highlight preview'),'the preview icon still has a caption')
 for _,t in ipairs(p.pool.labels or{})do assert(not t:IsShown()or t:GetText()~='Highlight preview','the preview icon still has a caption')end
 local preview=p.fields.preview;local px,py=at(preview);local _,effectY=at(p.fields.effect);local _,magY=at(p.fields.magnification)
 assert(px<=8 and py<=effectY+6 and py+preview:GetHeight()>=magY+12,'the preview icon does not span the Effect and Magnification rows')
 local captions={};for _,t in ipairs(p.pool.labels or{})do if t:IsShown()and(t:GetText()=='Effect'or t:GetText()=='Magnification')then local x=at(t);captions[#captions+1]=x end end
 assert(#captions==2,'Effect or Magnification lost its caption');for _,x in ipairs(captions)do assert(x>=px+preview:GetWidth()+4,'a caption overlaps the preview icon')end
 local sx=at(p.fields.color);local padX=at(p.fields.positionPad);assert(padX==sx,'the anchor arrows do not line up with the Highlight Color swatch')
 local log,detail=p.fields.loglevel,p.fields.detailed_profiling;local lx,ly=at(log);local cx,cy=at(detail)
 assert(math.abs(cy-ly)<=4 and cx>=lx+log:GetWidth(),'Detailed Profiling is not after Log Level on its row')
 assert(detail:GetWidth()<=22+180 and cx+detail:GetWidth()<=detail:GetParent():GetWidth()+.1,'Detailed Profiling is wider than its caption')
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
test('real Skin dropdown updates existing sample surfaces and follows external Masque selection',function()
 local h=assert(io.open('tests/masque_skin_selection.lua'));local source=h:read('*a');h:close()
 local backend=assert(loadstring(assert(source:match('^(.-)\ntest%('))..'\nreturn fixture'))()
 local _,_,provider=backend()
 local f,a,p=fixture({enabled=true});local lib=f.env.LibStub
 f.env.LibStub=function(name,silent)if name=='Masque'then return provider.api,110210 end;return lib(name,silent)end
 f.load('Integrations/masque.lua');f.load('UI/preview.lua');a.db.profile.preview_spells=0;p:DiscardSettingsDraft();p:Draw()
 p.fields.preview_sample:Click();local window=a.nextWindow;local child=window.icons[1].masqueSurface
 assert(window.sampleCount==3 and child and child:IsShown())
 local adds,removes=provider.adds,provider.removes
 choose(p,'Round');assert(a.nextWindow==window and window.sampleCount==3 and window.icons[1].masqueSurface==child)
 assert(child.texture.appliedSkin=='Round'and provider.adds==adds and provider.removes==removes and not p:IsSettingsDraftDirty())
 provider:external('Square');assert(p.fields.preview_skin:GetText()=='Square'and child.texture.appliedSkin=='Square')
 p.fields.preview_sample:Click();assert(not a.nextWindow and a.db.profile.preview_spells==0)
end)
test('real General Preview action paints transient samples without applying the draft',function()
 local f,a,p=fixture();p:DiscardSettingsDraft();a.db.profile.preview_spells=0;p:Draw()
 f.load('Integrations/masque.lua');f.load('UI/preview.lua')
 local dirty=p:IsSettingsDraftDirty();p.fields.preview_sample:Click();local window=a.nextWindow
 assert(a:IsPreviewSampleEnabled()and window:Valid()and window.sampleCount==3 and window.count==0 and window.title:GetText()=='Preview')
 assert(a.db.profile.preview_spells==0 and p:IsSettingsDraftDirty()==dirty)
 local stale=p.fields.preview_sample.scripts.OnClick;p:Release();stale();assert(a:IsPreviewSampleEnabled())
 a:SetPreviewSampleEnabled(false);assert(not a.nextWindow and a.db.profile.preview_spells==0)
end)
finish()
