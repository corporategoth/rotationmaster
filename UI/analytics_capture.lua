-- Settings-side controls for the volatile cast-receipt capture (General > Debugging: Capture casts, Stop, Cast report,
-- Clear). The capture itself is addon.Analytics.NativeCasts (Platform/analytics_casts.lua); this file only starts,
-- stops, clears and reports it, independently of any pending settings draft, and owns no saved data.
-- It captures the service and its five methods once at load and later refuses to call anything that was replaced, so a
-- swapped-in service is never driven. The report is built from detached snapshot data and shows only allowlisted tokens
-- and numbers, never raw error text, GUIDs or names.
-- Loaded from the UI section of RotationMaster.toc, after Platform/analytics_casts.lua; used by
-- UI/settings_general.lua, Help/general.lua and the disable path in Diagnostics/cpu.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local type, rawget, rawequal, pcall = type, rawget, rawequal, pcall

-- ============================================================================
-- Capture service ownership
-- ============================================================================

-- The capture service and the methods this file may call, captured once at load. owned() later verifies they are
-- unchanged.
local service = addon.Analytics and addon.Analytics.NativeCasts
local methods = {}

for _, name in ipairs({ 'Start', 'Stop', 'Clear', 'GetStatus', 'GetSnapshot' }) do
    methods[name] = service and service[name]
end

-- generation counts retirements so an operation that finished after Clear or shutdown can tell its result is stale;
-- lease is the running capture session; busy is the in-flight action.
local generation, lease, busy = 0, nil, false

-- True only while addon.Analytics.NativeCasts is still the service captured at load with all five methods unchanged.
-- @return boolean  True when the captured service and every captured method are still the live, unreplaced ones.
--
-- Every action checks it first.
local function owned()
    if not service or not addon.Analytics or not rawequal(addon.Analytics.NativeCasts, service) then
        return false
    end

    for name, fn in pairs(methods) do
        if type(fn) ~= 'function' or not rawequal(service[name], fn) then
            return false
        end
    end

    return true
end

-- The standard text for every refused or unavailable action.
-- @return string  The localized "Cast capture is unavailable." text.
local function available()
    return L['Cast capture is unavailable.']
end

-- Calls a captured service method under pcall; the caller treats a nil result as failure.
-- @param name string  The captured method to call: 'Start', 'Stop', 'Clear', 'GetStatus' or 'GetSnapshot'.
-- @param ... any  The arguments passed after the service itself.
-- @return any|nil  The method's first result, or nil when the call raised (or returned nothing).
local function invoke(name, ...)
    local ok, value = pcall(methods[name], service, ...)

    if not ok then
        return nil
    end

    return value
end

-- Reads the capture phase ("starting", "running", "idle", ...) from GetStatus.
-- @return string|nil  The phase, or nil when the service is not owned or the status is malformed.
local function phase()
    if not owned() then
        return nil
    end

    local status = invoke('GetStatus')
    return type(status) == 'table' and rawget(status, 'phase') or nil
end

-- ============================================================================
-- Status for the settings page
-- ============================================================================

-- Returns the localized one-line status shown beside the capture buttons.
-- @return string  The running, idle or unavailable status text; unavailable when called with a self other than addon.
function addon:GetCastCaptureStatusText()
    if not rawequal(self, addon) then
        return available()
    end

    local p = phase()

    if p == 'running' or p == 'starting' then
        return L['Cast capture status: running']
    end
    if p == 'idle' then
        return L['Cast capture status: idle']
    end

    return available()
end

-- Reports whether a cast capture is running and, on request, whether a report can be opened.
-- @param withReport boolean|nil  When true, also check that a snapshot exists.
-- @return boolean|nil  True while the capture is starting or running; nil when called with a self other than addon.
-- @return boolean|nil  Only when withReport is set: true when the service is idle, owned and holds a snapshot table;
--   false while running or unowned; nil otherwise.
--
-- Running state is cheap. The report check copies the last snapshot, so callers ask for it only when the running state
-- changes.
function addon:GetCastCaptureState(withReport)
    if not rawequal(self, addon) then
        return nil
    end

    local p = phase()
    local running = p == 'running' or p == 'starting'

    if not withReport then
        return running
    end
    if running or not owned() then
        return running, false
    end

    return running, type(invoke('GetSnapshot')) == 'table'
end

