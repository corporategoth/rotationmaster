local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:ShowCustomConditionTransfer(parent,update,key,condition)
    local owner=parent.rmConditionOwner;if not owner then return end
    if parent.nativeCustomEditor and self.ShowConditionFunctionBundleTransfer and condition.bindings and next(condition.bindings) then return self:ShowConditionFunctionBundleTransfer(parent,update,key,condition) end
    local codec=self:NewRotationCodec();local text,why=codec:Encode({format='RM-CustomCondition',version=1,name=key or '',condition=condition})
    if not text then return nil,why end
    local p=parent.rmCustomTransferForm
    if p then p:Release() else local host=CreateFrame('Frame',nil,UIParent);host:SetSize(1,1);host:Hide();p=self:CreateSettingsForm(host);parent.rmCustomTransferForm=p end
    p:Open(function() end);parent:SetCallback('OnClose',function() end);if parent.HideForChild then parent:HideForChild() else parent:Hide() end
    local function valid() return addon:CanResumeCustomConditionDialog(parent,owner) end
    local dialog
    local options={canReplace=key~=nil and self.db.global.custom_conditions[key]~=nil,selectedName=key,fallbackName=L['IMPORTED_CONDITION'],valid=valid,
        originalName=function(input) local parsed=self:ParseCustomConditionImport(input,codec);return parsed and parsed.name end,
        onClose=function()
            if dialog then owner.widgets[dialog]=nil;dialog.rmConditionOwner=nil end
            if p.active then p:Release() end
            if valid() then if not parent.nativeCustomEditor then parent:SetCallback('OnClose',function(widget) LibStub('AceGUI-3.0'):Release(widget) end) end;parent:Show() end
        end}
    dialog=self:ShowSettingsTextTransfer(p,L['Import/Export Condition'],text,function(input,settings)
        local parsed,errorText=self:ParseCustomConditionImport(input,codec)
        if not parsed then
            if parent.nativeCustomEditor and self.ShowConditionFunctionBundleTransfer then
                local bundle=self:ParseFunctionBundleImport(input,codec)
                if bundle and bundle.root.kind=='condition' then dialog.frame:Hide();self:ShowConditionFunctionBundleTransfer(parent,update,key,condition,input);return false,L['Review the dependency bundle before applying it.'] end
            end
            return false,errorText
        end
        local destination=settings.mode=='replace' and key or settings.name
        if not self:IsCustomConditionIdentifier(destination,settings.mode=='replace') then return false,L['Use letters, numbers and underscores for the condition identifier.'] end
        if settings.mode=='new' and self:describeCondition(destination)~=nil then return false,L['That condition identifier already exists.'] end
        local serial=dialog.serial
        p:Confirm(L['This import contains Lua code. Only continue if you trust its author. Import opens the code for review; saving the condition can execute it.'],function()
            if not valid() or dialog.serial~=serial or dialog.input:GetText()~=input then return end
            self:LayoutCustomConditionEditor(parent,update,destination,parsed.condition);dialog.frame:Hide()
        end)
        p.prompt.frame:SetParent(UIParent);self:RegisterWindowForEscape(p.prompt)
        return false,L['Confirm the Lua import, then review it before saving.']
    end,options)
    function dialog:Hide() self.frame:Hide() end
    dialog.rmConditionOwner=owner;owner.widgets[dialog]=true;return dialog
end
