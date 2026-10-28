-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Death Knight premades: switches, priorities, boundaries and reminders
-- through the real catalog, predicates (RUNE, grid TALENT, pet auras, SPECIALIZATION, WEAPON_TYPE, FORM by
-- spell), composition and
-- sequence executor on a modeled 5.5.4 client (tests/fixtures/mop_premade_model_a.lua).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local M = dofile('tests/fixtures/mop_premade_model_a.lua')

local BLOOD, BSIM, FROST, DW, UNHOLY, UCAP =
    'rm.mop.deathknight.blood',
    'rm.mop.deathknight.blood.wowsims',
    'rm.mop.deathknight.frost',
    'rm.mop.deathknight.frost.dualwield',
    'rm.mop.deathknight.unholy',
    'rm.mop.deathknight.unholy.wowsims'

local ALL = { BLOOD, BSIM, FROST, DW, UNHOLY, UCAP }

-- Spells.
local DC, DS, IT, PS, BS, GRIP, BB, PEST, DND, OUTBREAK, HORN, ERW, ARMY, RAISE, FREEZE, IBF =
    47541, 49998, 45477, 45462, 45902, 49576, 48721, 50842, 43265, 77575, 57330, 47568, 42650, 46584, 47528, 48792

local HS, RS, TAP, VB, BONE, DRW, SR_B, BLOODP = 55050, 56815, 48982, 55233, 49222, 49028, 114866, 48263
local HB, FS, OBL, PILLAR, SR_F, FROSTP = 49184, 49143, 49020, 51271, 130735, 48266
local SS, FEST, DT, GARG, FRENZY, SR_U, UNHOLYP = 55090, 85948, 63560, 49206, 49016, 130736, 48265
local BTAP, LEECH, BLIGHT = 45529, 123693, 115989
local FEVER, PLAGUE = 55095, 55078

local function dk(level)
    local f, s = M.new('death-knight')
    local a = f.addon
    s.setLevel(level or 90)
    s.powerType = M.POWER.RunicPower
    s.energy = 0
    s.ranged(IT, GRIP, OUTBREAK, HB, DC)
    return a, s, f
end

local function diseased(s)
    s.debuff('target', FEVER, { expirationTime = 125, duration = 30 })
    s.debuff('target', PLAGUE, { expirationTime = 125, duration = 30 })
end

local BASE = { DC, DS, IT, PS, BS, GRIP, BB, PEST }

test('the Death Knight premades load, validate and declare Mists of Pandaria only, from 55', function()
    M.scope('death-knight', ALL, 55)
end)

test('switch: Blood and Frost by specialization (Frost by the off hand too), Unholy catches the rest', function()
    local a, s = dk(55)
    s.learn(unpack(BASE))
    assert(M.selected(a) == UNHOLY, 'an unspecialized knight runs Unholy')

    assert(
        M.switch(a, BLOOD) == 'no-match' and M.switch(a, FROST) == 'no-match',
        'no specialization yet: no specialization premade applies (body.specs)'
    )

    s.specID(252)
    assert(M.selected(a) == UNHOLY, 'Unholy')
    s.learn(HB, FS, 50034)
    assert(M.selected(a) == UNHOLY, 'spells of other specializations do not matter')
    s.specID(251)
    s.gear = { [16] = M.AXE2H }
    assert(M.selected(a) == FROST, 'Frost with a two-hander')
    s.gear = { [16] = M.SWORD, [17] = M.SWORD }
    assert(M.selected(a) == DW, 'Frost with two weapons')
    assert(M.switch(a, FROST) == 'match', 'the two-hand pack still matches underneath')
    s.gear = { [16] = M.SWORD, [17] = M.OFFHAND }
    assert(M.switch(a, DW) == 'no-match' and M.selected(a) == FROST, 'an off-hand item that is no weapon')
    s.gear = { [16] = M.AXE2H }
    assert(M.switch(a, DW) == 'no-match', 'a two-hander leaves the off hand empty')
    s.specID(250)
    assert(M.selected(a) == BLOOD, 'Blood')
    assert(M.switch(a, BSIM) == 'match' and M.switch(a, UCAP) == 'match', 'variants share their switches')
    assert(M.row(a, BSIM).envelope.body.disabled and M.row(a, UCAP).envelope.body.disabled, 'variants ship disabled')
end)

