-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Teaches addon.Forecast (Core/forecast.lua) what the player's spells do, from watching them being cast, while the
-- forecast switch (profile.forecast) is on:
--   * the aura a spell leaves on the target or the player (the auras before the cast against the auras shortly after it);
--   * the damage a spell does and the healing it does to the player, as a running average, from the combat log (not on
--     Retail and Forever, which hide it).
-- Everything learned is a few numbers per spell in RotationMasterDB.global.forecast, capped at 160 spells. With the switch
-- off no frame, event or timer exists. Loaded from the Platform section of RotationMaster.toc after
-- Platform/metrics_events.lua.

local _, addon = ...
local platform = addon.Platform

local forecast = addon.Forecast
local frame, playerGUID
local running = false
local pending = {}

-- A spell whose aura was seen this many times is taken as known; one that left none this many times is taken as leaving
-- none. Both stop the aura scans for that spell.
local CONFIRMED, NONE = 3, 5
local SETTLE = 0.35
local ALPHA = 0.25

-- Reads the player's auras on a unit that came from the player.
-- @param unit string  "target" or "player".
-- @param filter string  "HARMFUL" or "HELPFUL".
-- @param into table  The table to fill with [spellID] = { duration, expiration }.
local function scan(unit, filter, into)
    for index = 1, 64 do
        local aura = platform:GetAuraByIndex(unit, index, filter)

        if not aura then
            break
        end

        if aura.sourceUnit == 'player' and type(aura.spellID) == 'number' then
            into[aura.spellID] = { duration = aura.duration or 0, expiration = aura.expirationTime or 0 }
        end
    end
end

-- Takes the auras before a cast.
-- @param spell number  The spell about to be cast.
local function before(spell)
    local known = forecast:Known(spell)

    if known and ((known.applies and (known.applies.n or 0) >= CONFIRMED) or (known.none or 0) >= NONE) then
        return
    end

    local snapshot = { target = {}, player = {} }

    if UnitExists('target') then
        scan('target', 'HARMFUL', snapshot.target)
    end

    scan('player', 'HELPFUL', snapshot.player)
    pending[spell] = snapshot
end

-- Compares the auras after a cast with those before it and records what the spell left.
-- @param spell number  The spell that was cast.
local function after(spell)
    local snapshot = pending[spell]
    pending[spell] = nil

    if not snapshot then
        return
    end

    local now = { target = {}, player = {} }

    if UnitExists('target') then
        scan('target', 'HARMFUL', now.target)
    end

    scan('player', 'HELPFUL', now.player)
    local name = platform:GetSpellInfo(spell)
    name = name and name.name
    local best

    for _, unit in ipairs({ 'target', 'player' }) do
        for aura, record in pairs(now[unit]) do
            local was = snapshot[unit][aura]

            if not was or record.expiration > was.expiration + 0.5 then
                local info = platform:GetSpellInfo(aura)
                local named = info and info.name == name

                if not best or named and not best.named then
                    best = { unit = unit, aura = aura, duration = record.duration, named = named }
                end
            end
        end
    end

    local entry = forecast:Known(spell, true)

    if not entry then
        return
    end

    if best then
        local same = entry.applies and entry.applies.aura == best.aura and entry.applies.unit == best.unit

        entry.applies = {
            unit = best.unit,
            aura = best.aura,
            duration = best.duration,
            n = same and (entry.applies.n or 0) + 1 or 1,
        }
    else
        entry.none = (entry.none or 0) + 1
    end
end

-- Folds an amount into a running average.
-- @param entry table  The spell's record.
-- @param key string  "damage" or "heal".
-- @param amount number  The new amount.
local function average(entry, key, amount)
    entry[key] = entry[key] and (entry[key] * (1 - ALPHA) + amount * ALPHA) or amount
end

-- Handles a combat log event: the player's damage, and healing to the player, per spell.
-- @param ... any  The combat log payload.
local function addOutput(...)
    local _, sub, _, source, _, _, _, dest, _, _, _, spell, _, _, amount, extra = ...

    if source ~= playerGUID or type(spell) ~= 'number' or type(amount) ~= 'number' then
        return
    end

    local entry

    if sub == 'SPELL_DAMAGE' or sub == 'RANGE_DAMAGE' then
        entry = forecast:Known(spell, true)

        if entry then
            average(entry, 'damage', math.max(0, amount - math.max(0, extra or 0)))
        end
    elseif sub == 'SPELL_HEAL' and dest == playerGUID then
        entry = forecast:Known(spell, true)

        if entry then
            average(entry, 'heal', math.max(0, amount - math.max(0, extra or 0)))
        end
    end
end

-- Handles the registered game events.
-- @param _ table  The frame.
-- @param event string  The event name.
-- @param ... any  The event arguments.
local function onEvent(_, event, ...)
    if event == 'UNIT_SPELLCAST_SENT' then
        local unit, _, _, spell = ...

        if unit == 'player' and platform:CanReadValue(spell) and type(spell) == 'number' then
            before(spell)
        end
    elseif event == 'UNIT_SPELLCAST_SUCCEEDED' then
        local unit, _, spell = ...

        if unit == 'player' and platform:CanReadValue(spell) and type(spell) == 'number' and pending[spell] then
            if C_Timer and C_Timer.After then
                C_Timer.After(SETTLE, function()
                    after(spell)
                end)
            else
                after(spell)
            end
        end
    elseif event == 'COMBAT_LOG_EVENT_UNFILTERED' then
        local read = type(C_CombatLog) == 'table' and C_CombatLog.GetCurrentEventInfo or CombatLogGetCurrentEventInfo

        addOutput(read())
    end
end

-- Starts or stops learning to match the profile's forecast switch. Safe to call at any time.
-- @param off boolean|nil  True stops learning whatever the switch says.
function addon:ApplyForecastSettings(off)
    local profile = addon.db and addon.db.profile
    local wanted = off ~= true and profile ~= nil and profile.enable ~= false and profile.forecast == true

    if wanted == running then
        return
    end

    running = wanted

    if not wanted then
        if frame then
            frame:UnregisterAllEvents()
        end

        for key in pairs(pending) do
            pending[key] = nil
        end

        playerGUID = nil
        return
    end

    if not frame then
        frame = CreateFrame('Frame')
        addon:SetUIScript(frame, 'OnEvent', onEvent)
    end

    playerGUID = UnitGUID('player')
    frame:RegisterUnitEvent('UNIT_SPELLCAST_SENT', 'player')
    frame:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')

    if platform:GetCombatDataPolicy() ~= 'restricted' then
        frame:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
    end
end

-- Whether the forecast switch is on and the forecast should run.
-- @return boolean  True when predictions should be made.
function addon:IsForecastOn()
    return running
end
