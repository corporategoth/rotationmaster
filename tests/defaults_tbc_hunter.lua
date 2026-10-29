-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Hunter premades: ranged DPS (simulator recommended, Wowhead). Real predicates, catalog,
-- composition, sequence and publisher; WoW observations are modeled in
-- tests/fixtures/tbc_physical_premades.lua.
local M = dofile('tests/fixtures/tbc_physical_premades.lua')
local test, finish = M.F.suite()
local HS, HW = 'rm.tbc.hunter.ranged.simulator', 'rm.tbc.hunter.ranged.wowhead'
local mid = { 13165, 883, 982, 136, 2643, 3045, 1130, 1495 }
local late = { 34120, 34074, 34026 }

local function hunter(level, ...)
    local f, s = M.fixture('HUNTER', { level = level })
    M.know(s, 75, 6603, 2973, 1978, 3044)

    for _, set in ipairs({ ... }) do
        M.know(s, unpack(set))
    end

    s.range[6603] = false
    s.autorepeat = true
    s.usable[1495] = false
    s.usable[19306] = false
    s.debuffs = { { id = 1130, source = 'party1' } }
    return f, s
end

local function first(f, s, id)
    return (M.first(f, s, id))
end

local function both(f, s, g, t, a, b)
    local x, y = first(f, s, HS), first(g, t, HW)
    local want = b

    if b == nil then
        want = a
    elseif b == false then
        want = nil
    end

    assert(x == a and y == want, 'simulator ' .. tostring(x) .. ' wowhead ' .. tostring(y))
end

local function each(s, t, fn)
    fn(s)
    fn(t)
end

local function cd(s, id)
    s.cooldown[id] = { startTime = 95, duration = 10, isEnabled = true, modRate = 1 }
end

test(
    'both premades register valid 1–70, share the switch, the simulator premade auto-selects and the Wowhead one ships disabled',
    function()
        local f, s = hunter(1)
        local a = f.addon

        for _, level in ipairs({ 1, 30, 70 }) do
            s.level = level
            a.longtermCache = {}

            for _, r in ipairs(a:ListDefaultRotations(0)) do
                assert(r.eligible == (r.id ~= HW), r.id .. ' at ' .. level)
            end

            assert(M.switches(f, HS) and M.switches(f, HW))
        end

        for _, src in ipairs(a:GetDefaultRotation(HW).envelope.sources) do
            assert(src.url:find('wowhead%.com'), src.url)
        end

        for _, src in ipairs(a:GetDefaultRotation(HS).envelope.sources) do
            assert(not src.url:find('wowhead'), src.url)
        end

        local poll, selected = M.publisher(f, s)
        s.autorepeat = false
        poll()
        assert(selected() == HS and f.addon.currentSpell == 75)
        assert(a:SetDefaultRotationEnabled(HS, false))
        poll()
        assert(selected() ~= HW, 'the disabled Wowhead premade was chosen')
        assert(a:SetDefaultRotationEnabled(HW, true))
        poll()
        assert(selected() == HW)
    end
)

test(
    'casts and channels stop with Attack suppressed; no target stops; melee range uses melee strikes then white hits',
    function()
        for _, id in ipairs({ HS, HW }) do
            local f, s = hunter(20, mid)
            s.cast = true
            local x, r = M.first(f, s, id)
            assert(not x and r.status == 'stopped' and r.suppressAttack)
            s.cast = false
            s.channel = true
            x, r = M.first(f, s, id)
            assert(not x and r.suppressAttack)
            s.channel = false
            s.exists = false
            x, r = M.first(f, s, id)
            assert(not x and r.suppressAttack)
            s.exists = true
            s.range[6603] = true
            assert(first(f, s, id) == 2973)
            s.active[2973] = true
            s.usable[1495] = true
            assert(first(f, s, id) == 1495)
            s.usable[1495] = false
            x, r = M.first(f, s, id)
            assert(not x and r.status == 'stopped' and not r.suppressAttack, 'white hits continue')
        end
    end
)

