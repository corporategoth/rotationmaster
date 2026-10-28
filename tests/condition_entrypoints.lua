local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local a = f.addon
    local calls = { lookups = 0 }
    a.conditionDefinitions = { A = { description = 'Original condition' } }

    a.conditionSpecials = {
        DELETE = { icon = 'delete', desc = 'Delete' },
        AND = { icon = 'and', desc = 'All' },
        OR = { icon = 'or', desc = 'Any' },
        NOT = { icon = 'not', desc = 'Unless' },
    }

    local lib = f.env.LibStub

    f.env.LibStub = function(name, ...)
        if name == 'AceGUI-3.0' then
            calls.lookups = calls.lookups + 1

            if calls.poison then
                error('Ace lookup forbidden')
            end
        end

        return lib(name, ...)
    end

    return f, a, calls
end

test('native entry points forward exact arguments and return tuples without any Ace dependency', function()
    local f, a, calls = fixture()
    calls.poison = true
    f.load('UI/condition_entrypoints.lua')
    local value, callback, target = {}, {}, {}

    a.ShowConditionEditor = function(self, index, spec, v, cb, valid)
        assert(self == a and index == 4 and spec == 2 and v == value and cb == callback and valid == target)
        return nil, 'native', nil, 7
    end

    local function results(...)
        assert(select('#', ...) == 4)
        local first, why, third, last = ...
        assert(first == nil and why == 'native' and third == nil and last == 7)
    end

    results(a:EditCondition(4, 2, value, callback, target))
    local frame = {}

    frame.rmCompactRefresh = function(...)
        assert(select('#', ...) == 0)
        return 'compact', nil, 3
    end

    local function compact(...)
        assert(select('#', ...) == 3)
        local first, second, last = ...
        assert(first == 'compact' and second == nil and last == 3)
    end

    compact(a.LayoutConditionFrame(frame))
    assert(calls.lookups == 0)
end)

test('missing native editors and unsupported hosts never revive or mutate a legacy renderer', function()
    local f, a, calls = fixture()
    calls.poison = true
    f.load('UI/condition_entrypoints.lua')

    a.GetLegacyConditionRenderer = function()
        error('retired renderer was invoked')
    end

    local value = { unchanged = true }

    local callback = function()
        error('unsupported edit called callback')
    end

    local result, why = a:EditCondition(1, 0, value, callback, function() return true end)
    assert(result == nil and type(why) == 'string' and why:find('native', 1, true))
    local frame = { marker = {}, rmCompactRefresh = true }
    local marker = frame.marker
    result, why = a.LayoutConditionFrame(frame)

    assert(
        result == nil
            and type(why) == 'string'
            and frame.marker == marker
            and frame.rmCompactRefresh == true
            and value.unchanged
    )

    result, why = a.LayoutConditionFrame(nil)
    assert(result == nil and type(why) == 'string' and calls.lookups == 0)
end)

test('custom transfer rejects foreign editor owners before touching callbacks visibility or source', function()
    local f, a, calls = fixture()
    calls.poison = true
    f.load('UI/custom_condition_transfer.lua')
    local owner = {}
    local parent = { rmConditionOwner = owner }

    parent.Hide = function()
        error('foreign editor hidden')
    end

    parent.SetCallback = function()
        error('foreign callbacks changed')
    end

    a.NewRotationCodec = function()
        error('foreign transfer encoded source')
    end

    local source = { description = 'Preserve' }

    local result, why = a:ShowCustomConditionTransfer(
        parent,
        function()
            error('foreign update')
        end,
        'ID',
        source
    )

    assert(
        result == nil
            and type(why) == 'string'
            and why:find('Native', 1, true)
            and parent.rmConditionOwner == owner
            and source.description == 'Preserve'
            and calls.lookups == 0
    )
end)

finish()
