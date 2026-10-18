local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(inline)
    local f=F.new();local a=f.addon;dofile('tests/fixtures/native_ui.lua')(f.env);local make=f.env.CreateFrame;f.env.CreateFrame=function(kind,...) local frame=make(kind,...);if kind=='EditBox' then local set=frame.SetText;frame.SetText=function(self,text) if self.maxLetters and self.maxLetters>0 then text=text:sub(1,self.maxLetters) end;set(self,text) end end;return frame end;local data,deps=dofile('tests/fixtures/codec.lua')();a.RotationData=data;a.NewRotationCodec=function() return data.NewCodec(deps) end;a.pretty_name='Rotation Master';a.name='rotationmaster';a.db.char={};a.db.global.custom_conditions={}
    for _,path in ipairs({'Core/custom_condition_owner.lua','UI/settings_draft.lua','Core/custom_authoring.lua','Core/schema_authoring.lua','UI/schema_editor.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_roster_order.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/custom_condition_transfer.lua','UI/icon_picker.lua','UI/help.lua','Options/custom_condition.lua','UI/lua_editor.lua','UI/custom_condition_editor.lua'}) do local h=io.open(path);if h then h:close();f.load(path) end end
    a.conditionDefinitions=a.definitions;a.RegisterCondition=function(self,key,value) self.conditionDefinitions[key]=value;if value.on_register then value.on_register(key) end end
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    if inline then f.load('UI/settings_collections.lua');f.load('UI/settings_conditions.lua');f.load('UI/condition_source_pane.lua');a.listConditions=function(_,_,_,store) local tags={};for key in pairs((store or a.db).global.custom_conditions) do tags[#tags+1]=key end;table.sort(tags);return tags end end
    return f,a
end
test('native editor stages schema and callbacks until Apply and has cross-function Undo',function()
    local f,a=fixture();assert(a.CreateWorkbenchLuaEditor,'native code editor missing');local saved;local d=a:condition_edit_box(function(key) saved=key end)
    assert(d.nativeCustomEditor and d.form and d.code);local p=d.form;local function edit(key,text) local c=p.fields[key];c:SetText(text);c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c) end
    edit('identifier','NATIVE');edit('description','Native condition');edit('schema','{ count = number }');d.code.edit:SetText('return false');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d:UpdateActions();assert(d.code.frame.rmUnsaved and d.functionTabs.evaluate.rmUnsaved);assert(not a.db.global.custom_conditions.NATIVE)
    d:SelectFunction('print');d.code.edit:SetText('return "Name"');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.codeUndo:Click();assert(d:PendingSource().print~= 'return "Name"');d.codeRedo:Click();assert(d:PendingSource().print=='return "Name"');d:SelectFunction('evaluate');d.apply:Click();assert(saved=='NATIVE' and a.db.global.custom_conditions.NATIVE.fields.count=='number' and not d.frame:IsShown())
end)
test('syntax checks never run callbacks and errors preserve code and saved source',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Original';a.db.global.custom_conditions.CUSTOM=source;a.conditionDefinitions.CUSTOM={description='Original'};local d=a:condition_edit_box(function() end,'CUSTOM',source)
    d.code.edit:SetText('return )');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.syntax:Click();assert(d.frame:IsShown() and d.code:GetText()=='return )' and a.db.global.custom_conditions.CUSTOM==source)
    d.code.edit:SetText('error("MUST NOT RUN")');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.syntax:Click();assert(d:PendingSource().evaluate=='error("MUST NOT RUN")' and a.db.global.custom_conditions.CUSTOM==source);d.cancel:Click();assert(not d.frame:IsShown() and a:SettingsDataEqual(a.db.global.custom_conditions.CUSTOM,source),'reloaded duplicate or original source mismatch')
end)
test('closing dirty code asks Apply Discard Cancel and stale owner callbacks cannot save',function()
    local f,a=fixture();local valid=true;local d=a:condition_edit_box(function() error('stale save') end,nil,nil,function() return valid end);d.code.edit:SetText('return 4');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d:Hide();assert(d.form.prompt and d.form.prompt.discard);d.form.prompt.cancel:Click();assert(d.frame:IsShown());d:Hide();d.form.prompt.discard:Click();assert(not d.frame:IsShown())
    d=a:condition_edit_box(function() error('stale save') end,nil,nil,function() return valid end);local click=d.apply.scripts.OnClick;valid=false;click();assert(not next(a.db.global.custom_conditions))
end)
test('optional code providers fail closed to native fallback and release their controls',function()
    local f,a=fixture();assert(a.RegisterLuaEditorProvider,'provider interface missing');a:RegisterLuaEditorProvider('throwing',function() error('provider unavailable') end)
    local owner=f.env.CreateFrame('Frame');local code=a:CreateWorkbenchLuaEditor(owner,function() end,function() return true end,'throwing');assert(code.edit and code.provider=='native');code:SetText('return 1');assert(code:GetText()=='return 1');code:Release();assert(not code.frame:IsShown())
end)
test('trusted imports into the native editor remain unsaved until Apply and child cancel restores the draft',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Original';a.db.global.custom_conditions.CUSTOM=source;a.conditionDefinitions.CUSTOM={description='Original'};a.describeCondition=function(_,key) return key=='CUSTOM' and 'Original' end
    local d=a:condition_edit_box(function() end,'CUSTOM',source);d.transfer:Click();local transfer=d.rmCustomTransferForm.textDialog;assert(transfer.frame:IsShown() and not d.frame:IsShown());transfer.cancel:Click();assert(d.frame:IsShown() and not d.model:IsDirty())
    d.transfer:Click();transfer=d.rmCustomTransferForm.textDialog;local incoming=a:CopySettingsData(source);incoming.evaluate='return 42';incoming.fields={checks='condition[]'};transfer.input:SetText(assert(a:NewRotationCodec():Encode({format='RM-CustomCondition',version=1,name='CUSTOM',condition=incoming})));transfer.apply:Click();d.rmCustomTransferForm.prompt.accept:Click();assert(d.frame:IsShown() and d.model.value.evaluate=='return 42' and a.db.global.custom_conditions.CUSTOM==source);d.apply:Click();assert(a.db.global.custom_conditions.CUSTOM.evaluate=='return 42')
end)
test('bundled syntax engine exposes its native API and colors roundtrip without changing source',function()
    local f,a=fixture();f.load('LibsAugment/FAIAP.lua');assert(a.LuaSyntax and a.LuaSyntax.enable and a.LuaSyntax.disable);local source='local x = "color | marker"';assert(a.LuaSyntax.decode(a.LuaSyntax.encode(source))==source)
end)
test('an optional provider that throws during editing falls back without losing text',function()
    local f,a=fixture();local released=0;a:RegisterLuaEditorProvider('broken-runtime',function(parent) return {frame=f.env.CreateFrame('Frame',nil,parent),GetText=function() error('failed') end,SetText=function() error('failed') end,Release=function() released=released+1;error('release failed') end} end)
    local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'broken-runtime');code:SetText('return 99');assert(code.provider=='native' and code:GetText()=='return 99' and released==1);code:Release();assert(not code.frame:IsShown())
