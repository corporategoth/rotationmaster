local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local AceGUI=LibStub("AceGUI-3.0")
local function button(parent,text,width)
    return addon:CreateWorkbenchButton(parent,text,width)
end
local function label(parent,font)
    local text=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    text:SetJustifyH("LEFT");text:SetWordWrap(false)
    return text
end
local function create(parent)
    local frame=CreateFrame("Frame",nil,parent);frame:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0)
    local browser={frame=frame,rowButtons={},specButtons={},filters={},rows={},active=false,filter="all",query=""}
    local specs=CreateFrame("Frame",nil,frame);browser.specs=specs
    local left=CreateFrame("Frame",nil,frame);browser.left=left
    local detail=CreateFrame("Frame",nil,frame);browser.detail=detail
    local search=addon:CreateWorkbenchEditBox(left);browser.search=search
    search:SetAutoFocus(false);search:SetMaxLetters(128);search:SetFontObject("GameFontHighlightSmall")
    search:SetSize(240,24);search:SetTextInsets(5,5,0,0)
    local searchLabel=label(left);searchLabel:SetText(L["Search rotations"]);searchLabel:SetPoint("TOPLEFT",0,0)
    search:SetPoint("TOPLEFT",left,"TOPLEFT",5,-20)
    addon:SetUIScript(search,"OnTextChanged",function(control)
        if not browser.active then return end
        browser.query=string.lower(string.sub(control:GetText() or "",1,128));browser:RefreshRows()
        if browser.list then browser.list:SetVerticalScroll(0) end
    end)
    addon:SetUIScript(search,"OnEscapePressed",function(control) control:ClearFocus() end)
    local filterEntries={{"all",L["All"]},{"builtin",L["Built In"]},{"custom",L["Custom"]}}
    for index,entry in ipairs(filterEntries) do
        local control=button(left,entry[2],76);browser.filters[entry[1]]=control
        control:SetPoint("TOPLEFT",left,"TOPLEFT",(index-1)*80,-52)
        local key=entry[1];addon:SetUIScript(control,"OnClick",function() browser:SetFilter(key) end)
    end
    browser.selectedTags={};browser.tagMode='any'
    browser.tagLabel=label(left);browser.tagLabel:SetText(L['Tags']);browser.tagLabel:SetPoint('TOPLEFT',0,-80)
    browser.tagModeButton=addon:CreateWorkbenchPill(left,L['Any'],44);browser.tagModeButton:SetPoint('TOPLEFT',40,-80);browser.tagModeButton:SetAccent(.75,.6,.18)
    browser.tagPicker=addon:CreateRotationTagPicker(left,{allowCustom=false,
        available=function() return browser.availableTags or {} end,
        valid=function() return browser.active and browser.profile==addon.db.profile end,
        changed=function(tags) browser:SetTags(tags) end,
        color=function(tag) return addon:GetRotationTagColor(tag) end,
        setColor=function(tag,color) addon:SetRotationTagColor(tag,color);browser:RefreshRows() end,
        layout=function() if browser.active then browser:Layout() end end})
    browser.tagPicker.frame:SetPoint('TOPLEFT',0,-104);browser.tagButton=browser.tagPicker.input;browser.tagMenu=browser.tagPicker.menu
    addon:SetUIScript(browser.tagModeButton,'OnClick',function() if browser.active then browser.tagMode=browser.tagMode=='any' and 'all' or 'any';browser.tagModeButton:SetText(browser.tagMode=='any' and L['Any'] or L['All']);browser:RefreshRows() end end)
    local list=addon:CreateWorkbenchScrollFrame(left);browser.list=list
    local child=CreateFrame("Frame",nil,list);child:SetPoint("TOPLEFT",list,"TOPLEFT",0,0);list:SetScrollChild(child);browser.listChild=child
    local empty=label(child);empty:SetPoint("TOPLEFT",4,-6);empty:SetText(L["No rotations match this search."]);browser.empty=empty
    local count=label(left);browser.count=count
    local new=addon:CreateWorkbenchLabeledIconButton(left,"plus",L["New"],112);browser.newButton=new
    addon:SetUIScript(new,"OnClick",function()
        if not browser.active then return end
        browser:RequestLeave(function()
        if not browser.active then return end
        local custom=addon.db.profile.rotations[browser.spec] or {}
        local id
        for _=1,100 do
            local candidate=addon:uuid()
            if type(candidate)=="string" and custom[candidate]==nil and not addon:GetDefaultIdForRuntime(browser.spec,candidate) and candidate~=DEFAULT then id=candidate;break end
        end
        if not id then return end
        browser.pendingId=id;browser.filter="all";browser.tag=nil;browser.selectedTags={};browser.query="";search:SetText("")
        browser:SelectRotation(browser.spec,id,true)
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
                local source=addon:GetEditableRotation(browser.spec,browser.selected);local title=source and source.name
                if builtin then for _,entry in ipairs(addon:ListDefaultRotations(browser.spec)) do if entry.id==builtin then title=entry.name;break end end end
                local name=string.format(L["Copy of %s"],title or browser.selected)
                local id
                if builtin then id=addon:CloneDefaultRotation(browser.spec,builtin,name) else id=addon:DuplicateCustomRotation(browser.spec,browser.selected,name) end
                if id then browser:SelectRotation(browser.spec,id,true) end
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
    function browser:ReleaseDetails()
        addon.configPaneGeneration=(addon.configPaneGeneration or 0)+1
        addon.currentConditionEval=nil
        self.editorOwner=nil
        if AceGUI.ClearFocus then AceGUI:ClearFocus() end
        if self.pane then
            local pane=self.pane;self.pane=nil
            if self.nativeDetails then pane:Release() else AceGUI:Release(pane) end
            self.nativeDetails=nil
        end
    end
    function browser:RefreshRows()
        if not self.active then return end
        local all={{key=DEFAULT,name=DEFAULT,kind="custom",fallback=true}}
        for id,body in pairs(addon.db.profile.rotations[self.spec] or {}) do
            if id~=DEFAULT and type(body)=="table" then
                all[#all+1]={key=id,name=type(body.name)=="string" and body.name or tostring(id),kind="custom",enabled=not body.disabled}
            end
        end
        for _,entry in ipairs(addon:ListDefaultRotations(self.spec)) do
            all[#all+1]={key=entry.runtimeKey,id=entry.id,name=entry.name,description=entry.description,
                kind="builtin",enabled=entry.enabled,eligible=entry.eligible,readOnly=true}
        end
        local pending={}
        for _,entry in ipairs(addon.ListPendingRotationDrafts and addon:ListPendingRotationDrafts(self.spec) or {}) do
            pending[entry.id]=true;all[#all+1]={key=entry.id,name=entry.name,kind="custom",pending=true,presentation=entry.presentation}
        end
        if self.pendingId and not addon:GetEditableRotation(self.spec,self.pendingId) then
            if not pending[self.pendingId] then all[#all+1]={key=self.pendingId,name=NEW,kind="custom",pending=true} end
        else self.pendingId=nil end
        table.sort(all,function(a,b)
            if a.fallback~=b.fallback then return a.fallback==true end
            if a.name~=b.name then return a.name<b.name end
            return tostring(a.key)<tostring(b.key)
        end)
        local tags,seen={},{};self.tagRevision=(self.tagRevision or 0)+1
        for _,entry in ipairs(all) do
            local view=entry.pending and entry.presentation or addon:GetRotationTagView(self.spec,entry.key)
            entry.tags=addon.RotationData.GetRotationTags(view) or {};entry.search=addon.RotationData.RotationSearchText(view,entry.name,entry.description)
            local body=type(view.body)=='table' and view.body or view;entry.priority=addon.RotationData.GetRotationPriority(body.priority)
            for _,tag in ipairs(entry.tags) do local canonical=tag:lower();if not seen[canonical] then tags[#tags+1]=tag;seen[canonical]=true end end
        end
        table.sort(tags,function(a,b) return a:lower()<b:lower() end);self.availableTags=tags
        local selected={};for _,tag in ipairs(self.selectedTags) do if seen[tag:lower()] then selected[#selected+1]=tag end end;self.selectedTags=selected;self.tag=selected[1];self.tagPicker:SetTags(selected)
        local rows={}
        for _,entry in ipairs(all) do
            if (self.filter=='all' or self.filter==entry.kind) and addon.RotationData.RotationTagMatches(entry.tags,self.selectedTags,self.tagMode) and entry.search:find(self.query,1,true) then rows[#rows+1]=entry end
        end
        self.rows=rows
        for index,entry in ipairs(rows) do
            local control=self.rowButtons[index]
            if not control then
                control=CreateFrame("Button",nil,child)
                control.nameLabel=label(control,"GameFontHighlight")
                control.nameLabel:SetPoint("TOPLEFT",6,-5)
                control.statusLabel=label(control);control.statusLabel:SetPoint("TOPLEFT",6,-24)
                control.selection=control:CreateTexture(nil,"BACKGROUND");control.selection:SetAllPoints(control)
                control.selection:SetColorTexture(.1,.25,.3,.8);self.rowButtons[index]=control
            end
            control:SetPoint("TOPLEFT",child,"TOPLEFT",0,-(index-1)*48)
            control:SetSize(child:GetWidth(),46)
            control.nameLabel:SetWidth(math.max(32,child:GetWidth()-12));control.statusLabel:SetWidth(math.max(32,child:GetWidth()-12))
            control.nameLabel:SetText(entry.name)
            if entry.readOnly then control.nameLabel:SetTextColor(.357,.753,.922)
            else control.nameLabel:SetTextColor(.9,.92,.94) end
            local status=entry.readOnly and L["Built In · read-only"] or entry.fallback and L["Fallback rotation"] or L["Custom rotation"]
            if entry.readOnly and not entry.enabled then status=status.." — "..L["Disabled"]
            elseif entry.readOnly and not entry.eligible then status=status.." — "..L["Not available"] end
            if not entry.fallback then status=status..' · '..(entry.priority and string.format(L['Priority %d'],entry.priority) or L['Invalid priority']) end
            control.statusLabel:SetText(status);control.statusLabel:SetTextColor(.67,.72,.77)
            if entry.key==self.selected then control.selection:Show() else control.selection:Hide() end
            local key=entry.key;addon:SetUIScript(control,"OnClick",function() self:SelectRotation(self.spec,key) end)
            control:Show()
        end
        for index=#rows+1,#self.rowButtons do self.rowButtons[index]:Hide();self.rowButtons[index]:SetScript("OnClick",nil) end
        if #rows==0 then empty:Show() else empty:Hide() end
        child:SetHeight(math.max(30,#rows*48));list:UpdateScrollChildRect()
        count:SetText(string.format(L["%d of %d rotations"],#rows,#all))
        if self.pendingId==self.selected or self.nativeDetails and self.pane and self.pane.workspace.pending then duplicate:Disable();compare:Disable() else duplicate:Enable();compare:Enable() end
        for key,control in pairs(self.filters) do if key==self.filter then control:Disable() else control:Enable() end end
    end
    function browser:SetTags(tags)
        if not self.active then return end
        local normalized=addon.RotationData.NormalizeRotationTags(tags or {});if not normalized then return end
        self.selectedTags=normalized;self.tag=normalized[1];self:RefreshRows();list:SetVerticalScroll(0)
    end
    function browser:SetTag(value) if value==nil or type(value)=='string' then self:SetTags(value and {value} or {}) end end
    function browser:SetFilter(value)
        if value~="all" and value~="builtin" and value~="custom" then return end
        self.filter=value;self:RefreshRows();list:SetVerticalScroll(0)
    end
    function browser:RequestLeave(callback)
        if self.nativeDetails and self.pane and self.pane.RequestLeave then return self.pane:RequestLeave(callback) end
        callback();return true
    end
    function browser:SelectRotation(spec,id,approved)
        if not self.active then return end
        if not approved and self.pane and self.nativeDetails then
            local owner=self.editorOwner
            return self:RequestLeave(function() if self.active and self.editorOwner==owner then self:SelectRotation(spec,id,true) end end)
        end
        local found=false
        for _,entry in ipairs(self.specEntries) do if entry.id==spec then found=true;break end end
        if not found then spec=self.specEntries[1].id end
        if spec~=self.spec then self.pendingId=nil;self.query="";search:SetText("") end
        self.spec=spec
        local draftExists=false
        for _,entry in ipairs(addon.ListPendingRotationDrafts and addon:ListPendingRotationDrafts(spec) or {}) do if entry.id==id then draftExists=true;break end end
        local exists=draftExists or id==DEFAULT or addon:GetEditableRotation(spec,id) or addon:GetDefaultIdForRuntime(spec,id) or id==self.pendingId
        self.selected=exists and id or DEFAULT
        addon.configRotationSelection={spec=spec,id=self.selected}
        self:ReleaseDetails()
        local owner={};self.editorOwner=owner
        local function selected(nextSpec,nextId)
            if self.active and self.editorOwner==owner then self:SelectRotation(nextSpec,nextId) end
        end
        if addon.CreateRotationEditor then
            local pane,problem=addon:CreateRotationEditor(detail,spec,self.selected,selected)
            if not pane then
                self.editorOwner=nil
                local label=detail.rmEditorError or detail:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                detail.rmEditorError=label;label:SetPoint("TOPLEFT",8,-8);label:SetText(tostring(problem));label:Show()
            else
                if detail.rmEditorError then detail.rmEditorError:Hide() end
                self.nativeDetails=true;self.pane=pane
                pane.onSaved=function() if self.active and self.editorOwner==owner then self:RefreshRows() end end
            end
        else
            local pane=AceGUI:Create("SimpleGroup");self.pane=pane;pane:SetLayout("Flow")
            pane.frame:SetParent(detail);pane.frame:ClearAllPoints();pane.frame:SetAllPoints(detail)
            pane:SetWidth(detail:GetWidth());pane:SetHeight(detail:GetHeight());pane.frame:Show()
            addon:BuildRotationEditor(pane,spec,self.selected,selected)
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
        local top=hasSelectors and y+32 or 0;local leftWidth=addon:GetWorkbenchSidebarWidth(width)
        specs:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);specs:SetSize(width,top)
        left:SetPoint("TOPLEFT",frame,"TOPLEFT",0,-top);left:SetSize(leftWidth,addon:GetWorkbenchSidebarHeight(height,top))
        detail:SetPoint("TOPLEFT",frame,"TOPLEFT",leftWidth+18,-top);detail:SetSize(math.max(200,width-leftWidth-18),left:GetHeight())
        for index,key in ipairs({'all','builtin','custom'}) do local filter=self.filters[key];filter:ClearAllPoints();filter:SetPoint('TOPLEFT',left,'TOPLEFT',(index-1)*(leftWidth+4)/3,-52);filter:SetWidth((leftWidth-8)/3) end
        search:SetWidth(leftWidth-10)
        local footerHeight=50
        self.tagPicker:SetWidth(leftWidth)
        local listTop=104+self.tagPicker.height+8
        list:SetPoint("TOPLEFT",left,"TOPLEFT",0,-listTop);list:SetSize(leftWidth-24,math.max(64,left:GetHeight()-listTop-36-footerHeight))
        child:SetWidth(list:GetWidth())
        count:ClearAllPoints();count:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",0,footerHeight+8)
        local buttonWidth=(leftWidth-4)/2
        for _,control in ipairs({new,duplicate,import,compare}) do control:ClearAllPoints();control:SetWidth(buttonWidth) end
        new:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",0,24);duplicate:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",buttonWidth+4,24)
        import:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",0,0);compare:SetPoint("BOTTOMLEFT",left,"BOTTOMLEFT",buttonWidth+4,0)
        empty:SetWidth(math.max(40,child:GetWidth()-8))
        if self.pane then self.pane:SetWidth(detail:GetWidth());self.pane:SetHeight(detail:GetHeight()) end
        self:RefreshRows()
    end
    function browser:SetWidth(value) frame:SetWidth(value) end
    function browser:SetHeight(value) frame:SetHeight(value) end
    function browser:Release()
        self.active=false;self.tagPicker:Hide();self:ReleaseDetails();self.pendingId=nil;search:ClearFocus();if self.tagMenu then self.tagMenu:Release() end
        for _,control in ipairs(self.rowButtons) do control:Hide();addon:SetUIScript(control,"OnClick",nil) end
        frame:Hide()
    end
    function browser:Open(selection)
        self.active=false;self.filter="all";self.tag=nil;self.query="";search:SetText("")
        self.specEntries=addon:GetRotationEditorSpecs()
        for index,entry in ipairs(self.specEntries) do
            local control=self.specButtons[index]
            if not control then control=button(specs,"",120);self.specButtons[index]=control end
            control.spec=entry.id;control:SetText(entry.name);control:SetWidth(math.min(210,math.max(100,control:GetFontString():GetStringWidth()+24)))
            local id=entry.id;addon:SetUIScript(control,"OnClick",function() self:SelectRotation(id,id==addon.currentSpec and addon.currentRotation or DEFAULT) end)
            if #self.specEntries>1 then control:Show() else control:Hide() end
        end
        for index=#self.specEntries+1,#self.specButtons do self.specButtons[index]:Hide();self.specButtons[index]:SetScript("OnClick",nil) end
        self:Layout();frame:Show()
        local spec=selection and selection.spec or addon.currentSpec
        local found=false;for _,entry in ipairs(self.specEntries) do if entry.id==spec then found=true;break end end
        if not found then spec=self.specEntries[1].id end
        self.active=true;self.profile=addon.db.profile;self.selectedTags={}
        self:SelectRotation(spec,selection and selection.id or spec==addon.currentSpec and addon.currentRotation or DEFAULT)
        return self
    end
    addon:SetUIScript(frame,"OnSizeChanged",function() browser:Layout() end)
    return browser
end
function addon:CreateRotationBrowser(parent,selection)
    local browser=parent.rmRotationBrowser
    if not browser then browser=create(parent);parent.rmRotationBrowser=browser end
    browser:SetWidth(parent:GetWidth());browser:SetHeight(parent:GetHeight())
    return browser:Open(selection)
end
