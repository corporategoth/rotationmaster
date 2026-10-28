-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project)
    local a, e = f.addon, f.env
    local state = { exists = true, dead = true, friendly = true, calls = {} }

    local function call(kind, ...)
        state.calls[#state.calls + 1] = { kind, ... }

        if state.throw == kind then
            error('native failure')
        end

        return state[kind]
    end

    e.UnitExists = function(...) return call('exists', ...) end
    e.UnitIsDeadOrGhost = function(...) return call('dead', ...) end
    e.UnitIsFriend = function(...) return call('friendly', ...) end

    for _, path in ipairs({
        'Platform/unit_states.lua',
        'Conditions/unit_states.lua',
        'Core/unit_state_conditions.lua',
    }) do
        local h = io.open(path)

        if h then
            h:close()
            f.load(path)
        end
    end

    return f, a, state
end

local function observe(a, kind)
    assert(a.Platform.GetUnitStateObservation, 'unit-state adapter missing')
    return a.Platform:GetUnitStateObservation('mouseover', kind)
end

test('exact dead-or-ghost and player friendliness tuples preserve readable false', function()
    for _, kind in ipairs({ 'dead', 'friendly' }) do
        local _, a, s = fixture()
        assert(observe(a, kind) == true)
        assert(s.calls[1][2] == 'mouseover')
        local row = s.calls[2]
        assert(row[1] == kind)

        if kind == 'friendly' then
            assert(row[2] == 'player' and row[3] == 'mouseover')
        else
            assert(row[2] == 'mouseover' and row[3] == nil)
        end

        s[kind] = false
        assert(observe(a, kind) == false)
    end
end)

test('missing units and missing restricted failed or malformed observations remain unavailable', function()
    for _, kind in ipairs({ 'dead', 'friendly' }) do
        local f, a, s = fixture()
        s.exists = false
        assert(observe(a, kind) == nil and #s.calls == 1)
        s.exists = true

        for _, key in ipairs({ 'exists', kind }) do
            for _, bad in ipairs({ 0, 1, 'false', {} }) do
                s[key] = bad
                assert(observe(a, kind) == nil)
            end

            s[key] = nil
            assert(observe(a, kind) == nil)
            s[key] = true
            s.throw = key
            assert(observe(a, kind) == nil)
            s.throw = nil
            local secret = {}
            f.env.canaccessvalue = function(v) return not rawequal(v, secret) end
            s[key] = secret
            assert(observe(a, kind) == nil)
            s[key] = true
        end

        f.env[kind == 'dead' and 'UnitIsDeadOrGhost' or 'UnitIsFriend'] = nil
        assert(observe(a, kind) == nil)
    end
end)

test('unsupported clients and invalid queries do not call native APIs', function()
    local _, a, s = fixture(999)
    assert(observe(a, 'dead') == nil and #s.calls == 0)
    local _, b, t = fixture()
    assert(b.Platform:GetUnitStateObservation('', 'dead') == nil)
    assert(observe(b, 'enemy') == nil and #t.calls == 0)
end)

test('new leaves use one evaluation cache and retry current state in a fresh pass', function()
    local _, a, s = fixture()

    for _, tag in ipairs({ 'DEAD', 'FRIENDLY' }) do
        local d = assert(a.definitions[tag], tag .. ' definition missing')
        local cache = {}
        assert(d.valid(0, { unit = 'mouseover' }))
        assert(d.evaluate({ unit = 'mouseover' }, cache) == true)
        local n = #s.calls
        assert(d.evaluate({ unit = 'mouseover' }, cache) == true and #s.calls == n)
        s[tag == 'DEAD' and 'dead' or 'friendly'] = false
        assert(d.evaluate({ unit = 'mouseover' }, {}) == false)
        assert(type(d.help) == 'function' and d.icon)
    end
end)

test('switch seeding occurs once per saved profile and preserves subsequent removals', function()
    local _, a = fixture()
    assert(a.InitializeUnitStateConditions, 'profile initializer missing')

    local db = {
        profile = { switch_conditions = { 'AND', 'GROUP' }, condition_groups = {}, engravingConditionsSeeded = true },
    }

    a:InitializeUnitStateConditions(nil, db)

    assert(
        db.profile.unitStateSwitchSeeded
            and table.concat(db.profile.switch_conditions, ',') == 'AND,GROUP,DEAD,FRIENDLY'
    )

    table.remove(db.profile.switch_conditions, 4)
    a:InitializeUnitStateConditions(nil, db)
    assert(#db.profile.switch_conditions == 3)

    local fresh = {
        profile = { switch_conditions = { 'DEAD' }, condition_groups = {}, engravingConditionsSeeded = true },
    }

    a:InitializeUnitStateConditions(nil, fresh)
    assert(table.concat(fresh.profile.switch_conditions, ',') == 'DEAD,FRIENDLY')
end)

test(
    'resurrection expression follows announcement target and short circuits living or unavailable recipients',
    function()
        local f, a, s = fixture()

        for _, path in ipairs({
            'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua', 'Data/validation.lua',
            'Data/condition_draft.lua', 'Core/conditions.lua', 'Conditions/unit_states.lua', 'Conditions/character.lua',
            'Core/announcements.lua'
        }) do
            f.load(path)
        end

        -- Exercise the existing GROUP condition with its new Unit field.
        local grouped = false
        local groupCalls = 0

        f.env.UnitInParty = function(unit)
            groupCalls = groupCalls + 1
            assert(unit == 'mouseover')
            return grouped
        end

        f.env.UnitInRaid = function(unit)
            assert(unit == 'mouseover')
            return nil
        end

        local tree = {
            type = 'AND',
            value = {
                { type = 'DEAD', unit = 'announcementtarget' },
                {
                    type = 'OR',
                    value = {
                        { type = 'FRIENDLY', unit = 'announcementtarget' },
                        { type = 'GROUP', unit = 'announcementtarget' },
                    },
                },
            },
        }

        assert(a:AnnouncementConditionMatches({ conditions = tree }, 'Recipient', nil, 'mouseover') and groupCalls == 0)
        s.friendly = false
        assert(not a:AnnouncementConditionMatches({ conditions = tree }, 'Recipient', nil, 'mouseover'))
        grouped = true
        assert(a:AnnouncementConditionMatches({ conditions = tree }, 'Recipient', nil, 'mouseover'))
        s.dead = false
        local n = groupCalls

        assert(
            not a:AnnouncementConditionMatches({ conditions = tree }, 'Recipient', nil, 'mouseover') and groupCalls == n
        )

        s.exists = false

        assert(
            not a:AnnouncementConditionMatches({
                conditions = { type = 'NOT', value = { type = 'DEAD', unit = 'announcementtarget' } },
            }, nil, nil, 'mouseover')
        )

        assert(not a:AnnouncementConditionMatches({ conditions = tree }, nil, nil, nil))
        assert(tree.value[1].unit == 'announcementtarget')
    end
)

test('summaries and help retain literal unit labels and explain unavailable recipients', function()
    local f, a = fixture()
    f.load('Core/conditions.lua')
    f.load('Conditions/unit_states.lua')
    a.units.mouseover = 'Name%1|cFFFF0000'

    for _, tag in ipairs({ 'DEAD', 'FRIENDLY' }) do
        local d = a.conditionDefinitions[tag]
        assert(a:DescribeCondition({ type = tag, unit = 'mouseover' }, 0):find('Name%1|cFFFF0000', 1, true))
        local frame = f.widget('Help')
        d.help(frame)
        assert(F.text(frame):find('unavailable', 1, true))
    end
end)

finish()
