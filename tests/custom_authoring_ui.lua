local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon;dofile('tests/fixtures/native_ui.lua')(f.env);local make=f.env.CreateFrame;f.env.CreateFrame=function(kind,...) local frame=make(kind,...);if kind=='EditBox' then local set=frame.SetText;frame.SetText=function(self,text) if self.maxLetters and self.maxLetters>0 then text=text:sub(1,self.maxLetters) end;set(self,text) end end;return frame end;local data,deps=dofile('tests/fixtures/codec.lua')();a.RotationData=data;a.NewRotationCodec=function() return data.NewCodec(deps) end;a.pretty_name='Rotation Master';a.name='rotationmaster';a.db.char={};a.db.global.custom_conditions={}
    for _,path in ipairs({'Core/custom_condition_owner.lua','UI/settings_draft.lua','Core/custom_authoring.lua','UI/settings_history.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_roster_order.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/custom_condition_transfer.lua','UI/icon_picker.lua','UI/help.lua','Options/custom_condition.lua','UI/lua_editor.lua','UI/custom_condition_editor.lua'}) do local h=io.open(path);if h then h:close();f.load(path) end end
    a.conditionDefinitions=a.definitions;a.RegisterCondition=function(self,key,value) self.conditionDefinitions[key]=value;if value.on_register then value.on_register(key) end end
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    return f,a
end
test('native editor stages schema and callbacks until Apply and has cross-function Undo',function()
    local f,a=fixture();assert(a.CreateWorkbenchLuaEditor,'native code editor missing');local saved;local d=a:condition_edit_box(function(key) saved=key end)
    assert(d.nativeCustomEditor and d.form and d.code);local p=d.form;local function edit(key,text) local c=p.fields[key];c:SetText(text);c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c) end
    edit('identifier','NATIVE');edit('description','Native condition');edit('schema','{ count = number }');d.code.edit:SetText('return true');d.code.edit.scripts.OnTextChanged(d.code.edit,true);assert(not a.db.global.custom_conditions.NATIVE)
    d:SelectFunction('print');d.code.edit:SetText('return "Name"');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d:SelectFunction('evaluate');d.undo:Click();assert(d.model.value.print~= 'return "Name"');d.redo:Click();assert(d.model.value.print=='return "Name"');d.apply:Click();assert(saved=='NATIVE' and a.db.global.custom_conditions.NATIVE.fields.count=='number' and not d.frame:IsShown())
end)
test('syntax checks never run callbacks and errors preserve code and saved source',function()
    local f,a=fixture();local source=a:CopySettingsData(a.empty_condition);source.description='Original';a.db.global.custom_conditions.CUSTOM=source;a.conditionDefinitions.CUSTOM={description='Original'};local d=a:condition_edit_box(function() end,'CUSTOM',source)
    d.code.edit:SetText('return )');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.syntax:Click();assert(d.frame:IsShown() and d.code:GetText()=='return )' and a.db.global.custom_conditions.CUSTOM==source)
    d.code.edit:SetText('error("MUST NOT RUN")');d.code.edit.scripts.OnTextChanged(d.code.edit,true);d.syntax:Click();assert(d.model.value.evaluate=='error("MUST NOT RUN")' and a.db.global.custom_conditions.CUSTOM==source);d.cancel:Click();assert(not d.frame:IsShown() and a:SettingsDataEqual(a.db.global.custom_conditions.CUSTOM,source),'reloaded duplicate or original source mismatch')
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
    local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end);assert(code.syntax,'real syntax engine failed to attach');local source='local count = 1';code:SetText(source);a.LuaSyntax.indentEditbox(code.edit);assert(code:GetText()==source and a.LuaSyntax.coloredGetText(code.edit):find('|c',1,true));code:Release();assert(not code.frame:IsShown())
end)
test('profile replacement closes native authoring and leaves its captured callbacks inert',function()
    local f,a=fixture();local d=a:condition_edit_box(function() error('stale callback') end);local apply=d.apply.scripts.OnClick;a.db.profile={};d.frame.scripts.OnUpdate();assert(d.closed and not d.frame:IsShown());apply();assert(not next(a.db.global.custom_conditions))
end)
test('choosing icons preserves live code text and undo can restore it',function()
    local f,a=fixture();local d=a:condition_edit_box(function() end);d.code.edit:SetText('return 12345');d.code.edit.scripts.OnTextChanged(d.code.edit,true);local choose;a.ShowWorkbenchIconPicker=function(_,_,callback) choose=callback;return {serial=1,frame=f.env.CreateFrame('Frame')} end;d.form.fields.icon:Click();choose(123);assert(d.code:GetText()=='return 12345' and d.model.value.evaluate=='return 12345');d.undo:Click();assert(d.model.value.evaluate=='return 12345' and d.model.value.icon~=123)
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
finish()
