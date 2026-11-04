-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Feeds addon.Metrics (Analytics/metrics.lua) from the game. Two independent switches, both off by default
-- (profile.metrics_adherence and profile.metrics_effectiveness):
--   * adherence: the recommended spell (the ROTATIONMASTER_SPELL_UPDATE message the glow already sends), the player's own
--     casts (UNIT_SPELLCAST_SENT for "player" only) and the start and end of combat;
--   * effectiveness: damage and healing the player did, from the combat log. Retail and Forever hide the combat log
--     payload, so the switch does nothing there and the report says so.
-- With both off no frame, event, message handler or timer exists. Combat log work for events of other sources is one
-- comparison. Nothing is allocated per event. Loaded from the Platform section of RotationMaster.toc.

local _, addon = ...
local platform = addon.Platform
local AceEvent = LibStub('AceEvent-3.0')

local metrics = addon.Metrics
local frame, playerGUID
local listener = {}
AceEvent:Embed(listener)
local running = { adherence = false, effectiveness = false }

-- Handles the recommendation changing.
-- @param _ string  The message name.
-- @param rotation string|nil  The active rotation id.
-- @param _ number  The step index.
-- @param _ string  The condition id.
-- @param _ string  The condition type.
-- @param spell number|nil  The recommended spell.
local function onAdvice(_, rotation, _, _, _, spell)
    metrics:Advice(rotation, type(spell) == 'number' and spell or nil, GetTime())
end

-- Whether the combat log can be read for the effectiveness figures.
-- @return boolean  False on the restricted clients, whose combat log payload is hidden.
local function canReadCombatLog()
    return platform:GetCombatDataPolicy() ~= 'restricted'
end

-- Adds one combat log event's amount when the player did it.
-- @param ... any  The combat log event payload.
local function addOutput(...)
    local _, sub, _, source, _, _, _, _, _, _, _, p12, _, _, p15, p16, p17 = ...

    if source ~= playerGUID or not metrics:IsInFight() then
        return
    end

    if sub == 'SWING_DAMAGE' then
        metrics:Output(math.max(0, (p12 or 0) - math.max(0, p15 or 0)), 0)
    elseif sub == 'SPELL_DAMAGE' or sub == 'RANGE_DAMAGE' or sub == 'SPELL_PERIODIC_DAMAGE' then
        metrics:Output(math.max(0, (p15 or 0) - math.max(0, p16 or 0)), 0)
    elseif sub == 'SPELL_HEAL' or sub == 'SPELL_PERIODIC_HEAL' then
        metrics:Output(0, math.max(0, (p15 or 0) - math.max(0, p16 or 0) - math.max(0, p17 or 0)))
    end
end

-- Handles one combat log event: adds the player's damage and healing.
local function onCombatLog()
    local read = type(C_CombatLog) == 'table' and C_CombatLog.GetCurrentEventInfo or CombatLogGetCurrentEventInfo

    addOutput(read())
end

-- Handles the registered game events.
-- @param _ table  The frame.
-- @param event string  The event name.
-- @param ... any  The event arguments.
local function onEvent(_, event, ...)
    if event == 'UNIT_SPELLCAST_SENT' then
        local unit, _, _, spell = ...

        if unit == 'player' and platform:CanReadValue(spell) and type(spell) == 'number' then
            local now = GetTime()

            if addon.currentSpell ~= nil and addon.currentSpell ~= metrics:CurrentAdvice() then
                metrics:Advice(addon.currentRotation, addon.currentSpell, now)
            elseif addon.currentSpell == nil and metrics:CurrentAdvice() ~= nil then
                metrics:Advice(addon.currentRotation, nil, now)
            end

            metrics:Cast(spell, now)
        end
    elseif event == 'PLAYER_REGEN_DISABLED' then
        metrics:FightStart(GetTime())
    elseif event == 'PLAYER_REGEN_ENABLED' then
        metrics:FightEnd(GetTime())
    elseif event == 'COMBAT_LOG_EVENT_UNFILTERED' then
        onCombatLog()
    end
end

-- Creates the one frame the first time a switch is turned on.
-- @return table  The frame.
local function getFrame()
    if not frame then
        frame = CreateFrame('Frame')
        addon:SetUIScript(frame, 'OnEvent', onEvent)
    end

    return frame
end

-- Whether a switch is on in the active profile, with the rotation enabled.
-- @param key string  The profile key.
-- @return boolean  True when collection for that key should run.
local function wanted(key)
    local profile = addon.db and addon.db.profile
    return profile ~= nil and profile.enable ~= false and profile[key] == true
end

-- Starts or stops collection to match the profile's switches. Safe to call at any time and as often as wanted.
-- @param off boolean|nil  True stops collection whatever the switches say (the rotation is being disabled).
function addon:ApplyMetricsSettings(off)
    local adherence = off ~= true and wanted('metrics_adherence')
    local effectiveness = off ~= true and wanted('metrics_effectiveness') and canReadCombatLog()

    if adherence == running.adherence and effectiveness == running.effectiveness then
        return
    end

    if not adherence and not effectiveness then
        if frame then
            frame:UnregisterAllEvents()
        end

        listener:UnregisterAllMessages()
        metrics:Reset()
        running.adherence, running.effectiveness = false, false
        playerGUID = nil
        return
    end

    local f = getFrame()
    f:UnregisterAllEvents()
    metrics:Reset()
    playerGUID = UnitGUID('player')
    f:RegisterEvent('PLAYER_REGEN_DISABLED')
    f:RegisterEvent('PLAYER_REGEN_ENABLED')

    if adherence then
        f:RegisterUnitEvent('UNIT_SPELLCAST_SENT', 'player')
        listener:RegisterMessage('ROTATIONMASTER_SPELL_UPDATE', onAdvice)
    else
        listener:UnregisterAllMessages()
    end

    if effectiveness then
        f:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
    end

    running.adherence, running.effectiveness = adherence, effectiveness

    if InCombatLockdown() then
        metrics:FightStart(GetTime())
    end
end

-- What is collecting right now.
-- @return boolean  Adherence collection is running.
-- @return boolean  Effectiveness collection is running.
-- @return boolean  The combat log can be read on this client.
function addon:GetMetricsState()
    return running.adherence, running.effectiveness, canReadCombatLog()
end
