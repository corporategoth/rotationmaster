local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local tones={white={.85,.85,.85},green={.25,.55,.32},red={.8,.24,.2},gray={.4,.4,.4}}
function addon:CreateRotationCard(parent)
    local card={frame=CreateFrame('Frame',nil,parent),controls={}}
    local frame=card.frame;frame:EnableMouse(true)
    card.decoration=self:CreateRoundedCardDecoration(frame)
    card.expand=self:CreateConditionChevron(frame);card.expand:SetPoint('TOPLEFT',4,-4);card.expand.tooltip=L['Expand or collapse the card. Click action or condition text for details.']
    card.title=self:CreateWorkbenchButton(frame,'',268);card.title:SetPoint('TOPLEFT',26,-3);card.title.art:SetAlpha(.1)
    card.title:RegisterForDrag('LeftButton')
    card.name=self:CreateWorkbenchEditBox(frame);card.name:SetSize(248,24);card.name:SetTextInsets(3,3,0,0);card.name:SetPoint('TOPLEFT',32,-5);card.name:SetMaxLetters(120);card.name:Hide()
    card.preview=CreateFrame('Frame',nil,frame);card.preview:SetSize(18,18);card.preview:SetPoint('TOPLEFT',26,-27)
    card.icon=card.preview:CreateTexture(nil,'ARTWORK');card.icon:SetAllPoints(card.preview)
    card.action=self:CreateWorkbenchButton(frame,'',256);card.action:SetPoint('TOPLEFT',48,-25);card.action.art:SetAlpha(.08)
    card.condition=self:CreateWorkbenchButton(frame,'',280);card.condition.tooltip=L['Click condition text on any card to view or edit its conditions.'];card.condition:SetPoint('TOPLEFT',26,-46);card.condition:SetHeight(24)
    local caption=card.condition:GetFontString();caption:ClearAllPoints();caption:SetPoint('LEFT',3,0);caption:SetWidth(274);caption:SetJustifyH('LEFT');caption:SetWordWrap(true)
    for _,entry in ipairs({{'up','up',L['Move Up']},{'down','down',L['Move Down']},{'duplicate','copy',L['Duplicate']},{'remove','trash',L['Delete']}}) do
        card.controls[entry[1]]=self:CreateWorkbenchIconButton(frame,entry[2],entry[3])
    end
    card.controls.up:SetSize(18,18);card.controls.down:SetSize(18,18);card.controls.up:SetPoint('TOPLEFT',4,-28);card.controls.down:SetPoint('TOPLEFT',4,-46)
    card.controls.duplicate:SetPoint('TOPRIGHT',-5,-24);card.controls.remove.icon:SetVertexColor(1,.3,.3,1)
    card.controls.enable=self:CreateWorkbenchPill(frame,'',64)
    card.armToggle=self:CreateWorkbenchIconButton(frame,'branch',L['Show or hide branch paths']);card.armToggle:SetPoint('TOPLEFT',28,-4);card.armToggle:SetSize(18,18)
    card.controls.help=self:CreateWorkbenchHelpButton(frame,L['Help']);card.controls.help:SetSize(20,20);card.controls.help.icon:SetSize(18,18);card.controls.help:SetPoint('TOPRIGHT',-5,-3)
    card.fields=CreateFrame('Frame',nil,frame)
    function card:Place(model,readOnly)
        self.model=model;frame:ClearAllPoints();frame:SetPoint('TOPLEFT',parent,'TOPLEFT',model.x,-model.y);frame:SetSize(model.width,model.height)
        self:SetValidation(model.invalid)
        local step=model.step;local branch=step.type=='branch';local normal=not model.compact and not model.expanded
        local action=branch and L['Click to add branch name'] or step.type=='none' and L['Stop'] or
            (step.type=='spell' or step.type=='pet' or step.type=='any') and addon:SpellLabel(step.action) or L['Item']
        self.defaultTitle=branch and model.compact and addon:DescribeCardCondition(step.conditions or {},self.spec) or action
        if not branch then local info=addon.Platform and addon.Platform:GetSpellInfo(step.action);if info and (step.type=='spell' or step.type=='pet' or step.type=='any') then self.defaultTitle=info.name end end
        if not branch then self.defaultTitle=addon:PlainWorkbenchName(self.defaultTitle):gsub('^%[(.*)%]$','%1') end
        local suppliedName=model.displayName;if suppliedName==nil then suppliedName=step.name end
        self.title:SetText(addon:PlainWorkbenchName(suppliedName and suppliedName~='' and suppliedName or self.defaultTitle))
        local pillWidth=branch and 118 or 64
        self.title:ClearAllPoints();self.title:SetPoint('TOPLEFT',branch and 50 or 26,-3)
        self.title:SetWidth((model.compact and model.width-52 or model.width-pillWidth-56)-(branch and 24 or 0));addon:AlignWorkbenchTextLeft(self.title,3)
        if branch then self.armToggle:Show();self.armToggle:SetSelected(model.collapsed) else self.armToggle:Hide() end
        self.name:ClearAllPoints();self.name:SetPoint('TOPLEFT',self.title,'TOPLEFT',0,0);self.name:SetSize(self.title:GetWidth(),self.title:GetHeight())
        self.action:SetText(action);self.action:SetWidth(math.max(256,model.width-84));addon:AlignWorkbenchTextLeft(self.action,3)
        self.condition:ClearAllPoints();self.condition:SetPoint('TOPLEFT',26,branch and -28 or -46)
        self.condition:SetText(addon:PlainWorkbenchName(model.pendingProblem and string.format(L['Incomplete input: %s'],model.pendingProblem) or addon:DescribeCardCondition(step.conditions or {},self.spec)))
        local ownHeader=model.headerHeight or 84
        self.condition:SetHeight(math.max(24,ownHeader-(branch and 32 or model.section=='cooldowns' and 54 or 50)))
        self.condition:GetFontString():SetTextColor(model.invalid and 1 or .7,model.invalid and .35 or .75,model.invalid and .3 or .7)
        local spell=addon.Platform and addon.Platform:GetSpellInfo(step.action)
        self.icon:SetTexture(spell and spell.iconID or addon:GetConditionIcon(step.conditions and step.conditions.type));self.icon:SetAlpha(model.inactive and .4 or 1)
        self.expand:PointState(model.compact and 'compact' or model.expanded and 'expanded' or 'normal')
        self.controls.enable:SetWidth(pillWidth);self.controls.enable:ClearAllPoints();self.controls.enable:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-28,-4)
        self.controls.remove:ClearAllPoints();self.controls.remove:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-4,-44)
        self.controls.enable:SetText(branch and ((step.mode or 'evaluate')=='evaluate' and L['Evaluate condition'] or step.mode=='true' and L['Always true'] or L['Always false']) or step.disabled and L['Disabled'] or L['Enabled'])
        self.controls.enable:SetSelected(branch and step.mode=='true' or not branch and not step.disabled)
        self.fields:ClearAllPoints();self.fields:SetPoint('TOPLEFT',28,-28);self.fields:SetSize(model.width-56,math.max(1,model.height-28-((model.conditionHeight or 0)>0 and model.conditionHeight+4 or 0)))
        if model.expanded then self.fields:Show() else self.fields:Hide() end
        for _,control in pairs(self.controls) do if model.compact then control:Hide() else control:Show() end end
        if not model.compact and (normal or (model.conditionHeight or 0)>0) then self.condition:Show() else self.condition:Hide() end
        if normal and not branch then self.action:Show();self.preview:Show() else self.action:Hide();self.preview:Hide() end
        if model.section=='cooldowns' then self.controls.up:Hide();self.controls.down:Hide() end
        if model.section=='cooldowns' and normal then
            self.preview:SetSize(36,36);self.preview:SetPoint('TOPLEFT',26,-28);self.action:SetPoint('TOPLEFT',68,-26);self.action:SetWidth(model.width-96)
            self.condition:SetPoint('TOPLEFT',68,-50);self.condition:SetWidth(model.width-96);self.condition:GetFontString():SetWidth(model.width-102)
            local profile=addon.db.profile;local effect=(addon.db.global.effects or {})[step.effect or profile.effect]
            if effect and addon.Glow then addon:Glow(self.preview,'rotation-card-preview',effect,addon:ResolveHighlightColor(step.color),step.magnification or profile.magnification or 1,step.setpoint or profile.setpoint or 'CENTER',step.xoffs or profile.xoffs or 0,step.yoffs or profile.yoffs or 0,step.angle) end
        else
            self.preview:SetSize(18,18);self.preview:SetPoint('TOPLEFT',26,-27);self.action:SetPoint('TOPLEFT',48,-25)
            self.condition:SetWidth(math.max(280,model.width-60));self.condition:GetFontString():SetWidth(math.max(274,model.width-66))
        end
        if (model.conditionHeight or 0)>0 then
            self.condition:ClearAllPoints();self.condition:SetPoint('TOPLEFT',26,-model.height+model.conditionHeight+4);self.condition:SetSize(model.width-56,model.conditionHeight);self.condition:GetFontString():SetWidth(model.width-62)
        end
        if self.name:HasFocus() then self.name:Show();self.title:Hide()
        else self.name:Hide();self.title:Show() end
        for key,control in pairs(self.controls) do if (readOnly and key~='help') or (key=='up' and not model.canMoveUp) or (key=='down' and not model.canMoveDown) then control:Disable() else control:Enable() end end
        frame:SetAlpha(model.inactive and .6 or 1);frame:Show()
    end
    -- A selected card wears a gold outline over its border.
    function card:SetSelected(selected)
        if selected and not self.selection then
            self.selection={}
            for _,side in ipairs({{'TOPLEFT','TOPRIGHT','h'},{'BOTTOMLEFT','BOTTOMRIGHT','h'},{'TOPLEFT','BOTTOMLEFT','v'},{'TOPRIGHT','BOTTOMRIGHT','v'}}) do
                local edge=frame:CreateTexture(nil,'OVERLAY');edge:SetColorTexture(1,.82,.2,.95);edge:SetPoint(side[1]);edge:SetPoint(side[2])
                if side[3]=='h' then edge:SetHeight(2) else edge:SetWidth(2) end;self.selection[#self.selection+1]=edge
            end
        end
        self.selected=selected==true
        for _,edge in ipairs(self.selection or {}) do if self.selected then edge:Show() else edge:Hide() end end
    end
    function card:SetValidation(invalid)
        self.model.invalid=invalid
        local tone=invalid and tones.red or tones[self.model.border] or tones.green
        self.decoration:SetColors(tone[1],tone[2],tone[3],.75,.06)
    end
    function card:Release()
        self.token=nil;self.frame:Hide();self.name:ClearFocus();self:SetSelected(false)
        if addon.HideGlow then addon:HideGlow(self.preview,'rotation-card-preview') end
        if self.fieldSpellIcon then self.fieldSpellIcon:Hide() end
        if self.releaseFields then self.releaseFields();self.releaseFields=nil end
        for _,control in pairs(self.controls) do addon:SetUIScript(control,'OnClick',nil) end
        for _,control in ipairs({self.title,self.action,self.condition,self.expand,self.armToggle,self.frame}) do
            for _,event in ipairs({'OnClick','OnMouseDown','OnMouseUp','OnMouseWheel','OnDragStart','OnDragStop','OnEnter','OnLeave'}) do if control:HasScript(event) then addon:SetUIScript(control,event,nil) end end
        end
        for _,event in ipairs({'OnEditFocusGained','OnEditFocusLost','OnUpdate'}) do addon:SetUIScript(self.name,event,nil) end
        addon:SetUIScript(self.name,'OnTextChanged',nil);addon:SetUIScript(self.name,'OnEnterPressed',nil);addon:SetUIScript(self.name,'OnEscapePressed',nil)
    end
    return card
end
