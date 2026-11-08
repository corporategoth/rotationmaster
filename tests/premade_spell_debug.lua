-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- /rm debug spells (Diagnostics/premade_spells.lua): it lists the spell IDs of the premades that fit this character which the
-- client does not know, from step actions and condition spells (a totem slot is not a spell), keeps the report in the
-- saved variables, and is reachable through the /rm debug router.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function client(rows, known)
    local f = F.new(18, 12, 'SHAMAN')
    local a = f.addon
    a.db = { global = {}, profile = {} }
    a.currentSpec = 0
    a.ListDefaultRotations = function() return rows end
    a.Platform.GetSpellInfo = function(_, id) return known[id] and { name = 'Spell ' .. id } or nil end
    local printed, shown = {}, {}

    a.print = function(_, message, ...)
        printed[#printed + 1] = string.format(message, ...)
    end

    a.ShowConditionText = function(_, text)
        shown[#shown + 1] = text
    end

    f.load('Diagnostics/glow.lua')
    f.load('Diagnostics/premade_spells.lua')
    return a, printed, shown
end

local rows = {
    {
        id = 'rm.test.one',
        fits = true,
        body = {
            cooldowns = { { id = 'imbue', type = 'spell', action = 8232, conditions = {} } },
            rotation = {
                {
                    id = 'bolt',
                    type = 'spell',
                    action = 403,
                    conditions = { type = 'BUFF', unit = 'player', spell = 408505 },
                },
                {
                    id = 'gate',
                    type = 'branch',
                    conditions = { type = 'TOTEM', spell = 1 },
                    onTrue = {
                        { id = 'nova', type = 'spell', action = 408341, conditions = {} },
                    },
                    onFalse = {},
                },
            },
        },
    },
    { id = 'rm.test.other', fits = false, body = { rotation = { { id = 'x', type = 'spell', action = 99999 } } } },
}

test('it lists the spell IDs the client does not know, once each with where they are named', function()
    local a, printed, shown = client(rows, { [8232] = true, [403] = true })
    local lines, unknown = a:BuildPremadeSpellDiagnostic()
    local text = table.concat(lines, '\n')
    assert(unknown == 2, text)
    assert(text:find('rm.test.one: 2 spell ID(s) unknown', 1, true), text)
    assert(text:find('408505: condition BUFF', 1, true) and text:find('408341: step nova', 1, true), text)
    assert(not text:find('99999', 1, true), 'a premade that does not fit this character is not checked')
    assert(not text:find('rm.test.other', 1, true) and text:find('1 premade(s) checked, 2 unknown', 1, true), text)
    assert(not text:find(': 1 ', 1, true), 'a totem slot is not read as a spell')
    a:RunPremadeSpellDiagnostic()
    assert(#shown == 1 and shown[1]:find('408505', 1, true), 'the report opens in the copyable window')
    assert(a.db.global.diagnostics.spells.lines[1]:find('Premade spell IDs', 1, true), 'and is saved')
    assert(#printed == 1 and printed[1]:find('1 premade(s) checked', 1, true), 'chat gets only the total')
end)

test('/rm debug spells is routed, and "show" reopens the saved report', function()
    local a, _, shown = client(rows, { [8232] = true, [403] = true, [408505] = true, [408341] = true })
    a:HandleDebugCommand('spells')
    assert(#shown == 1 and shown[1]:find('0 unknown', 1, true), shown[1])
    a:HandleDebugCommand('spells show')
    assert(#shown == 2)
end)

finish()
