-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Runtime half of the lean evaluation engine's compiled plan: it decides, once per poll, whether main.lua may run the
-- active rotation from a cached plan prepared by Core/rotation_scope.lua, and hands back the leases that prove the plan
-- is still current while it runs. It owns the cached plan, its execution generation and the route counters; it must
-- never build or edit rotation data itself and must fall back to the standard engine (return nil) whenever any proof is
-- missing. Loaded from RotationMaster.toc after Core/rotation_selection.lua. It captures its inputs through cold,
-- one-time binders (execution generation, scoped plan source, announcement dispatcher, presentation source from
-- buttons.lua) and deletes the public binder names afterwards, so later code cannot swap them; main.lua takes
-- acquire/register via addon:ConsumeActiveRuntimePlan once at load.

local _, addon = ...
local readExecutionGeneration
---@type fun(...): any
local bindExecutionGeneration = addon.BindRotationExecutionGeneration

if type(bindExecutionGeneration) == 'function' then
    bindExecutionGeneration(addon, function(read)
        readExecutionGeneration = read
    end)
end

local kind, raw, identity = type, rawget, rawequal
local sourcePairs, sourceIpairs = pairs, ipairs
---@type fun(f: number|function): table
local environment = getfenv
local source, readActive, dispatch, dispatchEnvironment
---@type fun(...): any
local bind = addon.BindScopedActiveRuntimePlan

if kind(bind) == 'function' then
    bind(addon, function(value, read)
        source, readActive = value, read
    end)

    addon.BindScopedActiveRuntimePlan = nil
end

---@type fun(...): any, any
local consume = addon.ConsumeAnnouncementRuntimeSource

if kind(consume) == 'function' then
    dispatch, dispatchEnvironment = consume(addon)
    addon.ConsumeAnnouncementRuntimeSource = nil
end

local glowCooldown, presentationEnvironment

-- Captures the presentation method (GlowCooldown) and its environment, once.
-- @param method function  The original GlowCooldown method.
-- @param env table  The environment GlowCooldown was defined in.
--
-- buttons.lua consumes this receiver before its library callbacks, then sends the literal method immediately after
-- definition. Never recapture a live field. Ignored when not called on the addon or when already captured.
function addon:BindActiveRuntimePresentationSource(method, env)
    if self ~= addon or glowCooldown ~= nil or kind(method) ~= 'function' or kind(env) ~= 'table' then
        return
    end

    glowCooldown, presentationEnvironment = method, env
end

-- ============================================================================
-- Consumer identity and registration
-- ============================================================================

local spellIDs, sequence, mainEnvironment, registered
local request, plan, planGeneration
local plansBuilt, reused, declined, currentRoute = 0, 0, 0, 'idle'

-- Reports whether every function this plan depends on is still the original.
-- @param owner table  The addon.
-- @return boolean  True only while every function this plan depends on (glow, spell-id lookup, sequence evaluator,
--   announcement dispatch) is still the exact original value with its original environment. Any swapped function means
--   the plan is not trusted.
local function consumers(owner)
    return registered
        and identity(owner, addon)
        and kind(environment) == 'function'
        and kind(dispatch) == 'function'
        and kind(dispatchEnvironment) == 'table'
        and kind(glowCooldown) == 'function'
        and identity(raw(owner, 'GlowCooldown'), glowCooldown)
        and identity(environment(glowCooldown), presentationEnvironment)
        and identity(raw(owner, 'GetSpellIds'), spellIDs)
        and identity(raw(owner, 'EvaluateRotationSequence'), sequence)
        and identity(raw(owner, 'DispatchAnnouncement'), dispatch)
        and identity(environment(spellIDs), mainEnvironment)
        and identity(environment(sequence), mainEnvironment)
        and identity(environment(dispatch), dispatchEnvironment)
end

-- Registers main.lua's spell-id lookup, sequence evaluator and function environment as consumers of plans.
-- @param owner table  The addon.
-- @param ids function  The spell-id lookup (GetSpellIds).
-- @param run function  The sequence evaluator (EvaluateRotationSequence).
-- @param env table  The function environment main.lua's functions run in.
-- @return boolean|nil  True on the first valid registration, nothing afterwards.
--
-- Called once by main.lua.
local function register(owner, ids, run, env)
    if registered or owner ~= addon or kind(ids) ~= 'function' or kind(run) ~= 'function' or kind(env) ~= 'table' then
        return
    end

    spellIDs, sequence, mainEnvironment, registered = ids, run, env, true
    return true
end

-- Publication guard handed out for a request that was superseded.
-- @return boolean  Always false, so stale work publishes nothing.
local function retired()
    return false
end

-- ============================================================================
-- Acquiring a plan
-- ============================================================================

