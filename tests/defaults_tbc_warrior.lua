-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Warrior premades: DPS (simulator recommended, Icy Veins) and tank (Wowhead recommended,
-- Icy Veins). Real predicates, catalog, composition, sequence and publisher; WoW observations
-- are modeled in tests/fixtures/tbc_physical_premades.lua.
local M = dofile('tests/fixtures/tbc_physical_premades.lua')
local test, finish = M.F.suite()

local DW, DI, PW, PI =
    'rm.tbc.warrior.dps.simulator',
    'rm.tbc.warrior.dps.icyveins',
    'rm.tbc.warrior.protection.wowhead',
    'rm.tbc.warrior.protection.icyveins'

local early = { 6603, 78, 6673, 100, 772, 6343, 1715 }
local mid = {2687, 7386, 7384, 5308, 845, 20252, 72, 1160, 6572, 2565, 871}
local arms = { 1680, 6552, 12294, 34428, 1719, 12328, 12292 }
local fury = { 1680, 6552, 23881, 34428, 1719, 29801, 12292 }

local function warrior(level, ...)
    local f, s = M.fixture('WARRIOR', { level = level })
    M.know(s, unpack(early))

    for _, set in ipairs({ ... }) do
        M.know(s, unpack(set))
    end

    s.range[6603] = true
    s.usable[7384] = false
    s.usable[34428] = false
    s.usable[6572] = false
    return f, s
end

local function first(f, s, id)
    return (M.first(f, s, id))
end

local function cd(s, id)
    s.cooldown[id] = { startTime = 99, duration = 6, isEnabled = true, modRate = 1 }
end

local function eligible(f)
    local out = {}

    for _, r in ipairs(f.addon:ListDefaultRotations(0)) do
        if r.eligible then
            out[r.id] = true
        end
    end

    return out
end

test(
    'four premades register valid at every level, the tank switch holds level 10, and each cites only its own source family',
    function()
        local f, s = warrior(1)
        local a = f.addon

        -- Applicability holds only load-time facts: every premade fits any level; level lives in the switch. The Icy Veins
        -- variants ship disabled (same switch, lower priority).
        for _, level in ipairs({ 1, 9, 10, 40, 70 }) do
            s.level = level
            a.longtermCache = {}
            local e = eligible(f)
            assert(e[DW] and not e[DI] and e[PW] and not e[PI], 'scope at ' .. level)
        end

        s.forms = 3
        s.shift(71)

        for _, case in ipairs({ { 9, false }, { 10, true } }) do
            s.level = case[1]
            a.longtermCache = {}
            assert(M.switches(f, PW) == case[2] and M.switches(f, PI) == case[2], 'tank switch at ' .. case[1])
        end

        for id, host in pairs({ [DI] = 'icy%-veins%.com', [PI] = 'icy%-veins%.com' }) do
            for _, src in ipairs(a:GetDefaultRotation(id).envelope.sources) do
                assert(src.url:find(host), id .. ' cites ' .. src.url)
            end
        end

        for _, src in ipairs(a:GetDefaultRotation(PW).envelope.sources) do
            assert(not src.url:find('icy%-veins'), PW .. ' cites Icy Veins')
        end

        for _, id in ipairs({ DW, DI, PW, PI }) do
            local v = a:GetDefaultRotation(id)

            assert(
                v.validation.valid
                    and v.readOnly
                    and v.revision == ({ [DW] = 5, [DI] = 6, [PW] = 6, [PI] = 7 })[id]
                    and v.enabled == (id == DW or id == PW)
            )
        end
    end
)

test(
    'variants share their sibling switch; Defensive Stance selects the tank, anything else DPS, recommended first',
    function()
        local f, s = warrior(5)
        local poll, selected = M.publisher(f, s)

        for _, case in ipairs({
            { 5, 1, DW },
            { 12, 2, PW },
            { 12, 1, DW },
            { 40, 3, DW },
            { 70, 2, PW },
            { 70, 1, DW },
        }) do
            s.level, s.form = case[1], case[2]
            poll()
            assert(selected() == case[3], case[1] .. '/' .. case[2] .. ' selected ' .. tostring(selected()))

            assert(
                M.switches(f, DW) == M.switches(f, DI) and M.switches(f, PW) == M.switches(f, PI),
                'sibling switches disagree'
            )
        end

        -- No talent points and no stances beyond Battle: still the DPS premade.
        s.level, s.form, s.forms = 10, 1, 1
        poll()
        assert(selected() == DW)
        s.forms = 3
        assert(f.addon:SetDefaultRotationEnabled(DW, false) and f.addon:SetDefaultRotationEnabled(DI, true))
        s.form = 1
        poll()
        assert(selected() == DI)
        assert(f.addon:SetDefaultRotationEnabled(PW, false) and f.addon:SetDefaultRotationEnabled(PI, true))
        s.form = 2
        poll()
        assert(selected() == PI)
        -- Stances are read by spell: Defensive Stance selects the tank wherever it sits on the bar.
        assert(f.addon:SetDefaultRotationEnabled(PW, true))
        s.bar = { 2457, 2458, 71 }
        s.form = 3
        poll()
        assert(selected() == PW, 'Defensive Stance in slot 3')
        s.form = 2
        poll()

        assert(
            selected() == DI and not M.switches(f, PW),
            'Berserker Stance in slot 2 is not Defensive (the recommended DPS premade is off here)'
        )
    end
)

