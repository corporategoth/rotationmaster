-- Platform adapter for totem slots (GetNumTotemSlots, GetTotemInfo). Readers return `value, nil` or `nil, reason`;
-- every tuple field passes platform:CanReadValue before it is compared, because totem slots can be secret on
-- restricted clients. Must not decide which totem a spell makes; the TOTEM conditions in Conditions/totem.lua do
-- that. Loaded from RotationMaster.toc after Platform/inventory.lua. Not a Built In helper source, so it has no
-- generated bindings block.
local _, addon = ...
local platform = addon.Platform

-- Whether a value is a number that is neither NaN nor infinite.
-- @param value any  The value to test.
-- @return boolean  True for a finite number.
local function finite(value)
    return type(value) == "number" and value == value and value < math.huge and value > -math.huge
end

-- Whether a value is an integer totem slot number from 1 to 64.
-- @param value any  The value to test.
-- @return boolean  True for an integer from 1 to 64.
local function slotNumber(value)
    return finite(value) and value >= 1 and value <= 64 and value % 1 == 0
end

-- Reads how many totem slots the client has (GetNumTotemSlots).
-- @return number|nil  The slot count (0 to 64); nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetTotemSlotCount()
    if type(GetNumTotemSlots) ~= "function" then
        return nil, "missing-api"
    end

    local ok, count = pcall(GetNumTotemSlots)

    if not ok then
        return nil, "api-error"
    end
    if not self:CanReadValue(count) then
        return nil, "restricted-value"
    end
    if not finite(count) or count < 0 or count > 64 or count % 1 ~= 0 then
        return nil, "invalid-api-result"
    end

    return count
end

-- Turns one GetTotemInfo tuple into a normalized totem record.
-- @param slot number  The totem slot the tuple was read for.
-- @param have boolean|nil  The native "slot has a totem" flag; false yields an inactive record with zeroed times.
-- @param name string|nil  The totem name.
-- @param start number|nil  The start time.
-- @param duration number|nil  The duration in seconds.
-- @param icon number|nil  The icon file id.
-- @param rate number|nil  The haste modifier rate; nil is treated as 1.
-- @param id number|nil  The totem spell id; zero or nil leaves spellID unset.
-- @return table|nil  The record { slot, active, name, startTime, duration, iconID, modRate, spellID }; an empty slot is
--   { slot, active = false, startTime = 0, duration = 0, modRate = 1 }. nil when any field is restricted or malformed.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Observation transport is kept separate from validation, as with spell/aura records. No tuple field is compared
-- before its readability check.
local function normalize(slot, have, name, start, duration, icon, rate, id)
    if not platform:CanReadValue(have) then
        return nil, "restricted-value"
    end
    if have == nil then
        return nil, "totem-data-unavailable"
    end
    if type(have) ~= "boolean" then
        return nil, "invalid-api-result"
    end
    if not have then
        return { slot = slot, active = false, startTime = 0, duration = 0, modRate = 1 }
    end

    for _, field in pairs({ name = name, start = start, duration = duration, icon = icon, rate = rate, id = id }) do
        if not platform:CanReadValue(field) then
            return nil, "restricted-value"
        end
    end

    if type(name) ~= "string" or not finite(start) or start < 0 or not finite(duration) or duration < 0 then
        return nil, "invalid-api-result"
    end
    if rate ~= nil and (not finite(rate) or rate <= 0) then
        return nil, "invalid-api-result"
    end
    if id ~= nil and (not finite(id) or id < 0 or id % 1 ~= 0) then
        return nil, "invalid-api-result"
    end
    if icon ~= nil and (not finite(icon) or icon < 0 or icon % 1 ~= 0) then
        return nil, "invalid-api-result"
    end

    return {
        slot = slot,
        active = duration > 0,
        name = name,
        startTime = start,
        duration = duration,
        iconID = icon,
        modRate = rate or 1,
        spellID = id and id > 0 and id or nil,
    }
end

-- Reads one totem slot (GetTotemInfo).
-- @param slot number  The totem slot, an integer from 1 to 64.
-- @return table|nil  The normalized record, as described above normalize; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetTotemInfo(slot)
    if not slotNumber(slot) then
        return nil, "invalid-totem-slot"
    end
    if type(GetTotemInfo) ~= "function" then
        return nil, "missing-api"
    end

    local ok, have, name, start, duration, icon, rate, id = pcall(GetTotemInfo, slot)

    if not ok then
        return nil, "api-error"
    end

    return normalize(slot, have, name, start, duration, icon, rate, id)
end
