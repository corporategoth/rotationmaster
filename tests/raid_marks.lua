-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The raid mark table (Platform/raid_marks.lua): lazy event registration, the rescan, single-token updates, pruning,
-- unreachable units kept by GUID, unreadable values, the lease, capability gating by what the client has, and the mark
-- unit types resolved through the existing group unit path. See docs/raid-marks.md.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local W = dofile('tests/fixtures/raid_mark_world.lua')
local C = dofile('tests/fixtures/condition_client.lua')
local SECRET = W.SECRET

local SKULL, CROSS, MOON, STAR = 8, 7, 5, 1
local FAMILIES = { 'retail', 'forever', 'mists', 'tbc', 'era' }

-- A unit of the world: a GUID, the mark it carries (nil for none) and its hostility.
local function unit(guid, mark, enemy)
    return { guid = guid, mark = mark, enemy = enemy == true, friend = enemy == false }
end

-- The record the snapshot holds for a mark number.
local function entry(a, mark)
    return a.Platform:GetRaidMarkSnapshot().marks[mark]
end

test('nothing is registered and nothing is read until something asks about marks', function()
    for _, name in ipairs(FAMILIES) do
        local _, a, _, w = W.client(name)
        assert(#w.frames == w.baseline, name .. ' made a frame before anything asked')
        assert(w:registeredCount() == 0, name .. ' registered events before anything asked')
        assert((w.calls.GetRaidTargetIndex or 0) == 0, name .. ' read marks before anything asked')
        assert(not a.Platform:IsRaidMarkWatching(), name .. ' was watching')
    end
end)

test('the first question registers every event the client knows and rescans once', function()
    local _, a, _, w = W.client('tbc')
    w:set('target', unit('G1', SKULL, true))
    local token, why = a.Platform:ResolveRaidMarkUnit('skull')
    assert(token == 'target' and why == nil, tostring(token) .. ' ' .. tostring(why))
    assert(a.Platform:IsRaidMarkWatching())
    local registered = w:registered()
    assert(#registered == #W.allEvents, 'registered ' .. table.concat(registered, ','))
    local snapshot = a.Platform:GetRaidMarkSnapshot()
    assert(snapshot.scans == 1 and snapshot.starts == 1, 'one rescan on start')
    -- A second question on the same poll reads the mark of the one token it returns, and scans nothing.
    local before = w.calls.GetRaidTargetIndex
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    assert(w.calls.GetRaidTargetIndex == before + 1, 'a repeated question must verify one token, not rescan')
    assert(a.Platform:GetRaidMarkSnapshot().scans == 1)
end)

test('only the events the client has are registered, and the scan follows them', function()
    local _, a, _, w = W.client('era', {
        events = { 'RAID_TARGET_UPDATE', 'PLAYER_TARGET_CHANGED', 'UPDATE_MOUSEOVER_UNIT', 'GROUP_ROSTER_UPDATE' },
    })

    w:set('target', unit('G1', SKULL, true))
    w:set('nameplate3', unit('G9', CROSS, true))
    w:set('focus', unit('G7', MOON, true))
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    local registered = {}

    for _, event in ipairs(w:registered()) do
        registered[event] = true
    end

    assert(
        registered.RAID_TARGET_UPDATE and registered.PLAYER_TARGET_CHANGED and not registered.NAME_PLATE_UNIT_ADDED,
        'event set'
    )

    assert(not entry(a, CROSS).held, 'a nameplate was scanned on a client with no nameplate event')
    assert(not entry(a, MOON).held, 'focus was scanned on a client with no focus event')
    local snapshot = a.Platform:GetRaidMarkSnapshot()
    assert(snapshot.registered.NAME_PLATE_UNIT_ADDED == false and snapshot.registered.RAID_TARGET_UPDATE == true)
end)

test('an event the catalog says the client lacks is not registered even where registering it would not fail', function()
    local _, a, _, w = W.client('tbc', { lenient = true, events = { 'RAID_TARGET_UPDATE', 'PLAYER_TARGET_CHANGED' } })
    w:set('target', unit('G1', SKULL, true))
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    local registered = w:registered()

    assert(
        #registered == 2 and registered[1] == 'PLAYER_TARGET_CHANGED' and registered[2] == 'RAID_TARGET_UPDATE',
        table.concat(registered, ',')
    )

    assert(w.registerAttempts == 2, 'tried ' .. w.registerAttempts .. ' registrations')
end)

test('a client with no event catalog tries every event and keeps those that registered', function()
    local _, a, _, w = W.client('era', { catalog = false, events = { 'RAID_TARGET_UPDATE', 'PLAYER_TARGET_CHANGED' } })
    w:set('target', unit('G1', SKULL, true))
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    assert(w:registeredCount() == 2, table.concat(w:registered(), ','))
end)

test('RAID_TARGET_UPDATE rescans the reachable tokens and rebuilds the table', function()
    local _, a, _, w = W.client('tbc', { group = { raid = true, size = 10 } })
    w:set('player', unit('GP', nil, false))
    w:set('raid3', unit('G3', CROSS, false))
    w:set('raid7target', unit('G70', SKULL, true))
    w:set('boss1', unit('GB', MOON, true))
    w:set('nameplate12', unit('GN', STAR, true))
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'raid7target')
    assert(a.Platform:ResolveRaidMarkUnit('cross') == 'raid3')
    assert(a.Platform:ResolveRaidMarkUnit('moon') == 'boss1')
    assert(a.Platform:ResolveRaidMarkUnit('star') == 'nameplate12')
    local token, why = a.Platform:ResolveRaidMarkUnit('square')
    assert(token == nil and why == 'no-marked-unit', tostring(why))
    -- Someone moves the skull to another unit and the game says only that a mark changed.
    w.tokens['raid7target'].mark = nil
    w:set('raid9target', unit('G90', SKULL, true))
    w:fire('RAID_TARGET_UPDATE')
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'raid9target')
    assert(entry(a, SKULL).guid == 'G90')
end)

