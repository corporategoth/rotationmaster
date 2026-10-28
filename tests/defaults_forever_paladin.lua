-- WoW Forever Paladin premades: switches, priorities, boundaries and reminders through the real
-- catalog, predicates, composition and sequence executor on a modeled Forever client (probe policy;
-- the last test keeps the real restricted policy).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local M = dofile('tests/fixtures/forever_premade_model.lua')

local RET, PROT, IVPROT, HOLY, WHHOLY =
    'rm.forever.paladin.retribution',
    'rm.forever.paladin.protection',
    'rm.forever.paladin.protection.icyveins',
    'rm.forever.paladin.holy',
    'rm.forever.paladin.holy.wowhead'

local unpack = unpack or table.unpack

local function paladin(level)
    local f, s = M.new('paladin')
    local a = f.addon
    s.setLevel(level or 60)
    s.ranged(879, 24275, 1311606, 1310911, 635, 19750, 4987, 1152, 20271)
    return a, s, f
end

local retKit = {20154, 21082, 20375, 20271, 679, 1311606, 1310911, 879, 26573, 2812, 24275}

test('the Paladin premades load, validate and declare Forever only', function()
    local a = paladin()
    local rows = M.rows(a)

    for _, id in ipairs({ RET, PROT, IVPROT, HOLY, WHHOLY }) do
        local row = assert(rows[id], id)
        local scope = row.applicability

        assert(
            row.readOnly
                and row.builtin
                and scope.families[1] == 'forever'
                and #scope.families == 1
                and scope.class == 'PALADIN'
                and scope.maxLevel == nil
                and scope.minLevel == nil,
            id
        )

        local variant = id == IVPROT or id == WHHOLY

        assert(
            row.eligible == not variant,
            id .. (variant and ' variant is not off by default' or ' not eligible on the probe Forever context')
        )

        assert((row.envelope.body.disabled == true) == variant, id .. ' disabled flag')
    end
end)

test(
    'switch by talent tree (1 Holy, 2 Protection, 3 Retribution): Retribution by default; Righteous Fury or the Protection tree tanks; grouped deep Holy heals',
    function()
        local a, s = paladin(1)
        s.learn(20154)
        assert(M.selected(a) == RET, 'level 1')
        s.setLevel(20)
        s.buff('player', 25780)
        assert(M.selected(a) == PROT, 'Righteous Fury on: Protection')
        s.clearAuras()
        s.setTrees({ 0, 5, 0 })
        assert(M.selected(a) == PROT, 'Protection main tree at any depth')
        s.setTrees({ 5, 5, 0 })
        assert(M.selected(a) == RET, 'a tie stays Retribution')
        s.buff('player', 25780)
        assert(M.selected(a) == PROT, 'a tie with Righteous Fury on: Protection')
        s.clearAuras()
        s.setLevel(30)
        s.setTrees({ 0, 0, 21 })
        s.learn(1311015)
        assert(M.selected(a) == RET, 'a known Prot talent spell under a Retribution main tree is not the switch')
        s.known[1311015] = nil
        s.setTrees({ 21, 0, 10 })
        s.learn(1311606)
        assert(M.selected(a) == RET, 'solo Shockadin stays Retribution')
        s.group = true
        assert(M.selected(a) == HOLY, 'grouped deep Holy heals')
        s.buff('player', 25780)
        assert(M.selected(a) == PROT, 'Righteous Fury beats Holy')
        s.clearAuras()
        s.setTrees({ 20, 0, 10 })
        assert(M.selected(a) == RET, '20 Holy points: not yet the healer')
        s.setTrees({ 10, 0, 21 })
        assert(M.selected(a) == RET, 'Retribution main tree with Holy Shock')
        s.setTrees({ 21, 0, 10 })

        assert(
            M.switch(a, IVPROT) == M.switch(a, PROT) and M.switch(a, WHHOLY) == 'match',
            'variants share their switches'
        )

        s.known = {}
        s.group = false
        s.setTrees({ 0, 0, 0 })
        assert(M.selected(a) == RET, 'a Paladin with nothing learned still gets a premade')
    end
)

