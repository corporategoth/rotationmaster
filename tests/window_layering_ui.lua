-- Window layering through the real RM windows: every popup type opened from every kind of parent it has in the
-- addon, over the client's frame-ordering model (tests/fixtures/layer_model.lua), under both readings of Raise().
-- tests/window_layering.lua covers the registry itself with synthetic windows.
local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function sourcePrefix(path)
    local h=assert(io.open(path));local source=h:read('*a');h:close()
    return assert(source:match('^(.-)\ntest%('))
end
-- The condition editor suite's world (real editor, canvas, cards, type picker, help), plus the real settings window.
local editorFixture=assert(loadstring(sourcePrefix('tests/condition_editor_ui.lua')..'\nreturn fixture','@condition-editor-fixture'))()
-- The settings pages suite's world (real forms, prompts, transfers, pickers).
local pagesFixture=assert(loadstring(sourcePrefix('tests/settings_pages.lua')..'\nreturn fixture','@settings-pages-fixture'))()

local function layered(f,raise)
    f.env.UISpecialFrames={}
    return dofile('tests/fixtures/layer_model.lua')(f.env,{raise=raise})
end
local function configWorld(raise)
    local f=editorFixture();local a=f.addon;local model=layered(f,raise);local create=model.create
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.SetupOptions=function() end;a.BuildConfigurationPane=function() end
    a.OpenNativeSettings=function(_,parent)
        local p={frame=create('Frame',nil,parent)}
        function p:SetWidth(v) self.frame:SetWidth(v) end
        function p:SetHeight(v) self.frame:SetHeight(v) end
        function p:Release() self.frame:Hide() end
        p:SetWidth(parent:GetWidth());p:SetHeight(parent:GetHeight());p.frame:Show();return p
    end
    f.load('UI/settings_transfer.lua');f.load('UI/config.lua')
    local shell=a:ShowConfig('Rotations')
    return f,a,model,shell
end
local function covers(model,popup,window,except)
    local ok,node=model.coversWindow(popup,window,except)
    assert(ok,'popup (level '..popup.layer.level..') is beneath content of the window it came from (level '..tostring(node and node.layer.level)..')')
end
local function each(name,body)
    for _,raise in ipairs({'siblings','strata'}) do test(name..' ['..raise..' raise]',function() body(raise) end) end
end
local function number() return {type='NUMBER',number=7} end

each('the condition editor opens above the settings window, whichever way the settings window was clicked since',function(raise)
    local f,a,model,config=configWorld(raise)
    local editor=assert(a:ShowConditionEditor(1,0,number(),function() end))
    covers(model,editor.frame,config.frame)
    -- Click the settings window (its content and a control inside it): the editor must not end up beneath it.
    for _,target in ipairs({config.content,config.footer,config.frame}) do
        model.click(target);a:SyncWindowLayers()
        covers(model,editor.frame,config.frame)
        assert(f.env.RotationMasterFrontmostDialog==editor.frame,'Escape would close the settings window under the editor')
    end
    -- Edit another condition while one is open: the open editor is brought forward, not left beneath.
    model.click(config.content)
    assert(a:ShowConditionEditor(2,0,number(),function() end)==editor)
    covers(model,editor.frame,config.frame)
    -- Closed and opened again after the settings window was raised.
    editor.cancel:Click();model.click(config.content)
    assert(a:ShowConditionEditor(1,0,number(),function() end)==editor)
    covers(model,editor.frame,config.frame)
end)

each('Help opened from the editor, and from the settings window, stays above the window it came from',function(raise)
    local f,a,model,config=configWorld(raise)
    local editor=assert(a:ShowConditionEditor(1,0,number(),function() end))
    local help=assert(a:ShowWorkbenchHelp('Topic',{{title='A',text='b'}},'Rotation Master'))
    covers(model,help.frame,editor.frame);covers(model,help.frame,config.frame)
    for _,target in ipairs({editor.frame,config.content}) do
        model.click(target);a:SyncWindowLayers()
        covers(model,help.frame,editor.frame);covers(model,help.frame,config.frame)
    end
    -- A second Help topic replaces the first inside the same (still visible) window.
    model.click(editor.frame)
    assert(a:ShowWorkbenchHelp('Other',{{title='C',text='d'}},'Rotation Master')==help)
    covers(model,help.frame,editor.frame)
end)

