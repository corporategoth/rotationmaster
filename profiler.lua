-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Evaluation timer: addon:ProfiledCode builds a profiler object (start/stop/child/report/reset) that main.lua wraps
-- around each poll, and the policy half of this file decides whether that profiler measures or is a no-op.
-- Loaded from RotationMaster.toc after utils.lua and before main.lua, which consumes the policy hooks once at its load
-- and then removes the public ConsumeLegacyEvaluationProfilerPolicy name. It owns timing only: times are kept in
-- seconds, a broken or missing clock is counted as `unavailable` instead of raising, and nothing here may error on
-- the poll path. Detailed per-phase numbers are read by Diagnostics/cpu_runtime.lua through addon.evaluationProfile.
local _, addon = ...

local string, pairs, protect, kind = string, pairs, pcall, type

-- Picks the best clock the client has (GetTimePreciseSec, debugprofilestop, GetTime).
-- @return function|nil  The clock function; nil when none exists.
-- @return number  The factor that converts its result to seconds.
local function clock()
    if kind(GetTimePreciseSec) == 'function' then
        return GetTimePreciseSec, 1
    end
    if kind(debugprofilestop) == 'function' then
        return debugprofilestop, .001
    end
    if kind(GetTime) == 'function' then
        return GetTime, 1
    end

    return nil, 1
end

-- Calls the clock under pcall.
-- @param fn function|nil  The clock function.
-- @return number|nil  The reading when it is a finite non-negative number; nil otherwise.
local function readClock(fn)
    if not fn then
        return
    end

    local ok, value = protect(fn)

    if ok and kind(value) == 'number' and value == value and value >= 0 and value < math.huge then
        return value
    end
end

-- Shared do-nothing method for the disabled profiler.
local function noop() end

-- Child accessor of the disabled profiler.
-- @param self table  The disabled profiler.
-- @return table  The profiler itself, so chained child():start() calls stay no-ops.
local function nopChild(self)
    return self
end

