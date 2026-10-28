-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail Demon Hunter premades: per-spec storage, auto-select, the Blizzard Assisted step, the
-- reference priorities, Stops and reminders through the real catalog, predicates, composition and
-- sequence executor on a modeled Retail client (probe policy; the last test keeps the real
-- restricted policy). C_AssistedCombat is a model of Blizzard's documented API.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local M = dofile('tests/fixtures/retail_premade_model_a.lua')
local HAVOC, VENGEANCE, DEVOURER = 577, 581, 1480
local P = 'rm.retail.demonhunter.'

local ids = {
    [HAVOC] = { P .. 'havoc', P .. 'havoc.guide' },
    [VENGEANCE] = { P .. 'vengeance', P .. 'vengeance.guide', P .. 'vengeance.simc' },
    [DEVOURER] = { P .. 'devourer', P .. 'devourer.guide', P .. 'devourer.simc' },
}

local function dh(spec, level)
    local f, s = M.new('demon-hunter', 'DEMONHUNTER', spec)
    local a = f.addon
    s.setLevel(level or 90)
    s.powerType = 17
    s.energy = 50
    s.ranged(183752, 185123, 204157, 473728, 473662, 1217610, 1226019, 1245453, 1246167, 1245412, 1221150, 370965)
    return a, s, f
end

local function enable(a, id)
    assert(a:SetDefaultRotationEnabled(id, true))
end

test('every Demon Hunter premade loads for its own specialization only and declares Retail', function()
    for spec, list in pairs(ids) do
        local a = dh(spec)
        local rows = M.rows(a)

        for index, id in ipairs(list) do
            local row = assert(rows[id], id)
            local scope = row.applicability

            assert(
                row.readOnly
                    and row.builtin
                    and #scope.families == 1
                    and scope.families[1] == 'retail'
                    and scope.class == 'DEMONHUNTER',
                id
            )

            assert(
                scope.specs == nil and scope.minLevel == nil and scope.maxLevel == nil,
                id .. ' scope: load-time facts only'
            )

            assert(
                row.envelope.body.switch == nil
                    and #row.envelope.body.specs == 1
                    and row.envelope.body.specs[1] == spec,
                id .. ' specs'
            )

            assert(row.eligible == (index == 1), id .. ' eligibility: only the Assisted premade is on by default')
        end

        for other, list2 in pairs(ids) do
            if other ~= spec then
                for _, id in ipairs(list2) do
                    assert(rows[id] == nil or not rows[id].eligible, id .. ' eligible in spec ' .. spec)
                end
            end
        end
    end
end)

test(
    'auto-select: the Blizzard Assisted premade in each spec slot; an enabled reference runs but never outranks it',
    function()
        for spec, list in pairs(ids) do
            local a = dh(spec)
            assert(M.selected(a) == list[1], 'spec ' .. spec .. ': ' .. tostring(M.selected(a)))

            for _, id in ipairs(list) do
                assert(M.switch(a, id) == 'match', id .. ' switch')
            end

            for i = 2, #list do
                enable(a, list[i])
                assert(M.rows(a)[list[i]].eligible, list[i] .. ' enabled but not runnable')
            end

            assert(M.selected(a) == list[1], 'a reference outranked the recommended premade')
            local low = dh(spec, 8)
            assert(M.selected(low) == list[1], 'a Demon Hunter starts at 8 with a specialization: its premade')
        end
    end
)

test(
    'Assisted: follows the suggestion every poll, falls through when there is none, waits on casts and channels',
    function()
        for spec, list in pairs(ids) do
            local a, s = dh(spec)
            s.learn(162794, 188499, 263642, 228477, 473662, 473728)

            local first, second =
                ({
                    [HAVOC] = { 162794, 188499 },
                    [VENGEANCE] = { 263642, 228477 },
                    [DEVOURER] = { 473662, 473728 },
                })[spec][1],
                ({
                    [HAVOC] = { 162794, 188499 },
                    [VENGEANCE] = { 263642, 228477 },
                    [DEVOURER] = { 473662, 473728 },
                })[spec][2]

            s.suggest = first
            M.expect(a, s, list[1], first, nil, 'first suggestion')
            assert(s.assistedCheck == false, 'suggestion not read with checkForVisibleButton=false')
            s.suggest = second
            M.expect(a, s, list[1], second, nil, 'a new suggestion is followed')
            s.suggest = nil
            M.expect(a, s, list[1], nil, nil, 'nothing suggested')
            s.suggest = 12345
            M.expect(a, s, list[1], nil, nil, 'an unknown suggestion is skipped')
            s.suggest = first
            s.cast = true
            M.expect(a, s, list[1], nil, 'stopped', 'casting')
            s.cast = false
            s.channel = true
            M.expect(a, s, list[1], nil, 'stopped', 'channelling (Eye Beam, Fel Devastation, Void Ray)')
            s.channel = false
            s.cooling(first, 5)
            M.expect(a, s, list[1], nil, nil, 'a cooling suggestion is not recommended')
            s.cooldown = {}
            s.assisted = false
            M.expect(a, s, list[1], nil, nil, 'Assisted Combat unavailable for this spec')
        end
    end
)

