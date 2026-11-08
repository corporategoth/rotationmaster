-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for the game's own swing timer: PLAYER_SWING(swingDuration, swingType), which Forever sends for
-- every melee swing (C_SwingTimer; swingType 0 main hand, 1 off hand). The duration already includes haste, and the
-- payload is plain in combat (Hekili Forever's probes), so the time to the next swing reads there while UnitAttackSpeed
-- is secret. Returns `value, nil` or `nil, reason`. Loaded from RotationMaster.toc after Platform/combat_events.lua;
-- Conditions/swing_timer.lua uses it.
local _, addon = ...
local platform = addon.Platform

-- Per hand (1 main, 2 off): { time, duration } of the last swing.
local swings = {}

-- Records one swing (the PLAYER_SWING handler; also used by tests).
-- @param now number  The time of the swing.
-- @param duration any  The swing duration in seconds.
-- @param swingType any  0 for the main hand, 1 for the off hand.
function platform:NoteSwing(now, duration, swingType)
    if not self:CanReadValue(duration) or not self:CanReadValue(swingType) then
        return
    end
    if type(duration) ~= 'number' or duration <= 0 or duration ~= duration or duration == math.huge then
        return
    end
    if swingType ~= 0 and swingType ~= 1 then
        return
    end

    swings[swingType + 1] = { time = now, duration = duration }
end

if type(CreateFrame) == 'function' then
    local events = CreateFrame('Frame')

    if pcall(events.RegisterEvent, events, 'PLAYER_SWING') then
        events:SetScript('OnEvent', function(_, _, duration, swingType)
            platform:NoteSwing(type(GetTime) == 'function' and GetTime() or 0, duration, swingType)
        end)
    end
end

-- Reports whether the client has the game's swing timer.
-- @return boolean  True where C_SwingTimer exists (Forever).
function platform:HasSwingTimer()
    return type(C_SwingTimer) == 'table'
end

-- Reads the seconds until the next swing of a hand.
-- @param offhand boolean|nil  True for the off hand.
-- @param now number  The time to measure from.
-- @return number|nil  The seconds left, 0 when no swing is under way (none yet, or the last one has finished); nil
--   when the client has no swing timer.
-- @return string|nil  'missing-api' when the first return is nil; nil otherwise.
function platform:GetNextSwingObservation(offhand, now)
    if not self:HasSwingTimer() then
        return nil, 'missing-api'
    end

    local swing = swings[offhand and 2 or 1]

    if not swing or type(now) ~= 'number' then
        return 0
    end

    return math.max(0, swing.time + swing.duration - now)
end

-- Reads the duration of the last swing of a hand, the current swing interval.
-- @param offhand boolean|nil  True for the off hand.
-- @return number|nil  The seconds; nil before the first swing of that hand.
function platform:GetLastSwingDuration(offhand)
    local swing = swings[offhand and 2 or 1]
    return swing and swing.duration or nil
end
