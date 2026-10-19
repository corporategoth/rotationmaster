local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Also called after import overlays: AceDB emits Reset/Copy before the
-- importer publishes its final roots, so its event alone cannot authorize them.
function addon:RefreshRotationProfileStorage()
    local ok,why=self:InitializeScopedRotationStorage()
    self.rotationStorageError=not ok and why or nil
    if self.InitializeRotationLibrary then self:InitializeRotationLibrary() end
    if not ok and self.warn then self:warn(L['Rotation data requires recovery: %s'],why) end
    return ok,why
end

function addon:RotationProfileChanged()
    if (self.rotationProfileChangeDepth or 0)>0 then return self:RefreshRotationProfileStorage() end
    if self.DisableRotation then self:DisableRotation() end
    self.manualRotation=false;self.autoswitchRotation={};self.longtermCache={}
    self.configRotationSelection=nil
    local ok,why=self:RefreshRotationProfileStorage()
    if self.RefreshConfiguration then self:RefreshConfiguration() end
    if ok and self.db.profile.enable and self.EnableRotation then self:EnableRotation() end
    return ok,why
end

function addon:InstallRotationProfileLifecycle()
    if self.rotationProfileLifecycleInstalled then return end
    self.rotationProfileLifecycleInstalled=true
    for _,event in ipairs({'OnProfileChanged','OnProfileCopied','OnProfileReset'}) do
        self.db.RegisterCallback(self,event,'RotationProfileChanged')
    end
end
