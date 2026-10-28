-- Mists of Pandaria Classic Warrior premades: Arms (wowsims, recommended) and its Icy Veins pooling variant, Fury
-- (wowsims) and its Icy Veins variant, Protection, and the Unspecialized catch-all. Real predicates, catalog,
-- composition, sequence and publisher on a modeled MoP Classic client (tests/fixtures/mop_premade_model_b.lua).
local M = dofile('tests/fixtures/mop_premade_model_b.lua')
local test, finish = M.F.suite()

local ARMS, ARMSIV, FURY, FURYIV, PROT, BASE =
    'rm.mop.warrior.arms',
    'rm.mop.warrior.arms.icyveins',
    'rm.mop.warrior.fury',
    'rm.mop.warrior.fury.icyveins',
    'rm.mop.warrior.protection',
    'rm.mop.warrior.unspecialized'

local CS, MS, SLAM, OP, EXEC, BT, RB, WS, SS = 86346, 12294, 1464, 7384, 5308, 23881, 85288, 100130, 23922

local function warrior(level, ...)
    local f, s = M.fixture('WARRIOR', { level = level })
    M.know(s, 78, 100, 34428, 5308)

    for _, set in ipairs({ ... }) do
        M.know(s, unpack(set))
    end

    s.range[6603] = true
    s.range[100] = false
    s.range[57755] = true
    s.form = 1
    s.power = 50
    -- The engine's own gates: Execute below 20% health, Victory Rush after a killing blow.
    s.usable[5308] = false
    s.usable[34428] = false
    s.usable[103840] = false
    return f, s
end

local function first(f, s, id)
    return (M.first(f, s, id))
end

local arms = { MS, SLAM, OP, 57755, 6343, 1680 }
local armsFull = {MS, SLAM, OP, 57755, 6343, 1680, 12328, CS, 118000, 107570, 46924, 6673, 469}
local fury = { BT, WS, RB, 57755, 1680, 6673 }

local function smash(s, left)
    s.debuffs = { { id = CS, expires = 100 + (left or 5) } }
end

test(
    'switch: the catch-all owns levels 1-9 and a spec-less 10+; each specialization picks its premade; variants are off',
    function()
        local f, s = warrior(5)
        assert(M.scoped(f, 'WARRIOR') == 6)
        assert(M.selected(f, s) == BASE and M.ordered(f, s) == BASE)

        assert(
            f.addon:evaluateConditionResult(M.body(f.addon, ARMS).switch).status == 'no-match',
            'below 10 the level test ends the switch before the specialization'
        )

        s.specID(72)

        assert(
            M.selected(f, s) == BASE and M.ordered(f, s) == BASE,
            'levels 1-9 stay in the catch-all whatever the client reports'
        )

        s.level = 20
        s.spec = nil
        assert(M.selected(f, s) == BASE and M.ordered(f, s) == BASE, 'no specialization yet')

        assert(
            not f.addon:RotationSpecsApply(M.body(f.addon, FURY).specs, s.talentGroup),
            'no specialization yet: no specialization premade applies (body.specs)'
        )

        s.specID(71)
        assert(M.selected(f, s) == ARMS and M.ordered(f, s) == ARMS)
        s.specID(72)
        M.know(s, MS, SS)
        assert(M.selected(f, s) == FURY and M.ordered(f, s) == FURY, 'spells of other specializations do not matter')
        s.specID(73)
        assert(M.selected(f, s) == PROT and M.ordered(f, s) == PROT)
        s.talentGroup = 2
        s.specID(71)
        assert(M.selected(f, s) == ARMS, 'second talent group, another spec')
        local a = f.addon

        for _, id in ipairs({ ARMSIV, FURYIV }) do
            assert(M.body(a, id).disabled and M.body(a, id).priority < M.body(a, ARMS).priority, id)
        end

        assert(a:SetDefaultRotationEnabled(ARMSIV, true))
        assert(M.selected(f, s) == ARMS, 'the recommended premade outranks an enabled variant')
        assert(a:SetDefaultRotationEnabled(ARMS, false))
        assert(M.selected(f, s) == ARMSIV)

        for _, src in ipairs(a:GetDefaultRotation(ARMSIV).envelope.sources) do
            assert(not src.url:find('wowsims'), src.url)
        end
    end
)

