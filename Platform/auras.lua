local _, addon = ...
local platform = addon.Platform
local isEra = platform:GetClientInfo().family == "era"
local durationProvider, checkedDurations

local fields = {name="string", spellID="number", applications="number", dispelName="string",
                duration="number", expirationTime="number", sourceUnit="string", isStealable="boolean"}
local function normalize(raw)
    if not platform:CanReadValue(raw) then return nil, "restricted-value" end
    if raw == nil then return nil end
    if type(raw) ~= "table" then return nil, "invalid-api-result" end
    local result = {unavailable={}}
    for key, kind in pairs(fields) do
        local value = raw[key == "spellID" and "spellId" or key]
        if not platform:CanReadValue(value) then result.unavailable[key] = "restricted-value"
        elseif value ~= nil and type(value) ~= kind then result.unavailable[key] = "invalid-api-result"
        elseif type(value) == "number" and (value ~= value or value == math.huge or value == -math.huge or value < 0) then
            result.unavailable[key] = "invalid-api-result"
        else result[key] = value end
    end
    if result.name == nil and not result.unavailable.name then result.unavailable.name = "invalid-api-result" end
    return result
end

function platform:GetAuraByIndex(unit, index, filter)
    for _, value in pairs({unit=unit, index=index, filter=filter}) do
        if not self:CanReadValue(value) then return nil, "restricted-value" end
    end
    if type(unit) ~= "string" or unit == "" or type(index) ~= "number" or index < 1
        or index > 256 or index % 1 ~= 0 or (filter ~= "HELPFUL" and filter ~= "HARMFUL" and filter ~= "HARMFUL|RAID") then
        return nil, "invalid-aura-query"
    end
    local legacy
    -- ClassicDurations supplies otherwise unavailable Era timer estimates.
    -- It stays optional and never substitutes for a restricted native result.
    if isEra and not checkedDurations and (type(LibStub) == "table" or type(LibStub) == "function") then
        checkedDurations = true
        local ok, lib = pcall(LibStub, "LibClassicDurations", true)
        if ok and type(lib) == "table" and type(lib.UnitAuraDirect) == "function" then durationProvider = lib.UnitAuraDirect end
    end
    legacy = durationProvider
    if not legacy and C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
        local ok, raw = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if not ok then return nil, "api-error" end
        return normalize(raw)
    end
    legacy = legacy or UnitAura
    if type(legacy) ~= "function" then return nil, "missing-api" end
    local ok, name, _, count, dispel, duration, expiration, source, stealable, _, id = pcall(legacy, unit, index, filter)
    if not ok then return nil, "api-error" end
    if not self:CanReadValue(name) then return nil, "restricted-value" end
    if name == nil then return nil end
    if self:CanReadValue(stealable) and stealable == nil then stealable = false end
    return normalize({name=name, applications=count, dispelName=dispel, duration=duration,
        expirationTime=expiration, sourceUnit=source, spellId=id, isStealable=stealable})
end

function platform:ReadAuraField(aura, field)
    if not fields[field] or type(aura) ~= "table" then return nil, "invalid-aura-field" end
    if aura.unavailable and aura.unavailable[field] then return nil, aura.unavailable[field] end
    return aura[field]
end

function platform:AuraRemaining(aura, now)
    local expiration, reason = self:ReadAuraField(aura, "expirationTime")
    if reason then return nil, reason end
    if expiration == nil then return nil, "aura-time-unavailable" end
    if not self:CanReadValue(now) then return nil, "restricted-value" end
    if type(now) ~= "number" or now ~= now or now == math.huge or now == -math.huge then return nil, "invalid-time" end
    if expiration == 0 then
        local duration, why = self:ReadAuraField(aura, "duration")
        if why then return nil, why end
        if duration == 0 then return math.huge end
        return nil, "aura-time-unavailable"
    end
    return math.max(0, expiration - now)
end