test('a rescan reads the party and its targets, not the raid, when the group is a party', function()
    local _, a, _, w = W.client('tbc', { group = { raid = false, size = 3 } })
    w:set('party2', unit('G2', MOON, false))
    w:set('raid2', unit('GX', SKULL, true))
    w:set('party1target', unit('G1T', CROSS, true))
    assert(a.Platform:ResolveRaidMarkUnit('moon') == 'party2')
    assert(a.Platform:ResolveRaidMarkUnit('cross') == 'party1target')

    assert(
        select(2, a.Platform:ResolveRaidMarkUnit('skull')) == 'no-marked-unit',
        'raid tokens are not read in a party'
    )
end)

test('a token event reads only that token', function()
    local _, a, _, w = W.client('tbc', { group = { raid = true, size = 20 } })
    w:set('target', unit('G1', SKULL, true))
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    w:set('target', unit('G2', CROSS, true))
    w.calls.GetRaidTargetIndex = 0
    w:fire('PLAYER_TARGET_CHANGED')
    assert(w.calls.GetRaidTargetIndex <= 3, 'a target change scanned: ' .. w.calls.GetRaidTargetIndex)
    assert(a.Platform:ResolveRaidMarkUnit('cross') == 'target')
    assert(entry(a, SKULL).reachable == false and entry(a, SKULL).token == nil, 'the old skull unit is out of reach')
end)

test('mouseover, focus, soft targets, nameplates and a raid member target each update the table', function()
    local _, a, _, w = W.client('retail', { group = { raid = true, size = 5 } })
    assert(select(2, a.Platform:ResolveRaidMarkUnit('skull')) == 'no-marked-unit')
    w:set('mouseover', unit('GM', SKULL, true))
    w:fire('UPDATE_MOUSEOVER_UNIT')
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'mouseover')
    w:set('focus', unit('GF', CROSS, true))
    w:fire('PLAYER_FOCUS_CHANGED')
    assert(a.Platform:ResolveRaidMarkUnit('cross') == 'focus')
    w:set('softenemy', unit('GS', MOON, true))
    w:fire('PLAYER_SOFT_ENEMY_CHANGED')
    assert(a.Platform:ResolveRaidMarkUnit('moon') == 'softenemy')
    w:set('nameplate5', unit('GN', STAR, true))
    w:fire('NAME_PLATE_UNIT_ADDED', 'nameplate5')
    assert(a.Platform:ResolveRaidMarkUnit('star') == 'nameplate5')
    w:set('raid2target', unit('GR', 6, true))
    w:fire('UNIT_TARGET', 'raid2')
    assert(a.Platform:ResolveRaidMarkUnit('square') == 'raid2target')
    -- UNIT_TARGET for a unit the table does not hold targets of is ignored without a read.
    w.calls.GetRaidTargetIndex = 0
    w:fire('UNIT_TARGET', 'nameplate5')
    assert(w.calls.GetRaidTargetIndex == 0, 'read a nameplate target on UNIT_TARGET')