each('dropdown menus, the condition type picker and full-text reports open above the editor that owns them',function(raise)
    local f,a,model,config=configWorld(raise)
    local editor=assert(a:ShowConditionEditor(1,0,number(),function() end))
    local menu=a:CreateWorkbenchSelector()
    menu:Open(editor.apply,{{value=1,text='One'},{value=2,text='Two'}},nil,function() end,function() return true end)
    covers(model,menu.frame,editor.frame);covers(model,menu.frame,config.frame)
    model.click(editor.frame);a:SyncWindowLayers()
    covers(model,menu.frame,editor.frame)
    menu:Hide()
    if a.ShowConditionText then
        local text=assert(a:ShowConditionText('A long condition expression','Full text'))
        covers(model,text.frame,editor.frame)
        model.click(editor.frame);a:SyncWindowLayers();covers(model,text.frame,editor.frame)
        -- Shown again while still visible, after the editor was clicked.
        model.click(editor.frame)
        a:ShowConditionText('Another expression','Full text')
        covers(model,text.frame,editor.frame)
    end
    local card=editor.canvas.cards[1]
    if card and card.typeButton then
        card.typeButton:Click()
        local host=card.picker and card.picker.host or editor.picker and editor.picker.host
        if host and host:IsShown() then covers(model,host,editor.frame,{host}) end
    end
end)

each('a text report opened over the editor and a report opened over the settings window are both in front',function(raise)
    local f,a,model,config=configWorld(raise)
    local report=a:CreateWorkbenchTextReport()
    report:SetReport('Report','text',nil)
    covers(model,report.frame,config.frame)
    local editor=assert(a:ShowConditionEditor(1,0,number(),function() end))
    model.click(config.content);a:SyncWindowLayers()
    covers(model,editor.frame,config.frame)
    -- The report was open first, so it is beneath the editor opened later: that is the newest-in-front rule.
    assert(model.over(editor.frame,report.frame))
    report:SetReport('Report again','more',nil)
    covers(model,report.frame,editor.frame)
end)

each('settings prompts, transfer windows, pickers and comparisons open above the page that owns them',function(raise)
    local f,parent=pagesFixture();local a=f.addon;local model=layered(f,raise)
    local window=model.ensure(parent);a:OpenPopup({frame=window},nil,{kind='window'})
    window:Show()
    local p=a:CreateSettingsForm(parent);p:Open(function() end)
    local function check(name,frame,except)
        local ok,node=model.coversWindow(frame,window,except or {frame})
        assert(ok,name..' is beneath the settings window ('..frame.layer.level..' vs '..tostring(node and node.layer.level)..')')
        model.click(window);a:SyncWindowLayers()
        ok,node=model.coversWindow(frame,window,except or {frame})
        assert(ok,name..' fell beneath the settings window after it was clicked ('..frame.layer.level..' vs '..tostring(node and node.layer.level)..')')
    end
    p:Confirm('Sure?',function() end);check('confirm prompt',p.prompt.frame)
    p.prompt.frame:Hide()
    local transfer=a:ShowSettingsTextTransfer(p,'Transfer','Data',function() return true end)
    check('text transfer',transfer.frame)
    -- Opened again while visible, after the page was clicked.
    model.click(window)
    a:ShowSettingsTextTransfer(p,'Transfer','Data',function() return true end)
    check('text transfer, again',transfer.frame)
    transfer.frame:Hide()
    if a.ShowWorkbenchIconPicker then
        local picker=a:ShowWorkbenchIconPicker(nil,function() end,function() return true end)
        check('icon picker',picker.frame)
        model.click(window)
        a:ShowWorkbenchIconPicker(nil,function() end,function() return true end)
        check('icon picker, again',picker.frame)
    end
end)

finish()
