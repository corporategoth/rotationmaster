-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era and Season of Discovery Priest premades: damage (default, Warcraft Tavern, simulator),
-- healer, and their Season of Discovery counterparts. Real catalog, composition, predicates, build
-- context, sequence executor, readiness and auto-select order on a modeled 1.15 client
-- (tests/fixtures/era_premade_model_a.lua).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local M = dofile('tests/fixtures/era_premade_model_a.lua')

local DPS, TAVERN, SIMS, HEAL =
    'rm.era.priest.dps', 'rm.era.priest.dps.warcrafttavern', 'rm.era.priest.dps.simulator', 'rm.era.priest.healer'

local SDPS, SSPIKE, SHEAL, STAVERN =
    'rm.sod.priest.dps', 'rm.sod.priest.dps.wowhead', 'rm.sod.priest.healer', 'rm.sod.priest.healer.warcrafttavern'

local VANILLA, SOD = { DPS, TAVERN, SIMS, HEAL }, { SDPS, SSPIKE, SHEAL, STAVERN }

local SMITE, PAIN, BLAST, FLAY, FORM, SHOOT, HOLYFIRE, NOVA, EMBRACE, PLAGUE =
    585, 589, 8092, 15407, 15473, 5019, 14914, 15237, 15286, 2944

local SHIELD, LESSER, HEAL1, HEAL3, GREATER, FLASH, RENEW, POH, DISPEL, CURE, ABOLISH =
    17, 2050, 2054, 6063, 2060, 2061, 139, 596, 527, 528, 552

local VP, VT, SPIKE, SWD, SEAR, VZONE, PENANCE, COH, POM, SURGE =
    425204, 402668, 431655, 401955, 413259, 431681, 402174, 401946, 401859, 431666

local function priest(level, ...)
    local f, s = M.new('priest')
    local a = f.addon
    s.setLevel(level or 60)
    s.targetRange = { 28, 30 }
    s.learn(SMITE, ...)

    s.ranged(
        SMITE,
        PAIN,
        BLAST,
        FLAY,
        HOLYFIRE,
        SHOOT,
        EMBRACE,
        PLAGUE,
        VP,
        VT,
        SPIKE,
        SWD,
        SEAR,
        VZONE,
        PENANCE,
        SHIELD,
        LESSER,
        HEAL1,
        HEAL3,
        GREATER,
        FLASH,
        RENEW,
        DISPEL,
        CURE,
        ABOLISH,
        COH,
        POM
    )

    return a, s, f
end

local function shadow(...)
    return priest(60, PAIN, BLAST, FLAY, FORM, SHOOT, EMBRACE, ...)
end

local function stopped(a, s, id, label)
    local r = M.expect(a, s, id, nil, 'stopped', label)
    assert(r.suppressAttack, label .. ' would melee')
end

local function friend(s, health)
    s.friendly = true
    s.hostile = false
    s.health.target = health or 100
end

test('all eight Priest premades register valid, localized, sourced, composed and era-scoped', function()
    local a, _, f = priest()
    M.registered(a, f, VANILLA, 'PRIEST')
    M.registered(a, f, SOD, 'PRIEST')

    for _, id in ipairs(VANILLA) do
        assert(a:GetDefaultRotationComposition(id), id .. ' is not composed')
    end

    for _, id in ipairs(SOD) do
        assert(a:GetDefaultRotationComposition(id), id .. ' is not composed')
    end

    for _, id in ipairs({ HEAL, SHEAL }) do
        local sw = M.row(a, id).envelope.body.switch

        assert(
            sw.type == 'AND' and sw.value[1].type == 'LEVEL' and sw.value[1].value == 10,
            id .. ' switch holds level 10'
        )
    end

    for _, source in ipairs(M.row(a, TAVERN).envelope.sources) do
        assert(source.url:find('warcrafttavern'), 'Tavern variant cites another source')
    end

    for _, source in ipairs(M.row(a, SSPIKE).envelope.sources) do
        assert(not source.url:find('simulator'), 'Mind Spike variant cites simulator')
    end
end)