end)

test('a unit that carries one mark cannot be recorded under another', function()
    local _, a, _, w = W.client('tbc')
    local boss = unit('G1', SKULL, true)
    w:set('target', boss)
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    boss.mark = CROSS
    w:fire('PLAYER_TARGET_CHANGED')
    assert(a.Platform:ResolveRaidMarkUnit('cross') == 'target')
    assert(not entry(a, SKULL).held, 'the unit is recorded with two marks')
end)

test('a unit seen under a new token with a new mark is not kept under its old mark', function()
    local _, a, _, w = W.client('tbc')
    local boss = unit('G1', SKULL, true)
    w:set('nameplate1', boss)
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'nameplate1')
    boss.mark = CROSS
    w:remove('nameplate1')
    w:set('mouseover', boss)
    w:fire('UPDATE_MOUSEOVER_UNIT')
    assert(not entry(a, SKULL).held, 'the same unit is recorded with two marks')
    assert(a.Platform:ResolveRaidMarkUnit('cross') == 'mouseover')
end)

test('a marked unit that leaves reach stays by GUID, flagged out of reach, and is found again by its GUID', function()
    local _, a, _, w = W.client('retail')
    local add = unit('G1', SKULL, true)
    w:set('target', add)
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    -- The target changes and the unit is nowhere the client can name.
    w:remove('target')
    w:fire('PLAYER_TARGET_CHANGED')
    local token, why = a.Platform:ResolveRaidMarkUnit('skull')
    assert(token == nil and why == 'no-token', tostring(why))
    local held = entry(a, SKULL)
    assert(held.held and held.reachable == false and held.guid == 'G1' and held.lastToken == 'target', 'kept by GUID')
    assert(a.Platform:GetRaidMarkCount() == 1, 'an out-of-reach marked unit still counts')
    -- It comes back as a nameplate: the event finds the mark on the token, with the same GUID.
    w:set('nameplate2', add)
    w:fire('NAME_PLATE_UNIT_ADDED', 'nameplate2')
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'nameplate2')
    assert(entry(a, SKULL).reachable)
end)

test('UnitTokenFromGUID re-points a marked unit at another token it is still reachable by', function()
    local _, a, _, w = W.client('retail', { group = { raid = true, size = 4 } })
    local boss = unit('G1', SKULL, true)
    w:set('target', boss)
    w:set('raid2target', boss)
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    w:remove('target')
    w:fire('PLAYER_TARGET_CHANGED')
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'raid2target', 'found again through its GUID')
    assert(w.calls.UnitTokenFromGUID >= 1)
end)

test('the mark is pruned when a rescan shows it gone from a unit that is still reachable', function()
    local _, a, _, w = W.client('retail')
    local boss = unit('G1', SKULL, true)
    w:set('target', boss)
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    w:set('nameplate4', boss)
    w:remove('target')
    boss.mark = nil
    w:fire('RAID_TARGET_UPDATE')
    assert(not entry(a, SKULL).held, 'a gone mark was kept')
    local token, why = a.Platform:ResolveRaidMarkUnit('skull')
    assert(token == nil and why == 'no-marked-unit', tostring(why))
    assert(a.Platform:GetRaidMarkCount() == 0)
end)

