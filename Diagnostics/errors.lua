local addon_name, addon = ...

-- No global error hook: only RM-owned execution boundaries call this service.
local service = {}
addon.Diagnostics = service
local reports, fingerprints, nextId = {}, {}, 0
local handling = false
local fields = {"module", "operation", "event", "rotationId", "rotationRevision", "stepId",
                "conditionPath", "conditionTag", "actionContext", "provider", "providerVersion"}
local platformFields = {"family", "projectId", "expansion", "classicExpansionLevel", "seasonId", "gameModeId",
                        "hardcore", "selfFoundAllowed", "combatDataPolicy", "runtimeVerified"}

local function readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    if type(canaccessvalue) == "function" then
        local ok, allowed = pcall(canaccessvalue, value)
        if not ok or not allowed then return false end
    end
    return true
end

local function scalar(value, limit)
    if not readable(value) then return nil end
    local kind = type(value)
    if kind == "string" then return value:sub(1, limit or 256) end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then return tostring(value) end
end

local function probe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return scalar(value) end
end

local function contextCopy(context)
    local copy = {}
    if readable(context) and type(context) == "table" then
        for _, key in ipairs(fields) do copy[key] = scalar(rawget(context, key)) end
    end
    return copy
end

local function copyRecord(record)
    local copy = {}
    for key, value in pairs(record) do
        if key == "context" then copy.context = contextCopy(value)
        elseif key ~= "rawMessage" and key ~= "rawStack" then copy[key] = value end
    end
    return copy
end

local function identifiers()
    local names = {}
    local function add(value)
        value = scalar(value)
        if value and #value >= 2 then names[#names+1] = value end
    end
    add(probe(GetRealmName))
    add(probe(GetGuildInfo, "player"))
    if type(UnitName) == "function" then
        for i = 0, 44 do
            local unit = i == 0 and "player" or i <= 4 and "party"..i or "raid"..(i-4)
            local ok, name, realm = pcall(UnitName, unit)
            if ok then add(name); add(realm) end
        end
    end
    return names
end

local function redact(text, names)
    text = text:gsub("Player%-%d+%-%x+", "<player-guid>")
    text = text:gsub("(/home/)[^/]+", "%1<user>"):gsub("(/Users/)[^/]+", "%1<user>")
    text = text:gsub("([A-Za-z]:\\Users\\)[^\\]+", "%1<user>")
    for _, name in ipairs(names) do
        text = text:gsub(name:gsub("(%W)", "%%%1"), "<redacted>")
    end
    return text
end

local function recordError(context, message, stack)
    local clean = contextCopy(context)
    local errorText = scalar(message, 2048) or "<unavailable error value>"
    stack = scalar(stack, 8192) or "<stack unavailable>"
    local fingerprint = errorText.."\n"..stack
    for _, key in ipairs(fields) do fingerprint = fingerprint.."\n"..key.."="..(clean[key] or "") end
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
        if line:find('[string', 1, true) then return "<custom Lua stack frame omitted>" end
        return redact(line, names)
    end)
    for key, value in pairs(clean) do clean[key] = redact(value, names) end
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version, build, interface
    if type(GetBuildInfo) == "function" then
        local ok, v, b, _, i = pcall(GetBuildInfo)
        if ok then version, build, interface = scalar(v), scalar(b), scalar(i) end
    end
    local record = {id=nextId, count=1, first=now, last=now, message=safeMessage, stack=safeStack,
                    rawMessage=errorText, rawStack=stack,
                    context=clean, addonVersion=probe(metadata, addon_name, "Version") or "unknown",
                    clientVersion=version or "unknown", clientBuild=build or "unknown",
                    interface=interface or "unknown", locale=probe(GetLocale) or "unknown",
                    fingerprint=fingerprint}
    if addon.Platform and type(addon.Platform.GetClientInfo) == "function" then
        local ok, info = pcall(addon.Platform.GetClientInfo, addon.Platform)
        if ok and readable(info) and type(info) == "table" then
            for _, key in ipairs(platformFields) do record["platform_"..key] = scalar(rawget(info, key)) end
        end
    end
    reports[#reports+1] = record
    fingerprints[fingerprint] = record
    if #reports > 100 then
        local removed = table.remove(reports, 1)
        fingerprints[removed.fingerprint] = nil
    end
    return record.id
end

function service:Call(context, callback, ...)
    local args = {n=select("#", ...), ...}
    return xpcall(function() return callback(unpack(args, 1, args.n)) end, function(message)
        if handling then return 0 end
        handling = true
        -- Capture the stack in the error handler, before xpcall unwinds it.
        local stack
        if type(debugstack) == "function" then
            local ok, value = pcall(debugstack, 2, 30, 20)
            if ok then stack = value end
        end
        local ok, id = pcall(recordError, context, message, stack)
        -- Resolve at the error point: a collector may load after RM.
        local handlerOk, handler = pcall(function()
            if type(geterrorhandler) == "function" then return geterrorhandler() end
        end)
        if handlerOk and type(handler) == "function" then pcall(handler, message) end
        handling = false
        return ok and id or 0
    end)
end

function service:GetReports()
    local copy = {}
    for i, record in ipairs(reports) do copy[i] = copyRecord(record); copy[i].fingerprint = nil end
    return copy
end

function service:FormatReport(id, includeOriginal)
    local parts = {}
    for _, record in ipairs(reports) do
        if id == nil or record.id == id then
            parts[#parts+1] = "Rotation Master error #"..record.id.." ("..record.count.." occurrences)"
            parts[#parts+1] = "RM: "..record.addonVersion.." | WoW: "..record.clientVersion.." | Locale: "..record.locale
            parts[#parts+1] = "Client build: "..record.clientBuild.." | Interface: "..record.interface
            for _, key in ipairs(platformFields) do
                local value = record["platform_"..key]
                if value then parts[#parts+1] = "Platform "..key..": "..value end
            end
            parts[#parts+1] = "First/last session time: "..record.first.." / "..record.last
            parts[#parts+1] = includeOriginal == true and record.rawMessage or record.message
            parts[#parts+1] = includeOriginal == true and record.rawStack or record.stack
            for _, key in ipairs(fields) do
                if record.context[key] then parts[#parts+1] = key..": "..record.context[key] end
            end
            parts[#parts+1] = ""
        end
    end
    return table.concat(parts, "\n")
end

function service:Clear()
    reports, fingerprints = {}, {}
end

-- A broken owned script is retired until its owner installs a new callback.
-- The existing collector still receives the original failure through Call.
function service:Wrap(context,callback)
    local failed=false
    return function(...)
        if failed then return end
        local function result(ok,...)
            if ok then return ... end
            failed=true
        end
        return result(self:Call(context,callback,...))
    end
end