test(
    'standard realm: damage owns low levels, solo play, no points and ties; healer in a group with Holy or Discipline',
    function()
        local a, s = priest(1)
        assert(M.selected(a) == DPS, 'level 1')
        assert(M.switch(a, HEAL) == 'no-match', 'healer below level 10')
        s.setLevel(60)

        for _, id in ipairs(SOD) do
            assert(
                not M.row(a, id).eligible
                    and M.row(a, id).eligibilityReason
                        == ((id == SSPIKE or id == STAVERN) and 'disabled' or 'ruleset-mismatch'),
                id .. ' eligible on a standard realm'
            )
        end

        for _, id in ipairs({ TAVERN, SIMS, SSPIKE, STAVERN }) do
            assert(M.row(a, id).envelope.body.disabled == true, id .. ' must ship disabled')
        end

        s.setLevel(30)
        s.group = true
        assert(M.selected(a) == DPS, 'group with no talent points stays damage')
        assert(M.switch(a, HEAL) == 'unavailable')
        s.setTalents({ 0, 21, 0 })
        assert(M.selected(a) == HEAL, 'Holy in a group heals')
        s.setTalents({ 21, 0, 0 })
        assert(M.selected(a) == HEAL, 'Discipline in a group heals')
        s.setTalents({ 10, 10, 0 })
        assert(M.selected(a) == DPS, 'a tie falls back to damage')
        s.setTalents({ 0, 0, 31 })
        assert(M.selected(a) == DPS, 'Shadow in a group does damage')
        s.setTalents({ 31, 20, 0 })
        s.group = false
        assert(M.selected(a) == DPS, 'solo Discipline does damage')
        s.setLevel(60)
        s.group = true
        assert(M.selected(a) == HEAL)
        assert(M.switch(a, TAVERN) == 'match' and M.switch(a, SIMS) == 'match', 'variants share the damage switch')
        assert(a:SetDefaultRotationEnabled(DPS, false))
        s.group = false
        assert(M.selected(a) == nil, 'the variants ship disabled')
        assert(a:SetDefaultRotationEnabled(TAVERN, true) and a:SetDefaultRotationEnabled(SIMS, true))
        assert(M.selected(a) == TAVERN, 'enabled, the Tavern variant is next')
        assert(a:SetDefaultRotationEnabled(TAVERN, false))
        assert(M.selected(a) == SIMS)
    end
)

test('Season of Discovery realm: SoD premades win over every vanilla premade', function()
    local a, s = priest(1)
    s.setSeason(2)
    assert(M.selected(a) == SDPS, 'level 1 on SoD')
    s.setLevel(60)
    s.group = true
    s.setTalents({ 0, 31, 20 })
    assert(M.selected(a) == SHEAL, 'SoD healer')
    assert(M.switch(a, STAVERN) == 'match')
    assert(a:SetDefaultRotationEnabled(SHEAL, false))
    assert(M.selected(a) == SDPS, 'the Tavern healer ships disabled')
    assert(a:SetDefaultRotationEnabled(STAVERN, true))
    assert(M.selected(a) == STAVERN)
    assert(a:SetDefaultRotationEnabled(SHEAL, true))
    s.group = false
    assert(M.selected(a) == SDPS)
    assert(a:SetDefaultRotationEnabled(SDPS, false))
    assert(M.selected(a) ~= SSPIKE, 'the Mind Spike variant ships disabled')
    assert(a:SetDefaultRotationEnabled(SSPIKE, true))
    assert(M.selected(a) == SSPIKE, 'enabled, the Mind Spike variant is next')
    s.setSeason(3, true)
    assert(M.selected(a) == DPS, 'Hardcore uses the vanilla premades')
end)

test(
    'boundaries: cast, channel, no target and someone else\'s fight stop every damage premade without melee',
    function()
        for _, id in ipairs({ DPS, TAVERN, SIMS, SDPS, SSPIKE }) do
            local a, s = shadow(VP, VT, SPIKE)

            if id:find('sod') then
                s.setSeason(2)
            end

            s.buff('player', FORM)
            s.cast = true
            stopped(a, s, id, id .. ' casting')
            s.cast = false
            s.channel = true
            stopped(a, s, id, id .. ' channelling')
            s.channel = false
            s.hostile = false
            stopped(a, s, id, id .. ' no hostile target')
            s.hostile = true
            s.combat = false
            stopped(a, s, id, id .. ' pulling a mob someone else fights')
            s.combat = true
            assert(M.first(a, s, id), id .. ' gave no advice in plain combat')
        end
    end
)

