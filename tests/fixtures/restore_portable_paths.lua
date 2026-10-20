-- Strict inverse of diagnostic-path bookkeeping only; all validation stays live.
local old=[==[
function data.CheckPortable(value)
    local active, nodes, bytes = {}, 0, 0
    local function text(value, path)
        if #value > maxString then return false, diagnostic("data-string-limit", path) end
        bytes = bytes + #value
        if bytes > maxBytes then return false, diagnostic("data-byte-limit", path) end
        return true
    end
    local function visit(current, path, depth)
        nodes = nodes + 1
        if nodes > maxNodes then return false, diagnostic("data-node-limit", path) end
        if depth > maxDepth then return false, diagnostic("data-depth-limit", path) end
        local kind = type(current)
        if kind == "nil" or kind == "boolean" then return true end
        if kind == "string" then return text(current, path) end
        if kind == "number" then
            if finite(current) then return true end
            return false, diagnostic("non-finite-number", path)
        end
        if kind ~= "table" then return false, diagnostic("non-portable-type", path) end
        if getmetatable(current) ~= nil then return false, diagnostic("data-metatable", path) end
        if active[current] then return false, diagnostic("data-cycle", path) end
        active[current] = true
        local keys = {}
        -- Bound collection before sorting or visiting children. A wide hostile
        -- table must not trigger an unbounded sort merely to report an error.
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
                local ok, why = text(key, path)
                if not ok then return false, why end
            end
            local suffix = type(key) == "number" and "["..key.."]" or "."..key:sub(1, 80)
            local ok, why = visit(current[key], path..suffix, depth+1)
            if not ok then return false, why end
        end
        active[current] = nil
        return true
    end
    return visit(value, "$", 0)
end
]==]
local repaired=[==[
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
]==]
local oldDiagnostic=[==[
local function diagnostic(code, path)
    return {code=code, path=path, severity="error"}
end
]==]
local repairedDiagnostic=[==[
local function diagnostic(code, path)
    local location = "$"
    for _, key in ipairs(path) do
        location = location .. (type(key)=="number" and "["..key.."]" or "."..key:sub(1,80))
    end
    return {code=code, path=location, severity="error"}
end
]==]
local function replaceOnce(text,new,old)
 local first,last=text:find(new,1,true)
 assert(first and not text:find(new,last+1,true),'unexpected portable path repair body/count')
 return text:sub(1,first-1)..old..text:sub(last+1)
end
return function(text,hash)
 assert(type(text)=='string','expected portable module source')
 text=replaceOnce(text,repaired,old)
 text=replaceOnce(text,repairedDiagnostic,oldDiagnostic)
 if hash then assert(hash(text)=='12133044','portable module differs beyond path bookkeeping') end
 return text
end,old,repaired
