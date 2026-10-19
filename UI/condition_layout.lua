local _,addon=...
local AceGUI
-- Advanced saved layouts share this cell with the unchanged constructor.
function addon:BindConditionGroupCompatibilityLibrary()
    AceGUI=addon:GetConditionWidgetCompatibilityLibrary()
    return AceGUI
end
---@class RMConditionGroup: AceGUIWidget
---@field children table[]
---@field rmLease table
---@field rmActive boolean
---@field SetLayout fun(self: RMConditionGroup, layout: string)
---@field AddChild fun(self: RMConditionGroup, child: AceGUIWidget)
---@field DoLayout fun(self: RMConditionGroup)
---@field PauseLayout fun(self: RMConditionGroup)
---@field ResumeLayout fun(self: RMConditionGroup)
---@field ReleaseChildren fun(self: RMConditionGroup)

-- RM owns field geometry and ordinary widget leases. Historical custom child
-- widgets and advanced layouts retain an explicit Ace compatibility path.
-- Simple vertical cell alignment belongs to the native numeric table layout.
-- Other cell features still use the explicitly requested legacy layout.
local function verticalAlignment(value)
    if value==nil then return 0 end
    if type(value)~='string' then return nil end
    value=value:lower()
    if value=='start' or value:sub(1,3)=='top' then return 0 end
    if value=='end' or value:sub(1,6)=='bottom' then return 1 end
    if value=='middle' or value:sub(1,6)=='center' then return .5 end
end
local function constructor(legacy)
    local group={type='RM-ConditionGroup',children={}}
    local frame=CreateFrame('Frame',nil,UIParent);group.frame=frame;group.content=frame
    function group:OnAcquire() self.children={};self.layout='List';self.paused=false;self.layingOut=false;self:SetWidth(300);self:SetHeight(1) end
    function group:SetLayout(layout) self.layout=layout;self:DoLayout() end
    function group:PauseLayout() self.paused=true end
    function group:ResumeLayout() self.paused=false;self:DoLayout() end
    function group:OnWidthSet() if not self.sizing then self:DoLayout() end end
    function group:SetWidth(width)
        self.sizing=true;frame:SetWidth(width);frame.width=width;self.sizing=false;self:DoLayout()
    end
    function group:LayoutFinished(_,height) self:SetHeight(height or 1) end
    function group:AddChild(child)
        self.children[#self.children+1]=child;child.parent=self
        if child.frame then child.frame:SetParent(frame);child.frame:Show() end
        self:DoLayout()
    end
    function group:AddChildren(...) for i=1,select('#',...) do self:AddChild(select(i,...)) end end
    function group:ReleaseChildren()
        local children=self.children;self.children={}
        local problem
        for _,child in ipairs(children) do local ok,why=pcall(addon.ReleaseConditionWidget,addon,child);child.parent=nil;if not ok then problem=problem or why end end
        if problem then error(problem,0) end
        self:DoLayout()
    end
    function group:DoLayout()
        if self.paused or self.layingOut or self.isQueuedForRelease then return end
        self.layingOut=true
        local width=math.max(1,frame:GetWidth() or 300);local padding=self:GetUserData('padding')
        padding=type(padding)=='number' and padding==padding and math.max(0,math.min(64,padding)) or 0
        width=math.max(1,width-padding*2);local y=padding;local gap=4
        local settings=self:GetUserData('table');local columns=self.layout=='Table' and settings and settings.columns
        local compatibility=self.layout~='List' and self.layout~='Table' and self.layout~='RM-SpellField'
        if self.layout=='Table' and settings and (settings.align or settings.alignH or settings.alignV or settings.space~=nil or settings.spaceH~=nil or settings.spaceV~=nil) then compatibility=true end
        if columns then for _,column in ipairs(columns) do if type(column)~='number' then compatibility=true end end end
        for _,child in ipairs(self.children) do local cell=child:GetUserData('cell');if cell and (cell.colspan or cell.rowspan or cell.align or cell.alignH or cell.alignV and (self.layout~='Table' or verticalAlignment(cell.alignV)==nil)) then compatibility=true end end
        local legacy=compatibility and AceGUI.GetLayout and AceGUI:GetLayout(self.layout)
        if legacy then
            -- Saved custom callbacks can still request Ace layouts and advanced
            -- table cells. Retain that explicit compatibility path while RM's
            -- ordinary built-in groups own their geometry here.
            legacy(frame,self.children);self.layingOut=false
            if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
            return
        elseif self.layout=='RM-SpellField' then
            y=addon:LayoutWorkbenchSpellGroup(frame,self.children) or 0
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
        self:LayoutFinished(width,y);self.layingOut=false
        if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
    end
    ---@cast group AceGUIWidget
    return addon:RegisterConditionWidget(group,1,legacy)
end
---@return RMConditionGroup
function addon:CreateConditionGroup()
    local group=addon:AcquireConditionWidget('RM-ConditionGroup',constructor)
    ---@cast group RMConditionGroup
    return group
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="AceGUI" then return addon:BindConditionGroupCompatibilityLibrary() end
        if name=="CreateConditionGroup" then return addon.CreateConditionGroup end
        if name=="constructor" then return constructor end
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
