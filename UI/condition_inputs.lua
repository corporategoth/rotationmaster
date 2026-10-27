local _, addon = ...
local function finite(value) return type(value)=='number' and value==value and value>-math.huge and value<math.huge end

-- Native visuals and pending-input protocol shared by condition fields.
---@class RMConditionInput: RMConditionWidget
---@field editbox EditBox
---@field SetFocus fun(self: RMConditionInput)
---@field ClearFocus fun(self: RMConditionInput)
---@field SetMaxLetters fun(self: RMConditionInput, value: number)
---@field DisableButton fun(self: RMConditionInput)
---@field SetText fun(self: RMConditionInput, text: any)
---@field GetText fun(self: RMConditionInput): string
---@field SetLabel fun(self: RMConditionInput, text: string)
---@field SetDisabled fun(self: RMConditionInput, disabled: boolean?)
---@field SetValue fun(self: RMConditionInput, value: number?)
---@field GetValue fun(self: RMConditionInput): number?
---@field SetSliderValues fun(self: RMConditionInput, minimum: number, maximum: number, step: number)
---@field SetIsPercent fun(self: RMConditionInput, value: boolean?)
---@field IsPending fun(self: RMConditionInput): boolean
---@field CommitPending fun(self: RMConditionInput): boolean?
local function constructor(numeric)
    local w={type=numeric and 'RM-ConditionSlider' or 'RM-ConditionEditBox',alive=false}
    local frame=CreateFrame('Frame',nil,UIParent);w.frame=frame;frame:SetSize(220,44)
    local caption=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');w.caption=caption
    caption:SetPoint('TOPLEFT');caption:SetPoint('TOPRIGHT');caption:SetHeight(18);caption:SetJustifyH('LEFT')
    local input=addon:CreateWorkbenchEditBox(frame);w.editbox=input;input:SetMaxLetters(4096)
    local slider=numeric and addon:CreateWorkbenchSlider(frame,0,100,1,140) or nil;w.slider=slider
    local function display()
        local value=w.value
        if not numeric then return w.text or '' end
        if value==nil then return '' end
        if not finite(value) then return tostring(value) end
        return string.format('%.6g',value*(w.isPercent and 100 or 1))..(w.isPercent and '%' or '')
    end
    local function parse(text)
        text=text:match('^%s*(.-)%s*$')
        if w.isPercent and text:sub(-1)=='%' then text=text:sub(1,-2) end
        local value=tonumber(text)
        if not finite(value) then return end
        if w.isPercent then value=value/100 end
        if value<w.minimum or value>w.maximum then return end
        return value
    end
    local function paint()
        w.setting=true;input:SetText(display());w.confirmed=input:GetText();w.pending=false
        input:SetTextColor(1,1,1)
        if slider then slider:SetValue(finite(w.value) and w.value or w.minimum) end
        w.setting=false
    end
    local function pendingChanged() w:Fire('OnPendingChanged',w.pending) end
    function w:SetLabel(text)
        self.label=text or '';caption:SetText(self.label);local y=self.label~='' and -20 or 0
        if self.label~='' then caption:Show() else caption:Hide() end
        input:ClearAllPoints();input:SetPoint('TOPRIGHT',0,y);input:SetHeight(24)
        if slider then
            input:SetWidth(64);slider:ClearAllPoints();slider:SetPoint('LEFT',frame,'LEFT',0,y/2);slider:SetPoint('RIGHT',input,'LEFT',-8,0)
        else input:SetPoint('TOPLEFT',0,y) end
        self:SetHeight(self.label~='' and 44 or 24)
    end
    function w:SetText(text) self.text=text==nil and '' or tostring(text);paint() end
    function w:GetText() return input:GetText() end
    function w:SetValue(value) self.value=value;paint() end
    function w:GetValue() return self.value end
    function w:SetSliderValues(minimum,maximum,step)
        if not finite(minimum) or not finite(maximum) or maximum<minimum or not finite(step) or step<=0 then return end
        self.minimum,self.maximum,self.step=minimum,maximum,step
        self.setting=true;slider:SetMinMaxValues(minimum,maximum);slider:SetValueStep(step);self.setting=false;paint()
    end
    function w:SetIsPercent(value) self.isPercent=value==true;paint() end
    function w:IsPending() return self.alive and not self.disabled and self.pending==true end
    function w:CommitPending()
        local owner=self
        for _=1,128 do
            if not owner then break end
            if owner.isQueuedForRelease then return true end
            owner=owner.parent
        end
        if not self:IsPending() then return true end
        local text=input:GetText();local value=numeric and parse(text) or text
        if numeric and not finite(value) then input:SetTextColor(1,.35,.35);return nil end
        local changed=numeric and value~=self.value or not numeric and text~=self.text
        if numeric then self.value=value else self.text=text end
        paint()
        if changed then self:Fire(numeric and 'OnValueChanged' or 'OnEnterPressed',value) end
        pendingChanged();return true
    end
    function w:SetFocus() if self.alive and not self.disabled then input:SetFocus() end end
    function w:ClearFocus() input:ClearFocus() end
    function w:SetMaxLetters(value) input:SetMaxLetters(value) end
    function w:SetDisabled(value)
        self.disabled=value==true
        input:EnableMouse(not self.disabled);input:EnableKeyboard(not self.disabled)
        if slider then slider:EnableMouse(not self.disabled) end
        frame:SetAlpha(self.disabled and .45 or 1)
        if self.disabled then paint();input:ClearFocus() end
    end
    function w:OnAcquire()
        self.alive=true;self.minimum,self.maximum,self.step=0,100,1;self.isPercent=false;self.value=nil;self.text=''
        self:SetMaxLetters(4096);self:SetWidth(220);self:SetLabel('');self:SetDisabled(false)
        if slider then self:SetSliderValues(0,100,1) end;paint()
    end
    function w:OnRelease() self.alive=false;self.pending=false;input:ClearFocus() end
    addon:SetUIScript(input,'OnTextChanged',function(_,user)
        if w.setting or not user or not w.alive or w.disabled then return end
        w.pending=input:GetText()~=w.confirmed
        local valid=not numeric or parse(input:GetText())~=nil
        input:SetTextColor(1,valid and 1 or .35,valid and 1 or .35);pendingChanged()
    end)
    addon:SetUIScript(input,'OnEnterPressed',function() if w.alive and not w.disabled and w:CommitPending() then input:ClearFocus() end end)
    addon:SetUIScript(input,'OnEditFocusLost',function() if w.alive and not w.disabled and not w.isQueuedForRelease then w:CommitPending() end end)
    addon:SetUIScript(input,'OnEscapePressed',function() if w.alive then paint();input:ClearFocus();pendingChanged() end end)
    -- Reference popups can temporarily hide their editor. Only release
    -- discards pending input; ordinary hiding must retain invalid blockers too.
    addon:SetUIScript(frame,'OnHide',function() input:ClearFocus() end)
    if slider then
        slider:EnableMouseWheel(true)
        addon:SetUIScript(slider,'OnValueChanged',function(_,value)
            if w.setting or not w.alive or w.disabled or not finite(value) then return end
            value=math.max(w.minimum,math.min(w.maximum,w.minimum+math.floor((value-w.minimum)/w.step+.5)*w.step))
            local changed=value~=w.value;w.value=value;paint()
            if changed then w:Fire('OnValueChanged',value) end;pendingChanged()
        end)
        addon:SetUIScript(slider,'OnMouseWheel',function(_,direction)
            if w.alive and not w.disabled and direction~=0 then slider:SetValue((finite(w.value) and w.value or w.minimum)+(direction>0 and w.step or -w.step)) end
        end)
    end
    ---@cast w RMConditionWidget
    return addon:RegisterConditionWidget(w)
end

---@return RMConditionInput
function addon:CreateConditionEditBox()
    local w=addon:AcquireConditionWidget('RM-ConditionEditBox',function() return constructor(false) end)
    ---@cast w RMConditionInput
    return w
end

---@return RMConditionInput
function addon:CreateConditionSlider()
    local w=addon:AcquireConditionWidget('RM-ConditionSlider',function() return constructor(true) end)
    ---@cast w RMConditionInput
    return w
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="CreateConditionEditBox" then return addon.CreateConditionEditBox end
        if name=="CreateConditionSlider" then return addon.CreateConditionSlider end
        if name=="constructor" then return constructor end
        if name=="finite" then return finite end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("UI/condition_inputs.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["UI/condition_inputs.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