end)
test('native code control uses the real bundled indentation hooks and returns uncolored Lua',function()
    local f,a=fixture();f.load('LibsAugment/FAIAP.lua');local enable=a.LuaSyntax.enable
    a.LuaSyntax.enable=function(edit,...)
        local methods={GetText=edit.GetText,SetText=edit.SetText};setmetatable(edit,{__index=methods})
        function edit:GetMaxBytes() return self.maxBytes or 0 end;function edit:SetMaxBytes(v) self.maxBytes=v end;function edit:GetMaxLetters() return self.maxLetters or 0 end;function edit:GetCursorPosition() return self.cursor or 0 end;function edit:IsMultiLine() return self.multiLine end
        return enable(edit,...)
    end
    local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end);assert(code.syntax,'real syntax engine failed to attach');for _,color in pairs(code.syntaxColors) do assert(not color:find('^|c00'),'transparent syntax colors hide the caret') end;local source='local count = 1';code:SetText(source);a.LuaSyntax.indentEditbox(code.edit);assert(code:GetText()==source and a.LuaSyntax.coloredGetText(code.edit):find('|c',1,true));code:GetText();code.nativeSetText(code.edit,'return 123');code.edit.scripts.OnTextChanged(code.edit,true);assert(code:GetText()=='return 123','syntax cache lost a fresh keystroke');code:Release();assert(not code.frame:IsShown());code:Acquire(function() end,function() return true end);code:SetText('return 456');assert(code:GetText()=='return 456');code:Release()