test('Blood: boundaries, pull from range, emergency and Blood Shield Death Strikes', function()
    local a, s = dk(90)
    s.learn(DC, DS, IT, PS, BS, GRIP, BB, PEST, DND, OUTBREAK, HORN, HS, RS, SR_B, BTAP, 50034)
    s.cast = true
    M.expect(a, s, BLOOD, nil, 'stopped', 'casting')
    s.cast = false
    s.channel = true
    M.expect(a, s, BLOOD, nil, 'stopped', 'channelling Army')
    s.channel = false
    s.hostile = false
    M.expect(a, s, BLOOD, nil, 'stopped', 'no attackable target')
    s.hostile = true
    s.combat = false
    s.targetRange = { 20, 25 }
    M.expect(a, s, BLOOD, OUTBREAK, nil, 'pull from range: Outbreak')
    s.cooling(OUTBREAK, 30)
    M.expect(a, s, BLOOD, IT, nil, 'pull: Icy Touch')
    s.usable[IT] = false
    local r = M.expect(a, s, BLOOD, GRIP, nil, 'pull: Death Grip')
    s.cooling(GRIP, 20)
    r = M.expect(a, s, BLOOD, nil, 'stopped', 'pull spent: stop')
    s.cooldown = {}
    s.usable = {}
    s.combat = true
    s.targetRange = { 0, 5 }
    diseased(s)
    s.buff('player', 77535, { sourceUnit = 'player' })
    s.health.player = 40
    M.expect(a, s, BLOOD, DS, nil, 'below half health')
    s.health.player = 100
    s.clearAuras()
    diseased(s)
    M.expect(a, s, BLOOD, DS, nil, 'Blood Shield missing at 80+')
    s.setLevel(70)
    s.setRunes('BBuuff')
    M.expect(a, s, BLOOD, HS, nil, 'below 80 no Blood Shield step: Heart Strike on two Blood runes')
end)

test('Blood: diseases, rune caps, Rune Strike, Soul Reaper, Crimson Scourge, filler order', function()
    local a, s = dk(90)
    s.learn(DC, DS, IT, PS, BS, BB, PEST, DND, OUTBREAK, HORN, HS, RS, SR_B, BTAP, 50034)
    s.buff('player', 77535, { sourceUnit = 'player' })
    M.expect(a, s, BLOOD, OUTBREAK, nil, 'diseases missing: Outbreak')
    s.cooling(OUTBREAK, 30)
    M.expect(a, s, BLOOD, IT, nil, 'Frost Fever by Icy Touch')
    s.debuff('target', FEVER, { expirationTime = 125, duration = 30 })
    M.expect(a, s, BLOOD, PS, nil, 'Blood Plague by Plague Strike')
    s.debuff('target', PLAGUE, { expirationTime = 103, duration = 30 })
    M.expect(a, s, BLOOD, BB, nil, 'Blood Boil refreshes a disease under 5 s')
    s.clearAuras()
    s.buff('player', 77535, { sourceUnit = 'player' })
    diseased(s)
    M.expect(a, s, BLOOD, DS, nil, 'all Frost and Unholy runes up: Death Strike')
    s.setRunes('BBuuff')
    s.energy = 95
    M.expect(a, s, BLOOD, RS, nil, 'Rune Strike near the cap')
    s.energy = 20
    s.health.target = 30
    M.expect(a, s, BLOOD, SR_B, nil, 'Soul Reaper under 35%')
    s.health.target = 100
    M.expect(a, s, BLOOD, HS, nil, 'two Blood runes: Heart Strike')
    s.setRunes('bbuuff')
    s.buff('player', 81141)
    M.expect(a, s, BLOOD, DND, nil, 'Crimson Scourge with long diseases: Death and Decay')
    s.cooling(DND, 20)
    M.expect(a, s, BLOOD, BB, nil, 'Crimson Scourge: Blood Boil otherwise')
    s.clearAuras()
    s.buff('player', 77535, { sourceUnit = 'player' })
    diseased(s)
    s.cooldown = {}
    s.cooling(OUTBREAK, 30)
    s.buff('player', 114851, { applications = 11 })
    M.expect(a, s, BLOOD, BTAP, nil, 'eleven Blood Charges: Blood Tap')
    s.clearAuras()
    s.buff('player', 77535, { sourceUnit = 'player' })
    diseased(s)
    s.setRunes('bbUuff')
    M.expect(a, s, BLOOD, DS, nil, 'Death Strike is the main filler')
    s.usable[DS] = false
    s.setRunes('Bbuuff')
    M.expect(a, s, BLOOD, HS, nil, 'one Blood rune: Heart Strike')
    s.usable[HS] = false
    s.energy = 40
    M.expect(a, s, BLOOD, RS, nil, 'Rune Strike spends runic power')
    s.usable[RS] = false
    M.expect(a, s, BLOOD, HORN, nil, 'Horn of Winter last')
end)