test('pull: Hunter\'s Mark nobody placed, pre-pull Aimed Shot while standing, Auto Shot, then wait', function()
    for _, id in ipairs({ HS, HW }) do
        local f, s = hunter(40, mid, { 19434 })
        s.combat = false
        s.autorepeat = false
        s.debuffs = {}
        assert(first(f, s, id) == 1130)
        s.debuffs = { { id = 1130, source = 'party1' } }
        assert(first(f, s, id) == 19434)
        s.moving = true
        assert(first(f, s, id) == 75)
        s.autorepeat = true
        local x, r = M.first(f, s, id)
        assert(not x and r.status == 'stopped' and r.suppressAttack)
    end
end)

test(
    'before Steady Shot: Auto Shot restart, Mark, own Serpent Sting, then mana-gated shots; identical in both',
    function()
        local f, s = hunter(30, mid, { 19434 })
        local g, t = hunter(30, mid, { 19434 })

        each(s, t, function(x)
            x.autorepeat = false
        end)

        both(f, s, g, t, 75)

        each(s, t, function(x)
            x.autorepeat = true
            x.debuffs = {}
        end)

        both(f, s, g, t, 1130)

        each(s, t, function(x)
            x.debuffs = { { id = 1130 } }
        end)

        both(f, s, g, t, 1978)

        each(s, t, function(x)
            x.debuffs[2] = { id = 1978, source = 'party1' }
        end)

        both(f, s, g, t, 1978)

        each(s, t, function(x)
            x.debuffs[2] = { id = 3043 }
        end)

        both(f, s, g, t, 19434, 19434)

        each(s, t, function(x)
            x.mana = 45
        end)

        both(f, s, g, t, 2643)

        each(s, t, function(x)
            x.mana = 35
        end)

        local x, r = M.first(f, s, HS)
        assert(not x and r.status == 'stopped' and r.suppressAttack, 'low mana: let Auto Shot and the pet work')

        each(s, t, function(x)
            x.mana = 100
            x.debuffs[2] = nil
            x.targetHealth = 20
        end)

        both(f, s, g, t, 19434)
        M.know(s, 13552)
        s.mana = 100
        s.targetHealth = 100
        assert(first(f, s, HS) == 13552, 'highest learned Sting rank')
    end
)

test('moving: instant shots only; simulator keeps Serpent Sting, Wowhead does not', function()
    local f, s = hunter(40, mid)
    local g, t = hunter(40, mid)

    each(s, t, function(x)
        x.moving = true
    end)

    both(f, s, g, t, 2643)

    each(s, t, function(x)
        cd(x, 2643)
    end)

    both(f, s, g, t, 3044)

    each(s, t, function(x)
        cd(x, 3044)
    end)

    both(f, s, g, t, 1978, false)
end)

test(
    'from Steady Shot: Multi-Shot, Steady after Auto Shot; the gap is Arcane and solo Sting for simulator, waiting for Wowhead',
    function()
        local f, s = hunter(70, mid, late)
        local g, t = hunter(70, mid, late)
        both(f, s, g, t, 2643)

        each(s, t, function(x)
            cd(x, 2643)
            x.sinceAuto = .2
        end)

        both(f, s, g, t, 34120)

        each(s, t, function(x)
            x.sinceAuto = 1
        end)

        both(f, s, g, t, 3044, false)

        each(s, t, function(x)
            x.mana = 40
        end)

        both(f, s, g, t, 1978, false)
        s.group = true
        local x, r = M.first(f, s, HS)
        assert(not x and r.status == 'stopped' and r.suppressAttack, 'no Sting in a group')

        each(s, t, function(x)
            x.sinceAuto = nil
        end)

        both(f, s, g, t, nil)
    end
)

