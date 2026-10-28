-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Error boundary and report store: addon.Diagnostics. Callbacks run through service:Call or service:Wrap, a failure is
-- recorded with its (redacted) message, stack and context, deduplicated by fingerprint, and handed on to the game's
-- own error handler so other collectors still see it. Also observes protected-action blocks and errors reported to
-- the global error handler that come from this addon.
-- Must not leak personal data: names, realms, guild, player GUIDs and home paths are redacted, and custom Lua
-- (a "[string" chunk) is never recorded unless the original text is explicitly requested (FormatReport). Keeps at
-- most 100 reports in memory only. Loaded from RotationMaster.toc after profiler.lua, before Diagnostics/cpu.lua.
local addon_name, addon = ...

-- RM boundaries catch thrown failures. A narrow observer forwards every
-- reported error to the existing collector, recording only RM-attributable ones.
local service = {}
addon.Diagnostics = service
local reports, fingerprints, nextId = {}, {}, 0
local handling = false
local activeContext
local observerHandlers = setmetatable({}, { __mode = 'k' })
local forwarding = 0

local fields = {
    "module", "operation", "event", "rotationId", "rotationRevision", "stepId", "conditionPath", "conditionTag",
    "actionContext", "provider", "providerVersion"
}

local platformFields = {
    "family", "projectId", "expansion", "classicExpansionLevel", "seasonId", "gameModeId", "hardcore",
    "selfFoundAllowed", "combatDataPolicy", "runtimeVerified"
}

-- ============================================================================
-- Scalar copies and redaction
-- ============================================================================

-- Tells whether a game value may be read: it is neither a secret nor inaccessible.
-- @param value any  The value to test.
-- @return boolean  True when the value is readable; false when it is secret or inaccessible, or when the check throws.
local function readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)

        if not ok or secret then
            return false
        end
    end

    if type(canaccessvalue) == "function" then
        local ok, allowed = pcall(canaccessvalue, value)

        if not ok or not allowed then
            return false
        end
    end

    return true
end

-- Converts a value to a string scalar for a report.
-- @param value any  The value to convert.
-- @param limit number|nil  The most characters kept of a string; nil means 256.
-- @return string|nil  The string (truncated), or "true"/"false", or the number as text; nil for anything else or an
--   unreadable value.
--
-- Reports hold scalars only, never live references.
local function scalar(value, limit)
    if not readable(value) then
        return nil
    end

    local kind = type(value)

    if kind == "string" then
        return value:sub(1, limit or 256)
    end
    if kind == "boolean" then
        return value and "true" or "false"
    end
    if kind == "number" then
        return tostring(value)
    end
end

