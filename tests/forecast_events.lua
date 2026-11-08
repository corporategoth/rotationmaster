-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- What the forecast learns from the player's casts (Platform/forecast_events.lua): nothing exists while the switch is off,
-- an aura a spell leaves is found by comparing the auras before and after, damage and self-healing are averaged per spell
-- from the combat log, a spell settled either way stops being scanned, and the restricted clients register no combat log.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

-- Builds a client with the forecast files loaded and a world the platform readers answer from.
-- @param product number  The WOW_PROJECT_ID.
-- @return table  The fixture with .made (frames), .world and .fire.
local function client(product)
    local f = F.new(product or 5, 1, 'MAGE')
    local e, a = f.env, f.addon
    local made, world = {}, { auras = { target = {}, player = {} }, scans = 0 }
    local native = e.CreateFrame

    e.CreateFrame = function(...)
        local frame = native(...)
        frame.events, frame.unitEvents = {}, {}

        function frame:RegisterEvent(event)
            self.events[event] = true
        end

        function frame:RegisterUnitEvent(event, unit)
            self.unitEvents[event] = unit
        end

        function frame:UnregisterAllEvents()
            self.events, self.unitEvents = {}, {}
        end

        made[#made + 1] = frame
        return frame
    end

    e.UnitGUID = function()
        return 'Player-1'
    end

    e.UnitExists = function()
        return true
    end

    e.C_Timer = {
        After = function(_, fn)
            fn()
        end,
    }

    a.SetUIScript = function(_, frame, event, fn)
        frame.scripts[event] = fn
    end

    a.db = { global = {}, profile = { enable = true } }
    local platform = a.Platform

    function platform:GetAuraByIndex(unit, index)
        world.scans = world.scans + 1
        local row = world.auras[unit][index]

        return row and {
            spellID = row.id,
            name = row.name,
            sourceUnit = 'player',
            duration = row.duration,
            expirationTime = row.expires,
        }
    end

    function platform:GetSpellInfo(spell)
        return { name = world.names and world.names[spell] or ('Spell ' .. spell) }
    end

    f.load('Core/forecast.lua')
    f.load('Platform/forecast_events.lua')
    f.made, f.world = made, world

    f.fire = function(event, ...)
        local frame = made[#made]
        frame.scripts.OnEvent(frame, event, ...)
    end

    return f
end

test('with the switch off nothing exists', function()
    local f = client()
    f.addon:ApplyForecastSettings()
    assert(#f.made == 0 and not f.addon:IsForecastOn())
end)

test('the switch registers the cast events and the combat log, and the rotation being disabled stops them', function()
    local f = client()
    f.addon.db.profile.forecast = true
    f.addon:ApplyForecastSettings()
    local frame = f.made[1]
    assert(f.addon:IsForecastOn())
    assert(frame.unitEvents.UNIT_SPELLCAST_SENT == 'player' and frame.unitEvents.UNIT_SPELLCAST_SUCCEEDED == 'player')
    assert(frame.events.COMBAT_LOG_EVENT_UNFILTERED)
    f.addon:ApplyForecastSettings(true)
    assert(not next(frame.events) and not next(frame.unitEvents) and not f.addon:IsForecastOn())
end)

test('the aura a spell leaves is learned from the auras before and after the cast', function()
    local f = client()
    f.addon.db.profile.forecast = true
    f.addon:ApplyForecastSettings()
    f.world.names = { [172] = 'Corruption', [172900] = 'Corruption' }
    f.world.auras.target = { { id = 1, name = 'Old', duration = 30, expires = 200 } }
    f.fire('UNIT_SPELLCAST_SENT', 'player', nil, 'guid', 172)

    f.world.auras.target = {
        { id = 1, name = 'Old', duration = 30, expires = 200 },
        { id = 172900, name = 'Corruption', duration = 18, expires = 118 },
    }

    f.fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'guid', 172)
    local known = f.addon.Forecast:Known(172)
    assert(known.applies.unit == 'target' and known.applies.aura == 172900 and known.applies.duration == 18)
    assert(known.applies.n == 1)
end)

test('a spell that leaves nothing is counted, and a settled spell is not scanned again', function()
    local f = client()
    f.addon.db.profile.forecast = true
    f.addon:ApplyForecastSettings()

    for _ = 1, 5 do
        f.fire('UNIT_SPELLCAST_SENT', 'player', nil, 'guid', 133)
        f.fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'guid', 133)
    end

    assert(f.addon.Forecast:Known(133).none == 5)
    local scans = f.world.scans
    f.fire('UNIT_SPELLCAST_SENT', 'player', nil, 'guid', 133)
    assert(f.world.scans == scans, 'five empty looks settle it')
end)

test('damage and healing to the player are averaged per spell from the player\'s own combat log events', function()
    local f = client()
    f.addon.db.profile.forecast = true
    f.addon:ApplyForecastSettings()
    local payload

    f.env.CombatLogGetCurrentEventInfo = function()
        return (table.unpack or unpack)(payload)
    end

    payload = {
        0, 'SPELL_DAMAGE', false, 'Player-1', 'Me', 0, 0, 'Creature-1', 'Dummy', 0, 0, 133, 'Fireball', 4, 1000, 200
    }

    f.fire('COMBAT_LOG_EVENT_UNFILTERED')
    assert(f.addon.Forecast:Known(133).damage == 800)

    payload = {
        0, 'SPELL_DAMAGE', false, 'Player-1', 'Me', 0, 0, 'Creature-1', 'Dummy', 0, 0, 133, 'Fireball', 4, 400, 0
    }

    f.fire('COMBAT_LOG_EVENT_UNFILTERED')
    assert(f.addon.Forecast:Known(133).damage == 700, 'a quarter of the new amount: 800 * .75 + 400 * .25')
    payload = {0, 'SPELL_DAMAGE', false, 'Creature-1', 'Dummy', 0, 0, 'Player-1', 'Me', 0, 0, 1, 'Hit', 1, 5000, 0}
    f.fire('COMBAT_LOG_EVENT_UNFILTERED')
    assert(f.addon.Forecast:Known(1) == nil, 'only the player\'s own spells')
    payload = {0, 'SPELL_HEAL', false, 'Player-1', 'Me', 0, 0, 'Player-1', 'Me', 0, 0, 2061, 'Flash Heal', 2, 900, 400}
    f.fire('COMBAT_LOG_EVENT_UNFILTERED')
    assert(f.addon.Forecast:Known(2061).heal == 500)
    payload = {0, 'SPELL_HEAL', false, 'Player-1', 'Me', 0, 0, 'Party-2', 'Friend', 0, 0, 2061, 'Flash Heal', 2, 900, 0}
    f.fire('COMBAT_LOG_EVENT_UNFILTERED')
    assert(f.addon.Forecast:Known(2061).heal == 500, 'healing someone else is not healing the player')
end)

test('Retail and Forever register no combat log', function()
    for _, product in ipairs({ 1, 18 }) do
        local f = client(product)
        f.addon.db.profile.forecast = true
        f.addon:ApplyForecastSettings()

        assert(
            f.made[1].unitEvents.UNIT_SPELLCAST_SENT == 'player' and not f.made[1].events.COMBAT_LOG_EVENT_UNFILTERED
        )
    end
end)

test('what is known is bounded and can be forgotten', function()
    local f = client()

    for spell = 1, 200 do
        f.addon.Forecast:Known(spell, true)
    end

    local count = 0

    for _ in pairs(f.addon.db.global.forecast.spells) do
        count = count + 1
    end

    assert(count == 160)
    f.addon.Forecast:Clear()
    assert(f.addon.Forecast:Known(1) == nil)
end)

finish()
