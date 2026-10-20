-- Actual native forms and real AceDB; no codec dependency for editing/copy tests.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function row()return{itemID=1710,minimum=5,target=12,enabled=true}end
local function deep()local value={};local at=value;for i=1,20000 do local child={};at.child=child;at=child end;return value end
local function fixture()
 local f=F.new();local a,e=f.addon,f.env;local _,create=dofile('tests/fixtures/native_ui.lua')(e)
 a.pretty_name='Rotation Master';a.name='rotationmaster';a.configPaneGeneration=1
 for _,path in ipairs({'Platform/spells.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/rotation_store.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Core/rotation_migration.lua','Help/general.lua','Help/itemsets.lua','UI/window.lua','UI/help.lua','UI/icon_picker.lua','UI/color_picker.lua','UI/settings_roster_order.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/settings_general.lua','UI/settings_profiles.lua','UI/collection_compare.lua','UI/settings_collections.lua','UI/settings_items.lua'})do
  f.load(path)
 end
 local parent=create('Frame');parent:SetSize(1000,600)
 a.db.profile.itemsets={s={name='Set',items={1710}}};a.db.global.itemsets={};a.db.global.effects={};a.db.char={bindings={}}
 return f,a,parent
end
local function aceDB()
 local e=setmetatable({},{__index=_G});e._G=e;e.securecallfunction=function(fn,...)return fn(...)end
 e.CreateFrame=function()return{RegisterEvent=function()end,SetScript=function()end}end
 e.UnitFactionGroup=function()return'Horde'end;e.GetLocale=function()return'enUS'end;e.UnitClass=function()return'Shaman','SHAMAN'end;e.UnitRace=function()return'Orc','Orc'end;e.GetRealmName=function()return'Realm'end;e.UnitNameUnmodified=function()return'Player'end;e.GetCurrentRegionName=function()return'US'end;e.GetCurrentRegion=function()return 1 end;e.strlenutf8=string.len
 for _,path in ipairs({'Libs/LibStub/LibStub.lua','Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua','Libs/AceDB-3.0/AceDB-3.0.lua'})do local chunk=assert(loadfile(path));setfenv(chunk,e);chunk()end
 return e.LibStub('AceDB-3.0'):New('StockUIExternalDB',{profile={version=3,poll=.15},global={},char={}},true)
end
local function profiles()
 local f,a,parent=fixture();local db=aceDB();a.db=db;db:SetProfile('Source');db.profile.poll=.25;db.profile.stockTargets={a=row()};db:SetProfile('Default')
 local p=a:OpenNativeSettings(parent,'Profiles');return f,a,parent,db,p
