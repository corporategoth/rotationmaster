local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local tags = {
    'PROXIMITY', 'PROXIMITY_HEALTH', 'PROXIMITY_HEALTH_COUNT', 'PROXIMITY_HEALTHPCT', 'PROXIMITY_HEALTHPCT_COUNT',
    'PROXIMITY_MANA', 'PROXIMITY_MANA_COUNT', 'PROXIMITY_MANAPCT', 'PROXIMITY_MANAPCT_COUNT'
}

local function fixture()
    local f = F.new()
    local a = f.addon

    f.units = {
        player = { x = 0, y = 0, instance = 1, health = 50, maxhealth = 100, mana = 30, maxmana = 100 },
        party1 = { x = 3, y = 4, instance = 1, health = 20, maxhealth = 100, mana = 10, maxmana = 100 },
    }

    f.ranges = {}
    f.missingPositions = {}
    f.rangeCalls = 0
    f.group = true
    f.env.Enum.PowerType.Mana = 0
    f.env.UnitExists = function(unit) return f.units[unit] ~= nil end
    f.env.IsInRaid = function() return f.raid == true end
    f.env.IsInGroup = function() return f.group end
    f.env.UnitPlayerOrPetInRaid = function(unit) return f.raid and f.units[unit] ~= nil end
    f.env.UnitPlayerOrPetInParty = function(unit) return f.group and not f.raid and f.units[unit] ~= nil end
    f.env.UnitInRaid = function(unit) return f.raidIndices and f.raidIndices[unit] end
    f.env.UnitIsUnit = function(unit, other) return unit == other end

    f.env.GetRaidRosterInfo = function(index)
        local group = f.raidGroups and f.raidGroups[index]

        if group then
            return 'Member', 0, group
        end
    end

    f.env.UnitPosition = function(unit)
        local u = f.units[unit]

        if u and not f.missingPositions[unit] then
            return u.y, u.x, 0, u.instance
        end
    end

    f.env.UnitHealth = function(unit) return f.units[unit].health end
    f.env.UnitHealthMax = function(unit) return f.units[unit].maxhealth end
    f.env.UnitPower = function(unit) return f.units[unit].mana end
    f.env.UnitPowerMax = function(unit) return f.units[unit].maxmana end

    f.libraries['LibRangeCheck-3.0'].GetRange = function(_, unit)
        f.rangeCalls = f.rangeCalls + 1
        local r = f.ranges[unit]

        if type(r) == 'function' then
            return r()
        end
        if r then
            return r.minimum, r.maximum
        end
    end

    for _, path in ipairs({
        'Data/plain.lua',
        'Data/tags.lua',
        'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua',
        'Core/conditions.lua',
        'Conditions/common.lua',
        'Conditions/spatial.lua',
        'Conditions/spatial_stats.lua',
    }) do
        f.load(path)
    end

    return f, a
end

local function value(tag)
    return {
        type = tag,
        unit = 'player',
        distance = 10,
        operator = 'GREATERTHAN',
        value = .1,
        operation = 'minimum',
        healthoperator = 'GREATERTHAN',
        health = .1,
        manaoperator = 'GREATERTHAN',
        mana = .1,
    }
end

local function uncertain(f)
    f.missingPositions.player = true
    f.ranges.party1 = { minimum = 5, maximum = 15 }
end

test('all nine proximity consumers keep uncertain interval membership unavailable beneath NOT', function()
    local f, a = fixture()
    uncertain(f)

    for _, tag in ipairs(tags) do
        local v = value(tag)
        assert(a:evaluateConditionResult(v).status == 'unavailable', tag .. ' counted uncertain membership')

        assert(
            a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'unavailable',
            tag .. ' authorized its negation from uncertainty'
        )
    end
end)