test(
    'aspects: simulator Viper below 20% in combat and Hawk again at 50%; Wowhead Hawk only; travel aspects respected out of combat',
    function()
        local f, s = hunter(70, mid, late)
        local g, t = hunter(70, mid, late)
        assert(M.upkeep(f, s, HS)['hunter-hawk'] == 13165 and M.upkeep(g, t, HW)['hunter-hawk'] == 13165)

        each(s, t, function(x)
            x.buffs = { { id = 13165 } }
            x.mana = 15
        end)

        assert(M.upkeep(f, s, HS)['hunter-viper'] == 34074 and M.upkeep(g, t, HW)['hunter-viper'] == nil)

        each(s, t, function(x)
            x.buffs = { { id = 34074 } }
            x.mana = 40
        end)

        assert(not M.upkeep(f, s, HS)['hunter-hawk'] and M.upkeep(g, t, HW)['hunter-hawk'])
        s.mana = 50
        assert(M.upkeep(f, s, HS)['hunter-hawk'])
        s.mana = 10
        s.combat = false
        assert(not M.upkeep(f, s, HS)['hunter-viper'], 'Viper only in combat')

        each(s, t, function(x)
            x.buffs = { { id = 5118 } }
            x.combat = false
            x.mana = 100
        end)

        assert(not M.upkeep(f, s, HS)['hunter-hawk'] and not M.upkeep(g, t, HW)['hunter-hawk'])

        each(s, t, function(x)
            x.combat = true
        end)

        assert(M.upkeep(f, s, HS)['hunter-hawk'] and M.upkeep(g, t, HW)['hunter-hawk'], 'dazed in combat: Hawk')
        local h, u = hunter(6, { 13163 })
        assert(M.upkeep(h, u, HS)['hunter-monkey'] == 13163)
        u.buffs = { { id = 13163 } }
        assert(not M.upkeep(h, u, HS)['hunter-monkey'])
        u.buffs = {}
        M.know(u, 13165)
        assert(not M.upkeep(h, u, HS)['hunter-monkey'] and M.upkeep(h, u, HS)['hunter-hawk'])
    end
)

test('pet care, Kill Command, cooldowns on elites and bosses, Silencing Shot', function()
    for _, id in ipairs({ HS, HW }) do
        local f, s = hunter(70, mid, late, { 19574, 23989, 34490, 19506 })
        s.buffs = { { id = 13165 }, { id = 19506 } }
        local u = M.upkeep(f, s, id)
        assert(u['hunter-call-pet'] == 883 and not u['hunter-revive-pet'] and not u['hunter-mend-pet'])
        s.pet = true
        s.petDead = true
        u = M.upkeep(f, s, id)
        assert(not u['hunter-call-pet'] and u['hunter-revive-pet'] == 982)
        s.petDead = false
        s.petHealth = 40
        assert(M.upkeep(f, s, id)['hunter-mend-pet'] == 136)
        s.petBuffs = { { id = 136 } }
        assert(not M.upkeep(f, s, id)['hunter-mend-pet'])
        u = M.upkeep(f, s, id)
        assert(u['hunter-kill-command'] == 34026 and not u['hunter-rapid-fire'] and not u['hunter-bestial-wrath'])
        s.classification = 'elite'
        u = M.upkeep(f, s, id)
        assert(u['hunter-rapid-fire'] == 3045 and u['hunter-bestial-wrath'] == 19574 and not u['hunter-readiness'])
        s.cooldown[3045] = { startTime = 90, duration = 300, isEnabled = true, modRate = 1 }
        assert(M.upkeep(f, s, id)['hunter-readiness'] == 23989)
        s.targetCast = 'Fear'
        assert(M.upkeep(f, s, id)['hunter-silencing-shot'] == 34490)
        assert(not M.upkeep(f, s, id)['hunter-trueshot-aura'])
    end
end)

test('single target vs packs: three enemies fighting you make Multi-Shot ignore the mana gate in both', function()
    local f, s = hunter(30, mid)
    local g, t = hunter(30, mid)

    each(s, t, function(x)
        x.debuffs[2] = { id = 1978 }
        x.mana = 30
    end)

    both(f, s, g, t, nil)

    each(s, t, function(x)
        x.enemies = { 1, 0, false }
    end)

    both(f, s, g, t, nil)

    each(s, t, function(x)
        x.enemies = { 1, 0, 0 }
    end)

    both(f, s, g, t, 2643)

    each(s, t, function(x)
        cd(x, 2643)
    end)

    both(f, s, g, t, nil)
end)

test('real publisher follows Auto Shot timing', function()
    local f, s = hunter(70, mid, late)
    local poll, selected, glow = M.publisher(f, s)
    cd(s, 2643)
    s.sinceAuto = .2
    poll()
    assert(selected() == HS and f.addon.currentSpell == 34120)
    s.sinceAuto = 1
    poll()
    assert(f.addon.currentSpell == 3044)
    assert(#glow > 0)
end)

finish()
