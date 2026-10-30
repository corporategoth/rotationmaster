-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Hunter premades: switches, priorities, boundaries and reminders through the real
-- catalog, predicates, composition and sequence executor on a modeled Forever client (probe policy;
-- the last test keeps the real restricted policy).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local M = dofile('tests/fixtures/forever_premade_model.lua')

local RANGED, SAVER, SV, WEAVE =
    'rm.forever.hunter.ranged',
    'rm.forever.hunter.ranged.mobalytics',
    'rm.forever.hunter.survival',
    'rm.forever.hunter.survival.weave'

local function hunter(level)
    local f, s = M.new('hunter')
    local a = f.addon
    s.setLevel(level or 60)
    s.targetRange = { 30, 35 }
    s.ranged(75, 1130, 1978, 3044, 19434, 2643, 1510, 1293241, 1310687, 3045)
    return a, s, f
end

local kit = {75, 1130, 1978, 3044, 19434, 2643, 1510, 1293241, 1310687, 2973, 1495, 13813}

test('the Hunter premades load, validate and declare Forever only', function()
    local a = hunter()
    local rows = M.rows(a)

    for _, id in ipairs({ RANGED, SAVER, SV, WEAVE }) do
        local row = assert(rows[id], id)
        local scope = row.applicability

        assert(
            row.readOnly
                and row.builtin
                and scope.families[1] == 'forever'
                and #scope.families == 1
                and scope.class == 'HUNTER'
                and scope.maxLevel == nil
                and scope.minLevel == nil,
            id
        )

        local variant = id == SAVER or id == WEAVE

        assert(
            row.eligible == not variant,
            id .. (variant and ' variant is not off by default' or ' not eligible on the probe Forever context')
        )

        assert((row.envelope.body.disabled == true) == variant, id .. ' disabled flag')
    end
end)

test('switch: every Hunter is ranged until Strider Kick; Survival melee after', function()
    local a, s = hunter(1)
    s.learn(75)
    assert(M.selected(a) == RANGED, 'level 1')
    s.setLevel(30)
    s.learn(1293241, 19434)
    assert(M.selected(a) == RANGED, 'Beast Mastery at 30')
    s.learn(1317257)
    assert(M.selected(a) == RANGED, 'a known Strider Kick without Survival points is not the switch')
    s.setTrees({ 0, 0, 20 })
    assert(M.selected(a) == RANGED, 'Survival before 21 points levels ranged')
    s.setTrees({ 0, 0, 21 })
    assert(M.selected(a) == SV, 'Survival main tree with 21 points: melee')
    s.setTrees({ 31, 0, 21 })
    assert(M.selected(a) == RANGED, 'a Beast Mastery hybrid with Strider Kick stays ranged')
    s.setTrees({ 0, 0, 21 })
    assert(M.switch(a, WEAVE) == 'match' and M.switch(a, SAVER) == 'match', 'variants share their switches')
    s.known = {}
    s.setTrees({ 0, 0, 0 })
    assert(M.selected(a) == RANGED, 'a Hunter with nothing learned still gets a premade')
end)

test('ranged: boundaries, melee dead zone and the pull', function()
    local a, s = hunter()
    s.learn((unpack or table.unpack)(kit))
    s.cast = true
    M.expect(a, s, RANGED, nil, 'stopped', 'casting Aimed Shot')
    s.cast = false
    s.channel = true
    M.expect(a, s, RANGED, nil, 'stopped', 'channelling Volley')
    s.channel = false
    s.hostile = false
    M.expect(a, s, RANGED, nil, 'stopped', 'no hostile target')
    s.hostile = true
    s.targetRange = { 0, 5 }
    M.expect(a, s, RANGED, 2973, nil, 'mob in melee: Raptor Strike')
    s.current[2973] = true
    M.expect(a, s, RANGED, 1495, nil, 'Raptor queued: Mongoose Bite')
    s.current[2973] = nil
    s.usable[2973] = false
    s.usable[1495] = false
    local r = M.expect(a, s, RANGED, nil, 'stopped', 'melee strikes down: auto attack')
    assert(not r.suppressAttack)
    s.usable = {}
    s.targetRange = { 30, 35 }
    s.combat = false
    M.expect(a, s, RANGED, 1130, nil, 'pull: Hunter\'s Mark')
    s.debuff('target', 1130, { sourceUnit = 'party1' })
    M.expect(a, s, RANGED, 75, nil, 'pull: another Hunter\'s Mark counts, Auto Shot')
    s.buff('player', 415407)
    M.expect(a, s, RANGED, 1310687, nil, 'pull: Sniper Shot under Rapid Killing')
    s.clearAuras()
    s.repeatActive = true
    s.debuff('target', 1130)
    r = M.expect(a, s, RANGED, nil, 'stopped', 'pull ends after Auto Shot')
end)

