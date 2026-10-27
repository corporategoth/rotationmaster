-- Assisted highlight manager: owns the one character CVar that turns Blizzard's Assisted Highlight on, so it is on only
-- while the active rotation has a "Blizzard's suggestion" step, and always restored. The design is described below.
-- It must not run per poll and never touches the CVar in combat. Loaded late in the TOC (after
-- Core/unit_state_conditions.lua) and driven by its own event frame, AceDB profile callbacks and the
-- ROTATIONMASTER_ROTATION message. Retail only.

local _, addon = ...

-- Who highlights a "Blizzard's suggestion" step: Rotation Master's own glow,
-- Blizzard's Assisted Highlight, or both (profile.assisted_highlight =
-- "rm" | "blizzard" | "both", default "rm").
--
-- Blizzard's highlight is one character CVar, assistedCombatHighlight, read
-- by Blizzard's AssistedCombatManager (Retail only; see
-- Platform/assisted_combat.lua). It cannot follow single steps: it is either
-- on, highlighting Blizzard's suggestion all the time, or off. So it is
-- turned on while the active rotation has a "Blizzard's suggestion" step and
-- the mode is not "rm", and RM's own glow steps aside for that step only in
-- "blizzard" mode.
--
-- The user's setting is never left changed:
--   * the CVar is written only outside combat (a change wanted in combat
--     waits for PLAYER_REGEN_ENABLED), and only when it is off: a user who
--     already has it on is never touched;
--   * before writing, the previous value is saved per character
--     (db.char.assistedHighlight = {previous, applied}), so a crash or a
--     reload in combat restores it at the next login;
--   * it is put back when the rotation no longer wants it, RM is disabled,
--     the mode changes, or at logout/reload (where the record is kept, marked
--     restoredAtLogout, until the next login confirms the write stuck);
--   * if the user changes it meanwhile, their value wins: the record is
--     dropped and RM stops managing it until the mode is chosen again.
-- Cost: nothing per poll. The engines read one boolean field
-- (addon.assistedGlowHidden) only for an assisted step.

-- ============================================================================
-- State and helpers
-- ============================================================================

local CVAR_ON = '1'
local MODES = { rm = true, blizzard = true, both = true }
local manager = { ready = false, userOverride = false, applying = false, loggingOut = false, pending = false }
addon.AssistedHighlight = manager
addon.assistedGlowHidden = false

-- Returns the active profile table, or nil before the database exists.
local function profile()
    local db = addon.db
    return type(db) == 'table' and type(db.profile) == 'table' and db.profile or nil
end

-- Returns the per-character saved table (where the restore record lives), or nil before the database exists.
local function characterStore()
    local db = addon.db
    return type(db) == 'table' and type(db.char) == 'table' and db.char or nil
end

-- True in combat lockdown. An unreadable or unknown answer counts as combat, because the CVar must not be written then.
local function inCombat()
    if type(InCombatLockdown) ~= 'function' then return false end
    local ok, locked = pcall(InCombatLockdown)
    return not ok or (locked ~= false and locked ~= nil)
end

-- Returns the configured mode, 'rm', 'blizzard' or 'both'; anything else (unset or corrupt) reads as 'rm'.
function addon:GetAssistedHighlightMode(settings)
    local source = settings or profile()
    local mode = type(source) == 'table' and source.assisted_highlight or nil
    if MODES[mode] then return mode end
    return 'rm'
end

-- true, or nil plus a reason when this client has no Blizzard highlight.
function addon:GetAssistedHighlightSupport()
    local platform = self.Platform

    if type(platform) ~= 'table' or type(platform.GetAssistedHighlightSupport) ~= 'function' then
        return nil, 'missing-api'
    end

    return platform:GetAssistedHighlightSupport()
end

-- Whether the active rotation has an enabled, reachable "Blizzard's
-- suggestion" step in its rotation list. Every lookup is guarded, so a missing service reads as false.
local function rotationUsesAssisted(self)
    local id, spec = self.currentRotation, self.currentSpec
    if id == nil or spec == nil or type(self.GetRotationForCleanup) ~= 'function' then return false end
    local ok, rotation = pcall(self.GetRotationForCleanup, self, spec, id)
    if not ok or type(rotation) ~= 'table' then return false end
    local data = self.RotationData
    if type(data) ~= 'table' or type(data.IndexRotationSteps) ~= 'function' then return false end
    local indexed, index = pcall(data.IndexRotationSteps, rotation, { allowMissingIds = true })
    if not indexed or type(index) ~= 'table' or type(index.rows) ~= 'table' then return false end

    for _, row in ipairs(index.rows) do
        local step = row.step

        if
            row.section == 'rotation'
            and not row.unreachable
            and type(step) == 'table'
            and step.type == 'assisted'
            and not step.disabled
        then
            return true
        end
    end

    return false
end

-- True when the CVar should be on now: a mode that uses Blizzard's highlight, a client that supports it, and an active
-- rotation that has an assisted step.
local function wanted(self)
    if self:GetAssistedHighlightMode() == 'rm' or self.currentRotation == nil then return false end
    if not self:GetAssistedHighlightSupport() then return false end
    if self.Platform:GetAssistedCombatAvailability() ~= true then return false end
    return rotationUsesAssisted(self)
end

-- True for a well-formed restore record { previous, applied }; a corrupt saved record is dropped by the caller.
local function validRecord(record)
    return type(record) == 'table' and type(record.previous) == 'string' and type(record.applied) == 'string'
end