test('Blood: leveling before Heart Strike and Rune Strike; AoE with and without Roiling Blood', function()
    local a, s = dk(58)
    s.learn(DC, DS, IT, PS, BS, BB, PEST, 50034)
    diseased(s)
    M.expect(a, s, BLOOD, DS, nil, '58: Death Strike with all runes up')
    s.setRunes('BBuuff')
    M.expect(a, s, BLOOD, BS, nil, '58: Blood Strike on two Blood runes')
    s.energy = 85
    M.expect(a, s, BLOOD, DC, nil, '58: Death Coil near the cap without Rune Strike')
    s.setLevel(90)
    s.energy = 0
    s.learn(DND, HS, RS, OUTBREAK)
    s.buff('player', 77535, { sourceUnit = 'player' })
    s.setRunes('Bbuuff')
    s.near(3)
    M.expect(a, s, BLOOD, DND, nil, 'three enemies: Death and Decay')
    s.cooling(DND, 20)
    M.expect(a, s, BLOOD, PEST, nil, 'spread by Pestilence')
    s.talents[1] = true
    M.expect(a, s, BLOOD, BB, nil, 'Roiling Blood spreads by Blood Boil')
    s.talents = {}
    s.history(PEST, 2)
    M.expect(a, s, BLOOD, BB, nil, 'just spread: Blood Boil on a Blood rune')
end)

test('Blood reminders: presence, Bone Shield, Rune Tap, defensives by health, Army, interrupt', function()
    local a, s = dk(90)
    s.learn(BLOODP, FROSTP, BONE, TAP, VB, IBF, DRW, ERW, 48743, ARMY, HORN, FREEZE)
    s.combat = false
    s.group = true
    s.classification = 'worldboss'
    local lit = M.upkeep(a, s, BLOOD)
    assert(lit[BLOODP] and not lit[FROSTP] and lit[BONE] and lit[HORN] and lit[ARMY], 'between pulls')
    s.buff('player', FROSTP)
    s.buff('player', BONE, { applications = 4 })
    s.buff('player', 57330)
    lit = M.upkeep(a, s, BLOOD)

    assert(
        lit[BLOODP] and not lit[BONE] and not lit[HORN],
        'the Frost Presence aura alone is no presence; shield charged; horn up'
    )

    s.bar = { FROSTP, BLOODP }
    s.form = 1
    lit = M.upkeep(a, s, BLOOD)
    assert(not lit[BLOODP], 'a presence you chose is kept, wherever it sits on the bar')
    s.form = 2
    assert(not M.upkeep(a, s, BLOOD)[BLOODP], 'in Blood Presence')
    s.form = 0
    s.clearAuras()
    s.buff('player', BONE, { applications = 1 })
    lit = M.upkeep(a, s, BLOOD)
    assert(lit[BONE], 'one charge left')
    s.combat = true
    s.classification = 'normal'
    s.group = false
    lit = M.upkeep(a, s, BLOOD)
    assert(not lit[TAP] and not lit[VB] and not lit[DRW] and not lit[ARMY])
    s.buff('player', 96171)
    lit = M.upkeep(a, s, BLOOD)
    assert(lit[TAP], 'Will of the Necropolis: free Rune Tap')
    s.clearAuras()
    s.health.player = 45
    lit = M.upkeep(a, s, BLOOD)
    assert(lit[TAP] and lit[VB] and not lit[IBF] and not lit[ERW], '45%: Rune Tap and Vampiric Blood')
    s.setRunes('bbuuff')
    s.health.player = 25
    lit = M.upkeep(a, s, BLOOD)
    assert(lit[IBF] and lit[ERW] and lit[48743] and not lit[TAP], '25% and no runes')
    s.classification = 'elite'
    lit = M.upkeep(a, s, BLOOD)
    assert(lit[DRW], 'Dancing Rune Weapon on an elite')
    s.forget(BLOODP)
    s.health.player = 100
    s.clearAuras()
    lit = M.upkeep(a, s, BLOOD)
    assert(lit[FROSTP], 'Frost Presence before Blood Presence is learned')
end)