test('a Wrath progression client never registers the Mists premades', function()
    local f = M.fixture('WARRIOR', { project = 11, expansion = 2 })
    assert(#f.addon:ListDefaultRotations(1) == 0 and f.addon:GetDefaultRotation(ARMS) == nil)
end)

test(
    'boundaries: casts, channels and no target stop with Attack suppressed; out of combat Charge, Heroic Throw, then Attack',
    function()
        for _, id in ipairs({ ARMS, ARMSIV, FURY, FURYIV, PROT, BASE }) do
            local f, s = warrior(90, armsFull, fury, { SS })

            for _, key in ipairs({ 'cast', 'channel' }) do
                s[key] = true
                local x, r = M.first(f, s, id)
                assert(not x and r.status == 'stopped' and r.suppressAttack, id .. ' ' .. key)
                s[key] = false
            end

            s.hostile = false
            local x, r = M.first(f, s, id)
            assert(not x and r.suppressAttack, id)
            s.hostile = true
            s.combat = false
            s.range[100] = true
            assert(first(f, s, id) == 100, id .. ' charge')
            s.range[100] = false

            if id ~= BASE then
                s.range[6603] = false
                assert(first(f, s, id) == 57755, id .. ' throw')
                s.range[6603] = true
            end

            x, r = M.first(f, s, id)
            assert(not x and r.status == 'stopped' and not r.suppressAttack, id .. ' out of combat lets Attack start')
        end
    end
)

test(
    'Arms levelling: Mortal Strike, Overpower on Taste for Blood, Slam filler, Execute below 20%; Charge for rage when out of range',
    function()
        local f, s = warrior(30, arms)
        assert(first(f, s, ARMS) == MS)
        s.cooldown[MS] = { startTime = 99, duration = 6, isEnabled = true, modRate = 1 }
        assert(first(f, s, ARMS) == SLAM, 'no window before 81: Slam filler')
        s.buffs = { { id = 60503, stacks = 1 } }
        assert(first(f, s, ARMS) == OP)
        s.buffs = { { id = 60503, stacks = 4 } }
        s.power = 100
        assert(first(f, s, ARMS) == OP, 'four stacks before a rage Slam')
        s.targetHealth = 15
        s.usable[EXEC] = true
        assert(first(f, s, ARMS) == EXEC, 'Sudden Execute unknown: Execute')
        s.nopower[EXEC] = true
        assert(first(f, s, ARMS) == OP)
        s.targetHealth = 100
        s.usable[EXEC] = false
        s.nopower[EXEC] = nil
        s.buffs = {}
        s.power = 40
        s.range[100] = true
        assert(first(f, s, ARMS) == 100, 'charge-weave under 66 rage')
        s.power = 80
        assert(first(f, s, ARMS) == SLAM)
        s.health = 60
        M.know(s, 103840)
        s.usable[103840] = true
        assert(first(f, s, ARMS) == 103840, 'Impending Victory below 70%')
    end
)

test(
    'Arms full kit: Colossus Smash window, Storm Bolt in it, Dragon Roar outside, Bladestorm with Bloodbath, shout for rage',
    function()
        local f, s = warrior(90, armsFull)
        assert(first(f, s, ARMS) == CS)
        smash(s, 0.5)
        assert(first(f, s, ARMS) == CS, 'refresh under a second')
        smash(s)
        assert(first(f, s, ARMS) == MS)
        s.cooldown[MS] = { startTime = 99, duration = 6, isEnabled = true, modRate = 1 }
        assert(first(f, s, ARMS) == 107570, 'Storm Bolt in the window')
        s.cooldown[107570] = { startTime = 99, duration = 30, isEnabled = true, modRate = 1 }
        assert(first(f, s, ARMS) == SLAM, 'Slam in the window, not Dragon Roar')
        s.debuffs = {}
        s.cooldown[CS] = { startTime = 99, duration = 20, isEnabled = true, modRate = 1 }
        assert(first(f, s, ARMS) == 118000, 'Dragon Roar outside')
        s.cooldown[118000] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
        assert(first(f, s, ARMS) == 46924, 'Bladestorm without Bloodbath talented')
        s.talents[17] = true
        assert(first(f, s, ARMS) == SLAM, 'Bloodbath talented: wait for it')
        s.buffs = { { id = 12292 } }
        assert(first(f, s, ARMS) == 46924)
        s.buffs = {}
        s.talents[17] = nil
        s.cooldown[46924] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
        s.nopower[SLAM] = true
        s.power = 20
        assert(first(f, s, ARMS) == 6673, 'Battle Shout for rage')
        s.buffs = { { id = 469 } }
        assert(first(f, s, ARMS) == 469, 'keep your Commanding Shout')
    end
)

test(
    'Arms AoE on engaged enemies: Sweeping Strikes, Thunder Clap for Deep Wounds on three, Whirlwind on five',
    function()
        local f, s = warrior(90, armsFull)
        smash(s)
        s.enemies = { 0, 0 }
        assert(first(f, s, ARMS) == 12328)
        s.buffs = { { id = 12328 } }
        assert(first(f, s, ARMS) == MS, 'two enemies: Sweeping Strikes then the single-target list')
        s.enemies = { 0, 0, 0 }
        assert(first(f, s, ARMS) == 6343)
        s.debuffs[2] = { id = 115767, expires = 110 }
        assert(first(f, s, ARMS) == 46924)
        s.enemies = { 0, 0, false }
        assert(first(f, s, ARMS) == MS, 'an enemy that is not fighting you is not counted')
        s.enemies = { 0, 0, 0, 0, 0 }

        for _, id in ipairs({ 46924, 118000, MS, SLAM }) do
            s.cooldown[id] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
        end

        s.power = 30
        assert(first(f, s, ARMS) == 1680, 'Whirlwind on five')
    end
)

test('Arms Icy Veins variant pools rage outside the window and Slams freely inside it', function()
    local f, s = warrior(90, armsFull)
    s.cooldown[CS] = { startTime = 99, duration = 20, isEnabled = true, modRate = 1 }

    for _, id in ipairs({ MS, 46924, 118000, 107570 }) do
        s.cooldown[id] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
    end

    s.power = 60
    assert(first(f, s, ARMS) == SLAM, 'recommended: Slam filler')
    local x, r = M.first(f, s, ARMSIV)
    assert(x == nil and r.status ~= 'stopped', 'pooling: nothing to press')
    s.power = 85
    assert(first(f, s, ARMSIV) == SLAM)
    s.power = 60
    smash(s)
    assert(first(f, s, ARMSIV) == SLAM, 'in the window')
    s.targetHealth = 10
    s.usable[EXEC] = true
    s.debuffs = {}
    s.cooldown[CS] = nil
    assert(first(f, s, ARMSIV) == CS)
    smash(s)
    assert(first(f, s, ARMSIV) == EXEC)
    s.targetHealth = 100
    s.enemies = { 0, 0, 0 }
    s.buffs = { { id = 12328 } }
    assert(first(f, s, ARMSIV) == 6343, 'pack: Thunder Clap')
end)

test(
    'Fury: Colossus Smash with banked charges, Bloodthirst, Bloodsurge, Raging Blow keeps a charge, Wild Strike filler',
    function()
        local f, s = warrior(30, fury)
        assert(first(f, s, FURY) == BT)
        s.cooldown[BT] = { startTime = 99, duration = 4.5, isEnabled = true, modRate = 1 }
        assert(first(f, s, FURY) == RB, 'before 81 Raging Blow is never held')
        s.usable[RB] = false
        assert(first(f, s, FURY) == WS)
        s.targetHealth = 10
        s.usable[EXEC] = true
        assert(first(f, s, FURY) == EXEC)
        s.targetHealth = 100
        local g, t = warrior(90, fury, { CS, 107570, 118000, 46924 })
        t.cooldown[BT] = { startTime = 99, duration = 4.5, isEnabled = true, modRate = 1 }
        t.buffs = { { id = 131116, stacks = 2 } }
        assert(first(g, t, FURY) == CS, 'two charges banked: Smash')
        t.buffs = { { id = 131116, stacks = 1 } }
        assert(first(g, t, FURY) == CS, 'Smash is next on its own line when missing')
        t.cooldown[CS] = { startTime = 99, duration = 20, isEnabled = true, modRate = 1 }
        assert(first(g, t, FURY) == 107570)
        t.cooldown[107570] = { startTime = 99, duration = 30, isEnabled = true, modRate = 1 }
        assert(first(g, t, FURY) == 118000, 'Dragon Roar outside the window')
        t.cooldown[118000] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
        assert(first(g, t, FURY) == 46924, 'Bladestorm while Bloodthirst cools')
        t.cooldown[46924] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
        t.buffs[2] = { id = 46916 }
        assert(first(g, t, FURY) == WS, 'Bloodsurge')
        t.buffs[2] = nil
        assert(first(g, t, FURY) == RB, 'Smash is far away: spend')
        t.cooldown[CS] = { startTime = 99, duration = 2, isEnabled = true, modRate = 1 }
        assert(first(g, t, FURY) == nil, 'Smash within 1.5 s: keep the charge and pool')
        t.power = 85
        assert(first(g, t, FURY) == WS, '80 rage: Wild Strike anyway')
        smash(t, 1)
        assert(first(g, t, FURY) == RB, 'window closing: dump charges')
    end
)

test('Fury AoE and the Icy Veins variant', function()
    local f, s = warrior(90, fury, { CS, 46924, 118000 })
    s.cooldown[46924] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
    s.enemies = { 0, 0 }
    smash(s)
    s.buffs = { { id = 12880 } }
    assert(first(f, s, FURY) == 1680, 'Whirlwind for Meat Cleaver')
    s.buffs[2] = { id = 85739, stacks = 1 }
    assert(first(f, s, FURY) == RB)
    s.buffs[1] = nil
    assert(first(f, s, FURY) == BT, 'Bloodthirst for Enrage')
    s.enemies = {}
    s.buffs = {}
    s.cooldown[46924] = nil
    assert(first(f, s, FURYIV) == 46924, 'Icy Veins spends Bladestorm in the window')
    assert(first(f, s, FURY) == BT)
    s.targetHealth = 10
    s.usable[EXEC] = true
    s.debuffs = {}
    s.cooldown[CS] = { startTime = 99, duration = 20, isEnabled = true, modRate = 1 }
    s.cooldown[118000] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
    assert(first(f, s, FURYIV) == EXEC, 'Execute ahead of Bloodthirst')
    s.enemies = { 0, 0, 0, 0 }
    s.targetHealth = 100
    assert(first(f, s, FURYIV) == BT, 'four: Enrage first')
end)

test(
    'Protection: Weakened Armor on elites, Shield Slam, Revenge, Devastate for Deep Wounds, Sunder before Devastate',
    function()
        local f, s = warrior(20, { SS, 7386, 6343, 2565 })
        s.form = 2
        assert(first(f, s, PROT) == SS)
        s.cooldown[SS] = { startTime = 99, duration = 6, isEnabled = true, modRate = 1 }
        assert(first(f, s, PROT) == 7386, 'Sunder Armor for Deep Wounds before Devastate')
        s.debuffs = { { id = 115767, expires = 110 } }
        s.cooldown[6343] = { startTime = 99, duration = 6, isEnabled = true, modRate = 1 }
        assert(first(f, s, PROT) == 7386, 'Sunder filler')
        local g, t = warrior(90, { SS, 20243, 7386, 6343, 6572, 2565, 118000, 46968 })
        t.form = 2
        t.cooldown[118000] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
        t.classification = 'elite'
        assert(first(g, t, PROT) == 20243, 'three Weakened Armor on an elite')
        t.debuffs = { { id = 113746, stacks = 3, expires = 120, source = 'party1' } }
        assert(first(g, t, PROT) == SS)
        t.power = 45
        t.charges[2565] = { 1, 2 }
        assert(first(g, t, PROT) == 6572, 'Revenge for the last Block rage')
        t.power = 70
        assert(first(g, t, PROT) == SS)
        t.cooldown[SS] = { startTime = 99, duration = 6, isEnabled = true, modRate = 1 }
        assert(first(g, t, PROT) == 20243, 'Deep Wounds missing')
        t.debuffs[2] = { id = 115767, expires = 110 }
        assert(first(g, t, PROT) == 6572)
        t.cooldown[6572] = { startTime = 99, duration = 9, isEnabled = true, modRate = 1 }
        assert(first(g, t, PROT) == 6343, 'Thunder Clap for Weakened Blows')
        t.debuffs[3] = { id = 115798, expires = 120, source = 'party2' }
        assert(first(g, t, PROT) == 20243)
        t.cooldown[6343] = nil
        t.enemies = { 0, 0, 0 }
        assert(first(g, t, PROT) == 46968, 'Shockwave on three')
        t.cooldown[46968] = { startTime = 99, duration = 40, isEnabled = true, modRate = 1 }
        assert(first(g, t, PROT) == 6343, 'Thunder Clap on cooldown on three')
    end
)

test(
    'reminders: shouts, stances, burst with Colossus Smash on long fights, rage dumps, interrupts, tank mitigation',
    function()
        local f, s = warrior(90, armsFull, {18499, 1719, 114207, 6544, 6552, 118038, 78, 845, 2457})
        s.form = 2
        local u = M.upkeep(f, s, ARMS)
        assert(u['warrior-shout'] == 6673 and u['warrior-stance'] == 2457)
        s.form = 3
        s.buffs = { { id = 469, source = 'party1' } }
        u = M.upkeep(f, s, ARMS)
        assert(not u['warrior-shout'] and not u['warrior-stance'], 'another shout and Berserker Stance are respected')
        assert(not u['warrior-arms-recklessness'])
        smash(s)
        assert(not M.upkeep(f, s, ARMS)['warrior-arms-recklessness'], 'a normal mob')
        s.classification = 'elite'
        u = M.upkeep(f, s, ARMS)

        assert(
            u['warrior-arms-recklessness'] == 1719
                and u['warrior-leap'] == 6544
                and u['warrior-arms-berserker-rage'] == 18499
        )

        s.ttd = 20
        s.classification = 'normal'
        assert(M.upkeep(f, s, ARMS)['warrior-arms-recklessness'], 'long forecast')
        s.power = 40
        assert(not M.upkeep(f, s, ARMS)['warrior-arms-heroic-strike'])
        s.power = 55
        assert(M.upkeep(f, s, ARMS)['warrior-arms-heroic-strike'] == 78, '50 rage in the window')
        s.debuffs = {}
        s.power = 95
        assert(not M.upkeep(f, s, ARMS)['warrior-arms-heroic-strike'])
        s.enemies = { 0, 0 }
        s.buffs[2] = { id = 12328 }
        s.power = 100
        u = M.upkeep(f, s, ARMS)
        assert(u['warrior-arms-cleave'] == 845 and not u['warrior-arms-heroic-strike'])
        s.targetCast = 'Fireball'
        assert(M.upkeep(f, s, ARMS)['warrior-pummel'] == 6552)
        s.health = 30
        assert(M.upkeep(f, s, ARMS)['warrior-die-by-the-sword'] == 118038)
        s.group = true
        s.buffs[3] = { id = 1719 }
        assert(M.upkeep(f, s, ARMS)['warrior-skull-banner'] == 114207)
        assert(not M.upkeep(f, s, ARMS)['warrior-shattering-throw'], 'off by default')
        local g, t = warrior(90, { SS, 2565, 112048, 71, 1160, 12975, 871 })
        t.form = 1
        u = M.upkeep(g, t, PROT)
        assert(u['warrior-prot-stance'] == 71 and u['warrior-prot-shield-block'] == 2565)
        t.buffs = { { id = 132404 } }
        t.health = 70
        u = M.upkeep(g, t, PROT)

        assert(
            not u['warrior-prot-shield-block'] and u['warrior-prot-shield-barrier'] == 112048,
            'Barrier while blocking and hurt'
        )

        t.health = 25
        t.classification = 'elite'
        u = M.upkeep(g, t, PROT)
        assert(u['warrior-prot-last-stand'] and u['warrior-prot-shield-wall'] and u['warrior-prot-demoralizing-shout'])
        assert(not u['warrior-prot-taunt'], 'taunt is off by default')
    end
)

test(
    'stances are read by spell: the reminders follow Battle, Defensive and Berserker Stance wherever they sit on the bar',
    function()
        local f, s = warrior(90, armsFull, { 2457, 71 })
        s.bar = { 71, 2457 }
        s.form = 2
        local u = M.upkeep(f, s, ARMS)
        assert(not u['warrior-stance'], 'Battle Stance in slot 2 is Battle Stance')
        assert(M.upkeep(f, s, PROT)['warrior-prot-stance'] == 71)
        s.form = 1
        assert(M.upkeep(f, s, ARMS)['warrior-stance'] == 2457, 'Defensive Stance in slot 1 asks for Battle Stance')
        assert(not M.upkeep(f, s, PROT)['warrior-prot-stance'])
        s.bar = { 2458, 2457, 71 }
        s.form = 1
        assert(not M.upkeep(f, s, ARMS)['warrior-stance'], 'Berserker Stance learned first is still Berserker')
        s.bar[1] = {}
        s.form = 1
        assert(not M.upkeep(f, s, ARMS)['warrior-stance'], 'an unreadable stance skips the reminder')
        s.bar = { 2457 }
        s.form = 0
        assert(M.upkeep(f, s, BASE)['warrior-starter-stance'] == 2457)
        s.form = 1
        assert(not M.upkeep(f, s, BASE)['warrior-starter-stance'])
    end
)

test(
    "Fury weapons: Single-Minded Fury Executes before Bladestorm, Titan's Grip spends a Raging Blow outside the window first",
    function()
        local f, s = warrior(90, fury, { CS, 46924 })
        s.cooldown[BT] = { startTime = 99, duration = 4.5, isEnabled = true, modRate = 1 }
        s.cooldown[CS] = { startTime = 99, duration = 20, isEnabled = true, modRate = 1 }
        s.cooldown[107570] = { startTime = 99, duration = 30, isEnabled = true, modRate = 1 }
        s.targetHealth = 15
        s.usable[EXEC] = true
        s.buffs = { { id = 131116, stacks = 1 } }
        s.gear = { [16] = M.SWORD, [17] = M.SWORD }
        assert(first(f, s, FURY) == EXEC, 'one-handers: Execute ahead of Bladestorm')
        s.gear = { [16] = M.AXE2H, [17] = M.AXE2H }
        assert(first(f, s, FURY) == 46924, "two-handers: Bladestorm first")
        s.cooldown[46924] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
        assert(first(f, s, FURY) == RB, "Titan's Grip: Raging Blow before Execute outside the window")
        s.buffs[2] = { id = 1719 }
        assert(first(f, s, FURY) == EXEC, 'not with Recklessness up')
        s.buffs[2] = nil
        smash(s)
        assert(first(f, s, FURY) == EXEC, 'not in the window')
        s.debuffs = {}
        s.gear = { [16] = M.AXE2H }
        s.cooldown[46924] = nil
        assert(first(f, s, FURY) == 46924, 'a lone two-hander has neither passive')
        s.cooldown[46924] = { startTime = 99, duration = 60, isEnabled = true, modRate = 1 }
        assert(first(f, s, FURY) == EXEC)
    end
)

test('Unspecialized: Victory Rush, Execute, Heroic Strike at 30 rage, a stance reminder with no stance', function()
    local f, s = warrior(7, { 2457 })
    s.power = 20
    local x, r = M.first(f, s, BASE)
    assert(x == nil and r.status ~= 'stopped')
    s.power = 30
    assert(first(f, s, BASE) == 78)
    s.targetHealth = 15
    s.usable[EXEC] = true
    assert(first(f, s, BASE) == EXEC)
    s.usable[34428] = true
    assert(first(f, s, BASE) == 34428)
    s.form = 0
    assert(M.upkeep(f, s, BASE)['warrior-starter-stance'] == 2457)
    s.form = 2
    assert(not M.upkeep(f, s, BASE)['warrior-starter-stance'])
end)

test('real publisher auto-selects by specialization and highlights', function()
    local f, s = warrior(90, armsFull)
    s.specID(71)
    local poll, selected, glow = M.publisher(f, s)
    poll()

    assert(
        selected() == ARMS and f.addon.currentSpell == CS,
        tostring(selected()) .. ' ' .. tostring(f.addon.currentSpell)
    )

    assert(#glow > 0)
    smash(s)
    poll()
    assert(f.addon.currentSpell == MS)
end)

finish()
