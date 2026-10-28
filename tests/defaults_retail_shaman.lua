-- Retail (Midnight) Shaman premades: specialization slots, the Blizzard Assisted rotations, the
-- disabled guide references, the Restoration healer list and the reminders, through the real
-- catalog, predicates, composition, readiness and sequence executor on a modeled Retail client
-- (probe policy; the last test keeps the real restricted policy).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local M = dofile('tests/fixtures/retail_premade_model_b.lua')
local ELE, ELEIV = 'rm.retail.shaman.elemental', 'rm.retail.shaman.elemental.icyveins'

local ENH, ENHSB, ENHTOT =
    'rm.retail.shaman.enhancement', 'rm.retail.shaman.enhancement.stormbringer', 'rm.retail.shaman.enhancement.totemic'

local RESTO = 'rm.retail.shaman.restoration'
local SPECS = { [262] = { ELE, ELEIV }, [263] = { ENH, ENHSB, ENHTOT }, [264] = { RESTO } }
local unpack = unpack or table.unpack

local function shaman()
    local f, s = M.new('shaman')
    s.ranged(188196, 452201, 188443, 51505, 470411, 196840, 8042, 117014, 470057, 61295, 77472, 1064, 5394, 73685)
    return f.addon, s, f
end

local function mw(s, n)
    local list = s.auras.player.HELPFUL

    for i = #list, 1, -1 do
        if list[i].spellId == 344179 then
            table.remove(list, i)
        end
    end

    s.buff('player', 344179, { applications = n })
end

test('every Shaman premade is listed in each slot, Retail only, eligible only in its own specialization', function()
    local a = shaman()
    M.checkSlots(a, SPECS)

    for _, id in ipairs({ ELEIV, ENHSB, ENHTOT }) do
        assert(M.row(a, 262, id).envelope.body.disabled == true, id .. ' reference is not off by default')
    end
end)

test('Assisted: Elemental and Enhancement follow Blizzard\'s suggestion after the Stops', function()
    local a, s = shaman()
    s.learn(51505, 17364)
    M.checkAssisted(a, s, 262, ELE, 51505)
    M.checkAssisted(a, s, 263, ENH, 17364)
    s.suggest = 17364
    s.hostile = false
    M.expect(a, s, 263, ENH, nil, 'stopped', 'no enemy target')
end)

test('reminders: Lightning Shield and Skyfury between pulls; cooldowns, Spiritwalker\'s Grace while moving', function()
    local a, s = shaman()
    s.learn(462854, 192106, 114050, 114051, 198067, 378081, 79206, 384352, 51533, 57994, 108271)
    s.combat = false
    local lit = M.upkeep(a, s, 262, ELE)
    assert(lit[462854] and lit[192106] and not lit[114050], 'Elemental: Skyfury and Lightning Shield')
    s.buff('player', 192106)
    s.buff('player', 462854, { sourceUnit = 'party1' })
    lit = M.upkeep(a, s, 263, ENH)
    assert(not lit[192106] and not lit[462854], 'both up (anyone\'s Skyfury counts)')
    s.combat = true
    lit = M.upkeep(a, s, 262, ELE)
    assert(lit[114050] and lit[198067] and lit[378081] and not lit[79206], 'Elemental cooldowns')
    s.moving = true
    lit = M.upkeep(a, s, 262, ELE)
    assert(lit[79206], 'Spiritwalker\'s Grace while moving')
    s.moving = false
    lit = M.upkeep(a, s, 263, ENH)
    assert(lit[114051] and lit[384352] and lit[51533], 'Enhancement cooldowns')
    s.health.player = 30
    lit = M.upkeep(a, s, 263, ENH)
    assert(lit[108271], 'Astral Shift when low')
end)

