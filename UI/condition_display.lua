-- Condition display widgets: the text label, the clickable link (label plus optional image) and the button that the
-- condition editor's layout engine places, built on the widget pool in UI/condition_widgets.lua.
-- They own only their own frames and measurement; they must not decide layout, which belongs to the parent container
-- (w.parent:DoLayout) and UI/condition_layout.lua.
-- Loaded from RotationMaster.toc after UI/condition_position.lua and before UI/selector.lua. The function bodies are
-- recorded as Built In helpers (see the generated bindings at the end), so nothing inside them may change.

local _, addon = ...

-- Fallback font object for labels and buttons; the global may be absent in a headless client, so the name is returned.
local function defaultFont() return GameFontHighlightSmall or 'GameFontHighlightSmall' end

-- Constructor for the pooled label (interactive false) or link (interactive true). A link adds a left image, click and
-- hover events, and a disabled state. Text measurement is re-entrancy guarded and notifies the parent layout only when
-- the measured height actually changed.
---@class RMConditionLabel: RMConditionWidget
---@field label FontString
---@field text string
---@field SetText fun(self: RMConditionLabel, text: any)
---@field SetFont fun(self: RMConditionLabel, path: string, height: number, flags: string?)
---@field SetFontObject fun(self: RMConditionLabel, font: any)
---@field SetColor fun(self: RMConditionLabel, red: number?, green: number?, blue: number?, alpha: number?)
---@field SetJustifyH fun(self: RMConditionLabel, value: string)
---@field SetJustifyV fun(self: RMConditionLabel, value: string)
local function labelConstructor(interactive)
    local w={type=interactive and 'RM-ConditionLink' or 'RM-ConditionLabel',text=''}
    local frame=CreateFrame(interactive and 'Button' or 'Frame',nil,UIParent);w.frame=frame
    local image=interactive and frame:CreateTexture(nil,'ARTWORK');w.image=image
    local label=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');w.label=label
    label:SetPoint('TOPLEFT');label:SetWordWrap(true);label:SetHeight(0)
    local function layoutText()
        local inset=image and w.imagePath and (w.imageWidth+4) or 0
        label:SetWidth(math.max(1,frame:GetWidth()-inset))
        local textHeight=math.max(1,label:GetStringHeight() or 0)
        local height=math.max(textHeight,image and w.imagePath and w.imageHeight or 0)
        label:ClearAllPoints();label:SetPoint('TOPLEFT',frame,'TOPLEFT',inset,-(height-textHeight)/2)
        if image then image:ClearAllPoints();image:SetPoint('TOPLEFT',frame,'TOPLEFT',0,-(height-w.imageHeight)/2) end
        -- Backing frame dimensions may be quantized. Compare text requests,
        -- not engine rounding, before notifying the parent layout.
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
    if interactive then
        function w:SetImage(path,...)
            self.imagePath=path;image:SetTexture(path)
            local count=select('#',...);if count==4 or count==8 then image:SetTexCoord(...) else image:SetTexCoord(0,1,0,1) end
            if path then image:Show() else image:Hide() end;measure()
        end
        function w:SetImageSize(width,height) self.imageWidth,self.imageHeight=width,height;image:SetSize(width,height);measure() end
        function w:SetDisabled(value) self.disabled=value==true;if self.disabled then frame:Disable() else frame:Enable() end end
    end
    function w:OnAcquire()
        self.measuring=false;self.measuredHeight=nil
        if interactive then self.imagePath=nil;self.imageWidth,self.imageHeight=24,24;image:SetTexture(nil);image:SetSize(24,24);image:Hide();self:SetDisabled(false) end
        self:SetText('');self:SetFontObject();self:SetColor();self:SetJustifyH('LEFT');self:SetJustifyV('TOP');self:SetWidth(200)
        if interactive then
            frame:RegisterForClicks('LeftButtonUp','RightButtonUp');local lease=self.rmLease
            local function live() return w.rmActive and w.rmLease==lease and not w:IsReleasing() end
            addon:SetUIScript(frame,'OnEnter',function() if live() then w:Fire('OnEnter') end end)
            addon:SetUIScript(frame,'OnLeave',function() if live() then w:Fire('OnLeave') end end)
            addon:SetUIScript(frame,'OnClick',function(_,button) if live() and not w.disabled then w:Fire('OnClick',button) end end)
        end
    end
    function w:OnRelease()
        self.text='';self.measuring=false;self.measuredHeight=nil;label:SetText('')
        if image then image:Hide();image:SetTexture(nil);self.imagePath=nil;if GameTooltip and GameTooltip:IsOwned(frame) then GameTooltip:Hide() end end
    end
    return addon:RegisterConditionWidget(w)
end

-- Constructor for the pooled button: a workbench button whose label can size itself to its text (SetAutoWidth) and
-- whose events only fire while the widget's lease is still the active one.
---@class RMConditionButton: RMConditionWidget
---@field label FontString
---@field text string
---@field autoWidth boolean
---@field disabled boolean
---@field SetText fun(self: RMConditionButton, text: any)
---@field SetAutoWidth fun(self: RMConditionButton, value: boolean?)
---@field SetDisabled fun(self: RMConditionButton, value: boolean?)
local function buttonConstructor()
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
    return addon:RegisterConditionWidget(w)
end

-- Acquires a label from the pool. The caller owns it until the container releases it.
---@return RMConditionLabel
function addon:CreateConditionLabel() return self:AcquireConditionWidget('RM-ConditionLabel',labelConstructor) end
-- Acquires a button from the pool.
---@return RMConditionButton
function addon:CreateConditionButton() return self:AcquireConditionWidget('RM-ConditionButton',buttonConstructor) end

-- Acquires a link (a clickable label with an optional image) from the pool; it shares its constructor with the label.
---@class RMConditionLink: RMConditionLabel
---@field image Texture
---@field SetImage fun(self: RMConditionLink, path: any, ...: number)
---@field SetImageSize fun(self: RMConditionLink, width: number, height: number)
---@field SetDisabled fun(self: RMConditionLink, disabled: boolean?)
---@return RMConditionLink
function addon:CreateConditionLink() return self:AcquireConditionWidget('RM-ConditionLink',function() return labelConstructor(true) end) end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="CreateConditionButton" then return addon.CreateConditionButton end
        if name=="CreateConditionLabel" then return addon.CreateConditionLabel end
        if name=="CreateConditionLink" then return addon.CreateConditionLink end
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