-- Builds a profiler.
-- @param enabled boolean|nil  False returns an inert object with the same method names; anything else (including nil)
--   measures.
-- @return table  The profiler (total, count, min, max, startTime, children and the start, stop, report, reset and
--   child methods).
--
-- Children are created on demand by name and overlap with their parent rather than adding to it.
local function Constructor(enabled)
    if enabled == false then
        return {
            total = 0,
            count = 0,
            min = 0,
            max = 0,
            startTime = 0,
            children = {},
            start = noop,
            stop = noop,
            report = noop,
            reset = noop,
            child = nopChild,
        }
    end

    -- Resolve capability once per profiler, never probe/reset a shared clock.
    local timer, scale = clock()

    local rv = {
        -- Public numeric timing fields remain seconds for existing consumers.
        total = 0.0,
        count = 0,
        min = 0.0,
        max = 0.0,
        unavailable = 0,
        children = {},
        startTime = 0.0,
        -- Starts a measurement; a broken clock leaves it unmeasured.
        start = function(self)
            local value = readClock(timer)
            self._started, self._clockValid = true, value ~= nil
            self.startTime = value and value * scale or 0
        end,
        -- Stops the measurement and adds it to the totals.
        -- @param self table  The profiler; nothing happens unless start was called first.
        --
        -- A measurement with an unreadable clock or a negative duration is counted as unavailable instead of raising.
        stop = function(self)
            if not self._started then
                return
            end

            self._started = false
            local ending = readClock(timer)
            local runtime = self._clockValid and ending and ending * scale - self.startTime
            self.startTime = 0.0

            if not runtime or runtime < 0 or runtime ~= runtime or runtime == math.huge then
                self.unavailable = self.unavailable + 1
                return
            end

            if self.count == 0 or runtime < self.min then
                self.min = runtime
            end
            if runtime > self.max then
                self.max = runtime
            end

            self.total = self.total + runtime
            self.count = self.count + 1
        end,
        -- Describes the measurements as text.
        -- @param self table  The profiler.
        -- @param full boolean|nil  True to include the children.
        -- @return string|nil  The summary; nil when nothing was measured and nothing was unavailable.
        report = function(self, full)
            if self.count == 0 then
                if self.unavailable > 0 then
                    return string.format('0 measured runs; %d unavailable', self.unavailable)
                end

                return
            end

            local rv = string.format(
                '%d runs (inclusive): total=%.3f ms, min=%.3f ms, avg=%.3f ms, max=%.3f ms',
                self.count,
                self.total * 1000,
                self.min * 1000,
                (self.total / self.count) * 1000,
                self.max * 1000
            )

            if self.unavailable > 0 then
                rv = rv .. string.format('; %d unavailable', self.unavailable)
            end

            if full then
                local parts = {}

                for name, child in pairs(self.children) do
                    local summary = child:report(full)

                    if summary then
                        parts[#parts + 1] = name .. '[' .. summary .. ']'
                    end
                end

                if #parts > 0 then
                    rv = rv .. ' { ' .. table.concat(parts, ', ') .. ' }; child scopes overlap and are not additive'
                end
            end

            return rv
        end,
        -- Clears every measurement and drops the children.
        reset = function(self)
            self.total = 0.0
            self.count = 0
            self.min = 0.0
            self.max = 0.0
            self.unavailable = 0
            self.startTime = 0.0
            self._started, self._clockValid = false, false
            self.children = {}
        end,
        -- Finds or creates a named child profiler.
        -- @param name string  The child's name.
        -- @return table  The child profiler.
        child = function(self, name)
            if self.children[name] == nil then
                self.children[name] = Constructor()
            end

            return self.children[name]
        end,
    }

    return rv
end

-- Public factory for a profiler object; see Constructor.
-- @param enabled boolean|nil  False for an inert profiler; anything else measures.
-- @return table  The profiler.
--
-- It may be replaced by another addon or a test, which is why build() below checks that it is still the original
-- before claiming ownership of a root.
function addon:ProfiledCode(enabled)
    return Constructor(enabled)
end

-- Main owns only roots built from this literal factory. Public nil remains FULL.
local ownedFactory = addon.ProfiledCode
local ownedRoot, ownedMode, ownedMethods, consumed
local refreshVersion = 0
local methods = { 'start', 'stop', 'child', 'report', 'reset' }

-- Whether evaluation timing is worth collecting.
-- @param owner table  The addon (its db profile is read).
-- @return boolean  True when the profile's log level is 3 or higher.
local function collecting(owner)
    local level = owner.db and owner.db.profile and owner.db.profile.loglevel
    return type(level) == 'number' and level >= 3
end

-- Whether the owner's current evaluationProfile is still the root this file built.
-- @param owner table  The addon.
-- @return boolean  True when none of its methods has been swapped out.
local function unmodified(owner)
    if owner.evaluationProfile ~= ownedRoot or not ownedRoot or owner.ProfiledCode ~= ownedFactory then
        return false
    end

    for _, name in ipairs(methods) do
        if ownedRoot[name] ~= ownedMethods[name] then
            return false
        end
    end

    return true
end

-- Installs a fresh root profiler on owner.evaluationProfile.
-- @param owner table  The addon.
-- @param mode boolean  True to measure; false for an inert profiler.
-- @param initial boolean  True for the first installation.
-- @return boolean  True if it installed one.
--
-- On a refresh (initial false) it backs off when someone replaced the root or its methods or the mode did not change;
-- it also backs off if the factory call itself changed the owner's state.
local function build(owner, mode, initial)
    refreshVersion = refreshVersion + 1
    local version = refreshVersion
    local before, db = owner.evaluationProfile, owner.db
    local profile = db and db.profile
    local factory = owner.ProfiledCode

    if not initial and (not unmodified(owner) or mode == ownedMode) then
        return false
    end

    if initial and factory ~= ownedFactory then
        -- Exact predecessor initialization for a foreign factory, including its
        -- nil argument, callouts and returned root. Never claim ownership.
        owner.evaluationProfile = factory(owner)
        return true
    end

    local root = factory(owner, mode)

    if
        refreshVersion ~= version
        or owner.evaluationProfile ~= before
        or owner.db ~= db
        or db.profile ~= profile
        or owner.ProfiledCode ~= factory
        or collecting(owner) ~= mode
    then
        return false
    end

    owner.evaluationProfile = root

    if factory == ownedFactory then
        ownedRoot, ownedMode, ownedMethods = root, mode, {}

        for _, name in ipairs(methods) do
            ownedMethods[name] = root[name]
        end
    end

    owner.lastCacheReport = GetTime()
    return true
end

-- Swaps the root profiler when the log level crossed the collecting threshold.
-- @return boolean  True if it replaced the root.
--
-- Called from the periodic report in main.lua.
function addon:RefreshEvaluationProfilerPolicy()
    if self ~= addon then
        return false
    end

    return build(self, collecting(self), false)
end

-- One-shot hand-off to main.lua of the evaluation profiler policy.
-- @return function|nil  An initializer for the first root profiler; nothing on a second call.
-- @return function|nil  A report gate for the periodic report: true means report and reset, false means skip this
--   period.
function addon:ConsumeLegacyEvaluationProfilerPolicy()
    if self ~= addon or consumed then
        return
    end

    consumed = true

    return function(owner)
        if owner == addon then
            return build(owner, collecting(owner), true)
        end
    end,
        function(owner)
            -- Foreign report/reset callbacks retain predecessor dispatch.
            if
                not ownedRoot
                or owner.evaluationProfile ~= ownedRoot
                or owner.ProfiledCode ~= ownedFactory
                or ownedRoot.report ~= ownedMethods.report
                or ownedRoot.reset ~= ownedMethods.reset
            then
                return true
            end

            return collecting(owner) and ownedMode
        end
end
