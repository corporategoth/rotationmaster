local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local function pathCopy(path) local result={};for i,p in ipairs(path) do result[i]=p end;return result end
local function prefix(a,b)
    if #a>#b then return false end
    for i,p in ipairs(a) do if b[i]~=p then return false end end;return true
end
local function sibling(a,b)
    if #a~=#b or type(a[#a])~="number" or type(b[#b])~="number" then return false end
    for i=1,#a-1 do if a[i]~=b[i] then return false end end;return true
end
function addon:CreateConditionCanvas(parent,owner)
    local canvas={frame=addon:CreateWorkbenchScrollFrame(parent),cards={},lines={},zones={},generation=0,owner=owner}
    canvas.child=CreateFrame("Frame",nil,canvas.frame);canvas.frame:SetScrollChild(canvas.child)
    function canvas:Selection()
        local result={};if not owner.active then return result end
        for _,row in ipairs(owner.active.session:Rows(4096)) do
            if owner.view.selection[addon.ConditionPathKey(row.path)] then result[#result+1]=pathCopy(row.path) end
        end
        return result
    end
    function canvas:Select(path,control,shift)
        if not owner.active or not owner:SyncWorking() then return end
        local key=addon.ConditionPathKey(path);local selection=owner.view.selection
        local rows=owner.active.session:Rows(4096)
        if shift and self.anchor and sibling(path,self.anchor) then
            if not control then selection={} end
            local low,high=math.min(path[#path],self.anchor[#path]),math.max(path[#path],self.anchor[#path])
            for _,row in ipairs(rows) do
                if sibling(path,row.path) and row.path[#path]>=low and row.path[#path]<=high then
                    for _,other in ipairs(rows) do
                        if prefix(other.path,row.path) or prefix(row.path,other.path) then selection[addon.ConditionPathKey(other.path)]=nil end
                    end
                    selection[addon.ConditionPathKey(row.path)]=true
                end
            end
        elseif control then
            if selection[key] then selection[key]=nil else
                for _,row in ipairs(rows) do
                    if prefix(row.path,path) or prefix(path,row.path) then selection[addon.ConditionPathKey(row.path)]=nil end
                end
                selection[key]=true
            end
        else selection={[key]=true} end
        owner.view.selection=selection;owner.active.selected=pathCopy(path);self.anchor=pathCopy(path)
        if (#self:Selection()>1)~=owner.selectionStrip then owner:Layout() else self:Reflow() end
    end
    local ghost=addon:CreateWorkbenchDragCard();canvas.ghost=ghost
    function canvas:CancelDrag()
        self.drag=nil;ghost:Hide();addon:SetUIScript(self.frame,"OnUpdate",nil)
        for _,zone in ipairs(self.zones) do zone.marker:Hide();zone:Hide() end
    end
    function canvas:CanDrop(target)
        local drag=self.drag
        if not drag or not owner.active or drag.generation~=self.generation or drag.session~=owner.active.session then return false end
        local destination=target.destination
        local key=addon.ConditionPathKey(destination.path).."/field:"..addon.ConditionPathKey({destination.field or "value"}).."/index:"..tostring(destination.index).."/relation:"..tostring(destination.relation)
        drag.valid=drag.valid or {}
        if drag.valid[key]~=nil then return drag.valid[key] end
        local draft=addon.RotationData.NewConditionDraft(owner.active.session:Snapshot(),addon.conditionDefinitions)
        local ok,locations
        if draft then
            if drag.insert then ok= draft:Insert(destination,drag.insert)
            else
                ok,locations=draft:Transfer(drag.paths,destination)
                if ok and #locations==#drag.paths then
                    local same=true
                    for index,path in ipairs(locations) do if not prefix(path,drag.paths[index]) or not prefix(drag.paths[index],path) then same=false;break end end
                    if same then ok=false end
                end
            end
        end
        drag.valid[key]=ok==true;return ok==true
    end
    function canvas:HoverTarget()
        local selected
        do
            for _,zone in ipairs(self.zones) do
                if zone:IsShown() and addon:IsWorkbenchDropZoneUnderPointer(zone,self.frame) then
                    if self:CanDrop(zone.target) then selected=zone;break end
                end
            end
        end
        for _,zone in ipairs(self.zones) do if zone==selected then zone.marker:Show() else zone.marker:Hide() end end
        return selected
    end
    function canvas:BeginDrag(state)
        if owner.active and owner.active.readOnly then return end
        self:CancelDrag();self.drag=state
        local preview=state.insert or owner.active.session:Snapshot()
        if not state.insert and state.paths[1] then for _,part in ipairs(state.paths[1]) do preview=preview[part] end end
        ghost:Present(state.insert and L["Insert condition"] or string.format(L["Move %d conditions"],#state.paths),addon:DescribeCondition(preview,owner.active.spec).."\n"..L["Drop in a highlighted gap."],self.frame)
        for _,zone in ipairs(self.zones) do zone:Show();zone.marker:Hide() end
        addon:SetUIScript(self.frame,"OnUpdate",function()
            if not self.drag then return end
            if self.drag.generation~=self.generation or not owner.active or self.drag.session~=owner.active.session then self:CancelDrag();return end
            ghost:FollowPointer()
            self:HoverTarget()
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then self:EndDrag() end
        end)
    end
    function canvas:StartDrag(path,token)
        if token~=self.generation or not owner.active then return end
        local key=addon.ConditionPathKey(path)
        if not owner.view.selection[key] then self:Select(path,false,false) end
        self:BeginDrag({generation=self.generation,session=owner.active.session,paths=self:Selection()})
    end
    function canvas:StartInsert(node)
        if not owner.active or not owner:SyncWorking() then return end
        self:BeginDrag({generation=self.generation,session=owner.active.session,insert=addon.RotationData.CopyData(node)})
    end
    function canvas:Drop(target)
        local drag=self.drag;local valid=self:CanDrop(target);self:CancelDrag()
        if not valid or not drag or drag.generation~=self.generation or not owner.active or drag.session~=owner.active.session then return end
        if drag.insert then return owner:Command("Insert",target.destination,drag.insert) end
        return owner:Command("Transfer",drag.paths,target.destination)
    end
    function canvas:EndDrag()
        if not self.drag then return end
        local selected=self:HoverTarget()
        if selected then return self:Drop(selected.target) end
        self:CancelDrag()
    end
    local horizontal=addon:CreateWorkbenchScrollBar(parent,'HORIZONTAL');canvas.horizontal=horizontal
    addon:SetUIScript(horizontal,"OnValueChanged",function(_,value) canvas.scrollX=value;canvas.frame:SetHorizontalScroll(value) end)
    function canvas:LayoutScrollBar()
        horizontal:ClearAllPoints();horizontal:SetPoint("TOPLEFT",self.frame,"BOTTOMLEFT",0,-4);horizontal:SetWidth(self.frame:GetWidth())
    end
    function canvas:Reflow()
        if not owner.active then return end
        local scene=owner:Scene();self.scene=scene;self.child:SetSize(scene.width,scene.height)
        local scrollRange=math.max(0,scene.width-self.frame:GetWidth())
        horizontal:UpdateExtent(scene.width,self.frame:GetWidth())
        horizontal:SetValue(math.min(self.scrollX or 0,scrollRange))
        if scrollRange>0 then horizontal:Show() else horizontal:Hide();self.frame:SetHorizontalScroll(0) end
        for index,model in ipairs(scene.cards) do
            local card=self.cards[index]
            if card then card:Place(model,owner:Caption(model),owner:Summary(model)) end
        end
        for index,line in ipairs(scene.connectors) do
            local texture=self.lines[index]
            if not texture then texture=self.child:CreateTexture(nil,"BACKGROUND");self.lines[index]=texture;texture:SetColorTexture(.38,.37,.28,1) end
            texture:ClearAllPoints();texture:SetPoint("TOPLEFT",self.child,"TOPLEFT",line.x,-line.y);texture:SetSize(line.width,line.height);texture:Show()
        end
        for index=#scene.connectors+1,#self.lines do self.lines[index]:Hide() end
        for index,target in ipairs(scene.dropTargets) do
            local zone=self.zones[index]
            if not zone then
                zone=CreateFrame("Frame",nil,self.child);self.zones[index]=zone
                zone:EnableMouse(false)
                local marker=CreateFrame("Frame",nil,zone);zone.marker=marker
                for _,edge in ipairs({{first="TOPLEFT",last="TOPRIGHT",horizontal=true},{first="BOTTOMLEFT",last="BOTTOMRIGHT",horizontal=true},
                    {first="TOPLEFT",last="BOTTOMLEFT"},{first="TOPRIGHT",last="BOTTOMRIGHT"}}) do
                    local line=marker:CreateTexture(nil,"OVERLAY");line:SetColorTexture(.45,.8,.5,.9)
                    line:SetPoint(edge.first,marker,edge.first,0,0);line:SetPoint(edge.last,marker,edge.last,0,0)
                    if edge.horizontal then line:SetHeight(1) else line:SetWidth(1) end
                end
            end
            zone.target=target;zone:ClearAllPoints();zone:SetPoint("TOPLEFT",self.child,"TOPLEFT",target.x,-target.y)
            zone:SetSize(target.width,target.height)
            zone.marker:ClearAllPoints();zone.marker:SetPoint("TOPLEFT",zone,"TOPLEFT",0,target.kind=="inside" and 0 or -target.height/2+1)
            zone.marker:SetSize(target.width,target.kind=="inside" and (target.boxHeight or target.height) or 2)
            zone:SetFrameLevel(self.child:GetFrameLevel()+80)
            local token=self.generation
            addon:SetUIScript(zone,"OnReceiveDrag",function() if token==self.generation then self:Drop(target) end end)
            zone.marker:Hide();if self.drag then zone:Show() else zone:Hide() end
        end
        for index=#scene.dropTargets+1,#self.zones do self.zones[index]:Hide() end
        self.frame:UpdateScrollChildRect();self.frame:UpdateWorkbenchScroll();owner:UpdateHistoryButtons();owner:UpdateDescription()
    end
    function canvas:Render()
        if owner.active and not owner:SyncWorking() then return end
        self:CancelDrag();self.generation=self.generation+1
        for _,card in ipairs(self.cards) do card:Release() end
        if not owner.active then return end
        local scene=owner:Scene();self.scene=scene;self.building=true
        for index,model in ipairs(scene.cards) do
            local card=self.cards[index]
            if not card then card=addon:CreateConditionCard(self.child);self.cards[index]=card end
            local token=self.generation;card.token=token
            local function alive() return owner.active and token==self.generation and card.token==token end
            self.measure=self.measure or self.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
            self.measure:SetWordWrap(false);self.measure:SetText(model.compact and not model.name and owner:Summary(model) or owner:Caption(model))
            owner.view.labelWidths=owner.view.labelWidths or {};owner.view.labelWidths[model.key]=self.measure:GetStringWidth();self.measure:Hide()
            card:Place(model,owner:Caption(model),owner:Summary(model))
            owner.view.summaryHeights=owner.view.summaryHeights or {}
            if card.summary.GetStringHeight then owner.view.summaryHeights[model.key]=card.summary:GetStringHeight()+4 end
            addon:SetUIScript(card.header,"OnClick",function()
                if not alive() then return end
                local control,shift=IsControlKeyDown and IsControlKeyDown(),IsShiftKeyDown and IsShiftKeyDown()
                if control or shift then self:Select(model.path,control,shift) else
                    owner.view.help[model.key]=nil;owner.view.cardStates[model.key]='expanded';self:Render()
                end
            end)
            addon:SetUIScript(card.frame,"OnMouseDown",function(_,button)
                if alive() and button=="LeftButton" then self:Select(model.path,IsControlKeyDown and IsControlKeyDown(),IsShiftKeyDown and IsShiftKeyDown()) end
            end)
            addon:SetUIScript(card.header,"OnDragStart",function() if alive() then self:StartDrag(model.path,token) end end)
            addon:SetUIScript(card.header,"OnDragStop",function() if alive() then self:EndDrag() end end)
            addon:SetUIScript(card.expand,"OnClick",function()
                if not alive() or not owner:SyncWorking() then return end
                owner.view.cardStates=owner.view.cardStates or {}
                owner.view.help[model.key]=nil
                owner.view.cardStates[model.key]=model.compact and 'normal' or model.expanded and 'normal' or 'compact';self:Render()
            end)
            addon:SetUIScript(card.typeButton,"OnClick",function()
                if not alive() or model.compact then return end
                if IsControlKeyDown and IsControlKeyDown() or IsShiftKeyDown and IsShiftKeyDown() then
                    self:Select(model.path,IsControlKeyDown and IsControlKeyDown(),IsShiftKeyDown and IsShiftKeyDown())
                else owner:OpenTypePicker(card,model,alive) end
            end)
            addon:SetUIScript(card.typeButton,"OnDragStart",function() if alive() then self:StartDrag(model.path,token) end end)
            addon:SetUIScript(card.typeButton,"OnDragStop",function() if alive() then self:EndDrag() end end)
            card.name:SetText(addon:PlainWorkbenchName(model.name or ""))
            addon:BindWorkbenchInlineName(card.name,function() if alive() then card.name:Hide();card.nameButton:Show();local name=card.name:GetText();card.nameButton:SetText(addon:PlainWorkbenchName(name~='' and name or model.group and L['Click to add group name'] or owner:Caption(model))) end end)
            addon:SetUIScript(card.nameButton,"OnClick",function()
                if not alive() then return end
                if model.compact then owner.view.cardStates[model.key]='normal';self:Render();return end
                local control,shift=IsControlKeyDown and IsControlKeyDown(),IsShiftKeyDown and IsShiftKeyDown()
                if control or shift then self:Select(model.path,control,shift)
                elseif model.group or model.name then card.nameButton:Hide();card.name:Show();card.name:SetFocus() end
            end)
            addon:SetUIScript(card.nameButton,"OnDragStart",function() if alive() then self:StartDrag(model.path,token) end end)
            addon:SetUIScript(card.nameButton,"OnDragStop",function() if alive() then self:EndDrag() end end)
            addon:SetUIScript(card.name,'OnTextChanged',function(input,userInput)
                if not alive() or owner.active.readOnly or not userInput then return end
                local node=owner.active.working;for _,part in ipairs(model.namePath) do node=node[part] end
                node.name=input:GetText();owner:SyncWorking();owner:UpdateHistoryButtons()
            end)
            addon:SetUIScript(card.name,"OnEnterPressed",function(input)
                if alive() then input:ClearFocus();owner:Command("SetName",model.namePath,input:GetText()) end
            end)
            addon:SetUIScript(card.name,"OnEscapePressed",function() card.name:ClearFocus();card.name:Hide();card.nameButton:Show() end)
            addon:SetUIScript(card.fold,'OnClick',function() if alive() then owner.view.hiddenChildren[model.key]=not owner.view.hiddenChildren[model.key];self:Render() end end)
            addon:SetUIScript(card.controls.up,"OnClick",function() if alive() then owner:Command("Move",model.path,-1) end end)
            addon:SetUIScript(card.controls.down,"OnClick",function() if alive() then owner:Command("Move",model.path,1) end end)
            addon:SetUIScript(card.controls.remove,"OnClick",function() if alive() then owner:Command("RemoveSelection",{model.path}) end end)
            addon:SetUIScript(card.controls.duplicate,"OnClick",function() if alive() then owner:Command("Duplicate",model.path) end end)
            addon:SetUIScript(card.controls.negate,"OnClick",function() if alive() then owner:Command("NegateSelection",{model.path}) end end)
            addon:SetUIScript(card.controls.disable,"OnClick",function() if alive() then owner:Command("SetProjectedDisabled",model.path,not model.disabled) end end)
            addon:SetUIScript(card.controls.operator,"OnClick",function() if alive() then owner:Command("SetGroupType",model.fieldPath,model.type=="AND" and "OR" or "AND") end end)
            addon:SetUIScript(card.controls.ungroup,"OnClick",function() if alive() then owner:Command("Unwrap",model.fieldPath) end end)
            addon:SetUIScript(card.controls.help,"OnClick",function()
                if not alive() or not owner:SyncWorking() then return end
                if model.expanded then owner.view.help[model.key]=not owner.view.help[model.key];self:Render()
                elseif addon.ShowWorkbenchHelp then addon:ShowWorkbenchHelp(model.name or (addon.conditionDefinitions[model.type] or {}).description or L['Condition'],addon:WorkbenchInteractionHelp('condition'),owner.chrome.author:GetText()) end
            end)
            if model.expanded then owner:BuildFields(card,model,alive) end
            for _,source in ipairs({card.header,card.typeButton,card.nameButton,card.frame}) do
                addon:BindWorkbenchDragSource(source,function() if alive() then self:StartDrag(model.path,token) end end,function() if alive() then self:EndDrag() end end)
            end
            local readOnly=owner.active.readOnly
            for key,control in pairs(card.controls) do
                if (readOnly and key~='help') or (key=='up' and not model.canMoveUp) or (key=='down' and not model.canMoveDown) then control:Disable() else control:Enable() end
            end
            if readOnly then card.typeButton:Disable();if model.compact then card.nameButton:Enable() else card.nameButton:Disable() end
            else card.typeButton:Enable();card.nameButton:Enable() end
        end
        self.building=false;self:Reflow()
    end
    function canvas:Release()
        self:CancelDrag();self.generation=self.generation+1
        for _,card in ipairs(self.cards) do card:Release() end
        horizontal:Hide()
    end
    return canvas
end