test('vanilla damage: training stages from Smite to Shadowform', function()
    local a, s = priest(1)
    s.combat = false
    s.targetCombat = false
    M.expect(a, s, DPS, SMITE, nil, 'level 1 pull: Smite')
    s.combat = true
    s.targetCombat = true
    M.expect(a, s, DPS, SMITE, nil, 'level 1: Smite')
    s.learn(PAIN)
    s.setLevel(4)
    M.expect(a, s, DPS, PAIN, nil, 'level 4: Pain first')
    s.debuff('target', PAIN)
    M.expect(a, s, DPS, SMITE, nil, 'Pain up: Smite')
    s.learn(BLAST)
    s.setLevel(10)
    M.expect(a, s, DPS, BLAST, nil, 'level 10: Mind Blast')
    s.cooling(BLAST, 6)
    M.expect(a, s, DPS, SMITE, nil, 'Mind Blast cooling: Smite')
    s.cooldown = {}
    s.clearAuras()
    s.combat = false
    s.targetCombat = false
    s.learn(SHIELD, HOLYFIRE)
    M.expect(a, s, DPS, SHIELD, nil, 'solo pull: shield first')
    s.debuff('player', 6788)
    M.expect(a, s, DPS, HOLYFIRE, nil, 'Weakened Soul: Holy Fire opener')
    s.group = true
    s.clearAuras()
    M.expect(a, s, DPS, HOLYFIRE, nil, 'no shield pull in a group')
    s.group = false
    s.learn(FORM)
    s.debuff('player', 6788)
    M.expect(a, s, DPS, FORM, nil, 'Shadowform learned: take it first')
    s.buff('player', FORM)
    M.expect(a, s, DPS, BLAST, nil, 'Shadowform: Mind Blast opener, no Holy Fire')
    s.usable[BLAST] = false
    M.expect(a, s, DPS, SMITE, nil, 'pull falls to Smite')
    s.usable[SMITE] = false
    stopped(a, s, DPS, 'pull ends in a stop')
    s.usable = {}
    s.combat = true
    s.targetCombat = true
    s.clearAuras()
    s.buff('player', FORM)
    s.learn(FLAY)
    s.debuff('target', PAIN)
    s.cooling(BLAST, 5)
    M.expect(a, s, DPS, FLAY, nil, 'Mind Flay filler')
end)

test('vanilla damage: wand finish, Vampiric Embrace, raids, moving, Holy Nova', function()
    local a, s = shadow(PLAGUE, NOVA)
    s.buff('player', FORM)
    M.expect(a, s, DPS, PAIN, nil, 'healthy solo, short fight: no Vampiric Embrace, Pain first')
    s.health.player = 60
    M.expect(a, s, DPS, EMBRACE, nil, 'solo and hurt: Vampiric Embrace')
    s.debuff('target', EMBRACE)
    M.expect(a, s, DPS, PAIN, nil, 'Embrace up')
    s.debuff('target', PAIN)
    M.expect(a, s, DPS, BLAST, nil, 'Devouring Plague needs a forecast; Mind Blast')
    s.clearAuras()
    s.buff('player', FORM)
    s.health.player = 100
    s.debuff('target', PAIN)
    s.health.target = 20
    M.expect(a, s, DPS, SHOOT, nil, 'dying solo target: wand')
    s.repeatActive = true
    stopped(a, s, DPS, 'wand already shooting')
    s.repeatActive = false
    s.health.target = 100
    s.mana.player = 20
    M.expect(a, s, DPS, SHOOT, nil, 'low mana solo: wand')
    s.mana.player = 100
    s.group = true
    s.health.target = 20
    M.expect(a, s, DPS, BLAST, nil, 'in a group a dying target still gets Mind Blast')
    s.health.target = 100
    s.instance = 'raid'
    s.health.player = 60
    M.expect(a, s, DPS, BLAST, nil, 'raid: no Vampiric Embrace or Devouring Plague')
    s.instance = nil
    s.group = false
    s.health.player = 100
    s.clearAuras()
    s.buff('player', FORM)
    s.moving = true
    M.expect(a, s, DPS, PAIN, nil, 'moving: Pain')
    s.debuff('target', PAIN)
    M.expect(a, s, DPS, PLAGUE, nil, 'moving: Devouring Plague')
    s.debuff('target', PLAGUE)
    stopped(a, s, DPS, 'moving with both DoTs up: stop')
    s.moving = false
    s.cooling(BLAST, 5)
    M.expect(a, s, DPS, FLAY, nil, 'Mind Flay filler; no AoE spell in vanilla Shadow')
    local b, t = priest(30, PAIN, BLAST, NOVA, SHOOT)
    t.debuff('target', PAIN)
    t.cooling(BLAST, 5)
    t.near(3)
    M.expect(b, t, DPS, NOVA, nil, 'no Mind Flay: Holy Nova on three enemies at hand')
    t.near(0)
    M.expect(b, t, DPS, SMITE, nil, 'no Mind Flay: Smite')
    t.usable[SMITE] = false
    stopped(b, t, DPS, 'Smite unusable: no melee, no wand fall-through')
    t.usable = {}
    local c, u = shadow()
    u.buff('player', FORM)
    u.debuff('target', PAIN)
    u.cooling(BLAST, 5)
    u.usable[FLAY] = false
    M.expect(c, u, DPS, SHOOT, nil, 'out of mana: wand fallback')
    u.repeatActive = true
    stopped(c, u, DPS, 'wand fallback already running')
    local raid = M.step(c, DPS, 'priest-raid-flay-r1')
    assert(raid.disabled and raid.ranked and raid.action == FLAY, 'rank-1 Mind Flay ships disabled')
end)

