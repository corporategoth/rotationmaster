local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:ShowLuaDebugOutput(control)
    if control.released or not control.valid() then return end
    local d=control.outputWindow
    if not d then
        d=self:CreateWorkbenchTransferShell(760,530);control.outputWindow=d
        d.chrome:SetContext(L['Debug output'],L['Output'],'')
        d.scroll:SetHeight(420);d.input:SetMaxLetters(0);d.input:SetTextInsets(6,6,4,4)
        d.content=CreateFrame('Frame',nil,d.scroll);d.input:ClearAllPoints();d.input:SetParent(d.content);d.input:SetAllPoints(d.content);d.scroll:SetScrollChild(d.content)
        d.measure=d.scroll:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.measure:SetWordWrap(true);d.measure:Hide()
        function d:Layout()
            local width=d.scroll:GetWidth()-22;d.measure:SetWidth(math.max(1,width-12));d.measure:SetHeight(0);d.measure:SetText(d.text or '')
            d.content:SetSize(width,math.max(d.scroll:GetHeight(),d.measure:GetStringHeight()+16));d.scroll:UpdateWorkbenchScroll()
        end
        function d:Refresh()
            local context=control.context or {};local console=control.engine.Query.Console
            local parts={L['Debug output'],tostring(context.name or context.id or ''),context.callback and tostring(context.callback) or ''}
            if control.debugError then parts[#parts+1]=control.debugError elseif console.statusText then parts[#parts+1]=console.statusText end
            parts[#parts+1]=table.concat(console.lines or {},'\n');self.text=table.concat(parts,'\n');self.setting=true;self.input:SetText(self.text);self.setting=false;self:Layout()
        end
        function d:Hide() self.frame:Hide() end
        addon:SetUIScript(d.input,'OnTextChanged',function() if not d.setting and d.input:GetText()~=d.text then d.setting=true;d.input:SetText(d.text or '');d.setting=false end;d:Layout() end)
        addon:SetUIScript(d.copy,'OnClick',function() d.input:SetFocus();d.input:SetCursorPosition(0);d.input:HighlightText(0,-1) end)
        addon:SetUIScript(d.clear,'OnClick',function() control.debugError=nil;control.engine.Query.Console:Clear();control.engine.Query.Console:SetStatus(nil);d:Refresh() end)
        d.apply:SetText(L['Refresh']);addon:SetUIScript(d.apply,'OnClick',function() d:Refresh() end)
        addon:SetUIScript(d.close,'OnClick',function() d:Hide() end);d.cancel:Hide()
        addon:SetUIScript(d.input,'OnEscapePressed',function() d:Hide() end);addon:SetUIScript(d.frame,'OnHide',function() d.input:ClearFocus() end)
        d.input:EnableMouseWheel(true);addon:SetUIScript(d.input,'OnMouseWheel',function(_,delta) d.scroll.workbenchBar:SetValue(d.scroll.workbenchBar:GetValue()-delta*40) end)
    end
    d:Refresh();d.frame:Show();self:RegisterWindowForEscape(d);return d
end