test('casting, channeling and a missing target stop without melee; out of combat only Charge then stop', function()
    for _, id in ipairs({ DW, DI, PW, PI }) do
        local f, s = warrior(40, mid, arms)
        s.form = id:find('protection') and 2 or 1
        s.power = 100
        s.cast = true
        local x, r = M.first(f, s, id)
        assert(not x and r.status == 'stopped' and r.suppressAttack, id)
        s.cast = false
        s.channel = true
        x, r = M.first(f, s, id)
        assert(not x and r.status == 'stopped' and r.suppressAttack)
        s.channel = false
        s.hostile = false
        x, r = M.first(f, s, id)
        assert(not x and r.suppressAttack)
        s.hostile = true
        s.combat = false
        assert(first(f, s, id) == 100)
        s.usable[100] = false
        x, r = M.first(f, s, id)
        assert(not x and r.status == 'stopped' and not r.suppressAttack)
    end
end)

test(
    'leveling DPS adapts by spell known: Rend, then Execute, Overpower; Thunder Clap on packs before Whirlwind',
    function()
        for _, id in ipairs({ DW, DI }) do
            local f, s = warrior(8)
            s.power = 20
            assert(first(f, s, id) == 772)
            s.debuffs = { { id = 772 } }
            assert(first(f, s, id) == nil)
            s.debuffs = { { id = 772, source = 'party1' } }
            assert(first(f, s, id) == 772, 'another warrior\'s Rend counts as missing')
            s.targetHealth = 40
            assert(first(f, s, id) == nil, 'Rend only at the start of a fight')
            M.know(s, unpack(mid))
            s.targetHealth = 15
            assert(first(f, s, id) == 5308)
            s.targetHealth = 60
            s.usable[7384] = true
            assert(first(f, s, id) == 7384)
            s.usable[7384] = false
            s.enemies = { 3, 0 }
            assert(first(f, s, id) == 6343)
            s.debuffs = { { id = 6343, source = 'party1' } }
            assert(first(f, s, id) == 772)
            M.know(s, 1680)
            assert(first(f, s, id) == 1680, 'Whirlwind first once known')
        end
    end
)

test(
    'simulator keeps Execute behind Mortal Strike/Bloodthirst/Whirlwind; Icy Veins puts it first for Arms, second for Fury',
    function()
        local f, s = warrior(70, mid, arms)
        local g, t = warrior(70, mid, arms)
        s.power, t.power = 60, 60
        s.targetHealth, t.targetHealth = 10, 10
        assert(first(f, s, DW) == 12294 and first(g, t, DI) == 5308, 'Arms execute phase')
        cd(s, 12294)
        cd(t, 12294)
        s.power, t.power = 40, 40
        assert(first(f, s, DW) == 5308 and first(g, t, DI) == 5308)
        s.power, t.power = 60, 60
        assert(first(f, s, DW) == 1680, 'simulator Whirlwind with rage to spare before Execute')
        s.targetHealth, t.targetHealth = 100, 100
        s.power, t.power = 40, 40
        assert(first(f, s, DW) == nil and first(g, t, DI) == 1680, 'Icy Veins Whirlwind holds no rage')
        local h, u = warrior(70, mid, fury)
        local k, v = warrior(70, mid, fury)
        u.power, v.power = 60, 60
        u.targetHealth, v.targetHealth = 10, 10
        u.buffs, v.buffs = { { id = 29801, expires = 120 } }, { { id = 29801, expires = 120 } }
        assert(first(h, u, DW) == 23881 and first(k, v, DI) == 23881, 'Bloodthirst first for Fury in both')
        cd(u, 23881)
        cd(v, 23881)
        assert(first(h, u, DW) == 1680 and first(k, v, DI) == 5308)
    end
)

