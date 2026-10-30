-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Priest premades: specialization slots, the Shadow Blizzard Assisted rotation,
-- the disabled guide references, the Discipline and Holy healer lists and the reminders, through
-- the real catalog, predicates, composition, readiness and sequence executor on a modeled Retail
-- client (probe policy; the last test keeps the real restricted policy).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local M = dofile('tests/fixtures/retail_premade_model_b.lua')
local SHADOW, SHADOWIV = 'rm.retail.priest.shadow', 'rm.retail.priest.shadow.icyveins'
local DISC, DISCWH, HOLY = 'rm.retail.priest.discipline', 'rm.retail.priest.discipline.wowhead', 'rm.retail.priest.holy'
local SPECS = { [258] = { SHADOW, SHADOWIV }, [256] = { DISC, DISCWH }, [257] = { HOLY } }
local unpack = unpack or table.unpack

local function priest()
    local f, s = M.new('priest')

    s.ranged(
        34914,
        589,
        335467,
        1227280,
        8092,
        15407,
        391403,
        32379,
        450983,
        263165,
        1242173,
        585,
        47540,
        17,
        1253593,
        2061,
        2050,
        34861,
        33076,
        596,
        88625,
        14914
    )

    return f.addon, s, f
end

local shadowKit = {34914, 589, 335467, 1227280, 8092, 15407, 391403, 32379, 450983, 263165, 1242173}

test('every Priest premade is listed in each slot, Retail only, eligible only in its own specialization', function()
    local a = priest()
    M.checkSlots(a, SPECS)

    for _, id in ipairs({ SHADOWIV, DISCWH }) do
        assert(M.row(a, 258, id).envelope.body.disabled == true, id .. ' reference is not off by default')
    end
end)

test('Shadow Assisted: suggestion, Stops, Power Infusion after Voidform, Shadowform between pulls', function()
    local a, s = priest()
    s.learn(unpack(shadowKit))
    M.checkAssisted(a, s, 258, SHADOW, 34914)
    s.hostile = false
    M.expect(a, s, 258, SHADOW, nil, 'stopped', 'no enemy target')
    s.hostile = true
    s.learn(10060, 232698, 21562, 15487)
    local lit = M.upkeep(a, s, 258, SHADOW)
    assert(not lit[10060], 'no Power Infusion before Voidform')
    s.history(228260, 5)
    lit = M.upkeep(a, s, 258, SHADOW)
    assert(lit[10060], 'Power Infusion right after Voidform')
    s.combat = false
    lit = M.upkeep(a, s, 258, SHADOW)
    assert(lit[232698] and lit[21562], 'Shadowform and Fortitude between pulls')
    s.buff('player', 194249)
    s.buff('player', 21562, { sourceUnit = 'party1' })
    lit = M.upkeep(a, s, 258, SHADOW)
    assert(not lit[232698] and not lit[21562], 'Voidform counts; anyone\'s Fortitude counts')
end)

