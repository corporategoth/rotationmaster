-- Window layering: a popup is never drawn beneath the window that opened it.
-- The layering rules are in docs/architecture/window-layering.md. This file drives the registry in UI/window.lua
-- with windows built like RM's (content at assorted levels above the window's own), over a model of the client's
-- frame ordering (tests/fixtures/layer_model.lua) under both readings of what Raise() does.
local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local WINDOW_FILE=os.getenv('RM_WINDOW_FILE') or 'UI/window.lua'
local function world(raise)
    local f=F.new();f.env.UISpecialFrames={}
    dofile('tests/fixtures/native_ui.lua')(f.env)
    local model=dofile('tests/fixtures/layer_model.lua')(f.env,{raise=raise})
    -- RM_WINDOW_FILE loads another revision of window.lua to reproduce a report against it (the registry is not shared).
    if os.getenv('RM_WINDOW_FILE') then
        for _,name in ipairs({'OpenPopup','RaiseWindow','RaiseForeignWindow','SyncWindowLayers','GetWindowLayers'}) do f.addon[name]=nil end
    end
    f.load(WINDOW_FILE)
    local sync=function() if f.addon.SyncWindowLayers then f.addon:SyncWindowLayers() end end
    local function openPopup(w,opener,options)
        w.frame:Show()
        if f.addon.OpenPopup then f.addon:OpenPopup(w,opener,options) else f.addon:RegisterWindowForEscape(w) end
    end
    return f,model,sync,openPopup
end
-- A window shaped like RM's: content at the window's level + 1, a deeper pane, and a control sitting `offset` above.
local function window(f,model,name,offset)
    local w={name=name,frame=model.create('Frame',name,f.env.UIParent)}
    w.frame:SetSize(400,300);w.frame:SetToplevel(true) -- every RM window asked for click-to-raise itself
    w.pane=model.create('Frame',nil,w.frame)
    w.deep=model.create('Frame',nil,w.pane);w.deep:SetFrameLevel(w.frame:GetFrameLevel()+(offset or 250))
    w.button=model.create('Button',nil,w.deep)
    w.frame:Hide()
    function w:Hide() self.frame:Hide() end
    return w
end
local function covers(model,popup,window,except)
    local ok,node=model.coversWindow(popup.frame,window.frame,except)
    assert(ok,popup.name..' is beneath content of '..window.name..' (level '..tostring(node and node.layer.level)..' vs '..popup.frame.layer.level..')')
end
local function eachModel(name,body)
    for _,raise in ipairs({'siblings','strata'}) do test(name..' ['..raise..' raise]',function() body(raise) end) end
end

eachModel('a popup opens above all of its opener, including content far above the opener window',function(raise)
    for _,offset in ipairs({5,250,500,1500}) do
        local f,model,_,open=world(raise)
        local config,editor=window(f,model,'config',offset),window(f,model,'editor')
        config.rmLayerKind='window'
        open(config);open(editor,config)
        covers(model,editor,config)
        assert(model.over(editor.frame,config.frame))
    end
end)

eachModel('clicking the opener after the popup opened cannot leave the popup beneath it',function(raise)
    local f,model,sync,open=world(raise)
    local config,editor=window(f,model,'config'),window(f,model,'editor')
    config.rmLayerKind='window'
    open(config);open(editor,config)
    local clicked=model.click(config.button)
    assert(clicked==config.frame,'the click did not reach the toplevel window')
    sync()
    covers(model,editor,config)
    assert(f.env.RotationMasterFrontmostDialog==editor.frame,'Escape would close the window under the popup')
end)

eachModel('opening a popup again while it is already visible brings it back in front',function(raise)
    local f,model,_,open=world(raise)
    local config,editor=window(f,model,'config'),window(f,model,'editor')
    config.rmLayerKind='window'
    open(config);open(editor,config)
    model.click(config.button)
    -- ShowConditionEditor on an open editor: Show() is a no-op, so nothing but the open call can fix this.
    open(editor,config)
    covers(model,editor,config)
end)

eachModel('a popup shown again after the opener was raised is placed above it',function(raise)
    local f,model,_,open=world(raise)
    local config,editor=window(f,model,'config'),window(f,model,'editor')
    config.rmLayerKind='window'
    open(config);open(editor,config)
    editor.frame:Hide();model.click(config.button);editor.frame:Show()
    covers(model,editor,config)
end)

eachModel('a chain of popups stays ordered whichever window is clicked',function(raise)
    local f,model,sync,open=world(raise)
    local config,editor,picker,prompt=window(f,model,'config',400),window(f,model,'editor',300),window(f,model,'picker',120),window(f,model,'prompt',20)
    config.rmLayerKind='window'
    open(config);open(editor,config);open(picker,editor);open(prompt,picker)
    for _,w in ipairs({config,editor,picker,prompt,editor,config}) do
        model.click(w.button);sync()
        covers(model,editor,config);covers(model,picker,editor,{picker.frame,prompt.frame});covers(model,prompt,picker)
        assert(model.over(prompt.frame,picker.frame) and model.over(picker.frame,editor.frame) and model.over(editor.frame,config.frame))
        assert(f.env.RotationMasterFrontmostDialog==prompt.frame)
    end
end)

