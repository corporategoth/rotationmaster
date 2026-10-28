-- Platform adapter for totem slots (GetNumTotemSlots, GetTotemInfo). Readers return `value, nil` or `nil, reason`;
-- every tuple field passes platform:CanReadValue before it is compared, because totem slots can be secret on
-- restricted clients. Must not decide which totem a spell makes; the TOTEM conditions in Conditions/totem.lua do
-- that. Loaded from RotationMaster.toc after Platform/inventory.lua. Not a Built In helper source, so it has no
-- generated bindings block.
local _, addon = ...
local platform = addon.Platform

-- True for a number that is neither NaN nor infinite.
local function finite(value)
    return type(value) == "number" and value == value and value < math.huge and value > -math.huge
end

-- True when value is an integer slot number from 1 to 64.
local function slotNumber(value)
    return finite(value) and value >= 1 and value <= 64 and value % 1 == 0
end

-- Returns the number of totem slots the client has (0 to 64), or nil and a reason.
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

-- Keep observation transport separate from validation, as with spell/aura
-- records. No tuple field is compared before its readability check.
-- Turns one GetTotemInfo tuple into { slot, active, name, startTime, duration, iconID, modRate, spellID }. An empty
-- slot (have == false) is an inactive record with zeroed times; otherwise nil and a reason when any field is
-- restricted or malformed.
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

-- Returns the normalized record for totem slot (1 to 64) as described above normalize, or nil and a reason.
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
