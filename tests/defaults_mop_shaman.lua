-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Shaman premades: Elemental, Enhancement (Wowhead, recommended), Enhancement wowsims
-- and Icy Veins variants (off by default), Restoration, Restoration Hekili (off) and the Unspecialized catch-all.
-- Real predicates, catalog, composition, sequence executor, readiness and publisher on a modeled MoP Classic
-- client (tests/fixtures/mop_premade_model_b.lua).
local M = dofile('tests/fixtures/mop_premade_model_b.lua')
local test, finish = M.F.suite()

local ELE, ENH, SIM, IV =
    'rm.mop.shaman.elemental',
    'rm.mop.shaman.enhancement',
    'rm.mop.shaman.enhancement.wowsims',
    'rm.mop.shaman.enhancement.icyveins'

local RESTO, HK, NEW = 'rm.mop.shaman.restoration', 'rm.mop.shaman.restoration.hekili', 'rm.mop.shaman.unspecialized'
local starter = { 403, 73899, 8042, 8004, 324 }
local ele = {51490, 8024, 8050, 3599, 57994, 421, 51505, 8190, 61882, 30823, 2894, 2825, 120668, 73680, 79206, 114049}
local enh = {60103, 8024, 8050, 3599, 57994, 17364, 115356, 421, 8232, 8190, 1535, 51533, 30823, 2894, 73680, 114049}
local resto = {61295, 77130, 331, 52127, 974, 5394, 51730, 1064, 16190, 73920, 77472, 108280, 73680, 8050, 51505}

-- The specialization follows its signature spell in the kit (as choosing one teaches it).
local function shaman(level, ...)
    local f, s = M.fixture('SHAMAN', { level = level })
    M.know(s, 6603)

    for _, set in ipairs({ ... }) do
        M.know(s, unpack(set))
    end

    s.range[6603] = true

    if level >= 10 then
        for _, pair in ipairs({ { 51490, 262 }, { 60103, 263 }, { 61295, 264 } }) do
            if s.known[pair[1]] then
                s.specID(pair[2])
            end
        end
    end

    return f, s
end

local function first(f, s, id)
    return (M.first(f, s, id))
end

local function cd(s, id, left)
    s.cooldown[id] = { startTime = 100 - (10 - (left or 5)), duration = 10, isEnabled = true, modRate = 1 }
end

local function stopped(f, s, id, suppress, label)
    local x, r = M.first(f, s, id)

    assert(
        not x and r.status == 'stopped' and r.suppressAttack == suppress,
        (label or id) .. ': ' .. tostring(x) .. ' ' .. tostring(r.status)
    )
end

local function swing(f, elapsed)
    f.addon.lastMainSwing = 100 - elapsed
end

test('the specialization picks the premade; the catch-all owns levels 1-9 and an unspecialized character', function()
    local f, s = shaman(5, starter)
    assert(M.scoped(f, 'SHAMAN') == 7)
    assert(M.selected(f, s) == NEW and M.ordered(f, s) == NEW, 'level 5')
    s.specID(263)
    assert(M.selected(f, s) == NEW and M.ordered(f, s) == NEW, 'levels 1-9 stay in the catch-all')
    s.spec = nil
    s.level = 20
    M.know(s, 51490, 60103, 61295)
    assert(M.selected(f, s) == NEW and M.ordered(f, s) == NEW, 'level 20 without a specialization')

    for _, case in ipairs({ { 262, ELE }, { 263, ENH }, { 264, RESTO } }) do
        s.specID(case[1])
        assert(M.selected(f, s) == case[2] and M.ordered(f, s) == case[2], case[2])
    end

    -- Dual spec: the second talent group reads its own specialization.
    s.talentGroup = 2
    s.specID(264)
    assert(M.ordered(f, s) == RESTO)
    s.specID(262)
    assert(M.ordered(f, s) == ELE)
    s.talentGroup = 1
    local a = f.addon
    s.specID(263)

    for _, id in ipairs({ SIM, IV, HK }) do
        assert(not a:GetDefaultRotation(id).enabled, id .. ' ships disabled')
    end

    assert(a:SetDefaultRotationEnabled(SIM, true))
    assert(M.ordered(f, s) == ENH, 'the recommended premade still outranks an enabled variant')
    assert(a:SetDefaultRotationEnabled(ENH, false))
    assert(M.ordered(f, s) == SIM)
    assert(a:SetDefaultRotationEnabled(SIM, false))
    assert(a:SetDefaultRotationEnabled(IV, true))
    assert(M.ordered(f, s) == IV)
    s.specID(264)
    assert(a:SetDefaultRotationEnabled(HK, true))
    assert(a:SetDefaultRotationEnabled(RESTO, false))
    assert(M.ordered(f, s) == HK)
end)

