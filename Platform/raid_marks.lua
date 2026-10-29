-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for raid target markers (skull, cross, square, moon, triangle, diamond, circle, star).
-- The game has no unit token for a mark: GetRaidTargetIndex(unit) answers only for a token you already hold, and
-- RAID_TARGET_UPDATE says that some mark changed without saying which. This file keeps an event-driven table, mark ->
-- { guid, token, reachable, seen, ... }, rebuilt by one rescan of the tokens the client can reach when a mark changes
-- and updated for a single token when that token changes (target, focus, mouseover, a nameplate, a raid member's
-- target). It owns the table, its event frame and the readers over it; Set Mark steps call the game API through
-- Platform/raid_mark_actions.lua. Nothing is
-- registered until something asks for marks (a mark unit type, MARKED, MARK_COUNT), and the events are dropped again
-- when nothing has asked for a while.
-- Every read goes through platform:CanReadValue: an unreadable answer is unavailable with a reason, never a guess.
-- Retail and Forever disable marker reads; other capabilities are detected from the functions and events the client has.
-- Loaded from RotationMaster.toc after Platform/group_units.lua, which hands the mark unit types to ResolveRaidMarkUnit.
local _, addon = ...
local platform = addon.Platform

-- Game names are read through this table, not as globals: they are probes, and a client that lacks one must read as
-- "no", not as a missing API in the surface test that guards the other platform files.
local env = getfenv and getfenv(1) or _G

-- ============================================================================
-- Marks
-- ============================================================================

-- The mark names, indexed by the number the game uses (1 star ... 8 skull), as unit type names and saved values.
local MARK_KEYS = { 'star', 'circle', 'diamond', 'triangle', 'moon', 'square', 'cross', 'skull' }
local MARK_INDEX = {}

for index, key in ipairs(MARK_KEYS) do
    MARK_INDEX[key] = index
end

-- The order the "highest priority marked unit" type tries the marks: skull first, star last.
local PRIORITY = { 8, 7, 6, 5, 4, 3, 2, 1 }

-- Static mark data for the files that build unit types, conditions and steps. keys[index] is the name of a mark,
-- index[name] its number, priority the order anymark tries them. Read only.
platform.RaidMarks = { keys = MARK_KEYS, index = MARK_INDEX, priority = PRIORITY }

-- The unit type names that stand for a marked unit: the eight marks, and anymark (the highest-priority marked unit).
local ANYMARK = 'anymark'

-- ============================================================================
-- Capability
-- ============================================================================

-- The seconds the events stay registered after the last question about marks.
local LEASE = 30

-- Returns whether the client has the function that reads a unit's mark.
local function canRead()
    return type(env.GetRaidTargetIndex) == 'function'
end

-- Tells whether a unit type name is one of the raid mark unit types.
-- @param kind any  A saved unit field.
-- @return boolean  True for skull ... star and anymark.
function platform:IsRaidMarkUnitKind(kind)
    return type(kind) == 'string' and (MARK_INDEX[kind] ~= nil or kind == ANYMARK)
end

-- Tells why raid marks cannot be read on this client.
-- @return string|nil  nil when marks can be read; 'unsupported-client' on Retail and Forever, 'unsupported-policy' on
--   a client with no known data policy, or 'missing-api' when the client has no GetRaidTargetIndex.
function platform:GetRaidMarkSupport()
    local family = self:GetClientFamily()

    if family == 'retail' or family == 'forever' then
        return 'unsupported-client'
    end

    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return 'unsupported-policy'
    end
    if not canRead() then
        return 'missing-api'
    end
end

-- Asks the event catalog whether the client knows an event.
-- @param event string  An event name.
-- @return boolean|nil  True or false as the catalog answers; nil when the client has no catalog or it failed.
local function eventKnown(event)
    local utils = env.C_EventUtils

    if type(utils) ~= 'table' or type(utils.IsEventValid) ~= 'function' then
        return nil
    end

    local ok, valid = pcall(utils.IsEventValid, event)

    if ok and type(valid) == 'boolean' then
        return valid
    end