end)
test('profile replacement closes native authoring and leaves its captured callbacks inert',function()
    local f,a=fixture();local d=a:condition_edit_box(function() error('stale callback') end);local apply=d.apply.scripts.OnClick;a.db.profile={};d.frame.scripts.OnUpdate();assert(d.closed and not d.frame:IsShown());apply();assert(not next(a.db.global.custom_conditions))
end)
test('choosing icons preserves live code text and undo can restore it',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);d.code.edit:SetText('return 12345');d.code.edit.scripts.OnTextChanged(d.code.edit,true);local choose;a.ShowWorkbenchIconPicker=function(_,_,callback) choose=callback;return {serial=1,frame=f.env.CreateFrame('Frame')} end;d.form.fields.icon:Click();choose(123);assert(d.code:GetText()=='return 12345' and d:PendingSource().evaluate=='return 12345');d.undo:Click();assert(d:PendingSource().evaluate=='return 12345' and d.model.value.icon~=123)
end)
test('malformed provider frames and throwing frame cleanup reach native fallback',function()
    local f,a=fixture();for _,bad in ipairs({true,{SetParent=function() error('attach failed') end,SetAllPoints=function() end,Hide=function() error('hide failed') end}}) do a:RegisterLuaEditorProvider('bad-frame',function() return {frame=bad,GetText=function() return '' end,SetText=function() end,Release=function() end} end);local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'bad-frame');assert(code.provider=='native' and code.edit);code:Release() end