test('proximity interval decisions respect successful upper and failed positive lower boundaries', function()
    local f, a = fixture()
    f.missingPositions.player = true
    local v = value('PROXIMITY')
    v.operator = 'EQUALS'
    v.value = 2
    f.ranges.party1 = { minimum = 5, maximum = 10 }
    assert(a:evaluateCondition(v), 'known upper-bound equality excluded a member')
    f.ranges.party1 = { minimum = 10, maximum = 15 }
    v.value = 1
    assert(a:evaluateCondition(v), 'failed lower checker at threshold counted the member')
    f.ranges.party1 = { minimum = 10 }
    assert(a:evaluateCondition(v), 'unbounded known-outside interval was treated as a member')
    f.ranges.party1 = { minimum = 0, maximum = 5 }
    v.distance = 0

    assert(
        a:evaluateConditionResult(v).status == 'unavailable',
        'synthetic zero lower floor became a failed zero-yard check'
    )
end)

test('readable coordinates preserve exact inclusive distance and distinguish another instance', function()
    local f, a = fixture()
    local v = value('PROXIMITY')
    v.distance = 5
    v.operator = 'EQUALS'
    v.value = 2
    assert(a:evaluateCondition(v) and f.rangeCalls == 0, 'coordinate membership changed or used estimates')
    f.units.party1.instance = 2
    v.value = 1
    assert(a:evaluateCondition(v), 'different instances were combined')
    f.units.party1.instance = 1
    f.missingPositions.party1 = true
    assert(a:evaluateConditionResult(v).status == 'unavailable', 'unobserved coordinate member was silently omitted')
end)

test('solo scans include the known player but no phantom slots and preserve legitimate zero counts', function()
    local f, a = fixture()
    f.group = false
    f.units.party1 = nil
    local v = value('PROXIMITY')
    v.operator = 'EQUALS'
    v.value = 1
    assert(a:evaluateCondition(v), 'solo scan omitted self or invented roster members')
    local count = value('PROXIMITY_HEALTH_COUNT')
    count.operator = 'EQUALS'
    count.value = 0
    count.healthoperator = 'GREATERTHAN'
    count.health = 100
    assert(a:evaluateCondition(count), 'known zero qualifying count became unavailable')
    f.units.pet = { x = 100, y = 0, instance = 1 }
    v.unit = 'pet'
    v.value = 0
    assert(a:evaluateCondition(v), 'complete known empty proximity scan lost zero count')
    local aggregate = value('PROXIMITY_HEALTH')
    aggregate.unit = 'pet'
    assert(a:evaluateConditionResult(aggregate).status == 'unavailable', 'empty aggregate invented a value')
end)

test('absent or inapplicable anchors are unavailable rather than fabricated empty counts', function()
    local f, a = fixture()
    f.units.player = nil

    for _, tag in ipairs(tags) do
        assert(
            a:evaluateConditionResult({ type = 'NOT', value = value(tag) }).status == 'unavailable',
            tag .. ' negated an absent anchor'
        )
    end

    f.units.target = {}
    f.group = false
    local v = value('PROXIMITY')
    v.unit = 'target'
    v.operator = 'EQUALS'
    v.value = 0
    assert(a:evaluateConditionResult(v).status == 'unavailable', 'unrelated solo anchor manufactured a zero count')
end)

test('malformed missing restricted and failed intervals never become actionable partial counts', function()
    local f, a = fixture()
    f.missingPositions.player = true
    local opaque = {}
    a.Platform.CanReadValue = function(_, v) return v ~= opaque end

    for _, bounds in ipairs({
        {},
        { minimum = -1, maximum = 5 },
        { minimum = 0 / 0, maximum = 5 },
        { minimum = 20, maximum = 10 },
        { minimum = 0, maximum = math.huge },
        { minimum = 0, maximum = opaque },
    }) do
        f.ranges.party1 = bounds

        assert(
            a:evaluateConditionResult(value('PROXIMITY')).status == 'unavailable',
            'invalid interval produced a count'
        )
    end

    f.ranges.party1 = function()
        error('failed range observation')
    end

    assert(
        a:evaluateConditionResult(value('PROXIMITY')).status == 'unavailable',
        'provider failure escaped unavailable'
    )
end)

