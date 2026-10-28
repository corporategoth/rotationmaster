-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Memory capture: records how Lua heap use and the addon's attributed memory change over a bounded run (default 10
-- minutes, at most 30) and renders a text report. Owns the capture run state and the StartMemoryCapture,
-- CompleteMemoryCapture, StopMemoryCapture, IsMemoryCaptureRunning and GetMemoryCaptureReport entry points, which the
-- performance window (UI/cpu_profile.lua) and the general settings call.
-- Must not hook the evaluator or control garbage collection; it only observes, at most one sample a second and one
-- detailed row every 30 seconds, and every native call is guarded because a run can be retired mid-callout.
-- Optional WoWTaskManager counters are read as public scalars only. Loaded from RotationMaster.toc after
-- Diagnostics/cpu_runtime.lua; detail rows read retained-memory counts from addon:GetRetainedMemoryDiagnostic
-- (Diagnostics/cpu.lua) when it exists.
local addon_name, addon = ...
-- Explicit, bounded lifetime observations. No evaluator hook or GC control.
local active, lastReport, latest
local DEFAULT_DURATION, MAX_DURATION, COUNT_LIMIT, NODE_LIMIT = 600, 1800, 4096, 8192
local kind, raw, nextKey, protect, each, same = type, rawget, next, pcall, ipairs, rawequal
local format, concat = string.format, table.concat

-- ============================================================================
-- Value guards
-- ============================================================================

-- Tells whether a game value may be read: it is neither a secret nor inaccessible.
-- @param value any  The value to test.
-- @return boolean  True when the value is readable; false when it is secret or inaccessible, or when a secret-value API
--   is not callable.
local function readable(value)
    local secret = raw(_G, 'issecretvalue')

    if secret ~= nil then
        if kind(secret) ~= 'function' then
            return false
        end

        local ok, v = protect(secret, value)

        if not ok or v ~= false then
            return false
        end
    end

    local access = raw(_G, 'canaccessvalue')

    if access ~= nil then
        if kind(access) ~= 'function' then
            return false
        end

        local ok, v = protect(access, value)

        if not ok or v ~= true then
            return false
        end
    end

    return true
end

-- Tells whether a value is a readable finite non-negative number small enough to be a safe integer.
-- @param value any  The value to test.
-- @return boolean  True when it is.
local function number(value)
    return readable(value) and kind(value) == 'number' and value == value and value >= 0 and value <= 9007199254740991
end

-- Reads value[key] without invoking metamethods.
-- @param value any  The table to read from.
-- @param key any  The key.
-- @return any  The value; nil when value is unreadable or not a table.
local function field(value, key)
    if readable(value) and kind(value) == 'table' then
        return raw(value, key)
    end
end

-- Tells whether a run is the active, running capture.
-- @param run table  The capture state.
-- @return boolean  True while it is.
--
-- Checked after every native call, because a callout can stop or replace the capture.
local function current(run)
    return active == run and run.phase == 'running'
end

-- Calls fn under pcall and returns its result only when it is a valid number and the run is still current.
-- @param run table  The capture state.
-- @param fn function|nil  The function to call.
-- @param ... any  The arguments passed to fn.
-- @return number|nil  The result; nil when fn is not a function, throws, returns something else or the run was retired
--   meanwhile.
---@return number|nil
local function callNumber(run, fn, ...)
    if not current(run) or kind(fn) ~= 'function' then
        return
    end

    local ok, value = protect(fn, ...)

    if not current(run) or not ok or not number(value) or not current(run) then
        return
    end

    ---@cast value number
    return value
end

-- Finds a C_AddOns function by name, falling back to the legacy global.
-- @param name string  The function name.
-- @return function|nil  The C_AddOns function, else the legacy global, else nil.
local function api(name)
    local method = field(raw(_G, 'C_AddOns'), name)

    if kind(method) == 'function' then
        return method
    end

    method = raw(_G, name)

    if kind(method) == 'function' then
        return method
    end
end