test('the mark is pruned when its remembered token now shows the unit without it', function()
    local _, a, _, w = W.client('tbc')
    local boss = unit('G1', SKULL, true)
    w:set('target', boss)
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    boss.mark = nil
    local token, why = a.Platform:ResolveRaidMarkUnit('skull')
    assert(token == nil and why == 'no-marked-unit', 'the verification read must notice: ' .. tostring(why))
    assert(not entry(a, SKULL).held)
end)

test(
    'without UnitTokenFromGUID an out-of-reach unit is kept until a token shows the mark again or the world changes',
    function()
        local _, a, _, w = W.client('tbc', { tokenFromGUID = false })
        local boss = unit('G1', SKULL, true)
        w:set('target', boss)
        assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
        w:remove('target')
        w:fire('PLAYER_TARGET_CHANGED')
        assert(select(2, a.Platform:ResolveRaidMarkUnit('skull')) == 'no-token')
        -- A rescan with the unit still unreachable keeps the record: the client cannot say the mark is gone.
        w:fire('RAID_TARGET_UPDATE')
        assert(entry(a, SKULL).held and not entry(a, SKULL).reachable)
        -- Another mark appears elsewhere; the skull record is untouched.
        w:set('mouseover', unit('G2', CROSS, true))
        w:fire('UPDATE_MOUSEOVER_UNIT')
        assert(entry(a, SKULL).held and entry(a, CROSS).held)
        -- A new world (a loading screen) forgets what was out of reach.
        w:fire('PLAYER_ENTERING_WORLD')
        assert(not entry(a, SKULL).held, 'an out-of-reach unit survived a loading screen')
        assert(entry(a, CROSS).held, 'a reachable one is found again by the rescan')
    end
)

test('a mark moved from an unreachable unit to a reachable one replaces the record', function()
    local _, a, _, w = W.client('retail')
    w:set('target', unit('G1', SKULL, true))
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    w:remove('target')
    w:fire('PLAYER_TARGET_CHANGED')
    w:set('nameplate1', unit('G2', SKULL, true))
    w:fire('RAID_TARGET_UPDATE')
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'nameplate1')
    assert(entry(a, SKULL).guid == 'G2')
end)

test('anymark answers the highest-priority reachable mark, skull first, and says why when none is', function()
    local _, a, _, w = W.client('tbc')
    local token, why = a.Platform:ResolveRaidMarkUnit('anymark')
    assert(token == nil and why == 'no-marked-unit', tostring(why))
    w:set('target', unit('G1', STAR, true))
    w:set('mouseover', unit('G2', MOON, true))
    w:fire('RAID_TARGET_UPDATE')
    assert(a.Platform:ResolveRaidMarkUnit('anymark') == 'mouseover', 'moon outranks star')
    w:set('focus', unit('G3', SKULL, true))
    w:fire('RAID_TARGET_UPDATE')
    assert(a.Platform:ResolveRaidMarkUnit('anymark') == 'focus', 'skull outranks everything')
    -- A skull that is out of reach is skipped for the next reachable mark.
    w:remove('focus')
    w:fire('PLAYER_FOCUS_CHANGED')
    assert(a.Platform:ResolveRaidMarkUnit('anymark') == 'mouseover', 'an unreachable skull must not hide the moon')
    -- With only unreachable marks, the highest-priority one explains.
    w:remove('mouseover')
    w:remove('target')
    w:fire('RAID_TARGET_UPDATE')
    local none, reason = a.Platform:ResolveRaidMarkUnit('anymark')
    assert(none == nil and reason == 'no-token', tostring(reason))
end)

test('an unreadable mark is unavailable with the reason, never a guess', function()
    local _, a, _, w = W.client('retail')
    w:set('target', unit('G1', SKULL, true))
    w.secretMarks.target = true
    local token, why = a.Platform:ResolveRaidMarkUnit('skull')
    assert(token == nil and why == 'unreadable', tostring(why))
    token, why = a.Platform:ResolveRaidMarkUnit('anymark')
    assert(token == nil and why == 'unreadable', tostring(why))
    local count, reason = a.Platform:GetRaidMarkCount()
    assert(count == nil and reason == 'unreadable', 'a table with unreadable tokens is incomplete')
    local mark, markReason = a.Platform:GetUnitRaidMark('target')
    assert(mark == nil and markReason == 'restricted-value')
    -- A mark that was read and then becomes unreadable on the remembered token is unreadable too.
    local _, b, _, v = W.client('retail')
    v:set('target', unit('G1', SKULL, true))
    assert(b.Platform:ResolveRaidMarkUnit('skull') == 'target')
    v.secretMarks.target = true
    token, why = b.Platform:ResolveRaidMarkUnit('skull')
    assert(token == nil and why == 'unreadable', tostring(why))
    assert(entry(b, SKULL).held, 'an unreadable token proves nothing, so the record stays')
end)