test('Assisted reminders: what the assistant leaves out, per spec, lit by readiness in Midnight combat', function()
    local a, s = dh(HAVOC)
    s.learn(191427, 370965, 198793, 183752, 198589)
    s.secrets()
    s.suggest = 162794
    s.learn(162794)
    M.expect(a, s, P .. 'havoc', 162794, nil, 'suggestion with secret data')
    s.health.player = 20
    s.targetCast = true
    local lit = M.upkeep(a, s, P .. 'havoc')
    assert(lit[191427] and lit[370965], 'Metamorphosis and The Hunt did not light on the readable cooldown flags')
    assert(not lit[198793], 'Vengeful Retreat without Inertia or Exergy')
    assert(lit[198589], 'Blur did not light on the readable cooldown flag')
    assert(not lit[183752], 'a reminder gated on hidden enemy casts lit')
    s.learn(427640)
    lit = M.upkeep(a, s, P .. 'havoc')
    assert(lit[198793], 'Vengeful Retreat with Inertia')
    s.secrets(false)
    lit = M.upkeep(a, s, P .. 'havoc')
    assert(lit[183752] and lit[198589], 'Disrupt and Blur did not light where readable')
    s.cooling(191427, 60)
    lit = M.upkeep(a, s, P .. 'havoc')
    assert(not lit[191427], 'a cooling reminder lit')
    s.combat = false
    lit = M.upkeep(a, s, P .. 'havoc')
    assert(not lit[370965] and not lit[198589], 'combat reminders lit out of combat')
    a, s = dh(VENGEANCE)
    s.learn(203720, 204021, 212084, 187827)
    s.secrets()
    lit = M.upkeep(a, s, P .. 'vengeance')
    assert(lit[203720] and lit[204021] and lit[212084] and lit[187827], 'Vengeance mitigation reminders')
    a, s = dh(DEVOURER)
    s.learn(1217605, 1246167, 1245412)
    s.secrets()
    lit = M.upkeep(a, s, P .. 'devourer')
    assert(lit[1217605] and lit[1246167] and lit[1245412], 'Devourer cooldown reminders')
end)

test(
    'Havoc reference: Aldrachi glaive cycle, Fel-Scarred Metamorphosis, Essence Break window, Eye Beam, fillers',
    function()
        local a, s = dh(HAVOC)
        local G = P .. 'havoc.guide'
        enable(a, G)
        s.learn(162794, 188499, 198013, 258860, 258920, 232893, 185123, 195072)
        s.charges[258920] = { current = 1, max = 2 }
        M.expect(a, s, G, 198013, nil, 'Eye Beam first when nothing is up')
        s.cooling(198013, 20)
        M.expect(a, s, G, 258860, nil, 'Essence Break with Eye Beam over 4 s away')
        s.cooling(258860, 30)
        M.expect(a, s, G, 188499, nil, 'Blade Dance')
        s.cooling(188499, 10)
        M.expect(a, s, G, 162794, nil, 'Chaos Strike')
        s.usable[162794] = false
        M.expect(a, s, G, 232893, nil, 'Felblade under 100 Fury')
        s.usable[162794] = nil
        s.cooldown = {}
        s.charges[258920] = { current = 2, max = 2 }
        M.expect(a, s, G, 258920, nil, 'Immolation Aura at two charges')
        s.charges[258920] = { current = 1, max = 2 }
        s.debuff('target', 320338)
        s.cooling(198013, 20)
        M.expect(a, s, G, 188499, nil, 'Essence Break window: Blade Dance')
        s.cooling(188499, 10)
        M.expect(a, s, G, 162794, nil, 'Essence Break window: Chaos Strike')
        s.clearAuras()
        s.cooldown = {}
        s.learn(442294)
        s.buff('player', 444686)
        M.expect(a, s, G, 185123, nil, 'Aldrachi: Reaver\'s Glaive')
        s.buff('player', 442442)
        M.expect(a, s, G, 162794, nil, 'Aldrachi: Chaos Strike on Rending Strike')
        s.clearAuras()
        s.known[442294] = nil
        s.buff('player', 162264)
        M.expect(a, s, G, 258860, nil, 'Fel-Scarred: Essence Break in Metamorphosis')
        s.cooling(258860, 30)
        M.expect(a, s, G, 188499, nil, 'Fel-Scarred: Blade Dance in Metamorphosis')
        s.clearAuras()
        s.cooldown = {}
        s.near(2)
        s.cooling(198013, 20)
        s.cooling(258860, 30)
        s.cooling(188499, 10)
        M.expect(a, s, G, 258920, nil, 'Immolation Aura on two enemies')
        s.near(0)
        s.learn(191427)
        local lit = M.upkeep(a, s, G)
        assert(lit[191427], 'Metamorphosis once Eye Beam and Blade Dance are spent')
        s.cooldown = {}
        lit = M.upkeep(a, s, G)
        assert(not lit[191427], 'Metamorphosis while Eye Beam is ready')
    end
)