test('ranged: Sting, the Hawk cycle, Arcane before Hawk, Aimed Shot', function()
    local a, s = hunter(20)
    s.learn(75, 1978, 3044, 19434)
    s.repeatActive = true
    s.debuff('target', 1130)
    M.expect(a, s, RANGED, 1978, nil, 'own Serpent Sting first')
    s.debuff('target', 3043)
    M.expect(a, s, RANGED, 3044, nil, 'own Scorpid Sting is kept')
    s.clearAuras()
    s.debuff('target', 1130)
    s.debuff('target', 1978, { sourceUnit = 'party1' })
    M.expect(a, s, RANGED, 1978, nil, 'another Hunter\'s Sting is not yours')
    s.health.target = 25
    M.expect(a, s, RANGED, 1978, nil, 'target health is secret: Sting even on a dying target')
    s.debuff('target', 1978)
    M.expect(a, s, RANGED, 3044, nil, 'Arcane on cooldown before Summon Hawk')
    s.health.target = 100
    s.debuff('target', 1978)
    s.cooling(3044, 4)
    M.expect(a, s, RANGED, 19434, nil, 'Aimed Shot while Arcane cools')
    s.cooldown = {}
    s.setLevel(30)
    s.learn(1293241)
    M.expect(a, s, RANGED, 1293241, nil, 'first Hawk')
    s.history(1293241, 6)
    M.expect(a, s, RANGED, 3044, nil, 'Arcane after a Hawk when Arcane is overdue')
    s.history(3044, 6)
    s.history(1293241, 0.5)
    M.expect(a, s, RANGED, 1293241, nil, 'Hawk again')
    a.spellHistory = {}
    s.history(3044, 12)
    s.history(1293241, 6)
    M.expect(a, s, RANGED, 1293241, nil, 'second Hawk before the next Arcane')
    s.cooling(1293241, 4)
    s.cooling(3044, 4)
    M.expect(a, s, RANGED, 19434, nil, 'Aimed Shot fills the shared cooldown')
    s.cooling(19434, 4)
    local r = M.expect(a, s, RANGED, nil, 'stopped', 'Auto Shot and the pet do the rest')
    assert(r.suppressAttack)
    s.cooldown = {}
    s.cooling(1293241, 4)
    s.cooling(3044, 4)
    s.learn(1310687)
    M.expect(a, s, RANGED, 19434, nil, 'no Sniper Shot on a normal mob without Rapid Killing')
    s.classification = 'elite'
    M.expect(a, s, RANGED, 1310687, nil, 'Sniper Shot on an elite')
end)

test('ranged: moving, Auto Shot restart, Mark and the AoE branch', function()
    local a, s = hunter()
    s.learn(75, 1130, 1978, 3044, 19434, 2643, 1510, 13813)
    s.debuff('target', 1978)
    s.debuff('target', 1130)
    s.moving = true
    M.expect(a, s, RANGED, 2643, nil, 'moving: Multi-Shot')
    s.cooling(2643, 3)
    M.expect(a, s, RANGED, 3044, nil, 'moving: Arcane')
    s.cooling(3044, 3)
    local r = M.expect(a, s, RANGED, nil, 'stopped', 'moving: nothing else')
    s.cooldown = {}
    s.moving = false
    M.expect(a, s, RANGED, 75, nil, 'Auto Shot is restarted')
    s.repeatActive = true
    s.clearAuras()
    s.debuff('target', 1978)
    s.health.target = 20
    M.expect(a, s, RANGED, 1130, nil, 'Mark on every target (health is secret)')
    s.debuff('target', 1130)
    s.health.target = 100
    s.near(2)
    M.expect(a, s, RANGED, 2643, nil, 'two enemies: Multi-Shot')
    s.near(3)
    M.expect(a, s, RANGED, 13813, nil, 'three: Explosive Trap')
    s.cooling(13813, 20)
    s.cooling(2643, 3)
    s.near(5)
    M.expect(a, s, RANGED, 1510, nil, 'five: Volley')
    s.near(4)
    M.expect(a, s, RANGED, 3044, nil, 'four with Multi-Shot cooling: single-target shots')
end)

test('ranged reminders: aspects, Trueshot Aura, pet care, burst on elites', function()
    local a, s = hunter()
    s.learn(13165, 13163, 5118, 1299346, 883, 982, 136, 3045, 19574, 20572, 19577)
    local lit = M.upkeep(a, s, RANGED)
    assert(lit[13165] and not lit[13163] and lit[1299346] and lit[883], 'Hawk, Trueshot, Call Pet')
    assert(not lit[3045] and not lit[19574], 'no burst on a normal mob')
    s.buff('player', 13165)
    s.buff('player', 1299346)
    s.pet = true
    s.health.pet = 30
    lit = M.upkeep(a, s, RANGED)

    assert(
        not lit[13165] and not lit[1299346] and not lit[883] and not lit[136],
        'Mend Pet is yours (health is secret)'
    )

    s.petDead = true
    lit = M.upkeep(a, s, RANGED)
    assert(lit[982] and not lit[136], 'Revive a dead pet')
    s.petDead = false
    s.classification = 'elite'
    lit = M.upkeep(a, s, RANGED)

    assert(
        lit[3045] and lit[19574] and lit[20572] and lit[19577],
        'burst on an elite; Intimidation when the mob is on you'
    )

    s.classification = 'normal'
    s.instance = 'party'
    lit = M.upkeep(a, s, RANGED)
    assert(lit[3045], 'burst in a dungeon')
    s.known[13165] = nil
    s.clearAuras()
    lit = M.upkeep(a, s, RANGED)
    assert(lit[13163], 'Monkey before Hawk')
    s.combat = false
    lit = M.upkeep(a, s, RANGED)
    assert(not lit[13163] and not lit[5118], 'no aspect nagging out of combat; Cheetah is opt-in')
end)

