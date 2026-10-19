local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();dofile('tests/fixtures/native_ui.lua')(f.env)
    local ace=f.libraries['AceGUI-3.0'];local constructors=ace.constructors;local stub=f.env.LibStub
    f.env.LibStub=setmetatable({NewLibrary=function() return ace end},{__call=function(_,...) return stub(...) end})
    f.env.geterrorhandler=function() return error end
    f.env.table=setmetatable({wipe=function(value) for key in pairs(value) do value[key]=nil end;return value end},{__index=table})
    local create=f.env.CreateFrame;f.env.CreateFrame=function(...)
        local frame=create(...);local size=frame.SetSize
        function frame:SetSize(width,height) if self.width~=width or self.height~=height then size(self,width,height) end end
        return frame
    end
    f.load('Libs/AceGUI-3.0/AceGUI-3.0.lua')
    for kind,build in pairs(constructors) do ace:RegisterWidgetType(kind,build,1) end
    return f
end
test('condition native list owns layout and propagates measured child heights',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup();group:SetWidth(320);group:SetLayout('List')
    local first=a:CreateConditionEditBox();first:SetLabel('First');first:SetFullWidth(true)
    local second=a:CreateConditionCheckBox();second:SetLabel('Second');second:SetFullWidth(true)
    group:AddChild(first);group:AddChild(second);group:DoLayout()
    assert(first.frame:GetWidth()==320 and second.frame:GetWidth()==320,'list did not size full-width children')
    assert(second.frame.point[5]<first.frame.point[5] and group.frame:GetHeight()>=68,'list overlapped rows')
    assert(first.parent==group and second.parent==group,'legacy child ownership missing')
end)
test('condition table sizes fixed and remaining columns',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup();group:SetWidth(320);group:SetLayout('Table');group:SetUserData('table',{columns={44,1}})
    local first=a:CreateConditionCheckBox();first:SetHeight(44)
    local second=a:CreateConditionEditBox();second:SetLabel('Spell');second:SetFullWidth(true)
    group:AddChild(first);group:AddChild(second);group:DoLayout()
    assert(first.frame:GetWidth()==44 and second.frame:GetWidth()==272,'table lost fixed/remaining columns')
    assert(second.frame.point[5]==first.frame.point[5] and second.frame.point[4]>first.frame.point[4],'table columns overlap')
end)
test('releasing native layout children discards pending text without callbacks',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup();local child=a:CreateConditionEditBox();local called=0
    child:SetText('Before');child:SetCallback('OnEnterPressed',function() called=called+1 end);group:AddChild(child)
    child.editbox:SetText('Pending');child.editbox.scripts.OnTextChanged(child.editbox,true)
    f.libraries['AceGUI-3.0'].Release=function(_,widget) widget.isQueuedForRelease=true;widget:OnRelease() end
    group:ReleaseChildren();assert(called==0 and #group.children==0 and not child:IsPending(),'release committed abandoned edits')
end)
test('pooled root hiding cannot commit child focus loss before recursive release',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup();local child=a:CreateConditionEditBox();local called=0
    child:SetText('Before');child:SetCallback('OnEnterPressed',function() called=called+1 end);group:AddChild(child)
    child.editbox:SetText('Pending');child.editbox.scripts.OnTextChanged(child.editbox,true)
    group.frame:SetScript('OnHide',function() child.editbox.scripts.OnEditFocusLost(child.editbox) end)
    f.libraries['AceGUI-3.0']:Release(group)
    assert(called==0,'parent release committed child focus loss before its own release')
end)
test('zero-width table columns keep intrinsic content sizing beside numeric values',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup();group:SetWidth(500);group:SetLayout('Table');group:SetUserData('table',{columns={0,75}})
    local first=a:CreateConditionDropdown();first:SetWidth(180);first:SetFullWidth(true)
    local second=a:CreateConditionEditBox();second:SetFullWidth(true);group:AddChild(first);group:AddChild(second);group:DoLayout()
    assert(first.frame:GetWidth()==180 and second.frame:GetWidth()==75,'zero column incorrectly consumed free space')
end)
test('pooled groups recover layout after a custom child throws during geometry',function()
    local f=fixture();local a=f.addon;local ace=f.libraries['AceGUI-3.0'];local group=a:CreateConditionGroup()
    local child=a:CreateConditionEditBox();local width=child.SetWidth
    child.SetWidth=function() error('custom field geometry failed') end
    assert(not pcall(group.AddChild,group,child),'custom geometry did not fail')
    child.SetWidth=width;ace:Release(group)
    local reused=a:CreateConditionGroup();assert(reused==group,'regression did not reuse the failed group')
    reused:SetWidth(320);local replacement=a:CreateConditionCheckBox();replacement:SetFullWidth(true);reused:AddChild(replacement)
    assert(replacement.frame:GetWidth()==320 and reused.frame:GetHeight()==24,'pooled group retained the failed layout lock')
end)
test('one native layout pass visits a deep group chain linearly',function()
    local f=fixture();local a=f.addon;local root=a:CreateConditionGroup();local current=root;local groups={root}
    for _=2,10 do local child=a:CreateConditionGroup();child:SetFullWidth(true);current:AddChild(child);groups[#groups+1]=child;current=child end
    current:AddChild(a:CreateConditionCheckBox());local passes=0
    for _,group in ipairs(groups) do local finished=group.LayoutFinished;group.LayoutFinished=function(self,...) passes=passes+1;return finished(self,...) end end
    root:DoLayout();assert(passes<=20,'native layout repeated deep subtrees: '..passes)
end)
test('legacy layout height changes propagate to a native parent',function()
    local f=fixture();local a=f.addon;local ace=f.libraries['AceGUI-3.0'];local height=20
    ace:RegisterLayout('ReviewLegacy',function(content) content.obj:LayoutFinished(content:GetWidth(),height) end)
    local parent=a:CreateConditionGroup();local child=a:CreateConditionGroup();child:SetLayout('ReviewLegacy');parent:AddChild(child)
    assert(parent.frame:GetHeight()==20);height=80;child:DoLayout()
    assert(parent.frame:GetHeight()==80,'native parent retained the previous legacy child height')
end)
finish()
