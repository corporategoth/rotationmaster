local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local a, e = f.addon, f.env
    local s = { party = false, raid = nil, group = true, playerRaid = false, calls = {} }

    -- GROUP dispatch uses a resolver protocol; full native roster resolution has independent event tests.
    a.Platform.GetAnnouncementRecipientGroupMembership = function(self, recipient, raidOnly)
        return self:GetUnitGroupMembership(recipient, raidOnly)
    end

    local function native(key, unit)
        s.calls[#s.calls + 1] = { key, unit }

        if s.throw == key then
            error('native failure')
        end

        return s[key]
    end

    e.IsInGroup = function() return native('group') end
    e.IsInRaid = function() return native('playerRaid') end
    e.UnitInParty = function(unit) return native('party', unit) end
    e.UnitInRaid = function(unit) return native('raid', unit) end

    e.UnitName = function()
        error('no selected target lookup')
    end

    for _, p in ipairs({
        'Platform/groups.lua', 'Diagnostics/errors.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua',
        'Data/rotation_tree.lua', 'Core/rotation_sequence.lua', 'Conditions/character.lua', 'Data/builtin_sources.lua',
        'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
    }) do
        f.load(p)
    end

    e.loadstring = function(code, name)
        local fn, why = loadstring(code, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    return f, a, e, s
end

local function unknown(a, node)
    assert(a:evaluateConditionResult(node).status == 'unavailable')
    assert(a:evaluateConditionResult({ type = 'NOT', value = node }).status == 'unavailable')

    local r = {
        rotation = {
            {
                type = 'branch',
                conditions = node,
                onTrue = { { type = 'spell', action = 1 } },
                onFalse = { { type = 'spell', action = 2 } },
            },
        },
    }

    assert(
        a:EvaluateRotationSequence(r, function(v) return a:evaluateConditionResult(v) end, function()
            error('unknown selected branch')
        end).status == 'unavailable'
    )
end

test('legacy public boolean query contract and player default stay unchanged', function()
    local _, a, _, s = fixture()

    assert(
        a.Platform:GetGroupMembership() == true
            and a.Platform:GetGroupMembership(false) == true
            and a.Platform:GetGroupMembership(true) == false
    )

    assert(
        #s.calls == 3
            and s.calls[1][1] == 'group'
            and s.calls[2][1] == 'group'
            and s.calls[3][1] == 'playerRaid'
            and s.calls[1][2] == nil
    )
end)

test('nil unit adds no new platform observation before legacy evaluator', function()
    local _, a = fixture()
    local original = a.Platform.CanReadValue
    local calls = {}

    a.Platform.CanReadValue = function(self, value)
        calls[#calls + 1] = { value }
        return original(self, value)
    end

    assert(a.conditionDefinitions.GROUP.evaluate({}, {}))
    local actual = calls
    calls = {}
    assert(a.Functions.cache.getCached({}, a.Platform.GetGroupMembership, a.Platform, nil))
    assert(#actual == #calls, 'legacy observation count changed')

    for i, row in ipairs(actual) do
        assert(
            type(row[1]) == type(calls[i][1]) and (type(row[1]) == 'table' or rawequal(row[1], calls[i][1])),
            'legacy observation argument changed'
        )
    end
end)

test('explicit helper normalizes party booleans and nullable raid indexes with short circuit', function()
    local _, a, _, s = fixture()
    s.party = true
    assert(a.Platform:GetUnitGroupMembership('target', false) == true and #s.calls == 1)
    s.calls = {}
    s.party = false
    assert(a.Platform:GetUnitGroupMembership('target') == false and #s.calls == 2)

    for _, index in ipairs({ 1, 40 }) do
        s.calls = {}
        s.raid = index

        assert(
            a.Platform:GetUnitGroupMembership('focus', true) == true
                and #s.calls == 1
                and s.calls[1][1] == 'raid'
                and s.calls[1][2] == 'focus'
        )
    end
end)

test('invalid or unreadable explicit inputs make no native query', function()
    local _, a, e, s = fixture()
    local opaque = {}
    e.issecretvalue = function(v) return rawequal(v, opaque) end

    for _, unit in ipairs({ '', 'bad\nunit', 42, {}, opaque }) do
        assert(a.Platform:GetUnitGroupMembership(unit) == nil)
    end

    assert(
        a.Platform:GetUnitGroupMembership(nil) == nil
            and a.Platform:GetUnitGroupMembership('target', 0) == nil
            and #s.calls == 0
    )

    e.WOW_PROJECT_ID = 999
    assert(a.Platform:GetUnitGroupMembership('target') == nil and #s.calls == 0)
end)

test('unknown party facts never become a raid fallback or false', function()
    for _, mode in ipairs({ 'missing', 'throw', 'nil', 'secret', 'invalid' }) do
        local _, a, e, s = fixture()
        s.raid = 1
        local opaque = {}
        e.canaccessvalue = function(v) return not rawequal(v, opaque) end

        if mode == 'missing' then
            e.UnitInParty = nil
        elseif mode == 'throw' then
            s.throw = 'party'
        elseif mode == 'nil' then
            s.party = nil
        elseif mode == 'secret' then
            s.party = opaque
        else
            s.party = 1
        end

        local result, why = a.Platform:GetUnitGroupMembership('target')
        assert(result == nil and why, mode)

        for _, call in ipairs(s.calls) do
            assert(call[1] ~= 'raid')
        end
    end
end)

test('raid nil is known nonmember but malformed indexes are unavailable', function()
    local _, a, e, s = fixture()
    assert(a.Platform:GetUnitGroupMembership('target', true) == false)

    for _, bad in ipairs({ false, true, 0, -1, 41, 1.5, math.huge, 0 / 0, '1', {} }) do
        s.raid = bad
        assert(a.Platform:GetUnitGroupMembership('target', true) == nil)
    end

    e.UnitInRaid = nil
    assert(a.Platform:GetUnitGroupMembership('target', true) == nil)
end)

test('nil and explicit player GROUP share exactly the legacy cached route', function()
    local _, a, _, s = fixture()
    local cache = {}
    local d = a.conditionDefinitions.GROUP
    assert(d.valid(0, {}) and d.valid(0, { unit = 'player' }))
    assert(d.evaluate({}, cache) == true and d.evaluate({ unit = 'player' }, cache) == true)
    assert(#s.calls == 1 and s.calls[1][1] == 'group')
    assert(a:printCondition({ type = 'GROUP' }, 0) == a:printCondition({ type = 'GROUP', unit = 'player' }, 0))
end)

test('unit GROUP evaluates selected membership and preserves known false through NOT', function()
    local _, a, _, s = fixture()
    assert(a.conditionDefinitions.GROUP.valid(0, { unit = 'target' }))
    assert(a:evaluateConditionResult({ type = 'GROUP', unit = 'target' }).status == 'no-match')
    assert(a:evaluateConditionResult({ type = 'NOT', value = { type = 'GROUP', unit = 'target' } }).status == 'match')
    s.raid = 1
    assert(a:evaluateConditionResult({ type = 'GROUP', unit = 'target', raid = true }).status == 'match')
    s.party = nil
    unknown(a, { type = 'GROUP', unit = 'focus' })
end)

test('spellrecipient requires exact raw event cache and cannot borrow selected target', function()
    local _, a, e, s = fixture()
    local d = a.conditionDefinitions.GROUP
    assert(d.valid(0, { unit = 'spellrecipient' }))
    local inherited = setmetatable({}, { __index = { announcementRecipient = 'Inherited-Name' } })
    local result, why = d.evaluate({ unit = 'spellrecipient' }, inherited)
    assert(result == nil and why == 'cast-recipient-unavailable' and #s.calls == 0)
    result, why = d.evaluate({ unit = 'spellrecipient' }, nil)
    assert(result == nil and why == 'cast-recipient-unavailable')
    local opaque = {}
    e.issecretvalue = function(v) return rawequal(v, opaque) end
    result, why = d.evaluate({ unit = 'spellrecipient' }, { announcementRecipient = opaque })
    assert(result == nil and why == 'cast-recipient-unavailable' and #s.calls == 0)
    s.party = true
    assert(d.evaluate({ unit = 'spellrecipient' }, { announcementRecipient = 'Exact-Recipient' }) == true)
    assert(#s.calls == 1 and s.calls[1][2] == 'Exact-Recipient')
end)

test('event membership cache is per recipient and fresh invocation', function()
    local _, a, _, s = fixture()
    local d = a.conditionDefinitions.GROUP
    local cache = { announcementRecipient = 'One' }
    s.party = true
    assert(d.evaluate({ unit = 'spellrecipient' }, cache))
    assert(d.evaluate({ unit = 'spellrecipient' }, cache))
    assert(#s.calls == 1)
    cache.announcementRecipient = 'Two'
    assert(d.evaluate({ unit = 'spellrecipient' }, cache))
    assert(#s.calls == 2 and s.calls[2][2] == 'Two')
    s.party = false
    s.raid = nil
    assert(d.evaluate({ unit = 'spellrecipient' }, { announcementRecipient = 'One' }) == false)
end)

test('unit summaries keep user labels literal under NOT and whole-phrase translations', function()
    local f, a = fixture()
    local label = '{{!private|changed}} {unit} 50%'
    a.units.target = label
    local node = { type = 'GROUP', unit = 'target' }
    local positive = a:printCondition(node, 0)
    local negative = a:printCondition({ type = 'NOT', value = node }, 0)
    assert(positive == label .. ' is in a group' and negative == label .. ' is not in a group')
    f.translations['{unit} {{!is|is not}} in a group'] = '{{!is|is not}} grouped: {unit}'
    assert(a:printCondition(node, 0) == 'is grouped: ' .. label)
    assert(a:printCondition({ type = 'NOT', value = { type = 'NOT', value = node } }, 0) == a:printCondition(node, 0))
end)

test('unit widget offers event recipient only in announcement context or existing reserved value', function()
    local _, a = fixture()
    local d = a.conditionDefinitions.GROUP

    for _, case in ipairs({ { false, nil, false }, { true, nil, true }, { false, 'spellrecipient', true } }) do
        local top = {
            GetUserData = function(_, key)
                if key == 'announcement' then
                    return case[1]
                elseif key == 'funcs' then
                    return { print = function() return '' end }
                end
            end,
            SetStatusText = function() end,
        }

        local children = {}

        local parent = {
            GetUserData = function() return top end,
            AddChild = function(_, child)
                children[#children + 1] = child
            end,
        }

        local before = a:CopySettingsData(a.units)
        local v = { unit = case[2] }
        d.widget(parent, 0, v)
        assert(#children == 2, 'missing unit selector')
        local unit = children[1]
        unit.configure()
        assert((unit.list.spellrecipient ~= nil) == case[3] and a:SettingsDataEqual(a.units, before))
        assert(v.unit == case[2], 'draw changed saved default')
    end
end)

test('source clones retain new behavior and old archived evaluator stays executable', function()
    local _, a, _, s = fixture()
    local source = assert(a:GetBuiltinConditionSource('GROUP'))
    assert(source.fields.unit == 'string')
    local clone = assert(a:CompileCustomCondition('COPY_GROUP_UNIT', source))
    a:RegisterCondition('COPY_GROUP_UNIT', clone)
    s.party = true
    assert(a:evaluateConditionResult({ type = 'COPY_GROUP_UNIT', unit = 'target' }).status == 'match')
    s.party = nil
    unknown(a, { type = 'COPY_GROUP_UNIT', unit = 'target' })
    local archive = a:CopySettingsData(source)
    archive.evaluate = 'return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)'
    local old = assert(a:CompileCustomCondition('ARCHIVE_GROUP', archive))
    assert(old.evaluate({ unit = 'target' }, {}) == true)
    local id = 'builtin:Platform/groups.lua:Platform_GetGroupMembership'
    assert(a:ResolveFunctionBinding(id) == a.Platform.GetGroupMembership)
    local fresh = 'builtin:Platform/groups.lua:Platform_GetUnitGroupMembership'
    assert(a:ResolveFunctionBinding(fresh) == a.Platform.GetUnitGroupMembership)
end)

test('new public helper source clone keeps receiver and exact native tuple', function()
    local _, a, _, s = fixture()
    local id = 'builtin:Platform/groups.lua:Platform_GetUnitGroupMembership'
    local record = assert(a.builtinFunctions[id])

    assert(
        record.source.args[1].name == 'self'
            and record.source.args[2].name == 'unit'
            and record.source.args[3].name == 'raidOnly'
    )

    assert(a:InstallCustomFunction('COPY_UNIT_MEMBERSHIP', a:CopySettingsData(record.source)))
    local fn = assert(a:ResolveFunctionBinding('COPY_UNIT_MEMBERSHIP'))
    s.raid = 4
    assert(fn(a.Platform, 'Recipient-Realm', true) == true and #s.calls == 1 and s.calls[1][2] == 'Recipient-Realm')
end)

finish()
