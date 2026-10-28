-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Compose the actual macro endpoint, contextual unit substitution and existing
-- GROUP leaf with the new unit predicates. Native output stays a test boundary.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local h = assert(io.open('tests/announcement_macros.lua'))
local source = h:read('*a')
h:close()
local prefix = assert(source:match('^(.-)\ntest%('))
local fixture, endpoint = assert(loadstring(prefix .. '\nreturn fixture,endpoint', '@resurrection-macro-fixture'))()

local function setup()
    local f, a, e, outputs, units = fixture()

    for _, path in ipairs({ 'Platform/unit_states.lua', 'Conditions/unit_states.lua', 'Conditions/character.lua' }) do
        f.load(path)
    end

    local state = { dead = true, friendly = true, group = false, groupCalls = 0 }

    e.UnitIsDeadOrGhost = function(unit)
        assert(unit == 'focus')
        return state.dead
    end

    e.UnitIsFriend = function(player, unit)
        assert(player == 'player' and unit == 'focus')
        return state.friendly
    end

    e.UnitInParty = function(unit)
        assert(unit == 'focus')
        state.groupCalls = state.groupCalls + 1
        return state.group
    end

    e.UnitInRaid = function(unit)
        assert(unit == 'focus')
        return nil
    end

    local entry = a.db.profile.announces[1]
    entry.identifier = 'resurrect'
    entry.announce = 'whisper'
    entry.value = 'Resurrecting {{target}}'

    entry.conditions = {
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

    return a, e, outputs, units, state, endpoint(e)
end

test('resurrection whisper conditions and recipient follow supplied unit rather than selected target', function()
    local a, e, outputs, units, state, invoke = setup()
    assert(invoke('resurrect', 'focus').chat)

    assert(
        #outputs == 1
            and outputs[1].target == 'Focus-Realm'
            and outputs[1].text == 'Resurrecting Focus-Realm'
            and state.groupCalls == 0
    )

    units.target.name = 'Different selected target'
    state.friendly = false
    assert(not invoke('resurrect', 'focus').chat)
    state.group = true
    assert(invoke('resurrect', 'focus').chat and outputs[2].target == 'Focus-Realm')
end)

test('living missing unreadable and rebound recipients cannot produce resurrection whisper', function()
    local a, e, outputs, units, state, invoke = setup()
    state.dead = false
    assert(not invoke('resurrect', 'focus').chat and state.groupCalls == 0)
    assert(not invoke('resurrect').chat)
    state.dead = true

    e.UnitIsDeadOrGhost = function(unit)
        units.focus.guid = 'Player-replacement'
        units.focus.name = 'Replacement'
        return true
    end

    assert(not invoke('resurrect', 'focus').chat and #outputs == 0)
end)

finish()
