-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The MARKED and MARK_COUNT conditions (Conditions/raid_marks.lua): what each value matches, the unavailable cases
-- (also under NOT), validity of saved values, the readable summaries, the editor controls, support by capability, the
-- one-time seed of existing profiles and the borrowed icons. See docs/raid-marks.md.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local W = dofile('tests/fixtures/raid_mark_world.lua')
local C = dofile('tests/fixtures/condition_client.lua')

local KEYS = { 'skull', 'cross', 'square', 'moon', 'triangle', 'diamond', 'circle', 'star' }
local NUMBER = { skull = 8, cross = 7, square = 6, moon = 5, triangle = 4, diamond = 3, circle = 2, star = 1 }
local FAMILIES = { 'mists', 'tbc', 'era' }

local function unit(guid, mark, enemy)
    return { guid = guid, mark = mark, enemy = enemy == true, friend = enemy == false }
end

local function marked(unitToken, mark)
    return { type = 'MARKED', unit = unitToken, mark = mark }
end

test('MARKED any matches a marked unit and not an unmarked one, and swaps under NOT', function()
    for _, name in ipairs(FAMILIES) do
        local _, a, _, w = W.client(name)
        w:set('target', unit('G1', 8, true))
        C.expect(a, marked('target', 'any'), 'match', name)
        w.tokens.target.mark = nil
        C.expect(a, marked('target', 'any'), 'no-match', name)
    end
end)

test('MARKED none matches a unit with no mark', function()
    local _, a, _, w = W.client('tbc')
    w:set('target', unit('G1', nil, true))
    C.expect(a, marked('target', 'none'), 'match')
    w.tokens.target.mark = 3
    C.expect(a, marked('target', 'none'), 'no-match')
end)

test('MARKED never matches a unit that does not exist, not even for none', function()
    local _, a = W.client('tbc')
    C.expect(a, marked('target', 'any'), 'no-match')
    C.expect(a, marked('target', 'none'), 'no-match')
    C.expect(a, marked('target', 'skull'), 'no-match')
end)

test('MARKED with one mark matches exactly that mark, for all eight marks', function()
    local _, a, _, w = W.client('tbc')
    w:set('target', unit('G1', nil, true))

    for _, key in ipairs(KEYS) do
        w.tokens.target.mark = NUMBER[key]

        for _, other in ipairs(KEYS) do
            C.expect(a, marked('target', other), other == key and 'match' or 'no-match', key .. ' against ' .. other)
        end
    end
end)

test('MARKED with several marks matches any of them', function()
    local _, a, _, w = W.client('tbc')
    w:set('target', unit('G1', NUMBER.moon, true))
    C.expect(a, marked('target', 'skull,moon'), 'match')
    C.expect(a, marked('target', 'moon,star'), 'match')
    C.expect(a, marked('target', 'skull,cross,square'), 'no-match')
    w.tokens.target.mark = nil
    C.expect(a, marked('target', 'skull,moon'), 'no-match')
    C.expect(a, marked('target', 'skull,cross,square,moon,triangle,diamond,circle,star'), 'no-match')
end)

test('MARKED reads once per evaluation through the cache', function()
    local _, a, _, w = W.client('tbc')
    w:set('target', unit('G1', 8, true))
    w.calls.GetRaidTargetIndex = 0

    local result = a:evaluateConditionResult({
        type = 'AND',
        value = { marked('target', 'skull'), marked('target', 'any'), marked('target', 'none') },
    })

    assert(result.status == 'no-match')
    assert(w.calls.GetRaidTargetIndex == 1, 'read ' .. w.calls.GetRaidTargetIndex .. ' times')
end)

