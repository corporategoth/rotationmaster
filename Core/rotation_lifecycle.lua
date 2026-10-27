-- Rotation profile lifecycle: reacts to AceDB profile change, copy and reset by retiring the active rotation,
-- rebuilding the scoped rotation storage and library, and re-enabling the engine. It owns the guard that drops events
-- from a replaced database, and must re-check the active transition after every step that can call out. Loaded after
-- Core/group_unit_resolution.lua; installed by main.lua once self.db exists. Every optional collaborator is read at
-- call time because several of them load later.

local addon_name, addon = ...
local activeCurrent = addon.IsActiveRotationTransitionCurrent
local beginActive = addon.BeginActiveRotationTransition
local retireActive = addon.RetireActiveRotationTransition
local invalidateDependencies = addon.InvalidateRotationDependencies
if type(invalidateDependencies) ~= 'function' then invalidateDependencies = nil end
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Also called after import overlays: AceDB emits Reset/Copy before the
-- importer publishes its final roots, so its event alone cannot authorize them.
-- Re-syncs integrations, notifies dependency freshness and rebuilds scoped storage and the library. Returns true, or
-- nil and the recovery reason (also kept in rotationStorageError).
function addon:RefreshRotationProfileStorage()
    if self.SyncQuestieIntegration then self:SyncQuestieIntegration() end
    if self.SyncEncounterIntegration then self:SyncEncounterIntegration() end
    if invalidateDependencies then invalidateDependencies(addon, 'all', nil) end
    local ok, why = self:InitializeScopedRotationStorage()
    self.rotationStorageError = not ok and why or nil
    if self.InitializeRotationLibrary then self:InitializeRotationLibrary() end
    if self.RefreshEvaluationProfilerPolicy then self:RefreshEvaluationProfilerPolicy() end
    if not ok and self.warn then self:warn(L['Rotation data requires recovery: %s'], why) end
    return ok, why
end

-- Handles a profile change, copy or reset. Returns true, or nil and a reason ('rotation-transition-superseded' when a
-- newer switch took over mid-way). The method reads are repeated after each step on purpose: any of them can run
-- foreign code that starts a newer transition, and the check must catch that before the next step.
function addon:RotationProfileChanged()
    local change = beginActive(self)
    if not activeCurrent(self, change) then return nil, 'rotation-transition-superseded' end

    if (self.rotationProfileChangeDepth or 0) > 0 then
        if not retireActive(self, change) or not activeCurrent(self, change) then
            return nil, 'rotation-transition-superseded'
        end

        local refresh = self.RefreshRotationProfileStorage
        if not activeCurrent(self, change) then return nil, 'rotation-transition-superseded' end
        return refresh(self)
    end

    local available = self.DisableRotation
    if not activeCurrent(self, change) then return nil, 'rotation-transition-superseded' end

    if available then
        local disable = self.DisableRotation
        if not activeCurrent(self, change) then return nil, 'rotation-transition-superseded' end
        local _, nextChange, stopped = disable(self)
        if stopped == false then return nil, 'rotation-transition-superseded' end
        change = nextChange or change
        if not activeCurrent(self, change) then return nil, 'rotation-transition-superseded' end
    elseif not retireActive(self, change) or not activeCurrent(self, change) then
        return nil, 'rotation-transition-superseded'
    end

    self.manualRotation = false
    self.autoswitchRotation = {}
    self.longtermCache = {}
    self.configRotationSelection = nil
    local refresh = self.RefreshRotationProfileStorage
    if not activeCurrent(self, change) then return nil, 'rotation-transition-superseded' end
    local ok, why = refresh(self)
    if not activeCurrent(self, change) then return nil, 'rotation-transition-superseded' end
    local configure = self.RefreshConfiguration
    if not activeCurrent(self, change) then return nil, 'rotation-transition-superseded' end

    if configure then
        configure = self.RefreshConfiguration
        if not activeCurrent(self, change) then return nil, 'rotation-transition-superseded' end
        configure(self)
    end

    if not activeCurrent(self, change) then return nil, 'rotation-transition-superseded' end

    if ok and self.db.profile.enable and self.EnableRotation then
        local enable = self.EnableRotation
        if not activeCurrent(self, change) then return nil, 'rotation-transition-superseded' end
        enable(self)
    end

    return ok, why
end

-- Registers the profile callbacks on the current AceDB, replacing a previous registration. Safe to call repeatedly.
function addon:InstallRotationProfileLifecycle()
    local db = self.db
    local previous = self.rotationProfileLifecycleDB
    local previousOwner = self.rotationProfileLifecycleOwner
    if self.rotationProfileLifecycleInstalled and previous == db and previousOwner then return end
    -- Retire authority before removing callbacks. A callback already captured
    -- by a dispatch must not apply the old database's event to a new active DB.
    self.rotationProfileLifecycleDB = nil
    self.rotationProfileLifecycleOwner = nil

    if previous and previousOwner then
        for _, event in ipairs({ 'OnProfileChanged', 'OnProfileCopied', 'OnProfileReset' }) do
            previous.UnregisterCallback(previousOwner, event)
        end
    end

    -- The addon itself already owns the init reset seeder on this registry.
    -- Give lifecycle callbacks a distinct binding owner so both can coexist.
    local owner = {}

    -- Ignores an event delivered to a callback that belongs to a database or owner that has since been replaced.
    local function changed(...)
        if self.db ~= db or self.rotationProfileLifecycleDB ~= db or self.rotationProfileLifecycleOwner ~= owner then
            return
        end

        return self:RotationProfileChanged(...)
    end

    for _, event in ipairs({ 'OnProfileChanged', 'OnProfileCopied', 'OnProfileReset' }) do
        db.RegisterCallback(owner, event, changed)
    end

    self.rotationProfileLifecycleDB = db
    self.rotationProfileLifecycleOwner = owner
    self.rotationProfileLifecycleInstalled = true
end
