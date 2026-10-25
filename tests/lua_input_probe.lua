local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local create=f.env.CreateFrame
    f.env.CreateFrame=function(kind,...)
        local frame=create(kind,...)
        if kind=='EditBox' then
            -- Native font reflow may disturb its insertion point. The dialog
            -- must restore that point without rewriting the diagnostic text.
            frame.SetFontObject=function(self,font) self.fontObject=font;self.fontState={path='Fonts\\FRIZQT__.TTF',size=12,flags=''};self.fontChanges=(self.fontChanges or 0)+1;if self.text then self:SetCursorPosition(#self.text) end end
            frame.SetFont=function(self,font,size,flags) self.font={font,size,flags};self.fontState={path=font,size=size,flags=flags};self.fontChanges=(self.fontChanges or 0)+1;if self.text then self:SetCursorPosition(#self.text) end;return true end
            frame.SetScript=function() error('raw native comparison attached an input script') end
            frame.HookScript=function() error('raw native comparison attached an input hook') end
        end
        return frame
    end
    local file=io.open('UI/lua_input_probe.lua');if file then file:close();f.load('UI/lua_input_probe.lua') end
    assert(type(f.addon.ShowLuaInputProbe)=='function','isolated native input comparison missing')
    return f,f.addon
end
test('isolated native probe uses a script-free direct multiline scroll child and stock font',function()
    local f,a=fixture();local original={source='USER_SOURCE_UNTOUCHED'};a.luaInputEditor=original
    local d=a:ShowLuaInputProbe();assert(d.active and d.frame:IsShown() and d.chrome and d.chrome.drag,'themed movable probe did not open')
    assert(d.edit:GetParent()==d.scroll and d.scroll:GetScrollChild()==d.edit and d.scroll.workbenchBar==nil,'probe did not isolate the native scroll-child path')
    assert(d.edit.multiLine and not d.edit.autoFocus and d.edit.mouseEnabled and d.edit.altArrowKeyMode==false,'native input setup changed')
    assert(d.edit.point[1]=='TOPLEFT' and not d.edit.allPoints and d.edit:GetHeight()==1,'native multiline height is constrained')
    assert(next(d.edit.scripts)==nil and next(d.edit.hooks or {})==nil,'raw input retains callbacks/hooks')
    assert(d.fontMode=='stock' and d.edit.fontObject=='ChatFontNormal' and d.fontState:GetText()=='Stock font','initial font state is unclear')
    assert(d.edit:GetText()=='first line: 0123456789\nsecond line: abcdefghij\nthird line: 0123456789' and d.edit:HasFocus(),'fixed comparison text/focus missing')
    assert(a.luaInputEditor==original and original.source=='USER_SOURCE_UNTOUCHED','probe changed the active editor owner')
end)
test('native font buttons preserve the same editable sample and insertion point',function()
    local _,a=fixture();local d=a:ShowLuaInputProbe();local input=d.edit;input:SetText('changed sample\nsecond');input:SetCursorPosition(7)
    local set=input.SetText;local writes=0;input.SetText=function(self,...) writes=writes+1;return set(self,...) end
    d.rmFont:Click();assert(d.edit==input and d.fontMode=='rm' and d.fontState:GetText()=='RM font','RM font toggle state missing')
    assert(input.font[1]=='Interface\\AddOns\\rotationmaster\\Fonts\\Inconsolata-Regular.ttf' and input.font[2]==12,'RM font did not use the editor font')
    assert(input:GetCursorPosition()==7 and input:GetText()=='changed sample\nsecond' and input:HasFocus(),'font switch changed sample/caret/focus')
    d.stockFont:Click();assert(d.fontMode=='stock' and d.fontState:GetText()=='Stock font' and input.fontObject=='ChatFontNormal','stock font did not return')
    assert(input:GetCursorPosition()==7 and input:GetText()=='changed sample\nsecond' and writes==0,'font comparison rewrote the sample or caret')
end)
test('native comparison close and reopen retire stale font callbacks without retaining source',function()
    local _,a=fixture();local d=a:ShowLuaInputProbe();local stale=d.rmFont:GetScript('OnClick');local staleClose=d.close:GetScript('OnClick');local oldSession=d.session
    d.edit:SetText('temporary edit');d.edit:SetCursorPosition(4);local changes=d.edit.fontChanges;d.close:Click()
    assert(not d.active and not d.frame:IsShown() and not d.edit:HasFocus(),'close retained native focus/session')
    stale();assert(d.edit.fontChanges==changes and d.edit:GetCursorPosition()==4,'closed dialog accepted stale font action')
    local again=a:ShowLuaInputProbe();assert(again==d and d.session~=oldSession and d.fontMode=='stock','reopen did not reuse a fresh isolated session')
    assert(d.edit:GetText()=='first line: 0123456789\nsecond line: abcdefghij\nthird line: 0123456789','reopen persisted edited sample')
    changes=d.edit.fontChanges;stale();assert(d.edit.fontChanges==changes and d.fontMode=='stock','old session changed reopened dialog')
    staleClose();assert(d.active and d.frame:IsShown(),'old session closed reopened dialog')
    d.rmFont:Click();assert(d.fontMode=='rm','new session font button is inactive');d:Hide();assert(not d.active and not d.edit:HasFocus())
end)
finish()