test('every premade is listed but ineligible on a Wrath progression client', function()
    local f = M.fixture('SHAMAN', { project = 11, expansion = 2 })

    for _, row in ipairs(f.addon:ListDefaultRotations(1)) do
        assert(
            not row.eligible and row.eligibilityReason == 'expansion-mismatch',
            row.id .. ' ' .. tostring(row.eligibilityReason)
        )
    end
end)

test(
    'casts, channels, Ghost Wolf and a missing target stop with Attack suppressed; out of combat a pull then a stop',
    function()
        for _, id in ipairs({ ELE, ENH, SIM, IV, NEW }) do
            local f, s = shaman(90, starter, ele, enh)

            for _, key in ipairs({ 'cast', 'channel' }) do
                s[key] = true
                stopped(f, s, id, true, id .. ' ' .. key)
                s[key] = false
            end

            s.buffs = { { id = 2645 } }
            stopped(f, s, id, true, id .. ' ghost wolf')
            s.buffs = {}
            s.hostile = false
            stopped(f, s, id, true, id .. ' no target')
            s.hostile = true
            s.combat = false

            for spell in pairs(s.known) do
                s.nopower[spell] = true
            end

            s.nopower[6603] = nil
            stopped(f, s, id, false, id .. ' out of combat ends in a stop that lets Attack run')
        end

        local f, s = shaman(90, starter, ele)
        s.combat = false
        assert(first(f, s, ELE) == 403, 'Elemental pre-casts Lightning Bolt')
        s.talents[16] = true
        assert(first(f, s, ELE) == 51505, 'Lava Burst with Unleashed Fury')
        f, s = shaman(90, enh)
        s.combat = false
        assert(first(f, s, ENH) == 73680, 'Unleash Elements while running in')
        f, s = shaman(40, starter, { 60103, 17364 })
        s.combat = false
        s.range[6603] = false
        assert(first(f, s, ENH) == 403, 'Lightning Bolt from range before Unleash Elements')
        f, s = shaman(5, starter)
        s.combat = false
        assert(first(f, s, NEW) == nil)
        s.range[6603] = false
        assert(first(f, s, NEW) == 403)
    end
)

test(
    'Elemental levelling kit: Flame Shock on a living target, Earth Shock, Lightning Bolt; Chain Lightning on two',
    function()
        local f, s = shaman(20, starter, { 51490, 8050 })
        s.ttd = 20
        assert(first(f, s, ELE) == 8050)
        s.debuffs = { { id = 8050, expires = 118 } }
        assert(first(f, s, ELE) == 403, 'no Lava Burst yet: Bolt')
        s.buffs = { { id = 324, stacks = 6 } }
        assert(first(f, s, ELE) == 8042, 'Fulmination at six charges')
        s.debuffs[1].expires = 102.5
        assert(first(f, s, ELE) == 8050, 'Flame Shock first when it is about to tick out')
        s.debuffs[1].expires = 105.5
        assert(first(f, s, ELE) == 403, 'Earth Shock waits while Flame Shock has under 6 s')
        s.ttd = 3
        s.debuffs = {}
        assert(first(f, s, ELE) == 403, 'a dying target gets no Flame Shock')
        s.classification = 'elite'
        assert(first(f, s, ELE) == 8050, 'an elite always does')
        M.know(s, 421)
        s.classification = 'normal'
        s.enemies = { 0, 0 }
        assert(first(f, s, ELE) == 421)
    end
)

