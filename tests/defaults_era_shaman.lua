-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era and Season of Discovery Shaman premades. Real predicates, build context (season
-- rulesets, talents, weapon enchants), catalog, composition, sequence and publisher; WoW
-- observations are modeled in tests/fixtures/era_rogue_shaman_warlock_warrior.lua.
local M = dofile('tests/fixtures/era_rogue_shaman_warlock_warrior.lua')
local test, finish = M.F.suite()

local ENH, ENHWT, ELE, ELEWS, RESTO, RESTOWT =
    'rm.era.shaman.enhancement',
    'rm.era.shaman.enhancement.warcrafttavern',
    'rm.era.shaman.elemental',
    'rm.era.shaman.elemental.simulator',
    'rm.era.shaman.restoration',
    'rm.era.shaman.restoration.warcrafttavern'

local SENH, SELE, SRESTO, STANK =
    'rm.sod.shaman.enhancement', 'rm.sod.shaman.elemental', 'rm.sod.shaman.restoration', 'rm.sod.shaman.tank'

local VANILLA, SEASON = { ENH, ENHWT, ELE, ELEWS, RESTO, RESTOWT }, { SENH, SELE, SRESTO, STANK }

local function shaman(level, ...)
    local f, s = M.fixture('SHAMAN', { level = level })
    M.know(s, 6603, 403, 331, 8017)

    for _, set in ipairs({ ... }) do
        M.know(s, unpack(set))
    end

    s.range[6603] = true
    s.mainEnchant = 1663
    return f, s
end

local kit = {8042, 8050, 8056, 324, 8075, 3599, 1535, 8190, 8512, 8835, 5394, 5675, 8004, 17364, 8232}

local function first(f, s, id)
    return (M.first(f, s, id))
end

local function stopped(f, s, id)
    local x, r = M.first(f, s, id)
    return x == nil and r.status == 'stopped', r
end

test(
    'every premade registers valid; vanilla on every realm, SoD only on Season of Discovery, above every vanilla premade',
    function()
        local f, s = shaman(60)
        local a = f.addon
        -- The same-switch source variants ship disabled.
        local off = { [ENHWT] = true, [ELEWS] = true, [RESTOWT] = true }

        for _, id in ipairs(VANILLA) do
            local row = assert(M.row(f, id), id)

            assert(
                row.validation.valid
                    and row.validation.resolved
                    and row.eligible == not off[id]
                    and (M.body(a, id).disabled == true) == (off[id] == true)
                    and a:GetDefaultRotationComposition(id),
                id
            )
        end

        for _, id in ipairs(SEASON) do
            assert(M.row(f, id).validation.valid and not M.row(f, id).eligible, id .. ' leaked onto a standard realm')
        end

        s.season = 2

        for _, id in ipairs({ SENH, SELE, SRESTO, STANK }) do
            assert(M.row(f, id).eligible, id)
        end

        for _, id in ipairs(SEASON) do
            for _, v in ipairs(VANILLA) do
                assert(M.body(a, id).priority > M.body(a, v).priority, id .. ' must outrank ' .. v)
            end
        end

        do
            local sw = M.row(f, STANK).envelope.body.switch

            assert(
                sw.type == 'AND' and sw.value[1].type == 'LEVEL' and sw.value[1].value == 30,
                'tank switch holds level 30'
            )
        end
    end
)

