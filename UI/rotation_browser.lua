local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local function button(parent,text,width)
    return addon:CreateWorkbenchButton(parent,text,width)
end
local function label(parent,font)
    local text=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    text:SetJustifyH("LEFT");text:SetWordWrap(false)
    return text
end
local function sameReference(a,b)
    if type(a)~='table' or type(b)~='table' or a.kind~=b.kind then return false end
    if a.kind=='builtin' then return a.id==b.id end
    if type(a.address)~='table' or type(b.address)~='table' then return false end
    for _,key in ipairs({'scope','class','owner','spec','id'}) do if a.address[key]~=b.address[key] then return false end end
    return true
end
local function create(parent)
    local frame=addon:TrackWorkbenchSize(CreateFrame("Frame",nil,parent));frame:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0)
    local browser={frame=frame,rowButtons={},specButtons={},filters={},rows={},active=false,filter="all",query=""}
    local specs=addon:TrackWorkbenchSize(CreateFrame("Frame",nil,frame));browser.specs=specs
    local left=addon:TrackWorkbenchSize(CreateFrame("Frame",nil,frame));browser.left=left
    local detail=addon:TrackWorkbenchSize(CreateFrame("Frame",nil,frame));browser.detail=detail
    -- The editor touches the page "?" corner; it inherits the reserve.
    detail.rmHelpReserve=addon:GetWorkbenchHelpReserve(frame)
    local search=addon:CreateWorkbenchEditBox(left);browser.search=search
    search:SetAutoFocus(false);search:SetMaxLetters(128);search:SetFontObject("GameFontHighlightSmall")
    search:SetSize(240,24);search:SetTextInsets(5,5,0,0)
    addon:AttachWorkbenchSearchHint(search)
    search:SetPoint("TOPLEFT",left,"TOPLEFT",0,0)
    addon:SetUIScript(search,"OnTextChanged",function(control)
        if not browser.active then return end
        browser.query=string.lower(string.sub(control:GetText() or "",1,128));browser:RefreshRows()
        if browser.list then browser.list.workbenchBar:SetValue(0) end
    end)
    addon:SetUIScript(search,"OnEscapePressed",function(control) control:ClearFocus() end)
    local filterEntries={{"all",L["All"]},{"builtin",L["Built In"]},{"custom",L["Custom"]}}
    for index,entry in ipairs(filterEntries) do
        local control=button(left,entry[2],76);browser.filters[entry[1]]=control
        control:SetPoint("TOPLEFT",left,"TOPLEFT",(index-1)*80,-28)
        local key=entry[1];addon:SetUIScript(control,"OnClick",function() browser:SetFilter(key) end)
    end
    browser.selectedTags={};browser.tagMode='any'
    browser.tagLabel=label(left);browser.tagLabel:SetText(L['Tags']);browser.tagLabel:SetHeight(18);browser.tagLabel:SetWidth(36);browser.tagLabel:SetJustifyV('MIDDLE');browser.tagLabel:SetPoint('TOPLEFT',0,-56)
    browser.tagModeButton=addon:CreateWorkbenchPill(left,L['Any'],44);browser.tagModeButton:SetPoint('TOPLEFT',40,-56);browser.tagModeButton:SetAccent(.75,.6,.18)
    browser.tagPicker=addon:CreateRotationTagPicker(left,{allowCustom=false,inputInset=92,
        available=function() return browser.availableTags or {} end,
        valid=function() return browser.active and browser.profile==addon.db.profile end,
        changed=function(tags) browser:SetTags(tags) end,
        color=function(tag) return addon:GetRotationTagColor(tag) end,
        setColor=function(tag,color) addon:SetRotationTagColor(tag,color);browser:RefreshRows() end,
        layout=function() if browser.active then browser:Layout() end end})
    browser.tagPicker.frame:SetPoint('TOPLEFT',0,-56);browser.tagButton=browser.tagPicker.input;browser.tagMenu=browser.tagPicker.menu
    addon:SetUIScript(browser.tagModeButton,'OnClick',function() if browser.active then browser.tagMode=browser.tagMode=='any' and 'all' or 'any';browser.tagModeButton:SetText(browser.tagMode=='any' and L['Any'] or L['All']);browser:RefreshRows() end end)
    local list=addon:CreateWorkbenchScrollFrame(left);browser.list=list
    local child=CreateFrame("Frame",nil,list);child:SetPoint("TOPLEFT",list,"TOPLEFT",0,0);list:SetScrollChild(child);browser.listChild=child
    local empty=label(child);empty:SetPoint("TOPLEFT",4,-6);empty:SetText(L["No rotations match this search."]);browser.empty=empty
    -- Rows follow the list column; the scroll bar reserves space only when shown.
    function list:OnWorkbenchColumnResized(width) empty:SetWidth(math.max(40,width-8));browser:RefreshViewport() end
    browser.splitter=addon:CreateWorkbenchSplitter(frame,function() if browser.active then browser:Layout() end end)
    local count=label(left);browser.count=count
    local new=addon:CreateWorkbenchLabeledIconButton(left,"plus",L["New"],112);browser.newButton=new
    addon:SetUIScript(new,"OnClick",function()
        if not browser.active then return end
        browser:RequestLeave(function()
        if not browser.active then return end
        local reference,key=addon:NewRotationDraftTarget(browser.spec)
        if not reference then if browser.pane then browser.pane:Message(key) end;return end
        browser.pendingId=key;browser.filter="all";browser.tag=nil;browser.selectedTags={};browser.query="";search:SetText("")
        browser:SelectRotation(browser.spec,key,true)
        end)
    end)
    local duplicate=addon:CreateWorkbenchLabeledIconButton(left,"copy",L["Duplicate"],112);browser.duplicateButton=duplicate
    addon:SetUIScript(duplicate,"OnClick",function()
        if not browser.active then return end
        local owner=browser.editorOwner
        browser:RequestLeave(function()
            if not browser.active or browser.editorOwner~=owner then return end
            if browser.nativeDetails and browser.pane then
                if not browser.pane.workspace.pending then browser.pane.clone.action() end
            else
                local builtin=addon:GetDefaultIdForRuntime(browser.spec,browser.selected)
                local source=browser.allByKey and browser.allByKey[browser.selected];local title=source and source.name
                local name=string.format(L["Copy of %s"],title or browser.selected)
                local id,why,reference
                if builtin then id,why,reference=addon:CloneDefaultRotation(browser.spec,builtin,name) else id,why,reference=addon:DuplicateCustomRotation(browser.spec,browser.selected,name) end
                if id then browser:SelectRotation(browser.spec,reference or id,true) end
            end
        end)
    end)
    local import=addon:CreateWorkbenchLabeledIconButton(left,"transfer",L["Import/Export"],112);browser.importButton=import
    addon:SetUIScript(import,"OnClick",function()
        if browser.active then browser:RequestLeave(function() if browser.active then addon:ShowRotationTransfer(browser.spec,browser.selected) end end) end
    end)
    local compare=addon:CreateWorkbenchLabeledIconButton(left,"compare",L["Compare"],140);browser.compareButton=compare
    addon:SetUIScript(compare,"OnClick",function()
        if not browser.active then return end
        local owner=browser.editorOwner
        browser:RequestLeave(function()
            if browser.active and browser.editorOwner==owner and addon.ShowRotationComparison then addon:ShowRotationComparison(browser.spec,browser.selected) end
        end)
    end)
    local recovery=button(left,L['Recover unassigned rotations'],240);browser.recoveryButton=recovery;recovery:Hide()
    function browser:RefreshRecovery()
        local rows,why
        if addon.ListUnassignedRotations and addon.ShowRotationAdoption then rows,why=addon:ListUnassignedRotations() end
        self.hasRecovery=rows and #rows>0 or why~=nil
        if self.hasRecovery then recovery:Show() else recovery:Hide() end
    end
    addon:SetUIScript(recovery,'OnClick',function()
        if not browser.active or browser.profile~=addon.db.profile then return end
        local serial,profile=browser.serial,browser.profile
        browser:RequestLeave(function()
            if not browser.active or browser.serial~=serial or addon.db.profile~=profile then return end
            addon:ShowRotationAdoption(browser,function(reference)
                if not browser.active or browser.serial~=serial or addon.db.profile~=profile then return end
                browser:RefreshRecovery();browser:Layout()
                browser:SelectRotation(reference.address.spec,reference,true)
                if addon.UpdateAutoSwitch then addon:UpdateAutoSwitch() end
                if addon.SwitchRotation then addon:SwitchRotation() end
            end)
        end)
    end)
    function browser:ReleaseDetails()
        addon.configPaneGeneration=(addon.configPaneGeneration or 0)+1
        addon.currentConditionEval=nil
        self.editorOwner=nil
        -- Retire native editor focus before releasing its owned pane.
        addon:ClearConditionWidgetFocus()
        if self.pane then
            local pane=self.pane;self.pane=nil
            if self.nativeDetails then pane:Release() end
            self.nativeDetails=nil
        end
    end
    function browser:RetireRow(control)
        control.browserLease=nil;control.browserEntry=nil;control.browserIndex=nil;addon:SetUIScript(control,'OnClick',nil);control:Hide()
    end
    function browser:BindRow(control,entry,index)
        local lease={};local serial,revision,spec,profile=self.serial,self.resultRevision,self.spec,self.profile
        local navigation=self.navigationRevision;local key=entry.key
        control.browserLease=lease;control.browserEntry=entry;control.browserIndex=index
        control:ClearAllPoints();control:SetPoint('TOPLEFT',child,'TOPLEFT',0,-(index-1)*48);control:SetSize(child:GetWidth(),46)
        control.nameLabel:SetWidth(math.max(32,child:GetWidth()-12));control.statusLabel:SetWidth(math.max(32,child:GetWidth()-12));control.nameLabel:SetText(entry.name)
        if entry.readOnly then control.nameLabel:SetTextColor(.357,.753,.922) else control.nameLabel:SetTextColor(.9,.92,.94) end
        local status=entry.readOnly and L['Built In · read-only'] or entry.fallback and L['Fallback rotation'] or L['Custom rotation']
        if entry.scope then status=status..' · '..(entry.scope=='character' and L['This character'] or L['Class']) end
        -- Who switched a Built In off is said apart from whether it can run here.
        if entry.readOnly and entry.builtinState=='user-disabled' then status=status..' — '..L['Disabled by you']
        elseif entry.readOnly and entry.builtinState=='shipped-disabled' then status=status..' — '..L['Ships disabled']
        elseif entry.readOnly and entry.builtinState==nil and not entry.enabled then status=status..' — '..L['Disabled']
        elseif entry.readOnly and not entry.eligible and entry.validationState=='valid' then status=status..' — '..L['Not available'] end
        if not entry.fallback then status=status..' · '..(entry.priority and string.format(L['Priority %d'],entry.priority) or L['Invalid priority']) end
        if entry.validationState and entry.validationState~='valid' and entry.validationState~='pending' then status=status..' — '..L['Not available'] end
        control.statusLabel:SetText(status);control.statusLabel:SetTextColor(.67,.72,.77);addon:SetWorkbenchListSelection(control,key==self.selected)
        -- Red when anything in it (a card, a branch child, a cooldown, the
        -- switch) stops it being selected; the tooltip names the first issue.
        local blocked=entry.problem~=nil or entry.validationState~=nil and entry.validationState~='valid' and entry.validationState~='pending'
        local blockedText=blocked and string.format(L['This rotation cannot be selected. %s.'],entry.problem and addon.DescribeRotationIssue and addon:DescribeRotationIssue(entry.problem) or L['It has incomplete or unsupported data']) or nil
        addon:SetWorkbenchProblem(control,blockedText)
        -- Grey when it is switched off (by you, or as it ships); amber when
        -- its switch can match together with another of its tier, so only
        -- priority decides (stronger on a tie). The tooltip says which apply.
        local disabledText
        if entry.readOnly and entry.builtinState=='user-disabled' then disabledText=L['Disabled by you: automatic switching skips it. Select it and click Disabled to turn it back on.']
        elseif entry.readOnly and entry.builtinState=='shipped-disabled' then disabledText=L['Ships disabled (an alternative to the recommended Built In): automatic switching skips it until you turn it on.']
        elseif not entry.readOnly and entry.enabled==false then disabledText=L['Disabled: automatic switching skips it.'] end
        local alpha=disabledText and .5 or 1
        control.nameLabel:SetAlpha(alpha);control.statusLabel:SetAlpha(alpha)
        if disabledText then control.nameLabel:SetTextColor(.6,.6,.6) end
        local overlapText,tie=nil,false
        if not entry.fallback and self.overlaps and addon.DescribeSwitchOverlap then overlapText,tie=addon:DescribeSwitchOverlap(self.overlaps[key]) end
        if addon.SetWorkbenchNotice then addon:SetWorkbenchNotice(control,overlapText and true or false,tie) end
        local lines={}
        if blockedText then lines[#lines+1]=blockedText end
        if disabledText then lines[#lines+1]=disabledText end
        if overlapText then lines[#lines+1]=overlapText end
        if not entry.fallback then lines[#lines+1]=L['Higher numbers are tried first; your own rotations are always tried before Built Ins.'] end
        control.tooltip=#lines>0 and table.concat(lines,'\n\n') or nil
        local function requestValid() return browser.active and browser.serial==serial and browser.profile==profile and profile==addon.db.profile and browser.spec==spec and browser.navigationRevision==navigation and browser.rowsByKey[key]~=nil end
        -- A Built In you switched off turns back on from the list in one click.
        if entry.readOnly and entry.builtinState=='user-disabled' then
            if not control.enableButton then
                control.enableButton=addon:CreateWorkbenchButton(control,L['Turn on'],64);control.enableButton:SetHeight(18)
                control.enableButton:SetPoint('RIGHT',control,'RIGHT',-6,0)
            end
            local button=control.enableButton;button.tooltip=L['Turn this Built In back on for this profile.']
            addon:SetUIScript(button,'OnClick',function()
                if not requestValid() or control.browserLease~=lease then return end
                local ok=addon:SetDefaultRotationEnabled(entry.canonicalId,true)
                if ok then
                    if addon.currentSpec~=nil and addon.db.profile.enable then addon:UpdateAutoSwitch();addon:SwitchRotation() end
                    browser:RefreshRows()
                end
            end)
            button:Show()
        elseif control.enableButton then addon:SetUIScript(control.enableButton,'OnClick',nil);control.enableButton:Hide() end
        addon:SetUIScript(control,'OnClick',function() if requestValid() and browser.resultRevision==revision and control.browserLease==lease then browser:SelectRotation(spec,key,false,requestValid) end end);control:Show()
    end
    function browser:RefreshViewport()
        if not self.active or self.profile~=addon.db.profile or self.rebuilding or self.refreshing or not self.rows then return end
        self.refreshing=true;local binding
        local ok,why=pcall(function()
            local first,last=addon:GetWorkbenchVisibleRowRange(#self.rows,48,list.workbenchBar:GetValue(),list:GetHeight(),96)
            local bound={}
            for _,control in ipairs(self.rowButtons) do if control.browserLease then
                local index=control.browserIndex
                if index>=first and index<=last then
                    bound[index]=control;control:SetWidth(child:GetWidth());control.nameLabel:SetWidth(math.max(32,child:GetWidth()-12));control.statusLabel:SetWidth(math.max(32,child:GetWidth()-12))
                else self:RetireRow(control) end
            end end
            local free=1
            for index=first,last do if not bound[index] then
                while self.rowButtons[free] and self.rowButtons[free].browserLease do free=free+1 end
                local control=self.rowButtons[free]
                if not control then
                    control=addon:CreateWorkbenchListRow(child,child:GetWidth(),46);self.rowButtons[free]=control
                    control.nameLabel=label(control,'GameFontHighlight');control.nameLabel:SetPoint('TOPLEFT',6,-5)
                    control.statusLabel=label(control);control.statusLabel:SetPoint('TOPLEFT',6,-24)
                end
                binding=control;self:BindRow(control,self.rows[index],index);binding=nil
            end end
        end)
        self.refreshing=nil;if not ok then if binding then pcall(self.RetireRow,self,binding) end;error(why,0) end
    end
    function browser:RefreshRows()
        if not self.active or self.profile~=addon.db.profile then return end
        local offset=list.workbenchBar:GetValue();local anchor=self.rows and self.rows[math.floor(offset/48)+1];local anchorOffset=offset%48
        self.rebuilding=true;self.resultRevision=(self.resultRevision or 0)+1
        for _,control in ipairs(self.rowButtons) do self:RetireRow(control) end
        local all,state=addon:ListRotationHeaders(self.spec)
        local reason=not all and state or nil;self.rosterStamp=all and state or nil
        all=all or {};self.loadError=reason
        local byKey={};for _,entry in ipairs(all) do byKey[entry.key]=entry end
        for _,entry in ipairs(addon.ListPendingRotationDrafts and addon:ListPendingRotationDrafts(self.spec) or {}) do
            if not byKey[entry.key] then
                local view=entry.presentation or {};local row={key=entry.key,reference=entry.reference,canonicalId=entry.canonicalId,name=entry.name,scope=entry.scope,kind='custom',pending=true,
                    fallback=entry.fallback,effectiveFallback=false,validationState='pending',tags=addon.RotationData.GetRotationTags(view) or {},
                    search=addon.RotationData.RotationSearchText(view,entry.name,view.description),priority=addon.RotationData.GetRotationPriority(view.priority)}
                all[#all+1]=row;byKey[row.key]=row
            end
        end
        if self.pendingId and byKey[self.pendingId] and not byKey[self.pendingId].pending then self.pendingId=nil end
        self.allByKey=byKey
        -- The order automatic switching tries them in: your own rotations,
        -- then Built Ins, each by priority (higher first), then name; the
        -- fallback, the last resort, comes last.
        table.sort(all,function(a,b)
            if a.fallback~=b.fallback then return b.fallback==true end
            local ab,bb=a.kind=='builtin',b.kind=='builtin'
            if ab~=bb then return bb end
            local ap,bp=a.priority or -math.huge,b.priority or -math.huge
            if ap~=bp then return ap>bp end
            if a.name~=b.name then return a.name<b.name end
            return tostring(a.key)<tostring(b.key)
        end)
        self.overlaps=self.spec==addon.currentSpec and addon.GetSwitchOverlaps and addon:GetSwitchOverlaps(self.spec) or {}
        local tags,seen={},{};self.tagRevision=(self.tagRevision or 0)+1
        for _,entry in ipairs(all) do
            for _,tag in ipairs(entry.tags or {}) do local canonical=tag:lower();if not seen[canonical] then tags[#tags+1]=tag;seen[canonical]=true end end
        end
        table.sort(tags,function(a,b) return a:lower()<b:lower() end);self.availableTags=tags
        local selected={};for _,tag in ipairs(self.selectedTags) do if seen[tag:lower()] then selected[#selected+1]=tag end end;self.selectedTags=selected;self.tag=selected[1];self.tagPicker:SetTags(selected)
        local rows={}
        for _,entry in ipairs(all) do
            if (self.filter=='all' or self.filter==entry.kind) and addon.RotationData.RotationTagMatches(entry.tags,self.selectedTags,self.tagMode) and entry.search:find(self.query,1,true) then rows[#rows+1]=entry end
        end
        self.rows=rows;self.rowsByKey={};local positions={}
        for index,entry in ipairs(rows) do self.rowsByKey[entry.key]=entry;positions[entry.key]=index end
        local parts={tostring(self.spec),self.filter,self.query,self.tagMode};for _,tag in ipairs(self.selectedTags) do parts[#parts+1]=tag end
        for index,value in ipairs(parts) do parts[index]=#value..':'..value end
        local signature=table.concat(parts,';')
        if signature~=self.navigationSignature then self.navigationSignature=signature;self.navigationRevision=(self.navigationRevision or 0)+1 end
        empty:SetText(reason or L['No rotations match this search.']);if #rows==0 then empty:Show() else empty:Hide() end
        child:SetHeight(math.max(30,#rows*48));list:UpdateScrollChildRect();list:UpdateWorkbenchScroll()
        if anchor and positions[anchor.key] then list.workbenchBar:SetValue((positions[anchor.key]-1)*48+anchorOffset) end
        self.rebuilding=nil;self:RefreshViewport()
        count:SetText(string.format(L["%d of %d rotations"],#rows,#all))
        if not self.selected or self.pendingId==self.selected or self.nativeDetails and self.pane and self.pane.workspace.pending then duplicate:Disable();compare:Disable() else duplicate:Enable();compare:Enable() end
        for key,control in pairs(self.filters) do if key==self.filter then control:Disable() else control:Enable() end end
    end
    function browser:SetTags(tags)
        if not self.active then return end
        local normalized=addon.RotationData.NormalizeRotationTags(tags or {});if not normalized then return end
        self.selectedTags=normalized;self.tag=normalized[1];self:RefreshRows();list.workbenchBar:SetValue(0)
    end
    function browser:SetTag(value) if value==nil or type(value)=='string' then self:SetTags(value and {value} or {}) end end
    function browser:SetFilter(value)
        if value~="all" and value~="builtin" and value~="custom" then return end
        self.filter=value;self:RefreshRows();list.workbenchBar:SetValue(0)
    end
    function browser:RequestLeave(callback)
        if self.nativeDetails and self.pane and self.pane.RequestLeave then return self.pane:RequestLeave(callback) end
        callback();return true
    end
    function browser:SelectRotation(spec,id,approved,requestValid)
        if not self.active or self.profile~=addon.db.profile or requestValid and not requestValid() then return end
        if not approved and self.pane and self.nativeDetails then
            local owner=self.editorOwner
            return self:RequestLeave(function() if self.active and self.editorOwner==owner and (not requestValid or requestValid()) then self:SelectRotation(spec,id,true,requestValid) end end)
        end
        local found=false
        for _,entry in ipairs(self.specEntries) do if entry.id==spec then found=true;break end end
        if not found then spec=self.specEntries[1].id end
        if spec~=self.spec then self.pendingId=nil;self.query="";search:SetText("") end
        self.spec=spec
        local headers,headerState=addon:ListRotationHeaders(spec)
        local headerError=not headers and headerState or nil
        local reference,selectionError=addon:ResolveRotationReference(spec,id)
        local key,fallback
        for _,entry in ipairs(headers or {}) do
            if reference and sameReference(reference,entry.reference) then key=entry.key end
            if entry.effectiveFallback or not fallback and entry.fallback then fallback=entry.key end
        end
        if not key and reference and type(id)=='string' then key=id end
        self.selected=key or fallback or headers and headers[1] and headers[1].key
        addon.configRotationSelection={spec=spec,id=self.selected}
        self:ReleaseDetails()
        local owner={};self.editorOwner=owner
        local function selected(nextSpec,nextId)
            if self.active and self.editorOwner==owner then self:SelectRotation(nextSpec,nextId) end
        end
        local pane,problem
        if not self.selected then problem=headerError or selectionError or L['No rotations match this search.']
        elseif type(addon.CreateRotationEditor)=='function' then pane,problem=addon:CreateRotationEditor(detail,spec,self.selected,selected)
        else problem=L['The native rotation editor is unavailable.'] end
        if not pane then
            self.editorOwner=nil
            local label=detail.rmEditorError or detail:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            detail.rmEditorError=label;label:SetPoint("TOPLEFT",8,-8);label:SetText(tostring(problem or L['The native rotation editor is unavailable.']));label:Show()
        else
            if detail.rmEditorError then detail.rmEditorError:Hide() end
            self.nativeDetails=true;self.pane=pane
            pane.onSaved=function() if self.active and self.editorOwner==owner then
                self.selected=pane.workspace.id or self.selected;addon.configRotationSelection={spec=self.spec,id=self.selected};self:RefreshRows()
            end end
        end
        for _,control in ipairs(self.specButtons) do
            if control.spec==spec then control:Disable() else control:Enable() end
        end
        self:RefreshRows()
    end
    function browser:Layout()
        local width,height=frame:GetWidth(),frame:GetHeight()
        local x,y=0,0
        local hasSelectors=false
        for _,control in ipairs(self.specButtons) do
            if control:IsShown() then
                hasSelectors=true
                if x+control:GetWidth()>width then x=0;y=y+28 end
                control:SetPoint("TOPLEFT",specs,"TOPLEFT",x,-y);x=x+control:GetWidth()+4
            end
        end
        local top=hasSelectors and y+32 or 0;local geometry=addon:GetWorkbenchRosterGeometry(width,height,top);local leftWidth=geometry.sidebarWidth
        specs:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);specs:SetSize(width,top)
        left:SetPoint("TOPLEFT",frame,"TOPLEFT",0,-top);left:SetSize(leftWidth,geometry.sidebarHeight)
        detail:SetPoint("TOPLEFT",frame,"TOPLEFT",geometry.detailX,-top);detail:SetSize(geometry.detailWidth,geometry.sidebarHeight)
        self.splitter:Place(geometry)
        addon:LayoutWorkbenchRow({self.filters.all,self.filters.builtin,self.filters.custom},0,28,leftWidth)
        search:SetWidth(leftWidth)
        local footerExtra=self.hasRecovery and 26 or 0
        local footerHeight=50+footerExtra
        self.tagPicker:SetWidth(leftWidth)
        local listTop=56+self.tagPicker.height+8
        list:SetPoint("TOPLEFT",left,"TOPLEFT",0,-listTop);list:SetHeight(math.max(64,left:GetHeight()-listTop-36-footerHeight))
        list:SetWorkbenchColumnWidth(leftWidth);child:SetWidth(list:GetWidth())
        count:ClearAllPoints();count:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",0,footerHeight+8);count:SetWidth(leftWidth)
        local buttonWidth=(leftWidth-4)/2
        for _,control in ipairs({new,duplicate,import,compare}) do control:ClearAllPoints();control:SetWidth(buttonWidth);addon:AlignWorkbenchTextLeft(control,24) end
        new:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",0,24+footerExtra);duplicate:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",buttonWidth+4,24+footerExtra)
        import:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",0,footerExtra);compare:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",buttonWidth+4,footerExtra)
        recovery:ClearAllPoints();recovery:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",0,0);recovery:SetWidth(leftWidth)
        empty:SetWidth(math.max(40,child:GetWidth()-8))
        if self.pane then self.pane:SetWidth(detail:GetWidth());self.pane:SetHeight(detail:GetHeight()) end
        self:RefreshViewport()
    end
    function browser:SetWidth(value) frame:SetWidth(value) end
    function browser:SetHeight(value) frame:SetHeight(value) end
    function browser:Release()
        self.active=false;self.serial=(self.serial or 0)+1;self.tagPicker:Hide();self:ReleaseDetails();self.pendingId=nil;search:ClearFocus();if self.tagMenu then self.tagMenu:Release() end
        for _,control in ipairs(self.rowButtons) do self:RetireRow(control) end
        frame:Hide()
    end
    function browser:Open(selection)
        self.active=false;self.serial=(self.serial or 0)+1;self.tagPicker:Hide();for _,control in ipairs(self.rowButtons) do self:RetireRow(control) end;self.filter="all";self.tag=nil;self.query="";search:SetText("")
        self.specEntries=addon:GetRotationEditorSpecs()
        for index,entry in ipairs(self.specEntries) do
            local control=self.specButtons[index]
            if not control then control=button(specs,"",120);self.specButtons[index]=control end
            control.spec=entry.id;control:SetText(entry.name);control:SetWidth(math.min(210,math.max(100,control:GetFontString():GetStringWidth()+24)))
            local id=entry.id;addon:SetUIScript(control,"OnClick",function() self:SelectRotation(id,id==addon.currentSpec and addon.currentRotation or DEFAULT) end)
            if #self.specEntries>1 then control:Show() else control:Hide() end
        end
        for index=#self.specEntries+1,#self.specButtons do self.specButtons[index]:Hide();self.specButtons[index]:SetScript("OnClick",nil) end
        self:RefreshRecovery();self:Layout();frame:Show()
        local spec=selection and selection.spec or addon.currentSpec
        local found=false;for _,entry in ipairs(self.specEntries) do if entry.id==spec then found=true;break end end
        if not found then spec=self.specEntries[1].id end
        self.active=true;self.profile=addon.db.profile;self.selectedTags={};self.tagPicker.frame:Show();self.tagPicker.input:Show()
        self:SelectRotation(spec,selection and selection.id or spec==addon.currentSpec and addon.currentRotation or DEFAULT)
        return self
    end
    list.workbenchBar:HookScript('OnValueChanged',function() browser:RefreshViewport() end)
    addon:SetUIScript(frame,"OnSizeChanged",function() browser:Layout() end)
    return browser
end
function addon:CreateRotationBrowser(parent,selection)
    local browser=parent.rmRotationBrowser
    if not browser then browser=create(parent);parent.rmRotationBrowser=browser end
    browser:SetWidth(parent:GetWidth());browser:SetHeight(parent:GetHeight())
    return browser:Open(selection)
end
