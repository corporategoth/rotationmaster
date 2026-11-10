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

test('a pull in the projection puts the player in combat, so the out-of-combat Stop does not end every slot', function()
    local f, a, platform = client()
    local seen = {}

    f.world.base[A] = { 10000, 1500 }
    platform.GetUnitFlagObservation = function() return false end
    platform.GetClientFamily = function() return 'forever' end
    a.SpellEffectData = { forever = { rows = '100=t:900:1,h:1' } }
    a.Forecast:ResetEffects()

    function a:EvaluateRotationSequence(body, evaluate, visit)
        seen[#seen + 1] = platform:GetUnitFlagObservation('player', 'combat')

        if seen[#seen] == false then
            return { status = 'stopped' }
        end

        visit(body[1], 1)
        return { status = 'selected' }
    end

    local slots = a.Forecast:Run({ { spell = B, action = true } }, A, 2)
    assert(#slots == 2 and seen[1] == true, 'combat after a harmful first spell')
    assert(platform:GetUnitFlagObservation('player', 'combat') == false, 'the real reader is back')
    assert(platform:GetUnitFlagObservation('target', 'combat') == false)

    seen = {}
    assert(#a.Forecast:Run({ { spell = B, action = true } }, C, 2) == 0, 'a helpful first spell starts no combat')
end)

test(
    'an upkeep step is taken to apply its own debuff before anything has been learned, so it is not predicted again',
    function()
        local f, a, platform = client()
        local missing = { type = 'NOT', value = { type = 'DEBUFF', unit = 'target', spell = A } }

        -- The stub condition reads the projected aura list, as the real DEBUFF condition does.
        function a:evaluateConditionWithCache(condition)
            if condition == missing then
                for index = 1, 40 do
                    local aura = platform:GetAuraByIndex('target', index, 'HARMFUL')

                    if not aura then
                        break
                    end

                    if aura.spellID == A then
                        return { status = 'no-match' }
                    end
                end
            end

            return { status = 'match' }
        end

        local rot = {
            { spell = A, action = true, conditions = missing },
            { spell = B, action = true, conditions = {} },
        }

        local slots = a.Forecast:Run(rot, A, 3)
        assert(#slots == 3, #slots)

        for index, slot in ipairs(slots) do
            assert(slot.spell == B, 'slot ' .. index .. ' repeated the upkeep spell: ' .. tostring(slot.spell))
        end

        -- Once the spell has been watched leaving nothing, the rotation's hint is not used.
        a.Forecast:Known(A, true).none = 5
        slots = a.Forecast:Run(rot, A, 1)
        assert(slots[1].spell == A, 'a spell known to leave no aura is predicted again')
    end
)

test(
    'the game tables say what a cast leaves, so it is not predicted again, and what was seen wins over them',
    function()
        local f, a, platform = client()
        local missing = { type = 'NOT', value = { type = 'DEBUFF', unit = 'target', spell = 900 } }
        local noBuff = { type = 'NOT', value = { type = 'BUFF', unit = 'player', spell = 901 } }

        platform.GetClientFamily = function() return 'forever' end
        a.SpellEffectData = { forever = { rows = '500=t:900:12,p:901:0;600=t:900:12' } }
        a.Forecast:ResetEffects()

        local list = a.Forecast:Effects(500).auras
        assert(#list == 2 and list[1].unit == 'target' and list[1].aura == 900 and list[1].duration == 12)
        assert(list[2].unit == 'player' and list[2].aura == 901 and list[2].duration == 0)
        assert(a.Forecast:Effects(777) == nil)

        function a:evaluateConditionWithCache(condition)
            local unit, filter, wanted = 'target', 'HARMFUL', 900

            if condition == noBuff then
                unit, filter, wanted = 'player', 'HELPFUL', 901
            elseif condition ~= missing then
                return { status = 'match' }
            end

            for index = 1, 40 do
                local aura = platform:GetAuraByIndex(unit, index, filter)

                if not aura then
                    break
                end

                if aura.spellID == wanted then
                    return { status = 'no-match' }
                end
            end

            return { status = 'match' }
        end

        -- 500's own debuff and buff are in place after it, so the steps that wait for them fall through to the filler.
        local rot = {
            { spell = 700, action = true, conditions = missing },
            { spell = 701, action = true, conditions = noBuff },
            { spell = B, action = true, conditions = {} },
        }

        local slots = a.Forecast:Run(rot, 500, 1)
        assert(slots[1] and slots[1].spell == B, 'predicted ' .. tostring(slots[1] and slots[1].spell))

        -- A spell the tables do not know leaves nothing, so the step for the missing debuff comes up.
        slots = a.Forecast:Run(rot, 777, 1)
        assert(slots[1] and slots[1].spell == 700)

        -- What was seen of the spell on this client wins: it leaves a different aura, so the debuff is still missing.
        a.Forecast:Known(500, true).applies = { unit = 'target', aura = 902, duration = 5, n = 3 }
        slots = a.Forecast:Run(rot, 500, 1)
        assert(slots[1] and slots[1].spell == 700, 'seen data wins over the tables')

        -- And a spell watched leaving nothing is not given an aura from the tables.
        a.Forecast:Known(600, true).none = 5
        slots = a.Forecast:Run(rot, 600, 1)
        assert(slots[1] and slots[1].spell == 700)
    end
)

test(
    'the generated Forever table reads: Rend leaves its debuff for nine seconds, Battle Shout its buff on the player',
    function()
        local f, a, platform = client()

        platform.GetClientFamily = function() return 'forever' end
        f.load('Data/spell_effects_forever.lua')
        a.Forecast:ResetEffects()

        local rend = a.Forecast:Effects(772).auras
        assert(rend and rend[1].unit == 'target' and rend[1].aura == 772 and rend[1].duration == 9)
        local shout = a.Forecast:Effects(6673).auras
        assert(shout and shout[1].unit == 'player' and shout[1].duration == 180)

        platform.GetClientFamily = function() return 'retail' end
        a.SpellEffectData = nil
        f.load('Data/spell_effects_forever.lua')
        assert(a.SpellEffectData == nil, 'the Forever table is not loaded on another client')
    end
)

test('a stacking aura gains a stack per cast up to its most, and a refresh keeps the count', function()
    local f, a, platform = client()
    local seen = {}

    platform.GetClientFamily = function() return 'forever' end
    a.SpellEffectData = { forever = { rows = '500=t:900:30:3' } }
    a.Forecast:ResetEffects()
    f.world.auras['targetHARMFUL'] = { { name = 'Debuff', id = 900, duration = 30, expires = NOW + 20 } }

    function a:EvaluateRotationSequence(body, _, visit)
        local aura = platform:GetAuraByIndex('target', 1, 'HARMFUL')
        seen[#seen + 1] = aura and aura.applications
        visit(body[1], 1)
        return { status = 'selected' }
    end

    -- The stub aura reports no application count (one), so the first cast makes two; each pass reads the projected count.
    a.Forecast:Run({ { spell = 500, action = true } }, 500, 3)
    assert(seen[1] == 2 and seen[2] == 3 and seen[3] == 3, table.concat(seen, ','))
end)

test(
    'builders add points and a finisher spends them all, read through both point readers, and the real ones are back',
    function()
        local f, a, platform = client()
        local real = 2
        local seen = {}

        platform.GetClientFamily = function() return 'forever' end
        a.SpellEffectData = { forever = { rows = '500=g:4:1;600=f:4' } }
        a.Forecast:ResetEffects()

        platform.GetUnitPointPowerObservation = function(_, _, _, kind)
            return kind == 'maximum' and 5 or real
        end

        platform.GetPlayerComboPointObservation = function(_, _, kind)
            return kind == 'maximum' and 5 or real
        end

        function a:EvaluateRotationSequence()
            seen[#seen + 1] = {
                platform:GetUnitPointPowerObservation('player', 4, 'current'),
                platform:GetPlayerComboPointObservation(4, 'current'),
            }

            return { status = 'complete' }
        end

        a.Forecast:Run({ {} }, 500, 1)
        assert(seen[1][1] == 3 and seen[1][2] == 3, 'one builder: ' .. tostring(seen[1][1]))
        seen = {}
        real = 5
        a.Forecast:Run({ {} }, 500, 1)
        assert(seen[1][1] == 5, 'capped at the most')
        seen = {}
        a.Forecast:Run({ {} }, 600, 1)
        assert(seen[1][1] == 0 and seen[1][2] == 0, 'a finisher spends them all')
        assert(platform:GetUnitPointPowerObservation('player', 4, 'current') == 5, 'the real reader is back')
    end
)

test('a cost the game hides in combat is the last one it let be read, and a readable one replaces it', function()
    local f, a, platform = client()
    local secret = {}
    local mana

    f.env.GetManaRegen = function() return 0, 0 end

    local realCan = platform.CanReadValue

    function platform:CanReadValue(value)
        return value ~= secret and realCan(self, value)
    end

    function a:EvaluateRotationSequence()
        mana = platform:GetUnitPowerObservation('player', 'mana').current
        return { status = 'complete' }
    end

    f.world.cost[A] = 10
    a.Forecast:Run({ {} }, A, 1)
    assert(mana == 90, 'readable: ' .. tostring(mana))

    f.env.C_Spell.GetSpellPowerCost = function() return { { type = MANA, cost = secret } } end
    a.Forecast:Run({ {} }, A, 1)
    assert(mana == 90, 'hidden: the last readable cost still counts: ' .. tostring(mana))

    -- Never read: nothing is guessed.
    a.Forecast:Run({ {} }, B, 1)
    assert(mana == 100, 'unknown cost: ' .. tostring(mana))

    -- Gear or a talent changed the cost out of combat: the new reading replaces the old.
    f.env.C_Spell.GetSpellPowerCost = function() return { { type = MANA, cost = 25 } } end
    a.Forecast:Run({ {} }, A, 1)
    assert(mana == 75, 'changed: ' .. tostring(mana))
    f.env.C_Spell.GetSpellPowerCost = function() return { { type = MANA, cost = secret } } end
    a.Forecast:Run({ {} }, A, 1)
    assert(mana == 75, 'hidden again: ' .. tostring(mana))
end)

test('a projection of standing still reads no movement, and the real reader is back after', function()
    local f, a, platform = client()
    platform.GetPlayerMovementObservation = function() return { speed = 7 } end
    assert(a.Forecast:PlayerMoving() == true)
    local seen = {}

    function a:EvaluateRotationSequence()
        seen[#seen + 1] = platform:GetPlayerMovementObservation().speed
        return { status = 'complete' }
    end

    a.Forecast:Wait({ {} }, 1, true)
    assert(seen[1] == 0, 'standing still')
    seen = {}
    a.Forecast:Wait({ {} }, 1, false)
    assert(seen[1] == 7, 'as the player is')
    assert(platform:GetPlayerMovementObservation().speed == 7 and a.Forecast:PlayerMoving())
    platform.GetPlayerMovementObservation = function() return { speed = 0 } end
    assert(a.Forecast:PlayerMoving() == false)
end)

test('a hidden cooldown counts from the last cast, and the pass jumps to when it ends', function()
    local f, a, platform = client()
    f.world.base[B] = { 6000, 1500 }
    platform.GetSpellCooldown = function() return nil, 'restricted-value' end
    platform.IsSpellReady = function() return false end
    a.Forecast:NoteCast(B, NOW - 4)
    local slots = a.Forecast:Run({ { spell = B, action = true } }, A, 1)
    assert(#slots == 1, 'the spell comes back once its cooldown is over')
    assert(math.abs(slots[1].delay - 2) < 0.1, 'cast four seconds ago of six: ' .. tostring(slots[1].delay))
end)

test('a readable cooldown is waited out exactly, not to the next whole second', function()
    local f, a = client()
    f.world.cooldown[B] = { startTime = NOW - 0.6, duration = 6, isEnabled = true, modRate = 1 }
    local slots = a.Forecast:Wait({ { spell = B, action = true } }, 1)
    assert(#slots == 1 and math.abs(slots[1].delay - 5.4) < 0.1, tostring(slots[1] and slots[1].delay))
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

        assert(seen[1] == false, 'a six second cooldown has not run out yet')
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

test('the tables give the resources a spell gains and costs and its school, read from the generated rows', function()
    local f, a, platform = client()

    platform.GetClientFamily = function() return 'forever' end
    a.SpellEffectData = { forever = { rows = '500=e:1:20,c:1:30:0,h:32;501=c:0:5:2.5' } }
    a.Forecast:ResetEffects()

    local row = a.Forecast:Effects(500)
    assert(row.gains[1] == 20 and row.costs[1].flat == 30 and row.costs[1].percent == 0)
    assert(row.harmful == true and row.school == 32)
    assert(a.Forecast:Effects(501).costs[0].flat == 5 and a.Forecast:Effects(501).costs[0].percent == 2.5)
end)

test('a resource a spell gives is there for the steps after it, and regeneration still adds to it', function()
    local f, a, platform = client()
    local seen = {}

    platform.GetClientFamily = function() return 'forever' end
    a.SpellEffectData = { forever = { rows = '500=e:0:50' } }
    a.Forecast:ResetEffects()

    function a:EvaluateRotationSequence()
        seen[#seen + 1] = platform:GetUnitPowerObservation('player', 'mana').current
        return { status = 'complete' }
    end

    a.Forecast:Run({ {} }, 500, 1)
    assert(math.abs(seen[1] - (100 + 50 + 5 * 1.5)) < 1e-9, tostring(seen[1]))
end)

test(
    'a cost the game will not say is taken from the tables, a percentage of the base mana learned from a spell that can be read',
    function()
        local f, a, platform = client()
        local seen = {}
        local level = 60

        platform.GetClientFamily = function() return 'forever' end
        platform.GetUnitLevelObservation = function() return { exists = true, level = level } end
        a.SpellEffectData = { forever = { rows = '500=c:0:20:0;501=c:0:0:10;502=c:0:5:2' } }
        a.Forecast:ResetEffects()

        -- The game hides the costs of 500 and 501 (secret numbers) and shows 502's.
        f.env.C_Spell.GetSpellPowerCost = function(spell)
            if spell == 502 then
                return f.world.cost[502] and { { type = MANA, cost = f.world.cost[502] } } or {}
            end

            return { { type = MANA, cost = 'secret' } }
        end

        function a:EvaluateRotationSequence(body, _, visit)
            seen[#seen + 1] = platform:GetUnitPowerObservation('player', 'mana').current
            visit(body[1], 1)
            return { status = 'selected' }
        end

        -- A flat cost needs no base mana: 100 less 20, plus a second and a half of regeneration.
        local slots = a.Forecast:Run({ { spell = B, action = true } }, 500, 1)
        assert(math.abs(seen[1] - (100 - 20 + 7.5)) < 1e-9, tostring(seen[1]))
        assert(math.abs(slots[1].confidence - 0.9 * 0.97) < 1e-9, 'a guessed cost costs a little confidence')

        -- A percentage cannot be worked out until a spell with one has been read: 25 mana is 5 and 2% of 1000.
        seen = {}
        a.Forecast:Run({ {} }, 501, 1)
        assert(math.abs(seen[1] - (100 + 7.5)) < 1e-9, 'no base mana known yet: nothing is spent')

        f.world.cost[502] = 25
        a.Forecast:Run({ {} }, 502, 1)
        f.world.cost[502] = nil
        seen = {}
        a.Forecast:Run({ {} }, 501, 1)
        assert(math.abs(seen[1] - (100 - 100 + 7.5)) < 1e-9, 'ten percent of 1000 base mana: ' .. tostring(seen[1]))
        assert(a.db.global.forecast.base.mana == 1000 and a.db.global.forecast.base.level == 60)

        -- A new level starts it over.
        level = 61
        seen = {}
        a.Forecast:Run({ {} }, 501, 1)
        assert(math.abs(seen[1] - (100 + 7.5)) < 1e-9, 'a different level: the base mana is not known')
    end
)

test(
    'an item the steps use is on its cooldown afterwards, so it is not predicted again, and its cooldown is learned',
    function()
        local f, a, platform = client()
        local USE, ITEM = 1500, 9001
        local itemCooldown = { startTime = 0, duration = 0, isEnabled = true }

        platform.GetItemID = function(_, item) return item end
        platform.GetItemUseSpell = function() return { name = 'Potion', spellID = USE } end
        platform.GetItemCooldown = function() return itemCooldown end

        platform.IsItemReady = function(self, item, now)
            local row = self:GetItemCooldown(item)
            return row.duration == 0 or row.startTime + row.duration <= now
        end

        function a:GetSpellIds(step)
            return { step.spell }, { step.item }
        end

        function a:NewActionReadiness(now)
            return function(kind, id, item)
                if kind == 'item' then
                    return platform:IsItemReady(item, now) == true
                end

                return platform:IsSpellReady(id, now) and platform:IsSpellUsable(id) == true
            end
        end

        local rot = { { type = 'item', spell = USE, item = ITEM, action = true }, { spell = B, action = true } }

        -- Never seen: used once for the window, at a small cost in confidence.
        local slots = a.Forecast:Run(rot, USE, 2)
        assert(slots[1] and slots[1].spell == B and slots[2] and slots[2].spell == B, 'the item is not predicted again')
        assert(math.abs(slots[1].confidence - 0.95 * 0.9) < 1e-9, tostring(slots[1].confidence))

        -- Without the cast, the same item step is first.
        slots = a.Forecast:Run(rot, B, 1)
        assert(slots[1].spell == USE)

        -- Seen cooling down for two minutes: remembered, and no longer a guess.
        itemCooldown = { startTime = 95, duration = 120, isEnabled = true }
        a.Forecast:Run(rot, B, 1)
        assert(a.Forecast:Known(USE).cooldown == 120)
        itemCooldown = { startTime = 0, duration = 0, isEnabled = true }
        slots = a.Forecast:Run(rot, USE, 1)

        assert(math.abs(slots[1].confidence - 0.9) < 1e-9, 'a known cooldown is no guess: ' .. slots[1].confidence)

        assert(platform:GetItemCooldown(ITEM).duration == 0, 'the real reader is back')
    end
)

test(
    'an aura seen after only some casts is projected when it is the likelier outcome, and then costs confidence',
    function()
        local f, a, platform = client()
        local seen

        function a:EvaluateRotationSequence(body, _, visit)
            seen = platform:GetAuraByIndex('target', 1, 'HARMFUL')
            visit(body[1], 1)
            return { status = 'selected' }
        end

        local entry = a.Forecast:Known(500, true)
        entry.casts, entry.seen = 10, { [900] = { unit = 'target', duration = 10, n = 3 } }
        a.Forecast:Run({ {} }, 500, 1)
        assert(seen == nil, 'three in ten is a proc, not what the spell applies')

        entry.seen[900].n = 7
        local slots = a.Forecast:Run({ { spell = B, action = true } }, 500, 1)
        assert(seen and seen.spellID == 900, 'seven in ten is the likelier outcome')
        assert(math.abs(slots[1].confidence - 0.85 * 0.9) < 1e-9, tostring(slots[1].confidence))

        entry.seen[900].n = 10
        slots = a.Forecast:Run({ { spell = B, action = true } }, 500, 1)
        assert(math.abs(slots[1].confidence - 0.9) < 1e-9, 'every cast: no cost')

        -- A single sighting is taken at the least number of casts, so it counts.
        entry.casts, entry.seen[900].n = 1, 1
        a.Forecast:Run({ {} }, 500, 1)
        assert(seen and seen.spellID == 900)
    end
)

test('the chance of a miss, from the levels, costs a share of the confidence', function()
    local f, a, platform = client()
    local flags = function(_, _, kind) return kind == 'enemy' end

    platform.GetClientFamily = function() return 'forever' end
    platform.GetUnitFlagObservation = flags

    local targetLevel = 63

    platform.GetUnitLevelObservation = function(_, unit)
        return { exists = true, level = unit == 'player' and 60 or targetLevel }
    end

    a.SpellEffectData = { forever = { rows = '500=h:1;501=h:32' } }
    a.Forecast:ResetEffects()

    -- Physical: 8% at three levels above, half of it costs confidence.
    local slots = a.Forecast:Run({ { spell = B, action = true } }, 500, 1)
    assert(math.abs(slots[1].confidence - 0.9 * (1 - 0.08 * 0.5)) < 1e-9, tostring(slots[1].confidence))

    -- A spell: 17% at three levels above, and 4% at the same level.
    slots = a.Forecast:Run({ { spell = B, action = true } }, 501, 1)
    assert(math.abs(slots[1].confidence - 0.9 * (1 - 0.17 * 0.5)) < 1e-9, tostring(slots[1].confidence))
    targetLevel = 60
    slots = a.Forecast:Run({ { spell = B, action = true } }, 501, 1)
    assert(math.abs(slots[1].confidence - 0.9 * (1 - 0.04 * 0.5)) < 1e-9, tostring(slots[1].confidence))

    -- Not aimed at an enemy, or no enemy to miss, or Retail: nothing.
    assert(math.abs(a.Forecast:Run({ { spell = B, action = true } }, C, 1)[1].confidence - 0.9) < 1e-9)
    platform.GetUnitFlagObservation = function() return false end
    assert(math.abs(a.Forecast:Run({ { spell = B, action = true } }, 500, 1)[1].confidence - 0.9) < 1e-9)
    platform.GetUnitFlagObservation = flags
    platform.GetClientFamily = function() return 'retail' end
    assert(math.abs(a.Forecast:Run({ { spell = B, action = true } }, 500, 1)[1].confidence - 0.9) < 1e-9)
end)

test(
    'a spell told to be ignored is forgotten and nothing is learned or used about it until it is not ignored',
    function()
        local f, a = client()
        local entry = a.Forecast:Known(500, true)
        entry.damage = 10
        assert(a.Forecast:Known(500) == entry and not a.Forecast:IsIgnored(500))

        a.Forecast:Ignore(500, true)
        assert(a.Forecast:IsIgnored(500) and a.Forecast:Known(500) == nil, 'what it had is forgotten')
        assert(a.Forecast:Known(500, true) == nil, 'and no record is made')

        a.Forecast:Ignore(500, false)
        assert(not a.Forecast:IsIgnored(500) and a.Forecast:Known(500, true) ~= nil, 'learning again')
    end
)

test('the Forever table has the racial that gives an aura, as Walk on Air does', function()
    local f, a, platform = client()

    platform.GetClientFamily = function() return 'forever' end
    f.load('Data/spell_effects_forever.lua')
    a.Forecast:ResetEffects()

    local row = a.Forecast:Effects(1259416)
    assert(row and row.auras[1] and row.auras[1].aura == 1259416 and row.auras[1].unit == 'player')
end)

finish()
