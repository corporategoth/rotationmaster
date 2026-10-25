local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- Native launcher and specialization services.

function addon:CreatePreviewWindow() return self:CreateNativePreviewWindow() end

function addon:GetRotationEditorSpecs(classID)
    if classID==nil and type(UnitClass)=="function" then
        local ok,_,_,id=pcall(UnitClass,"player")
        if ok then classID=id end
    end
    local entries=self.Platform:GetRotationSpecializations(classID)
    if not entries then return {{id=0,name=L["Rotations"]}} end
    for _,entry in ipairs(entries) do
        if entry.id==0 then entry.name=L["Rotations"]
        elseif entry.initial then entry.name=L["No specialization"]
        elseif not entry.name then
            local label=self.db.char.specs[entry.id]
            entry.name=type(label)=="string" and label or tostring(entry.id)
        end
    end
    return entries
end

function addon:SetupOptions()
    if self.optionsConfigured then
        return
    end
    self.optionsConfigured = true

    self.settingsLauncher=self:CreateSettingsLauncher()
    self:RegisterOptionsCategory(self.settingsLauncher.frame)
end