test('Vengeance reference: Aldrachi cycle, Fracture charges, Spirit Bomb on packs, Fury spending', function()
    local a, s = dh(VENGEANCE)
    local G = P .. 'vengeance.guide'
    enable(a, G)
    s.learn(263642, 247454, 258920, 204596, 228477, 212084, 232893, 204157)
    s.charges[263642] = { current = 1, max = 2 }
    M.expect(a, s, G, 258920, nil, 'Immolation Aura')
    s.cooling(258920, 20)
    M.expect(a, s, G, 204596, nil, 'Sigil of Flame')
    s.cooling(204596, 20)
    M.expect(a, s, G, 228477, nil, 'Soul Cleave against one target')
    s.near(3)
    s.energy = 60
    M.expect(a, s, G, 247454, nil, 'Spirit Bomb on three enemies')
    s.cooling(247454, 20)
    M.expect(a, s, G, 212084, nil, 'Fel Devastation at 50 Fury')
    s.near(0)
    s.charges[263642] = { current = 2, max = 2 }
    M.expect(a, s, G, 263642, nil, 'Fracture at full charges')
    s.charges[263642] = { current = 1, max = 2 }
    s.cooldown = {}
    s.learn(442294)
    s.buff('player', 444764)
    M.expect(a, s, G, 204157, nil, 'Aldrachi: Reaver\'s Glaive')
    s.clearAuras()
    s.buff('player', 442442)
    M.expect(a, s, G, 263642, nil, 'Aldrachi: Fracture on Rending Strike')
    s.clearAuras()
    s.buff('player', 442435)
    M.expect(a, s, G, 228477, nil, 'Aldrachi: Soul Cleave on Glaive Flurry')
    s.clearAuras()
    s.usable[228477] = false
    s.cooling(258920, 20)
    s.cooling(204596, 20)
    s.energy = 90
    M.expect(a, s, G, 212084, nil, 'no Soul Cleave: Fel Devastation')
    s.cooling(212084, 30)
    M.expect(a, s, G, 263642, nil, 'Fury is secret: Fracture does not wait for room')
    s.charges[263642] = { current = 0, max = 2 }
    s.cooling(263642, 5)
    s.cooling(232893, 5)
    M.expect(a, s, G, 204157, nil, 'Throw Glaive last')
    s.learn(203720)
    local lit = M.upkeep(a, s, G)
    assert(lit[203720], 'Demon Spikes when down')
    s.buff('player', 203819)
    lit = M.upkeep(a, s, G)
    assert(not lit[203720], 'Demon Spikes already up')
end)

test('Vengeance SimulationCraft reference: Aldrachi sigils first, no Fury thresholds, Annihilator Voidfall', function()
    local a, s = dh(VENGEANCE)
    local G = P .. 'vengeance.simc'
    enable(a, G)
    s.learn(263642, 247454, 258920, 204596, 228477, 212084, 232893, 204157, 187827, 204021, 390163, 207407, 442294)
    s.charges[263642] = { current = 1, max = 2 }
    s.charges[204021] = { current = 1, max = 2 }
    s.buff('player', 187827)
    M.expect(a, s, G, 204596, nil, 'Aldrachi: Sigil of Flame first')
    s.cooling(204596, 20)
    M.expect(a, s, G, 258920, nil, 'Aldrachi: Immolation Aura')
    s.cooling(258920, 20)
    M.expect(a, s, G, 204021, nil, 'Aldrachi: Fiery Brand without Fiery Demise')
    s.cooling(204021, 30)
    s.cooling(390163, 30)
    s.energy = 90
    M.expect(a, s, G, 263642, nil, 'Fury is secret: no Fel Devastation dump above 85')
    s.energy = 50
    M.expect(a, s, G, 263642, nil, 'Fracture filler')
    s.clearAuras()
    M.expect(a, s, G, 187827, nil, 'Metamorphosis when it is down')
    s.known[442294] = nil
    s.buff('player', 187827)
    s.cooldown = {}
    s.buff('player', 1256302)
    M.expect(a, s, G, 228477, nil, 'Annihilator: Soul Cleave spends a ready Voidfall')
    s.near(3)
    M.expect(a, s, G, 247454, nil, 'Annihilator: Spirit Bomb spends it on packs')
    s.near(0)
    s.clearAuras()
    s.buff('player', 187827)
    s.buff('player', 1256301, { applications = 2 })
    M.expect(a, s, G, 263642, nil, 'Annihilator: Fracture at two Voidfall stacks')
end)

