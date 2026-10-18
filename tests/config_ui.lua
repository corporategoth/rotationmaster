local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
test('native top tabs navigate every section resize and release embedded panes',function()
    local f=F.new();local a=f.addon;local created,released=0,0
    local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create;local pooled
    ace.Create=function(self,kind)
        assert(kind=='SimpleGroup','outer UI still uses AceGUI '..kind)
        created=created+1;local w=pooled;pooled=nil
        if not w then w=original(self,kind);w.frame=create('Frame') end
        function w:SetLayout(value) self.layout=value end
        return w
    end
    ace.Release=function(_,widget) released=released+1;widget.frame:Hide();widget.children={};pooled=widget end
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.configModuleApps={Example='example-options'}
    a.SetupOptions=function() end
    local seen={}
    a.BuildConfigurationPane=function(_,parent,key)
        assert(a.currentConditionEval==nil and a.specTab==nil,'released editor references survived navigation')
        seen[#seen+1]=key;parent:AddChild(f.widget('content'))
    end
    f.load('UI/window.lua');f.load('UI/help.lua');f.load('UI/config.lua')
    local shell=a:ShowConfig('Rotations');assert(shell.frame:GetWidth()>=1000 and seen[1]=='Rotations')
    assert(#shell.tabs==8,'not all sections and optional module are reachable')
    for _,tab in ipairs(shell.tabs) do
        a.currentConditionEval=function() error('old callback') end;a.specTab={}
        tab:Click();assert(seen[#seen]==tab.section)
        assert(shell.pane.frame.visible,'reacquired pane stayed hidden after tab navigation')
    end
    local before=created
    assert(a:ShowConfig('General')==shell and created==before+1,'reopening duplicated the native shell')
    assert(shell.pane.frame.parent==shell.content and shell.pane.width==shell.content:GetWidth())
    assert(shell.frame.strata=='FULLSCREEN_DIALOG','shell and legacy pane strata disagree')
    shell.frame:SetSize(700,500)
    local rows={}
    for _,tab in ipairs(shell.tabs) do rows[tab.point[5]]=true end
    local count=0;for _ in pairs(rows) do count=count+1 end
    assert(count>1 and shell.content:GetHeight()>200,'tabs did not wrap while preserving content space')
    a.currentConditionEval=function() end;a.specTab={}
    shell.close:Click()
    assert(shell.pane==nil and a.currentConditionEval==nil and a.specTab==nil and not shell.frame.visible)
    assert(a:ShowConfig('Rotations')==shell and shell.frame.visible and shell.pane,'native shell was not reused after closing')
    shell.frame.scripts.OnKeyDown(shell.frame,'ESCAPE');assert(not shell.frame.visible)
    assert(released>0)
end)
test('real rotation pane initializes immediately for TBC retail and progression without OnShow scripts',function()
    for _,client in ipairs({{5,1,0},{1,12,123},{19,5,1}}) do
        local f=F.new(client[1],client[2]);local a=f.addon
        local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
        ace.Create=function(self,kind)
            local w=original(self,kind);local scripts={}
            w.frame={SetScript=function(_,event,callback) scripts[event]=callback end,
                Show=function() if scripts.OnShow then scripts.OnShow() end end}
            function w:ReleaseChildren() self.children={} end
            function w:PauseLayout() end
            function w:ResumeLayout() end
            function w:DoLayout() end
            function w:SetGroupList() end
            function w:SetGroup() end
            function w:SetTabs() end
            function w:SelectTab(value) self.callbacks.OnGroupSelected(self,nil,value) end
            local add=w.AddChild
            function w:AddChild(child) add(self,child);child.frame:Show() end
            return w
        end
        f.env.LibStub=setmetatable({GetLibrary=function() return {} end},{__call=function(_,name) return f.libraries[name] or {} end})
        f.env.UnitClass=function() return 'Shaman','SHAMAN',7 end
        f.env.C_SpecializationInfo={GetNumSpecializationsForClassID=function() return 1 end}
        f.env.GetNumSpecializationsForClassID=nil
        f.env.GetSpecializationInfoForClassID=function() return 123,'Restoration' end
        f.env.GetNumTalentGroups=function() return 1 end
        a.GetSpecialization=function() return 1 end
        a.currentSpec=client[3];a.currentRotation='pack-key'
        a.db.char={specs={[1]='Primary'}};a.db.profile.rotations={}
        a.uuid=function() return 'unused' end
        a.configure_frame=function() end
        a.ListDefaultRotations=function() return {{runtimeKey='pack-key',name='Starter'}} end
        a.GetDefaultIdForRuntime=function(_,_,key) return key=='pack-key' and 'pack' end
        local built=0
        a.CreateDefaultRotationOptions=function() built=built+1 end
        f.load('Options/general.lua')
        local pane=ace:Create('SimpleGroup');pane.frame:Show()
        a:BuildConfigurationPane(pane,'Rotations')
        assert(built>0,'already shown rotation pane did not initialize on client '..client[1])
    end
end)
test('general effect preview removes native OnShow before pooled icon reuse',function()
    local f=F.new();local a=f.addon;local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    local icons={};local glows=0
    ace.Create=function(self,kind)
        local w=original(self,kind);local scripts={}
        w.frame={SetScript=function(_,event,fn) scripts[event]=fn end,GetScript=function(_,event) return scripts[event] end}
        function w:ReleaseChildren() self.children={} end
        function w:PauseLayout() end
        function w:ResumeLayout() end
        function w:DoLayout() end
        function w:SetList() end
        function w:SetRelativeWidth() end
        function w:SetColor() end
        function w:SetHasAlpha() end
        function w:SetPoint() end
        if kind=='Icon' then icons[#icons+1]=w end
        return w
    end
    f.env.LibStub=setmetatable({GetLibrary=function() return {} end},{__call=function(_,name) return f.libraries[name] or {} end})
    a.db.profile={minimap={},color={r=1,g=1,b=1,a=1},loglevel=2}
    a.db.global.effects={};a.textured_types={};a.configure_frame=function() end
    a.Glow=function() glows=glows+1 end;a.HideGlow=function() end
    f.load('Options/general.lua')
    a:BuildConfigurationPane(ace:Create('parent'),'General')
    local preview=assert(icons[1]);local show=assert(preview.frame:GetScript('OnShow'))
    assert(glows==1,'normal highlight preview was not initialized when its already-visible icon was added')
    show(preview.frame);assert(glows==2)
    preview.callbacks.OnRelease(preview)
    assert(preview.frame:GetScript('OnShow')==nil,'pooled import/export icon can restart the old effect preview')
end)
test('opening the actual custom rotation roster does not write display defaults into saved steps',function()
    local f=F.new();local a=f.addon;local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    ace.Create=function(self,kind)
        local w=original(self,kind);w.frame={SetScript=function() end}
        for _,method in ipairs({'PauseLayout','ResumeLayout','DoLayout','SetGroupList','SetGroup','SetTree','SetStatusTable','SetPoint'}) do w[method]=function() end end
        function w:ReleaseChildren() self.children={} end
        return w
    end
    f.env.BOOKTYPE_SPELL='spell';f.env.BOOKTYPE_PET='pet'
    f.env.LibStub=setmetatable({GetLibrary=function() return {} end},{__call=function(_,name) return f.libraries[name] or {} end})
    local first={id='one',type='spell',action=403,conditions={}}
    local second={id='two',type='spell',action=324,conditions={},name='Shield reminder'}
    a.db.profile.rotations={[0]={mine={name='Clone',switch={},rotation={first},cooldowns={second}}}}
    a.db.profile.itemsets={};a.db.global.itemsets={}
    a.currentRotation='mine';a.manualRotation=true
    a.ListDefaultRotations=function() return {} end;a.GetDefaultIdForRuntime=function() end
    a.Platform.GetSpellInfo=function(_,id) return {name=id==403 and 'Lightning Bolt' or 'Lightning Shield',spellID=id} end
    a.Platform.GetSpellLink=function() end
    a.configure_frame=function() end;a.usefulCondition=function() return false end
    a.rotationValidConditions=function() return true end;a.validateCondition=function() return true end
    a.uuid=function() return 'new-rotation' end
    f.load('Options/general.lua')
    a:BuildConfigurationPane(ace:Create('parent'),'Rotations')
    assert(first.use_name==nil and second.use_name==nil,'viewing persisted inferred name flags')
    assert(first.name==nil and second.name=='Shield reminder')
end)
test('opening an optional step inherits its highlight without saving a color until confirmed',function()
    local f=F.new();local a=f.addon;local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    local widgets={};local preview
    ace.Create=function(self,kind)
        local w=original(self,kind);widgets[#widgets+1]=w
        w.frame={SetScript=function() end,SetHyperlinksEnabled=function() end}
        for _,method in ipairs({'PauseLayout','ResumeLayout','DoLayout','SetRelativeWidth','SetPoint','SetList','SetHasAlpha','AddItem'}) do w[method]=function() end end
        function w:ReleaseChildren() self.children={} end
        function w:SetColor(...) self.rgba={...} end
        return w
    end
    f.env.BOOKTYPE_SPELL='spell';f.env.BOOKTYPE_PET='pet';f.env.NONE='None'
    local step={id='reminder',type='none',conditions={}}
    a.db.profile={rotations={[0]={mine={cooldowns={step}}}},itemsets={},effect='base',color={r=.2,g=.3,b=.4,a=.5}}
    a.db.global={effects={base={type='pixel',name='Base'}},itemsets={}}
    a.textured_types={};a.Glow=function(_,_,_,_,color) preview=color end
    a.HideGlow=function() end;a.RemoveCooldownGlowIfCurrent=function() end
    a.configure_frame=function() end;a.validateCondition=function() return true end
    a.printCondition=function() return 'Always' end;a.usefulCondition=function() return false end;a.evaluateCondition=function() return true end
    f.load('Options/rotations.lua')
    a:get_cooldown_list(ace:Create('parent'),0,'mine','reminder',function() end)
    assert(step.color==nil,'opening the optional editor changed the saved highlight color')
    assert(preview.r==.2 and preview.g==.3 and preview.b==.4 and preview.a==.5,'preview ignored profile inheritance')
    local picker
    for _,w in ipairs(widgets) do if w.kind=='ColorPicker' then picker=w end end
    assert(picker and table.concat(picker.rgba,',')=='0.2,0.3,0.4,0.5','picker and preview disagree')
    picker.callbacks.OnValueConfirmed(picker,nil,.8,.7,.6,.9)
    assert(step.color.r==.8 and step.color.a==.9 and preview.r==.8,'explicit color confirmation was not saved')
    assert(a.db.profile.color.r==.2,'color editing overwrote the inherited profile color')
end)
test('workbench title text tabs footer help and bounded scale follow navigation and reopen',function()
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    ace.Create=function(self,kind) local w=original(self,kind);w.frame=create('Frame');return w end
    ace.Release=function(_,w) w.frame:Hide() end
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.db.global.uiScale='bad'
    a.SetupOptions=function() end;a.BuildConfigurationPane=function() end
    f.load('UI/window.lua');f.load('UI/help.lua');f.load('UI/config.lua')
    local shell=a:ShowConfig('General')
    assert(shell.title.text:find('Rotation Master',1,true) and shell.activeTitle.text:find('General',1,true) and shell.icon.texture)
    assert(shell.footer and shell.tabs[1].template==nil,'tabs still have stock button art')
    shell.tabs[1]:Click();assert(shell.activeTitle.text:find('Rotations',1,true))
    shell.scaleSlider:SetValue(95);assert(a.db.global.uiScale==0.95 and shell.frame.scale==0.95)
    shell.scaleSlider:SetValue(1);assert(a.db.global.uiScale==0.7)
    shell.scaleSlider:SetValue(999);assert(a.db.global.uiScale==1.3)
    shell.help:Click();assert(shell.helpPane:IsShown())
    f.env.GetMouseFocus=function() return shell.content end
    shell.content.scripts.OnMouseDown(shell.content,'RightButton');assert(not shell.frame.visible)
    a:ShowConfig('General');assert(shell.frame.scale==1.3 and shell.activeTitle.text:find('General',1,true))
    a.db.global.uiScale=0/0;a:ShowConfig('General');assert(shell.frame.scale==1)
end)
test('configuration refresh waits for field callbacks to return and does not reopen a closed window',function()
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    ace.Create=function(self,kind) local w=original(self,kind);w.frame=create('Frame');return w end
    ace.Release=function(_,w) w.frame:Hide() end
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.SetupOptions=function() end;a.BuildConfigurationPane=function() end
    f.load('UI/window.lua');f.load('UI/help.lua');f.load('UI/config.lua')
    local shell=a:ShowConfig('Profiles');local old=shell.pane
    a:RefreshConfiguration();assert(shell.pane==old,'refresh released the active callback host synchronously')
    shell.frame.scripts.OnUpdate(shell.frame);assert(shell.pane~=old and shell.section=='Profiles')
    a:RefreshConfiguration();local stale=shell.frame.scripts.OnUpdate
    shell.close:Click();stale(shell.frame);assert(shell.pane==nil and not shell.frame.visible)
end)
test('header help displays the selected section article and releases it when navigating',function()
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    f.env.ENABLE='Enable'
    f.load('Help/general.lua')
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    ace.Create=function(self,kind) local w=original(self,kind);w.frame=create('Frame');return w end
    ace.Release=function(_,w) w.frame:Hide();w.released=true end
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.SetupOptions=function() end;a.BuildConfigurationPane=function() end
    f.load('UI/window.lua');f.load('UI/help.lua');f.load('UI/config.lua')
    local shell=a:ShowConfig('General');shell.help:Click()
    assert(shell.helpDialog and shell.helpDialog.sections[1].text:find('timing',1,true) and shell.helpDialog.close and shell.helpDialog.chrome.version:GetText()=='Help' and shell.helpDialog.closeButton==nil)
    local article=shell.helpDialog;shell:SelectSection('Profiles')
    assert(not article.frame:IsShown() and not shell.helpPane:IsShown())
    shell.help:Click();assert(shell.helpPane:IsShown() and shell.helpContent==nil)
    shell.close:Click()
end)
test('Plater-style chrome exposes compact bars slider bordered tabs metadata and honest installed-language menu',function()
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    ace.Create=function(self,kind) local w=original(self,kind);w.frame=create('Frame');return w end
    ace.Release=function(_,w) w.frame:Hide() end
    f.env.C_AddOns={GetAddOnMetadata=function(_,key) return ({Author='Makiel',Version='9.9', ['X-Website']='https://example.invalid/rm'})[key] end}
    f.env.GetLocale=function() return 'deDE' end
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.SetupOptions=function() end;a.BuildConfigurationPane=function() end
    f.load('UI/window.lua');f.load('UI/help.lua');f.load('UI/config.lua');local shell=a:ShowConfig('General')
    assert(shell.scaleSlider and shell.scaleSlider.kind=='Slider' and shell.scaleSlider.minimum==70 and shell.scaleSlider.maximum==130)
    assert(shell.footer:GetHeight()==20 and shell.header:GetHeight()<=38 and shell.tabs[1]:GetHeight()==22)
    assert(shell.version:GetText():find('9.9',1,true) and shell.edition:GetText():find('TBC',1,true) and shell.author:GetText():find('Makiel',1,true))
    assert(shell.language and shell.language.value=='enUS' and shell.language.template==nil)
    assert(shell.language.tooltip:find('deDE',1,true),'installed-language tooltip hides the actual game locale')
    shell.language:Click();assert(shell.languageMenu:IsShown() and #shell.languageRows==1 and shell.languageRows[1].selected)
    shell.languageRows[1]:Click();assert(not shell.languageMenu:IsShown())
    for _,tab in ipairs(shell.tabs) do assert(tab.selectionLine==nil and tab.border and tab.border:IsShown()==tab.selected) end
    shell.website:Click();assert(shell.linkInput:GetText()=='https://example.invalid/rm' and shell.linkInput.focused)
end)
test('right-click over a child inside content closes the window without replacing deferred refresh ownership',function()
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create;local released=0
    ace.Create=function(self,kind) local w=original(self,kind);w.frame=create('Frame');return w end
    ace.Release=function(_,w) released=released+1;w.frame:Hide() end
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.SetupOptions=function() end;a.BuildConfigurationPane=function() end
    f.load('UI/window.lua');f.load('UI/help.lua');f.load('UI/config.lua');local shell=a:ShowConfig('General')
    local down=false;f.env.IsMouseButtonDown=function(button) assert(button=='RightButton');return down end
    f.env.MouseIsOver=function(frame) return frame==shell.content end
    f.env.RotationMasterFrontmostDialog=create('Frame');shell.content.scripts.OnUpdate();down=true;shell.content.scripts.OnUpdate()
    assert(shell.frame:IsShown(),'right click through an obscuring RM dialog closed its underlying window')
    down=false;shell.content.scripts.OnUpdate();f.env.RotationMasterFrontmostDialog=nil
    a:RefreshConfiguration();assert(shell.frame.scripts.OnUpdate)
    shell.content.scripts.OnUpdate();down=true;shell.content.scripts.OnUpdate()
    assert(not shell.frame:IsShown() and released==1 and shell.pane==nil and shell.frame.scripts.OnUpdate==nil)
end)
test('right-click ignores opening with the button held and unrelated overlapping mouse focus',function()
    for _,api in ipairs({'GetMouseFoci','GetMouseFocus'}) do
        local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
        local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
        ace.Create=function(self,kind) local w=original(self,kind);w.frame=create('Frame');return w end
        ace.Release=function(_,w) w.frame:Hide() end
        a.pretty_name='Rotation Master';a.name='rotationmaster';a.SetupOptions=function() end;a.BuildConfigurationPane=function() end
        local down=true;local focus
        f.env.IsMouseButtonDown=function() return down end
        f.env.MouseIsOver=function() return true end
        f.env[api]=function() if api=='GetMouseFoci' then return {focus} end;return focus end
        f.load('UI/window.lua');f.load('UI/help.lua');f.load('UI/config.lua');local shell=a:ShowConfig('General')
        focus=shell.content;shell.content.scripts.OnUpdate()
        down=false
        local up=shell.content.scripts.OnMouseUp;if up then up(shell.content,'RightButton') end
        shell.content.scripts.OnUpdate()
        assert(shell.frame:IsShown(),'release of a press held while opening closed the window')
        focus=create('Frame');down=true;shell.content.scripts.OnUpdate()
        assert(shell.frame:IsShown(),'right-click through an unrelated focused overlay closed RM')
        down=false;shell.content.scripts.OnUpdate()
        local child=create('Button');function child:GetParent() return shell.content end
        focus=child;down=true;shell.content.scripts.OnUpdate()
        assert(not shell.frame:IsShown(),'eligible child focus did not close on a new right click')
        down=false;a:ShowConfig('General');focus=shell.content
        assert(shell.content.scripts.OnMouseDown,'direct content presses need an event handler')
        shell.content.scripts.OnMouseDown(shell.content,'RightButton');assert(not shell.frame:IsShown())
    end
end)
test('scaling keeps the window stationary during a drag and applies the chosen intermediate value on release',function()
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    ace.Create=function(self,kind) local w=original(self,kind);w.frame=create('Frame');return w end
    ace.Release=function(_,w) w.frame:Hide() end
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.SetupOptions=function() end;a.BuildConfigurationPane=function() end
    f.load('UI/window.lua');f.load('UI/help.lua');f.load('UI/config.lua');local shell=a:ShowConfig('General')
    shell.scaleSlider.scripts.OnMouseDown(shell.scaleSlider,'LeftButton');shell.scaleSlider:SetValue(83);shell.scaleSlider:SetValue(91)
    assert(shell.frame:GetScale()==1,'rescaling while dragging moved the slider under the pointer')
    shell.scaleSlider.scripts.OnMouseUp(shell.scaleSlider,'LeftButton')
    assert(shell.frame:GetScale()==.91 and a.db.global.uiScale==.91)
    local raw=assert(shell.scaleValue,'scale has no editable value');raw:SetText('87');raw.scripts.OnEnterPressed(raw);assert(a.db.global.uiScale==.87)
    raw:SetText('200');raw.scripts.OnEnterPressed(raw);assert(a.db.global.uiScale==.87);raw.scripts.OnEscapePressed(raw);assert(raw:GetText()=='87')
    local tab=shell.tabs[1];local before=table.concat(tab.art.color,',');tab.scripts.OnEnter();tab.scripts.OnLeave()
    assert(table.concat(tab.art.color,',')==before,'tab resting appearance changes after hovering')
end)
test('opening failures and native UI callbacks reach RM reports and the current external collector',function()
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env);local errors={}
    f.env.geterrorhandler=function() return function(message) errors[#errors+1]=message end end
    f.env.debugstack=function() return 'Interface/AddOns/rotationmaster/UI/config.lua:1: native callback' end
    f.load('Diagnostics/errors.lua');f.load('UI/window.lua');f.load('UI/help.lua');f.load('UI/config.lua')
    a.SetupOptions=function() error('options-open-failed',0) end
    assert(a:ShowConfig('Rotations')==nil and #a.Diagnostics:GetReports()==1 and #errors==1)
    local control=a:CreateWorkbenchButton(create('Frame'),'Test',80)
    a:SetUIScript(control,'OnClick',function() error('owned-click-failed',0) end)
    control:Click();assert(#errors==2 and a.Diagnostics:GetReports()[2].context.operation=='OnClick')
    control:Click();assert(#errors==2,'failed callback was not retired')
end)
finish()
