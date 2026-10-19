local _,addon=...
local AceGUI=LibStub('AceGUI-3.0')

-- Condition/Help adapter for the same arrow block used by settings and cards.
---@class RMConditionPositionPad: AceGUIWidget
---@field pad any
---@field disabled boolean
---@field SetDisabled fun(self: RMConditionPositionPad, value: boolean?)
local function constructor(legacy)
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
    return addon:RegisterConditionWidget(w,1,legacy)
end
AceGUI:RegisterWidgetType('RM-ConditionPositionPad',function() return constructor(true) end,1)
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
