local _,addon=...

---@class RMConditionCheckBox: RMConditionWidget
---@field button Button
---@field SetLabel fun(self: RMConditionCheckBox, text: string)
---@field SetValue fun(self: RMConditionCheckBox, value: boolean?)
---@field GetValue fun(self: RMConditionCheckBox): boolean
---@field SetDisabled fun(self: RMConditionCheckBox, disabled: boolean)
local function constructor()
    local w={type='RM-CheckBox',alive=false,disabled=false}
    local frame=CreateFrame('Frame',nil,UIParent);w.frame=frame;frame:SetSize(180,24)
    local button=addon:CreateWorkbenchCheckBox(frame,'',180);w.button=button;button:SetAllPoints(frame)
    function w:OnAcquire() self.alive=true;self:SetLabel('');self:SetValue(false);self:SetDisabled(false);self:SetWidth(180);self:SetHeight(24) end
    function w:OnRelease() self.alive=false;self:SetValue(false) end
    function w:SetLabel(text) button:SetText(text or '') end
    function w:SetValue(value) button:SetChecked(value==true) end
    function w:GetValue() return button:GetChecked() end
    function w:SetDisabled(value) self.disabled=value==true;if self.disabled then button:Disable();button:SetAlpha(.45) else button:Enable();button:SetAlpha(1) end end
    function w:OnWidthSet(width) button:GetFontString():SetWidth(math.max(1,width-22)) end
    addon:SetUIScript(button,'OnClick',function()
        if not w.alive or w.disabled then return end
        w:SetValue(not w:GetValue());w:Fire('OnValueChanged',w:GetValue())
    end)
    ---@cast w RMConditionWidget
    return addon:RegisterConditionWidget(w)
end
---@return RMConditionCheckBox
function addon:CreateConditionCheckBox()
    local widget=addon:AcquireConditionWidget('RM-CheckBox',constructor)
    ---@cast widget RMConditionCheckBox
    return widget
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="CreateConditionCheckBox" then return addon.CreateConditionCheckBox end
        if name=="constructor" then return constructor end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("UI/checkbox.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["UI/checkbox.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
