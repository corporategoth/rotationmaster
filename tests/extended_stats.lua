-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

-- Installed ExtendedCharacterStats Modules/Data/Data.lua defines the public
-- entry point as Data.GetStatInfo(refName), not a receiver method.
local function fixture()
    local f = F.new()
    local a, e = f.addon, f.env
    a.delayed_condition = {}
    local state = { imports = 0, calls = {}, power = 42, chance = '25%' }

    local data = {
        GetStatInfo = function(...)
            assert(select('#', ...) == 1, 'GetStatInfo received an implicit receiver')
            local name = ...
            assert(type(name) == 'string', 'refName must be a string')
            state.calls[#state.calls + 1] = name

            if state.fail then
                error('ECS stat failed')
            end

            if name == 'Power' then
                return state.power
            elseif name == 'Chance' then
                return state.chance
            end

            error('unexpected stat: ' .. name)
        end,
    }

    e.ECSLoader = {
        ImportModule = function(self, name)
            assert(self == e.ECSLoader and name == 'Data')
            state.imports = state.imports + 1
            return data
        end,
    }

    e.ExtendedCharacterStats = {
        profile = {
            refName = 'RootHeader',
            text = 'Stats',
            power = { refName = 'Power', text = 'Power' },
            nested = { refName = 'ChanceHeader', text = 'Chances', chance = { refName = 'Chance', text = 'Chance' } },
        },
    }

    for _, p in ipairs({
        'Diagnostics/errors.lua',
        'Core/conditions.lua',
        'Conditions/common.lua',
        'Conditions/ext_stats.lua',
        'Data/builtin_sources.lua',
        'Core/builtin_sources.lua',
        'Core/custom_authoring.lua',
        'Core/function_data.lua',
    }) do
        f.load(p)
    end

    for tag, definition in pairs(a.delayed_condition.ExtendedCharacterStats) do
        a:RegisterCondition(tag, definition)
    end

    e.loadstring = function(text, name)
        local fn, why = loadstring(text, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    return f, a, state, data
end

test('deferred ECS registration uses the actual dot API and initializes both condition kinds once', function()
    local _, a, s = fixture()
    assert(s.imports == 1 and #s.calls == 2)
    assert(a.conditionDefinitions.ECS_STAT.valid(0, { stat = 'Power', operator = 'EQUALS', value = 42 }))
    assert(a.conditionDefinitions.ECS_STAT_PCT.valid(0, { stat = 'Chance', operator = 'EQUALS', value = .25 }))
    assert(not a.conditionDefinitions.ECS_STAT.valid(0, { stat = 'Chance', operator = 'EQUALS', value = 42 }))
    assert(not a.conditionDefinitions.ECS_STAT_PCT.valid(0, { stat = 'RootHeader', operator = 'EQUALS', value = .25 }))
    a.conditionDefinitions.ECS_STAT.on_register()
    assert(s.imports == 1 and #s.calls == 2)
end)

test('ECS native and source-clone callbacks share the one-argument observation cache', function()
    local _, a, s = fixture()
    local clones = {}

    for _, tag in ipairs({ 'ECS_STAT', 'ECS_STAT_PCT' }) do
        clones[tag] = assert(a:CompileCustomCondition('COPY_' .. tag, assert(a:GetBuiltinConditionSource(tag))))
        clones[tag].on_register()
    end

    s.calls = {}
    local cache = {}

    for _, entry in ipairs({ { 'ECS_STAT', 'Power', 42 }, { 'ECS_STAT_PCT', 'Chance', .25 } }) do
        local value = { stat = entry[2], operator = 'EQUALS', value = entry[3] }

        assert(
            a.conditionDefinitions[entry[1]].evaluate(value, cache) == true
                and clones[entry[1]].evaluate(value, cache) == true
        )
    end

    assert(#s.calls == 2 and s.imports == 1)
    s.power = 7
    s.chance = '50.5%'
    assert(clones.ECS_STAT.evaluate({ stat = 'Power', operator = 'EQUALS', value = 7 }, {}) == true)
    assert(clones.ECS_STAT_PCT.evaluate({ stat = 'Chance', operator = 'EQUALS', value = .505 }, {}) == true)
end)

test('provider failures remain unavailable under negation instead of authorizing an action', function()
    local _, a, s = fixture()
    s.fail = true
    local value = { type = 'ECS_STAT', stat = 'Power', operator = 'EQUALS', value = 42 }

    assert(
        a:evaluateConditionResult(value).status == 'unavailable'
            and a:evaluateConditionResult({ type = 'NOT', value = value }).status == 'unavailable'
    )
end)

finish()