test('mana-saving variant: one Hawk, Aimed, no Arcane with Hawk', function()
    local a, s = hunter()
    s.learn(75, 1978, 3044, 19434, 1293241, 2643)
    s.repeatActive = true
    s.debuff('target', 1130)
    s.debuff('target', 1978)
    M.expect(a, s, SAVER, 1293241, nil, 'first Hawk')
    s.history(1293241, 3)
    M.expect(a, s, SAVER, 19434, nil, 'Aimed Shot while a Hawk is up')
    s.cooling(19434, 4)

    local r = M.expect(
        a,
        s,
        SAVER,
        nil,
        'stopped',
        'no second Hawk (target health is secret) and no Arcane Shot once Summon Hawk is known'
    )

    s.known[1293241] = nil
    M.expect(a, s, SAVER, 3044, nil, 'Arcane Shot before Hawk')
    s.near(2)
    s.cooldown = {}
    M.expect(a, s, SAVER, 2643, nil, 'Multi-Shot on two')
end)

test('Survival melee: pull, range shots, melee order and packs', function()
    local a, s = hunter()
    s.learn(1317257, 1130, 1978, 3044, 19434, 75, 1495, 2973, 19306, 13813)
    s.combat = false
    M.expect(a, s, SV, 1130, nil, 'pull: Mark')
    s.debuff('target', 1130)
    M.expect(a, s, SV, 1978, nil, 'pull: Sting from range')
    s.debuff('target', 1978)
    local r = M.expect(a, s, SV, nil, 'stopped', 'then run in')
    assert(not r.suppressAttack)
    s.combat = true
    M.expect(a, s, SV, 3044, nil, 'in combat out of range: Arcane Shot')
    s.targetRange = { 0, 5 }
    M.expect(a, s, SV, 1495, nil, 'melee: Mongoose Bite first')
    s.usable[1495] = false
    M.expect(a, s, SV, 1317257, nil, 'Strider Kick')
    s.cooling(1317257, 5)
    M.expect(a, s, SV, 2973, nil, 'Raptor Strike')
    s.current[2973] = true
    M.expect(a, s, SV, 19306, nil, 'Raptor queued: Counterattack')
    s.usable[19306] = false
    r = M.expect(a, s, SV, nil, 'stopped', 'auto attack')
    assert(not r.suppressAttack)
    s.near(3)
    M.expect(a, s, SV, 13813, nil, 'Explosive Trap on three')
    s.learn(13161)
    local lit = M.upkeep(a, s, SV)
    assert(lit[13161] and not lit[13165], 'Aspect of the Beast, not Hawk')
    s.clearAuras()
    s.learn(1130)
    lit = M.upkeep(a, s, SV)
    assert(lit[1130], 'Mark upkeep for Expose Prey')
end)

test('Survival weave: exit with Strider Kick, shoot outside, return when Raptor is ready', function()
    local a, s = hunter()
    s.learn(1317257, 1130, 1978, 3044, 19434, 75, 1495, 2973, 19306)
    s.debuff('target', 1130)
    s.debuff('target', 1978)
    s.targetRange = { 0, 5 }
    M.expect(a, s, WEAVE, 1495, nil, 'Mongoose Bite')
    s.usable[1495] = false
    M.expect(a, s, WEAVE, 2973, nil, 'Raptor Strike')
    s.cooling(2973, 4)
    M.expect(a, s, WEAVE, 1317257, nil, 'Raptor far off: Strider Kick out')
    s.cooling(2973, 2)
    M.expect(a, s, WEAVE, 19306, nil, 'Raptor close: stay in')
    s.targetRange = { 8, 25 }
    s.cooling(2973, 4)
    M.expect(a, s, WEAVE, 3044, nil, 'outside: Arcane Shot')
    s.cooling(2973, 0.5)
    local r = M.expect(a, s, WEAVE, nil, 'stopped', 'Raptor nearly ready: go back in')
    assert(not r.suppressAttack)
end)

test(
    'on the real restricted Forever client every Hunter premade is complete and the ranged premade auto-selects',
    function()
        M.checkRestricted(
            'hunter',
            { RANGED, SAVER, SV, WEAVE },
            function(s)
                s.learn(75, 1317257)
            end,
            RANGED
        )
    end
)

finish()
