local _,addon=...
-- Optional separately installed provider. All provider calls are cold lifecycle
-- work except ReSkin on an actual dimension change; publications only set art.
local status={state='disabled',reason='disabled',enabled=false}
local function publish(window,state,reason)
 status={state=state,reason=reason,enabled=window and window.profile.preview_masque==true or false,
  version=window and window.masqueVersion,apiMinor=window and window.masqueMinor,nativeAcceptance='unverified',
  versionStatus=window and window.masqueVersion=='12.1.0'and window.masqueMinor==110210 and'source-tested'or'unverified'}
end
-- User action only: the documented /masque entrypoint toggles its own panel.
-- Success means dispatch completed, not that a settings window became visible.
function addon:ToggleMasqueSettings()
 if not rawequal(self,addon)then return false end
 local ok,dispatched=pcall(function()
  local commands=SlashCmdList
  if type(commands)~='table'then return false end
  local toggle=commands.MASQUE
  if type(toggle)~='function'then return false end
  toggle('');return true
 end)
 return ok and dispatched==true
end
function addon:GetMasquePreviewStatus()
 local copy={};for key,value in pairs(status)do copy[key]=value end;return copy
end
local function baseline(icon)
 if icon.masqueSurface then icon.masqueSurface:Hide()end
 icon.texture:Show()
end
local function remove(icon)
 local owner=icon.masqueOwner;icon.masqueOwner=nil;baseline(icon)
 if owner then
  -- Clear ownership before crossing the provider boundary. A failed detach is
  -- terminal for this surface: never allocate more frames or hand it elsewhere.
  local ok=pcall(owner.remove,owner.group,icon.masqueSurface)
  if not ok then icon.masqueQuarantined=true end
  baseline(icon)
 end
end
function addon:ReleaseMasquePreview(window)
 window.masqueEpoch=(window.masqueEpoch or 0)+1
 window.masqueProvider=nil;window.masqueGroup=nil
 local busy=window.masqueBusy;window.masqueBusy=true
 for _,icon in ipairs(window.icons)do remove(icon)end
 window.masqueBusy=busy
 publish(window,'disabled','released')
end
local function surface(icon)
 local child=icon.masqueSurface
 if not child then
  child=CreateFrame('Button',nil,icon);child:SetPoint('TOPLEFT',icon,'TOPLEFT',0,0);child:EnableMouse(false)
  child.texture=child:CreateTexture(nil,'ARTWORK');child.texture:SetAllPoints(child)
  child.normal=child:CreateTexture(nil,'ARTWORK');child.normal:SetAllPoints(child)
  icon.masqueSurface=child
 end
 child:Hide();return child
end
local function nativeVersion()
 local namespace=C_AddOns
 local get=namespace and namespace.GetAddOnMetadata or GetAddOnMetadata
 if type(get)=='function'then
  local value=get('Masque','Version')
  if type(value)=='string'then return value:sub(1,64)end
 end
end
function addon:ConfigureMasquePreview(window)
 -- Reentry invalidates the outer lease. It cannot attach a competing owner
 -- while an AddButton/RemoveButton call is still on the provider's stack.
 if window.masqueBusy then self:ReleaseMasquePreview(window);publish(window,'unavailable','reentry');return end
 window.masqueBusy=true
 window.masqueEpoch=(window.masqueEpoch or 0)+1;local epoch=window.masqueEpoch
 local generation,profile=window.generation,window.profile
 local function valid()return window:Valid()and window.generation==generation and rawequal(window.profile,profile)and window.masqueEpoch==epoch end
 local function fail(state,reason)
  if not valid()then return end
  self:ReleaseMasquePreview(window);publish(window,state,reason)
 end
 local ok=pcall(function()
  if not valid()then return end
  if window.profile.preview_masque~=true then fail('disabled','disabled');return end
  local provider,minor=LibStub('Masque',true)
  if not valid()then return end
  window.masqueVersion=nativeVersion();window.masqueMinor=type(minor)=='number'and minor or nil
  if not valid()then return end
  if provider==nil then fail('missing','missing');return end
  if type(provider)~='table'then fail('incompatible','group-api');return end
  local groupFn=provider.Group;if not valid()then return end
  if type(groupFn)~='function'then fail('incompatible','group-api');return end
  local group=window.masqueGroup
  if not rawequal(provider,window.masqueProvider)then
   self:ReleaseMasquePreview(window);epoch=epoch+1
   if not valid()then return end
   group=groupFn(provider,'Rotation Master','RecommendationPreview')
   if not valid()then return end
  end
  if type(group)~='table'then fail('incompatible','button-api');return end
  local add=group.AddButton;if not valid()then return end
  local detach=group.RemoveButton;if not valid()then return end
  local reskin=group.ReSkin;if not valid()then return end
  if type(add)~='function'or type(detach)~='function'or type(reskin)~='function'then fail('incompatible','button-api');return end
  -- Captured public function identity is the removal contract for that owner.
  for _,icon in ipairs(window.icons)do
   local owner=icon.masqueOwner
   if owner and(not rawequal(owner.group,group)or owner.add~=add or owner.remove~=detach or owner.reskin~=reskin)then
    fail('incompatible','changed-api');return
   end
   if icon.masqueQuarantined then fail('unavailable','detach-failed');return end
  end
  window.masqueProvider,window.masqueGroup=provider,group
  for i=1,window.slots do
   local icon=window:EnsureIcon(i)
   if icon.masqueQuarantined then fail('unavailable','detach-failed');return end
   if not icon.masqueOwner then
    local child=surface(icon);child:SetSize(window.iconSize,window.iconSize)
    child.texture:SetTexture(icon.texture:GetTexture())
    local owner={group=group,add=add,remove=detach,reskin=reskin}
    icon.masqueOwner=owner
    local added=pcall(owner.add,group,child,{Icon=child.texture,Normal=child.normal},'Action',true)
    if not valid()then
     -- AddButton may finish after a synchronous release. Remove again after
     -- that late completion, without touching a newly acquired baseline.
     icon.masqueOwner=nil;baseline(icon)
     if not pcall(owner.remove,group,child)then icon.masqueQuarantined=true end
     baseline(icon);return
    end
    if not added then fail('error','add-failed');return end
   end
   icon.texture:Hide();icon.masqueSurface:Show()
  end
  publish(window,'connected','attached')
 end)
 if not ok then fail('error','provider-error')end
 window.masqueBusy=false
end
function addon:ResizeMasquePreviewIcon(window,icon)
 local owner=icon.masqueOwner;local child=icon.masqueSurface
 if not owner or not child then return end
 if math.abs(child:GetWidth()-window.iconSize)<=.1 and math.abs(child:GetHeight()-window.iconSize)<=.1 then return end
 local epoch=window.masqueEpoch
 child:SetSize(window.iconSize,window.iconSize)
 if not window:Valid()or epoch~=window.masqueEpoch then return end
 window.masqueBusy=true
 local ok=pcall(owner.reskin,owner.group,child)
 window.masqueBusy=false
 if not ok and window:Valid()and epoch==window.masqueEpoch then self:ReleaseMasquePreview(window);publish(window,'error','reskin-failed')end
end
