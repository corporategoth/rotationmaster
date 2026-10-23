local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- A new-item field placed at the left of a list's header row (its Add sits
-- at the right). Returns the width it used.
function addon:LayoutNewItemField(form,field,y,width)
    form.y=y;field:ClearAllPoints();field:SetPoint('TOPLEFT',0,-y);field:SetSize(math.max(60,width),22);return 0
end
function addon:InstallSettingsOrdered(p)
    function p:OrderedCollection(key,items,title,build,changed,options)
        options=options or {};self.ordered=self.ordered or {}
        local token=self.generation;local parent=self.surface or self.child;local width=self.width
        local ghost=self:Acquire('orderedGhosts',function() return addon:CreateWorkbenchDragCard() end);ghost:SetParent(UIParent);ghost:Hide()
        local view={rows={},zones={},compact=options.compact==true,ghost=ghost,unsavedKey=options.unsavedKey or (key:match("^items_") and "items" or "sequence")};self.ordered[key]=view
        local function valid()
            if not p:Valid(token) then return false end
            if options.current and options.current()~=true then return false end
            return p:Valid(token)
        end
        function view:CancelDrag()
            self.drag=nil;self.tail=nil;self.insertFactory=nil;self.insertAction=nil
            if self.ghost.rmCollectionDragOwner==self or self.ghost.rmCollectionDragOwner==nil then
                self.ghost.rmCollectionDragOwner=nil;if options.endPreview then options.endPreview(self.ghost) end;self.ghost:Hide();addon:SetUIScript(self.ghost,'OnUpdate',nil)
                for _,zone in ipairs(self.zones) do zone:Hide();zone.marker:Hide() end
            end
        end
        function view:CanDrop(gap)
            if not valid() or options.readOnly then return false end
            if self.insertFactory or self.insertAction then return type(gap)=='number' and gap%1==0 and gap>=1 and gap<=#items+1 end
            return addon:CanReorderWorkbenchRange(items,self.drag,gap,self.tail)
        end
        function view:Drop(gap)
            local from,tail,factory,action=self.drag,self.tail,self.insertFactory,self.insertAction;local allowed=self:CanDrop(gap);self:CancelDrag()
            if not allowed or not p:FlushEdits() or not valid() then return false end
            -- A dropped add action inserts through the page's own add path, so
            -- a drop at the end leaves exactly what a click on Add leaves.
            if action then
                local function insert() action(gap) end
                if p.WithSettingsHistory then p:WithSettingsHistory(insert) else insert() end;return true
            end
            local original={};for i,value in ipairs(items) do original[i]=value end
            local function apply()
                if not valid() or #items~=#original then return false end
                for i,value in ipairs(original) do if items[i]~=value then return false end end
                p:WithSettingsHistory(function() if factory then table.insert(items,gap,factory()) else addon:ReorderWorkbenchRange(items,from,gap,tail) end;changed();p:Draw() end);return true
            end
            if factory and options.confirmInsert then options.confirmInsert(apply,gap);return true end
            if not factory and options.confirmReorder then options.confirmReorder(apply,from,gap,tail);return true end
            return apply()
        end
        function view:Hover()
            local selected
            for i,zone in ipairs(self.zones) do if self:CanDrop(i) and addon:IsWorkbenchDropZoneUnderPointer(zone,p.scroll) then selected=i;break end end
            for i,zone in ipairs(self.zones) do if i==selected then zone.marker:Show() else zone.marker:Hide() end end
            return selected
        end
        function view:EndDrag() local gap=self:Hover();if gap then self:Drop(gap) else self:CancelDrag() end end
        function view:BeginDrag(index)
            if self.drag==index then return end
            self:CancelDrag();if not valid() or options.readOnly or not p:FlushEdits() or not valid() then return end
            self.drag=index;self.tail=IsControlKeyDown and IsControlKeyDown() or false;self.ghost.rmCollectionDragOwner=self;self.ghost:Present((self.tail and L['Move this and following entries']..': ' or '')..title(index),(options.dragSummary and options.dragSummary(index)..'\n' or '')..L['Drop in a highlighted gap.'],p.frame,self.tail and #items-index+1 or 1)
            self.ghost.texture=self.ghost.texture or self.ghost:CreateTexture(nil,'ARTWORK');self.ghost.texture:SetSize(28,28);self.ghost.texture:SetPoint('TOPLEFT',8,-8);local icon=options.dragIcon and options.dragIcon(index);self.ghost.label:ClearAllPoints();self.ghost.label:SetPoint('TOPLEFT',icon and 44 or 10,-8);self.ghost.label:SetWidth((self.tail and #items-index+1>1 and 230 or 320)-(icon and 34 or 0));if icon then self.ghost.texture:SetTexture(icon);self.ghost.texture:Show() else self.ghost.texture:Hide() end
            local entries={}
            for i=index,self.tail and #items or index do local row=self.rows[i];if row then entries[#entries+1]={frame=row,x=0,y=row.dragY,width=row:GetWidth(),height=row:GetHeight()} end end
            self.ghost:PresentCards(entries,parent);self.ghost:CaptureCancel(function() self:CancelDrag() end)
            -- Gaps right before and after the carried card would not move it.
            for gap,zone in ipairs(self.zones) do if self:CanDrop(gap) then zone:Show() else zone:Hide() end end
            addon:SetUIScript(self.ghost,'OnUpdate',function()
                if not valid() then self:CancelDrag();return end
                self.ghost:FollowPointer();self:Hover();if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then self:EndDrag() end
            end)
        end
        function view:BeginInsert(factory,label,action)
            self:CancelDrag();if not valid() or options.readOnly or type(factory)~='function' and type(action)~='function' or not p:FlushEdits() or not valid() then return false end
            if type(action)=='function' then self.insertAction=action else self.insertFactory=factory end;self.ghost.rmCollectionDragOwner=self
            self.ghost:Present(label,L['Drop in a highlighted gap.'],p.frame,1)
            self.ghost.label:ClearAllPoints();self.ghost.label:SetPoint('TOPLEFT',10,-8);self.ghost.label:SetWidth(320);if self.ghost.texture then self.ghost.texture:Hide() end
            self.ghost:CaptureCancel(function() self:CancelDrag() end)
            for _,zone in ipairs(self.zones) do zone:Show() end
            addon:SetUIScript(self.ghost,'OnUpdate',function()
                if not valid() then self:CancelDrag();return end
                self.ghost:FollowPointer();self:Hover();if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then self:EndDrag() end
            end)
            return true
        end
        -- The list's header row: an optional section title at the left and the
        -- add action right-aligned to the cards' right edge, on one row. With
        -- neither there is no row. options.heading is a string or {text,key,
        -- collapsed,toggle}; options.add is {key,text,icon,insert(gap),click,
        -- beginDrag,appendGap,leading(form,y,width),enabled}. A click appends
        -- through insert(appendGap); dragging Add drops into a gap through the
        -- same insert, so both leave identical data.
        local heading=type(options.heading)=='string' and {text=options.heading} or options.heading
        local add=options.add
        if heading or add then
            local y=self.y;local addWidth=0
            if add then
                local button=self:Acquire('orderedAdd',function() return addon:CreateWorkbenchLabeledIconButton(parent,'plus','',110) end)
                button:SetText(add.text or L['Add']);button.icon:SetTexture(addon:ControlTexture(add.icon or 'plus'))
                addWidth=math.min(math.max(110,button:GetFontString():GetStringWidth()+40),math.max(60,math.floor(width*.5)))
                button:ClearAllPoints();button:SetPoint('TOPLEFT',width-addWidth,-y);button:SetSize(addWidth,22);addon:AlignWorkbenchTextLeft(button,24)
                if add.key then self.fields[add.key]=button end;view.add=button
                local blocked=options.readOnly or add.enabled==false
                if blocked then button:Disable() else button:Enable() end
                addon:SetUIScript(button,'OnClick',self:Guard(function()
                    if blocked then return end
                    if add.click then return add.click() end
                    if self:FlushEdits() and valid() then add.insert(add.appendGap and add.appendGap() or #items+1) end
                end))
                addon:BindWorkbenchDragSource(button,function()
                    if blocked or not valid() then return end
                    if add.beginDrag then return add.beginDrag(view) end
                    view:BeginInsert(add.factory,add.label or add.text,add.insert)
                end,function() if valid() then view:EndDrag() end end)
            end
            local left=0
            if add and add.leading then left=add.leading(self,y,math.max(1,width-addWidth-8)) or 0 end
            if heading then
                local titleWidth=math.max(1,width-addWidth-(addWidth>0 and 8 or 0)-left)
                if heading.toggle then
                    local c=self:Acquire('orderedToggles',function() return addon:CreateWorkbenchLabeledIconButton(parent,'chevron-down','',200) end)
                    c:ClearAllPoints();c:SetPoint('TOPLEFT',left,-y);c:SetSize(titleWidth,22);c:SetText(heading.text);c.art:Hide();addon:AlignWorkbenchTextLeft(c,20)
                    addon:StyleWorkbenchHeader(c:GetFontString());c.icon:SetTexture(addon:ControlTexture(heading.collapsed and 'chevron-right' or 'chevron-down'));c:Enable()
                    addon:SetUIScript(c,'OnClick',self:Guard(function() if valid() then heading.toggle() end end));if heading.key then self.fields[heading.key]=c end;view.heading=c
                else
                    local t=self:Acquire('orderedHeadings',function() local text=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');text:SetJustifyH('LEFT');text:SetJustifyV('MIDDLE');text:SetWordWrap(false);return text end)
                    t:ClearAllPoints();t:SetPoint('TOPLEFT',left,-y);t:SetSize(titleWidth,22);t:SetText(heading.text);addon:StyleWorkbenchHeader(t)
                    if heading.key then self.fields[heading.key]=t end;view.heading=t
                end
            end
            self.y=y+28
            if heading and heading.collapsed then view.collapsed=true;self.cleanups[#self.cleanups+1]=function() view:CancelDrag() end;return view end
        end
        local boundaries={self.y}
        for i in ipairs(items) do
            local y=self.y;local outerSurface,outerWidth=self.surface,self.width
            local row=self:Acquire(options.compact and 'orderedTableRows' or 'orderedCards',function()
                local frame=CreateFrame('Frame',nil,parent);frame.header=addon:CreateWorkbenchButton(frame,'',width-56);frame.header.art:Hide();frame.body=addon:TrackWorkbenchSize(CreateFrame('Frame',nil,frame));frame.body:SetPoint('TOPLEFT',26,0)
                frame.up=addon:CreateWorkbenchIconButton(frame,'up',L['Move Up']);frame.down=addon:CreateWorkbenchIconButton(frame,'down',L['Move Down']);frame.remove=addon:CreateWorkbenchIconButton(frame,'trash',L['Delete']);frame.remove.icon:SetVertexColor(1,.25,.25,1)
                if not options.compact then frame.decoration=addon:CreateRoundedCardDecoration(frame);frame.decoration:SetColors(.35,.4,.44,.65,.08) end
                return frame
            end);view.rows[i]=row;row.dragY=y
            -- One card for every list: no title row and no grip. The whole card
            -- picks up for a drag; arrows on the left; on the right a rail of
            -- optional Help and Duplicate above Delete, and an optional
            -- Enabled pill on the first row left of the rail.
            row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-y);row:SetWidth(width);row.header:Hide()
            if row.header.grip then row.header.grip:Hide() end
            row.up:ClearAllPoints();row.down:ClearAllPoints();row.remove:ClearAllPoints()
            row.up:SetPoint('TOPLEFT',3,options.compact and -1 or -4);row.down:SetPoint('TOPLEFT',3,options.compact and -14 or -22)
            row.up:SetSize(18,options.compact and 13 or 18);row.down:SetSize(18,options.compact and 13 or 18)
            if options.readOnly or i==1 then row.up:Disable() else row.up:Enable() end;if options.readOnly or i==#items then row.down:Disable() else row.down:Enable() end
            addon:SetUIScript(row.up,'OnClick',self:Guard(function() view.drag=i;view.tail=false;view:Drop(i-1) end));addon:SetUIScript(row.down,'OnClick',self:Guard(function() view.drag=i;view.tail=false;view:Drop(i+2) end))
            local rail=0
            local function railSlot(control) control:ClearAllPoints();control:SetPoint('TOPRIGHT',-4,-3-rail*22);control:SetSize(20,20);rail=rail+1;control:Show() end
            if options.help and not options.compact then
                row.help=row.help or addon:CreateWorkbenchHelpButton(row,L['Help']);row.help.icon:SetSize(18,18);row.help:Enable();railSlot(row.help)
                if type(options.help)=='function' then addon:SetUIScript(row.help,'OnClick',self:Guard(function() if valid() then options.help(i,items[i],row) end end)) end
            elseif row.help then row.help:Hide() end
            if options.duplicate and not options.compact then
                row.duplicate=row.duplicate or addon:CreateWorkbenchIconButton(row,'copy',L['Duplicate']);railSlot(row.duplicate)
                local allowed=not options.readOnly and (not options.canDuplicate or options.canDuplicate(i,items[i]))
                if allowed then row.duplicate:Enable() else row.duplicate:Disable() end
                if type(options.duplicate)=='function' then addon:SetUIScript(row.duplicate,'OnClick',self:Guard(function() if allowed and valid() then options.duplicate(i,items[i],row) end end)) end
            elseif row.duplicate then row.duplicate:Hide() end
            railSlot(row.remove)
            if options.readOnly then row.remove:Disable() else row.remove:Enable() end
            addon:SetUIScript(row.remove,'OnClick',self:Guard(function() if not options.readOnly and self:FlushEdits() and valid() then if options.removeItem then options.removeItem(i,items[i]) else table.remove(items,i);changed();self:Draw() end end end))
            row.firstRowReserve=0
            if options.enabled and not options.compact then
                -- options.enabled is {get,toggle,width,tooltip}, or true when the
                -- page sets the pill's state and action while building the card.
                local spec=type(options.enabled)=='table' and options.enabled or {}
                local pillWidth=spec.width or 70
                row.enabled=row.enabled or addon:CreateWorkbenchPill(row,'',pillWidth)
                row.enabled:ClearAllPoints();row.enabled:SetPoint('TOPRIGHT',-28,-4);row.enabled:SetSize(pillWidth,18);row.enabled:Show()
                if spec.get then
                    local on=spec.get(i,items[i])==true
                    row.enabled:SetText(on and L['Enabled'] or L['Disabled']);row.enabled:SetSelected(on);row.enabled.tooltip=spec.tooltip
                    if options.readOnly then row.enabled:Disable() else row.enabled:Enable() end
                    addon:SetUIScript(row.enabled,'OnClick',self:Guard(function() if not options.readOnly and valid() then spec.toggle(i,items[i],row) end end))
                end
                -- Body coordinates kept free on the first row for the pill.
                row.firstRowReserve=pillWidth+6
            elseif row.enabled then row.enabled:Hide() end
            local bodyX=options.compact and 4 or 26
            row.body:SetWidth(options.compact and width-bodyX-28 or width-62)
            local function startDrag() view:BeginDrag(i) end;local function stopDrag() if valid() then view:EndDrag() end end
            row:EnableMouse(true);row.body:EnableMouse(true)
            for _,surface in ipairs({row,row.body}) do
                addon:SetUIScript(surface,'OnMouseDown',self:Guard(function(_,button) if button=='LeftButton' then startDrag() end end));addon:SetUIScript(surface,'OnMouseUp',self:Guard(function(_,button) if button=='LeftButton' then stopDrag() end end));addon:BindWorkbenchDragSource(surface,startDrag,stopDrag)
            end
            self.fields[(options.prefix or key)..i..'up']=row.up;self.fields[(options.prefix or key)..i..'down']=row.down;self.fields[(options.prefix or key)..i..'remove']=row.remove
            self.surface=row.body;self.width=row.body:GetWidth();self.y=options.compact and 2 or 4
            if self.BeginLabelScope then self:BeginLabelScope() end
            build(self,i,items[i],row)
            if self.EndLabelScope then self:EndLabelScope() end
            if options.current and not valid()then return view end
            local height=math.max(options.compact and 30 or math.max(44,3+rail*22+2),self.y+8);row:SetHeight(height);row.body:SetHeight(height);row.body:ClearAllPoints();row.body:SetPoint('TOPLEFT',bodyX,0)
            self.surface=outerSurface;self.width=outerWidth;self.y=y+height+(options.compact and 4 or 12);boundaries[#boundaries+1]=self.y-(options.compact and 2 or 6)
        end
        for i,y in ipairs(boundaries) do
            local zone=self:Acquire('orderedZones',function() local frame=CreateFrame('Frame',nil,parent);frame.marker=frame:CreateTexture(nil,'OVERLAY');frame.marker:SetColorTexture(.9,.75,.3,1);frame.marker:SetPoint('LEFT');frame.marker:SetPoint('RIGHT');frame.marker:SetHeight(3);return frame end)
            zone:ClearAllPoints();zone:SetPoint('TOPLEFT',0,-y+6);zone:SetSize(width,12);zone:EnableMouse(false);zone:Hide();zone.marker:Hide();view.zones[i]=zone
        end
        self.cleanups[#self.cleanups+1]=function() view:CancelDrag() end
        return view
    end
end
