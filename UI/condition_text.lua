local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- Oversized expressions remain fully inspectable/copyable without letting a
-- footer displace the condition tree or adding a scrollbar to that footer.
function addon:ShowConditionText(value,heading,copyLinks)
    if type(value)~='string' then return end
    local dialog=self.conditionTextWindow
    if not dialog then
        dialog={frame=CreateFrame('Frame',nil,UIParent)};self.conditionTextWindow=dialog
        local frame=dialog.frame;frame:SetSize(700,400);frame:SetPoint('CENTER');frame:SetToplevel(true);frame:EnableMouse(true)
        local title=frame:CreateFontString(nil,'OVERLAY','GameFontNormal');title:SetPoint('TOPLEFT',12,-8);dialog.title=title
        dialog.chrome=self:CreateWorkbenchDialogChrome(frame,title)
        local scroll=addon:CreateWorkbenchScrollFrame(frame);scroll:SetPoint('TOPLEFT',12,-36);scroll:SetSize(660,300);dialog.scroll=scroll
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
        dialog.copy=addon:CreateWorkbenchButton(frame,L['Copy full condition'],150);dialog.copy:SetPoint('BOTTOMLEFT',12,26);addon:SetUIScript(dialog.copy,'OnClick',copy)
        dialog.close=addon:CreateWorkbenchIconButton(frame,'close',L['Close']);dialog.close:SetPoint('TOPRIGHT',-6,-6);addon:SetUIScript(dialog.close,'OnClick',function() frame:Hide() end)
        addon:SetUIScript(edit,'OnEscapePressed',function() frame:Hide() end);addon:SetUIScript(frame,'OnHide',function() edit:ClearFocus() end)
        function dialog:Show() frame:Show() end
        function dialog:Hide() frame:Hide() end
        function dialog:SetText(text) self.text=text;setting=true;edit:SetText(text);setting=false;resize();copy() end
        addon.HideOnEscape(dialog)
    end
    -- Release-page reports may offer a bounded set of exact URL selections.
    -- Other report users always restore the original scroll area and controls.
    dialog.linkButtons=dialog.linkButtons or {}
    for _,button in ipairs(dialog.linkButtons)do button:Hide();addon:SetUIScript(button,'OnClick',nil)end
    local count=type(copyLinks)=='table' and math.min(#copyLinks,8)or 0
    dialog.scroll:SetHeight(300-math.ceil(count/3)*28)
    for i=1,count do
        local entry=copyLinks[i];local button=dialog.linkButtons[i]
        if not button then button=addon:CreateWorkbenchButton(dialog.frame,'',210);dialog.linkButtons[i]=button end
        button:ClearAllPoints();button:SetPoint('BOTTOMLEFT',12+((i-1)%3)*220,54+math.floor((i-1)/3)*28)
        button:SetText(entry.label);button:Show()
        addon:SetUIScript(button,'OnClick',function()
            if dialog.text~=value then return end
            dialog.edit:SetFocus();dialog.edit:SetCursorPosition(entry.first);dialog.edit:HighlightText(entry.first,entry.last)
            dialog.scroll:SetVerticalScroll(math.max(0,(entry.line-1)*14))
        end)
    end
    dialog.chrome:SetContext(heading or L['Full condition text'],L['Report'],'');dialog.copy:SetText(heading and L['Copy report'] or L['Copy full condition'])
    dialog:Show();dialog:SetText(value);return dialog
end
