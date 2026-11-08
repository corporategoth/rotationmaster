-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- addon.Metrics: how advice, casts and fights become adherence, delay, deviation and output figures; the caps that bound
-- the saved table; the report and its JSON and model-prompt forms. Pure Lua: no client, no events (the event wiring is
-- tests/metrics_events.lua).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fresh()
    local f = F.new(5, 1, 'MAGE')
    f.addon.db = { global = {}, profile = {} }
    f.load('Analytics/metrics.lua')
    return f.addon.Metrics, f
end

local FIREBALL, FROSTBOLT, ARCANE, BLINK, POLY = 133, 116, 5143, 1953, 118

-- One fight: advice appears, the player casts, the fight lasts `length` seconds.
local function fight(m, rotation, steps, length)
    m:FightStart(100)

    for _, step in ipairs(steps) do
        if step.advice ~= nil then
            m:Advice(rotation, step.advice or nil, step.at)
        end
        if step.cast then
            m:Cast(step.cast, step.at)
        end
    end

    return m:FightEnd(100 + (length or 30))
end

test('following the advice records how long after it appeared the spell was pressed', function()
    local m = fresh()

    assert(fight(m, 'rot', {
        { advice = FIREBALL, at = 101 },
        { cast = FIREBALL, at = 101.5 },
        { advice = FROSTBOLT, at = 103 },
        { cast = FROSTBOLT, at = 104 },
    }))

    local r = m:Report().rotations[1]
    assert(r.id == 'rot' and r.fights == 1 and r.casts == 2 and r.followed == 2 and r.followedPercent == 100)
    assert(r.meanDelay == 0.75, r.meanDelay)

    assert(
        r.delayHistogram[3] == 1 and r.delayHistogram[4] == 1,
        'a half second and a full second land in buckets 3 and 4'
    )
end)

test(
    'a cast of another spell is out of order, outside the rotation, or unadvised, and says what was replaced',
    function()
        local m = fresh()

        fight(m, 'rot', {
            { advice = FIREBALL, at = 101 },
            { cast = FROSTBOLT, at = 102 },
            { advice = FROSTBOLT, at = 102.1 },
            { cast = BLINK, at = 103 },
            { cast = FROSTBOLT, at = 104 },
            { advice = false, at = 104.1 },
            { cast = POLY, at = 105 },
            { advice = ARCANE, at = 106 },
            { cast = FIREBALL, at = 107 },
        })

        local r = m:Report().rotations[1]
        assert(r.casts == 5 and r.followed == 1 and r.unadvised == 1)
        assert(r.outside == 1, 'Blink is not in the rotation')
        assert(r.outOfOrder == 2, 'Frostbolt while Fireball was advised, and Fireball while Arcane Blast was')
        assert(r.followed + r.outOfOrder + r.outside + r.unadvised == r.casts)
        local fireball

        for _, s in ipairs(r.spells) do
            if s.spell == FIREBALL then
                fireball = s
            end
        end

        assert(fireball.replacedBy[1].spell == FROSTBOLT and fireball.replacedBy[1].count == 1)
        assert(r.outsideSpells[1].spell == BLINK)
    end
)

test('advice that was replaced before it was used counts as not acted on', function()
    local m = fresh()

    fight(m, 'rot', {
        { advice = FIREBALL, at = 101 },
        { advice = FROSTBOLT, at = 102 },
        { cast = FROSTBOLT, at = 102.5 },
    })

    local r = m:Report().rotations[1]
    assert(r.superseded == 1 and r.followed == 1)
end)

test('nothing is recorded outside a fight, and a fight that is too short or has no casts is not filed', function()
    local m = fresh()
    m:Advice('rot', FIREBALL, 1)
    m:Cast(FIREBALL, 2)
    assert(not m:HasData())

    assert(
        not fight(m, 'rot', { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } }, 5),
        'five seconds is too short'
    )

    assert(not fight(m, 'rot', { { advice = FIREBALL, at = 101 } }, 30), 'no casts')
end)