test(
    'Elemental full kit: Unleashed Fury, Flame Shock, Lava Burst, Elemental Blast, Earth Shock; Lava Surge and Ascendance',
    function()
        local f, s = shaman(90, starter, ele, { 117014 })
        s.ttd = 60
        s.talents[16] = true
        assert(first(f, s, ELE) == 73680)
        cd(s, 73680)
        assert(first(f, s, ELE) == 8050)
        s.debuffs = { { id = 8050, expires = 125 } }
        assert(first(f, s, ELE) == 51505)
        cd(s, 51505)
        assert(first(f, s, ELE) == 117014)
        cd(s, 117014)
        s.buffs = { { id = 324, stacks = 7 } }
        assert(first(f, s, ELE) == 8042)
        s.buffs = { { id = 77762 } }
        s.cooldown[51505] = nil
        s.debuffs[1].expires = 101
        cd(s, 8050)
        assert(first(f, s, ELE) == 51505, 'Lava Surge resets Lava Burst: cast it even on a fading Flame Shock')
        s.debuffs[1].expires = 125
        s.cooldown[8050] = nil
        s.cooldown[51505] = nil
        s.buffs = { { id = 114050 } }
        assert(first(f, s, ELE) == 51505, 'Ascendance: Lava Burst')
        cd(s, 51505)
        assert(first(f, s, ELE) == 403)
        s.cooldown[73680] = nil
        assert(first(f, s, ELE) == 403, 'no Unleash Elements inside Ascendance')
        s.buffs = {}
        s.cooldown[114049] = { startTime = 99, duration = 2, isEnabled = true, modRate = 1 }
        s.debuffs[1].expires = 114
        assert(first(f, s, ELE) == 73680)
        cd(s, 73680)
        assert(first(f, s, ELE) == 8050, 'Flame Shock topped up just before Ascendance')
    end
)

test('Elemental packs at four engaged enemies, Earthquake off; moving shows instants only', function()
    local f, s = shaman(90, starter, ele)
    s.enemies = { 0, 0, 0 }
    s.debuffs = { { id = 8050, expires = 130 } }
    assert(first(f, s, ELE) == 51505, 'three enemies keep the single-target core')
    s.enemies = { 0, 0, 0, 0 }
    assert(first(f, s, ELE) == 8190, 'Magma in melee')
    s.range[6603] = false
    assert(first(f, s, ELE) == 421, 'at range: Chain Lightning')
    s.range[6603] = true
    s.totems[1] = { 40, 'Spell 2894' }
    assert(first(f, s, ELE) == 421, 'never over Fire Elemental')
    s.buffs = { { id = 77762 } }
    assert(first(f, s, ELE) == 51505, 'Lava Surge')
    s.buffs = {}
    s.nopower[421] = true
    stopped(f, s, ELE, false, 'packs stop after Chain Lightning')

    for _, step in ipairs(M.body(f.addon, ELE).rotation) do
        if step.id == 'shaman-ele-aoe' then
            for _, x in ipairs(step.onTrue) do
                if x.action == 61882 then
                    assert(x.disabled)
                end
            end
        end
    end

    local g, t = shaman(90, starter, ele)
    t.debuffs = { { id = 8050, expires = 130 } }
    t.moving = true
    assert(first(g, t, ELE) == 403, 'Lava Burst is not cast while moving')
    t.buffs = { { id = 324, stacks = 6 } }
    assert(first(g, t, ELE) == 8042)
    t.buffs = { { id = 77762 } }
    assert(first(g, t, ELE) == 51505)
    t.buffs = { { id = 79206 } }
    assert(first(g, t, ELE) == 51505, "Spiritwalker's Grace: the normal list")
end)

