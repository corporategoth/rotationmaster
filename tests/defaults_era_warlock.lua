-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era and Season of Discovery Warlock premades. Real predicates, build context (season
-- rulesets, talents), catalog, composition, sequence and publisher; WoW observations are modeled
-- in tests/fixtures/era_rogue_shaman_warlock_warrior.lua.
local M = dofile('tests/fixtures/era_rogue_shaman_warlock_warrior.lua')
local test, finish = M.F.suite()
local DPS, WT, IV = 'rm.era.warlock.dps', 'rm.era.warlock.dps.warcrafttavern', 'rm.era.warlock.dps.icyveins'

local TANK, FIRE, FIREIV, SHADOW, SHADOWWS =
    'rm.sod.warlock.tank',
    'rm.sod.warlock.fire',
    'rm.sod.warlock.fire.icyveins',
    'rm.sod.warlock.shadow',
    'rm.sod.warlock.shadow.wowsims'

local VANILLA, SEASON = { DPS, WT, IV }, { TANK, FIRE, FIREIV, SHADOW, SHADOWWS }

local function warlock(level, ...)
    local f, s = M.fixture('WARLOCK', { level = level })
    M.know(s, 686, 348, 687, 688)

    for _, set in ipairs({ ... }) do
        M.know(s, unpack(set))
    end

    s.pet = true
    return f, s
end

-- A level-60 kit: Corruption, Agony, Life Tap, Drain Life, Drain Soul, Demon Armor, Voidwalker,
-- Doom, Elements, Shadow, Siphon Life, Shoot, Searing Pain, Rain of Fire.
local kit = {172, 980, 1454, 689, 1120, 706, 697, 603, 1490, 17862, 18265, 5019, 5676, 5740}

local function first(f, s, id)
    return (M.first(f, s, id))
end

local function stopped(f, s, id)
    local x, r = M.first(f, s, id)
    return x == nil and r.status == 'stopped', r
end