test('damage and healing per second, and output by how closely fights followed the advice', function()
    local m = fresh()

    for index = 1, 3 do
        m:FightStart(0)
        m:Advice('rot', FIREBALL, 0)

        for _ = 1, 10 do
            m:Cast(FIREBALL, 1)
        end

        m:Output(10000, 500)
        m:FightEnd(10)
    end

    for index = 1, 3 do
        m:FightStart(0)
        m:Advice('rot', FIREBALL, 0)

        for _ = 1, 10 do
            m:Cast(FROSTBOLT, 1)
        end

        m:Output(5000, 0)
        m:FightEnd(10)
    end

    local r = m:Report().rotations[1]
    assert(r.fights == 6 and r.dps == 750 and r.hps == 25, r.dps)
    assert(#r.byAdherence == 2)
    assert(r.byAdherence[1].tier == 'low' and r.byAdherence[1].dps == 500)
    assert(r.byAdherence[2].tier == 'high' and r.byAdherence[2].dps == 1000 and r.byAdherence[2].hps == 50)
end)

test('the saved table is bounded', function()
    local m, f = fresh()

    for n = 1, 30 do
        fight(m, 'rot' .. n, { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } })
    end

    local saved = f.addon.db.global.metrics

    assert(
        #saved.order == 24 and saved.rotations.rot1 == nil and saved.rotations.rot30,
        'the oldest rotations go first'
    )

    m:Clear()

    for spell = 1, 100 do
        m:FightStart(0)
        m:Advice('wide', spell, 0)
        m:Cast(spell, 1)
        m:Advice('wide', 1, 1.5)
        m:Cast(100000 + spell, 2)
        m:FightEnd(20)
    end

    local count = 0

    for _ in pairs(f.addon.db.global.metrics.rotations.wide.spells) do
        count = count + 1
    end

    assert(count == 64, count)
    local replaced = 0

    for _ in pairs(f.addon.db.global.metrics.rotations.wide.spells[1].replaced) do
        replaced = replaced + 1
    end

    assert(replaced == 8, 'one advised spell remembers at most eight replacements')

    for index = 1, 60 do
        fight(m, 'long', { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } })
    end

    assert(#f.addon.db.global.metrics.rotations.long.ring == 40)
    assert(#m:Report().rotations[1].fightList <= 40)
end)

test('the JSON export is stable, escaped and carries the client facts', function()
    local m = fresh()
    fight(m, 'rot "1"', { { advice = FIREBALL, at = 101 }, { cast = FIREBALL, at = 102 } })

    local report = m:Report(function(id)
        return 'My\nrotation'
    end, function(id)
        return 'Spell ' .. id
    end)

    local json = m:ToJSON(report, { family = 'tbc', interface = 20506 })
    assert(json:find('"format":"rm-metrics"', 1, true) and json:find('"version":1', 1, true))
    assert(json:find('"id":"rot \\"1\\""', 1, true) and json:find('"name":"My\\nrotation"', 1, true))
    assert(json:find('"family":"tbc"', 1, true) and json:find('"interface":20506', 1, true))
    assert(json == m:ToJSON(report, { family = 'tbc', interface = 20506 }), 'the same report encodes the same way')
    assert(not json:find('[\n\t]'), 'no raw control characters')
    assert(m.DELAY_EDGES[1] == 0.25 and #m.DELAY_EDGES == 5, 'the report draws the delay chart from these edges')
end)

test(
    'a forecast is checked against the highlights that follow: the third prediction against the highlight after next',
    function()
        local m = fresh()
        m:SetPredicting(true)
        m:FightStart(100)
        m:Advice('rot', FIREBALL, 101)
        m:Predicted(FIREBALL, { FROSTBOLT, ARCANE, BLINK }, { 0.8, 0.6, 0.5 })
        m:Predicted(FIREBALL, { POLY, POLY, POLY }, { 1, 1, 1 })
        m:Advice('rot', FROSTBOLT, 102)
        m:Advice('rot', nil, 103)
        m:Advice('rot', POLY, 104)
        m:Advice('rot', BLINK, 105)
        m:Cast(BLINK, 105.5)
        m:FightEnd(130)
        local rows = m:Report().rotations[1].predictionAccuracy
        assert(#rows == 3, #rows)

        assert(
            rows[1].slot == 2
                and rows[1].checked == 1
                and rows[1].hitPercent == 100
                and rows[1].meanConfidencePercent == 80
        )

        assert(rows[2].slot == 3 and rows[2].hitPercent == 0, 'Arcane Blast was predicted, Polymorph came')
        assert(rows[3].slot == 4 and rows[3].hitPercent == 100 and rows[3].meanConfidencePercent == 50)
        assert(m:PredictionRate(2) == nil, 'too few checked for a rate')
    end
)

test('prediction tracking records nothing while it is off, outside a fight, or for a forecast of old advice', function()
    local m = fresh()
    m:FightStart(100)
    m:Advice('rot', FIREBALL, 101)
    m:Predicted(FIREBALL, { FROSTBOLT }, { 1 })
    m:Advice('rot', FROSTBOLT, 102)
    m:Cast(FROSTBOLT, 103)
    m:FightEnd(130)
    assert(#m:Report().rotations[1].predictionAccuracy == 0)
    m:SetPredicting(true)
    m:FightStart(200)
    m:Advice('rot', FIREBALL, 201)
    m:Predicted(FROSTBOLT, { ARCANE }, { 1 })
    m:Advice('rot', ARCANE, 202)
    m:Cast(ARCANE, 203)
    m:FightEnd(230)
    assert(#m:Report().rotations[1].predictionAccuracy == 0, 'a forecast for a spell that is not advised is ignored')
end)

test('the hit rate over twenty checked predictions feeds the forecast', function()
    local m = fresh()
    m:SetPredicting(true)

    for n = 1, 25 do
        m:FightStart(0)
        m:Advice('rot', FIREBALL, 0)
        m:Predicted(FIREBALL, { FROSTBOLT }, { 0.5 })
        m:Advice('rot', n % 5 == 0 and ARCANE or FROSTBOLT, 1)
        m:Cast(FROSTBOLT, 2)
        m:FightEnd(20)
    end

    assert(math.abs(m:PredictionRate(2) - 20 / 25) < 1e-9)
end)

finish()
