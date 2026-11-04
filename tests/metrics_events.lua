-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The event wiring of addon.Metrics (Platform/metrics_events.lua): nothing exists while both switches are off, the
-- switches create exactly the registrations they need, a cast is matched with the advice current when it was pressed,
-- the combat log is read only for the player's own output, and the restricted clients register no combat log at all.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

-- Builds a client with the metrics files loaded and a scriptable clock, frame and message bus.
-- @param product number  The WOW_PROJECT_ID.
-- @return table  The fixture, plus the frames it created and the clock.
local function client(product)
    local f = F.new(product or 5, 1, 'MAGE')
    local e = f.env
    local made, clock = {}, { now = 100, combat = false }

    e.GetTime = function()
        return clock.now
    end

    e.InCombatLockdown = function()
        return clock.combat
    end

    e.UnitGUID = function()
        return 'Player-1'
    end

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

    local bus = {}

    local ace = {
        Embed = function(_, target)
            function target:RegisterMessage(message, fn)
                bus[message] = fn
            end

            function target:UnregisterAllMessages()
                bus = {}
            end
        end,
    }

    local stub = e.LibStub

    e.LibStub = function(name)
        return name == 'AceEvent-3.0' and ace or stub(name)
    end

    f.send = function(message, ...)
        if bus[message] then
            bus[message](message, ...)
        end
    end

    f.addon.db = { global = {}, profile = { enable = true } }

    f.addon.SetUIScript = function(_, frame, event, fn)
        frame.scripts[event] = fn
    end

    f.load('Analytics/metrics.lua')
    f.load('Platform/metrics_events.lua')
    f.made, f.clock = made, clock
    return f
end