end

-- The events the table follows, with the unit tokens each one changes. Each is registered only when the client has it.
local EVENTS = {
    'RAID_TARGET_UPDATE', 'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED', 'UPDATE_MOUSEOVER_UNIT',
    'NAME_PLATE_UNIT_ADDED', 'NAME_PLATE_UNIT_REMOVED', 'GROUP_ROSTER_UPDATE', 'UNIT_TARGET',
    'INSTANCE_ENCOUNTER_ENGAGE_UNIT', 'ARENA_OPPONENT_UPDATE', 'PLAYER_SOFT_ENEMY_CHANGED',
    'PLAYER_SOFT_FRIEND_CHANGED', 'PLAYER_ENTERING_WORLD'
}

-- Describes what this client offers for following marks, for /rm debug marks and for tests. Allocates; not for the
-- poll.
-- @return table  { read = boolean, set = boolean, command = boolean, tokenFromGUID = boolean,
--   events = { [event] = boolean|nil } } where an event is true or false as the event catalog answers and nil when the
--   client has no catalog.
function platform:GetRaidMarkCapabilities()
    local events = {}

    for _, event in ipairs(EVENTS) do
        events[event] = eventKnown(event)
    end

    local commands = env.SecureCmdList
    local slash = env.SlashCmdList

    return {
        read = canRead(),
        set = type(env.SetRaidTarget) == 'function',
        command = type(commands) == 'table' and commands.TARGET_MARKER ~= nil
            or type(slash) == 'table' and slash.TARGET_MARKER ~= nil,
        tokenFromGUID = type(env.UnitTokenFromGUID) == 'function',
        events = events,
    }
end

-- ============================================================================
-- Reading one unit
-- ============================================================================

-- Reads the mark a unit token carries right now.
-- @param unit string  A unit token such as 'target' or 'raid3'; the unit need not exist.
-- @return number|nil  0 for no mark, 1 (star) to 8 (skull); nil when it cannot be read.
-- @return string|nil  Why the first return is nil: 'missing-api', 'invalid-unit' (unit is not a string), 'api-error',
--   'restricted-value', 'invalid-api-result', 'unsupported-client' or 'unsupported-policy'; nil otherwise.
--
-- The one place that calls GetRaidTargetIndex. A missing mark is 0 (the game returns nil for it).
function platform:GetUnitRaidMark(unit)
    local unsupported = self:GetRaidMarkSupport()

    if unsupported then
        return nil, unsupported
    end

    local read = env.GetRaidTargetIndex

    if type(read) ~= 'function' then
        return nil, 'missing-api'
    end
    if type(unit) ~= 'string' then
        return nil, 'invalid-unit'
    end

    local ok, index = pcall(read, unit)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(index) then
        return nil, 'restricted-value'
    end
    if index == nil then
        return 0
    end
    if type(index) ~= 'number' or index < 0 or index > 8 or index % 1 ~= 0 then
        return nil, 'invalid-api-result'
    end

    return index
end

-- ============================================================================
-- The table
-- ============================================================================

-- One record per mark, reused in place. held says the table knows a unit with this mark; token is the token that holds
-- it now (nil while the unit is out of reach); lastToken the last one that did; reachable whether the unit can be read
-- now; seen when it was last verified; enemy and friend what was read from it (nil when unreadable).
local entries = {}

for index = 1, 8 do
    entries[index] = { held = false, reachable = false, seen = 0 }
end

-- Facts about the watch itself, read by the debug report and by tests.
local watch = {
    active = false,
    frame = nil,
    lastUse = 0,
    timer = false,
    registered = {},
    scans = 0,
    updates = 0,
    unreadable = 0,
    lastScan = nil,
    stops = 0,
    starts = 0,
    failedAt = nil,
}

