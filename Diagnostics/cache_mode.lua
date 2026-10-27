local _, addon = ...
-- Acquire the owned dispatch cell before ordinary aliases are captured, then
-- select once after AceDB initialization has materialized SavedVariables.
local type, rawget, rawset, pcall = type, rawget, rawset, pcall
local globals = _G

local function savedGlobal()
    local saved = rawget(globals, 'RotationMasterDB')
    return type(saved) == 'table' and rawget(saved, 'global') or nil
end

local function readyGlobal()
    local db = rawget(addon, 'db')
    return type(db) == 'table' and rawget(db, 'global') or nil
end

local function directRequested(global)
    -- Preserve explicit legacy choices: false means cached, true means direct.
    -- Missing or malformed preferences use the allocation-light direct default.
    return type(global) ~= 'table' or rawget(global, 'diagnosticCacheBypass') ~= false
end

local loaded = 'cached'
local dispatch
local bind = rawget(addon, 'BindCacheDiagnosticDispatcher')

if type(bind) == 'function' then
    local ok = pcall(bind, addon, function(selectMode)
        if type(selectMode) == 'function' then dispatch = selectMode end
    end)

    rawset(addon, 'BindCacheDiagnosticDispatcher', nil)
    if not ok then dispatch = nil end
end

local finalized, initialized = false, false

function addon:InitializeCacheDiagnosticMode(global)
    if self ~= addon then return false, 'invalid-owner' end

    if finalized then
        if initialized then return true end
        return false, 'cache-mode-unavailable'
    end

    if type(global) ~= 'table' then return false, 'cache-mode-unavailable' end
    finalized = true
    local selectMode = dispatch
    dispatch = nil
    if type(selectMode) ~= 'function' then return false, 'cache-mode-unavailable' end
    local direct = directRequested(global)
    local ok, selected = pcall(selectMode, direct)
    if not ok or selected ~= true then return false, 'cache-mode-unavailable' end
    loaded = direct and 'direct' or 'cached'
    initialized = true
    return true
end

function addon:GetCacheDiagnosticMode()
    if self ~= addon then return nil, 'invalid-owner' end
    local global = readyGlobal()
    if type(global) ~= 'table' then global = savedGlobal() end
    local requested = directRequested(global) and 'direct' or 'cached'
    return loaded, requested, loaded ~= requested
end

function addon:SetCacheDiagnosticMode(mode)
    if self ~= addon then return false, 'invalid-owner' end
    if mode ~= 'cached' and mode ~= 'direct' then return false, 'invalid-cache-mode' end
    local global = readyGlobal()
    if type(global) ~= 'table' then return false, 'cache-mode-unavailable' end
    rawset(global, 'diagnosticCacheBypass', mode == 'direct')
    return true
end
