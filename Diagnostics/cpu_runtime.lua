-- Native runtime capture: measures normal outer EvaluateNextAction dispatches with Blizzard's C_AddOnProfiler
-- (MeasureCall) for a bounded run (default 10 s, at most 60 s or 512 dispatches) and renders a text report with time,
-- gross allocation, per-phase rows, decision counts and runtime diagnostic deltas.
-- Owns the capture state and the Start, Stop, Cancel, IsRunning and GetReport entry points. While a capture runs it
-- temporarily replaces addon.EvaluateNextAction and the profiler's child lookup, and restores both when the run ends or
-- any identity it relies on changes; it must never start evaluation, reset counters or leave a lasting hook.
-- Never runs beside the cumulative CPU profile (Diagnostics/cpu.lua refuses to start while this runs, and this refuses
-- to start while that runs). Loaded from RotationMaster.toc after Diagnostics/cpu.lua.
local addon_name, addon = ...
-- Explicit native measurements of normal outer evaluator dispatches. This
-- module never starts evaluation, resets counters, or installs a lasting hook.
local active, lastReport
local LIMIT, SAFE = 512, 9007199254740991

-- ============================================================================
-- Value guards
-- ============================================================================

-- Packs varargs with their count, so a trailing nil is not lost.
local function tuple(...)
    return { n = select('#', ...), ... }
end

-- True when value is neither a secret nor inaccessible; a throwing check counts as unreadable.
local function readable(value)
    local secret = rawget(_G, 'issecretvalue')

    if type(secret) == 'function' then
        local ok, v = pcall(secret, value)

        if not ok or v ~= false then
            return false
        end
    end

    local access = rawget(_G, 'canaccessvalue')

    if type(access) == 'function' then
        local ok, v = pcall(access, value)

        if not ok or v ~= true then
            return false
        end
    end

    return true
end

-- True for a readable finite number.
local function finite(v)
    return readable(v) and type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

-- Returns t[k] without invoking metamethods, or nil when t is unreadable or not a table.
local function field(t, k)
    if readable(t) and type(t) == 'table' then
        return rawget(t, k)
    end
end

-- Returns a byte counter as a whole non-negative number up to 2^53 - 1 (a string of at most 16 digits is converted),
-- or nil when it is anything else.
local function bytes(v)
    if not readable(v) then
        return
    end

    if type(v) == 'string' then
        if #v == 0 or #v > 16 or not v:match('^%d+$') then
            return
        end

        v = tonumber(v)
    end

    if finite(v) and v >= 0 and v <= SAFE and v % 1 == 0 then
        return v
    end
end

-- Reads the run's clock under pcall; returns a finite number or nil.
local function now(run)
    local ok, v = pcall(run.clock)

    if ok and finite(v) then
        return v
    end
end

-- True while C_AddOnProfiler and the two functions captured at start are still the very same objects.
local function providerCurrent(run)
    return rawequal(rawget(_G, 'C_AddOnProfiler'), run.provider)
        and rawequal(rawget(run.provider, 'IsEnabled'), run.enabled)
        and rawequal(rawget(run.provider, 'MeasureCall'), run.measure)
end

-- True while run is the active running capture and its dispatch wrapper is still installed on the addon.
local function current(run)
    return active == run and run.phase == 'running' and rawequal(rawget(addon, 'EvaluateNextAction'), run.wrapper)
end

-- ============================================================================
-- Decision counts
-- ============================================================================

-- Consumed once by Main; the sink receives fixed scalar enums only.
local decisionSetter, decisionBound, decisionOwner

-- One-shot handoff from main.lua of the function that installs or clears the evaluator's decision counter sink.
-- Returns true on the first valid call; later calls do nothing.
function addon:BindCPURuntimeDecisionCounts(setter)
    if self ~= addon or decisionBound or type(setter) ~= 'function' then
        return
    end

    decisionBound = true
    decisionSetter = setter
    return true
end

