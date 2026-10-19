local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(inline)
    local f=F.new();local a=f.addon;dofile('tests/fixtures/native_ui.lua')(f.env);local make=f.env.CreateFrame;f.env.CreateFrame=function(kind,...) local frame=make(kind,...);if kind=='EditBox' then local set=frame.SetText;frame.SetText=function(self,text) if self.maxLetters and self.maxLetters>0 then text=text:sub(1,self.maxLetters) end;set(self,text) end end;return frame end;local data,deps=dofile('tests/fixtures/codec.lua')();a.RotationData=data;a.NewRotationCodec=function() return data.NewCodec(deps) end;a.pretty_name='Rotation Master';a.name='rotationmaster';a.db.char={};a.db.global.custom_conditions={}
    for _,path in ipairs({'Core/custom_condition_owner.lua','UI/settings_draft.lua','Core/custom_authoring.lua','Core/schema_authoring.lua','Core/schema_canvas.lua','UI/schema_cards.lua','UI/schema_editor.lua','UI/custom_source_fields.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_roster_order.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/custom_condition_transfer.lua','UI/icon_picker.lua','UI/help.lua','Core/custom_condition_services.lua','UI/lua_input_diagnostics.lua','UI/lua_editor.lua','UI/custom_condition_editor.lua'}) do local h=io.open(path);if h then h:close();f.load(path) end end
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
    assert(g.cards['1/1'],'nested field is not shown in its parent card');g.undo:Click();g.form.fields.add:Click();assert(#g.model.root.children==2,'schema Undo retained primitive navigation')
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
    assert(d and d.isEmbedded and d.frame:GetParent()==p.frame and not p.fields.edit_custom and not d.rmEscapeEntry,'custom editor still launches a dialog')
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
test('inline authoring has one callback row compact identity header and owner footer actions',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    local row
    for _,tab in pairs(d.functionTabs) do row=row or tab.point[3];assert(tab.point[3]==row,'callback tabs wrap onto multiple lines') end
    assert(d.syntax:GetParent()==d.form.child and d.syntax.point[3]==d.codeReset.point[3] and d.syntax.point[2]>d.codeReset.point[2],'syntax is not after Reset')
    assert(not d.undo:IsShown() and not d.redo:IsShown(),'duplicate footer history still shown')
    assert(d.apply:GetParent()==p.frame and d.cancel:GetParent()==p.frame and d.viewChanges:GetParent()==p.frame,'source actions scroll instead of anchoring to pane footer')
    assert(d.viewChanges.point[1]=='RIGHT' and d.viewChanges.point[2]==d.apply,'View Changes is not adjacent to Apply')
    assert(d.form.fields.definition_enabled.pillDecoration and d.form.fields.definition_enabled.selected,'availability is not the green enabled pill')
    assert(d.form.fields.definition_enabled.point[1]=='RIGHT' and d.form.fields.definition_enabled.point[2]==d.form.fields.delete,'availability is not beside delete')
    assert(d.form.fields.icon:GetHeight()>=48 and d.form.fields.icon:GetText()=='','source icon is still a Choose icon button')
    assert(d.form.fields.identifier.point[2]>d.form.fields.icon.point[2] and d.form.fields.description.point[2]==d.form.fields.identifier.point[2],'identity controls do not share space with source icon')
    assert(d.form.fields.moveLabel:GetText()=='Move' and d.form.fields.move_to:GetText()=='Other' and d.form.fields.move_to.point[3]==d.form.fields.current_category.point[3],'category destination lacks its inline label')
end)
test('inline category Move stages its chosen destination until Apply',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    a.db.profile.condition_groups={{id='group',name='Group',conditions={}}};local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    d.form.fields.move_to:Click();for _,button in ipairs(d.form.menu.rows) do if button:GetText()=='Group' then button:Click();break end end
    assert(d.model.context.category=='group' and #a.db.profile.condition_groups[1].conditions==0)
    assert(d.form.fields.current_category:GetText()=='Other' and d.form.fields.move_to:GetText()=='Group','pending destination replaced the original category display')
    d:UpdateActions();assert(d.form.fields.move_to.rmUnsaved);assert(d:Apply());assert(a.db.profile.condition_groups[1].conditions[1]=='INLINE')
end)
test('input diagnostics observe native events without exposing source or rewriting the cursor',function()
    local f,a=fixture();f.load('UI/lua_input_diagnostics.lua');local d=a:condition_edit_box(function() end);local code=d.code;local edit=code.edit
    edit:SetText('PRIVATE_BODY');edit:SetFocus();edit:SetCursorPosition(3);code:ObserveInput('mouse-up')
    local report=a:LuaEditorInputReport();assert(not report:find('PRIVATE_BODY',1,true) and report:find('cursor=3',1,true) and report:find('focus=true',1,true))
    assert(edit:GetCursorPosition()==3 and edit:HasFocus() and edit:GetText()=='PRIVATE_BODY','input report changed the editing state')
    for i=1,100 do edit:SetCursorPosition(i);code:ObserveInput('cursor') end
    assert(#code.inputTrace<=32 and code.inputCounts.cursor==100,'input trace is unbounded or loses counters')
    d:Close();assert(a:LuaEditorInputReport():find('closed',1,true));local reopened=a:condition_edit_box(function() end);assert(reopened.code.inputCounts.cursor==nil,'reused editor retained old traces')
end)
test('source footer follows schema child ownership and navigation includes its pending fields',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    d.form.fields.schemaGraph:Click();local graph=d.schemaEditor;graph.form.fields.add:Click()
    assert(not d.apply:IsShown() and not d.cancel:IsShown() and not d.viewChanges:IsShown(),'source footer stayed visible under schema child')
    local left=false;p:RequestLeave(function() left=true end);assert(not left and p.prompt.frame:IsShown(),'schema draft escaped pending navigation')
    p.prompt.cancel:Click();assert(graph.active);p:RequestLeave(function() left=true end);p.prompt.accept:Click()
    assert(left and a.db.global.custom_conditions.INLINE.fields.field=='string','Apply lost the schema child draft')
    d=p.inlineCondition;assert(d.apply:IsShown() and d.cancel:IsShown() and d.viewChanges:IsShown())
    d.form.fields.schemaGraph:Click();d.schemaEditor.cancel:Click();assert(d.apply:IsShown() and d.viewChanges:IsShown(),'child Cancel did not restore source footer')
end)
test('reacquiring a native editor makes it the input diagnostic target',function()
    local f,a=fixture();local valid=function() return true end
    local first=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,valid,'plain');local second=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,valid,'plain')
    first:Release();second:Release();first:Acquire(function() end,valid);first:ObserveInput('activeA')
    local report=a:LuaEditorInputReport();assert(report:find('state=open',1,true) and report:find('activeA',1,true),'diagnostics still target another closed editor')
end)
test('closing an owner with a schema child does not suspend its next source session',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);d.form.fields.schemaGraph:Click();assert(d.suspended);d:Close()
    local saved;d=a:condition_edit_box(function(key) saved=key end);d.model.key='REOPENED';d.model.value.description='Reopened';d.form:Draw()
    assert(d:Apply() and saved=='REOPENED','reopened editor remained suspended by the prior child')
end)
test('resizing the owner preserves a schema child draft including invalid raw field names',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    d.form.fields.schemaGraph:Click();d.schemaEditor.form.fields.add:Click();local raw=d.schemaEditor.form.fields.field_1;raw:SetText('bad name');raw.scripts.OnTextChanged(raw,true)
    p:SetWidth(1060);d=p.inlineCondition;local graph=d.schemaEditor
    assert(graph.active and graph.form.fields.field_1:GetText()=='bad name' and graph.model.root.children[1].name=='field','resize discarded schema editor state')
    assert(not d.apply:IsShown());graph.cancel:Click();assert(d.apply:IsShown() and next(d.model.value.fields)==nil)
end)
test('fractional native geometry settles without repeated text reflow or moving the caret',function()
    local f,a=fixture();local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain')
    code.frame:SetSize(720,310);code:SetText('return true');local edit=code.edit;local nativeHeight=edit.GetHeight;local nativeWidth=edit.GetWidth;local setHeight=edit.SetHeight;local setWidth=edit.SetWidth
    edit.GetHeight=function(self) return nativeHeight(self)+.00003051758 end;edit.GetWidth=function(self) return nativeWidth(self)+.00003051758 end
    local writes=0
    edit.SetHeight=function(self,n) writes=writes+1;if writes>8 then error('native text reflow loop') end;setHeight(self,n);self:SetCursorPosition(#self:GetText());self.scripts.OnTextChanged(self,false) end
    edit.SetWidth=function(self,n) writes=writes+1;if writes>8 then error('native text reflow loop') end;setWidth(self,n);self:SetCursorPosition(#self:GetText());self.scripts.OnTextChanged(self,false) end
    edit:SetCursorPosition(3);for i=1,100 do code:Layout() end
    assert(writes==0 and edit:GetCursorPosition()==3,'idle layout repeatedly invalidates native editing')
    code.frame:SetSize(740,330);assert(writes>0 and writes<=2,'resize recursively invalidates native editing');local settled=writes
    edit:SetCursorPosition(4);for i=1,100 do code:Layout() end;assert(writes==settled and edit:GetCursorPosition()==4)
end)
test('source pane shares roster geometry and reserves scrolling for its editing areas',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';source.fields={spell='number',unit='string'};a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields=source.fields}
    local host=f.env.CreateFrame('Frame');host:SetSize(1600,1000);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    assert(a.GetWorkbenchRosterGeometry,'shared roster geometry missing');local geometry=a:GetWorkbenchRosterGeometry(1600,1000)
    assert(p.roster.frame.point[2]==0 and d.frame.point[2]==geometry.detailX and d.frame:GetWidth()==geometry.detailWidth,'source pane differs from shared roster edges')
    assert(not p.scroll:IsShown() and not d.form.scroll:IsShown(),'source metadata still uses an outer scrolling form')
    assert(d.form.fields.current_category.point[3]<d.form.fields.description.point[3],'category did not move below description')
    assert(d.form.fields.current_category:GetWidth()==d.form.fields.move_to:GetWidth()+42,'category and Move do not split their shared field width')
    assert(d.form.fields.advancedSchema.rmCheck and not d.form.fields.advancedSchema:GetChecked(),'Advanced is not an unchecked checkbox')
    assert(d.schemaRows and #d.schemaRows>=2 and d.schemaRows[1]:GetText()=='spell','schema fields are not shown directly')
    assert(d.code.frame:GetHeight()>310 and -d.code.frame.point[3]+d.code.frame:GetHeight()<=d.body:GetHeight(),'code does not fill the remaining height or is clipped')
    local before=d.code.frame:GetHeight();p:SetHeight(1050);assert(d.code.frame:GetHeight()>before,'height-only resize did not grow the input')
    d.form.fields.advancedSchema:Click();assert(d.form.fields.schema:IsShown() and d.form.fields.advancedSchema:GetChecked())
end)
test('source editing fits the supported minimum pane for every callback and schema mode',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';source.fields={one='number',two='string',three='boolean'};a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields=source.fields}
    local host=f.env.CreateFrame('Frame');host:SetSize(776,402);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    for _,advanced in ipairs({false,true}) do d.advancedSchema=advanced;d.form:Draw()
        for name in pairs(a.CustomConditionCallbacks) do d:SelectFunction(name);assert(-d.code.frame.point[3]+d.code.frame:GetHeight()<=d.body:GetHeight()-4,'minimum pane clips '..name);assert(d.code.frame:GetHeight()>=60) end
    end
end)
test('disabled invalid schemas and stale field order remain open for repair without source loss',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Legacy';source.disabled=true;source.fields={count='old_unknown_type'};a.db.global.custom_conditions.LEGACY=source;a.conditionDefinitions.LEGACY=assert(a:CompileCustomCondition('LEGACY',source,true))
    local d=a:condition_edit_box(function() end,'LEGACY',source);assert(d.schemaViewport.rmInvalid and d.model.value.fields.count=='old_unknown_type')
    d.form.fields.schemaGraph:Click();assert(d.form.fields.schema:IsShown() and d.form.fields.schema:GetText():find('old_unknown_type',1,true))
    local raw=d.form.fields.schema;raw:SetText('{count=number}');raw.scripts.OnTextChanged(raw,true);assert(d:Apply());assert(a.db.global.custom_conditions.LEGACY.fields.count=='number')
    source=a:CopySettingsData(source);source.fields={count='number'};source.fieldOrder={{'missing'}};a.db.global.custom_conditions.LEGACY=source;d=a:condition_edit_box(function() end,'LEGACY',source);d.form.fields.schemaGraph:Click();assert(d.schemaEditor.active);d.schemaEditor.apply:Click();assert(d.model.value.fieldOrder[1][1]=='count')
end)
test('schema cards show nested field types controls and detached editing',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);d.model.value.fields={group={inner='number'},last='boolean'};d.form:Draw();d.form.fields.schemaGraph:Click();local g=d.schemaEditor
    assert(g.cards and g.cards['1'] and g.cards['1/1'] and g.cards['2'],'schema is still a flat drill-down list')
    local parent,child=g.cards['1'],g.cards['1/1'];assert(parent.decoration and child.frame:GetParent()==g.form.child and child.frame.point[2]>parent.frame.point[2] and child.frame:GetFrameLevel()>parent.frame:GetFrameLevel())
    assert(not parent.up:IsEnabled() and not g.cards['2'].down:IsEnabled());assert(parent.help and parent.duplicate and parent.remove.icon and parent.type and parent.name)
    child.duplicate:Click();assert(#g.model.root.children[1].children==2 and not d.model.value.fields.group.inner_copy)
    g.cards['1'].fold:Click();assert(not g.cards['1/1'] and g.cards['1']);g.cards['1'].fold:Click();assert(g.cards['1/1'])
    g.cards['1/1'].help:Click();assert(a.helpWindow.frame:IsShown() and #a.helpWindow.sections>=3)
    g.apply:Click();assert(d.model.value.fields.group.inner_copy=='number')
end)
test('schema dragging carries live cards into nested gaps and cancel restores originals',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);d.model.value.fields={a='string',group={inner='number'},z='boolean'};d.form:Draw();d.form.fields.schemaGraph:Click();local g=d.schemaEditor
    local view=g.cardView;assert(view and #view.zones>4)
    local first=g.cards['1'];view:BeginDrag({1});assert(view.ghost:IsShown() and view.ghost.liveEntries[1].frame==first.frame and view.ghost.placeholders[1]:IsShown(),'schema drag has no native card preview')
    view:CancelDrag();assert(first.frame:GetParent()==g.form.child and not view.ghost:IsShown())
    view:BeginDrag({1});assert(view:Drop({2},2));assert(g.model.root.children[1].name=='group' and g.model.root.children[1].children[2].name=='a');g.undo:Click();assert(g.model.root.children[1].name=='a')
    view=g.cardView;view:BeginDrag({2});assert(not view:Drop({2},1),'container dropped inside itself');assert(g.active)
    view:BeginDrag({2});g.cancel:Click();assert(not view.ghost:IsShown() and not g.active and d.model.value.fields.a=='string')
end)
test('schema field dirty markers and validation update before redraw',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);d.model.value.fields={one='number',two='string'};d.form:Draw();d.form.fields.schemaGraph:Click();local g=d.schemaEditor
    local name=g.form.fields.field_1;name:SetText('two');name.scripts.OnTextChanged(name,true);name.scripts.OnEnterPressed(name);g:UpdateActions()
    assert(g.cards['1'].frame.rmInvalid and g.cards['2'].frame.rmInvalid,'duplicate names are not marked on both fields');assert(g.cards['1'].frame.rmUnsaved)
    g.apply:Click();assert(g.active and d.model.value.fields.one=='number');g.undo:Click();assert(not g.cards['1'].frame.rmInvalid and not g.cards['1'].frame.rmUnsaved)
end)
test('deep legacy schemas stay repairable with positive controls and overlong names are marked',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);local nested='number';for i=1,36 do nested={field=nested} end;d.model.value.fields=nested;d.form:Draw();d.form.fields.schemaGraph:Click();local g=d.schemaEditor
    local count=0;for _,card in pairs(g.cards) do count=count+1;assert(card.type:GetWidth()>=80 and card.name:GetWidth()>=80 and card.frame:GetWidth()>=300,'legacy nesting made controls unusable') end;assert(g.cardView.scene.byKey[string.rep('1/',35)..'1'] and count<36);g.form.scroll.workbenchBar:SetValue(g.cardView.scene.byKey[string.rep('1/',35)..'1'].y);assert(g.cards[string.rep('1/',35)..'1'])
    g.cancel:Click();d.model.value.fields={[string.rep('x',65)]='number'};d.form:Draw();d.form.fields.schemaGraph:Click();assert(d.schemaEditor.cards['1'].frame.rmInvalid,'overlong legacy field is unmarked')
end)
test('native multiline input owns text height without a forced-height feedback loop',function()
    local f,a=fixture();local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain');code.frame:SetSize(600,300);code:SetText('return true')
    local edit=code.edit;local writes=0;edit.SetHeight=function() writes=writes+1 end
    edit.GetHeight=function() return 24 end -- Native multiline text owns its natural text height.
    edit:SetCursorPosition(3);edit:SetFocus();for i=1,120 do code:Layout() end
    assert(writes==0 and edit:GetCursorPosition()==3 and edit:HasFocus(),'viewport sizing repeatedly overrides native multiline geometry')
    assert(code.content and code.scroll:GetScrollChild()==code.content and edit:GetParent()==code.content,'text is not anchored within a stable scroll child')
end)
test('syntax success is green and shares the footer action row',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline';a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    d.syntax:Click();local message=d.form.message;assert(message.textColor[2]>message.textColor[1],'successful syntax check has an error color')
    assert(message:GetParent()==d.apply:GetParent() and message.actionAnchor==d.test and d.test.point[2]==d.viewChanges,'syntax message and Test do not share the footer action row')
    d.code:SetText('return )');d.syntax:Click();assert(message.textColor[1]>message.textColor[2],'syntax failures no longer use the error color')
    d.form.fields.schemaGraph:Click();assert(not message:IsShown(),'source notification remains visible under schema child');d.schemaEditor.cancel:Click();assert(message:IsShown())
end)
test('standalone source footer reserves space for transfer and stays below code',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end)
    local bottom=d.frame:GetHeight()-34+d.code.frame.point[3]-d.code.frame:GetHeight()
    assert(bottom>=d.apply.point[3]+d.apply:GetHeight(),'standalone footer overlaps code')
end)
test('standalone syntax status reserves transfer action width',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end)
    assert(d.transfer.point[2]==12 and d.form.message.point[2]==d.transfer and d.form.message.point[3]=='RIGHT','syntax status spans the transfer button')
end)
test('builtin conditions share the inline source pane without allowing source edits',function()
    local f,a=fixture(true);f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Conditions/combat.lua')
    a.db.profile.condition_groups={};a.db.profile.disabled_conditions={};a.db.profile.switch_conditions={};a.db.profile.other_conditions_order={}
    a.listConditions=function() return {'COMBAT'} end
    local host=f.env.CreateFrame('Frame');host:SetSize(1000,700);local p=a:OpenNativeSettings(host,'Conditions')
    local d=assert(p.inlineCondition,'builtin source pane missing');assert(d.readOnly and d.code:GetText():find('GetUnitFlagObservation',1,true) and d.code:GetText():find('"combat"',1,true));assert(not d.code.edit:IsEnabled(),'readonly input still accepts keys');assert(not d.code:GetText():match('^%s'),'shared leading indentation remains');assert(d:PendingSource().evaluate==a:GetBuiltinConditionSource('COMBAT').evaluate,'view formatting changed authored source')
    assert(not d.form.fields.description:IsEnabled() and not d.form.fields.icon:IsEnabled() and not d.form.fields.definition_enabled:IsShown())
    local original=d.code:GetText();d.code.edit:SetText('return false');d.code.edit.scripts.OnTextChanged(d.code.edit,true);assert(d.code:GetText()==original,'readonly source accepted input')
    assert(not d.form.fields.schemaGraph:IsEnabled() and not d:IsDirty())
    d.form.fields.hidden:Click();d.apply:Click();assert(a:SettingsContains(a.db.profile.disabled_conditions,'COMBAT') and not a.db.global.custom_conditions.COMBAT)
    p.fields.duplicate_custom:Click();assert(p.inlineCondition and not p.inlineCondition.readOnly and p.inlineCondition.model.value.parameters.evaluate);local clone=p.inlineCondition;for _,field in ipairs({'identifier','description','icon','schema','schemaGraph','advancedSchema'}) do assert(clone.form.fields[field]:IsEnabled(),field..' remained disabled after builtin view') end
end)
test('duplicating source starts with clean fields and normalized code rather than formatter changes',function()
    local f,a=fixture(true);f.load('LibsAugment/FAIAP.lua');local enable=a.LuaSyntax.enable
    a.LuaSyntax.enable=function(edit,...)
        local methods={GetText=edit.GetText,SetText=edit.SetText};setmetatable(edit,{__index=methods})
        function edit:GetMaxBytes() return self.maxBytes or 0 end;function edit:SetMaxBytes(v) self.maxBytes=v end;function edit:GetMaxLetters() return self.maxLetters or 0 end;function edit:IsMultiLine() return self.multiLine end
        return enable(edit,...)
    end
    local source=a:CopySettingsData(a.empty_condition);source.description='Indented';source.fields={unit='string'};source.evaluate='\n        if true then\n            return true\n        end\n'
    a.db.global.custom_conditions.INDENTED=source;assert(a:register_custom_condition('INDENTED',source))
    a.db.profile.condition_groups={};a.db.profile.disabled_conditions={};a.db.profile.switch_conditions={};a.db.profile.other_conditions_order={}
    local host=f.env.CreateFrame('Frame');host:SetSize(1000,700);local p=a:OpenNativeSettings(host,'Conditions');p.fields.duplicate_custom:Click()
    local d=p.inlineCondition;assert(d and not d.readOnly);a.LuaSyntax.indentEditbox(d.code.edit);d:UpdateActions();d.form:RefreshUnsaved()
    assert(not d.code:GetText():match('^%s'),'clone retained a blank first line or shared indentation')
    assert(not d.code.frame.rmUnsaved and not d.functionTabs.evaluate.rmUnsaved,'formatter made a fresh clone look edited')
    assert(not d.form.fields.description.rmUnsaved and not d.form.fields.schema.rmUnsaved and not d.form.fields.identifier.rmUnsaved,'pooled field baselines leaked into a fresh clone')
    assert(d.apply:IsEnabled(),'new clone still needs Apply to create it')
end)
test('builtin condition code keeps the selected documentation provider in read-only mode',function()
    local f,a=fixture(true);f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Conditions/combat.lua')
    a.db.profile.lua_editor='Documentation provider';a:RegisterLuaEditorProvider('Documentation provider',function(parent)
        local c={frame=f.env.CreateFrame('Frame',nil,parent),edit=f.env.CreateFrame('EditBox',nil,parent)}
        function c:GetText() return self.edit:GetText() end;function c:SetText(text) self.edit:SetText(text) end
        function c:SetReadOnly(readonly) self.readOnly=readonly;if readonly then self.edit:Disable() else self.edit:Enable() end end
        function c:SetContext(context) self.context=context end;function c:Release() self.frame:Hide() end
        return c
    end)
    a.db.profile.condition_groups={};a.db.profile.disabled_conditions={};a.db.profile.switch_conditions={};a.db.profile.other_conditions_order={};a.listConditions=function() return {'COMBAT'} end
    local host=f.env.CreateFrame('Frame');host:SetSize(1000,700);local p=a:OpenNativeSettings(host,'Conditions');local d=assert(p.inlineCondition)
    assert(d.readOnly and d.code.provider=='Documentation provider','builtin code discarded the selected provider and its API documentation')
    assert(not d.code.edit:IsEnabled() and d.code.inner.readOnly,'provider source view permits typing')
    assert(d.code.inner.context.kind=='condition' and d.code.inner.context.id=='COMBAT','readonly provider lost its RM symbol context');assert(not d:IsDirty())
end)
test('confirmed condition deletion removes source and registry immediately and leaves its successor clean',function()
    local f,a=fixture(true);for _,key in ipairs({'A','B'}) do local source=a:CopySettingsData(a.empty_condition);source.description=key;a.db.global.custom_conditions[key]=source;a.conditionDefinitions[key]={description=key,fields={}} end
    local removed=0;a.UnregisterCondition=function(self,key) removed=removed+1;self.conditionDefinitions[key]=nil end
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');assert(p.condition=='A');p.inlineCondition.form.fields.delete:Click()
    assert(p.prompt.text:GetText():find('cannot be undone',1,true) and a.db.global.custom_conditions.A and removed==0);p.prompt.accept:Click();local d=p.inlineCondition
    assert(not a.db.global.custom_conditions.A and not a.conditionDefinitions.A and removed==1 and p.condition=='B' and d and not d:IsDirty() and not d.apply:IsEnabled() and not d.viewChanges:IsEnabled(),'successor inherited deleted entry dirty state')
end)
test('failed condition unregister keeps both saved source and registered definition',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='A';a.db.global.custom_conditions.A=source;local definition={description='A',fields={}};a.conditionDefinitions.A=definition
    a.UnregisterCondition=function() error('cleanup failed') end;local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');p.inlineCondition.form.fields.delete:Click();p.prompt.accept:Click();assert(a.db.global.custom_conditions.A==source and a.conditionDefinitions.A==definition and p.inlineCondition,'failed unregister partially removed a condition')
end)
test('condition deletion offers Discard for invalid pending schema before permanent confirmation',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='A';a.db.global.custom_conditions.A=source;a.conditionDefinitions.A={description='A',fields={}};a.UnregisterCondition=function(self,key) self.conditionDefinitions[key]=nil end
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition;d.form.fields.schema:SetText('{ invalid =');d.form.fields.schema.scripts.OnTextChanged(d.form.fields.schema,true)
    d.form.fields.delete:Click();assert(p.prompt.discard:IsShown(),'invalid schema blocked deletion navigation');p.prompt.cancel:Click();assert(d.form.fields.schema:GetText()=='{ invalid =')
    d.form.fields.delete:Click();p.prompt.discard:Click();assert(p.prompt.text:GetText():find('cannot be undone',1,true) and a.db.global.custom_conditions.A);p.prompt.accept:Click();assert(not a.db.global.custom_conditions.A and not a.conditionDefinitions.A and not p:IsSettingsDraftDirty())
end)
test('renaming required schema fields stages their metadata atomically and leaves code unchanged',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Required unit';source.fields={unit='string'};source.requiredFields={'unit'}
    a.db.global.custom_conditions.REQUIRED=source;a.conditionDefinitions.REQUIRED={description=source.description};local original=a:CopySettingsData(source)
    local d=a:condition_edit_box(function() end,'REQUIRED',source);d.form.fields.schemaGraph:Click();local g=d.schemaEditor
    local name=g.form.fields.field_1;name:SetText('renamed');name.scripts.OnTextChanged(name,true);g:UpdateActions();g.apply:Click()
    assert(d.model.value.requiredFields[1]=='renamed','schema child kept a stale required name')
    assert(d.schemaViewport.rmUnsaved and a:SettingsDataEqual(a.db.global.custom_conditions.REQUIRED,original))
    assert(d:Apply(),'parent Apply failed after a valid root rename');local saved=a.db.global.custom_conditions.REQUIRED
    assert(saved.fields.renamed=='string' and saved.requiredFields[1]=='renamed')
    for name in pairs(a.CustomConditionCallbacks) do assert(saved[name]==original[name],'schema metadata rewrote callback text') end
end)
test('root Required controls stay detached through Cancel Undo and parent Discard',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Optional fields';source.fields={group={child='number'},unit='string'}
    a.db.global.custom_conditions.OPTIONAL=source;a.conditionDefinitions.OPTIONAL={description=source.description};local d=a:condition_edit_box(function() end,'OPTIONAL',source)
    d.form.fields.schemaGraph:Click();local g=d.schemaEditor;assert(not g:IsDirty() and not g.cards['1/1'].required,'nested fields got root requirement controls')
    assert(g.cards['2'].required and not g.cards['2'].required:GetChecked());g.cards['2'].required:Click()
    assert(g.model.root.children[2].required and source.requiredFields==nil);g.cancel:Click();assert(d.model.value.requiredFields==nil and not d:IsDirty())
    d.form.fields.schemaGraph:Click();g=d.schemaEditor;g.model:SetRequired({2},true);g:UpdateActions();g.apply:Click();assert(d.model.value.requiredFields[1]=='unit' and d.schemaViewport.rmUnsaved)
    assert(d:TravelModel(false));d.form:Draw();d:UpdateActions();assert(d.model.value.requiredFields==nil and not d.schemaViewport.rmUnsaved)
    d:Close();assert(source.requiredFields==nil)
end)
test('advanced schema reconciles explicit removed requirements but invalid text preserves them',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Required';source.fields={unit='string',count='number'};source.requiredFields={'unit','count'}
    a.db.global.custom_conditions.ADVANCED=source;a.conditionDefinitions.ADVANCED={description=source.description};local d=a:condition_edit_box(function() end,'ADVANCED',source)
    local raw=d.form.fields.schema;raw:SetText('{broken=');raw.scripts.OnTextChanged(raw,true);assert(not d:Flush() and #d.model.value.requiredFields==2)
    raw:SetText('{ count = number }');raw.scripts.OnTextChanged(raw,true);d:UpdateActions();assert(d:Flush());assert(#d.model.value.requiredFields==1 and d.model.value.requiredFields[1]=='count')
    d:Close();assert(#source.requiredFields==2 and source.fields.unit=='string')
end)
test('invalid requirement references remain unchanged on open and repair only on explicit child Apply',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Legacy requirements';source.fields={unit='string'};source.requiredFields={'missing','unit'}
    a.db.global.custom_conditions.REPAIR=source;a.conditionDefinitions.REPAIR={description=source.description};local d=a:condition_edit_box(function() end,'REPAIR',source)
    assert(d.model.value.requiredFields[1]=='missing' and d.schemaViewport.rmInvalid);d.form.fields.schemaGraph:Click();local g=d.schemaEditor
    assert(g.requiresApply and g.form.message:GetText():find('Required field references',1,true));g.cancel:Click();assert(#d.model.value.requiredFields==2 and #source.requiredFields==2)
    d.form.fields.schemaGraph:Click();g=d.schemaEditor;g.apply:Click();assert(#d.model.value.requiredFields==1 and d.model.value.requiredFields[1]=='unit' and #source.requiredFields==2)
    assert(d:Apply() and #a.db.global.custom_conditions.REPAIR.requiredFields==1)
end)
test('required flags and pending root names survive owner resize until explicit Apply',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Inline requirements';source.fields={unit='string'}
    a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description=source.description,fields=source.fields}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    d.form.fields.schemaGraph:Click();local g=d.schemaEditor;g.cards['1'].required:Click();local raw=g.form.fields.field_1;raw:SetText('renamed');raw.scripts.OnTextChanged(raw,true)
    p:SetWidth(1060);d=p.inlineCondition;g=d.schemaEditor
    assert(g.active and g.model.root.children[1].required and g.form.fields.field_1:GetText()=='renamed');assert(source.requiredFields==nil and source.fields.unit=='string')
    assert(g:Apply() and d.model.value.requiredFields[1]=='renamed' and d.model.value.fields.renamed=='string')
    assert(source.requiredFields==nil and source.fields.unit=='string');p:Release()
end)
test('complete graphical schemas reach their last root field with bounded reusable rows and cached validation',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);local fields={};for i=1,511 do fields[string.format('field%03d',i)]='number' end
    d.model.value.fields=fields;d.form:Draw();d.form.fields.schemaGraph:Click();local g=d.schemaEditor;local view=g.cardView
    assert(view.scene and #view.scene.rows==511,'graphical schema still truncates the complete model')
    local calls=0;local original=a.IsEditableFieldSchemaName;a.IsEditableFieldSchemaName=function(...) calls=calls+1;return original(...) end
    g.form.scroll.workbenchBar:SetValue(g.form.scroll.workbenchBar.scrollRange);assert(g.cards['511'] and g.cards['511'].required,'last root field is inaccessible')
    local stale=g.cards['511'].remove.scripts.OnClick;local high=#view.rows
    local warmRows,warmZones
    for pass=1,2 do for i=0,10 do g.form.scroll.workbenchBar:SetValue(g.form.scroll.workbenchBar.scrollRange*i/10) end
        if pass==1 then warmRows,warmZones=#view.rows,#view.zones else assert(#view.rows==warmRows and #view.zones==warmZones,'warm scrolling allocated additional row or gap leases') end
    end
    assert(#view.rows<40 and #view.rows<=high+4 and #view.zones<40,'schema pools grew with the complete model: '..#view.rows..'/'..high..'/'..#view.zones);assert(calls==0,'scroll repeated complete schema validation')
    g.form.scroll.workbenchBar:SetValue(0);stale();assert(#g.model.root.children==511,'retired row callback removed its old field')
    g.form.scroll.workbenchBar:SetValue(g.form.scroll.workbenchBar.scrollRange);local row=g.cards['511'];row.name:SetText('renamed');row.name.scripts.OnTextChanged(row.name,true);row.type:Click();for _,choice in ipairs(g.form.menu.rows) do if choice:GetText()=='Boolean' then choice:Click();break end end
    g.cards['511'].required:Click();g.apply:Click()
    assert(d.model.value.fields.renamed=='boolean' and d.model.value.requiredFields[1]=='renamed' and fields.field511=='number')
end)
test('unchanged schema action updates reuse dirty comparisons and invalid raw names pin recycled rows',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);local fields={};for i=1,511 do fields[string.format('field%03d',i)]='number' end
    d.model.value.fields=fields;d.form:Draw();d.form.fields.schemaGraph:Click();local g=d.schemaEditor;local first=g.cards['1'];local input=first.name
    local comparisons=0;local equal=a.SettingsDataEqual;a.SettingsDataEqual=function(...) comparisons=comparisons+1;return equal(...) end
    for i=1,20 do g:UpdateActions() end;assert(comparisons==0,'unchanged action updates traversed the schema baseline')
    input:SetText('bad name');input.scripts.OnTextChanged(input,true);input:SetFocus();input:SetCursorPosition(3);local stale=input.scripts.OnEscapePressed
    g.form.scroll.workbenchBar:SetValue(g.form.scroll.workbenchBar.scrollRange);assert(g.cards['1']==first and input:HasFocus() and input:GetText()=='bad name')
    assert(not g:Apply() and g.active and fields.field001=='number')
    input.scripts.OnEscapePressed(input);g.form.scroll.workbenchBar:SetValue(g.form.scroll.workbenchBar.scrollRange/2)
    assert(first.lease and first.path[1]~=1,'clean released name slot was not recycled');first.name:SetFocus();stale();assert(first.name:HasFocus(),'retired Escape affected a new schema row')
    g.cancel:Click()
end)
test('offscreen pending schema names and caret survive owner resize and remain repairable',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Large inline schema';source.fields={};for i=1,511 do source.fields[string.format('field%03d',i)]='number' end
    a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description=source.description,fields=source.fields}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition;d.form.fields.schemaGraph:Click();local g=d.schemaEditor
    g.form.scroll.workbenchBar:SetValue(g.form.scroll.workbenchBar.scrollRange);local input=g.cards['511'].name;input:SetText('bad name');input.scripts.OnTextChanged(input,true);input:SetFocus();input:SetCursorPosition(3);g.form.scroll.workbenchBar:SetValue(0)
    p:SetWidth(1060);d=p.inlineCondition;g=d.schemaEditor;input=g.form.fields.field_511
    assert(input and input:GetText()=='bad name' and input:HasFocus() and input:GetCursorPosition()==3,'resize lost the offscreen pending name or native caret')
    assert(not g:Apply() and source.fields.field511=='number');input:SetText('renamed');input.scripts.OnTextChanged(input,true);assert(g:Apply() and d.model.value.fields.renamed=='number');p:Release()
end)
test('nested schema viewport drag carries complete hidden descendants to newly exposed final gaps',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);local fields={};for i=1,50 do local child={};for j=1,9 do child['child'..j]='string' end;fields[string.format('group%02d',i)]=child end
    d.model.value.fields=fields;d.form:Draw();d.form.fields.schemaGraph:Click();local g=d.schemaEditor;local view=g.cardView;assert(#view.scene.rows==500)
    g.form.scroll.workbenchBar:SetValue(g.form.scroll.workbenchBar.scrollRange);assert(g.cards['50'] and g.cards['50'].required and #view.rows<40)
    view:BeginDrag({50});assert(view.ghost.count:GetText()=='10 cards');g.form.scroll.workbenchBar:SetValue(0)
    local first;for _,zone in ipairs(view.zones) do if zone.target and #zone.path==0 and zone.gap==1 then first=zone end end
    assert(first and view:Drop(first.path,first.gap));assert(g.model.root.children[1].name=='group50' and #g.model.root.children[1].children==9)
    g.undo:Click();view=g.cardView;view:BeginDrag({1});g.form.scroll.workbenchBar:SetValue(g.form.scroll.workbenchBar.scrollRange)
    local final;for _,zone in ipairs(view.zones) do if zone.target and #zone.path==0 and zone.gap==51 then final=zone end end
    assert(final and view:Drop(final.path,final.gap));assert(g.model.root.children[50].name=='group01');g.undo:Click();assert(g.model.root.children[1].name=='group01');g.cancel:Click()
end)
test('schema viewport binding failure retires the partial lease and a later refresh recovers',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);local fields={};for i=1,511 do fields[string.format('field%03d',i)]='number' end
    d.model.value.fields=fields;d.form:Draw();d.form.fields.schemaGraph:Click();local g=d.schemaEditor;local view=g.cardView
    local paint=a.PaintSelectorSelection;local failed=false;a.PaintSelectorSelection=function(...) if not failed then failed=true;error('injected schema binding failure') end;return paint(...) end
    local ok=pcall(g.form.scroll.workbenchBar.SetValue,g.form.scroll.workbenchBar,g.form.scroll.workbenchBar.scrollRange)
    assert(not ok and failed and not view.refreshing,'failed schema binding kept the viewport reentry guard')
    assert(#g.form.edits==0 and next(g.cards)==nil,'failed binding retained records for retired input leases')
    a.PaintSelectorSelection=paint;view:Refresh();assert(g.cards['511'] and g.cards['511'].name:GetText()=='field511')
    local input=g.cards['511'].name;input:SetText('renamed');input.scripts.OnTextChanged(input,true);assert(g:Apply() and d.model.value.fields.renamed=='number');d:Close()
end)
test('legacy field names keep their complete text for graphical repair without changing the source',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);local name=string.rep('a',5000);local fields={[name]='number'}
    d.model.value.fields=fields;d.form:Draw();d.form.fields.schemaGraph:Click();local g=d.schemaEditor;local input=g.cards['1'].name
    assert(input:GetText()==name and g.cards['1'].frame.rmInvalid,'accepted compatibility name was truncated before repair')
    input:SetText('repaired');input.scripts.OnTextChanged(input,true);assert(g:Apply() and d.model.value.fields.repaired=='number' and fields[name]=='number');d:Close()
end)
test('every supported graphical schema fits the parent Advanced field without truncation or false errors',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Full supported schema';source.fields={}
    for i=1,511 do source.fields['f'..string.rep('x',60)..string.format('%03d',i)]='number' end
    a.db.global.custom_conditions.FULL_SCHEMA=source;a.conditionDefinitions.FULL_SCHEMA={description=source.description,fields=source.fields}
    local original=a:CopySettingsData(source);local d=a:condition_edit_box(function() end,'FULL_SCHEMA',source);local input=d.form.fields.schema;local raw=a:FormatCustomFieldSchema(source.fields)
    assert(#raw>32768 and input.maxLetters>=#raw and input:GetText()==raw,'supported schema was truncated by its parent input')
    assert(a:ParseCustomFieldSchema(raw),'the supported graph cannot roundtrip through Advanced')
    d.validationRequested=true;d:UpdateActions();assert(not input.rmInvalid and not d:IsDirty() and a:SettingsDataEqual(source,original))
end)
test('untouched compatibility schemas validate from the model while dirty Advanced text keeps strict parser limits',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Legacy schema';source.fields={}
    for i=1,600 do source.fields['field'..i]='number' end
    a.db.global.custom_conditions.LEGACY_SCHEMA=source;a.conditionDefinitions.LEGACY_SCHEMA={description=source.description,fields=source.fields}
    local d=a:condition_edit_box(function() end,'LEGACY_SCHEMA',source);d.validationRequested=true;d:UpdateActions();local input=d.form.fields.schema
    assert(not input.rmInvalid and not d:IsDirty(),'hidden raw schema imposed new save limits on untouched compatibility data')
    input:SetText(input:GetText()..' ');input.scripts.OnTextChanged(input,true);d:UpdateActions();assert(input.rmInvalid and not d:Flush(),'dirty Advanced text bypassed its bounded parser')
    input.scripts.OnEscapePressed(input);d:UpdateActions();assert(not input.rmInvalid and not d:IsDirty() and source.fields.field600=='number')
end)
test('bound-helper navigation offers pending condition choices before selecting its function',function()
    local f,a=fixture(true);f.load('UI/settings_functions.lua');f.load('UI/function_bindings.lua')
    a.db.global.custom_functions={HELPER={name='helper',namespace='custom',description='Helper',args={},returns={{type='boolean',description='Result'}},code='return true',bindings={}}};a:InitializeFunctionRegistry()
    local source=a:CopySettingsData(a.empty_condition);source.description='Inline';source.bindings={['custom.helper']='HELPER'};a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields={}}
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Conditions');local d=p.inlineCondition
    a.configWindow={pane=p};local opened;a.ShowConfig=function(_,section) opened=section end
    d.code.edit:SetText('return false');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.form.fields.function_bindings:Click()
    local alias=d.form.fields.binding_alias_1;alias:SetText('not a valid alias');alias.scripts.OnTextChanged(alias,true);d.form.fields.binding_target_1:Click()
    assert(p.prompt and p.prompt.frame:IsShown() and not opened and not a.configFunctionSelection,'helper jump bypassed pending condition edits')
    p.prompt.cancel:Click();assert(d.OwnerValid() and d.code:GetText()=='return false' and alias:GetText()=='not a valid alias' and not opened)
    d.form.fields.binding_target_1:Click();p.prompt.discard:Click();assert(opened=='Functions' and a.configFunctionSelection=='HELPER' and a.db.global.custom_conditions.INLINE.evaluate==source.evaluate)
end)
test('settings custom editor opens a canonical shallow copy and preserves source and owner guards',function()
    local f,a=fixture(true);local source=a:CopySettingsData(a.empty_condition);source.description='Original';source.fields={count='number'}
    a.db.global.custom_conditions.CUSTOM=source;a.conditionDefinitions.CUSTOM={description='Original'}
    local p=a:CreateSettingsForm(f.env.UIParent);p:Open(function() end)
    local copy,seen;local canonical=a.Functions.collections.deepcopy
    a.Functions.collections.deepcopy=function(value,...) local result=canonical(value,...);if value==source then copy=result;seen=true end;return result end
    a.deepcopy=function() error('retired addon.deepcopy used by settings custom editor') end
    local d,owner=a:OpenSettingsCustomCondition(p,'CUSTOM',source)
    assert(seen and copy~=source and copy.fields==source.fields and d.nativeCustomEditor and owner.active)
    local description=d.form.fields.description;description:SetText('Edited');description.scripts.OnTextChanged(description,true);description.scripts.OnEnterPressed(description)
    assert(source.description=='Original' and a.db.global.custom_conditions.CUSTOM==source and d:PendingSource().description=='Edited')
    d:UpdateActions();d.apply:Click();assert(a.db.global.custom_conditions.CUSTOM.description=='Edited' and source.description=='Original' and p.condition=='CUSTOM' and p.category=='ALL' and p.conditionSource=='custom')
    local saved=a.db.global.custom_conditions.CUSTOM;d,owner=a:OpenSettingsCustomCondition(p,'CUSTOM',saved)
    local apply=d.apply.scripts.OnClick;p:Release();apply()
    assert(a.db.global.custom_conditions.CUSTOM==saved and source.description=='Original' and not owner.active)
end)
finish()