test('MARKED is unavailable, also under NOT, when the mark is hidden or the client cannot read', function()
    for _, name in ipairs({ 'retail', 'forever' }) do
        local _, a, _, w = W.client(name)
        w:set('target', unit('G1', 8, true))
        w.secretMarks.target = true
        C.expect(a, marked('target', 'any'), 'unavailable', name)
        C.expect(a, marked('target', 'none'), 'unavailable', name)
        C.expect(a, marked('target', 'skull'), 'unavailable', name)
        local _, reason = C.status(a, marked('target', 'any'))
        assert(reason == 'unsupported-client', tostring(reason))
    end

    local _, b, e = W.client('tbc')
    e.UnitExists = function() return nil end
    C.expect(b, marked('target', 'any'), 'unavailable', 'a unit whose existence is unknown')
    local _, c, f = W.client('tbc')
    f.UnitExists = function() return W.SECRET end
    C.expect(c, marked('target', 'any'), 'unavailable', 'a hidden existence')
end)

test('MARKED on a mark unit type follows the unit that carries the mark', function()
    local _, a, _, w = W.client('tbc')
    C.expect(a, marked('skull', 'skull'), 'unavailable', 'nobody carries the skull')
    local _, reason = C.status(a, marked('skull', 'any'))
    assert(reason == 'no-marked-unit', tostring(reason))
    w:set('nameplate4', unit('G4', 8, true))
    w:fire('RAID_TARGET_UPDATE')
    C.expect(a, marked('skull', 'skull'), 'match')
    C.expect(a, marked('anymark', 'skull'), 'match')
    C.expect(a, marked('cross', 'skull'), 'unavailable')
end)

test('valid accepts exactly the choices the editor can save', function()
    local _, a = W.client('tbc')
    local definition = a.conditionDefinitions.MARKED

    for _, good in ipairs({
        'any',
        'none',
        'skull',
        'star',
        'skull,moon',
        'star,circle,diamond,triangle,moon,square,cross,skull',
    }) do
        assert(definition.valid(0, marked('target', good)), 'rejected ' .. good)
    end

    for _, bad in ipairs({
        '', 'Skull', 'skull,', ',skull', 'skull,,moon', 'skull, moon', 'skull,skull', 'any,none', 'none,skull',
        'purple', 'skull moon'
    }) do
        assert(not definition.valid(0, marked('target', bad)), 'accepted ' .. bad)
    end

    assert(not definition.valid(0, marked('target', nil)), 'accepted a missing mark')
    assert(not definition.valid(0, marked('target', string.rep('skull,', 40))), 'accepted an oversized list')
    assert(not definition.valid(0, marked(nil, 'any')), 'accepted a missing unit')
    assert(not definition.valid(0, marked('nonsense', 'any')), 'accepted an unknown unit')
    assert(definition.valid(0, marked('skull', 'any')), 'a mark unit type is a valid unit')
end)

test('MARKED summaries read as sentences for every choice', function()
    local _, a = W.client('tbc')

    assert(a:printCondition(marked('target', 'any'), 0) == 'your target has a raid mark', a:printCondition(
        marked('target', 'any'),
        0
    ))

    assert(a:printCondition(marked('player', 'any'), 0) == 'you have a raid mark')
    assert(a:printCondition(marked('target', 'none'), 0) == 'your target has no raid mark')

    assert(a:printCondition(marked('target', 'skull'), 0) == 'your target has the Skull mark', a:printCondition(
        marked('target', 'skull'),
        0
    ))

    assert(
        a:printCondition(marked('target', 'moon,skull'), 0) == 'your target has one of these marks: Skull, Moon',
        a:printCondition(marked('target', 'moon,skull'), 0)
    )

    assert(a:printCondition(marked('focus', 'star'), 0) == 'your focus target has the Star mark')
    local negated = a:printCondition({ type = 'NOT', value = marked('target', 'any') }, 0)
    assert(negated:find('does not have a raid mark', 1, true), negated)
    local bare = a:printCondition({ type = 'MARKED' }, 0)
    assert(bare:find('<unit>', 1, true), bare)
end)

