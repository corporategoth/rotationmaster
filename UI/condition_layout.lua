local _,addon=...
local AceGUI=LibStub('AceGUI-3.0')
---@class RMConditionGroup: AceGUIWidget
---@field children table[]
---@field SetLayout fun(self: RMConditionGroup, layout: string)
---@field AddChild fun(self: RMConditionGroup, child: AceGUIWidget)
---@field DoLayout fun(self: RMConditionGroup)

-- RM owns field geometry. AceGUI supplies pooling and releases legacy custom
-- child widgets until those optional APIs can be retired independently.
local function constructor()
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
        for _,child in ipairs(children) do AceGUI:Release(child);child.parent=nil end
        self:DoLayout()
    end
    function group:DoLayout()
        if self.paused or self.layingOut or self.isQueuedForRelease then return end
        self.layingOut=true
        local width=math.max(1,frame:GetWidth() or 300);local y=0;local gap=4
        local settings=self:GetUserData('table');local columns=self.layout=='Table' and settings and settings.columns
        local compatibility=self.layout~='List' and self.layout~='Table' and self.layout~='RM-SpellField'
        if columns then for _,column in ipairs(columns) do if type(column)~='number' then compatibility=true end end end
        for _,child in ipairs(self.children) do local cell=child:GetUserData('cell');if cell and (cell.colspan or cell.rowspan or cell.align or cell.alignH or cell.alignV) then compatibility=true end end
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
            local x,rowHeight,column=0,0,1
            for _,child in ipairs(self.children) do
                local control=child.frame
                if control then
                    local childWidth=widths and widths[column] or (child.width=='fill' or child.fullWidth) and width or child.width or control:GetWidth()
                    if type(childWidth)~='number' then childWidth=width end
                    child:SetWidth(math.max(1,childWidth));if child.DoLayout and child.type~='RM-ConditionGroup' then child:DoLayout() end
                    control:ClearAllPoints();control:SetPoint('TOPLEFT',frame,'TOPLEFT',x,-y)
                    local height=control:GetHeight() or child.height or 0;rowHeight=math.max(rowHeight,height)
                    if widths and column<#widths then x=x+widths[column]+gap;column=column+1
                    else y=y+rowHeight+gap;x,rowHeight,column=0,0,1 end
                end
            end
            if column>1 then y=y+rowHeight+gap end
            y=math.max(1,y-gap)
        end
        self:LayoutFinished(width,y);self.layingOut=false
        if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
    end
    ---@cast group AceGUIWidget
    return AceGUI:RegisterAsWidget(group)
end
AceGUI:RegisterWidgetType('RM-ConditionGroup',constructor,1)
---@return RMConditionGroup
function addon:CreateConditionGroup()
    local group=AceGUI:Create('RM-ConditionGroup')
    ---@cast group RMConditionGroup
    return group
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="AceGUI" then return AceGUI end
        if name=="CreateConditionGroup" then return addon.CreateConditionGroup end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("UI/condition_layout.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["UI/condition_layout.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
