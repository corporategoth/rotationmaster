local addon_name, addon = ...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local reasons={
    ["disabled"]=L["Disabled"], ["invalid-or-unsupported"]=L["Unavailable conditions or unsupported data"],
    ["edition-mismatch"]=L["Different WoW edition"], ["class-mismatch"]=L["Different class"],
    ["specialization-mismatch"]=L["Different specialization"], ["action-context-mismatch"]=L["Different action context"], ["ruleset-mismatch"]=L["Different season or game rules"],
    ["missing-level"]=L["Character level is unavailable"], ["level-mismatch"]=L["Outside its level range"],
    ["missing-build"]=L["Game build is unavailable"], ["build-mismatch"]=L["Different game build"],
    ["unsupported-context-selector"]=L["Required context is not supported yet"],
    ["restricted-or-unsupported-client"]=L["Reference only on this client"],
}
addon.BuiltinEligibilityReasons=reasons
local function label(parent,text,kind)
    local widget=addon:CreateConditionLabel()
    if kind=='Heading' then widget:SetFontObject(addon.WorkbenchHeaderFont);widget:SetColor(unpack(addon.WorkbenchHeaderColor)) end
    widget:SetFullWidth(true);widget:SetText(text);parent:AddChild(widget)
    return widget
end
local function referenceContent(row,spec)
    local root=addon:CreateConditionGroup();root:SetFullWidth(true);root:SetLayout('List');root:PauseLayout()
    local ok,why=pcall(function()
        addon:CreateRotationReference(root,row.envelope and row.envelope.body or {},spec)
        label(root,L['Sources'],'Heading')
        for _,source in ipairs(row.envelope and row.envelope.sources or {}) do
            label(root,source.title or source.url)
            if source.title then label(root,source.url) end
        end
    end)
    if not ok then addon:ReleaseConditionWidget(root);error(why,0) end
    root:ResumeLayout();return root
end
-- Legacy option containers still need an inner scroll area. Borrow a normal
-- native group as its lease and restore every decorated method on release.
local function addReference(frame,root)
    if frame:GetUserData('defaultWholeScroll') then frame:AddChild(root);return end
    local holder=addon:CreateConditionGroup();holder:SetFullWidth(true)
    local viewport=holder.rmDefaultViewport
    if not viewport then viewport=addon:CreateWorkbenchGroupViewport(holder.frame);holder.rmDefaultViewport=viewport end
    viewport:ClearAllPoints();viewport:SetPoint('TOPLEFT');viewport:Show()
    local layout,releaseChildren,release=holder.DoLayout,holder.ReleaseChildren,holder.OnRelease
    holder.DoLayout=function(self) viewport:SetSize(math.max(1,self.frame:GetWidth()-24),math.max(1,self.frame:GetHeight())) end
    holder.ReleaseChildren=function(self) self.children={};viewport:ReleaseConditionContent() end
    holder.OnRelease=function(self,...)
        viewport:Hide();self.DoLayout=layout;self.ReleaseChildren=releaseChildren;self.OnRelease=release
        return release(self,...)
    end
    holder:SetHeight(math.max(120,(frame.frame:GetHeight() or 480)-260));holder.children={root}
    holder:DoLayout();viewport:SetConditionContent(root);frame:AddChild(holder)