test('unknown health mana and percentage denominators propagate through counts and aggregates', function()
    for _, tag in ipairs(tags) do
        if tag ~= 'PROXIMITY' then
            local f, a = fixture()
            local mana = tag:find('MANA', 1, true)
            local field = mana and 'mana' or 'health'
            f.units.party1[field] = nil

            assert(
                a:evaluateConditionResult({ type = 'NOT', value = value(tag) }).status == 'unavailable',
                tag .. ' ignored unknown member statistics'
            )

            f.units.party1[field] = 10

            if tag:find('PCT', 1, true) then
                f.units.party1[mana and 'maxmana' or 'maxhealth'] = 0
                assert(a:evaluateConditionResult(value(tag)).status == 'unavailable', tag .. ' divided by zero')
            end
        end
    end
end)

test('uncertain proximity guards never choose either branch or fall through to later actions', function()
    local f, a = fixture()
    uncertain(f)

    for _, tag in ipairs(tags) do
        local rotation = {
            rotation = {
                {
                    id = 'guard',
                    type = 'branch',
                    conditions = value(tag),
                    onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                    onFalse = { { id = 'no', type = 'spell', action = 2 } },
                },
                { id = 'tail', type = 'spell', action = 3 },
            },
        }

        local result = a:EvaluateRotationSequence(
            rotation,
            function(v) return a:evaluateConditionResult(v) end,
            function()
                error('unknown proximity chose an action')
            end
        )

        assert(result.status == 'unavailable' and result.suppressAttack, tag .. ' fell through from uncertainty')
    end
end)

test('legacy proximity callbacks retain their arguments and nil-return side effects', function()
    local f, a = fixture()
    f.missingPositions.player = true
    f.ranges.party1 = { minimum = 0, maximum = 8 }
    local seen = {}
    local cache = {}

    local complete, why = a.proximity_eval(value('PROXIMITY'), cache, function(c, unit, distance)
        assert(c == cache)
        seen[unit] = distance
    end)

    assert(
        complete and not why and seen.player == 0 and seen.party1 == 8,
        'legacy callback API lost its documented upper-bound estimate'
    )
end)

test('raid subgroup filtering skips proven other groups and requires readable owner subgroup', function()
    local f, a = fixture()
    f.raid = true
    f.units.party1 = nil
    f.units.raid1 = { x = 0, y = 0, instance = 1 }
    f.units.raid2 = {}
    f.raidIndices = { player = 1 }
    f.raidGroups = { [1] = 1, [2] = 2 }
    local v = value('PROXIMITY')
    v.samegroup = true
    v.operator = 'EQUALS'
    v.value = 1
    assert(a:evaluateCondition(v), 'another subgroup demanded irrelevant missing coordinates')
    f.raidGroups[2] = nil
    assert(a:evaluateConditionResult(v).status == 'unavailable', 'missing subgroup silently excluded a real member')
    f.raidGroups[2] = 2
    f.raidIndices.player = nil
    assert(a:evaluateConditionResult(v).status == 'unavailable', 'unknown anchor subgroup became an empty scan')
end)

test('excluded pets do not contaminate scans while included unobserved pets remain unavailable', function()
    local f, a = fixture()
    f.group = false
    f.units.party1 = nil
    f.units.pet = {}
    f.missingPositions.pet = true
    local v = value('PROXIMITY')
    v.operator = 'EQUALS'
    v.value = 1
    assert(a:evaluateCondition(v), 'excluded pet contaminated a known solo scan')
    v.includepets = true

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'unavailable',
        'included unknown pet silently disappeared'
    )
end)

