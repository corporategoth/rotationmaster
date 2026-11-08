-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- ENEMIES_TARGETING counts hostile nameplates targeting you (unavailable when the game hides the comparison);
-- RECENT_KILL matches a kill by you or your group within N seconds.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local SECRET = {}

local function fixture()
    local f = F.new(18, 12)
    local a, e = f.addon, f.env

    local s = {
        plates = {
            nameplate1 = { hostile = true, onMe = true },
            nameplate2 = { hostile = true, onMe = false },
            nameplate3 = { hostile = false, onMe = true },
        },
    }

    e.UnitExists = function(token) return s.plates[token] ~= nil end
    e.UnitCanAttack = function(_, token) return s.plates[token] and s.plates[token].hostile end

    e.UnitIsUnit = function(token)
        local plate = s.plates[token:gsub('target$', '')]

        if s.secret then
            return SECRET
        end

        return plate and plate.onMe or false
    end

    for _, file in ipairs({
        'Platform/combat_events.lua',
        'Diagnostics/errors.lua',
        'Core/conditions.lua',
        'Data/plain.lua',
        'Data/tags.lua',
        'Data/rotation_tree.lua',
        'Core/rotation_sequence.lua',
        'Conditions/combat_events.lua',
    }) do
        f.load(file)
    end

    local readable = a.Platform.CanReadValue
    a.Platform.CanReadValue = function(p, v) return v ~= SECRET and readable(p, v) end
    return f, a, s
end

local function status(a, condition)
    return a:evaluateConditionResult(condition).status
end

test('enemies targeting you counts hostile plates whose target is you', function()
    local _, a, s = fixture()
    assert(a.Platform:GetEnemiesTargetingPlayer() == 1)
    s.plates.nameplate2.onMe = true
    assert(a.Platform:GetEnemiesTargetingPlayer() == 2)
    assert(status(a, { type = 'ENEMIES_TARGETING', operator = 'GREATERTHANOREQUALS', value = 2 }) == 'match')
    assert(status(a, { type = 'ENEMIES_TARGETING', operator = 'GREATERTHAN', value = 2 }) == 'no-match')
end)

test('a hidden target comparison is unavailable, also under NOT', function()
    local _, a, s = fixture()
    s.secret = true
    local condition = { type = 'ENEMIES_TARGETING', operator = 'GREATERTHAN', value = 0 }
    assert(status(a, condition) == 'unavailable')
    assert(status(a, { type = 'NOT', value = condition }) == 'unavailable')
end)

test('a recent kill matches within the window only', function()
    local f, a = fixture()
    f.env.GetTime = function() return 100 end
    local condition = { type = 'RECENT_KILL', value = 5 }
    assert(status(a, condition) == 'no-match', 'no kill yet')
    a.Platform:NoteKill(97)
    assert(status(a, condition) == 'match')
    a.Platform:NoteKill(90)
    assert(status(a, condition) == 'no-match')

    assert(
        a.conditionDefinitions.RECENT_KILL.valid(0, { value = 5 })
            and not a.conditionDefinitions.RECENT_KILL.valid(0, {})
    )
end)

finish()
