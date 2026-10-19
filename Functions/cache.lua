local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local _G,unpack,type,pairs=_G,unpack,type,pairs

-- One closure owns native cache state; legacy addon APIs remain direct aliases.
local cache={}
addon.Functions=addon.Functions or {}
addon.Functions.cache=cache

local cacheHits = 0
local cacheMisses = 0
local nilArgument, cachedResult = {}, {}

local function packResults(...)
    return { n = select('#', ...), ... }
end

local function getCachedInternal(cache, recordnil, func, ...)
    if type(func) == 'string' then func = _G[func] end
    if type(func) ~= 'function' then return end
    if cache == nil then return func(...) end

    -- Exact keys preserve argument types, identity and arity. Hashing concatenated
    -- strings allowed unrelated observations to collide, even for numeric IDs.
    local args, count = { ... }, select('#', ...)
    for i = 1, count do
        local value = args[i]
        if addon.Platform and addon.Platform.CanReadValue and not addon.Platform:CanReadValue(value) then
            return func(...)
        end
        if type(value) == 'number' and value ~= value then return func(...) end
        if value == nil then args[i] = nilArgument end
    end
    local node = cache[func]
    for i = 1, count do
        if not node then break end
        node = node[args[i]]
    end
    local result = node and node[cachedResult]
    if result then
        cacheHits = cacheHits + 1
        return unpack(result, 1, result.n)
    end

    cacheMisses = cacheMisses + 1
    result = packResults(func(...))
    local store = recordnil
    if not store then
        -- Inspect the packed keys, not potentially restricted return values.
        for key in pairs(result) do
            if type(key) == 'number' then store = true; break end
        end
    end
    if store then
        -- Retry misses and thrown calls must not accumulate empty paths.
        if not cache[func] then cache[func] = {} end
        node = cache[func]
        for i = 1, count do
            local key = args[i]
            if not node[key] then node[key] = {} end
            node = node[key]
        end
        node[cachedResult] = result
    end
    return unpack(result, 1, result.n)
end

cache.getCached = function(cache, func, ...)
    return getCachedInternal(cache, true, func, ...)
end

cache.getRetryCached = function(cache, func, ...)
    return getCachedInternal(cache, false, func, ...)
end

function cache:ReportCacheStats()
    addon:debug(L["Cache hit rate at %.02f%%"], (cacheHits / (cacheHits + cacheMisses)) * 100)
    cacheHits = 0
    cacheMisses = 0
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="cacheHits" then return cacheHits end
        if name=="cacheMisses" then return cacheMisses end
        if name=="cachedResult" then return cachedResult end
        if name=="getCached" then return addon.Functions.cache.getCached end
        if name=="getCachedInternal" then return getCachedInternal end
        if name=="getRetryCached" then return addon.Functions.cache.getRetryCached end
        if name=="nilArgument" then return nilArgument end
        if name=="packResults" then return packResults end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Functions/cache.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Functions/cache.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