test(
    'auto-select by talent tree, with Enhancement owning levels 1–9, no points and ties; the Way of Earth tank by its imbue',
    function()
        local f, s = shaman(5)
        local a = f.addon

        for _, season in ipairs({ false, 2 }) do
            s.season = season or nil
            local enh, ele, resto = season and SENH or ENH, season and SELE or ELE, season and SRESTO or RESTO
            s.level = 5
            s.talents = { 0, 0, 0 }
            assert(M.selected(f, s) == enh, 'level 5')
            s.level = 40
            assert(M.selected(f, s) == enh, 'no points spent')
            s.talents = { 10, 10, 0 }
            assert(M.selected(f, s) == enh, 'a tie')
            s.talents = { 31, 0, 20 }
            assert(M.selected(f, s) == ele)
            s.talents = { 0, 21, 30 }
            assert(M.selected(f, s) == resto)
            s.talents = { 0, 31, 0 }
            assert(M.selected(f, s) == enh)
        end

        s.season = 2
        s.talents = { 0, 31, 0 }
        s.mainEnchant = 1663
        assert(M.selected(f, s) == SENH, 'Rockbiter without Way of Earth: Enhancement')
        M.know(s, 8232)
        assert(M.selected(f, s) == SENH, 'Windfury known and Rockbiter kept, without the rune: Enhancement')
        M.engrave(s, 408531)
        assert(M.selected(f, s) == STANK, 'Way of Earth (a passive rune) engraved: tank')
        s.talents = { 31, 0, 0 }
        assert(M.selected(f, s) == STANK, 'either tree tanks')
        M.unengrave(s, 408531)
        M.engrave(s, 408680)
        assert(M.selected(f, s) == STANK, 'either Way of Earth spell')
        M.unengrave(s, 408680)
        assert(M.selected(f, s) == SELE, 'no Way of Earth: Elemental')
        s.mainEnchant = false
        assert(M.selected(f, s) == SELE)
        s.season = nil
        s.talents = { 31, 0, 0 }
        assert(a:SetDefaultRotationEnabled(ELE, false))
        assert(M.selected(f, s) == ENH, 'the variants ship disabled: the Enhancement catch-all runs')

        for _, id in ipairs({ ELEWS, RESTOWT, ENHWT }) do
            assert(a:SetDefaultRotationEnabled(id, true))
        end

        assert(M.selected(f, s) == ELEWS)
        s.talents = { 0, 0, 31 }
        assert(a:SetDefaultRotationEnabled(RESTO, false))
        assert(M.selected(f, s) == RESTOWT)
        s.talents = { 0, 0, 0 }
        assert(a:SetDefaultRotationEnabled(ENH, false))
        assert(M.selected(f, s) == ENHWT)
    end
)

test('casts, channels and Ghost Wolf stop with Attack suppressed', function()
    for _, id in ipairs({ ENH, ELE, RESTO, SENH, SELE, SRESTO, STANK }) do
        local f, s = shaman(60, kit)

        for _, key in ipairs({ 'cast', 'channel' }) do
            s[key] = true
            local ok, r = stopped(f, s, id)
            assert(ok and r.suppressAttack, id .. ' ' .. key)
            s[key] = false
        end

        s.buffs = { { id = 2645 } }
        local ok, r = stopped(f, s, id)
        assert(ok and r.suppressAttack, id .. ' Ghost Wolf')
    end
end)

test(
    'Enhancement: Bolt pull from range, interrupt, raid shocks, totems on packs, Stormstrike and shock order',
    function()
        local f, s = shaman(40, kit)
        s.combat = false
        s.targetCombat = false
        s.range[6603] = false
        assert(first(f, s, ENH) == 403, 'pull with Bolt from range')
        s.range[6603] = true
        assert(stopped(f, s, ENH), 'in melee: auto attack pulls')
        s.combat = true
        s.targetCombat = true
        s.exists = false
        assert(stopped(f, s, ENH))
        s.exists = true
        s.targetCast = 'Heal'
        assert(first(f, s, ENH) == 8042)
        s.targetCast = nil
        assert(first(f, s, ENH) == 17364)
        s.nopower[17364] = true
        s.instance = 'raid'
        assert(first(f, s, ENH) == 8056, 'raids: Frost Shock')
        s.nopower[8056] = true
        local ok, r = stopped(f, s, ENH)
        assert(ok and not r.suppressAttack)
        s.instance = nil
        s.nopower[8056] = nil
        s.enemies = { 0, 0, 0 }
        assert(first(f, s, ENH) == 1535)
        s.totems[1] = { 5, 1535 }
        assert(first(f, s, ENH) == 8050, 'Fire Nova up: on to single target')
        s.enemies = {}
        s.totems = {}
        s.debuffs = { { id = 17364 } }
        assert(first(f, s, ENH) == 8042, 'Earth Shock into the Stormstrike debuff')
        s.debuffs = {}
        assert(first(f, s, ENH) == 8050)
        s.debuffs = { { id = 8050 } }
        assert(first(f, s, ENH) == 8042)
        s.mana = 40
        assert(first(f, s, ENH) == nil, 'below half mana: melee')
        s.ttd = 1
        assert(first(f, s, ENH) == 8042, 'finishing shock')
        s.ttd = nil
        s.range[6603] = false
        assert(first(f, s, ENH) == 403)
        s.debuffs = {}
        s.targetHealth = 40
        s.range[6603] = true
        s.mana = 100
        assert(first(f, s, ENH) == 8042, 'no Flame Shock on a target about to die')
    end
)