-- Ends the current capture generation and clears the service.
-- @return boolean  True when the service reported a clear.
--
-- It only ever calls the originally captured Clear, so shutdown never runs a replacement. Clear is the strict inverse
-- for a pending Start too.
local function retire()
    generation = generation + 1
    lease = nil
    busy = nil

    -- Clear is the strict inverse for a pending Start too. Never invoke a
    -- replacement service or replacement method during addon shutdown.
    if service and type(methods.Clear) == 'function' and rawequal(service.Clear, methods.Clear) then
        return invoke('Clear') == true
    end

    return false
end

-- Drops any capture when the addon is disabled; called from Diagnostics/cpu.lua after the CPU and memory captures stop.
-- @return boolean  True when the service cleared; false when called with a self other than addon or nothing was
--   cleared.
function addon:ClearCastCaptureForDisable()
    if not rawequal(self, addon) then
        return false
    end

    return retire()
end

-- ============================================================================
-- Report text
-- ============================================================================

-- Formats a finite number for the report.
-- @param v any  The value to format.
-- @return string  tostring(v) for a finite number; "?" for NaN, infinities and non-numbers, so nothing unreadable is
--   printed.
local function number(v)
    if type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge then
        return tostring(v)
    end

    return '?'
end

-- Formats client metadata for the report.
-- @param v any  The metadata value.
-- @return string  A number through number(); a string cut to 64 characters with control characters made spaces and
--   pipes doubled; "unavailable" (localized) for anything else.
local function metadata(v)
    if type(v) == 'number' then
        return number(v)
    end
    if type(v) ~= 'string' then
        return L['unavailable']
    end

    return (v:sub(1, 64):gsub('[%c]', ' '):gsub('|', '||'))
end

-- Restricts a report field to a fixed vocabulary.
-- @param value any  The candidate token.
-- @param allowed table<string,boolean>  The set of accepted strings.
-- @return string  The value when it is a string in the allowed set, otherwise "unknown".
local function token(value, allowed)
    return type(value) == 'string' and allowed[value] and value or 'unknown'
end

-- The fixed vocabularies the report accepts for cast kind, actor and receipt signal.
local kinds = { ordinary = true, channel = true, autorepeat = true, unmodeled = true }
local actors = { player = true, pet = true, other = true, unknown = true }
local signals = { sent = true, start = true, success = true, failed = true, interrupted = true, stop = true }

-- These are adapter/builder tokens, never arbitrary native error text.
local reasons = {
    stop = true,
    context = true,
    disabled = true,
    error = true,
    ['end'] = true,
    unknown = true,
    ['native-error'] = true,
    ['retired-operation'] = true,
    ['unreadable-value'] = true,
    ['invalid-time'] = true,
    ['unsupported-client'] = true,
    ['invalid-client-info'] = true,
    ['missing-dependency'] = true,
    ['cleanup-failed'] = true,
    ['builder-error'] = true,
    ['invalid-payload'] = true,
    ['missing-frame-method'] = true,
    ['foreign-frame-method'] = true,
    ['foreign-frame-handler'] = true,
    ['foreign-registration'] = true,
    ['registration-failed'] = true,
    ['timer-before-commit'] = true,
    ['timer-failed'] = true,
    ['record-limit'] = true,
    ['alias-limit'] = true,
    ['pending-limit'] = true,
    ['payload-limit'] = true,
    ['invalid-receipt'] = true,
    ['replay-refused'] = true,
    ['decreasing-time'] = true,
}

