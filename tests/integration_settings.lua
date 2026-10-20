-- Actual native form transitions; bundled codecs/AceDB are used where available.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(options)
 options=options or{};local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
 a.pretty_name='Rotation Master';a.name='rotationmaster';a.configPaneGeneration=1
 for _,path in ipairs({'UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/settings_collections.lua','UI/lua_editor.lua','UI/settings_integrations.lua'})do f.load(path)end
 local ok=pcall(require,'bit')
 if ok then local data,deps=dofile('tests/fixtures/codec.lua')();a.RotationData=data;a.NewRotationCodec=function()return data.NewCodec(deps)end
 elseif not a.RotationData then for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua'})do f.load(path)end end
 local rawCreate=create
 local function withFontAPI(kind,name,parent,template)
  local frame=rawCreate(kind,name,parent,template);local make=frame.CreateFontString
  function frame:CreateFontString(...)
   local label=make(self,...);function label:SetNonSpaceWrap(value)self.nonSpaceWrap=value end;return label
  end
  return frame
 end
 f.env.CreateFrame=withFontAPI;create=withFontAPI
 local loaded={LuaWorkbench=options.workbench~=false,Questie=options.questie~=false,ExtendedCharacterStats=true,MobInfo2=false,WeakAuras=true,Dominos=true}
 local calls={sync=0,refresh=0,created=0};a.db.profile.lua_editor=options.selected or'auto'
 a.LuaSyntax={enable=function()end,disable=function()end,decode=function(s)return s end}
 a.ListIntegrationStatus=function()
  local rows={};for _,row in ipairs({{'!!!LuaWorkbench','LuaWorkbench','Lua editor integration.'},{'WowLua','WowLua','Optional editor addon.'},{'ExtendedCharacterStats','ExtendedCharacterStats','Optional character statistics conditions.'},{'MobInfo2','MobInfo2','Recorded creature history conditions.'},{'WeakAuras','WeakAuras','Recommendation event bridge.'},{'Questie','Questie','Quest update receipts only.'},{'Dominos','Dominos','Optional action-bar glow support.'}})do
   rows[#rows+1]={id=row[1],name=row[2],version=loaded[row[2]]and'1.2.3'or nil,state=loaded[row[2]]and'loaded'or'missing',detail=row[3]}
  end;return rows
 end
 a.DiscoverLuaEditorIntegrations=function()end
 a.IsLuaWorkbenchIntegrationAvailable=function()return loaded.LuaWorkbench end
 a.SyncQuestieIntegration=function()calls.sync=calls.sync+1 end;a.RefreshQuestieIntegration=function()calls.refresh=calls.refresh+1 end
 a.GetQuestieIntegrationStatus=function()return{state='disabled'}end
 local function register(id)
  a:RegisterLuaEditorProvider(id,function(host,changed,valid)
   calls.created=calls.created+1;if not loaded[id]then return nil end
   return a:CreateWorkbenchLuaEditor(host,changed,valid,'plain')
  end);loaded[id]=loaded[id]~=false
 end
 register('LuaWorkbench')
 local parent=create('Frame');parent:SetSize(options.width or 1000,600)
 local p=a:OpenNativeSettings(parent,'Integrations')
 return f,a,p,loaded,calls,register,parent
end
local function click(p,key)local c=assert(p.fields[key],key..' missing');c:Click();return c end
local function pill(p,id)return assert(p.fields['integration_status_'..id],'status '..id..' missing')end
local function state(p,id)return pill(p,id):GetText()end
local function draft(p)return p:SettingsData().profile end
local function choose(p,id)
 local menu=assert(p.menu,'menu missing')
 for _,row in ipairs(menu.rows)do
  local entry=menu.matches and menu.matches[row.menuIndex]
  if entry and entry.value==id then row:Click();return end
 end
 error('choice '..id..' missing')
end
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end

test('line numbers is global directly below editor heading and Native has only syntax highlighting',function()
 local _,_,p=fixture();assert(p.fields.integration_card_editor_native and p.fields.lua_line_numbers and p.fields.lua_native_highlighting)
 assert(not p.fields.integration_select_auto and not p.fields.integration_select_plain and not p.fields.integration_enable_native)
 assert(not p.fields.integration_card_editor_options)
 assert(p.fields.lua_line_numbers:GetParent()==p.child)
 assert(p.fields.lua_native_highlighting:GetParent()==p.fields.integration_card_editor_native)
 local heading=p.fields.section_integrations_editors
 assert(heading and -p.fields.lua_line_numbers.point[3]>-heading.point[3] and -p.fields.lua_line_numbers.point[3]<-p.fields.integration_card_editor_native.point[3])
 assert(p.fields.integration_help_editor_native and not p.fields.questie_refresh)
end)
test('pill colors and fixed states replace description status and passive switches',function()
 local _,_,p=fixture();assert(state(p,'editor_LuaWorkbench')=='Selected' and state(p,'editor_native')=='Enabled')
 assert(state(p,'ExtendedCharacterStats')=='Supported' and state(p,'MobInfo2')=='Not loaded')
 assert(not pill(p,'MobInfo2'):IsEnabled()and not pill(p,'ExtendedCharacterStats'):IsEnabled())
 assert(state(p,'Questie')=='Disabled')
 for _,label in ipairs(p.pool.integrationLabels or{})do assert(not label:GetText():find('Loaded; connection not confirmed.',1,true))end
end)
test('cards span available form width and measure name version columns before description',function()
 local _,_,p=fixture({width=1300});assert(p.width>760)
 assert(p.fields.integration_card_editor_native:GetWidth()==p.width)
 local before=p.fields.integration_card_editor_native:GetWidth();p.frame:SetWidth(500);p:Draw();assert(p.fields.integration_card_editor_native:GetWidth()<before)
 for _,c in ipairs(p.pool.integrationLabels or{})do assert(c:GetWidth()>0 and c:GetWidth()<p.width)end
end)
test('Native highlighting and line numbers are independent draft preferences',function()
 local _,a,p=fixture({selected='plain'});assert(not p.fields.lua_native_highlighting:GetChecked())
 click(p,'lua_native_highlighting');assert(draft(p).lua_native_highlighting==true and draft(p).lua_editor=='native' and not a.db.profile.lua_native_highlighting)
 click(p,'lua_line_numbers');assert(draft(p).lua_line_numbers==false)
 p:DiscardSettingsDraft();p:Draw();assert(not p.fields.lua_native_highlighting:GetChecked() and p.fields.lua_line_numbers:GetChecked())
end)
test('highlight option does not switch an external selected editor',function()
 local _,_,p=fixture({selected='LuaWorkbench'});click(p,'lua_native_highlighting');assert(draft(p).lua_editor=='LuaWorkbench' and draft(p).lua_native_highlighting==false)
end)
test('Enabled pill offers Disable and Select without mutating until choice',function()
 local _,_,p=fixture();local before=draft(p).lua_editor;click(p,'integration_status_editor_native')
 assert(draft(p).lua_editor==before and not draft(p).lua_editor_disabled)
 choose(p,'select');assert(draft(p).lua_editor=='native' and state(p,'editor_native')=='Selected')
end)
test('menu cancel has no field change or caption write',function()
 local _,_,p=fixture();local text=state(p,'editor_native');click(p,'integration_status_editor_native');p.menu:Hide()
 assert(state(p,'editor_native')==text and draft(p).lua_editor=='auto' and not p:IsSettingsDraftDirty())
end)
test('Selected pill disables and hands off to the sole enabled alternative atomically',function()
 local _,a,p=fixture({selected='LuaWorkbench'});click(p,'integration_status_editor_LuaWorkbench')
 assert(draft(p).lua_editor_disabled.LuaWorkbench and draft(p).lua_editor=='native' and state(p,'editor_native')=='Selected')
 assert(a.db.profile.lua_editor=='LuaWorkbench' and not a.db.profile.lua_editor_disabled)
end)
test('Selected with no enabled alternative disables to plain emergency fallback',function()
 local _,_,p=fixture({workbench=false,selected='native'});click(p,'integration_status_editor_native')
 assert(draft(p).lua_editor_disabled.native and draft(p).lua_editor=='plain' and state(p,'editor_native')=='Disabled')
end)
test('Selected multiple alternatives prompts without partial changes and commit chooses one',function()
 local _,_,p,loaded,_,register=fixture({selected='native'});register('Another');loaded.Another=true;p:Draw()
 click(p,'integration_status_editor_native');assert(not draft(p).lua_editor_disabled and draft(p).lua_editor=='native')
 choose(p,'LuaWorkbench');assert(draft(p).lua_editor_disabled.native and draft(p).lua_editor=='LuaWorkbench')
end)
test('Disabled click enables only when another editor is selected',function()
 local _,a,p=fixture({selected='native'});a.db.profile.lua_editor_disabled={LuaWorkbench=true};p:DiscardSettingsDraft();p:Draw()
 click(p,'integration_status_editor_LuaWorkbench');assert(not (draft(p).lua_editor_disabled or{}).LuaWorkbench and draft(p).lua_editor=='native')
end)
test('all disabled allows any clicked available editor to enable and select itself',function()
 local _,a,p=fixture({selected='plain'});a.db.profile.lua_editor_disabled={native=true,LuaWorkbench=true};p:DiscardSettingsDraft();p:Draw()
 click(p,'integration_status_editor_LuaWorkbench');assert(draft(p).lua_editor=='LuaWorkbench' and draft(p).lua_editor_disabled.native and not draft(p).lua_editor_disabled.LuaWorkbench)
end)
test('stale menu and released callbacks never overwrite a newer owner or pill caption',function()
 local _,a,p=fixture();click(p,'integration_status_editor_native');local stale
 for _,row in ipairs(p.menu.rows)do if row:IsShown()then stale=row.scripts.OnClick;break end end;assert(stale)
 local old=state(p,'editor_native');p:Draw();stale();assert(draft(p).lua_editor=='auto' and state(p,'editor_native')==old)
 local callback=pill(p,'editor_LuaWorkbench').scripts.OnClick;p:Release();callback();assert(a.db.profile.lua_editor=='auto')
end)
test('menu commit rechecks availability and leaves selected disable uncommitted on disappearance',function()
 local _,_,p,loaded,_,register=fixture({selected='native'});register('Another');loaded.Another=true;p:Draw()
 click(p,'integration_status_editor_native');loaded.LuaWorkbench=false;choose(p,'LuaWorkbench')
 assert(draft(p).lua_editor=='native' and not draft(p).lua_editor_disabled)
end)
test('64 key disable cap refuses a new entry without changing selection',function()
 local _,a,p,loaded,_,register=fixture({selected='native'});local map={}
 for i=1,64 do map['Stored '..i]=true end;a.db.profile.lua_editor_disabled=map;register('Another');loaded.Another=true;p:DiscardSettingsDraft();p:Draw()
 click(p,'integration_status_editor_native');choose(p,'LuaWorkbench')
 assert(count(draft(p).lua_editor_disabled)==64 and not draft(p).lua_editor_disabled.native and draft(p).lua_editor=='native')
end)
test('Questie pill toggles only loaded preference and Sync waits for Apply',function()
 local _,a,p,_,calls=fixture();click(p,'integration_status_Questie');assert(draft(p).questie_enabled and state(p,'Questie')=='Enabled' and calls.sync==0 and calls.refresh==0)
 assert(p:SaveSettingsDraft());assert(a.db.profile.questie_enabled and calls.sync==1)
end)
test('missing Questie pill is gray inert and options have no prose or Refresh',function()
 local _,_,p,_,calls=fixture({questie=false});assert(state(p,'Questie')=='Not loaded');click(p,'integration_status_Questie');assert(not draft(p).questie_enabled and calls.sync==0)
 assert(not p.fields.questie_enabled and not p.fields.questie_refresh)
 local card=p.fields.integration_card_Questie
 for _,c in ipairs(p.pool.text or{})do assert(c:GetParent()==p.child,'options contain prose')end
 assert(card and not p.fields.integration_help_Questie)
end)
test('draft conflict refuses partial selection and disable publication; Discard restores saved fields',function()
 local _,a,p=fixture({selected='LuaWorkbench'});click(p,'integration_status_editor_LuaWorkbench');a.db.profile.lua_editor_disabled={Other=true}
 assert(not p:SaveSettingsDraft());assert(a.db.profile.lua_editor=='LuaWorkbench' and not a.db.profile.lua_editor_disabled.LuaWorkbench)
 p:DiscardSettingsDraft();p:Draw();assert(draft(p).lua_editor=='LuaWorkbench' and not draft(p).lua_editor_disabled.LuaWorkbench)
end)
test('closed portable profile preserves custom disable keys and native bool; rejects malformed bounds',function()
 local _,a=fixture();local input={lua_editor='plain',lua_native_highlighting=false,lua_editor_disabled={native=true,['Custom provider']=true}}
 assert(a:ValidateProfileTransfer(input));local restored=assert(a:ProfileFromPortable(assert(a:ProfileToPortable(input))));assert(restored.lua_native_highlighting==false and restored.lua_editor_disabled['Custom provider'])
 for _,map in ipairs({{auto=true},{plain=true},{['']=true},{['  ']=true},{x=false},{x=1},setmetatable({x=true},{})})do assert(not a:ValidateProfileTransfer({lua_editor_disabled=map}))end
 local tooMany={};for i=1,65 do tooMany['Provider '..i]=true end;assert(not a:ValidateProfileTransfer({lua_editor_disabled=tooMany}))
 assert(not a:ValidateProfileTransfer({lua_native_highlighting='true'}))
end)
test('actual codec roundtrip retains native bool and bounded stored unknown provider preferences',function()
 if not (bit or bit32)then print('SKIP real LibCompress codec: native bit library unavailable');return end
 local _,a=fixture();local value={lua_editor='native',lua_native_highlighting=false,lua_editor_disabled={Future=true}}
 local codec=assert(a.NewRotationCodec());local wire=assert(codec:Encode(a:ProfileToPortable(value)));local decoded=assert(codec:Decode(wire));local restored=assert(a:ProfileFromPortable(decoded.value));assert(restored.lua_native_highlighting==false and restored.lua_editor_disabled.Future)
end)
test('actual AceDB CopyProfile and ResetProfile preserve or clear new preferences',function()
 local f=assert(io.open('tests/startup.lua'));local source=f:read('*a');f:close();local prefix=assert(source:match('^(.-)\ntest%('));local persistent=assert(source:match('(local function persistentFixture.-)\n%-%- WoW SavedVariables'))
 local make=assert(loadstring(prefix..'\n'..persistent..'\nreturn persistentFixture'))();local _,a=make()
 a.db.profile.lua_editor='plain';a.db.profile.lua_native_highlighting=false;a.db.profile.lua_editor_disabled={Custom=true}
 a.db:SetProfile('Other');assert(a.db.profile.lua_native_highlighting==nil and not a.db.profile.lua_editor_disabled)
 a.db:CopyProfile('Default');assert(a.db.profile.lua_native_highlighting==false and a.db.profile.lua_editor_disabled.Custom)
 a.db:ResetProfile();assert(a.db.profile.lua_native_highlighting==nil and not a.db.profile.lua_editor_disabled)
end)
test('native layout keeps controls in their cards and reuses warm pooled resources',function()
 local _,_,p=fixture({width=420});local card=p.fields.integration_card_editor_native;assert(card)
 local pools={};for kind,rows in pairs(p.pool)do pools[kind]=#rows end
 for i=1,5 do p:Draw();assert(p.fields.integration_card_editor_native==card)end
 for kind,n in pairs(pools)do assert(#p.pool[kind]==n)end
 local old=pill(p,'editor_native').scripts.OnClick;p:Release();old();assert(not p.frame:IsShown())
end)
test('provider names only request owned copyable links and retired name handlers stay inert',function()
 local _,a,p=fixture();local list=a.ListIntegrationStatus;local shown=0
 a.ListIntegrationStatus=function(self)local rows=list(self);for _,row in ipairs(rows)do if row.id=='Questie'then row.projectURL='https://www.curseforge.com/wow/addons/questie'end end;return rows end
 a.ShowIntegrationProjectLink=function(self,id)assert(self==a and id=='Questie');shown=shown+1 end
 p:Draw();assert(not p.fields.integration_name_editor_native:IsEnabled())
 click(p,'integration_name_Questie');assert(shown==1)
 local stale=p.fields.integration_name_Questie.scripts.OnClick;p:Draw();stale();assert(shown==1)
 local current=p.fields.integration_name_Questie.scripts.OnClick;local oldMeta=getmetatable(a)
 a.ShowIntegrationProjectLink=nil;setmetatable(a,{__index=function(_,key)if key=='ShowIntegrationProjectLink'then p:Release();return function()shown=shown+1 end end end})
 current();setmetatable(a,oldMeta);assert(shown==1)
end)
test('availability method lookup retirement stops the old menu before another call or publication',function()
 local _,a,p,loaded,_,register=fixture({selected='native'});register('Another');loaded.Another=true;p:Draw();click(p,'integration_status_editor_native')
 local list=a.ListLuaEditorProviders;local calls=0;local oldMeta=getmetatable(a);a.ListLuaEditorProviders=nil
 setmetatable(a,{__index=function(_,key)if key=='ListLuaEditorProviders'then p:Release();return function(self)calls=calls+1;return list(self)end end end})
 choose(p,'LuaWorkbench');setmetatable(a,oldMeta);assert(calls==0 and a.db.profile.lua_editor=='native' and not a.db.profile.lua_editor_disabled)
end)
test('selection remembers the legacy inferred highlighting preference without Draw normalization',function()
 local _,a,p=fixture({selected='plain'});assert(draft(p).lua_native_highlighting==nil)
 click(p,'integration_status_editor_LuaWorkbench');choose(p,'select')
 assert(draft(p).lua_editor=='LuaWorkbench'and draft(p).lua_native_highlighting==false and not p.fields.lua_native_highlighting:GetChecked())
 assert(a.db.profile.lua_native_highlighting==nil and a.db.profile.lua_editor=='plain')
end)
test('registered custom editor can be selected and persistently disabled through the same handoff',function()
 local _,_,p,loaded,_,register=fixture({selected='native'});register('Another');loaded.Another=true;p:Draw()
 click(p,'integration_status_editor_Another');choose(p,'select');assert(draft(p).lua_editor=='Another')
 click(p,'integration_status_editor_Another');choose(p,'native')
 assert(draft(p).lua_editor_disabled.Another and draft(p).lua_editor=='native'and state(p,'editor_Another')=='Disabled')
end)
test('loaded versions preserve complete short and long text with nonspace wrapping at full and narrow width',function()
 local _,a,p=fixture();local original=a.ListIntegrationStatus;local version=string.rep('1234567890',28)
 a.ListIntegrationStatus=function(self)local rows=original(self);for _,row in ipairs(rows)do if row.id=='Questie'then row.version=version end end;return rows end
 for _,width in ipairs({1300,420})do
  p.frame:SetWidth(width);p:Draw();local card=assert(p.fields.integration_card_Questie);local versionLabel
  for _,label in ipairs(p.pool.integrationLabels)do if label:GetParent()==card and label:GetText()==version then versionLabel=label end end
  assert(versionLabel and versionLabel.nonSpaceWrap==true and versionLabel.maxLines==0,'version can still clip a nonspace run')
  assert(versionLabel:GetHeight()>=versionLabel:GetStringHeight() and card:GetHeight()>=versionLabel:GetHeight()+20)
  local x=versionLabel.point[2];assert(x>=0 and x+versionLabel:GetWidth()<=card:GetWidth())
 end
 version='1.2.3';p.frame:SetWidth(1300);p:Draw();local found
 for _,label in ipairs(p.pool.integrationLabels)do if label:GetParent()==p.fields.integration_card_Questie and label:GetText()==version then found=label end end
 assert(found and found:GetWidth()>=found:GetStringWidth(),'natural short version was squeezed')
end)
test('not loaded versions remain empty even when installed metadata includes a version',function()
 local _,a,p=fixture({workbench=false,questie=false});local original=a.ListIntegrationStatus
 a.ListIntegrationStatus=function(self)local rows=original(self);for _,row in ipairs(rows)do if row.state=='missing'then row.version='99.88.installed-not-loaded'end end;return rows end
 p:Draw()
 for _,id in ipairs({'editor_LuaWorkbench','WowLua','MobInfo2','Questie'})do
  local card=assert(p.fields['integration_card_'..id]);local empty=0
  for _,label in ipairs(p.pool.integrationLabels)do if label:GetParent()==card then assert(label:GetText()~='99.88.installed-not-loaded'and label:GetText()~='Unknown');if label:GetText()==''then empty=empty+1 end end end
  assert(empty>=1,'missing addon version cell not empty')
 end
 -- Actual addon load evidence, not editor-capability availability, owns version display.
 a.ListIntegrationStatus=function(self)local rows=original(self);for _,row in ipairs(rows)do if row.id=='!!!LuaWorkbench'then row.state='loaded';row.version='7.8.9.loaded-capability-unavailable'end end;return rows end
 p:Draw();local found=false
 for _,label in ipairs(p.pool.integrationLabels)do if label:GetParent()==p.fields.integration_card_editor_LuaWorkbench and label:GetText()=='7.8.9.loaded-capability-unavailable'then found=true end end
 assert(found,'loaded version was hidden by editor capability failure')
end)
test('version display prioritizes explicit addon load evidence independently of connection status',function()
 local f,a,p=fixture();local original=a.ListIntegrationStatus;local version='4.3.2.load-evidence'
 local function rendered()
  local card=assert(p.fields.integration_card_Questie)
  for _,label in ipairs(p.pool.integrationLabels)do if label:GetParent()==card and label:GetText()==version then return true end end
  return false
 end
 for _,case in ipairs({{loaded=true,state='unknown',show=true},{loaded=true,state='missing',show=true},{loaded=false,state='connected',show=false},{state='connected',show=true},{state='unknown',show=false}})do
  a.ListIntegrationStatus=function(self)local rows=original(self);for _,row in ipairs(rows)do if row.id=='Questie'then row.loaded=case.loaded;row.state=case.state;row.version=version end end;return rows end
  p:Draw();assert(rendered()==case.show,'load evidence lost to connection state '..case.state)
 end
 -- Actual catalog: native load/version succeeds while cached Questie status fails.
 f.env.IsAddOnLoaded=function(id)return id=='Questie'end
 f.env.GetAddOnMetadata=function(_,field)assert(field=='Version');return version end
 a.Platform.CanReadValue=function()return true end
 a.GetQuestieIntegrationStatus=function()error('private cached connection failure')end
 f.load('Integrations/catalog.lua')
 local entry;for _,row in ipairs(a:ListIntegrationStatus())do if row.id=='Questie'then entry=row end end
 assert(entry and entry.loaded==true and entry.state=='unknown')
 p:Draw();assert(rendered(),'actual loaded Questie version disappeared after cached-status error')
end)
test('shared integration help stays at page level; option help is beneath the status pill',function()
 local f,a,p=fixture();f.load('UI/help.lua');local shown={};local L=f.env.LibStub('AceLocale-3.0'):GetLocale('rotationmaster')
 a.ShowWorkbenchHelp=function(_,name,sections)shown={name=name,sections=sections}end
 for _,id in ipairs({'editor_LuaWorkbench','ExtendedCharacterStats','MobInfo2','WeakAuras','Dominos','WowLua','Questie'})do
  assert(not p.fields['integration_help_'..id],'generic Help repeated on addon '..id)
 end
 for _,id in ipairs({'editor_native'})do
  local help=assert(p.fields['integration_help_'..id]);local status=pill(p,id);local card=p.fields['integration_card_'..id]
  assert(help:GetParent()==card and help.point[1]=='TOPLEFT')
  assert(help.point[2]+help:GetWidth()==status.point[2]+status:GetWidth(),'Help is not right aligned with Status')
  assert(-help.point[3]>=-status.point[3]+status:GetHeight()+6,'Help is not below Status')
  assert(-help.point[3]+help:GetHeight()+6<=card:GetHeight(),'Help exceeds its card')
 end
 click(p,'integration_help_editor_native');assert(shown.sections[1].text==L['Help.Integrations.native_highlighting'],'Native Help repeats general editor instructions')
 local page=a:GetIntegrationOptionHelp();local common={};for _,section in ipairs(page)do common[section.id]=section.text end
 assert(common.lua_editor and common.optional_addons and common.lua_line_numbers and common.questie_enabled,'shared guidance not available in page Help')
end)
test('integration sections collapse without settings mutations and retire pooled old callbacks',function()
 local _,a,p=fixture();local before=a:CopySettingsData(draft(p));local section=assert(p.fields.section_integrations_editors)
 for _,key in ipairs({'editors','conditions','notifications','quests','actionbars'})do assert(p.fields['section_integrations_'..key])end
 local stale=p.fields.integration_status_editor_native.scripts.OnClick;local oldSection=section.scripts.OnClick
 click(p,'section_integrations_editors');assert(p.closedSections.integrations_editors and not p.fields.lua_line_numbers and not p.fields.integration_card_editor_native)
 assert(p.fields.integration_card_Questie and not p:IsSettingsDraftDirty())
 stale();oldSection();assert(p.closedSections.integrations_editors and not p.menu)
 click(p,'section_integrations_editors');assert(p.fields.lua_line_numbers and p.fields.integration_card_editor_native and not p:IsSettingsDraftDirty())
 assert(draft(p).lua_editor==before.lua_editor and not draft(p).lua_editor_disabled)
 local retired=p.fields.section_integrations_conditions.scripts.OnClick;p:Release();retired();assert(not p.closedSections.integrations_conditions)
end)
test('only explicit unsupported clients hide inventory and editor menu candidates',function()
 local _,a,p=fixture();local context={family='tbc',build=123};local clientCalls=0;local seen={}
 a.Platform.GetClientInfo=function()clientCalls=clientCalls+1;return context end
 a.GetIntegrationClientSupport=function(_,id,client)assert(client==context);seen[id]=true;return ({['!!!LuaWorkbench']='unsupported',Questie='unsupported',Dominos='unsupported',MobInfo2='unknown'})[id] or'supported'end
 p:Draw();assert(clientCalls==1 and seen['!!!LuaWorkbench'] and not seen.LuaWorkbench)
 assert(not p.fields.integration_card_editor_LuaWorkbench and not p.fields.integration_card_Questie and not p.fields.section_integrations_quests and not p.fields.integration_card_Dominos)
 assert(p.fields.integration_card_editor_native and p.fields.integration_card_MobInfo2 and state(p,'editor_native')=='Selected')
 click(p,'integration_status_editor_native');assert(draft(p).lua_editor=='plain'and draft(p).lua_editor_disabled.native and not p.menu)
end)
test('support is rechecked at menu commit and unknown or failed support remains visible',function()
 local _,a,p=fixture({selected='native'});local reject=false
 a.GetIntegrationClientSupport=function(_,id)if id=='!!!LuaWorkbench'and reject then return'unsupported'end;return'unknown'end
 p:Draw();click(p,'integration_status_editor_LuaWorkbench');reject=true;choose(p,'select')
 assert(draft(p).lua_editor=='native'and not draft(p).lua_editor_disabled)
 a.GetIntegrationClientSupport=function()error('private compatibility error')end
 a.Platform.GetClientInfo=function()error('private client error')end
 assert(pcall(function()p:Draw()end));assert(p.fields.integration_card_editor_LuaWorkbench and p.fields.integration_card_Questie)
end)
test('client and support lookups stop an obsolete drawing before provider work',function()
 local _,a,p=fixture();local calls=0
 a.GetIntegrationClientSupport=function()calls=calls+1;return'supported'end
 a.Platform.GetClientInfo=function()p:Release();return{family='retail'}end
 p:Draw();assert(not p.active and calls==0 and not p.fields.integration_card_editor_native)
 local _,b,q=fixture();local prior=getmetatable(b);b.GetIntegrationClientSupport=nil
 setmetatable(b,{__index=function(_,key)if key=='GetIntegrationClientSupport'then q:Release();return function()error('obsolete support call')end end;return prior and prior.__index and prior.__index(b,key)end})
 assert(pcall(function()q:Draw()end));assert(not q.active and not q.fields.integration_card_editor_native)
end)
test('only Native options use gold standard Help below Status at full and narrow widths',function()
 local _,_,p=fixture()
 for _,width in ipairs({1300,420})do
  p.frame:SetWidth(width);p:Draw()
  for _,id in ipairs({'editor_native'})do
   local help=assert(p.fields['integration_help_'..id]);local card=p.fields['integration_card_'..id];local status=pill(p,id)
   assert(help:GetWidth()==20 and help:GetHeight()==20 and help.icon:GetWidth()==18,'Help does not match condition card icon dimensions')
   assert(help.icon.color[1]==1 and help.icon.color[2]==.82 and help.icon.color[3]==.25)
   assert(help.point[2]+20==status.point[2]+status:GetWidth())
   assert(-help.point[3]>=-status.point[3]+status:GetHeight()+6 and -help.point[3]+26<=card:GetHeight())
  end
  local syntax=p.fields.lua_native_highlighting;local help=p.fields.integration_help_editor_native
  assert(syntax.point[3]==help.point[3],'Help pushed the first addon option below its row')
  assert(syntax.point[2]+syntax:GetWidth()+8<=help.point[2],'addon option overlaps Help')
  assert(not p.fields.integration_help_editor_LuaWorkbench and not p.fields.integration_help_Dominos and not p.fields.integration_help_Questie)
 end
end)
finish()
