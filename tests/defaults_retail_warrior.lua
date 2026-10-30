-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Warrior premades: specialization slots, the Blizzard Assisted rotations, the
-- disabled guide references and the reminders, through the real catalog, predicates,
-- composition, readiness and sequence executor on a modeled Retail client (probe policy; the last
-- test keeps the real restricted policy). Rage is the player's current power (POWER).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local M = dofile('tests/fixtures/retail_premade_model_b.lua')

local ARMS, ARMSSL, ARMSCO =
    'rm.retail.warrior.arms', 'rm.retail.warrior.arms.slayer', 'rm.retail.warrior.arms.colossus'

local FURY, FURYSL, FURYTH = 'rm.retail.warrior.fury', 'rm.retail.warrior.fury.slayer', 'rm.retail.warrior.fury.thane'
local PROT, PROTIV = 'rm.retail.warrior.protection', 'rm.retail.warrior.protection.icyveins'
local SPECS = { [71] = { ARMS, ARMSSL, ARMSCO }, [72] = { FURY, FURYSL, FURYTH }, [73] = { PROT, PROTIV } }
local unpack = unpack or table.unpack

local function warrior()
    local f, s = M.new('warrior')
    s.powerType = 1
    s.energy = 40
    s.ranged(100)
    return f.addon, s, f
end

test('every Warrior premade is listed in each slot, Retail only, eligible only in its own specialization', function()
    local a = warrior()
    M.checkSlots(a, SPECS)

    for _, id in ipairs({ ARMSSL, ARMSCO, FURYSL, FURYTH, PROTIV }) do
        assert(M.row(a, 71, id).envelope.body.disabled == true, id .. ' reference is not off by default')
    end
end)

test('Assisted: each specialization follows Blizzard\'s suggestion after the Stops', function()
    local a, s = warrior()
    s.learn(12294, 23881, 23922)
    M.checkAssisted(a, s, 71, ARMS, 12294)
    M.checkAssisted(a, s, 72, FURY, 23881)
    M.checkAssisted(a, s, 73, PROT, 23922)
    s.suggest = 23922
    s.hostile = false
    local r = M.expect(a, s, 73, PROT, nil, 'stopped', 'no enemy target')
    assert(r.suppressAttack)
end)

test('reminders: Battle Shout, Heroic Strike, cooldowns, defensives', function()
    local a, s = warrior()
    s.learn(6673, 6552, 107574, 1269383, 376079, 118038, 1719, 184364)
    s.combat = false
    local lit = M.upkeep(a, s, 71, ARMS)
    assert(lit[6673] and not lit[1269383], 'Battle Shout between pulls')
    s.buff('player', 6673, { sourceUnit = 'party1' })
    lit = M.upkeep(a, s, 72, FURY)
    assert(not lit[6673], 'anyone\'s Battle Shout counts')
    s.combat = true
    lit = M.upkeep(a, s, 71, ARMS)

    assert(
        lit[107574] and lit[1269383] and lit[376079] and lit[118038],
        'Arms: Avatar, Heroic Strike, Champion\'s Spear, Die by the Sword on readiness'
    )

    lit = M.upkeep(a, s, 72, FURY)

    assert(
        lit[1719] and lit[107574] and lit[184364],
        'Fury: Recklessness, Avatar, Enraged Regeneration on readiness (health is secret)'
    )

    s.combat = false
    assert(not M.upkeep(a, s, 71, ARMS)[118038] and not M.upkeep(a, s, 72, FURY)[184364], 'defensives out of combat')
end)

test('Protection Assisted: Shield Block and Ignore Pain while tanking, Taunt in a group, defensives', function()
    local a, s = warrior()
    s.learn(2565, 190456, 107574, 1160, 376079, 871, 12975, 355)
    local lit = M.upkeep(a, s, 73, PROT)
    assert(lit[2565] and lit[190456] and lit[1160] and not lit[355], 'mitigation while the target attacks you')
    s.targetTarget = 'party1'
    lit = M.upkeep(a, s, 73, PROT)
    assert(not lit[2565] and not lit[190456] and not lit[355], 'not tanking: no mitigation; solo: no Taunt')
    s.group = true
    lit = M.upkeep(a, s, 73, PROT)
    assert(lit[355], 'grouped: Taunt')
    s.targetTarget = 'player'
    s.health.player = 20
    lit = M.upkeep(a, s, 73, PROT)
    assert(lit[871] and lit[12975], 'Shield Wall and Last Stand when low')
end)

