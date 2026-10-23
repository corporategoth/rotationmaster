local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function nativePages(f)
    local a=f.addon;local counters={created=0,released=0,seen={}}
    local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    a.GetConditionWidgetCompatibilityLibrary=function() error('native shell requested retired GUI library') end
    a.OpenNativeSettings=function(_,parent,key)
        counters.created=counters.created+1;counters.seen[#counters.seen+1]=key
        local p={frame=create('Frame',nil,parent)}
        function p:SetWidth(value) self.width=value;self.frame:SetWidth(value) end
        function p:SetHeight(value) self.height=value;self.frame:SetHeight(value) end
        function p:Release() counters.released=counters.released+1;self.frame:Hide() end
        p:SetWidth(parent:GetWidth());p:SetHeight(parent:GetHeight());p.frame:Show();return p
    end
    return counters
end

test('native top tabs navigate every section resize and release only native owned panes',function()
    local f=F.new();local a=f.addon;local pages=nativePages(f)
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.configModuleApps={Example='example-options'}
    a.SetupOptions=function() end
    a.BuildConfigurationPane=function() error('native page revived a retired renderer') end
    f.load('UI/window.lua');f.load('UI/help.lua');f.load('UI/config.lua')
    local shell=a:ShowConfig('Rotations');assert(shell.frame:GetWidth()>=1000 and pages.seen[1]=='Rotations')
    local sections={};for _,tab in ipairs(shell.tabs) do sections[tab.section]=true end
    assert(#shell.tabs==9 and sections.Functions and not sections['module:Example'],'retired module UI is still registered')
    for _,tab in ipairs(shell.tabs) do
        a.currentConditionEval=function() error('old callback') end;a.specTab={}
        tab:Click();assert(pages.seen[#pages.seen]==tab.section and a.currentConditionEval==nil and a.specTab==nil)
        assert(shell.pane.frame.visible,'native pane stayed hidden after tab navigation')
    end
    local before=pages.created
    assert(a:ShowConfig('General')==shell and pages.created==before+1)
    assert(shell.pane.frame.parent==shell.content and shell.pane.width==shell.content:GetWidth())
    shell.frame:SetSize(700,500)
    local rows={};for _,tab in ipairs(shell.tabs) do rows[tab.point[5]]=true end
    local count=0;for _ in pairs(rows) do count=count+1 end
    assert(count>1 and shell.content:GetHeight()>200)
    a.currentConditionEval=function() end;a.specTab={};shell.close:Click()
    assert(not shell.pane and not a.currentConditionEval and not a.specTab and not shell.frame.visible)
    assert(a:ShowConfig('Rotations')==shell and shell.frame.visible and shell.pane)
    shell.frame.scripts.OnKeyDown(shell.frame,'ESCAPE');assert(not shell.frame.visible and pages.released>0)
end)
-- The four retired Options renderer tests now have their native behavior covered
-- by rotation_editor_ui, settings_pages and preview suites. They no longer load
-- an unsupported renderer merely to recreate removed UI contracts.
test('workbench title text tabs footer help and bounded scale follow navigation and reopen',function()
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    nativePages(f)
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
    nativePages(f)
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
    nativePages(f)
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
    nativePages(f)
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
    assert(shell.website:GetText()=='Website','the website link shows its URL instead of reading Website')
    shell.website:Click();assert(shell.linkInput:GetText()=='https://example.invalid/rm' and shell.linkInput.focused and shell.linkInput.selection and shell.linkInput.selection[1]==0 and shell.linkInput.selection[2]==-1,'Website does not open the highlighted copy box')
end)
test('right-click over a child inside content closes the window without replacing deferred refresh ownership',function()
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local pages=nativePages(f)
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.SetupOptions=function() end;a.BuildConfigurationPane=function() end
    f.load('UI/window.lua');f.load('UI/help.lua');f.load('UI/config.lua');local shell=a:ShowConfig('General')
    local down=false;f.env.IsMouseButtonDown=function(button) assert(button=='RightButton');return down end
    f.env.MouseIsOver=function(frame) return frame==shell.content end
    f.env.RotationMasterFrontmostDialog=create('Frame');shell.content.scripts.OnUpdate();down=true;shell.content.scripts.OnUpdate()
    assert(shell.frame:IsShown(),'right click through an obscuring RM dialog closed its underlying window')
    down=false;shell.content.scripts.OnUpdate();f.env.RotationMasterFrontmostDialog=nil
    a:RefreshConfiguration();assert(shell.frame.scripts.OnUpdate)
    shell.content.scripts.OnUpdate();down=true;shell.content.scripts.OnUpdate()
    assert(not shell.frame:IsShown() and pages.released==1 and shell.pane==nil and shell.frame.scripts.OnUpdate==nil)
end)
test('right-click ignores opening with the button held and unrelated overlapping mouse focus',function()
    for _,api in ipairs({'GetMouseFoci','GetMouseFocus'}) do
        local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
        nativePages(f)
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
    nativePages(f)
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
test('missing native pages use a native error surface without reviving unregistered legacy panes',function()
    local f=F.new();local a=f.addon;a.pretty_name='Rotation Master';a.name='rotationmaster';a.SetupOptions=function() end
    a.GetConditionWidgetCompatibilityLibrary=function() error('missing native page allocated retired GUI') end
    f.load('UI/config.lua')
    local shell=a:ShowConfig('General');assert(shell.nativePane and shell.pane and shell.pane.message:GetText():find('General',1,true))
    local first=shell.pane;shell:SelectSection('Profiles');assert(shell.pane==first and shell.pane.frame:IsShown() and shell.pane.message:GetText():find('Profiles',1,true),'error pane was not reused')
    shell:SelectSection('unregistered');assert(shell.section=='Rotations' and shell.pane.message:GetText():find('Rotations',1,true))
    shell.close:Click();assert(not first.frame:IsShown() and not shell.pane)
end)
test('retired module maps and foreign builders cannot create tabs render panes or release foreign frames',function()
    local f=F.new();local a=f.addon;local pages=nativePages(f)
    a.SetupOptions=function() end;a.configModuleApps={['Module title']='ApplicationID'};a.name='rotationmaster';a.pretty_name='Rotation Master'
    a.BuildConfigurationPane=function() error('retired foreign renderer invoked') end
    a.BuildModuleConfigurationPane=function() error('retired module renderer invoked') end
    f.load('UI/config.lua');local shell=a:ShowConfig('module:Module title')
    assert(#shell.tabs==9 and shell.section=='Rotations' and shell.nativePane)
    for _,tab in ipairs(shell.tabs) do assert(not tab.section:match('^module:')) end
    local native=shell.pane;shell:ReleasePane();assert(pages.released==1 and not native.frame:IsShown())
    local foreign={Release=function() error('foreign owner released') end}
    shell.pane=foreign;shell.nativePane=false;shell:ReleasePane();assert(not shell.pane and pages.released==1)
end)
finish()
