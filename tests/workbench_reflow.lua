-- Live reflow under client-faithful sizing. In the client a frame's rect
-- resolves on the next layout pass, so code that reads a size it has just
-- assigned (or a size set by anchors) gets the previous one and nothing
-- reflows. tests/fixtures/deferred_layout.lua makes the mock behave that way;
-- every scenario here resizes, lets the "client" run frames, then proves
-- the contents follow the pane and stay inside it.
local F=dofile('tests/fixtures/addon.lua')
local make=dofile('tests/fixtures/rotation_data.lua')
local audit=dofile('tests/fixtures/layout_audit.lua')
local test,finish=F.suite()
local function browserFixture(product,expansion,realCustom)
    local f=F.new(product,expansion);local a=f.addon;f.env.NEW='New'
    local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env);local layout=dofile('tests/fixtures/deferred_layout.lua')(f.env,create);create=layout.create;f.layout=layout
    local data,envelope,validation=make();a.RotationData=data;a.conditionDefinitions=validation.conditions
    f.load('Data/catalog.lua');f.load('Data/diff.lua');f.load('Core/rotation_library.lua');local tags=io.open('Core/rotation_tags.lua');if tags then tags:close();f.load('Core/rotation_tags.lua') end
    a.GetRotationContext=function(_,spec) return {family='tbc',class='SHAMAN',level=11,spec=spec,actionContext='player',combatDataPolicy='probe'} end
    local counter=0;a.uuid=function() counter=counter+1;return 'new-'..counter end
    local pack=envelope();pack.nameKey='Twin';pack.descriptionKey='Contains % [ brackets';pack.applicability.maxLevel=19
    assert(a:RegisterDefaultRotation(pack))
    local other=envelope();other.id='other-pack';other.nameKey='Other default';other.applicability.class='MAGE'
    assert(a:RegisterDefaultRotation(other))
    a.db.profile.rotations={[0]={one={name='Twin',rotation={}},two={name='Twin',rotation={}}},[1]={third={name='Secondary custom',rotation={}}}}
    a.db.profile.enable=false;a.db.char={specs={[1]='Primary',[2]='Secondary'}};a.db.profile.itemsets={};a.db.global.effects={}
    assert(a:InitializeRotationLibrary());assert(a:SetDefaultRotationEnabled(other.id,false))
    a.Platform.GetSpellInfo=function(_,id) return {spellID=id,name='Lightning Bolt'} end
    a.Platform.GetSpellLink=function() return '|Hspell:403|h[Lightning Bolt]|h' end
    a.printCondition=function() return 'Readable condition' end
    f.load('UI/defaults.lua');f.load('UI/rotation_reference.lua');f.load('UI/settings_setup.lua')
    local nativeEditor
    if realCustom then
        a.validateCondition=function() return true end
        a.GetImportValidationOptions=function() return {conditions=a.conditionDefinitions} end
        a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() end;a.EvaluateNextAction=function() end
        for _,path in ipairs({'Platform/spells.lua','Data/rotation_draft.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','Core/rotation_canvas.lua','UI/window.lua','UI/rotation_cards.lua','UI/rotation_canvas.lua','UI/color_picker.lua','UI/rotation_effect_fields.lua','UI/rotation_fields.lua','UI/rotation_navigation.lua','UI/rotation_metadata.lua','UI/rotation_view.lua','UI/rotation_editor.lua'}) do f.load(path) end
        nativeEditor=a.CreateRotationEditor
    end
    local editors={}
    -- Native pane fixture isolates the roster; the name/apply case below uses
    -- the actual native editor and the reference case uses native reference controls.
    a.CreateRotationEditor=function(self,parent,spec,id,onSelect)
        if nativeEditor then
            local pane,why=nativeEditor(self,parent,spec,id,onSelect)
            if pane then editors[#editors+1]={pane=pane,spec=spec,id=id,select=onSelect} end
            return pane,why
        end
        local pane=self:CreateConditionGroup();pane.frame:SetParent(parent);pane:SetWidth(parent:GetWidth());pane:SetHeight(parent:GetHeight())
        pane.workspace={pending=false};pane.clone={action=function()
            local builtin=self:GetDefaultIdForRuntime(spec,id);local source=self:GetEditableRotation(spec,id)
            local title=source and source.name or id;local name='Copy of '..title
            local generated=builtin and self:CloneDefaultRotation(spec,builtin,name) or self:DuplicateCustomRotation(spec,id,name)
            if generated then onSelect(spec,generated) end
        end}
        local release=pane.Release
        function pane:Release() self.released=true;self.Release=nil;return release(self) end
        editors[#editors+1]={pane=pane,spec=spec,id=id,select=onSelect}
        local builtin=self:GetDefaultIdForRuntime(spec,id)
        if builtin then self:CreateDefaultRotationOptions(pane,spec,builtin,function(generated) onSelect(spec,generated) end)
        else local label=self:CreateConditionLabel();label:SetText('custom editor');pane:AddChild(label) end
        return pane
    end
    dofile('tests/fixtures/rotation_header_backend.lua')(a,f.env.DEFAULT,f.env.NEW)
    f.load('UI/rotation_browser.lua')
    return f,pack,editors,create,frames
end
local function conditionFixture()
    local f=F.new();local a=f.addon
    local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.frames=frames;f.layout=dofile('tests/fixtures/deferred_layout.lua')(f.env,create)
    local widgets={}
    a:ObserveConditionWidgets(function(widget) widgets[#widgets+1]=widget end)
    for _,file in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/condition_draft.lua','Data/validation.lua','Data/diff.lua','Core/conditions.lua','Core/condition_catalog.lua','Core/condition_editor.lua','Core/condition_canvas.lua','UI/window.lua','UI/help.lua','UI/condition_picker.lua','UI/condition_cards.lua','UI/condition_canvas.lua','UI/condition_editor.lua','UI/condition_entrypoints.lua'}) do f.load(file) end
    local h=io.open('UI/condition_text.lua');if h then h:close();f.load('UI/condition_text.lua') end
    a:RegisterCondition('NUMBER',{description='Number check',fields={number='number'},requiredFields={'number'},
        valid=function(_,value) return type(value.number)=='number' end,
        evaluate=function() error('editor must not evaluate combat') end,
        print=function() error('compact tree must not execute a printer') end,
        widget=function(parent,_,value)
            local slider=a:CreateConditionSlider();slider:SetLabel('Number');slider:SetValue(value.number)
            slider:SetCallback('OnValueChanged',function(_,_,amount)
                value.number=amount
                local top=parent:GetUserData('top')
                top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'),0))
            end)
            parent:AddChild(slider)
        end,help=function(parent) local label=a:CreateConditionLabel();label:SetText('Number help');parent:AddChild(label) end})
    a.listConditions=function() return {'AND','OR','NOT','DELETE','NUMBER'} end
    function a:GetImportValidationOptions() return {conditions=self.conditionDefinitions} end
    a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() end;a.configPaneGeneration=1
    if arg and arg[1] then f.load(arg[1]) end
    dofile('tests/fixtures/workbench_help_contract.lua')(a,f.env)
    return f,widgets
end
local function authoringFixture(inline,workbench)
    local f=workbench and dofile('tests/fixtures/lua_workbench.lua')() or F.new();local a=f.addon;if not workbench then local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.frames=frames;f.layout=dofile('tests/fixtures/deferred_layout.lua')(f.env,create);local make=f.env.CreateFrame;f.env.CreateFrame=function(kind,...) local frame=make(kind,...);if kind=='EditBox' then local set=frame.SetText;frame.SetText=function(self,text) if self.maxLetters and self.maxLetters>0 then text=text:sub(1,self.maxLetters) end;set(self,text) end end;return frame end end;if pcall(require,'bit') then local data,deps=dofile('tests/fixtures/codec.lua')();a.RotationData=data;a.NewRotationCodec=function() return data.NewCodec(deps) end else a.RotationData=make() end;a.pretty_name='Rotation Master';a.name='rotationmaster';a.db.char={};a.db.global.custom_conditions={}
    for _,path in ipairs({'Core/custom_condition_owner.lua','UI/settings_draft.lua','Core/custom_authoring.lua','Core/schema_authoring.lua','Core/schema_canvas.lua','UI/schema_cards.lua','UI/schema_editor.lua','UI/custom_source_fields.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_roster_order.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/custom_condition_transfer.lua','UI/icon_picker.lua','UI/help.lua','Core/custom_condition_services.lua','UI/lua_input_probe.lua','UI/lua_input_diagnostics.lua','UI/lua_editor.lua','UI/custom_condition_editor.lua'}) do local h=io.open(path);if h then h:close();f.load(path) end end
    a.conditionDefinitions=a.definitions;a.RegisterCondition=function(self,key,value) self.conditionDefinitions[key]=value;if value.on_register then value.on_register(key) end end
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    if inline then f.load('UI/settings_collections.lua');f.load('UI/settings_conditions.lua');f.load('UI/condition_source_pane.lua');a.listConditions=function(_,_,_,store) local tags={};for key in pairs((store or a.db).global.custom_conditions) do tags[#tags+1]=key end;table.sort(tags);return tags end end
    return f,a
end
local function integrationFixture(options)
 options=options or{};local f=F.new();local a=f.addon;local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.frames=frames;f.layout=dofile('tests/fixtures/deferred_layout.lua')(f.env,create);create=f.layout.create
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
 local loaded={LuaWorkbench=options.workbench~=false,Questie=options.questie~=false,Masque=options.masque~=false,ExtendedCharacterStats=true,MobInfo2=false,WeakAuras=true,Dominos=true}
 local calls={sync=0,refresh=0,created=0,preview=0};a.db.profile.lua_editor=options.selected or'auto'
 a.LuaSyntax={enable=function()end,disable=function()end,decode=function(s)return s end}
 a.ListIntegrationStatus=function()
  local rows={};for _,row in ipairs({{'!!!LuaWorkbench','LuaWorkbench','Lua editor integration.'},{'WowLua','WowLua','Optional editor addon.'},{'ExtendedCharacterStats','ExtendedCharacterStats','Optional character statistics conditions.'},{'MobInfo2','MobInfo2','Recorded creature history conditions.'},{'WeakAuras','WeakAuras','Recommendation event bridge.'},{'Questie','Questie','Quest update receipts only.'},{'Masque','Masque','Optional preview-button skins.'},{'Dominos','Dominos','Optional action-bar glow support.'}})do
   rows[#rows+1]={id=row[1],name=row[2],version=loaded[row[2]]and'1.2.3'or nil,state=loaded[row[2]]and'loaded'or'missing',detail=row[3]}
  end;return rows
 end
 a.DiscoverLuaEditorIntegrations=function()end
 a.IsLuaWorkbenchIntegrationAvailable=function()return loaded.LuaWorkbench end
 a.SyncQuestieIntegration=function()calls.sync=calls.sync+1 end;a.RefreshQuestieIntegration=function()calls.refresh=calls.refresh+1 end
 a.GetQuestieIntegrationStatus=function()return{state='disabled'}end
 a.RefreshPreviewWindow=function()calls.preview=calls.preview+1 end
 local function register(id)
  a:RegisterLuaEditorProvider(id,function(host,changed,valid)
   calls.created=calls.created+1;if not loaded[id]then return nil end
   return a:CreateWorkbenchLuaEditor(host,changed,valid,'plain')
  end);loaded[id]=loaded[id]~=false
 end
 register('LuaWorkbench')
 local parent=a:TrackWorkbenchSize(create('Frame'));parent:SetSize(options.width or 1000,600)
 local p=a:OpenNativeSettings(parent,'Integrations')
 return f,a,p,loaded,calls,register,parent
end
local function pointer(f)
    local state={x=0,down=true}
    f.env.GetCursorPosition=function() return state.x,0 end
    f.env.IsMouseButtonDown=function() return state.down end
    return state
end
local function drag(layout,splitter,state,delta)
    state.down=true;state.x=0;splitter.scripts.OnMouseDown(splitter,'LeftButton')
    state.x=delta;splitter.scripts.OnUpdate(splitter,.01);layout.step()
    state.down=false;layout.settle()
    assert(not splitter.drag,'divider drag did not end on release')
end
local function settingsShell(key,setup)
    local f=F.new();local a=f.addon;local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local layout=dofile('tests/fixtures/deferred_layout.lua')(f.env,create)
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.configPaneGeneration=1;a.RotationData=make()
    for _,path in ipairs({'Platform/spells.lua','Data/catalog.lua','Data/rotation_store.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Core/rotation_migration.lua','Help/general.lua','Help/conditions.lua','Help/effects.lua','Help/itemsets.lua','Help/announce.lua','UI/window.lua','UI/help.lua','UI/icon_picker.lua','UI/color_picker.lua','UI/settings_roster_order.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/cpu_profile.lua','UI/settings_general.lua','UI/settings_profiles.lua','UI/collection_compare.lua','UI/settings_collections.lua','UI/settings_announces.lua','UI/settings_effects.lua','UI/settings_items.lua','UI/settings_conditions.lua'}) do local h=io.open(path);if h then h:close();f.load(path) end end
    f.load('UI/config.lua')
    a.SetupOptions=function() end;a.RemoveAllCurrentGlows=function() end;a.HideGlow=function() end;a.Glow=function() end
    a.listConditions=function() return {} end
    a.db.GetCurrentProfile=function() return 'One' end;a.db.GetProfiles=function() return {'One','Two'} end
    a.db.profile.announces={{type='spell',spell=403,ranked=true,event='SUCCEEDED',announce='local',value='Cast'}}
    a.db.global.effects={pulse={name='Pulse',type='pulse',frequency=.25,sequence={1,.5}},dazzle={name='Dazzle',type='dazzle',sequence={{r=1,g=1,b=1,a=1}}}};a.db.profile.effect='pulse'
    a.db.global.itemsets={potions={name='Potions',items={1,2}}}
    if setup then setup(a) end
    local shell=a:ShowConfig(key);layout.settle()
    local p=shell.pane;if p.roster and p.roster.rows[1] and p.roster.rows[1]:IsShown() then p.roster.rows[1]:Click();layout.settle() end
    return f,a,shell,layout,frames
end

test('tracked frames answer with the size just assigned and note the size the client reports',function()
    local f=F.new();local a=f.addon;local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local layout=dofile('tests/fixtures/deferred_layout.lua')(f.env,create)
    local plain=layout.create('Frame');plain:SetSize(300,200);layout.step();plain:SetWidth(500);assert(plain:GetWidth()==300,'fixture does not defer like the client')
    local frame=a:TrackWorkbenchSize(layout.create('Frame'));frame:SetSize(300,200);frame:SetWidth(500)
    assert(frame:GetWidth()==500 and frame:GetHeight()==200,'tracked frame returned a stale size')
    local seen;a:SetUIScript(frame,'OnSizeChanged',function(self) seen=self:GetWidth() end);layout.settle()
    layout.userResize(frame,640,200);layout.step();assert(seen==640 and frame:GetWidth()==640,'client sizing was not visible to the handler')
end)

for _,key in ipairs({'General','Effects','ItemSets','Announces','Profiles','Conditions'}) do
    test(key..' reflows live when the window is resized and when the divider moves',function()
        local f,a,shell,layout,frames=settingsShell(key);local state=pointer(f)
        for _,size in ipairs({{1600,820},{800,500},{1120,760}}) do
            layout.userResize(shell.frame,size[1],size[2]);layout.settle()
            local content=size[1]-24;local p=shell.pane
            assert(shell.content:GetWidth()==content and p.frame:GetWidth()==content,key..' pane did not follow the window to '..size[1])
            if p.roster then assert(p.width==p.scroll:GetWidth() and p.scroll.point[2]+p.scroll:GetWidth()+math.max(18,shell.content.rmHelpReserve)==content,key..' detail did not follow the window')
            elseif p.columnMode or p.fullWidth then assert(p.fullWidth==math.max(340,content-40),key..' columns did not follow the window')
            else assert(p.width==math.max(340,content-40),key..' form did not follow the window') end
            audit.assertContained(shell.frame,frames,key..' at '..size[1],{captions=true})
            -- The page "?" shares the first row: content starts right under the tabs
            -- and nothing drawn on that row reaches under the "?".
            local help=shell.pageHelp;local box=audit.resolver(shell.frame)(help)
            assert(shell.paneHeaderHeight==0 and box.top==audit.resolver(shell.frame)(shell.content).top,key..' page Help takes its own row')
            audit.assertCornerFree(shell.frame,frames,box,key..' first row runs under the page Help at '..size[1],function(frame) return frame==help or frame.parent==help end)
        end
        local p=shell.pane
        if p.roster then
            local before=p.width;drag(layout,p.roster.splitter,state,120)
            assert(p.width==before-120 and p.width==p.scroll:GetWidth(),key..' detail did not follow the divider')
            audit.assertContained(shell.frame,frames,key..' after the divider',{captions=true})
        end
    end)
end

local function browserScene(f,width)
    local a=f.addon;local layout=f.layout
    a.db.profile.rotations[0].one.rotation={{id='s1',type='spell',action=403,ranked=true,conditions={}},{id='s2',type='item',action={1,2},conditions={}},
        {id='b1',type='branch',conditions={},onTrue={{id='s3',type='spell',action=403,conditions={}}},onFalse={}}}
    a.db.profile.rotations[0].one.cooldowns={{id='c1',type='spell',action=403,conditions={}},{id='c2',type='spell',action=403,conditions={}}}
    local host=a:TrackWorkbenchSize(layout.create('Frame'));host.rmHelpReserve=a.WorkbenchLayout.helpReserve;host:SetSize(width,640);layout.settle()
    local browser=a:CreateRotationBrowser(host,{spec=0,id='one'});layout.settle()
    for _,id in ipairs({'s1','s2','b1','s3','c1','c2'}) do browser.pane.view.cardStates[id]='expanded' end
    browser.pane:Render();layout.settle();return browser
end
local function assertEditor(browser,frames,message)
    local pane=browser.pane;local cards={};for _,card in ipairs(pane.canvas.cards) do cards[card.frame]=true end
    assert(pane.frame:GetWidth()==browser.detail:GetWidth() and pane.canvas.frame:GetWidth()==pane.frame:GetWidth()-40,message..': editor did not follow its pane')
    assert(pane.view.viewportWidth==pane.canvas.frame:GetWidth(),message..': cards were laid out for a stale viewport')
    audit.assertContained(browser.frame,frames,message,{captions=true,container=function(frame) return cards[frame] end,horizontalScroll={[pane.canvas.frame]=true}})
    local w=browser.frame:GetWidth();audit.assertCornerFree(browser.frame,frames,{left=w-20,right=w,top=0,bottom=-20},message..': editor runs under the page Help corner')
end

test('the rotation editor reflows live and list or grid cards fill the canvas',function()
    local f,_,_,_,frames=browserFixture(nil,nil,true);f.load('UI/help.lua');local layout=f.layout;local state=pointer(f)
    local browser=browserScene(f,1000);local pane=browser.pane
    assertEditor(browser,frames,'open')
    for _,width in ipairs({1600,776,1200}) do browser:SetWidth(width);layout.settle();assertEditor(browser,frames,'width '..width) end
    drag(layout,browser.splitter,state,150);assertEditor(browser,frames,'divider')
    -- Diagram cards keep their design width; the list fills the viewport.
    for _,card in ipairs(pane.canvas.cards) do assert(card.frame:GetWidth()==340,'diagram card changed width') end
    pane.view.layout='list';pane:Render();layout.settle()
    local right=pane.canvas.frame:GetWidth()-4
    for _,card in ipairs(pane.canvas.cards) do
        local model=card.model;local nested=model.x>0
        assert(model.x+model.width==right-(nested and 8 or 0),'list card does not reach the viewport edge')
        assert(card.fields:GetWidth()==model.width-56,'card fields do not follow the card')
    end
    browser:SetWidth(776);layout.settle();assertEditor(browser,frames,'narrow list')
    right=pane.canvas.frame:GetWidth()-4;assert(pane.canvas.cards[1].model.x+pane.canvas.cards[1].model.width==right,'list card did not narrow with the pane')
    pane.contentTabs.cooldowns:Click();layout.settle();browser:SetWidth(1400);layout.settle();assertEditor(browser,frames,'cooldown grid')
    local first,second=pane.canvas.cards[1].model,pane.canvas.cards[2].model
    assert(first.width>340 and first.width==second.width and second.x==first.width+24,'cooldown grid does not share the row')
end)

test('inline function and condition editors follow window and divider changes without losing unsaved code',function()
    for _,which in ipairs({'Functions','Conditions'}) do
        local f,a
        if which=='Functions' then
            f=F.new();a=f.addon;local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.frames=frames;f.layout=dofile('tests/fixtures/deferred_layout.lua')(f.env,create)
            a.db.char={};a.db.global.custom_functions={};a.RotationData=make()
            for _,path in ipairs({'Core/function_data.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_roster_order.lua','UI/settings_form.lua','UI/settings_collections.lua','UI/settings_transfer.lua','UI/lua_input_probe.lua','UI/lua_input_diagnostics.lua','UI/lua_editor.lua','UI/settings_functions.lua','UI/function_bindings.lua','UI/function_source_pane.lua','UI/function_bundle_transfer.lua'}) do local file=io.open(path);if file then file:close();f.load(path) end end
            a.db.global.custom_functions.A={name='LongFunctionName',description='Documentation',args={{name='value',type='number',description='Input value'}},returns={{type='number',description='Result'}},code='return value'}
        else
            f,a=authoringFixture(true)
            local source=a:CopySettingsData(a.empty_condition);source.description='Inline';source.fields={spell='number',unit='string'};a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields=source.fields}
        end
        local layout=f.layout;local state=pointer(f)
        local host=a:TrackWorkbenchSize(layout.create('Frame'));host.rmHelpReserve=a.WorkbenchLayout.helpReserve;host:SetSize(1000,600);layout.settle()
        local p=a:OpenNativeSettings(host,which);layout.settle()
        local function editor() return which=='Functions' and p.inlineFunction or p.inlineCondition end
        local d=editor();d.code.edit:SetText('return 7');d.code.edit.scripts.OnTextChanged(d.code.edit,true)
        local function check(message)
            d=editor();local side=p.roster.frame:GetWidth()
            assert(d.frame.point[2]==side+18 and d.frame:GetWidth()==host:GetWidth()-side-18-host.rmHelpReserve,which..' editor did not follow: '..message)
            assert(d.code.frame:GetWidth()>=d.frame:GetWidth()-40 and d.code:GetText()=='return 7',which..' code editor lost width or text: '..message)
            audit.assertContained(host,f.frames,which..' '..message,{captions=true})
            local w=host:GetWidth();audit.assertCornerFree(host,f.frames,{left=w-20,right=w,top=0,bottom=-20},which..' runs under the page Help corner: '..message)
        end
        check('open')
        for _,width in ipairs({1600,776,1200}) do host:SetSize(width,600);p:SetWidth(width);layout.settle();check('width '..width) end
        drag(layout,p.roster.splitter,state,150);check('divider')
    end
end)

test('the condition editor window reflows when the client resizes it',function()
    local f=conditionFixture();local a=f.addon;local layout=f.layout
    local root={type='AND',value={{type='NUMBER',number=3},{type='OR',value={{type='NUMBER',number=1},{type='NOT',value={type='NUMBER',number=2}}}}}}
    local shell=a:ShowConditionEditor(1,0,root,function() end,function() return true end,{persistentOwner=true});layout.settle()
    for _,width in ipairs({660,1400,900}) do
        layout.userResize(shell.frame,width,560);layout.settle()
        assert(shell.canvas.frame:GetWidth()==width-52 and shell.view.width==width-60,'condition canvas did not follow the window')
        local cards={};for _,card in ipairs(shell.canvas.cards) do cards[card.frame]=true;assert(card.model.x+card.model.width<=shell.view.width+.5,'condition card wider than its canvas') end
        audit.assertContained(shell.frame,f.frames,'condition editor at '..width,{captions=true,container=function(frame) return cards[frame] end,horizontalScroll={[shell.canvas.frame]=true}})
    end
end)

test('Integrations cards and editor rows follow the page width live',function()
    local f,a,p=integrationFixture({width=1000});local layout=f.layout;layout.settle();local parent=p.frame:GetParent()
    parent.rmHelpReserve=a.WorkbenchLayout.helpReserve
    for _,width in ipairs({1600,776,1200}) do
        parent:SetSize(width,600);p:SetWidth(width);layout.settle()
        assert(p.width==width-40 and p.fields.integration_card_editor_native:GetWidth()==p.width,'Integrations did not follow '..width)
        audit.assertContained(parent,f.frames,'Integrations at '..width,{captions=true})
        audit.assertCornerFree(parent,f.frames,{left=width-20,right=width,top=0,bottom=-20},'Integrations runs under the page Help corner at '..width)
    end
end)

test('General shares the Enable row in thirds and its capture columns reflow',function()
    local f,a,shell,layout,frames=settingsShell('General')
    for _,size in ipairs({{1600,820},{800,500},{1120,760}}) do
        layout.userResize(shell.frame,size[1],size[2]);layout.settle()
        local p=shell.pane;local width=p.columnSingle and p.fullWidth or p.columnWidth
        local enable,bar,minimap=p.fields.enable,p.fields.disable_buttons,p.fields.minimap
        local third=(width-8)/3
        assert(enable.point[3]==bar.point[3] and bar.point[3]==minimap.point[3] and enable.point[2]==0 and math.abs(enable:GetWidth()-third)<.01 and bar:GetWidth()==enable:GetWidth() and minimap:GetWidth()==enable:GetWidth()
            and math.abs(bar.point[2]-(third+4))<.01 and math.abs(minimap.point[2]-2*(third+4))<.01,'Enable row is not split in thirds at '..size[1])
        local tops={};for _,key in ipairs({'cpu_capture','cpu_runtime_capture','memory_capture','cast_capture'}) do local b=p.fields[key];if b then tops[#tops+1]=b end end
        for _,b in ipairs(tops) do assert(b:GetWidth()<=width+.01,'capture column wider than the page') end
        audit.assertContained(shell.frame,frames,'General at '..size[1],{captions=true})
    end
end)

test('capture buttons follow captures started, stopped or finished elsewhere only while shown',function()
    local state={running=false,report=nil,reads=0}
    local f,a,shell,layout=settingsShell('General',function(a)
        a.StartCPUProfile=function() state.running=true;return true end
        a.StopCPUProfile=function() state.running=false;state.report='kept';return true end
        a.IsCPUProfileRunning=function() state.reads=state.reads+1;return state.running end
        a.GetCPUProfileReport=function() if state.running then return 'running' end;return state.report end
        a.print=function() end
    end)
    local p=shell.pane;local capture,report=p.fields.cpu_capture,p.fields.cpu_report
    assert(capture:GetText()=='Capture CPU (10s)' and not report:IsEnabled(),'report enabled before any capture')
    state.running=true;layout.settle(20);assert(capture:GetText()=='Stop CPU capture' and not report:IsEnabled(),'capture started elsewhere was not shown')
    state.running=false;state.report='finished';layout.settle(20);assert(capture:GetText()=='Capture CPU (10s)' and report:IsEnabled(),'finished capture did not enable its report')
    capture:Click();assert(state.running and capture:GetText()=='Stop CPU capture')
    capture:Click();assert(not state.running and state.report=='kept' and report:IsEnabled(),'Stop did not keep the report')
    shell.frame:Hide();local reads=state.reads;state.running=true;layout.settle(20);assert(state.reads==reads,'hidden page polled capture state')
end)

test('custom condition flags share one row in thirds and wrap instead of clipping',function()
    local f,a=authoringFixture(true);local layout=f.layout
    local source=a:CopySettingsData(a.empty_condition);source.description='Inline';source.fields={spell='number'};a.db.global.custom_conditions.INLINE=source;a.conditionDefinitions.INLINE={description='Inline',fields=source.fields}
    local host=a:TrackWorkbenchSize(layout.create('Frame'));host:SetSize(1400,600);layout.settle()
    local p=a:OpenNativeSettings(host,'Conditions');layout.settle()
    for _,case in ipairs({{1400,nil},{776,99999}}) do
        a.db.global.workbenchSidebarWidth=case[2];host:SetSize(case[1],600);p:SetWidth(case[1]);layout.settle()
        local form=p.inlineCondition.form;local flags={form.fields.hidden,form.fields.switch,form.fields.announcement}
        local row=form.width-148
        for _,flag in ipairs(flags) do
            assert(flag:GetFontString():GetStringWidth()+22<=flag:GetWidth()+.01,'flag caption clipped at '..case[1])
            assert(flag.point[2]+flag:GetWidth()<=row+.01,'flag runs into the Enabled and Delete controls')
        end
        if case[1]==1400 then assert(flags[1].point[3]==flags[3].point[3],'wide page did not keep the flags on one row') end
        if flags[1].point[3]==flags[3].point[3] then
            assert(math.abs(flags[1]:GetWidth()-(row-8)/3)<.01 and flags[2].point[3]==flags[1].point[3],'one-row flags are not thirds')
        else assert(flags[3].point[3]<flags[1].point[3],'narrow flags overlap instead of wrapping') end
        audit.assertContained(host,f.frames,'flags at '..case[1],{captions=true})
    end
end)

finish()
