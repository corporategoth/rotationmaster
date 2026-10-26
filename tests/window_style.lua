local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
test('RM dialog styling adds one fully opaque background without replacing native handlers',function()
    local f=F.new();f.load('UI/window.lua')
    local count,alpha,rgba,points,hidden,released=0,.6,nil,{},false,false
    local frame={SetAlpha=function(_,value) alpha=value end,GetAlpha=function() return alpha end,
        CreateTexture=function(_,name,layer,template,level)
            count=count+1;assert(name==nil and layer=='BACKGROUND' and level<0)
            return {SetPoint=function(_,...) points[#points+1]={...} end,
                Show=function() hidden=false end,Hide=function() hidden=true end,
                SetColorTexture=function(_,...) rgba={...} end}
        end}
    local original=function() assert(hidden and alpha==.6);released=true end
    local widget={frame=frame,OnRelease=original}
    f.addon:MakeWindowOpaque(widget);f.addon:MakeWindowOpaque(widget)
    assert(count==1 and alpha==1 and rgba[4]==1 and #points==2)
    assert(points[1][1]=='TOPLEFT' and points[2][1]=='BOTTOMRIGHT')
    widget:OnRelease()
    assert(released and widget.OnRelease==original and not widget.rmOpaqueActive,'pooled widget retained RM styling')
end)
test('escape setup applies opaque styling while retaining escape close behavior',function()
    local f=F.new();f.load('UI/window.lua');local styled,closed,keyHandler=false,false
    local original=f.addon.MakeWindowOpaque
    f.addon.MakeWindowOpaque=function(_,widget) assert(widget.frame);styled=true end
    local frame={EnableKeyboard=function() end,SetPropagateKeyboardInput=function() end,
        SetScript=function(_,event,callback) assert(event=='OnKeyDown');keyHandler=callback end}
    local widget={frame=frame,Hide=function() closed=true end}
    f.addon.HideOnEscape(widget);assert(styled)
    keyHandler(frame,'ESCAPE');assert(closed)
    f.addon.MakeWindowOpaque=original
end)
test('standard Escape closes the frontmost RM dialog and pooled release restores native lifetime',function()
    local f=F.new();f.env.UISpecialFrames={}
    local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    f.load('UI/window.lua')
    local function escape()
        local found=false
        for _,name in pairs(f.env.UISpecialFrames) do
            local frame=f.env[name]
            if frame and frame:IsShown() then frame:Hide();found=true end
        end
        return found
    end
    local base={frame=create('Frame')};base.frame:SetFrameStrata('FULLSCREEN_DIALOG');base.frame:SetFrameLevel(50)
    local dialog={frame=create('Frame')};dialog.frame:SetFrameLevel(3)
    local shown,hidden,released=0,0,0
    local onShow=function() shown=shown+1 end
    local onHide=function() hidden=hidden+1;dialog:OnRelease() end
    local onRelease=function() released=released+1 end
    dialog.frame:SetScript('OnShow',onShow);dialog.frame:SetScript('OnHide',onHide);dialog.OnRelease=onRelease
    f.addon.HideOnEscape(base);f.addon.HideOnEscape(dialog)
    assert(dialog.frame:GetFrameLevel()>base.frame:GetFrameLevel(),'dialog remained under its owner')
    assert(dialog.frame:GetFrameStrata()=='FULLSCREEN_DIALOG' and dialog.frame.raised)
    assert(#f.env.UISpecialFrames==1,'Escape should have one RM target')
    assert(escape() and not dialog.frame.visible and base.frame.visible,'Escape did not close only the frontmost window')
    assert(hidden==1 and released==1 and dialog.OnRelease==onRelease)
    assert(dialog.frame:GetScript('OnShow')==onShow and dialog.frame:GetScript('OnHide')==onHide)
    assert(dialog.frame:GetFrameLevel()==3 and dialog.frame:GetFrameStrata()=='MEDIUM','pooled window retained RM ordering')
    -- It can now be reused by another addon without becoming an RM Escape target.
    dialog.frame:Show();assert(shown==1)
    assert(escape() and not base.frame.visible and dialog.frame.visible)
    assert(not escape())
    base.frame:Show();assert(escape() and not base.frame.visible,'persistent shell did not re-register on Show')
end)
test('Escape follows a mouse-raised peer window without closing a background dialog',function()
    local f=F.new();f.env.UISpecialFrames={}
    local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.load('UI/window.lua')
    -- Two independent windows (for example the settings window and a stand-alone report), neither opened by the other.
    local base={frame=create('Frame'),rmLayerKind='window'};local dialog={frame=create('Frame'),rmLayerKind='window'}
    f.addon.HideOnEscape(base);f.addon.HideOnEscape(dialog)
    -- Native SetToplevel raises a clicked root without firing OnShow.
    base.frame:SetFrameLevel(dialog.frame:GetFrameLevel()+1);base.frame:Raise()
    for _,frame in ipairs(frames) do if frame.visible and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame) end end
    local target=f.env[f.env.UISpecialFrames[1]]
    assert(f.env.RotationMasterFrontmostDialog==base.frame,'Escape alias still targets the background comparison')
    target:Hide();assert(not base.frame.visible and dialog.frame.visible)
    assert(f.env.RotationMasterFrontmostDialog==dialog.frame)
end)
test('a popup opened by a window stays the Escape target and the front window when its opener is clicked',function()
    local f=F.new();f.env.UISpecialFrames={}
    local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.load('UI/window.lua')
    local base={frame=create('Frame'),rmLayerKind='window'};local dialog={frame=create('Frame')}
    f.addon.HideOnEscape(base);f.addon.HideOnEscape(dialog)
    -- Native SetToplevel raises the clicked opener over its popup without firing OnShow.
    base.frame:SetFrameLevel(dialog.frame:GetFrameLevel()+1);base.frame:Raise()
    for _,frame in ipairs(frames) do if frame.visible and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame) end end
    assert(f.env.RotationMasterFrontmostDialog==dialog.frame,'Escape would close the opener under its own popup')
    assert(dialog.frame:GetFrameLevel()>base.frame:GetFrameLevel(),'the popup stayed under the clicked opener')
end)
test('workbench scale reaches independent dialogs but is inherited only once by child popovers',function()
    local f=F.new();local _,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.load('UI/window.lua')
    f.addon.db.global.uiScale=.87
    local root={frame=create('Frame',nil,f.env.UIParent)};f.addon:MakeWindowOpaque(root)
    local child={frame=create('Frame',nil,root.frame)};f.addon:MakeWindowOpaque(child)
    assert(root.frame:GetScale()==.87 and child.frame:GetScale()==1)
    f.addon:ScaleWorkbenchWindows(.93);assert(root.frame:GetScale()==.93 and child.frame:GetScale()==1)
    root:OnRelease();assert(root.frame:GetScale()==1)
    f.addon:ScaleWorkbenchWindows(.75);assert(root.frame:GetScale()==1,'a released pooled frame retained RM scale ownership')
end)
test('themed dialog headers drag their own window without intercepting body fields or resetting geometry',function()
    local f=F.new();local _,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.load('UI/window.lua')
    local frame=create('Frame',nil,f.env.UIParent);frame:SetSize(620,430);frame:SetPoint('CENTER')
    local started,stopped,movable,clamped=0,0,false,false
    function frame:SetMovable(value) movable=value end;function frame:SetClampedToScreen(value) clamped=value end
    function frame:StartMoving() started=started+1 end;function frame:StopMovingOrSizing() stopped=stopped+1 end
    local field=create('EditBox',nil,frame);local clicked=0;field:SetScript('OnMouseDown',function() clicked=clicked+1 end)
    local title=frame:CreateFontString(nil,'OVERLAY','GameFontNormal');local chrome=f.addon:CreateWorkbenchDialogChrome(frame,title)
    local drag=assert(chrome.drag,'shared dialog chrome has no title-bar drag surface')
    assert(movable and clamped and drag:GetParent()==frame and drag.drags[1]=='LeftButton')
    assert(not frame.drags and not field.drags,'dialog dragging captures editable content')
    drag:GetScript('OnDragStart')(drag,'RightButton');assert(started==0,'right-click started a drag')
    drag:GetScript('OnDragStart')(drag,'LeftButton');assert(started==1)
    frame:SetPoint('TOPLEFT',f.env.UIParent,'TOPLEFT',120,-90);local point=frame.point
    drag:GetScript('OnDragStop')(drag);assert(stopped==1)
    chrome:SetContext('Output','Output','Example');frame:SetSize(700,500);chrome:LayoutTitle()
    assert(frame.point==point and frame.point[4]==120 and frame.point[5]==-90,'chrome layout recentered a moved dialog')
    field:GetScript('OnMouseDown')(field,'LeftButton');assert(clicked==1 and started==1,'editing content moved the window')
end)
test('shared title dragging stops on hide and leaves owner close handlers intact',function()
    local f=F.new();local _,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.load('UI/window.lua')
    local frame=create('Frame',nil,f.env.UIParent);local hidden,stopped=0,0
    local onHide=function() hidden=hidden+1 end;frame:SetScript('OnHide',onHide)
    function frame:StopMovingOrSizing() stopped=stopped+1 end
    local chrome=f.addon:CreateWorkbenchDialogChrome(frame,frame:CreateFontString())
    local drag=assert(chrome.drag);drag:GetScript('OnDragStart')(drag,'LeftButton');frame:Hide()
    -- Native hiding a parent emits OnHide on its drag child as well.
    drag:GetScript('OnHide')(drag)
    assert(stopped==1 and hidden==1 and frame:GetScript('OnHide')==onHide)
    assert(f.addon:EnableWorkbenchTitleDrag(frame)==drag,'same root allocated duplicate title drag handlers')
end)
finish()