test('vanilla damage reminders: Inner Fire, Fortitude, Inner Focus, Scream, Fade, Desperate Prayer', function()
    local a, s = shadow(588, 1243, 14751, 8122, 586, 13908, 2652)
    s.combat = false
    local lit = M.upkeep(a, s, DPS)
    assert(lit[588] and lit[1243] and lit[2652] and not lit[14751], 'out of combat buffs')
    s.buff('player', 588)
    s.buff('player', 21562)
    lit = M.upkeep(a, s, DPS)
    assert(not lit[588] and not lit[1243], 'Prayer of Fortitude counts')
    s.combat = true
    lit = M.upkeep(a, s, DPS)
    assert(lit[14751] and not lit[1243], 'Inner Focus with Mind Blast ready')
    s.cooling(BLAST, 6)
    lit = M.upkeep(a, s, DPS)
    assert(not lit[14751], 'no Inner Focus while Mind Blast cools')
    s.health.player = 40
    s.near(2)
    lit = M.upkeep(a, s, DPS)
    assert(lit[8122], 'Scream: two enemies at hand, half health')
    s.group = true
    lit = M.upkeep(a, s, DPS)
    assert(not lit[8122], 'no Scream in a group')
    s.targetThreat = 1
    lit = M.upkeep(a, s, DPS)
    assert(lit[586], 'Fade when the target turns on you')
    s.health.player = 20
    lit = M.upkeep(a, s, DPS)
    assert(lit[13908], 'Desperate Prayer')
end)

test('Warcraft Tavern: Mind Blast pull, wand between Mind Blasts solo, Mind Flay in a group', function()
    local a, s = shadow(SHIELD)
    s.buff('player', FORM)
    s.combat = false
    s.targetCombat = false
    M.expect(a, s, TAVERN, BLAST, nil, 'pull: Mind Blast, no shield')
    s.combat = true
    s.targetCombat = true
    M.expect(a, s, TAVERN, PAIN, nil, 'Pain once')
    s.debuff('target', PAIN)
    M.expect(a, s, TAVERN, BLAST, nil, 'Mind Blast')
    s.health.target = 25
    M.expect(a, s, TAVERN, SHOOT, nil, 'below 30%: no second Mind Blast, wand')
    s.health.target = 100
    s.cooling(BLAST, 5)
    M.expect(a, s, TAVERN, SHOOT, nil, 'wand filler, not Mind Flay')
    s.repeatActive = true
    stopped(a, s, TAVERN, 'wand already shooting')
    s.repeatActive = false
    s.group = true
    M.expect(a, s, TAVERN, FLAY, nil, 'group: Mind Flay')
end)

test('simulator: Inner Focus on Devouring Plague, Devouring Plague in raids', function()
    local a, s = shadow(PLAGUE, 14751)
    s.buff('player', FORM)
    s.debuff('target', PAIN)
    s.instance = 'raid'
    s.group = true
    s.raid = true
    local lit = M.upkeep(a, s, SIMS)
    assert(lit[14751], 'Inner Focus while Devouring Plague is ready')
    M.expect(a, s, SIMS, BLAST, nil, 'Inner Focus ready, not yet used: hold Devouring Plague')
    s.buff('player', 14751)
    M.expect(a, s, SIMS, PLAGUE, nil, 'Inner Focus up: Devouring Plague, even in a raid')
    M.expect(a, s, DPS, BLAST, nil, 'the default never casts Devouring Plague in a raid')
    s.clearAuras()
    s.buff('player', FORM)
    s.debuff('target', PAIN)
    s.cooling(14751, 100)
    M.expect(a, s, SIMS, PLAGUE, nil, 'Inner Focus cooling: Devouring Plague anyway')
    s.debuff('target', PLAGUE)
    lit = M.upkeep(a, s, SIMS)
    assert(not lit[14751], 'no Inner Focus with Plague up and Mind Blast... ')
end)

