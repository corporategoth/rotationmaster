local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
-- Reuse actual mounted native hosts without executing their unrelated suites.
local function host(path,codec)
 local h=assert(io.open(path));local source=h:read('*a');h:close();source=source:sub(1,assert(source:find('\ntest(',1,true))-1)
 if not codec then
  local start,stop=source:find("local codecData,codecDeps=dofile('tests/fixtures/codec.lua')();a.RotationData=codecData;a.NewRotationCodec=function() return codecData.NewCodec(codecDeps) end",1,true)
  if not start then start,stop=source:find("local data,deps=dofile('tests/fixtures/codec.lua')();a.RotationData=data;a.NewRotationCodec=function() return data.NewCodec(deps) end;",1,true)end
  if start then source=source:sub(1,start-1).."f.load('Data/plain.lua');f.load('Data/tags.lua');f.load('Data/rotation_tree.lua');f.load('Data/validation.lua');f.load('Data/diff.lua');"..source:sub(stop+1)end
 end
 return assert(loadstring(source..'\nreturn fixture','@'..path..':focused-host'))()
end
local settings=host('tests/settings_pages.lua');local editor=host('tests/condition_editor_ui.lua');local custom=host('tests/custom_authoring_ui.lua')
test('actual Announcement checkbox stages Apply Discard and stale owner correctly',function()
 local f,parent=settings();local a=f.addon;a.conditionDefinitions={A={description='Alpha'}};a.conditionSpecials={};a.db.global.custom_conditions={};a.db.profile={condition_groups={},switch_conditions={'A'},announcement_conditions={},other_conditions_order={},disabled_conditions={}};f.load('Core/conditions.lua');a:RegisterCondition('A',{description='Alpha'});f.load('Core/condition_catalog.lua')
 local p=a:OpenNativeSettings(parent,'Conditions');p.condition='A';p:Draw();local checkbox=assert(p.fields.announcement,'missing Announcement checkbox');assert(checkbox.tooltip and checkbox.tooltip:find('announcement',1,true));checkbox:Click();assert(#a.db.profile.announcement_conditions==0 and p.draft.profile.announcement_conditions[1]=='A','staging');p:DiscardSettingsDraft();p:Draw();assert(not p.fields.announcement:GetChecked(),'discard');p.fields.announcement:Click();p.fields.apply:Click();assert(a.db.profile.announcement_conditions[1]=='A' and a.db.profile.switch_conditions[1]=='A','Apply: '..tostring(p.message and p.message:GetText()))
 local stale=p.fields.announcement.scripts.OnClick;p:Release();assert(checkbox.tooltip==nil,'pooled flag brief retained after release');stale();assert(a.db.profile.announcement_conditions[1]=='A')
end)
test('actual announcement owner picker filters choices but keeps existing unmarked nodes',function()
 local f=editor();local a=f.addon;f.load('Core/condition_catalog.lua');a:RegisterCondition('OTHER',{description='Other',fields={},valid=function()return true end});a.db.profile.announcement_conditions={'OTHER'};a.db.profile.switch_conditions={'NUMBER'};a.db.profile.condition_groups={};a.db.profile.other_conditions_order={};a.db.profile.disabled_conditions={}
 local root={type='NUMBER',number=7};local shell=a:ShowConditionEditor(1,0,root,nil,nil,{announcement=true,announcementTarget=true});assert(shell and shell.userdata.announcementTarget);shell.canvas.cards[1].typeButton:Click();local matches=shell.canvas.cards[1].picker.matches;local found={};for _,tag in ipairs(matches)do found[tag]=true end;assert(found.OTHER and not found.NUMBER,'announcement owner used Switch/All choices');shell.cancel:Click();assert(root.type=='NUMBER' and root.number==7)
 shell=a:EditCondition(1,0,root);shell.canvas.cards[1].typeButton:Click();found={};for _,tag in ipairs(shell.canvas.cards[1].picker.matches)do found[tag]=true end;assert(found.NUMBER and found.OTHER,'ordinary action choices were narrowed');shell.cancel:Click()
end)
test('inline custom flag participates in detached Undo Redo Apply and duplicate defaults',function()
 local f,a=custom(true);local source=a:CopySettingsData(a.empty_condition);source.description='Custom';a.db.global.custom_conditions.CUSTOM=source;a.conditionDefinitions.CUSTOM={description='Custom'};a.db.profile={condition_groups={},switch_conditions={'CUSTOM'},announcement_conditions={},other_conditions_order={},disabled_conditions={}}
 local parent=f.env.CreateFrame('Frame');parent:SetSize(1000,600);local p=a:OpenNativeSettings(parent,'Conditions');local d=assert(p.inlineCondition);assert(d.form.fields.announcement,'inline source host lacks Announcement checkbox');d.form.fields.announcement:Click();assert(d.model.context.announcement and #a.db.profile.announcement_conditions==0);assert(d.model:Undo() and not d.model.context.announcement);assert(d.model:Redo() and d.model.context.announcement);d.apply:Click();assert(a.db.profile.announcement_conditions[1]=='CUSTOM' and a.db.profile.switch_conditions[1]=='CUSTOM')
 a:DuplicateInlineCustomCondition(p);local duplicate=p.inlineCondition;assert(duplicate and not duplicate.model.context.announcement,'duplicate inherited different identifier membership');assert(a.db.profile.announcement_conditions[1]=='CUSTOM')
end)
finish()