-- Scratch for one rescan: the first token seen holding each mark.
local found = {}

-- Reads the clock; 0 on a client with no GetTime.
local function clock()
    local now = env.GetTime
    return type(now) == 'function' and now() or 0
end

-- Calls a game function that answers a boolean about two units; true, false, or nil when it cannot be read.
-- @param fn function|nil  The game function to call (UnitCanAttack or UnitIsFriend); anything else answers nil.
-- @param ... any  The arguments passed to fn.
-- @return boolean|nil  True for true or 1; false for false, 0 or nil; nil when fn is missing, raised or answered a
--   restricted value (or any other value).
local function readBoolean(fn, ...)
    if type(fn) ~= 'function' then
        return nil
    end

    local ok, value = pcall(fn, ...)

    if not ok or not platform:CanReadValue(value) then
        return nil
    end
    if value == true or value == 1 then
        return true
    end
    if value == false or value == 0 or value == nil then
        return false
    end
end

-- Reads the GUID of a unit token; nil when it cannot be read (an NPC's GUID is secret on a restricted client).
-- @param token string  The unit token.
-- @return string|nil  The unit's GUID; nil when UnitGUID is missing, raised, was restricted or answered something that
--   is not a non-empty string.
local function readGUID(token)
    local read = env.UnitGUID

    if type(read) ~= 'function' then
        return nil
    end

    local ok, guid = pcall(read, token)

    if ok and platform:CanReadValue(guid) and type(guid) == 'string' and guid ~= '' then
        return guid
    end
end

-- Finds the token that stands for a GUID right now, where the client can say.
-- @param guid string  A unit GUID.
-- @return string|nil  The unit token, or nil when the unit is not in reach or the client cannot answer.
local function tokenFromGUID(guid)
    local find = env.UnitTokenFromGUID

    if type(find) ~= 'function' then
        return nil
    end

    local ok, token = pcall(find, guid)

    if ok and platform:CanReadValue(token) and type(token) == 'string' and token ~= '' then
        return token
    end
end

-- Forgets what the table knows about one mark.
-- @param entry table  The record of the mark, cleared in place.
local function drop(entry)
    entry.held, entry.reachable = false, false
    entry.guid, entry.token, entry.lastToken, entry.enemy, entry.friend = nil, nil, nil, nil, nil
end

-- Marks the table as changed, so the idle gate evaluates the next tick.
local function changed()
    watch.updates = watch.updates + 1
    local gate = addon.idleGate

    if type(gate) == 'table' then
        gate.dirty = true
    end
end

-- Records that the unit behind `token` holds mark `index`, and forgets any other mark the same unit was recorded with.
-- @param index number  The mark, 1 to 8.
-- @param token string  A token that reads that mark now.
--
-- The table is updated in place and changed() is called when anything differs.
local function hold(index, token)
    local entry = entries[index]
    local guid = readGUID(token)
    local differs = not entry.held or entry.token ~= token or entry.guid ~= guid or not entry.reachable
    entry.held, entry.reachable = true, true
    entry.guid, entry.token, entry.lastToken, entry.seen = guid, token, token, clock()
    entry.enemy = readBoolean(env.UnitCanAttack, 'player', token)
    entry.friend = readBoolean(env.UnitIsFriend, 'player', token)

    -- A unit carries one mark: another record with this GUID, or one that thought this token was someone else, is stale.
    for other = 1, 8 do
        local record = entries[other]

        if other ~= index and record.held then
            if guid ~= nil and record.guid == guid then
                drop(record)
                differs = true
            elseif record.token == token then
                record.token, record.reachable = nil, false
                differs = true
            end
        end
    end

    if differs then
        changed()
    end
end

-- Looks for the unit of a recorded mark after its token stopped holding it.
-- @param index number  The mark, 1 to 8.
--
-- The record is re-pointed at a token that still holds the mark, dropped when its unit is in reach and no longer
-- carries the mark, or kept by GUID and flagged out of reach otherwise.
local function relocate(index)
    local entry = entries[index]

    if not entry.held then
        return
    end

    local token = entry.guid and tokenFromGUID(entry.guid)

    if token then
        local current = platform:GetUnitRaidMark(token)

        if current == index then
            if entry.token ~= token or not entry.reachable then
                changed()
            end

            entry.token, entry.lastToken, entry.reachable, entry.seen = token, token, true, clock()
            return
        end

        -- The unit is in reach and does not carry the mark any more: the mark is gone.
        if current ~= nil then
            drop(entry)
            changed()
            return
        end
    end

    if entry.reachable or entry.token ~= nil then
        changed()
    end

    entry.token, entry.reachable = nil, false
end

-- Reads one token and brings the table up to date for it.
-- @param token string  A token whose unit may have changed.
local function tokenChanged(token)
    local mark = platform:GetUnitRaidMark(token)

    -- An unreadable token proves nothing either way: the table is left as it is.
    if mark == nil then
        return
    end

    for index = 1, 8 do
        local entry = entries[index]

        if entry.held and entry.token == token and index ~= mark then
            relocate(index)
        end
    end

    if mark > 0 then
        hold(mark, token)
    end
end

-- ============================================================================
-- Rescan
-- ============================================================================

-- Token names built once, so a rescan builds no strings.
local RAID, RAID_TARGET, PARTY, PARTY_TARGET, BOSS, ARENA, PLATE = {}, {}, {}, {}, {}, {}, {}

for index = 1, 40 do
    RAID[index], RAID_TARGET[index] = 'raid' .. index, 'raid' .. index .. 'target'
    PLATE[index] = 'nameplate' .. index
end

for index = 1, 4 do
    PARTY[index], PARTY_TARGET[index] = 'party' .. index, 'party' .. index .. 'target'
end

for index = 1, 8 do
    BOSS[index] = 'boss' .. index
end

for index = 1, 5 do
    ARENA[index] = 'arena' .. index
end

-- Reads one token during a rescan and remembers the first token seen carrying each mark.
-- @param token string  The unit token to read.
--
-- A token that is restricted counts in watch.unreadable; any other unreadable token is ignored.
local function visit(token)
    local mark, why = platform:GetUnitRaidMark(token)

    if mark == nil then
        if why == 'restricted-value' then
            watch.unreadable = watch.unreadable + 1
        end

        return
    end

    if mark > 0 and not found[mark] then
        found[mark] = token
    end
end

-- Reads the size of the group.
-- @return boolean  Whether the group is a raid.
-- @return number  The members, capped at 40; 0 when alone or when the client cannot say.
local function groupSize()
    local count, raid = env.GetNumGroupMembers, env.IsInRaid

    if type(count) ~= 'function' then
        return false, 0
    end

    local ok, size = pcall(count)

    if not ok or not platform:CanReadValue(size) or type(size) ~= 'number' or size ~= size or size < 0 then
        return false, 0
    end

    if size > 40 then
        size = 40
    end

    local inRaid = false

    if type(raid) == 'function' then
        local called, answer = pcall(raid)

        if called and platform:CanReadValue(answer) then
            inRaid = answer == true or answer == 1
        end
    end

    return inRaid, size - size % 1
end

-- Rebuilds the table from every token the client can reach.
--
-- For each mark the first token that carries it is recorded, a mark held but seen nowhere is looked up by its GUID, and
-- watch.unreadable counts the tokens that could not be read (the table is then incomplete).
local function rescan()
    watch.scans = watch.scans + 1
    watch.unreadable = 0
    watch.lastScan = clock()

    for index = 1, 8 do
        found[index] = nil
    end

    local registered = watch.registered
    visit('player')
    visit('target')

    if registered.PLAYER_FOCUS_CHANGED then
        visit('focus')
    end

    visit('mouseover')

    if registered.PLAYER_SOFT_ENEMY_CHANGED then
        visit('softenemy')
    end
    if registered.PLAYER_SOFT_FRIEND_CHANGED then
        visit('softfriend')
    end

    visit('pet')
    local raid, size = groupSize()

    if raid then
        for index = 1, size do
            visit(RAID[index])
        end

        for index = 1, size do
            visit(RAID_TARGET[index])
        end
    else
        for index = 1, math.min(4, size - 1) do
            visit(PARTY[index])
            visit(PARTY_TARGET[index])
        end
    end

    if registered.INSTANCE_ENCOUNTER_ENGAGE_UNIT then
        for index = 1, 8 do
            visit(BOSS[index])
        end
    end

    if registered.ARENA_OPPONENT_UPDATE then
        for index = 1, 5 do
            visit(ARENA[index])
        end
    end

    if registered.NAME_PLATE_UNIT_ADDED then
        for index = 1, 40 do
            visit(PLATE[index])
        end
    end

    for index = 1, 8 do
        local token = found[index]

        if token then
            hold(index, token)
        elseif entries[index].held then
            relocate(index)
        end
    end
end

-- ============================================================================
-- Events and the lease
-- ============================================================================

-- Forgets every record; used when the world changes under the table.
local function clear()
    for index = 1, 8 do
        if entries[index].held then
            drop(entries[index])
            changed()
        end
    end
end

-- Forward declaration: the lease check stops the watch, and the watch schedules the lease check.
local stopWatch

-- Reads one event and brings the table up to date. Runs only while the watch is active.
-- @param event string  The event name.
-- @param unit string|nil  The unit token the event carries, where it has one; an unreadable or non-string value is
--   ignored.
-- @return nil  Nothing: the expired-lease path returns the result of stopWatch, which returns none.
--
-- An event that arrives after the lease ran out stops the watch instead of being handled.
local function onEvent(event, unit)
    if clock() - watch.lastUse > LEASE then
        return stopWatch()
    end

    if event == 'PLAYER_TARGET_CHANGED' then
        tokenChanged('target')
    elseif event == 'PLAYER_FOCUS_CHANGED' then
        tokenChanged('focus')
    elseif event == 'UPDATE_MOUSEOVER_UNIT' then
        tokenChanged('mouseover')
    elseif event == 'PLAYER_SOFT_ENEMY_CHANGED' then
        tokenChanged('softenemy')
    elseif event == 'PLAYER_SOFT_FRIEND_CHANGED' then
        tokenChanged('softfriend')
    elseif event == 'NAME_PLATE_UNIT_ADDED' or event == 'NAME_PLATE_UNIT_REMOVED' then
        if platform:CanReadValue(unit) and type(unit) == 'string' then
            tokenChanged(unit)
        end
    elseif event == 'UNIT_TARGET' then
        -- Only a unit the table can hold a target of matters; the event fires for every unit that changes target.
        if platform:CanReadValue(unit) and type(unit) == 'string' then
            if
                string.sub(unit, 1, 4) == 'raid'
                or string.sub(unit, 1, 5) == 'party'
                or string.sub(unit, 1, 4) == 'boss'
            then
                tokenChanged(unit .. 'target')
            end
        end
    elseif event == 'PLAYER_ENTERING_WORLD' then
        clear()
        rescan()
    else
        rescan()
    end
end

-- The lease check scheduled while the watch runs; stops the watch once nothing has asked for marks for LEASE seconds,
-- otherwise looks again when the lease would run out.
-- @return nil  Nothing: the expired-lease path returns the result of stopWatch, which returns none.
local function leaseCheck()
    watch.timer = false

    if not watch.active then
        return
    end

    local idle = clock() - watch.lastUse

    if idle >= LEASE then
        return stopWatch()
    end

    local timer = env.C_Timer

    if type(timer) == 'table' and type(timer.After) == 'function' then
        watch.timer = true
        timer.After(LEASE - idle + 1, leaseCheck)
    end
end

-- Registers the events and takes a first full rescan.
-- @return boolean  True once the watch is running; false when the client cannot make a frame or register an event.
local function startWatch()
    if type(env.CreateFrame) ~= 'function' then
        return false
    end

    if not watch.frame then
        local ok, frame = pcall(env.CreateFrame, 'Frame')

        if
            not ok
            or type(frame) ~= 'table'
            or type(frame.RegisterEvent) ~= 'function'
            or type(frame.SetScript) ~= 'function'
        then
            return false
        end

        frame:SetScript('OnEvent', function(_, event, unit)
            onEvent(event, unit)
        end)

        watch.frame = frame
    end

    local frame, any = watch.frame, false

    for _, event in ipairs(EVENTS) do
        local known = eventKnown(event)
        local registered = false

        if known ~= false then
            registered = pcall(frame.RegisterEvent, frame, event)
        end

        watch.registered[event] = registered

        if registered then
            any = true
        end
    end

    if not any then
        return false
    end

    watch.active, watch.starts = true, watch.starts + 1
    rescan()
    local timer = env.C_Timer

    if not watch.timer and type(timer) == 'table' and type(timer.After) == 'function' then
        watch.timer = true
        timer.After(LEASE + 1, leaseCheck)
    end

    return true
end

-- Drops the events and the table.
stopWatch = function()
    if not watch.active then
        return
    end

    watch.active = false
    watch.stops = watch.stops + 1
    local frame = watch.frame

    if frame and type(frame.UnregisterAllEvents) == 'function' then
        frame:UnregisterAllEvents()
    end

    for event in pairs(watch.registered) do
        watch.registered[event] = false
    end

    clear()
end

-- Records that something is asking about marks, starting the watch if it is not running.
-- @return boolean  Whether the table is being kept current; false (without retrying for 5 seconds) when the watch
--   could not be started.
local function touch()
    local now = clock()
    watch.lastUse = now

    if watch.active then
        return true
    end

    -- A client that cannot follow marks is not asked again on every poll.
    if watch.failedAt and now - watch.failedAt < 5 then
        return false
    end

    local started = startWatch()
    watch.failedAt = not started and now or nil
    return started
end

-- Stops following marks now and forgets the table; the next question starts it again.
function platform:ReleaseRaidMarks()
    stopWatch()
end

-- Tells whether the events are registered.
-- @return boolean  True while the table is being kept current.
function platform:IsRaidMarkWatching()
    return watch.active == true
end

-- ============================================================================
-- Questions over the table
-- ============================================================================

-- Finds the token that holds a mark now, verifying it with one read.
-- @param index number  The mark, 1 to 8.
-- @return string|nil  The token holding the mark.
-- @return string|nil  Why the first return is nil: 'no-marked-unit' when no unit is known to hold it, 'unreadable'
--   when the table cannot say, 'no-token' when the unit is known but out of reach; nil otherwise.
local function resolveIndex(index)
    local entry = entries[index]

    if not entry.held then
        if watch.unreadable > 0 then
            return nil, 'unreadable'
        end

        return nil, 'no-marked-unit'
    end

    local token = entry.token

    if token then
        local current = platform:GetUnitRaidMark(token)

        if current == index then
            return token
        end
        if current == nil then
            return nil, 'unreadable'
        end

        relocate(index)

        if not entry.held then
            return nil, 'no-marked-unit'
        end

        token = entry.token

        if token then
            return token
        end
    end

    return nil, 'no-token'
end

-- Turns a mark unit type into the token of the unit that carries the mark right now.
-- @param kind string  skull, cross, square, moon, triangle, diamond, circle, star or anymark; any other value answers
--   'invalid-group-unit'.
-- @return string|nil  The unit token, such as 'target' or 'raid7'.
-- @return string|nil  Why there is none: 'invalid-group-unit', 'missing-api', 'unsupported-policy', 'no-marked-unit',
--   'unreadable' or 'no-token'; nil when there is a token.
--
-- anymark answers the first mark in skull, cross, square, moon, triangle, diamond, circle, star order that has a
-- reachable unit; when none does, the reason of the highest-priority mark the table knows (else 'no-marked-unit').
function platform:ResolveRaidMarkUnit(kind)
    local unsupported = self:GetRaidMarkSupport()

    if unsupported then
        return nil, unsupported
    end

    local single = MARK_INDEX[kind]

    if not single and kind ~= ANYMARK then
        return nil, 'invalid-group-unit'
    end
    if not touch() then
        return nil, 'missing-api'
    end
    if single then
        return resolveIndex(single)
    end

    local firstReason

    for _, index in ipairs(PRIORITY) do
        local token, reason = resolveIndex(index)

        if token then
            return token
        end

        if entries[index].held and not firstReason then
            firstReason = reason
        end
    end

    if firstReason then
        return nil, firstReason
    end
    if watch.unreadable > 0 then
        return nil, 'unreadable'
    end

    return nil, 'no-marked-unit'
end

-- Counts the marks the table knows a unit for.
-- @param filter string|nil  nil or 'any' for every marked unit; 'enemy' for the ones you can attack; 'friendly' for
--   the friendly ones.
-- @return number|nil  The marked units known, out-of-reach ones included; nil when it cannot be counted.
-- @return string|nil  Why the count is nil: 'missing-api', 'unsupported-policy', or 'unreadable' when a token could not
--   be read or a filter fact is unknown for a marked unit; nil otherwise.
function platform:GetRaidMarkCount(filter)
    local unsupported = self:GetRaidMarkSupport()

    if unsupported then
        return nil, unsupported
    end
    if not touch() then
        return nil, 'missing-api'
    end
    if watch.unreadable > 0 then
        return nil, 'unreadable'
    end

    local count = 0

    for index = 1, 8 do
        local entry = entries[index]

        if entry.held then
            if filter == 'enemy' then
                if entry.enemy == nil then
                    return nil, 'unreadable'
                end

                if entry.enemy then
                    count = count + 1
                end
            elseif filter == 'friendly' then
                if entry.friend == nil then
                    return nil, 'unreadable'
                end

                if entry.friend then
                    count = count + 1
                end
            else
                count = count + 1
            end
        end
    end

    return count
end

-- Copies the table and the watch for /rm debug marks and for tests. Allocates; never called by the poll.
-- @return table  { watching, now, scans, updates, unreadable, lastScan, starts, stops, failedAt,
--   registered = { [event] = boolean },
--   marks = { [1..8] = { held, guid, token, lastToken, reachable, age, enemy, friend } } }
function platform:GetRaidMarkSnapshot()
    local now = clock()
    local marks, registered = {}, {}

    for index = 1, 8 do
        local entry = entries[index]

        marks[index] = {
            held = entry.held,
            guid = entry.guid,
            token = entry.token,
            lastToken = entry.lastToken,
            reachable = entry.reachable,
            age = entry.held and now - entry.seen or nil,
            enemy = entry.enemy,
            friend = entry.friend,
        }
    end

    for event, value in pairs(watch.registered) do
        registered[event] = value
    end

    return {
        watching = watch.active,
        now = now,
        scans = watch.scans,
        updates = watch.updates,
        unreadable = watch.unreadable,
        lastScan = watch.lastScan,
        starts = watch.starts,
        stops = watch.stops,
        failedAt = watch.failedAt,
        registered = registered,
        marks = marks,
    }
end

-- Starts following marks for the debug report and returns the snapshot; the same lease applies as for any question.
-- @return table  The snapshot; see GetRaidMarkSnapshot.
function platform:ObserveRaidMarks()
    if not self:GetRaidMarkSupport() then
        touch()
    end

    return self:GetRaidMarkSnapshot()
end