test('an unreadable GUID keeps the unit by its token, and it is out of reach once the token moves on', function()
    local _, a, _, w = W.client('retail')
    w:set('target', unit('G1', SKULL, true))
    w.secretGuids.target = true
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    assert(entry(a, SKULL).guid == nil, 'a secret GUID must not be stored')
    w:set('target', unit('G2', nil, true))
    w:fire('PLAYER_TARGET_CHANGED')
    local token, why = a.Platform:ResolveRaidMarkUnit('skull')
    assert(token == nil and why == 'no-token', tostring(why))
end)

test('an out-of-range mark value is invalid, not a mark', function()
    local _, a, e = W.client('tbc')
    e.GetRaidTargetIndex = function() return 9 end
    local mark, why = a.Platform:GetUnitRaidMark('target')
    assert(mark == nil and why == 'invalid-api-result')
    e.GetRaidTargetIndex = function() return 'skull' end
    mark, why = a.Platform:GetUnitRaidMark('target')
    assert(mark == nil and why == 'invalid-api-result')

    e.GetRaidTargetIndex = function()
        error('boom')
    end

    mark, why = a.Platform:GetUnitRaidMark('target')
    assert(mark == nil and why == 'api-error')
    e.GetRaidTargetIndex = function() return nil end
    assert(a.Platform:GetUnitRaidMark('target') == 0, 'no mark reads as zero')
    assert(select(2, a.Platform:GetUnitRaidMark(nil)) == 'invalid-unit')
end)

test('the events are dropped when nothing has asked for a while, by the next event or by the timer', function()
    local _, a, _, w = W.client('tbc')
    w:set('target', unit('G1', SKULL, true))
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    assert(w:registeredCount() > 0)
    -- An event inside the lease keeps the watch.
    w:advance(20)
    w:fire('PLAYER_TARGET_CHANGED')
    assert(w:registeredCount() > 0 and a.Platform:IsRaidMarkWatching())
    -- Nothing asks for longer than the lease: the next event drops the registrations and the table.
    w:advance(31)
    w:fire('PLAYER_TARGET_CHANGED')
    assert(w:registeredCount() == 0 and not a.Platform:IsRaidMarkWatching(), 'still registered after the lease')
    assert(not entry(a, SKULL).held, 'the table survived the watch')
    -- Asking again starts it again.
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    assert(a.Platform:GetRaidMarkSnapshot().starts == 2 and w:registeredCount() > 0)
    -- The timer does the same with no event at all.
    w:advance(40)
    w:runTimers()
    assert(w:registeredCount() == 0 and not a.Platform:IsRaidMarkWatching(), 'the lease timer did not drop the events')
end)

test('a question inside the lease moves it, so a busy rotation keeps the events', function()
    local _, a, _, w = W.client('tbc')
    w:set('target', unit('G1', SKULL, true))
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')

    for _ = 1, 6 do
        w:advance(20)
        assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
        w:runTimers()
    end

    assert(a.Platform:IsRaidMarkWatching() and a.Platform:GetRaidMarkSnapshot().starts == 1)
    a.Platform:ReleaseRaidMarks()
    assert(w:registeredCount() == 0 and not a.Platform:IsRaidMarkWatching())
end)

test('a change to the table wakes the idle gate and an unchanged event does not', function()
    local _, a, _, w = W.client('tbc')
    a.idleGate = { dirty = false }
    w:set('target', unit('G1', SKULL, true))
    assert(a.Platform:ResolveRaidMarkUnit('skull') == 'target')
    assert(a.idleGate.dirty == true, 'the first scan found a mark')
    a.idleGate.dirty = false
    w:fire('PLAYER_TARGET_CHANGED')
    assert(a.idleGate.dirty == false, 'nothing changed, so the gate was not woken')
    w:set('target', unit('G2', CROSS, true))
    w:fire('PLAYER_TARGET_CHANGED')
    assert(a.idleGate.dirty == true)
end)

