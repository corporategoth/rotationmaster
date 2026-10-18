local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local types={{value='string',text=L['Text']},{value='number',text=L['Number']},{value='boolean',text=L['Boolean']},{value='condition',text=L['Condition']},{value='condition[]',text=L['Condition list']},{value='record',text=L['Record / map']},{value='union',text=L['Allowed types / list alternatives']}}
local function key(path) return table.concat(path,'/') end
local function parentPath(path) local result=addon:CopySettingsData(path);table.remove(result);return result end
local function append(path,index) local result=addon:CopySettingsData(path);result[#result+1]=index;return result end
local function invalid(node,parent,root)
    if parent.kind=='record' then
        if not addon:IsEditableFieldSchemaName(node.name,root) then return true end
        for _,other in ipairs(parent.children) do if other~=node and other.name==node.name then return true end end
    end
    if node.children then
        if #node.children==0 then return true end
        for _,child in ipairs(node.children) do if invalid(child,node,false) then return true end end
    end
    return false
end
function addon:BuildFieldSchemaCards(form,owner)
    local model=owner.model;local token=form.generation;local cards={};owner.cards=cards;owner.folded=owner.folded or {}
    local ghost=form:Acquire('schemaGhost',function() return addon:CreateWorkbenchDragCard() end);ghost:SetParent(UIParent);ghost:Hide()
    local view={zones={},ghost=ghost};owner.cardView=view
    local function valid() return owner.active and form:Valid(token) end
    function view:CancelDrag()
        self.drag=nil;ghost:Hide();addon:SetUIScript(ghost,'OnUpdate',nil)
        for _,zone in ipairs(self.zones) do zone:Hide();zone.marker:Hide() end
    end
    function view:CanDrop(path,gap) return valid() and self.drag and model:CanTransfer(self.drag.path,path,gap,self.drag.tail) or false end
    function view:Drop(path,gap)
        local drag=self.drag;local allowed=self:CanDrop(path,gap);self:CancelDrag()
        if not allowed or not form:FlushEdits() or not valid() then return false end
        if model:Transfer(drag.path,path,gap,drag.tail) then form:Draw();return true end
        return false
    end
    function view:Hover()
        local target
        for _,zone in ipairs(self.zones) do
            if self:CanDrop(zone.path,zone.gap) and addon:IsWorkbenchDropZoneUnderPointer(zone,form.scroll) and (not target or #zone.path>#target.path) then target=zone end
        end
        for _,zone in ipairs(self.zones) do if zone==target then zone.marker:Show() else zone.marker:Hide() end end
        return target
    end
    function view:EndDrag() local target=self:Hover();if target then self:Drop(target.path,target.gap) else self:CancelDrag() end end
    function view:BeginDrag(path)
        self:CancelDrag();if not valid() or not form:FlushEdits() then return end
        local node=model:Node(path);local parent=model:Node(parentPath(path));if not node or not parent then return end
        local tail=IsControlKeyDown and IsControlKeyDown() or false;self.drag={path=addon:CopySettingsData(path),tail=tail}
        local entries={};for i=path[#path],tail and #parent.children or path[#path] do
            local card=cards[key(append(parentPath(path),i))]
            if card then entries[#entries+1]={frame=card.frame,x=0,y=card.y,width=card.frame:GetWidth(),height=card.frame:GetHeight()} end
        end
        ghost:Present(tostring(node.name),L['Drag one entry; Ctrl-drag moves it and all following siblings.'],form.frame,#entries)
        ghost:PresentCards(entries,cards[key(path)].frame:GetParent());ghost:CaptureCancel(function() self:CancelDrag() end)
        for _,zone in ipairs(self.zones) do zone:Show() end
        addon:SetUIScript(ghost,'OnUpdate',function()
            if not valid() then self:CancelDrag();return end
            ghost:FollowPointer();self:Hover();if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then self:EndDrag() end
        end)
    end
    function view:UpdateMarkers()
        if self.markerRevision==model.revision then return end;self.markerRevision=model.revision
        for _,row in pairs(cards) do
            local node=model:Node(row.path);local parent=model:Node(parentPath(row.path));local original=owner.baseline
            for _,index in ipairs(row.path) do original=original and original.children and original.children[index] end
            local bad=invalid(node,parent,#row.path==1)
            row.decoration:SetColors(bad and .8 or .3,bad and .25 or .55,bad and .2 or .35,.7,.035)
            addon:SetWorkbenchInvalid(row.frame,bad,string.format(L['Invalid field schema: %s'],key(row.path)))
            addon:SetWorkbenchUnsaved(row.frame,not addon:SettingsDataEqual(node,original))
        end
    end
    form.cleanups[#form.cleanups+1]=function() view:CancelDrag() end
    local function gap(parent,path,index,y,x,width)
        local zone=form:Acquire('schemaGaps',function()
            local frame=CreateFrame('Frame',nil,parent);frame.marker=frame:CreateTexture(nil,'OVERLAY');frame.marker:SetColorTexture(.9,.75,.3,1);frame.marker:SetPoint('LEFT');frame.marker:SetPoint('RIGHT');frame.marker:SetHeight(3);return frame
        end)
        zone:SetParent(parent);zone:ClearAllPoints();zone:SetPoint('TOPLEFT',x,-y+5);zone:SetSize(width,10);zone:EnableMouse(false);zone.path=addon:CopySettingsData(path);zone.gap=index;zone:Hide();zone.marker:Hide();view.zones[#view.zones+1]=zone
    end
    local rendered=0
    local function children(parent,node,path,startY,x,width)
        local y=startY;gap(parent,path,1,y,x,width)
        for index,child in ipairs(node.children) do
            if rendered>=200 then break end;rendered=rendered+1
            local pathHere=append(path,index);local id=key(pathHere);local savedSurface,savedWidth,savedY=form.surface,form.width,form.y
            local row=form:Acquire('schemaCards',function()
                local c={};c.frame=CreateFrame('Frame',nil,parent);c.frame:EnableMouse(true);c.decoration=addon:CreateRoundedCardDecoration(c.frame)
                function c:Show() self.frame:Show() end
                function c:Hide() self.frame:Hide() end
                function c:SetParent(value) self.frame:SetParent(value) end
                c.fold=addon:CreateConditionChevron(c.frame);c.fold:SetPoint('TOPLEFT',3,-3);c.fold:SetSize(18,18)
                for _,entry in ipairs({{'up','up',L['Move Up']},{'down','down',L['Move Down']},{'duplicate','copy',L['Duplicate']},{'remove','trash',L['Delete']}}) do c[entry[1]]=addon:CreateWorkbenchIconButton(c.frame,entry[2],entry[3]);c[entry[1]]:SetSize(18,18) end
                c.help=addon:CreateWorkbenchHelpButton(c.frame,L['Help']);c.help:SetSize(20,20);c.help:SetPoint('TOPRIGHT',-4,-3)
                c.duplicate:SetPoint('TOPRIGHT',-4,-26);c.remove:SetPoint('TOPRIGHT',-4,-47);c.remove.icon:SetVertexColor(1,.25,.25,1)
                c.up:SetPoint('TOPLEFT',4,-23);c.down:SetPoint('TOPLEFT',c.up,'BOTTOMLEFT',0,0)
                c.line=c.frame:CreateTexture(nil,'BACKGROUND');c.line:SetColorTexture(.5,.48,.34,.6)
                return c
            end)
            cards[id]=row;row.path=pathHere;row.y=y;row.frame:SetParent(parent);row.frame:ClearAllPoints();row.frame:SetPoint('TOPLEFT',x,-y);row.frame:SetWidth(width)
            form.surface=row.frame;form.width=width;form.y=0
            local nameWidth=math.max(84,(width-112)*.43);local name=form:Edit('field_'..id,nil,node.kind=='record' and child.name or tostring(index),function(text) if node.kind~='record' or text:match('^[%a_][%w_]*$') then return text end end,function(text) model:Change(function() child.name=text end);owner:UpdateActions() end)
            row.name=name;name:ClearAllPoints();name:SetPoint('TOPLEFT',28,-23);name:SetWidth(nameWidth);name:EnableMouse(node.kind=='record');name:EnableKeyboard(node.kind=='record')
            local kind=form:Choice('type_'..id,nil,child.kind,types,function(value) model:SetKind(pathHere,value);form:Draw() end)
            row.type=kind;kind:ClearAllPoints();kind:SetPoint('TOPLEFT',34+nameWidth,-23);kind:SetWidth(width-nameWidth-64)
            if index==1 then row.up:Disable() else row.up:Enable() end;if index==#node.children then row.down:Disable() else row.down:Enable() end
            local function command(fn) if valid() and form:FlushEdits() and fn() then form:Draw() end end
            addon:SetUIScript(row.up,'OnClick',form:Guard(function() command(function() return model:Transfer(pathHere,path,index-1) end) end))
            addon:SetUIScript(row.down,'OnClick',form:Guard(function() command(function() return model:Transfer(pathHere,path,index+2) end) end))
            addon:SetUIScript(row.duplicate,'OnClick',form:Guard(function() command(function() return model:Duplicate(pathHere) end) end))
            addon:SetUIScript(row.remove,'OnClick',form:Guard(function() command(function() return model:Remove(pathHere) end) end))
            addon:SetUIScript(row.help,'OnClick',form:Guard(function()
                addon:ShowWorkbenchHelp(tostring(child.name),{
                    {title=L['Fields'],text=L['Field names are Lua identifiers. Choose a field type from its dropdown. Records contain named fields; allowed types contain alternatives, including nested records.']},
                    {title=L['Move, copy and remove'],text=L['Drag one entry; Ctrl-drag moves it and all following siblings.']..' '..L['A container carries its nested fields. Drop into a highlighted gap. Up / Down moves within the current container; Duplicate copies the complete field; the red trash can deletes it.']},
                    {title=L['Help and saving'],text=L['The chevron hides or shows nested fields. Add field appends to that container. Undo / Redo affect the draft. Apply validates and stages the schema; Cancel leaves the condition unchanged. Red borders mark invalid names or incomplete types.']}
                },owner.chrome and owner.chrome.owner or L['Field schema'])
            end))
            row.fold:PointState(owner.folded[id] and 'compact' or 'normal')
            if child.children then row.fold:Show() else row.fold:Hide() end
            addon:SetUIScript(row.fold,'OnClick',form:Guard(function() if form:FlushEdits() then owner.folded[id]=not owner.folded[id];form:Draw() end end))
            addon:BindWorkbenchDragSource(row.frame,function() view:BeginDrag(pathHere) end,function() if valid() then view:EndDrag() end end)
            local height=70
            if child.children and not owner.folded[id] then
                -- Legacy definitions can be deeper than new schemas. Stop
                -- shrinking before any editable field becomes unusable.
                local indent=math.max(0,math.min(28,width-326))
                height=children(row.frame,child,pathHere,72,indent,math.max(320,width-indent-6))
                form.surface=row.frame;form.width=width;form.y=height+2
                local add=form:Button('add_'..id,L['Add field'],function() command(function() return model:Add(pathHere) end) end,'plus');add:ClearAllPoints();add:SetPoint('TOPLEFT',indent,-height);add:SetWidth(math.min(150,width-48));height=height+32
                row.line:ClearAllPoints();row.line:SetPoint('TOPLEFT',14,-68);row.line:SetSize(2,math.max(1,height-76));row.line:Show()
            else row.line:Hide() end
            row.frame:SetHeight(height);form.surface=savedSurface;form.width=savedWidth;form.y=savedY
            y=y+height+6;gap(parent,path,index+1,y,x,width)
        end
        return y
    end
    form:Heading(L['Fields']);local y=form.y
    form.y=4;local add=form:Button('add',L['Add field'],function() if model:Add({}) then form:Draw() end end,'plus');add:ClearAllPoints();add:SetPoint('TOPRIGHT',form.child,'TOPRIGHT',0,-4);add:SetWidth(150);form.y=y
    form.y=children(form.child,model.root,{},form.y,0,form.width)
    if rendered>=200 then form:Text(L['Showing the first 200 fields. Use Advanced schema for larger definitions.']) end
    owner:UpdateActions()
end
