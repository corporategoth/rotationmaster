local restoreCreature = dofile('tests/fixtures/restore_creature_type_repairs.lua')
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local classID = 'builtin:Conditions/character.lua:character_class'

local function fixture(project, initial)
    local f = F.new(project or 11, 2, 'MAGE')
    local a, e = f.addon, f.env
    e.LOCALIZED_CLASS_NAMES_MALE = { MAGE = 'Mage', SHAMAN = 'Shaman', WARRIOR = 'Warrior' }

    local s = {
        group = false,
        raid = false,
        classes = { player = initial or 'MAGE' },
        exists = { player = true },
        calls = {},
    }

    if initial == 'nil' then
        s.classes.player = false
    end

    local function call(name, ...)
        s.calls[#s.calls + 1] = { name, n = select('#', ...), ... }

        if s.throw == name then
            error('native failure')
        end
    end

    e.IsInGroup = function(...)
        assert(select('#', ...) == 0)
        call('group', ...)
        return s.group
    end

    e.IsInRaid = function(...)
        assert(select('#', ...) == 0)
        call('raid', ...)
        return s.raid
    end

    e.UnitExists = function(...)
        assert(select('#', ...) == 1)
        local unit = ...
        call('exists', ...)
        local value = s.exists[unit]

        if value == nil then
            return false
        end

        return value
    end

    e.UnitClass = function(...)
        assert(select('#', ...) == 1)
        local unit = ...
        call('class', ...)
        local value = s.classes[unit]

        if value == false then
            value = nil
        end

        return s.label, value, s.id, s.tail
    end

    for _, path in ipairs({ 'Platform/roster_class.lua', 'Core/class_group_conditions.lua' }) do
        local file = io.open(path)

        if file then
            file:close()
            f.load(path)
        end
    end

    for _, path in ipairs({
        'Diagnostics/errors.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua', 'Conditions/character.lua', 'Data/builtin_sources.lua',
        'Core/builtin_sources.lua', 'Core/custom_authoring.lua', 'Core/function_data.lua'
    }) do
        f.load(path)
    end

    e.loadstring = function(text, name)
        local fn, why = loadstring(text, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    s.calls = {}
    return f, a, s
end

local function node(n, raid, class, op)
    return {
        type = 'CLASS_GROUP',
        class = class or 'MAGE',
        operator = op or 'EQUALS',
        value = n == nil and 1 or n,
        raid = raid,
    }
end

local function unknown(a, value)
    assert(a.conditionDefinitions.CLASS_GROUP.valid(0, value), 'unknown test fields invalid')

    for _, v in ipairs({
        value,
        { type = 'NOT', value = value },
        { type = 'AND', value = { value } },
        { type = 'OR', value = { { type = 'NOT', value = value } } },
    }) do
        local result = a:evaluateConditionResult(v)

        assert(
            result.status == 'unavailable'
                and result.reason ~= 'condition-callback-error'
                and result.reason ~= 'invalid-condition-fields',
            tostring(result.status) .. ':' .. tostring(result.reason)
        )
    end

    for _, v in ipairs({ value, { type = 'NOT', value = value } }) do
        local body = {
            rotation = {
                {
                    id = 'guard',
                    type = 'branch',
                    conditions = v,
                    onTrue = { { id = 'yes', type = 'spell', action = 1 } },
                    onFalse = { { id = 'no', type = 'spell', action = 2 } },
                },
            },
        }

        assert(
            a:EvaluateRotationSequence(body, function(x) return a:evaluateConditionResult(x) end, function()
                error('unknown roster selected branch')
            end).status == 'unavailable'
        )
    end
end

local function count(s, name)
    local n = 0

    for _, call in ipairs(s.calls) do
        if call[1] == name then
            n = n + 1
        end
    end

    return n
end

local function raw(a)
    local source = assert(a:GetBuiltinConditionSource('CLASS_GROUP'))
    source.evaluate = dofile('tests/fixtures/restore_class_group_repairs.lua')(source.evaluate, true)
    source.bindings.character_class = classID
    return source
end

test('membership unknowns stay closed under valid direct negated grouped and branch evaluation', function()
    for _, which in ipairs({ 'group', 'raid' }) do
        for _, mode in ipairs({ 'missing', 'nil', 'throw', 'restricted', 0, 'true', {} }) do
            local f, a, s = fixture()
            s.group = true
            local opaque = {}
            f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

            if mode == 'missing' then
                f.env[which == 'group' and 'IsInGroup' or 'IsInRaid'] = nil
            elseif mode == 'nil' then
                s[which] = nil
            elseif mode == 'throw' then
                s.throw = which
            elseif mode == 'restricted' then
                s[which] = opaque
            else
                s[which] = mode
            end

            unknown(a, node(1, true))
        end
    end
end)

test('required existence and class failures remain unavailable across real logical wrappers', function()
    for _, fact in ipairs({ 'exists', 'class' }) do
        for _, mode in ipairs({ 'missing', 'nil', 'throw', 'restricted', 'empty', 0, true, {} }) do
            local f, a, s = fixture()
            local opaque = {}
            f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
            local name = fact == 'exists' and 'UnitExists' or 'UnitClass'

            if mode == 'missing' then
                f.env[name] = nil
            elseif mode == 'throw' then
                s.throw = fact
            elseif fact == 'exists' then
                local value = mode == 'restricted' and opaque or mode == 'empty' and '' or mode

                if mode == 'nil' then
                    f.env.UnitExists = function() return nil end
                else
                    s.exists.player = value
                end
            else
                local value = mode == 'restricted' and opaque or mode == 'empty' and '' or mode

                if mode == 'nil' then
                    s.classes.player = false
                else
                    s.classes.player = value
                end
            end

            -- True is the one valid existence observation and is covered by positive controls.
            if not (fact == 'exists' and mode == true) then
                unknown(a, node())
            end
        end
    end
end)

test('known solo and exact lazy party or raid order consume no inferred roster counts', function()
    local _, a, s = fixture()
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(), {}))

    assert(
        #s.calls == 3
            and s.calls[1][1] == 'group'
            and s.calls[2][1] == 'exists'
            and s.calls[2][2] == 'player'
            and s.calls[3][1] == 'class'
    )

    s.calls = {}
    s.group = true
    s.throw = 'raid'
    s.exists.party2 = true
    s.classes.party2 = 'MAGE'
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(2, false), {}))
    assert(count(s, 'raid') == 0 and count(s, 'exists') == 5 and count(s, 'class') == 2)

    local order = {
        { 'group' },
        { 'exists', 'player' },
        { 'class', 'player' },
        { 'exists', 'party1' },
        { 'exists', 'party2' },
        { 'class', 'party2' },
        { 'exists', 'party3' },
        { 'exists', 'party4' },
    }

    assert(#s.calls == #order)

    for i, expected in ipairs(order) do
        assert(s.calls[i][1] == expected[1] and s.calls[i][2] == expected[2], 'party observation order changed')
    end

    s.calls = {}
    s.throw = nil
    s.raid = true
    s.exists = { raid40 = true }
    s.classes = { raid40 = 'MAGE' }
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(1, true), {}))
    assert(count(s, 'exists') == 40 and count(s, 'class') == 1)

    for i = 1, 40 do
        assert(s.calls[i + 2][1] == 'exists' and s.calls[i + 2][2] == 'raid' .. i)
    end