test(
    'Blood (wowsims): Death Strike only when hurt, shield fading or runes capping; lone Heart Strike by rune timers',
    function()
        local a, s = dk(90)
        s.learn(DC, DS, IT, PS, BS, BB, DND, OUTBREAK, HORN, HS, RS, SR_B, 50034)
        diseased(s)
        s.buff('player', 77535, { sourceUnit = 'player', expirationTime = 110 })
        s.usable[RS] = false
        s.setRunes('bbuUfF')
        M.expect(a, s, BSIM, HORN, nil, 'healthy, shield up, nothing capped: no Death Strike, runes unready')
        s.health.player = 65
        M.expect(a, s, BSIM, DS, nil, 'below 70%')
        s.health.player = 100
        s.clearAuras()
        diseased(s)
        s.buff('player', 77535, { sourceUnit = 'player', expirationTime = 102 })
        M.expect(a, s, BSIM, DS, nil, 'shield under 3 s')
        s.clearAuras()
        diseased(s)
        s.buff('player', 77535, { sourceUnit = 'player', expirationTime = 110 })
        s.setRunes('Bbuuff')
        M.expect(a, s, BSIM, HS, nil, 'one Blood rune, Frost and Unholy runes far away: Heart Strike')

        assert(
            M.first(a, s, BLOOD) == DS,
            'the recommended pack would Death Strike here (no shield step needed, Death Strike filler)'
        )
    end
)

test('Frost two-hand: Killing Machine Obliterate, caps, Rime, leveling Death Strike, reminders', function()
    local a, s = dk(90)

    s.learn(
        DC,
        DS,
        IT,
        PS,
        GRIP,
        BB,
        PEST,
        DND,
        OUTBREAK,
        HORN,
        HB,
        FS,
        OBL,
        SR_F,
        PILLAR,
        RAISE,
        ERW,
        FROSTP,
        IBF,
        ARMY,
        FREEZE
    )

    s.combat = false
    s.targetRange = { 20, 25 }
    M.expect(a, s, FROST, OUTBREAK, nil, 'pull: Outbreak')
    s.cooling(OUTBREAK, 30)
    M.expect(a, s, FROST, HB, nil, 'pull: Howling Blast')
    s.combat = true
    s.targetRange = { 0, 5 }
    s.cooldown = {}
    s.health.player = 30
    M.expect(a, s, FROST, DS, nil, 'survival Death Strike')
    s.health.player = 100
    M.expect(a, s, FROST, OUTBREAK, nil, 'diseases by Outbreak')
    s.cooling(OUTBREAK, 30)
    M.expect(a, s, FROST, HB, nil, 'Frost Fever by Howling Blast')
    s.debuff('target', FEVER)
    M.expect(a, s, FROST, PS, nil, 'Blood Plague by Plague Strike')
    s.debuff('target', PLAGUE)
    s.buff('player', 51124)
    M.expect(a, s, FROST, OBL, nil, 'Killing Machine: Obliterate')
    s.clearAuras()
    diseased(s)
    s.energy = 80
    M.expect(a, s, FROST, FS, nil, 'Frost Strike above 76')
    s.energy = 0
    s.buff('player', 59052)
    M.expect(a, s, FROST, HB, nil, 'Rime')
    s.clearAuras()
    diseased(s)
    M.expect(a, s, FROST, OBL, nil, 'a capped pair: Obliterate')
    s.usable[OBL] = false
    M.expect(a, s, FROST, HB, nil, 'Howling Blast with what is left')
    s.usable = {}
    s.health.target = 20
    M.expect(a, s, FROST, SR_F, nil, 'Soul Reaper under 35%')
    s.health.target = 100
    s.near(3)
    M.expect(a, s, FROST, PEST, nil, 'AoE: spread')
    s.history(PEST, 1)
    M.expect(a, s, FROST, DND, nil, 'AoE: Death and Decay on an Unholy rune')
    s.setRunes('bbuuFF')
    M.expect(a, s, FROST, HB, nil, 'AoE without Unholy runes: Howling Blast')
    s.near(0)
    local lit = M.upkeep(a, s, FROST)
    assert(lit[FROSTP] and lit[PILLAR] and lit[RAISE] and lit[HORN] and not lit[ERW], 'Frost reminders in combat')
    s.setRunes('bbuuff')
    lit = M.upkeep(a, s, FROST)
    assert(lit[ERW], 'Empower Rune Weapon with every rune down')
    local b, t = dk(56)
    t.learn(DC, DS, IT, PS, BS, HB, FS)
    diseased(t)
    t.setRunes('bbUUff')
    t.usable[HB] = false
    M.expect(b, t, FROST, DS, nil, '56: Death Strike spends Unholy runes before Obliterate')
    t.energy = 50
    t.usable[DS] = false
    M.expect(b, t, FROST, FS, nil, '56: Frost Strike at 40')
end)

