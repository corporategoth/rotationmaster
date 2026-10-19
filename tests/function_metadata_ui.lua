local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(readonly)
    local f=F.new();local a=f.addon;dofile('tests/fixtures/native_ui.lua')(f.env);a.db.char={};a.db.global.custom_functions={}
    for _,path in ipairs({'Core/function_data.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_roster_order.lua','UI/settings_form.lua','UI/settings_collections.lua','UI/settings_transfer.lua','UI/lua_input_diagnostics.lua','UI/lua_editor.lua','UI/settings_functions.lua','UI/function_bindings.lua','UI/function_source_pane.lua','UI/function_bundle_transfer.lua'}) do f.load(path) end
    local src={name='helper',description=string.rep('Readable description. ',50),args={{name='value',type='number | nil',description=string.rep('Argument documentation. ',20)}},returns={{type='RMResult | boolean',description='First result'}},code='    return value',bindings={}}
    if readonly then a:RegisterBuiltinFunction('builtin:test',src,function() return function(v) return v end end) else a.db.global.custom_functions.HELPER=src;a:InitializeFunctionRegistry() end
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:OpenNativeSettings(host,'Functions');return f,a,p,p.inlineFunction,src
end
test('packaged and custom metadata share named type selectors nullable and description widgets',function()
    for _,readonly in ipairs({false,true}) do
        local _,_,_,d=fixture(readonly);local fields=d.form.fields
        assert(fields.arg_1_type and fields.arg_1_nullable and fields.return_1_type and fields.return_1_nullable,'metadata does not share type selectors')
        assert(fields.arg_1_type:IsEnabled()~=readonly and fields.arg_1_nullable:IsEnabled()~=readonly)
        assert(fields.description.multiLine and fields.description.cursor==0 and fields.description:GetHeight()>24,'long descriptions are truncated or start at the end')
        assert(fields.arg_1_description.multiLine and fields.arg_1_description:GetHeight()>24)
        assert(d:PendingSource().args[1].type=='number | nil' and d:PendingSource().returns[1].type=='RMResult | boolean','opening metadata rewrites its type')
    end
end)
test('nullable toggling preserves existing union members and stages type edits',function()
    local _,_,_,d,original=fixture(false);d.form.fields.arg_1_nullable:Click();assert(d:PendingSource().args[1].type=='number' and original.args[1].type=='number | nil')
    d.form.fields.return_1_nullable:Click();assert(d:PendingSource().returns[1].type=='RMResult | boolean | nil')
    d.form.fields.arg_1_type:Click();local menu=d.form.menu;local chosen;for _,row in ipairs(menu.rows) do if row:GetText()=='string' then chosen=row end end
    if not chosen then for index,entry in ipairs(menu.entries or {}) do if entry.value=='string' then chosen=menu.rows[index] end end end
    assert(chosen,'type choices omit string');chosen:Click();assert(d:PendingSource().args[1].type=='string' and d:IsDirty())
end)
test('code expansion preserves pending metadata code and editor provider',function()
    local _,_,p,d=fixture(false);local editor=d.code;local name=d.form.fields.description;name:SetText('Changed description');name.scripts.OnTextChanged(name,true)
    d.code.edit:SetText('return value + 1');d.code.edit.scripts.OnTextChanged(d.code.edit,true)
    assert(d.codeExpand,'code corner expansion missing');d.codeExpand:Click();assert(d.codeExpanded and d.code==editor and d.code:GetText()=='return value + 1' and d:PendingSource().description=='Changed description')
    assert(not d.form.fields.name,'metadata still occupies the enlarged source view');d.codeExpand:Click();assert(not d.codeExpanded and d.form.fields.name and d.code==editor)
    p:Draw();assert(p.inlineFunction.code:GetText()=='return value + 1' and p.inlineFunction:IsDirty())
end)
test('readonly code expansion never replaces original indented source with displayed code',function()
    local _,_,p,d,original=fixture(true);assert(d.codeExpand,'readonly source lacks expansion');d.codeExpand:Click();d.codeExpand:Click();p:Draw();assert(p.inlineFunction:PendingSource().code==original.code and not p.inlineFunction:IsDirty())
end)
test('metadata controls fit a narrow pane and descriptions measure their displayed width',function()
    local _,_,_,d=fixture(false);d.frame:SetWidth(280);d.form:Draw();local form=d.form
    for _,key in ipairs({'arg_1_name','arg_1_type','arg_1_nullable','arg_1_description','return_1_type','return_1_nullable','return_1_description'}) do
        local control=assert(form.fields[key]);assert(control.point[2]+control:GetWidth()<=form.width,key..' overflows the pane')
    end
    local input=form.fields.arg_1_description;local lines=math.ceil(#input:GetText()/math.max(1,(input:GetWidth()-10)/7));assert(input:GetHeight()==math.max(54,lines*12+12),'description height used another field width')
    assert(form.fields.arg_1_type.rmUnsaved~=true);form.fields.arg_1_nullable:Click();assert(form.fields.arg_1_type.rmUnsaved,'type change lacks unsaved marker')
end)
test('nil-only result metadata stays a nil type without widening it to nullable any',function()
    local _,_,p,d=fixture(false);d.value.returns[1].type='nil';d.baseline.returns[1].type='nil';d.form:Draw();d:UpdateActions()
    assert(d.form.fields.return_1_type:GetText()=='nil','nil-only return was displayed as any')
    assert(not d.form.fields.return_1_nullable:IsEnabled() and d:PendingSource().returns[1].type=='nil')
end)
finish()
