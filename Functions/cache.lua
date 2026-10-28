-- Per-poll result cache for condition evaluation: getCached/getRetryCached memoize a function call by its exact
-- arguments inside one cache table, and protectedRead wraps a cached call in pcall for condition code.
-- This file owns the canonical bodies; utils.lua re-exports them as addon.getCached, addon.getRetryCached and
-- addon.ReportCacheStats for saved custom source. Diagnostics/cache_mode.lua binds the diagnostic dispatcher.
-- Loaded from RotationMaster.toc with the other Functions/ files, after Functions/collections.lua.
-- Restricted clients: an argument that platform:CanReadValue rejects makes the call bypass the cache entirely, so a
-- secret value is never used as a table key.
-- The function bodies are recorded as Built In helpers and are frozen: saved copies hash their exact text.
local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- Calls a cached read behind pcall.
-- @param cache table|nil  The cache table passed to getCached.
-- @param method function|nil  The function to call through the cache.
-- @param ... any  The arguments of the call.
-- @return boolean  True when the call ran without error; false for a throwing call, or when the method is absent.
-- @return any  The call's results (any number), the error value, or "missing-api" when the method is absent (an API
--   this client does not have).
--
-- Conditions use it so a throwing read becomes "unavailable", not an error. Preserves the original global type/pcall
-- lookups and live legacy cache dispatch.
local function protectedRead(cache, method, ...)
    if type(method)~="function" then return false,"missing-api" end
    return pcall(addon.getCached,cache,method,...)
end

local _G, unpack, type, pairs = _G, unpack, type, pairs

-- One closure owns native cache state; legacy addon APIs remain direct aliases.
local cache = {}
addon.Functions = addon.Functions or {}
addon.Functions.cache = cache
cache.protectedRead = protectedRead

local cacheHits = 0
local cacheMisses = 0
local nilArgument, cachedResult = {}, {}

-- Packs a call's results into a table with an explicit count so nil results survive the round trip.
-- @param ... any  The values to pack.
-- @return table  {n=count, ...}.
local function packResults(...)
    return { n = select('#', ...), ... }
end

-- Returns the memoized results of func(...) from the cache table, calling and storing on a miss.
-- @param cache table|nil  The cache table; nil calls through uncached.
-- @param recordnil boolean  True to store a call that returned nothing; false to retry it next time (the getRetryCached
--   behavior).
-- @param func function|string  The function to call, or the name of a global function.
-- @param ... any  The arguments of the call; they are the cache key, so an unreadable (restricted) or NaN argument
--   calls through uncached.
-- @return any  The results of func(...), any number of them; nothing when func is not a function.
---@param cache table|nil
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

-- Keep the source-owned implementation above and its generated getter intact.
-- Both existing public wrappers share this diagnostic-only dispatch cell.
do
    local getCachedInternal = getCachedInternal
    local bound = false

    -- Hands the diagnostics module a one-shot switch that can route every cached call straight to the function, with no
    -- memoizing, to measure the cache's cost.
    -- @param bind function  Called once with the switch function(direct): it takes a boolean (true routes calls
    --   straight through), returns true on the first valid call and false afterwards.
    --
    -- Only the first call binds; Diagnostics/cache_mode.lua calls it at load and then removes this method from addon.
    function addon:BindCacheDiagnosticDispatcher(bind)
        if self ~= addon or type(bind) ~= "function" or bound then
            return
        end

        bound = true
        local selected = false

        bind(function(direct)
            if selected or type(direct) ~= "boolean" then
                return false
            end

            selected = true

            if direct then
                getCachedInternal = function(_, _recordnil, func, ...)
                    if type(func) == 'string' then
                        func = _G[func]
                    end

                    if type(func) ~= 'function' then
                        return
                    end

                    return func(...)
                end
            end

            return true
        end)
    end

    -- Memoizing call: results are stored whether or not the function returned anything.
    -- @param cache table|nil  The cache table; nil calls through uncached.
    -- @param func function|string  The function to call, or the name of a global function.
    -- @param ... any  The arguments of the call.
    -- @return any  The results of func(...), any number of them.
    cache.getCached = function(cache, func, ...)
    return getCachedInternal(cache, true, func, ...)
end

    -- Memoizing call that does not store an empty result, so a read that returned nothing is retried on the next call.
    -- @param cache table|nil  The cache table; nil calls through uncached.
    -- @param func function|string  The function to call, or the name of a global function.
    -- @param ... any  The arguments of the call.
    -- @return any  The results of func(...), any number of them.
    cache.getRetryCached = function(cache, func, ...)
    return getCachedInternal(cache, false, func, ...)
end
end

-- Writes the hit rate since the last report to the debug log and resets the counters (main.lua's evaluation report
-- calls it as ReportCacheStats(addon) about every 15 seconds; with no calls recorded the rate is 0/0).
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
        if name=="protectedRead" then return protectedRead end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Functions/cache.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Functions/cache.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
