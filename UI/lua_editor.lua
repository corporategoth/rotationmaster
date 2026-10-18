local addon_name,addon=...
local providers={}
function addon:ListLuaEditorProviders()
    local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
    local entries={{value='auto',text=L['Automatic']},{value='native',text=L['Built In syntax highlighting']},{value='plain',text=L['Plain text']}}
    local names={};for name in pairs(providers) do names[#names+1]=name end;table.sort(names)
    for _,name in ipairs(names) do entries[#entries+1]={value=name,text=name} end
    return entries
end
local function hideFrame(frame)
    pcall(function() if frame and type(frame.Hide)=='function' then frame:Hide() end end)
end
local function usableFrame(frame)
    local ok,result=pcall(function() return frame and type(frame.SetParent)=='function' and type(frame.SetAllPoints)=='function' and type(frame.Hide)=='function' end)
    return ok and result
end
-- Optional editor addons may register this RM-owned contract. No dependency or
-- undocumented third-party globals are required by the native fallback.
function addon:RegisterLuaEditorProvider(name,create)
    if type(name)~='string' or #name>128 or not name:find('%S') or name=='native' or name=='plain' or name=='auto' or type(create)~='function' then return false end
    providers[name]=create;return true
end
function addon:CreateWorkbenchLuaEditor(parent,changed,valid,preferred)
    preferred=preferred or self.db.profile.lua_editor or 'auto'
    if preferred=='auto' then
        local names={};for name in pairs(providers) do names[#names+1]=name end;table.sort(names);preferred=names[1] or 'native'
    end
    if preferred and providers[preferred] then
        local host=CreateFrame('Frame',nil,parent)
        local ok,control=pcall(providers[preferred],host,changed,valid)
        if ok and type(control)=='table' and usableFrame(control.frame) and type(control.GetText)=='function' and type(control.SetText)=='function' and type(control.Release)=='function' then
            local c={frame=host,provider=preferred,inner=control,lastText=''}
            local function fallback()
                pcall(c.inner.Release,c.inner);hideFrame(c.inner.frame)
                c.inner=addon:CreateWorkbenchLuaEditor(host,changed,valid,'native');c.inner.frame:SetAllPoints(host);c.provider='native';c.edit=c.inner.edit;c.inner:SetText(c.lastText)
            end
            ---@return string
    function c:GetText()
                local read,text=pcall(self.inner.GetText,self.inner)
                if not read or type(text)~='string' then fallback();text=self.inner:GetText() end
                self.lastText=text;return text
            end
            function c:SetText(text)
                self.lastText=text or '';if not pcall(self.inner.SetText,self.inner,self.lastText) then fallback() end
            end
            function c:Release() if self.released then return end;self.released=true;pcall(self.inner.Release,self.inner);self.frame:Hide() end
            local attached=pcall(function() control.frame:SetParent(host);control.frame:SetAllPoints(host) end)
            if not attached then fallback() end
            return c
        end
        if ok and type(control)=='table' then if type(control.Release)=='function' then pcall(control.Release,control) end;hideFrame(control.frame) end
        host:Hide()
    end
    local c={frame=CreateFrame('Frame',nil,parent),provider='native',valid=valid,changed=changed}
    c.scroll=self:CreateWorkbenchScrollFrame(c.frame);c.scroll:SetPoint('TOPLEFT');c.edit=CreateFrame('EditBox',nil,c.scroll);c.edit:SetMultiLine(true);c.edit:SetAutoFocus(false);c.edit:EnableMouse(true);c.edit:EnableKeyboard(true);c.edit:SetAltArrowKeyMode(false);c.edit:SetBlinkSpeed(.5);c.edit:SetTextColor(1,1,1);c.edit:SetJustifyH('LEFT');c.edit:SetJustifyV('TOP');c.edit:SetFontObject('GameFontHighlightSmall');c.edit:SetTextInsets(6,6,4,4);c.edit:SetMaxLetters(0);c.edit:SetPoint('TOPLEFT');c.scroll:SetScrollChild(c.edit)
    addon:SetUIScript(c.edit,'OnMouseDown',function(_,button) if button=='LeftButton' and not c.released and c.valid() and not c.edit:HasFocus() then c.edit:SetFocus() end end)
    c.scroll:EnableMouse(true);addon:SetUIScript(c.scroll,'OnMouseDown',function(_,button) if button=='LeftButton' and not c.released and c.valid() and not c.edit:HasFocus() then c.edit:SetFocus() end end)
    c.measure=c.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');c.measure:SetWordWrap(true);c.measure:Hide()
    if c.edit.SetFont then c.edit:SetFont('Interface\\AddOns\\'..addon_name..'\\Fonts\\Inconsolata-Regular.ttf',12,'') end
    if c.measure.SetFont then c.measure:SetFont('Interface\\AddOns\\'..addon_name..'\\Fonts\\Inconsolata-Regular.ttf',12,'') end
    function c:Layout()
        local width=math.max(1,self.frame:GetWidth()-24);local height=math.max(1,self.frame:GetHeight());if self.scroll:GetWidth()~=self.frame:GetWidth() or self.scroll:GetHeight()~=height then self.scroll:SetSize(self.frame:GetWidth(),height) end;if self.edit:GetWidth()~=width then self.edit:SetWidth(width) end;self.measure:SetWidth(math.max(1,width-12));self.measure:SetText(self:GetText());local editHeight=math.max(height,self.measure:GetStringHeight()+16);if self.edit:GetHeight()~=editHeight then self.edit:SetHeight(editHeight) end;self.scroll:UpdateWorkbenchScroll()
    end
    ---@return string
    function c:GetText()
        -- FAIAP's cached GetText can lag a keystroke until its coloring update.
        -- Apply and callback switches must always read the current source.
        if self.syntax then local text=self.syntax.decode(self.nativeGetText(self.edit));return type(text)=='string' and text or '' end
        return self.edit:GetText() or ''
    end
    function c:SetText(text) self.setting=true;self.edit:SetText(text or '');self.setting=false;self:Layout() end
    function c:SetChanged(callback) self.changed=callback end
    function c:Acquire(callback,ownerValid)
        self.released=false;self.changed=callback;self.valid=ownerValid
        if self.syntax then pcall(self.syntax.enable,self.edit,nil,4) end
    end
    function c:Release()
        if self.released then return end;self.released=true;self.edit:ClearFocus()
        if self.syntax then pcall(self.syntax.disable,self.edit) end
        self.changed=nil;self.valid=function() return false end
        self.edit.GetText=self.nativeGetText;self.edit.SetText=self.nativeSetText
        for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do self.edit:SetScript(event,self.nativeScripts[event]) end
        self.edit:SetText('');self.frame:Hide()
    end
    addon:SetUIScript(c.edit,'OnTextChanged',function() c:Layout();if not c.setting and not c.released and c.valid() and c.changed then c.changed(c:GetText()) end end)
    addon:SetUIScript(c.frame,'OnSizeChanged',function() c:Layout() end)
    addon:SetUIScript(c.edit,'OnMouseWheel',function(_,delta) c.scroll.workbenchBar:SetValue(c.scroll.workbenchBar:GetValue()-delta*36) end);c.edit:EnableMouseWheel(true)
    addon:SetUIScript(c.edit,'OnCursorChanged',function(_,_,y,_,height) local bar=c.scroll.workbenchBar;local top=-y;if top<bar:GetValue() then bar:SetValue(top) elseif top+height>bar:GetValue()+c.scroll:GetHeight() then bar:SetValue(top+height-c.scroll:GetHeight()) end end)
    c.edit:SetText('')
    c.nativeGetText=c.edit.GetText;c.nativeSetText=c.edit.SetText;c.nativeScripts={}
    for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do c.nativeScripts[event]=c.edit:GetScript(event) end
    local syntax=preferred~='plain' and self.LuaSyntax
    if syntax then
        local getText,setText=c.edit.GetText,c.edit.SetText;local scripts={};for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do scripts[event]=c.edit:GetScript(event) end
        local ok=pcall(syntax.enable,c.edit,nil,4)
        if ok then c.syntax=syntax else
            pcall(syntax.disable,c.edit);c.edit.GetText=getText;c.edit.SetText=setText
            for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do c.edit:SetScript(event,scripts[event]) end
        end
    end
    c:SetText('');return c
end