end)
test('closed editors release ownership and Escape entries, close owned pickers and reuse native frames',function()
    local f,a=fixture();f.env.UISpecialFrames={};local d=a:condition_edit_box(function() end);local owner=d.owner;d.form.fields.icon:Click();assert(a.iconPicker.frame:IsShown());d:Close();assert(not a.iconPicker.frame:IsShown() and not d.rmEscapeEntry and not owner.widgets[d] and not d.model,'closed editor retains resources');local frame=d.frame;local editor=d.code;local stale=d.apply.scripts.OnClick;local reopened=a:condition_edit_box(function() end);assert(reopened.frame==frame and reopened.code==editor,'native frame allocation was not reused');if stale then stale() end;assert(not next(a.db.global.custom_conditions))
end)
test('the schema control can display and roundtrip valid schemas larger than four KiB',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Large schema';source.fields={};for i=1,100 do source.fields['field_'..string.rep('x',35)..i]='number' end;a.db.global.custom_conditions.LARGE=source;a.conditionDefinitions.LARGE={description='Large schema'};local d=a:condition_edit_box(function() end,'LARGE',source);local c=d.form.fields.schema;assert(#c:GetText()>4096 and c.maxLetters>=#c:GetText(),'schema input truncates supported data');assert(a:ParseCustomFieldSchema(c:GetText()))
end)
test('opening after a profile change reclaims a stale cached editor before the update callback runs',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);local frame=d.frame;a.db.profile={};local reopened=a:condition_edit_box(function() end);assert(reopened.frame==frame and not reopened.closed and reopened.form.profile==a.db.profile and reopened.owner.active)
end)
test('native Duplicate Apply and simulated reload preserve real UUID-generated custom conditions',function()
    local f,a=fixture();f.load('UI/settings_collections.lua');f.load('UI/settings_conditions.lua');local source=a:CopySettingsData(a.empty_condition);source.description='Original';a.db.global.custom_conditions.CUSTOM=source;assert(a:register_custom_condition('CUSTOM',source));a.db.profile.condition_groups={};a.db.profile.disabled_conditions={};a.db.profile.other_conditions_order={};a.db.profile.switch_conditions={};a.conditionSpecials={}
    a.listConditions=function(_,_,_,store) local keys={};for key in pairs((store or a.db).global.custom_conditions) do keys[#keys+1]=key end;return keys end
    local p=a:OpenNativeSettings(f.env.UIParent,'Conditions');p.fields.duplicate_custom:Click();p.fields.apply:Click();local duplicate;for key in pairs(a.db.global.custom_conditions) do if key~='CUSTOM' then duplicate=key end end;assert(duplicate and duplicate:match('CUSTOM_') and a.conditionDefinitions[duplicate] and type(a.conditionDefinitions[duplicate].evaluate)=='function','duplicate registration missing: '..tostring(duplicate));a.conditionDefinitions={};for key,value in pairs(a.db.global.custom_conditions) do assert(a:register_custom_condition(key,value)) end;assert(a.conditionDefinitions[duplicate] and a:SettingsDataEqual(a.db.global.custom_conditions.CUSTOM,source),'reloaded duplicate or original source mismatch')
end)
test('custom Lua View Changes shows unflushed source without compiling saving or flushing it',function()
    local f,a=fixture();local d=a:condition_edit_box(function() error('saved') end);local original=d.model.value.evaluate;d.code.edit:SetText('invalid lua !!!');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d:UpdateActions()
    assert(d.viewChanges and d.viewChanges:IsEnabled() and not d.viewChanges.icon);d.viewChanges:Click();local view=d.draftComparisonOwner.comparison
    assert(view.frame:IsShown() and d.model.value.evaluate==original and not next(a.db.global.custom_conditions));local found=false;for _,row in ipairs(view.rows) do if row.right=='invalid lua !!!' then found=true end end;assert(found)
end)
test('condition sidebar transfer opens the shared review dialog and cancel resumes the code editor',function()
    local f,a=fixture();f.load('UI/settings_collections.lua');f.load('UI/settings_conditions.lua')
    local source=a:CopySettingsData(a.empty_condition);source.description='Custom';a.db.global.custom_conditions.CUSTOM=source;a.conditionDefinitions.CUSTOM={description='Custom'};a.listConditions=function() return {'CUSTOM'} end
    local host=f.env.CreateFrame('Frame');host:SetSize(1000,600);local p=a:CreateSettingsForm(host);p:Open(function(form) a:BuildConditionSettings(form) end)
    assert(p.fields.transfer:IsEnabled());p.fields.transfer:Click();local d=a.nativeCustomConditionDialog;local transfer=d.rmCustomTransferForm.textDialog
    assert(transfer.frame:IsShown() and not d.frame:IsShown() and transfer.input:GetText()~='');transfer.cancel:Click();assert(d.frame:IsShown() and a.db.global.custom_conditions.CUSTOM==source)
    d.cancel:Click();p:Release()
end)
test('native code accepts focus and invalid form fields do not trap function tabs or drop raw text',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end)
    assert(d.code.edit.mouseEnabled and d.code.scroll.mouseEnabled==false,'native edit input is intercepted by a covering scroll frame')
    d.code.edit:SetFocus();assert(d.code.edit.focused)
    local field=d.form.fields.identifier;field:SetText('AND');field.scripts.OnTextChanged(field,true);d.apply:Click();assert(d.form.message:GetText()~='')
    d.code.edit:SetText('return true');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.functionTabs.print:Click()
    assert(d.selected=='print' and field:GetText()=='AND' and d:PendingSource().evaluate=='return true')
end)
test('custom condition list and draft mark invalid source without running registration code',function()
    local f,a=fixture();f.load('UI/settings_collections.lua');f.load('UI/settings_conditions.lua')
    local source=a:CopySettingsData(a.empty_condition);source.description='Broken';source.evaluate='return )';source.on_register='error("must not run")';a.db.global.custom_conditions.BAD=source;a.listConditions=function() return {'BAD'} end
    local host=f.env.CreateFrame('Frame');host:SetSize(1000,600);local p=a:OpenNativeSettings(host,'Conditions');assert(p.roster.rows[1].rmInvalid and p.roster.rows[1].tooltip:find('Invalid condition:',1,true))
    p.fields.edit_custom:Click();local d=a.nativeCustomConditionDialog;assert(d.functionTabs.evaluate.rmInvalid and d.code.frame.rmInvalid)
    d.code.edit:SetText('return true');d.code.edit.scripts.OnTextChanged(d.code.edit,true);assert(not d.code.frame.rmInvalid and not d.functionTabs.evaluate.rmInvalid and a.db.global.custom_conditions.BAD==source)
end)
test('definition enable pill stages inert registration and preserves disabled source across transfer and reload',function()
    local f,a=fixture();f.load('Core/conditions.lua');f.load('UI/settings_collections.lua');f.load('UI/settings_conditions.lua')
    local source=a:CopySettingsData(a.empty_condition);source.description='Toggle';source.valid='return true';source.evaluate='return true';source.on_register='addon.enableCount=(addon.enableCount or 0)+1';source.on_unregister='addon.disableCount=(addon.disableCount or 0)+1'
    a.db.global.custom_conditions.TOGGLE=source;assert(a:register_custom_condition('TOGGLE',source));a.listConditions=function() return {'TOGGLE'} end
    local host=f.env.CreateFrame('Frame');host:SetSize(1000,600);local p=a:OpenNativeSettings(host,'Conditions');assert(p.fields.definition_enabled)
    p.fields.definition_enabled:Click();assert(not source.disabled and not a.conditionDefinitions.TOGGLE.disabled and p.fields.definition_enabled.rmUnsaved)
    p.fields.apply:Click();assert(a.db.global.custom_conditions.TOGGLE.disabled and a.conditionDefinitions.TOGGLE.disabled and a.disableCount==1 and a.enableCount==1)
    assert(a:evaluateConditionResult({type='NOT',value={type='TOGGLE'}}).status=='unavailable')
    local codec=a:NewRotationCodec();local text=assert(codec:Encode({format='RM-CustomCondition',version=1,name='TOGGLE',condition=a.db.global.custom_conditions.TOGGLE}));assert(a:ParseCustomConditionImport(text,codec).condition.disabled)
    f.load('validate.lua');a.warn=function() end;a:validate_custom_condition('global','TOGGLE',a.db.global.custom_conditions.TOGGLE,true);assert(a.db.global.custom_conditions.TOGGLE.disabled)
    a:UnregisterCondition('TOGGLE');assert(a:register_custom_condition('TOGGLE',a.db.global.custom_conditions.TOGGLE));assert(a.enableCount==1)
    p.fields.definition_enabled:Click();p.fields.apply:Click();assert(not a.db.global.custom_conditions.TOGGLE.disabled and a.enableCount==2 and a:evaluateConditionResult({type='TOGGLE'}).status=='match')
end)
test('disabling incomplete source preserves its text and re-enable rejects invalid code or failed hooks',function()
    local f,a=fixture();f.load('Core/conditions.lua');f.load('UI/settings_collections.lua');f.load('UI/settings_conditions.lua')
    local source=a:CopySettingsData(a.empty_condition);source.description='Incomplete';source.evaluate='return )';a.db.global.custom_conditions.BROKEN=source;a.listConditions=function() return {'BROKEN'} end
    local host=f.env.CreateFrame('Frame');host:SetSize(1000,600);local p=a:OpenNativeSettings(host,'Conditions');p.fields.definition_enabled:Click();p.fields.apply:Click();assert(a.conditionDefinitions.BROKEN.disabled and a.db.global.custom_conditions.BROKEN.evaluate=='return )')
    p.fields.definition_enabled:Click();assert(a.db.global.custom_conditions.BROKEN.disabled and p:SettingsData().global.custom_conditions.BROKEN.disabled and p.message:GetText()~='')
    a.db.global.custom_conditions.BROKEN.evaluate='return true';a.db.global.custom_conditions.BROKEN.on_register='error("registration failure")';p:DiscardSettingsDraft();p:Draw();p.fields.definition_enabled:Click();p.fields.apply:Click();assert(a.db.global.custom_conditions.BROKEN.disabled and a.conditionDefinitions.BROKEN.disabled)
    p.fields.edit_custom:Click();local d=a.nativeCustomConditionDialog;d.code.edit:SetText('return 987');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.form.fields.definition_enabled:Click();assert(d.code:GetText()=='return 987')
end)
test('new identifier stays neutral until Apply and filters input with the runtime character policy',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);local field=d.form.fields.identifier
    assert(not field.rmInvalid,'new identifier is marked invalid before Apply')
    field:SetText('my condition!?_42');field.scripts.OnTextChanged(field,true)
    assert(field:GetText()=='mycondition_42','unsupported identifier characters can be entered')
    field.scripts.OnEnterPressed(field);assert(d.model.key=='mycondition_42','editor rejects valid runtime identifier')
    d:UpdateActions();d.apply:Click();assert(d.form.fields.description.rmInvalid and d.frame:IsShown(),'Apply did not mark missing description')
