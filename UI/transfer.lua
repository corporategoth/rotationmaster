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
    p.cleanups[#p.cleanups+1]=function() if d.serial==serial then d.frame:Hide() end end;d.frame:Show();self:RegisterWindowForEscape(d);return d
end
function addon:ShowRotationTransfer(spec,id)
    local codec=self:NewRotationCodec();local session=self.RotationData.NewImportSession(codec,self:GetImportValidationOptions())
    local source,exportError=self:GetRotationExportData(spec,id);local exported;if source then exported,exportError=codec:Encode(source) end
    local p=self.rotationTransferForm
    if p then p:Release() else local host=CreateFrame('Frame',nil,UIParent);host:SetSize(1,1);host:Hide();p=self:CreateSettingsForm(host);self.rotationTransferForm=p end
    p:Open(function() end)
    local original=self:GetEditableRotation(spec,id);local expected={profile=self.db.profile,target=original,body=original and self.RotationData.CopyData(original)}
    local canReplace=original~=nil and not self:GetDefaultIdForRuntime(spec,id);local candidate
    local options={canReplace=canReplace,selectedName=original and original.name or source and (source.body and source.body.name or source.nameKey or source.name),fallbackName=L['Imported rotation'],requirePreview=true}
    options.originalName=function(text) local decoded=codec:Decode(text);local value=decoded and decoded.value;if type(value)=='table' then return value.body and value.body.name or value.nameKey or value.name end end
    options.invalidate=function(d) candidate=nil;session:Clear();d.apply:Disable();d.inspect:Disable();d.status:SetText(L['Text changed. Preview again before importing.']);if p.importPreview then p.importPreview.frame:Hide() end end
    options.preview=function(d)
        local why;candidate,why=session:Stage(d.input:GetText());d.apply:Disable();d.inspect:Disable()
        if not candidate then d.status:SetText(string.format(L['Import preview unavailable: %s'],why));return end
        d.inspect:Enable();local ready,reason=session:GetReady(candidate.token)
        d.status:SetText(ready and L['Ready to import. Choose replacement or a named copy.'] or string.format(L['This import cannot be applied: %s'],reason));if ready then d.apply:Enable() end
        local own=original or source and (source.body or source) or {rotation={},cooldowns={}};local view=session:Compare(candidate.token,own,self.RotationData.GetRotationTags(source));if view then self:ShowNativeImportPreview(p,view,spec) end
    end
    options.inspect=function()
        if not candidate then return end;local object=candidate.kind=='envelope' and candidate.value or {body=candidate.value};local report=self.RotationData.DiffRotations({},object)
        for _,diagnostic in ipairs(candidate.validation.diagnostics) do report.diagnostics[#report.diagnostics+1]=diagnostic end;return self:ShowComparisonReport(self:FormatRotationComparison(report))
    end
    options.onClose=function() session:Clear();if p.active then p:Release() end end
    local dialog=self:ShowSettingsTextTransfer(p,L['Import/Export Rotation'],exported or '',function(_,settings)
        if not candidate then return false,L['Preview a pasted rotation before importing it.'] end
        local target=settings.mode=='replace' and id or nil
        local generated,why=self:ApplyRotationImport(session,candidate.token,spec,settings.name,target,expected)
        if not generated then return false,string.format(L['Could not import this rotation: %s'],why) end
        self:ShowConfig('Rotations',{spec=spec,id=generated});return true
    end,options)
    if exportError then dialog.status:SetText(string.format(L['Export unavailable: %s'],exportError)) end
    return dialog
end