test('MARK_COUNT compares the number of marked units known', function()
    for _, name in ipairs(FAMILIES) do
        local _, a, _, w = W.client(name)
        local count = { type = 'MARK_COUNT', operator = 'GREATERTHAN', value = 1 }
        C.expect(a, count, 'no-match', name)
        w:set('target', unit('G1', 8, true))
        w:set('mouseover', unit('G2', 7, true))
        w:fire('RAID_TARGET_UPDATE')
        C.expect(a, count, 'match', name)
        C.expect(a, { type = 'MARK_COUNT', operator = 'EQUALS', value = 2 }, 'match', name)
        C.expect(a, { type = 'MARK_COUNT', operator = 'LESSTHAN', value = 2 }, 'no-match', name)
    end
end)

test('MARK_COUNT filters by enemy and friendly', function()
    local _, a, _, w = W.client('tbc')
    w:set('target', unit('G1', 8, true))
    w:set('focus', unit('G2', 7, false))
    w:set('mouseover', unit('G3', 6, true))
    w:fire('RAID_TARGET_UPDATE')
    C.expect(a, { type = 'MARK_COUNT', filter = 'enemy', operator = 'EQUALS', value = 2 }, 'match')
    C.expect(a, { type = 'MARK_COUNT', filter = 'friendly', operator = 'EQUALS', value = 1 }, 'match')
    C.expect(a, { type = 'MARK_COUNT', filter = 'any', operator = 'EQUALS', value = 3 }, 'match')
    C.expect(a, { type = 'MARK_COUNT', operator = 'EQUALS', value = 3 }, 'match', 'no filter is any')
end)

test('MARK_COUNT is unavailable, also under NOT, when a mark cannot be read', function()
    local _, a, _, w = W.client('tbc')
    w:set('target', unit('G1', 8, true))
    w.secretMarks.nameplate1 = true
    C.expect(a, { type = 'MARK_COUNT', operator = 'GREATERTHAN', value = 0 }, 'unavailable')
    local _, reason = C.status(a, { type = 'MARK_COUNT', operator = 'GREATERTHAN', value = 0 })
    assert(reason == 'unreadable', tostring(reason))
end)

test('MARK_COUNT with a filter is unavailable while a unit hostility is unknown', function()
    local _, a, e, w = W.client('tbc')
    w:set('target', unit('G1', 8, true))
    e.UnitCanAttack = function() return W.SECRET end
    C.expect(a, { type = 'MARK_COUNT', filter = 'enemy', operator = 'GREATERTHAN', value = 0 }, 'unavailable')

    C.expect(
        a,
        { type = 'MARK_COUNT', operator = 'GREATERTHAN', value = 0 },
        'match',
        'the unfiltered count does not need hostility'
    )
end)

test('MARK_COUNT valid accepts a count of 0 to 8 with a known operator and filter', function()
    local _, a = W.client('tbc')
    local definition = a.conditionDefinitions.MARK_COUNT

    for _, good in ipairs({
        { operator = 'EQUALS', value = 0 },
        { operator = 'GREATERTHAN', value = 8 },
        { operator = 'EQUALS', value = 3, filter = 'enemy' },
        { operator = 'EQUALS', value = 3, filter = 'friendly' },
        { operator = 'EQUALS', value = 3, filter = 'any' },
    }) do
        assert(definition.valid(0, good))
    end

    for _, bad in ipairs({
        { operator = 'EQUALS', value = -1 },
        { operator = 'EQUALS', value = 9 },
        { operator = 'EQUALS', value = 0 / 0 },
        { operator = 'NEAR', value = 1 },
        { value = 1 },
        { operator = 'EQUALS' },
        { operator = 'EQUALS', value = 1, filter = 'all' },
    }) do
        assert(not definition.valid(0, bad))
    end
end)

test('MARK_COUNT summaries name the filter', function()
    local _, a = W.client('tbc')
    local any = a:printCondition({ type = 'MARK_COUNT', operator = 'GREATERTHAN', value = 1 }, 0)
    assert(any:find('the number of marked units', 1, true) and any:find('1', 1, true), any)

    assert(a:printCondition({ type = 'MARK_COUNT', filter = 'enemy', operator = 'EQUALS', value = 2 }, 0):find(
        'marked enemy units',
        1,
        true
    ))

    assert(a:printCondition({ type = 'MARK_COUNT', filter = 'friendly', operator = 'EQUALS', value = 2 }, 0):find(
        'marked friendly units',
        1,
        true
    ))
end)

