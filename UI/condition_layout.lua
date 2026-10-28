-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Condition layout container: the native group widget (RM-ConditionGroup) that the condition editor and the help
-- cards use to stack, tabulate and wrap child widgets, with the List, Table, RM-SpellField and RM-IconRows layouts.
-- It owns child parenting, ownership checks and width/height propagation; it must not know what the children are.
-- Loaded from RotationMaster.toc after UI/condition_inputs.lua and before UI/condition_table.lua, on top of the pool in
-- UI/condition_widgets.lua. The function bodies are recorded as Built In helpers (see the generated bindings at the
-- end), so only the comments outside functions may change.

local _, addon = ...

---@class RMConditionGroup: RMConditionWidget
---@field children table[]
---@field rmLease table
---@field rmActive boolean
---@field SetLayout fun(self: RMConditionGroup, layout: string)
---@field AddChild fun(self: RMConditionGroup, child: RMConditionWidget)
---@field DoLayout fun(self: RMConditionGroup)
---@field PauseLayout fun(self: RMConditionGroup)
---@field ResumeLayout fun(self: RMConditionGroup)
---@field ReleaseChildren fun(self: RMConditionGroup)

-- Maps a table cell's alignV option to a fraction of the row's spare height.
-- @param value string|nil  'start'/'top', 'middle'/'center' or 'end'/'bottom' (any case, and any longer word starting
--   with top, bottom or center); nil means unset (top).
-- @return number|nil  0, .5 or 1; nil for a non-string or an unrecognized string.
--
-- Native compact rows share rich Table and spell-field geometry with RM controls. A recorded Built In helper, so its
-- body is frozen.
local function verticalAlignment(value)
    if value==nil then return 0 end
    if type(value)~='string' then return nil end
    value=value:lower()
    if value=='start' or value:sub(1,3)=='top' then return 0 end
    if value=='end' or value:sub(1,6)=='bottom' then return 1 end
    if value=='middle' or value:sub(1,6)=='center' then return .5 end
end

-- An icon spanning the rows of the controls beside it: children[1] is the
-- icon, the controls that follow are its rows, top to bottom, and a control
-- marked userdata "side" (a button) sits right of the last row when the row
-- has the room, else on a line of its own under the rows. The icon's frame is
-- centered on the rows.
local ICON_ROWS_GAP = 4
local ICON_ROWS_MINIMUM = 190

