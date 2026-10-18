local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local data=addon.RotationData
local definitions={{'author','Author'},{'realm','Realm'},{'email','Email'},{'website','Website'},{'version','Version'}}
local function label(parent,value,y)
    local text=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');text:SetPoint('TOPLEFT',8,-y);text:SetWidth(460);text:SetJustifyH('LEFT');text:SetWordWrap(true);text:SetText(value);return text
end
function addon:InstallRotationMetadata(pane)
    local dialog={fields={},labels={}}
    local frame=CreateFrame('Frame',nil,UIParent);dialog.frame=frame;frame:SetSize(530,540);frame:SetPoint('CENTER');frame:SetFrameStrata('FULLSCREEN_DIALOG');frame:SetToplevel(true);frame:EnableMouse(true);frame:SetClampedToScreen(true)
    addon:MakeWindowOpaque(frame)
    dialog.title=frame:CreateFontString(nil,'OVERLAY','GameFontNormal');dialog.chrome=addon:CreateWorkbenchDialogChrome(frame,dialog.title)
    local drag=CreateFrame('Frame',nil,frame);drag:SetPoint('TOPLEFT',8,-1);drag:SetPoint('TOPRIGHT',-150,-1);drag:SetHeight(28);drag:EnableMouse(true);drag:RegisterForDrag('LeftButton')
    addon:SetUIScript(drag,'OnDragStart',function() frame:StartMoving() end);addon:SetUIScript(drag,'OnDragStop',function() frame:StopMovingOrSizing() end);frame:SetMovable(true)
    local scroll=addon:CreateWorkbenchScrollFrame(frame);scroll:SetPoint('TOPLEFT',12,-40);scroll:SetSize(484,296);dialog.scroll=scroll
    local child=CreateFrame('Frame',nil,scroll);child:SetSize(476,296);scroll:SetScrollChild(child)
    pane.descriptionLabel:SetParent(child);pane.descriptionLabel:ClearAllPoints();pane.descriptionLabel:SetPoint('TOPLEFT',8,0)
    local area=CreateFrame('Frame',nil,child);area:SetPoint('TOPLEFT',8,-20);area:SetSize(460,108);dialog.descriptionArea=area
    local background=area:CreateTexture(nil,'BACKGROUND');background:SetAllPoints(area);background:SetColorTexture(.08,.09,.10,.95)
    local line=area:CreateTexture(nil,'BORDER');line:SetPoint('BOTTOMLEFT');line:SetPoint('BOTTOMRIGHT');line:SetHeight(1);line:SetColorTexture(.38,.43,.48,.8)
    local descriptionScroll=addon:CreateWorkbenchScrollFrame(area);descriptionScroll:SetPoint('TOPLEFT',4,-4);descriptionScroll:SetSize(436,100);dialog.descriptionScroll=descriptionScroll
    pane.description:SetParent(descriptionScroll);pane.description:ClearAllPoints();pane.description:SetPoint('TOPLEFT',0,0);pane.description:SetWidth(436);pane.description:SetHeight(100);pane.description:SetTextInsets(4,4,4,4);descriptionScroll:SetScrollChild(pane.description);dialog.fields.description=pane.description
    addon:SetUIScript(pane.description,'OnSizeChanged',function() descriptionScroll:UpdateWorkbenchScroll() end)
    addon:SetUIScript(pane.description,'OnCursorChanged',function(_,_,y,_,height)
        if not dialog:Valid() then return end
        descriptionScroll:UpdateWorkbenchScroll();local bar=descriptionScroll.workbenchBar;local offset=bar:GetValue();local top=-y
        if top<offset then bar:SetValue(top) elseif top+height>offset+descriptionScroll:GetHeight() then bar:SetValue(top+height-descriptionScroll:GetHeight()) end
    end)
    pane.description:EnableMouseWheel(true);addon:SetUIScript(pane.description,'OnMouseWheel',function(_,delta) local bar=descriptionScroll.workbenchBar;bar:SetValue(bar:GetValue()-delta*40) end)
    local function bodyMouseUp(_,button)
        if not dialog:Valid() then return end
        if button=='RightButton' then dialog:Close(false) elseif button=='LeftButton' and not pane.workspace.readOnly then pane.description:SetFocus() end
    end
    descriptionScroll:EnableMouse(true);addon:SetUIScript(descriptionScroll,'OnMouseUp',bodyMouseUp);addon:SetUIScript(pane.description,'OnMouseUp',function(control,button) if button=='RightButton' then bodyMouseUp(control,button) end end)
    for index,entry in ipairs(definitions) do
        local key=entry[1];local y=140+(index-1)*30;dialog.labels[key]=label(child,L[entry[2]],y);dialog.labels[key]:SetWidth(96);dialog.labels[key]:SetHeight(24);dialog.labels[key]:SetJustifyV('MIDDLE')
        local input=addon:CreateWorkbenchEditBox(child);dialog.fields[key]=input;input:SetSize(352,24);input:SetPoint('TOPLEFT',116,-y);input:SetMaxLetters(512)
        addon:SetUIScript(input,'OnMouseUp',function(control,button) if button=='RightButton' then bodyMouseUp(control,button) end end)
    end
    dialog.sourceHeading=label(child,L['Sources'],296);dialog.source=label(child,'',316);dialog.source:Hide();dialog.sourceHeading:Hide()
    dialog.note=label(frame,L['Use changes updates the draft. Apply the rotation to save it.'],348);dialog.note:SetWidth(506)
    dialog.apply=addon:CreateWorkbenchButton(frame,L['Use changes'],112);dialog.apply:SetPoint('BOTTOMRIGHT',-136,28)
    dialog.cancel=addon:CreateWorkbenchButton(frame,L['Cancel'],112);dialog.cancel:SetPoint('BOTTOMRIGHT',-16,28)
    dialog.close=addon:CreateWorkbenchIconButton(frame,'close',L['Close']);dialog.close:SetPoint('TOPRIGHT',-5,-5)
    dialog.help=addon:CreateWorkbenchHelpButton(frame,L['Help']);dialog.help:SetPoint('TOPRIGHT',-31,-5);dialog.help:SetSize(20,20);dialog.help.icon:SetSize(16,16)
    addon:SetUIScript(dialog.help,'OnClick',function() if dialog:Valid() and addon.ShowWorkbenchHelp then addon:ShowWorkbenchHelp(L['Rotation metadata'],{{title=L['Description and attribution'],text=L['Edit the description, author, realm, email, website and version. Source citations remain separate from your attribution. Use changes updates the rotation draft; Apply the rotation to save it. Cancel or Escape restores this dialog’s opening values.']}},pane:RotationDisplayName()) end end)
    addon:SetUIScript(frame,'OnMouseUp',function(control,button) if button=='RightButton' then bodyMouseUp(control,button) end end)
    addon:SetUIScript(scroll,'OnMouseUp',function(control,button) if button=='RightButton' then bodyMouseUp(control,button) end end);scroll:EnableMouse(true)
    function dialog:Layout(sourceText)
        local contentHeight=296
        if sourceText~='' then
            self.source:SetText(sourceText);self.source:SetHeight(0);self.source:SetHeight(self.source:GetStringHeight());self.source:Show();self.sourceHeading:Show();contentHeight=316+self.source:GetHeight()+12
        else self.source:SetText('');self.source:Hide();self.sourceHeading:Hide() end
        child:SetHeight(contentHeight);local visible=math.min(contentHeight,380);scroll:SetHeight(visible)
        self.note:SetHeight(0);local noteHeight=math.max(14,self.note:GetStringHeight());self.note:SetHeight(noteHeight);self.note:ClearAllPoints();self.note:SetPoint('TOPLEFT',12,-40-visible-8)
        frame:SetHeight(40+visible+8+noteHeight+8+24+8+20);self.chrome:LayoutTitle();scroll:UpdateWorkbenchScroll();descriptionScroll:UpdateWorkbenchScroll()
    end
    function dialog:Valid() return pane.active and self.workspace==pane.workspace and self.generation==pane.generation and frame:IsShown() end
    function dialog:Sync()
        local snapshot=pane.workspace:Snapshot();local metadata=type(snapshot.metadata)=='table' and snapshot.metadata or {}
        pane.metadataDraft=data.CopyData(metadata)
        if not pane.descriptionDirty then pane.description:SetText(snapshot.description or (pane.workspace.readOnly and pane.workspace.description or '')) end
        if self.opened and not pane.descriptionDirty and not pane.metadataDirty then
            self.startMetadata=data.CopyData(metadata);self.startMetadataDirty=false;self.startDescription=pane.description:GetText();self.startDescriptionDirty=false
        end
        for _,entry in ipairs(definitions) do self.fields[entry[1]]:SetText(type(metadata[entry[1]])=='string' and metadata[entry[1]] or '') end
    end
    function dialog:Restore()
        if not pane.active or self.workspace~=pane.workspace or self.generation~=pane.generation then return end
        pane.metadataDraft=data.CopyData(self.startMetadata);pane.metadataDirty=self.startMetadataDirty
        pane.description:SetText(self.startDescription);pane.descriptionDirty=self.startDescriptionDirty;pane:UpdateHistory()
    end
    function dialog:Close(keep)
        if not keep then self:Restore() end
        self.closing=true;frame:Hide();self.closing=false;self.opened=false
    end
    function dialog:Open()
        if self:Valid() then addon:RegisterWindowForEscape(self);frame:Raise();return end
        self.openToken=(self.openToken or 0)+1
        self.workspace=pane.workspace;self.generation=pane.generation
        if not pane.metadataDirty then self:Sync() end
        self.startMetadata=data.CopyData(pane.metadataDraft);self.startMetadataDirty=pane.metadataDirty
        self.startDescription=pane.description:GetText();self.startDescriptionDirty=pane.descriptionDirty
        local readOnly=pane.workspace.readOnly
        local lines={}
        local source=pane.workspace.source;local seen={}
        local function sources(manifest)
            if type(manifest)~='table' then return end
            if type(manifest.sources)=='table' then for _,entry in ipairs(manifest.sources) do if type(entry)=='table' and type(entry.url)=='string' and not seen[entry.url] then
                seen[entry.url]=true;lines[#lines+1]=(type(entry.title)=='string' and entry.title or L['Source'])..'\n'..entry.url
            end end end
        end
        if source then sources(source.envelope) end
        local reserved=pane.workspace.reserved or {}
        for _,kind in ipairs({'origins','imports','comparisons'}) do local entry=reserved[kind];if type(entry)=='table' then sources(entry.manifest) end end
        self.note:SetText(readOnly and L['Packaged default: clone it to edit its metadata.'] or L['Use changes updates the draft. Apply the rotation to save it.'])
        if type(pane.workspace:Snapshot().metadata)~='table' and pane.workspace:Snapshot().metadata~=nil then self.note:SetText(string.format(L['Saved metadata is invalid (%s). Editing these fields replaces it.'],tostring(pane.workspace:Snapshot().metadata))) end
        self.chrome:SetContext(pane:RotationDisplayName(),L['Metadata'],pane:RotationDisplayName());self:Layout(table.concat(lines,'\n\n'));scroll.workbenchBar:SetValue(0);descriptionScroll.workbenchBar:SetValue(0)
        for _,input in pairs(self.fields) do input:EnableMouse(not readOnly) end
        if readOnly then self.apply:Disable() else self.apply:Enable() end
        local token=self.openToken;local owner=self.workspace
        local function valid() return self:Valid() and token==self.openToken and owner==self.workspace end
        for _,entry in ipairs(definitions) do local key=entry[1];local input=self.fields[key]
            addon:SetUIScript(input,'OnTextChanged',function(_,userInput)
                if not valid() or readOnly or not userInput then return end
                pane.metadataDraft=pane.metadataDraft or {};pane.metadataDraft[key]=input:GetText()~='' and input:GetText() or nil;pane.metadataDirty=true;pane:UpdateHistory()
            end)
            addon:SetUIScript(input,'OnEditFocusGained',readOnly and function(control) control:ClearFocus() end or nil)
        end
        addon:SetUIScript(self.apply,'OnClick',function()
            if not valid() or readOnly then return end
            if pane:FlushName() then self:Close(true);pane:Render() end
        end)
        local function cancel()
            if not valid() then return end
            self:Close(false)
        end
        addon:SetUIScript(self.cancel,'OnClick',cancel);addon:SetUIScript(self.close,'OnClick',cancel)
        self.opened=true;frame:SetFrameLevel(pane.frame:GetFrameLevel()+100);frame:Show();addon:RegisterWindowForEscape(self)
        scroll:UpdateWorkbenchScroll()
    end
    addon:SetUIScript(frame,'OnHide',function() if dialog.opened and not dialog.closing then dialog:Restore() end;dialog.opened=false;for _,input in pairs(dialog.fields) do input:ClearFocus() end end)
    function dialog:Hide() self:Close(false) end
    frame:Hide();addon.HideOnEscape(dialog);pane.metadataWindow=dialog
end
