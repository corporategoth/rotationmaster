-- The condition editor's image widget: a button holding one texture and an optional caption, used for spell, item and
-- talent icons in condition editors and help pages (UI/spell_icon.lua, Conditions/talent.lua, Help/common.lua).
-- Owns the widget definition only; callers get an instance from addon:CreateConditionIcon and never build one directly.
-- Loaded from the UI/ block of RotationMaster.toc after UI/condition_widgets.lua, which supplies the lease and
-- acquire/release machinery this widget plugs into. This is a generated-binding file: constructor and
-- CreateConditionIcon are recorded as Built In helpers, so their bodies are frozen and the generated block at the end
-- is never edited.
local _, addon = ...

-- Builds one icon widget (a Button frame plus its texture and caption) for the widget pool and registers it with the
-- lease machinery. Its click and hover scripts fire only while the widget's lease is still the live one.
-- @return RMConditionIcon  The new widget, registered with the widget registry.
--
-- Shared native image primitive with owned callback and input leases. A recorded Built In helper, so its body is
-- frozen.
---@class RMConditionIcon: RMConditionWidget
---@field image Texture
---@field label FontString
---@field SetText fun(self: RMConditionIcon, text: string?)
---@field SetLabel fun(self: RMConditionIcon, text: string?)
---@field SetImage fun(self: RMConditionIcon, path: string|number|nil, ...: number)
---@field SetImageByAtlas fun(self: RMConditionIcon, atlas: string)
---@field SetImageSize fun(self: RMConditionIcon, width: number, height: number)
---@field SetDisabled fun(self: RMConditionIcon, value: boolean?)
local function constructor()
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
    return addon:RegisterConditionWidget(w)
end

-- Returns a pooled icon widget from the condition widget registry; release it through the owning container.
-- @return RMConditionIcon  The pooled icon widget.
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
