local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function identity(value) return type(value)=='table' and value.id or value end
function addon:InstallSettingsRosterOrder(p)
    function p:BindRosterOrderRow(row,entry,revision)
        local r=self.roster;local items=r.options.order;local index
        for i,value in ipairs(items or {}) do if identity(value)==entry.value then index=i;break end end
        row.icon:ClearAllPoints();row.icon:SetPoint('LEFT',index and 24 or 4,0);addon:AlignWorkbenchTextLeft(row,entry.icon and (index and 54 or 34) or 6)
        if row.up then row.up:Hide();row.down:Hide() end
        addon:SetUIScript(row,'OnDragStart',nil);addon:SetUIScript(row,'OnDragStop',nil)
        if not index then return end
        if not row.up then row.up=addon:CreateWorkbenchIconButton(row,'up',L['Move Up']);row.down=addon:CreateWorkbenchIconButton(row,'down',L['Move Down']);row.up:SetPoint('TOPLEFT',1,-2);row.down:SetPoint('TOPLEFT',1,-16);row.up:SetSize(18,14);row.down:SetSize(18,14) end
        row.up:Show();row.down:Show();if index==1 then row.up:Disable() else row.up:Enable() end;if index==#items then row.down:Disable() else row.down:Enable() end
        local function valid() return r.revision==revision end
        addon:SetUIScript(row.up,'OnClick',self:Guard(function() if valid() then r.orderView.drag=entry.value;r.orderView.tail=false;r.orderView:Drop(index-1) end end))
        addon:SetUIScript(row.down,'OnClick',self:Guard(function() if valid() then r.orderView.drag=entry.value;r.orderView.tail=false;r.orderView:Drop(index+2) end end))
        addon:BindWorkbenchDragSource(row,function() if valid() then r.orderView:Begin(entry.value,entry.text) end end,function() if valid() then r.orderView:EndDrag() end end)
    end
    function p:PrepareRosterOrder(revision)
        local r=self.roster;if r.orderView then r.orderView:Cancel() end
        if not r.options.order then r.orderView=nil;return end
        local items=r.options.order;local token=self.generation
        r.orderGhost=r.orderGhost or addon:CreateWorkbenchDragCard();r.orderZones=r.orderZones or {}
        local view={zones=r.orderZones,ghost=r.orderGhost};r.orderView=view
        local function valid() return p:Valid(token) and r.revision==revision end
        function view:Index() for i,value in ipairs(items) do if identity(value)==self.drag then return i end end end
        function view:Cancel() self.drag=nil;self.tail=nil;if r.orderView==self then self.ghost:Hide();addon:SetUIScript(self.ghost,'OnUpdate',nil);for _,zone in ipairs(self.zones) do zone:Hide();zone.marker:Hide() end end end
        function view:CanDrop(gap) local from=self:Index();return valid() and addon:CanReorderWorkbenchRange(items,from,gap,self.tail) end
        function view:Drop(gap)
            local id,tail=self.drag,self.tail;local before=items[gap] and identity(items[gap]);local allowed=self:CanDrop(gap);self:Cancel()
            if not allowed or not p:FlushEdits() or not p:Valid(token) or r.options.order~=items then return false end
            local from;gap=#items+1;for i,value in ipairs(items) do if identity(value)==id then from=i end;if identity(value)==before then gap=i end end
            if not addon:ReorderWorkbenchRange(items,from,gap,tail) then return false end
            if r.options.orderChanged then r.options.orderChanged(items) end;p:Draw();return true
        end
        function view:Hover()
            local selected
            for _,zone in ipairs(self.zones) do if self:CanDrop(zone.gap) and addon:IsWorkbenchDropZoneUnderPointer(zone,r.scroll) then selected=zone;break end end
            for _,zone in ipairs(self.zones) do if zone==selected then zone.marker:Show() else zone.marker:Hide() end end;return selected
        end
        function view:EndDrag() local zone=self:Hover();if zone then self:Drop(zone.gap) else self:Cancel() end end
        function view:Begin(id,title,tail)
            if tail==nil then tail=IsControlKeyDown and IsControlKeyDown() or false end
            self:Cancel();if not valid() or not p:FlushEdits() or not p:Valid(token) or r.options.order~=items then return end
            if r.orderView~=self then return r.orderView:Begin(id,title,tail) end
            self.drag=id;self.tail=tail;self.ghost:Present((tail and L['Move this and following entries']..': ' or '')..title,L['Drop in a highlighted gap.'],p.frame);for _,zone in ipairs(self.zones) do if zone.gap then zone:Show() end end
            addon:SetUIScript(self.ghost,'OnUpdate',function() if not valid() then self:Cancel();return end;self.ghost:FollowPointer();self:Hover();if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then self:EndDrag() end end)
        end
        self.cleanups[#self.cleanups+1]=function() view:Cancel() end
    end
    function p:BuildRosterOrderZones()
        local r=self.roster;if not r.orderView then return end
        local used=0;local last
        local function zoneAt(y,gap)
            used=used+1;local zone=r.orderZones[used]
            if not zone then zone=CreateFrame('Frame',nil,r.child);zone.marker=zone:CreateTexture(nil,'OVERLAY');zone.marker:SetColorTexture(.9,.75,.3,1);zone.marker:SetPoint('LEFT');zone.marker:SetPoint('RIGHT');zone.marker:SetHeight(3);zone:EnableMouse(false);r.orderZones[used]=zone end
            zone:ClearAllPoints();zone:SetPoint('TOPLEFT',0,-y+6);zone:SetSize(r.child:GetWidth(),12);zone.gap=gap;zone:Hide();zone.marker:Hide()
        end
        for visible,entry in ipairs(r.matches) do for index,value in ipairs(r.options.order) do if identity(value)==entry.value then zoneAt((visible-1)*34,index);last={y=visible*34,gap=index+1};break end end end
        if last then zoneAt(last.y,last.gap) end
        for i=used+1,#r.orderZones do r.orderZones[i].gap=nil;r.orderZones[i]:Hide();r.orderZones[i].marker:Hide() end
    end
end