test('vanilla healer: friendly target priorities and training stages', function()
    local a, s = priest(10, LESSER, RENEW, 1243)
    s.group = true
    s.setTalents({ 0, 5, 0 })
    friend(s, 100)
    s.combat = false
    M.expect(a, s, HEAL, 1243, nil, 'out of combat: Fortitude on the target')
    s.buff('target', 1243)
    stopped(a, s, HEAL, 'out of combat with Fortitude: nothing, no Renew pre-cast')
    s.combat = true
    stopped(a, s, HEAL, 'healthy target: nothing to do')
    s.health.target = 80
    M.expect(a, s, HEAL, RENEW, nil, 'light damage: Renew')
    s.buff('target', RENEW)
    M.expect(a, s, HEAL, LESSER, nil, 'Renew up: Lesser Heal')
    s.health.target = 45
    M.expect(a, s, HEAL, LESSER, nil, 'below half before Heal: Lesser Heal')
    s.learn(HEAL1)
    s.setLevel(20)
    M.expect(a, s, HEAL, HEAL1, nil, 'Heal learned')
    s.health.target = 80
    M.expect(a, s, HEAL, HEAL1, nil, 'top-up with any Heal before rank 3')
    s.learn(HEAL3)
    M.expect(a, s, HEAL, HEAL3, nil, 'top-up with Heal rank 3')
    s.learn(GREATER, FLASH, SHIELD, POH, DISPEL, CURE)
    s.setLevel(40)
    s.health.target = 45
    M.expect(a, s, HEAL, GREATER, nil, 'big damage: Greater Heal')
    s.health.target = 35
    M.expect(a, s, HEAL, FLASH, nil, 'below 40%: Flash Heal')
    s.health.target = 25
    M.expect(a, s, HEAL, SHIELD, nil, 'below 30%: Shield')
    s.debuff('target', 6788)
    M.expect(a, s, HEAL, FLASH, nil, 'Weakened Soul: Flash Heal')
    s.clearAuras()
    s.buff('target', RENEW)
    s.health.target = 90
    s.debuff('target', 1, { dispelName = 'Magic' })
    M.expect(a, s, HEAL, DISPEL, nil, 'Magic: Dispel Magic')
    s.clearAuras()
    s.buff('target', RENEW)
    s.debuff('target', 2, { dispelName = 'Disease' })
    M.expect(a, s, HEAL, CURE, nil, 'Disease: Cure Disease')
    s.learn(ABOLISH)
    M.expect(a, s, HEAL, ABOLISH, nil, 'Abolish Disease once learned')
    s.clearAuras()
    s.buff('target', RENEW)
    s.members(70, 70, 75)
    M.expect(a, s, HEAL, POH, nil, 'three hurt party members: Prayer of Healing')
    s.cast = true
    stopped(a, s, HEAL, 'casting')
    s.cast = false
end)

test('vanilla healer: enemy target damage and reminders', function()
    local a, s = priest(40, PAIN, 14752, 14751, 588, 1243)
    s.group = true
    s.setTalents({ 31, 5, 0 })
    M.expect(a, s, HEAL, SMITE, nil, 'enemy target, no forecast: Smite')
    s.hostile = false
    stopped(a, s, HEAL, 'nothing attackable')
    s.hostile = true
    s.combat = false
    local lit = M.upkeep(a, s, HEAL)
    assert(lit[14752] and lit[588] and lit[1243] and not lit[14751], 'Divine Spirit, Inner Fire, Fortitude')
    s.buff('player', 27681)
    lit = M.upkeep(a, s, HEAL)
    assert(not lit[14752], 'Prayer of Spirit counts')
    s.combat = true
    s.learn(10060)
    lit = M.upkeep(a, s, HEAL)
    assert(lit[14751] and not lit[10060], 'Inner Focus in combat; Power Infusion off by default')
end)

