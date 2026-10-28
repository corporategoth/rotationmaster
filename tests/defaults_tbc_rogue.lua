-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Rogue premades: melee DPS (wowsims recommended, Wowhead). Real predicates, catalog,
-- composition, sequence and publisher; WoW observations are modeled in
-- tests/fixtures/tbc_physical_premades.lua.
local M = dofile('tests/fixtures/tbc_physical_premades.lua')
local test, finish = M.F.suite()
local RS, RH = 'rm.tbc.rogue.dps.wowsims', 'rm.tbc.rogue.dps.wowhead'

local function rogue(level, ...)
    local f, s = M.fixture('ROGUE', { level = level })
    M.know(s, 6603, 1752, 2098)

    for _, set in ipairs({ ... }) do
        M.know(s, unpack(set))
    end

    s.range[6603] = true
    s.usable[14251] = false
    s.targettarget = 'player'
    return f, s
end

local mid = { 5171, 53, 703, 8676, 1833, 1943, 1766, 5277 }

local function first(f, s, id)
    return (M.first(f, s, id))
end

local function both(f, s, g, t, a, b)
    local x, y = first(f, s, RS), first(g, t, RH)
    assert(x == a and y == (b == nil and a or b), 'wowsims ' .. tostring(x) .. ' wowhead ' .. tostring(y))
end

local function set(s, t, key, value)
    s[key], t[key] = value, value
end

test(
    'both premades register valid 1–70, share the switch, the wowsims premade auto-selects and the Wowhead one ships disabled',
    function()
        local f, s = rogue(1)
        local a = f.addon

        for _, level in ipairs({ 1, 20, 70 }) do
            s.level = level
            a.longtermCache = {}

            for _, r in ipairs(a:ListDefaultRotations(0)) do
                assert(r.eligible == (r.id ~= RH), r.id .. ' at ' .. level)
            end

            assert(M.switches(f, RS) and M.switches(f, RH))
        end

        for _, src in ipairs(a:GetDefaultRotation(RH).envelope.sources) do
            assert(not src.url:find('icy%-veins') and not src.url:find('wowsims'), src.url)
        end

        for _, src in ipairs(a:GetDefaultRotation(RS).envelope.sources) do
            assert(not src.url:find('wowhead'), src.url)
        end

        local poll, selected = M.publisher(f, s)
        s.level = 1
        poll()
        assert(selected() == RS and f.addon.currentSpell == 1752)
        s.level = 70
        poll()
        assert(selected() == RS)
        assert(a:SetDefaultRotationEnabled(RS, false))
        poll()
        assert(selected() ~= RH, 'the disabled Wowhead premade was chosen')
        assert(a:SetDefaultRotationEnabled(RH, true))
        poll()
        assert(selected() == RH)
    end
)

test('casts, channels and a missing target stop with Attack suppressed', function()
    for _, id in ipairs({ RS, RH }) do
        local f, s = rogue(20, mid)

        for _, key in ipairs({ 'cast', 'channel' }) do
            s[key] = true
            local x, r = M.first(f, s, id)
            assert(not x and r.status == 'stopped' and r.suppressAttack, key)
            s[key] = false
        end

        s.dead = true
        local x, r = M.first(f, s, id)
        assert(not x and r.suppressAttack)
        s.dead = false
        assert(first(f, s, id) == 1752)
    end
end)

test('stealth opener adapts by spell known and group, then stops without breaking stealth', function()
    for _, id in ipairs({ RS, RH }) do
        local f, s = rogue(10)
        s.stealth = true
        s.combat = false
        assert(first(f, s, id) == 1752, 'nothing learned yet: Sinister Strike')
        M.know(s, 703)
        s.group = true
        assert(first(f, s, id) == 703)
        s.group = false
        assert(first(f, s, id) == 703, 'Garrote fallback before Cheap Shot')
        M.know(s, 8676)
        assert(first(f, s, id) == 703, 'Ambush needs the target not facing you')
        s.targettarget = nil
        assert(first(f, s, id) == 8676)
        s.gear[16] = M.GEAR.SWORD
        assert(first(f, s, id) == 703, 'Ambush needs a dagger in the main hand')
        s.gear[16] = M.GEAR.DAGGER
        M.know(s, 1833)
        assert(first(f, s, id) == 1833, 'solo Cheap Shot')
        s.group = true
        assert(first(f, s, id) == 703, 'group Garrote')
        M.know(s, 14183)
        assert(first(f, s, id) == 14183, 'Premeditation first')

        for spell in pairs(s.known) do
            s.nopower[spell] = true
        end

        local x, r = M.first(f, s, id)
        assert(not x and r.status == 'stopped' and r.suppressAttack)
    end
end)

