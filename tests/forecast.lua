-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- addon.Forecast (Core/forecast.lua): the projected readers (cooldown, readiness, charges, usability, power, auras, health),
-- the pass loop that predicts the recommendations after the first, the confidence, and that the real readers are always put
-- back. The conditions and the rotation executor are stubbed here; tests/forecast_engine.lua runs the real ones.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local NOW = 100
local MANA = 0

-- Builds the addon with Core/forecast.lua loaded over a platform whose readers answer from `world`.
-- @return table  The fixture, the world and the stub counters.
local function client()
    local f = F.new(5, 1, 'MAGE')
    local e, a = f.env, f.addon
    local platform = a.Platform

    local world = {
        cooldown = {},
        mana = { current = 100, maximum = 200 },
        auras = {},
        health = { target = { current = 1000, maximum = 1000 }, player = { current = 500, maximum = 1000 } },
        cost = {},
        base = {},
        cast = {},
        steps = {},
    }

    e.Enum = { PowerType = { Mana = MANA, Energy = 3 } }

    e.GetTime = function()
        return NOW
    end

    e.GetManaRegen = function()
        return 0, 5
    end

    e.GetSpellBaseCooldown = function(spell)
        local row = world.base[spell]
        return row and row[1] or 0, row and row[2] or 1500
    end

    e.C_Spell = {
        GetSpellPowerCost = function(spell)
            return world.cost[spell] and { { type = MANA, cost = world.cost[spell] } } or {}
        end,
    }

    function platform:GetSpellInfo(spell)
        return { name = 'Spell ' .. spell, castTime = (world.cast[spell] or 0) * 1000 }
    end

    function platform:GetGlobalCooldown()
        return { startTime = 0, duration = 0 }
    end

    function platform:GetSpellCooldown(spell)
        return world.cooldown[spell] or { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
    end

    function platform:IsSpellReady(spell, now)
        local row = self:GetSpellCooldown(spell)
        return row.duration == 0 or row.startTime + row.duration <= now
    end

    function platform:GetSpellCharges()
        return nil, 'spell-charges-unavailable'
    end

    function platform:IsSpellUsable(spell)
        local cost = world.cost[spell]
        return true, cost ~= nil and cost > world.mana.current
    end

    function platform:GetUnitPowerObservation(unit, resource)
        if unit ~= 'player' then
            return { exists = false }
        end

        return { exists = true, powerType = MANA, current = world.mana.current, maximum = world.mana.maximum }
    end

    function platform:GetAuraByIndex(unit, index, filter)
        local row = world.auras[unit .. filter] and world.auras[unit .. filter][index]
        return row and { name = row.name, spellID = row.id, duration = row.duration, expirationTime = row.expires }
    end

    function platform:GetUnitHealthObservation(unit)
        local row = world.health[unit]
        return row and { exists = true, current = row.current, maximum = row.maximum } or { exists = false }
    end

    a.db = { global = {}, profile = {} }
    f.load('Core/forecast.lua')

    -- Stubs for the executor, the conditions and the bars: the steps in world.steps are tried in order.
    local counts = { passes = 0 }

    function a:EvaluateRotationSequence(body, evaluate, visit)
        counts.passes = counts.passes + 1

        for index, step in ipairs(body) do
            if visit(step, index) == false then
                return { status = 'selected' }
            end
        end

        return { status = 'complete' }
    end

    function a:evaluateConditionWithCache(condition)
        return { status = condition == false and 'no-match' or 'match' }
    end

    function a:GetSpellIds(step)
        return { step.spell }
    end

    function a:FindSpell(ids)
        return ids[1]
    end

    function a:NewActionReadiness(now)
        return function(kind, id)
            return platform:IsSpellReady(id, now) and platform:IsSpellUsable(id) == true
        end
    end

    f.world, f.counts = world, counts
    return f, a, platform
end

local A, B, C = 100, 200, 300

test('a cast spell is on cooldown in the projected state and the others have moved on in time', function()
    local f, a, platform = client()
    f.world.base[A] = { 10000, 1500 }
    f.world.cooldown[B] = { startTime = 98, duration = 30, isEnabled = true, modRate = 1 }
    f.world.cooldown[C] = { startTime = 98, duration = 3, isEnabled = true, modRate = 1 }
    local seen = {}
    local original = platform.IsSpellReady

    function a:EvaluateRotationSequence(body, evaluate, visit)
        seen.a = platform:GetSpellCooldown(A)
        seen.b = platform:GetSpellCooldown(B)

        seen.aReady, seen.bReady, seen.cReady =
            platform:IsSpellReady(A, NOW), platform:IsSpellReady(B, NOW), platform:IsSpellReady(C, NOW)
    end

    a.Forecast:Run({ {} }, A, 1)
    -- After the first cast the next decision is 1.5 seconds on: A has 10 seconds from its cast, B has 30 - 2 - 1.5 left.
    assert(seen.a.startTime + seen.a.duration - NOW == 8.5, seen.a.startTime + seen.a.duration - NOW)
    assert(seen.b.startTime + seen.b.duration - NOW == 26.5)
    assert(not seen.aReady and not seen.bReady, 'A and B are still cooling down')
    assert(seen.cReady, 'C\'s three seconds ended before the projected time')
    assert(platform.IsSpellReady == original, 'the real reader is back')
end)

test('power is spent by the predicted casts and regenerates over the time they take', function()
    local f, a, platform = client()
    f.world.cost[A] = 30
    f.world.cost[B] = 90
    local seen = {}

    function a:EvaluateRotationSequence()
        seen.power = platform:GetUnitPowerObservation('player', 'mana', true)
        seen.usable = { platform:IsSpellUsable(B) }
    end

    a.Forecast:Run({ {} }, A, 1)
    assert(seen.power.current == 100 - 30 + 5 * 1.5, seen.power.current)
    assert(seen.usable[1] == false and seen.usable[2] == true, 'B costs 90 and only 77.5 will be there')
    assert(platform:GetUnitPowerObservation('player', 'mana', true).current == 100)
end)

test('auras age, expire, and the ones a predicted spell is known to apply appear', function()
    local f, a, platform = client()

    f.world.auras['targetHARMFUL'] = {
        { name = 'Short', id = 1, duration = 6, expires = NOW + 2 },
        { name = 'Long', id = 2, duration = 30, expires = NOW + 20 },
    }

    a.Forecast:Known(A, true).applies = { unit = 'target', aura = 77, duration = 12 }
    local seen = {}

    function a:EvaluateRotationSequence()
        seen.list = {}

        for index = 1, 5 do
            local aura = platform:GetAuraByIndex('target', index, 'HARMFUL')

            if not aura then
                break
            end

            seen.list[aura.spellID] = aura.expirationTime - NOW
        end
    end

    a.Forecast:Run({ {} }, A, 1)
    assert(seen.list[1] == nil or seen.list[1] > 0, 'an aura that has ended by then is gone or has time left')
    assert(seen.list[1] == 0.5, 'Short had 2 seconds, 1.5 have passed')
    assert(seen.list[2] == 18.5)
    assert(seen.list[77] == 10.5, 'the applied aura has its 12 seconds minus the time since the cast')
end)

test('an aura that has expired by the projected time is dropped', function()
    local f, a, platform = client()
    f.world.auras['targetHARMFUL'] = { { name = 'Gone', id = 1, duration = 6, expires = NOW + 1 } }
    local found

    function a:EvaluateRotationSequence()
        found = platform:GetAuraByIndex('target', 1, 'HARMFUL')
    end

    a.Forecast:Run({ {} }, A, 1)
    assert(found == nil)
end)

test(
    'health takes off the damage a predicted spell is known to do and adds the healing it does to the player',
    function()
        local f, a, platform = client()
        a.Forecast:Known(A, true).damage = 300
        a.Forecast:Known(B, true).heal = 200
        local seen = {}

        function a:EvaluateRotationSequence()
            seen.target = platform:GetUnitHealthObservation('target').current
            seen.player = platform:GetUnitHealthObservation('player').current
        end

        a.Forecast:Run({ {} }, A, 1)
        assert(seen.target == 700 and seen.player == 500)
        a.Forecast:Run({ {} }, B, 1)
        assert(seen.player == 700)
    end
)

test('the pass picks the first ready step each time, and a spell on cooldown is not predicted again', function()
    local f, a = client()
    f.world.base[A] = { 10000, 1500 }
    local steps = { { spell = A, action = true }, { spell = B, action = true } }
    local slots = a.Forecast:Run(steps, A, 3)
    assert(#slots == 3 and f.counts.passes == 3)
    assert(slots[1].spell == B and slots[2].spell == B and slots[3].spell == B, 'A is cooling down, B repeats')
    assert(slots[1].at == 3 and slots[3].at == 6, 'each takes a global cooldown')
    assert(slots[1].confidence > slots[2].confidence and slots[2].confidence > slots[3].confidence)
    assert(slots[2].confidence < slots[1].confidence * 0.9 + 1e-9, 'a repeat costs confidence')
    assert(slots[1].confidence <= 0.9 and slots[1].confidence > 0.05)
end)

test(
    'with every spell cooling down the pass moves forward, and each slot says when it follows the first spell',
    function()
        local f, a = client()
        f.world.base[A] = { 6000, 0 }
        local slots = a.Forecast:Run({ { spell = A, action = true } }, A, 2)
        assert(#slots >= 1, 'the first spell is cast again once its cooldown has run out')
        assert(slots[1].delay >= 6 and slots[1].delay <= 8, slots[1].delay)
        assert(slots[2] == nil or slots[2].delay > slots[1].delay)
        assert(slots[1].confidence < 0.9, 'waiting costs confidence')
    end
)

test('a cast already under way counts from now, and a later slot is never surer than an earlier one', function()
    local f, a = client()
    f.world.cast[A] = 3
    local steps = { { spell = B, action = true } }
    local full = a.Forecast:Run(steps, A, 1)
    local partway = a.Forecast:Run(steps, A, 1, 1)
    assert(full[1].delay == 3 and partway[1].delay == 1, 'the cast has one second left: ' .. tostring(partway[1].delay))
    local slots = a.Forecast:Run(steps, A, 4)
    assert(#slots == 4)

    for index = 2, #slots do
        assert(slots[index].confidence <= slots[index - 1].confidence)
    end
end)

test('the pass is judged by the preview readiness options', function()
    local f, a = client()
    local outputs = {}
    local original = a.NewActionReadiness

    function a:NewActionReadiness(now, output)
        outputs[#outputs + 1] = output
        return original(self, now, output)
    end

    a.Forecast:Run({ { spell = B, action = true } }, A, 1)
    assert(#outputs > 0 and outputs[1] == 'preview', tostring(outputs[1]))
end)

test('cast time longer than the global cooldown sets the step, and costs a little confidence', function()
    local f, a = client()
    f.world.cast[A] = 3
    local slots = a.Forecast:Run({ { spell = B, action = true } }, A, 1)
    assert(slots[1].at == 3 + 1.5, slots[1].at)
    local f2, a2 = client()
    local slots2 = a2.Forecast:Run({ { spell = B, action = true } }, A, 1)
    assert(slots[1].confidence < slots2[1].confidence)
end)

test('nothing ready ends the forecast early and a failing pass leaves the real readers in place', function()
    local f, a, platform = client()
    local steps = { { spell = A, action = true } }
    f.world.cooldown[A] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
    assert(#a.Forecast:Run(steps, B, 3) == 0)

    local before = {
        platform.GetSpellCooldown,
        platform.IsSpellReady,
        platform.GetUnitPowerObservation,
        platform.GetAuraByIndex,
    }

    function a:EvaluateRotationSequence()
        error('boom')
    end

    assert(#a.Forecast:Run(steps, B, 3) == 0)

    assert(
        platform.GetSpellCooldown == before[1]
            and platform.IsSpellReady == before[2]
            and platform.GetUnitPowerObservation == before[3]
            and platform.GetAuraByIndex == before[4]
    )

    assert(#a.Forecast:Run(steps, B, 3) == 0, 'and the next call works again')
end)

test('the player is not casting in the projected state, so a casting Stop does not end every pass', function()
    local f, a, platform = client()
    local seen

    platform.GetUnitCastObservation = function() return { active = true, spellID = A } end

    function a:EvaluateRotationSequence()
        seen = platform:GetUnitCastObservation('player', 'cast')
        return { status = 'complete' }
    end

    a.Forecast:Run({ {} }, A, 1)
    assert(seen and seen.active == false, 'projected: the cast has finished')
    assert(platform:GetUnitCastObservation('player', 'cast').active == true, 'and the real reader is back')
end)

test(
    'with the cooldown times hidden, a spell not ready now is taken as ready once its own cooldown has gone by',
    function()
        local f, a, platform = client()
        local seen = {}

        f.world.base[B] = { 6000, 1500 }
        platform.GetSpellCooldown = function() return nil, 'restricted-value' end
        platform.IsSpellReady = function() return false end

        function a:EvaluateRotationSequence()
            seen[#seen + 1] = platform:IsSpellReady(B, 100)
            return { status = 'complete' }
        end

        a.Forecast:Run({ {} }, A, 3)

        assert(seen[1] == false and seen[2] == false and seen[3] == false, 'a six second cooldown has not run out yet')
        assert(seen[#seen] == true, 'and has once the projected time has gone past it')
    end
)

test('hidden values stay hidden: a restricted cooldown is passed through, not shifted', function()
    local f, a, platform = client()
    f.world.cooldown[A] = { startTime = 'secret', duration = 'secret', isEnabled = true }
    local seen

    function a:EvaluateRotationSequence()
        seen = platform:GetSpellCooldown(A)
    end

    a.Forecast:Run({ {} }, B, 1)
    assert(seen.startTime == 'secret' and seen.duration == 'secret')
end)

test('the measured hit rate of earlier forecasts is blended into the confidence', function()
    local f, a = client()
    local plain = a.Forecast:Run({ { spell = B, action = true } }, A, 1)[1].confidence
    a.Metrics = { PredictionRate = function(_, slot) return slot == 2 and 0.1 or nil end }
    local blended = a.Forecast:Run({ { spell = B, action = true } }, A, 1)[1].confidence
    assert(math.abs(blended - (plain + 0.1) / 2) < 1e-9)
end)

finish()
