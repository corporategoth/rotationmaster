-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- /rm debug marks (Diagnostics/raid_marks.lua): it reports the capabilities, the table and what every mark unit resolves
-- to, it is read only (no mark is set, no saved data changes, no button is made), it is cheap, and it is reachable
-- through the /rm debug router. See docs/raid-marks.md.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local W = dofile('tests/fixtures/raid_mark_world.lua')

local function unit(guid, mark, enemy)
    return { guid = guid, mark = mark, enemy = enemy == true, friend = enemy == false }
end

-- A client with the report loaded, and a way to read what it printed.
local function client(name, options)
    local f, a, e, w = W.client(name, options)
    f.load('Diagnostics/raid_marks.lua')
    local printed = {}

    a.print = function(_, message, ...)
        printed[#printed + 1] = string.format(message, ...)
    end

    return f, a, e, w, printed
end

local function text(printed)
    return table.concat(printed, '\n')
end

test('the report lists what the client offers, the table and each mark unit', function()
    local _, a, _, w, printed = client('tbc', {
        events = { 'RAID_TARGET_UPDATE', 'PLAYER_TARGET_CHANGED', 'UPDATE_MOUSEOVER_UNIT' },
        tokenFromGUID = false,
    })

    w:set('target', unit('Creature-1', 8, true))
    w:set('mouseover', unit('Player-2', 5, false))
    a:RunRaidMarkDiagnostic()
    local report = text(printed)
    assert(report:find('== Raid marks on tbc', 1, true), report)
    assert(report:find('GetRaidTargetIndex=yes', 1, true) and report:find('SetRaidTarget=yes', 1, true), report)
    assert(report:find('UnitTokenFromGUID=no', 1, true), 'a missing function is reported as no')
    assert(report:find('RAID_TARGET_UPDATE=yes', 1, true) and report:find('NAME_PLATE_UNIT_ADDED=no', 1, true), report)
    assert(report:find('Watching: yes; 3 events registered', 1, true), report)
    assert(report:find('skull    8: Creature-1, target, reachable', 1, true), report)
    assert(report:find('moon     5: Player-2, mouseover, reachable', 1, true), report)
    assert(report:find('cross    7: -', 1, true), 'an empty mark is a dash')
    assert(report:find('skull     -> target', 1, true) and report:find('moon      -> mouseover', 1, true), report)
    assert(report:find('cross     unavailable (no-marked-unit)', 1, true), report)
    assert(report:find('anymark   -> target', 1, true), 'anymark takes the skull')
    assert(report:find('Offered in the unit pickers: yes', 1, true))
    assert(report:find('Set Mark step: available; hidden buttons made 0', 1, true), report)
    assert(report:find('You may place marks now: yes', 1, true))
end)

test('the report shows a unit out of reach, an unreadable table and a client with no mark API', function()
    local _, a, _, w, printed = client('retail')
    w:set('target', unit('G1', 8, true))
    a.Platform:ResolveRaidMarkUnit('skull')
    w:remove('target')
    w:fire('PLAYER_TARGET_CHANGED')
    w:advance(2.5)
    a:RunRaidMarkDiagnostic()
    local report = text(printed)
    assert(report:find('G1, last target, NOT reachable, 2.5s', 1, true), report)
    assert(report:find('skull     unavailable (no-token)', 1, true), report)
    local _, b, _, v, second = client('retail')
    v.secretMarks.player = true
    b:RunRaidMarkDiagnostic()
    assert(text(second):find('unreadable', 1, true), text(second))
    local _, c, _, x, third = client('era', { read = false, set = false })
    c:RunRaidMarkDiagnostic()
    local none = text(third)
    assert(none:find('Reading marks: unavailable (missing-api)', 1, true), none)
    assert(none:find('GetRaidTargetIndex=no', 1, true) and none:find('Offered in the unit pickers: no', 1, true), none)
    assert(none:find('Set Mark step: unavailable (missing-api)', 1, true), none)
    assert(#x.frames == x.baseline, 'a client with no mark API made a frame')
end)

test('the report is read only and cheap', function()
    local _, a, e, w, printed = client('tbc')
    local sets = 0

    e.SetRaidTarget = function()
        sets = sets + 1
    end

    w:set('target', unit('G1', 8, true))
    local profile = a:CopySettingsData(a.db.profile)
    a:RunRaidMarkDiagnostic()

    assert(
        sets == 0 and #w.attributeWrites == 0 and #w.macros == 0 and next(a.markButtons) == nil,
        'the report changed the game or made a button'
    )

    assert(a:SettingsDataEqual(profile, a.db.profile), 'the report changed saved data')
    -- One rescan of every token a solo player can reach (sixty with nameplates, bosses and arena), plus one verification read
    -- per mark unit that resolves.
    assert(w.calls.GetRaidTargetIndex <= 70, 'a report scanned too much: ' .. w.calls.GetRaidTargetIndex)
    local lines = #printed
    assert(lines >= 20 and lines <= 40, 'the report length: ' .. lines)
end)

test('/rm debug marks is routed to the report', function()
    local f, a, _, _, printed = client('tbc')
    f.load('Diagnostics/glow.lua')
    a:HandleDebugCommand('marks')
    assert(text(printed):find('== Raid marks', 1, true), text(printed))
    a:HandleDebugCommand(' marks ')
    assert(#printed > 30, 'whitespace around the word is fine')
end)

finish()