test(
    'Slice and Dice: wowsims from two points, Wowhead from one; renewed only in its last two seconds; own only',
    function()
        local f, s = rogue(30, mid)
        local g, t = rogue(30, mid)
        set(s, t, 'points', 1)
        both(f, s, g, t, 1752, 5171)
        set(s, t, 'points', 2)
        both(f, s, g, t, 5171)
        s.buffs = { { id = 5171, expires = 110 } }
        t.buffs = { { id = 5171, expires = 110 } }
        both(f, s, g, t, 1752)
        s.buffs[1].expires = 101.5
        t.buffs[1].expires = 101.5
        both(f, s, g, t, 5171)
        s.buffs[1].source = 'party1'
        s.buffs[1].expires = 110
        assert(first(f, s, RS) == 5171, 'another rogue\'s Slice is not yours')
    end
)

test(
    'five-point finisher: wowsims Rupture when it will last and Blade Flurry is down, Wowhead always Eviscerate; pool at five',
    function()
        local f, s = rogue(40, mid, { 13877 })
        local g, t = rogue(40, mid, { 13877 })

        for _, x in ipairs({ s, t }) do
            x.buffs = { { id = 5171, expires = 130 } }
            x.points = 5
        end

        both(f, s, g, t, 2098)
        set(s, t, 'ttd', 30)
        both(f, s, g, t, 1943, 2098)
        s.debuffs = { { id = 1943 } }
        assert(first(f, s, RS) == 2098)
        s.debuffs = { { id = 1943, source = 'party1' } }
        assert(first(f, s, RS) == 1943)
        s.buffs[2] = { id = 13877 }
        assert(first(f, s, RS) == 2098, 'Blade Flurry is cleaving')
        s.buffs[2] = nil
        set(s, t, 'ttd', 10)
        both(f, s, g, t, 2098)

        for _, x in ipairs({ s, t }) do
            x.nopower[2098], x.nopower[1943] = true, true
        end

        local x, r = M.first(f, s, RS)
        local y, q = M.first(g, t, RH)

        assert(
            not x and not y and r.status == 'stopped' and q.status == 'stopped' and not r.suppressAttack,
            'pool: no builder at five, auto attack continues'
        )
    end
)

test('near-death two-point Eviscerate is a wowsims finisher only', function()
    local f, s = rogue(40, mid)
    local g, t = rogue(40, mid)

    for _, x in ipairs({ s, t }) do
        x.buffs = { { id = 5171, expires = 130 } }
        x.points = 2
        x.ttd = 3
    end

    both(f, s, g, t, 2098, 1752)
    set(s, t, 'ttd', nil)
    both(f, s, g, t, 1752)
end)

test('builders follow what is known and whether the target is facing you', function()
    for _, id in ipairs({ RS, RH }) do
        local f, s = rogue(50, mid, { 1329 })
        assert(first(f, s, id) == 1752, 'targeted: Mutilate falls back to Sinister Strike')
        s.targettarget = 'party1'
        assert(first(f, s, id) == 1329)
        s.known[1329] = false
        assert(first(f, s, id) == 53, 'Backstab when not tanked')
        s.gear[16] = M.GEAR.SWORD
        assert(first(f, s, id) == 1752, 'no dagger: Sinister Strike instead of Backstab')
        s.gear[16] = M.GEAR.DAGGER
        M.know(s, 16511)
        assert(first(f, s, id) == 16511)
        M.know(s, 14278)
        assert(first(f, s, id) == 14278)
        M.know(s, 1757, 1759)
        s.known[16511], s.known[14278], s.known[53] = false, false, false
        assert(first(f, s, id) == 1759, 'highest learned Sinister rank')
        s.mapped[1759] = false
        assert(first(f, s, id) == 1757)
        M.know(s, 5938)
        s.debuffs = { { id = 2818, stacks = 5, expires = 101 } }
        assert(first(f, s, id) == 5938, 'Shiv saves a full Deadly stack')
        s.debuffs[1].expires = 110
        assert(first(f, s, id) == 1757)
        s.usable[14251] = true
        M.know(s, 14251)
        assert(first(f, s, id) == 14251, 'Riposte first')
    end
end)

