local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- Text-only transfers never execute Lua. The caller validates the candidate
-- and applies it only while its original form and database are still alive.
function addon:ShowSettingsTextTransfer(p,title,text,apply,options)
    local d=p.textDialog
    if not d then
        d={frame=CreateFrame('Frame',nil,UIParent)};p.textDialog=d;d.frame:SetSize(570,430);d.frame:SetPoint('CENTER');d.frame:SetFrameStrata('FULLSCREEN_DIALOG');d.frame:EnableMouse(true);d.frame:SetToplevel(true);addon:MakeWindowOpaque(d.frame)
        d.title=d.frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=addon:CreateWorkbenchDialogChrome(d.frame,d.title)
        d.scroll=addon:CreateWorkbenchScrollFrame(d.frame);d.scroll:SetPoint('TOPLEFT',12,-40);d.scroll:SetSize(520,300)
        d.input=CreateFrame('EditBox',nil,d.scroll);d.input:SetFontObject('GameFontHighlightSmall');d.input:SetMultiLine(true);d.input:SetAutoFocus(false);d.input:SetMaxLetters(131072);d.input:SetSize(510,300);d.input:SetPoint('TOPLEFT');d.scroll:SetScrollChild(d.input)
        d.original=d.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.original:SetPoint('TOPLEFT',12,-36);d.original:SetSize(546,22);d.original:SetJustifyH('LEFT')
        d.destination=addon:CreateWorkbenchCheckBox(d.frame,L['Replace selected entry'],210);d.destination:SetPoint('TOPLEFT',12,-62)
        d.nameLabel=d.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.nameLabel:SetPoint('TOPLEFT',232,-62);d.nameLabel:SetSize(54,24);d.nameLabel:SetText(L['Name'])
        d.name=addon:CreateWorkbenchEditBox(d.frame);d.name:SetPoint('TOPLEFT',290,-62);d.name:SetSize(268,24);d.name:SetMaxLetters(256)
        d.status=d.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.status:SetPoint('TOPLEFT',12,-346);d.status:SetSize(546,32);d.status:SetWordWrap(true);d.status:SetJustifyH('LEFT')
        d.copy=addon:CreateWorkbenchButton(d.frame,L['Copy'],64);d.copy:SetPoint('BOTTOMLEFT',12,28)
        d.clear=addon:CreateWorkbenchButton(d.frame,L['Clear'],64);d.clear:SetPoint('BOTTOMLEFT',82,28)
        d.apply=addon:CreateWorkbenchButton(d.frame,L['Import'],100);d.apply:SetPoint('BOTTOMRIGHT',-120,28)
        d.cancel=addon:CreateWorkbenchButton(d.frame,L['Cancel'],100);d.cancel:SetPoint('BOTTOMRIGHT',-12,28)
        d.preview=addon:CreateWorkbenchButton(d.frame,L['Preview import'],90);d.preview:SetPoint('BOTTOMLEFT',152,28);d.inspect=addon:CreateWorkbenchButton(d.frame,L['Inspect import'],90);d.inspect:SetPoint('BOTTOMLEFT',248,28)
        d.close=addon:CreateWorkbenchIconButton(d.frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5)
        local function hide() d.frame:Hide() end
        addon:SetUIScript(d.cancel,'OnClick',hide);addon:SetUIScript(d.close,'OnClick',hide);addon:SetUIScript(d.frame,'OnHide',function() d.input:ClearFocus();if d.options and d.options.onClose then d.options.onClose() end end)
        addon:SetUIScript(d.input,'OnSizeChanged',function() d.scroll:UpdateWorkbenchScroll() end)
        addon:SetUIScript(d.input,'OnCursorChanged',function(_,_,y,_,height) local top=-y;local bar=d.scroll.workbenchBar;d.scroll:UpdateWorkbenchScroll();if top<bar:GetValue() then bar:SetValue(top) elseif top+height>bar:GetValue()+d.scroll:GetHeight() then bar:SetValue(top+height-d.scroll:GetHeight()) end end)
        d.input:EnableMouseWheel(true);addon:SetUIScript(d.input,'OnMouseWheel',function(_,delta) local bar=d.scroll.workbenchBar;bar:SetValue(bar:GetValue()-delta*40) end)
        d.frame:Hide()
    end
    d.serial=(d.serial or 0)+1;local serial=d.serial;local token=p.generation
    local function valid() return p:Valid(token) and d.serial==serial and d.frame:IsShown() and (not options or not options.valid or options.valid()) end
    d.chrome:SetContext(title,L['Import/Export'],addon.pretty_name or L['Rotation Master']);d.input:SetText(text or '')
    d.options=options;d.mode=options and options.canReplace and 'replace' or 'new';d.nameDirty=false
    local function destination()
        d.destination:SetText(L['Replace selected entry']);d.destination:SetChecked(d.mode=='replace');if options.canReplace then d.destination:Enable() else d.destination:Disable() end;d.name:EnableMouse(d.mode=='new');d.name:SetTextColor(d.mode=='new' and 1 or .5,d.mode=='new' and 1 or .5,d.mode=='new' and 1 or .5)
        if d.mode=='replace' then d.name:SetText(options.selectedName or '') else d.name:SetText(d.newName or options.fallbackName or '') end
    end
    local function preview()
        if not valid() or not options then return end
        local ok,name=pcall(options.originalName,d.input:GetText());name=ok and type(name)=='string' and name~='' and name or L['Name not supplied']
        d.original:SetText(L['Original name']..': '..name);d.originalName=name
        if not d.nameDirty then d.newName=name~=L['Name not supplied'] and name or options.fallbackName or '' end;destination()
    end
    if options then
        d.original:Show();d.destination:Show();d.nameLabel:Show();d.name:Show();d.newName=options.fallbackName or '';d.scroll:ClearAllPoints();d.scroll:SetPoint('TOPLEFT',12,-98);d.scroll:SetHeight(232);d.input:SetHeight(232)
        addon:SetUIScript(d.destination,'OnClick',function() if valid() and options.canReplace then d.mode=d.mode=='replace' and 'new' or 'replace';destination() end end)
        addon:SetUIScript(d.name,'OnTextChanged',function(_,user) if user and valid() and d.mode=='new' then d.nameDirty=true;d.newName=d.name:GetText() end end)
        addon:SetUIScript(d.name,'OnEscapePressed',function() d.frame:Hide() end)
        addon:SetUIScript(d.input,'OnTextChanged',function(_,user) if user then preview();if options.invalidate then options.invalidate(d) end end end)
        d.status:SetText(L['Choose a new named copy or replace the selected editable entry. Review the destination before importing.'])
    else
        d.original:Hide();d.destination:Hide();d.nameLabel:Hide();d.name:Hide();d.scroll:ClearAllPoints();d.scroll:SetPoint('TOPLEFT',12,-40);d.scroll:SetHeight(300);d.input:SetHeight(300);addon:SetUIScript(d.input,'OnTextChanged',nil);d.status:SetText(L['Copy this text to export. Import replaces the selected settings.'])
    end
    if options and options.requirePreview then d.preview:Show();d.inspect:Show();d.apply:Disable();d.inspect:Disable();addon:SetUIScript(d.preview,'OnClick',function() if valid() then options.preview(d) end end);addon:SetUIScript(d.inspect,'OnClick',function() if valid() then return options.inspect(d) end end) else d.preview:Hide();d.inspect:Hide();d.apply:Enable() end
    addon:SetUIScript(d.clear,'OnClick',function() if valid() then d.input:SetText('');d.input:SetFocus();d.input:SetCursorPosition(0);d.scroll.workbenchBar:SetValue(0);if options then preview();if options.invalidate then options.invalidate(d) end end end end)
    addon:SetUIScript(d.copy,'OnClick',function() if valid() then d.input:SetFocus();d.input:SetCursorPosition(0);d.input:HighlightText(0,-1) end end)
    addon:SetUIScript(d.apply,'OnClick',function()
        if not valid() then return end
        local settings
        if options then local name=d.mode=='new' and d.name:GetText() or options.selectedName;if d.mode=='new' and (not name:find('%S') or #name>256) then d.status:SetText(L['Enter a name first.']);return end;settings={mode=d.mode,name=name,originalName=d.originalName} end
        local result=p:WithSettingsHistory(function() local ok,why=apply(d.input:GetText(),settings);return {ok,why} end);local ok,why=result[1],result[2];if not ok then d.status:SetText(why or L['Invalid import.']);return end
        d.frame:Hide();p:Draw()
    end)
    d.frame:SetFrameLevel(p.frame:GetFrameLevel()+250);d.frame:Show();d.scroll.workbenchBar:SetValue(0);d.scroll:UpdateWorkbenchScroll();addon:RegisterWindowForEscape(d);if options then preview() end;return d
end
