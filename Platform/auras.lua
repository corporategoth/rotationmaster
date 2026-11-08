-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for auras: C_UnitAuras (with the UnitAura global and LibClassicDurations as fallbacks on Era).
-- Owns the `value or nil, reason` readers that turn a native aura into one validated record and read fields and
-- remaining time from it; every field is checked on its own, so a secret or malformed field is marked unavailable in
-- record.unavailable instead of failing the record. It must not interpret an aura for a rotation. Needs
-- platform:GetClientFamily at load time. Loaded from RotationMaster.toc after Platform/spellbook.lua.
local _, addon = ...
local platform = addon.Platform
local isEra = platform:GetClientFamily() == "era"
local durationProvider, checkedDurations

-- The aura fields RM reads, with the Lua type each must have.
local fields = {
    name = "string",
    spellID = "number",
    applications = "number",
    dispelName = "string",
    duration = "number",
    expirationTime = "number",
    sourceUnit = "string",
    isStealable = "boolean",
}

-- Validates a native aura into a record that RM reads.
-- @param raw table|nil  The native aura record, or the tuple rebuilt into one.
-- @param owned boolean  True when raw is a fresh table nobody else holds (a native record or our own tuple).
-- @return table|nil  The validated record; nil for no aura (raw was nil) or when raw itself is unusable.
-- @return string|nil  The reason code when raw itself is unusable; nil otherwise.
--
-- On builds without secrets an owned raw is normalized in place instead of copied; invalid fields are still cleared
-- and marked unavailable in record.unavailable, which exists only when a field is unavailable.
local function normalize(raw, owned)
    if not platform:CanReadValue(raw) then
        return nil, "restricted-value"
    end
    if raw == nil then
        return nil
    end
    if type(raw) ~= "table" then
        return nil, "invalid-api-result"
    end

    -- The unavailable map exists only when a field is unavailable.
    local result = owned and platform.secretsUnrestricted and raw or {}

    -- Records why one field has no value.
    -- @param key string  The aura field name.
    -- @param reason string  The reason code stored in result.unavailable.
    local function unavailable(key, reason)
        result.unavailable = result.unavailable or {}
        result.unavailable[key] = reason
    end

    for key, kind in pairs(fields) do
        local value = raw[key == "spellID" and "spellId" or key]

        if not platform:CanReadValue(value) then
            result[key] = nil
            unavailable(key, "restricted-value")
        elseif value ~= nil and type(value) ~= kind then
            result[key] = nil
            unavailable(key, "invalid-api-result")
        elseif
            type(value) == "number" and (value ~= value or value == math.huge or value == -math.huge or value < 0)
        then
            result[key] = nil
            unavailable(key, "invalid-api-result")
        else
            result[key] = value
        end
    end

    if result.name == nil and not (result.unavailable and result.unavailable.name) then
        unavailable("name", "invalid-api-result")
    end

    return result
end