test('Retribution: boundaries, seal upkeep, Crusader once, Command for slow weapons', function()
    local a, s = paladin()
    s.learn(unpack(retKit))
    s.cast = true
    M.expect(a, s, RET, nil, 'stopped', 'casting')
    s.cast = false
    s.hostile = false
    local r = M.expect(a, s, RET, nil, 'stopped', 'no hostile target')
    assert(not r.suppressAttack)
    s.hostile = true
    M.expect(a, s, RET, 20154, nil, 'a normal mob gets no Crusader (target health is secret, so only elites do)')
    s.classification = 'elite'
    M.expect(a, s, RET, 21082, nil, 'no seal, elite, Judgement ready: Crusader')
    s.debuff('target', 21183, { sourceUnit = 'party1' })
    M.expect(a, s, RET, 20154, nil, 'target already judged: Righteousness')
    s.swing = 3.4
    M.expect(a, s, RET, 20375, nil, 'slow weapon: Command')
    s.swing = 2.6
    s.clearAuras()
    s.classification = 'normal'
    s.health.target = 50
    M.expect(a, s, RET, 20154, nil, 'a normal mob gets no Crusader')
    s.classification = 'elite'
    s.health.target = 100
    s.cooling(20271, 5)
    M.expect(a, s, RET, 20154, nil, 'Judgement cooling: no Crusader yet')
    s.cooldown = {}
    s.buff('player', 20154, { expirationTime = 110, duration = 30 })
    M.expect(a, s, RET, 679, nil, 'seal up: Holy Strike')
    s.clearAuras()
    s.buff('player', 20154, { expirationTime = 102, duration = 30 })
    M.expect(a, s, RET, 21082, nil, 'seal under 3 s: reseal')
    s.clearAuras()
    s.buff('player', 21082, { expirationTime = 120, duration = 30 })
    s.debuff('target', 21183)
    M.expect(a, s, RET, 20154, nil, 'Crusader judged: swap to the main seal')
end)

test('Retribution: Holy Strike, Shockadin, Exorcism, AoE Consecration, Hammer of Wrath', function()
    local a, s = paladin()
    s.learn(unpack(retKit))
    s.buff('player', 20154, { expirationTime = 120, duration = 30 })
    M.expect(a, s, RET, 679, nil, 'Holy Strike')
    s.cooling(679, 5)
    M.expect(a, s, RET, 1311606, nil, 'Holy Shock')
    s.cooling(1311606, 8)
    M.expect(a, s, RET, 1310911, nil, 'Light\'s Vigil while Holy Shock cools')
    s.cooling(1310911, 4)
    s.usable[24275] = false

    local r = M.expect(
        a,
        s,
        RET,
        nil,
        'complete',
        'Hammer of Wrath outside its execute range: melee (no mana-to-spare Consecration)'
    )

    assert(not r.suppressAttack)
    s.usable[24275] = nil
    M.expect(a, s, RET, 24275, nil, 'Hammer of Wrath once it can be cast')
    s.usable[24275] = false
    s.creature = 'UNDEAD'
    M.expect(a, s, RET, 879, nil, 'Exorcism on Undead')
    s.creature = 'HUMANOID'
    s.mana.player = 60
    s.near(3)
    M.expect(a, s, RET, 26573, nil, 'three engaged: Consecration')
    s.cooling(26573, 5)
    s.creature = 'DEMON'
    M.expect(a, s, RET, 879, nil, 'Exorcism before the AoE branch on Demons')
end)