test('full-kit training stages: highest learned rank, Rampage upkeep, Intercept and Victory Rush first', function()
    local f, s = warrior(70, mid, fury)
    s.power = 60
    M.know(s, 23892, 23894)
    s.known[29801] = false
    assert(first(f, s, DW) == 23894, 'highest learned Bloodthirst rank')
    s.mapped[23894] = false
    assert(first(f, s, DW) == 23892)
    s.mapped[23894] = nil
    assert(first(f, s, DW) == 23894)
    M.know(s, 29801)
    assert(first(f, s, DW) == 29801, 'Rampage missing')
    s.buffs = { { id = 29801, expires = 103 } }
    assert(first(f, s, DW) == 29801, 'under five seconds')
    s.buffs = { { id = 29801, expires = 120 } }
    assert(first(f, s, DW) == 23894)
    s.range[6603] = false
    s.range[20252] = true
    assert(first(f, s, DW) == 20252)
    s.range[6603] = true
    s.usable[34428] = true
    assert(first(f, s, DW) == 34428)
end)

test(
    'simulator spends spare rage on Devastate or Sunder to five then Hamstring; Icy Veins only Hamstring near the cap',
    function()
        local f, s = warrior(40, mid)
        local g, t = warrior(40, mid)
        s.debuffs = { { id = 772 } }
        t.debuffs = { { id = 772 } }
        s.targetHealth, t.targetHealth = 60, 60
        s.power, t.power = 50, 50
        assert(first(f, s, DW) == 7386 and first(g, t, DI) == nil)
        s.debuffs[2] = { id = 7386, stacks = 5, source = 'party1' }
        assert(first(f, s, DW) == nil)
        s.power = 75
        assert(first(f, s, DW) == 1715)
        t.power = 89
        assert(first(g, t, DI) == nil)
        t.power = 90
        assert(first(g, t, DI) == 1715)
        M.know(s, 20243)
        s.power = 50
        assert(first(f, s, DW) == 20243)
    end
)

test(
    'single target vs packs: Whirlwind first when two enemies fight you; Cleave and Sweeping Strikes reminded, Heroic Strike not',
    function()
        for _, id in ipairs({ DW, DI }) do
            local f, s = warrior(70, mid, arms)
            s.power = 60
            assert(first(f, s, id) == 12294)
            local u = M.upkeep(f, s, id)

            assert(
                u['warrior-dps-heroic-strike'] and not u['warrior-dps-cleave'] and not u['warrior-dps-sweeping-strikes']
            )

            s.enemies = { 3, 1 }
            assert(first(f, s, id) == 1680)
            u = M.upkeep(f, s, id)

            assert(
                u['warrior-dps-cleave'] == 845
                    and u['warrior-dps-sweeping-strikes'] == 12328
                    and not u['warrior-dps-heroic-strike']
            )

            s.enemies = { 3, false, false }
            assert(first(f, s, id) == 12294, 'enemies that are not fighting you are not counted')

            f.env.UnitThreatSituation = function()
                error('threat unavailable')
            end

            local x, r = M.first(f, s, id)

            assert(
                not x and r.status == 'unavailable' and r.suppressAttack,
                'an unreadable count halts instead of guessing'
            )
        end
    end
)

test(
    'DPS reminders: shout, Bloodrage, Heroic Strike thresholds and queue, interrupts, Death Wish and Recklessness',
    function()
        local f, s = warrior(8)
        local u = M.upkeep(f, s, DW)
        assert(u['warrior-dps-battle-shout'] == 6673)
        s.buffs = { { id = 6673, source = 'party1' } }
        assert(not M.upkeep(f, s, DW)['warrior-dps-battle-shout'])
        s.buffs = { { id = 469 } }
        assert(not M.upkeep(f, s, DW)['warrior-dps-battle-shout'])
        s.power = 29
        assert(not M.upkeep(f, s, DW)['warrior-dps-heroic-strike'])
        s.power = 30
        assert(M.upkeep(f, s, DW)['warrior-dps-heroic-strike'] == 78)
        s.active[78] = true
        assert(not M.upkeep(f, s, DW)['warrior-dps-heroic-strike'])
        s.active[78] = nil
        s.combat = false
        assert(not M.upkeep(f, s, DW)['warrior-dps-heroic-strike'])
        local g, t = warrior(70, mid, arms)
        t.power = 59
        assert(not M.upkeep(g, t, DI)['warrior-dps-heroic-strike'])
        t.power = 60
        assert(M.upkeep(g, t, DI)['warrior-dps-heroic-strike'])
        t.power = 20
        assert(M.upkeep(g, t, DI)['warrior-dps-bloodrage'] == 2687)
        t.health = 40
        assert(not M.upkeep(g, t, DI)['warrior-dps-bloodrage'])
        t.targetCast = 'Heal'
        u = M.upkeep(g, t, DI)
        assert(u['warrior-dps-pummel'] == 6552 and u['warrior-dps-shield-bash'] == 72)
        t.targetInterruptible = false
        u = M.upkeep(g, t, DI)
        assert(not u['warrior-dps-pummel'])
        assert(not u['warrior-dps-death-wish'])
        t.classification = 'elite'
        u = M.upkeep(g, t, DI)
        assert(u['warrior-dps-death-wish'] and not u['warrior-dps-recklessness'])
        t.classification = 'worldboss'
        assert(M.upkeep(g, t, DI)['warrior-dps-recklessness'] == 1719)
    end
)