-- Reads one aura of a unit by position.
-- @param self table  The platform table.
-- @param unit string  The unit token to read; must be a non-empty string.
-- @param index number  The aura position, an integer from 1 to 256.
-- @param filter string  "HELPFUL", "HARMFUL" or "HARMFUL|RAID".
-- @return table|nil  The validated aura; nil when there is no such aura or it cannot be read.
-- @return string|nil  The reason code when the first return is nil because of a failure; nil otherwise.
--
-- Never retains the native record. On Era, LibClassicDurations (when present) supplies otherwise unavailable timer
-- estimates; it stays optional and never substitutes for a restricted native result.
local function readAuraByIndex(self, unit, index, filter)
    if not self:CanReadValue(unit) or not self:CanReadValue(index) or not self:CanReadValue(filter) then
        return nil, "restricted-value"
    end
    if
        type(unit) ~= "string"
        or unit == ""
        or type(index) ~= "number"
        or index < 1
        or index > 256
        or index % 1 ~= 0
        or (filter ~= "HELPFUL" and filter ~= "HARMFUL" and filter ~= "HARMFUL|RAID")
    then
        return nil, "invalid-aura-query"
    end

    local legacy

    -- ClassicDurations supplies otherwise unavailable Era timer estimates.
    -- It stays optional and never substitutes for a restricted native result.
    -- It wraps the UnitAura global, which Era provides only while
    -- loadDeprecationFallbacks is on; without it C_UnitAuras is read directly.
    if
        isEra
        and not checkedDurations
        and type(UnitAura) == "function"
        and (type(LibStub) == "table" or type(LibStub) == "function")
    then
        checkedDurations = true
        local ok, lib = pcall(LibStub, "LibClassicDurations", true)

        if ok and type(lib) == "table" and type(lib.UnitAuraDirect) == "function" then
            durationProvider = lib.UnitAuraDirect
        end
    end

    legacy = durationProvider

    if not legacy and C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
        local ok, raw = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)

        if not ok then
            self.lastAuraError = tostring(raw)
            return nil, "api-error"
        end

        return normalize(raw, true)
    end

    legacy = legacy or UnitAura

    if type(legacy) ~= "function" then
        return nil, "missing-api"
    end

    local ok, name, _, count, dispel, duration, expiration, source, stealable, _, id = pcall(
        legacy,
        unit,
        index,
        filter
    )

    if not ok then
        self.lastAuraError = tostring(name)
        return nil, "api-error"
    end

    if not self:CanReadValue(name) then
        return nil, "restricted-value"
    end
    if name == nil then
        return nil
    end

    if self:CanReadValue(stealable) and stealable == nil then
        stealable = false
    end

    return normalize({
        name = name,
        applications = count,
        dispelName = dispel,
        duration = duration,
        expirationTime = expiration,
        sourceUnit = source,
        spellId = id,
        isStealable = stealable,
    }, true)
end

-- Your own auras last read readably, by spell id: { expires, stacks, duration }, for "Remember hidden buffs and
-- cooldowns" (profile.remember_hidden). Learned on every readable read of the player's auras; your own cast of the
-- spell restarts it from the learned duration (NoteAuraCast).
local auraMemory = {}

-- Reads the aura at an index of a unit's aura list, learning your own auras for the memory above.
-- @param unit string  The unit token to read; must be a non-empty string.
-- @param index number  The 1-based position in the filtered list.
-- @param filter string|nil  The aura filter.
-- @return table|nil  The validated aura; nil at the end of the list or when it cannot be read.
-- @return string|nil  The reason code when the read failed; nil otherwise.
function platform:GetAuraByIndex(unit, index, filter)
    local aura, reason = readAuraByIndex(self, unit, index, filter)

    if aura and unit == "player" and not aura.unavailable then
        local spell, expires = aura.spellID, aura.expirationTime

        if type(spell) == "number" and type(expires) == "number" then
            auraMemory[spell] = { expires = expires, stacks = aura.applications, duration = aura.duration }
        end
    end

    return aura, reason
end

-- Notes your own successful cast, restarting a remembered aura of that spell from its learned duration.
-- @param spell any  The cast spell id; a hidden id is ignored.
-- @param now number  The time of the cast.
function platform:NoteAuraCast(spell, now)
    if not self:CanReadValue(spell) or type(spell) ~= "number" then
        return
    end

    local memory = auraMemory[spell]

    if memory and type(memory.duration) == "number" and memory.duration > 0 then
        memory.expires = now + memory.duration
    end
end

-- Reads a remembered aura of yours.
-- @param spell number  The spell id.
-- @return table|nil  { expires, stacks, duration }; nil when it was never read.
function platform:GetRememberedAura(spell)
    return auraMemory[spell]
end

-- Finds the first aura with a spell name that a filter admits.
-- @param unit string  The unit token to read; must be a non-empty string.
-- @param name string  The spell name to look up; must be a non-empty string.
-- @param filter string  The aura filter string.
-- @return table|nil  The validated aura; nil when there is none or it cannot be read.
-- @return string|nil  The reason code when the first return is nil because of a failure; nil otherwise.
function platform:GetAuraBySpellName(unit, name, filter)
    local lookup = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName

    if type(lookup) ~= "function" then
        return nil, "missing-api"
    end
    if type(unit) ~= "string" or unit == "" or type(name) ~= "string" or name == "" or type(filter) ~= "string" then
        return nil, "invalid-aura-query"
    end

    local ok, raw = pcall(lookup, unit, name, filter)

    if not ok then
        self.lastAuraError = tostring(raw)
        return nil, "api-error"
    end

    return normalize(raw, true)