test('Retribution reminders: Judgement, aura and Blessing, healing out of combat, optional steps off', function()
    local a, s = paladin()
    s.learn(20271, 7294, 465, 20217, 19740, 19750, 635, 633, 853)
    local lit = M.upkeep(a, s, RET)

    assert(
        lit[7294] and not lit[465] and lit[20217] and not lit[19740] and not lit[20271],
        'aura and Blessing, no Judgement without a seal'
    )

    s.buff('player', 465)
    s.buff('player', 19740)
    s.buff('player', 20375)
    lit = M.upkeep(a, s, RET)
    assert(not lit[7294] and not lit[20217] and lit[20271], 'your choices are kept; Judgement with a seal up')
    assert(not lit[853], 'Hammer of Justice step is off by default')
    s.mana.player = 10
    lit = M.upkeep(a, s, RET)
    assert(lit[20271], 'Judgement whenever a seal is up (mana is secret)')
    s.combat = false
    s.health.player = 50
    lit = M.upkeep(a, s, RET)
    assert(not lit[19750] and not lit[635], 'healing yourself is yours (health is secret)')
    s.combat = true
    s.health.player = 10
    lit = M.upkeep(a, s, RET)
    assert(not lit[633], 'Lay on Hands is yours')
end)

test('Protection: taunt branch, AoE and single-target orders, tank reminders', function()
    local a, s = paladin()
    s.learn(1311015, 1310994, 20271, 679, 26573, 879, 2812, 25780, 1311649, 20925, 633)
    s.buff('player', 25780)
    s.buff('player', 1311649, { expirationTime = 120, duration = 30 })
    s.targetTarget = 'party1'
    M.expect(a, s, PROT, 20271, nil, 'taunt: Judgement')
    s.cooling(20271, 5)
    M.expect(a, s, PROT, 1310994, nil, 'Judgement cooling: Swift Judgement')
    s.cooldown = {}
    s.targetTarget = 'player'
    M.expect(a, s, PROT, 679, nil, 'one enemy: Holy Strike')
    s.cooling(679, 5)
    s.mana.player = 50
    M.expect(a, s, PROT, 26573, nil, 'then Consecration (mana is secret, so at any mana)')
    s.cooling(26573, 5)
    local r = M.expect(a, s, PROT, nil, 'complete', 'everything cooling: melee')
    assert(not r.suppressAttack)
    s.cooldown = {}
    s.near(2)
    M.expect(a, s, PROT, 26573, nil, 'two engaged: Consecration first')
    s.cooling(26573, 5)
    M.expect(a, s, PROT, 679, nil, 'AoE: Holy Strike while Consecration cools')
    s.cooldown = {}
    s.mana.player = 100
    s.creature = 'UNDEAD'
    s.cooling(26573, 5)
    M.expect(a, s, PROT, 879, nil, 'Exorcism on Undead in AoE')
    local lit = M.upkeep(a, s, PROT)

    assert(
        lit[20271] and lit[20925] and not lit[25780] and not lit[1311649],
        'Judgement and Holy Shield; Fury and seal up'
    )

    s.clearAuras()
    s.health.player = 30
    lit = M.upkeep(a, s, PROT)

    assert(
        lit[25780] and lit[1311649] and not lit[1311015] and not lit[633],
        'Righteous Fury, Seal of Fury; Templar\'s Bulwark and Lay on Hands are yours (health is secret)'
    )
end)

test('Icy Veins Protection: Consecration first, Judgement held for taunts', function()
    local a, s = paladin()
    s.learn(1311015, 1310994, 20271, 679, 26573, 879)
    s.buff('player', 25780)
    s.buff('player', 1311649, { expirationTime = 120, duration = 30 })
    M.expect(a, s, IVPROT, 26573, nil, 'Consecration first on one enemy')
    s.cooling(26573, 5)
    M.expect(a, s, IVPROT, 679, nil, 'Holy Strike, no Judgement while you hold aggro')
    s.targetTarget = 'party1'
    M.expect(a, s, IVPROT, 20271, nil, 'Judgement to taunt')
    assert(not M.upkeep(a, s, IVPROT)[20271], 'no on-cooldown Judgement reminder')
end)