-- Writes the CVar through the Platform adapter. The applying flag makes the resulting CVAR_UPDATE event ignore our own
-- write. Returns the value now in effect, or nil and a reason.
local function write(value)
    manager.applying = true
    local ok, now, why = pcall(addon.Platform.SetAssistedHighlightCVar, addon.Platform, value)
    manager.applying = false
    if not ok then return nil, 'api-error' end
    return now, why
end

-- ============================================================================
-- Reconciliation
-- ============================================================================

-- Brings the CVar and addon.assistedGlowHidden in line with what the rotation wants. Called on every relevant event,
-- not per poll. In combat it only marks the work pending; PLAYER_REGEN_ENABLED finishes it.
function manager:Reconcile()
    if not self.ready or self.loggingOut or self.applying then return end
    local platform = addon.Platform

    if type(platform) ~= 'table' or type(platform.GetAssistedHighlightCVar) ~= 'function' then
        addon.assistedGlowHidden = false
        return
    end

    local want = wanted(addon)
    local current = platform:GetAssistedHighlightCVar()
    local store = characterStore()

    if not inCombat() and store then
        self.pending = false
        local record = store.assistedHighlight

        if record ~= nil and not validRecord(record) then
            store.assistedHighlight = nil
            record = nil
        end

        if record and current ~= nil then
            if record.restoredAtLogout then
                -- The logout restore either stuck (current is the user's
                -- value again) or did not (still ours), else the user changed it.
                record.restoredAtLogout = nil

                if current == record.previous then
                    store.assistedHighlight = nil
                    record = nil
                elseif current ~= record.applied then
                    store.assistedHighlight = nil
                    record = nil
                    self.userOverride = true
                end
            elseif current ~= record.applied then
                store.assistedHighlight = nil
                record = nil
                self.userOverride = true
            end
        end

        if want and not self.userOverride then
            if not record and current ~= nil and current ~= CVAR_ON then
                -- Saved before the write, so the restore survives a crash.
                store.assistedHighlight = { previous = current, applied = CVAR_ON }
                local now = write(CVAR_ON)

                if now ~= CVAR_ON then
                    -- Not in effect: there is nothing of ours to put back
                    -- unless the client reports something else entirely.
                    if now == nil or now == current then store.assistedHighlight = nil end
                end

                current = now or current
            end
        elseif record then
            local now = write(record.previous)
            if now == record.previous then store.assistedHighlight = nil end
            current = now or current
        end
    elseif want or (store and store.assistedHighlight ~= nil) then
        self.pending = true
    end

    addon.assistedGlowHidden = want and addon:GetAssistedHighlightMode() == 'blizzard' and current == CVAR_ON or false
end

-- At logout or reload: put the user's value back now, keeping the record
-- (marked) until the next login sees it stuck. In combat the record alone
-- restores it at the next login.
function manager:Logout()
    self.loggingOut = true
    local store = characterStore()
    local record = store and store.assistedHighlight
    if not validRecord(record) or inCombat() then return end
    local current = addon.Platform:GetAssistedHighlightCVar()

    if current ~= record.applied then
        store.assistedHighlight = nil
        return
    end

    local now = write(record.previous)
    if now == record.previous then record.restoredAtLogout = true end
end

-- A mode chosen in settings also ends a user override from this session.
-- Public entry for settings changes and rotation switches; clearOverride is true when the user picked a mode.
function addon:RefreshAssistedHighlight(clearOverride)
    if clearOverride then manager.userOverride = false end
    manager:Reconcile()
end

-- ============================================================================
-- Events
-- ============================================================================

local profileEvents = { 'OnProfileChanged', 'OnProfileCopied', 'OnProfileReset' }

-- Single event handler for the frame events, the AceDB profile callbacks and the rotation message. The first
-- PLAYER_ENTERING_WORLD marks the manager ready and registers the profile callbacks; nothing reconciles before that.
function manager:OnEvent(event, ...)
    if event == 'PLAYER_LOGOUT' then return self:Logout() end

    if event == 'PLAYER_ENTERING_WORLD' then
        if not self.ready then
            self.ready = true
            local db = addon.db

            if type(db) == 'table' and type(db.RegisterCallback) == 'function' then
                for _, name in ipairs(profileEvents) do
                    db.RegisterCallback(manager, name, function() manager:Reconcile() end)
                end
            end
        end

        return self:Reconcile()
    end

    if event == 'CVAR_UPDATE' then
        if self.applying then return end
        local name = ...
        local platform = addon.Platform
        local cvar = type(platform) == 'table' and platform.ASSISTED_HIGHLIGHT_CVAR or 'assistedCombatHighlight'
        if type(name) == 'string' and name:lower() ~= cvar:lower() then return end
        return self:Reconcile()
    end

    if event == 'PLAYER_REGEN_ENABLED' or event == 'ROTATIONMASTER_ROTATION' then return self:Reconcile() end
end

if type(CreateFrame) == 'function' then
    local ok, frame = pcall(CreateFrame, 'Frame')

    if
        ok
        and type(frame) == 'table'
        and type(frame.RegisterEvent) == 'function'
        and type(frame.SetScript) == 'function'
    then
        manager.frame = frame
        frame:SetScript('OnEvent', function(_, event, ...) manager:OnEvent(event, ...) end)

        for _, event in ipairs({ 'PLAYER_ENTERING_WORLD', 'PLAYER_REGEN_ENABLED', 'PLAYER_LOGOUT', 'CVAR_UPDATE' }) do
            pcall(frame.RegisterEvent, frame, event)
        end
    end
end

do
    local ok, events = pcall(LibStub, 'AceEvent-3.0', true)

    if ok and type(events) == 'table' and type(events.RegisterMessage) == 'function' then
        events.RegisterMessage(manager, 'ROTATIONMASTER_ROTATION', function(message) manager:OnEvent(message) end)
    end
end