test('the count and its filters', function()
    local _, a, _, w = W.client('tbc')
    w:set('target', unit('G1', SKULL, true))
    w:set('focus', unit('G2', CROSS, false))
    w:set('mouseover', unit('G3', MOON, true))
    assert(a.Platform:GetRaidMarkCount() == 3)
    assert(a.Platform:GetRaidMarkCount('any') == 3)
    assert(a.Platform:GetRaidMarkCount('enemy') == 2)
    assert(a.Platform:GetRaidMarkCount('friendly') == 1)
    -- A hostility the client will not say makes a filtered count unavailable, and the plain count still works.
    w.tokens.focus.friend = nil
    w:fire('RAID_TARGET_UPDATE')
    assert(a.Platform:GetRaidMarkCount('friendly') == 0)
end)

test('capability gating: a client with no way to read marks offers and resolves nothing', function()
    for _, name in ipairs(FAMILIES) do
        local _, a, _, w = W.client(name, { read = false })
        assert(a.Platform:GetRaidMarkSupport() == 'missing-api', name)
        assert(a.units.skull == nil and a.units.anymark == nil, name .. ' offered a mark unit it cannot read')
        assert(a.groupUnitKinds.skull == true, name .. ' must still recognize a saved mark unit')
        assert(select(2, a.Platform:ResolveGroupUnit('skull')) == 'missing-api', name)
        assert(#w.frames == w.baseline, name .. ' made a frame')
    end
end)

test('capability gating: every client that can read marks offers all nine mark unit types', function()
    for _, name in ipairs(FAMILIES) do
        local _, a = W.client(name)

        for _, kind in ipairs({
            'skull', 'cross', 'square', 'moon', 'triangle', 'diamond', 'circle', 'star', 'anymark'
        }) do
            assert(a.units[kind] and a.unitsPossessive[kind] and a.groupUnitKinds[kind], name .. ' lacks ' .. kind)
        end
    end
end)

test('capability gating: the mark names are the game own strings when it has them', function()
    local f, a, e = W.client('tbc')
    e.RAID_TARGET_8 = 'Totenkopf'
    f.load('constants.lua')
    f.load('Core/raid_mark_units.lua')
    assert(a.units.skull:find('Totenkopf', 1, true), a.units.skull)
    assert(a.unitsPossessive.skull:find('Totenkopf', 1, true))
    assert(a.units.cross:find('Cross', 1, true), 'the English name is the fallback: ' .. a.units.cross)
end)

test('capability gating: a client that cannot make a frame or register an event cannot follow marks', function()
    local _, a, e = W.client('tbc')
    e.CreateFrame = nil
    local token, why = a.Platform:ResolveRaidMarkUnit('skull')
    assert(token == nil and why == 'missing-api', tostring(why))
    local _, b, _, v = W.client('tbc', { events = {}, catalog = false })
    token, why = b.Platform:ResolveRaidMarkUnit('skull')
    assert(token == nil and why == 'missing-api', tostring(why))
    -- A failed start is not retried on every poll.
    assert(v:registeredCount() == 0)
    local frames, attempts = #v.frames, v.registerAttempts
    b.Platform:ResolveRaidMarkUnit('skull')
    b.Platform:ResolveRaidMarkUnit('skull')
    assert(#v.frames == frames and v.registerAttempts == attempts, 'a failed start was retried on the next question')
    v:advance(6)
    b.Platform:ResolveRaidMarkUnit('skull')
    assert(v.registerAttempts > attempts, 'a failed start is retried once the pause is over')
end)

test('capability report lists what the client offers without registering anything', function()
    local _, a, _, w = W.client('era', { tokenFromGUID = false, events = { 'RAID_TARGET_UPDATE' } })
    local caps = a.Platform:GetRaidMarkCapabilities()
    assert(caps.read and caps.set and caps.command and not caps.tokenFromGUID)
    assert(caps.events.RAID_TARGET_UPDATE == true and caps.events.NAME_PLATE_UNIT_ADDED == false)
    assert(w:registeredCount() == 0 and #w.frames == w.baseline)
    local _, b = W.client('era', { catalog = false })
    assert(b.Platform:GetRaidMarkCapabilities().events.RAID_TARGET_UPDATE == nil, 'no catalog: unknown, not false')
end)

test('mark unit types run through every existing unit-based condition', function()
    for _, name in ipairs(FAMILIES) do
        local _, a, e, w = W.client(name, { group = { raid = false, size = 3 } })
        local combat = {}
        e.UnitAffectingCombat = function(token) return combat[token] == true end

        e.UnitIsUnit = function(left, right)
            return w.tokens[left] ~= nil and w.tokens[left] == w.tokens[right]
        end

        w:set('party2', unit('G2', SKULL, false))
        w:set('nameplate3', unit('G3', MOON, true))
        combat.party2 = true
        C.expect(a, { type = 'COMBAT', unit = 'skull' }, 'match', name)
        combat.party2 = false
        C.expect(a, { type = 'COMBAT', unit = 'skull' }, 'no-match', name)

        C.expect(
            a,
            { type = 'COMBAT', unit = 'cross' },
            'unavailable',
            name .. ' nobody has the cross: unavailable, also under NOT'
        )

        local _, reason = C.status(a, { type = 'COMBAT', unit = 'cross' })
        assert(reason == 'no-marked-unit', tostring(reason))
        w:set('target', w.tokens.nameplate3)
        C.expect(a, { type = 'ISSAME', unit = 'moon', otherunit = 'target' }, 'match', name)
        C.expect(a, { type = 'ISSAME', unit = 'skull', otherunit = 'target' }, 'no-match', name)
        assert(a.conditionDefinitions.COMBAT.valid(0, { unit = 'skull' }), 'the saved unit is a valid choice')
        assert(a:printCondition({ type = 'COMBAT', unit = 'skull' }, 0):find('Skull', 1, true))
    end
end)

test('a mark unit resolves once per kind per evaluation', function()
    local _, a, _, w = W.client('tbc')
    w:set('target', unit('G1', SKULL, true))
    local resolved = a:ResolveConditionUnits({ type = 'ISSAME', unit = 'skull', otherunit = 'skull' }, {})
    assert(resolved.unit == 'target' and resolved.otherunit == 'target')
    local cache = {}
    local first = a:ResolveConditionUnits({ type = 'ISSAME', unit = 'skull', otherunit = 'player' }, cache)
    w.calls.GetRaidTargetIndex = 0
    local second = a:ResolveConditionUnits({ type = 'ISSAME', unit = 'skull', otherunit = 'player' }, cache)

    assert(
        first.unit == 'target' and second.unit == 'target' and w.calls.GetRaidTargetIndex == 0,
        'the cache did not hold'
    )
end)

test('support: a mark unit type needs a client that can read marks, for any condition', function()
    local _, a = W.client('tbc')
    assert(C.support(a, 'COMBAT', { unit = 'skull' }) == nil)
    assert(C.support(a, 'ISSAME', { unit = 'player', otherunit = 'anymark' }) == nil)
    local _, b = W.client('tbc', { read = false })
    assert(C.support(b, 'COMBAT', { unit = 'skull' }) == 'missing-api')
    assert(C.support(b, 'ISSAME', { unit = 'player', otherunit = 'star' }) == 'missing-api')
    assert(C.support(b, 'COMBAT', { unit = 'target' }) == nil, 'ordinary units are not affected')
end)

test('the real TOC order gives every client its mark unit types', function()
    local T = dofile('tests/fixtures/toc_addon.lua')
    local retail = T.new({ project = 1, class = 'WARRIOR' }).addon.units
    assert(retail.skull and retail.anymark, 'Retail lost its mark unit types')
    local era = T.new({ project = 2, expansion = 1, class = 'WARRIOR' }).addon.units
    assert(era.skull and era.star, 'Classic Era lost its mark unit types')
end)

finish()
