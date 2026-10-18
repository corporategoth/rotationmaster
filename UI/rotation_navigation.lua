local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)

function addon:InstallRotationNavigation(pane)
    function pane:ConfirmDelete()
        local workspace=self.workspace
        if not self.active or workspace.readOnly or workspace.pending or workspace.id==DEFAULT then return end
        if not self.deletePrompt then
            local frame=CreateFrame('Frame',nil,self.frame);frame:SetSize(390,110);frame:SetPoint('CENTER');frame:EnableMouse(true)
            local bg=frame:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints(frame);bg:SetColorTexture(.06,.07,.08,1)
            local label=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');label:SetPoint('TOPLEFT',12,-12);label:SetWidth(366);label:SetWordWrap(true)
            label:SetText(L['Delete this custom rotation and its unsaved draft? This cannot be undone.'])
            local confirm=addon:CreateWorkbenchButton(frame,L['Delete'],90);confirm:SetPoint('BOTTOMRIGHT',-110,12)
            local cancel=addon:CreateWorkbenchButton(frame,L['Cancel'],90);cancel:SetPoint('BOTTOMRIGHT',-12,12)
            self.deletePrompt={frame=frame,confirm=confirm,cancel=cancel};frame:Hide()
        end
        local prompt=self.deletePrompt;local token=self.generation
        local function valid() return pane.active and pane.generation==token and pane.workspace==workspace and prompt.frame:IsShown() and workspace:ValidTarget() end
        addon:SetUIScript(prompt.cancel,'OnClick',function() if valid() then prompt.frame:Hide() end end)
        addon:SetUIScript(prompt.confirm,'OnClick',function()
            if not valid() then return end
            local ok,why=addon:DeleteCustomRotation(workspace.spec,workspace.id)
            if not ok then pane:Message(why);return end
            prompt.frame:Hide();pane:RefreshAdvice();pane:AfterDelete()
        end)
        prompt.frame:SetFrameLevel(self.frame:GetFrameLevel()+100);prompt.frame:Show();addon:RegisterWindowForEscape(prompt)
    end
    function pane:RequestLeave(callback)
        if not self.active or type(callback)~='function' then return nil,'rotation-pane-released' end
        if self.metadataWindow and self.metadataWindow.frame:IsShown() then if not self:FlushName() then return false,'invalid-metadata' end;self.metadataWindow:Close(true) end
        if not self:HasUnsavedChanges() then callback();return true end
        if not self.leavePrompt then
            local frame=CreateFrame('Frame',nil,self.frame);frame:SetSize(420,130);frame:SetPoint('CENTER');frame:EnableMouse(true)
            local background=frame:CreateTexture(nil,'BACKGROUND');background:SetAllPoints(frame);background:SetColorTexture(.06,.07,.08,1)
            local title=frame:CreateFontString(nil,'OVERLAY','GameFontHighlight');title:SetPoint('TOPLEFT',14,-14);title:SetText(L['Unsaved rotation changes'])
            local message=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');message:SetPoint('TOPLEFT',14,-38);message:SetWidth(392);message:SetWordWrap(true)
            message:SetText(L['Apply this draft, discard its changes, or keep editing.'])
            self.leavePrompt={frame=frame,message=message}
            for index,entry in ipairs({{'apply',L['Apply']},{'discard',L['Discard']},{'cancel',L['Cancel']}}) do
                local control=addon:CreateWorkbenchButton(frame,entry[2],124);control:SetPoint('BOTTOMLEFT',14+(index-1)*134,14);self.leavePrompt[entry[1]]=control
            end
            addon:SetUIScript(frame,'OnHide',function() pane.pendingLeave=nil end);frame:Hide()
        end
        local prompt=self.leavePrompt
        local request={callback=callback,generation=self.generation,workspace=self.workspace};self.pendingLeave=request
        local function valid() return pane.active and pane.pendingLeave==request and pane.generation==request.generation and pane.workspace==request.workspace end
        addon:SetUIScript(prompt.apply,'OnClick',function()
            if not valid() then return end
            local ok,why=pane:Apply()
            if not ok then prompt.message:SetText(L['The draft could not be applied. Complete the marked fields or Cancel to keep editing.']..' '..tostring(why));return end
            prompt.frame:Hide();callback()
        end)
        addon:SetUIScript(prompt.discard,'OnClick',function()
            if not valid() then return end
            local ok,why=pane.workspace:Discard();if not ok then pane:Message(why);return end
            pane.nameDirty=false;pane.descriptionDirty=false;pane.metadataDirty=false;pane:ClearPendingFields();prompt.frame:Hide();callback()
        end)
        addon:SetUIScript(prompt.cancel,'OnClick',function() if valid() then prompt.frame:Hide() end end)
        prompt.message:SetText(L['Apply this draft, discard its changes, or keep editing.'])
        prompt.frame:SetFrameLevel(self.frame:GetFrameLevel()+100);prompt.frame:Show();addon:RegisterWindowForEscape(prompt)
        return false,'rotation-navigation-pending'
    end
end
