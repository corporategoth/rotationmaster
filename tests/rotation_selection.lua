local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.addon.RotationData = make()
    f.addon.usefulCondition = function(_, value) return value and value.type ~= nil end
    f.addon.validateCondition = function(_, value) return value == nil or not value.invalid end
    f.addon.rotationValidConditions = function(_, value) return not value.invalid end
    f.addon.IsDefaultRuntimeRotation = function(_, _, id) return id:sub(1, 5) == 'pack:' end
    f.load('Core/rotation_selection.lua')
    return f.addon
end

local function body(name, priority)
    return {
        name = name,
        priority = priority,
        switch = { type = 'COMBAT' },
        rotation = { { type = 'spell', action = 403 } },
    }
end

test('explicit priorities sort high first, packs and yours alike, with stable name and identity ties', function()
    local a = fixture()

    local rows = {
        z = body('Same', 7),
        a = body('Same', 7),
        b = body('Before', 7),
        low = body('A', -2),
        ['pack:high'] = body('Pack', 1000),
        ['pack:tie'] = body('Bz', 7),
    }

    local order = a:GetOrderedAutoSwitchRotations(0, rows)
    assert(table.concat(order, ',') == 'pack:high,b,pack:tie,a,z,low', table.concat(order, ','))
    assert(rows.low.priority == -2 and rows.a.name == 'Same', 'selection mutated saved rotations')
end)

test(
    'missing priorities retain alphabetical behavior and invalid or disabled candidates stay out; no switch condition is a candidate',
    function()
        local a = fixture()

        local rows = {
            z = body('Z'),
            a = body('A'),
            disabled = body('Disabled', 9),
            invalid = body('Invalid', 10),
            missing = body('Missing', 50),
            fraction = body('Fraction', 1.5),
            bad = body('Bad', '7'),
            huge = body('Huge', 100001),
            [F.new().env.DEFAULT] = body('Fallback', 100000),
        }

        rows.disabled.disabled = true
        rows.invalid.invalid = true
        rows.missing.switch = {}
        local order = a:GetOrderedAutoSwitchRotations(0, rows)
        -- missing has an empty switch: no switch condition matches, so it ranks by priority like the rest.
        assert(table.concat(order, ',') == 'missing,a,z' and rows.a.priority == nil, table.concat(order, ','))
        rows.missing.switch = nil

        assert(
            table.concat(a:GetOrderedAutoSwitchRotations(0, rows), ',') == 'missing,a,z',
            'an absent switch is no switch: ' .. table.concat(a:GetOrderedAutoSwitchRotations(0, rows), ',')
        )
    end
)

test('rotation priority validates portable integer bounds and missing zero without normalizing saved bodies', function()
    local d, envelope, options = make()
    local value = envelope()
    assert(d.GetRotationPriority, 'priority helper missing')
    assert(d.GetRotationPriority(nil) == 0)

    for _, priority in ipairs({ -100000, 0, 100000 }) do
        value.body.priority = priority
        assert(d.ValidateEnvelope(value, options).valid)
    end

    for _, priority in ipairs({ -100001, 100001, .5, '3', false }) do
        value.body.priority = priority
        assert(not d.ValidateEnvelope(value, options).valid)
    end

    value.body.priority = nil
    assert(d.ValidateEnvelope(value, options).valid and value.body.priority == nil)
end)

finish()