test('Frost dual-wield: Killing Machine Frost Strike, Howling Blast spends Frost and Death runes', function()
    local a, s = dk(90)
    s.specID(251)
    s.gear = { [16] = M.SWORD, [17] = M.SWORD }
    s.learn(DC, DS, PS, DND, OUTBREAK, HORN, HB, FS, OBL, SR_F, BTAP, LEECH)
    diseased(s)
    assert(M.selected(a) == DW)
    s.buff('player', 51124)
    M.expect(a, s, DW, FS, nil, 'Killing Machine: Frost Strike')
    s.clearAuras()
    diseased(s)
    M.expect(a, s, DW, HB, nil, 'two Frost runes: Howling Blast')
    s.setRunes('bbUUff')
    M.expect(a, s, DW, OBL, nil, 'two Unholy runes below 77: Obliterate')
    s.energy = 80
    M.expect(a, s, DW, FS, nil, 'two Unholy runes at 80 runic power: Frost Strike first')
    s.energy = 0
    s.setRunes('bbUuff')
    M.expect(a, s, DW, OBL, nil, 'one Unholy rune: Obliterate')
    s.setRunes('bbuuFf')
    M.expect(a, s, DW, HB, nil, 'a Frost rune: Howling Blast')
    s.buff('player', 114851, { applications = 11 })
    M.expect(a, s, DW, BTAP, nil, 'Blood Tap at eleven charges')
    s.clearAuras()
    s.debuff('target', FEVER, { expirationTime = 102, duration = 30 })
    s.debuff('target', PLAGUE)
    s.usable[HB] = false
    s.usable[OBL] = false
    M.expect(a, s, DW, LEECH, nil, 'Plague Leech before diseases fall, Outbreak ready')
    s.cooling(OUTBREAK, 20)
    s.energy = 45
    M.expect(a, s, DW, FS, nil, 'Outbreak cooling: no Leech; Frost Strike at 40')
end)

