-- Native frame primitives are external; report selection/rendering/clear stay real.
local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local addon={}
local env=setmetatable({}, {__index=_G})
local frames={}
local function frame(kind,name,parent,template)
    local f={kind=kind,name=name,parent=parent,template=template,scripts={},width=760,height=520,text=''}
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:SetWidth(w) self.width=w end
    function f:SetHeight(h) self.height=h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:SetPoint(...) self.point={...} end
    function f:SetAllPoints() end
    function f:SetFrameStrata() end
    function f:SetMovable() end
    function f:SetResizable() end
    function f:SetResizeBounds() end
    function f:EnableMouse(value) self.mouseEnabled=value end
    function f:RegisterForDrag() end
    function f:SetScript(name,fn) self.scripts[name]=fn end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:StartSizing() end
    function f:Show() self.visible=true end
    function f:Hide() self.visible=false end
    function f:SetMultiLine() end
    function f:SetAutoFocus() end
    function f:SetFontObject() end
    function f:SetTextInsets() end
    function f:SetText(text) self.highlighted=false;self.text=text;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
    function f:GetText() return self.text end
    function f:SetFocus() self.focus=true end
    function f:ClearFocus() self.focus=false end
    function f:HighlightText(start,stop) self.highlighted=true;self.selection={start,stop} end
    function f:SetCursorPosition(value) self.cursor=value end
    function f:SetVerticalScroll(value) self.scrollOffset=value end
    function f:GetNumLines() local _,n=self.text:gsub('\n','');return n+1 end
    function f:GetFont() return 'font',12 end
    function f:SetScrollChild(child) self.child=child end
    function f:UpdateScrollChildRect() end
    function f:CreateTexture() local t={};function t:SetAllPoints() end;function t:SetColorTexture() end;return t end
    function f:CreateFontString() return frame('FontString') end
    frames[#frames+1]=f;return f
end
env.CreateFrame=frame;env.UIParent=frame('Frame');env.UISpecialFrames={}
env.ChatFontNormal='font';env.GetTime=function() return 1 end
env.LibStub=function(name)
    assert(name=='AceLocale-3.0','error UI requires '..name)
    return {GetLocale=function() return setmetatable({}, {__index=function(_,key) return key end}) end}
end
local function load(path) local chunk=assert(loadfile(path));setfenv(chunk,env);chunk('rotationmaster',addon) end
load('Diagnostics/errors.lua')
load('UI/errors.lua')
test('error window opens without AceGUI and explains empty state',function()
    addon:ShowErrors()
    assert(addon.errorsWindow.visible)
    assert(addon.errorsWindow.report:GetText():find('No Rotation Master errors',1,true))
end)
test('error report navigation copy and clear use only RM records',function()
    addon.Diagnostics:Call({},function() error('first problem',0) end)
    addon.Diagnostics:Call({},function() error('second problem',0) end)
    addon:ShowErrors()
    local w=addon.errorsWindow
    assert(w.report:GetText():find('second problem',1,true))
    w.previous.scripts.OnClick()
    assert(w.report:GetText():find('first problem',1,true))
    w.next.scripts.OnClick()
    assert(w.report:GetText():find('second problem',1,true))
    w.copy.scripts.OnClick()
    assert(w.report.focus and w.report.highlighted)
    w.clear.scripts.OnClick()
    assert(#addon.Diagnostics:GetReports()==0)
    assert(w.report:GetText():find('No Rotation Master errors',1,true))
end)
test('original custom error text is opt-in and resets when reopening',function()
    addon.Diagnostics:Call({customCode=true},function() error('PRIVATE custom detail',0) end)
    addon:ShowErrors()
    local w=addon.errorsWindow
    assert(not w.report:GetText():find('PRIVATE',1,true))
    w.original.scripts.OnClick()
    assert(w.report:GetText():find('PRIVATE',1,true))
    addon:ShowErrors()
    assert(not w.report:GetText():find('PRIVATE',1,true))
end)
test('copy has a positioned mouse-selectable editor and survives unchanged text notifications',function()
    addon:ShowErrors()
    local w=addon.errorsWindow
    w.copy.scripts.OnClick()
    assert(w.report.point and w.report.mouseEnabled,'report editor is not positioned/selectable')
    assert(w.report.selection[1]==0 and w.report.selection[2]==-1,'copy must explicitly select all text')
    w.report.scripts.OnTextChanged(w.report,false)
    assert(w.report.highlighted,'unchanged text notification cleared copy selection')
end)
finish()
