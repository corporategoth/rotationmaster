-- Retail Monk premades: per-spec storage, auto-select, the Blizzard Assisted step with Icy Veins'
-- brews, the reference priorities (Combo Strikes on readable cast history), Stops and reminders
-- through the real catalog, predicates, composition and sequence executor on a modeled Retail client
-- (probe policy; the last test keeps the real restricted policy).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local M = dofile('tests/fixtures/retail_premade_model_a.lua')
local BREW, WW, MW = 268, 269, 270
local P = 'rm.retail.monk.'

local ids = {
    [BREW] = { P .. 'brewmaster', P .. 'brewmaster.guide' },
    [WW] = { P .. 'windwalker', P .. 'windwalker.guide' },
    [MW] = { P .. 'mistweaver' },
}

local function monk(spec, level)
    local f, s = M.new('monk', 'MONK', spec)
    local a = f.addon
    s.setLevel(level or 90)
    s.powerType = 3
    s.energy = 50
    s.points = 2
    s.ranged(116705, 117952, 121253, 115181, 123986)
    return a, s, f
end

local function enable(a, id)
    assert(a:SetDefaultRotationEnabled(id, true))
end

test('every Monk premade loads for its own specialization only and declares Retail', function()
    for spec, list in pairs(ids) do
        local a = monk(spec)
        local rows = M.rows(a)

        for index, id in ipairs(list) do
            local row = assert(rows[id], id)
            local scope = row.applicability

            assert(
                row.readOnly
                    and row.builtin
                    and #scope.families == 1
                    and scope.families[1] == 'retail'
                    and scope.class == 'MONK',
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

            assert(
                row.eligible == (index == 1 and spec ~= MW),
                id .. ' eligibility: only the Assisted premades are on by default'
            )
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

test('auto-select: Assisted for Brewmaster and Windwalker; Mistweaver is reference only', function()
    for spec, list in pairs(ids) do
        local a = monk(spec)

        for _, id in ipairs(list) do
            assert(M.switch(a, id) == 'match', id .. ' switch')
        end

        if spec == MW then
            assert(M.selected(a) == nil, 'the Mistweaver reference auto-selected')
            enable(a, list[1])
            assert(M.rows(a)[list[1]].eligible, 'an enabled Mistweaver reference is not runnable')
        else
            assert(M.selected(a) == list[1], 'spec ' .. spec .. ': ' .. tostring(M.selected(a)))
            enable(a, list[2])
            assert(M.rows(a)[list[2]].eligible, 'an enabled reference is not runnable')
            assert(M.selected(a) == list[1], 'the reference outranked the recommended premade')
        end

        do
            local low, ls = monk(spec, 9)
            ls.respec(1450)

            assert(
                M.selected(low) == P .. 'initial',
                'below 10 the game reports the initial spec: ' .. tostring(M.selected(low))
            )
        end
    end
end)

test('Assisted: follows the suggestion, falls through when there is none, waits on casts and channels', function()
    for _, spec in ipairs({ BREW, WW }) do
        local id = ids[spec][1]
        local a, s = monk(spec)
        s.learn(100780, 100784, 113656, 121253)
        s.suggest = 100780
        M.expect(a, s, id, 100780, nil, 'suggested Tiger Palm')
        assert(s.assistedCheck == false)
        s.suggest = 100784
        M.expect(a, s, id, 100784, nil, 'a new suggestion is followed')
        s.suggest = nil
        M.expect(a, s, id, nil, nil, 'nothing suggested')
        s.suggest = 12345
        M.expect(a, s, id, nil, nil, 'an unknown suggestion is skipped')
        s.suggest = 100780
        s.cast = true
        M.expect(a, s, id, nil, 'stopped', 'casting')
        s.cast = false
        s.channel = true
        M.expect(a, s, id, nil, 'stopped', 'channelling Fists of Fury')
        s.channel = false
        s.cooling(100780, 5)
        M.expect(a, s, id, nil, nil, 'a cooling suggestion is not recommended')
        s.cooldown = {}
        s.assisted = false
        M.expect(a, s, id, nil, nil, 'Assisted Combat unavailable')
    end
end)

test('Brewmaster Assisted in Midnight combat: the suggestion and the brews run on readable cooldown flags', function()
    local a, s = monk(BREW)
    local id = P .. 'brewmaster'
    s.learn(121253, 115399, 132578, 119582, 322507, 322109, 116705, 115203, 26297)
    s.secrets()
    s.suggest = 121253
    M.expect(a, s, id, 121253, nil, 'suggestion with secret data')
    s.cooling(121253, 6)
    M.expect(a, s, id, nil, nil, 'cooling by the never-secret flag')
    s.cooldown = {}
    s.health.player = 20
    s.targetCast = true
    local lit = M.upkeep(a, s, id)

    for _, brew in ipairs({ 115399, 132578, 119582, 322507, 322109, 26297 }) do
        assert(lit[brew], brew .. ' did not light in combat')
    end

    assert(lit[115203], 'Fortifying Brew did not light on the readable cooldown flag')
    assert(not lit[116705], 'a reminder gated on hidden enemy casts lit')
    s.secrets(false)
    lit = M.upkeep(a, s, id)
    assert(lit[115203] and lit[116705], 'Fortifying Brew and Spear Hand Strike where readable')
    s.cooling(119582, 10)
    lit = M.upkeep(a, s, id)
    assert(not lit[119582], 'a cooling brew lit')
    s.combat = false
    lit = M.upkeep(a, s, id)
    assert(not lit[115399] and not lit[322109], 'brews lit out of combat')
end)

test(
    'Windwalker Assisted: Invoke Xuen and Touch of Karma in combat; Chi and cast history stay readable when secret',
    function()
        local a, s = monk(WW)
        local id = P .. 'windwalker'
        s.learn(123904, 122470, 100780)
        local lit = M.upkeep(a, s, id)
        assert(lit[123904] and lit[122470])
        s.learn(1249625, 443028)
        lit = M.upkeep(a, s, id)
        assert(lit[1249625] and lit[443028], 'Zenith and Celestial Conduit, outside Assisted Combat')
        s.secrets()
        s.suggest = 100780
        M.expect(a, s, id, 100780, nil, 'suggestion in Midnight combat')

        local status = a:evaluateConditionResult({
            type = 'POINT',
            unit = 'player',
            operator = 'EQUALS',
            value = 2,
        }).status

        assert(status == 'match', 'Chi unreadable with secrets: ' .. status)
        s.history(100780)

        status = a:evaluateConditionResult({
            type = 'SPELL_HISTORY',
            spell = 100780,
            operator = 'EQUALS',
            value = 1,
        }).status

        assert(status == 'match', 'own cast history unreadable with secrets: ' .. status)
    end
)

test(
    'Brewmaster reference: pull, Blackout Kick, Blackout Combo, Keg Smash charges, Breath of Fire, kegs, packs, filler',
    function()
        local a, s = monk(BREW)
        local G = P .. 'brewmaster.guide'
        enable(a, G)
        s.learn(121253, 205523, 100780, 115181, 325153, 116847, 123986, 101546, 322101)
        s.combat = false
        M.expect(a, s, G, 121253, nil, 'pull: Keg Smash')
        s.combat = true
        M.expect(a, s, G, 205523, nil, 'Blackout Kick (the Brewmaster spell) first')
        s.cooling(205523, 3)
        M.expect(a, s, G, 115181, nil, 'Breath of Fire before Keg Smash at one charge')
        s.charges[121253] = { current = 2, max = 2 }
        M.expect(a, s, G, 121253, nil, 'Keg Smash at full charges')
        s.charges[121253] = { current = 1, max = 2 }
        s.buff('player', 1265307)
        M.expect(a, s, G, 121253, nil, 'Keg Smash with Empty Barrel')
        s.clearAuras()
        s.buff('player', 228563)
        M.expect(a, s, G, 100780, nil, 'Tiger Palm spends Blackout Combo')
        s.clearAuras()
        s.cooling(115181, 10)
        M.expect(a, s, G, 116847, nil, 'Rushing Jade Wind before Exploding Keg')
        s.cooling(116847, 5)
        M.expect(a, s, G, 325153, nil, 'Exploding Keg')
        s.cooling(325153, 40)
        M.expect(a, s, G, 123986, nil, 'Shado-Pan: Chi Burst after the kegs')
        s.buff('player', 228563)
        M.expect(a, s, G, 100780, nil, 'Shado-Pan: Blackout Combo above Chi Burst')
        s.learn(1262765)
        M.expect(a, s, G, 123986, nil, 'Master of Harmony: Chi Burst above Blackout Combo')
        s.clearAuras()
        s.cooling(123986, 20)
        s.cooling(121253, 5)
        M.expect(a, s, G, 100780, nil, 'Tiger Palm filler on one target')
        s.near(3)
        M.expect(a, s, G, 101546, nil, 'three enemies: Spinning Crane Kick (Jade Wind cooling)')
        s.near(0)
        s.usable[100780] = false
        M.expect(a, s, G, 322101, nil, 'Expel Harm last')
        local lit = M.upkeep(a, s, G)
        s.learn(115399, 119582, 322507)
        s.charges[119582] = { current = 0, max = 2 }
        s.cooling(322507, 60)
        lit = M.upkeep(a, s, G)
        assert(lit[115399], 'Black Ox Brew when the brews are spent')
        s.charges[119582] = { current = 1, max = 2 }
        s.cooldown[322507] = nil
        lit = M.upkeep(a, s, G)
        assert(not lit[115399] and lit[119582] and lit[322507], 'Black Ox Brew waits for the brews')
    end
)

test('Windwalker reference: Combo Strikes, Chi gates, Heart of the Jade Serpent, Zenith and procs', function()
    local a, s = monk(WW)
    local G = P .. 'windwalker.guide'
    enable(a, G)
    s.learn(113656, 152175, 392983, 107428, 100784, 100780, 101546, 443028, 467307)
    s.usable[152175] = false  -- Whirling Dragon Punch needs Fists of Fury and Rising Sun Kick cooling
    s.points = 4
    M.expect(a, s, G, 443028, nil, 'Celestial Conduit without Heart')
    s.cooling(443028, 60)
    M.expect(a, s, G, 113656, nil, 'Fists of Fury')
    s.history(113656)
    s.cooling(113656, 20)
    M.expect(a, s, G, 392983, nil, 'Strike of the Windlord (Dragon Punch not usable)')
    s.cooling(392983, 30)
    M.expect(a, s, G, 467307, nil, 'Rushing Wind Kick')
    s.cooling(467307, 8)
    M.expect(a, s, G, 107428, nil, 'Rising Sun Kick')
    s.history(107428)
    s.cooling(107428, 8)
    M.expect(a, s, G, 100784, nil, 'Blackout Kick filler')
    s.history(100784)
    s.points = 3
    M.expect(a, s, G, 100780, nil, 'Combo Strikes: not Blackout Kick twice; Tiger Palm below four Chi')
    s.points = 1
    s.history(100780)
    M.expect(a, s, G, 100784, nil, 'short on Chi after Tiger Palm: Blackout Kick, never Tiger Palm twice')
    s.points = 4
    s.cooldown = {}
    s.usable[152175] = nil
    s.history(1)
    M.expect(a, s, G, 152175, nil, 'Whirling Dragon Punch on top without Xuen known')
    s.learn(123904)
    s.cooling(123904, 5)
    M.expect(a, s, G, 443028, nil, 'grace-window Dragon Punch waits with Xuen near')
    s.cooling(123904, 60)
    M.expect(a, s, G, 152175, nil, 'Dragon Punch with Xuen far off')
    s.history(152175)
    s.buff('player', 443421, { expirationTime = 100.5 })
    M.expect(a, s, G, 113656, nil, 'Fists of Fury as Heart of the Jade Serpent ends')
    s.clearAuras()
    s.cooldown = {}
    s.cooling(152175, 30)
    s.cooling(443028, 60)
    s.cooling(123904, 60)
    s.points = 1
    s.energy = 90
    M.expect(a, s, G, 113656, nil, 'energy is secret: no Tiger Palm before the cap')
    s.learn(1272696)
    M.expect(a, s, G, 1272696, nil, 'Zenith Stomp when low on Chi')
end)

test('Mistweaver reference: fistweaving on a hostile target, nothing otherwise', function()
    local a, s = monk(MW)
    local G = P .. 'mistweaver'
    enable(a, G)
    s.learn(107428, 100784, 100780)
    M.expect(a, s, G, 107428, nil, 'Rising Sun Kick')
    s.cooling(107428, 8)
    M.expect(a, s, G, 100784, nil, 'Blackout Kick')
    s.cooling(100784, 3)
    M.expect(a, s, G, 100780, nil, 'Tiger Palm')
    s.hostile = false
    s.friendly = true
    M.expect(a, s, G, nil, 'stopped', 'friendly target: no advice')
end)

test(
    'on the real restricted Retail client every Monk premade is complete and the recommended premade auto-selects',
    function()
        M.restricted('monk', 'MONK', ids, { [270] = false })
    end
)

test(
    'before a specialization (initial spec 1450) a level-4 Monk gets the Blizzard Assisted premade, complete',
    function()
        M.initial('monk', 'MONK', 1450, P .. 'initial', { 100780 })
    end
)

finish()