test('Retail and Forever reject mark conditions even for readable or absent marks', function()
    for _, name in ipairs({ 'retail', 'forever' }) do
        local _, a, _, w = W.client(name)
        w:set('target', unit('G1', 8, true))
        w.calls.GetRaidTargetIndex = 0
        C.expect(a, marked('target', 'skull'), 'unavailable', name)
        C.expect(a, { type = 'MARK_COUNT', operator = 'EQUALS', value = 1 }, 'unavailable', name)
        assert(C.support(a, 'MARKED', marked('target', 'skull')) == 'unsupported-client')
        assert(C.support(a, 'MARK_COUNT', {}) == 'unsupported-client')
        assert(w.calls.GetRaidTargetIndex == 0, 'unsupported client queried marks')
    end
end)

test('support: both conditions need a client that can read marks', function()
    for _, name in ipairs(FAMILIES) do
        local _, a = W.client(name)
        assert(C.support(a, 'MARKED', marked('target', 'any')) == nil, name)
        assert(C.support(a, 'MARK_COUNT', { operator = 'EQUALS', value = 1 }) == nil, name)
        local _, b = W.client(name, { read = false })
        assert(C.support(b, 'MARKED', marked('target', 'any')) == 'missing-api', name)
        assert(C.support(b, 'MARK_COUNT', { operator = 'EQUALS', value = 1 }) == 'missing-api', name)
    end
end)

