local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();local a=f.addon;assert(a.InvalidateRotationDependencies,'managed writer API missing');a.db.global.itemsets={};a.db.global.effects={};a.db.profile.itemsets={};f.load('Core/conditions.lua');return f,a
end
local function stamp(a)
 for i=1,20 do local key,value=debug.getupvalue(a.InvalidateRotationDependencies,i);if key=='stamp'then return value end end
 error('actual private dependency generation missing')
end
local function condition()return {fields={},valid=function()return true end,evaluate=function()return true end,print=function()return'test'end,widget=function()end,help=function()end}end
local function settings()
 local f=F.new();local a,e=f.addon,f.env;local _,create=dofile('tests/fixtures/native_ui.lua')(e)
 a.pretty_name='Rotation Master';a.name='rotationmaster';a.configPaneGeneration=1
 for _,path in ipairs({'UI/settings_roster_order.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/collection_compare.lua','UI/settings_collections.lua','UI/settings_effects.lua','UI/settings_items.lua'})do f.load(path)end
 local parent=create('Frame');parent:SetSize(1000,600);return f,parent
end
test('registration publishes invalidation before trusted register hook',function()
 local _,a=fixture();local before=stamp(a);local d=condition();d.on_register=function()assert(stamp(a)~=before)end;a:RegisterCondition('LIVE',d);before=stamp(a);a:UnregisterCondition('LIVE');assert(stamp(a)~=before)
end)
test('captured writer notification performs no live callable probe after publication',function()
 local f,a=fixture();local before=stamp(a);local d=condition()
 f.env.type=function(value)
  if value==a.InvalidateRotationDependencies and a.conditionDefinitions.LIVE==d then assert(stamp(a)~=before,'live callable probe observed unmarked publication')end
  return type(value)
 end
 a:RegisterCondition('LIVE',d);assert(stamp(a)~=before)
end)
test('in-place helper availability and suspension transitions invalidate before resumed hooks',function()
 local f,a=fixture();local d=condition();d.functionBindings={helper='BASE'};d.functionSuspended=true;a:RegisterCondition('LIVE',d)
 local before=stamp(a);a.AreFunctionBindingsAvailable=function()return true end;d.on_register=function()assert(stamp(a)~=before,'resume hook saw old dependency generation')end
 assert(a:RefreshFunctionConsumers(true));assert(not d.functionSuspended)
 before=stamp(a);a.AreFunctionBindingsAvailable=function()return false,'missing'end;assert(a:PrepareFunctionConsumerTransition({}));assert(d.functionSuspended and stamp(a)~=before)
end)
test('staged effects and itemsets stay quiet until actual Apply and notify before refresh',function()
 local f,parent=settings();local a=f.addon;assert(a.InvalidateRotationDependencies,'service missing');a.db.global.effects={e={name='Effect',type='pixel'}};a.db.profile.itemsets={s={name='Set',items={1}}}
 local p=a:OpenNativeSettings(parent,'ItemSets');local before=stamp(a);local input=p.fields.name;input:SetText('Changed');input.scripts.OnTextChanged(input,true);assert(stamp(a)==before)
 a.ButtonFetch=function()assert(stamp(a)~=before,'publication refresh saw old generation')end;p.fields.apply:Click();assert(a.db.profile.itemsets.s.name=='Changed'and stamp(a)~=before)
 before=stamp(a);p=a:OpenNativeSettings(parent,'ItemSets',p);p:DiscardSettingsDraft();assert(stamp(a)==before)
end)
test('each callback-separated settings root publication invalidates again',function()
 local f,parent=settings();local a=f.addon;assert(a.InvalidateRotationDependencies,'service missing');local p=a:CreateSettingsForm(parent);p.transactionKeys={profile={'itemsets'},global={'itemsets'}};p:Open(function(form)form:SettingsData()end)
 local draft=p:SettingsData();draft.profile.itemsets={p={items={1}}};draft.global.itemsets={g={items={2}}};local copy=a.CopySettingsData;local observed,firstPublished
 a.CopySettingsData=function(self,value,...)
  if firstPublished then observed=stamp(a)end;local result=copy(self,value,...);firstPublished=true;return result
 end
 assert(p:SaveSettingsDraft());assert(observed and stamp(a)~=observed,'later settings publication reused epoch minted before intervening copy')
end)
test('same-root profile refresh always invalidates before initialization callbacks',function()
 local f,a=fixture();f.load('Core/rotation_lifecycle.lua');local before=stamp(a);a.InitializeScopedRotationStorage=function()assert(stamp(a)~=before,'profile refresh reused old epoch');return true end;a.InitializeRotationLibrary=function()end
 assert(a:RefreshRotationProfileStorage());assert(stamp(a)~=before)
end)
test('custom registration rollback cannot regain provisional epoch before old hook resumes',function()
 local f,a=fixture();f.load('Core/custom_authoring.lua');f.env.loadstring=function(code,name)local fn,why=loadstring(code,name);if fn then setfenv(fn,f.env)end;return fn,why end
 local source={description='Old',icon=1,fields={}};for callback in pairs(a.CustomConditionCallbacks)do source[callback]=''end
 assert(a:InstallCustomCondition('OLD',source,nil));local previous=a.conditionDefinitions.OLD;local provisional;a.CaptureDependencyToken=function(self)self.provisionalDependency=stamp(self)end
 f.env.type=function(value)assert(value~=a.InvalidateRotationDependencies,'rollback performed live callable probe');return type(value)end
 previous.on_register=function()assert(a.provisionalDependency and stamp(a)~=a.provisionalDependency,'rollback reused provisional dependency epoch')end
 local broken=a:CopySettingsData(source);broken.on_register='addon:CaptureDependencyToken();error("registration marker")'
 assert(not a:InstallCustomCondition('OLD',broken,previous));provisional=a.provisionalDependency;assert(provisional and stamp(a)~=provisional and a.conditionDefinitions.OLD==previous)
end)
test('confirmed native itemset deletion notifies only after accept and before button refresh',function()
 local f,parent=settings();local a=f.addon;assert(a.InvalidateRotationDependencies);a.db.profile.itemsets={s={name='Set',items={1}}};a.db.global.itemsets={}
 local p=a:OpenNativeSettings(parent,'ItemSets');local before=stamp(a);p.fields.delete:Click();assert(stamp(a)==before);p.prompt.cancel:Click();assert(stamp(a)==before)
 a.UpdateItemSetButtons=function()assert(stamp(a)~=before,'delete refresh saw stale epoch')end;p.fields.delete:Click();p.prompt.accept:Click();assert(a.db.profile.itemsets.s==nil and stamp(a)~=before)
end)
test('actual function bundle rollback never restores private generation with public registry versions',function()
 local h=assert(io.open('tests/function_data.lua'));local sourceText=h:read('*a');h:close();local prefix=assert(sourceText:match('^(.-)\ntest%('));local bundleFixture,source,condition=assert(loadstring(prefix..'\nreturn fixture,source,condition','@dependency-bundle-fixture'))()
 local f,a=bundleFixture();f.load('Core/conditions.lua');assert(a.InvalidateRotationDependencies);assert(a:InstallCustomFunction('BASE',source('return value+1')))
 local old=condition(a);old.bindings={helper='BASE'};assert(a:InstallCustomCondition('ROOT',old,nil));local original=a.conditionDefinitions.ROOT;local version=a.conditionRegistryVersion;a.CaptureDependencyToken=function(self)self.provisionalDependency=stamp(self)end
 local _,sender=bundleFixture();assert(sender:InstallCustomFunction('BASE',source('return value+10')));local nextSource=condition(sender);nextSource.bindings={helper='BASE'};nextSource.on_register='addon:CaptureDependencyToken();error("bundle failed")'
 f.env.type=function(value)assert(value~=a.InvalidateRotationDependencies,'bundle rollback performed live callable probe');return type(value)end
 local bundle=assert(sender:BuildFunctionBundle('condition','ROOT',nextSource));local plan=assert(a:PlanFunctionBundleImport(bundle,{BASE={action='replace'},ROOT={action='replace'}}));assert(plan.valid)
 assert(not a:ApplyFunctionBundleImport(plan));assert(a.provisionalDependency and stamp(a)~=a.provisionalDependency and a.conditionRegistryVersion==version and a.conditionDefinitions.ROOT==original)
end)
test('confirmed native effect deletion advances dependency epoch only on accept',function()
 local f,parent=settings();local a=f.addon;assert(a.InvalidateRotationDependencies);a.db.global.effects={e={name='Effect',type='pixel'}}
 local p=a:OpenNativeSettings(parent,'Effects');local before=stamp(a);p.fields.delete:Click();assert(stamp(a)==before);p.prompt.cancel:Click();assert(stamp(a)==before)
 p.fields.delete:Click();p.prompt.accept:Click();assert(a.db.global.effects.e==nil and stamp(a)~=before)
end)
test('failed custom deletion restoration invalidates before refresh without dropping saved source',function()
 local f,a=fixture();f.load('UI/settings_collections.lua');local d=condition();a:RegisterCondition('KEEP',d);local source={description='Saved'};a.db.global.custom_conditions={KEEP=source};local intermediate
 a.UnregisterCondition=function(self,key)self.conditionDefinitions[key]=nil;self:InvalidateRotationDependencies('condition',key);intermediate=stamp(a);error('cleanup marker')end
 f.env.type=function(value)assert(value~=a.InvalidateRotationDependencies,'failed delete restore performed live callable probe');return type(value)end
 local ok,why=a:DeleteSavedCustomCondition('KEEP');assert(not ok and tostring(why):find('cleanup marker',1,true));assert(stamp(a)~=intermediate and a.conditionDefinitions.KEEP==d and a.db.global.custom_conditions.KEEP==source)
end)
test('native profile reset invalidates after operation before final profile callback',function()
 local f,parent=settings();local a=f.addon;f.load('Data/plain.lua');f.load('Core/rotation_scope.lua');f.load('UI/settings_profiles.lua');a.db.GetCurrentProfile=function()return'Default'end;a.db.GetProfiles=function()return{'Default'}end;a.db.profiles={Default=a.db.profile}
 local before=stamp(a);a.db.ResetProfile=function()a.db.profile.poll=.2 end;a.RotationProfileChanged=function()assert(stamp(a)~=before,'final profile callback retained pre-operation epoch')end
 local p=a:OpenNativeSettings(parent,'Profiles');p.fields.reset:Click();assert(stamp(a)==before);p.prompt.accept:Click();assert(a.db.profile.poll==.2 and stamp(a)~=before)
end)
test('inline failed Apply invalidates restored definition before its old registration hook',function()
 local f,parent=settings();local a=f.addon;f.load('Core/conditions.lua')
 for _,path in ipairs({'Core/custom_condition_owner.lua','Core/custom_authoring.lua','Core/schema_authoring.lua','Core/schema_canvas.lua','UI/schema_cards.lua','UI/schema_editor.lua','UI/custom_source_fields.lua','UI/custom_condition_transfer.lua','UI/icon_picker.lua','UI/help.lua','Core/custom_condition_services.lua','UI/lua_input_probe.lua','UI/lua_input_diagnostics.lua','UI/lua_editor.lua','UI/custom_condition_editor.lua','UI/settings_conditions.lua','UI/condition_source_pane.lua'})do f.load(path)end
 f.env.loadstring=function(code,name)local fn,why=loadstring(code,name);if fn then setfenv(fn,f.env)end;return fn,why end
 a.listConditions=function()return{'INLINE'}end;local source=a:CopySettingsData(a.empty_condition);source.description='Inline';assert(a:InstallCustomCondition('INLINE',source,nil))
 local original=a.conditionDefinitions.INLINE;local provisional;a.CaptureDependencyToken=function(self)provisional=stamp(self)end
 original.on_register=function()assert(provisional and stamp(a)~=provisional,'inline restore hook saw provisional epoch')end
 local p=a:OpenNativeSettings(parent,'Conditions');local d=p.inlineCondition
 d:SelectFunction('on_register');d.code.edit:SetText('addon:CaptureDependencyToken()');d.code.edit.scripts.OnTextChanged(d.code.edit,true)
 p.SaveSettingsDraft=function()return false end;d.apply:Click()
 assert(provisional and a.conditionDefinitions.INLINE==original and stamp(a)~=provisional,'inline rollback lost dependency authority')
end)
test('delayed actual migration popup invalidates its later effect-root publication',function()
 local h=assert(io.open('tests/rotation_scope_runtime.lua'));local text=h:read('*a');h:close();local e,a=assert(loadstring(assert(text:match('^(.-)\nlocal function gate'))..'\nreturn fixture'))()()
 e.StaticPopupDialogs={};e.StaticPopup_Show=function(key)assert(key=='ROTATIONMASTER_RESET_EFFECTS')end;a.db.global.version=0
 a:init();local popup=assert(e.StaticPopupDialogs.ROTATIONMASTER_RESET_EFFECTS);local before=stamp(a);local previous=a.db.global.effects
 popup.OnAccept();assert(a.db.global.effects~=previous and stamp(a)~=before,'deferred effect reset did not invalidate')
end)
test('readonly validation leaves epoch stable and Repair advances across the actual traversal',function()
 local h=assert(io.open('tests/rotation_scope_runtime.lua'));local text=h:read('*a');h:close();local _,a=assert(loadstring(assert(text:match('^(.-)\nlocal function gate'))..'\nreturn fixture'))()()
 local defaults=a.db.defaults;local before=stamp(a);a:validate(defaults,false);assert(stamp(a)==before);a:validate(defaults,true);assert(stamp(a)~=before)
end)
test('direct destructive dependency repair notifies before returning or later warning callbacks',function()
 local f,a=fixture();f.load('validate.lua');a.warn=function()end
 f.env.type=function(value)assert(value~=a.InvalidateRotationDependencies,'destructive repair performed live callable probe');return type(value)end
 for _,kind in ipairs({'itemset','effect'})do local value=kind=='itemset'and{name='Bad',items={false}}or{name='Bad',type='pixel',unexpected=true};local before=stamp(a)
  a['validate_'..kind](a,'profile','00000000-0000-0000-0000-000000000001',value,false);assert(stamp(a)==before)
  a['validate_'..kind](a,'profile','00000000-0000-0000-0000-000000000001',value,true);assert(stamp(a)~=before,'destructive direct '..kind..' repair retained epoch')
 end
 local value={name='Invalid',items={1}};local before=stamp(a);a:validate_itemset('profile','invalid-id',value,true);assert(next(value)==nil and stamp(a)~=before,'early destructive repair return retained epoch')
end)
finish()