-- Lays the children out as an icon spanning the rows of the controls beside it. Called by the group's DoLayout for the
-- RM-IconRows layout only.
-- @param content Frame  The frame the children are positioned in.
-- @param children table[]  The group's children: children[1] is the icon, the rest are its rows (a child with user data
--   "side" is the side button).
-- @param width number  The width available.
-- @return number  The total height used; 0 when there is no icon or no row.
--
-- A recorded Built In helper, so its body is frozen.
local function layoutIconRows(content, children, width)
    local icon,side,rows=children[1],nil,{}
    for index=2,#children do
        local child=children[index]
        if child.GetUserData and child:GetUserData('side') then side=child else rows[#rows+1]=child end
    end
    if not icon or #rows==0 then return 0 end
    local iconWidth=icon.frame:GetWidth() or 0
    local left=iconWidth+ICON_ROWS_GAP
    local fieldWidth=math.max(1,width-left)
    local sideWidth=side and math.ceil(side.label and side.label:GetStringWidth() or 0)+30 or 0
    local inline=side~=nil and fieldWidth-sideWidth-ICON_ROWS_GAP>=ICON_ROWS_MINIMUM
    local y,bottom=0,0
    for index,row in ipairs(rows) do
        local rowWidth=fieldWidth
        local last=index==#rows
        if last and inline then rowWidth=fieldWidth-sideWidth-ICON_ROWS_GAP end
        row:SetWidth(math.max(1,rowWidth))
        row.frame:ClearAllPoints();row.frame:SetPoint('TOPLEFT',content,'TOPLEFT',left,-y)
        local height=row.frame:GetHeight() or 0
        if last and side and inline then
            side:SetWidth(sideWidth);side.frame:ClearAllPoints()
            side.frame:SetPoint('BOTTOMLEFT',content,'TOPLEFT',left+rowWidth+ICON_ROWS_GAP,-(y+height))
        end
        bottom=y+height;y=y+height+ICON_ROWS_GAP
    end
    local iconHeight=icon.frame:GetHeight() or 0
    icon.frame:ClearAllPoints();icon.frame:SetPoint('TOPLEFT',content,'TOPLEFT',0,-math.max(0,(bottom-iconHeight)/2))
    local total=math.max(bottom,iconHeight)
    if side and not inline then
        side:SetWidth(math.max(1,math.min(sideWidth,fieldWidth)));side.frame:ClearAllPoints();side.frame:SetPoint('TOPLEFT',content,'TOPLEFT',left,-(total+ICON_ROWS_GAP))
        total=total+ICON_ROWS_GAP+(side.frame:GetHeight() or 0)
    end
    return total
end

-- Constructor for a pooled group. The methods defined inside are the whole widget contract: DoLayout is re-entrancy
-- guarded (layingOut) and pausable, children must be live widgets owned by no other parent (cycles are rejected), and
-- ReleaseChildren hands every child back to the pool and reports the first release error after releasing them all.
-- @return RMConditionGroup  The new widget, registered with the widget registry.
--
-- A recorded Built In helper, so its body is frozen.
local function constructor()
    local group={type='RM-ConditionGroup',children={}}
    local frame=CreateFrame('Frame',nil,UIParent);group.frame=frame;group.content=frame
    function group:OnAcquire() self.children={};self.layout='List';self.paused=false;self.layingOut=false;self:SetWidth(300);self:SetHeight(1) end
    function group:SetLayout(layout)
        if layout~='List' and layout~='Table' and layout~='RM-SpellField' and layout~='RM-IconRows' then error('unsupported-condition-layout',0) end
        self.layout=layout;self:DoLayout()
    end
    function group:PauseLayout() self.paused=true end
    function group:ResumeLayout() self.paused=false;self:DoLayout() end
    function group:OnWidthSet() if not self.sizing then self:DoLayout() end end
    function group:SetWidth(width)
        self.sizing=true;frame:SetWidth(width);frame.width=width;self.sizing=false;self:DoLayout()
    end
    function group:LayoutFinished(_,height) self:SetHeight(height or 1) end
    local function validateChild(self,child,seen)
        if not addon:IsConditionWidget(child) or not child.rmActive or child:IsReleasing() then error('foreign-or-inactive-condition-child',0) end
        if not self.rmActive or self:IsReleasing() then error('inactive-condition-parent',0) end
        if child.parent or seen and seen[child] then error('condition-child-already-owned',0) end
        local current=self
        for _=1,128 do
            if not current then return end
            if current==child then error('condition-widget-parent-cycle',0) end
            current=current.parent
        end
        error('condition-widget-parent-cycle',0)
    end
    function group:AddChild(child)
        -- A hidden option (a rank checkbox on a client without ranks) is nil.
        if child==nil then return end
        validateChild(self,child)
        self.children[#self.children+1]=child;child.parent=self
        child.frame:SetParent(frame);child.frame:Show();self:DoLayout()
    end
    function group:AddChildren(...)
        local seen={}
        for i=1,select('#',...) do local child=select(i,...);validateChild(self,child,seen);seen[child]=true end
        for i=1,select('#',...) do local child=select(i,...);self.children[#self.children+1]=child;child.parent=self;child.frame:SetParent(frame);child.frame:Show() end
        self:DoLayout()
    end
    function group:ReleaseChildren()
        local children=self.children
        for _,child in ipairs(children) do if not addon:IsConditionWidget(child) then error('foreign-condition-child',0) end end
        self.children={}
        local problem
        for _,child in ipairs(children) do local ok,why=pcall(addon.ReleaseConditionWidget,addon,child);child.parent=nil;if not ok then problem=problem or why end end
        if problem then error(problem,0) end
        self:DoLayout()
    end
    function group:DoLayout()
        if self.paused or self.layingOut or self.isQueuedForRelease then return end
        self.layingOut=true
        local ok,why=pcall(function()
        local width=math.max(1,frame:GetWidth() or 300);local padding=self:GetUserData('padding')
        padding=type(padding)=='number' and padding==padding and math.max(0,math.min(64,padding)) or 0
        width=math.max(1,width-padding*2);local y=padding;local gap=4
        local settings=self:GetUserData('table');local columns=self.layout=='Table' and settings and settings.columns
        if self.layout=='RM-SpellField' then
            y=addon:LayoutWorkbenchSpellGroup(frame,self.children) or 0
        elseif self.layout=='RM-IconRows' then
            y=layoutIconRows(frame,self.children,width)
        else
            local widths
            if columns and #columns>0 then
                widths={};local fixed,weight=gap*(#columns-1),0
                for i,column in ipairs(columns) do
                    if type(column)=='number' and column<=0 then
                        local measured=0
                        for index=i,#self.children,#columns do local child=self.children[index];local size=type(child.width)=='number' and child.width or child.frame and child.frame:GetWidth() or 0;measured=math.max(measured,size) end
                        widths[i]=measured;fixed=fixed+measured
                    elseif type(column)=='number' and column<1 then widths[i]=width*column;fixed=fixed+widths[i]
                    elseif type(column)=='number' and column>=10 then widths[i]=column;fixed=fixed+column
                    else weight=weight+(type(column)=='number' and column or 1) end
                end
                for i,column in ipairs(columns) do if not widths[i] then widths[i]=math.max(1,(width-fixed)*(type(column)=='number' and column or 1)/math.max(1,weight)) end end
            end
            local x,rowHeight,column=padding,0,1
            local row={}
            local function finishRow()
                for _,entry in ipairs(row) do
                    entry.control:ClearAllPoints();entry.control:SetPoint('TOPLEFT',frame,'TOPLEFT',entry.x,-y-(rowHeight-entry.height)*entry.align)
                end
                y=y+rowHeight+gap;x,rowHeight,column=padding,0,1;row={}
            end
            for _,child in ipairs(self.children) do
                local control=child.frame
                if control then
                    local childWidth=widths and widths[column] or (child.width=='fill' or child.fullWidth) and width or child.width=='relative' and width*(child.relWidth or 1) or child.width or control:GetWidth()
                    if type(childWidth)~='number' then childWidth=width end
                    child:SetWidth(math.max(1,childWidth));if child.DoLayout and child.type~='RM-ConditionGroup' then child:DoLayout() end
                    local height=control:GetHeight() or child.height or 0;rowHeight=math.max(rowHeight,height)
                    local cell=child:GetUserData('cell')
                    row[#row+1]={control=control,x=x,height=height,align=widths and cell and verticalAlignment(cell.alignV) or 0}
                    if widths and column<#widths then x=x+widths[column]+gap;column=column+1
                    else finishRow() end
                end
            end
            if #row>0 then finishRow() end
            y=math.max(1,y-gap+padding)
        end
        self:LayoutFinished(width,y)
        end)
        self.layingOut=false
        if not ok then self.paused=false;error(why,0) end
        if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
    end
    ---@cast group RMConditionWidget
    return addon:RegisterConditionWidget(group)
end

-- Acquires a group from the pool. The caller owns it and its children until it is released.
-- @return RMConditionGroup  The pooled group widget.
---@return RMConditionGroup
function addon:CreateConditionGroup()
    local group=addon:AcquireConditionWidget('RM-ConditionGroup',constructor)
    ---@cast group RMConditionGroup
    return group
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="CreateConditionGroup" then return addon.CreateConditionGroup end
        if name=="ICON_ROWS_GAP" then return ICON_ROWS_GAP end
        if name=="ICON_ROWS_MINIMUM" then return ICON_ROWS_MINIMUM end
        if name=="constructor" then return constructor end
        if name=="layoutIconRows" then return layoutIconRows end
        if name=="verticalAlignment" then return verticalAlignment end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("UI/condition_layout.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["UI/condition_layout.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
