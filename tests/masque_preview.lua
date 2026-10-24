local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();local a=f.addon
 a.db.profile.preview_spells=3;a.db.profile.preview_opacity=1
 a.Platform.GetSpellInfo=function(_,id)return{iconID=id+10}end
 local p={adds=0,removes=0,reskins=0,groups=0,members={}}
 p.group={AddButton=function(_,button,regions,kind,strict)
  p.adds=p.adds+1;assert(strict==true and kind=='Action' and regions.Icon==button.texture and regions.Normal==button.normal)
  p.members[button]=regions;button.texture:SetTexCoord(.1,.9,.1,.9)
  if p.addHook then p.addHook(button)end
 end,RemoveButton=function(_,button)
  p.removes=p.removes+1;if p.removeHook then p.removeHook(button)end
  p.members[button]=nil;button.texture:SetTexCoord(.2,.8,.2,.8)
 end,ReSkin=function(_,button)p.reskins=p.reskins+1;assert(p.members[button]);if p.resizeHook then p.resizeHook(button)end end}
 p.api={Group=function(_,name,id)p.groups=p.groups+1;assert(name=='Rotation Master'and id=='RecommendationPreview');return p.group end}
 local lib=f.env.LibStub
 f.env.LibStub=function(name,silent)if name=='Masque'then assert(silent);p.discoveries=(p.discoveries or 0)+1;return p.api,110210 end;return lib(name)end
 f.env.C_AddOns={GetAddOnMetadata=function()return'12.1.0'end}
 f.load('Integrations/masque.lua');f.load('UI/preview.lua');return f,a,p