test(
    'Elemental reminders: shield, Flametongue, Searing, Fire Elemental, Ascendance after Lava Burst, group cooldowns',
    function()
        local f, s = shaman(90, starter, ele, { 16166 })
        local u = M.upkeep(f, s, ELE)

        assert(
            u['shaman-ele-lightning-shield'] == 324
                and u['shaman-ele-flametongue'] == 8024
                and u['shaman-ele-searing-totem'] == 3599
        )

        assert(
            not u['shaman-ele-fire-elemental']
                and u['shaman-ele-elemental-mastery'] == 16166
                and not u['shaman-ele-earth-elemental']
        )

        s.buffs = { { id = 324, stacks = 3 } }
        s.mainEnchant = 5
        s.totems[1] = 20
        u = M.upkeep(f, s, ELE)

        assert(
            not u['shaman-ele-lightning-shield']
                and not u['shaman-ele-flametongue']
                and not u['shaman-ele-searing-totem']
        )

        s.classification = 'elite'
        assert(M.upkeep(f, s, ELE)['shaman-ele-fire-elemental'] == 2894)
        s.classification = 'normal'
        s.talents[17] = true
        assert(M.upkeep(f, s, ELE)['shaman-ele-fire-elemental'], 'Primal Elementalist: on cooldown')
        s.debuffs = { { id = 8050, expires = 120 } }
        assert(not M.upkeep(f, s, ELE)['shaman-ele-ascendance'], 'Lava Burst still ready')
        cd(s, 51505)
        assert(M.upkeep(f, s, ELE)['shaman-ele-ascendance'] == 114049)
        s.debuffs[1].expires = 110
        assert(not M.upkeep(f, s, ELE)['shaman-ele-ascendance'], 'Flame Shock under 15 s')
        cd(s, 114049, 30)
        assert(not M.upkeep(f, s, ELE)['shaman-ele-elemental-mastery'], 'Elemental Mastery waits for Ascendance')
        s.targetCast = 'Fireball'
        assert(M.upkeep(f, s, ELE)['shaman-ele-wind-shear'] == 57994)
        assert(not M.upkeep(f, s, ELE)['shaman-ele-bloodlust'])
        s.group, s.classification = true, 'worldboss'
        assert(M.upkeep(f, s, ELE)['shaman-ele-bloodlust'] == 2825)
        s.playerDebuffs = { { id = 57724, source = 'party1' } }
        assert(not M.upkeep(f, s, ELE)['shaman-ele-bloodlust'], 'Sated')
        s.buffs[#s.buffs + 1] = { id = 2825, source = 'party1' }
        assert(M.upkeep(f, s, ELE)['shaman-ele-stormlash'] == 120668)
        s.mana = 10
        s.health = 40
        u = M.upkeep(f, s, ELE)
        assert(u['shaman-ele-thunderstorm'] == 51490 and u['shaman-ele-shamanistic-rage'] == 30823)
    end
)

test('Enhancement levelling: Primal Strike before Stormstrike, Lava Lash, Flame Shock, Earth Shock', function()
    local f, s = shaman(12, starter, { 60103, 8024, 8050 })
    assert(first(f, s, ENH) == 73899, 'Primal Strike until Stormstrike')
    cd(s, 73899)
    assert(first(f, s, ENH) == 60103)
    cd(s, 60103)
    assert(first(f, s, ENH) == 8050, 'Flame Shock when missing and Unleash Elements is unknown')
    s.debuffs = { { id = 8050, expires = 118 } }
    assert(first(f, s, ENH) == 8042)
    M.know(s, 17364)
    s.cooldown[73899] = nil
    assert(first(f, s, ENH) == 17364, 'Stormstrike replaces Primal Strike')
end)

test(
    'Enhancement full kit: Maelstrom spenders, weaving by the swing timer, Stormblast, Unleash Flame Flame Shock',
    function()
        local f, s = shaman(90, starter, enh, { 117014 })
        s.talents[16] = true
        assert(first(f, s, ENH) == 73680, 'Unleash Elements with Unleashed Fury')
        cd(s, 73680)
        assert(first(f, s, ENH) == 17364)
        s.buffs = { { id = 53817, stacks = 5 } }
        assert(first(f, s, ENH) == 117014)
        cd(s, 117014)
        assert(first(f, s, ENH) == 403, 'Bolt at five')
        s.buffs[1].stacks = 3
        swing(f, 2)
        assert(first(f, s, ENH) == 17364, 'three stacks, swing too close: no weave')
        swing(f, .5)
        assert(first(f, s, ENH) == 403, 'weave at three')
        s.buffs = { { id = 114051 } }
        assert(first(f, s, ENH) == 115356, 'Stormblast in Ascendance')
        s.buffs = {}
        cd(s, 17364)
        assert(first(f, s, ENH) == 60103)
        cd(s, 60103)
        s.buffs = { { id = 73683 } }
        assert(first(f, s, ENH) == 8050, 'Flame Shock under Unleash Flame')
        s.debuffs = { { id = 8050, expires = 108 } }
        assert(first(f, s, ENH) == 8050, 'refresh under 9 s')
        s.debuffs[1].expires = 125
        assert(first(f, s, ENH) == 8042)
        s.buffs = {}
        s.debuffs = {}
        cd(s, 73680, 3)
        assert(first(f, s, ENH) == 8042, 'Unleash Elements is close: wait for it')
        cd(s, 73680, 8)
        assert(first(f, s, ENH) == 8050, 'plain Flame Shock when Unleash Elements is far off')
    end
)

test(
    'Enhancement packs: Chain Lightning for Maelstrom, Lava Lash to spread, Fire Nova at four, Magma at six',
    function()
        local f, s = shaman(90, starter, enh)
        s.enemies = { 0, 0 }
        s.buffs = { { id = 53817, stacks = 5 } }
        assert(first(f, s, ENH) == 421)
        s.buffs = {}
        s.debuffs = { { id = 8050, expires = 130 } }
        assert(first(f, s, ENH) == 60103, 'Lava Lash on a Flame Shocked target')
        cd(s, 60103)
        assert(first(f, s, ENH) == 17364)
        cd(s, 17364)
        cd(s, 73680)
        cd(s, 8042)
        assert(first(f, s, ENH) == 1535, 'Fire Nova as the two-target filler')
        s.cooldown = {}
        s.enemies = { 0, 0, 0, 0 }
        assert(first(f, s, ENH) == 1535, 'Fire Nova first at four')
        s.enemies = { 0, 0, 0, 0, 0, 0 }
        assert(first(f, s, ENH) == 8190)
        s.totems[1] = { 40, 'Spell 8190' }
        assert(first(f, s, ENH) == 1535, 'Magma already down')
        s.enemies = {}
        local x = first(f, s, ENH)
        assert(x == 17364, 'single target again')
    end
)

test(
    'Enhancement reminders: imbues per hand, Feral Spirit, Ascendance after Stormstrike, Ancestral Swiftness, Shamanistic Rage',
    function()
        local f, s = shaman(20, starter, { 60103, 8024 })
        local u = M.upkeep(f, s, ENH)
        assert(u['shaman-enh-flametongue-main'] == 8024 and not u['shaman-enh-flametongue-off'], 'no off-hand weapon')
        s.gear = { [16] = M.SWORD, [17] = M.SHIELD }
        s.mainEnchant = 5
        u = M.upkeep(f, s, ENH)
        assert(not u['shaman-enh-flametongue-off'], 'a shield takes no imbue')
        s.offSpeed = 2.6
        assert(not M.upkeep(f, s, ENH)['shaman-enh-flametongue-off'], 'an off-hand swing alone is not a weapon')
        s.gear[17] = M.SWORD
        u = M.upkeep(f, s, ENH)
        assert(not u['shaman-enh-flametongue-main'] and u['shaman-enh-flametongue-off'] == 8024, 'dual wielding')
        M.know(s, 8232)
        u = M.upkeep(f, s, ENH)

        assert(
            u['shaman-enh-windfury-weapon'] == 8232 and not u['shaman-enh-flametongue-off'],
            'Windfury first on the main hand'
        )

        s.mainEnchant = 283
        u = M.upkeep(f, s, ENH)
        assert(u['shaman-enh-flametongue-off'] == 8024)
        s.offEnchant = 5
        u = M.upkeep(f, s, ENH)
        assert(not u['shaman-enh-windfury-weapon'] and not u['shaman-enh-flametongue-off'])
        local g, t = shaman(90, starter, enh, { 16188 })
        u = M.upkeep(g, t, ENH)
        assert(u['shaman-enh-feral-spirit'] == 51533 and u['shaman-enh-ancestral-swiftness'] == 16188)
        assert(not u['shaman-enh-ascendance'], 'Stormstrike ready')
        cd(t, 17364, 6)
        assert(M.upkeep(g, t, ENH)['shaman-enh-ascendance'] == 114049)
        t.buffs = { { id = 53817, stacks = 2 } }
        assert(not M.upkeep(g, t, ENH)['shaman-enh-ancestral-swiftness'])
        t.health = 50
        assert(M.upkeep(g, t, ENH)['shaman-enh-shamanistic-rage'] == 30823)
        t.health = 80
        assert(M.upkeep(g, t, IV)['shaman-enh-iv-shamanistic-rage'], 'Icy Veins: on cooldown')
    end
)

test(
    'wowsims variant: any stack whose cast fits before the swing, Unleash for a missing Flame Shock, Earth Shock below two stacks',
    function()
        local f, s = shaman(90, starter, enh)
        s.debuffs = { { id = 8050, expires = 130 } }
        cd(s, 17364)
        s.buffs = { { id = 53817, stacks = 1 } }
        swing(f, .4)
        assert(first(f, s, SIM) == 403, 'one stack, 2.2 s to the swing')
        swing(f, 1)
        assert(first(f, s, SIM) == 60103)
        s.buffs[1].stacks = 4
        swing(f, 2)
        assert(first(f, s, SIM) == 403, 'four stacks fit in 0.6 s')
        s.buffs = {}
        s.debuffs = {}
        assert(first(f, s, SIM) == 73680, 'Unleash Elements whenever Flame Shock is missing')
        cd(s, 73680)
        cd(s, 60103)
        assert(first(f, s, SIM) == 8050)
        s.debuffs = { { id = 8050, expires = 130 } }
        assert(first(f, s, SIM) == 8042)
        s.buffs = { { id = 53817, stacks = 2 } }
        swing(f, 2.5)
        assert(first(f, s, SIM) == nil, 'no Earth Shock at two stacks')
    end
)

test(
    'Icy Veins variant: Lava Lash before Lightning Bolt, three-stack weave, Flame Shock spread on big pulls',
    function()
        local f, s = shaman(90, starter, enh)
        cd(s, 17364)
        s.buffs = { { id = 53817, stacks = 5 } }
        assert(first(f, s, IV) == 60103, 'Lava Lash before five stacks')
        assert(first(f, s, ENH) == 403, 'the recommended premade spends first')
        cd(s, 60103)
        assert(first(f, s, IV) == 403)
        s.buffs[1].stacks = 3
        swing(f, 2)
        assert(first(f, s, IV) == 73680)
        swing(f, .5)
        assert(first(f, s, IV) == 403)
        s.buffs = {}
        s.cooldown = {}
        s.enemies = { 0, 0, 0, 0 }
        assert(first(f, s, IV) == 8050, 'spread Flame Shock first')
        s.debuffs = { { id = 8050, expires = 130 } }
        assert(first(f, s, IV) == 1535)
        cd(s, 1535)
        assert(first(f, s, IV) == 60103)
    end
)

test('Restoration heals the friendly target and deals damage to an attackable one', function()
    local f, s = shaman(90, starter, resto)
    s.hostile, s.friend = false, true
    local x, r = M.first(f, s, RESTO)
    assert(x == 61295 or x == nil, 'nothing to heal: ' .. tostring(x))
    s.targetHealth = 96
    stopped(f, s, RESTO, true, 'healthy target')
    s.targetHealth = 92
    assert(first(f, s, RESTO) == 61295, 'Riptide below 95%')
    s.targetBuffs = { { id = 61295 } }
    stopped(f, s, RESTO, true, 'Riptide rolling, above 90%')
    s.targetHealth = 85
    assert(first(f, s, RESTO) == 331)
    s.targetHealth = 55
    assert(first(f, s, RESTO) == 77472)
    s.targetHealth = 30
    assert(first(f, s, RESTO) == 8004)
    s.buffs = { { id = 16188 } }
    assert(first(f, s, RESTO) == 77472, 'Ancestral Swiftness: instant Greater Healing Wave')
    s.buffs = {}
    s.targetHealth = 80
    s.debuffs = { { id = 1, dispel = 'Magic', source = 'target' } }
    assert(first(f, s, RESTO) == 77130, 'Purify Spirit')
    s.debuffs = {}
    s.members(70, 70, 70)
    assert(first(f, s, RESTO) == 73680, 'Unleash Elements before Healing Rain')
    cd(s, 73680)
    assert(first(f, s, RESTO) == 73920)
    cd(s, 73920)
    assert(first(f, s, RESTO) == 1064, 'Chain Heal')
    local g, t = shaman(15, starter, { 61295 })
    t.hostile, t.friend = false, true
    t.targetHealth = 65
    t.targetBuffs = { { id = 61295 } }
    assert(first(g, t, RESTO) == 8004, 'Healing Surge below 70% before Healing Wave is learned')
    local h, u = shaman(90, starter, resto)
    u.ttd = 30
    assert(first(h, u, RESTO) == 8050)
    u.debuffs = { { id = 8050, expires = 120 } }
    assert(first(h, u, RESTO) == 51505)
    cd(u, 51505)
    local y, ry = M.first(h, u, RESTO)
    assert(y == 403)
    u.nopower[403] = true
    y, ry = M.first(h, u, RESTO)
    assert(not y and ry.status == 'stopped' and not ry.suppressAttack)
end)

test(
    'Restoration reminders: shields, Earthliving, Earth Shield on focus, totems, Spiritwalker\'s Grace; assignment cooldowns off',
    function()
        local f, s = shaman(15, starter, { 61295 })
        local u = M.upkeep(f, s, RESTO)
        assert(u['shaman-resto-lightning-shield'] == 324, 'Lightning Shield before Water Shield')
        local g, t = shaman(90, starter, resto, { 108281, 79206 })
        t.friend, t.hostile = true, false
        u = M.upkeep(g, t, RESTO)

        assert(
            u['shaman-resto-water-shield'] == 52127
                and not u['shaman-resto-lightning-shield']
                and u['shaman-resto-earthliving'] == 51730
        )

        assert(not u['shaman-resto-healing-stream'], 'nobody hurt')
        t.targetHealth = 90
        assert(M.upkeep(g, t, RESTO)['shaman-resto-healing-stream'] == 5394)
        t.mainEnchant = 3345
        t.buffs = { { id = 52127 } }
        t.mana = 70
        u = M.upkeep(g, t, RESTO)

        assert(
            not u['shaman-resto-earthliving']
                and not u['shaman-resto-water-shield']
                and u['shaman-resto-mana-tide'] == 16190
        )

        t.targetHealth = 30

        assert(
            M.upkeep(g, t, RESTO)['shaman-resto-ancestral-swiftness'] == nil,
            'Ancestral Swiftness is a talent you do not have'
        )

        t.members(50, 50, 50, 50)
        t.health = 50
        u = M.upkeep(g, t, RESTO)
        assert(u['shaman-resto-healing-tide'] == 108280 and u['shaman-resto-ancestral-guidance'] == 108281)
        assert(not u['shaman-resto-ascendance'] and not u['shaman-resto-spirit-link'], 'raid assignments ship off')
        t.moving = true
        assert(M.upkeep(g, t, RESTO)['shaman-resto-spiritwalkers-grace'] == 79206)
    end
)

test(
    'Restoration Hekili variant: Earth Shield and Riptide on the target, Healing Rain kept up, health ladder',
    function()
        local f, s = shaman(90, starter, resto)
        s.hostile, s.friend = false, true
        assert(first(f, s, HK) == 974)
        s.targetBuffs = { { id = 974 } }
        assert(first(f, s, HK) == 61295)
        s.targetBuffs[2] = { id = 61295 }
        assert(first(f, s, HK) == 73920, 'Healing Rain whenever none is down')
        s.history = { { spell = 73920, time = 95 } }
        assert(first(f, s, HK) == 73680)
        cd(s, 73680)
        stopped(f, s, HK, true, 'everyone healthy')
        s.targetHealth = 65
        assert(first(f, s, HK) == 331, 'Healing Wave below 70%')
        s.targetHealth = 50
        assert(first(f, s, HK) == 331, 'Healing Wave sits above Greater Healing Wave in this ladder')
        s.nopower[331] = true
        assert(first(f, s, HK) == 77472)
        s.members(60, 60, 60)
        s.nopower = {}
        assert(first(f, s, HK) == 1064, 'Chain Heal below 80% group average')
        local g, t = shaman(90, starter, resto)
        t.debuffs = { { id = 8050, expires = 130 } }
        cd(t, 51505)
        t.nopower[403] = true
        assert(first(g, t, HK) == 8042, 'damage list adds Earth Shock')
    end
)

test('catch-all: Primal Strike, Earth Shock, Healing Surge when low and solo, Lightning Shield', function()
    local f, s = shaman(7, starter)
    assert(first(f, s, NEW) == 73899)
    cd(s, 73899)
    assert(first(f, s, NEW) == 8042)
    cd(s, 8042)
    local x, r = M.first(f, s, NEW)
    assert(not x and r.status == 'complete', 'melee: Attack')
    s.range[6603] = false
    assert(first(f, s, NEW) == 403)
    s.health = 30
    assert(first(f, s, NEW) == 8004)
    s.group = true
    assert(first(f, s, NEW) == 403, 'in a group: no self-heal')
    assert(M.upkeep(f, s, NEW)['shaman-new-lightning-shield'] == 324)
    s.buffs = { { id = 324, stacks = 3 } }
    assert(not M.upkeep(f, s, NEW)['shaman-new-lightning-shield'])
end)

test('real publisher auto-selects by specialization and highlights', function()
    local f, s = shaman(90, starter, ele)
    s.ttd = 60
    local poll, selected, glow = M.publisher(f, s)
    poll()

    assert(
        selected() == ELE and f.addon.currentSpell == 8050,
        tostring(selected()) .. ' ' .. tostring(f.addon.currentSpell)
    )

    s.debuffs = { { id = 8050, expires = 130 } }
    poll()
    assert(f.addon.currentSpell == 51505)
    assert(#glow > 0)
end)

finish()