local retainedKeys = {
    'spellIDs', 'spellNames', 'itemRecords', 'itemIndex', 'itemBlocked', 'buttons', 'slots', 'logical', 'overlays',
    'sequence', 'pixel', 'autocast', 'blizzard', 'proc'
}

local publicKeys = {
    'units', 'spellRows', 'combatUnits', 'combatRows', 'damageUnits', 'damageRows', 'healRows', 'combatKeys',
    'longtermKeys'
}

-- Optional installed WTM public scalars only; no WTM method, event or frame hook.
local wtmAddonKey = string.lower(addon_name)

-- ============================================================================
-- Sampling
-- ============================================================================

-- Reads the WoWTaskManager spike counters for this addon and compares them with the previous snapshot, counting how
-- many spike increases happened in intervals where the heap dropped.
-- @param run table  The capture state; the wtm* counters are updated.
-- @param at number  The time of this sample.
-- @param dropped boolean|nil  True when the heap dropped since the previous sample.
--
-- Co-occurrence only; it proves no causality.
local function sampleSpikes(run, at, dropped)
    local owner = field(field(field(raw(_G, 'WoWTaskManager'), 'Processes'), 'byName'), wtmAddonKey)
    local n, last = field(owner, 'spikes'), field(owner, 'lastSpikeAt')

    if not current(run) then
        return
    end

    if not number(n) or n % 1 ~= 0 then
        run.wtmOwner = nil
        run.wtmCount = nil
        run.wtmLast = nil
        return
    end

    if not current(run) then
        return
    end

    run.wtmSnapshots = run.wtmSnapshots + 1

    if same(run.wtmOwner, owner) and run.wtmCount and n >= run.wtmCount then
        local increase = n - run.wtmCount
        run.wtmIncreases = run.wtmIncreases + increase
        run.wtmIntervals = run.wtmIntervals + 1
        run.wtmMaxInterval = math.max(run.wtmMaxInterval or 0, at - run.wtmAt)

        if dropped and increase > 0 then
            run.wtmOverlaps = run.wtmOverlaps + increase
            run.wtmOverlapIntervals = run.wtmOverlapIntervals + 1
        end
    end

    run.wtmOwner, run.wtmCount, run.wtmAt = owner, n, at
    run.wtmLast = number(last) and last or nil
end

-- Counts the keys of a plain table (no metatable) without calling into it, charging each key to the shared budget.
-- @param run table  The capture state; the count stops when it is retired.
-- @param map any  The table to count.
-- @param budget table  {n=number}, the nodes counted so far for the whole row; updated.
-- @return number|nil  The count; nil when the table is unreadable or the run was retired.
-- @return boolean|nil  True when the count was capped; nil when the first value is nil.
local function count(run, map, budget)
    if not readable(map) or kind(map) ~= 'table' or getmetatable(map) ~= nil then
        return
    end

    local n, key = 0, nil

    repeat
        if budget.n >= NODE_LIMIT then
            return n, true
        end

        local value
        key, value = nextKey(map, key)

        if key == nil then
            return n, false
        end
        if not readable(key) or not current(run) then
            return
        end

        budget.n = budget.n + 1
        n = n + 1
    until n > COUNT_LIMIT

    return COUNT_LIMIT, true
end