end)
test('code editing has native keyboard arrows without repeated focus resets',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);local edit=d.code.edit
    assert(not edit.keyboardEnabled and edit.altArrowKeyMode==false and edit.countInvisibleLetters==false,'native arrow key handling not configured')
    edit:SetFocus();edit:SetCursorPosition(3);local focused=edit.SetFocus;edit.SetFocus=function() error('already focused edit refocused') end
    if edit.scripts.OnMouseDown then edit.scripts.OnMouseDown(edit,'LeftButton') end
    d:UpdateActions();assert(edit.cursor==3);edit.SetFocus=focused
end)
test('callback pending code has independent Undo Redo and Reset without registration',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);local original=d.model.value.evaluate
    assert(d.codeReset and d.codeUndo and d.codeRedo)
    d.code.edit:SetText('return 1');d.code.edit.scripts.OnTextChanged(d.code.edit,true)
    d.code.edit:SetText('return 2');d.code.edit.scripts.OnTextChanged(d.code.edit,true)
    d.codeUndo:Click();assert(d.code:GetText()=='return 1');d.codeRedo:Click();assert(d.code:GetText()=='return 2')
    d.codeReset:Click();assert(d.code:GetText()==original and d.model.value.evaluate==original and not next(a.db.global.custom_conditions))
    d.code.edit:SetText('return )');d.code.edit.scripts.OnTextChanged(d.code.edit,true);assert(d.code.frame.rmInvalid);d.codeReset:Click();assert(d.code:GetText()==original and not d.code.frame.rmInvalid)
