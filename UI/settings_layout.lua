local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:InstallSettingsLayout(p)
    local simpleLayout=p.Layout
    function p:ResetLayout()
        self.surface=nil;self.rosterUsed=false;self.columnMode=false;self.columnSingle=false
        if self.roster then self.roster.frame:Hide() end
        for _,frame in ipairs(self.columns or {}) do frame:Hide() end
        self.scroll:ClearAllPoints();self.scroll:SetPoint('TOPLEFT',8,-8);simpleLayout(self)
    end
    function p:Column(index)
        if index==1 then
            self.fullWidth=math.max(340,self.frame:GetWidth()-40);self.columnSingle=self.fullWidth<960;self.columnMode=true
            self.child:SetWidth(self.fullWidth)
            if self.columnSingle then self.width=math.min(760,self.fullWidth);return end
            self.columns=self.columns or {};self.columnWidth=(self.fullWidth-24)/2
            for i=1,2 do local f=self.columns[i] or CreateFrame('Frame',nil,self.child);self.columns[i]=f;f:ClearAllPoints();f:SetPoint('TOPLEFT',(i-1)*(self.columnWidth+24),0);f:SetSize(self.columnWidth,1);f:Show() end
        end
        if self.columnSingle then return end
        if self.currentColumn then self.columns[self.currentColumn]:SetHeight(math.max(1,self.y)) end
        self.currentColumn=index;self.surface=self.columns[index];self.width=self.columnWidth;self.y=4
    end
    function p:EndColumns()
        if self.columnSingle then self.columnMode=false;return end
        self.columns[self.currentColumn]:SetHeight(math.max(1,self.y));self.y=math.max(self.columns[1]:GetHeight(),self.columns[2]:GetHeight());self.width=self.fullWidth;self.surface=nil;self.currentColumn=nil;self.columnMode=false
    end
    function p:UpdateRosterEntry(value,presentation)
        local r=self.roster;if not r then return end
        for _,entry in ipairs(r.entries) do if entry.value==value then entry.text=presentation.text or entry.text;entry.search=presentation.search or '';entry.icon=presentation.icon or nil;break end end
        self:RefreshRoster()
    end
    function p:RefreshRoster()
        local r=self.roster;if not r then return end
        r.revision=(r.revision or 0)+1;local revision=r.revision;self:PrepareRosterOrder(revision);local query=(r.search:GetText() or ''):lower();r.matches={}
        for _,entry in ipairs(r.entries) do
            if ((entry.text or '')..' '..(entry.search or '')):lower():find(query,1,true) then r.matches[#r.matches+1]=entry end
        end
        for i,entry in ipairs(r.matches) do
            local row=r.rows[i];if not row then row=addon:CreateWorkbenchListRow(r.child,230,32);row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(24,24);row.icon:SetPoint('LEFT',4,0);r.rows[i]=row end
            row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-(i-1)*34);row:SetSize(r.child:GetWidth(),32);row:SetText(entry.text);row:GetFontString():SetTextColor(entry.custom==false and .4 or .92,entry.custom==false and .7 or .94,entry.custom==false and 1 or .96);addon:SetWorkbenchListSelection(row,entry.value==r.current);addon:AlignWorkbenchTextLeft(row,entry.icon and 34 or 6)
            if entry.icon then row.icon:SetTexture(entry.icon);row.icon:Show() else row.icon:Hide() end;row:Show()
            addon:SetWorkbenchInvalid(row,entry.invalid,entry.validationMessage);row.tooltip=entry.validationMessage
            if entry.disabled then row:GetFontString():SetTextColor(.5,.5,.5) end
            addon:SetUIScript(row,'OnClick',self:Guard(function() if r.revision~=revision or not self:FlushEdits() then return end;r.choose(entry.value) end));self:BindRosterOrderRow(row,entry,revision)
        end
        for i=#r.matches+1,#r.rows do r.rows[i]:Hide() end
        self:BuildRosterOrderZones();r.child:SetHeight(math.max(1,#r.matches*34));if #r.matches==0 then r.empty:Show() else r.empty:Hide() end;r.scroll:UpdateWorkbenchScroll()
    end
    function p:SetRosterActions(entries,keepManage)
        local r=self.roster;if not r then return end
        r.footerActions=entries;r.footerManage=keepManage==true;r.actionButtons=r.actionButtons or {};r.new:Hide();if keepManage then r.manage:Show() else r.manage:Hide() end
        for i,entry in ipairs(entries) do
            local button=r.actionButtons[i];if not button then button=addon:CreateWorkbenchLabeledIconButton(r.frame,entry.icon,entry.text,120);r.actionButtons[i]=button end
            button:SetText(entry.text);button.icon:SetTexture(addon:ControlTexture(entry.icon));button:Show();if entry.enabled==false then button:Disable() else button:Enable() end
            self.fields[entry.key]=button;addon:SetUIScript(button,'OnClick',self:Guard(function() if self:FlushEdits() then entry.action() end end))
        end
        for i=#entries+1,#r.actionButtons do r.actionButtons[i]:Hide() end;self:Layout()
    end
    function p:UseRoster(entries,current,choose,options)
        options=options or {};self.rosterUsed=true
        local r=self.roster
        if not r then
            r={frame=CreateFrame('Frame',nil,self.frame),rows={}};self.roster=r;r.frame:SetPoint('TOPLEFT',8,-8)
            r.category=addon:CreateWorkbenchLabeledIconButton(r.frame,'chevron-down','',238);r.category:SetPoint('TOPLEFT',0,0)
            r.search=addon:CreateWorkbenchEditBox(r.frame);r.search:SetMaxLetters(128);addon:AttachWorkbenchSearchHint(r.search)
            r.scroll=addon:CreateWorkbenchScrollFrame(r.frame);r.child=CreateFrame('Frame',nil,r.scroll);r.scroll:SetScrollChild(r.child)
            r.empty=r.child:CreateFontString(nil,'OVERLAY','GameFontDisableSmall');r.empty:SetPoint('TOPLEFT',6,-6);r.empty:SetText(L['No matches.'])
            r.new=addon:CreateWorkbenchLabeledIconButton(r.frame,'plus',L['New'],238);r.new:SetPoint('BOTTOMLEFT',0,0)
            r.manage=addon:CreateWorkbenchButton(r.frame,'',238);r.manage:SetPoint('BOTTOMLEFT',0,30)
        end
        r.footerActions=nil;r.footerManage=false;for _,button in ipairs(r.actionButtons or {}) do button:Hide() end
        r.entries=entries;r.current=current;r.choose=choose;r.options=options;r.frame:Show();r.search:SetText(self.rosterQuery or '')
        addon:SetUIScript(r.search,'OnTextChanged',self:Guard(function(_,user) if user then self.rosterQuery=r.search:GetText();self:RefreshRoster() end end));addon:SetUIScript(r.search,'OnEscapePressed',self:Guard(function() r.search:ClearFocus() end))
        r.sourceButtons=r.sourceButtons or {}
        for i,entry in ipairs(options.sources or {}) do
            local control=r.sourceButtons[i];if not control then control=addon:CreateWorkbenchButton(r.frame,'',74);r.sourceButtons[i]=control end
            control:SetText(entry.text);control:SetSelected(entry.value==options.source);control:Show()
            addon:SetUIScript(control,'OnClick',self:Guard(function() if self:FlushEdits() then options.chooseSource(entry.value) end end))
        end
        for i=#(options.sources or {})+1,#r.sourceButtons do r.sourceButtons[i]:Hide() end
        if options.categories then
            local caption=L['All'];local selected;for _,entry in ipairs(options.categories) do if entry.value==options.category then caption=entry.text;selected=entry end end;addon:PaintSelectorSelection(r.category,selected,caption);r.category:Show()
            addon:SetUIScript(r.category,'OnClick',self:Guard(function() if self:FlushEdits() then self:ShowChoices(r.category,options.categories,options.chooseCategory) end end))
        else r.category:Hide() end
        r.new:ClearAllPoints();r.new:SetPoint('BOTTOMLEFT',0,options.manage and 30 or 0);r.manage:ClearAllPoints();r.manage:SetPoint('BOTTOMLEFT',0,0)
        if options.new then r.new:SetText(options.newText or L['New']);r.new:Show();addon:SetUIScript(r.new,'OnClick',self:Guard(function() if self:FlushEdits() then options.new() end end)) else r.new:Hide() end
        if options.manage then r.manage:SetText(options.manageText or L['Manage categories']);r.manage:Show();addon:SetUIScript(r.manage,'OnClick',self:Guard(function() if self:FlushEdits() then options.manage() end end)) else r.manage:Hide() end
        self:Layout();self.width=math.max(340,math.min(760,self.scroll:GetWidth()-8));self.child:SetWidth(self.width);self:RefreshRoster()
    end
    function p:Layout()
        if not self.rosterUsed or not self.roster then simpleLayout(self);return end
        local r=self.roster;local side=addon:GetWorkbenchSidebarWidth(self.frame:GetWidth());local height=math.max(1,self.frame:GetHeight()-(self.creationUsed and 66 or 38))
        local sidebarHeight=addon:GetWorkbenchSidebarHeight(self.frame:GetHeight(),8)
        r.frame:SetSize(side,sidebarHeight);r.category:SetWidth(side);r.new:SetWidth(side);r.manage:SetWidth(side);r.search:ClearAllPoints();r.search:SetPoint('TOPLEFT',0,0);r.search:SetSize(side,24)
        local filterTop=28
        if r.options.sources then
            local width=(side-8)/#r.options.sources
            for i,control in ipairs(r.sourceButtons) do control:ClearAllPoints();control:SetPoint('TOPLEFT',(i-1)*(width+4),-filterTop);control:SetWidth(width) end
            filterTop=filterTop+28
        end
        r.category:ClearAllPoints();r.category:SetPoint('TOPLEFT',0,-filterTop)
        local footerHeight=r.footerActions and math.ceil(#r.footerActions/2)*28+(r.footerManage and 30 or 0) or (r.options.new and 30 or 0)+(r.options.manage and 30 or 0)
        if r.footerActions then local width=(side-6)/2;for i,button in ipairs(r.actionButtons) do button:ClearAllPoints();button:SetPoint('BOTTOMLEFT',((i-1)%2)*(width+6),(r.footerManage and 30 or 0)+(math.ceil(#r.footerActions/2)-1-math.floor((i-1)/2))*28);button:SetWidth(width);addon:AlignWorkbenchTextLeft(button,24) end end
        local top=filterTop+(r.options.categories and 32 or 4);r.scroll:ClearAllPoints();r.scroll:SetPoint('TOPLEFT',0,-top);r.scroll:SetSize(side-18,math.max(1,sidebarHeight-top-footerHeight));r.child:SetWidth(side-26)
        self.scroll:ClearAllPoints();self.scroll:SetPoint('TOPLEFT',side+24,-8);self.scroll:SetSize(math.max(1,self.frame:GetWidth()-side-50),height);self.message:SetWidth(math.max(1,self.frame:GetWidth()-(self.creationUsed and 340 or 20)))
    end
end
