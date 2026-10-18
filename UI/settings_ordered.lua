local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:InstallSettingsOrdered(p)
    function p:OrderedCollection(key,items,title,build,changed,options)
        options=options or {};self.ordered=self.ordered or {}
        local token=self.generation;local parent=self.surface or self.child;local width=self.width
        local ghost=self:Acquire('orderedGhosts',function() return addon:CreateWorkbenchDragCard() end);ghost:SetParent(UIParent);ghost:Hide()
        local view={rows={},zones={},compact=options.compact==true,ghost=ghost,unsavedKey=key:match("^items_") and "items" or "sequence"};self.ordered[key]=view
        local function valid() return p:Valid(token) end
        function view:CancelDrag()
            self.drag=nil;self.tail=nil
            if self.ghost.rmCollectionDragOwner==self or self.ghost.rmCollectionDragOwner==nil then
                self.ghost.rmCollectionDragOwner=nil;if options.endPreview then options.endPreview(self.ghost) end;self.ghost:Hide();addon:SetUIScript(self.ghost,'OnUpdate',nil)
                for _,zone in ipairs(self.zones) do zone:Hide();zone.marker:Hide() end
            end
        end
        function view:CanDrop(gap) return valid() and addon:CanReorderWorkbenchRange(items,self.drag,gap,self.tail) end
        function view:Drop(gap)
            local from,tail=self.drag,self.tail;local allowed=self:CanDrop(gap);self:CancelDrag()
            if not allowed or not p:FlushEdits() or not valid() then return false end
            p:WithSettingsHistory(function() addon:ReorderWorkbenchRange(items,from,gap,tail);changed();p:Draw() end);return true
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
            self:CancelDrag();if not valid() or not p:FlushEdits() or not valid() then return end
            self.drag=index;self.tail=IsControlKeyDown and IsControlKeyDown() or false;self.ghost.rmCollectionDragOwner=self;self.ghost:Present((self.tail and L['Move this and following entries']..': ' or '')..title(index),(options.dragSummary and options.dragSummary(index)..'\n' or '')..L['Drop in a highlighted gap.'],p.frame,self.tail and #items-index+1 or 1)
            self.ghost.texture=self.ghost.texture or self.ghost:CreateTexture(nil,'ARTWORK');self.ghost.texture:SetSize(28,28);self.ghost.texture:SetPoint('TOPLEFT',8,-8);local icon=options.dragIcon and options.dragIcon(index);self.ghost.label:ClearAllPoints();self.ghost.label:SetPoint('TOPLEFT',icon and 44 or 10,-8);self.ghost.label:SetWidth((self.tail and #items-index+1>1 and 230 or 320)-(icon and 34 or 0));if icon then self.ghost.texture:SetTexture(icon);self.ghost.texture:Show() else self.ghost.texture:Hide() end
            local entries={}
            for i=index,self.tail and #items or index do local row=self.rows[i];if row then entries[#entries+1]={frame=row,x=0,y=row.dragY,width=row:GetWidth(),height=row:GetHeight()} end end
            self.ghost:PresentCards(entries,parent);self.ghost:CaptureCancel(function() self:CancelDrag() end)
            for _,zone in ipairs(self.zones) do zone:Show() end
            addon:SetUIScript(self.ghost,'OnUpdate',function()
                if not valid() then self:CancelDrag();return end
                self.ghost:FollowPointer();self:Hover();if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then self:EndDrag() end
            end)
        end
        local boundaries={self.y}
        for i in ipairs(items) do
            local y=self.y;local outerSurface,outerWidth=self.surface,self.width
            local row=self:Acquire(options.compact and 'orderedTableRows' or 'orderedCards',function()
                local frame=CreateFrame('Frame',nil,parent);frame.header=addon:CreateWorkbenchButton(frame,'',width-56);frame.header.art:Hide();frame.body=CreateFrame('Frame',nil,frame);frame.body:SetPoint('TOPLEFT',26,0)
                frame.up=addon:CreateWorkbenchIconButton(frame,'up',L['Move Up']);frame.down=addon:CreateWorkbenchIconButton(frame,'down',L['Move Down']);frame.remove=addon:CreateWorkbenchIconButton(frame,'trash',L['Delete']);frame.remove.icon:SetVertexColor(1,.25,.25,1)
                if not options.compact then frame.decoration=addon:CreateRoundedCardDecoration(frame);frame.decoration:SetColors(.35,.4,.44,.65,.08) end
                return frame
            end);view.rows[i]=row;row.dragY=y
            row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-y);row:SetWidth(width)
            row.header:ClearAllPoints();row.header:SetPoint('TOPLEFT',26,-3);row.header:SetWidth(width-54);row.header:SetText((options.compact or options.header==false) and '' or title(i));addon:AlignWorkbenchTextLeft(row.header,3)
            row.header.grip=row.header.grip or row.header:CreateTexture(nil,'ARTWORK');row.header.grip:SetTexture(addon:ControlTexture('grip'));row.header.grip:SetSize(12,18);row.header.grip:SetPoint('LEFT',2,0)
            if options.header==false then row.header:SetPoint('TOPRIGHT',-4,-25);row.header:SetWidth(20);row.header:SetHeight(20);row.header.grip:Hide() elseif options.compact then row.header:SetPoint('TOPLEFT',20,-2);row.header:SetWidth(18);row.header:SetHeight(26);row.header.grip:Show() else row.header:SetHeight(20);row.header.grip:Hide() end
            row.header.tooltip=L['Drag one entry; Ctrl-drag moves it and all following siblings.'];row.body:SetWidth(width-62)
            row.up:ClearAllPoints();row.down:ClearAllPoints();row.remove:ClearAllPoints()
            row.up:SetPoint('TOPLEFT',3,options.compact and -1 or options.header==false and -4 or -26);row.down:SetPoint('TOPLEFT',3,options.compact and -14 or options.header==false and -22 or -44)
            row.up:SetSize(18,options.compact and 13 or 18);row.down:SetSize(18,options.compact and 13 or 18);row.remove:SetPoint('TOPRIGHT',-4,-3)
            if i==1 then row.up:Disable() else row.up:Enable() end;if i==#items then row.down:Disable() else row.down:Enable() end
            addon:SetUIScript(row.up,'OnClick',self:Guard(function() view.drag=i;view.tail=false;view:Drop(i-1) end));addon:SetUIScript(row.down,'OnClick',self:Guard(function() view.drag=i;view.tail=false;view:Drop(i+2) end))
            addon:SetUIScript(row.remove,'OnClick',self:Guard(function() if self:FlushEdits() and valid() then table.remove(items,i);changed();self:Draw() end end))
            local function startDrag() view:BeginDrag(i) end;local function stopDrag() if valid() then view:EndDrag() end end
            row:EnableMouse(true);row.body:EnableMouse(true)
            for _,surface in ipairs({row,row.body}) do
                addon:SetUIScript(surface,'OnMouseDown',self:Guard(function(_,button) if button=='LeftButton' then startDrag() end end));addon:SetUIScript(surface,'OnMouseUp',self:Guard(function(_,button) if button=='LeftButton' then stopDrag() end end));addon:BindWorkbenchDragSource(surface,startDrag,stopDrag)
            end
            addon:BindWorkbenchDragSource(row.header,function() view:BeginDrag(i) end,function() if valid() then view:EndDrag() end end)
            self.fields[(options.prefix or key)..i..'up']=row.up;self.fields[(options.prefix or key)..i..'down']=row.down;self.fields[(options.prefix or key)..i..'remove']=row.remove
            self.surface=row.body;self.width=width-62;self.y=options.compact and 2 or options.header==false and 4 or 28
            build(self,i,items[i],row)
            local height=math.max(options.compact and 30 or options.header==false and 44 or 68,self.y+8);row:SetHeight(height);row.body:SetHeight(height);row.body:ClearAllPoints();row.body:SetPoint('TOPLEFT',26,options.header==false and -math.max(0,(height-(self.y-4))/2-4) or 0)
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
