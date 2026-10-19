local _,addon=...
local AceGUI=LibStub('AceGUI-3.0')
local function defaultFont() return GameFontHighlightSmall or 'GameFontHighlightSmall' end

---@class RMConditionLabel: AceGUIWidget
---@field label FontString
---@field text string
---@field SetText fun(self: RMConditionLabel, text: any)
---@field SetFont fun(self: RMConditionLabel, path: string, height: number, flags: string?)
---@field SetFontObject fun(self: RMConditionLabel, font: any)
---@field SetColor fun(self: RMConditionLabel, red: number?, green: number?, blue: number?, alpha: number?)
---@field SetJustifyH fun(self: RMConditionLabel, value: string)
---@field SetJustifyV fun(self: RMConditionLabel, value: string)
local function labelConstructor(legacy)
    local w={type='RM-ConditionLabel',text=''}
    local frame=CreateFrame('Frame',nil,UIParent);w.frame=frame
    local label=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');w.label=label
    label:SetPoint('TOPLEFT');label:SetWordWrap(true);label:SetHeight(0)
    local function layoutText()
        label:SetWidth(math.max(1,frame:GetWidth()))
        local height=math.max(1,label:GetStringHeight() or 0)
        -- Backing frame dimensions may be quantized. Compare text requests,
        -- not engine rounding, before notifying a legacy parent's layout.
        local changed=height~=w.measuredHeight
        w.measuredHeight=height;w:SetHeight(height)
        return changed
    end
    local function measure()
        if w.measuring then return end
        w.measuring=true
        local ok,changed=pcall(layoutText)
        w.measuring=false
        if not ok then error(changed,0) end
        if changed and w.parent and w.parent.DoLayout then w.parent:DoLayout() end
    end
    function w:OnWidthSet() measure() end
    function w:SetText(text) self.text=text==nil and '' or tostring(text);label:SetText(self.text);measure() end
    function w:SetFont(path,height,flags) label:SetFont(path,height,flags);measure() end
    function w:SetFontObject(font) label:SetFontObject(font or defaultFont());measure() end
    function w:SetColor(red,green,blue,alpha)
        if red==nil or green==nil or blue==nil then red,green,blue=1,1,1 end
        label:SetTextColor(red,green,blue,alpha or 1)
    end
    function w:SetJustifyH(value) label:SetJustifyH(value) end
    function w:SetJustifyV(value) label:SetJustifyV(value) end
    function w:OnAcquire()
        self.measuring=false;self.measuredHeight=nil
        self:SetText('');self:SetFontObject();self:SetColor();self:SetJustifyH('LEFT');self:SetJustifyV('TOP');self:SetWidth(200)
    end
    function w:OnRelease() self.text='';self.measuring=false;self.measuredHeight=nil;label:SetText('') end
    return addon:RegisterConditionWidget(w,1,legacy)
end

---@class RMConditionButton: AceGUIWidget
---@field label FontString
---@field text string
---@field autoWidth boolean
---@field disabled boolean
---@field SetText fun(self: RMConditionButton, text: any)
---@field SetAutoWidth fun(self: RMConditionButton, value: boolean?)
---@field SetDisabled fun(self: RMConditionButton, value: boolean?)
local function buttonConstructor(legacy)
    local w={type='RM-ConditionButton',text='',disabled=false,autoWidth=false}
    local frame=addon:CreateWorkbenchButton(UIParent,'',200);w.frame=frame
    local label=frame:GetFontString();w.label=label;label:SetWordWrap(false)
    local enter,leave=frame:GetScript('OnEnter'),frame:GetScript('OnLeave')
    function w:OnWidthSet(width) label:SetWidth(math.max(1,width-12)) end
    function w:SetText(text)
        self.text=text==nil and '' or tostring(text);frame:SetText(self.text);label:SetText(self.text)
        if self.autoWidth then self:SetWidth(label:GetStringWidth()+30) end
    end
    function w:SetAutoWidth(value)
        self.autoWidth=value==true
        if self.autoWidth then self:SetWidth(label:GetStringWidth()+30) end
    end
    function w:SetDisabled(value) self.disabled=value==true;if self.disabled then frame:Disable() else frame:Enable() end end
    function w:OnAcquire()
        self:SetAutoWidth(false);self:SetWidth(200);self:SetHeight(24);self:SetDisabled(false);self:SetText('')
        label:SetFontObject(defaultFont());frame:SetSelected(false);frame.tooltip=nil;frame:RegisterForClicks('LeftButtonUp')
        local lease=self.rmLease
        local function live() return w.rmActive and w.rmLease==lease and not w:IsReleasing() end
        addon:SetUIScript(frame,'OnClick',function(_,button) if live() and not w.disabled then w:Fire('OnClick',button) end end)
        addon:SetUIScript(frame,'OnEnter',function() if live() then if enter then enter(frame) end;w:Fire('OnEnter') end end)
        addon:SetUIScript(frame,'OnLeave',function() if live() then if leave then leave(frame) end;w:Fire('OnLeave') end end)
    end
    function w:OnRelease()
        if GameTooltip and GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
        self.text='';frame:SetText('');label:SetText('');frame.tooltip=nil
    end
    return addon:RegisterConditionWidget(w,1,legacy)
end

-- Only explicit legacy callers allocate through Ace. Ordinary Help uses RM pools.
AceGUI:RegisterWidgetType('RM-ConditionLabel',function() return labelConstructor(true) end,1)
AceGUI:RegisterWidgetType('RM-ConditionButton',function() return buttonConstructor(true) end,1)
---@return RMConditionLabel
function addon:CreateConditionLabel() return self:AcquireConditionWidget('RM-ConditionLabel',labelConstructor) end
---@return RMConditionButton
function addon:CreateConditionButton() return self:AcquireConditionWidget('RM-ConditionButton',buttonConstructor) end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="CreateConditionButton" then return addon.CreateConditionButton end
        if name=="CreateConditionLabel" then return addon.CreateConditionLabel end
        if name=="buttonConstructor" then return buttonConstructor end
        if name=="defaultFont" then return defaultFont end
        if name=="labelConstructor" then return labelConstructor end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("UI/condition_display.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["UI/condition_display.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
