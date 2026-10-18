local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- Oversized expressions remain fully inspectable/copyable without letting a
-- footer displace the condition tree or adding a scrollbar to that footer.
function addon:ShowConditionText(value,heading)
    if type(value)~='string' then return end
    local dialog=self.conditionTextWindow
    if not dialog then
        dialog={frame=CreateFrame('Frame',nil,UIParent)};self.conditionTextWindow=dialog
        local frame=dialog.frame;frame:SetSize(700,400);frame:SetPoint('CENTER');frame:SetToplevel(true);frame:EnableMouse(true)
        local title=frame:CreateFontString(nil,'OVERLAY','GameFontNormal');title:SetPoint('TOPLEFT',12,-8);dialog.title=title
        local scroll=addon:CreateWorkbenchScrollFrame(frame);scroll:SetPoint('TOPLEFT',12,-36);scroll:SetSize(660,320);dialog.scroll=scroll
        local edit=CreateFrame('EditBox',nil,scroll);dialog.edit=edit;edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetFontObject('GameFontHighlightSmall');edit:SetPoint('TOPLEFT');edit:SetWidth(650);edit:SetTextInsets(4,4,4,4);scroll:SetScrollChild(edit)
        local setting=false
        local function resize()
            local lines=edit.GetNumLines and edit:GetNumLines() or math.ceil(#(edit:GetText() or '')/80)
            edit:SetHeight(math.max(24,lines*14+16));scroll:UpdateScrollChildRect()
        end
        addon:SetUIScript(edit,'OnTextChanged',function()
            if not setting and edit:GetText()~=dialog.text then setting=true;edit:SetText(dialog.text or '');setting=false end
            resize()
        end)
        local function copy() edit:SetFocus();edit:SetCursorPosition(0);edit:HighlightText(0,-1);scroll:SetVerticalScroll(0) end
        dialog.copy=addon:CreateWorkbenchButton(frame,L['Copy full condition'],150);dialog.copy:SetPoint('BOTTOMLEFT',12,10);addon:SetUIScript(dialog.copy,'OnClick',copy)
        dialog.close=addon:CreateWorkbenchIconButton(frame,'close',L['Close']);dialog.close:SetPoint('TOPRIGHT',-6,-6);addon:SetUIScript(dialog.close,'OnClick',function() frame:Hide() end)
        addon:SetUIScript(edit,'OnEscapePressed',function() frame:Hide() end);addon:SetUIScript(frame,'OnHide',function() edit:ClearFocus() end)
        function dialog:Show() frame:Show() end
        function dialog:Hide() frame:Hide() end
        function dialog:SetText(text) self.text=text;setting=true;edit:SetText(text);setting=false;resize();copy() end
        addon.HideOnEscape(dialog)
    end
    dialog.title:SetText(heading or L['Full condition text']);dialog.copy:SetText(heading and L['Copy report'] or L['Copy full condition'])
    dialog:Show();dialog:SetText(value);return dialog
end