end)
test('graphical fields edit a staged schema and preserve order through transfer and reload',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end)
    assert(d.form.fields.schemaGraph:IsShown() and not d.form.fields.schema:IsShown(),'raw schema is still the default editor')
    d.form.fields.schemaGraph:Click();local graph=d.schemaEditor;assert(graph.frame:IsShown() and not d.frame:IsShown())
    graph.form.fields.add:Click();local name=graph.form.fields.field_1;name:SetText('spell');name.scripts.OnTextChanged(name,true);name.scripts.OnEnterPressed(name)
    graph.apply:Click();assert(d.frame:IsShown() and d.model.value.fields.spell=='string' and d.model.value.fieldOrder[1][1]=='spell' and not next(a.db.global.custom_conditions))
    d.model.value.description='Fields';d.model.key='FIELDS';d.form:Draw();d:UpdateActions();d.apply:Click();local saved=a.db.global.custom_conditions.FIELDS;assert(saved and saved.fieldOrder[1][1]=='spell')
    local codec=a:NewRotationCodec();local value=a:ParseCustomConditionImport(assert(codec:Encode({format='RM-CustomCondition',version=1,name='FIELDS',condition=saved})),codec);assert(value.condition.fieldOrder[1][1]=='spell')
    f.load('validate.lua');a.warn=function() end;saved.fields.tests='condition[]';a:validate_custom_condition('global','FIELDS',saved,true);assert(saved.fieldOrder[1][1]=='spell' and saved.fields.tests=='condition[]')
end)
test('pending callback text survives tab switches and redraws until Reset or whole-condition Apply',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);local original=d.model.value.evaluate
    d.code.edit:SetText('return 876');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d:SelectFunction('print');d:SelectFunction('evaluate')
    assert(d.code:GetText()=='return 876' and d.model.value.evaluate==original and d.codeReset:IsEnabled(),'switching callback applied its buffer')
    d.form:Draw();d:UpdateActions();assert(d.code:GetText()=='return 876');d.codeReset:Click();assert(d.code:GetText()==original)
