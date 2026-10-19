local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- Native launcher and specialization services, plus the preserved metadata
-- bridge for optional module/legacy configuration consumers.

local function pack(...) return {n=select('#',...),...} end

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

    -- AceConfigRegistry supports function providers. Native pages never query
    -- these legacy tables, so their metadata libraries are needed only when a
    -- legacy consumer explicitly requests the corresponding application.
    local AceConfig=LibStub('AceConfig-3.0')
    local profileOptions={}
    local function ensureProfileLifecycle(db)
        if self.db==db and self.rotationProfileLifecycleInstalled
            and (self.rotationProfileLifecycleDB~=db or not self.rotationProfileLifecycleOwner)
            and self.InstallRotationProfileLifecycle then
            self:InstallRotationProfileLifecycle()
        end
    end
    AceConfig:RegisterOptionsTable(self.name..'Profiles',function()
        local db=self.db
        ensureProfileLifecycle(db)
        local options=profileOptions[db]
        if options then return options end
        options=LibStub('AceDBOptions-3.0'):GetOptionsTable(db)
        local previous=options.handler.SetProfile
        options.handler.SetProfile=function(obj,...)
            -- An issued table still belongs to its original DB. It may act on
            -- that DB, but cannot refresh or enable the current addon's DB.
            if self.db~=db then return previous(obj,...) end
            ensureProfileLifecycle(db)
            -- The actual installed callbacks own the transition. This is a
            -- dispatch-time check because installation may follow first query.
            if self.rotationProfileLifecycleInstalled and self.rotationProfileLifecycleDB==db
                and self.rotationProfileLifecycleOwner then return previous(obj,...) end
            self:DisableRotation()
            local result=pack(previous(obj,...))
            self:RefreshConfiguration()
            self:EnableRotation()
            return unpack(result,1,result.n)
        end
        profileOptions[db]=options
        return options
    end)

    local about
    local application=self.name
    AceConfig:RegisterOptionsTable(self.name..'About',function()
        if not about then
            local options=LibStub('LibAboutPanel-2.0'):AboutOptionsTable(application)
            options.order=-1
            about=options
        end
        return about
    end)
end