test(
    'tank core: Shield Slam, Revenge; Wowhead keeps Demoralizing Shout and Thunder Clap up on elites, Icy Veins does not',
    function()
        local f, s = warrior(60, mid, { 23922, 20243 })
        local g, t = warrior(60, mid, { 23922, 20243 })
        s.form, t.form = 2, 2
        s.power, t.power = 60, 60
        assert(first(f, s, PW) == 23922 and first(g, t, PI) == 23922)
        cd(s, 23922)
        cd(t, 23922)
        s.usable[6572], t.usable[6572] = true, true
        assert(first(f, s, PW) == 6572 and first(g, t, PI) == 6572)
        s.usable[6572], t.usable[6572] = false, false
        assert(first(f, s, PW) == 20243 and first(g, t, PI) == 20243)
        s.classification, t.classification = 'elite', 'elite'
        assert(first(f, s, PW) == 1160 and first(g, t, PI) == 20243)
        s.debuffs = { { id = 99, source = 'party1' } }
        assert(first(f, s, PW) == 6343, 'Demoralizing Roar counts')
        s.debuffs[2] = { id = 6343, source = 'party1' }
        assert(first(f, s, PW) == 20243)
        s.enemies = { 3, 2 }
        s.debuffs = {}
        t.enemies = { 3, 2 }
        assert(first(f, s, PW) == 6343 and first(g, t, PI) == 6343)
        cd(s, 6343)
        cd(t, 6343)
        assert(first(f, s, PW) == 1160 and first(g, t, PI) == 1160)
        t.classification = 'normal'
        assert(first(g, t, PI) == 20243, 'Icy Veins: Demoralizing Shout only for elite packs')
    end
)

test('tank leveling: Sunder to five before Devastate, Icy Veins Rend until Shield Slam', function()
    local f, s = warrior(20, mid)
    local g, t = warrior(20, mid)
    s.form, t.form = 2, 2
    s.power, t.power = 40, 40
    assert(first(f, s, PW) == 7386 and first(g, t, PI) == 7386)
    s.debuffs = { { id = 7386, stacks = 5 } }
    t.debuffs = { { id = 7386, stacks = 5 } }
    assert(first(f, s, PW) == nil and first(g, t, PI) == 772)
    M.know(t, 23922)
    cd(t, 23922)
    assert(first(g, t, PI) == nil)
end)

test('tank reminders: Shield Block by source policy, Heroic Strike from 30 rage, emergency defensives', function()
    local f, s = warrior(60, mid, { 12975 })
    local g, t = warrior(60, mid, { 12975 })
    s.form, t.form = 2, 2
    s.power, t.power = 30, 30
    assert(M.upkeep(f, s, PW)['warrior-prot-heroic-strike'] == 78)
    t.targettarget = 'player'

    assert(
        not M.upkeep(f, s, PW)['warrior-prot-shield-block'] and M.upkeep(g, t, PI)['warrior-prot-shield-block'] == 2565
    )

    t.targettarget = 'party1'
    assert(not M.upkeep(g, t, PI)['warrior-prot-shield-block'])
    s.targetLevel = 63
    assert(M.upkeep(f, s, PW)['warrior-prot-shield-block'] == 2565)
    s.gear[17] = nil
    assert(not M.upkeep(f, s, PW)['warrior-prot-shield-block'], 'no shield, no Shield Block')
    s.gear[17] = M.GEAR.AXE2H
    assert(not M.upkeep(f, s, PW)['warrior-prot-shield-block'])
    s.gear[17] = M.GEAR.SHIELD
    s.buffs = { { id = 2565 } }
    assert(not M.upkeep(f, s, PW)['warrior-prot-shield-block'])
    s.targetLevel = nil
    s.buffs = {}
    s.classification = 'worldboss'
    assert(M.upkeep(f, s, PW)['warrior-prot-shield-block'])
    s.health = 25
    local u = M.upkeep(f, s, PW)
    assert(u['warrior-prot-last-stand'] == 12975 and not u['warrior-prot-shield-wall'])
    s.health = 15
    assert(M.upkeep(f, s, PW)['warrior-prot-shield-wall'] == 871)
end)

test('real publisher highlights the auto-selected premade and follows a stance change', function()
    local f, s = warrior(70, mid, arms)
    s.power = 60
    local poll, selected, glow, messages = M.publisher(f, s)
    poll()
    assert(selected() == DW and f.addon.currentSpell == 12294)
    s.form = 2
    M.know(s, 23922)
    poll()
    assert(selected() == PW and f.addon.currentSpell == 23922)
    assert(#glow > 0 and #messages > 0)
end)

finish()