test('SoD damage: runes by engraving, DoTs, Mind Blast, Melting Faces, set Mind Flay, Mind Spike', function()
    local a, s = priest(10, PAIN, BLAST, PENANCE, HOLYFIRE, SHOOT)
    s.setSeason(2)
    s.combat = false
    s.targetCombat = false
    M.expect(a, s, SDPS, BLAST, nil, 'leveling pull: Mind Blast')
    s.cooling(BLAST, 5)
    M.expect(a, s, SDPS, PENANCE, nil, 'pull: Penance before Shadowform')
    s.cooldown = {}
    s.combat = true
    s.targetCombat = true
    s.debuff('target', PAIN)
    s.cooling(BLAST, 5)
    M.expect(a, s, SDPS, PENANCE, nil, 'leveling: Penance damage')
    s.cooling(PENANCE, 5)
    M.expect(a, s, SDPS, SMITE, nil, 'no Mind Spike or Flay: Smite')
    a, s = shadow(VP, VT, SPIKE, SWD, PLAGUE)
    s.setSeason(2)
    s.buff('player', FORM)
    s.combat = false
    s.targetCombat = false
    M.expect(a, s, SDPS, VT, nil, 'pull: Vampiric Touch pre-cast')
    s.combat = true
    s.targetCombat = true
    M.expect(a, s, SDPS, VP, nil, 'Void Plague first')
    s.debuff('target', VP, { expirationTime = 120, duration = 30 })
    M.expect(a, s, SDPS, PAIN, nil, 'then Pain')
    s.debuff('target', PAIN, { expirationTime = 120, duration = 30 })
    M.expect(a, s, SDPS, VT, nil, 'then Vampiric Touch')
    s.debuff('target', VT, { expirationTime = 120, duration = 30 })
    M.expect(a, s, SDPS, BLAST, nil, 'Devouring Plague needs a forecast: Mind Blast on cooldown')
    s.clearAuras()
    s.buff('player', FORM)
    s.debuff('target', VP, { expirationTime = 101, duration = 30 })
    s.debuff('target', PAIN, { expirationTime = 120, duration = 30 })
    s.debuff('target', VT, { expirationTime = 120, duration = 30 })
    M.expect(a, s, SDPS, VP, nil, 'Void Plague under 1.5 s: refresh')
    s.engrave(413251)
    M.expect(a, s, SDPS, BLAST, nil, 'Pain and Suffering (a passive rune) keeps it rolling: no refresh, Mind Blast')
    s.clearAuras()
    s.buff('player', FORM)
    s.debuff('target', PAIN, { expirationTime = 120, duration = 30 })
    s.debuff('target', VT, { expirationTime = 120, duration = 30 })
    M.expect(a, s, SDPS, VP, nil, 'Pain and Suffering still applies a missing Void Plague')
    s.unengrave(413251)
    s.learn(VP)
    s.clearAuras()
    s.buff('player', FORM)

    for _, id in ipairs({ VP, PAIN, VT }) do
        s.debuff('target', id, { expirationTime = 120, duration = 30 })
    end

    s.cooling(BLAST, 5)
    M.expect(a, s, SSPIKE, SWD, nil, 'variant: Mind Blast cooling, Shadow Word: Death')
    M.expect(a, s, SDPS, SWD, nil, 'Shadow Word: Death while healthy')
    s.health.player = 40
    M.expect(a, s, SDPS, SPIKE, nil, 'hurt: no Death, Mind Spike filler')
    s.health.player = 100
    s.buff('player', 456549)
    M.expect(a, s, SDPS, FLAY, nil, 'Melting Faces: Mind Flay')
    s.auras.player.HELPFUL[#s.auras.player.HELPFUL] = nil
    s.cooling(SWD, 5)
    a.GetEquippedSetPieces = function(_, set) return set == 1938 and 6 or 0 end
    M.expect(a, s, SDPS, FLAY, nil, 'six-piece: Mind Flay replaces Mind Spike')
    M.expect(a, s, SSPIKE, SPIKE, nil, 'variant ignores the set: Mind Spike')
    a.GetEquippedSetPieces = function() return 0 end
    M.expect(a, s, SDPS, SPIKE, nil, 'no set: Mind Spike')
    s.unlearn(SPIKE)
    M.expect(a, s, SDPS, FLAY, nil, 'no Mind Spike rune: Mind Flay')
end)

test('SoD Mind Spike variant holds Mind Blast for three of your Mind Spike stacks', function()
    local a, s = shadow(VP, VT, SPIKE)
    s.setSeason(2)
    s.buff('player', FORM)

    for _, id in ipairs({ VP, PAIN, VT }) do
        s.debuff('target', id, { expirationTime = 120, duration = 30 })
    end

    M.expect(a, s, SSPIKE, BLAST, nil, 'a known Mind Spike whose rune is not engraved: Mind Blast is not held')
    s.engrave(SPIKE)
    M.expect(a, s, SSPIKE, SPIKE, nil, 'no stacks: Mind Spike')
    M.expect(a, s, SDPS, BLAST, nil, 'default: Mind Blast on cooldown')
    s.debuff('target', SPIKE, { applications = 2 })
    M.expect(a, s, SSPIKE, SPIKE, nil, 'two stacks: Mind Spike')
    s.auras.target.HARMFUL[#s.auras.target.HARMFUL] = nil
    s.debuff('target', SPIKE, { applications = 3 })
    M.expect(a, s, SSPIKE, BLAST, nil, 'three stacks: Mind Blast')
    s.auras.target.HARMFUL[#s.auras.target.HARMFUL] = nil
    s.debuff('target', SPIKE, { applications = 3, sourceUnit = 'party1' })
    M.expect(a, s, SSPIKE, SPIKE, nil, 'someone else\'s stacks do not count')
    s.unengrave(SPIKE)
    M.expect(a, s, SSPIKE, BLAST, nil, 'without the Mind Spike rune Mind Blast is not held')
end)

test('SoD damage: AoE, moving, wand, reminders', function()
    local a, s = shadow(VP, VT, SPIKE, SWD, SEAR, VZONE, 402799, 401977, 402789, 425294)
    s.setSeason(2)
    s.buff('player', FORM)

    for _, id in ipairs({ VP, PAIN, VT }) do
        s.debuff('target', id, { expirationTime = 120, duration = 30 })
    end

    s.near(3)
    M.expect(a, s, SDPS, BLAST, nil, 'three enemies: single target')
    s.near(4)
    M.expect(a, s, SDPS, VZONE, nil, 'four: Void Zone')
    s.cooling(VZONE, 20)
    M.expect(a, s, SDPS, SEAR, nil, 'then Mind Sear')
    s.cooldown = {}
    s.near(0)
    s.clearAuras()
    s.buff('player', FORM)
    s.moving = true
    M.expect(a, s, SDPS, VP, nil, 'moving: Void Plague')
    s.debuff('target', VP)
    M.expect(a, s, SDPS, PAIN, nil, 'moving: Pain')
    s.debuff('target', PAIN)
    M.expect(a, s, SDPS, SWD, nil, 'moving: Shadow Word: Death')
    s.health.player = 40
    stopped(a, s, SDPS, 'moving, hurt: stop')
    s.health.player = 100
    s.moving = false
    s.health.target = 20
    M.expect(a, s, SDPS, SHOOT, nil, 'dying solo target: wand')
    s.health.target = 100
    local lit = M.upkeep(a, s, SDPS)

    assert(
        not lit[402799] and not lit[401977] and not lit[402789] and not lit[425294],
        'normal mob, full mana: no cooldowns'
    )

    s.classification = 'worldboss'
    lit = M.upkeep(a, s, SDPS)
    assert(lit[402799] and lit[401977] and lit[402789], 'boss: Homunculi, Shadowfiend, Eye of the Void')
    s.classification = 'normal'
    s.mana.player = 10
    lit = M.upkeep(a, s, SDPS)
    assert(lit[401977] and lit[425294], 'drained: Shadowfiend and Dispersion')
    s.learn(EMBRACE)
    s.unlearn(VT)
    lit = M.upkeep(a, s, SDPS)
    assert(not lit[EMBRACE], 'Vampiric Embrace needs a long fight forecast')
end)

test('SoD healer: Penance, Prayer of Mending, Surge of Light, Circle of Healing, enemy target', function()
    local a, s = priest(
        60,
        PAIN,
        PENANCE,
        POM,
        FLASH,
        SHIELD,
        COH,
        POH,
        GREATER,
        HEAL1,
        RENEW,
        VP,
        HOLYFIRE,
        402004,
        425207,
        425284,
        401977
    )

    s.setSeason(2)
    s.group = true
    s.setTalents({ 0, 31, 20 })
    M.expect(a, s, SHEAL, VP, nil, 'enemy target, no forecast: Void Plague')
    s.debuff('target', VP)
    M.expect(a, s, SHEAL, PENANCE, nil, 'then Penance')
    s.cooling(PENANCE, 5)
    M.expect(a, s, SHEAL, HOLYFIRE, nil, 'then Holy Fire')
    s.cooldown = {}
    s.clearAuras()
    friend(s, 100)
    s.combat = false
    M.expect(a, s, SHEAL, POM, nil, 'pre-pull: Prayer of Mending')
    s.cooling(POM, 8)
    s.buff('target', 1243)
    stopped(a, s, SHEAL, 'pre-pull done')
    s.combat = true
    stopped(a, s, SHEAL, 'healthy, Mending cooling: nothing')
    s.cooldown = {}
    M.expect(a, s, SHEAL, POM, nil, 'Prayer of Mending whenever ready')
    s.cooling(POM, 8)
    s.health.target = 75
    M.expect(a, s, SHEAL, PENANCE, nil, 'Penance below 80%')
    s.cooling(PENANCE, 5)
    s.buff('player', SURGE)
    M.expect(a, s, SHEAL, FLASH, nil, 'Surge of Light: instant Flash Heal')
    s.auras.player.HELPFUL = {}
    M.expect(a, s, SHEAL, RENEW, nil, 'light damage: Renew')
    s.buff('target', RENEW)
    M.expect(a, s, SHEAL, HEAL1, nil, 'Heal')
    s.members(70, 70, 70)
    M.expect(a, s, SHEAL, COH, nil, 'three hurt: Circle of Healing')
    s.cooling(COH, 5)
    M.expect(a, s, SHEAL, POH, nil, 'then Prayer of Healing')
    s.party = {}
    s.cooldown = {}
    s.cooling(POM, 8)
    s.cooling(PENANCE, 5)
    s.health.target = 45
    M.expect(a, s, SHEAL, SHIELD, nil, 'below half: Shield')
    s.debuff('target', 6788)
    M.expect(a, s, SHEAL, GREATER, nil, 'Weakened Soul: Greater Heal')
    s.health.target = 25
    M.expect(a, s, SHEAL, FLASH, nil, 'below 30%: Flash Heal')
    local lit = M.upkeep(a, s, SHEAL)
    assert(lit[402004], 'Pain Suppression on a dying target')
    s.members(45, 40, 40)
    lit = M.upkeep(a, s, SHEAL)
    assert(lit[425207] and lit[425284], 'party in trouble: Barrier and Spirit of the Redeemer')
    s.mana.player = 50
    lit = M.upkeep(a, s, SHEAL)
    assert(lit[401977], 'Shadowfiend below 60% mana')
end)

test('SoD Tavern healer: Shield whenever possible, Serendipity heals, Flash Heal filler', function()
    local a, s = priest(60, PENANCE, POM, FLASH, SHIELD, COH, POH, GREATER, HEAL1, RENEW)
    s.setSeason(2)
    s.group = true
    s.setTalents({ 0, 31, 20 })
    friend(s, 85)
    M.expect(a, s, STAVERN, POM, nil, 'Prayer of Mending on cooldown')
    s.cooling(POM, 8)
    M.expect(a, s, STAVERN, RENEW, nil, 'no Soul Warding engraved: no Shield at 85%, Renew')
    s.engrave(402000, 413248)
    M.expect(a, s, STAVERN, SHIELD, nil, 'Soul Warding (a passive rune): Shield whenever it can be taken')
    s.debuff('target', 6788)
    M.expect(a, s, STAVERN, RENEW, nil, 'minor damage: Renew')
    s.buff('target', RENEW)
    M.expect(a, s, STAVERN, FLASH, nil, 'Flash Heal builds Serendipity')
    s.unengrave(413248)
    s.learn(413248)
    stopped(a, s, STAVERN, 'no Serendipity engraved: no Flash Heal on minor injuries')
    s.engrave(413248)
    s.health.target = 65
    M.expect(a, s, STAVERN, PENANCE, nil, 'heavy damage: Penance')
    s.cooling(PENANCE, 5)
    M.expect(a, s, STAVERN, FLASH, nil, 'no stacks: Flash Heal')
    s.buff('player', 413247, { applications = 3 })
    M.expect(a, s, STAVERN, GREATER, nil, 'three Serendipity: Greater Heal')
    s.members(70, 70, 70)
    M.expect(a, s, STAVERN, COH, nil, 'three hurt: Circle')
    s.cooling(COH, 5)
    M.expect(a, s, STAVERN, POH, nil, 'three Serendipity and three hurt: Prayer of Healing')
end)

finish()