end)

test('present unknown class cannot become absent or partial count even after positive matches', function()
    for _, unit in ipairs({ 'player', 'party1', 'party4', 'raid40' }) do
        local _, a, s = fixture()
        s.group = unit ~= 'player'
        s.raid = unit == 'raid40'
        s.exists[unit] = true
        s.classes[unit] = false
        unknown(a, node(1, s.raid))
    end

    local _, a, s = fixture()
    s.group = true
    s.exists.party4 = true
    s.classes.party4 = false
    unknown(a, node(0, false, 'WARRIOR', 'NOTEQUALS'))
end)

test('current player failure and live changes recover per pass while raid does not require player', function()
    local _, a, s = fixture(nil, 'nil')
    unknown(a, node())
    s.classes.player = 'MAGE'
    assert(a:evaluateConditionResult(node()).status == 'match')
    s.classes.player = 'SHAMAN'
    assert(a:evaluateConditionResult(node(1, false, 'SHAMAN')).status == 'match')
    s.group = true
    s.raid = true
    s.exists = { raid1 = true }
    s.classes = { raid1 = 'MAGE' }
    s.calls = {}
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(1, true), {}))

    for _, call in ipairs(s.calls) do
        assert(call[2] ~= 'player')
    end
end)

test('known absence zero fractional thresholds optional raid and future class strings keep their meanings', function()
    local _, a, s = fixture()
    s.exists.player = false
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(0), {}))
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(.5, nil, 'MAGE', 'LESSTHAN'), {}))
    s.exists.player = true
    s.classes.player = 'FUTURE_CLASS'
    assert(a:GetClassGroupCount({}, 'FUTURE_CLASS', nil) == 1)
    s.group = true
    s.raid = false
    s.exists.party1 = true
    s.classes.party1 = 'MAGE'
    s.classes.player = 'MAGE'
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(2, true), {}))
    s.throw = 'raid'
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(2, nil), {}))

    for _, value in ipairs({ 0, 'true', {} }) do
        unknown(a, node(2, value))
    end
end)

test('unused class tuple fields are ignored and selected observations snapshot complete results by pass', function()
    local _, a, s = fixture()
    s.label = {}
    s.id = {}
    s.tail = {}
    local cache = {}
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(), cache))
    s.classes.player = 'SHAMAN'
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(), cache) and count(s, 'class') == 1)

    assert(
        a.conditionDefinitions.CLASS_GROUP.evaluate(node(1, nil, 'SHAMAN'), {})
            and a.conditionDefinitions.CLASS_GROUP.evaluate(node(1, nil, 'SHAMAN'))
    )

    local _, a, s = fixture()
    s.classes.player = false
    cache = {}
    local value, why = a.conditionDefinitions.CLASS_GROUP.evaluate(node(), cache)
    assert(value == nil and why)
    s.classes.player = 'MAGE'
    local again, reason = a.conditionDefinitions.CLASS_GROUP.evaluate(node(), cache)
    assert(again == nil and reason == why)
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(), {}))
end)

