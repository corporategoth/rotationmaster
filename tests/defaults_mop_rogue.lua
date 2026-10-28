-- Mists of Pandaria Classic Rogue premades: Assassination, Combat and Subtlety (recommended), the Subterfuge Subtlety
-- premade (auto-selected on tier-1 talent 2), the disabled source variants (Assassination Icy Veins, Combat Sinister
-- Strike builder, Combat Hekili) and the Unspecialized catch-all. Real predicates, catalog, composition, sequence
-- executor, readiness and publisher on a modeled 5.5.4 client (tests/fixtures/mop_premade_model_b.lua).
local M = dofile('tests/fixtures/mop_premade_model_b.lua')
local test, finish = M.F.suite()

local ASSA, ASSA_IV, COMBAT, COMBAT_IV, COMBAT_HK =
    'rm.mop.rogue.assassination',
    'rm.mop.rogue.assassination.icyveins',
    'rm.mop.rogue.combat',
    'rm.mop.rogue.combat.icyveins',
    'rm.mop.rogue.combat.hekili'

local SUB, SUB_WT, START = 'rm.mop.rogue.subtlety', 'rm.mop.rogue.subtlety.warcrafttavern', 'rm.mop.rogue.unspecialized'
local ALL = { ASSA, ASSA_IV, COMBAT, COMBAT_IV, COMBAT_HK, SUB, SUB_WT, START }

-- The specialization follows its signature spell in the kit (as choosing one teaches it); daggers in both hands.
local function rogue(level, ...)
    local f, s = M.fixture('ROGUE', { level = level })
    M.know(s, 6603, 1752, 2098, 1784)

    for _, set in ipairs({ ... }) do
        M.know(s, unpack(set))
    end

    s.range[6603] = true
    s.usable[1784] = false
    s.gear = { [16] = M.DAGGER, [17] = M.DAGGER }

    if level >= 10 then
        for _, pair in ipairs({ { 1329, 259 }, { 13877, 260 }, { 16511, 261 }, { 31223, 261 } }) do
            if s.known[pair[1]] then
                s.specID(pair[2])
            end
        end
    end

    return f, s
end

local assassination = {
    1329, 5171, 73651, 32645, 1833, 111240, 408, 1943, 703, 51723, 1856, 14185, 79140, 121411, 121471, 1766, 2823, 3408
}

local combat = {
    13877, 5171, 73651, 84617, 1833, 13750, 408, 1943, 51723, 1856, 14185, 51690, 121411, 121471, 8676, 1766, 2823, 3408
}

local subtlety = {
    16511, 31223, 5171, 73651, 14183, 53, 408, 1943, 703, 51723, 1856, 14185, 51713, 121411, 121471, 8676, 1766, 2823,
    3408
}

local function first(f, s, id)
    return (M.first(f, s, id))
end

