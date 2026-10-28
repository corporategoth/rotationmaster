-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- /rm debug timeline (Diagnostics/timeline.lua): a read-only probe of
-- Blizzard's encounter timeline. It must say which functions exist, mark every
-- event field readable or secret (and flag a field the documentation calls
-- NeverSecret that is secret), survive a missing API, a throwing call and an
-- unreadable value, keep to its caps, save for SavedVariables, and register
-- its events only while a watch runs.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local SECRET = setmetatable({}, { __tostring = function() return 'secret' end })

local function client(project)
    local f = F.new(project or 1, 12, 'WARRIOR')
    local e = f.env
    local a = f.addon

    for _, path in ipairs({ 'Diagnostics/glow.lua', 'Diagnostics/timeline.lua' }) do
        f.load(path)
    end

    e.RotationMasterDB = {}
    e.issecretvalue = function(v) return rawequal(v, SECRET) end
    e.canaccessvalue = function(v) return not rawequal(v, SECRET) end

    a.Platform.CanReadValue = function(_, v)
        if rawequal(v, SECRET) then
            return false, 'restricted-value'
        end

        return true
    end

    local game = {
        events = {
            [101] = {
                state = 0,
                left = 12.5,
                track = 2,
                info = {
                    id = 101,
                    source = 0,
                    duration = 30,
                    maxQueueDuration = 0,
                    spellName = SECRET,
                    spellID = SECRET,
                    iconFileID = SECRET,
                    icons = SECRET,
                    severity = SECRET,
                    isApproximate = false,
                },
            },
            [102] = {
                state = 1,
                left = 40,
                track = 3,
                info = {
                    id = 102,
                    source = 0,
                    duration = SECRET,
                    maxQueueDuration = 0,
                    spellName = 'Ability',
                    spellID = 1,
                    iconFileID = 2,
                    icons = 0,
                    severity = 1,
                    isApproximate = true,
                },
            },
        },
    }

    e.C_EncounterTimeline = {
        IsFeatureAvailable = function() return true end,
        IsFeatureEnabled = function() return true end,
        HasAnyEvents = function() return true end,
        HasActiveEvents = function() return true end,
        HasPausedEvents = function() return false end,
        HasVisibleEvents = function() return true end,
        GetCurrentTime = function() return 5 end,
        GetViewType = function() return 0 end,
        GetEventList = function() return { 101, 102 } end,
        GetSortedEventList = function() return { 101, 102 } end,
        GetEventState = function(id) return game.events[id].state end,
        GetEventTimeRemaining = function(id) return game.events[id].left end,
        GetEventTimeElapsed = function() return 0 end,
        GetEventTrack = function(id) return game.events[id].track end,
        GetEventInfo = function(id) return game.events[id].info end,
        IsEventBlocked = function() return false end,
        GetEventCountBySource = function() return 2 end,
    }

    e.C_InstanceEncounter = { IsEncounterInProgress = function() return true end }
    local printed, shown = {}, {}

    a.print = function(_, message, ...)
        printed[#printed + 1] = string.format(message, ...)
    end

    a.ShowConditionText = function(_, text, heading)
        shown.text, shown.heading = text, heading
    end

    local timers = {}

    a.ScheduleRepeatingTimer = function(_, fn, interval)
        timers[#timers + 1] = { fn = fn, interval = interval }
        return #timers
    end

    a.CancelTimer = function(_, id)
        if timers[id] then
            timers[id].cancelled = true
        end
    end

    local frames = {}
    local create = e.CreateFrame

    e.CreateFrame = function(...)
        local frame = create(...)
        frame.registered = {}

        function frame:RegisterEvent(event)
            self.registered[event] = true
        end

        function frame:UnregisterAllEvents()
            self.registered = {}
        end

        function frame:SetScript(name, fn)
            self[name] = fn
        end

        frames[#frames + 1] = frame
        return frame
    end

    return f, a, e, game, printed, shown, timers, frames
end

local function find(lines, pattern)
    for _, line in ipairs(lines) do
        if line:find(pattern) then
            return line
        end
    end
end

test('the snapshot lists the functions, the state, and every event field as a value or secret', function()
    local _, a, e, game, printed, shown = client()
    local lines = a:RunTimelineDiagnostic()
    assert(find(lines, '^== Encounter timeline probe') and find(lines, '^client family=retail'))
    assert(find(lines, '^functions missing: none'))
    assert(find(lines, '^HasActiveEvents %-> true') and find(lines, '^GetCurrentTime %-> 5'))
    assert(find(lines, '^encounter in progress=true'))
    assert(find(lines, '^GetEventList %-> 2 events'))
    assert(find(lines, 'event 101: state=0 remaining=12.500 track=2 blocked=false'), tostring(find(lines, 'event 101')))

    assert(
        find(
            lines,
            'spellName=secret spellID=secret iconFileID=secret icons=secret severity=secret isApproximate=false'
        ),
        'secret fields are named'
    )

    assert(
        find(lines, 'duration=secret') and find(lines, 'documented NeverSecret!'),
        'a NeverSecret field that is secret is flagged'
    )

    assert(find(lines, 'spellName=Ability spellID=1'), 'readable fields show their values')
    assert(find(lines, '^GetSortedEventList%(12%) %-> %[101,102%] n=2'))
    assert(shown.heading == 'Timeline diagnostic' and shown.text == table.concat(lines, '\n'))
    local saved = e.RotationMasterDB.diagnostics.timeline
    assert(#saved == 1 and saved[1].lines == lines)
    assert(printed[1] == 'Timeline diagnostic saved.')
end)

test('a missing API, a throwing call and a secret list never raise an error', function()
    local _, a, e = client()
    e.C_EncounterTimeline = nil
    local lines = a:BuildTimelineDiagnostic()
    assert(find(lines, 'C_EncounterTimeline is MISSING'), 'missing API')
    local _, b, f = client()

    f.C_EncounterTimeline.GetEventList = function()
        error('boom')
    end

    f.C_EncounterTimeline.HasActiveEvents = function()
        error('blocked')
    end

    lines = b:BuildTimelineDiagnostic()
    assert(find(lines, 'GetEventList error: .*boom') and find(lines, 'HasActiveEvents %-> error: .*blocked'))
    local _, c, g = client()
    g.C_EncounterTimeline.GetEventList = function() return SECRET end
    lines = c:BuildTimelineDiagnostic()
    assert(find(lines, 'GetEventList %-> secret'))
    local _, d, h = client()
    h.C_EncounterTimeline.GetEventInfo = function() return SECRET end
    lines = d:BuildTimelineDiagnostic()
    assert(find(lines, 'info: record is secret'))
    local _, k, m = client()

    m.C_EncounterTimeline.GetEventInfo = function()
        error('no info')
    end

    lines = k:BuildTimelineDiagnostic()
    assert(find(lines, 'info: error: .*no info'))
end)

test('the report keeps to its line cap and to three saved reports', function()
    local _, a, e, game = client()
    local big = {}

    for i = 1, 200 do
        big[i] = 1000 + i
        game.events[1000 + i] = { state = 0, left = i, track = 1, info = { id = 1000 + i } }
    end

    e.C_EncounterTimeline.GetEventList = function() return big end
    local lines = a:BuildTimelineDiagnostic()
    assert(#lines <= 500)
    local count = 0

    for _, l in ipairs(lines) do
        if l:find('^  event ') then
            count = count + 1
        end
    end

    assert(count == 12, 'only the first 12 events are expanded: ' .. count)

    for _ = 1, 5 do
        a:RunTimelineDiagnostic()
    end

    assert(#e.RotationMasterDB.diagnostics.timeline == 3)
    a:RunTimelineDiagnostic('show')
end)

test('a watch registers its events only while it runs, logs each arrival and one line per second', function()
    local _, a, e, game, printed, shown, timers, frames = client()
    local lines = a:RunTimelineDiagnostic('3')

    assert(
        #frames == 1
            and frames[1].registered.ENCOUNTER_TIMELINE_EVENT_ADDED
            and frames[1].registered.ENCOUNTER_START
            and frames[1].registered.ENCOUNTER_END
    )

    assert(shown.text == nil, 'a watch does not open the window until it is read')
    assert(printed[#printed] == 'Timeline diagnostic saved. Watching for 3 seconds.')

    frames[1].OnEvent(frames[1], 'ENCOUNTER_TIMELINE_EVENT_ADDED', {
        id = 103,
        source = 0,
        duration = 20,
        maxQueueDuration = 0,
        spellName = SECRET,
        spellID = SECRET,
        iconFileID = SECRET,
        icons = SECRET,
        severity = SECRET,
        isApproximate = false,
    })

    frames[1].OnEvent(frames[1], 'ENCOUNTER_END', 2417, 'Boss', 16, 20, 1)

    assert(
        find(lines, 'ENCOUNTER_TIMELINE_EVENT_ADDED id=103 source=0 duration=20.*spellName=secret'),
        'the payload fields are marked'
    )

    assert(find(lines, 'ENCOUNTER_END 2417'), 'a plain payload is shown')
    local timer = timers[1]
    timer.fn()
    timer.fn()

    assert(find(lines, 'encounter=true active=true next=%[101:12.500s/0 102:40s/1%]'), tostring(find(
        lines,
        'encounter='
    )))

    assert(next(frames[1].registered) and not timer.cancelled)
    timer.fn()
    assert(timer.cancelled and next(frames[1].registered) == nil, 'the watch unregisters its events when it ends')
    assert(printed[#printed] == 'Timeline watch finished. Run /rm debug timeline show to view it.')
    a:RunTimelineDiagnostic('show')
    assert(shown.text:find('Watch for 3s'))
end)

test('stop ends a watch early, and a bad argument prints usage', function()
    local _, a, e, _, printed, _, timers, frames = client()
    a:RunTimelineDiagnostic('stop')
    assert(printed[#printed] == 'No timeline watch is running.')
    a:RunTimelineDiagnostic('60')
    a:RunTimelineDiagnostic('stop')
    assert(timers[1].cancelled and next(frames[1].registered) == nil)
    a:RunTimelineDiagnostic('soon')
    assert(printed[#printed] == 'Usage: /rm debug timeline [seconds|show|stop]')
    a:RunTimelineDiagnostic('9999')
    local last = #timers
    assert(frames[#frames].registered.ENCOUNTER_START)
end)

test('the debug command and the help list reach it', function()
    local _, a = client()
    local called

    a.RunTimelineDiagnostic = function(_, argument)
        called = argument
    end

    a:HandleDebugCommand('timeline 30')
    assert(called == '30')
    local text = assert(io.open('main.lua')):read('*a')
    assert(text:find('/rm debug timeline [seconds]', 1, true), 'the help list names the command')
end)

finish()