end
function addon:CreateDefaultRotationOptions(frame,spec,id,onClone,onRefresh)
    local token={};frame.rmDefaultOptionsToken=token
    local profile,global=self.db.profile,self.db.global;local lease=frame.rmLease
    local function valid()
        return frame.rmDefaultOptionsToken==token and addon.db.profile==profile and addon.db.global==global
            and (not frame.rmWidget or frame.rmActive and frame.rmLease==lease)
            and not (frame.IsReleasing and frame:IsReleasing())
    end
    frame:ReleaseChildren()
    local rows=self:ListDefaultRotations(spec);local row
    for _,candidate in ipairs(rows or {}) do if candidate.id==id then row=candidate;break end end
    if not row then label(frame,L['The Built In rotation is unavailable.']);return end
    local paused=frame.paused or frame.LayoutPaused
    if frame.PauseLayout then frame:PauseLayout() end
    local function build()
        label(frame,row.name,'Heading');label(frame,L['Built In · read-only']);label(frame,row.description)
        local scope=row.applicability or {}
        -- Only what decides loading (edition, class...); specialization and
        -- level are part of the switch condition shown in the editor.
        label(frame,(addon.DescribeApplicability and addon:DescribeApplicability(scope) or '')..' '..string.format(L['Revision %s'],tostring(row.revision or '?')))
        -- Name the first condition this client cannot support, when that is why.
        local unsupported
        if not row.eligible and row.eligibilityReason=='invalid-or-unsupported' and type(row.validation)=='table' and addon.DescribeUnsupportedCondition then
            for _,problem in ipairs(row.validation.diagnostics or {}) do unsupported=addon:DescribeUnsupportedCondition(problem);if unsupported then break end end
        end
        local status=label(frame,row.eligible and L['Available for this character']
            or string.format(L['Not available for this character: %s'],unsupported or reasons[row.eligibilityReason] or L['Unavailable']))
        local enable=addon:CreateConditionCheckBox();enable:SetLabel(L['Enable Built In']);enable:SetValue(row.switchedOn==true)
        enable:SetCallback('OnValueChanged',function(_,_,value)
            if not valid() then return end
            local ok,reason=addon:SetDefaultRotationEnabled(id,value)
            if not valid() then return end
            if not ok then status:SetText(string.format(L['Could not update this Built In rotation: %s'],reason));return end
            if addon.currentSpec~=nil and profile.enable then addon:UpdateAutoSwitch();addon:SwitchRotation();addon:EvaluateNextAction() end
            if onRefresh then onRefresh() end
        end);frame:AddChild(enable)
        local clone=addon:CreateConditionButton();clone:SetText(L['Clone to edit'])
        clone:SetCallback('OnClick',function()
            if not valid() then return end
            local generated,reason=addon:CloneDefaultRotation(spec,id,string.format(L['Copy of %s'],row.name))
            if not valid() then return end
            if generated then if onClone then onClone(generated) end
            else status:SetText(string.format(L['Could not duplicate this Built In rotation: %s'],reason)) end
        end);frame:AddChild(clone)
        local export=addon:CreateConditionButton();export:SetText(L['Export Built In'])
        export:SetCallback('OnClick',function() if valid() then return addon:ShowRotationTransfer(spec,row.runtimeKey) end end)
        frame:AddChild(export);addReference(frame,referenceContent(row,spec))
    end
    local ok,why=pcall(build)
    if not paused and frame.ResumeLayout then frame:ResumeLayout() end
    if not ok then error(why,0) end
end

function addon:ShowDefaultRotation(spec,id)
    local window=self.defaultRotationWindow
    if not window then
        window={frame=CreateFrame('Frame',nil,UIParent),children={}};self.defaultRotationWindow=window
        local frame=window.frame;frame:SetSize(880,680);frame:SetPoint('CENTER');frame:SetFrameStrata('FULLSCREEN_DIALOG');frame:SetToplevel(true);frame:SetClampedToScreen(true);frame:EnableMouse(true);self:MakeWindowOpaque(frame)
        window.title=frame:CreateFontString(nil,'OVERLAY','GameFontNormal');window.chrome=self:CreateWorkbenchDialogChrome(frame,window.title)
        window.close=self:CreateWorkbenchIconButton(frame,'close',L['Close']);window.close:SetPoint('TOPRIGHT',-5,-5)
        window.viewport=self:CreateWorkbenchGroupViewport(frame);window.viewport:SetPoint('TOPLEFT',12,-40);window.viewport:SetSize(830,612)
        function window:Clear() self.active=false;self.root=nil;self.children={};self.viewport:ReleaseConditionContent() end
        function window:Hide() self.frame:Hide() end
        addon:SetUIScript(window.close,'OnClick',function() window:Hide() end)
        addon:SetUIScript(frame,'OnHide',function() window:Clear() end);frame:Hide()
    end
    window:Clear();window.serial=(window.serial or 0)+1;local serial=window.serial
    local profile,global=self.db.profile,self.db.global
    local root=self:CreateConditionGroup();root:SetLayout('List');root:SetUserData('defaultWholeScroll',true)
    window.root=root;window.children={root};window.active=true;local lease=root.rmLease
    local function valid() return window.active and window.serial==serial and addon.db.profile==profile and addon.db.global==global and root.rmActive and root.rmLease==lease end
    window.chrome:SetContext(L['Built In rotation reference'],L['Built In · read-only'],self.pretty_name)
    window.viewport:SetConditionContent(root)
    local function cloned(generated)
        if not valid() then return end
        window:Hide();addon:ShowConfig('Rotations',{spec=spec,id=generated})
    end
    local function refresh() if valid() then addon:CreateDefaultRotationOptions(root,spec,id,cloned,refresh) end end
    local ok,why=pcall(refresh)
    if not ok then window:Clear();error(why,0) end
    addon:SetUIScript(window.frame,'OnUpdate',function() if window.active and window.serial==serial and not valid() then window:Hide() end end)
    window.frame:Show();addon:RegisterWindowForEscape(window)
    return window
end