end)
test('schema Undo returns to a container and Record conversion saves named keys',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);d.form.fields.schemaGraph:Click();local g=d.schemaEditor
    g.form.fields.add:Click();g.form.fields.type_1:Click();for _,row in ipairs(g.form.menu.rows) do if row:GetText()=='Record / map' then row:Click();break end end
    g.form.fields.children_1:Click();g.undo:Click();g.form.fields.add:Click();assert(#g.model.root.children==2,'schema Undo retained primitive navigation')
    g.cancel:Click();d.model.value.fields={value={'string','number'}};d.form:Draw();d.form.fields.schemaGraph:Click();g=d.schemaEditor
    g.form.fields.type_1:Click();for _,row in ipairs(g.form.menu.rows) do if row:GetText()=='Record / map' then row:Click();break end end;g.apply:Click()
    assert(d.model.value.fields.value[1]==nil and d.model.value.fields.value.field1=='string','record conversion saved numeric keys')
end)
test('mixed case custom identifiers survive replacing their own export',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Case';a.db.global.custom_conditions.myCondition=source;a.conditionDefinitions.myCondition={description='Case'}
    local d=a:condition_edit_box(function() end,'myCondition',source);d.transfer:Click();local transfer=d.rmCustomTransferForm.textDialog;transfer.apply:Click()
    assert(d.rmCustomTransferForm.prompt and d.rmCustomTransferForm.prompt.frame:IsShown(),'mixed case replacement was rejected');d.rmCustomTransferForm.prompt.accept:Click();assert(d.model.key=='myCondition')
end)
test('callback Reset restores saved code and default code with undo while docs stay outside source',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end)
    assert(d.codeReset and not d.codeApply and not d.codeCancel,'callback controls still use Apply and Cancel')
    assert(not d.code:GetText():find('^%s*%-%-'),'new code contains generated header comments')
    assert(d.code.editorDecoration and not d.documentation:GetText():find('Available bindings',1,true));assert(d.code.frame.point[3]<d.signature.point[3] and d.signature.point[3]<d.codeUndo.point[3] and d.codeUndo.point[3]<d.documentation.point[3],'signature is not directly above code');assert(d.documentation:GetText():find('|cffffcc55evalStart|r',1,true) and d.documentation:GetText():find('boolean',1,true),'typed callback documentation missing')
    local default=d.code:GetText();d.code.edit:SetText('return 99');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.codeReset:Click();assert(d.code:GetText()==default);d.codeUndo:Click();assert(d.code:GetText()=='return 99')
    d:Close();local source=a:CopySettingsData(a.empty_condition);source.description='Saved';source.evaluate='return false';a.db.global.custom_conditions.SAVED=source;a.conditionDefinitions.SAVED={description='Saved'}
    d=a:condition_edit_box(function() end,'SAVED',source);d.code.edit:SetText('return 3');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.codeReset:Click();assert(d.code:GetText()=='return false')
end)
test('callback help describes pending buffers and Reset without obsolete per-callback Apply',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);d.help:Click()
    local text=d.ownedHelp.sections[1].text
    assert(text:find('Reset restores',1,true) and text:find('all callback',1,true) and not text:find('Its Apply',1,true),'callback help still describes removed controls')
