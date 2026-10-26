local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
function addon:NewRotationCodec()
    local serializer,compressor=LibStub("AceSerializer-3.0"),LibStub("LibCompress")
    return self.RotationData.NewCodec({
        serialize=function(value) return serializer:Serialize(value) end,
        deserialize=function(text) return serializer:Deserialize(text) end,
        compress=function(text) return compressor:Compress(text,1) end,
        decompress=function(text) return compressor:Decompress(text) end,
    })
end
function addon:ShowNativeImportPreview(p,view,spec)
    local d=p.importPreview
    if not d then
        d={frame=CreateFrame('Frame',nil,UIParent)};p.importPreview=d;d.frame:SetSize(940,620);d.frame:SetPoint('CENTER');d.frame:SetFrameStrata('FULLSCREEN_DIALOG');d.frame:SetToplevel(true);d.frame:SetClampedToScreen(true);d.frame:EnableMouse(true);self:MakeWindowOpaque(d.frame)
        d.title=d.frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=self:CreateWorkbenchDialogChrome(d.frame,d.title);d.close=self:CreateWorkbenchIconButton(d.frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5);self:SetUIScript(d.close,'OnClick',function() d.frame:Hide() end)
        d.scroll=self:CreateWorkbenchGroupViewport(d.frame);d.scroll:SetPoint('TOPLEFT',12,-34);d.scroll:SetSize(898,560)
        function d:Clear() self.scroll:ReleaseConditionContent();self.graph=nil end
        self:SetUIScript(d.frame,'OnHide',function() d:Clear() end);d.frame:Hide()
    end
    d:Clear();d.serial=(d.serial or 0)+1;local serial=d.serial
    local graph=self:CreateConditionGroup();d.graph=graph;graph:SetLayout('List');d.scroll:SetConditionContent(graph)
    d.chrome:SetContext(L['Import comparison'],L['Read-only'],self.pretty_name)
    local ok,why=pcall(self.RenderRotationComparison,self,graph,view,spec)
    if not ok then d:Clear();error(why,0) end
    p.cleanups[#p.cleanups+1]=function() if d.serial==serial then d.frame:Hide() end end;d.frame:Show();self:RegisterWindowForEscape(d)
    if self.BindTransferHelp then
        local generation=p.generation;local graphLease=graph.rmLease;local evidence=self:CopySettingsData(view)
        self:BindTransferHelp(d,{heading=L['Import comparison'],brief=L['Help.Transfers.comparison_brief'],sections={{title=L['Read-only'],text=L['Help.Transfers.comparison']}},briefs={close=L['Help.Transfers.cancel']}},function()
            return p.importPreview==d and d.serial==serial and p.generation==generation and (not p.Valid or p:Valid(generation))
                and d.graph==graph and graph.rmActive and graph.rmLease==graphLease and addon:SettingsDataEqual(view,evidence)
        end)
    end
    return d
end
-- The full content of an incoming rotation, read-only, in the rotation editor
-- itself: header, specializations, switch condition, steps and cooldowns, as
-- they are shown for a Built In. The editor works on a detached copy of the
-- staged candidate (NewRotationPreviewWorkspace): nothing here can reach the
-- candidate, the live profile or the rotation in the transfer window.
function addon:ShowNativeImportContent(p,preview,spec)
    local d=p.importContent
    if not d then
        d={frame=CreateFrame('Frame',nil,UIParent)};p.importContent=d;d.frame:SetSize(940,620);d.frame:SetPoint('CENTER');d.frame:SetFrameStrata('FULLSCREEN_DIALOG');d.frame:SetToplevel(true);d.frame:SetClampedToScreen(true);d.frame:EnableMouse(true);self:MakeWindowOpaque(d.frame)
        d.title=d.frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=self:CreateWorkbenchDialogChrome(d.frame,d.title);d.close=self:CreateWorkbenchIconButton(d.frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5);self:SetUIScript(d.close,'OnClick',function() d.frame:Hide() end)
        d.host=CreateFrame('Frame',nil,d.frame);d.host:SetPoint('TOPLEFT',12,-34);d.host:SetSize(916,562)
        function d:Clear()
            local pane,workspace=self.pane,self.workspace;self.pane=nil;self.workspace=nil
            if pane and pane.active then pane:Release() end
            if workspace then workspace:Close() end
        end
        self:SetUIScript(d.frame,'OnHide',function() d:Clear() end);d.frame:Hide()
    end
    d:Clear();d.serial=(d.serial or 0)+1;local serial=d.serial
    local workspace,why=self:NewRotationPreviewWorkspace(spec,preview);if not workspace then return nil,why end
    local pane,problem=self:CreateRotationEditor(d.host,spec,workspace.id,nil,workspace);if not pane then workspace:Close();return nil,problem end
    d.workspace=workspace;d.pane=pane
    d.chrome:SetContext(L['Import preview'],L['Read-only'],self.pretty_name)
    p.cleanups[#p.cleanups+1]=function() if d.serial==serial then d.frame:Hide() end end;d.frame:Show();self:RegisterWindowForEscape(d)
    if self.BindTransferHelp then
        local generation=p.generation
        self:BindTransferHelp(d,{heading=L['Import preview'],brief=L['Help.Transfers.preview_view_brief'],sections={{title=L['Read-only'],text=L['Help.Transfers.preview_view']}},briefs={close=L['Help.Transfers.cancel']}},function()
            return p.importContent==d and d.serial==serial and p.generation==generation and (not p.Valid or p:Valid(generation))
                and d.workspace==workspace and not workspace.closed and d.pane==pane and pane.active
        end)
    end
    return d
end
function addon:ShowRotationTransfer(spec,id)
    local codec=self:NewRotationCodec()
    local source,exportError=self:GetRotationExportData(spec,id);local exported;if source then exported,exportError=codec:Encode(source) end
    -- The Format choice (Rotation Master or WowSims): the session reads what is pasted through the chosen format.
    local formats=self:NewTransferFormatState(codec,source,spec,exported)
    local session=self.RotationData.NewImportSession(formats.codec,self:GetImportValidationOptions())
    local p=self.rotationTransferForm
    if p then p:Release() else local host=CreateFrame('Frame',nil,UIParent);host:SetSize(1,1);host:Hide();p=self:CreateSettingsForm(host);self.rotationTransferForm=p end
    p:Open(function() end)
    local reference=self:ResolveRotationReference(spec,id)
    local record,recordToken;if reference then record,recordToken=self:GetRotationRecordSnapshot(spec,reference) end
    -- A snapshot that failed answers (nil, reason): the reason is a string, not a token. A selection with no saved
    -- record (a new rotation not applied yet, a Default never saved) has nothing to replace.
    if type(record)~='table' or type(recordToken)~='table' then recordToken=nil end
    local original=record and record.body;local profile=self.db.profile;local coordinator=self:GetScopedRotationCoordinator();local context=self:GetRotationOwnerContext()
    local expected={profile=profile,reference=reference,recordToken=recordToken}
    local candidate,dialog;local active=true;local generation=p.generation
    local function valid()
        if not active or not p:Valid(generation) or addon.db.profile~=profile or addon:GetScopedRotationCoordinator()~=coordinator or not coordinator or not coordinator:CheckReady() then return false end
        local now=addon:GetRotationOwnerContext()
        if not now or not context or now.class~=context.class or now.character~=context.character then return false end
        return not recordToken or coordinator:TokenCurrent(recordToken)
    end
    -- Which selections an import can replace: a saved custom rotation, the saved Default included (it is a custom
    -- record and Apply replaces it in place). Never a Built In, a new rotation not yet applied, or a Default that was
    -- never saved. canReplace is the one answer; the dialog's mode starts from it and everything below reads the mode.
    local canReplace=reference~=nil and reference.kind=='custom' and record~=nil and recordToken~=nil
    local options={valid=valid,canReplace=canReplace,selectedName=original and original.name or source and self:RotationDisplayName(source),fallbackName=L['Imported rotation'],requirePreview=true,
        help={heading=L['Import/Export Rotation'],brief=L['Help.Transfers.rotation_brief'],briefs=self:TransferHelpBriefs(),sections={{title=L['Import/Export'],text=L['Help.Transfers.rotation']},{title=L['Preview import'],text=L['Help.Transfers.rotation_preview']},{title=L['Applies to'],text=L['Copies belong to your Class unless This character is selected. Replacement keeps its original owner.']},{title=L['Format'],text=L['Help.Transfers.rotation_format']}}}}
    options.originalName=function(text) local decoded=formats.codec:Decode(text);local value=decoded and decoded.value;if type(value)=='table' then return self:RotationDisplayName(value) end end
    options.invalidate=function(d) if not valid() or dialog and (d~=dialog or d.options~=options) then return end;candidate=nil;session:Clear();d.apply:Disable();d.inspect:Disable();d.status:SetText(d.mode=='replace' and L['Text changed. Compare again before importing.'] or L['Text changed. Preview again before importing.']);if p.importPreview then p.importPreview.frame:Hide() end;if p.importContent then p.importContent.frame:Hide() end end
    options.preview=function(d)
        if not valid() then return end
        local why;candidate,why=session:Stage(d.input:GetText());d.apply:Disable();d.inspect:Disable()
        if not candidate then
            d.status:SetText(string.format(L['Import preview unavailable: %s'],tostring(why)))
            -- A WowSims rotation with nothing to import still has a report that says why.
            if formats.format=='wowsims' and formats.failure and formats.failure.report then d.inspect:Enable() end
            return
        end
        d.inspect:Enable();local ready,reason=session:GetReady(candidate.token)
        d.status:SetText(ready and L['Ready to import. Choose replacement or a named copy.'] or string.format(L['This import cannot be applied: %s'],reason));if ready then d.apply:Enable() end
        if formats.format=='wowsims' and formats.lastImport then
            local summary=formats.lastImport.report.summary
            d.status:SetText((d.status:GetText() or '')..'\n'..string.format(L['Converted from WowSims: %d steps, %d disabled. Choose Check import for the full report.'],summary.steps,summary.disabled))
        end
        if p.importPreview then p.importPreview.frame:Hide() end;if p.importContent then p.importContent.frame:Hide() end
        if d.mode=='replace' and canReplace then
            -- Replacing: what would change in the selected rotation.
            local own=original or source and (source.body or source) or {rotation={},cooldowns={}};local view=session:Compare(candidate.token,own,self.RotationData.GetRotationTags(source));if view then self:ShowNativeImportPreview(p,view,spec) end
        else
            -- A new copy: nothing to compare with, so everything that would be created.
            local incoming,missing=session:Preview(candidate.token)
            local shown,problem
            if incoming then local ok,result,reason=pcall(self.ShowNativeImportContent,self,p,incoming,spec);if ok then shown,problem=result,reason else problem=result end else problem=missing end
            if not shown and valid() then d.status:SetText((d.status:GetText() or '')..'\n'..string.format(L['This import cannot be shown in full (%s). Use Check import for details.'],tostring(problem))) end
        end
    end
    options.inspect=function()
        if formats.format=='wowsims' and valid() then
            local conversion=formats.lastImport
            local text=conversion and conversion.text
            if not text and formats.failure and formats.failure.report then
                text=self:RenderTransferFormatReport('wowsims',formats.failure.report,'import')
            end
            if text and not candidate then return self:ShowTransferReport(L['WowSims import report'],text) end
            if text then
                local object=candidate.kind=='envelope' and candidate.value or {body=candidate.value};local report=self.RotationData.DiffRotations({},object)
                for _,diagnostic in ipairs(candidate.validation.diagnostics) do report.diagnostics[#report.diagnostics+1]=diagnostic end
                return self:ShowTransferReport(L['WowSims import report'],text..'\n\n'..self:FormatRotationComparison(report))
            end
        end
        if not valid() or not candidate then return end;local object=candidate.kind=='envelope' and candidate.value or {body=candidate.value};local report=self.RotationData.DiffRotations({},object)
        for _,diagnostic in ipairs(candidate.validation.diagnostics) do report.diagnostics[#report.diagnostics+1]=diagnostic end;return self:ShowComparisonReport(self:FormatRotationComparison(report))
    end
    options.onClose=function() active=false;formats:Forget();session:Clear();if p.active and p.generation==generation then p:Release() end end
    dialog=self:ShowSettingsTextTransfer(p,L['Import/Export Rotation'],exported or '',function(_,settings)
        if not candidate then return false,L['Preview a pasted rotation before importing it.'] end
        local target=settings.mode=='replace' and reference or nil
        local generated,why,saved=self:ApplyRotationImport(session,candidate.token,spec,settings.name,target,expected,{scope=dialog.scope:GetChecked() and 'character' or 'class',specs=type(self.rotationListSpec)=='number' and self.rotationListSpec or nil})
        if not generated then return false,string.format(L['Could not import this rotation: %s'],why) end
        local workspace,problem=self:GetRotationEditWorkspace(spec,saved);if not workspace then return false,problem end
        self:ShowConfig('Rotations',{spec=spec,id=workspace.id});return true
    end,options)
    if not dialog.scope then
        dialog.classScope=self:CreateWorkbenchCheckBox(dialog.frame,L['Class'],210);dialog.classScope:SetPoint('TOPLEFT',12,-98)
        dialog.scope=self:CreateWorkbenchCheckBox(dialog.frame,L['This character'],268);dialog.scope:SetPoint('TOPLEFT',290,-98)
    end
    dialog.scope:SetChecked(false);dialog.scope:Show();dialog.classScope:Show()
    local function scopeState()
        if dialog.mode=='replace' then dialog.scope:SetChecked(reference and reference.address and reference.address.scope=='character');dialog.scope:Disable()
        elseif context and context.character then dialog.scope:Enable() else dialog.scope:SetChecked(false);dialog.scope:Disable() end
        dialog.classScope:SetChecked(not dialog.scope:GetChecked());if dialog.mode=='new' then dialog.classScope:Enable() else dialog.classScope:Disable() end
    end
    local destination=dialog.destination:GetScript('OnClick')
    self:SetUIScript(dialog.destination,'OnClick',function(...) if dialog.options==options then destination(...);if not valid() then return end;if dialog.mode=='new' then dialog.scope:SetChecked(false) end;scopeState();if p.importPreview then p.importPreview.frame:Hide() end;if p.importContent then p.importContent.frame:Hide() end end end)
    self:SetUIScript(dialog.scope,'OnClick',function() if valid() and dialog.options==options and dialog.mode=='new' and context.character then dialog.scope:SetChecked(true);scopeState() end end)
    self:SetUIScript(dialog.classScope,'OnClick',function() if valid() and dialog.options==options and dialog.mode=='new' then dialog.scope:SetChecked(false);scopeState() end end)
    dialog.scope.tooltip=L['Copies belong to your Class unless This character is selected. Replacement keeps its original owner.']
    -- The Format row sits under the scope row; the text box and the status line move down to make room.
    dialog.frame:SetHeight(470)
    dialog.scroll:ClearAllPoints();dialog.scroll:SetPoint('TOPLEFT',12,-190);dialog.scroll:SetHeight(188);dialog.input:SetHeight(188);scopeState()
    dialog.status:ClearAllPoints();dialog.status:SetPoint('TOPLEFT',12,-384)
    self:AttachTransferFormatControls(dialog,formats,options)
    if exportError and formats.format=='rm' then dialog.status:SetText(string.format(L['Export unavailable: %s'],exportError)) end
    return dialog
end
