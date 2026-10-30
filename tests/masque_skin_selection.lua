-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local file=assert(io.open('tests/masque_preview.lua'));local source=file:read('*a');file:close()
local make=assert(loadstring(assert(source:match('^(.-)\ntest%('))..'\nreturn fixture'))()
local function fixture()
 local f,a,p=make();local skin='Blizzard Classic';local currentArg;local callbacks={}
 p.skinSets,p.optionReads,p.callbackRegistrations=0,0,0
 p.skins={['Blizzard Classic']={},Round={},Square={},Hidden={Disable=true}}
 p.api.GetSkins=function(self)assert(self==p.api);return p.skins end
 local reskin=p.group.ReSkin
 p.group.ReSkin=function(self,button)
  if p.reskinHook then p.reskinHook()end
  if p.disabled then return end
  if button then reskin(self,button);button.texture.appliedSkin=skin
  else for child in pairs(p.members)do reskin(self,child);child.texture.appliedSkin=skin end end
 end
 p.group.GetOptions=function(self)
  assert(self==p.group);p.optionReads=p.optionReads+1;local arg={};currentArg=arg
  return{args={Disable={arg=arg,get=function(info)assert(info[1]=='Disable'and info.arg==arg);return p.disabled==true end},SkinID={arg=arg,values={['Blizzard Classic']='Blizzard Classic',Round='Round',Square='Square'},
   get=function(info)assert(info[1]=='SkinID'and #info==1 and info.arg==arg);if p.getHook then p.getHook()end;return skin end,
   set=function(info,id)
    assert(info[1]=='SkinID'and #info==1 and info.arg==arg and currentArg==arg,'stale public option closure')
    p.skinSets=p.skinSets+1;skin=id;p.group:ReSkin();if p.setHook then p.setHook()end
    if callbacks.SkinID then callbacks.SkinID(p.group,'SkinID',skin)end
   end}}}
 end
 p.group.RegisterCallback=function(self,callback,...)
  assert(self==p.group and type(callback)=='function');p.callbackRegistrations=p.callbackRegistrations+1
  for i=1,select('#',...)do callbacks[select(i,...)]=callback end
 end
 function p:external(id)skin=id;self.group:ReSkin();if callbacks.SkinID then callbacks.SkinID(self.group,'SkinID',id)end end
 function p:selected()return skin end
 function p:callback()return callbacks.SkinID end
 function p:disable(value)self.disabled=value;if callbacks.Disabled then callbacks.Disabled(self.group,'Disabled',value)end end
 a.db.profile.preview_masque=true
 return f,a,p
end
test('missing and disabled providers expose one native choice without discovery',function()
 local f,a,p=fixture();a.db.profile.preview_masque=false
 assert(type(a.GetPreviewSkinChoices)=='function','skin API missing')
 local rows,available=a:GetPreviewSkinChoices();assert(not available and #rows==1 and rows[1].value=='Blizzard Classic')
 assert(a:GetPreviewSkin()=='Blizzard Classic'and a:SetPreviewSkin('Round')==false and not p.discoveries)
 a.db.profile.preview_masque=true;p.api=nil;rows,available=a:GetPreviewSkinChoices();assert(not available and #rows==1 and a:GetPreviewSkin()=='Blizzard Classic')
end)
test('public fresh options are the only selection authority and choices are detached',function()
 local _,a,p=fixture();assert(type(a.GetPreviewSkinChoices)=='function','skin API missing')
 local rows,available=a:GetPreviewSkinChoices();assert(available and #rows==3 and rows[1].value=='Blizzard Classic')
 rows[1].value='Changed';assert(a:GetPreviewSkinChoices()[1].value=='Blizzard Classic')
 assert(a:GetPreviewSkin()=='Blizzard Classic'and a:SetPreviewSkin('Round')and p:selected()=='Round'and a:GetPreviewSkin()=='Round')
 assert(p.skinSets==1 and p.optionReads>=3 and not a.nativePreviewWindow)
 assert(a.db.profile.preview_skin==nil and a.db.profile.preview_masque==true)
 assert(not a:SetPreviewSkin('Hidden')and not a:SetPreviewSkin('missing')and not a:SetPreviewSkin({})and p.skinSets==1)
 p:external('Square');assert(a:GetPreviewSkin()=='Square','provider must remain sole authority')
end)
test('explicit setter refreshes current child art and notifies after busy scope',function()
 local _,a,p=fixture();assert(type(a.SetPreviewSkin)=='function','skin API missing');local w=a:CreateNativePreviewWindow();w:AddRecommendation(403)
 local icon=w.icons[1];local child=icon.masqueSurface;local adds,removes=p.adds,p.removes;local notices=0
 child.texture:SetTexture(999)
 a.previewSkinChanged=function()notices=notices+1;assert(not w.masqueBusy and a:GetPreviewSkin()=='Round')end
 assert(a:SetPreviewSkin('Round'));assert(notices==1 and child.texture:GetTexture()==icon.texture:GetTexture()and child.texture.appliedSkin=='Round')
 assert(icon.masqueSurface==child and icon:IsShown()and p.adds==adds and p.removes==removes and p.callbackRegistrations==1)
 for i=2,3 do assert(not w.icons[i]:IsShown(),'refresh revealed an empty slot')end
end)
test('external skin events update visible samples and real icons with no publication callback work',function()
 local _,a,p=fixture();assert(type(a.GetPreviewSkin)=='function','skin API missing');local w=a:CreateNativePreviewWindow();w:AddRecommendation(403)
 local notices=0;a.previewSkinChanged=function()notices=notices+1;assert(not w.masqueBusy and a:GetPreviewSkin()=='Round')end
 p:external('Round');assert(notices==1 and w.icons[1].masqueSurface.texture.appliedSkin=='Round')
 local calls=p.reskins;local options=p.optionReads;local registered=p.callbackRegistrations
 for n=1,10 do w:ReleaseChildren();w:AddRecommendation(403);w:DoLayout()end
 assert(p.reskins==calls and p.optionReads==options and p.callbackRegistrations==registered,'publication queried skin controls')
 a.previewSkinChanged=nil;assert(a:SetPreviewSampleEnabled(true));w:ReleaseChildren();assert(w.count==0 and w.sampleCount==3);p:external('Square');assert(w.icons[1].sample and w.icons[1].masqueSurface.texture.appliedSkin=='Square'and w.icons[1].masqueSurface.texture:GetTexture()==w.icons[1].texture:GetTexture())
end)
test('retired callbacks cannot affect released or replaced owners',function()
 local _,a,p=fixture();assert(type(a.SetPreviewSkin)=='function','skin API missing');local w=a:CreateNativePreviewWindow();w:AddRecommendation(403)
 local callback=assert(p:callback());local notices=0;a.previewSkinChanged=function()notices=notices+1 end
 w:Release();local calls=p.reskins;callback(p.group,'SkinID','Round');assert(p.reskins==calls and notices==0)
 a.db.profile={preview_spells=1,preview_masque=false};a:RefreshPreviewWindow();callback(p.group,'SkinID','Round');assert(p.reskins==calls and notices==0)
end)
test('option failures and reentry are contained without stale writes or notifications',function()
 for _,phase in ipairs({'options','set','reskin','profile'})do
  local _,a,p=fixture();assert(type(a.SetPreviewSkin)=='function','skin API missing');local w=a:CreateNativePreviewWindow();w:AddRecommendation(403)
  local notices=0;a.previewSkinChanged=function()notices=notices+1 end
  if phase=='options'then p.group.GetOptions=function()error('private')end
  elseif phase=='set'then p.setHook=function()error('private')end
  elseif phase=='reskin'then p.reskinHook=function()error('private')end
  else p.getHook=function()a.db.profile={preview_spells=1,preview_masque=false}end end
  local ok,value=pcall(a.SetPreviewSkin,a,'Round');assert(ok and value==false,phase);assert(notices==0,phase)
 end
end)
test('provider Disabled option refuses applied skin claims and keeps native fallback live',function()
 local _,a,p=fixture();local w=a:CreateNativePreviewWindow();w:AddRecommendation(403);local child=w.icons[1].masqueSurface
 p:disable(true);assert(w.icons[1].texture:IsShown()and not child:IsShown())
 local rows,available=a:GetPreviewSkinChoices();assert(not available and #rows==1 and a:GetPreviewSkin()=='Blizzard Classic')
 assert(a:SetPreviewSkin('Round')==false and p.skinSets==0)
 w:Configure();assert(w.icons[1].texture:IsShown()and not child:IsShown(),'Configure revived externally disabled skin')
 p:disable(false);assert(not w.icons[1].texture:IsShown()and child:IsShown())
 assert(a:SetPreviewSkin('Round')and child.texture.appliedSkin=='Round')
end)
test('cold controls receive external changes without a preview and listener failures stay contained',function()
 local _,a,p=fixture();local notices=0
 assert(select(2,a:GetPreviewSkinChoices())and p.callbackRegistrations==1 and not a.nativePreviewWindow)
 a.previewSkinChanged=function()notices=notices+1;assert(a:GetPreviewSkin()=='Round')end
 p:external('Round');assert(notices==1 and not a.nativePreviewWindow)
 a.previewSkinChanged=function()error('private listener')end
 assert(pcall(p.external,p,'Square')and a:SetPreviewSkin('Round'))
end)
test('callback registration and public Disabled reads stop after retiring the window lease',function()
 for _,phase in ipairs({'register','options','disabled'})do
  local _,a,p=fixture();local reads,notices=0,0;local held
  a.previewSkinChanged=function()notices=notices+1 end
  local register=p.group.RegisterCallback;local options=p.group.GetOptions
  local function retire()local w=a.nextWindow;held=w;w:Release()end
  if phase=='register'then p.group.RegisterCallback=function(...)register(...);retire()end
  elseif phase=='options'then p.group.GetOptions=function(...)local value=options(...);retire();return value end
  else p.group.GetOptions=function(...)local value=options(...);value.args.Disable.get=function()reads=reads+1;retire();return true end;return value end end
  local w=a:CreateNativePreviewWindow();assert(held==w and not w.active and not w.masqueSkinLink,phase)
  assert(a:GetMasquePreviewStatus().state~='connected'and notices==0,phase)
  for _,icon in ipairs(w.icons)do assert(not icon.masqueOwner and icon.texture:IsShown()and not icon.masqueSurface:IsShown(),phase)end
  if phase=='disabled'then assert(reads==1)end
 end
end)
test('Disabled read retirement prevents setter writes and failed reads preserve known disabled art',function()
 local _,a,p=fixture();local w=a:CreateNativePreviewWindow();w:AddRecommendation(403);local options=p.group.GetOptions
 p.group.GetOptions=function(...)local value=options(...);value.args.Disable.get=function()w:Release();return false end;return value end
 assert(a:SetPreviewSkin('Round')==false and p.skinSets==0 and not w.active,'retired Disabled getter reached setter')
 local _,b,q=fixture();local current=b:CreateNativePreviewWindow();current:AddRecommendation(403);q:disable(true)
 q.group.GetOptions=function()error('private disabled read')end;current:Configure()
 assert(current.icons[1].texture:IsShown()and not current.icons[1].masqueSurface:IsShown(),'failed read revived known disabled skin')
end)
test('RM skin changes notify the loaded Masque settings UI after saving the provider selection',function()
 local f,a,p=fixture();local lib=f.env.LibStub;local notices=0;local displayed='Blizzard Classic';local registry={}
 registry.NotifyChange=function(self,name)
  assert(self==registry and name=='Masque');notices=notices+1;displayed=a:GetPreviewSkin()
 end
 f.env.LibStub=function(name,silent)if name=='AceConfigRegistry-3.0'then assert(silent);return registry end;return lib(name,silent)end
 assert(a:SetPreviewSkin('Round')and p:selected()=='Round'and displayed=='Round'and notices==1)
 a:GetPreviewSkin();a:GetPreviewSkinChoices();assert(not a:SetPreviewSkin('missing')and notices==1)
end)
test('absent malformed or throwing optional settings notifier preserves a saved skin',function()
 for _,kind in ipairs({'absent','malformed','throws'})do
  local f,a,p=fixture();local lib=f.env.LibStub
  f.env.LibStub=function(name,silent)
   if name=='AceConfigRegistry-3.0'then
    assert(silent);if kind=='malformed'then return{NotifyChange=false}elseif kind=='throws'then return{NotifyChange=function()error('notification')end}end
    return nil
   end
   return lib(name,silent)
  end
  assert(a:SetPreviewSkin('Round')and p:selected()=='Round',kind)
 end
end)
test('settings notification may read current skin but cannot recursively change it',function()
 local f,a,p=fixture();local lib=f.env.LibStub;local notices=0
 f.env.LibStub=function(name,silent)
  if name=='AceConfigRegistry-3.0'then return{NotifyChange=function()
   notices=notices+1;assert(a:GetPreviewSkin()=='Round');assert(a:SetPreviewSkin('Square')==false)
  end}end
  return lib(name,silent)
 end
 assert(a:SetPreviewSkin('Round')and p:selected()=='Round'and notices==1)
end)
finish()
