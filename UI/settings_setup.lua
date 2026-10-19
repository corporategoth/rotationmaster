local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- Native launcher and specialization services, plus the preserved metadata
-- bridge for optional module/legacy configuration consumers.
local AceConfig=LibStub('AceConfig-3.0')
local AceDBOptions=LibStub('AceDBOptions-3.0')
local AboutPanel=LibStub('LibAboutPanel-2.0')

function addon:CreatePreviewWindow() return self:CreateNativePreviewWindow() end

-- Optional modules keep their registered AceConfig application. Built-in
-- pages are owned by native settings builders and never enter this bridge.
function addon:BuildModuleConfigurationPane(frame,section)
    local name=type(section)=='string' and section:match('^module:(.+)$')
    local application=name and self.configModuleApps and self.configModuleApps[name]
    if not application then return false end
    LibStub('AceConfigDialog-3.0'):Open(application,frame)
    return true
end

function addon:GetRotationEditorSpecs(classID)
    if classID==nil and type(UnitClass)=="function" then
        local ok,_,_,id=pcall(UnitClass,"player")
        if ok then classID=id end
    end
    local entries=self.Platform:GetRotationSpecializations(classID)
    if not entries then return {{id=0,name=L["Rotations"]}} end
    for _,entry in ipairs(entries) do
        if entry.id==0 then entry.name=L["Rotations"]
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
    self.configModuleApps = {}
    for _,module in addon:IterateModules() do
        if module.SetupOptions then
            module:SetupOptions(function(appName,name) self.configModuleApps[name]=appName end)
        end
    end

    local options = AceDBOptions:GetOptionsTable(self.db)
    local prev_setprofile = options.handler.SetProfile
    options.handler["SetProfile"] = function(obj, info, value)
        addon:DisableRotation()
        prev_setprofile(obj, info, value)
        addon:RefreshConfiguration()
        addon:EnableRotation()
    end
    AceConfig:RegisterOptionsTable(addon.name .. "Profiles", options)

    local about = AboutPanel:AboutOptionsTable(addon.name)
    about.order = -1
    AceConfig:RegisterOptionsTable(addon.name .. "About", about)
end