-- Fires an event at the metrics frame.
-- @param f table  The fixture.
-- @param event string  The event name.
-- @param ... any  The arguments.
local function fire(f, event, ...)
    local frame = f.made[#f.made]
    frame.scripts.OnEvent(frame, event, ...)
end

test('with both switches off nothing exists', function()
    local f = client()
    f.addon:ApplyMetricsSettings()
    assert(#f.made == 0)
    local adherence, effectiveness = f.addon:GetMetricsState()
    assert(not adherence and not effectiveness)
end)

test('adherence registers the cast and combat events and one message, and effectiveness adds the combat log', function()
    local f = client()
    f.addon.db.profile.metrics_adherence = true
    f.addon:ApplyMetricsSettings()
    local frame = f.made[1]
    assert(frame.unitEvents.UNIT_SPELLCAST_SENT == 'player')
    assert(frame.events.PLAYER_REGEN_DISABLED and frame.events.PLAYER_REGEN_ENABLED)
    assert(not frame.events.COMBAT_LOG_EVENT_UNFILTERED)
    f.addon.db.profile.metrics_effectiveness = true
    f.addon:ApplyMetricsSettings()
    assert(#f.made == 1, 'the one frame is reused')
    assert(f.made[1].events.COMBAT_LOG_EVENT_UNFILTERED)
    f.addon:ApplyMetricsSettings(true)
    assert(not next(f.made[1].events) and not next(f.made[1].unitEvents), 'disabling the rotation stops collection')
    local adherence, effectiveness = f.addon:GetMetricsState()
    assert(not adherence and not effectiveness)
end)

test('a cast is matched with the advice that was current when it was pressed', function()
    local f = client()
    f.addon.db.profile.metrics_adherence = true
    f.addon:ApplyMetricsSettings()
    fire(f, 'PLAYER_REGEN_DISABLED')
    f.clock.now = 101
    f.addon.currentRotation, f.addon.currentSpell = 'rot', 133
    f.send('ROTATIONMASTER_SPELL_UPDATE', 'rot', 1, 'c1', 'spell', 133)
    f.clock.now = 101.5
    fire(f, 'UNIT_SPELLCAST_SENT', 'player', nil, 'guid', 133)
    f.clock.now = 102
    fire(f, 'UNIT_SPELLCAST_SENT', 'party1', nil, 'guid', 116)
    f.clock.now = 120
    fire(f, 'PLAYER_REGEN_ENABLED')
    local r = f.addon.Metrics:Report().rotations[1]
    assert(r and r.casts == 1 and r.followed == 1 and r.meanDelay == 0.5, 'only the player\'s own cast counts')
end)

test('advice cleared without a message is noticed when a cast arrives', function()
    local f = client()
    f.addon.db.profile.metrics_adherence = true
    f.addon:ApplyMetricsSettings()
    fire(f, 'PLAYER_REGEN_DISABLED')
    f.clock.now = 101
    f.addon.currentRotation, f.addon.currentSpell = 'rot', 133
    f.send('ROTATIONMASTER_SPELL_UPDATE', 'rot', 1, 'c1', 'spell', 133)
    f.addon.currentSpell = nil
    f.clock.now = 102
    fire(f, 'UNIT_SPELLCAST_SENT', 'player', nil, 'guid', 133)
    f.clock.now = 130
    fire(f, 'PLAYER_REGEN_ENABLED')
    local r = f.addon.Metrics:Report().rotations[1]
    assert(r.unadvised == 1 and r.followed == 0)
end)

test('the combat log adds only the player\'s damage and effective healing', function()
    local f = client()
    f.addon.db.profile.metrics_effectiveness = true
    f.addon.db.profile.metrics_adherence = true
    f.addon:ApplyMetricsSettings()
    local events = {}

    f.env.CombatLogGetCurrentEventInfo = function()
        return (table.unpack or unpack)(events)
    end

    fire(f, 'PLAYER_REGEN_DISABLED')
    f.clock.now = 101
    f.addon.currentRotation, f.addon.currentSpell = 'rot', 133
    f.send('ROTATIONMASTER_SPELL_UPDATE', 'rot', 1, 'c1', 'spell', 133)
    fire(f, 'UNIT_SPELLCAST_SENT', 'player', nil, 'guid', 133)

    events = {
        0, 'SPELL_DAMAGE', false, 'Player-1', 'Me', 0, 0, 'Creature-1', 'Dummy', 0, 0, 133, 'Fireball', 4, 1000, 100
    }

    fire(f, 'COMBAT_LOG_EVENT_UNFILTERED')
    events = {0, 'SWING_DAMAGE', false, 'Player-1', 'Me', 0, 0, 'Creature-1', 'Dummy', 0, 0, 200, 0}
    fire(f, 'COMBAT_LOG_EVENT_UNFILTERED')
    events = {0, 'SPELL_DAMAGE', false, 'Creature-1', 'Dummy', 0, 0, 'Player-1', 'Me', 0, 0, 1, 'Hit', 1, 5000, 0}
    fire(f, 'COMBAT_LOG_EVENT_UNFILTERED')
    events = {0, 'SPELL_HEAL', false, 'Player-1', 'Me', 0, 0, 'Player-1', 'Me', 0, 0, 2, 'Heal', 2, 800, 300, 100}
    fire(f, 'COMBAT_LOG_EVENT_UNFILTERED')
    f.clock.now = 111
    fire(f, 'PLAYER_REGEN_ENABLED')
    local r = f.addon.Metrics:Report().rotations[1]
    assert(r.dps == 100 and r.hps == 36, tostring(r.dps) .. ' ' .. tostring(r.hps))
end)

test('Retail and Forever register no combat log whatever the switch says', function()
    for _, product in ipairs({ 1, 18 }) do
        local f = client(product)
        f.addon.db.profile.metrics_effectiveness = true
        f.addon:ApplyMetricsSettings()
        local adherence, effectiveness, readable = f.addon:GetMetricsState()
        assert(not effectiveness and not readable, 'product ' .. product)
        assert(#f.made == 0)
    end
end)

finish()
