local _,addon=...
local AceGUI=LibStub('AceGUI-3.0')

---@class RMConditionCheckBox: AceGUIWidget
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
    ---@cast w AceGUIWidget
    return AceGUI:RegisterAsWidget(w)
end
AceGUI:RegisterWidgetType('RM-CheckBox',constructor,1)
---@return RMConditionCheckBox
function addon:CreateConditionCheckBox()
    local widget=AceGUI:Create('RM-CheckBox')
    ---@cast widget RMConditionCheckBox
    return widget
end