test('Enhancement reminders: Rockbiter solo, Windfury in dungeons, shield, totems and healing', function()
    local f, s = shaman(40, kit)
    s.mainEnchant = false
    local u = M.upkeep(f, s, ENH)
    assert(u['enh-rockbiter-weapon'] == 8017 and not u['enh-windfury-weapon'])
    s.instance = 'party'
    u = M.upkeep(f, s, ENH)
    assert(u['enh-windfury-weapon'] == 8232 and not u['enh-rockbiter-weapon'])
    s.mainEnchant = 1663
    assert(M.upkeep(f, s, ENH)['enh-windfury-weapon'], 'Rockbiter replaced in a dungeon')
    s.mainEnchant = 1669
    assert(not M.upkeep(f, s, ENH)['enh-windfury-weapon'])
    s.instance = nil
    s.mainEnchant = 1663
    u = M.upkeep(f, s, ENH)
    assert(u['enh-lightning-shield'] == 324 and not u['enh-water-shield'])
    s.buffs = { { id = 324 } }
    assert(not u['enh-strength-of-earth'], 'a normal mob solo is not a long fight')
    s.classification = 'elite'
    u = M.upkeep(f, s, ENH)

    assert(
        u['enh-strength-of-earth'] == 8075
            and u['enh-searing-totem'] == 3599
            and u['enh-grace-of-air'] == 8835
            and u['enh-healing-stream'] == 5394
            and not u['enh-windfury-totem']
    )

    s.group = true
    u = M.upkeep(f, s, ENH)
    assert(u['enh-windfury-totem'] == 8512 and u['enh-mana-spring'] == 5675 and not u['enh-grace-of-air'])
    s.totems = { { 5 }, { 5 }, { 5 }, { 5 } }
    u = M.upkeep(f, s, ENH)
    assert(not u['enh-strength-of-earth'] and not u['enh-windfury-totem'])
    s.group = false
    s.health = 20
    assert(M.upkeep(f, s, ENH)['enh-emergency-lesser-wave'] == 8004)
    s.combat = false
    s.hostile = false
    s.health = 50
    u = M.upkeep(f, s, ENH)
    assert(u['enh-heal-after-pull'] == 331 and not u['enh-stoneclaw'], 'Hardcore totems are listed off')
end)

test(
    'Warcraft Tavern Enhancement: Flame Shock before shocks, Frost Shock on high group threat, Windfury once learned',
    function()
        local f, s = shaman(40, kit)
        s.nopower[17364] = true
        s.mainEnchant = false
        assert(first(f, s, ENHWT) == 8050)
        s.debuffs = { { id = 8050 } }
        assert(first(f, s, ENHWT) == 8042)
        s.group = true
        s.threat = 1
        assert(first(f, s, ENHWT) == 8056)
        assert(M.upkeep(f, s, ENHWT)['enh-wt-windfury-weapon'] == 8232)
    end
)

test('Elemental: execute shock, moving shocks, solo melee, packs, Chain Lightning on procs, Bolt filler', function()
    local f, s = shaman(40, kit, { 421, 16166, 16188 })
    s.talents = { 31, 0, 0 }
    s.range[6603] = false
    assert(first(f, s, ELE) == 403)
    s.buffs = { { id = 16166 } }
    assert(first(f, s, ELE) == 421)
    s.buffs = { { id = 16246 } }
    assert(first(f, s, ELE) == 421, 'Clearcasting')
    s.buffs = {}
    s.ttd = 2
    assert(first(f, s, ELE) == 8042)
    s.ttd = nil
    s.moving = true
    assert(first(f, s, ELE) == 8050)
    s.debuffs = { { id = 8050 } }
    assert(first(f, s, ELE) == 8056)
    s.nopower[8056] = true
    assert(stopped(f, s, ELE), 'moving: no cast')
    s.moving = false
    s.debuffs = {}
    s.range[6603] = true
    assert(first(f, s, ELE) == 8042, 'solo in melee: Earth Shock')
    s.targetHealth = 20
    assert(stopped(f, s, ELE), 'nearly dead: melee')
    s.group = true
    s.targetHealth = 100
    assert(first(f, s, ELE) == 403, 'groups keep casting')
    s.enemies = { 0, 0, 0 }
    assert(first(f, s, ELE) == 1535)
    s.range[6603] = false
    assert(first(f, s, ELE) == 421, 'out of melee: Chain Lightning')
    local u = M.upkeep(f, s, ELE)
    assert(u['ele-elemental-mastery'] == 16166)
    s.health = 20
    assert(M.upkeep(f, s, ELE)['ele-natures-swiftness'] == 16188)
    s.instance = 'raid'
    s.mainEnchant = false
    assert(not M.upkeep(f, s, ELE)['ele-rockbiter-weapon'], 'no imbue in raids')
end)

