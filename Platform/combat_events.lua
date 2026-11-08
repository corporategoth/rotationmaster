-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for two combat facts that stay readable while the combat log is closed to addons: how many enemies
-- are targeting you (nameplate tokens: UnitExists, UnitCanAttack and UnitIsUnit("nameplateNtarget", "player")) and
-- when you or your group last killed something (PARTY_KILL, which fires even while its GUIDs are hidden). Readers return
-- `value, nil` or `nil, reason`, and every value passes platform:CanReadValue. Comparisons through a compound token are
-- secret on restricted maps (dungeons and raids; SecretWhenUnitComparisonRestricted), so the count is unavailable there.
-- Loaded from RotationMaster.toc after Platform/unit_rank.lua; Conditions/combat_events.lua uses it.
local _, addon = ...
local platform = addon.Platform

-- The time of the last PARTY_KILL, or nil before the first one this session.
local lastKill

if type(CreateFrame) == 'function' then
    local events = CreateFrame('Frame')
    pcall(events.RegisterEvent, events, 'PARTY_KILL')

    events:SetScript('OnEvent', function()
        lastKill = type(GetTime) == 'function' and GetTime() or nil
    end)
end

-- Notes a kill by you or your group (the PARTY_KILL handler; also used by tests).
-- @param now number  The time of the kill.
function platform:NoteKill(now)
    lastKill = now
end

-- Reads when you or your group last killed something.
-- @return number|false  The GetTime() of the last kill; false when there was none this session.
function platform:GetLastKillTime()
    return lastKill or false
end

-- Counts the hostile units on nameplates whose target is you.
-- @return number|nil  The count; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil ('restricted-value' when the game hides a target
--   comparison, as it does on restricted maps); nil otherwise.
function platform:GetEnemiesTargetingPlayer()
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return nil, 'unsupported-policy'
    end
    if type(UnitExists) ~= 'function' or type(UnitCanAttack) ~= 'function' or type(UnitIsUnit) ~= 'function' then
        return nil, 'missing-api'
    end

    local count = 0

    for index = 1, 40 do
        local token = 'nameplate' .. index
        local ok, exists = pcall(UnitExists, token)

        if ok and self:CanReadValue(exists) and exists then
            local hostileOk, hostile = pcall(UnitCanAttack, 'player', token)

            if not hostileOk or not self:CanReadValue(hostile) then
                return nil, 'restricted-value'
            end

            if hostile then
                local sameOk, same = pcall(UnitIsUnit, token .. 'target', 'player')

                if not sameOk or not self:CanReadValue(same) then
                    return nil, 'restricted-value'
                end
                if canaccessvalue and not canaccessvalue(same) then
                    return nil, 'restricted-value'
                end

                if same == true then
                    count = count + 1
                end
            end
        end
    end

    return count
end
