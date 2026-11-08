-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The forecast through the real engine: the real rotation executor and conditions on the Shaman starter rotation, the real
-- preview window, both evaluation engines. With the switch off the preview is what it always was; with it on the first
-- recommendation is read as before and the rest come from Core/forecast.lua with their confidence.
local make = dofile('tests/fixtures/rotation_execution.lua')
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

-- Builds the headless engine with the preview window recording what it is given.
-- @param engine string  "standard" or "lean".
-- @return table  The engine fixture, with .seen (the recommendations), .platform and .poll.
local function engine(engine)
    local c = make({ preview = 3, buttons = true, target = true, combat = true, engine = engine })
    local a, e = c.a, c.e
    c.load('Analytics/metrics.lua')
    c.load('Core/forecast.lua')
    c.load('Platform/forecast_events.lua')
    a.db.profile.preview_spells = 3
    local seen = {}
    local window = a.nextWindow
    local add = window.AddRecommendation

    window.AddRecommendation = function(self, spell, item, confidence)
        seen[#seen + 1] = { spell = spell, confidence = confidence }
        return add(self, spell, item, confidence)
    end

    c.seen = seen
    c.platform = a.Platform

    c.on = function(flag)
        a.IsForecastOn = function()
            return flag
        end
    end

    c.poll = function()
        for index = #seen, 1, -1 do
            seen[index] = nil
        end

        c.tick()
        return seen
    end

    return c
end

test('the spell being cast or channeled is read from the game, and nothing is read when the player is idle', function()
    local c = engine('standard')
    local e = c.e
    c.load('Platform/casting.lua')
    assert(c.a.Forecast:CastingSpell() == nil)

    e.UnitCastingInfo = function(unit)
        return unit == 'player' and 'Lightning Bolt' or nil, '', 1, 100000, 102000, false, 'castid', false, 403
    end

    assert(c.a.Forecast:CastingSpell() == 403, 'a cast')
    e.UnitCastingInfo = function() end

    e.UnitChannelInfo = function(unit)
        return unit == 'player' and 'Drain Life' or nil, '', 1, 100000, 105000, false, false, 689
    end

    assert(c.a.Forecast:CastingSpell() == 689, 'a channel')
end)

-- While a spell is being cast the rotation has stopped advising; the preview then shows what follows the spell being cast.
for _, kind in ipairs({ 'standard', 'lean' }) do
    test(kind .. ' engine: while casting, the preview shows what follows the spell being cast', function()
        local c = engine(kind)
        c.on(false)
        local a = c.a
        local asked
        local casting

        a.Platform.IsSpellReady = function() return false end
        a.Forecast.CastingSpell = function() return casting end

        a.Forecast.Run = function(_, _, first, count)
            asked = { first = first, count = count }
            return { { spell = 403, cond = { id = 'next', type = 'spell' }, index = 1, confidence = .9 } }
        end

        local seen = c.poll()
        assert(#seen == 0 and asked == nil, 'nothing is ready and nothing is being cast: the preview is empty')
        casting = 8042
        seen = c.poll()
        assert(asked and asked.first == 8042 and asked.count == 3, 'the forecast starts from the spell being cast')
        assert(#seen == 1 and seen[1].spell == 403, 'and its answer is what the preview shows')
    end)
end

for _, kind in ipairs({ 'standard', 'lean' }) do
    test(kind .. ' engine: with the switch off the preview is what it always was', function()
        local c = engine(kind)
        c.on(false)
        local seen = c.poll()
        assert(#seen >= 1 and seen[1].spell == 8042)

        for _, row in ipairs(seen) do
            assert(row.confidence == nil, 'nothing fades while the forecast is off')
        end
    end)

    test(
        kind .. ' engine: the first recommendation is read as before and the rest are predicted with a confidence',
        function()
            local c = engine(kind)
            c.on(false)
            local before = c.poll()[1].spell
            c.on(true)
            local seen = c.poll()
            assert(seen[1].spell == before and seen[1].confidence == nil)
            assert(#seen == 3, #seen)
            assert(seen[2].confidence and seen[3].confidence and seen[2].confidence > seen[3].confidence)
            assert(seen[2].confidence < 1 and seen[3].confidence > 0)
        end
    )

    test(kind .. ' engine: a spell with a cooldown is not predicted straight after being cast', function()
        local c = engine(kind)
        c.on(true)

        c.e.GetSpellBaseCooldown = function(id)
            return id == 8042 and 6000 or 0, 1500
        end

        local seen = c.poll()
        assert(seen[1].spell == 8042)

        for index = 2, #seen do
            assert(seen[index].spell ~= 8042, 'Earth Shock was just cast and has six seconds to go')
        end
    end)

    test(kind .. ' engine: the real readers are back after every poll', function()
        local c = engine(kind)

        local names = {
            'GetSpellCooldown',
            'IsSpellReady',
            'IsSpellUsable',
            'GetAuraByIndex',
            'GetUnitHealthObservation',
        }

        local before = {}

        for _, name in ipairs(names) do
            before[name] = c.platform[name]
        end

        c.on(true)
        c.poll()

        for _, name in ipairs(names) do
            assert(c.platform[name] == before[name], name)
        end
    end)
end

test('a forecast that errors costs the predictions, not the first recommendation', function()
    local c = engine('standard')
    c.on(true)
    c.a.EvaluateConditionWithCacheOriginal = c.a.evaluateConditionWithCache

    c.a.evaluateConditionWithCache = function()
        error('boom')
    end

    local seen = c.poll()
    assert(#seen == 1 and seen[1].spell == 8042)
    assert(#c.a.Diagnostics:GetReports() == 0, 'the failure is logged, not reported as an error')
end)

finish()