test('simulator Elemental: Chain Lightning on cooldown, Earth Shock in Elemental Mastery', function()
    local f, s = shaman(60, kit, { 421, 16166 })
    s.talents = { 31, 0, 0 }
    s.range[6603] = false
    s.group = true
    assert(first(f, s, ELEWS) == 421 and first(f, s, ELE) == 403)
    s.nopower[421] = true
    s.buffs = { { id = 16166 } }
    assert(first(f, s, ELEWS) == 8042)
end)

test('Restoration heals the friendly target by health; fights a hostile one; Tavern leads with Chain Heal', function()
    local f, s = shaman(40, kit, { 16188, 1064, 526, 2870, 16190 })
    s.talents = { 0, 0, 31 }
    s.friend, s.hostile = true, false
    s.targetHealth = 95
    assert(stopped(f, s, RESTO), 'healthy target: nothing')
    s.targetHealth = 85
    assert(first(f, s, RESTO) == 331 and first(f, s, RESTOWT) == 1064)
    s.targetHealth = 35
    assert(first(f, s, RESTO) == 8004)
    s.targetHealth = 25
    assert(first(f, s, RESTO) == 16188)
    s.buffs = { { id = 16188 } }
    assert(first(f, s, RESTO) == 331)
    s.buffs = {}
    s.targetHealth = 80
    s.debuffs = { { id = 1, dispel = 'Poison' } }
    assert(first(f, s, RESTO) == 526)
    s.debuffs = { { id = 1, dispel = 'Disease' } }
    assert(first(f, s, RESTO) == 2870)
    s.friend, s.hostile = false, true
    s.debuffs = {}
    s.targetHealth = 100
    s.range[6603] = false
    assert(first(f, s, RESTO) == 8050)
    s.debuffs = { { id = 8050 } }
    assert(first(f, s, RESTO) == 403)
    s.exists = false
    assert(first(f, s, RESTO) == nil, 'no target: no advice')
    s.exists = true
    s.group = true
    assert(M.upkeep(f, s, RESTO)['resto-mana-spring'])
    s.mana = 50
    assert(M.upkeep(f, s, RESTO)['resto-mana-tide'] == 16190)
end)

test(
    'SoD Enhancement: Maelstrom spells at five stacks, Stormstrike, Lava Lash, Flame Shock; imbues per weapon',
    function()
        local f, s = shaman(60, kit, { 408490, 408507, 425339, 674, 8024 })
        s.season = 2
        s.mainEnchant = 283
        s.offEnchant = true
        M.engrave(s, 408507)
        assert(first(f, s, SENH) == 17364)
        s.nopower[17364] = true
        assert(first(f, s, SENH) == 408507)
        s.nopower[408507] = true
        s.buffs = { { id = 408505, stacks = 5 } }
        assert(first(f, s, SENH) == 408490)
        s.buffs = {}
        assert(first(f, s, SENH) == 8050)
        s.debuffs = { { id = 8050 } }
        assert(first(f, s, SENH) == 8042)
        s.nopower[8042] = true
        assert(first(f, s, SENH) == 425339)
        s.enemies = { 0, 0, 0 }
        assert(first(f, s, SENH) == 8190)
        s.totems[1] = 5
        M.know(s, 408341)
        assert(first(f, s, SENH) == 408341, 'Fire Nova from a fire totem')
        s.enemies = {}
        s.totems = {}
        local u = M.upkeep(f, s, SENH)
        assert(not u['sod-enh-windfury-weapon'] and not u['sod-enh-offhand-flametongue'], 'both weapons enchanted')
        s.offEnchant = false
        s.gear = { [16] = M.GEAR.SWORD }
        u = M.upkeep(f, s, SENH)

        assert(
            not u['sod-enh-offhand-flametongue'] and not u['sod-enh-offhand-windfury'],
            'Dual Wield known, nothing in the off hand'
        )

        s.gear[17] = M.GEAR.SHIELD
        u = M.upkeep(f, s, SENH)
        assert(not u['sod-enh-offhand-flametongue'] and not u['sod-enh-offhand-windfury'], 'a shield takes no imbue')
        s.gear[17] = M.GEAR.SWORD
        u = M.upkeep(f, s, SENH)

        assert(
            u['sod-enh-offhand-flametongue'] == 8024
                and not u['sod-enh-offhand-windfury']
                and not u['sod-enh-offhand-windfury-icyveins']
        )

        M.unengrave(s, 408507)
        u = M.upkeep(f, s, SENH)

        assert(
            u['sod-enh-offhand-windfury'] == 8232 and not u['sod-enh-offhand-flametongue'],
            'no Lava Lash rune: Windfury off hand'
        )

        M.engrave(s, 408507)
        s.mainEnchant = 1663
        assert(M.upkeep(f, s, SENH)['sod-enh-windfury-weapon'] == 8232, 'Windfury replaces Rockbiter')
    end
)