eachModel('RaiseWindow brings a window and everything it opened in front of another window without inverting them',function(raise)
    local f,model,sync,open=world(raise)
    local a,pa,b=window(f,model,'a'),window(f,model,'pa'),window(f,model,'b')
    a.rmLayerKind='window';b.rmLayerKind='window'
    open(a);open(pa,a);open(b)
    assert(model.over(b.frame,pa.frame),'the window opened last should be in front')
    assert(f.addon:RaiseWindow(a))
    assert(model.over(a.frame,b.frame) and model.over(pa.frame,a.frame))
    assert(f.addon:RaiseWindow(b))
    assert(model.over(b.frame,pa.frame) and model.over(pa.frame,a.frame))
    sync()
    assert(model.over(b.frame,pa.frame) and model.over(pa.frame,a.frame))
end)

eachModel('peer windows are not chained: clicking either one raises it',function(raise)
    local f,model,sync,open=world(raise)
    local a,b=window(f,model,'a'),window(f,model,'b')
    a.rmLayerKind='window';b.rmLayerKind='window'
    open(a);open(b)
    model.click(a.button);sync()
    assert(model.over(a.frame,b.frame),'a peer window could not be brought forward')
    model.click(b.button);sync()
    assert(model.over(b.frame,a.frame))
end)

eachModel('two windows with their own popups interleave without any popup falling below its opener',function(raise)
    local f,model,sync,open=world(raise)
    local a,pa,b,pb=window(f,model,'a',300),window(f,model,'pa'),window(f,model,'b',200),window(f,model,'pb')
    a.rmLayerKind='window';b.rmLayerKind='window'
    open(a);open(pa,a);open(b);open(pb,b)
    for _,w in ipairs({a,b,pa,pb,a,pb,b}) do
        model.click(w.button);sync()
        covers(model,pa,a);covers(model,pb,b)
    end
end)

eachModel('without a named opener a popup still opens above whatever was open and stays above it',function(raise)
    local f,model,sync,open=world(raise)
    local config,help=window(f,model,'config',600),window(f,model,'help')
    config.rmLayerKind='window'
    open(config);open(help)
    covers(model,help,config)
    model.click(config.button);sync()
    covers(model,help,config)
end)

eachModel('a popup opened from a hidden owner stays above the window beneath that owner',function(raise)
    local f,model,sync,open=world(raise)
    local config,editor,schema=window(f,model,'config'),window(f,model,'editor'),window(f,model,'schema')
    config.rmLayerKind='window'
    open(config);open(editor,config);editor.frame:Hide();open(schema,editor)
    model.click(config.button);sync()
    covers(model,schema,config)
end)

eachModel('a popup nested inside its opener (a prompt in a pane) clears the opener content, and a later popup clears it',function(raise)
    local f,model,sync,open=world(raise)
    local config=window(f,model,'config',700)
    local prompt={name='prompt',frame=model.create('Frame','prompt',config.pane)};prompt.frame:Hide()
    local late=window(f,model,'late')
    config.rmLayerKind='window'
    open(config);open(prompt,config)
    covers(model,prompt,config,{prompt.frame})
    open(late)
    assert(model.over(late.frame,prompt.frame),'a popup opened later is beneath an older prompt')
    model.click(config.button);sync()
    covers(model,prompt,config,{prompt.frame})
end)

eachModel('opening again does not ratchet levels upward',function(raise)
    local f,model,sync,open=world(raise)
    local config,editor=window(f,model,'config',250),window(f,model,'editor')
    config.rmLayerKind='window'
    open(config);open(editor,config)
    local first=editor.frame.layer.level
    for _=1,60 do open(editor,config);f.addon:RaiseWindow(config);sync() end
    assert(editor.frame.layer.level<=first+60,'level kept climbing: '..first..' -> '..editor.frame.layer.level)
    assert(config.frame.layer.level<=1200)
end)

eachModel('a Blizzard panel opened over the windows sits above them and below the popup that controls it',function(raise)
    local f,model,sync,open=world(raise)
    local config,editor=window(f,model,'config',250),window(f,model,'editor')
    config.rmLayerKind='window'
    local blizzard=model.create('Frame','PlayerSpellsFrame',f.env.UIParent)
    blizzard:SetFrameLevel(40)
    local inner=model.create('Frame',nil,blizzard)
    open(config);open(editor,config)
    assert(f.addon:RaiseForeignWindow(blizzard,editor))
    assert(blizzard.layer.strata=='FULLSCREEN_DIALOG' and model.over(blizzard,config.frame),'the panel is beneath the RM window that opened it')
    open(editor,config,{over=blizzard})
    assert(model.over(editor.frame,blizzard) and model.over(editor.frame,inner))
    -- Clicking the panel raises it natively (toplevel); the control strip returns above it on the next frame.
    blizzard:SetToplevel(true);blizzard:SetFrameLevel(model.key(editor.frame)%100000+50)
    sync()
    assert(model.over(editor.frame,blizzard) and model.over(editor.frame,inner),'the control strip stayed beneath the panel')
end)

