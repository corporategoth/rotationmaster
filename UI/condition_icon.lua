local _,addon=...
local AceGUI=LibStub('AceGUI-3.0')

-- Shared image primitive. RM owns ordinary leases; custom Ace containers may
-- transfer the same public widget contract through the legacy bridge.
---@class RMConditionIcon: AceGUIIcon
---@field image Texture
---@field label FontString
---@field SetText fun(self: RMConditionIcon, text: string?)
local function constructor(legacy)
    local w={type='RM-ConditionIcon',alive=false,disabled=false}
    local frame=CreateFrame('Button',nil,UIParent);w.frame=frame;frame:EnableMouse(true)
    local image=frame:CreateTexture(nil,'ARTWORK');w.image=image;image:SetPoint('TOP',0,-5)
    local label=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');w.label=label
    label:SetPoint('BOTTOMLEFT');label:SetPoint('BOTTOMRIGHT');label:SetJustifyH('CENTER');label:SetJustifyV('TOP');label:SetHeight(18)
    function w:SetLabel(text)
        self.labelText=text or '';label:SetText(self.labelText)
        if self.labelText~='' then label:Show() else label:Hide() end
        self:SetHeight(image:GetHeight()+(self.labelText~='' and 25 or 10))
    end
    function w:SetText(text) self:SetLabel(text) end
    function w:SetImage(path,...)
        image:SetTexture(path)
        local count=select('#',...)
        if count==4 or count==8 then image:SetTexCoord(...) else image:SetTexCoord(0,1,0,1) end
    end
    function w:SetImageByAtlas(atlas) image:SetAtlas(atlas) end
    function w:SetImageSize(width,height)
        image:SetSize(width,height);self:SetHeight(height+(self.labelText~='' and 25 or 10))
    end
    function w:SetDisabled(value)
        self.disabled=value==true
        if self.disabled then frame:Disable();image:SetVertexColor(.5,.5,.5,.5);label:SetTextColor(.5,.5,.5)
        else frame:Enable();image:SetVertexColor(1,1,1,1);label:SetTextColor(1,1,1) end
    end
    function w:OnAcquire()
        self.alive=true;self:SetWidth(110);self:SetLabel('');self:SetImage(nil);self:SetImageSize(64,64);self:SetDisabled(false)
        frame:RegisterForClicks('LeftButtonUp')
        local lease=self.rmLease
        local function live() return w.alive and w.rmActive and w.rmLease==lease and not w:IsReleasing() end
        addon:SetUIScript(frame,'OnClick',function(_,button) if live() and not w.disabled then w:Fire('OnClick',button) end end)
        addon:SetUIScript(frame,'OnEnter',function() if live() then w:Fire('OnEnter') end end)
        addon:SetUIScript(frame,'OnLeave',function() if live() then w:Fire('OnLeave') end end)
    end
    function w:OnRelease()
        self.alive=false
        if GameTooltip and GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
        self:SetLabel('');self:SetImage(nil)
    end
    return addon:RegisterConditionWidget(w,1,legacy)
end
AceGUI:RegisterWidgetType('RM-ConditionIcon',function() return constructor(true) end,1)
---@return RMConditionIcon
function addon:CreateConditionIcon()
    return self:AcquireConditionWidget('RM-ConditionIcon',constructor)
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="CreateConditionIcon" then return addon.CreateConditionIcon end
        if name=="constructor" then return constructor end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("UI/condition_icon.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["UI/condition_icon.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