-- Builds the copyable cast report text from a detached snapshot.
-- @param snapshot table  The detached snapshot from the capture service (status, reason, advice, client, capture.trace,
--   startWitness).
-- @return string  The multi-line report; a short "Capture: unavailable" report when the snapshot is not complete or has
--   no trace.
--
-- Counts describe receipt rows only and are never scores; the detail list is capped at 200 rows with an omitted count,
-- and the START witness block between its marker comments is checked by tests.
local function report(snapshot)
    local client = type(snapshot.client) == 'table' and snapshot.client or {}

    local lines = {
        L['Rotation Master cast receipt diagnostics'],
        L['Producer: UNIT_SPELLCAST adapter'],
        L['Native acceptance: unverified'],
        snapshot.advice == 'primary-publisher-receipts'
            and L['Advice/presentation rows describe observed delivery boundaries only; ordinary-cast proof: not available.']
            or L['Advice: not available; presentation: not available; ordinary-cast proof: not available.'],
        L['Scoring: unavailable'],
        L['Rotation attribution: unavailable; capture seconds are not encounter seconds.'],
        L['Damage: unavailable (no damage observations or encounter denominator).'],
        L['Tank: unavailable (no threat, mitigation or survival observations).'],
        L['Healer: unavailable (no effective healing, absorbs or mana observations).'],
        string.format(
            L['Client: family=%s version=%s build=%s interface=%s locale=%s'],
            metadata(client.family),
            metadata(client.version),
            metadata(client.build),
            metadata(client.interface),
            metadata(client.locale)
        ),
    }

    local reason = token(snapshot.reason, reasons)

    if snapshot.status ~= 'complete' then
        lines[#lines + 1] = string.format(L['Capture: unavailable; reason=%s'], reason)
        return table.concat(lines, '\n')
    end

    local trace = snapshot.capture and snapshot.capture.trace

    if type(trace) ~= 'table' or type(trace.records) ~= 'table' then
        lines[#lines + 1] = L['Capture: unavailable']
        return table.concat(lines, '\n')
    end

    local rows = trace.records
    lines[#lines + 1] = string.format(L['Capture: complete; reason=%s'], reason)
    lines[#lines + 1] = string.format(L['Duration: %s seconds'], number(trace.duration))
    lines[#lines + 1] = string.format(L['Records: %d'], #rows)
    local attempts, results = 0, 0
    local coverage = { advice = 0, presentation = 0, visible = 0, hidden = 0, unknown = 0, retired = 0 }

    local counts = {
        sent = 0,
        start = 0,
        success = 0,
        failed = 0,
        interrupted = 0,
        stop = 0,
        channel = 0,
        unmodeled = 0,
    }

    for _, row in ipairs(rows) do
        local signal

        if row.type == 'advice' then
            coverage.advice = coverage.advice + 1
        elseif row.type == 'retire' then
            coverage.retired = coverage.retired + 1
        elseif row.type == 'presentation' then
            coverage.presentation = coverage.presentation + 1
            local state = token(row.state, { visible = true, hidden = true, unknown = true })
            coverage[state] = coverage[state] + 1
        end

        if row.type == 'attempt' then
            attempts = attempts + 1
            signal = row.phase
        elseif row.type == 'result' then
            results = results + 1
            signal = row.status
        end

        if type(signal) == 'string' and signals[signal] then
            counts[signal] = counts[signal] + 1
        end

        if row.castKind == 'channel' then
            counts.channel = counts.channel + 1
        elseif row.castKind == 'unmodeled' then
            counts.unmodeled = counts.unmodeled + 1
        end
    end

    lines[#lines + 1] = string.format(L['Attempts: %d; results: %d'], attempts, results)
    lines[#lines + 1] = L['Counts describe receipt rows, not gameplay opportunities.']

    lines[#lines + 1] = string.format(
        L['Receipt signals: sent=%d start=%d success=%d failed=%d interrupted=%d stop=%d'],
        counts.sent,
        counts.start,
        counts.success,
        counts.failed,
        counts.interrupted,
        counts.stop
    )

    lines[#lines + 1] = string.format(L['Receipt kinds: channel=%d unmodeled=%d'], counts.channel, counts.unmodeled)

    if snapshot.advice == 'primary-publisher-receipts' then
        lines[#lines + 1] = string.format(
            L['Coverage rows: advice=%d presentation=%d visible=%d hidden=%d unknown=%d retired=%d (not opportunities).'],
            coverage.advice,
            coverage.presentation,
            coverage.visible,
            coverage.hidden,
            coverage.unknown,
            coverage.retired
        )

        lines[#lines
            + 1] = L['Visible means RM-owned preview frame state at a delivery boundary; it does not prove perception or native pixel rendering.']
    end

    for i = 1, math.min(#rows, 200) do
        local row = rows[i]

        if row.type == 'advice' then
            lines[#lines + 1] = string.format(
                'seq=%s time=%s advice action=%s spell=%s epoch=%s',
                number(row.seq),
                number(row.time),
                token(row.action, { spell = true, unmodeled = true, none = true, unknown = true }),
                number(row.spell),
                number(row.epoch)
            )
        elseif row.type == 'presentation' then
            lines[#lines + 1] = string.format(
                'seq=%s time=%s presentation adviceSeq=%s state=%s',
                number(row.seq),
                number(row.time),
                number(row.adviceSeq),
                token(row.state, { visible = true, hidden = true, unknown = true })
            )
        elseif row.type == 'retire' then
            lines[#lines + 1] = string.format(
                'seq=%s time=%s retire reason=%s',
                number(row.seq),
                number(row.time),
                token(row.reason, reasons)
            )
        else
            local kind = token(row.type, { attempt = true, result = true })

            lines[#lines + 1] = string.format(
                'seq=%s time=%s %s actor=%s cast=%s spell=%s kind=%s signal=%s',
                number(row.seq),
                number(row.time),
                kind,
                token(row.actor, actors),
                number(row.cast),
                number(row.spell),
                token(row.castKind, kinds),
                token(row.phase or row.status, signals)
            )
        end
    end

    if #rows > 200 then
        lines[#lines + 1] = string.format(L['Rows omitted: %d'], #rows - 200)
    end

    -- BEGIN ANALYTICS START WITNESS REPORT
    if type(snapshot.startWitness) == 'table' then
        local counts = snapshot.startWitness

        -- Formats one START witness counter.
        -- @param value any  The counter value.
        -- @return string  The integer as text when it is a whole number from 0 to 4096; "?" otherwise.
        local function count(value)
            return type(value) == 'number'
                and value == value
                and value >= 0
                and value <= 4096
                and value % 1 == 0
                and tostring(value)
                or '?'
        end

        lines[#lines + 1] = string.format(
            L['START witness rows: observed=%s matched=%s mismatch=%s excluded=%s unknown=%s (not ordinary proof).'],
            count(counts.observed),
            count(counts.matched),
            count(counts.mismatch),
            count(counts.excluded),
            count(counts.unknown)
        )

        lines[#lines
            + 1] = L['START witnesses compare current cast identity and non-autorepeat classification only; they do not classify ordinary casts or enable scoring.']
    end

    -- END ANALYTICS START WITNESS REPORT
    return table.concat(lines, '\n')
end

-- ============================================================================
-- Actions
-- ============================================================================

-- Runs one capture action from the settings page.
-- @param action string  One of "start", "stop", "report" or "clear".
-- @return boolean  True when the action succeeded.
-- @return string  The localized message to show; empty when the report window opened, or "" when the result is stale.
-- @return boolean|nil  False when a Clear or shutdown happened while the action ran, so the caller must not act on it;
--   true otherwise; nil on the early refusals (bad self, bad action, busy, not owned) and after "clear".
--
-- At most one action runs at a time. A start lasts 30 seconds and survives closing the settings window.
function addon:RunCastCaptureAction(action)
    if not rawequal(self, addon) then
        return false, available()
    end

    if action == 'clear' then
        if not owned() then
            return false, available()
        end

        return retire(), L['Cast capture cleared.']
    end

    if action ~= 'start' and action ~= 'stop' and action ~= 'report' then
        return false, available()
    end
    if busy or not owned() then
        return false, available()
    end

    local operation = {}
    busy = operation
    local ticket = generation
    local ok, message = false, available()

    if action == 'start' then
        local value = invoke('Start', { duration = 30 })

        if ticket == generation and owned() and value then
            lease = value
            ok = true
            message = L['Cast capture started for 30 seconds. Configuration can be closed during capture.']
        end
    elseif action == 'stop' then
        if lease then
            local value = invoke('Stop', lease, 'stop')

            if ticket == generation and owned() and value then
                lease = nil
                ok = true
                message = L['Cast capture stopped. Open Cast report to inspect receipts.']
            end
        else
            message = L['No cast capture is running.']
        end
    else
        local status = phase()

        if status == 'running' or status == 'starting' then
            message = L['Cast capture is running. Stop it or wait before opening Cast report.']
        else
            local value = invoke('GetSnapshot')

            if
                ticket == generation
                and owned()
                and type(value) == 'table'
                and type(self.ShowConditionText) == 'function'
            then
                local text = report(value)

                if ticket == generation and owned() then
                    local shown = pcall(self.ShowConditionText, self, text, L['Cast receipt report'])
                    ok = shown
                    message = shown and '' or available()
                end
            else
                message = L['No cast capture report is available. Start a capture first.']
            end
        end
    end

    if rawequal(busy, operation) then
        busy = nil
    end

    if ticket ~= generation then
        return false, '', false
    end

    return ok, message, true
end
