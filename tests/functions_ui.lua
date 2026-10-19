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
test('Functions opens packaged helpers readonly and duplicates a typed source without saving',function()
    local f,a,host=fixture();assert(a.BuildFunctionSettings,'Functions page missing')
    a:RegisterBuiltinFunction('builtin:test',source('Packaged helper'),function() return function(v) return v end end)
    a:RegisterBuiltinFunction('builtin:value',source('Internal constant'),function() return {} end,true)
    local p=a:OpenNativeSettings(host,'Functions');assert(#p.roster.entries==1 and p.inlineFunction.readOnly and p.inlineFunction.code.readOnly)
    assert(not p.inlineFunction.form.fields.name:IsEnabled() and p.inlineFunction.signature:GetText():find('value',1,true))
    p.fields.duplicate_function:Click();local d=p.inlineFunction;assert(not d.readOnly and d:IsDirty() and not next(a.db.global.custom_functions));assert(d:PendingSource().args[1].type=='number')
    edit(d,'name','My helper');d.apply:Click();assert(a.db.global.custom_functions[p.functionID].name=='My helper' and a:ResolveFunctionBinding(p.functionID)(8)==8)
end)
test('typed metadata and code stage until Apply, history resets and syntax checks execute no helper',function()
    local f,a,host=fixture();local original=source('Original');a.db.global.custom_functions.CUSTOM=original;a:InitializeFunctionRegistry()
    local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction;edit(d,'arg_1_type','number|nil');code(d,'error("must not run")');d.syntax:Click();assert(a.db.global.custom_functions.CUSTOM==original and d.form.message:GetText():find('No custom code',1,true))
    d.codeUndo:Click();assert(d.code:GetText()=='return value');d.codeRedo:Click();assert(d.code:GetText():find('must not run',1,true));d.codeReset:Click();assert(d.code:GetText()=='return value');d.codeUndo:Click();assert(d.code:GetText():find('must not run',1,true))
    code(d,'return value + 1');d.apply:Click();assert(a.db.global.custom_functions.CUSTOM.args[1].type=='number|nil' and a:ResolveFunctionBinding('CUSTOM')(4)==5)
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
    local p=a:OpenNativeSettings(host,'Functions');local d=p.inlineFunction;assert(not d.form.fields.binding_alias_1);d.form.fields.function_bindings:Click();edit(d,'binding_alias_1','renamed');assert(d:PendingSource().bindings.renamed=='HELPER' and not d:PendingSource().bindings.helper and d.code:GetText()=='return helper(value)')
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
    local child=view.pane.children[1];local stale=child.callbacks.OnEnterPressed;view.close:Click();assert(d.frame:IsShown() and not child.alive);stale(child,'OnEnterPressed','41');assert(not a.previewEdits and a.db.global.custom_conditions.PREVIEW==value)
end)
test('Help Preview uses the help renderer and owner closure releases its child output',function()
    local f,a=fixture();conditionEditor(f,a);previewContainers(f);a.db.global.custom_conditions={};local d=a:condition_edit_box(function() end);d:SelectFunction('help');assert(d.test and d.test:IsShown(),'condition Test action missing')
    code(d,'frame:AddChild(addon.help_funcs.CreateText("Live help preview"))');d.test:Click();local view=d.sourcePreview;assert(view.helpPane.children[1].children[1].text:find('Live help preview',1,true));local pane=view.pane;d:Close();assert(not view.frame:IsShown() and pane.isQueuedForRelease)
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
    local input=view.pane.children[1];input.callbacks.OnEnterPressed(input,'OnEnterPressed','3');view.check:Click();assert(view.lastResult.valid and view.lastResult.status=='match' and a.checkedEvaluate==1 and view.sample.count==3)
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
    local f,a=fixture();local d=checkEditor(f,a);assert(d.test:GetText()=='Test');a.db.global.condition_test_values={CHECK={count=3}};d.test:Click();local view=d.sourcePreview;local old=view.pane.children[1];local stale=old.callbacks.OnEnterPressed
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
    local values,why=a:ConditionTestValues(d);assert(not values and why=='Set test values in Test before debugging Evaluate.' and not d.conditionTestState.configured)
    view.sample.count=3;view.check:Click();assert(view.lastResult.status=='match' and d.conditionTestState.configured);view.close:Click();values=assert(a:ConditionTestValues(d));assert(values.count==3);values.count=900;assert(a:ConditionTestValues(d).count==3,'debugger received live sample storage')
    d.model.value.fields.extra='number';assert(not a:ConditionTestValues(d),'stale schema reused configured samples')
end)
test('committed unified Test inputs configure detached values without running validation',function()
    local f,a=fixture();local d=checkEditor(f,a);assert(d.test and a.ConditionTestValues);d.test:Click();local view=d.sourcePreview;local input=view.pane.children[1];input.callbacks.OnEnterPressed(input,'OnEnterPressed','2')
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
    input.callbacks.OnEnterPressed(input,'OnEnterPressed','3');assert(not a.checkedEvaluate and view.pendingTest)
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
    d.test:Click();local view=d.sourcePreview;local button=view.helpPane.children[1];button.callbacks.OnValueChanged(button,'OnValueChanged',true)
    assert(a.helpClicked and not a:ConditionTestValues(d) and not view.pendingTest,'help interaction implicitly configured untouched default fields')
end)
test('packaged readonly conditions use the same Test fields help and results without changing source',function()
    local f,a=fixture();conditionEditor(f,a);previewContainers(f);f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Conditions/common.lua');f.load('Conditions/combat.lua')
    f.env.UnitExists=function() return true end;f.env.UnitAffectingCombat=function() return true end
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    local source=assert(a:GetBuiltinConditionSource('COMBAT'));local host=f.env.CreateFrame('Frame');host:SetSize(1000,700)
    local d=a:condition_edit_box(function() error('must not save') end,'COMBAT',source,nil,{readOnly=true,parent=host,width=900,height=650})
    d:SelectFunction('help');d.test:Click();local view=d.sourcePreview;assert(not view.failed and view.pane.children[1] and view.helpPane.children[1])
    local unit=view.pane.children[1];unit.callbacks.OnValueChanged(unit,'OnValueChanged','player');view.frame.scripts.OnUpdate(view.frame,0)
    assert(view.lastResult and view.lastResult.status=='match' and d.conditionTestState.values.unit=='player');view:Close();assert(d.readOnly and not d:IsDirty() and a:SettingsDataEqual(d:PendingSource(),source) and not (a.db.global.custom_conditions or {}).COMBAT)
end)
finish()