test(
    'Shadow Icy Veins reference: pre-pull Touch, DoT upkeep, Madness, procs, Mind Blast, moving, Flay clipping',
    function()
        local a, s = priest()
        s.learn(unpack(shadowKit))
        s.powerType = 13
        s.energy = 20
        s.combat = false
        M.expect(a, s, 258, SHADOWIV, 34914, nil, 'Vampiric Touch before the pull')
        s.debuff('target', 34914, { expirationTime = 121, duration = 21 })
        local r = M.expect(a, s, 258, SHADOWIV, nil, 'stopped', 'nothing else before the pull')
        s.combat = true
        s.clearAuras()
        M.expect(a, s, 258, SHADOWIV, 1227280, nil, 'Tentacle Slam applies Vampiric Touch')
        s.cooling(1227280, 8)
        M.expect(a, s, 258, SHADOWIV, 34914, nil, 'Vampiric Touch when Tentacle Slam is cooling')
        s.debuff('target', 34914, { expirationTime = 110, duration = 21 })
        M.expect(a, s, 258, SHADOWIV, 589, nil, 'Shadow Word: Pain')
        s.debuff('target', 589, { expirationTime = 110, duration = 16 })
        M.expect(a, s, 258, SHADOWIV, 335467, nil, 'Madness when missing')
        s.debuff('target', 335467, { expirationTime = 105, duration = 6 })
        M.expect(a, s, 258, SHADOWIV, 450983, nil, 'Void Blast during Madness')
        s.cooling(450983, 5)
        M.expect(a, s, 258, SHADOWIV, 263165, nil, 'Void Torrent')
        s.cooling(263165, 20)
        M.expect(a, s, 258, SHADOWIV, 8092, nil, 'Mind Blast')
        s.cooling(8092, 5)
        M.expect(a, s, 258, SHADOWIV, 391403, nil, 'Mind Flay: Insanity during Madness')
        s.usable[391403] = false
        M.expect(a, s, 258, SHADOWIV, 1242173, nil, 'Void Volley')
        s.usable[1242173] = false
        s.energy = 70
        M.expect(a, s, 258, SHADOWIV, 15407, nil, 'Insanity is secret: no Madness before the cap')
        s.energy = 20
        s.moving = true
        M.expect(a, s, 258, SHADOWIV, 32379, nil, 'moving: Shadow Word: Death')
        s.moving = false
        M.expect(a, s, 258, SHADOWIV, 15407, nil, 'Mind Flay')
        s.health.target = 15
        M.expect(a, s, 258, SHADOWIV, 15407, nil, 'target health is secret: no Shadow Word: Death execute')
        s.health.target = 100
        s.clearAuras()
        s.debuff('target', 589, { expirationTime = 110, duration = 16 })
        s.debuff('target', 34914, { expirationTime = 104, duration = 21 })
        M.expect(a, s, 258, SHADOWIV, 34914, nil, 'Vampiric Touch in its last 30%')
        s.channel = true
        s.cooldown = {}
        s.channelSpell = 263165
        M.expect(a, s, 258, SHADOWIV, nil, 'stopped', 'Void Torrent runs out, Mind Blast or not')
        s.channelSpell = 15407
        M.expect(a, s, 258, SHADOWIV, 34914, nil, 'Mind Flay with Mind Blast ready: clip')
        s.channelSpell = 391403
        M.expect(a, s, 258, SHADOWIV, 34914, nil, 'Mind Flay: Insanity too')
        s.channelSpell = 263165
        s.history(263165, 1)
        M.expect(a, s, 258, SHADOWIV, nil, 'stopped', 'a fresh Void Torrent is not clipped')
        s.channelSpell = 15407
        s.cooling(8092, 5)
        M.expect(a, s, 258, SHADOWIV, nil, 'stopped', 'Mind Blast cooling: let the channel run')
        s.channel = false
        s.channelSpell = nil
        s.learn(228260, 10060, 120644)
        s.cooldown = {}
        s.clearAuras()
        local lit = M.upkeep(a, s, 258, SHADOWIV)
        assert(lit[120644] and not lit[228260] and not lit[10060], 'Halo; Voidform waits for both DoTs')
        s.debuff('target', 34914)
        s.debuff('target', 589)
        lit = M.upkeep(a, s, 258, SHADOWIV)
        assert(lit[228260], 'Voidform with both DoTs')
        s.buff('player', 194249)
        lit = M.upkeep(a, s, 258, SHADOWIV)
        assert(lit[10060], 'Power Infusion in Voidform')
    end
)

test('Discipline: friendly Shield and Penance; enemy Pain by cast history, Mind Blast, Penance, Smite', function()
    local a, s = priest()
    s.learn(589, 8092, 47540, 17, 32379, 450983, 585, 2061)
    M.expect(a, s, 256, DISC, 589, nil, 'Shadow Word: Pain first')
    s.history(589, 4)
    s.debuff('target', 589, { expirationTime = 110, duration = 16 })
    M.expect(a, s, 256, DISC, 8092, nil, 'cast recently: Mind Blast')
    s.clearAuras()
    M.expect(a, s, 256, DISC, 589, nil, 'a new target without your Pain gets it')
    s.debuff('target', 589)
    s.cooling(8092, 5)
    M.expect(a, s, 256, DISC, 47540, nil, 'Penance')
    s.cooling(47540, 5)
    M.expect(a, s, 256, DISC, 17, nil, 'Power Word: Shield (self)')
    s.cooling(17, 5)
    M.expect(a, s, 256, DISC, 32379, nil, 'Shadow Word: Death')
    s.cooling(32379, 5)
    M.expect(a, s, 256, DISC, 450983, nil, 'Void Blast')
    s.usable[450983] = false
    M.expect(a, s, 256, DISC, 585, nil, 'Smite')
    a.spellHistory = {}
    s.history(589, 13)
    M.expect(a, s, 256, DISC, 589, nil, '12 s after the last cast: Pain again')
    s.hostile = false
    s.friendly = true
    s.cooldown = {}
    M.expect(a, s, 256, DISC, 17, nil, 'friendly target: Shield')
    s.cooling(17, 5)
    M.expect(a, s, 256, DISC, 47540, nil, 'then Penance')
    s.cooling(47540, 5)
    M.expect(a, s, 256, DISC, 2061, nil, 'Flash Heal')
    s.friendly = false
    s.exists = false
    local r = M.expect(a, s, 256, DISC, nil, 'stopped', 'no target')
    assert(r.suppressAttack)
    s.exists = true
    s.learn(194509, 472433, 421453, 33206)
    s.cooldown = {}
    local lit = M.upkeep(a, s, 256, DISC)
    assert(lit[194509] and lit[472433] and lit[421453] and not lit[33206], 'cooldowns; Pain Suppression on a friend')
end)