-- Sets up the run's decision tables (rotation and cooldown rows, nine counters each) and the sink the evaluator calls
-- with (scope, event) for each reached decision. The sink only counts while a measured dispatch is executing.
local function decisionPrepare(run)
    run.decisionComplete = 0
    run.decisionAvailable = type(decisionSetter) == 'function'

    run.decisionFields = {
        'attempted', 'matched', 'notMatchedOrUnavailable', 'skippedDisabled', 'skippedNoAction', 'mapped', 'unmapped',
        'ready', 'notReady'
    }

    run.decisionIndex = {
        attempt = 1,
        matched = 2,
        notmatched = 3,
        disabled = 4,
        noaction = 5,
        mapped = 6,
        unmapped = 7,
        ready = 8,
        notready = 9,
    }

    run.decisionTotals = { {0, 0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0, 0} }
    run.decisionScratch = { {0, 0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0, 0} }

    run.decisionSink = function(scope, event)
        if not current(run) or not run.callbackInside or not run.decisionSampleOK then
            return
        end

        local row = scope == 'rotation' and 1 or scope == 'cooldowns' and 2
        local index = run.decisionIndex[event]
        local scratch = run.decisionScratch

        if row and index and scratch then
            scratch[row][index] = scratch[row][index] + 1
        end
    end
end

-- Gives the run's sink to the evaluator, when the handoff happened.
local function decisionInstall(run)
    if run.decisionAvailable then
        decisionOwner = run
        decisionSetter(run.decisionSink)
    end
end

-- Removes the sink, but only if this run is the one that installed it.
local function decisionRestore(run)
    if decisionOwner == run then
        decisionOwner = nil
        decisionSetter(nil)
    end
end

-- Adds one dispatch's scratch counts to the totals, only when the whole dispatch was counted cleanly.
local function decisionAccumulate(run)
    if not run.decisionSampleOK or not run.decisionScratch or decisionOwner ~= run then
        return
    end

    run.decisionComplete = run.decisionComplete + 1

    for row = 1, 2 do
        for index = 1, 9 do
            run.decisionTotals[row][index] = run.decisionTotals[row][index] + run.decisionScratch[row][index]
        end
    end
end

