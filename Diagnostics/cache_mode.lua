-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Cache diagnostic mode: chooses once per session whether the observation cache memoizes (cached) or every call goes
-- straight to its function (direct), so /rm perf can measure what the cache costs.
-- Owns the one-shot switch handed over by Functions/cache.lua (BindCacheDiagnosticDispatcher) and the saved choice
-- RotationMasterDB.global.diagnosticCacheBypass (absent or true means direct, an explicit false means cached). The
-- choice is applied by addon:InitializeCacheDiagnosticMode from main.lua after AceDB initialization and takes effect
-- on reload; it must not be switched mid-session. Loaded from RotationMaster.toc after Functions/cache.lua.
local _, addon = ...
-- Acquire the owned dispatch cell before ordinary aliases are captured, then
-- select once after AceDB initialization has materialized SavedVariables.
local type, rawget, rawset, pcall = type, rawget, rawset, pcall
local globals = _G

-- Returns the global saved-variables table straight from the RotationMasterDB global (before AceDB has set up
-- addon.db), or nil.
local function savedGlobal()
    local saved = rawget(globals, 'RotationMasterDB')
    return type(saved) == 'table' and rawget(saved, 'global') or nil
end

-- Returns the AceDB global table once addon.db exists, or nil before that.
local function readyGlobal()
    local db = rawget(addon, 'db')
    return type(db) == 'table' and rawget(db, 'global') or nil
end

-- Returns true when the saved choice asks for direct mode.
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
        if type(selectMode) == 'function' then
            dispatch = selectMode
        end
    end)

    rawset(addon, 'BindCacheDiagnosticDispatcher', nil)

    if not ok then
        dispatch = nil
    end
end

local finalized, initialized = false, false

-- Applies the saved choice, once, by firing the switch Functions/cache.lua handed over. Returns true, or false and a
-- reason code; later calls report the first outcome and never change the mode again.
function addon:InitializeCacheDiagnosticMode(global)
    if self ~= addon then
        return false, 'invalid-owner'
    end

    if finalized then
        if initialized then
            return true
        end

        return false, 'cache-mode-unavailable'
    end

    if type(global) ~= 'table' then
        return false, 'cache-mode-unavailable'
    end

    finalized = true
    local selectMode = dispatch
    dispatch = nil

    if type(selectMode) ~= 'function' then
        return false, 'cache-mode-unavailable'
    end

    local direct = directRequested(global)
    local ok, selected = pcall(selectMode, direct)

    if not ok or selected ~= true then
        return false, 'cache-mode-unavailable'
    end

    loaded = direct and 'direct' or 'cached'
    initialized = true
    return true
end

-- Returns the mode in effect this session ("cached" or "direct"), the mode the saved choice asks for, and whether
-- they differ (a reload is then needed).
function addon:GetCacheDiagnosticMode()
    if self ~= addon then
        return nil, 'invalid-owner'
    end

    local global = readyGlobal()

    if type(global) ~= 'table' then
        global = savedGlobal()
    end

    local requested = directRequested(global) and 'direct' or 'cached'
    return loaded, requested, loaded ~= requested
end

-- Saves the choice for the next session ("cached" or "direct"); does not change the mode in effect. Returns true, or
-- false and a reason code.
function addon:SetCacheDiagnosticMode(mode)
    if self ~= addon then
        return false, 'invalid-owner'
    end
    if mode ~= 'cached' and mode ~= 'direct' then
        return false, 'invalid-cache-mode'
    end

    local global = readyGlobal()

    if type(global) ~= 'table' then
        return false, 'cache-mode-unavailable'
    end

    rawset(global, 'diagnosticCacheBypass', mode == 'direct')
    return true
end
