-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- NEXT_SWING reads the game's swing timer (PLAYER_SWING): seconds to the next swing per hand, 0 while none is under way,
-- and it exists only where the client has C_SwingTimer.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project, timer)
    local f = F.new(project or 18, 12)
    f.env.C_SwingTimer = timer ~= false and { IsTargetWithinSwingRange = function() return true end } or nil

    for _, file in ipairs({
        'Platform/swing_timer.lua', 'Diagnostics/errors.lua', 'Core/conditions.lua', 'Core/condition_support.lua',
        'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua', 'Core/rotation_sequence.lua',
        'Conditions/swing_timer.lua'
    }) do
        f.load(file)
    end

    return f, f.addon
end

test('the next swing counts down per hand from each swing', function()
    local f, a = fixture()
    local p = a.Platform
    assert(p:GetNextSwingObservation(false, 100) == 0, 'no swing yet')
    p:NoteSwing(100, 2.6, 0)
    p:NoteSwing(100.5, 1.8, 1)
    assert(math.abs(p:GetNextSwingObservation(false, 101) - 1.6) < 1e-9)
    assert(math.abs(p:GetNextSwingObservation(true, 101) - 1.3) < 1e-9)
    assert(p:GetNextSwingObservation(false, 110) == 0, 'finished swing')
    assert(p:GetLastSwingDuration(false) == 2.6)
    f.env.GetTime = function() return 101 end
    assert(a:evaluateConditionResult({ type = 'NEXT_SWING', operator = 'LESSTHAN', value = 2 }).status == 'match')
    local off = { type = 'NEXT_SWING', offhand = true, operator = 'LESSTHAN', value = 1 }
    assert(a:evaluateConditionResult(off).status == 'no-match')
end)

test('malformed swings are ignored', function()
    local _, a = fixture()
    local p = a.Platform
    p:NoteSwing(100, -1, 0)
    p:NoteSwing(100, 2, 2)
    p:NoteSwing(100, 'x', 0)
    assert(p:GetNextSwingObservation(false, 100.5) == 0 and p:GetLastSwingDuration(false) == nil)
end)

test('it exists only where the client has the swing timer', function()
    local _, a = fixture(18)
    local value = { type = 'NEXT_SWING', operator = 'LESSTHAN', value = 1 }
    assert(a:GetConditionSupport('NEXT_SWING', a.conditionDefinitions.NEXT_SWING, value) == nil)
    local _, b = fixture(1, false)
    assert(b:GetConditionSupport('NEXT_SWING', b.conditionDefinitions.NEXT_SWING, value) == 'missing-api')
end)

finish()