test('Arms Slayer reference: Charge, Sweeping Strikes, Rend before Smash, Sudden Death, Bladestorm, fillers', function()
    local a, s = warrior()
    s.learn(100, 260708, 772, 228920, 163201, 167105, 227847, 1269383, 7384, 12294, 1464)
    s.combat = false
    M.expect(a, s, 71, ARMSSL, 100, nil, 'Charge to open')
    s.combat = true
    s.cooling(167105, 1)
    M.expect(a, s, 71, ARMSSL, 772, nil, 'Rend before Colossus Smash')
    s.debuff('target', 388539, { expirationTime = 112, duration = 15 })
    M.expect(a, s, 71, ARMSSL, 228920, nil, 'Ravager just before Colossus Smash')
    s.cooldown = {}
    s.cooling(228920, 60)
    M.expect(a, s, 71, ARMSSL, 167105, nil, 'Colossus Smash')
    s.cooling(167105, 40)
    s.buff('player', 52437, { applications = 2 })
    M.expect(a, s, 71, ARMSSL, 163201, nil, 'two Sudden Death: Execute')
    s.clearAuras()
    s.debuff('target', 388539, { expirationTime = 112, duration = 15 })
    M.expect(a, s, 71, ARMSSL, 1269383, nil, 'Heroic Strike')
    s.usable[1269383] = false
    s.debuff('target', 208086)
    M.expect(a, s, 71, ARMSSL, 227847, nil, 'Bladestorm in Colossus Smash')
    s.cooling(227847, 60)
    M.expect(a, s, 71, ARMSSL, 12294, nil, 'Mortal Strike')
    s.cooling(12294, 4)
    s.usable[163201] = false
    M.expect(a, s, 71, ARMSSL, 7384, nil, 'Overpower')
    s.cooling(7384, 5)
    M.expect(a, s, 71, ARMSSL, 1464, nil, 'Slam')
    s.near(2)
    M.expect(a, s, 71, ARMSSL, 260708, nil, 'two engaged: Sweeping Strikes')
end)

test('Arms Colossus reference: Mortal Strike for Colossal Might, Demolish in Colossus Smash', function()
    local a, s = warrior()
    s.learn(12294, 772, 228920, 163201, 167105, 376079, 436358, 1269383, 7384, 227847, 1464)
    s.debuff('target', 388539, { expirationTime = 112, duration = 15 })
    M.expect(a, s, 71, ARMSCO, 12294, nil, 'Mortal Strike below five Colossal Might')
    s.buff('player', 440989, { applications = 5 })
    M.expect(a, s, 71, ARMSCO, 228920, nil, 'five stacks: Ravager')
    s.cooling(228920, 60)
    M.expect(a, s, 71, ARMSCO, 167105, nil, 'Colossus Smash')
    s.cooling(167105, 40)
    s.debuff('target', 208086)
    M.expect(a, s, 71, ARMSCO, 376079, nil, 'Champion\'s Spear')
    s.cooling(376079, 60)
    M.expect(a, s, 71, ARMSCO, 436358, nil, 'Demolish in Colossus Smash with Colossal Might')
end)

test('Fury Slayer reference: Enrage, Recklessness branch, rage spending, builders', function()
    local a, s = warrior()
    s.learn(100, 190411, 184367, 446035, 5308, 385059, 335097, 335096, 85288, 23881)
    M.expect(a, s, 72, FURYSL, 184367, nil, 'no Enrage: Rampage')
    s.buff('player', 184362, { expirationTime = 104, duration = 4 })
    M.expect(a, s, 72, FURYSL, 335097, nil, 'Crushing Blow')
    s.usable[335097] = false
    M.expect(a, s, 72, FURYSL, 335096, nil, 'Bloodbath')
    s.usable[335096] = false
    s.energy = 100
    M.expect(a, s, 72, FURYSL, 5308, nil, '100 rage outside Recklessness: Execute first')
    s.energy = 40
    s.buff('player', 1719)
    M.expect(a, s, 72, FURYSL, 184367, nil, 'Recklessness: Rampage whenever affordable (rage is secret)')
    s.power[184367] = true
    M.expect(a, s, 72, FURYSL, 446035, nil, 'Recklessness: Bladestorm')
    s.cooling(446035, 60)
    s.usable[5308] = false
    M.expect(a, s, 72, FURYSL, 385059, nil, 'Recklessness: Odyn\'s Fury')
    s.cooling(385059, 30)
    s.clearAuras()
    s.buff('player', 184362, { expirationTime = 104, duration = 4 })
    s.power[184367] = nil
    M.expect(a, s, 72, FURYSL, 85288, nil, 'Raging Blow')
    s.cooling(85288, 5)
    M.expect(a, s, 72, FURYSL, 184367, nil, 'Rampage')
    s.usable[184367] = false
    M.expect(a, s, 72, FURYSL, 23881, nil, 'Bloodthirst')
    s.near(2)
    M.expect(a, s, 72, FURYSL, 190411, nil, 'two engaged without the Whirlwind buff: Whirlwind')
end)