-- Decides whether the active rotation may run from a cached plan and hands back the leases that prove it stays current.
-- @param owner table  The addon.
-- @param spec number  The specialization ID or talent group of the selected rotation.
-- @param key string  The selected rotation id.
-- @return table|nil  The rotation body when the plan manages the poll and the rotation is allowed now; nil when the
--   standard engine must run, or when the rotation is not allowed now.
-- @return function|nil  current(), the full guard; the `retired` guard when the request was superseded.
-- @return any  The plan's token.
-- @return boolean  True when the plan manages the poll (the `handled` flag); false when the standard engine must run.
-- @return any  The plan's presentation.
-- @return function|nil  conditionCurrent(), the lease for condition evaluation.
-- @return function|nil  notifiedCurrent(), the lease that checks only the managed execution clock.
-- @return function|nil  deliveryCurrent(), the lease for publishing the result to the glow.
-- @return function|nil  dispatchCurrent(receiver), the lease asked by each receiver before it runs.
--
-- Called by main.lua each poll. Returns `nil, nil, nil, false` when the standard engine must run. With handled=true and
-- a nil body, the guard (`retired`) says the request was superseded.
local function acquire(owner, spec, key)
    if owner ~= addon then
        return nil, nil, nil, false
    end

    if not identity(raw(owner, 'currentSpec'), spec) or not identity(raw(owner, 'currentRotation'), key) then
        declined = declined + 1
        currentRoute = 'retired'
        return nil, retired, nil, true
    end

    local db = raw(owner, 'db')
    local profile = kind(db) == 'table' and raw(db, 'profile')
    local ticket = {}
    request = ticket
    local handle, revision, operation

    if kind(readActive) == 'function' then
        handle, revision, operation = readActive(owner, spec, key)
    end

    -- Reports whether this request is still the newest one.
    -- @return boolean  True when no newer acquire replaced `request` and the active handle, revision and operation are
    --   unchanged since the plan was read.
    --
    -- A newer acquire replaces `request`, which retires this one.
    local function requestCurrent()
        if not identity(request, ticket) then
            return false
        end
        if not handle then
            return true
        end

        local nextHandle, nextRevision, nextOperation = readActive(owner, spec, key)
        return identity(nextHandle, handle) and nextRevision == revision and identity(nextOperation, operation)
    end

    if not consumers(owner) or kind(source) ~= 'function' then
        plan = nil
        planGeneration = nil
        declined = declined + 1
        currentRoute = 'fallback'
        return nil, nil, nil, false
    end

    local built = false

    -- A completed entry proof qualifies only this exact cached plan at this
    -- notification generation. Fresh context/eligibility still ends in a full
    -- proof below, so raw root changes cannot return an old private body.
    local authoritative = plan
        and (planGeneration ~= nil and planGeneration == readExecutionGeneration() or plan.authority())

    if not requestCurrent() then
        declined = declined + 1
        currentRoute = 'retired'
        return nil, retired, nil, true
    end

    if not authoritative then
        local prepared = source(owner, spec, key)

        if prepared then
            plansBuilt = plansBuilt + 1
            built = true
        end

        if not requestCurrent() then
            declined = declined + 1
            currentRoute = 'retired'
            return nil, retired, nil, true
        end

        plan = prepared
        planGeneration = nil
    end

    if not plan or not consumers(owner) then
        plan = nil
        planGeneration = nil
        declined = declined + 1
        currentRoute = 'fallback'
        return nil, nil, nil, false
    end

    -- entry's final source-owned proof covers context and eligibility work.
    -- Capture before those callbacks: never refresh an older request to a
    -- generation published by reentrant work during preparation.
    local executionGeneration = readExecutionGeneration and readExecutionGeneration()
    local selected = plan
    local state = selected.entry()

    if not requestCurrent() or executionGeneration == nil or readExecutionGeneration() ~= executionGeneration then
        declined = declined + 1
        currentRoute = 'retired'
        return nil, retired, nil, true
    end

    if not state then
        plan = nil
        planGeneration = nil
        declined = declined + 1
        currentRoute = 'fallback'
        return nil, nil, nil, false
    end

    -- Publish before late consumer source getters: a notification during those
    -- callouts must never bless an old plan with a newer generation.
    planGeneration = executionGeneration

    -- Cheap scalar proof that this acquisition still owns the poll.
    -- @return boolean  True while the ticket, plan, generation, database, profile, spec and rotation are the same.
    local function continuationCurrent()
        return request == ticket
            and plan == selected
            and readExecutionGeneration() == executionGeneration
            and raw(owner, 'db') == db
            and kind(db) == 'table'
            and raw(db, 'profile') == profile
            and identity(raw(owner, 'currentSpec'), spec)
            and identity(raw(owner, 'currentRotation'), key)
    end

    -- Full guard returned to main.lua.
    -- @return boolean  True while the scalar proof holds, the consumers' identity is intact and the scope's own proof
    --   says the active handle, revision and operation are the ones read at acquire time.
    local function current()
        if not continuationCurrent() or not consumers(owner) or not continuationCurrent() then
            return false
        end

        -- Scope's full proof ends with one callback-free active snapshot. Use
        -- it for both request and scope authority, then reject late reentry.
        local valid, activeHandle, activeRevision, activeOperation = selected.current(state)

        return continuationCurrent()
            and valid
            and identity(activeHandle, handle)
            and activeRevision == revision
            and identity(activeOperation, operation)
    end

    if not identity(plan, selected) or not consumers(owner) then
        declined = declined + 1
        currentRoute = 'retired'
        return nil, current, nil, true
    end

    if not built then
        reused = reused + 1
    end

    currentRoute = state.allowed and 'managed' or 'unavailable'

    -- Lease for condition evaluation.
    -- @return boolean  True while the request and plan are still ours and the plan's own condition proof still holds.
    local function conditionCurrent()
        return identity(request, ticket)
            and identity(plan, selected)
            and consumers(owner)
            and selected.conditionCurrent(state)
    end

    -- Lease that checks only the managed execution clock.
    -- @return boolean  True while no change was notified since acquire.
    local function notifiedCurrent()
        return executionGeneration ~= nil
            and request == ticket
            and plan == selected
            and readExecutionGeneration() == executionGeneration
    end

    -- Lease for publishing the result to the glow.
    -- @return boolean  True while ownership holds and the presentation method is still the original.
    local function deliveryCurrent()
        -- Completed scalar/detached output follows the managed mutation clock.
        -- Raw profile/spec/selection remain immediate ownership boundaries;
        -- unnotified table edits are re-proved by the next full acquisition.
        if not continuationCurrent() then
            return false
        end
        if
            not identity(raw(owner, 'GlowCooldown'), glowCooldown)
            or not identity(environment(glowCooldown), presentationEnvironment)
        then
            return false
        end

        return continuationCurrent() and identity(raw(owner, 'GlowCooldown'), glowCooldown)
    end

    -- Once any ownership check fails the whole dispatch stays failed for this acquisition, so a later receiver cannot
    -- continue after a partial run.
    local dispatchFailed = false

    -- Lease asked by each receiver before it runs.
    -- @param receiver string  'condition', 'resume', 'step', 'sequence', 'iterator' or 'pathcopy'.
    -- @return boolean  True when the functions that receiver uses and the globals they read are unchanged. After one
    --   failure it answers false.
    local function dispatchCurrent(receiver)
        if dispatchFailed then
            return false
        end

        -- These scalar ownership checks have no source lookup or callout.
        -- The graph retains its actual provider certificates at private handoff.
        if receiver == 'condition' or receiver == 'resume' then
            local valid = continuationCurrent()

            if not valid then
                dispatchFailed = true
            end

            return valid
        end

        if not continuationCurrent() then
            dispatchFailed = true
            return false
        end

        local valid = true

        if receiver == 'step' then
            valid = identity(raw(owner, 'GetSpellIds'), spellIDs)
                and identity(environment(spellIDs), mainEnvironment)
                and identity(raw(owner, 'GetSpellIds'), spellIDs)
                and identity(raw(mainEnvironment, 'type'), kind)
                and identity(raw(mainEnvironment, 'ipairs'), sourceIpairs)
        elseif receiver == 'sequence' or receiver == 'iterator' or receiver == 'pathcopy' then
            valid = identity(raw(owner, 'EvaluateRotationSequence'), sequence)
                and identity(environment(sequence), mainEnvironment)
                and identity(raw(owner, 'EvaluateRotationSequence'), sequence)
                and identity(raw(mainEnvironment, 'type'), kind)
                and identity(raw(mainEnvironment, 'ipairs'), sourceIpairs)
                and (receiver ~= 'iterator' or identity(raw(mainEnvironment, 'pairs'), sourcePairs))
        end

        valid = valid and selected.executionSource(receiver) and continuationCurrent()

        if not valid then
            dispatchFailed = true
        end

        return valid
    end

    return state.allowed and selected.body or nil,
        current,
        selected.token,
        true,
        selected.presentation,
        conditionCurrent,
        notifiedCurrent,
        deliveryCurrent,
        dispatchCurrent
end

-- ============================================================================
-- Public surface
-- ============================================================================

-- One-time handoff to main.lua, which keeps `acquire` and `register` locally and clears this public name.
-- @return function|nil  `acquire`; nil for any other caller.
-- @return function|nil  `register`.
function addon:ConsumeActiveRuntimePlan()
    if self ~= addon then
        return
    end

    return acquire, register
end

-- Returns the plan route counters for a diagnostic capture.
-- @return table|nil  { plansBuilt, reused, declined, currentRoute }; nil unless called on the addon.
--
-- Scalar snapshots only; collection does not prepare or inspect a plan.
function addon:GetActiveRuntimePlanDiagnostic()
    if self ~= addon then
        return
    end

    return { plansBuilt = plansBuilt, reused = reused, declined = declined, currentRoute = currentRoute }
end