end

-- Reads one of the player's own buffs by spell ID.
-- @param spellID number  The spell ID of the aura to find.
-- @return table|nil  The validated aura; nil when the player has no such aura or it cannot be read.
-- @return string|nil  The reason code when the first return is nil because of a failure; nil otherwise.
--
-- On a restricted client the game refuses to walk the player's auras in combat to addon code (it raises "Auras cannot
-- be accessed when secret while tainted"), so a lookup by spell ID is tried first: it names the one aura wanted and may
-- be answered where the walk is not. The error text of a refusal is kept in platform.lastAuraError for the glow report.
function platform:GetPlayerAuraBySpellID(spellID)
    local lookup = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

    if type(lookup) ~= "function" then
        return nil, "missing-api"
    end
    if not self:CanReadValue(spellID) or type(spellID) ~= "number" or spellID <= 0 or spellID % 1 ~= 0 then
        return nil, "invalid-aura-query"
    end

    local ok, raw = pcall(lookup, spellID)

    if not ok then
        self.lastAuraError = tostring(raw)
        return nil, "api-error"
    end

    return normalize(raw, true)
end

-- Whether the game hides aura data from addons right now (C_Secrets.ShouldAurasBeSecret, on the restricted policy only).
-- Forever was seen handing back an empty player aura list in combat (Glowing Bars' notes), so an empty list read while
-- this is true proves nothing.
-- @return boolean  True while auras are hidden, or when the answer cannot be read; false without the API or off the
--   restricted policy.
function platform:AreAurasHidden()
    if self:GetCombatDataPolicy() ~= "restricted" then
        return false
    end

    local secrets = C_Secrets

    if type(secrets) ~= "table" or type(secrets.ShouldAurasBeSecret) ~= "function" then
        return false
    end

    local ok, hidden = pcall(secrets.ShouldAurasBeSecret)

    if not ok or not self:CanReadValue(hidden) then
        return true
    end

    return hidden == true
end

-- Reads one field of a validated aura.
-- @param aura table  An aura record from GetAuraByIndex or GetAuraBySpellName.
-- @param field string  The field name, one of those RM reads (name, spellID, applications, dispelName, duration,
--   expirationTime, sourceUnit, isStealable).
-- @return any|nil  The field value; nil when it is absent or unavailable.
-- @return string|nil  The reason that field is unavailable, or "invalid-aura-field"; nil otherwise.
function platform:ReadAuraField(aura, field)
    if not fields[field] or type(aura) ~= "table" then
        return nil, "invalid-aura-field"
    end
    if aura.unavailable and aura.unavailable[field] then
        return nil, aura.unavailable[field]
    end

    return aura[field]
end

-- Computes the seconds left on an aura.
-- @param aura table  An aura record from GetAuraByIndex or GetAuraBySpellName.
-- @param now number  The current time, a GetTime value.
-- @return number|nil  The seconds left (never negative); math.huge for an aura with no duration; nil when its
--   expiration cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:AuraRemaining(aura, now)
    local expiration, reason = self:ReadAuraField(aura, "expirationTime")

    if reason then
        return nil, reason
    end
    if expiration == nil then
        return nil, "aura-time-unavailable"
    end
    if not self:CanReadValue(now) then
        return nil, "restricted-value"
    end
    if type(now) ~= "number" or now ~= now or now == math.huge or now == -math.huge then
        return nil, "invalid-time"
    end

    if expiration == 0 then
        local duration, why = self:ReadAuraField(aura, "duration")

        if why then
            return nil, why
        end
        if duration == 0 then
            return math.huge
        end

        return nil, "aura-time-unavailable"
    end

    return math.max(0, expiration - now)
end