-- Appends the decision section of the report (counts, caveats about what was reached) to lines.
local function decisionReport(lines, run)
    lines[#lines + 1] = 'Decisions: complete='
        .. (run.decisionComplete or 0)
        .. '; unavailable='
        .. (run.measured - (run.decisionComplete or 0))

    lines[#lines
        + 1] = 'Counts are reached action decisions, not unique configured rows or all rotation clauses; unreached/short-circuited conditions are not counted false. Cooldowns count reached configured rows.'

    lines[#lines
        + 1] = 'Condition false combines not matched or unavailable. Mapping is the FindSpell cached button index, not visibility, glow or animation; one row can perform multiple mapping/readiness attempts.'

    if (run.decisionComplete or 0) > 0 then
        for row = 1, 2 do
            local parts = {}

            for index, name in ipairs(run.decisionFields) do
                parts[#parts + 1] = name .. '=' .. run.decisionTotals[row][index]
            end

            lines[#lines + 1] = (row == 1 and 'rotation' or 'cooldowns') .. ' decisions | ' .. table.concat(parts, '; ')
        end
    end
end

-- ============================================================================
-- Phase markers
-- ============================================================================

-- Capture-only markers at the existing six profiler child lookups. The real
-- child objects/methods are always returned and invoked by the original code.
local childNames = { 'environment', 'environment', 'rotation', 'rotation', 'cooldowns', 'cooldowns' }

local eventNames = {
    'RM:environment:start',
    'RM:environment:stop',
    'RM:rotation:start',
    'RM:rotation:stop',
    'RM:cooldowns:start',
    'RM:cooldowns:stop',
}

local phaseNames = {
    'selection+macro',
    'environment',
    'history+setup',
    'rotation',
    'transition',
    'cooldowns',
    'publication+tail',
}

-- True while the evaluation profile root, its child lookup wrapper and the native marker function are still the ones
-- the run captured.
local function phaseCurrent(run)
    return run.phaseRoot
        and rawequal(rawget(addon, 'evaluationProfile'), run.phaseRoot)
        and rawequal(rawget(run.phaseRoot, 'child'), run.childWrapper)
        and rawequal(rawget(run.provider, 'AddMeasuredCallEvent'), run.marker)
end

-- Prepares the phase rows and builds the child lookup wrapper that drops a native marker at each of the six expected
-- lookups, in order. If the profile shape is not recognized, phases are simply left unavailable for the run.
local function phasePrepare(run)
    decisionPrepare(run)
    run.phaseComplete = 0
    run.phaseRows = {}

    for i = 1, 7 do
        run.phaseRows[i] = { time = 0, allocated = 0, deallocated = 0 }
    end

    local root = field(addon, 'evaluationProfile')
    local child = field(root, 'child')
    local marker = field(run.provider, 'AddMeasuredCallEvent')

    if type(root) ~= 'table' or type(child) ~= 'function' or type(marker) ~= 'function' then
        return
    end

    run.phaseRoot, run.childOriginal, run.marker = root, child, marker

    run.childWrapper = function(self, ...)
        local name = (...)

        if rawequal(self, root) and run.callbackInside and current(run) then
            run.phasePosition = run.phasePosition + 1

            if not run.samplePhaseOK or not phaseCurrent(run) or childNames[run.phasePosition] ~= name then
                run.samplePhaseOK = false
            else
                local ok = pcall(marker, eventNames[run.phasePosition])

                if not ok or not current(run) or not phaseCurrent(run) then
                    run.samplePhaseOK = false
                end
            end
        end

        return child(self, ...)
    end
end

-- Swaps in the child lookup wrapper, only if nothing else changed the profile since phasePrepare.
local function phaseInstall(run)
    if
        run.phaseRoot
        and rawequal(rawget(addon, 'evaluationProfile'), run.phaseRoot)
        and rawequal(rawget(run.phaseRoot, 'child'), run.childOriginal)
        and rawequal(rawget(run.provider, 'AddMeasuredCallEvent'), run.marker)
    then
        rawset(run.phaseRoot, 'child', run.childWrapper)
    end
end

-- Puts the original child lookup back, only if the wrapper is still the installed one.
local function phaseRestore(run)
    if run.phaseRoot and rawequal(rawget(run.phaseRoot, 'child'), run.childWrapper) then
        rawset(run.phaseRoot, 'child', run.childOriginal)
    end
end

-- True for a readable number that is not a valid byte counter (negative, fractional or not finite).
local function invalidSnapshotCounter(value)
    return readable(value) and type(value) == 'number' and (not finite(value) or value < 0 or value % 1 ~= 0)
end

-- Splits one dispatch's native event list into seven consecutive phase intervals (time and byte differences) and adds
-- them to the run. A dispatch whose markers are missing, out of order or not monotonic is dropped whole, so phase rows
-- only ever hold complete samples.
local function phaseAccumulate(run, metrics, elapsed, allocated, deallocated)
    if not run.samplePhaseOK or run.phasePosition ~= 6 or not phaseCurrent(run) then
        return
    end

    local events = field(metrics, 'events')

    if not readable(events) or type(events) ~= 'table' or #events ~= 6 then
        return
    end

    local times, allocations, deallocations = { 0 }, { 0 }, { 0 }
    local allocOK, freeOK = allocated ~= nil, deallocated ~= nil

    for i = 1, 6 do
        local event = field(events, i)
        local name = field(event, 'name')

        if not readable(name) or name ~= eventNames[i] then
            return
        end

        local t = field(event, 'elapsedMilliseconds')

        if not finite(t) or t < times[i] or t > elapsed then
            return
        end

        times[i + 1] = t
        local rawA, rawD = field(event, 'allocatedBytes'), field(event, 'deallocatedBytes')

        if invalidSnapshotCounter(rawA) or invalidSnapshotCounter(rawD) then
            return
        end

        local a, d = bytes(rawA), bytes(rawD)

        if a == nil then
            allocOK = false
        elseif allocOK and (a < allocations[i] or a > allocated) then
            return
        end

        if d == nil then
            freeOK = false
        elseif freeOK and (d < deallocations[i] or d > deallocated) then
            return
        end

        allocations[i + 1], deallocations[i + 1] = a, d
    end

    times[8], allocations[8], deallocations[8] = elapsed, allocated, deallocated

    if not current(run) or not phaseCurrent(run) then
        return
    end

    run.phaseComplete = run.phaseComplete + 1

    for i, row in ipairs(run.phaseRows) do
        row.time = row.time + (times[i + 1] - times[i])

        if row.allocated ~= nil then
            row.allocated = allocOK and row.allocated + (allocations[i + 1] - allocations[i]) or nil

            if row.allocated and row.allocated > SAFE then
                row.allocated = nil
            end
        end

        if row.deallocated ~= nil then
            row.deallocated = freeOK and row.deallocated + (deallocations[i + 1] - deallocations[i]) or nil

            if row.deallocated and row.deallocated > SAFE then
                row.deallocated = nil
            end
        end
    end
end

-- ============================================================================
-- Boundary snapshots
-- ============================================================================

-- Returns the profile's poll interval as text, or "unavailable".
local function poll()
    local value = field(field(rawget(addon, 'db'), 'profile'), 'poll')
    return finite(value) and tostring(value) or 'unavailable'
end

-- Timer ticks the idle gate let through or skipped; skipped ticks never reach
-- EvaluateNextAction, so they are not dispatches in this capture.
-- Returns a flat copy of the idle gate and lean plan counters (scalars only), read at a capture boundary.
local function idleGate()
    local gate = rawget(addon, 'idleGate')
    local value = field(field(rawget(addon, 'db'), 'profile'), 'idle_poll')
    local lean = rawget(addon, 'leanStats')
    lean = type(lean) == 'table' and lean or {}

    return {
        interval = finite(value) and tostring(value) or 'unavailable',
        evaluated = type(gate) == 'table' and gate.evaluated or nil,
        skipped = type(gate) == 'table' and gate.skipped or nil,
        built = lean.built,
        polls = lean.polls,
        key = lean.key,
        generation = lean.generation,
        context = lean.context,
        age = lean.age,
    }
end

-- Boundary-only routing label. No IDs, names, providers or private bodies leave
-- here, and report reads/normal evaluator dispatches never re-observe selection.
local selectionSub = string.sub

-- Returns "none", "scoped", "raw" or "unavailable" for the current rotation selection, without exposing the identifier.
local function selectedKey()
    local value = rawget(addon, 'currentRotation')

    if not readable(value) or not rawequal(rawget(addon, 'currentRotation'), value) then
        return 'unavailable'
    end
    if value == nil then
        return 'none'
    end
    if type(value) ~= 'string' then
        return 'unavailable'
    end

    local ok, prefix = pcall(selectionSub, value, 1, 13)

    if not ok then
        return 'unavailable'
    end

    return prefix == '\1rm:rotation:' and 'scoped' or 'raw'
end

-- Snapshot only at explicit capture boundaries, outside measured dispatches.
-- Copy scalar fields immediately: providers cannot mutate a retained snapshot.
local diagnosticSpecs = {
    {
        method = 'GetActiveRuntimePlanDiagnostic',
        label = 'Active runtime plan',
        state = 'currentRoute',
        fields = { 'plansBuilt', 'reused', 'declined' },
    },
    {
        method = 'GetConditionRuntimeDiagnostic',
        label = 'Condition runtime',
        state = 'active',
        fields = {
            'compiles',
            'legacyFallback',
            'leafEvaluations',
            'validatorCalls',
            'stableHits',
            'eventInvalidations',
        },
    },
}

local diagnosticRoutes = { idle = true, managed = true, unavailable = true, fallback = true, retired = true }

-- Returns "cached", "direct" or "unavailable" from the cache mode provider, trusting it only while addon still holds
-- that very function.
local function observationMode(provider)
    if type(provider) ~= 'function' or not rawequal(rawget(addon, 'GetCacheDiagnosticMode'), provider) then
        return 'unavailable'
    end

    local ok, value = pcall(provider, addon)

    if not ok or not readable(value) or not rawequal(rawget(addon, 'GetCacheDiagnosticMode'), provider) then
        return 'unavailable'
    end
    if value == 'cached' or value == 'direct' then
        return value
    end

    return 'unavailable'
end

-- Copies one runtime diagnostic provider's state and counters into a table of scalars; { state = "unavailable" } when
-- the provider is missing, throws or was replaced during the call.
local function diagnosticSnapshot(spec, provider)
    local snapshot = { state = 'unavailable' }

    if type(provider) ~= 'function' or not rawequal(rawget(addon, spec.method), provider) then
        return snapshot
    end

    local ok, result = pcall(provider, addon)

    if not ok or not rawequal(rawget(addon, spec.method), provider) then
        return snapshot
    end

    local state = field(result, spec.state)

    if readable(state) then
        if spec.state == 'active' and type(state) == 'boolean' then
            snapshot.state = tostring(state)
        elseif spec.state == 'currentRoute' and type(state) == 'string' and diagnosticRoutes[state] then
            snapshot.state = state
        end
    end

    for _, name in ipairs(spec.fields) do
        snapshot[name] = bytes(field(result, name))
    end

    if not rawequal(rawget(addon, spec.method), provider) then
        return { state = 'unavailable' }
    end

    return snapshot
end

-- Records the cache mode and the first snapshot of every diagnostic provider at capture start.
local function diagnosticStart(run)
    run.cacheModeProvider = rawget(addon, 'GetCacheDiagnosticMode')
    run.cacheModeStart = observationMode(run.cacheModeProvider)
    run.diagnostics = {}

    for i, spec in ipairs(diagnosticSpecs) do
        local provider = rawget(addon, spec.method)
        run.diagnostics[i] = { provider = provider, first = diagnosticSnapshot(spec, provider) }
    end
end

-- Records the cache mode and the closing snapshot of every diagnostic provider at capture end.
local function diagnosticEnd(run)
    run.cacheModeEnd = observationMode(run.cacheModeProvider)

    for i, spec in ipairs(diagnosticSpecs) do
        local record = run.diagnostics and run.diagnostics[i]

        if record then
            record.last = diagnosticSnapshot(spec, record.provider)
        end
    end
end

-- Appends the cache mode and the capture deltas of each diagnostic provider's counters to lines.
local function diagnosticReport(lines, run)
    lines[#lines + 1] = 'Observation cache: start='
        .. (run.cacheModeStart or 'unavailable')
        .. '; end='
        .. (run.cacheModeEnd or 'unavailable')

    for i, spec in ipairs(diagnosticSpecs) do
        local record = run.diagnostics and run.diagnostics[i]
        local first, last = record and record.first or {}, record and record.last or {}

        local parts = {
            spec.label .. ': start=' .. (first.state or 'unavailable') .. '; end=' .. (last.state or 'unavailable'),
        }

        for _, name in ipairs(spec.fields) do
            local a, b = first[name], last[name]
            parts[#parts + 1] = name .. '=' .. (a and b and b >= a and string.format('%.0f', b - a) or 'unavailable')
        end

        lines[#lines + 1] = table.concat(parts, '; ')
    end

    lines[#lines
        + 1] = 'Runtime counters are capture deltas; route/active states describe boundaries only. Diagnostics are read outside measured dispatches.'
end

-- ============================================================================
-- Report and dispatch
-- ============================================================================

-- Renders the finished run as report text. status is "complete", "stopped", "cancelled" or "invalid", and reason says
-- why a run was invalidated. Gross allocation is reported as such: it is not retained heap or evidence of a leak.
local function report(run, status, reason)
    local lines = {
        'Rotation Master native runtime capture: ' .. status .. (reason and ' (' .. reason .. ')' or ''),
        'Scope: all normal EvaluateNextAction dispatches, including timer and event calls; descendants overlap.',
        'Requested='
            .. string.format('%g', run.requested)
            .. ' s; actual='
            .. (run.duration and string.format('%.3f s', run.duration) or 'unavailable')
            .. '; max dispatches=512; measured='
            .. run.measured
            .. '; unmeasured nested='
            .. run.nested,
        'poll start=' .. run.poll,
        (function()
            local a, b = run.idleStart or {}, run.idleEnd or {}

            -- Capture delta of one counter as text, or "unavailable" when either end is missing or it went backwards.
            local function delta(k)
                return a[k] and b[k] and b[k] >= a[k] and tostring(b[k] - a[k]) or 'unavailable'
            end

            local engine = rawget(addon, 'GetEvaluationEngine')
            local ok, name = false, nil

            if type(engine) == 'function' then
                ok, name = pcall(engine, addon)
            end

            return 'Engine: '
                .. (ok and type(name) == 'string' and name or 'unavailable')
                .. '; lean polls='
                .. delta('polls')
                .. '; plans built='
                .. delta('built')
                .. ' (dropped: selection='
                .. delta('key')
                .. ', generation='
                .. delta('generation')
                .. ', context='
                .. delta('context')
                .. ', age='
                .. delta('age')
                .. ')'
                .. '. Idle gate: idle_poll='
                .. (a.interval or 'unavailable')
                .. '; timer ticks evaluated='
                .. delta('evaluated')
                .. '; skipped='
                .. delta('skipped')
        end)(),
        'Selected key: start='
            .. (run.selectionStart or 'unavailable')
            .. '; end='
            .. (run.selectionEnd or 'unavailable'),
        string.format(
            'elapsedMilliseconds: total=%.3f; average=%.3f; max=%.3f',
            run.elapsed,
            run.measured > 0 and run.elapsed / run.measured or 0,
            run.maximum
        ),
        'allocatedBytes='
            .. (run.allocated ~= nil and string.format('%.0f', run.allocated) or 'unavailable')
            .. '; deallocatedBytes='
            .. (run.deallocated ~= nil and string.format('%.0f', run.deallocated) or 'unavailable'),
        'Gross allocated/deallocated bytes are not retained heap, garbage collection totals, or evidence of a memory leak.',
        'Measurements include the capture trampoline and instrumentation; real native evaluator acceptance requires a client capture.',
    }

    decisionReport(lines, run)

    lines[#lines + 1] = 'Phases: complete='
        .. (run.phaseComplete or 0)
        .. '; unavailable='
        .. (run.measured - (run.phaseComplete or 0))
        .. ' (missing, changed or invalid marker sequence/snapshots).'

    lines[#lines
        + 1] = 'Phase rows include complete samples only, at existing child lookup boundaries. Intervals are disjoint; native marker overhead is included, unadjusted.'

    lines[#lines
        + 1] = 'Byte snapshots are differenced; unavailable arithmetic is withheld. Native totals exclude outer aggregation and report work.'

    if run.phaseComplete and run.phaseComplete > 0 then
        for i, row in ipairs(run.phaseRows) do
            lines[#lines + 1] = string.format(
                '%s | time=%.3f ms | allocatedBytes=%s | deallocatedBytes=%s',
                phaseNames[i],
                row.time,
                row.allocated ~= nil and string.format('%.0f', row.allocated) or 'unavailable',
                row.deallocated ~= nil and string.format('%.0f', row.deallocated) or 'unavailable'
            )
        end
    end

    diagnosticReport(lines, run)
    return table.concat(lines, '\n')
end

-- Ends the run exactly once: takes the closing snapshots, restores EvaluateNextAction, the child lookup and the
-- decision sink, cancels the timer, stores the report and calls the optional OnCPURuntimeCaptureFinished hook. The
-- original dispatch function is restored only if the wrapper is still the installed one.
local function finish(run, status, reason)
    if active ~= run or run.phase == 'finishing' then
        return
    end

    run.phase = 'finishing'
    local ended = now(run)

    if ended and run.started and ended >= run.started and finite(ended - run.started) then
        run.duration = ended - run.started
    end

    run.selectionEnd = selectedKey()
    run.idleEnd = idleGate()
    diagnosticEnd(run)
    active = nil
    run.phase = 'retired'
    decisionRestore(run)

    if rawequal(rawget(addon, 'EvaluateNextAction'), run.wrapper) then
        addon.EvaluateNextAction = run.original
    end

    phaseRestore(run)
    local timer = run.timer
    run.timer = nil

    if timer then
        pcall(run.cancel, addon, timer)
    end

    lastReport = report(run, status, reason)
    local callback = rawget(addon, 'OnCPURuntimeCaptureFinished')

    if type(callback) == 'function' then
        pcall(callback, addon, lastReport, status)
    end
end

-- Returns the original function's results from a packed pcall, rethrowing its error with the original error value.
local function originalResult(result)
    if not result[1] then
        error(result[2], 0)
    end

    return unpack(result, 2, result.n)
end

-- The wrapper installed over addon.EvaluateNextAction. Measures an outer dispatch through the native profiler, running
-- the original exactly once inside it, and returns the original's results unchanged. Nested dispatches are only
-- counted. Any surprise (a replaced API, an unusable clock, a callback that did not run once with the same arguments)
-- ends the capture as invalid and falls through to the original, so evaluation is never altered or lost.
local function dispatch(run, self, ...)
    if not rawequal(self, addon) or not current(run) then
        return run.original(self, ...)
    end

    if run.inside then
        run.nested = run.nested + 1
        run.samplePhaseOK = false
        run.decisionSampleOK = false
        return run.original(self, ...)
    end

    if not providerCurrent(run) then
        finish(run, 'invalid', 'profiling-api-changed')
        return run.original(self, ...)
    end

    local at = now(run)

    if not current(run) or not providerCurrent(run) then
        finish(run, 'invalid', 'capture-changed')
        return run.original(self, ...)
    end

    if not at or at < run.started then
        finish(run, 'invalid', 'clock-unavailable')
        return run.original(self, ...)
    end

    if at >= run.started + run.requested then
        finish(run, 'complete')
        return run.original(self, ...)
    end

    local entries, open, result = 0, true, nil
    local arguments = tuple(self, ...)
    local exact = true

    -- The callback the native profiler measures: runs the original once, and only with the arguments it was given.
    local function once(...)
        if not open then
            return
        end

        entries = entries + 1

        if entries ~= 1 or not current(run) then
            return
        end

        local given = tuple(...)

        if given.n ~= arguments.n then
            exact = false
        else
            for i = 1, arguments.n do
                if not rawequal(given[i], arguments[i]) then
                    exact = false
                    break
                end
            end
        end

        run.callbackInside = true
        result = tuple(pcall(run.original, unpack(arguments, 1, arguments.n)))
        run.callbackInside = false
        return 'RM:runtime'
    end

    run.inside = true
    run.decisionSampleOK = run.decisionAvailable

    if run.decisionSampleOK then
        for row = 1, 2 do
            for index = 1, 9 do
                run.decisionScratch[row][index] = 0
            end
        end
    end

    run.phasePosition = 0
    run.samplePhaseOK = phaseCurrent(run) and true or false
    local native = tuple(pcall(run.measure, once, self, ...))
    open = false
    run.inside = false

    if not result then
        finish(run, 'invalid', 'callback-not-run')
        return run.original(self, ...)
    end

    if not result[1] then
        finish(run, 'invalid', 'original-error')
        return originalResult(result)
    end

    if not current(run) then
        return originalResult(result)
    end

    local valid = native[1]
        and entries == 1
        and exact
        and providerCurrent(run)
        and native.n == 3
        and native[3] == 'RM:runtime'

    local elapsed = valid and field(native[2], 'elapsedMilliseconds')

    if not finite(elapsed) or elapsed < 0 or not finite(run.elapsed + elapsed) then
        valid = false
    end

    if not valid then
        finish(run, 'invalid', 'native-result-unavailable')
        return originalResult(result)
    end

    decisionAccumulate(run)
    run.measured = run.measured + 1
    run.elapsed = run.elapsed + elapsed
    run.maximum = math.max(run.maximum, elapsed)

    local allocated, deallocated = bytes(field(native[2], 'allocatedBytes')), bytes(field(
        native[2],
        'deallocatedBytes'
    ))

    phaseAccumulate(run, native[2], elapsed, allocated, deallocated)

    if run.allocated ~= nil then
        run.allocated = allocated and run.allocated + allocated or nil

        if run.allocated and run.allocated > SAFE then
            run.allocated = nil
        end
    end

    if run.deallocated ~= nil then
        run.deallocated = deallocated and run.deallocated + deallocated or nil

        if run.deallocated and run.deallocated > SAFE then
            run.deallocated = nil
        end
    end

    if current(run) and run.measured >= LIMIT then
        finish(run, 'complete', 'dispatch-limit')
    end

    return originalResult(result)
end

-- ============================================================================
-- Public API
-- ============================================================================

-- Starts a capture of duration seconds (default 10, 1 to 60). Returns true, or false and a reason code (for example
-- "already-running", "cumulative-capture-running" or "native-profiler-unavailable"). Refuses to run beside the
-- cumulative CPU profile.
function addon:StartCPURuntimeCapture(duration)
    if not rawequal(self, addon) then
        return false, 'invalid-owner'
    end
    if active then
        return false, 'already-running'
    end

    if duration == nil then
        duration = 10
    end

    if not finite(duration) or duration < 1 or duration > 60 then
        return false, 'invalid-duration'
    end

    local original = rawget(addon, 'EvaluateNextAction')
    local cumulative = rawget(addon, 'IsCPUProfileRunning')
    local schedule, cancel = rawget(addon, 'ScheduleTimer'), rawget(addon, 'CancelTimer')
    local clock = rawget(_G, 'GetTimePreciseSec') or rawget(_G, 'GetTime')

    if
        type(original) ~= 'function'
        or type(cumulative) ~= 'function'
        or type(schedule) ~= 'function'
        or type(cancel) ~= 'function'
        or type(clock) ~= 'function'
    then
        return false, 'missing-runtime-api'
    end

    local run = {
        phase = 'starting',
        requested = duration,
        poll = 'unavailable',
        original = original,
        cancel = cancel,
        clock = clock,
        measured = 0,
        nested = 0,
        elapsed = 0,
        maximum = 0,
        allocated = 0,
        deallocated = 0,
    }

    active = run

    -- Retires the starting run and returns the failure for the caller.
    local function reject(reason)
        if active == run then
            active = nil
            run.phase = 'retired'
        end

        return false, reason
    end

    local ok, running = pcall(cumulative, addon)

    if active ~= run then
        return false, 'capture-retired'
    end
    if not ok or not readable(running) or running ~= false then
        return reject('cumulative-capture-running')
    end

    run.provider = rawget(_G, 'C_AddOnProfiler')
    run.enabled = field(run.provider, 'IsEnabled')
    run.measure = field(run.provider, 'MeasureCall')

    if type(run.enabled) ~= 'function' or type(run.measure) ~= 'function' then
        return reject('missing-native-profiler-api')
    end

    local good, enabled = pcall(run.enabled)

    if active ~= run then
        return false, 'capture-retired'
    end
    if not good or not readable(enabled) or enabled ~= true or not providerCurrent(run) then
        return reject('native-profiler-unavailable')
    end

    run.started = now(run)
    run.poll = poll()
    run.idleStart = idleGate()
    run.selectionStart = selectedKey()
    diagnosticStart(run)

    if active ~= run then
        return false, 'capture-retired'
    end

    phasePrepare(run)

    if active ~= run then
        return false, 'capture-retired'
    end
    if
        not run.started
        or not providerCurrent(run)
        or not rawequal(rawget(addon, 'EvaluateNextAction'), original)
        or not rawequal(rawget(addon, 'IsCPUProfileRunning'), cumulative)
    then
        return reject('capture-changed')
    end

    run.wrapper = function(...) return dispatch(run, ...) end

    local accepted, timer = pcall(
        schedule,
        addon,
        function()
            finish(run, 'complete')
        end,
        duration
    )

    if active ~= run then
        if accepted and timer then
            pcall(cancel, addon, timer)
        end

        return false, 'capture-retired'
    end

    if not accepted or not timer then
        return reject('timer-error')
    end

    run.timer = timer

    if
        not providerCurrent(run)
        or not rawequal(rawget(addon, 'EvaluateNextAction'), original)
        or not rawequal(rawget(addon, 'IsCPUProfileRunning'), cumulative)
    then
        finish(run, 'invalid', 'capture-changed')
        return false, 'capture-changed'
    end

    addon.EvaluateNextAction = run.wrapper
    run.phase = 'running'
    phaseInstall(run)
    decisionInstall(run)
    lastReport = nil
    return true
end

-- Ends the running capture as "stopped", keeping its report. Returns true, or false and a reason code.
function addon:StopCPURuntimeCapture()
    if not rawequal(self, addon) then
        return false, 'invalid-owner'
    end
    if not active then
        return false, 'not-running'
    end

    finish(active, 'stopped')
    return true
end

-- Ends the running capture as "cancelled" (the report says so). Returns true, or false and a reason code. Called by
-- addon:OnDisable (Diagnostics/cpu.lua) and by the cancel action of the performance window.
function addon:CancelCPURuntimeCapture()
    if not rawequal(self, addon) then
        return false, 'invalid-owner'
    end
    if not active then
        return false, 'not-running'
    end

    finish(active, 'cancelled')
    return true
end

-- True while a capture is running.
function addon:IsCPURuntimeCaptureRunning()
    return active ~= nil
end

-- Returns a one-line status while a capture runs, else the last report, or nil and "not-captured".
function addon:GetCPURuntimeCaptureReport()
    if active then
        return string.format(
            'Rotation Master native runtime capture: running (requested %g s; all normal evaluator dispatches)',
            active.requested
        )
    end
    if lastReport then
        return lastReport
    end

    return nil, 'not-captured'
end