end
test('actual native deep20000 malformed stock opens Item Sets without recursive draft traversal',function()
 local _,a,parent=fixture();local bad=deep();a.db.profile.stockTargets=bad
 local p=a:OpenNativeSettings(parent,'ItemSets');assert(p.fields.name and p.fields.apply and a.db.profile.stockTargets==bad);assert(p.draft.profile.stockTargets==nil)
end)
test('actual native invalid stock is excluded but unrelated itemset Apply works and preserves saved root',function()
 local _,a,parent=fixture();local bad={};bad.self=bad;a.db.profile.stockTargets=bad;local original=a.CopySettingsData
 a.CopySettingsData=function(self,value,...)assert(value~=bad,'invalid root reached generic copy');return original(self,value,...)end
 local p=a:OpenNativeSettings(parent,'ItemSets');local c=p.fields.name;c:SetText('Updated');c.scripts.OnTextChanged(c,true);p.fields.apply:Click()
 assert(a.db.profile.itemsets.s.name=='Updated'and a.db.profile.stockTargets==bad and bad.self==bad)
end)
test('absent and valid stock preserve detached drafts and no manufactured optional default',function()
 local _,a,parent=fixture();local p=a:OpenNativeSettings(parent,'ItemSets');assert(a.db.profile.stockTargets==nil and p.draft.profile.stockTargets==nil);p:Release()
 local plan={a=row()};a.db.profile.stockTargets=plan;p=a:OpenNativeSettings(parent,'ItemSets');assert(p.draft.profile.stockTargets~=plan and p.draft.profile.stockTargets.a~=plan.a and p.draft.profile.stockTargets.a.target==12 and a.db.profile.stockTargets==plan)
end)
test('actual native duplicate refuses invalid stock before creating or copying profile',function()
 local _,a,_,db,p=profiles();local bad=deep();db.profile.stockTargets=bad;local copies=0;local copy=db.CopyProfile;db.CopyProfile=function(self,...)copies=copies+1;return copy(self,...)end
 p.fields.duplicate:Click();if p.creating then p.fields.apply:Click()end
 assert(copies==0 and db:GetCurrentProfile()=='Default'and not db.profiles['Copy of Default']and db.profile.stockTargets==bad,'invalid duplicate entered AceDB mutation')
end)
test('actual native Copy rechecks source after confirmation and retains destination fields',function()
 local _,a,_,db,p=profiles();local copies=0;local copy=db.CopyProfile;db.CopyProfile=function(self,...)copies=copies+1;return copy(self,...)end
 p.fields.copy:Click();p.menu.rows[1]:Click();assert(p.prompt.frame:IsShown());local bad=deep();db.profiles.Source.stockTargets=bad;p.prompt.accept:Click()
 assert(copies==0 and db:GetCurrentProfile()=='Default'and db.profile.poll==.15 and db.profiles.Source.stockTargets==bad,'stale Copy confirmation entered recursive mutation')
end)
test('actual native saved-profile Compare rechecks roots before generic copy',function()
 local _,a,_,db,p=profiles();p.fields.compare:Click();local bad=deep();db.profiles.Source.stockTargets=bad;local original=a.CopySettingsData
 a.CopySettingsData=function(self,value,...)assert(value~=bad,'invalid comparison root reached generic copy');return original(self,value,...)end
 p.menu.rows[1]:Click();assert(not p.comparison or not p.comparison.frame:IsShown(),'invalid saved profile opened comparison');assert(db.profiles.Source.stockTargets==bad)
end)
test('actual duplicate source invalidated by AceDB profile callback is not copied and previous profile restored',function()
 local _,a,_,db,p=profiles();db.profile.stockTargets={a=row()};local source=db.profile;local copies=0;local copy=db.CopyProfile;db.CopyProfile=function(self,...)copies=copies+1;return copy(self,...)end
 local owner={};db.RegisterCallback(owner,'OnProfileChanged',function()if db:GetCurrentProfile()=='Copy of Default'then db.profile.callbackMarker='preserved';source.stockTargets=deep()end end)
 p.fields.duplicate:Click();p.fields.apply:Click();assert(copies==0 and db:GetCurrentProfile()=='Default'and db.profile==source,'callback-invalidated duplicate copied source or stranded active profile '..tostring(copies)..'/'..db:GetCurrentProfile()..'/'..tostring(db.profile==source)..'/'..p.message:GetText());assert(db.profiles['Copy of Default']and db.profiles['Copy of Default'].callbackMarker=='preserved','do not delete callback-owned destination state')
end)
test('actual valid AceDB duplicate remains detached with previous active profile',function()
 local _,a,_,db,p=profiles();db.profile.stockTargets={a=row()};local source=db.profile;p.fields.duplicate:Click();p.fields.apply:Click();local copy=db.profiles['Copy of Default'];assert(db:GetCurrentProfile()=='Default'and db.profile==source and copy.stockTargets~=source.stockTargets and copy.stockTargets.a~=source.stockTargets.a and copy.stockTargets.a.target==12)
end)
test('actual General draft also excludes deep invalid stock before its unsaved baseline work',function()
 local _,a,parent=fixture();local bad=deep();a.db.profile.stockTargets=bad
 local p=a:OpenNativeSettings(parent,'General');assert(p.active and p.fields.poll and p.draft.profile.stockTargets==nil and a.db.profile.stockTargets==bad)
end)
test('stock-only guard does not impose full transport validation on ordinary profile copying',function()
 local _,a,_,db,p=profiles();db.profile.unknownLegacyField={kept=true};db.profile.poll='legacy-value';p.fields.duplicate:Click();p.fields.apply:Click()
 local result=db.profiles['Copy of Default'];assert(result and result.unknownLegacyField.kept==true and result.poll=='legacy-value' and db:GetCurrentProfile()=='Default')
end)
if pcall(require,'bit')then test('actual native profile import rechecks replacement target before recursive equality',function()
 local _,a,_,db,p=profiles();db.profile.stockTargets={a=row()};local codecData,deps=dofile('tests/fixtures/codec.lua')();a.NewRotationCodec=function()return codecData.NewCodec(deps)end
 p.fields.transfer:Click();assert(p.textDialog and p.textDialog.frame:IsShown());local bad=deep();db.profile.stockTargets=bad;local original=a.CopySettingsData
 a.CopySettingsData=function(self,value,...)assert(value~=bad,'invalid live import target reached generic copy');return original(self,value,...)end
 p.textDialog.apply:Click();assert(p.textDialog.frame:IsShown()and db.profile.stockTargets==bad)
end)else print('SKIP real compressed profile import: native bit dependency absent')end
test('shared safety service reads raw optional stock and projects only malformed field without extra returns',function()
 local _,a=fixture();local safety=assert(a.StockSettings,'stock safety service missing');local reads=0
 local child={unchanged=true};local profile=setmetatable({other=child},{__index=function(_,key)if key=='stockTargets'then reads=reads+1;error('stock inherited getter')end end})
 local validator=a.StockTargets.Validate;a.StockTargets.Validate=function()error('absent optional stock invoked validator')end
 assert(safety.CheckProfile(profile)==true and safety.DraftProfile(profile)==profile and reads==0);a.StockTargets.Validate=validator
 local bad={};bad.self=bad;profile.stockTargets=bad;local projection=safety.DraftProfile(profile)
 assert(select('#',safety.DraftProfile(profile))==1 and projection~=profile and rawget(projection,'stockTargets')==nil and projection.other==child and profile.stockTargets==bad and bad.self==bad)
 for _,value in ipairs({false,7,'future',setmetatable({},{__index=function()error('stock meta getter')end})})do profile.stockTargets=value;assert(not safety.CheckProfile(profile)and safety.DraftProfile(profile).stockTargets==nil and profile.stockTargets==value)end
end)
test('direct Copy rechecks after runtime disable callbacks before AceDB mutates destination',function()
 local _,a,_,db,p=profiles();local copies=0;local copy=db.CopyProfile;db.CopyProfile=function(self,...)copies=copies+1;return copy(self,...)end
 a.DisableRotation=function()db.profiles.Source.stockTargets=deep()end
 p.fields.copy:Click();p.menu.rows[1]:Click();p.prompt.accept:Click()
 assert(copies==0 and db:GetCurrentProfile()=='Default'and db.profile.poll==.15,'disable callback invalidated source after last stock preflight')
end)
test('strict safety inverse closes complete baseline modules and rejects unrelated source edits',function()
 local restore=dofile('tests/fixtures/restore_stock_targets_safety_ui.lua')
 for _,path in ipairs({'UI/settings_draft.lua','UI/settings_profiles.lua','UI/settings_collections.lua'})do
  local file=assert(io.open(path));local source=file:read('*a');file:close();if path=='UI/settings_draft.lua' or path=='UI/settings_collections.lua' then source=dofile('tests/fixtures/restore_stock_targets_ui.lua')(source,path) end;assert(restore(source,path)~=source)
  assert(not pcall(restore,source..'\n-- unrelated change',path),'whole-module safety inverse accepted unrelated edit')
 end
end)
test('duplicate Apply rechecks source changed after entering creation before allocating a destination',function()
 local _,a,_,db,p=profiles();p.fields.duplicate:Click();assert(p.creating);local bad=deep();db.profile.stockTargets=bad
 p.fields.apply:Click();assert(db:GetCurrentProfile()=='Default'and not db.profiles['Copy of Default']and db.profile.stockTargets==bad)
end)
test('saved-profile Compare ignores deleted live source and retired selection callbacks',function()
 local _,a,_,db,p=profiles();p.fields.compare:Click();local choose=p.menu.rows[1].scripts.OnClick;db:DeleteProfile('Source');choose();assert(not p.comparison or not p.comparison.frame:IsShown())
 p:Draw();db:SetProfile('Source');db:SetProfile('Default');p:Draw();p.fields.compare:Click();choose=p.menu.rows[1].scripts.OnClick;p:Release();choose();assert(not p.comparison or not p.comparison.frame:IsShown())
end)
finish()
