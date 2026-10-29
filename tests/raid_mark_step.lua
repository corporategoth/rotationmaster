-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Direct Set Mark behavior at the platform and whole-rotation levels.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local W = dofile('tests/fixtures/raid_mark_world.lua')

test('Retail and Forever never call the protected mark API', function()
    for _, family in ipairs({ 'retail', 'forever' }) do
        local _, a, e = W.client(family)
        local calls = 0

        e.SetRaidTarget = function()
            calls = calls + 1
        end

        assert(not a.Platform:TrySetRaidMark({ unit = 'target', action = 'skull' }))
        assert(not a.Platform:TrySetRaidMark({ unit = 'target', action = 'highest_unset' }))
        assert(calls == 0, family .. ' called SetRaidTarget')
    end
end)

test('highest unset selects the first unused mark', function()
    local _, a, e, w = W.client('tbc')
    local selected

    e.SetRaidTarget = function(unit, mark)
        selected = { unit, mark }
    end

    assert(a.Platform:TrySetRaidMark({ unit = 'target', action = 'highest_unset' }))
    assert(selected[1] == 'target' and selected[2] == 8)
    w:set('focus', { guid = 'skull', mark = 8, enemy = true })
    w:fire('RAID_TARGET_UPDATE')
    assert(a.Platform:TrySetRaidMark({ unit = 'target', action = 'highest_unset' }))
    assert(selected[2] == 7)
end)

test('each unit and marker is passed directly to SetRaidTarget', function()
    local _, a, e = W.client('tbc')
    local calls = {}

    e.SetRaidTarget = function(unit, mark)
        calls[#calls + 1] = { unit, mark }
    end

    for _, unit in ipairs({ 'player', 'target', 'focus', 'mouseover', 'pet', 'targettarget', 'focustarget' }) do
        for index, action in ipairs({
            'none', 'star', 'circle', 'diamond', 'triangle', 'moon', 'square', 'cross', 'skull'
        }) do
            assert(a.Platform:TrySetRaidMark({ unit = unit, action = action }))
            local call = calls[#calls]
            assert(call[1] == unit and call[2] == index - 1)
        end
    end

    assert(#calls == 63)
end)

test('direct calls do not check raid roles or whether the mark is already set', function()
    local _, a, e = W.client('tbc', { group = { raid = true, size = 5 } })
    local calls = 0

    e.SetRaidTarget = function(unit, mark)
        assert(unit == 'target' and mark == 8)
        calls = calls + 1
    end

    e.GetRaidTargetIndex = function()
        error('mark state must not be checked')
    end

    e.UnitIsGroupLeader = function()
        error('raid role must not be checked')
    end

    e.UnitIsGroupAssistant = e.UnitIsGroupLeader
    assert(a.Platform:TrySetRaidMark({ unit = 'target', action = 'skull' }))
    assert(calls == 1)
end)

test('invalid fields, missing API and errors do not break evaluation', function()
    local _, a, e = W.client('tbc')
    local calls = 0

    e.SetRaidTarget = function()
        calls = calls + 1
        error('client refused')
    end

    assert(not a.Platform:TrySetRaidMark({ unit = 'target', action = 'skull' }))
    assert(calls == 1)
    assert(not a.Platform:TrySetRaidMark({ unit = 'target', action = 'purple' }))
    assert(not a.Platform:TrySetRaidMark({ unit = 'target]\n/run x', action = 'skull' }))
    assert(calls == 1)
    e.SetRaidTarget = nil
    assert(not a.Platform:TrySetRaidMark({ unit = 'target', action = 'none' }))
end)

-- Whole poll: the real addon in TOC order, a rotation whose first step sets a mark on your target and a spell step
-- behind it, a macro on the first action bar slot that presses the step's button.
local root = assert(io.popen('pwd'):read('*l'))

-- Builds the whole-poll world with the Set Mark platform pieces, a character whose first bar slot holds the macro and a
-- rotation named Marks that is active. options go to the whole-poll fixture. Returns the fixture, the state the test
-- steers (mark, slot, body), the pseudo spell id of the first step, and the timers the first button asked for.
local function wholePoll(options)
    options = options or {}
    options.target, options.combat, options.buttons, options.macro, options.poll = true, true, true, true, .15
    local c = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price', root, true, root, true)(options)
    local a, e = c.a, c.e

    for _, path in ipairs({
        'Platform/unit_presence.lua',
        'Platform/raid_marks.lua',
        'Platform/raid_mark_actions.lua',
        'Core/raid_mark_buttons.lua',
    }) do
        c.load(path)
    end

    local state = { mark = nil, slot = 'macro', body = '/click RM_Mark_target_skull' }
    local create = e.CreateFrame

    e.CreateFrame = function(kind, name, ...)
        local frame = create(kind, name, ...)
        frame.attributes = {}

        function frame:SetAttribute(key, value)
            self.attributes[key] = value
        end

        function frame:GetAttribute(key)
            return self.attributes[key]
        end

        if name then
            e[name] = frame
        end

        return frame
    end

    local spells = { 403, 8042, 324, 8017 }

    e.GetActionInfo = function(slot)
        if slot == 1 and state.slot == 'macro' then
            return 'macro', 1
        end

        return 'spell', spells[slot]
    end

    e.GetMacroBody = function() return state.body end
    e.GetRaidTargetIndex = function(token) return token == 'target' and state.mark or nil end
    e.SetRaidTarget = function() end
    e.UnitIsGroupLeader = function() return false end
    e.UnitIsGroupAssistant = function() return false end
    e.IsInRaid = function() return false end
    e.GetNumGroupMembers = function() return 0 end

    -- The first button asks for a rescan through the addon timer; the test runs it by hand.
    local timers = {}

    a.ScheduleTimer = function(_, callback)
        timers[#timers + 1] = callback
        return #timers
    end

    a.CancelTimer = function() end
    a.db.profile.idle_poll = 0

    local reference = {
        kind = 'custom',
        address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = 'marks' },
    }

    assert(a:CommitRotationDraft(
        reference,
        nil,
        {
            body = {
                name = 'Marks',
                priority = 0,
                cooldowns = {},
                rotation = {
                    { id = 'mark', type = 'mark', unit = 'target', action = 'skull', conditions = {} },
                    { id = 'bolt', type = 'spell', action = 8042, conditions = {} },
                },
            },
        },
        'class'
    ))

    a:HandleCommand('set Marks')

    for _ = 1, 3 do
        c.tick()
    end

    return c, state, a.Platform:GetMarkActionId('target', 8), timers
end

test('both engines directly attempt the mark and continue to the spell without making a button', function()
    for _, engine in ipairs({ 'lean', 'standard' }) do
        local c = wholePoll()
        local calls = {}

        c.e.SetRaidTarget = function(unit, mark)
            calls[#calls + 1] = { unit, mark }
        end

        assert(c.a:SetEvaluationEngine(engine))
        c.tick()
        c.tick()
        assert(#calls > 0, engine .. ' did not attempt SetRaidTarget')
        assert(calls[1][1] == 'target' and calls[1][2] == 8, engine .. ' used the wrong arguments')
        assert(c.a.currentSpell == 8042, engine .. ' did not continue to the spell')
        assert(c.e.RM_Mark_target_skull == nil, engine .. ' created a button')
        assert(c.a:GetStepBinding({ type = 'mark', unit = 'target', action = 'skull' }) == nil)
    end
end)

finish()