test('Elemental reference: pre-pull, AoE list, Master of the Elements windows, spenders, filler', function()
    local a, s = shaman()
    s.learn(191634, 51505, 443454, 470411, 470057, 452201, 188196, 117014, 8042, 188443, 61882, 196840)
    s.powerType = 11
    s.energy = 40
    s.combat = false
    M.expect(a, s, 262, ELEIV, 191634, nil, 'Stormkeeper before the pull')
    s.cooling(191634, 50)
    M.expect(a, s, 262, ELEIV, 51505, nil, 'Lava Burst before the pull')
    s.combat = true
    M.expect(a, s, 262, ELEIV, 443454, nil, 'Ancestral Swiftness')
    s.cooling(443454, 20)
    M.expect(a, s, 262, ELEIV, 470411, nil, 'Flame Shock missing')
    s.debuff('target', 188389, { expirationTime = 115, duration = 18 })
    s.buff('player', 77762)
    M.expect(a, s, 262, ELEIV, 51505, nil, 'Lava Burst on Lava Surge to start Master of the Elements')
    s.clearAuras()
    s.debuff('target', 188389, { expirationTime = 115, duration = 18 })
    M.expect(a, s, 262, ELEIV, 470057, nil, 'no Lava Surge or charges: Voltaic Blaze')
    s.cooling(470057, 8)
    s.buff('player', 260734)
    M.expect(a, s, 262, ELEIV, 452201, nil, 'Master of the Elements: Tempest')
    s.known[452201] = nil
    M.expect(a, s, 262, ELEIV, 117014, nil, 'then Elemental Blast')
    s.known[117014] = nil
    M.expect(a, s, 262, ELEIV, 8042, nil, 'Earth Shock')
    s.clearAuras()
    s.debuff('target', 188389, { expirationTime = 115, duration = 18 })
    M.expect(a, s, 262, ELEIV, 8042, nil, 'Earth Shock whenever affordable (Maelstrom is secret)')
    s.power[8042] = true
    M.expect(a, s, 262, ELEIV, 188196, nil, 'Lightning Bolt filler while Earth Shock is unaffordable')
    s.power[8042] = nil
    s.moving = true
    M.expect(a, s, 262, ELEIV, 470411, nil, 'moving: Flame Shock')
    s.cooling(470411, 5)
    M.expect(a, s, 262, ELEIV, 196840, nil, 'then Frost Shock')
    s.moving = false
    s.cooldown = {}
    s.near(3)
    s.cooling(191634, 50)
    s.cooling(443454, 20)
    M.expect(a, s, 262, ELEIV, 61882, nil, 'three engaged, Flame Shock up: Earthquake')
    s.buff('player', 191634)
    M.expect(a, s, 262, ELEIV, 188443, nil, 'Stormkeeper: Chain Lightning')
end)

test('Enhancement Stormbringer reference: Flame Shock, Crash buff, Maelstrom Weapon spends, AoE', function()
    local a, s = shaman()
    s.learn(1218090, 470057, 470411, 197214, 187874, 60103, 115356, 452201, 188196, 17364, 188443)
    s.usable[115356] = false
    s.usable[1218090] = false
    M.expect(a, s, 263, ENHSB, 470057, nil, 'Voltaic Blaze to open Flame Shock')
    s.debuff('target', 188389)
    M.expect(a, s, 263, ENHSB, 197214, nil, 'Sundering')
    s.cooling(197214, 20)
    M.expect(a, s, 263, ENHSB, 187874, nil, 'Crash Lightning for its buff')
    s.buff('player', 187878)
    M.expect(a, s, 263, ENHSB, 60103, nil, 'Lava Lash for Lashing Flames')
    s.debuff('target', 334168)
    mw(s, 10)
    M.expect(a, s, 263, ENHSB, 452201, nil, '10 stacks: Tempest')
    s.known[452201] = nil
    M.expect(a, s, 263, ENHSB, 188196, nil, '10 stacks: Lightning Bolt')
    s.known[452201] = true
    s.clearAuras()
    s.debuff('target', 188389)
    s.debuff('target', 334168)
    s.buff('player', 187878)
    mw(s, 8)
    s.cooling(470057, 1)
    M.expect(a, s, 263, ENHSB, 452201, nil, '8 stacks with Voltaic Blaze about ready: spend early')
    s.cooling(470057, 8)
    s.cooling(187874, 10)
    M.expect(a, s, 263, ENHSB, 60103, nil, '8 stacks otherwise: Lava Lash')
    s.charges = { [17364] = 2 }
    M.expect(a, s, 263, ENHSB, 17364, nil, 'Stormstrike at two charges')
    s.charges = nil
    s.usable[1218090] = nil
    mw(s, 9)
    M.expect(a, s, 263, ENHSB, 1218090, nil, 'Primordial Storm at 9')
    s.usable[1218090] = false
    s.clearAuras()
    s.cooldown = {}
    s.near(3)
    M.expect(a, s, 263, ENHSB, 187874, nil, 'three engaged: Crash Lightning for its buff')
    s.buff('player', 187878)
    mw(s, 9)
    M.expect(a, s, 263, ENHSB, 188443, nil, 'Chain Lightning at 9')
end)

