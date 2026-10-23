local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:InstallSettingsLayout(p)
    local simpleLayout=p.Layout
    function p:ResetLayout()
        self.surface=nil;self.rosterUsed=false;self.columnMode=false;self.columnSingle=false
        -- A divider drag redraws the page; keep its splitter alive meanwhile.
        if self.roster then self.roster.frame:Hide();if self.roster.splitter and not self.roster.splitter.drag then self.roster.splitter:Hide() end end
        for _,frame in ipairs(self.columns or {}) do frame:Hide() end
        self.scroll:Show();self.scroll:ClearAllPoints();self.scroll:SetPoint('TOPLEFT',8,-8);simpleLayout(self)
    end
    function p:Column(index)
        if index==1 then
            self.fullWidth=math.max(340,self.frame:GetWidth()-40);self.columnSingle=self.fullWidth<960;self.columnMode=true
            self.child:SetWidth(self.fullWidth)
            if self.columnSingle then self.width=self.fullWidth;return end
            self.columns=self.columns or {};self.columnWidth=(self.fullWidth-24)/2
            for i=1,2 do local f=self.columns[i] or addon:TrackWorkbenchSize(CreateFrame('Frame',nil,self.child));self.columns[i]=f;f:ClearAllPoints();f:SetPoint('TOPLEFT',(i-1)*(self.columnWidth+24),0);f:SetSize(self.columnWidth,1);f:Show() end
        end
        if self.columnSingle then return end
        -- Each column sizes its own caption column.
        if self.EndLabelScope and self.labelScope then self:EndLabelScope();self:BeginLabelScope() end
        if self.currentColumn then self.columns[self.currentColumn]:SetHeight(math.max(1,self.y)) end
        self.currentColumn=index;self.surface=self.columns[index];self.width=self.columnWidth;self.y=4
    end
    function p:EndColumns()
        if self.columnSingle then self.columnMode=false;return end
        if self.EndLabelScope and self.labelScope then self:EndLabelScope();self:BeginLabelScope() end
        self.columns[self.currentColumn]:SetHeight(math.max(1,self.y));self.y=math.max(self.columns[1]:GetHeight(),self.columns[2]:GetHeight());self.width=self.fullWidth;self.surface=nil;self.currentColumn=nil;self.columnMode=false
    end
    function p:UpdateRosterEntry(value,presentation)
        local r=self.roster;if not r then return end
        for _,entry in ipairs(r.entries) do if entry.value==value then entry.text=presentation.text or entry.text;entry.search=presentation.search or '';entry.icon=presentation.icon or nil;break end end
        self:RefreshRoster()
    end
    function p:RetireRosterRow(row)
        row.rosterLease=nil;row.rosterEntry=nil;row.rosterIndex=nil
        for _,event in ipairs({'OnClick','OnMouseDown','OnDragStart','OnDragStop'}) do addon:SetUIScript(row,event,nil) end
        row.rmDragged=nil;row.rmDragOriginalDown=nil;row.rmDragDownWrapper=nil
        if row.up then addon:SetUIScript(row.up,'OnClick',nil);addon:SetUIScript(row.down,'OnClick',nil);row.up:Hide();row.down:Hide() end
        row:Hide()
    end
    function p:ReleaseRoster()
        local r=self.roster;if not r then return end
        r.active=false;r.rebuilding=true;r.unsavedState=nil;r.unsavedByValue={}
        if r.orderView then r.orderView:Cancel() end
        for _,row in ipairs(r.rows) do self:RetireRosterRow(row) end
        for _,placeholder in ipairs(r.dragPlaceholders or {}) do placeholder:Hide();placeholder.rosterPlaceholderIndex=nil end
        r.rebuilding=nil;r.search:ClearFocus();r.frame:Hide();if r.splitter and not r.splitter.drag then r.splitter:Hide() end
    end
    function p:BindRosterViewportRow(row,entry,index)
        local r=self.roster;local lease={};local revision=r.revision
        row.rosterLease=lease;row.rosterEntry=entry;row.rosterIndex=index;row.rmDragged=nil
        row:SetParent(r.child);row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-(index-1)*34);row:SetSize(r.child:GetWidth(),32)
        row:SetText(entry.text)
        local color=entry.textColor
        row:GetFontString():SetTextColor(color and color[1] or entry.custom==false and .4 or .92,color and color[2] or entry.custom==false and .7 or .94,color and color[3] or entry.custom==false and 1 or .96)
        addon:SetWorkbenchListSelection(row,entry.value==r.current);addon:AlignWorkbenchTextLeft(row,entry.icon and 34 or 6)
        if entry.icon then row.icon:SetTexture(entry.icon);row.icon:Show() else row.icon:Hide() end
        addon:SetWorkbenchInvalid(row,entry.invalid,entry.validationMessage);row.tooltip=entry.validationMessage
        addon:SetWorkbenchUnsaved(row,self.RosterEntryUnsaved and self:RosterEntryUnsaved(entry) or false)
        if entry.disabled then row:GetFontString():SetTextColor(.5,.5,.5) end
        addon:SetUIScript(row,'OnClick',self:Guard(function() if r.active and r.revision==revision and row.rosterLease==lease and self:FlushEdits() then r.choose(entry.value) end end))
        self:BindRosterOrderRow(row,entry,revision);row:Show()
    end
    function p:RefreshRosterViewport()
        local r=self.roster
        if not r or not r.active or r.rebuilding or r.refreshing or not r.matches or not self:Valid(r.generation) then return end
        r.refreshing=true;local binding
        local ok,why=pcall(function()
            local top=r.scroll.workbenchBar:GetValue();local height=r.scroll:GetHeight()
            local first,last=addon:GetWorkbenchVisibleRowRange(#r.matches,34,top,height,102)
            local bound={}
            for _,row in ipairs(r.rows) do if row.rosterLease then
                local index=row.rosterIndex;local carried=r.orderView and r.orderView.carried and r.orderView.carried[row]
                if index>=first and index<=last or carried then
                    bound[index]=row
                    if not carried then
                        row:SetWidth(r.child:GetWidth())
                        local entry=row.rosterEntry;local ordered=r.orderIndex[entry.value]
                        addon:AlignWorkbenchTextLeft(row,entry.icon and (ordered and 54 or 34) or 6)
                    end
                else self:RetireRosterRow(row) end
            end end
            local free,placeholders=1,0
            for index=first,last do if not bound[index] then
                local view=r.orderView
                if view and view:Carries(r.matches[index]) then
                    placeholders=placeholders+1;r.dragPlaceholders=r.dragPlaceholders or {}
                    local placeholder=r.dragPlaceholders[placeholders]
                    if not placeholder then placeholder=CreateFrame('Frame',nil,r.child);placeholder:EnableMouse(false);placeholder.decoration=addon:CreateRoundedCardDecoration(placeholder);placeholder.decoration:SetColors(.4,.4,.4,.7,.12);r.dragPlaceholders[placeholders]=placeholder end
                    placeholder.rosterPlaceholderIndex=index;placeholder:ClearAllPoints();placeholder:SetPoint('TOPLEFT',0,-(index-1)*34);placeholder:SetSize(r.child:GetWidth(),32);placeholder:Show()
                else
                while r.rows[free] and r.rows[free].rosterLease do free=free+1 end
                local row=r.rows[free]
                if not row then
                    row=addon:CreateWorkbenchListRow(r.child,230,32);r.rows[free]=row
                    row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(24,24);row.icon:SetPoint('LEFT',4,0)
                end
                binding=row;self:BindRosterViewportRow(row,r.matches[index],index);binding=nil
                end
            end end
            for i=placeholders+1,#(r.dragPlaceholders or {}) do local placeholder=r.dragPlaceholders[i];placeholder.rosterPlaceholderIndex=nil;placeholder:Hide() end
            self:BuildRosterOrderZones()
        end)
        r.refreshing=nil
        if not ok then if binding then pcall(self.RetireRosterRow,self,binding) end;error(why,0) end
    end
    function p:RefreshRoster()
        local r=self.roster;if not r then return end
        local top=r.scroll.workbenchBar:GetValue();local anchor=r.matches and r.matches[math.floor(top/34)+1];local offset=top%34
        r.rebuilding=true
        if r.orderView then r.orderView:Cancel() end
        for _,row in ipairs(r.rows) do self:RetireRosterRow(row) end
        r.revision=(r.revision or 0)+1;local query=(r.search:GetText() or ''):lower();r.matches={};r.matchIndex={}
        for _,entry in ipairs(r.entries) do
            if ((entry.text or '')..' '..(entry.search or '')):lower():find(query,1,true) then
                r.matches[#r.matches+1]=entry;r.matchIndex[entry.value]=r.matchIndex[entry.value] or #r.matches
            end
        end
        self:PrepareRosterOrder(r.revision)
        r.child:SetHeight(math.max(1,#r.matches*34));if #r.matches==0 then r.empty:Show() else r.empty:Hide() end
        r.scroll:UpdateWorkbenchScroll()
        if anchor and r.matchIndex[anchor.value] then r.scroll.workbenchBar:SetValue((r.matchIndex[anchor.value]-1)*34+offset) end
        r.rebuilding=nil;self:RefreshRosterViewport()
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
            r={frame=addon:TrackWorkbenchSize(CreateFrame('Frame',nil,self.frame)),rows={}};self.roster=r;r.frame:SetPoint('TOPLEFT',0,0)
            r.category=addon:CreateWorkbenchLabeledIconButton(r.frame,'chevron-down','',238);r.category:SetPoint('TOPLEFT',0,0)
            r.search=addon:CreateWorkbenchEditBox(r.frame);r.search:SetMaxLetters(128);addon:AttachWorkbenchSearchHint(r.search)
            r.scroll=addon:CreateWorkbenchScrollFrame(r.frame);r.child=CreateFrame('Frame',nil,r.scroll);r.scroll:SetScrollChild(r.child)
            r.scroll.workbenchBar:HookScript('OnValueChanged',function() self:RefreshRosterViewport() end)
            -- Rows follow the list column; the scroll bar reserves space only when shown.
            function r.scroll.OnWorkbenchColumnResized() self:RefreshRosterViewport() end
            r.splitter=addon:CreateWorkbenchSplitter(self.frame,function() self:ResizeSplit() end)
            r.empty=r.child:CreateFontString(nil,'OVERLAY','GameFontDisableSmall');r.empty:SetPoint('TOPLEFT',6,-6);r.empty:SetText(L['No matches.'])
            r.new=addon:CreateWorkbenchLabeledIconButton(r.frame,'plus',L['New'],238);r.new:SetPoint('BOTTOMLEFT',0,0)
            r.manage=addon:CreateWorkbenchButton(r.frame,'',238);r.manage:SetPoint('BOTTOMLEFT',0,30)
        end
        r.footerActions=nil;r.footerManage=false;for _,button in ipairs(r.actionButtons or {}) do button:Hide() end
        r.rebuilding=true;r.entries=entries;r.current=current;r.choose=choose;r.options=options;r.active=true;r.generation=self.generation;r.frame:Show();
        local generation=self.generation;self.cleanups[#self.cleanups+1]=function() if r.generation==generation then self:ReleaseRoster() end end
        r.search:SetText(self.rosterQuery or '')
        addon:SetUIScript(r.search,'OnTextChanged',self:Guard(function(_,user) if user then self.rosterQuery=r.search:GetText();self:RefreshRoster() end end));addon:SetUIScript(r.search,'OnEscapePressed',self:Guard(function() r.search:ClearFocus() end))
        r.sourceButtons=r.sourceButtons or {}
        for i,entry in ipairs(options.sources or {}) do
            local control=r.sourceButtons[i];if not control then control=addon:CreateWorkbenchButton(r.frame,'',74);r.sourceButtons[i]=control end
            control:SetText(entry.text);control:SetSelected(entry.value==options.source);control:Show()
            addon:SetUIScript(control,'OnClick',self:Guard(function() if options.requestSource then options.requestSource(entry.value) elseif self:FlushEdits() then options.chooseSource(entry.value) end end))
        end
        for i=#(options.sources or {})+1,#r.sourceButtons do r.sourceButtons[i]:Hide() end
        if options.categories then
            local caption=L['All'];local selected;for _,entry in ipairs(options.categories) do if entry.value==options.category then caption=entry.text;selected=entry end end;addon:PaintSelectorSelection(r.category,selected,caption);r.category:Show()
            addon:SetUIScript(r.category,'OnClick',self:Guard(function() if self:FlushEdits() then self:ShowChoices(r.category,options.categories,options.chooseCategory) end end))
        else r.category:Hide() end
        r.new:ClearAllPoints();r.new:SetPoint('BOTTOMLEFT',0,options.manage and 30 or 0);r.manage:ClearAllPoints();r.manage:SetPoint('BOTTOMLEFT',0,0)
        if options.new then r.new:SetText(options.newText or L['New']);r.new:Show();addon:SetUIScript(r.new,'OnClick',self:Guard(function() if self:FlushEdits() then options.new() end end)) else r.new:Hide() end
        if options.manage then r.manage:SetText(options.manageText or L['Manage categories']);r.manage:Show();addon:SetUIScript(r.manage,'OnClick',self:Guard(function() if self:FlushEdits() then options.manage() end end)) else r.manage:Hide() end
        self:Layout();self.width=math.max(340,self.scroll:GetWidth());self.child:SetWidth(self.width);self:RefreshRoster()
    end
    function p:Layout()
        if not self.rosterUsed or not self.roster then simpleLayout(self);return end
        local r=self.roster;local geometry=addon:GetWorkbenchRosterGeometry(self.frame:GetWidth(),self.frame:GetHeight());self.rosterGeometry=geometry
        local side=geometry.sidebarWidth;local height=math.max(1,self.frame:GetHeight()-38);local sidebarHeight=geometry.sidebarHeight
        r.frame:SetSize(side,sidebarHeight);r.category:SetWidth(side);r.new:SetWidth(side);r.manage:SetWidth(side);r.search:ClearAllPoints();r.search:SetPoint('TOPLEFT',0,0);r.search:SetSize(side,24)
        local filterTop=28
        if r.options.sources then
            local shown={};for i=1,#r.options.sources do shown[i]=r.sourceButtons[i] end
            addon:LayoutWorkbenchRow(shown,0,filterTop,side)
            filterTop=filterTop+28
        end
        r.category:ClearAllPoints();r.category:SetPoint('TOPLEFT',0,-filterTop)
        local footerHeight=r.footerActions and math.ceil(#r.footerActions/2)*28+(r.footerManage and 30 or 0) or (r.options.new and 30 or 0)+(r.options.manage and 30 or 0)
        if r.footerActions then local width=(side-6)/2;for i,button in ipairs(r.actionButtons) do button:ClearAllPoints();button:SetPoint('BOTTOMLEFT',((i-1)%2)*(width+6),(r.footerManage and 30 or 0)+(math.ceil(#r.footerActions/2)-1-math.floor((i-1)/2))*28);button:SetWidth(width);addon:AlignWorkbenchTextLeft(button,24) end end
        local top=filterTop+(r.options.categories and 32 or 4);r.scroll:ClearAllPoints();r.scroll:SetPoint('TOPLEFT',0,-top);r.scroll:SetHeight(math.max(1,sidebarHeight-top-footerHeight))
        r.scroll:SetWorkbenchColumnWidth(side);r.child:SetWidth(r.scroll:GetWidth());r.empty:SetWidth(math.max(1,r.child:GetWidth()-12));r.splitter:Place(geometry)
        self.scroll:ClearAllPoints();self.scroll:SetPoint('TOPLEFT',geometry.detailX,0);self.scroll:SetSize(geometry.detailWidth-math.max(18,addon:GetWorkbenchHelpReserve(self.frame)),height);addon:ReserveWorkbenchHelpCorner(self.frame,self.scroll,0);self.message:SetWidth(math.max(1,self.frame:GetWidth()-(self.creationUsed and 340 or 20)))
        self:RefreshRosterViewport()
    end
    -- A divider drag changes the detail width without resizing the page, so
    -- the page is drawn again exactly as after a window resize, pending
    -- (even invalid) input included.
    function p:ResizeSplit()
        if not self.rosterUsed or not self.roster then return end
        self:Layout();self:Relayout()
    end
end