test('Unholy: catch-all kit, Dark Transformation, Scourge, Sudden Doom, Festering, Soul Reaper, AoE', function()
    local a, s = dk(55)
    s.learn(DC, DS, IT, PS, BS, GRIP, BB, PEST)
    M.expect(a, s, UNHOLY, PS, nil, 'unspecced: Blood Plague first')
    s.debuff('target', PLAGUE)
    M.expect(a, s, UNHOLY, IT, nil, 'then Frost Fever')
    s.debuff('target', FEVER)
    M.expect(a, s, UNHOLY, BS, nil, 'then Blood Strike')
    s.energy = 45
    s.usable[BS] = false
    M.expect(a, s, UNHOLY, DC, nil, 'Death Coil at 40')
    s.health.player = 30
    s.usable = {}
    M.expect(a, s, UNHOLY, DS, nil, 'low health: Death Strike')
    local b, t = dk(90)
    t.learn(DC, DS, IT, PS, BB, PEST, DND, OUTBREAK, HORN, SS, FEST, DT, SR_U, BTAP, LEECH)
    diseased(t)
    t.pet = true
    t.buff('pet', 91342, { applications = 5 })
    M.expect(b, t, UNHOLY, DT, nil, 'five Shadow Infusion: Dark Transformation')
    t.clearAuras()
    diseased(t)
    t.energy = 95
    M.expect(b, t, UNHOLY, DC, nil, 'Death Coil at the cap')
    t.energy = 0
    M.expect(b, t, UNHOLY, SS, nil, 'Scourge Strike (Death and Decay only on a target with a known lifetime)')
    t.usable[SS] = false
    t.buff('player', 81340)
    M.expect(b, t, UNHOLY, DC, nil, 'Sudden Doom')
    t.clearAuras()
    diseased(t)
    M.expect(b, t, UNHOLY, FEST, nil, 'Festering Strike')
    t.usable = {}
    t.health.target = 30
    M.expect(b, t, UNHOLY, SR_U, nil, 'Soul Reaper under 35%')
    t.health.target = 100
    t.near(4)
    t.setRunes('bbuuFf')
    M.expect(b, t, UNHOLY, PEST, nil, 'AoE: spread')
    t.history(PEST, 1)
    M.expect(b, t, UNHOLY, DND, nil, 'AoE: Death and Decay')
    t.cooling(DND, 20)
    M.expect(b, t, UNHOLY, IT, nil, 'AoE: Icy Touch on a Frost rune')
    t.setRunes('Bbuuff')
    M.expect(b, t, UNHOLY, BB, nil, 'AoE: Blood Boil on a Blood rune')
    t.near(0)
    t.clearAuras()
    t.cooling(OUTBREAK, 20)
    t.debuff('target', FEVER)
    M.expect(b, t, UNHOLY, PS, nil, 'Plague Strike for a missing Blood Plague')
end)

test('Unholy reminders: presence, ghoul, Gargoyle on lust or a long elite, Frenzy, Empower, Army', function()
    local a, s = dk(90)
    s.learn(UNHOLYP, FROSTP, RAISE, GARG, FRENZY, ERW, IBF, 48743, HORN, FREEZE, ARMY)
    s.combat = false
    local lit = M.upkeep(a, s, UNHOLY)
    assert(lit[UNHOLYP] and lit[RAISE] and not lit[GARG] and not lit[FRENZY], 'between pulls')
    s.pet = true
    s.shift(UNHOLYP)
    lit = M.upkeep(a, s, UNHOLY)
    assert(not lit[RAISE] and not lit[UNHOLYP])
    s.combat = true
    lit = M.upkeep(a, s, UNHOLY)
    assert(lit[FRENZY] and not lit[GARG], 'Frenzy on cooldown; no Gargoyle on trash')
    s.buff('player', 2825)
    lit = M.upkeep(a, s, UNHOLY)
    assert(lit[GARG], 'Gargoyle under Bloodlust')
    s.setRunes('bbuuff')
    s.energy = 30
    lit = M.upkeep(a, s, UNHOLY)
    assert(lit[ERW], 'Empower with no runes and little runic power')
    s.health.player = 25
    lit = M.upkeep(a, s, UNHOLY)
    assert(lit[IBF] and lit[48743], 'defensives; Death Pact with the ghoul up')
end)

test('Unholy (wowsims): Death Coil rebuilds Shadow Infusion; rune pairs choose Scourge or Festering', function()
    local a, s = dk(90)
    s.learn(DC, DS, IT, PS, OUTBREAK, HORN, SS, FEST, DT, SR_U)
    diseased(s)
    s.pet = true
    s.energy = 45
    M.expect(a, s, UCAP, DC, nil, 'Dark Transformation down, under five stacks: Death Coil')
    assert(M.first(a, s, UNHOLY) == SS, 'the recommended pack spends runes first')
    s.buff('pet', DT)
    s.setRunes('bbUUff')
    M.expect(a, s, UCAP, SS, nil, 'two Unholy runes: Scourge Strike')
    s.setRunes('BBuuFF')
    M.expect(a, s, UCAP, FEST, nil, 'Blood and Frost pairs capped: Festering Strike')
    s.setRunes('Bbuuff')
    s.usable[SS] = false
    s.usable[FEST] = false
    M.expect(a, s, UCAP, DC, nil, 'nothing to strike: Death Coil at 40')
end)

finish()