test(
    'single target vs packs: Blade Flurry and Adrenaline Rush need a second enemy or an elite, and Slice and Dice',
    function()
        for _, id in ipairs({ RS, RH }) do
            local f, s = rogue(40, mid, { 13877, 13750 })
            local u = M.upkeep(f, s, id)
            assert(not u['rogue-blade-flurry'])
            s.buffs = { { id = 5171, expires = 130 } }
            assert(not M.upkeep(f, s, id)['rogue-blade-flurry'])
            s.enemies = { 0, 1 }
            u = M.upkeep(f, s, id)
            assert(u['rogue-blade-flurry'] == 13877 and u['rogue-adrenaline-rush'] == 13750)
            s.enemies = { 3, false }
            assert(not M.upkeep(f, s, id)['rogue-blade-flurry'], 'an enemy not fighting you is not counted')
            s.classification = 'elite'
            assert(M.upkeep(f, s, id)['rogue-blade-flurry'])
            s.buffs = {}
            assert(not M.upkeep(f, s, id)['rogue-blade-flurry'])
        end
    end
)

test('reminders: poisons per weapon, Kick, Cold Blood and Evasion', function()
    local f, s = rogue(40, mid, { 14177 })
    local u = M.upkeep(f, s, RS)
    assert(u['rogue-mainhand-poison'] and not u['rogue-offhand-poison'], 'no off-hand weapon, no off-hand poison')
    s.offSpeed = 1.8
    assert(not M.upkeep(f, s, RS)['rogue-offhand-poison'], 'an off-hand swing alone is not a weapon')
    s.gear[17] = M.GEAR.OFFHAND
    assert(not M.upkeep(f, s, RS)['rogue-offhand-poison'], 'a held item takes no poison')
    s.gear[17] = M.GEAR.DAGGER
    assert(M.upkeep(f, s, RS)['rogue-offhand-poison'])
    s.offEnchant = true
    s.mainEnchant = true
    u = M.upkeep(f, s, RS)
    assert(not u['rogue-mainhand-poison'] and not u['rogue-offhand-poison'])
    local items = M.body(f.addon, RS).cooldowns

    for _, step in ipairs(items) do
        if step.id == 'rogue-offhand-poison' then
            assert(step.action[1] == 22054 and step.action[8] == 21927)
        end
    end

    assert(not u['rogue-kick'])
    s.targetCast = 'Fireball'
    assert(M.upkeep(f, s, RS)['rogue-kick'] == 1766)
    s.targetInterruptible = false
    assert(not M.upkeep(f, s, RS)['rogue-kick'])
    s.points = 3
    assert(not M.upkeep(f, s, RS)['rogue-cold-blood'])
    s.points = 4
    assert(M.upkeep(f, s, RS)['rogue-cold-blood'] == 14177)
    s.health = 40
    assert(M.upkeep(f, s, RS)['rogue-evasion'] == 5277)
    s.targettarget = 'party1'
    assert(not M.upkeep(f, s, RS)['rogue-evasion'])
end)

test('unavailable combo points halt with Attack suppressed rather than guessing a builder', function()
    local f, s = rogue(20, mid)

    f.env.GetComboPoints = function()
        error('unavailable')
    end

    local x, r = M.first(f, s, RS)
    assert(not x and r.status == 'unavailable' and r.suppressAttack)
end)

test('real publisher highlights the selected premade across combo points', function()
    local f, s = rogue(40, mid)
    local poll, selected, glow = M.publisher(f, s)
    s.buffs = { { id = 5171, expires = 130 } }
    poll()
    assert(selected() == RS and f.addon.currentSpell == 1752)
    s.points = 5
    poll()
    assert(f.addon.currentSpell == 2098)
    assert(#glow > 0)
end)

finish()
