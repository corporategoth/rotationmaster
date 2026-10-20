local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();f.addon.Platform.CanReadValue=function()return true end
 f.load('Integrations/catalog.lua');f.load('UI/help.lua');f.load('UI/condition_text.lua')
 return f,f.addon
end
test('release metadata has a bounded verified URL list for each supported identity',function()
 local _,a=fixture();assert(a.GetIntegrationProjectLinks,'release metadata missing')
 for _,row in ipairs(a:ListIntegrationStatus())do
  local links=a:GetIntegrationProjectLinks(row.id);assert(type(links)=='table' and #links>0 and #links<=8,row.id)
  assert(row.projectURL==links[1].url and links[1].primary==true,row.id)
  local seen={};for _,link in ipairs(links)do
   assert(type(link.label)=='string' and type(link.note)=='string' and link.note~='')
   assert(link.url:match('^https://') and not link.url:find('[%s|]') and not seen[link.url]);seen[link.url]=true
  end
 end
 assert(#a:GetIntegrationProjectLinks('native')==0 and #a:GetIntegrationProjectLinks('unknown')==0)
end)
test('release metadata is detached and never calls third party code or opens a browser',function()
 local f,a=fixture();f.env.IsAddOnLoaded=function()error('release links cannot discover addons')end
 f.env.GetAddOnMetadata=function()error('release links cannot query versions')end
 local links=a:GetIntegrationProjectLinks('!!!LuaWorkbench');links[1].url='corrupt';links.extra={}
 local nextLinks=a:GetIntegrationProjectLinks('!!!LuaWorkbench');assert(nextLinks[1].url~='corrupt' and not nextLinks.extra)
end)
test('copy dialog offers every channel and selects only the requested URL',function()
 local f,a=fixture();local dialog=a:ShowIntegrationProjectLink('LUI');assert(dialog and dialog.frame:IsShown())
 local links=a:GetIntegrationProjectLinks('LUI');assert(#links>1)
 for i,link in ipairs(links)do
  assert(dialog.text:find(link.url,1,true) and dialog.text:find(link.note,1,true))
  local button=assert(dialog.linkButtons[i]);assert(button:IsShown());button:Click()
  local span=dialog.edit.selection
  -- The native fixture stores HighlightText arguments in highlight.
  assert(span and dialog.text:sub(span[1]+1,span[2])==link.url)
 end
 local stale=dialog.linkButtons[1].scripts.OnClick
 a:ShowConditionText('ordinary report','CPU profile');assert(dialog.scroll:GetHeight()==300)
 for _,button in ipairs(dialog.linkButtons)do assert(not button:IsShown() and not button.scripts.OnClick)end
 stale();assert(dialog.text=='ordinary report','stale URL copy replaced an unrelated report')
end)
test('unsupported identities do not open reports and successor projects stay explicit',function()
 local _,a=fixture();assert(not a:ShowIntegrationProjectLink('unknown'))
 local links=a:GetIntegrationProjectLinks('AzeriteUI');assert(links[1].note:lower():find('legacy',1,true) or links[1].note:lower():find('histor',1,true))
 for _,link in ipairs(links)do if link.url:find('azeriteui6',1,true)then assert(link.note:lower():find('different',1,true))end end
end)
finish()