local function sliced(s, left)
    s.buffs[#s.buffs + 1] = { id = 5171, expires = 100 + (left or 30) }
end

local function stopped(f, s, id, suppress, label)
    local x, r = M.first(f, s, id)

    assert(
        not x and r.status == 'stopped',
        (label or id) .. ': expected a Stop, got ' .. tostring(x) .. ' ' .. tostring(r.status)
    )

    if suppress ~= nil then
        assert(
            (r.suppressAttack == true) == suppress,
            (label or id) .. ': suppressAttack ' .. tostring(r.suppressAttack)
        )
    end
end

test(
    'switches: catch-all below 10 and without a spec, one premade per specialization, Subterfuge picks the Tavern premade',
    function()
        local f, s = rogue(5)
        assert(M.scoped(f, 'ROGUE') == 8)
        assert(M.selected(f, s) == START and M.ordered(f, s) == START, 'level 5')
        s.specID(261)
        assert(M.selected(f, s) == START and M.ordered(f, s) == START, 'levels 1-9 stay in the catch-all')
        s.spec = nil
        s.level = 12
        M.know(s, 1329, 13877, 16511)
        assert(M.selected(f, s) == START and M.ordered(f, s) == START, 'level 12 without a specialization')

        for _, case in ipairs({ { 259, ASSA }, { 260, COMBAT }, { 261, SUB } }) do
            local g, t = rogue(40)
            t.specID(case[1])
            assert(M.selected(g, t) == case[2] and M.ordered(g, t) == case[2], 'specialization ' .. case[1])

            for _, other in ipairs({ ASSA, COMBAT, SUB }) do
                if other ~= case[2] then
                    assert(not M.switches(g, other), other .. ' also matches ' .. case[1])
                end
            end
        end

        local g, t = rogue(90, { 16511 })
        t.talents[2] = true
        assert(M.selected(g, t) == SUB_WT and M.ordered(g, t) == SUB_WT, 'Subterfuge talented')
        t.talents[2] = false
        t.talents[3] = true
        assert(M.selected(g, t) == SUB, 'Shadow Focus keeps the recommended premade')
        g, t = rogue(90, { 13877 })
        t.talents[18] = true
        assert(M.switches(g, COMBAT_HK) and M.selected(g, t) == COMBAT, 'the Hekili variant ships off')
    end
)

test('variants ship disabled at a lower priority and take over only when chosen', function()
    local f, s = rogue(90, { 13877 })
    s.talents[18] = true
    local a = f.addon
    local rows = {}

    for _, row in ipairs(a:ListDefaultRotations(1)) do
        rows[row.id] = row
    end

    for _, id in ipairs({ ASSA_IV, COMBAT_IV, COMBAT_HK }) do
        assert(not rows[id].eligible and rows[id].eligibilityReason == 'disabled', id)
        assert(M.body(a, id).priority == 20)
    end

    -- Each is eligible in its own specialization only (body.specs).
    for _, id in ipairs({ ASSA, COMBAT, SUB }) do
        assert(
            (rows[id].eligible or rows[id].eligibilityReason == 'specialization-mismatch')
                and M.body(a, id).priority == 30,
            id
        )
    end

    assert(M.body(a, SUB_WT).priority == 35 and not M.body(a, SUB_WT).disabled and M.body(a, START).priority == 1)
    assert(a:SetDefaultRotationEnabled(COMBAT_IV, true))
    assert(M.selected(f, s) == COMBAT, 'enabled but lower priority')
    assert(a:SetDefaultRotationEnabled(COMBAT, false))
    assert(M.selected(f, s) == COMBAT_IV)
    assert(a:SetDefaultRotationEnabled(COMBAT_HK, true))
    assert(M.selected(f, s) == COMBAT_IV or M.selected(f, s) == COMBAT_HK)
    assert(a:SetDefaultRotationEnabled(COMBAT_IV, false))
    assert(M.selected(f, s) == COMBAT_HK)
    s.talents[18] = false

    assert(
        M.selected(f, s) == START,
        'Hekili needs Anticipation; with every other Combat premade off the catch-all is left'
    )
end)

test('dual spec: each talent group selects by its own specialization', function()
    local f, s = rogue(90, { 1329 })
    assert(M.selected(f, s) == ASSA)
    s.talentGroup = 2
    s.specID(261)
    assert(M.selected(f, s) == SUB and M.ordered(f, s) == SUB, 'group 2')
    s.talentGroup = 1
    s.specID(259)
    assert(M.selected(f, s) == ASSA)
end)

test('casts, channels and a missing target stop with Attack suppressed in every premade', function()
    for _, id in ipairs(ALL) do
        local f, s = rogue(90, assassination, combat, subtlety)

        for _, key in ipairs({ 'cast', 'channel' }) do
            s[key] = true
            stopped(f, s, id, true, id .. ' ' .. key)
            s[key] = false
        end

        s.hostile = false
        stopped(f, s, id, true, id .. ' no target')
        s.hostile = true
        assert(first(f, s, id) ~= nil, id .. ' recommends something with a target')
    end
end)

test('out of combat: Stealth, then stop and let Attack start a body pull', function()
    for _, id in ipairs(ALL) do
        local f, s = rogue(90, assassination, combat, subtlety)
        s.combat = false
        s.usable[1784] = nil
        assert(first(f, s, id) == 1784, id)
        s.usable[1784] = false
        stopped(f, s, id, false, id .. ' Stealth not ready')
    end
end)

test('Backstab and Dispatch need a dagger in the main hand; Ambush and Mutilate do not', function()
    local f, s = rogue(90, subtlety)
    sliced(s)
    s.debuffs = { { id = 89775, expires = 120 } }
    s.targettarget = 'party1'
    assert(first(f, s, SUB) == 53 and first(f, s, SUB_WT) == 53, 'dagger: Backstab from behind')
    s.gear = { [16] = M.SWORD, [17] = M.DAGGER }
    assert(first(f, s, SUB) == 16511 and first(f, s, SUB_WT) == 16511, 'a sword in the main hand: Hemorrhage')
    s.gear = {}
    assert(first(f, s, SUB) == 16511, 'no weapon: Hemorrhage')
    s.gear = { [16] = { 7099, 2, 15, 'INVTYPE_WEAPON' } }
    f.env.GetItemInfoInstant = function() end
    assert(first(f, s, SUB) == 16511, 'an unreadable weapon skips Backstab, never guesses')
    local g, t = rogue(90, assassination)
    sliced(t)
    t.debuffs = { { id = 1943, expires = 120 } }
    t.targetHealth = 30
    t.points = 2
    assert(first(g, t, ASSA) == 111240)
    t.gear = { [16] = M.SWORD }
    assert(first(g, t, ASSA) == 1329, 'no dagger: Mutilate instead of Dispatch')
    t.stealth = true
    t.combat = false
    t.group = true
    t.buffs[#t.buffs + 1] = { id = 121153, expires = 110 }
    assert(first(g, t, ASSA) == 1329, 'Blindside opener without a dagger: Mutilate')
    local h, u = rogue(90, combat)
    u.stealth = true
    u.group = true
    u.gear = { [16] = M.SWORD }
    assert(first(h, u, COMBAT) == 8676, 'Ambush with a sword')
end)

test('stealth openers by spec, each ending in a Stop', function()
    local f, s = rogue(90, assassination)
    s.stealth = true
    s.combat = false
    assert(first(f, s, ASSA) == 1833, 'solo Cheap Shot')
    s.group = true
    assert(first(f, s, ASSA) == 1329, 'group Mutilate')
    s.buffs = { { id = 121153, expires = 110 } }
    assert(first(f, s, ASSA) == 111240, 'Blindside Dispatch')
    assert(first(f, s, ASSA_IV) == 111240)
    s.nopower[111240], s.nopower[1329] = true, true
    stopped(f, s, ASSA, true, 'pooling in Stealth')
    local g, t = rogue(90, combat)
    t.stealth = true
    t.group = true
    assert(first(g, t, COMBAT) == 8676)
    t.usable[8676] = false
    assert(first(g, t, COMBAT) == 84617, 'Revealing Strike when Ambush cannot land')
    assert(first(g, t, COMBAT_IV) == 84617)
    local h, u = rogue(90, subtlety)
    u.stealth = true
    u.combat = false
    u.group = true
    assert(first(h, u, SUB) == 14183, 'Premeditation')
    u.points = 3
    assert(first(h, u, SUB) == 14183)
    u.points = 4
    assert(first(h, u, SUB) == 5171, 'Slice and Dice before the pull')
    sliced(u)
    assert(first(h, u, SUB) == 8676)
    u.points = 5
    u.combat = true
    assert(first(h, u, SUB) == 1943, 'finish in the window: Rupture')
    u.debuffs = { { id = 1943, expires = 120 } }
    assert(first(h, u, SUB) == 2098)
    u.points = 2
    u.usable[8676] = false
    u.usable[14183] = false
    assert(first(h, u, SUB) == 703, 'Garrote fallback')
    u.stealth = false
    u.buffs[#u.buffs + 1] = { id = 51713, expires = 105 }
    u.usable[8676] = nil
    assert(first(h, u, SUB) == 8676, 'Shadow Dance counts as the window')
    local i, v = rogue(8, { 8676 })
    v.stealth = true
    v.combat = false
    assert(first(i, v, START) == 8676)
    v.usable[8676] = false
    assert(first(i, v, START) == 1752)
    M.know(v, 1833)
    assert(first(i, v, START) == 1833, 'solo Cheap Shot')
    v.group = true
    v.usable[8676] = nil
    assert(first(i, v, START) == 8676)
end)

test(
    'Assassination levelling kit: Mutilate, Slice and Dice, Eviscerate at four before Envenom and at five before Rupture',
    function()
        local f, s = rogue(14, { 1329, 5171 })
        assert(first(f, s, ASSA) == 1329)
        s.points = 1
        assert(first(f, s, ASSA) == 5171, 'Slice and Dice from one point')
        sliced(s, 10)
        assert(first(f, s, ASSA) == 1329)
        s.points = 4
        assert(first(f, s, ASSA) == 2098, 'four points without Anticipation: spend')
        s.points = 5
        assert(first(f, s, ASSA) == 2098, 'no Rupture yet: spend at five')
        s.buffs[1].expires = 101
        s.points = 2
        assert(first(f, s, ASSA) == 5171, 'before 60, refresh Slice and Dice under 2 s')
        s.level = 60
        assert(first(f, s, ASSA) == 1329, 'from 60 Envenom keeps it up')
    end
)

test(
    'Assassination full kit: Rupture, Envenom at five, four-point Envenom rule, Dispatch, Mutilate, pooling',
    function()
        local f, s = rogue(90, assassination)
        sliced(s)
        s.classification = 'worldboss'
        s.points = 1
        assert(first(f, s, ASSA) == 1943, 'Rupture when no bleed is up')
        s.debuffs = { { id = 703, expires = 110 } }
        assert(first(f, s, ASSA) == 1329, 'Garrote counts')
        s.debuffs = {}
        s.classification = 'normal'
        s.ttd = 5
        assert(first(f, s, ASSA) == 1329, 'no Rupture on a dying target')
        s.ttd = nil
        assert(first(f, s, ASSA) == 1329, 'no forecast, normal mob: no Rupture')
        s.classification = 'worldboss'
        s.debuffs = { { id = 1943, expires = 120 } }
        s.points = 5
        assert(first(f, s, ASSA) == 32645, 'Envenom at five')
        s.debuffs[1].expires = 101
        assert(first(f, s, ASSA) == 1943, 'refresh Rupture at five under 2 s')
        s.debuffs[1].expires = 103
        s.points = 4
        assert(first(f, s, ASSA) == 32645, 'four points: keep the Envenom buff rolling')
        s.buffs[#s.buffs + 1] = { id = 32645, expires = 110 }
        s.power = 40
        assert(first(f, s, ASSA) == nil, 'buff up, low energy: pool rather than Mutilate at four')
        s.power = 60
        assert(first(f, s, ASSA) == 32645, '50 energy spends')
        s.talents[18] = true
        assert(first(f, s, ASSA) == 1329, 'with Anticipation Mutilate at four')
        s.talents[18] = false
        s.power = 40
        s.targetHealth = 30
        assert(first(f, s, ASSA) == 111240, 'Dispatch below 35%')
        s.points = 2
        assert(first(f, s, ASSA) == 111240)
        s.targetHealth = 100
        assert(first(f, s, ASSA) == 1329)
        s.buffs[#s.buffs + 1] = { id = 121153, expires = 110 }
        assert(first(f, s, ASSA) == 111240, 'Blindside')
        s.ttd = 3
        s.classification = 'normal'
        assert(first(f, s, ASSA) == 32645, 'two points on a dying target')
    end
)

test('Assassination Icy Veins variant: Envenom only at five, Dispatch and Mutilate otherwise', function()
    local f, s = rogue(90, assassination)
    sliced(s)
    s.classification = 'worldboss'
    s.debuffs = { { id = 1943, expires = 120 } }
    s.points = 4
    assert(first(f, s, ASSA_IV) == 1329, 'no four-point Envenom')
    s.points = 5
    assert(first(f, s, ASSA_IV) == 32645)
    s.nopower[32645], s.nopower[2098] = true, true
    stopped(f, s, ASSA_IV, false, 'pool at five')
    s.nopower[32645], s.nopower[2098] = nil, nil
    s.points = 2
    s.targetHealth = 20
    assert(first(f, s, ASSA_IV) == 111240)
end)

test('Assassination packs: four or more engaged enemies with Fan of Knives known', function()
    local f, s = rogue(90, assassination)
    sliced(s)
    s.enemies = { 0, 0, 0 }
    assert(first(f, s, ASSA) == 1329, 'three enemies: single target')
    s.enemies = { 0, 0, 0, 0 }
    assert(first(f, s, ASSA) == 51723)
    s.points = 2
    assert(first(f, s, ASSA) == 1943, 'Rupture at two')
    s.debuffs = { { id = 1943, expires = 120 } }
    assert(first(f, s, ASSA) == 51723)
    s.buffs[1].expires = 102
    assert(first(f, s, ASSA) == 32645, 'Envenom to save Slice and Dice')
    s.buffs[1].expires = 130
    s.points = 5
    s.enemies = { 0, 0, 0, 0, 0, 0, 0 }
    assert(first(f, s, ASSA) == 121411, 'Crimson Tempest at seven')
    s.enemies = { 0, 0, 0, 0, false, false }
    s.points = 0
    assert(first(f, s, ASSA) == 51723, 'enemies not fighting you are not counted')
    s.enemies = { 0, 0, 0, false }
    assert(first(f, s, ASSA) == 1329)
    local g, t = rogue(60, { 1329, 5171, 32645, 1943 })
    sliced(t)
    t.enemies = { 0, 0, 0, 0, 0 }
    assert(first(g, t, ASSA) == 1329, 'no Fan of Knives yet: single target')
    local h, u = rogue(90, assassination)
    sliced(u)
    u.enemies = {0, 0, 0, 0, 0, 0, 0, 0, 0}
    u.points = 3
    assert(first(h, u, ASSA_IV) == 51723, 'nine or more: no Rupture')
    u.enemies = { 0, 0, 0, 0 }
    assert(first(h, u, ASSA_IV) == 1943)
end)

test(
    'Combat: Revealing Strike builder, Sinister Strike only under lust with Adrenaline Rush, finishers need Revealing Strike',
    function()
        local f, s = rogue(12, { 13877 })
        assert(first(f, s, COMBAT) == 1752, 'Sinister Strike before Revealing Strike')
        s.points = 5
        assert(first(f, s, COMBAT) == 2098, 'no Revealing Strike yet: finish')
        local g, t = rogue(90, combat)
        sliced(t)
        assert(first(g, t, COMBAT) == 84617)
        t.debuffs = { { id = 84617, expires = 120 } }
        assert(first(g, t, COMBAT) == 84617, 'Revealing Strike is the builder')
        assert(first(g, t, COMBAT_IV) == 1752, 'variant: Sinister Strike builder')
        t.buffs[#t.buffs + 1] = { id = 13750, expires = 110 }
        assert(first(g, t, COMBAT) == 84617, 'Adrenaline Rush alone is not enough')
        t.buffs[#t.buffs + 1] = { id = 2825, expires = 130, source = 'party1' }
        assert(first(g, t, COMBAT) == 1752, 'Bloodlust from anyone plus Adrenaline Rush')
        t.buffs = {}
        sliced(t)
        t.points = 5
        t.debuffs = {}
        assert(first(g, t, COMBAT) == 84617, 'refresh Revealing Strike before finishing')
        assert(first(g, t, COMBAT_IV) == 84617)
        t.debuffs = { { id = 84617, expires = 120 } }
        assert(first(g, t, COMBAT) == 2098)
        t.classification = 'worldboss'
        assert(first(g, t, COMBAT) == 1943, 'Rupture on a boss')
        t.buffs[#t.buffs + 1] = { id = 13877, expires = 0 }
        assert(first(g, t, COMBAT) == 2098, 'no Rupture while Blade Flurry cleaves')
        t.nopower[2098] = true
        stopped(g, t, COMBAT, false, 'pool at five')
        t.nopower[2098] = nil
        t.buffs[1].expires = 101
        assert(first(g, t, COMBAT) == 5171, 'Slice and Dice under 2 s')
        t.buffs = {}
        t.points = 2
        assert(first(g, t, COMBAT) == 5171)
    end
)

test('Combat at eight engaged enemies: Slice and Dice, Crimson Tempest when they live, Fan of Knives', function()
    local f, s = rogue(90, combat)
    sliced(s)
    s.debuffs = { { id = 84617, expires = 120 } }
    s.enemies = { 0, 0, 0, 0, 0, 0, 0 }
    assert(first(f, s, COMBAT) == 84617)
    s.enemies = { 0, 0, 0, 0, 0, 0, 0, 0 }
    assert(first(f, s, COMBAT) == 51723)
    s.points = 5
    s.ttd = 20
    assert(first(f, s, COMBAT) == 121411)
    s.ttd = 8
    assert(first(f, s, COMBAT) == 51723)
    assert(first(f, s, COMBAT_IV) == 51723)
end)

test('Combat Hekili variant: build into Anticipation, finish in Deep Insight or at four charges', function()
    local f, s = rogue(90, combat)
    s.talents[18] = true
    sliced(s)
    s.debuffs = { { id = 84617, expires = 120 } }
    s.points = 5
    assert(first(f, s, COMBAT_HK) == 2098, 'Shadow Blades ready: finish')
    s.cooldown[121471] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
    assert(first(f, s, COMBAT_HK) == 84617, 'below four charges: keep building')
    s.buffs[#s.buffs + 1] = { id = 115189, stacks = 4, expires = 120 }
    assert(first(f, s, COMBAT_HK) == 2098, 'four charges: finish')
    s.buffs[2] = nil
    s.debuffs = { { id = 84617, expires = 120 } }
    s.buffs[#s.buffs + 1] = { id = 115189, stacks = 5, expires = 120 }
    s.buffs[#s.buffs + 1] = { id = 84747, expires = 110 }
    assert(first(f, s, COMBAT_HK) == 2098, 'Deep Insight: finish')
    s.enemies = { 0, 0, 0, 0 }
    s.points = 2
    assert(first(f, s, COMBAT_HK) == 51723, 'Fan of Knives from four')
    local g, t = rogue(90, combat)
    t.talents[18] = true
    t.points = 4
    t.buffs = { { id = 5171, expires = 110 }, { id = 84654, stacks = 11, expires = 0 } }
    assert(first(g, t, COMBAT_HK) == 5171, 'early Slice and Dice at 11 Bandit\'s Guile')
end)

test('Subtlety: Slice and Dice, finishers, Hemorrhage bleed, Backstab from behind', function()
    local f, s = rogue(12, { 16511, 5171 })
    assert(first(f, s, SUB) == 16511, 'Hemorrhage is the only builder before 40')
    s.points = 1
    assert(first(f, s, SUB) == 5171)
    sliced(s)
    s.points = 5
    assert(first(f, s, SUB) == 2098, 'no Rupture yet')
    local g, t = rogue(90, subtlety)
    sliced(t)
    assert(first(g, t, SUB) == 16511, 'apply the Hemorrhage bleed')
    t.debuffs = { { id = 89775, expires = 120 } }
    assert(first(g, t, SUB) == 16511, 'front: Hemorrhage')
    t.targettarget = 'party1'
    assert(first(g, t, SUB) == 53, 'behind: Backstab')
    t.points = 5
    t.classification = 'worldboss'
    assert(first(g, t, SUB) == 1943)
    t.debuffs[2] = { id = 1943, expires = 103 }
    stopped(g, t, SUB, false, 'Rupture at 3 s: wait')
    t.debuffs[2].expires = 120
    assert(first(g, t, SUB) == 2098)
    t.buffs[1].expires = 103
    stopped(g, t, SUB, false, 'Slice and Dice at 3 s: wait')
    t.buffs[1].expires = 101
    assert(first(g, t, SUB) == 5171)
    t.buffs[1].expires = 130
    t.classification = 'normal'
    t.ttd = 3
    t.debuffs[2] = nil
    assert(first(g, t, SUB) == 2098, 'no Rupture on a dying target: Eviscerate')
    t.points = 0
    t.ttd = nil
    t.enemies = { 0, 0, 0 }
    assert(first(g, t, SUB) == 51723, 'Fan of Knives from three')
    t.points = 5
    assert(first(g, t, SUB) == 121411)
    t.debuffs[#t.debuffs + 1] = { id = 122233, expires = 120 }
    assert(first(g, t, SUB) == 2098)
end)

test('Subterfuge premade: Ambush in the linger, Crimson Tempest instead of Eviscerate on two or three', function()
    local f, s = rogue(90, subtlety)
    s.talents[2] = true
    sliced(s)
    s.buffs[#s.buffs + 1] = { id = 115192, expires = 102 }
    s.points = 4
    assert(first(f, s, SUB_WT) == 8676, 'Ambush while Subterfuge lingers')
    assert(first(f, s, SUB) == 16511, 'the Shadow Focus premade ignores Subterfuge')
    s.buffs[2] = nil
    s.points = 5
    s.enemies = { 0, 0 }
    s.classification = 'worldboss'
    assert(first(f, s, SUB_WT) == 1943, 'Rupture on two targets')
    s.debuffs = { { id = 1943, expires = 120 } }
    assert(first(f, s, SUB_WT) == 121411, 'Crimson Tempest replaces Eviscerate')
    assert(first(f, s, SUB) == 2098)
    s.points = 1
    assert(first(f, s, SUB_WT) == 16511, 'two or three: single-target builders')
    s.enemies = { 0, 0, 0, 0 }
    assert(first(f, s, SUB_WT) == 51723)
end)

test('solo levelling: Recuperate and Kidney Shot only when not grouped', function()
    for _, id in ipairs({ ASSA, COMBAT, SUB, START }) do
        local f, s = rogue(45, assassination, combat, subtlety)
        sliced(s)
        s.debuffs = { { id = 84617, expires = 120 }, { id = 89775, expires = 120 } }
        s.points = 3
        s.health = 80
        assert(first(f, s, id) == 73651, id .. ' Recuperate')
        s.buffs[#s.buffs + 1] = { id = 73651, expires = 120 }
        s.health = 30
        assert(first(f, s, id) == 408, id .. ' Kidney Shot')
        s.targettarget = 'party1'
        assert(first(f, s, id) ~= 408, id .. ' not when the mob is on someone else')
        s.targettarget = 'player'
        s.group = true
        assert(first(f, s, id) ~= 408 and first(f, s, id) ~= 73651, id .. ' grouped')
    end
end)

test('unspecialized: Slice and Dice at two, Eviscerate at four or on a dying target, Sinister Strike', function()
    local f, s = rogue(9, { 5171 })
    assert(first(f, s, START) == 1752)
    s.points = 2
    assert(first(f, s, START) == 5171)
    sliced(s)
    assert(first(f, s, START) == 1752)
    s.ttd = 3
    assert(first(f, s, START) == 2098)
    s.ttd = nil
    s.points = 4
    assert(first(f, s, START) == 2098)
end)

test('reminders: poisons, Kick, Shadowstep, Evasion, spec cooldowns', function()
    local f, s = rogue(90, assassination, { 108211, 36554, 5277 })
    local u = M.upkeep(f, s, ASSA)

    assert(
        u['rogue-lethal-poison'] == 2823 and u['rogue-leeching-poison'] == 108211 and not u['rogue-crippling-poison'],
        'Leeching when talented'
    )

    s.known[108211] = false
    assert(M.upkeep(f, s, ASSA)['rogue-crippling-poison'] == 3408)
    s.buffs = { { id = 2823, expires = 3700 }, { id = 5761, expires = 3700 } }
    u = M.upkeep(f, s, ASSA)

    assert(
        not u['rogue-lethal-poison'] and not u['rogue-crippling-poison'] and not u['rogue-lethal-refresh'],
        'a manual Mind-numbing choice is kept'
    )

    s.combat = false
    s.buffs[1].expires = 400
    assert(M.upkeep(f, s, ASSA)['rogue-lethal-refresh'] == 2823, 'top up out of combat')
    s.combat = true
    s.buffs = { { id = 8679, expires = 3700 }, { id = 3408, expires = 3700 } }
    assert(not M.upkeep(f, s, ASSA)['rogue-lethal-poison'], 'Wound Poison counts')
    assert(not M.upkeep(f, s, ASSA)['rogue-kick'])
    s.targetCast = 'Fireball'
    assert(M.upkeep(f, s, ASSA)['rogue-kick'] == 1766)
    s.targetInterruptible = false
    assert(not M.upkeep(f, s, ASSA)['rogue-kick'])
    s.range[6603] = false
    assert(M.upkeep(f, s, ASSA)['rogue-shadowstep'] == 36554)
    s.range[6603] = true
    s.health = 30
    assert(M.upkeep(f, s, ASSA)['rogue-evasion'] == 5277)
    s.group = true
    assert(not M.upkeep(f, s, ASSA)['rogue-evasion'])

    for _, step in ipairs(M.body(f.addon, ASSA).cooldowns) do
        if step.id == 'rogue-tricks' or step.id == 'rogue-expose-armor' then
            assert(step.disabled, step.id)
        end
    end

    -- Assassination: Vendetta on a long fight with a buff up, Shadow Blades and Vanish inside it, Preparation after Vanish.
    s.buffs = { { id = 5171, expires = 130 } }
    s.classification = 'worldboss'
    u = M.upkeep(f, s, ASSA)
    assert(u['rogue-assassination-vendetta'] == 79140 and not u['rogue-assassination-shadow-blades'])
    s.debuffs = { { id = 79140, expires = 115 } }
    s.power = 40
    u = M.upkeep(f, s, ASSA)
    assert(u['rogue-assassination-shadow-blades'] == 121471 and u['rogue-assassination-vanish'] == 1856)
    s.power = 70
    assert(not M.upkeep(f, s, ASSA)['rogue-assassination-vanish'], 'Vanish only at low energy')
    s.cooldown[1856] = { startTime = 90, duration = 120, isEnabled = true, modRate = 1 }
    assert(M.upkeep(f, s, ASSA)['rogue-assassination-preparation'] == 14185)
    assert(M.upkeep(f, s, ASSA_IV)['rogue-assassination-iv-vendetta'] == 79140)
end)

test(
    'Combat reminders: Blade Flurry on and off, Adrenaline Rush with Shadow Blades, Killing Spree, Vanish in Deep Insight',
    function()
        local f, s = rogue(90, combat)
        local u = M.upkeep(f, s, COMBAT)
        assert(not u['rogue-blade-flurry-on'] and not u['rogue-blade-flurry-off'])
        s.enemies = { 0, 0 }
        assert(M.upkeep(f, s, COMBAT)['rogue-blade-flurry-on'] == 13877)
        s.buffs = { { id = 13877, expires = 0 } }
        assert(not M.upkeep(f, s, COMBAT)['rogue-blade-flurry-on'])
        s.enemies = { 0 }
        assert(M.upkeep(f, s, COMBAT)['rogue-blade-flurry-off'] == 13877, 'cancel it on one target')
        s.buffs = { { id = 5171, expires = 130 } }
        assert(not M.upkeep(f, s, COMBAT)['rogue-adrenaline-rush'])
        s.power = 30
        u = M.upkeep(f, s, COMBAT)
        assert(u['rogue-adrenaline-rush'] == 13750 and u['rogue-killing-spree'] == 51690)
        s.buffs[#s.buffs + 1] = { id = 13750, expires = 110 }
        u = M.upkeep(f, s, COMBAT)

        assert(
            u['rogue-shadow-blades'] == 121471 and not u['rogue-killing-spree'],
            'Killing Spree waits for Adrenaline Rush to end'
        )

        s.buffs = { { id = 84747, expires = 110 } }
        u = M.upkeep(f, s, COMBAT)
        assert(u['rogue-vanish'] == 1856)
        s.power = 80
        assert(not M.upkeep(f, s, COMBAT)['rogue-vanish'])
    end
)

test(
    'Subtlety reminders: Shadow Dance at 75 energy, Vanish when Find Weakness is ending, Shadow Blades outside the windows',
    function()
        local f, s = rogue(90, subtlety)
        s.buffs = { { id = 5171, expires = 130 } }
        s.debuffs = { { id = 1943, expires = 120 } }
        s.classification = 'worldboss'
        s.power = 80
        local u = M.upkeep(f, s, SUB)
        assert(u['rogue-subtlety-shadow-dance'] == 51713 and u['rogue-subtlety-shadow-blades'] == 121471)
        assert(not u['rogue-subtlety-vanish'], 'Dance is ready, so no Vanish')
        s.cooldown[51713] = { startTime = 90, duration = 60, isEnabled = true, modRate = 1 }
        assert(M.upkeep(f, s, SUB)['rogue-subtlety-vanish'] == 1856)
        s.debuffs[2] = { id = 91021, expires = 110 }
        assert(not M.upkeep(f, s, SUB)['rogue-subtlety-vanish'], 'Find Weakness still up')
        s.power = 60
        s.cooldown[51713] = nil
        assert(not M.upkeep(f, s, SUB)['rogue-subtlety-shadow-dance'], 'pool to 75')
        s.buffs[#s.buffs + 1] = { id = 51713, expires = 105 }
        assert(not M.upkeep(f, s, SUB)['rogue-subtlety-shadow-blades'])
    end
)

test('unavailable combo points halt the rotation rather than guessing', function()
    local f, s = rogue(40, assassination)
    sliced(s)

    f.env.UnitPower = function()
        error('unavailable')
    end

    local x, r = M.first(f, s, ASSA)
    assert(not x and r.status == 'unavailable', tostring(x) .. ' ' .. tostring(r.status))
end)

test('real publisher auto-selects by specialization and highlights across combo points', function()
    local f, s = rogue(90, combat)
    sliced(s)
    s.debuffs = { { id = 84617, expires = 120 } }
    local poll, selected, glow = M.publisher(f, s)
    poll()

    assert(
        selected() == COMBAT and f.addon.currentSpell == 84617,
        tostring(selected()) .. ' ' .. tostring(f.addon.currentSpell)
    )

    s.points = 5
    poll()
    assert(f.addon.currentSpell == 2098)
    assert(#glow > 0)
end)

finish()
