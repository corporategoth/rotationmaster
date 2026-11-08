-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- /rm debug secrets builds a report without failing when APIs are missing, lists unavailable condition counts, and
-- clears them on reset.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new(18, 12)
    f.load('Diagnostics/secrets.lua')
    local a = f.addon
    a.unavailableConditionCounts = { BUFF = { ['restricted-value'] = 7 }, MOVING = { ['restricted-value'] = 2 } }
    local shown = {}

    a.ShowConditionText = function(_, text, heading)
        shown.text, shown.heading = text, heading
    end

    a.print = function(_, fmt, ...)
        shown.printed = string.format(fmt, ...)
    end

    return a, shown
end

test('the report survives missing APIs and lists the unavailable counts, most frequent first', function()
    local a, shown = fixture()
    a:RunSecretsDiagnostic('')
    assert(shown.heading == 'Secret value probe' and shown.text:find('client:', 1, true), 'report shown')

    local buff, moving = shown.text:find('BUFF: restricted-value = 7', 1, true), shown.text:find(
        'MOVING: restricted',
        1,
        true
    )

    assert(buff and moving and buff < moving, 'counts listed in order')
end)

test('reset clears the counts', function()
    local a, shown = fixture()
    a:RunSecretsDiagnostic('reset')
    assert(next(a.unavailableConditionCounts) == nil and shown.printed == 'Secret value counts cleared.')
    a:RunSecretsDiagnostic('')
    assert(shown.text:find('  none', 1, true), 'empty list says none')
end)

finish()
