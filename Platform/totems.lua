-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for totem slots (GetNumTotemSlots, GetTotemInfo). Readers return `value, nil` or `nil, reason`;
-- every tuple field passes platform:CanReadValue before it is compared, because totem slots can be secret on
-- restricted clients. Must not decide which totem a spell makes; the TOTEM conditions in Conditions/totem.lua do
-- that. Loaded from RotationMaster.toc after Platform/inventory.lua. Not a Built In helper source, so it has no
-- generated bindings block.
--
-- Retail and Forever hide totem slots in combat (SecretWhenTotemSlotSecret). PLAYER_TOTEM_UPDATE still fires, so a
-- slot is tracked: a readable read records it (and the duration of its totem spell); an update right after one of your
-- own casts is that spell's totem being summoned; any other update means the totem is gone (destroyed or expired).
-- While the slot is hidden, GetTotemInfo answers from that record, marked estimated, when the totem's duration is known.
local _, addon = ...
local platform = addon.Platform

-- Per slot: { active, spellID, startTime, duration }; per spell: the duration last read for its totem; the last cast.
local trackedSlots, totemDurations, lastCast = {}, {}, { time = -math.huge }

-- How soon after your cast a slot update counts as that cast's totem, in seconds.
local SUMMON_WINDOW = 0.5

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

-- Answers a hidden slot from its tracked record.
-- @param slot number  The totem slot.
-- @return table|nil  A record shaped like normalize's, with estimated = true; nil when the slot was never tracked, or
--   holds a totem whose duration is unknown.
local function trackedRecord(slot)
    local tracked = trackedSlots[slot]

    if not tracked then
        return nil
    end
    if not tracked.active then
        return { slot = slot, active = false, startTime = 0, duration = 0, modRate = 1, estimated = true }
    end
    if not tracked.duration then
        return nil
    end

    local info = tracked.spellID and platform.GetSpellInfo and platform:GetSpellInfo(tracked.spellID)

    return {
        slot = slot,
        active = true,
        name = info and info.name or "",
        startTime = tracked.startTime,
        duration = tracked.duration,
        modRate = 1,
        spellID = tracked.spellID,
        estimated = true,
    }
end

-- Notes a slot update while the slot is hidden: a summon of the spell you just cast, or the totem going away.
-- @param slot number  The slot from PLAYER_TOTEM_UPDATE.
-- @param now number  The time of the update.
function platform:NoteTotemSlotUpdate(slot, now)
    if not slotNumber(slot) then
        return
    end

    if now - lastCast.time <= SUMMON_WINDOW and lastCast.spellID then
        trackedSlots[slot] = {
            active = true,
            spellID = lastCast.spellID,
            startTime = now,
            duration = totemDurations[lastCast.spellID],
        }

        lastCast.time = -math.huge
    else
        trackedSlots[slot] = { active = false }
    end
end

-- Notes one of your own successful casts, for matching the totem it summons.
-- @param spellID any  The cast spell id; a hidden or malformed id still marks the time, with no spell.
-- @param now number  The time of the cast.
function platform:NoteTotemCast(spellID, now)
    lastCast.time = now
    lastCast.spellID = self:CanReadValue(spellID) and finite(spellID) and spellID > 0 and spellID or nil
end

if type(CreateFrame) == "function" then
    local events = CreateFrame("Frame")
    pcall(events.RegisterEvent, events, "PLAYER_TOTEM_UPDATE")

    if not pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player") then
        pcall(events.RegisterEvent, events, "UNIT_SPELLCAST_SUCCEEDED")
    end

    events:SetScript("OnEvent", function(_, event, a, _, c)
        local now = type(GetTime) == "function" and GetTime() or 0

        if event == "PLAYER_TOTEM_UPDATE" then
            if platform:CanReadValue(a) then
                platform:NoteTotemSlotUpdate(a, now)
            end
        elseif platform:CanReadValue(a) and a == "player" then
            platform:NoteTotemCast(c, now)
        end
    end)
end

-- Reads one totem slot (GetTotemInfo).
-- @param slot number  The totem slot, an integer from 1 to 64.
-- @return table|nil  The normalized record, as described above normalize; nil when it cannot be read. A slot the
--   client hides is answered from its tracked record (estimated = true) when there is one.
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

    local record, reason = normalize(slot, have, name, start, duration, icon, rate, id)

    if record then
        trackedSlots[slot] = {
            active = record.active,
            spellID = record.spellID,
            startTime = record.startTime,
            duration = record.active and record.duration or nil,
        }

        if record.active and record.spellID then
            totemDurations[record.spellID] = record.duration
        end

        return record
    end

    if reason == "restricted-value" then
        local tracked = trackedRecord(slot)

        if tracked then
            return tracked
        end
    end

    return nil, reason
end
