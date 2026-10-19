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
    local db=self.db
    local previous=self.rotationProfileLifecycleDB
    local previousOwner=self.rotationProfileLifecycleOwner
    if self.rotationProfileLifecycleInstalled and previous==db and previousOwner then return end
    -- Retire authority before removing callbacks. A callback already captured
    -- by a dispatch must not apply the old database's event to a new active DB.
    self.rotationProfileLifecycleDB=nil
    self.rotationProfileLifecycleOwner=nil
    if previous and previousOwner then
        for _,event in ipairs({'OnProfileChanged','OnProfileCopied','OnProfileReset'}) do
            previous.UnregisterCallback(previousOwner,event)
        end
    end
    -- The addon itself already owns the init reset seeder on this registry.
    -- Give lifecycle callbacks a distinct binding owner so both can coexist.
    local owner={}
    local function changed(...)
        if self.db~=db or self.rotationProfileLifecycleDB~=db or self.rotationProfileLifecycleOwner~=owner then return end
        return self:RotationProfileChanged(...)
    end
    for _,event in ipairs({'OnProfileChanged','OnProfileCopied','OnProfileReset'}) do
        db.RegisterCallback(owner,event,changed)
    end
    self.rotationProfileLifecycleDB=db
    self.rotationProfileLifecycleOwner=owner
    self.rotationProfileLifecycleInstalled=true
end