end
test('standalone remains default and public status is cached',function()
 local _,a,p=fixture();local w=a:CreateNativePreviewWindow();w:AddRecommendation(403)
 assert(p.adds==0 and not w.icons[1].masqueSurface and not p.discoveries)
 local status=a:GetMasquePreviewStatus();assert(status.state=='disabled');status.state='mutated';assert(a:GetMasquePreviewStatus().state=='disabled')
end)
test('configure registers once and publications retain bounded ownership without provider work',function()
 local _,a,p=fixture();a.db.profile.preview_masque=true;local w=a:CreateNativePreviewWindow()
 assert(p.adds==3 and p.groups==1)
 for _,icon in ipairs(w.icons)do assert(not icon:IsShown(),'empty enabled preview revealed unfilled icons')end
 local discoveries=p.discoveries
 for n=1,20 do w:ReleaseChildren();for i=1,3 do w:AddRecommendation(400+n+i)end;w:DoLayout()end
 assert(p.adds==3 and p.reskins==0 and p.discoveries==discoveries and p.removes==0 and #w.icons==3)
 assert(a:GetMasquePreviewStatus().state=='connected'and a:GetMasquePreviewStatus().apiMinor==110210)
 w:Configure();assert(p.adds==3 and p.reskins==0)
 a.db.profile.preview_icon_size=80;w:Configure();assert(p.reskins==3)
 w:DoLayout();assert(p.reskins==3)
end)
test('optout hides altered surface and returns pristine original texture',function()
 local _,a,p=fixture();a.db.profile.preview_masque=true;local w=a:CreateNativePreviewWindow();w:AddRecommendation(403)
 local icon=w.icons[1];local texture=icon.texture;local surface=icon.masqueSurface
 assert(surface:IsShown()and not texture:IsShown()and surface.texture:GetTexture()==413)
 a.db.profile.preview_masque=false;w:Configure()
 assert(p.removes==3 and not surface:IsShown()and texture:IsShown()and icon.texture==texture and not texture.texCoord)
 for i=1,20 do a.db.profile.preview_masque=true;w:Configure();a.db.profile.preview_masque=false;w:Configure();assert(icon.masqueSurface==surface)end
end)
test('absence incompatibility and thrown API leave baseline available',function()
 for _,mode in ipairs({'missing','incompatible','group-error','add-error','resize-error'})do
  local _,a,p=fixture();a.db.profile.preview_masque=true
  if mode=='missing'then p.api=nil elseif mode=='incompatible'then p.group.ReSkin=nil elseif mode=='group-error'then p.api.Group=function()error('private')end elseif mode=='add-error'then p.addHook=function()error('private')end end
  local w=a:CreateNativePreviewWindow();w:AddRecommendation(403)
  if mode=='resize-error'then p.resizeHook=function()error('private')end;a.db.profile.preview_icon_size=80;w:Configure()end
  assert(w.icons[1].texture:IsShown()and(not w.icons[1].masqueSurface or not w.icons[1].masqueSurface:IsShown()),mode)
  assert(a:GetMasquePreviewStatus().state~='connected',mode)
 end
end)
test('failed removal quarantines reusable child and never exposes retained skin',function()
 local _,a,p=fixture();a.db.profile.preview_masque=true;local w=a:CreateNativePreviewWindow();w:AddRecommendation(403)
 p.removeHook=function(button)button:Show();error('private')end;a.db.profile.preview_masque=false;w:Configure();local count=p.adds
 a.db.profile.preview_masque=true;w:Configure();assert(p.adds==count and a:GetMasquePreviewStatus().reason=='detach-failed')
 assert(w.icons[1].texture:IsShown()and not w.icons[1].masqueSurface:IsShown())
end)
test('release profile replacement and stale callbacks retire old membership',function()
 local _,a,p=fixture();a.db.profile.preview_masque=true;local w=a:CreateNativePreviewWindow();w:AddRecommendation(403)
 local stale=w:MenuEntries()[2].func;w:Release();assert(p.removes==3 and not next(p.members))
 a.db.profile={preview_spells=2,preview_masque=true};a:RefreshPreviewWindow();assert(p.adds==5);stale();assert(w.active and next(p.members))
 a.db.profile={preview_spells=1};a:RefreshPreviewWindow();assert(not next(p.members)and a:GetMasquePreviewStatus().state=='disabled')
end)
test('synchronous add reentry cannot skin a retired or reacquired lease',function()
 local _,a,p=fixture();a.db.profile.preview_masque=true;local entered=false
 p.addHook=function()if not entered then entered=true;a.nextWindow:Release();a:CreateNativePreviewWindow()end end
 local w=a:CreateNativePreviewWindow();assert(entered and not next(p.members))
 for _,icon in ipairs(w.icons)do assert(icon.texture:IsShown()and not icon.masqueSurface:IsShown())end
 p.addHook=nil;w:Configure();assert(a:GetMasquePreviewStatus().state=='connected')
end)
test('provider replacement removes old public ownership before bounded reuse',function()
 local _,a,p=fixture();a.db.profile.preview_masque=true;local w=a:CreateNativePreviewWindow();local child=w.icons[1].masqueSurface
 local old=p.group;local replacement={};for key,value in pairs(old)do replacement[key]=value end
 p.api={Group=function()return replacement end};w:Configure()
 assert(p.removes==3 and p.adds==6 and w.icons[1].masqueSurface==child and w.icons[1].masqueOwner.group==replacement)
 old.ReSkin=function()error('stale')end
 w:Release();assert(not next(p.members))
end)
test('synchronous removal and reskin reentry never attach a competing owner',function()
 for _,phase in ipairs({'remove','resize'})do
  local _,a,p=fixture();a.db.profile.preview_masque=true;local w=a:CreateNativePreviewWindow();local entered=false
  local function reenter()if not entered then entered=true;w:Release();a:CreateNativePreviewWindow()end end
  if phase=='remove'then p.removeHook=reenter;w:Release()
  else p.resizeHook=reenter;a.db.profile.preview_icon_size=80;w:Configure()end
  assert(entered and not next(p.members),phase)
  for _,icon in ipairs(w.icons)do assert(icon.texture:IsShown()and not icon.masqueSurface:IsShown(),phase)end
  p.removeHook=nil;p.resizeHook=nil;w:Configure();assert(a:GetMasquePreviewStatus().state=='connected',phase)
 end
end)
test('all slot counts retain at most five native and isolated skin surfaces',function()
 local _,a,p=fixture();a.db.profile.preview_masque=true;local w=a:CreateNativePreviewWindow();local children={}
 for cycle=1,5 do for n=1,5 do
  a.db.profile.preview_spells=n;w:Configure();w:ReleaseChildren()
  for i=1,n do w:AddRecommendation(400+i);children[i]=children[i]or w.icons[i].masqueSurface;assert(children[i]==w.icons[i].masqueSurface)end
  assert(#w.icons<=5);w:ReleaseChildren()
  for _,icon in ipairs(w.icons)do assert(not icon:IsShown())end
 end end
 assert(#w.icons==5 and p.adds==5)
end)
test('additive historical inverse preserves complete old files and rejects unrelated successors',function()
 local inverse=dofile('tests/fixtures/restore_masque_preview.lua')
 for _,path in ipairs({'UI/settings_integrations.lua','Core/profile_data.lua','UI/settings_collections.lua'})do
  local file=assert(io.open(path));local source=file:read('*a');file:close()
  local old=inverse(path,source);assert(old~=source and inverse(path,old)==old)
  assert(not pcall(inverse,path,source..'\n'),'whole-file mutation accepted')
  assert(dofile('tests/fixtures/restore_integration_settings.lua')(path,source))
 end
end)
test('settings toggle is idle at module load and never discovers or builds preview state',function()
 local f=F.new();local reads,calls=0,0
 f.env.SlashCmdList=setmetatable({},{__index=function()reads=reads+1;return function()calls=calls+1 end end})
 f.env.CreateFrame=function()error('settings helper allocated a frame')end
 f.env.LibStub=function()error('settings helper discovered a provider')end
 f.load('Integrations/masque.lua')
 assert(type(f.addon.ToggleMasqueSettings)=='function','public user-action settings helper missing')
 assert(reads==0 and calls==0 and not f.addon.nativePreviewWindow,'module load opened settings')
end)
test('settings toggle checks namespace and callable command capability',function()
 local f,a,p=fixture();assert(type(a.ToggleMasqueSettings)=='function','settings toggle missing')
 for _,commands in ipairs({false,1,'Masque',{}, {MASQUE=false},{MASQUE='toggle'}})do
  f.env.SlashCmdList=commands;assert(a:ToggleMasqueSettings()==false)
 end
 f.env.SlashCmdList=nil;assert(a:ToggleMasqueSettings()==false)
 assert(not p.discoveries and p.groups==0 and p.adds==0 and not a.nativePreviewWindow)
end)
test('settings toggle dispatches exactly one empty argument only for its own receiver',function()
 local f,a,p=fixture();assert(type(a.ToggleMasqueSettings)=='function','settings toggle missing')
 local reads,calls=0,0
 f.env.SlashCmdList=setmetatable({},{__index=function(_,key)
  reads=reads+1;assert(key=='MASQUE');return function(...)calls=calls+1;assert(select('#',...)==1 and (...)=='','slash argument shape changed');return nil end
 end})
 assert(a.ToggleMasqueSettings({})==false and a.ToggleMasqueSettings(nil)==false and reads==0 and calls==0)
 assert(a:ToggleMasqueSettings()==true and reads==1 and calls==1)
 assert(a:ToggleMasqueSettings()==true and reads==2 and calls==2)
 assert(not p.discoveries and p.groups==0 and p.adds==0 and not a.nativePreviewWindow)
end)
test('settings toggle contains command lookup and dispatch errors without changing adapter status',function()
 local f,a=fixture();assert(type(a.ToggleMasqueSettings)=='function','settings toggle missing')
 local before=a:GetMasquePreviewStatus()
 for _,commands in ipairs({setmetatable({},{__index=function()error('private lookup')end}),{MASQUE=function()error('private dispatch')end}})do
  f.env.SlashCmdList=commands;local ok,value=pcall(a.ToggleMasqueSettings,a);assert(ok and value==false)
 end
 local after=a:GetMasquePreviewStatus();assert(after.state==before.state and after.enabled==before.enabled and not a.nativePreviewWindow)
end)
finish()