test('Devourer references: Void Metamorphosis branch, Soulburst, Void Ray once affordable', function()
    local a, s = dh(DEVOURER)
    local G = P .. 'devourer.guide'
    enable(a, G)
    s.learn(473662, 1226019, 1241937, 1245412, 1246167, 1217605, 1239123, 473728, 1217610, 1221150, 1245453)
    M.expect(a, s, G, 1226019, nil, 'Reap')
    s.cooling(1226019, 5)
    M.expect(a, s, G, 1241937, nil, 'Soul Immolation when it is not burning')
    s.buff('player', 1241937)
    M.expect(a, s, G, 1217605, nil, 'Void Metamorphosis')
    s.cooling(1217605, 60)
    M.expect(a, s, G, 1239123, nil, 'Hungering Slash')
    s.cooling(1239123, 10)
    s.power[473728] = true
    M.expect(a, s, G, 473662, nil, 'Consume while Void Ray is unaffordable')
    s.power[473728] = nil
    M.expect(a, s, G, 473728, nil, 'Void Ray once affordable')
    s.buff('player', 1225789, { applications = 50 })
    s.cooldown = {}
    s.cooling(1226019, 5)
    M.expect(a, s, G, 1245412, nil, 'Voidblade once Void Metamorphosis is ready')
    s.clearAuras()
    s.buff('player', 1297433)
    M.expect(a, s, G, 473662, nil, 'Consume on Soulburst')
    s.clearAuras()
    s.buff('player', 1217607)
    M.expect(a, s, G, 473728, nil, 'in Void Metamorphosis: Void Ray')
    s.cooling(473728, 10)
    M.expect(a, s, G, 1221150, nil, 'in Void Metamorphosis: Collapsing Star')
    s.cooling(1221150, 30)
    M.expect(a, s, G, 1245453, nil, 'in Void Metamorphosis: Cull')
    s.cooling(1245453, 5)
    M.expect(a, s, G, 1217610, nil, 'in Void Metamorphosis: Devour')
    s.buff('player', 1297433)
    s.cooldown = {}
    M.expect(a, s, G, 1217610, nil, 'Soulburst in Void Metamorphosis: Devour first')
    G = P .. 'devourer.simc'
    enable(a, G)
    s.clearAuras()
    s.cooldown = {}
    M.expect(a, s, G, 1217605, nil, 'SimC: Void Metamorphosis as soon as it is ready')
    s.cooling(1217605, 60)
    M.expect(a, s, G, 1226019, nil, 'SimC: Reap')
    s.cooling(1226019, 5)
    M.expect(a, s, G, 473728, nil, 'SimC: Void Ray outside Metamorphosis')
    s.cooling(473728, 10)
    s.near(2)
    M.expect(a, s, G, 1241937, nil, 'SimC: Soul Immolation on packs')
    s.near(0)
    s.cooldown = {}
    s.buff('player', 1217607)
    s.learn(1240201)
    M.expect(a, s, G, 1246167, nil, 'SimC: The Hunt with Devourer\'s Bite in Metamorphosis')
    s.known[1240201] = nil
    s.buff('player', 1297433)
    M.expect(a, s, G, 1217610, nil, 'SimC: Devour on Soulburst against one target')
    s.near(2)
    M.expect(a, s, G, 473728, nil, 'SimC: Void Ray first on packs')
    s.near(0)
end)

test(
    'on the real restricted Retail client every Demon Hunter premade is complete and the Assisted premade auto-selects',
    function()
        M.restricted('demon-hunter', 'DEMONHUNTER', ids)
    end
)

test(
    'before a specialization (initial spec 1456) a level-4 Demon Hunter gets the Blizzard Assisted premade, complete',
    function()
        M.initial('demon-hunter', 'DEMONHUNTER', 1456, P .. 'initial', { 162794 })
    end
)

finish()
