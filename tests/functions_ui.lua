local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon;dofile('tests/fixtures/native_ui.lua')(f.env);a.db.char={};a.db.global.custom_functions={}
    for _,path in ipairs({'Core/function_data.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_roster_order.lua','UI/settings_form.lua','UI/settings_collections.lua','UI/settings_transfer.lua','UI/lua_input_diagnostics.lua','UI/lua_editor.lua','UI/settings_functions.lua','UI/function_bindings.lua','UI/function_source_pane.lua','UI/function_bundle_transfer.lua'}) do local file=io.open(path);if file then file:close();f.load(path) end end
    local data,deps=dofile('tests/fixtures/codec.lua')();a.RotationData=data;a.NewRotationCodec=function() return data.NewCodec(deps) end
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700)
    return f,a,host
end
local function source(name) return {name=name,description=name..' documentation',args={{name='value',type='number',description='Input value'}},returns={{type='number',description='Result'}},code='return value',bindings={}} end
local function edit(d,key,value) local c=assert(d.form.fields[key],key);c:SetText(value);c.scripts.OnTextChanged(c,true);c.scripts.OnEnterPressed(c) end
local function code(d,value) d.code.edit:SetText(value);d.code.edit.scripts.OnTextChanged(d.code.edit,true);d:UpdateActions() end
local function conditionEditor(f,a)
    for _,path in ipairs({'Core/custom_condition_owner.lua','Core/custom_authoring.lua','Core/schema_authoring.lua','UI/schema_cards.lua','UI/schema_editor.lua','UI/custom_source_fields.lua','UI/settings_transfer.lua','UI/custom_condition_transfer.lua','UI/icon_picker.lua','UI/help.lua','Options/custom_condition.lua','UI/custom_condition_editor.lua','UI/condition_source_preview.lua'}) do local file=io.open(path);if file then file:close();f.load(path) end end
    a.conditionDefinitions=a.definitions;a.describeCondition=function(self,key) local definition=self.conditionDefinitions[key];return definition and definition.description end
end
local function previewContainers(f)
    local ace=f.libraries['AceGUI-3.0'];local create=ace.Create
    ace.Create=function(self,kind)
        local widget=create(self,kind);widget.frame=widget.frame or f.env.CreateFrame('Frame');widget.userdata=widget.userdata or {}
        if kind=='SimpleGroup' then
            function widget:DoLayout() local height=0;for _,child in ipairs(self.children) do height=height+(child.frame and child.frame:GetHeight() or 20) end;self.frame:SetHeight(math.max(1,height));if self.LayoutFinished then self:LayoutFinished(self.frame:GetWidth(),height) end end
            local add=widget.AddChild;function widget:AddChild(child) add(self,child);if child.frame then child.frame:SetParent(self.frame) end;self:DoLayout() end
        end
        return widget
    end
    ace.Release=function(self,widget)
        if widget.isQueuedForRelease then return end;widget.isQueuedForRelease=true
        for _,child in ipairs(widget.children or {}) do self:Release(child) end
        if widget.OnRelease then widget:OnRelease() end;if widget.frame then widget.frame:Hide() end
    end
