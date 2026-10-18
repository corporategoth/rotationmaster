local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new();local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local scroll=f.addon:CreateWorkbenchScrollFrame(create('Frame'));scroll:SetSize(300,200)
    local child=create('Frame');child:SetSize(500,1000);scroll:SetScrollChild(child);scroll:UpdateWorkbenchScroll()
    return f,scroll,child
end
test('flat scrollbars use a proportional thumb and support wheel drag and clamped resize',function()
    local _,scroll,child=fixture();local bar=scroll.workbenchBar
    assert(scroll.template==nil and bar:IsShown() and bar.maximum==800 and bar.thumbTexture:GetHeight()>=18)
    scroll.scripts.OnMouseWheel(scroll,-2);assert(scroll.scrollOffset==80)
    bar:SetValue(800);assert(scroll.scrollOffset==800)
    child:SetHeight(300);scroll:UpdateWorkbenchScroll();assert(scroll.scrollOffset==100 and bar.maximum==100)
    child:SetHeight(150);scroll:UpdateWorkbenchScroll();assert(scroll.scrollOffset==0 and not bar:IsShown())
end)
test('flat horizontal bar shares the restrained thumb styling without scale slider ticks',function()
    local f,scroll=fixture();local bar=f.addon:CreateWorkbenchScrollBar(scroll,'HORIZONTAL')
    bar:SetSize(300,10);bar:UpdateExtent(900,300);assert(bar.maximum==600 and bar.thumbTexture:GetWidth()==100)
    bar:SetValue(100);bar.forward:Click();assert(bar.value==140)
    bar.back:Click();assert(bar.value==100)
end)
test('track gaps page toward the clicked side and resize changes the page size',function()
    local f,scroll,child=fixture();local bar=scroll.workbenchBar
    assert(bar.pageBack and bar.pageForward,'track gaps have no directional paging controls')
    bar:SetValue(400);bar.pageBack.scripts.OnMouseDown(bar.pageBack,'LeftButton');assert(bar:GetValue()==200)
    bar.pageForward.scripts.OnMouseDown(bar.pageForward,'LeftButton');assert(bar:GetValue()==400)
    scroll:SetHeight(100);bar.pageBack.scripts.OnMouseDown(bar.pageBack,'LeftButton');assert(bar:GetValue()==300)
    bar.pageForward.scripts.OnMouseDown(bar.pageForward,'RightButton');assert(bar:GetValue()==300)
    bar:SetValue(20);bar.pageBack.scripts.OnMouseDown(bar.pageBack,'LeftButton');assert(bar:GetValue()==0)
    local h=f.addon:CreateWorkbenchScrollBar(scroll,'HORIZONTAL');h:UpdateExtent(900,300);h:SetValue(400)
    h.pageBack.scripts.OnMouseDown(h.pageBack,'LeftButton');assert(h:GetValue()==100)
    h.pageForward.scripts.OnMouseDown(h.pageForward,'LeftButton');assert(h:GetValue()==400)
end)
test('owned thumb dragging follows pointer direction and clamps both axes',function()
    local f,scroll=fixture();local bar=scroll.workbenchBar;bar:SetSize(10,200);bar:UpdateExtent(1000,200)
    assert(bar.thumbButton,'native reversed thumb is still active')
    local x,y=100,500;f.env.GetCursorPosition=function() return x,y end;f.env.IsMouseButtonDown=function() return true end
    bar:SetValue(200);bar.thumbButton.scripts.OnMouseDown(bar.thumbButton,'LeftButton');y=480;bar.thumbButton.scripts.OnUpdate(bar.thumbButton)
    assert(bar:GetValue()>200 and bar.thumbTexture.point[3]<0)
    y=900;bar.thumbButton.scripts.OnUpdate(bar.thumbButton);assert(bar:GetValue()==0)
    bar.thumbButton.scripts.OnMouseUp(bar.thumbButton);assert(bar.dragStart==nil)
    local h=f.addon:CreateWorkbenchScrollBar(scroll,'HORIZONTAL');h:SetSize(300,10);h:UpdateExtent(900,300)
    h:SetValue(100);h.thumbButton.scripts.OnMouseDown(h.thumbButton,'LeftButton');x=120;h.thumbButton.scripts.OnUpdate(h.thumbButton);assert(h:GetValue()>100)
end)
test('thumb repaint is owned by value updates after content grows',function()
    local _,scroll,child=fixture();local bar=scroll.workbenchBar
    bar:SetSize(10,200);bar:UpdateExtent(1000,200);bar:SetValue(200)
    child:SetHeight(1800);scroll:UpdateWorkbenchScroll()
    -- Consumer script replacement/reflow must not own the thumb repaint.
    bar.hooks=bar.hooks or {};bar.hooks.OnValueChanged=nil
    local before=bar.thumbTexture.point[3];bar:SetValue(600)
    assert(scroll.scrollOffset==600 and bar.thumbTexture.point[3]<before,'content moved but the thumb froze')
end)
test('reentrant scroll range changes keep the latest thumb extent',function()
    local f,scroll=fixture();local bar=scroll.workbenchBar;bar:SetSize(10,200);local reentered=false
    f.addon:SetUIScript(bar,'OnValueChanged',function()
        if not reentered then reentered=true;bar:UpdateExtent(2000,200) end
    end)
    bar:UpdateExtent(500,200)
    assert(bar.scrollRange==1800 and bar.pageSize==200 and bar.thumbLength==20,'outer reflow overwrote the latest thumb geometry')
end)
test('unchanged scroll extents do not rewrite the native text scroll offset',function()
    local _,scroll=fixture();local native=scroll.SetVerticalScroll;local writes=0
    scroll.GetVerticalScroll=function(self) return self.scrollOffset or 0 end
    scroll.SetVerticalScroll=function(self,value) writes=writes+1;native(self,value) end
    for i=1,120 do scroll:UpdateWorkbenchScroll() end
    assert(writes==0,'idle extent checks repeatedly invalidate native scrolling')
    scroll.workbenchBar:SetValue(100);assert(writes==1 and scroll.scrollOffset==100)
    for i=1,120 do scroll:UpdateWorkbenchScroll() end;assert(writes==1)
end)
finish()
