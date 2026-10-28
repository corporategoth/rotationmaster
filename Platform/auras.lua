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

-- owned: raw is a fresh table nobody else holds (a native record or our own
-- tuple). On builds without secrets it is normalized in place instead of
-- copied; invalid fields are still cleared and marked unavailable.
-- Returns the validated record, nil for no aura, or nil and a reason code when raw itself is unusable.
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

-- Returns the validated aura at index (1 to 256) of a unit for filter "HELPFUL", "HARMFUL" or "HARMFUL|RAID", nil
-- when there is no such aura, or nil and a reason code. Never retains the native record.
function platform:GetAuraByIndex(unit, index, filter)
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

-- The first aura with this spell name that the filter admits, or nil.
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
        return nil, "api-error"
    end

    return normalize(raw, true)
end

-- Returns one field of a validated aura, or nil and the reason that field is unavailable (or "invalid-aura-field").
function platform:ReadAuraField(aura, field)
    if not fields[field] or type(aura) ~= "table" then
        return nil, "invalid-aura-field"
    end
    if aura.unavailable and aura.unavailable[field] then
        return nil, aura.unavailable[field]
    end

    return aura[field]
end

-- Returns the seconds left on an aura at time now (a GetTime value), math.huge for an aura with no duration, or nil
-- and a reason code when its expiration cannot be read.
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