test('a Blizzard panel in a higher strata raises the popup into that strata; a protected one is not touched in combat',function()
    local f,model,_,open=world('siblings')
    local config,editor=window(f,model,'config'),window(f,model,'editor')
    config.rmLayerKind='window'
    local top=model.create('Frame','Top',f.env.UIParent);top:SetFrameStrata('TOOLTIP');top:SetFrameLevel(100)
    open(config);open(editor,config,{over=top})
    assert(editor.frame:GetFrameStrata()=='TOOLTIP' and model.over(editor.frame,top))
    local locked=model.create('Frame','Locked',f.env.UIParent);locked:SetFrameLevel(5)
    function locked:IsProtected() return true end
    f.env.InCombatLockdown=function() return true end
    assert(f.addon:RaiseForeignWindow(locked,editor)==false and locked:GetFrameStrata()=='MEDIUM' and locked:GetFrameLevel()==5,'a protected frame was moved in combat')
    f.env.InCombatLockdown=function() return false end
    assert(f.addon:RaiseForeignWindow(locked,editor)==true and locked:GetFrameStrata()=='FULLSCREEN_DIALOG')
end)

test('a stack that would pass the client level limit is compacted and stays ordered',function()
    local f,model,sync,open=world('siblings')
    local config,editor,picker=window(f,model,'config',250),window(f,model,'editor',250),window(f,model,'picker',250)
    config.rmLayerKind='window'
    open(config);config.frame:SetFrameLevel(7800)
    open(editor,config);open(picker,editor)
    for _,w in ipairs({config,editor,picker}) do assert(w.frame.layer.level<=8000 and w.frame.layer.level>=0) end
    covers(model,editor,config);covers(model,picker,editor)
    model.click(config.button);sync()
    covers(model,editor,config);covers(model,picker,editor)
    for _,node in ipairs(model.frames) do assert(node.layer.level<=10000) end
end)

test('a frame that opts out of layering (the drag ghost) keeps its strata and level',function()
    local f,model,_,open=world('siblings')
    local config=window(f,model,'config');config.rmLayerKind='window'
    open(config)
    local ghost={name='ghost',frame=model.create('Frame','ghost',f.env.UIParent)}
    ghost.frame:SetFrameStrata('TOOLTIP');ghost.frame:SetFrameLevel(777)
    open(ghost,nil,{layer=false})
    assert(ghost.frame:GetFrameStrata()=='TOOLTIP' and ghost.frame:GetFrameLevel()==777)
    ghost.frame:Hide();ghost.frame:Show()
    assert(ghost.frame:GetFrameStrata()=='TOOLTIP' and ghost.frame:GetFrameLevel()==777)
    assert(f.env.RotationMasterFrontmostDialog==ghost.frame,'the ghost is still the Escape target')
end)

test('a window that is not an Escape target is layered but never closed by Escape',function()
    local f,model,_,open=world('siblings')
    local config,errors=window(f,model,'config',300),window(f,model,'errors')
    config.rmLayerKind='window'
    open(config);open(errors,nil,{escape=false,kind='window'})
    assert(model.over(errors.frame,config.frame) and errors.frame:GetFrameStrata()=='FULLSCREEN_DIALOG')
    assert(f.env.RotationMasterFrontmostDialog==config.frame,'a layer-only window became the Escape target')
    model.click(config.button)
    assert(model.over(config.frame,errors.frame),'peer windows must be raisable')
end)

test('releasing a pooled window restores its native strata and level and forgets it',function()
    local f,model,_,open=world('siblings')
    local pooled=window(f,model,'pooled');pooled.frame:SetFrameLevel(3)
    local released=0;pooled.OnRelease=function() released=released+1 end
    local original=pooled.OnRelease
    open(pooled)
    assert(pooled.frame:GetFrameStrata()=='FULLSCREEN_DIALOG')
    pooled:OnRelease()
    assert(released==1 and pooled.OnRelease==original and pooled.frame:GetFrameLevel()==3 and pooled.frame:GetFrameStrata()=='MEDIUM')
    for _,layer in ipairs(f.addon:GetWindowLayers()) do assert(layer.frame~=pooled.frame,'released window is still registered') end
end)

test('reopening a pooled window re-resolves its opener rather than keeping a stale one',function()
    local f,model,sync,open=world('siblings')
    local a,b,popup=window(f,model,'a'),window(f,model,'b'),window(f,model,'popup')
    a.rmLayerKind='window';b.rmLayerKind='window'
    open(a);open(b);open(popup,a)
    popup.frame:Hide();open(popup,b)
    model.click(a.button);sync()
    assert(model.over(a.frame,b.frame) and model.over(popup.frame,b.frame),'the popup still follows its previous opener')
    model.click(b.button);sync()
    covers(model,popup,b)
end)

finish()
