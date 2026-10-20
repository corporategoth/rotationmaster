local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();f.addon.Platform.CanReadValue=function()return true end
 f.load('Integrations/catalog.lua');f.load('UI/help.lua');f.load('UI/condition_text.lua')
 return f,f.addon
end
test('release metadata has a bounded verified URL list for each supported identity',function()
 local _,a=fixture();assert(a.GetIntegrationProjectLinks,'release metadata missing')
 for _,row in ipairs(a:ListIntegrationStatus())do
  local links=a:GetIntegrationProjectLinks(row.id);assert(type(links)=='table' and #links>0 and #links<=32,row.id)
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
  assert(row.provider:GetFontString().justifyV=='MIDDLE','provider text is not vertically centered')
  for _,control in ipairs({row.provider,row.edit,row.copy})do
   local point=control.point;assert(point[1]=='LEFT' and point[2]==row.frame and point[3]=='LEFT' and point[5]==0,'provider, URL and Copy do not share the row center')
  end
  local before=row.edit:GetText();row.edit:SetText('changed');row.edit.scripts.OnTextChanged(row.edit,true)
  assert(row.edit:GetText()==before,'URL typing/paste changed canonical read-only field')
 end
end)
test('copy and URL focus select only their own field and unselect every other URL',function()
 local _,a=fixture();local d=a:ShowIntegrationProjectLink('LUI');local count=#a:GetIntegrationProjectLinks('LUI')
 for i=1,count do
  local row=d.rows[i];row.copy:Click();assert(row.edit.focused and row.edit.selection[1]==0 and row.edit.selection[2]==-1)
  for j=1,count do if i~=j then assert(not d.rows[j].edit.focused and d.rows[j].edit.selection[2]==0,'another URL remains selected')end end
 end
 d.rows[1].edit.scripts.OnEditFocusGained(d.rows[1].edit)
 assert(d.rows[1].edit.selection[2]==-1 and d.rows[count].edit.selection[2]==0)
end)
test('release popup reuses bounded rows and retired copy callbacks cannot target a newer addon',function()
 local _,a=fixture();local d=a:ShowIntegrationProjectLink('LUI');local stale=d.rows[1].copy.scripts.OnClick
 local last=#a:GetIntegrationProjectLinks('LUI');local warm=d.rows[last];local nextDialog=a:ShowIntegrationProjectLink('G15Buttons');assert(nextDialog==d and d.title:GetText()=='G15Buttons')
 assert(not warm.frame:IsShown() and not warm.edit.focused and warm.edit.selection[2]==0)
 stale();assert(not d.rows[1].edit.focused,'old LUI copy selected the new G15Buttons URL')
 local hidden=d.rows[1].copy.scripts.OnClick;d.close:Click();hidden();assert(not d.rows[1].edit.focused)
 assert(a:ShowIntegrationProjectLink('LUI')==d and d.rows[last]==warm)
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
test('all verified provider and edition links render beyond the former eight-row cutoff',function()
 local _,a=fixture();local links={}
 for i=1,12 do links[i]={label='Provider '..i,url='https://github.com/example/project'..i,note='Fixture channel',primary=i==1,families={}}end
 a.GetIntegrationProjectLinks=function()return links,'Many channels'end
 local d=a:ShowIntegrationProjectLink('future-addon');assert(d.rows[12] and d.rows[12].frame:IsShown(),'verified links were silently cut off')
 assert(d.frame:GetHeight()<400 and d.scroll:GetHeight()<d.child:GetHeight(),'additional channels should scroll in the compact popup')
 d.rows[1].copy:Click();d.rows[12].copy:Click()
 assert(d.rows[12].edit:GetText()==links[12].url and d.rows[12].edit.selection[2]==-1 and d.rows[1].edit.selection[2]==0)
end)
finish()