local function dots(s, ...)
    for _, id in ipairs({ ... }) do
        s.debuffs[#s.debuffs + 1] = { id = id }
    end
end

test(
    'every premade registers valid 1–60; vanilla on every realm, SoD only on Season of Discovery, above every vanilla premade',
    function()
        local f, s = warlock(60)
        local a = f.addon
        -- The same-switch source variants ship disabled.
        local off = { [WT] = true, [IV] = true, [FIREIV] = true, [SHADOWWS] = true }

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
            local row = M.row(f, id)

            assert(
                row.validation.valid
                    and row.validation.resolved
                    and not row.eligible
                    and (M.body(a, id).disabled == true) == (off[id] == true),
                id
            )
        end

        s.season = 2

        for _, id in ipairs(SEASON) do
            assert(M.row(f, id).eligible == not off[id], id)
        end

        for _, id in ipairs(SEASON) do
            for _, v in ipairs(VANILLA) do
                assert(M.body(a, id).priority > M.body(a, v).priority, id .. ' must outrank ' .. v)
            end
        end
    end
)

test(
    'auto-select: one vanilla premade for every tree; SoD by engraved hands and bracer runes; variants when disabled',
    function()
        local f, s = warlock(1)
        local a = f.addon

        for _, level in ipairs({ 1, 10, 40, 60 }) do
            s.level = level
            s.season = nil

            for _, talents in ipairs({ { 0, 0, 0 }, { 31, 0, 20 }, { 0, 21, 30 }, { 10, 10, 10 } }) do
                s.talents = talents
                assert(M.selected(f, s) == DPS, level)
            end

            s.season = 2
            assert(M.selected(f, s) == SHADOW, 'SoD catch-all at ' .. level)
        end

        M.know(s, 412758)
        assert(M.selected(f, s) == SHADOW, 'Incinerate known without its rune: Shadow')
        s.known[412758] = false
        M.engrave(s, 412758)
        assert(M.selected(f, s) == FIRE, 'Incinerate')
        M.unengrave(s, 412758)
        M.engrave(s, 403629)
        assert(M.selected(f, s) == FIRE, 'Chaos Bolt')
        M.engrave(s, 403789)
        assert(M.selected(f, s) == TANK, 'Metamorphosis wins')
        M.unengrave(s, 403789)
        assert(a:SetDefaultRotationEnabled(FIRE, false))
        assert(M.selected(f, s) == SHADOW, 'the Icy Veins Fire variant ships disabled')

        for _, id in ipairs({ FIREIV, SHADOWWS, WT, IV }) do
            assert(a:SetDefaultRotationEnabled(id, true))
        end

        assert(M.selected(f, s) == FIREIV)
        M.unengrave(s, 403629)
        assert(a:SetDefaultRotationEnabled(SHADOW, false))
        assert(M.selected(f, s) == SHADOWWS)
        s.season = nil
        assert(a:SetDefaultRotationEnabled(DPS, false))
        assert(M.selected(f, s) == WT)
        assert(a:SetDefaultRotationEnabled(WT, false))
        assert(M.selected(f, s) == IV)
    end
)

test('casts, channels, no target and another player\'s mob stop without melee; a group may join a pull', function()
    for _, id in ipairs({ DPS, WT, IV, TANK, FIRE, SHADOW }) do
        local f, s = warlock(60, kit)

        if id ~= DPS and id ~= WT and id ~= IV then
            s.season = 2
        end

        s.cast = true
        local ok, r = stopped(f, s, id)
        assert(ok and r.suppressAttack, id)
        s.cast = false
        s.channel = true
        assert(stopped(f, s, id), id .. ' channel kept')
        s.channel = false
        s.exists = false
        assert(stopped(f, s, id))
        s.exists = true
        s.combat = false
        assert(stopped(f, s, id), id .. ' tagged by someone else')
        s.group = true
        assert(first(f, s, id), id .. ' joins the group pull')
        s.group = false
        s.targetCombat = false
        assert(first(f, s, id), id .. ' pulls a fresh mob')
    end

    local f, s = warlock(60, kit, { 427717, 1120 })
    s.season = 2
    s.channel = true
    s.channelSpell = 1120
    dots(s, 427717, 403677, 426320, 980, 172, 18265)
    assert(stopped(f, s, SHADOWWS), 'wowsims: nothing due, keep draining')
    s.debuffs = {}
    assert(first(f, s, SHADOWWS) == 427717, 'wowsims: clip the Drain Soul channel for a due DoT')

    for _, id in ipairs({ 1949, 755, 689 }) do
        s.channelSpell = id
        local ok, r = stopped(f, s, SHADOWWS)
        assert(ok and r.suppressAttack, 'wowsims: channel ' .. id .. ' (Hellfire, Health Funnel, Drain Life) is kept')
    end

    s.channelSpell = nil
    assert(stopped(f, s, SHADOWWS), 'wowsims: a channel it cannot name is kept')
end)

test(
    'leveling: Immolate and Shadow Bolt at 1; curse, DoTs, then solo sustain and the wand as learned; groups never wand',
    function()
        local f, s = warlock(1)
        assert(first(f, s, DPS) == 348)
        dots(s, 348)
        assert(first(f, s, DPS) == 686)
        s.debuffs = {}
        s.mana = 30
        assert(first(f, s, DPS) == 686, 'solo Immolate needs 40% mana')
        s.mana = 100
        f, s = warlock(40, kit)
        assert(first(f, s, DPS) == 980, 'curse first')
        dots(s, 980)
        assert(first(f, s, DPS) == 348)
        dots(s, 348)
        assert(first(f, s, DPS) == 172)
        dots(s, 172)
        assert(first(f, s, DPS) == 18265)
        dots(s, 18265)
        assert(first(f, s, DPS) == 5019, 'healthy solo Warlock wands')
        s.autorepeat = true
        local ok, r = stopped(f, s, DPS)
        assert(ok and r.suppressAttack, 'wand running')
        s.autorepeat = false
        s.health = 50
        assert(first(f, s, DPS) == 689)
        s.health = 90
        s.mana = 50
        assert(first(f, s, DPS) == 1454)
        s.mana = 100
        s.usable[5019] = false
        assert(first(f, s, DPS) == 686, 'no wand: Shadow Bolt')
        s.usable[5019] = nil
        s.group = true
        assert(first(f, s, DPS) == 686, 'groups never wand')
    end
)

test('a dying solo target gets Drain Soul or a finisher, never new DoTs', function()
    local f, s = warlock(40, kit)
    s.targetHealth = 10
    assert(first(f, s, DPS) == 1120, 'Drain Soul for a shard')
    s.items[6265] = 3
    assert(first(f, s, DPS) == 5019, 'shards enough: wand, no DoTs')
    M.know(s, 17877)
    assert(first(f, s, DPS) == 17877)
    s.known[17877] = false
    s.talent['1:4'] = 1
    assert(first(f, s, DPS) == 1120, 'Improved Drain Soul')
    s.talent['1:4'] = 0
    s.usable[5019] = false
    assert(stopped(f, s, DPS), 'nothing to finish with: stop, no DoTs')
    s.classification = 'elite'
    assert(first(f, s, DPS) == 980, 'elites keep the full rotation')
    s.classification = 'normal'
    s.group = true
    assert(first(f, s, DPS) == 980)
end)

test(
    'group finishers and the raid curse: Shadow for a Shadow build, Elements when Shadow is taken; Siphon Life on Shadow Vulnerability',
    function()
        local f, s = warlock(60, kit, { 17877, 18788 })
        s.group = true
        s.instance = 'raid'
        s.classification = 'worldboss'
        assert(first(f, s, DPS) == 17862, 'Demonic Sacrifice build: Curse of Shadow')
        s.debuffs = { { id = 17862, source = 'raid2' } }
        assert(first(f, s, DPS) == 1490)
        s.debuffs = { { id = 1490, source = 'raid3' }, { id = 17862, source = 'raid2' } }
        s.ttd = 90
        assert(first(f, s, DPS) == 603, 'Doom on a long fight')
        s.ttd = nil
        assert(first(f, s, DPS) == 980)
        dots(s, 980, 348, 172)
        assert(first(f, s, DPS) == 686, 'raid Siphon Life waits for Shadow Vulnerability')
        s.debuffs[#s.debuffs + 1] = { id = 17800, source = 'raid4' }
        assert(first(f, s, DPS) == 18265)
        assert(first(f, s, IV) == 686, 'Icy Veins: no Siphon Life in raids')
        s.debuffs = { { id = 980 } }
        assert(first(f, s, IV) == 172, 'Icy Veins: no Immolate in raids')
        s.ttd = 1
        assert(first(f, s, DPS) == 17877, 'Shadowburn in the last seconds')
        s.ttd = 3
        assert(first(f, s, DPS) == 5676, 'Searing Pain')
    end
)

test('moving: instants only, Corruption with Improved Corruption 5/5, then stop', function()
    local f, s = warlock(60, kit)
    s.moving = true
    assert(first(f, s, DPS) == 980, 'curse is instant')
    dots(s, 980)
    assert(first(f, s, DPS) == 18265)
    dots(s, 18265)
    s.mana = 80
    assert(first(f, s, DPS) == 1454)
    s.mana = 100
    assert(stopped(f, s, DPS), 'nothing instant left')
    s.talent['1:2'] = 5
    assert(first(f, s, DPS) == 172)
end)

test('packs: Rain of Fire on three engaged enemies, then the main target keeps its DoTs', function()
    local f, s = warlock(60, kit)
    s.enemies = { 0, 0, 0 }
    assert(first(f, s, DPS) == 5740)
    s.nopower[5740] = true
    assert(first(f, s, DPS) == 980)
    s.enemies = { 0, 0 }
    s.nopower[5740] = nil
    assert(first(f, s, DPS) == 980, 'two enemies: single target')
end)

test('reminders: armor, pets by situation, sacrifices, Healthstone and Health Funnel', function()
    local f, s = warlock(60, kit, { 18708, 18788, 712, 755 })
    s.pet = false
    s.combat = false
    local u = M.upkeep(f, s, DPS)
    assert(u['lock-demon-armor'] == 706 and not u['lock-demon-skin'])
    s.buffs = { { id = 687 } }
    assert(M.upkeep(f, s, DPS)['lock-demon-armor'], 'Demon Armor replaces Skin')
    s.buffs = { { id = 706 } }
    u = M.upkeep(f, s, DPS)
    assert(not u['lock-demon-armor'] and u['lock-voidwalker'] == 697 and not u['lock-imp'])
    s.group = true
    u = M.upkeep(f, s, DPS)
    assert(u['lock-succubus'] == 712 and not u['lock-imp'], 'Succubus for Demonic Sacrifice')
    s.known[18788] = false
    u = M.upkeep(f, s, DPS)
    assert(u['lock-imp'] == 688 and not u['lock-succubus'])
    s.combat = true
    u = M.upkeep(f, s, DPS)
    assert(not u['lock-imp'] and u['lock-fel-domination'] == 18708, 'no summons in combat, Fel Domination')
    s.buffs[2] = { id = 18791 }
    assert(not M.upkeep(f, s, DPS)['lock-fel-domination'], 'a sacrificed pet is not replaced')
    s.buffs = { { id = 706 } }
    s.pet = true
    M.know(s, 18788)
    assert(M.upkeep(f, s, DPS)['lock-demonic-sacrifice'] == 18788)
    s.group = false
    s.health = 40
    s.items[19013] = 1
    u = M.upkeep(f, s, DPS)
    assert(u['lock-healthstone'])
    s.health = 70
    s.petHealth = 20
    assert(M.upkeep(f, s, DPS)['lock-health-funnel'] == 755)
    M.know(s, 7812)
    s.health = 30
    assert(M.upkeep(f, s, DPS)['lock-voidwalker-sacrifice'] == 7812)
end)

test(
    'Warcraft Tavern drain tank: Drain Life filler from its fourth rank, Life Tap near full health, the Succubus',
    function()
        local f, s = warlock(40, kit, { 712 })
        dots(s, 980, 348, 172, 18265)
        assert(first(f, s, WT) == 5019, 'before rank 4: the wand')
        M.know(s, 7651)
        assert(first(f, s, WT) == 689 and first(f, s, DPS) == 5019)
        s.mana = 80
        assert(first(f, s, WT) == 1454, 'Life Tap at full health')
        s.health = 80
        assert(first(f, s, WT) == 689)
        s.pet = false
        s.combat = false
        s.targetCombat = false
        local u = M.upkeep(f, s, WT)
        assert(u['lock-wt-succubus'] == 712 and not u['lock-wt-imp'])
    end
)

test(
    'SoD tank: Shadow Cleave for Defender\'s Resolve, procs, Incinerate buff, curse, DoTs, Searing Pain; Metamorphosis reminder',
    function()
        local f, s = warlock(60, kit, { 403789, 403835, 412758, 426320, 403677, 403828, 425463 })
        s.season = 2
        M.engrave(s, 426320)
        assert(first(f, s, TANK) == 403835)
        s.buffs = { { id = 460200, expires = 110 } }
        assert(first(f, s, TANK) == 412758)
        s.buffs[2] = { id = 412758, expires = 130 }
        assert(first(f, s, TANK) == 980)
        dots(s, 980)
        assert(first(f, s, TANK) == 426320)
        dots(s, 426320, 403677, 172, 18265)
        assert(first(f, s, TANK) == 5676, 'Searing Pain filler')
        M.know(s, 6353)
        s.buffs[3] = { id = 457643 }
        assert(first(f, s, TANK) == 6353, 'Soul Fire! proc')
        s.buffs[3] = nil
        local u = M.upkeep(f, s, TANK)
        assert(u['sod-tank-metamorphosis'] == 403789 and u['sod-tank-demonic-grace'] == 425463)
        s.buffs[3] = { id = 403789 }
        s.group = true
        s.targettarget = 'party1'
        u = M.upkeep(f, s, TANK)
        assert(not u['sod-tank-metamorphosis'] and u['sod-tank-menace'] == 403828)
    end
)

test(
    'SoD Fire: Backdraft Conflagrate, Immolate, Incinerate buff, Decimation Soul Fire instead of Chaos Bolt below 35%; Icy Veins variant',
    function()
        local f, s = warlock(60, kit, { 403629, 412758, 17962, 6353 })
        s.season = 2
        dots(s, 980)
        M.engrave(s, 403629, 412758)
        assert(first(f, s, FIRE) == 348)
        dots(s, 348)
        assert(first(f, s, FIRE) == 17962, 'Conflagrate for Backdraft')
        s.buffs = { { id = 427714 } }
        assert(first(f, s, FIRE) == 412758, 'Incinerate buff')
        s.buffs[2] = { id = 412758, expires = 130 }
        assert(first(f, s, FIRE) == 403629, 'Chaos Bolt')
        s.nopower[403629] = true
        assert(first(f, s, FIRE) == 412758, 'Incinerate filler')
        s.nopower[403629] = nil
        s.targetHealth = 30
        assert(first(f, s, FIRE) == 412758, 'no Chaos Bolt below 35%')
        s.buffs[3] = { id = 440873 }
        assert(first(f, s, FIRE) == 6353)
        assert(first(f, s, FIREIV) == 17962, 'Icy Veins: Conflagrate on cooldown')
        s.nopower[17962] = true
        assert(first(f, s, FIREIV) == 403629, 'Icy Veins: Chaos Bolt in execute')
    end
)

test(
    'SoD Shadow: Unstable Affliction, Master Channeler, Shadowflame, Corruption, Haunt, Drain Soul execute; wowsims early refresh',
    function()
        local f, s = warlock(60, kit, { 427717, 403677, 426320, 403501 })
        s.season = 2
        dots(s, 980)
        M.engrave(s, 426320)
        assert(first(f, s, SHADOW) == 427717)
        dots(s, 427717)
        assert(first(f, s, SHADOW) == 403677)
        dots(s, 403677)
        assert(first(f, s, SHADOW) == 426320)
        dots(s, 426320)
        assert(first(f, s, SHADOW) == 172)
        dots(s, 172)
        assert(first(f, s, SHADOW) == 403501)
        s.nopower[403501] = true
        assert(first(f, s, SHADOW) == 18265)
        dots(s, 18265)
        s.targetHealth = 18
        s.group = true
        assert(first(f, s, SHADOW) == 686, 'no Soul Siphon engraved: no execute Drain Soul')
        M.engrave(s, 403511)
        assert(first(f, s, SHADOW) == 1120, 'Drain Soul below 20% with Soul Siphon (a passive rune)')
        s.targetHealth = 100
        assert(first(f, s, SHADOW) == 686, 'Shadow Bolt filler')
        assert(first(f, s, SHADOWWS) == 1120, 'wowsims: Drain Soul filler')
        s.debuffs[2].expires = 106
        assert(first(f, s, SHADOWWS) == 427717 and first(f, s, SHADOW) == 686, 'wowsims renews with 7.5 seconds left')
        s.debuffs[2].expires = 105
        M.engrave(s, 426243)
        assert(first(f, s, SHADOW) == 427717, 'Invocation (a passive rune): Unstable Affliction renewed under 6 s')
        s.debuffs[2].expires = 130

        for _, d in ipairs(s.debuffs) do
            if d.id == 172 then
                d.expires = 104
            end
        end

        assert(first(f, s, SHADOW) == 172, 'Invocation: Corruption renewed under 6 s')
        M.unengrave(s, 426243)
        assert(first(f, s, SHADOW) == 686, 'without Invocation an instant DoT runs out first')
    end
)

test('real publisher highlights the selected premade and follows the realm and runes', function()
    local f, s = warlock(40, kit)
    local poll, selected = M.publisher(f, s)
    poll()
    assert(selected() == DPS and f.addon.currentSpell == 980)
    s.season = 2
    f.addon:InvalidateBuildContext('client')
    poll()
    assert(selected() == SHADOW)
    M.engrave(s, 403789)
    M.know(s, 403835)
    poll()
    assert(selected() == TANK and f.addon.currentSpell == 403835)
end)

finish()