end)
test('custom source edits in the right pane without an Edit launcher or separate Escape window',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    assert(d and d.isEmbedded and d.frame:GetParent()==p.child and not p.fields.edit_custom and not d.rmEscapeEntry,'custom editor still launches a dialog')
    d.code.edit:SetText('return false');d.code.edit.scripts.OnTextChanged(d.code.edit,true);local left=false;p:RequestLeave(function() left=true end);assert(not left and p.prompt.frame:IsShown());p.prompt.cancel:Click();assert(d.code:GetText()=='return false')
    d.apply:Click();assert(a.db.global.custom_conditions.INLINE.evaluate=='return false' and p.inlineCondition~=nil and not p.inlineCondition:IsDirty(),'inline Apply did not persist or reset draft')
    p.fields.add_custom:Click();d=p.inlineCondition;assert(d.model.key=='' and not d.form.fields.identifier.rmInvalid and not p.fields.edit_custom)
    d.form.fields.identifier:SetText('newCondition');d.form.fields.identifier.scripts.OnTextChanged(d.form.fields.identifier,true);d.form.fields.identifier.scripts.OnEnterPressed(d.form.fields.identifier)
    d.form.fields.description:SetText('New');d.form.fields.description.scripts.OnTextChanged(d.form.fields.description,true);d:UpdateActions();d.apply:Click()
    assert(a.db.global.custom_conditions.newCondition and p.condition=='newCondition')
end)
test('inline preferences stage with code and failed registration preserves saved preferences',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    a.db.profile.condition_groups={{id='group',name='Group',conditions={}}};local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    d.form.fields.hidden:Click();assert(not a:SettingsContains(a.db.profile.disabled_conditions,'INLINE') and d:IsDirty())
    d:SelectFunction('on_register');d.code.edit:SetText('error("failed hook")');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.apply:Click()
    assert(d.frame:IsShown() and not a:SettingsContains(a.db.profile.disabled_conditions,'INLINE') and a.db.global.custom_conditions.INLINE==source)
    d.codeReset:Click();d.apply:Click();assert(a:SettingsContains(a.db.profile.disabled_conditions,'INLINE'))
    d=p.inlineCondition;d.form.fields.hidden:Click();p:RequestLeave(function() p:Release() end);p.prompt.discard:Click();assert(a:SettingsContains(a.db.profile.disabled_conditions,'INLINE') and not p.active)
end)
test('focused inline code routes Escape and right click through pending-change navigation',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    d.code.edit:SetFocus();d.code.edit:SetText('return false');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.code.edit.scripts.OnEscapePressed(d.code.edit)
    assert(p.prompt.frame:IsShown() and p.active and not d.code.edit:HasFocus());p.prompt.cancel:Click()
    d.code.edit:SetFocus();d.code.edit.scripts.OnMouseDown(d.code.edit,'RightButton');assert(p.prompt.frame:IsShown());p.prompt.discard:Click();assert(not p.active and a.db.global.custom_conditions.INLINE.evaluate==source.evaluate)
end)
test('inline page resize preserves callback buffers preferences raw input and original conflict baseline',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    d.code.edit:SetText('return false');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.form.fields.hidden:Click();d:SelectFunction('print')
    local raw=d.form.fields.schema;raw:SetText('{ broken =');raw.scripts.OnTextChanged(raw,true)
    p:SetWidth(1050);d=p.inlineCondition
    assert(d:IsDirty() and d.model.context.hidden and d.selected=='print' and d:PendingSource().evaluate=='return false','resize discarded source or preferences')
    assert(d.form.fields.schema:GetText()=='{ broken =','resize discarded invalid raw input')
    d:SelectFunction('evaluate');d.codeUndo:Click();assert(d.code:GetText()==source.evaluate,'resize lost callback history');d.codeRedo:Click()
    a.db.global.custom_conditions.INLINE=a:CopySettingsData(source);a.db.global.custom_conditions.INLINE.description='External'
    p:SetWidth(1060);d=p.inlineCondition;d.form.fields.schema:SetText('{}');d.form.fields.schema.scripts.OnTextChanged(d.form.fields.schema,true)
    assert(not d:Apply() and a.db.global.custom_conditions.INLINE.description=='External','resize accepted a concurrent source replacement')
end)
test('inline code-only Apply preserves existing switch and category order',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    a.db.profile.switch_conditions={'A','INLINE','B'};a.db.profile.condition_groups={{id='group',name='Group',conditions={'A','INLINE','B'}}}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    d.code.edit:SetText('return false');d.code.edit.scripts.OnTextChanged(d.code.edit,true);assert(d:Apply())
    assert(table.concat(a.db.profile.switch_conditions,',')=='A,INLINE,B' and table.concat(a.db.profile.condition_groups[1].conditions,',')=='A,INLINE,B','code Apply reordered condition memberships')
end)
test('invalid inline schema still permits category navigation through Apply Discard Cancel',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    local raw=d.form.fields.schema;raw:SetText('{ broken =');raw.scripts.OnTextChanged(raw,true);d.form.fields.current_category:Click()
    assert(p.prompt and p.prompt.frame:IsShown(),'invalid raw schema blocked pending-change navigation');p.prompt.cancel:Click();assert(d.form.fields.schema:GetText()=='{ broken =')
    d.form.fields.current_category:Click();p.prompt.discard:Click();assert(p.mode=='categories' and not p.inlineCondition)
end)
finish()
