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
test('release popup is a compact addon-titled table of readonly URL fields and Copy icons',function()
 local _,a=fixture();local d=a:ShowIntegrationProjectLink('LUI');local links=a:GetIntegrationProjectLinks('LUI')
 assert(d and d==a.integrationProjectWindow and d~=a.conditionTextWindow,'release links still use the generic report')
 assert(d.title:GetText()=='LUI' and d.frame:GetWidth()<700 and d.frame:GetHeight()<400)
 assert(d.providerHeading:GetText()=='Provider' and d.urlHeading:GetText()=='URL')
 for i,link in ipairs(links)do
  local row=assert(d.rows[i]);assert(row.edit:GetText()==link.url and row.provider:GetText()==link.label)
  assert(row.copy.icon:GetTexture()==a:ControlTexture('copy'),'expected standard Copy icon')
  assert(row.edit:GetCursorPosition()==0,'readonly URL starts scrolled to the end')
  assert(row.provider.tooltip:find(link.note,1,true),'edition evidence no longer accessible')
  local before=row.edit:GetText();row.edit:SetText('changed');row.edit.scripts.OnTextChanged(row.edit,true)
  assert(row.edit:GetText()==before,'URL typing/paste changed canonical read-only field')
 end
end)
test('copy and URL focus select only their own field and unselect every other URL',function()
 local _,a=fixture();local d=a:ShowIntegrationProjectLink('LUI')
 for i=1,4 do
  local row=d.rows[i];row.copy:Click();assert(row.edit.focused and row.edit.selection[1]==0 and row.edit.selection[2]==-1)
  for j=1,4 do if i~=j then assert(not d.rows[j].edit.focused and d.rows[j].edit.selection[2]==0,'another URL remains selected')end end
 end
 d.rows[1].edit.scripts.OnEditFocusGained(d.rows[1].edit)
 assert(d.rows[1].edit.selection[2]==-1 and d.rows[4].edit.selection[2]==0)
end)
test('release popup reuses bounded rows and retired copy callbacks cannot target a newer addon',function()
 local _,a=fixture();local d=a:ShowIntegrationProjectLink('LUI');local stale=d.rows[1].copy.scripts.OnClick
 local warm=d.rows[4];local nextDialog=a:ShowIntegrationProjectLink('Questie');assert(nextDialog==d and d.title:GetText()=='Questie')
 assert(not warm.frame:IsShown() and not warm.edit.focused and warm.edit.selection[2]==0)
 stale();assert(not d.rows[1].edit.focused,'old LUI copy selected the new Questie URL')
 local hidden=d.rows[1].copy.scripts.OnClick;d.close:Click();hidden();assert(not d.rows[1].edit.focused)
 assert(a:ShowIntegrationProjectLink('LUI')==d and d.rows[4]==warm)
 a:ShowConditionText('ordinary CPU report','CPU profile');local report=a.conditionTextWindow
 assert(report~=d and report.scroll:GetHeight()==300 and report.edit:GetText()=='ordinary CPU report' and not report.linkButtons)
end)
test('unsupported identities do not open reports and successor projects stay explicit',function()
 local _,a=fixture();assert(not a:ShowIntegrationProjectLink('unknown'))
 local links=a:GetIntegrationProjectLinks('AzeriteUI');assert(links[1].note:lower():find('legacy',1,true) or links[1].note:lower():find('histor',1,true))
 for _,link in ipairs(links)do if link.url:find('azeriteui6',1,true)then assert(link.note:lower():find('different',1,true))end end
end)
test('clicking an addon again raises its existing popup above an open report',function()
 local f,a=fixture();f.env.UISpecialFrames={}
 local d=a:ShowIntegrationProjectLink('LUI');a:ShowConditionText('CPU report','CPU profile')
 assert(a.conditionTextWindow.frame:GetFrameLevel()>d.frame:GetFrameLevel())
 assert(a:ShowIntegrationProjectLink('Questie')==d)
 assert(d.frame:GetFrameLevel()>a.conditionTextWindow.frame:GetFrameLevel(),'reused popup stayed behind an existing window')
end)
finish()