end
local function pooledPreviewContainers(f)
    -- Use the shipped pool, container layout and widgets. In particular, pooled
    -- roots stay hidden until their native host explicitly shows them.
    local ace=f.libraries['AceGUI-3.0'];local constructors=ace.constructors;local stub=f.env.LibStub;local errors={}
    f.env.LibStub=setmetatable({NewLibrary=function(_,name) assert(name=='AceGUI-3.0');return ace end},{__call=function(_,...) return stub(...) end})
    f.env.geterrorhandler=function() return function(err) errors[#errors+1]=err end end
    f.env.xpcall=function(callback,handler,...) local args={n=select('#',...),...};return xpcall(function() return callback(unpack(args,1,args.n)) end,handler) end
    f.env.table=setmetatable({wipe=function(value) for key in pairs(value) do value[key]=nil end;return value end},{__index=table})
    local create=f.env.CreateFrame
    f.env.CreateFrame=function(...)
        local frame=create(...);local setSize=frame.SetSize
        -- WoW only emits OnSizeChanged for an actual size change.
        function frame:SetSize(width,height) if self.width~=width or self.height~=height then setSize(self,width,height) end end
        return frame
    end
    f.load('Libs/AceGUI-3.0/AceGUI-3.0.lua')
    for kind,constructor in pairs(constructors) do ace:RegisterWidgetType(kind,constructor,1) end
    f.load('Libs/AceGUI-3.0/widgets/AceGUIContainer-SimpleGroup.lua');f.load('Libs/AceGUI-3.0/widgets/AceGUIWidget-Label.lua')
    return errors
end
test('Functions opens packaged helpers readonly and duplicates a typed source without saving',function()
    local f,a,host=fixture();assert(a.BuildFunctionSettings,'Functions page missing')
    a:RegisterBuiltinFunction('builtin:test',source('Packaged helper'),function() return function(v) return v end end)
    a:RegisterBuiltinFunction('builtin:value',source('Internal constant'),function() return {} end,true)
    local p=a:OpenNativeSettings(host,'Functions');assert(#p.roster.entries==1 and p.inlineFunction.readOnly and p.inlineFunction.code.readOnly)
    assert(not p.inlineFunction.form.fields.name:IsEnabled() and p.inlineFunction.signature:GetText():find('value',1,true))
    p.fields.duplicate_function:Click();local d=p.inlineFunction;assert(not d.readOnly and d:IsDirty() and not next(a.db.global.custom_functions));assert(d:PendingSource().args[1].type=='number')
    edit(d,'name','myHelper');d.apply:Click();assert(a.db.global.custom_functions[p.functionID].name=='myHelper' and a:ResolveFunctionBinding(p.functionID)(8)==8)
end)
test('typed metadata and code stage until Apply, history resets and syntax checks execute no helper',function()
    local f,a,host=fixture();local original=source('Original');a.db.global.custom_functions.CUSTOM=original;a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction;d.form.fields.arg_1_nullable:Click();code(d,'error("must not run")');d.syntax:Click();assert(a.db.global.custom_functions.CUSTOM==original and d.form.message:GetText():find('No custom code',1,true))
    d.codeUndo:Click();assert(d.code:GetText()=='return value');d.codeRedo:Click();assert(d.code:GetText():find('must not run',1,true));d.codeReset:Click();assert(d.code:GetText()=='return value');d.codeUndo:Click();assert(d.code:GetText():find('must not run',1,true))
    code(d,'return value + 1');d.apply:Click();assert(a.db.global.custom_functions.CUSTOM.args[1].type=='number | nil' and a:ResolveFunctionBinding('CUSTOM')(4)==5)
end)
test('unsaved navigation offers Apply Discard Cancel and preserves invalid source on redraw',function()
    local f,a,host=fixture();a.db.global.custom_functions.A=source('Alpha');a.db.global.custom_functions.B=source('Beta');a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction;code(d,'return )');p:Draw();d=p.inlineFunction;assert(d.code:GetText()=='return )' and d.code.frame.rmInvalid)
    p.roster.choose('B');assert(p.prompt.frame:IsShown() and p.functionID=='A');p.prompt.cancel:Click();assert(p.inlineFunction.code:GetText()=='return )');p.roster.choose('B');p.prompt.discard:Click();assert(p.functionID=='B' and a.db.global.custom_functions.A.code=='return value')
end)
test('disabled and missing dependency reasons stay visible and stale Apply cannot save',function()
    local f,a,host=fixture();local original=source('Unavailable');original.bindings={helper='MISSING'};a.db.global.custom_functions.A=original;a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');assert(p.roster.entries[1].invalid and p.roster.entries[1].validationMessage:find('missing-function',1,true));local d=p.inlineFunction;d.form.fields.definition_enabled:Click();assert(not original.disabled and d:IsDirty());d.apply:Click();assert(a.db.global.custom_functions.A.disabled)
    d=p.inlineFunction;local apply=d.apply.scripts.OnClick;code(d,'return 5');a.db.profile={};apply();assert(a.db.global.custom_functions.A.code=='return value')
end)
test('bundle transfer exports dependencies and requires resolving conflicts before an atomic import',function()
    local f,a,host=fixture();assert(a.ShowFunctionBundleTransfer,'bundle transfer UI missing')
    local helper=source('Helper');local root=source('Root');root.bindings={helper='HELPER'};root.code='return helper(value)'
    a.db.global.custom_functions.ROOT=root;a.db.global.custom_functions.HELPER=helper;a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');p.functionID='ROOT';p:Draw();p.fields.transfer:Click();local d=p.functionBundleTransfer
    local exported=assert(a:ParseFunctionBundleImport(d.input:GetText(),a:NewRotationCodec()));assert(#exported.dependencies==1)
    d.includeDependencies:Click();exported=assert(a:ParseFunctionBundleImport(d.input:GetText(),a:NewRotationCodec()));assert(#exported.dependencies==0 and #exported.requirements==1)
    d.includeDependencies:Click();exported=assert(a:ParseFunctionBundleImport(d.input:GetText(),a:NewRotationCodec()));exported.dependencies[1].source.code='return value * 2';exported.requirements[1].hash=a:FunctionSourceHash(exported.dependencies[1].source);d.input:SetText(assert(a:NewRotationCodec():Encode(exported)));d:Review();assert(d.plan and not d.plan.valid and not d.apply:IsEnabled(),d.status:GetText())
    d.choices['function:HELPER']={action='rename',id='HELPER_COPY',name='New helper'};d.choices['function:ROOT']={action='replace',id='ROOT'};d:Review();assert(d.plan.valid and d.apply:IsEnabled());d.apply:Click();assert(a:ResolveFunctionBinding('ROOT')(3)==6 and a:ResolveFunctionBinding('HELPER')(3)==3 and a.db.global.custom_functions.HELPER_COPY.name=='New helper')
end)
test('shared binding rows rename explicit aliases without rewriting the Lua body',function()
    local f,a,host=fixture();local src=source('Bound');src.bindings={helper='HELPER'};src.code='return helper(value)';a.db.global.custom_functions.A=src;a.db.global.custom_functions.HELPER=source('Helper');a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction;assert(not d.form.fields.binding_alias_1);d.form.fields.function_bindings:Click();edit(d,'binding_alias_1','renamed');assert(d:PendingSource().bindings.renamed=='HELPER' and not d:PendingSource().bindings.helper and d.code:GetText()=='return helper(value)');assert(d.form.fields.function_bindings.rmUnsaved and d.form.fields.binding_alias_1.rmUnsaved and d.form.fields.binding_target_1.rmUnsaved,'binding changes lack saved-baseline markers')
    d.form.fields.binding_remove_1:Click();assert(not next(d:PendingSource().bindings) and d.code:GetText()=='return helper(value)')
end)
test('condition authoring shares collapsed bindings and bundle Cancel resumes its unsaved source',function()
    local f,a=fixture();conditionEditor(f,a);a.db.global.custom_conditions={};a.db.global.custom_functions.HELPER=source('Helper');a:InitializeFunctionRegistry()
    local value=a:CopySettingsData(a.empty_condition);value.description='Bound condition';value.bindings={helper='HELPER'};local d=a:condition_edit_box(function() end,'TEST',value);assert(d.form.fields.function_bindings and not d.form.fields.binding_alias_1)
    d.form.fields.function_bindings:Click();assert(d.form.fields.binding_alias_1);code(d,'return helper(value)');d.transfer:Click();local transfer=d.form.functionBundleTransfer
    assert(transfer and transfer.frame:IsShown() and not d.frame:IsShown());assert(transfer.input:GetText()~='',transfer.status:GetText());local exported=assert(a:ParseFunctionBundleImport(transfer.input:GetText(),a:NewRotationCodec()));assert(exported.root.kind=='condition' and #exported.dependencies==1)
    transfer.cancel:Click();assert(d.frame:IsShown() and d:PendingSource().evaluate=='return helper(value)' and not a.db.global.custom_conditions.TEST)
end)
test('every imported row exposes full readonly Lua source before any save',function()
    local f,a,host=fixture();local p=a:OpenNativeSettings(host,'Functions');p.fields.transfer:Click();local d=p.functionBundleTransfer
    local value=source('Long helper');value.code='--'..string.rep('x',10000)..'\nreturn value';local bundle={format='RM-FunctionBundle',version=1,root={kind='function',id='NEW',name='Long helper',source=value},dependencies={},requirements={}}
    d.input:SetText(assert(a:NewRotationCodec():Encode(bundle)));d:Review();assert(d.form.fields.review_source_1,'readable source review missing');d.form.fields.review_source_1:Click();assert(d.sourceReview.code:GetText()==value.code and d.sourceReview.code.readOnly and not next(a.db.global.custom_functions));d.sourceReview.close:Click();assert(d.frame:IsShown())
end)
test('function symbol navigation uses the shell pending-change guard',function()
    local f,a=fixture();assert(a.ShowFunctionSource,'function source navigation missing');a.SetupOptions=function() end;a.pretty_name='Rotation Master';a.name='rotationmaster';a.db.GetCurrentProfile=function() return 'Test' end;f.load('UI/config.lua')
    a.db.global.custom_functions.A=source('Alpha');a.db.global.custom_functions.B=source('Beta');a:InitializeFunctionRegistry();local shell=a:ShowFunctionSource('A');local p=shell.pane;code(p.inlineFunction,'return )');a:ShowFunctionSource('B');assert(p.prompt.frame:IsShown() and p.functionID=='A');p.prompt.cancel:Click();p:Draw();assert(p.functionID=='A' and p.inlineFunction.code:GetText()=='return )','Cancel left a pending symbol selection');a:ShowFunctionSource('B');p.prompt.discard:Click();assert(shell.pane.functionID=='B' and shell.pane.inlineFunction.code:GetText()=='return value')
end)
test('idle function source frames reuse syntax validation until source or graph changes',function()
    local f,a,host=fixture();a.db.global.custom_functions.A=source('Alpha');a:InitializeFunctionRegistry();local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction
    local validate=a.ValidateCustomFunctionSource;local checks=0;a.ValidateCustomFunctionSource=function(self,...) checks=checks+1;return validate(self,...) end;d.validationInput=nil
    for _=1,5 do d:UpdateActions() end;assert(checks==1,'idle frames recompile unchanged source')
    code(d,'return value + 1');assert(checks==2);a.functionRegistryVersion=a.functionRegistryVersion+1;d:UpdateActions();assert(checks==3)
end)
test('Functions help explains source history explicit aliases and the bundle save boundary',function()
    local f,a=fixture();f.load('UI/help.lua');local entries=a:WorkbenchPageHelp('Functions');local text={};for _,entry in ipairs(entries) do text[#text+1]=entry.text end;text=table.concat(text,'\n')
    assert(text:find('Reset',1,true) and text:find('alias',1,true) and text:find('Apply import',1,true) and text:find('read-only',1,true),'Functions help lacks its authoring and import contracts')
end)
test('schema preview keeps its label fixed and Advanced owns a multiline viewport',function()
    local f,a=fixture();conditionEditor(f,a);a.db.global.custom_conditions={};local d=a:condition_edit_box(function() end);local form=d.form;local label=form.fields.schemaLabel;assert(label,'schema label anchor missing');local y=label.point[3];local h=label:GetHeight()
    form.fields.advancedSchema:Click();assert(form.fields.schemaLabel.point[3]==y and form.fields.schemaLabel:GetHeight()==h,'Advanced moved the schema label')
    local raw=form.fields.schema;assert(raw.multiLine and raw:GetParent()==d.schemaViewport.schemaContent and raw.allPoints==d.schemaViewport.schemaContent,'Advanced still uses a single-line input');assert(d.schemaViewport.schemaContent:GetHeight()>=d.schemaViewport:GetHeight())
    raw:SetText('{ first = number,\n second = string }');raw.scripts.OnTextChanged(raw,true);d:UpdateActions();assert(d.schemaViewport.rmUnsaved and not form.fields.schemaGraph.rmUnsaved,'schema dirty marker does not cover its entire viewport')
end)
test('field schema history and root Add stay above the scrolled cards',function()
    local f,a=fixture();conditionEditor(f,a);a.db.global.custom_conditions={};local d=a:condition_edit_box(function() end);d.form.fields.schemaGraph:Click();local g=d.schemaEditor
    assert(g.undo.point[1]=='TOPLEFT' and g.redo.point[1]=='TOPLEFT','schema history is still in the footer');assert(g.form.fields.add:GetParent()==g.frame and g.form.fields.add.point[1]=='TOPRIGHT','Add field scrolls with cards')
    assert(g.cards and not next(g.cards));g.form.fields.add:Click();assert(g.cards['1'].y==4,'redundant Fields heading still reserves space');g.undo:Click();assert(not next(g.cards));g.redo:Click();assert(g.cards['1'])
end)
test('bundle transfer shares Copy Clear X and child right-click close controls',function()
    local f,a,host=fixture();local down,focus=false,nil;f.env.IsMouseButtonDown=function() return down end;f.env.GetMouseFocus=function() return focus end
    a.db.global.custom_functions.A=source('Alpha');a:InitializeFunctionRegistry();local p=a:OpenNativeSettings(host,'Functions');p.fields.transfer:Click();local d=p.functionBundleTransfer
    assert(d.sharedTransferShell and d.clear and d.frame.rmRightClickWatcher,'bundle does not use the common transfer shell');d:Review();assert(d.plan.valid);d.clear:Click();assert(d.input:GetText()=='' and not d.apply:IsEnabled() and not d.plan)
    d.close:Click();assert(not d.frame:IsShown());p.fields.transfer:Click();focus=d.input;down=true;d.frame.rmRightClickWatcher.scripts.OnUpdate();assert(not d.frame:IsShown(),'right-click on a child did not close the bundle')
end)
test('Functions roster Compare keeps the shared four-action layout and never edits sources',function()
    local f,a,host=fixture();local original=source('Alpha');a.db.global.custom_functions.A=original;a:InitializeFunctionRegistry();local p=a:OpenNativeSettings(host,'Functions');assert(p.fields.compare and not p.fields.compare:IsEnabled(),'single source has no disabled Compare action')
    a:RegisterBuiltinFunction('builtin:other',source('Packaged helper'),function() return function(value) return value end end);p:Draw();assert(#p.roster.footerActions==4 and p.fields.compare:IsEnabled());p.fields.compare:Click();p.menu.rows[1]:Click();assert(p.comparison and p.comparison.frame:IsShown() and a.db.global.custom_functions.A==original and not p.inlineFunction:IsDirty())
end)
test('new Fields UI template drops unused AceGUI while legacy header recognition preserves authored bodies',function()
    local f,a=fixture();conditionEditor(f,a);assert(not a.empty_condition.widget:find('local AceGUI',1,true),'new template still requires unused AceGUI')
    local legacy=a:CopySettingsData(a.empty_condition);legacy.widget='-- Create the widgets required to configure this condition.\n-- Params:\n--    parent - A bounding box that will contain this condition\'s widgets.\n--    spec - The talent specialization in use (as a number).\n--    value - The storage for this condition (ie. where it\'s parameters are stored).\nlocal AceGUI = LibStub("AceGUI-3.0")\nreturn AceGUI'
    local prepared=a:PrepareCustomConditionEditorSource(legacy);assert(prepared.widget=='local AceGUI = LibStub("AceGUI-3.0")\nreturn AceGUI','legacy authored body was removed with its template comments')
end)
test('Fields UI Preview explicitly runs the current buffer with detached values and disposes stale controls',function()
    local f,a=fixture();conditionEditor(f,a);previewContainers(f);a.db.global.custom_conditions={};local value=a:CopySettingsData(a.empty_condition);value.description='Preview';value.fields={count='number'};value.on_register='error("must not register")';value.evaluate='error("must not evaluate")';a.db.global.custom_conditions.PREVIEW=value
    local d=a:condition_edit_box(function() error('must not save') end,'PREVIEW',value);d:SelectFunction('widget');assert(d.test,'condition Test action missing')
    code(d,'addon.previewBuilds=(addon.previewBuilds or 0)+1; local top=parent:GetUserData("top"); assert(top:GetUserData("root")==value and top:GetUserData("funcs")); value.count=99; local input=addon:CreateConditionEditBox(); input:SetText(tostring(value.count)); input:SetCallback("OnEnterPressed",function(_,_,text) value.count=tonumber(text); addon.previewEdits=(addon.previewEdits or 0)+1 end); parent:AddChild(input)')
    d.syntax:Click();assert(not a.previewBuilds);d.test:Click();local view=d.sourcePreview;assert(view and view.frame:IsShown() and view.sample.count==99 and a.previewBuilds==1 and not d.frame:IsShown());assert(a.db.global.custom_conditions.PREVIEW==value and d:IsDirty() and not a.conditionDefinitions.PREVIEW)
    local child=view.pane.children[1];local stale=child.events.OnEnterPressed;view.close:Click();assert(d.frame:IsShown() and not child.alive);stale(child,'OnEnterPressed','41');assert(not a.previewEdits and a.db.global.custom_conditions.PREVIEW==value)
end)
test('Help Preview uses the help renderer and owner closure releases its child output',function()
    local f,a=fixture();conditionEditor(f,a);previewContainers(f);a.db.global.custom_conditions={};local d=a:condition_edit_box(function() end);d:SelectFunction('help');assert(d.test and d.test:IsShown(),'condition Test action missing')
    code(d,'frame:AddChild(addon.help_funcs.CreateText("Live help preview"))');d.test:Click();local view=d.sourcePreview;assert(view.helpPane.children[1].children[1].text:find('Live help preview',1,true));local pane=view.pane;d:Close();assert(not view.frame:IsShown() and not pane.rmActive)
end)
test('preview runtime errors are redacted and release even unattached native widgets',function()
    local f,a=fixture();conditionEditor(f,a);previewContainers(f);f.load('Diagnostics/errors.lua');a.db.global.custom_conditions={};local d=a:condition_edit_box(function() end);d:SelectFunction('widget');assert(d.test,'condition Test action missing')
    code(d,'addon.previewOrphan=addon:CreateConditionEditBox(); error("preview-source-secret")');d.test:Click();local view=d.sourcePreview;assert(not a.previewOrphan.alive and not view.status:GetText():find('preview-source-secret',1,true));local reports=a.Diagnostics:GetReports();assert(#reports==1 and reports[1].message:find('omitted',1,true));view.close:Click();assert(d.frame:IsShown())
end)
local function checkEditor(f,a)
    conditionEditor(f,a);previewContainers(f);a.db.global.custom_conditions={};local value=a:CopySettingsData(a.empty_condition);value.description='Check sample';value.fields={count='number'};value.valid='addon.checkedValid=(addon.checkedValid or 0)+1; return value.count>0';value.evaluate='addon.checkedEvaluate=(addon.checkedEvaluate or 0)+1; return value.count>=3';value.on_register='error("must not register")';value.on_unregister='error("must not unregister")';value.widget='local input=addon:CreateConditionEditBox(); input:SetText(tostring(value.count)); input:SetCallback("OnEnterPressed",function(_,_,text) value.count=tonumber(text) end); parent:AddChild(input)';a.db.global.custom_conditions.CHECK=value
    local owner=a:condition_edit_box(function() error('must not save') end,'CHECK',value);owner:SelectFunction('evaluate');return owner,value
end
test('Evaluate Check validates detached editable sample first and persists only separate test values',function()
    local f,a=fixture();local d,saved=checkEditor(f,a);assert(d.test:IsShown() and d.test:GetText()=='Test','Evaluate Check action missing');d.syntax:Click();assert(not a.checkedValid and not a.checkedEvaluate);d.test:Click();local view=d.sourcePreview;assert(not view.lastResult and not a.checkedValid and not a.checkedEvaluate);view.check:Click()
    assert(view.lastResult and view.lastResult.valid==false and view.lastResult.status=='invalid' and not a.checkedEvaluate)
    local input=view.pane.children[1];input:Fire('OnEnterPressed','3');view.check:Click();assert(view.lastResult.valid and view.lastResult.status=='match' and a.checkedEvaluate==1 and view.sample.count==3)
    assert(a.db.global.condition_test_values.CHECK.count==3 and not a.db.global.condition_test_values.CHECK.type and a.db.global.custom_conditions.CHECK==saved and not a.conditionDefinitions.CHECK)
    view.close:Click();d.test:Click();view=d.sourcePreview;view.check:Click();assert(view.sample.count==3 and view.lastResult.status=='match');view.close:Click();code(d,'return nil,"no-observation"');d.test:Click();d.sourcePreview.check:Click();assert(d.sourcePreview.lastResult.status=='unavailable' and d.sourcePreview.lastResult.reason=='no-observation')
end)
test('Live Check is opt-in throttled refreshes changed source and clears stale results on compile errors',function()
    local f,a=fixture();local d=checkEditor(f,a);assert(d.test:GetText()=='Test','Evaluate Check action missing');a.db.global.condition_test_values={CHECK={count=3}};d.test:Click();local view=d.sourcePreview;view.check:Click();local calls=a.checkedEvaluate
    view.frame.scripts.OnUpdate(view.frame,1);assert(a.checkedEvaluate==calls and not view.liveEnabled);code(d,'addon.checkedEvaluate=(addon.checkedEvaluate or 0)+1; return false');view.frame.scripts.OnUpdate(view.frame,1);assert(a.checkedEvaluate==calls,'source editing executed code without Live')
    view.live:Click();view.frame.scripts.OnUpdate(view.frame,.25);assert(a.checkedEvaluate==calls);view.frame.scripts.OnUpdate(view.frame,.25);assert(a.checkedEvaluate==calls+1 and view.lastResult.status=='no-match')
    code(d,'return )');view.frame.scripts.OnUpdate(view.frame,.5);assert(not view.lastResult and a.checkedEvaluate==calls+1,'compile error kept a stale result or executed old code');local tick=view.frame.scripts.OnUpdate;view.close:Click();assert(not view.liveEnabled);tick(view.frame,1);assert(a.checkedEvaluate==calls+1)
end)
test('Check owner replacement stops live work and malformed test values never persist',function()
    local f,a=fixture();local d=checkEditor(f,a);assert(d.test:GetText()=='Test','Evaluate Check action missing');a.db.global.condition_test_values={CHECK={count=3}};d.test:Click();local view=d.sourcePreview;view.sample.extra=function() end;view.check:Click();assert(not a.db.global.condition_test_values.CHECK.extra)
    view.live:Click();local calls=a.checkedEvaluate;a.db.profile={};view.frame.scripts.OnUpdate(view.frame,1);assert(not view.active and not view.liveEnabled and a.checkedEvaluate==calls)
end)
test('Check source rebuild makes callbacks from released preview controls inert',function()
    local f,a=fixture();local d=checkEditor(f,a);assert(d.test:GetText()=='Test');a.db.global.condition_test_values={CHECK={count=3}};d.test:Click();local view=d.sourcePreview;local old=view.pane.children[1];local stale=old.events.OnEnterPressed
    code(d,'return )');view.check:Click();assert(not view.lastResult and not old.alive);stale(old,'OnEnterPressed','900');assert(view.sample.count==3,'released controls still mutate the active sample')
end)
test('bundle review rejects the opposite root kind and clears a previously accepted plan',function()
    local f,a,host=fixture();conditionEditor(f,a);local c=a:CopySettingsData(a.empty_condition);c.description='Condition root'
    local bundles={['function']=assert(a:BuildFunctionBundle('function','IMPORTED_FUNCTION',source('Function root'))),condition=assert(a:BuildFunctionBundle('condition','IMPORTED_CONDITION',c))}
    local p=a:OpenNativeSettings(host,'Functions');local codec=a:NewRotationCodec()
    for _,kind in ipairs({'function','condition'}) do
        local d=a:ShowFunctionBundleTransfer(p,nil,nil,{kind=kind});d.input:SetText(assert(codec:Encode(bundles[kind])));assert(d:Review() and d.plan.valid and d.apply:IsEnabled())
        local opposite=kind=='function' and 'condition' or 'function';d.input:SetText(assert(codec:Encode(bundles[opposite])));assert(not d:Review(),'wrong root kind accepted')
        assert(not d.plan and not d.bundle and not d.apply:IsEnabled() and #d.lastRows==0 and #d.lastRequirements==0)
        d.apply:Click();assert(not next(a.db.global.custom_functions) and not next(a.db.global.custom_conditions or {}));d.cancel:Click()
    end
end)
test('Check commits pending native test fields and edits clear old results without evaluating',function()
    local f,a=fixture();local d=checkEditor(f,a);a.db.global.condition_test_values={CHECK={count=3}};d.test:Click();local view=d.sourcePreview;local input=view.pane.children[1];local calls=a.checkedEvaluate
    input.editbox:SetText('1');input.editbox.scripts.OnTextChanged(input.editbox,true);assert(input:IsPending());view.check:Click();assert(view.sample.count==1 and view.lastResult.status=='no-match','Check ignored pending field text')
    calls=a.checkedEvaluate;input.editbox:SetText('2');input.editbox.scripts.OnTextChanged(input.editbox,true);input.editbox.scripts.OnEnterPressed();assert(not view.lastResult and a.checkedEvaluate==calls,'editing a sample kept a stale result or evaluated automatically')
end)
test('Check reports unavailable helper dependencies without trying to execute its field callback',function()
    local f,a=fixture();local d=checkEditor(f,a);f.load('Diagnostics/errors.lua');d.model.value.bindings={helper='MISSING'};d.test:Click();local view=d.sourcePreview;view.check:Click()
    assert(not view.failed and view.lastResult and view.lastResult.status=='unavailable','missing helper fell through to a field rendering error')
    assert(view.lastResult.reason=='missing-function' and not a.checkedValid and not a.checkedEvaluate and #a.Diagnostics:GetReports()==0)
    view.close:Click();assert(d.frame:IsShown())
end)
test('one footer Test action is available from every callback and exposes its editor owner',function()
    local f,a=fixture();local d=checkEditor(f,a);assert(d.test and not d.preview,'condition-level Test action missing');assert(d.test:GetText()=='Test' and d.test.point[2]==d.viewChanges and d.test.point[1]=='RIGHT')
    for callback in pairs(a.CustomConditionCallbacks) do d:SelectFunction(callback);assert(d.test:IsShown() and d.test:GetParent()==d.viewChanges:GetParent());assert(d.code.context and d.code.context.testOwner==d,'editor context lacks its Test owner') end
end)
test('unified Test renders fields and help together and defaults do not configure debugger values',function()
    local f,a=fixture();local d=checkEditor(f,a);assert(a.ConditionTestValues and d.test,'unified Test bridge missing');d.model.value.help='frame:AddChild(addon.help_funcs.CreateText("Combined help"))';d:SelectFunction('on_register');d.test:Click();local view=d.sourcePreview
    assert(view.pane.children[1] and view.helpPane.children[1].children[1].text:find('Combined help',1,true));assert(not view.lastResult and not a.checkedValid and not a.checkedEvaluate,'opening Test evaluated defaults')
    local values,why=a:ConditionTestValues(d);assert(not values and why=='Set values in Test before running or debugging this condition.' and not d.conditionTestState.configured)
    view.sample.count=3;view.check:Click();assert(view.lastResult.status=='match' and d.conditionTestState.configured);view.close:Click();values=assert(a:ConditionTestValues(d));assert(values.count==3);values.count=900;assert(a:ConditionTestValues(d).count==3,'debugger received live sample storage')
    d.model.value.fields.extra='number';assert(not a:ConditionTestValues(d),'stale schema reused configured samples')
end)
test('committed unified Test inputs configure detached values without running validation',function()
    local f,a=fixture();local d=checkEditor(f,a);assert(d.test and a.ConditionTestValues);d.test:Click();local view=d.sourcePreview;local input=view.pane.children[1];input:Fire('OnEnterPressed','2')
    local values=assert(a:ConditionTestValues(d));assert(values.count==2 and not a.checkedValid and not a.checkedEvaluate and d.conditionTestState.profile==a.db.profile and d.conditionTestState.global==a.db.global)
    view.close:Click();a.db.profile={};assert(not a:ConditionTestValues(d),'replaced profile retained debugger samples')
end)
test('debug rendering surface stays beside the source and executes no condition callbacks',function()
    local f,a=fixture();local d=checkEditor(f,a);assert(a.CreateConditionDebugSurface,'debug surface bridge missing');local surface=a:CreateConditionDebugSurface(d,'widget')
    assert(surface.parent and surface.values and surface.valid() and d.frame:IsShown() and not a.checkedValid and not a.checkedEvaluate and not surface.helpPane)
    local input=a:CreateConditionEditBox();input:SetText('Debug output');surface:Guard(input);surface.parent:AddChild(input);assert(input.alive);local closed=0;surface.onClose=function() closed=closed+1;surface:Close() end;surface:Close();surface:Close();assert(closed==1 and not surface.onClose and not input.alive and d.frame:IsShown() and not surface.valid())
end)
test('choosing Test field values refreshes validation and evaluation without enabling Live',function()
    local f,a=fixture();local d=checkEditor(f,a);d.test:Click();local view=d.sourcePreview;local input=view.pane.children[1]
    input:Fire('OnEnterPressed','3');assert(not a.checkedEvaluate and view.pendingTest)
    view.frame.scripts.OnUpdate(view.frame,0);assert(view.lastResult and view.lastResult.status=='match' and a.checkedEvaluate==1 and not view.liveEnabled)
    view.frame.scripts.OnUpdate(view.frame,1);assert(a.checkedEvaluate==1,'field change accidentally enabled continuous evaluation')
end)
test('closing Test commits pending valid fields for later debugging without evaluating them',function()
    local f,a=fixture();local d=checkEditor(f,a);d.test:Click();local view=d.sourcePreview;local input=view.pane.children[1]
    input.editbox:SetText('3');input.editbox.scripts.OnTextChanged(input.editbox,true);view:Close()
    assert(assert(a:ConditionTestValues(d)).count==3 and not a.checkedEvaluate,'closing Test dropped a chosen field or evaluated while closing')
end)
test('configured debugger samples expire with the source editor while saved values remain available in Test',function()
    local f,a=fixture();local d,saved=checkEditor(f,a);d.test:Click();local view=d.sourcePreview;view.sample.count=3;view.check:Click();view:Close();assert(a:ConditionTestValues(d));d:Close()
    local reopened=a:condition_edit_box(function() end,'CHECK',saved);assert(reopened==d and not a:ConditionTestValues(reopened),'pooled editor revived a former debugger authorization')
    reopened.test:Click();assert(reopened.sourcePreview.sample.count==3 and not a:ConditionTestValues(reopened),'displaying saved sample values implicitly configured debugging');reopened.sourcePreview.check:Click();assert(a:ConditionTestValues(reopened).count==3)
end)
test('help interactions do not configure default Test fields or trigger evaluation',function()
    local f,a=fixture();local d=checkEditor(f,a);d:SelectFunction('help');code(d,'local button=addon:CreateConditionCheckBox();button:SetLabel("Help interaction");button:SetCallback("OnValueChanged",function() addon.helpClicked=true end);frame:AddChild(button)')
    d.test:Click();local view=d.sourcePreview;local button=view.helpPane.children[1];button:Fire('OnValueChanged',true)
    assert(a.helpClicked and not a:ConditionTestValues(d) and not view.pendingTest,'help interaction implicitly configured untouched default fields')
end)
test('packaged readonly conditions use the same Test fields help and results without changing source',function()
    local f,a=fixture();conditionEditor(f,a);previewContainers(f);f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Conditions/common.lua');f.load('Conditions/combat.lua')
    f.env.UnitExists=function() return true end;f.env.UnitAffectingCombat=function() return true end
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    local source=assert(a:GetBuiltinConditionSource('COMBAT'));local host=f.env.CreateFrame('Frame');host:SetSize(1000,700)
    local d=a:condition_edit_box(function() error('must not save') end,'COMBAT',source,nil,{readOnly=true,parent=host,width=900,height=650})
    d:SelectFunction('help');d.test:Click();local view=d.sourcePreview;assert(not view.failed and view.pane.children[1] and view.helpPane.children[1])
    local unit=view.pane.children[1];unit:Fire('OnValueChanged','player');view.frame.scripts.OnUpdate(view.frame,0)
    assert(view.lastResult and view.lastResult.status=='match' and d.conditionTestState.values.unit=='player');view:Close();assert(d.readOnly and not d:IsDirty() and a:SettingsDataEqual(d:PendingSource(),source) and not (a.db.global.custom_conditions or {}).COMBAT)
end)
test('pooled Test roots keep real Attackable and Allies fields visible and editable on reopening',function()
    for _,key in ipairs({'ATTACKABLE','PROXIMITY'}) do
        local f,a=fixture();local errors=pooledPreviewContainers(f);conditionEditor(f,a)
        f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Conditions/common.lua');f.load('Conditions/combat.lua');f.load('Conditions/spatial.lua')
        f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
        local src=assert(a:GetBuiltinConditionSource(key));local host=f.env.CreateFrame('Frame');host:SetSize(1000,700)
        local d=a:condition_edit_box(function() error('must not save') end,key,src,nil,{readOnly=true,parent=host,width=900,height=650})
        for pass=1,2 do
            d.test:Click();local view=d.sourcePreview;assert(not view.failed,view.status:GetText())
            assert(view.contentPane.frame:IsShown(),key..' pooled Test scroll root remained hidden')
            assert(view.pane.frame:IsShown() and view.pane.frame:GetHeight()>0 and #view.helpPane.children>0)
            local unit=assert(view.pane.children[1]);assert(unit.type=='RM-Selector' and unit.frame:IsShown() and unit.frame:GetHeight()==44)
            unit.button:Click();local menu=unit.selector;assert(menu.frame:IsShown())
            local wanted=key=='ATTACKABLE' and 'target' or 'player'
            for index,id in ipairs(unit.order) do if id==wanted then menu.rows[index]:Click();break end end
            assert(view.sample.unit==wanted and not menu.frame:IsShown(),'native unit selector did not update test values')
            assert(#errors==0,table.concat(errors,'\n'));view:Close()
        end
        for pass=1,2 do
            local surface=a:CreateConditionDebugSurface(d,'widget');assert(surface.contentPane.frame:IsShown(),'pooled callback output root remained hidden')
            assert(surface.chrome and surface.info:GetText():find('Rendered output',1,true));surface:Close()
        end
        assert(not d:IsDirty() and a:SettingsDataEqual(d:PendingSource(),src))
    end
end)
test('function names are valid local call names while legacy registry references stay stable',function()
    local f,a,host=fixture();assert(a.FunctionEditorName,'callable names missing')
    assert(a:FunctionEditorName('OLD',{name='Old helper'})=='Old_helper')
    assert(a:IsCustomFunctionIdentifier(a:FunctionEditorName('OLD',{name='123 end'})))
    a.db.global.custom_functions.STABLE=source('Old helper');a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction
    assert(d.form.fields.name:GetText()=='Old_helper' and not d:IsDirty())
    edit(d,'name','123new helper!');assert(d.form.fields.name:GetText()=='newhelper')
    d.apply:Click();assert(p.functionID=='STABLE' and a.db.global.custom_functions.STABLE.name=='newhelper' and a:ResolveFunctionBinding('STABLE')(4)==4)
    p.fields.duplicate_function:Click();assert(a:IsCustomFunctionIdentifier(p.inlineFunction.value.name) and p.inlineFunction.value.name~='newhelper')
end)
test('binding rows identify their source and use the same readonly controls without mutating source',function()
    local f,a,host=fixture()
    a:RegisterBuiltinFunction('builtin:first:AceGUI',source('AceGUI'),function() return {} end,true)
    a:RegisterBuiltinFunction('builtin:second:AceGUI',source('AceGUI'),function() return {} end,true)
    local src=source('readonlyHelper');src.code='    return value';src.bindings={gui='builtin:first:AceGUI'}
    a:RegisterBuiltinFunction('builtin:test',src,function() return function(v) return v end end)
    local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction;d.form.fields.function_bindings:Click()
    assert(d.form.fields.binding_alias_1 and d.form.fields.binding_target_1,'readonly bindings have a different layout')
    assert(not d.form.fields.binding_alias_1:IsEnabled() and not d.form.fields.binding_target_1:IsEnabled())
    assert(d.form.fields.binding_target_1:GetText():find('first',1,true),'source module missing')
    assert(d:PendingSource().code==src.code and not d:IsDirty(),'opening readonly bindings rewrote packaged source')
    a.db.global.custom_functions.CUSTOM=source('customHelper');a.db.global.custom_functions.CUSTOM.bindings={gui='builtin:first:AceGUI'};a:InitializeFunctionRegistry();p.functionID='CUSTOM';p:Draw();assert(p.inlineFunction.form.fields.binding_alias_1:IsEnabled(),'readonly alias lock leaked to custom source')
    local choices=a:FunctionBindingChoices();local labels={};for _,entry in ipairs(choices) do assert(not labels[entry.text],'ambiguous binding target');labels[entry.text]=true end
end)
test('readonly function source retains provider knowledge and requires an input lock',function()
    local f,a,host=fixture();local locked
    a:RegisterLuaEditorProvider('knowledge',function(parent)
        local c={frame=f.env.CreateFrame('Frame',nil,parent),text=''}
        function c:GetText() return self.text end;function c:SetText(value) self.text=value end
        function c:SetReadOnly(value) locked=value end;function c:Release() end;return c
    end)
    a.db.profile.lua_editor='knowledge';a:RegisterBuiltinFunction('builtin:test',source('helper'),function() return function(v) return v end end)
    local p=a:OpenNativeSettings(host,'Functions');assert(p.inlineFunction.code.provider=='knowledge' and locked,'readonly pane loses advanced knowledge')
    a:RegisterLuaEditorProvider('unlocked',function(parent)
        return {frame=f.env.CreateFrame('Frame',nil,parent),GetText=function() return '' end,SetText=function() end,Release=function() end}
    end)
    a.db.profile.lua_editor='unlocked';p:Draw();assert(p.inlineFunction.code.provider=='native' and p.inlineFunction.code.inner.readOnly,'provider without readonly support allowed source input')
end)
test('confirmed function deletion resolves pending edits and immediately refreshes registry and clean successor',function()
    local f,a,host=fixture();a.db.global.custom_functions.A=source('Alpha');a.db.global.custom_functions.B=source('Beta');a:InitializeFunctionRegistry();local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction
    code(d,'return )');d.form.fields.delete:Click();assert(p.prompt.discard:IsShown() and a.db.global.custom_functions.A);p.prompt.cancel:Click();assert(d.code:GetText()=='return )')
    d.form.fields.delete:Click();p.prompt.discard:Click();assert(p.prompt.text:GetText():find('cannot be undone',1,true));p.prompt.cancel:Click();assert(a.db.global.custom_functions.A and not p.inlineFunction:IsDirty())
    p.inlineFunction.form.fields.delete:Click();p.prompt.accept:Click();assert(not a.db.global.custom_functions.A and not a:FunctionAvailable('A') and p.functionID=='B' and not p.inlineFunction:IsDirty() and not p.inlineFunction.apply:IsEnabled())
end)
test('confirmed function deletion removes it immediately and selects a clean successor',function()
    local f,a,host=fixture();a.db.global.custom_functions.A=source('first');a.db.global.custom_functions.B=source('second');a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction;d.form.fields.delete:Click();assert(p.prompt.frame:IsShown() and a.db.global.custom_functions.A)
    p.prompt.cancel:Click();assert(a.db.global.custom_functions.A and not d:IsDirty())
    d.form.fields.delete:Click();p.prompt.accept:Click();d=p.inlineFunction
    assert(not a.db.global.custom_functions.A and p.functionID=='B' and not d:IsDirty() and not d.apply:IsEnabled() and not d.viewChanges:IsEnabled())
end)
test('function deletion allows discarding an invalid name before permanent confirmation',function()
    local f,a,host=fixture();a.db.global.custom_functions.A=source('first');a.db.global.custom_functions.B=source('second');a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction;local name=d.form.fields.name;name:SetText('');name.scripts.OnTextChanged(name,true);d.form.fields.delete:Click()
    assert(p.prompt.discard and p.prompt.discard:IsShown(),'invalid name blocked Discard');p.prompt.cancel:Click();assert(d.form.fields.name:GetText()=='' and a.db.global.custom_functions.A)
    d.form.fields.delete:Click();p.prompt.discard:Click();assert(p.prompt.frame:IsShown() and a.db.global.custom_functions.A);p.prompt.accept:Click();assert(not a.db.global.custom_functions.A and p.functionID=='B' and not p.inlineFunction:IsDirty())
end)
test('function pane shows exact callable paths and attaching completion keeps a stable exportable binding',function()
    local _,a,host=fixture();a.db.global.custom_functions.HELPER=source('doubleValue');a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction
    assert(a.FunctionInvocation and a:FunctionInvocation('HELPER',d.value)=='functions.doubleValue(value)','call form missing')
    a:RegisterBuiltinFunction('builtin:method',{name='MakeField',description='Field',args={{name='self',type='RMAddon'},{name='value',type='table'}},returns={},code='return value'},function() return function(_,v) return v end end)
    a.builtinFunctions['builtin:method'].callName='addon:MakeField';a.builtinFunctions['builtin:method'].public=true
    assert(a:FunctionInvocation('builtin:method',a.builtinFunctions['builtin:method'].source)=='builtin.MakeField(addon, value)')
    assert(a:FunctionInvocation('builtin:method',a.builtinFunctions['builtin:method'].source,true)=='addon:MakeField(value)')
    p.fields.new_function:Click();d=p.inlineFunction;assert(a.BindEditorFunction,'completion binding bridge missing')
    local insertion=assert(a:BindEditorFunction(d,'HELPER','doubleValue'));assert(d.value.bindings.doubleValue=='HELPER' and not a.db.global.custom_functions[p.newFunctionID])
    code(d,'return functions.doubleValue(4)');assert(insertion:commit());d:UpdateActions();assert(d.form.fields.function_bindings.rmUnsaved and d.code.context.bindFunction)
    d.apply:Click();assert(a:ResolveFunctionBinding(p.functionID)()==4)
    local bundle=assert(a:BuildFunctionBundle('function',p.functionID));assert(#bundle.dependencies==1 and bundle.dependencies[1].id=='HELPER')
end)
test('completion binding rejects readonly stale conflicting and self references without changing saved source',function()
    local _,a,host=fixture();a.db.global.custom_functions.A=source('alpha');a.db.global.custom_functions.B=source('beta');a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction;assert(a.BindEditorFunction)
    assert(not a:BindEditorFunction(d,'A','alpha'));d.readOnly=true;assert(not a:BindEditorFunction(d,'B','beta'));d.readOnly=false
    d.value.bindings.beta='A';assert(not a:BindEditorFunction(d,'B','beta'));p:Release();assert(not a:BindEditorFunction(d,'B','other'));assert(not next(a.db.global.custom_functions.A.bindings))
end)
test('condition completion binding refreshes symbols without losing pending callback code',function()
    local f,a=fixture();conditionEditor(f,a);a.db.global.custom_conditions={};a.db.global.custom_functions.HELPER=source('helper');a:InitializeFunctionRegistry()
    local value=a:CopySettingsData(a.empty_condition);value.description='Completion test';local d=a:condition_edit_box(function() end,'TEST',value)
    local insertion=assert(a:BindEditorFunction(d,'HELPER','helper'));code(d,'return functions.helper(value)');assert(insertion:commit())
    assert(d.code.context.source.bindings.helper=='HELPER' and d.code:GetText()=='return functions.helper(value)' and d.code.context.bindFunction,'completion context kept an unbound source')
    d:SelectFunction('print');assert(d.code.context.source.bindings.helper=='HELPER' and d:PendingSource().evaluate=='return functions.helper(value)')
end)
local function completion(f,a,d)
    f.env.GetLocale=function() return 'enUS' end;f.load('Libs/LuaWorkbench-Embed/modules.lua');f.load('Core/lua_symbols.lua')
    local create=f.env.CreateFrame;f.env.CreateFrame=function(...) local frame=create(...);frame.RegisterEvent=function() end;frame.UnregisterAllEvents=function() end;return frame end
    local engine={L={},UI={},Workspace={db={options={}}},Query={Console={SetStatus=function() end}}}
    for _,name in ipairs({'Localization','LuaEditor','Analysis','APIHelp','Autocomplete'}) do a.LuaWorkbenchModules[name]('rotationmaster',engine) end
    local input={editBox=d.code.edit,GetText=function() return d.code:GetText() end};engine.Query.Console.input=input
    function engine.Query.Editor:SetSource(_,text,cursor) code(d,text);d.code.edit:SetCursorPosition(cursor) end
    a:ApplyLuaContextSymbols(engine,{kind=d.model and 'condition' or 'function',id=d.model and d.model.key or d.key,callback=d.selected,source=d:PendingSource(),bindFunction=function(id,alias) return a:BindEditorFunction(d,id,alias) end},true)
    local complete=engine.Autocomplete;function complete:Update() end
    d.code.edit:SetCursorPosition(#d.code:GetText());complete.input=input;complete.context=assert(complete:Context(input:GetText(),d.code.edit:GetCursorPosition()));complete.items=complete:Suggest(complete.context,true)
    for index,item in ipairs(complete.items) do if item.name=='functions.helper' then complete.selected=index end end
    assert(complete.selected,'helper suggestion missing');complete.panel={IsShown=function() return true end,Hide=function() end}
    return complete,input
end
test('accepted function completion is one undoable code and dependency transaction',function()
    local f,a,host=fixture();a.db.global.custom_functions.HELPER=source('helper');a:InitializeFunctionRegistry();local p=a:OpenNativeSettings(host,'Functions');p.fields.new_function:Click();local d=p.inlineFunction
    code(d,'return functions.he');local complete,input=completion(f,a,d);assert(complete:Accept(input));assert(d.code:GetText()=='return functions.helper' and d.value.bindings['functions.helper']=='HELPER')
    code(d,'return functions.helper(3)');d.codeUndo:Click();assert(d.code:GetText()=='return functions.helper' and d.value.bindings['functions.helper']=='HELPER')
    d.codeUndo:Click();assert(d.code:GetText()=='return functions.he' and not (d.value.bindings or {})['functions.helper'],'Undo split binding from insertion')
    d.codeRedo:Click();assert(d.code:GetText()=='return functions.helper' and d.value.bindings['functions.helper']=='HELPER');d.codeRedo:Click();assert(d.code:GetText()=='return functions.helper(3)')
    d.apply:Click();assert(a:ResolveFunctionBinding(p.functionID)()==3);local bundle=assert(a:BuildFunctionBundle('function',p.functionID));assert(#bundle.dependencies==1 and bundle.dependencies[1].id=='HELPER')
end)
test('condition completion travels atomically through global and code history around model edits',function()
    local f,a=fixture();conditionEditor(f,a);a.db.global.custom_conditions={};a.db.global.custom_functions.HELPER=source('helper');a:InitializeFunctionRegistry()
    local value=a:CopySettingsData(a.empty_condition);value.description='Before';local d=a:condition_edit_box(function() end,'TEST',value)
    d.model:Change(function(model) model.value.description='Earlier metadata' end);code(d,'return functions.he')
    local complete,input=completion(f,a,d);assert(complete:Accept(input));d.model:Change(function(model) model.value.description='Later metadata' end)
    d.undo:Click();assert(d.model.value.description=='Earlier metadata' and d.code:GetText()=='return functions.helper' and d.model.value.bindings['functions.helper']=='HELPER')
    d.undo:Click();assert(d.code:GetText()=='return functions.he' and not (d.model.value.bindings or {})['functions.helper'],'global Undo left an unbound function call')
    d.undo:Click();assert(d.model.value.description=='Before');d.redo:Click();assert(d.model.value.description=='Earlier metadata');d.redo:Click();assert(d.code:GetText()=='return functions.helper' and d.model.value.bindings['functions.helper']=='HELPER')
    code(d,'return functions.helper(value)');d:TravelCode(false);assert(d.code:GetText()=='return functions.helper' and d.model.value.bindings['functions.helper']=='HELPER')
    d:TravelCode(false);assert(d.code:GetText()=='return functions.he' and not (d.model.value.bindings or {})['functions.helper']);d:TravelCode(true);assert(d.code:GetText()=='return functions.helper' and d.model.value.bindings['functions.helper']=='HELPER')
end)
test('declined or failing insertion rolls back its staged binding and partial text without history',function()
    for _,throws in ipairs({false,true}) do
        local f,a,host=fixture();a.db.global.custom_functions.HELPER=source('helper');a:InitializeFunctionRegistry();local p=a:OpenNativeSettings(host,'Functions');p.fields.new_function:Click();local d=p.inlineFunction;code(d,'return functions.he')
        local complete,input=completion(f,a,d);local count=#d.undo
        complete.rmAccept=function() if throws then code(d,'partial');error('insertion failed') end;return false end
        local ok,accepted=pcall(complete.Accept,complete,input);assert(throws and not ok or not throws and ok and not accepted)
        assert(d.code:GetText()=='return functions.he' and not (d.value.bindings or {})['functions.helper'] and not d.pendingFunctionBinding and #d.undo==count,'failed insertion retained a dependency, partial code or history')
    end
end)
test('accepting an already typed full name records only the new dependency and Undo restores it',function()
    local f,a,host=fixture();a.db.global.custom_functions.HELPER=source('helper');a:InitializeFunctionRegistry();local p=a:OpenNativeSettings(host,'Functions');p.fields.new_function:Click();local d=p.inlineFunction;code(d,'return functions.helper')
    local transaction=assert(a:BindEditorFunction(d,'HELPER','functions.helper'));assert(transaction:commit() and d.value.bindings['functions.helper']=='HELPER');d.codeUndo:Click();assert(d.code:GetText()=='return functions.helper' and not (d.value.bindings or {})['functions.helper'])
    d.codeRedo:Click();assert(d.code:GetText()=='return functions.helper' and d.value.bindings['functions.helper']=='HELPER')
end)
test('function namespaces derive the roster filter and custom metadata stays staged',function()
    local _,a,host=fixture();assert(a.FunctionNamespace,'namespace metadata missing')
    a.db.global.custom_functions.A=source('same');a.db.global.custom_functions.A.namespace='alpha'
    a.db.global.custom_functions.B=source('same');a.db.global.custom_functions.B.namespace='beta';a:InitializeFunctionRegistry()
    local built=source('cached');built.namespace='utils';a:RegisterBuiltinFunction('builtin:utils.lua:cached',built,function() return function(v) return v end end)
    local p=a:OpenNativeSettings(host,'Functions');assert(p.roster.options.categories and #p.roster.options.categories==4,'namespace filter is not derived from existing helpers')
    p.roster.options.chooseCategory('beta');assert(#p.roster.entries==1 and p.functionID=='B' and p.inlineFunction.value.namespace=='beta')
    local d=p.inlineFunction;edit(d,'namespace','myTools');assert(a.db.global.custom_functions.B.namespace=='beta' and d:IsDirty())
    d.apply:Click();assert(a.db.global.custom_functions.B.namespace=='myTools' and p.functionID=='B' and not p.inlineFunction:IsDirty(),'moving namespace lost the selected function')
    assert(a:FunctionInvocation('B',a.db.global.custom_functions.B)=='myTools.same(value)')
end)
test('symbol navigation selects a helper outside the current namespace filter',function()
    local _,a,host=fixture();a.db.global.custom_functions.A=source('alpha');a.db.global.custom_functions.A.namespace='first'
    a.db.global.custom_functions.B=source('beta');a.db.global.custom_functions.B.namespace='second';a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');p.roster.options.chooseCategory('second');assert(p.functionID=='B')
    a.configWindow={pane=p};a.ShowConfig=function(_,section) assert(section=='Functions');p:Draw() end
    a:ShowFunctionSource('A');assert(p.functionID=='A' and p.inlineFunction.key=='A','namespace filtering replaced the requested symbol with another function')
end)
finish()