test(
    'SoD Elemental: Flame Shock upkeep, Lava Burst while it lasts, Rolling Thunder shock, Power Surge, two-target Chain Lightning',
    function()
        local f, s = shaman(60, kit, { 408490, 421, 408514, 16166, 8024 })
        s.season = 2
        s.talents = { 31, 0, 0 }
        assert(first(f, s, SELE) == 8050)
        s.debuffs = { { id = 8050, expires = 110 } }
        assert(first(f, s, SELE) == 408490)
        s.nopower[408490] = true
        s.buffs = { { id = 324, stacks = 9 } }
        assert(first(f, s, SELE) == 8042)
        s.buffs = {}
        s.enemies = { 0, 0 }
        assert(first(f, s, SELE) == 421)
        s.enemies = {}
        assert(first(f, s, SELE) == 403)
        s.debuffs[1].expires = 102
        assert(first(f, s, SELE) == 8050, 'renewed below three seconds')
        s.nopower[408490] = nil
        s.debuffs[1].expires = 101
        s.nopower[8050] = true
        assert(first(f, s, SELE) == 403, 'Flame Shock will not outlast the cast')
        s.buffs = { { id = 440285 } }
        assert(first(f, s, SELE) == 408490, 'Power Surge Lava Burst')
        s.mainEnchant = 1663
        local u = M.upkeep(f, s, SELE)
        assert(u['sod-ele-flametongue'] == 8024 and u['sod-ele-earth-shield'] == 408514)
    end
)

test(
    'SoD Restoration: Riptide and Lesser Healing Wave for emergencies, Power Surge Chain Heal, Riptide for Tidal Waves',
    function()
        local f, s = shaman(60, kit, { 408521, 1064, 415236, 408510, 408514 })
        s.season = 2
        s.talents = { 0, 0, 31 }
        s.friend, s.hostile = true, false
        s.targetHealth = 35
        assert(first(f, s, SRESTO) == 408521)
        s.nopower[408521] = true
        assert(first(f, s, SRESTO) == 8004)
        s.nopower[408521] = nil
        s.targetHealth = 92
        assert(first(f, s, SRESTO) == 408521)
        s.nopower[408521] = true
        assert(stopped(f, s, SRESTO))
        s.targetHealth = 85
        assert(first(f, s, SRESTO) == 331)
        s.buffs = { { id = 440285 } }
        assert(first(f, s, SRESTO) == 1064)
        local u = M.upkeep(f, s, SRESTO)
        assert(u['sod-resto-water-shield'] == 408510 and u['sod-resto-earth-shield'] == 408514)
    end
)

test(
    'SoD tank: Flame Shock pull, Earth Shock taunt, Molten Blast on packs, Lava Burst on Power Surge; Rockbiter kept',
    function()
        local f, s = shaman(60, kit, { 408490, 425339, 408696, 440580 })
        s.season = 2
        s.combat = false
        s.targetCombat = false
        assert(first(f, s, STANK) == 8050)
        s.combat = true
        s.targetCombat = true
        s.targettarget = 'party1'
        assert(first(f, s, STANK) == 8042, 'taunt')
        s.targettarget = 'player'
        assert(first(f, s, STANK) == 8050)
        s.debuffs = { { id = 8050, expires = 130 } }
        assert(first(f, s, STANK) == 408490)
        s.nopower[408490] = true
        assert(first(f, s, STANK) == 17364)
        s.enemies = { 0, 0 }
        assert(first(f, s, STANK) == 425339)
        s.enemies = {}
        s.mainEnchant = 283
        local u = M.upkeep(f, s, STANK)
        assert(u['sod-tank-rockbiter'] == 8017 and u['sod-tank-spirit-of-the-alpha'] == 408696)
    end
)

test('real publisher highlights the selected premade and follows talents and season', function()
    local f, s = shaman(40, kit)
    local poll, selected = M.publisher(f, s)
    poll()
    assert(selected() == ENH and f.addon.currentSpell == 17364)
    s.talents = { 31, 0, 0 }
    f.addon:InvalidateBuildContext('talents')
    poll()
    assert(selected() == ELE)
    s.season = 2
    s.mainEnchant = 283
    f.addon:InvalidateBuildContext('client')
    poll()
    assert(selected() == SELE)
    s.mainEnchant = 1663
    M.engrave(s, 408531)
    poll()
    assert(selected() == STANK, 'Way of Earth engraved: tank')
end)

finish()