-- Calls fn under pcall and returns its first result as a scalar string.
-- @param fn function|nil  The function to call; anything else yields nil.
-- @param ... any  The arguments passed to fn.
-- @return string|nil  The first result as a scalar (see scalar); nil when fn is not a function, throws or returns
--   something else.
local function probe(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, value = pcall(fn, ...)

    if ok then
        return scalar(value)
    end
end

-- Copies the whitelisted fields of an operation context into a table of scalars.
-- @param context table|nil  The operation context; anything but a readable table yields an empty copy.
-- @return table  The scalar string value of each whitelisted field that has one, by field name.
--
-- A rotation id that is an issued session handle is replaced by the rotation's printable identifier, or dropped.
local function contextCopy(context)
    local copy = {}

    if readable(context) and type(context) == "table" then
        for _, key in ipairs(fields) do
            local value = rawget(context, key)

            if key == 'rotationId' and readable(value) and type(value) == 'string' and value:find('[%z\1-\31\127]') then
                -- Issued row/runtime handles are private session authority,
                -- not printable or portable identifiers. Never report one.
                local ok, reference = pcall(function()
                    if addon.ResolveRotationReference then
                        return addon:ResolveRotationReference(addon.currentSpec, value)
                    end
                end)

                value = ok
                    and type(reference) == 'table'
                    and (reference.kind == 'builtin' and reference.id
                        or type(reference.address) == 'table' and reference.address.id)
                    or nil
            end

            copy[key] = scalar(value)
        end
    end

    return copy
end

-- Copies a stored report without the raw message and stack, with the context rebuilt through contextCopy.
-- @param record table  A stored report.
-- @return table  The copy.
local function copyRecord(record)
    local copy = {}

    for key, value in pairs(record) do
        if key == "context" then
            copy.context = contextCopy(value)
        elseif key ~= "rawMessage" and key ~= "rawStack" then
            copy[key] = value
        end
    end

    return copy
end

-- Collects the personal names to scrub from a report: realm, guild, and the name and realm of the player, party and
-- raid members (at most 45 units).
-- @return string[]  The names; names shorter than two characters are skipped.
local function identifiers()
    local names = {}

    -- Adds one name to the list when it is a readable string of at least two characters.
    -- @param value any  The name to add.
    local function add(value)
        value = scalar(value)

        if value and #value >= 2 then
            names[#names + 1] = value
        end
    end

    add(probe(GetRealmName))
    add(probe(GetGuildInfo, "player"))

    if type(UnitName) == "function" then
        for i = 0, 44 do
            local unit = i == 0 and "player" or i <= 4 and "party" .. i or "raid" .. (i - 4)
            local ok, name, realm = pcall(UnitName, unit)

            if ok then
                add(name)
                add(realm)
            end
        end
    end

    return names
end

-- Replaces player GUIDs, user names in file paths and every name in names with a placeholder.
-- @param text string  The text to scrub.
-- @param names string[]  The personal names to replace, from identifiers().
-- @return string  The scrubbed text.
local function redact(text, names)
    text = text:gsub("Player%-%d+%-%x+", "<player-guid>")
    text = text:gsub("(/home/)[^/]+", "%1<user>"):gsub("(/Users/)[^/]+", "%1<user>")
    text = text:gsub("([A-Za-z]:\\Users\\)[^\\]+", "%1<user>")

    for _, name in ipairs(names) do
        text = text:gsub(name:gsub("(%W)", "%%%1"), "<redacted>")
    end

    return text
end

-- ============================================================================
-- Recording and observing errors
-- ============================================================================

-- Records one failure.
-- @param context table|nil  The operation context (copied through contextCopy).
-- @param message any  The error value; stored as a scalar of at most 2048 characters.
-- @param stack string|nil  The stack text; at most 8192 characters are kept.
-- @return number  The report id (that of the existing report when this failure was recorded before).
--
-- An identical failure (same message, stack and context) only bumps the existing report's count. The message and stack
-- are stored redacted; the raw text is kept for explicit requests only, and custom Lua text is replaced by a
-- placeholder in the redacted form. The oldest report is dropped beyond 100.
local function recordError(context, message, stack)
    local clean = contextCopy(context)
    local errorText = scalar(message, 2048) or "<unavailable error value>"
    stack = scalar(stack, 8192) or "<stack unavailable>"
    local fingerprint = errorText .. "\n" .. stack

    for _, key in ipairs(fields) do
        fingerprint = fingerprint .. "\n" .. key .. "=" .. (clean[key] or "")
    end

    local now = probe(GetTime) or "unknown"
    local existing = fingerprints[fingerprint]

    if existing then
        existing.count = existing.count + 1
        existing.last = now
        return existing.id
    end

    nextId = nextId + 1
    local names = identifiers()
    local custom = stack:find('[string', 1, true) or errorText:find('[string', 1, true)

    if readable(context) and type(context) == "table" then
        custom = custom or scalar(rawget(context, "customCode")) == "true"
    end

    local safeMessage = custom and "<custom Lua error text omitted; original details require explicit selection>"
        or redact(errorText, names)

    local safeStack = stack:gsub("[^\n]+", function(line)
        if line:find('[string', 1, true) then
            return "<custom Lua stack frame omitted>"
        end

        return redact(line, names)
    end)

    for key, value in pairs(clean) do
        clean[key] = redact(value, names)
    end

    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version, build, interface

    if type(GetBuildInfo) == "function" then
        local ok, v, b, _, i = pcall(GetBuildInfo)

        if ok then
            version, build, interface = scalar(v), scalar(b), scalar(i)
        end
    end

    local record = {
        id = nextId,
        count = 1,
        first = now,
        last = now,
        message = safeMessage,
        stack = safeStack,
        rawMessage = errorText,
        rawStack = stack,
        context = clean,
        addonVersion = probe(metadata, addon_name, "Version") or "unknown",
        clientVersion = version or "unknown",
        clientBuild = build or "unknown",
        interface = interface or "unknown",
        locale = probe(GetLocale) or "unknown",
        fingerprint = fingerprint,
    }

    if addon.Platform and type(addon.Platform.GetClientInfo) == "function" then
        local ok, info = pcall(addon.Platform.GetClientInfo, addon.Platform)

        if ok and readable(info) and type(info) == "table" then
            for _, key in ipairs(platformFields) do
                record["platform_" .. key] = scalar(rawget(info, key))
            end
        end
    end

    reports[#reports + 1] = record
    fingerprints[fingerprint] = record

    if #reports > 100 then
        local removed = table.remove(reports, 1)
        fingerprints[removed.fingerprint] = nil
    end

    return record.id
end

-- Native security blocks are events, not necessarily thrown Lua errors or
-- geterrorhandler messages. Observe only this addon's events; other collectors
-- receive their own subscriptions normally. No retry, forwarding or polling.
do
    local frame

    -- OnEvent handler: records a blocked or forbidden protected action when this addon is the owner named by the event.
    -- @param _ any  The frame; not used.
    -- @param event string  "ADDON_ACTION_BLOCKED" or "ADDON_ACTION_FORBIDDEN"; any other event is ignored.
    -- @param owner any  The addon name the event names; events for other addons are ignored.
    -- @param blockedFunction any  The name of the blocked function, recorded as a scalar.
    local function observe(_, event, owner, blockedFunction)
        if
            handling
            or not readable(owner)
            or type(owner) ~= 'string'
            or #owner ~= #addon_name
            or owner:lower() ~= addon_name:lower()
        then
            return
        end
        if event ~= 'ADDON_ACTION_BLOCKED' and event ~= 'ADDON_ACTION_FORBIDDEN' then
            return
        end

        handling = true

        pcall(function()
            local context = contextCopy(activeContext)
            context.module = context.module or 'security'
            context.operation = event
            context.event = context.event or event
            local label = scalar(blockedFunction, 512) or '<unavailable function>'
            local stack = '<stack unavailable>'

            if type(debugstack) == 'function' then
                local traced, value = pcall(function() return debugstack(2, 30, 20) end)

                if traced then
                    stack = scalar(value, 8192) or stack
                end
            end

            recordError(
                context,
                event .. ': protected action ' .. label,
                'Stack captured at native security-event receipt:\n' .. stack
            )
        end)

        handling = false
    end

    local ok = pcall(function()
        if type(CreateFrame) ~= 'function' then
            return
        end

        frame = CreateFrame('Frame')

        if not frame or type(frame.RegisterEvent) ~= 'function' or type(frame.SetScript) ~= 'function' then
            return
        end

        frame:SetScript('OnEvent', observe)
        frame:RegisterEvent('ADDON_ACTION_BLOCKED')
        frame:RegisterEvent('ADDON_ACTION_FORBIDDEN')
    end)

    if not ok and frame then
        if type(frame.UnregisterAllEvents) == 'function' then
            pcall(frame.UnregisterAllEvents, frame)
        end
        if type(frame.SetScript) == 'function' then
            pcall(frame.SetScript, frame, 'OnEvent', nil)
        end
    end
end

-- Wraps the game's error handler once so that errors it receives from this addon's files (or from AceLocale for this
-- addon) are recorded.
-- @return boolean  True when a wrapper is installed (now or earlier); false when the handler API is missing or
--   installing failed.
--
-- Every error is still passed to the original handler. Cheap to call repeatedly: service:Call invokes it so that a
-- handler installed later is wrapped too.
function service:ObserveReportedErrors()
    if type(seterrorhandler) ~= 'function' or type(geterrorhandler) ~= 'function' then
        return false
    end

    local ok, handler = pcall(geterrorhandler)

    if not ok or type(handler) ~= 'function' then
        return false
    end
    if observerHandlers[handler] then
        return true
    end

    -- Records message when its stack passes through this addon's files (other than this one), or it is an AceLocale
    -- error for this addon.
    -- @param message any  The error message the game's handler received; non-strings are ignored.
    --
    -- Ignores errors raised while one is already being recorded or forwarded.
    local function observe(message)
        if handling or forwarding > 0 or not readable(message) or type(message) ~= 'string' then
            return
        end

        local stack = ''

        if type(debugstack) == 'function' then
            local traced, value = pcall(function() return debugstack(2, 30, 20) end)

            if traced then
                stack = scalar(value, 8192) or ''
            end
        end

        local owned = message:find('AceLocale-3.0: ' .. addon_name .. ':', 1, true)
        local prefix = 'interface/addons/' .. addon_name:lower() .. '/'

        for line in stack:lower():gmatch('[^\n]+') do
            if line:find(prefix, 1, true) and not line:find(prefix .. 'diagnostics/errors.lua', 1, true) then
                owned = true
                break
            end
        end

        if not owned then
            return
        end

        handling = true
        pcall(recordError, activeContext or { module = 'ui', operation = 'reported-error' }, message, stack)
        handling = false
    end

    -- The installed error handler: observes the error, then forwards it to the original handler unchanged.
    -- @param ... any  The arguments of the game's error handler (the error message first).
    -- @return any  Whatever the original handler returns (any number of values); rethrows its error if it failed.
    local function wrapper(...)
        observe((...))
        forwarding = forwarding + 1

        -- Restores the forwarding count and rethrows if the original handler itself errored.
        -- @param success boolean  Whether the original handler ran without error (the pcall flag).
        -- @param ... any  The handler's results, or the error value when it failed.
        -- @return any  The handler's results (any number of values).
        local function finish(success, ...)
            forwarding = forwarding - 1

            if not success then
                error((...), 0)
            end

            return ...
        end

        return finish(pcall(handler, ...))
    end

    observerHandlers[wrapper] = true
    return pcall(seterrorhandler, wrapper)
end

-- ============================================================================
-- Boundary (Call and Wrap) and reports
-- ============================================================================

-- Records the failure and passes it to the game's error handler.
-- @param message any  The error value xpcall hands over.
-- @return number  The report id, or 0 when it could not be recorded (including a failure raised while another is being
--   recorded).
--
-- The handler runs before xpcall unwinds, while activeContext is still this call's context, so one shared function
-- serves every call.
local function callFailed(message)
    if handling then
        return 0
    end

    handling = true
    -- Capture the stack in the error handler, before xpcall unwinds it.
    local stack

    if type(debugstack) == "function" then
        local ok, value = pcall(debugstack, 2, 30, 20)

        if ok then
            stack = value
        end
    end

    local ok, id = pcall(recordError, activeContext, message, stack)

    -- Resolve at the error point: a collector may load after RM.
    local handlerOk, handler = pcall(function()
        if type(geterrorhandler) == "function" then
            return geterrorhandler()
        end
    end)

    if handlerOk and type(handler) == "function" then
        pcall(handler, message)
    end

    handling = false
    return ok and id or 0
end

-- Puts the previous context back and passes the call's results through, so nested Calls keep their own context.
-- @param previous table|nil  The context to restore.
-- @param ... any  The call's results.
-- @return any  The same results (any number).
local function restore(previous, ...)
    activeContext = previous
    return ...
end

-- WoW's xpcall passes extra arguments to the callback; plain Lua 5.1 does not.
local xpcallForwards = select(2, xpcall(function(value) return value end, callFailed, true)) == true

-- Runs callback(...) under xpcall with context as the error context.
-- @param context table|nil  The error context, only read (and copied) when an error is recorded, so callers may reuse
--   one table.
-- @param callback function  The function to run.
-- @param ... any  The arguments passed to callback.
-- @return boolean  True when callback ran without error.
-- @return any  The callback's results (any number of values) on success; on failure the report id from callFailed (0
--   when it could not be recorded).
--
-- Calls run for every event and polling tick. Nested calls keep their own context.
function service:Call(context, callback, ...)
    self:ObserveReportedErrors()
    local previous = activeContext
    activeContext = context

    if xpcallForwards then
        return restore(previous, xpcall(callback, callFailed, ...))
    end

    local args = { n = select("#", ...), ... }
    return restore(previous, xpcall(function() return callback(unpack(args, 1, args.n)) end, callFailed))
end

-- Returns copies of the stored reports (redacted, without raw text or fingerprints).
-- @return table[]  The report copies, oldest first.
function service:GetReports()
    local copy = {}

    for i, record in ipairs(reports) do
        copy[i] = copyRecord(record)
        copy[i].fingerprint = nil
    end

    return copy
end

-- Formats a report as text for pasting into an issue.
-- @param id number|nil  The report id; nil formats every report.
-- @param includeOriginal boolean|nil  The original, unredacted message and stack are included only when this is exactly
--   true.
-- @return string  The formatted text; empty when no report matches.
function service:FormatReport(id, includeOriginal)
    local parts = {}

    for _, record in ipairs(reports) do
        if id == nil or record.id == id then
            parts[#parts + 1] = "Rotation Master error #" .. record.id .. " (" .. record.count .. " occurrences)"

            parts[#parts + 1] = "RM: "
                .. record.addonVersion
                .. " | WoW: "
                .. record.clientVersion
                .. " | Locale: "
                .. record.locale

            parts[#parts + 1] = "Client build: " .. record.clientBuild .. " | Interface: " .. record.interface

            for _, key in ipairs(platformFields) do
                local value = record["platform_" .. key]

                if value then
                    parts[#parts + 1] = "Platform " .. key .. ": " .. value
                end
            end

            parts[#parts + 1] = "First/last session time: " .. record.first .. " / " .. record.last
            parts[#parts + 1] = includeOriginal == true and record.rawMessage or record.message
            parts[#parts + 1] = includeOriginal == true and record.rawStack or record.stack

            for _, key in ipairs(fields) do
                if record.context[key] then
                    parts[#parts + 1] = key .. ": " .. record.context[key]
                end
            end

            parts[#parts + 1] = ""
        end
    end

    return table.concat(parts, "\n")
end

-- Forgets every stored report.
function service:Clear()
    reports, fingerprints = {}, {}
end

-- Returns a function that runs callback under service:Call with context, and stops running it after its first failure.
-- @param context table|nil  The error context passed to Call.
-- @param callback function  The function to wrap.
-- @return function  Called with the callback's arguments; returns the callback's results, or nothing once it has
--   failed.
--
-- A broken owned script is retired until its owner installs a new callback. The existing collector still receives the
-- original failure through Call.
function service:Wrap(context, callback)
    local failed = false

    return function(...)
        if failed then
            return
        end

        -- Passes the callback's results through, or retires the wrapper when it failed.
        -- @param ok boolean  Whether the call succeeded.
        -- @param ... any  The callback's results, or the failure.
        -- @return any  The callback's results on success (any number of values); nothing on failure.
        local function result(ok, ...)
            if ok then
                return ...
            end

            failed = true
        end

        return result(self:Call(context, callback, ...))
    end
end