-- Fills row with key and row counts of the addon's own history and cache tables.
-- @param run table  The capture state.
-- @param row table  The detail row being built; count fields and their *Capped flags are set.
--
-- Works within one node budget for the whole row so that a huge table cannot stall a sample. Counts are lower bounds
-- when the matching *Capped flag is true.
local function roots(run, row)
    local budget = { n = 0 }

    -- Stores the (capped) key count of map under row[key].
    -- @param key string  The row field; the capped flag goes to key .. "Capped".
    -- @param map any  The table to count.
    local function save(key, map)
        local n, capped = count(run, map, budget)
        row[key], row[key .. 'Capped'] = n, capped
    end

    save('units', raw(addon, 'unitsInRange'))
    save('spellRows', raw(addon, 'spellHistory'))
    save('combatKeys', raw(addon, 'combatCache'))
    save('longtermKeys', raw(addon, 'longtermCache'))

    -- Counts a table of per-unit tables: the unit count under unitKey and the summed row count of the child (and, with
    -- second, of a second child) under rowKey.
    -- @param root string  The name of the addon field that holds the table.
    -- @param unitKey string  The row field that receives the unit count.
    -- @param rowKey string  The row field that receives the summed row count.
    -- @param child string|nil  The field of each unit entry that holds the rows; nil counts the entry itself.
    -- @param second string|nil  A second field of each entry whose rows are summed into healRows.
    local function nested(root, unitKey, rowKey, child, second)
        local map = raw(addon, root)
        save(unitKey, map)

        if not readable(map) or kind(map) ~= 'table' or getmetatable(map) ~= nil then
            return
        end

        local total, capped, key = 0, false, nil
        local other, otherCapped = 0, false

        while true do
            if budget.n >= NODE_LIMIT then
                capped = true
                otherCapped = true
                break
            end

            local value
            key, value = nextKey(map, key)

            if key == nil then
                break
            end

            if not readable(key) or not current(run) then
                return
            end

            budget.n = budget.n + 1
            local n, cap = count(run, child and field(value, child) or value, budget)

            if n == nil then
                return
            end

            total = total + n
            capped = capped or cap

            if second then
                local x, c = count(run, field(value, second), budget)

                if x == nil then
                    return
                end

                other = other + x
                otherCapped = otherCapped or c
            end

            if total > COUNT_LIMIT or other > COUNT_LIMIT then
                capped = true
                otherCapped = true
                break
            end
        end

        row[rowKey], row[rowKey .. 'Capped'] = math.min(total, COUNT_LIMIT), capped

        if second then
            row.healRows, row.healRowsCapped = math.min(other, COUNT_LIMIT), otherCapped
        end
    end

    nested('combatHistory', 'combatUnits', 'combatRows')
    nested('damageHistory', 'damageUnits', 'damageRows', 'damage', 'heals')
end

-- ============================================================================
-- Report
-- ============================================================================

-- Tells whether a stored (already validated) value is a non-negative number.
-- @param value any  The value to test.
-- @return boolean  True when it is.
local function storedNumber(value)
    return kind(value) == 'number' and value == value and value >= 0 and value <= 9007199254740991
end

-- Formats a stored number to three decimals.
-- @param value any  The stored number.
-- @return string  The formatted number, or "unavailable".
local function amount(value)
    return storedNumber(value) and format('%.3f', value) or 'unavailable'
end