test('restricted existence coordinates and statistics never enter comparisons or arithmetic', function()
    local f, a = fixture()
    local opaque = {}
    a.Platform.CanReadValue = function(_, v) return v ~= opaque end
    local exists = f.env.UnitExists

    f.env.UnitExists = function(unit)
        if unit == 'party1' then
            return opaque
        end

        return exists(unit)
    end

    assert(a:evaluateConditionResult(value('PROXIMITY')).status == 'unavailable')
    f.env.UnitExists = exists
    f.units.party1.x = opaque
    assert(a:evaluateConditionResult(value('PROXIMITY')).status == 'unavailable')
    f.units.party1.x = 3

    for _, tag in ipairs(tags) do
        if tag ~= 'PROXIMITY' then
            local field = tag:find('MANA', 1, true) and 'mana' or 'health'
            local saved = f.units.party1[field]
            f.units.party1[field] = opaque

            assert(
                a:evaluateConditionResult({ type = 'NOT', value = value(tag) }).status == 'unavailable',
                tag .. ' compared a restricted statistic'
            )

            f.units.party1[field] = saved
        end
    end
end)

test('missing mana API never substitutes the health observation', function()
    local f, a = fixture()
    f.env.UnitPower = nil

    assert(
        a:evaluateConditionResult(value('PROXIMITY_MANA')).status == 'unavailable',
        'missing mana API silently measured health'
    )
end)

test('shared evaluation cache reuses raw observations across all nine proximity consumers', function()
    local f, a = fixture()
    f.missingPositions.player = true
    f.ranges.party1 = { minimum = 0, maximum = 5 }
    local conditions = { type = 'AND', value = {} }

    for _, tag in ipairs(tags) do
        conditions.value[#conditions.value + 1] = value(tag)
    end

    local healthCalls, powerCalls = 0, 0
    local health, power = f.env.UnitHealth, f.env.UnitPower

    f.env.UnitHealth = function(unit)
        healthCalls = healthCalls + 1
        return health(unit)
    end

    f.env.UnitPower = function(unit, kind)
        powerCalls = powerCalls + 1
        return power(unit, kind)
    end

    local result = a:evaluateConditionResult(conditions)

    assert(
        result.status ~= 'unavailable' and f.rangeCalls == 1 and healthCalls == 2 and powerCalls == 2,
        'proximity families reread the same observation per condition'
    )
end)

test('all proximity Help callbacks explain conservative membership and unavailable outcomes', function()
    local f, a = fixture()

    for _, tag in ipairs(tags) do
        local frame = f.widget('Group')
        a.conditionDefinitions[tag].help(frame)
        local text = F.text(frame)

        assert(
            text:find('upper range bound', 1, true) and text:find('unavailable', 1, true),
            tag .. ' hides the range uncertainty contract'
        )

        assert(
            not text:find('This will only work for yourself', 1, true),
            tag .. ' retains the obsolete location warning'
        )
    end
end)

test('fully observed false proximity results remain invertible and choose the False branch', function()
    local f, a = fixture()

    for _, tag in ipairs(tags) do
        local condition = value(tag)
        condition.operator = 'LESSTHAN'
        condition.value = 0
        assert(a:evaluateConditionResult(condition).status == 'no-match', tag .. ' lost its known false result')

        assert(
            a:evaluateConditionResult({ type = 'NOT', value = condition }).status == 'match',
            tag .. ' treated known false as unavailable'
        )

        local rotation = {
            rotation = {
                {
                    id = 'guard',
                    type = 'branch',
                    conditions = condition,
                    onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                    onFalse = { { id = 'no', type = 'spell', action = 2 } },
                },
            },
        }

        local selected

        local result = a:EvaluateRotationSequence(
            rotation,
            function(v) return a:evaluateConditionResult(v) end,
            function(step)
                selected = step.id
                return false
            end
        )

        assert(result.status == 'selected' and selected == 'no', tag .. ' did not select its observed False arm')
    end
end)

finish()
