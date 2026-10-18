local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local colors={green={.25,.7,.35},red={.85,.3,.25},gray={.4,.4,.4},neutral={.55,.58,.6}}
local function finite(value) return type(value)=='number' and value==value and value>-math.huge and value<math.huge end
local function zoom(value) return finite(value) and math.max(.25,math.min(2,value)) or 1 end
local function location(path) return table.concat(path,'/') end
local function moveCommand(snapshot,id,destination)
    local row=addon.RotationData.IndexRotationSteps(snapshot).byId[id]
    local path={};if row then for i=1,#row.path-1 do path[i]=row.path[i] end end
    return row and row.section=='rotation' and destination.parentId and location(path)~=location(destination.path) and 'MoveTail' or 'Move'
end
function addon:CreateRotationCanvas(parent,owner)
    local canvas={frame=addon:CreateWorkbenchScrollFrame(parent),cards={},lines={},labels={},zones={},generation=0}
    canvas.surface=CreateFrame('Frame',nil,canvas.frame);canvas.frame:SetScrollChild(canvas.surface)
    canvas.child=CreateFrame('Frame',nil,canvas.surface);canvas.child:SetPoint('TOPLEFT')
    canvas.horizontal=addon:CreateWorkbenchScrollBar(parent,'HORIZONTAL')
    addon:SetUIScript(canvas.horizontal,'OnValueChanged',function(_,value) canvas.scrollX=value;canvas.frame:SetHorizontalScroll(value) end)
    canvas.ghost=addon:CreateWorkbenchDragCard()
    function canvas:CancelDrag()
        self.drag=nil;self.pan=nil;self.ghost:Hide();addon:SetUIScript(self.frame,'OnUpdate',nil)
        for _,zone in ipairs(self.zones) do zone.marker:Hide();zone:Hide() end
    end
    function canvas:GetZoom() return zoom(owner.view.zoom) end
    function canvas:SetZoom(value)
        if not owner.active or not finite(value) then return nil end
        local previous=self:GetZoom();local nextZoom=zoom(value)
        local x=((self.scrollX or 0)+self.frame:GetWidth()/2)*nextZoom/previous-self.frame:GetWidth()/2
        local y=(self.frame.workbenchBar:GetValue()+self.frame:GetHeight()/2)*nextZoom/previous-self.frame:GetHeight()/2
        self:CancelDrag();owner.view.zoom=nextZoom;self.scrollX=x;self:Reflow()
        self.horizontal:SetValue(x);self.frame.workbenchBar:SetValue(y)
        return true
    end
    function canvas:BeginPan()
        if not owner.active or self.drag or type(GetCursorPosition)~='function' then return false end
        for _,card in ipairs(self.cards) do
            if card.frame:IsShown() and addon:IsWorkbenchDropZoneUnderPointer(card.frame,self.frame) then return false end
        end
        local ok,x,y=pcall(GetCursorPosition);local scale=self.frame:GetEffectiveScale()
        if not ok or not finite(x) or not finite(y) or not finite(scale) or scale<=0 then return false end
        self:CancelDrag()
        local request={x=x,y=y,scale=scale,scrollX=self.scrollX or 0,scrollY=self.frame.workbenchBar:GetValue(),generation=self.generation}
        self.pan=request
        addon:SetUIScript(self.frame,'OnUpdate',function()
            if self.pan~=request then return end
            if not owner.active or request.generation~=self.generation or IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then self:CancelDrag();return end
            local valid,cx,cy=pcall(GetCursorPosition)
            if not valid or not finite(cx) or not finite(cy) then self:CancelDrag();return end
            self.horizontal:SetValue(request.scrollX-(cx-request.x)/request.scale)
            self.frame.workbenchBar:SetValue(request.scrollY+(cy-request.y)/request.scale)
        end)
        return true
    end
    for _,surface in ipairs({canvas.child,canvas.surface}) do
        surface:EnableMouse(true);surface:RegisterForDrag('LeftButton')
        addon:SetUIScript(surface,'OnDragStart',function() canvas:BeginPan() end)
        addon:SetUIScript(surface,'OnDragStop',function() if canvas.pan then canvas:CancelDrag() end end)
        addon:SetUIScript(surface,'OnHide',function() canvas:CancelDrag() end)
    end
    function canvas:CanDrop(target)
        local drag=self.drag
        if not drag or not owner.active or owner.workspace.readOnly or drag.generation~=self.generation then return false end
        local d=target.destination;local key=location(d.path)..':'..d.index..':'..(d.parentId or '')
        if drag.valid[key]~=nil then return drag.valid[key] end
        local draft=addon.RotationData.NewRotationDraft(owner.workspace:Snapshot(),addon.uuid)
        local command=drag.insert and 'Insert' or moveCommand(owner.workspace:Snapshot(),drag.id,d)
        local ok=draft and draft:Command(command,drag.insert and d or drag.id,drag.insert or d)
        if ok and not drag.insert then
            local before=addon.RotationData.IndexRotationSteps(owner.workspace:Snapshot()).byId[drag.id]
            local after=addon.RotationData.IndexRotationSteps(draft:Snapshot()).byId[drag.id]
            if before and after and location(before.path)==location(after.path) then ok=false end
        end
        drag.valid[key]=ok==true;return ok==true
    end
    function canvas:HoverTarget()
        local selected
        for _,zone in ipairs(self.zones) do if zone:IsShown() and addon:IsWorkbenchDropZoneUnderPointer(zone,self.frame) and self:CanDrop(zone.target) then selected=zone;break end end
        for _,zone in ipairs(self.zones) do if zone==selected then zone.marker:Show() else zone.marker:Hide() end end
        return selected
    end
    function canvas:Drop(target)
        local drag=self.drag;local valid=self:CanDrop(target);self:CancelDrag()
        if not valid or not drag or drag.generation~=self.generation then return end
        local command=drag.insert and 'Insert' or moveCommand(owner.workspace:Snapshot(),drag.id,target.destination)
        return owner:Command(command,drag.insert and target.destination or drag.id,drag.insert or target.destination)
    end
    function canvas:EndDrag()
        if not self.drag then return end
        local zone=self:HoverTarget();if zone then return self:Drop(zone.target) end;self:CancelDrag()
    end
    function canvas:BeginDrag(id,insert)
        self:CancelDrag();if not owner.active or owner.workspace.readOnly then return end
        self.drag={id=id,insert=insert,generation=self.generation,valid={}}
        local step=insert or addon.RotationData.IndexRotationSteps(owner.workspace:Snapshot()).byId[id].step
        local title=step.name or (step.type=='branch' and L['Add branch'] or step.type=='none' and L['Stop'] or addon:SpellLabel(step.action))
        self.ghost:Present(title,addon:DescribeCondition(step.conditions or {},owner.workspace.spec)..'\n'..L['Drop in a highlighted gap.'],self.frame)
        for _,zone in ipairs(self.zones) do zone:Show() end
        addon:SetUIScript(self.frame,'OnUpdate',function()
            if not owner.active or not self.drag or self.drag.generation~=self.generation then self:CancelDrag();return end
            self.ghost:FollowPointer();self:HoverTarget()
            if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then self:EndDrag() end
        end)
    end
    function canvas:LayoutScrollBar()
        self.horizontal:ClearAllPoints();self.horizontal:SetPoint('TOPLEFT',self.frame,'BOTTOMLEFT',0,-4);self.horizontal:SetWidth(self.frame:GetWidth())
    end
    function canvas:Reflow()
        if not owner.active then return end
        local scene=owner:BuildScene();self.scene=scene
        if not scene then return end
        local factor=self:GetZoom()
        self.child:SetSize(scene.width,scene.height);self.child:SetScale(factor)
        self.surface:SetSize(math.max(self.frame:GetWidth(),scene.width*factor),math.max(self.frame:GetHeight(),scene.height*factor))
        if owner.LayoutSections then owner:LayoutSections(scene,self.child) end
        local range=math.max(0,scene.width*factor-self.frame:GetWidth())
        self.horizontal:UpdateExtent(scene.width*factor,self.frame:GetWidth());self.horizontal:SetValue(math.min(self.scrollX or 0,range))
        if range>0 then self.horizontal:Show() else self.horizontal:Hide();self.frame:SetHorizontalScroll(0) end
        for i,model in ipairs(scene.cards) do if self.cards[i] then self.cards[i]:Place(model,owner.workspace.readOnly) end end
        local n=0
        for _,edge in ipairs(scene.connectors) do
            local tone=colors[edge.tone] or colors.neutral
            for i=2,#edge.points do
                n=n+1;local line=self.lines[n]
                if not line then line=self.child:CreateTexture(nil,'BACKGROUND');self.lines[n]=line end
                local a,b=edge.points[i-1],edge.points[i]
                line:ClearAllPoints();line:SetPoint('TOPLEFT',self.child,'TOPLEFT',math.min(a.x,b.x),-math.min(a.y,b.y))
                line:SetSize(math.max(2,math.abs(a.x-b.x)+2),math.max(2,math.abs(a.y-b.y)+2));line:SetColorTexture(tone[1],tone[2],tone[3],edge.inactive and .25 or .8);line:Show()
            end
        end
        for i=n+1,#self.lines do self.lines[i]:Hide() end
        local labels=0
        for _,edge in ipairs(scene.connectors) do if edge.label then
            labels=labels+1;local label=self.labels[labels]
            if not label then label=self.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');self.labels[labels]=label end
            local point=edge.points[2];local tone=colors[edge.tone] or colors.neutral
            label:ClearAllPoints();label:SetPoint('TOPLEFT',self.child,'TOPLEFT',point.x+(edge.arm=='false' and -40 or 8),-point.y+14)
            label:SetText(edge.arm=='true' and L['True'] or L['False']);label:SetTextColor(tone[1],tone[2],tone[3]);label:Show()
        end end
        for _,arm in ipairs(scene.armLabels or {}) do
            labels=labels+1;local label=self.labels[labels]
            if not label then label=self.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');self.labels[labels]=label end
            local tone=arm.arm=='false' and colors.red or colors.green
            label:ClearAllPoints();label:SetPoint('TOPLEFT',self.child,'TOPLEFT',arm.x,-arm.y)
            label:SetText(arm.arm=='true' and L['True'] or L['False']);label:SetTextColor(tone[1],tone[2],tone[3],arm.inactive and .3 or 1);label:Show()
        end
        for i=labels+1,#self.labels do self.labels[i]:Hide() end
        for i,target in ipairs(scene.dropTargets) do
            local zone=self.zones[i]
            if not zone then zone=CreateFrame('Frame',nil,self.child);zone:EnableMouse(false);zone.marker=zone:CreateTexture(nil,'OVERLAY');zone.marker:SetColorTexture(.9,.75,.3,.95);zone.marker:SetPoint('LEFT');zone.marker:SetPoint('RIGHT');zone.marker:SetHeight(3);self.zones[i]=zone end
            zone.target=target;zone:ClearAllPoints();zone:SetPoint('TOPLEFT',self.child,'TOPLEFT',target.x,-target.y);zone:SetSize(target.width,target.height);zone.marker:Hide()
            if self.drag then zone:Show() else zone:Hide() end
        end
        for i=#scene.dropTargets+1,#self.zones do self.zones[i]:Hide() end
        self.frame:UpdateScrollChildRect();self.frame:UpdateWorkbenchScroll();owner:UpdateHistory();if owner.UpdateCanvasNavigation then owner:UpdateCanvasNavigation() end
    end
    function canvas:Render()
        self:CancelDrag();self.generation=self.generation+1
        for _,card in ipairs(self.cards) do card:Release() end
        if not owner.active then return end
        local scene=owner:BuildScene();self.scene=scene;if not scene then return end
        for i,model in ipairs(scene.cards) do
            local card=self.cards[i];if not card then card=addon:CreateRotationCard(self.child);self.cards[i]=card end
            local token=self.generation;card.token=token;card.spec=owner.workspace.spec
            local function alive() return owner.active and token==self.generation and card.token==token end
            local function writable() return alive() and not owner.workspace.readOnly end
            card:Place(model,owner.workspace.readOnly)
            owner.view.summaryHeights=owner.view.summaryHeights or {}
            local summary=card.condition:GetFontString();if summary.GetStringHeight then owner.view.summaryHeights[model.id]=summary:GetStringHeight()+4 end
            local step=model.step
            addon:SetUIScript(card.expand,'OnClick',function()
                if not alive() then return end
                owner.view.cardStates=owner.view.cardStates or {}
                owner.view.cardStates[model.id]=model.compact and 'normal' or model.expanded and 'normal' or 'compact';self:Render()
            end)
            addon:SetUIScript(card.title,'OnClick',function() if alive() and model.compact then owner.view.cardStates[model.id]='normal';owner:Render();return end;if writable() then card.name:SetText(addon:PlainWorkbenchName(owner:FieldText(model.id,'name',step.name or '')));card.title:Hide();card.name:Show();card.name:SetFocus() end end)
            addon:BindWorkbenchInlineName(card.name,function() if alive() then card.name:Hide();card.title:Show();local name=owner:FieldText(model.id,'name',step.name or '');if name=='' then name=card.defaultTitle end;card.title:SetText(addon:PlainWorkbenchName(name)) end end)
            addon:SetUIScript(card.name,'OnTextChanged',function(input,userInput) if writable() and userInput then owner:StageField(model.id,'name',input:GetText(),step.name or '',L['Name']) end end)
            addon:SetUIScript(card.name,'OnEnterPressed',function(input)
                if not writable() then return end
                owner:StageField(model.id,'name',input:GetText(),step.name or '',L['Name'])
                local ok,why=owner:FlushFieldEdits();if ok then owner:Render() else owner:Message(why) end
            end)
            local pendingName=owner:FieldText(model.id,'name',step.name or '')
            if pendingName~='' then card.title:SetText(addon:PlainWorkbenchName(pendingName)) end
            addon:SetUIScript(card.name,'OnEscapePressed',function() card.name:ClearFocus();card.name:Hide();card.title:Show() end)
            addon:SetUIScript(card.title,'OnDragStart',function() if writable() then self:BeginDrag(model.id) end end)
            addon:SetUIScript(card.title,'OnDragStop',function() if alive() then self:EndDrag() end end)
            local function actionLink()
                if step.type~='spell' and step.type~='pet' and step.type~='any' then return end
                local info=addon.Platform and addon.Platform:GetSpellInfo(step.action)
                if info and info.spellID then return 'spell:'..info.spellID end
            end
            addon:SetUIScript(card.action,'OnEnter',function(control)
                if not alive() then return end
                local link=actionLink();if link and GameTooltip then GameTooltip:SetOwner(control,'ANCHOR_RIGHT');GameTooltip:SetHyperlink(link) end
            end)
            addon:SetUIScript(card.action,'OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
            addon:SetUIScript(card.action,'OnClick',function(_,button)
                if not alive() then return end
                local link=actionLink()
                if IsShiftKeyDown and IsShiftKeyDown() and link and type(SetItemRef)=='function' then SetItemRef(link,addon:SpellLabel(step.action),button or 'LeftButton')
                else owner.view.cardStates[model.id]='expanded';self:Render() end
            end)
            addon:SetUIScript(card.condition,'OnClick',function() if alive() then owner:EditCondition(model.id) end end)
            addon:SetUIScript(card.condition,'OnEnter',function(control)
                if alive() and GameTooltip then GameTooltip:SetOwner(control,'ANCHOR_RIGHT');GameTooltip:SetText(control.tooltip,1,1,1,1,true) end
            end)
            addon:SetUIScript(card.condition,'OnLeave',function(control)
                if alive() and GameTooltip and GameTooltip:IsOwned(control) then GameTooltip:Hide() end
            end)
            addon:SetUIScript(card.controls.remove,'OnClick',function() if writable() then owner:Command('Remove',model.id) end end)
            addon:SetUIScript(card.controls.duplicate,'OnClick',function() if writable() then owner:Command('Duplicate',model.id) end end)
            addon:SetUIScript(card.controls.enable,'OnClick',function()
                if not writable() then return end
                if step.type=='branch' then owner:Command('UpdateStep',model.id,{mode=(step.mode or 'evaluate')=='evaluate' and 'true' or step.mode=='true' and 'false' or 'evaluate'})
                else owner:Command('UpdateStep',model.id,{disabled=not step.disabled}) end
            end)
            for _,direction in ipairs({{'up',-1},{'down',1}}) do
                local delta=direction[2];addon:SetUIScript(card.controls[direction[1]],'OnClick',function()
                    if not writable() then return end
                    local path={};for j=1,#model.path-1 do path[j]=model.path[j] end
                    local at=model.path[#model.path]+(delta>0 and 2 or -1)
                    owner:Command('Move',model.id,{path=path,index=at,parentId=model.parentId})
                end)
            end
            addon:SetUIScript(card.controls.help,'OnClick',function() if alive() then owner:ShowCardHelp(model) end end)
            addon:SetUIScript(card.armToggle,'OnClick',function() if alive() then owner.view.hiddenChildren[model.id]=not owner.view.hiddenChildren[model.id];self:Render() end end)
            for _,source in ipairs({card.title,card.action,card.condition,card.frame}) do
                addon:BindWorkbenchDragSource(source,function() if writable() then self:BeginDrag(model.id) end end,function() if alive() then self:EndDrag() end end)
            end
            if model.expanded and owner.BuildFields then owner:BuildFields(card,model,alive) end
        end
        self:Reflow()
    end
    function canvas:Release()
        self:CancelDrag();self.generation=self.generation+1
        for _,card in ipairs(self.cards) do card:Release() end
        self.horizontal:Hide();self.frame:Hide()
    end
    return canvas
end
