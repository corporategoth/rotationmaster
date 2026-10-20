local _, addon = ...
local data = addon.RotationData or {}
addon.RotationData = data
-- Owned plain-data diagnostics use standard byte slicing captured at load.
-- Literal string metatables and later library patches do not define this API.
local parserString=string
local parserSub=type(parserString)=="table" and rawget(parserString,"sub") or nil
if type(parserSub)~="function" then parserSub=nil end

-- Inputs are decoded/packaged data, never unsanitized game observations.
local maxDepth, maxNodes, maxBytes, maxString = 64, 20000, 1048576, 262144
local function diagnostic(code, path)
    local location = "$"
    for _, key in ipairs(path) do
        location = location .. (type(key)=="number" and "["..key.."]" or "."..parserSub(key,1,80))
    end
    return {code=code, path=location, severity="error"}
end
local function finite(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

function data.CheckPortable(value)
    local active, path, nodes, bytes = {}, {}, 0, 0
    local function text(value)
        if #value > maxString then return false, diagnostic("data-string-limit", path) end
        bytes = bytes + #value
        if bytes > maxBytes then return false, diagnostic("data-byte-limit", path) end
        return true
    end
    local function visit(current, depth)
        nodes = nodes + 1
        if nodes > maxNodes then return false, diagnostic("data-node-limit", path) end
        if depth > maxDepth then return false, diagnostic("data-depth-limit", path) end
        local kind = type(current)
        if kind == "nil" or kind == "boolean" then return true end
        if kind == "string" then return text(current) end
        if kind == "number" then
            if finite(current) then return true end
            return false, diagnostic("non-finite-number", path)
        end
        if kind ~= "table" then return false, diagnostic("non-portable-type", path) end
        if getmetatable(current) ~= nil then return false, diagnostic("data-metatable", path) end
        if active[current] then return false, diagnostic("data-cycle", path) end
        active[current] = true
        local keys = {}
        -- Preserve bounded collection and deterministic validation order.
        for key in pairs(current) do
            nodes = nodes + 1
            if nodes > maxNodes then return false, diagnostic("data-node-limit", path) end
            local keyType = type(key)
            if keyType ~= "string" and not (keyType == "number" and finite(key) and key >= 1 and key % 1 == 0) then
                return false, diagnostic("non-portable-key", path)
            end
            keys[#keys+1] = key
        end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b end
            return type(a) == "number"
        end)
        for _, key in ipairs(keys) do
            if type(key) == "string" then
                local ok, why = text(key)
                if not ok then return false, why end
            end
            path[#path+1] = key
            local ok, why = visit(current[key], depth+1)
            path[#path] = nil
            if not ok then return false, why end
        end
        active[current] = nil
        return true
    end
    return visit(value, 0)
end

function data.CopyData(value)
    local ok, why = data.CheckPortable(value)
    if not ok then return nil, why end
    local copies = {}
    local function copy(current)
        if type(current) ~= "table" then return current end
        if copies[current] then return copies[current] end
        local result = {}
        copies[current] = result
        for key, child in pairs(current) do result[key] = copy(child) end
        return result
    end
    return copy(value)
end

-- Private source-owner proof. Public portable/copy APIs remain fresh and live.
local portableType,portableRawget,portableEqual=type,rawget,rawequal
local portableGetmetatable=getmetatable
---@type fun(f: number|function): table
local portableGetfenv=getfenv
local portablePairs,portableIpairs=pairs,ipairs
local portableTable,portableMath=table,math
local portableSort,portableHuge=table.sort,math.huge
local portableEnvironment=portableType(portableGetfenv)=="function" and portableGetfenv(1) or nil
local ownedPortable=data.CheckPortable
local function portableOwned(namespace)
    return portableEqual(namespace,data) and portableType(portableEnvironment)=="table"
        and portableType(parserSub)=="function"
        and portableEqual(portableRawget(data,"CheckPortable"),ownedPortable)
        and portableEqual(portableGetfenv(ownedPortable),portableEnvironment)
        and portableEqual(portableGetfenv(finite),portableEnvironment)
        and portableEqual(portableGetfenv(diagnostic),portableEnvironment)
        and portableEqual(portableRawget(portableEnvironment,"type"),portableType)
        and portableEqual(portableRawget(portableEnvironment,"pairs"),portablePairs)
        and portableEqual(portableRawget(portableEnvironment,"ipairs"),portableIpairs)
        and portableEqual(portableRawget(portableEnvironment,"getmetatable"),portableGetmetatable)
        and portableEqual(portableRawget(portableEnvironment,"getfenv"),portableGetfenv)
        and portableEqual(portableRawget(portableEnvironment,"math"),portableMath)
        and portableEqual(portableRawget(portableMath,"huge"),portableHuge)
        and portableEqual(portableRawget(portableEnvironment,"table"),portableTable)
        and portableEqual(portableRawget(portableTable,"sort"),portableSort)
end
-- Capture-only explanation of the existing proof; never authorizes execution.
local function portableStatus(namespace)
    local result={reason="ready",raw={}}
    local function check(reason,ok) if result.reason=="ready" and not ok then result.reason=reason end end
    local environment=portableType(portableEnvironment)=="table"
    local capability=portableType(portableGetfenv)=="function"
    check("namespace",portableEqual(namespace,data));check("capability",capability)
    check("env",environment)
    check("method",portableEqual(portableRawget(data,"CheckPortable"),ownedPortable))
    check("public-env",capability and portableEqual(portableGetfenv(ownedPortable),portableEnvironment))
    check("finite-env",capability and portableEqual(portableGetfenv(finite),portableEnvironment))
    check("diagnostic-env",capability and portableEqual(portableGetfenv(diagnostic),portableEnvironment))
    result.parserSub=portableType(parserSub)=="function"
    check("parser-sub-unavailable",result.parserSub)
    local keys={"type","pairs","ipairs","getmetatable","getfenv","math","table"}
    local pointers={portableType,portablePairs,portableIpairs,portableGetmetatable,portableGetfenv,portableMath,portableTable}
    for i=1,7 do
        local key=keys[i];local ok=environment and portableEqual(portableRawget(portableEnvironment,key),pointers[i]) or false
        result.raw[key]=ok;check("raw-"..key,ok)
        if key=="math" then check("math-huge",portableType(portableMath)=="table" and portableEqual(portableRawget(portableMath,"huge"),portableHuge)) end
        if key=="table" then check("table-sort",portableType(portableTable)=="table" and portableEqual(portableRawget(portableTable,"sort"),portableSort)) end
    end
    return result
end
function addon:BindRotationPortableReader(bind)
    if self~=addon or portableType(bind)~="function" then return end
    bind(portableOwned,portableStatus)
end