test('MARKED and MARK_COUNT are in the Combat category of a new profile and are seeded once into an old one', function()
    local _, a = W.client('tbc')
    local defaults = { char = {}, profile = {}, global = {} }
    a:augmentDefaults(defaults)
    local combat

    for _, category in ipairs(defaults.profile.condition_groups) do
        if category.id == 'b3d7df2c-f257-4a2d-961e-66e49336d109' then
            combat = category
        end
    end

    local seen = {}

    for _, tag in ipairs(combat.conditions) do
        seen[tag] = true
    end

    assert(seen.MARKED and seen.MARK_COUNT, 'new profiles list both')

    -- An existing profile gets them once; removing one stays removed.
    local profile = {
        condition_groups = {
            { id = 'b3d7df2c-f257-4a2d-961e-66e49336d109', conditions = { 'COMBAT' } },
            { id = 'other', conditions = {} },
        },
    }

    a:InitializeRaidMarkConditions(nil, { profile = profile })
    assert(table.concat(profile.condition_groups[1].conditions, ',') == 'COMBAT,MARKED,MARK_COUNT')
    assert(#profile.condition_groups[2].conditions == 0 and profile.raidMarkConditionsSeeded == true)
    table.remove(profile.condition_groups[1].conditions, 2)
    a:InitializeRaidMarkConditions(nil, { profile = profile })
    assert(table.concat(profile.condition_groups[1].conditions, ',') == 'COMBAT,MARK_COUNT', 'a removed tag came back')

    local without = {
        condition_groups = { { id = 'b3d7df2c-f257-4a2d-961e-66e49336d109', conditions = { 'MARKED' } } },
    }

    a:InitializeRaidMarkConditions(nil, { profile = without })

    assert(
        table.concat(without.condition_groups[1].conditions, ',') == 'MARKED,MARK_COUNT',
        'a listed tag was duplicated'
    )
end)

test('the two conditions borrow the icon of a related condition and say so', function()
    local _, a = W.client('tbc')
    local artwork = a.Artwork.condition
    assert(artwork.MARKED == artwork.CLASSIFICATION and artwork.MARK_COUNT == artwork.DISTANCE_COUNT)

    assert(
        a.conditionDefinitions.MARKED.icon == artwork.MARKED
            and a.conditionDefinitions.MARK_COUNT.icon == artwork.MARK_COUNT
    )
end)

-- Editor controls. The unit selector is first, then the choice dropdown, then eight checkboxes.
local function mount(a, tag, value)
    local definition = a.conditionDefinitions[tag]
    local parent = a:CreateConditionGroup()
    parent:SetWidth(640)
    local root = { type = tag, condition = value }
    local funcs = {}
    local state = { prints = 0 }
    local top = {}

    function top:GetUserData(key)
        if key == 'root' then
            return root
        elseif key == 'funcs' then
            return funcs
        end
    end

    function funcs.print(_, _, spec)
        state.prints = state.prints + 1
        return definition.print(spec, value)
    end

    function top:SetStatusText(text)
        state.status = text
    end

    parent:SetUserData('top', top)
    definition.widget(parent, 7, value)

    for _, child in ipairs(parent.children) do
        if child.configure then
            child.configure()
        end
    end

    return parent, state
end

test('the MARKED editor sets any, none and a ticked list, and keeps the controls in step', function()
    local _, a = W.client('tbc')
    local value = { type = 'MARKED', unit = 'target' }
    local parent, state = mount(a, 'MARKED', value)
    assert(#parent.children == 10, 'unit selector, choice and eight checkboxes: ' .. #parent.children)
    local choice = parent.children[2]
    local boxes = {}

    for index = 3, 10 do
        boxes[#boxes + 1] = parent.children[index]
    end

    for _, box in ipairs(boxes) do
        assert(box.disabled == true and box:GetValue() == false, 'the boxes are off until the one-of choice')
    end

    choice:Fire('OnValueChanged', 'any')
    assert(value.mark == 'any' and state.prints == 1)
    choice:Fire('OnValueChanged', 'none')
    assert(value.mark == 'none')
    choice:Fire('OnValueChanged', 'some')
    assert(value.mark == 'skull', 'the one-of choice starts with the skull ticked')
    assert(boxes[1]:GetValue() == true and boxes[1].disabled == false, 'skull box is on and enabled')
    boxes[4]:Fire('OnValueChanged', true)
    assert(value.mark == 'skull,moon', value.mark)
    boxes[8]:Fire('OnValueChanged', true)
    assert(value.mark == 'skull,moon,star', value.mark)
    boxes[1]:Fire('OnValueChanged', false)
    boxes[4]:Fire('OnValueChanged', false)
    assert(value.mark == 'star', value.mark)
    boxes[8]:Fire('OnValueChanged', false)
    assert(value.mark == 'any', 'unticking the last mark returns to any')
    assert(choice:GetValue() == 'any' and boxes[8].disabled == true)
    choice:Fire('OnValueChanged', 'some')
    choice:Fire('OnValueChanged', 'some')
    assert(value.mark == 'skull', 'choosing the one-of choice again keeps the list')
    assert(a.conditionDefinitions.MARKED.valid(0, value))
    parent:Release()
end)

test('the MARKED editor shows a saved list and the MARK_COUNT editor shows its filter', function()
    local _, a = W.client('tbc')
    local value = { type = 'MARKED', unit = 'target', mark = 'cross,star' }
    local parent = mount(a, 'MARKED', value)
    assert(parent.children[2]:GetValue() == 'some')

    assert(
        parent.children[4]:GetValue() == true
            and parent.children[10]:GetValue() == true
            and parent.children[3]:GetValue() == false
    )

    parent:Release()
    local count = { type = 'MARK_COUNT', operator = 'EQUALS', value = 1 }
    local second = mount(a, 'MARK_COUNT', count)
    assert(second.children[1]:GetValue() == 'any')
    second.children[1]:Fire('OnValueChanged', 'enemy')
    assert(count.filter == 'enemy')
    second:Release()
end)

test('both conditions show their help', function()
    local _, a = W.client('tbc')

    for _, tag in ipairs({ 'MARKED', 'MARK_COUNT' }) do
        local frame = a:CreateConditionGroup()
        frame:SetWidth(640)
        a.conditionDefinitions[tag].help(frame)
        assert(#frame.children >= 1, tag .. ' help is empty')
        frame:Release()
    end
end)

finish()