test('Holy: heals the friendly target, party heal with Light\'s Vigil, dispels, hostile list', function()
    local a, s = paladin()
    s.learn(1311606, 1310911, 4987, 1152, 635, 19750, 20271, 679, 879)
    s.members(100, 100, 100, 100)
    s.hostile = false
    s.friendly = true
    s.health.target = 95
    M.expect(a, s, HOLY, 1310911, nil, 'Light\'s Vigil in combat (health is secret: your target decides)')
    s.cooling(1310911, 30)
    M.expect(a, s, HOLY, 19750, nil, 'Flash of Light as the main heal')
    s.health.target = 40
    M.expect(a, s, HOLY, 19750, nil, 'no Holy Light for a big deficit (health is secret)')
    s.buff('player', 437063)
    s.health.target = 65
    M.expect(a, s, HOLY, 635, nil, 'Infusion of Light: Holy Light')
    s.clearAuras()
    s.health.target = 20
    M.expect(a, s, HOLY, 19750, nil, 'no emergency Holy Shock (health is secret)')
    s.health.target = 80
    s.moving = true
    M.expect(a, s, HOLY, 1311606, nil, 'moving: Holy Shock')
    s.moving = false
    s.debuff('target', 1, { dispelName = 'Poison' })
    M.expect(a, s, HOLY, 4987, nil, 'Cleanse a poison')
    s.known[4987] = nil
    M.expect(a, s, HOLY, 1152, nil, 'Purify before Cleanse')
    s.clearAuras()
    s.buff('target', 1310909)
    M.expect(a, s, HOLY, 1311606, nil, 'your Vigil on the target: Holy Shock heals the party')
    s.clearAuras()
    s.usable[19750] = false
    local r = M.expect(a, s, HOLY, nil, 'stopped', 'nothing castable')
    assert(r.suppressAttack)
    s.usable[19750] = nil
    s.friendly = false
    s.hostile = true
    s.buff('player', 20165)
    M.expect(a, s, HOLY, 20271, nil, 'enemy with Seal of Light: Judgement of Light')
    s.debuff('target', 20185)
    M.expect(a, s, HOLY, 1311606, nil, 'then Holy Shock with mana')
    s.cooling(1311606, 8)
    M.expect(a, s, HOLY, 679, nil, 'Holy Strike while Holy Shock and Light\'s Vigil cool')
    s.learn(20165, 20216, 633)
    s.clearAuras()
    s.friendly = true
    s.hostile = false
    s.health.target = 10
    local lit = M.upkeep(a, s, HOLY)

    assert(
        lit[20165] and lit[20216] and not lit[633],
        'Seal of Light, Divine Favor; Lay on Hands is yours (health is secret)'
    )
end)

test('Wowhead Holy: Holy Shock on cooldown; Judgement of Light by seal swap', function()
    local a, s = paladin()
    s.learn(1311606, 635, 19750, 20271, 679, 20165, 20154, 879, 26573)
    s.members(100, 100, 100, 100)
    s.hostile = false
    s.friendly = true
    s.health.target = 85
    M.expect(a, s, WHHOLY, 1311606, nil, 'Holy Shock as a routine heal')
    M.expect(a, s, HOLY, 19750, nil, 'the Icy Veins order saves it')
    s.friendly = false
    s.hostile = true
    M.expect(a, s, WHHOLY, 20165, nil, 'swap to Seal of Light')
    s.buff('player', 20165)
    M.expect(a, s, WHHOLY, 20271, nil, 'judge it')
    s.debuff('target', 20185)
    M.expect(a, s, WHHOLY, 20154, nil, 'swap back to Righteousness')
    s.clearAuras()
    s.debuff('target', 20185)
    s.buff('player', 20154)
    M.expect(a, s, WHHOLY, 20271, nil, 'Judgement with Righteousness')
end)

test(
    'on the real restricted Forever client every Paladin premade is complete and the right one auto-selects',
    function()
        M.checkRestricted(
            'paladin',
            { RET, PROT, IVPROT, HOLY, WHHOLY },
            function(s)
                s.learn(20154, 1311015)
            end,
            RET
        )

        M.checkRestricted(
            'paladin',
            { PROT },
            function(s)
                s.learn(20154)
                s.buff('player', 25780)
            end,
            PROT
        )
    end
)

finish()