test('Fury Thane reference: Thunder Blast stacks and Avatar, Rampage after Raging Blow and Thunder Blast', function()
    local a, s = warrior()
    s.learn(190411, 184367, 335096, 435222, 335097, 85288, 23881, 5308, 385059, 6343)
    s.buff('player', 184362, { expirationTime = 104, duration = 4 })
    s.buff('player', 435615, { applications = 2 })
    M.expect(a, s, 72, FURYTH, 435222, nil, 'two Thunder Blast stacks')
    s.clearAuras()
    s.buff('player', 184362, { expirationTime = 104, duration = 4 })
    M.expect(a, s, 72, FURYTH, 335097, nil, 'Crushing Blow')
    s.usable[335097] = false
    s.usable[335096] = false
    s.buff('player', 107574)
    M.expect(a, s, 72, FURYTH, 435222, nil, 'Avatar: Thunder Blast')
    s.clearAuras()
    s.buff('player', 184362, { expirationTime = 104, duration = 4 })
    M.expect(a, s, 72, FURYTH, 85288, nil, 'Raging Blow')
    s.energy = 100
    M.expect(a, s, 72, FURYTH, 85288, nil, 'rage is secret: no 100-rage Rampage')
    s.cooling(85288, 5)
    s.usable[435222] = false
    M.expect(a, s, 72, FURYTH, 184367, nil, 'Rampage after Raging Blow and Thunder Blast')
end)

test('Protection Icy Veins reference: Charge, Thunder Blast, Shield Slam, Revenge; mitigation reminders', function()
    local a, s = warrior()
    s.learn(100, 228920, 435222, 436358, 385952, 23922, 6343, 163201, 6572, 20243, 2565, 190456)
    s.combat = false
    M.expect(a, s, 73, PROTIV, 100, nil, 'Charge')
    s.combat = true
    M.expect(a, s, 73, PROTIV, 228920, nil, 'Ravager')
    s.cooling(228920, 60)
    s.cooling(385952, 30)
    M.expect(a, s, 73, PROTIV, 435222, nil, 'Thunder Blast')
    s.usable[435222] = false
    M.expect(a, s, 73, PROTIV, 23922, nil, 'Shield Slam')
    s.cooling(23922, 5)
    M.expect(a, s, 73, PROTIV, 6343, nil, 'Thunder Clap')
    s.cooling(6343, 4)
    s.usable[163201] = false
    M.expect(a, s, 73, PROTIV, 6572, nil, 'Revenge')
    s.usable[6572] = false
    M.expect(a, s, 73, PROTIV, 20243, nil, 'Devastate')
    local lit = M.upkeep(a, s, 73, PROTIV)
    assert(lit[2565] and lit[190456], 'Shield Block while tanking; Ignore Pain whenever ready (rage is secret)')
    s.buff('player', 132404)
    lit = M.upkeep(a, s, 73, PROTIV)
    assert(not lit[2565] and lit[190456], 'Shield Block up')
end)

test(
    'on the real restricted Retail client every Warrior premade is complete and the recommended premade auto-selects',
    function()
        M.checkRestricted('warrior', SPECS, { 12294, 23881, 23922 })
    end
)

test(
    'before a specialization (initial spec 1446) a level-4 Warrior gets the Blizzard Assisted premade, complete',
    function()
        M.initial('warrior', 1446, 'rm.retail.warrior.initial', { 1464 })
    end
)

finish()
