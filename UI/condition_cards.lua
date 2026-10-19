local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function text(parent)
    local label=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');label:SetJustifyH('LEFT');label:SetWordWrap(true);return label
end
function addon:CreateConditionCard(parent)
    local card={frame=CreateFrame('Frame',nil,parent),controls={}}
    local frame=card.frame;frame:EnableMouse(true)
    card.decoration=addon:CreateRoundedCardDecoration(frame);card.borders=card.decoration.border
    card.header=CreateFrame('Button',nil,frame);card.header:EnableMouse(true);card.header:RegisterForDrag('LeftButton')
    card.summary=text(card.header);card.summary:SetPoint('TOPLEFT',0,-2);addon:InstallSpellHyperlinks(card.header)
    card.expand=addon:CreateConditionChevron(frame);card.expand:SetSize(18,18);card.expand:SetPoint('TOPLEFT',3,-3);card.expand.tooltip=L['Expand or collapse the card. Click action or condition text for details.']
    card.icon=frame:CreateTexture(nil,'ARTWORK');card.icon:SetSize(18,18);card.icon:SetPoint('TOPLEFT',25,-3)
    card.typeButton=addon:CreateWorkbenchButton(frame,'',210);card.typeButton:SetPoint('TOPLEFT',90,-2);card.typeButton.art:SetAlpha(.08);card.typeButton:RegisterForDrag('LeftButton')
    card.label=card.typeButton:GetFontString();card.label:ClearAllPoints();card.label:SetPoint('LEFT',3,0);card.label:SetJustifyH('LEFT');card.label:SetWordWrap(false)
    card.nameButton=addon:CreateWorkbenchButton(frame,'',182);card.nameButton.art:SetAlpha(.08);card.nameButton:RegisterForDrag('LeftButton')
    local nameLabel=card.nameButton:GetFontString();nameLabel:ClearAllPoints();nameLabel:SetPoint('LEFT',3,0);nameLabel:SetJustifyH('LEFT');nameLabel:SetWordWrap(false)
    card.name=addon:CreateWorkbenchEditBox(frame);card.name:SetSize(182,20);card.name:SetTextInsets(3,3,0,0);card.name:SetAutoFocus(false);card.name:SetMaxLetters(120);card.name:Hide()
    for _,entry in ipairs({{'up',L['Move Up'],'up'},{'down',L['Move Down'],'down'},
        {'remove',L['Remove condition'],'trash'},{'duplicate',L['Duplicate condition'],'copy'},{'ungroup',L['Ungroup'],'ungroup'}}) do
        card.controls[entry[1]]=addon:CreateWorkbenchIconButton(frame,entry[3],entry[2])
    end
    card.controls.up:SetSize(18,18);card.controls.down:SetSize(18,18)
    card.controls.duplicate:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-4,-24)
    card.controls.remove.icon:SetVertexColor(1,.3,.3,1)
    card.controls.help=addon:CreateWorkbenchHelpButton(frame,L['Help']);card.controls.help:SetSize(20,20);card.controls.help.icon:SetSize(18,18);card.controls.help:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-4,-3)
    card.fold=addon:CreateWorkbenchIconButton(frame,'branch',L['Show or hide branch paths']);card.fold:SetSize(18,18);card.fold:SetPoint('TOPLEFT',25,-3)
    card.controls.disable=addon:CreateWorkbenchPill(frame,'',64);card.controls.disable.tooltip=L['Enable or disable condition']
    card.controls.negate=addon:CreateWorkbenchPill(frame,'',40);card.controls.negate:SetPoint('TOPLEFT',46,-3);card.controls.negate.tooltip=L['If matches this condition; Unless negates it.']
    card.controls.operator=addon:CreateWorkbenchPill(frame,'',34);card.controls.operator:SetPoint('TOPLEFT',90,-3);card.controls.operator.tooltip=L['Switch All / Any']
    card.fields=CreateFrame('Frame',nil,frame)
    function card:Place(model,title,summary)
        local editingName=self.name:HasFocus()
        frame:ClearAllPoints();frame:SetPoint('TOPLEFT',parent,'TOPLEFT',model.x,-model.y);frame:SetSize(model.width,model.height);self.model=model;addon:SetWorkbenchUnsaved(frame,model.changed)
        local gray=model.disabled or model.unreachable;local r,g,b=.25,.55,.32
        if model.invalid then r,g,b=.8,.24,.20 elseif gray then r,g,b=.4,.4,.4 elseif model.negated then r,g,b=.8,.24,.20 end
        self.decoration:SetColors(r,g,b,model.selected and 1 or .65,model.group and .025 or .05)
        frame:SetAlpha(gray and .65 or 1)
        self.label:SetText(title);self.summary:SetText(summary or '');self.icon:SetTexture(addon:GetConditionIcon(model.type));self.icon:SetAlpha(gray and .4 or 1)
        self.label:SetTextColor(gray and .5 or .9,gray and .5 or .92,gray and .5 or .9)
        self.summary:SetTextColor(model.invalid and 1 or .65,model.invalid and .4 or .7,model.invalid and .32 or .65)
        self.expand:PointState(model.compact and 'compact' or model.expanded and 'expanded' or 'normal')
        local header=model.headerHeight or 26;local contentWidth=model.width-(model.group and 82 or 58)
        self.header:ClearAllPoints();self.header:SetPoint('TOPLEFT',26,-header);self.header:SetSize(contentWidth,math.max(18,model.ownHeight-header-4));self.summary:SetWidth(contentWidth)
        self.fields:ClearAllPoints();self.fields:SetPoint('TOPLEFT',26,-header);self.fields:SetSize(contentWidth,math.max(1,model.ownHeight-header-4));if not editingName then self.name:Hide() end
        self.typeButton:SetWidth(model.width-186);self.label:SetWidth(model.width-192)
        self.nameButton:ClearAllPoints();self.name:ClearAllPoints()
        self.nameButton:SetPoint('TOPLEFT',model.group and 128 or 90,model.group and -2 or -23)
        self.name:SetPoint('TOPLEFT',model.group and 128 or 90,model.group and -2 or -23)
        local nameWidth=model.width-(model.group and 224 or 120);self.nameButton:SetWidth(nameWidth);nameLabel:SetWidth(nameWidth-6);self.name:SetWidth(nameWidth)
        if model.group then self.typeButton:Hide() else self.typeButton:Show() end
        if model.group or (model.name and model.name~='') then self.nameButton:SetText(addon:PlainWorkbenchName(model.name and model.name~='' and model.name or L['Click to add group name']));self.nameButton:Show() else self.nameButton:Hide() end
        self.controls.up:ClearAllPoints();self.controls.down:ClearAllPoints();self.controls.up:SetPoint('TOPLEFT',frame,'TOPLEFT',4,-26);self.controls.down:SetPoint('TOPLEFT',self.controls.up,'BOTTOMLEFT',0,0)
        local footer=model.ownHeight-22
        self.controls.remove:ClearAllPoints();self.controls.remove:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-4,model.group and -64 or -44)
        self.controls.disable:ClearAllPoints();self.controls.disable:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-28,-4)
        self.controls.ungroup:ClearAllPoints();self.controls.ungroup:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-4,-44)
        self.controls.disable:SetText(model.disabled and L['Disabled'] or L['Enabled']);self.controls.disable:SetSelected(not model.disabled)
        nameLabel:SetTextColor(gray and .5 or .9,gray and .5 or .92,gray and .5 or .9)
        self.controls.negate:SetText(model.negated and L['Unless'] or L['If']);self.controls.negate:SetAccent(model.negated and .8 or .3,model.negated and .25 or .6,.3);self.controls.negate:SetSelected(true)
        if model.group then self.controls.operator:SetAccent(.85,.65,.15);self.controls.operator:SetText(model.type=='AND' and L['All'] or L['Any']);self.controls.operator:SetSelected(true);self.controls.operator:Show();self.controls.ungroup:Show() else self.controls.operator:Hide();self.controls.ungroup:Hide() end
        if model.expanded then self.fields:Show();self.header:Hide() else self.fields:Hide();self.header:Show() end
        if model.compact then
            for _,control in pairs(self.controls) do control:Hide() end
            self.icon:Hide();self.typeButton:Hide();self.header:Hide();self.fields:Hide()
            self.nameButton:ClearAllPoints();self.nameButton:SetPoint('TOPLEFT',model.group and 48 or 26,-3);self.nameButton:SetWidth(model.width-(model.group and 74 or 52));nameLabel:SetWidth(self.nameButton:GetWidth()-6)
            self.nameButton:SetText(addon:PlainWorkbenchName(model.name and model.name~='' and model.name or (model.group and (model.type=='AND' and L['All of'] or L['Any of']) or summary or title)));self.nameButton:Show()
        else
            self.icon:Show()
            for key,control in pairs(self.controls) do if key~='operator' and key~='ungroup' or model.group then control:Show() end end
        end
        if model.group then self.fold:Show();self.fold:SetSelected(model.collapsed);self.icon:Hide() else self.fold:Hide() end
        self.name:ClearAllPoints();self.name:SetPoint('TOPLEFT',self.nameButton,'TOPLEFT',0,0);self.name:SetSize(self.nameButton:GetWidth(),self.nameButton:GetHeight())
        if editingName then self.name:Show();self.nameButton:Hide() end
        if self.pane and self.pane.frame:GetWidth()~=contentWidth then self.pane:SetWidth(contentWidth) end
        frame:Show()
    end
    function card:Release()
        self.token=nil;if self.helpText then self.helpText:Hide() end;if self.picker then self.picker:Release() end
        if self.releaseFields then self.releaseFields();self.releaseFields=nil end
        self.pane=nil;self.proxy=nil;self.model=nil;self.frame:Hide();self.name:ClearFocus()
        for _,event in ipairs({'OnClick','OnMouseDown','OnDragStart','OnDragStop'}) do addon:SetUIScript(self.header,event,nil);addon:SetUIScript(self.nameButton,event,nil);addon:SetUIScript(self.typeButton,event,nil) end
        for _,control in pairs(self.controls) do addon:SetUIScript(control,'OnClick',nil) end
        for _,event in ipairs({'OnEditFocusGained','OnEditFocusLost','OnUpdate'}) do addon:SetUIScript(self.name,event,nil) end
        addon:SetUIScript(self.fold,'OnClick',nil);addon:SetUIScript(frame,'OnMouseDown',nil);addon:SetUIScript(frame,'OnDragStart',nil);addon:SetUIScript(frame,'OnDragStop',nil);addon:SetUIScript(self.expand,'OnClick',nil);addon:SetUIScript(self.name,'OnTextChanged',nil);addon:SetUIScript(self.name,'OnEnterPressed',nil);addon:SetUIScript(self.name,'OnEscapePressed',nil)
    end
    return card
end