test('Discipline Wowhead reference: Pain upkeep then Death first', function()
    local a, s = priest()
    s.learn(589, 8092, 47540, 32379, 585, 17, 2061)
    M.expect(a, s, 256, DISCWH, 589, nil, 'Pain missing')
    s.debuff('target', 589, { expirationTime = 110, duration = 16 })
    M.expect(a, s, 256, DISCWH, 32379, nil, 'Shadow Word: Death before Penance')
    s.cooling(32379, 5)
    M.expect(a, s, 256, DISCWH, 47540, nil, 'Penance before Mind Blast')
    s.hostile = false
    s.friendly = true
    M.expect(a, s, 256, DISCWH, 47540, nil, 'Penance first on a friend')
end)

test('Holy: Holy Words, Mending, procs on a friend; Chastise and Smite on an enemy', function()
    local a, s = priest()
    s.learn(34861, 2050, 33076, 596, 2061, 132157, 88625, 14914, 585, 1262763)
    s.hostile = false
    s.friendly = true
    M.expect(a, s, 257, HOLY, 34861, nil, 'Sanctify')
    s.cooling(34861, 30)
    M.expect(a, s, 257, HOLY, 2050, nil, 'Serenity')
    s.cooling(2050, 30)
    M.expect(a, s, 257, HOLY, 33076, nil, 'Prayer of Mending')
    s.cooling(33076, 5)
    s.buff('player', 114255)
    M.expect(a, s, 257, HOLY, 596, nil, 'Surge of Light: Prayer of Healing')
    s.known[596] = nil
    M.expect(a, s, 257, HOLY, 1262763, nil, 'Benediction')
    s.usable[1262763] = false
    M.expect(a, s, 257, HOLY, 2061, nil, 'Surge of Light: Flash Heal')
    s.clearAuras()
    s.known[596] = true
    M.expect(a, s, 257, HOLY, 2061, nil, 'solo: Flash Heal')
    s.group = true
    M.expect(a, s, 257, HOLY, 596, nil, 'grouped: Prayer of Healing')
    s.group = false
    s.moving = true
    M.expect(a, s, 257, HOLY, 132157, nil, 'moving: Holy Nova')
    s.moving = false
    s.friendly = false
    s.exists = false
    M.expect(a, s, 257, HOLY, nil, 'stopped', 'no target')
    s.exists = true
    s.hostile = true
    M.expect(a, s, 257, HOLY, 88625, nil, 'Chastise')
    s.cooling(88625, 30)
    M.expect(a, s, 257, HOLY, 14914, nil, 'Holy Fire')
    s.cooling(14914, 5)
    M.expect(a, s, 257, HOLY, 585, nil, 'Smite')
    s.learn(200183, 64843, 120644, 47788)
    local lit = M.upkeep(a, s, 257, HOLY)
    assert(lit[120644] and not lit[200183], 'Halo in combat; Apotheosis waits for a group')
    s.group = true
    lit = M.upkeep(a, s, 257, HOLY)
    assert(lit[200183] and lit[64843], 'grouped cooldowns')
    s.hostile = false
    s.friendly = true
    s.health.target = 20
    lit = M.upkeep(a, s, 257, HOLY)
    assert(lit[47788], 'Guardian Spirit on a dying friend')
end)

test(
    'on the real restricted Retail client every Priest premade is complete and the recommended premade auto-selects',
    function()
        M.checkRestricted('priest', SPECS, { 34914, 47540, 2050 })
    end
)

test(
    'before a specialization (initial spec 1452) a level-4 Priest gets the Blizzard Assisted premade, complete',
    function()
        M.initial('priest', 1452, 'rm.retail.priest.initial', { 585 })
    end
)

finish()