-- Renders the finished run as report text (about 15 KB at most; detail rows beyond that are omitted).
-- @param run table  The capture state.
-- @param status string  "complete", "stopped", "cancelled", "invalid" or "unavailable".
-- @return string  The report lines joined by newlines.
--
-- The text states what the numbers are not (heap is shared Lua memory, counts are keys not bytes) so the report cannot
-- be misread.
local function render(run, status)
    local lines = {
        'Rotation Master memory capture: ' .. status,
        'Native acceptance: unverified',
        'Whole heap is shared Lua memory; addonKiB is sampled attribution. Neither identifies retained object bytes.',
        'Heap decreases are observations, not confirmed GC events. No collection or evaluator profiling was requested.',
        format(
            'requested=%g s; actual=%s s; heap samples=%d; detailed samples=%d',
            run.requested,
            amount(run.elapsed),
            run.heapSamples,
            #run.rows
        ),
        format(
            'heapKiB start=%s; end=%s; min=%s; max=%s; decreases=%d (>=256 KiB); max drop=%s at=%s s',
            amount(run.heapStart),
            amount(run.heapEnd),
            amount(run.heapMin),
            amount(run.heapMax),
            run.drops,
            amount(run.maxDrop),
            amount(run.maxDropAt)
        ),
        format(
            'Explicit attribution refreshes=%d; successful=%d; failed=%d; scan total=%s ms; max=%s ms',
            run.scanAttempts,
            run.scanOK,
            run.scanFailed,
            amount(run.scanTime),
            amount(run.scanMax)
        )
            .. ' (timed scans='
            .. run.timedScans
            .. ')',
        'addonKiB boundary start='
            .. amount(run.startAddonKB)
            .. '; end='
            .. amount(run.endAddonKB)
            .. ' (explicit refresh results; unavailable if missing, failed or not requested)',
        format(
            'Sampler overhead total=%s ms; max=%s ms; failed samples=%d. Timings include instrumentation, unadjusted.',
            amount(run.overhead),
            amount(run.overheadMax),
            run.failedSamples
        )
            .. ' Timed sampler bodies='
            .. run.timedSamples
            .. '.',
        'Counts are keys/rows, not bytes; >= marks a bounded lower limit. Missing or restricted observations are unavailable.',
        'Heap precedes each attribution refresh. CPU/runtime flags describe detailed boundaries only; overlapping instrumentation can affect memory.',
        'Attribution refreshes occur only at capture start/end. Intermediate addonKiB is cached with unknown age; other addons may refresh it.',
        'Explicit memory attribution refreshes may themselves contribute to observed frame spikes; compare scan costs before attributing overlaps to ordinary RM work.',
    }

    -- Formats the named counts of a detail row, marking a capped count with ">=".
    -- @param row table  The detail row.
    -- @param keys string[]  The count fields to print.
    -- @return string  The fields as "key=value" separated by spaces; "unavailable" for a missing value.
    local function counts(row, keys)
        local parts = {}

        for _, key in each(keys) do
            local v = row[key]

            parts[#parts + 1] = key
                .. '='
                .. (storedNumber(v) and ((row[key .. 'Capped'] and '>=' or '') .. format('%.0f', v)) or 'unavailable')
        end

        return concat(parts, ' ')
    end

    if run.wtmSnapshots > 0 then
        lines[#lines + 1] = format(
            'WTM/RM spike increases=%d; overlapping observed heap-drop intervals=%d; overlapping spike increases=%d; valid comparisons=%d; max interval=%s s. Co-occurrence only, not confirmed GC or causality.',
            run.wtmIncreases,
            run.wtmOverlapIntervals,
            run.wtmOverlaps,
            run.wtmIntervals,
            amount(run.wtmMaxInterval)
        )
    else
        lines[#lines + 1] = 'WTM spike correlation: unavailable (optional public counters not observed).'
    end

    local reportBytes = #concat(lines, '\n')

    for _, row in each(run.rows) do
        local text = format(
            't=%s s heapKiB=%s addonKiB=%s fresh=%s scanMs=%s',
            amount(row.t),
            amount(row.heap),
            amount(row.addonKB),
            row.fresh and 'yes' or 'no',
            amount(row.scanMs)
        )
            .. ' attribution='
            .. row.attribution
            .. ' age='
            .. (row.fresh and '0' or 'unknown')
            .. ' cpu='
            .. row.cpu
            .. ' runtime='
            .. row.runtime
            .. ' WTM/RMspikes='
            .. (storedNumber(row.wtmSpikes) and format('%.0f', row.wtmSpikes) or 'unavailable')
            .. ' WTMlastSpikeT='
            .. amount(row.wtmLast)

        local a, b = counts(row, retainedKeys), counts(row, publicKeys)

        if a ~= '' then
            text = text .. ' ' .. a
        end
        if b ~= '' then
            text = text .. ' ' .. b
        end

        if reportBytes + #text + 1 > 15500 then
            lines[#lines + 1] = 'Remaining detailed rows omitted to keep report bounded.'
            break
        end

        lines[#lines + 1] = text
        reportBytes = reportBytes + #text + 1
    end

    lines[#lines
        + 1] = 'WTM spikes, when displayed elsewhere, correlate sampled CPU windows with slow frames; they do not prove RM caused a frame hitch.'

    return concat(lines, '\n')
end

-- Retires the run, cancels its timers, stores the rendered report and notifies the optional OnMemoryCaptureFinished
-- hook.
-- @param run table  The capture state; nothing happens for a run that is not current.
-- @param status string  "complete", "stopped", "cancelled", "invalid" or "unavailable".
local function finish(run, status)
    if not current(run) then
        return
    end

    active = nil
    run.phase = 'retired'

    if status == 'complete' and run.stopRequested then
        status = 'stopped'
    end

    local report = render(run, status)
    lastReport = report
    local repeating, timeout = run.timer, run.timeout
    run.timer, run.timeout = nil, nil

    if repeating then
        protect(run.cancel, addon, repeating)
    end
    if timeout then
        protect(run.cancel, addon, timeout)
    end

    if active == nil and latest == run then
        local notify = raw(addon, 'OnMemoryCaptureFinished')

        if kind(notify) == 'function' then
            protect(notify, addon, report, status)
        end
    end
end

-- Adds one detailed row: heap, the addon's memory, CPU capture state, retained-memory counts and table counts.
-- @param run table  The capture state.
-- @param at number  The time of this sample.
-- @param heap number|nil  The heap size in KiB read for this sample.
-- @param refresh boolean|nil  True to refresh the addon's memory through UpdateAddOnMemoryUsage (at capture start and
--   end only, because the refresh itself costs time and can cause frame spikes).
--
-- Abandons the row if the run is retired during a native call.
local function detail(run, at, heap, refresh)
    local row = {
        t = at - run.started,
        heap = heap,
        fresh = false,
        attribution = 'unavailable',
        wtmSpikes = run.wtmCount,
    }

    if run.wtmLast and run.wtmLast >= run.started then
        row.wtmLast = run.wtmLast - run.started
    end

    if kind(run.update) == 'function' and kind(run.memory) == 'function' then
        if refresh then
            run.scanAttempts = run.scanAttempts + 1
            local before = callNumber(run, run.ms)

            if not current(run) then
                return
            end

            local ok = protect(run.update)

            if not current(run) then
                return
            end

            local ending = callNumber(run, run.ms)

            if not current(run) then
                return
            end

            if before and ending and ending >= before then
                row.scanMs = ending - before
                run.scanTime = (run.scanTime or 0) + row.scanMs
                run.scanMax = math.max(run.scanMax or 0, row.scanMs)
                run.timedScans = run.timedScans + 1
            end

            if ok then
                row.addonKB = callNumber(run, run.memory, addon_name)
            end

            if not current(run) then
                return
            end

            row.fresh = row.addonKB ~= nil

            if row.fresh then
                row.attribution = 'refreshed'
                run.scanOK = run.scanOK + 1
            else
                run.scanFailed = run.scanFailed + 1
            end
        else
            row.addonKB = callNumber(run, run.memory, addon_name)

            if row.addonKB ~= nil then
                row.attribution = 'cached'
            end

            if not current(run) then
                return
            end
        end
    end

    if refresh then
        if run.finalDetail then
            run.endAddonKB = row.addonKB
        else
            run.startAddonKB = row.addonKB
        end
    end

    -- Reads whether a capture owned by another module is running.
    -- @param name string  The addon method to call (IsCPUProfileRunning or IsCPURuntimeCaptureRunning).
    -- @return string  "active", "inactive" or "unknown".
    local function captureState(name)
        local fn = raw(addon, name)

        if kind(fn) ~= 'function' then
            return 'unknown'
        end

        local ok, value = protect(fn, addon)

        if not current(run) then
            return 'unknown'
        end
        if ok and readable(value) and kind(value) == 'boolean' then
            return value and 'active' or 'inactive'
        end

        return 'unknown'
    end

    row.cpu, row.runtime = captureState('IsCPUProfileRunning'), captureState('IsCPURuntimeCaptureRunning')

    if not current(run) then
        return
    end

    local provider = raw(addon, 'GetRetainedMemoryDiagnostic')

    if kind(provider) == 'function' then
        local ok, value = protect(provider, addon)

        if not current(run) then
            return
        end

        if ok then
            for _, key in each(retainedKeys) do
                local n = field(value, key)

                if number(n) and n % 1 == 0 and n <= COUNT_LIMIT then
                    row[key] = n
                    row[key .. 'Capped'] = field(value, key .. 'Capped') == true
                end

                if not current(run) then
                    return
                end
            end
        end
    end

    protect(roots, run, row)

    if not current(run) then
        return
    end

    run.rows[#run.rows + 1] = row
    run.nextDetail = at + 30
end

-- One timer tick: reads the heap, tracks drops, adds a detail row when due, charges its own cost to the overhead totals
-- and finishes the run when its time is up.
-- @param run table  The capture state.
-- @param ending boolean|nil  True for the closing tick.
--
-- Never re-entered (run.sampling).
local function sample(run, ending)
    if not current(run) or run.sampling then
        return
    end

    run.sampling = true

    local ok = protect(function()
        local at = callNumber(run, run.clock)

        if not at or not current(run) then
            return
        end

        if at < run.started then
            finish(run, 'invalid')
            return
        end

        run.elapsed = at - run.started
        local freshTick = run.lastAt == nil or at > run.lastAt

        if freshTick or ending then
            local before = callNumber(run, run.ms)
            local heap = run.heapEnd

            if freshTick then
                heap = callNumber(run, run.heap, 'count')

                if not current(run) then
                    return
                end

                if heap ~= nil and run.heapSamples < run.heapLimit then
                    run.heapSamples = run.heapSamples + 1
                    run.heapStart = run.heapStart or heap
                    run.heapEnd = heap
                    run.heapMin = math.min(run.heapMin or heap, heap)
                    run.heapMax = math.max(run.heapMax or heap, heap)
                    local dropped = run.previousHeap and run.previousHeap - heap >= 256

                    if dropped then
                        local drop = run.previousHeap - heap
                        run.drops = run.drops + 1

                        if not run.maxDrop or drop > run.maxDrop then
                            run.maxDrop = drop
                            run.maxDropAt = at - run.started
                        end
                    end

                    sampleSpikes(run, at, dropped)

                    if not current(run) then
                        return
                    end

                    run.previousHeap = heap
                else
                    run.failedSamples = run.failedSamples + 1
                end

                run.lastAt = at
            end

            local final = ending or run.elapsed >= run.requested or run.heapSamples >= run.heapLimit

            if final then
                -- Reserve the final row even when periodic detail sampling drifted. Set
                -- before native callouts so a stale/late timer cannot repeat this scan.
                if not run.finalDetail then
                    run.finalDetail = true
                    detail(run, at, heap, true)
                end
            elseif at >= run.nextDetail and #run.rows < run.detailLimit - 1 then
                detail(run, at, heap, #run.rows == 0)
            end

            if not current(run) then
                return
            end

            local after = callNumber(run, run.ms)

            if before and after and after >= before then
                local cost = after - before
                run.overhead = (run.overhead or 0) + cost
                run.overheadMax = math.max(run.overheadMax or 0, cost)
                run.timedSamples = run.timedSamples + 1
            end
        end

        if ending or run.elapsed >= run.requested or run.heapSamples >= run.heapLimit then
            finish(run, 'complete')
        end
    end)

    if current(run) then
        run.sampling = false

        if not ok then
            run.failedSamples = run.failedSamples + 1
        end

        if ending then
            finish(run, 'invalid')
        end
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

-- Starts a memory capture. Only one capture runs at a time.
-- @param duration number|nil  Seconds to capture, 1 to 1800; nil means 600.
-- @return boolean  True when the capture started.
-- @return string|nil  The reason code when false (for example "already-running", "addon-disabled" or
--   "missing-memory-api"); nil when true.
function addon:StartMemoryCapture(duration)
    if self ~= addon then
        return false, 'foreign-owner'
    end

    local enabled = self.IsEnabled

    if kind(enabled) == 'function' then
        local ok, value = protect(enabled, self)

        if not ok or not readable(value) or value ~= true then
            return false, 'addon-disabled'
        end
    end

    if active then
        return false, 'already-running'
    end

    if duration == nil then
        duration = DEFAULT_DURATION
    end

    if not number(duration) or duration < 1 or duration > MAX_DURATION then
        return false, 'invalid-duration'
    end

    local run = {
        phase = 'running',
        requested = duration,
        heapLimit = math.ceil(duration) + 1,
        detailLimit = math.ceil(duration / 30) + 1,
        rows = {},
        heapSamples = 0,
        drops = 0,
        scanAttempts = 0,
        scanOK = 0,
        scanFailed = 0,
        failedSamples = 0,
        timedScans = 0,
        timedSamples = 0,
        wtmSnapshots = 0,
        wtmIncreases = 0,
        wtmIntervals = 0,
        wtmOverlaps = 0,
        wtmOverlapIntervals = 0,
        clock = raw(_G, 'GetTimePreciseSec') or raw(_G, 'GetTime'),
        heap = raw(_G, 'collectgarbage'),
        ms = raw(_G, 'debugprofilestop'),
        update = api('UpdateAddOnMemoryUsage'),
        memory = api('GetAddOnMemoryUsage'),
        cancel = raw(addon, 'CancelTimer'),
    }

    local repeating, timeout = raw(addon, 'ScheduleRepeatingTimer'), raw(addon, 'ScheduleTimer')

    if
        kind(run.clock) ~= 'function'
        or kind(run.heap) ~= 'function'
        or kind(repeating) ~= 'function'
        or kind(timeout) ~= 'function'
        or kind(run.cancel) ~= 'function'
    then
        return false, 'missing-memory-api'
    end

    active = run
    latest = run
    run.started = callNumber(run, run.clock)

    if not current(run) then
        return false, 'capture-retired'
    end

    if not run.started then
        finish(run, 'unavailable')
        return false, 'invalid-clock'
    end

    run.nextDetail = run.started
    sample(run)

    if not current(run) then
        return false, 'capture-retired'
    end

    if run.heapSamples == 0 then
        finish(run, 'unavailable')
        return false, 'unavailable-heap'
    end

    local ok, timer = protect(
        repeating,
        addon,
        function()
            sample(run)
        end,
        1
    )

    if not current(run) then
        if ok and timer then
            protect(run.cancel, addon, timer)
        end

        return false, 'capture-retired'
    end

    if not ok or not timer then
        finish(run, 'unavailable')
        return false, 'timer-error'
    end

    run.timer = timer

    local good, handle = protect(
        timeout,
        addon,
        function()
            sample(run, true)
        end,
        duration
    )

    if not current(run) then
        if good and handle then
            protect(run.cancel, addon, handle)
        end

        return false, 'capture-retired'
    end

    if not good or not handle then
        finish(run, 'unavailable')
        return false, 'timer-error'
    end

    run.timeout = handle
    return true
end

-- Ends the running capture as "stopped" with a final sample, keeping its report.
-- @return boolean  True when a capture was ended.
-- @return string|nil  "not-running" when false; nil when true.
--
-- Explicit completed boundary; legacy StopMemoryCapture remains cancellation.
function addon:CompleteMemoryCapture()
    if self ~= addon or not active then
        return false, 'not-running'
    end

    local run = active
    run.stopRequested = true

    if run.sampling then
        finish(run, 'stopped')
    else
        sample(run, true)
    end

    return true
end

-- Cancels the running capture without a final sample (the report says "cancelled").
-- @return boolean  True when a capture was cancelled.
-- @return string|nil  "not-running" when false; nil when true.
function addon:StopMemoryCapture()
    if self ~= addon or not active then
        return false, 'not-running'
    end

    finish(active, 'cancelled')
    return true
end

-- Tells whether a capture is running.
-- @return boolean  True while one is.
function addon:IsMemoryCaptureRunning()
    return self == addon and active ~= nil
end

-- Returns the report of the last finished capture.
-- @return string|nil  The report; nil while a capture runs or when none was captured.
-- @return string|nil  "foreign-owner", "running" or "not-captured" when the first value is nil; nil otherwise.
function addon:GetMemoryCaptureReport()
    if self ~= addon then
        return nil, 'foreign-owner'
    end
    if active then
        return nil, 'running'
    end

    return lastReport, lastReport and nil or 'not-captured'
end
