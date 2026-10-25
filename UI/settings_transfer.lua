local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- Text-only transfers never execute Lua. The caller validates the candidate
-- and applies it only while its original form and database are still alive.
-- Optional Help belongs to one current transfer/report, not its edit actions.
function addon:BindTransferHelp(d,metadata,ownerValid)
    local previous=d.transferHelpLease
    local profile,global,char=self.db.profile,self.db.global,self.db.char
    if ownerValid then
        local ok,current=pcall(ownerValid)
        if not ok or current~=true or d.transferHelpLease~=previous
            or self.db.profile~=profile or self.db.global~=global or self.db.char~=char then return end
    end
    local lease={cleanups={}};d.transferHelpLease=lease
    if previous then for _,clear in ipairs(previous.cleanups) do clear() end end
    if d.transferHelpLease~=lease then return end
    if not metadata then
        if d.help then self:SetUIScript(d.help,'OnClick',nil);d.help:Hide() end
        return
    end
    local extraValid=metadata.valid
    local function base()
        return d.transferHelpLease==lease and not lease.hidden and addon.db.profile==profile and addon.db.global==global and addon.db.char==char
    end
    local function current()
        if not base() or not d.frame:IsShown() or not base() then return false end
        for _,valid in ipairs({ownerValid or false,extraValid or false}) do if valid then
            local ok,value=pcall(valid);if not ok or value~=true or not base() then return false end
        end end
        local shown=d.frame:IsShown();return shown and base()
    end
    local onHide=d.frame:GetScript('OnHide')
    if onHide==d.transferHelpHideWrapper then onHide=d.transferHelpHideOriginal end
    d.transferHelpHideOriginal=onHide
    self:SetUIScript(d.frame,'OnHide',function(...)
        lease.hidden=true
        if onHide then return onHide(...) end
    end)
    d.transferHelpHideWrapper=d.frame:GetScript('OnHide')
    if not d.help then d.help=self:CreateWorkbenchHelpButton(d.frame,L['Help']) end
    if not base() then return end
    d.help:ClearAllPoints();d.help:SetPoint('TOPRIGHT',-31,-5);d.help:SetSize(20,20);d.help.icon:SetSize(18,18);d.help.tooltip=metadata.brief or L['Help'];d.help:Show()
    if not base() then return end
    local sections,heading,owner=metadata.sections,metadata.heading or L['Help'],metadata.owner
    self:SetUIScript(d.help,'OnClick',function()
        if d.transferHelpLease~=lease then return end
        local open=rawget(addon,'OpenWorkbenchHelp')
        if type(open)=='function' then return open(addon,{heading=heading,owner=owner,valid=current,sections=function()
            if type(sections)=='function' then return sections(d) end;return sections or {}
        end}) end
    end)
    if self.BindWorkbenchHelp then
        lease.cleanups[#lease.cleanups+1]=self:BindWorkbenchHelp(d.help,{brief=d.help.tooltip,valid=current})
        for key,brief in pairs(metadata.briefs or {}) do local control=d[key];if control then
            lease.cleanups[#lease.cleanups+1]=self:BindWorkbenchHelp(control,{brief=brief,valid=current})
        end end
    end
end
function addon:TransferHelpBriefs()
    return {copy=L['Help.Transfers.copy'],clear=L['Help.Transfers.clear'],apply=L['Help.Transfers.apply'],cancel=L['Help.Transfers.cancel'],close=L['Help.Transfers.cancel'],destination=L['Help.Transfers.destination'],name=L['Help.Transfers.name'],preview=L['Help.Transfers.preview'],inspect=L['Help.Transfers.inspect']}
end
-- Export and import strings are Base64: a fixed-pitch face keeps the 76-character
-- lines aligned and readable. Shells that show prose (reports, output) keep the
-- proportional face; the transfer windows call this on their own edit box.
local EXPORT_FONT='Interface\\AddOns\\'..addon_name..'\\Fonts\\Inconsolata-Regular.ttf'
local EXPORT_FONT_SIZES={12,11,10,9}
local EXPORT_BOX_MARGIN=12
-- The most letters the box accepts: the plain limit plus one newline per line.
function addon:ExportTextLimit(letters) return letters+math.ceil(letters/self.ExportTextWidth) end
-- Uses Inconsolata at the largest size whose 76-character line fits the box
-- without wrapping, measured rather than assumed. If the file is missing or the
-- client refuses it the box keeps the default font; nothing else changes.
function addon:UseExportFont(d)
    local input=d.input;d.exportFont=nil
    input:SetFontObject('GameFontHighlightSmall')
    if type(input.SetFont)~='function' then return false end
    d.exportProbe=d.exportProbe or d.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.exportProbe:Hide()
    local sample=string.rep('0',self.ExportTextWidth);local limit=input:GetWidth()-EXPORT_BOX_MARGIN;local chosen
    for _,size in ipairs(EXPORT_FONT_SIZES) do
        if input:SetFont(EXPORT_FONT,size,'')==false then break end
        -- A client that cannot load the file keeps the previous face; GetFont says which one is live.
        local path=type(input.GetFont)=='function' and input:GetFont()
        if type(path)=='string' and not path:lower():find('inconsolata',1,true) then break end
        if d.exportProbe:SetFont(EXPORT_FONT,size,'')==false then break end
        d.exportProbe:SetText(sample)
        chosen={size=size,width=d.exportProbe:GetStringWidth()}
        if chosen.width<=limit then break end
    end
    if not chosen then input:SetFontObject('GameFontHighlightSmall');return false end
    d.exportFont=chosen;return true
end
function addon:CreateWorkbenchTransferShell(width,height)
    width,height=width or 570,height or 430
    local d={frame=CreateFrame('Frame',nil,UIParent),sharedTransferShell=true}
    d.frame:SetSize(width,height);d.frame:SetPoint('CENTER');d.frame:SetFrameStrata('FULLSCREEN_DIALOG');d.frame:EnableMouse(true);d.frame:SetToplevel(true);self:MakeWindowOpaque(d.frame)
    d.title=d.frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=self:CreateWorkbenchDialogChrome(d.frame,d.title);d.chromeUpdate=d.frame:GetScript('OnUpdate')
    d.scroll=self:CreateWorkbenchScrollFrame(d.frame);d.scroll:SetPoint('TOPLEFT',12,-40);d.scroll:SetSize(width-50,height-130)
    d.input=CreateFrame('EditBox',nil,d.scroll);d.input:SetFontObject('GameFontHighlightSmall');d.input:SetMultiLine(true);d.input:SetAutoFocus(false);d.input:SetMaxLetters(self:ExportTextLimit(131072));d.input:SetSize(width-60,height-130);d.input:SetPoint('TOPLEFT');d.scroll:SetScrollChild(d.input)
    d.copy=self:CreateWorkbenchButton(d.frame,L['Copy'],64);d.copy:SetPoint('BOTTOMLEFT',12,28)
    d.clear=self:CreateWorkbenchButton(d.frame,L['Clear'],64);d.clear:SetPoint('BOTTOMLEFT',82,28)
    d.apply=self:CreateWorkbenchButton(d.frame,L['Import'],100);d.apply:SetPoint('BOTTOMRIGHT',-120,28)
    d.cancel=self:CreateWorkbenchButton(d.frame,L['Cancel'],100);d.cancel:SetPoint('BOTTOMRIGHT',-12,28)
    d.close=self:CreateWorkbenchIconButton(d.frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5)
    return d
end
-- Shared themed, copyable report surface. It never accepts document changes.
function addon:CreateWorkbenchTextReport(width,height)
    local d=self:CreateWorkbenchTransferShell(width or 820,height or 500)
    d.apply:Hide();d.cancel:Hide();d.clear:Hide();d.input:SetMaxLetters(0);d.input:SetTextInsets(4,4,4,4)
    d.content=CreateFrame('Frame',nil,d.scroll);d.input:SetParent(d.content);d.input:ClearAllPoints();d.input:SetPoint('TOPLEFT');d.scroll:SetScrollChild(d.content)
    d.measure=d.content:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.measure:SetWordWrap(true);d.measure:Hide()
    function d:Layout()
        local width=math.max(1,self.scroll:GetWidth()-8);self.measure:SetWidth(math.max(1,width-8));self.measure:SetHeight(0);self.measure:SetText(self.text or '')
        local height=math.max(self.scroll:GetHeight(),self.measure:GetStringHeight()+12);self.content:SetSize(width,height);self.input:SetSize(width,height);self.scroll:UpdateWorkbenchScroll()
    end
    function d:Hide() self.reportRequest=nil;self.frame:Hide() end
    function d:SetReport(title,value,context,help)
        local request={};self.reportRequest=request
        local db=addon.db;local profile,global,char=db.profile,db.global,db.char
        local displayed=false
        local function current()
            local shown=not displayed or self.frame:IsShown()
            return self.reportRequest==request and addon.db==db and db.profile==profile and db.global==global and db.char==char
                and shown and self.reportRequest==request
        end
        if not current() then return end
        local text=tostring(value or '');if not current() then return end
        self.text=text;self.chrome:SetContext(title,L['Read-only'],context or addon.pretty_name)
        if not current() then return end
        self.setting=true;self.input:SetText(text)
        if self.reportRequest~=request then return end
        self.setting=false;if not current() then return end
        self:Layout();if not current() then return end
        self.frame:Show();displayed=true;if not current() then return end
        addon:RegisterWindowForEscape(self);if not current() then return end
        self.input:SetFocus();if not current() then return end
        self.input:SetCursorPosition(0);if not current() then return end
        self.input:HighlightText(0,-1);if not current() then return end
        self.scroll.workbenchBar:SetValue(0);if not current() then return end
        addon:BindTransferHelp(self,help,current)
    end
    addon:SetUIScript(d.input,'OnTextChanged',function()
        if not d.setting and d.input:GetText()~=d.text then d.setting=true;d.input:SetText(d.text or '');d.setting=false end;d:Layout()
    end)
    addon:SetUIScript(d.input,'OnCursorChanged',function(_,_,y,_,height)
        if d.setting or type(y)~='number' then return end
        local top=-y;local bar=d.scroll.workbenchBar;d.scroll:UpdateWorkbenchScroll()
        if top<bar:GetValue() then bar:SetValue(top) elseif top+(height or 0)>bar:GetValue()+d.scroll:GetHeight() then bar:SetValue(top+(height or 0)-d.scroll:GetHeight()) end
    end)
    addon:SetUIScript(d.copy,'OnClick',function() d.input:SetFocus();d.input:SetCursorPosition(0);d.input:HighlightText(0,-1) end)
    addon:SetUIScript(d.close,'OnClick',function() d:Hide() end);addon:SetUIScript(d.input,'OnEscapePressed',function() d:Hide() end)
    addon:SetUIScript(d.frame,'OnHide',function() d.reportRequest=nil;d.input:ClearFocus() end)
    d.input:EnableMouseWheel(true);addon:SetUIScript(d.input,'OnMouseWheel',function(_,delta) d.scroll.workbenchBar:SetValue(d.scroll.workbenchBar:GetValue()-delta*40) end)
    return d
end

function addon:ShowSettingsTextTransfer(p,title,text,apply,options)
    local d=p.textDialog
    if not d then
        d=self:CreateWorkbenchTransferShell(570,430);p.textDialog=d;self:UseExportFont(d)
        d.original=d.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.original:SetPoint('TOPLEFT',12,-36);d.original:SetSize(546,22);d.original:SetJustifyH('LEFT')
        d.destination=addon:CreateWorkbenchCheckBox(d.frame,L['Replace selected entry'],210);d.destination:SetPoint('TOPLEFT',12,-62)
        d.nameLabel=d.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.nameLabel:SetPoint('TOPLEFT',232,-62);d.nameLabel:SetSize(54,24);d.nameLabel:SetText(L['Name'])
        d.name=addon:CreateWorkbenchEditBox(d.frame);d.name:SetPoint('TOPLEFT',290,-62);d.name:SetSize(268,24);d.name:SetMaxLetters(256)
        d.status=d.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.status:SetPoint('TOPLEFT',12,-346);d.status:SetSize(546,32);d.status:SetWordWrap(true);d.status:SetJustifyH('LEFT')
        d.preview=addon:CreateWorkbenchButton(d.frame,L['Preview import'],90);d.preview:SetPoint('BOTTOMLEFT',152,28);d.inspect=addon:CreateWorkbenchButton(d.frame,L['Inspect import'],90);d.inspect:SetPoint('BOTTOMLEFT',248,28)
        local function hide() d.frame:Hide() end
        addon:SetUIScript(d.cancel,'OnClick',hide);addon:SetUIScript(d.close,'OnClick',hide);addon:SetUIScript(d.frame,'OnHide',function() d.input:ClearFocus();if d.options and d.options.onClose then d.options.onClose() end end)
        addon:SetUIScript(d.input,'OnSizeChanged',function() d.scroll:UpdateWorkbenchScroll() end)
        addon:SetUIScript(d.input,'OnCursorChanged',function(_,_,y,_,height) local top=-y;local bar=d.scroll.workbenchBar;d.scroll:UpdateWorkbenchScroll();if top<bar:GetValue() then bar:SetValue(top) elseif top+height>bar:GetValue()+d.scroll:GetHeight() then bar:SetValue(top+height-d.scroll:GetHeight()) end end)
        d.input:EnableMouseWheel(true);addon:SetUIScript(d.input,'OnMouseWheel',function(_,delta) local bar=d.scroll.workbenchBar;bar:SetValue(bar:GetValue()-delta*40) end)
        d.frame:Hide()
    end
    d.serial=(d.serial or 0)+1;local serial=d.serial;local token=p.generation
    local function valid()
        if not p:Valid(token)or p.textDialog~=d or d.serial~=serial or not d.frame:IsShown()then return false end
        if options and options.valid and not options.valid()then return false end
        return p:Valid(token)and p.textDialog==d and d.serial==serial and d.frame:IsShown()
    end
    d.chrome:SetContext(title,L['Import/Export'],addon.pretty_name or L['Rotation Master']);d.input:SetText(addon:FormatExportText(text))
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
        local result=p:WithSettingsHistory(function() local ok,why=apply(d.input:GetText(),settings);return {ok,why} end);if not valid()then return end;local ok,why=result[1],result[2];if not ok then d.status:SetText(why or L['Invalid import.']);return end
        d.frame:Hide();p:Draw()
    end)
    d.frame:SetFrameLevel(p.frame:GetFrameLevel()+250);d.frame:Show();d.scroll.workbenchBar:SetValue(0);d.scroll:UpdateWorkbenchScroll();addon:RegisterWindowForEscape(d);if options then preview() end
    self:BindTransferHelp(d,options and options.help,valid);return d
end