test('unknown-family refusal and public roster policy remain distinct from combat policy', function()
    for _, project in ipairs({ 1, 2, 5, 11, 14, 18, 19 }) do
        local _, a = fixture(project)
        assert(a:evaluateConditionResult(node()).status == 'match')
    end

    local _, a, s = fixture(999)
    unknown(a, node())
    assert(#s.calls == 0)
end)

test('actual current editable clone shares normalized observations and has no frozen class requirement', function()
    local _, a, s = fixture()
    local source = assert(a:GetBuiltinConditionSource('CLASS_GROUP'))
    assert(not source.bindings.character_class, 'current source retains historical capture')
    assert(source.evaluate:find('GetClassGroupCount', 1, true), 'catalog stale')
    local clone = assert(a:CompileCustomCondition('COPY_CLASS_GROUP', source))
    a:RegisterCondition('COPY_CLASS_GROUP', clone)
    local cache = {}
    assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(), cache))
    assert(clone.evaluate(node(), cache))
    assert(count(s, 'group') == 1 and count(s, 'class') == 1)
end)

test('actual old raw source preserves known and nil lexical capture and unchanged requirement bundles', function()
    for _, initial in ipairs({ 'MAGE', 'nil' }) do
        local _, a, s = fixture(nil, initial)
        local source = raw(a)
        local before = a:CopySettingsData(source)
        local clone = assert(a:CompileCustomCondition('RAW_GROUP', source))
        s.classes.player = 'SHAMAN'
        assert(clone.evaluate(node(initial == 'MAGE' and 1 or 0), {}))
        assert(a.conditionDefinitions.CLASS_GROUP.evaluate(node(1, nil, 'SHAMAN'), {}))
        assert(a:SettingsDataEqual(source, before))

        local dependency = {
            description = 'Historical class value consumer',
            args = {},
            returns = {},
            bindings = { frozen = classID },
            code = 'return frozen',
        }

        local bundle = assert(a:BuildFunctionBundle('function', 'OLD_CLASS', dependency, false))

        assert(
            #bundle.requirements == 1
                and bundle.requirements[1].id == classID
                and bundle.requirements[1].hash == 'f9f4e4b5'
        )

        local original = a:CopySettingsData(bundle)
        local plan = assert(a:PlanFunctionBundleImport(bundle))
        assert(plan.valid and a:ApplyFunctionBundleImport(plan))
        assert(a:ResolveFunctionBinding('OLD_CLASS')() == (initial == 'MAGE' and 'MAGE' or nil))
        assert(a:SettingsDataEqual(bundle, original))
        bundle.requirements[1].hash = '00000000'
        assert(not assert(a:PlanFunctionBundleImport(bundle)).valid)
    end
end)

test('public count and roster source clones keep receiver cache and runtime query contracts', function()
    local f, a, s = fixture()
    local clones = {}

    for _, entry in ipairs({
        { 'Core/class_group_conditions.lua', 'GetClassGroupCount' },
        { 'Platform/roster_class.lua', 'Platform_GetRosterClassObservation' },
    }) do
        local id = 'builtin:' .. entry[1] .. ':' .. entry[2]
        local source = assert(a.builtinFunctions[id], 'public helper catalog stale').source
        assert(source.args[1].name == 'self' and source.description ~= '')
        assert(a:InstallCustomFunction('COPY_' .. entry[2], source))
        clones[entry[2]] = assert(a:ResolveFunctionBinding('COPY_' .. entry[2]))
    end

    local cache = {}
    assert(clones.GetClassGroupCount(a, cache, 'MAGE', nil) == 1)
    s.classes.player = 'SHAMAN'
    assert(clones.GetClassGroupCount(a, cache, 'MAGE', nil) == 1 and count(s, 'class') == 1)
    assert(clones.GetClassGroupCount(a, {}, 'SHAMAN', false) == 1)
    local observed, reason = clones.Platform_GetRosterClassObservation(a.Platform, 'party01')
    assert(observed == nil and reason == 'invalid-roster-unit')
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
    s.classes.player = opaque
    observed, reason = clones.GetClassGroupCount(a, {}, 'MAGE', false)
    assert(observed == nil and reason == 'restricted-value')
    -- Cache keys include the actual receiver, rather than only the native unit token.
    local other = setmetatable({}, { __index = a.Platform })
    local calls = 0

    other.GetRosterClassObservation = function(self, unit)
        assert(self == other and unit == 'player')
        calls = calls + 1
        return 'MAGE'
    end

    local second = setmetatable({ Platform = other }, { __index = a })
    cache = {}
    s.classes.player = 'SHAMAN'
    assert(a:GetClassGroupCount(cache, 'SHAMAN', nil) == 1)
    assert(clones.GetClassGroupCount(second, cache, 'MAGE', nil) == 1 and calls == 1)
end)

finish()