test('Enhancement Totemic reference: Surging Totem, Hot Hand Lava Lash, Doom Winds, Lightning Bolt at 5', function()
    local a, s = shaman()
    s.learn(470057, 470411, 444995, 197214, 60103, 187874, 1218090, 115356, 17364, 188196, 188443)
    s.usable[115356] = false
    s.debuff('target', 188389)
    M.expect(a, s, 263, ENHTOT, 444995, nil, 'Surging Totem')
    s.cooling(444995, 20)
    s.cooling(197214, 20)
    s.cooling(60103, 10)
    s.buff('player', 187878)
    M.expect(a, s, 263, ENHTOT, 187874, nil, 'below 5 stacks: Crash Lightning')
    s.cooling(187874, 10)
    M.expect(a, s, 263, ENHTOT, 17364, nil, 'then Stormstrike')
    s.cooldown = {}
    s.cooling(444995, 20)
    s.cooling(197214, 20)
    s.buff('player', 215785)
    M.expect(a, s, 263, ENHTOT, 60103, nil, 'Hot Hand: Lava Lash')
    s.cooling(60103, 5)
    s.buff('player', 466772)
    M.expect(a, s, 263, ENHTOT, 187874, nil, 'Doom Winds: Crash Lightning')
    s.clearAuras()
    s.debuff('target', 188389)
    s.buff('player', 187878)
    s.cooling(187874, 10)
    mw(s, 5)
    M.expect(a, s, 263, ENHTOT, 188196, nil, '5 stacks: Lightning Bolt')
    s.near(3)
    M.expect(a, s, 263, ENHTOT, 188443, nil, 'three engaged at 5 stacks: Chain Lightning')
end)

test('Restoration: friendly heals by readiness, enemy damage, no target stops, healer reminders', function()
    local a, s = shaman()
    s.learn(5394, 73685, 73920, 444995, 61295, 1064, 77472, 470411, 51505, 188196)
    s.hostile = false
    s.friendly = true
    M.expect(a, s, 264, RESTO, 5394, nil, 'Healing Stream Totem')
    s.cooling(5394, 20)
    M.expect(a, s, 264, RESTO, 73685, nil, 'Unleash Life')
    s.cooling(73685, 10)
    M.expect(a, s, 264, RESTO, 444995, nil, 'solo: no Healing Rain; Surging Totem')
    s.group = true
    M.expect(a, s, 264, RESTO, 73920, nil, 'grouped: Healing Rain')
    s.cooling(73920, 10)
    s.cooling(444995, 20)
    M.expect(a, s, 264, RESTO, 61295, nil, 'Riptide')
    s.cooling(61295, 5)
    M.expect(a, s, 264, RESTO, 1064, nil, 'grouped: Chain Heal')
    s.group = false
    M.expect(a, s, 264, RESTO, 77472, nil, 'solo: Healing Wave')
    s.friendly = false
    s.exists = false
    local r = M.expect(a, s, 264, RESTO, nil, 'stopped', 'no target')
    assert(r.suppressAttack)
    s.exists = true
    s.hostile = true
    M.expect(a, s, 264, RESTO, 470411, nil, 'enemy: Flame Shock')
    s.debuff('target', 188389)
    M.expect(a, s, 264, RESTO, 51505, nil, 'Lava Burst')
    s.learn(52127, 974, 378081, 108280, 98008)
    s.combat = false
    s.hostile = false
    s.friendly = true
    s.clearAuras()
    local lit = M.upkeep(a, s, 264, RESTO)
    assert(lit[52127] and lit[974], 'Water Shield and Earth Shield on the friend')
    s.buff('target', 974)
    lit = M.upkeep(a, s, 264, RESTO)
    assert(not lit[974], 'your Earth Shield is on the target')
    s.combat = true
    lit = M.upkeep(a, s, 264, RESTO)
    assert(lit[378081] and not lit[108280], 'Nature\'s Swiftness; group cooldowns wait')
    s.group = true
    lit = M.upkeep(a, s, 264, RESTO)
    assert(lit[108280] and lit[98008], 'grouped: Healing Tide and Spirit Link')
end)

test(
    'on the real restricted Retail client every Shaman premade is complete and the recommended premade auto-selects',
    function()
        M.checkRestricted('shaman', SPECS, { 51505, 17364, 61295 })
    end
)

test(
    'before a specialization (initial spec 1444) a level-4 Shaman gets the Blizzard Assisted premade, complete',
    function()
        M.initial('shaman', 1444, 'rm.retail.shaman.initial', { 188196 })
    end
)

finish()
