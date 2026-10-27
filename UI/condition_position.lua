-- Condition and Help editor adapter for the arrow-block position pad: wraps the workbench pad
-- (`addon:CreateWorkbenchPositionPad`) as a pooled condition widget that fires `OnOffsetChanged(dx, dy, center,
-- amount)`. Owns only the widget shell; the pad drawing and the offset math live in the workbench, and the widget never
-- writes saved data itself. Loaded from RotationMaster.toc after UI/condition_widgets.lua, which provides the widget
-- registry. Frozen: `constructor` and `CreateConditionPositionPad` are recorded Built In helpers (see the generated
-- bindings at the end), so no comment may be added inside a function body in this file.
local _, addon = ...

-- Condition/Help adapter for the same arrow block used by settings and cards. The pool constructor builds the frame,
-- the wrapped pad and the widget methods once per pooled instance; OnAcquire rebinds the pad to the current lease so a
-- click from a released widget is ignored, and OnRelease unbinds it and disables the pad.
---@class RMConditionPositionPad: RMConditionWidget
---@field pad any
---@field disabled boolean
---@field SetDisabled fun(self: RMConditionPositionPad, value: boolean?)
local function constructor()
    local w={type='RM-ConditionPositionPad',disabled=false}
    local frame=CreateFrame('Frame',nil,UIParent);w.frame=frame
    local pad=addon:CreateWorkbenchPositionPad(frame);w.pad=pad;pad:SetPoint('TOPLEFT')
    local clicks={}
    for name,button in pairs(pad.buttons) do clicks[name]=button:GetScript('OnClick') end
    function w:SetDisabled(value)
        self.disabled=value==true
        for _,button in pairs(pad.buttons) do if self.disabled then button:Disable() else button:Enable() end end
    end
    function w:OnAcquire()
        self:SetWidth(48);self:SetHeight(48);self:SetDisabled(false)
        local lease=self.rmLease
        local function live() return w.rmActive and w.rmLease==lease and not w.disabled and not w:IsReleasing() end
        pad:Bind(function(dx,dy,center,amount) w:Fire('OnOffsetChanged',dx,dy,center,amount) end,live,false)
        for name,button in pairs(pad.buttons) do
            local click=clicks[name]
            addon:SetUIScript(button,'OnClick',function(...) if live() then return click(...) end end)
        end
    end
    function w:OnRelease()
        pad:Bind(nil,nil,true);self.disabled=true
    end
    return addon:RegisterConditionWidget(w)
end

-- Returns a pooled position pad widget (48x48) from the condition widget registry.
---@return RMConditionPositionPad
function addon:CreateConditionPositionPad()
    return self:AcquireConditionWidget('RM-ConditionPositionPad',constructor)
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="CreateConditionPositionPad" then return addon.CreateConditionPositionPad end
        if name=="constructor" then return constructor end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("UI/condition_position.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["UI/condition_position.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
