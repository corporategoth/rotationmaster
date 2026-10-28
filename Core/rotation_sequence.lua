-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Sequence executor: walks a rotation body's steps in order (actions, Branches, Stops), asks the caller's `evaluate`
-- callback about each step's conditions, and reports which action step to visit, whether a Stop ended the walk, or
-- that the walk was unavailable. It owns control flow only: observation policy, action availability and optional
-- upkeep stay with the caller (main.lua). The second half of the file is a one-time private handoff to main.lua
-- (addon.BindRotationSequenceReader) that adds the managed-caller path and the execution-index cache, and checks that
-- the public function and its environment were not swapped. Loaded from the Core rotation group of RotationMaster.toc,
-- after Data/rotation_tree.lua, which supplies the step index. Reads no game API.
local _, addon = ...
local data = addon.RotationData

-- ============================================================================
-- Step walker
-- ============================================================================

-- Builds the walk's result for a body that cannot be walked.
-- @param diagnostic table|nil  The validation issue that explains why.
-- @return table  { status = "unavailable", suppressAttack = true, diagnostic }, so a broken body never lets a
--   lower-priority action fire.
local function unavailable(diagnostic)
    return { status = "unavailable", suppressAttack = true, diagnostic = diagnostic }
end

-- Copies a path produced by the private execution index.
-- @param path (string|number)[]  The dense scalar path of a managed row.
-- @return (string|number)[]  A fresh plain array.
--
-- Managed rows own dense scalar paths produced by the private execution index. Give each receiver a fresh plain array
-- without revalidating portable data.
local function managedPath(path)
    local result = {}

    for i = 1, #path do
        result[i] = path[i]
    end

    return result
end

-- Walks `body.rotation` depth-first.
-- @param body table  The rotation body.
-- @param evaluate function  evaluate(conditions, context) returns an observation about a step's conditions.
-- @param visit function  visit(step, ordinal, path) returns false to select the step.
-- @param rows table  Maps each step to its index row.
-- @param ordinal number  The row count.
-- @param kind function  Stands in for type(), so the managed path can use the captured original.
-- @param each function  Stands in for ipairs(), so the managed path can use the captured original.
-- @param managed function|nil  Asked before each path copy, iteration and resume whether the managed caller still owns
--   the call; the walk ends as unavailable if not.
-- @return table  { status, suppressAttack, fallbackOrdinal }. Status is 'complete' (no action chosen), 'selected'
--   (`visit` returned false for a step), 'stopped' (a Stop matched) or 'unavailable' (a Branch or Stop condition was
--   unavailable).
--
-- A Branch whose mode is "true" or "false" is decided without calling `evaluate`. Callbacks receive path copies, so
-- nothing they do can alter the index.
local function execute(body, evaluate, visit, rows, ordinal, kind, each, managed)
    local result = { status = "complete", suppressAttack = false, fallbackOrdinal = ordinal + 1 }

    -- Reports whether the managed caller still owns this walk; otherwise marks the result unavailable.
    -- @param receiver string  The kind of receiver about to run ('pathcopy', 'resume', 'iterator').
    -- @return boolean  True while it does.
    local function permitted(receiver)
        if managed(receiver) then
            return true
        end

        result.status = "unavailable"
        result.suppressAttack = true
        return false
    end

    -- Evaluates one step's conditions.
    -- @param step table  The step.
    -- @param row table  The step's index row.
    -- @return string  'match', 'no-match' or 'unavailable' (any malformed observation).
    local function check(step, row)
        local observation

        if managed then
            if not permitted('pathcopy') then
                return "unavailable"
            end

            local conditions, stepId = step.conditions, step.id
            local path = managedPath(row.path)
            observation = evaluate(conditions, { stepId = stepId, stepPath = path })

            if not permitted('resume') then
                return "unavailable"
            end
        else
            observation = evaluate(step.conditions, { stepId = step.id, stepPath = data.CopyData(row.path) })
        end

        if kind(observation) ~= "table" then
            return "unavailable"
        end
        if observation.status == "match" or observation.status == "no-match" then
            return observation.status
        end

        return "unavailable"
    end

    local walk

    -- Visits a step list in order and recurses into the chosen Branch arm.
    -- @param list table  The step list.
    -- @return boolean  False when the walk has ended (a selection, a Stop or an unavailable result, recorded in
    --   `result`); true to continue with the next sibling.
    walk = function(list)
        if managed and not permitted('iterator') then
            return false
        end

        for _, step in each(list) do
            local row = rows[step]

            if step.type == "branch" then
                local mode = step.mode or "evaluate"
                local status = mode == "true" and "match" or mode == "false" and "no-match" or check(step, row)

                if status == "unavailable" then
                    result.status = "unavailable"
                    result.suppressAttack = true
                    return false
                end

                if not walk(status == "match" and step.onTrue or step.onFalse) then
                    return false
                end
            elseif not step.disabled then
                if step.type == "stop" then
                    local status = check(step, row)

                    if status ~= "no-match" then
                        result.status = status == "unavailable" and "unavailable" or "stopped"
                        result.suppressAttack = status == "unavailable" or step.suppress_attack == true
                        return false
                    end
                elseif not managed then
                    if visit(step, row.ordinal, data.CopyData(row.path)) == false then
                        result.status = "selected"
                        return false
                    end
                else
                    if not permitted('pathcopy') then
                        return false
                    end

                    local position = row.ordinal
                    local path = managedPath(row.path)
                    local keepGoing = visit(step, position, path)

                    if keepGoing == false then
                        result.status = "selected"
                        return false
                    end
                end
            end
        end

        return true
    end

    walk(body.rotation or {})
    return result
end

-- ============================================================================
-- Public entry
-- ============================================================================

-- Walks a rotation body's steps in order and reports which action step to visit.
-- @param body table  The rotation body.
-- @param evaluate function  evaluate(step.conditions, context) returns an observation table with status 'match' or
--   'no-match'.
-- @param visit function  visit(step, ordinal, path) returns false to select the step.
-- @return table  The execute() result { status, suppressAttack, fallbackOrdinal }; status 'unavailable' when the body
--   or the callbacks are invalid.
--
-- The caller owns observation policy and action availability. This executor owns ordered control flow, and deliberately
-- leaves optional upkeep alone. Indexes `body` afresh on every call.
function addon:EvaluateRotationSequence(body, evaluate, visit)
    local index, why = data.IndexRotationSteps(body, { allowMissingIds = true })

    if not index then
        return unavailable(why)
    end
    if type(evaluate) ~= "function" or type(visit) ~= "function" then
        return unavailable({ code = "invalid-sequence-callback", path = "$", severity = "error" })
    end

    local rows, ordinal = {}, 0

    for _, row in ipairs(index.rows) do
        if row.section == "rotation" then
            rows[row.step] = row
            ordinal = ordinal + 1
        end
    end

    -- Plain type(), used by the public path; the managed path substitutes captured copies.
    -- @param value any  The value.
    -- @return string  Its type name.
    local function kind(value)
        return type(value)
    end

    -- Plain ipairs(), used by the public path; the managed path substitutes captured copies.
    -- @param list table  The list.
    -- @return function  The ipairs iterator, state and control values.
    local function each(list)
        return ipairs(list)
    end

    return execute(body, evaluate, visit, rows, ordinal, kind, each)
end

-- ============================================================================
-- Private handoff to main.lua
-- ============================================================================

-- Only main receives this reader. Public sequence calls always index afresh.
local sequenceType, sequenceRawget, sequenceEqual = type, rawget, rawequal
local sequenceIpairs = ipairs
---@type fun(f: number|function): table
local sequenceGetfenv = getfenv
local sequenceEnvironment = sequenceType(sequenceGetfenv) == "function" and sequenceGetfenv(1) or nil
local ownedSequence = addon.EvaluateRotationSequence
local readIndex, retireIndex, indexStatus
local bindIndex = addon.BindRotationExecutionIndexReader

if sequenceType(bindIndex) == "function" then
    ---@cast bindIndex function
    bindIndex(addon, function(read, retire, status)
        readIndex, retireIndex, indexStatus = read, retire, status
    end)

    addon.BindRotationExecutionIndexReader = nil
end

-- Reports whether the owner, the public method, the environment and the captured globals are still the ones this file
-- was loaded with.
-- @param owner table  The addon, as main.lua sees it.
-- @return table  The index reader's status with `sequence = { reason, raw }` merged in; reason is 'ready' or the first
--   failed check.
--
-- Diagnostic only. Source-owned status carries no body, cache, method, or profile references.
local function sequenceStatus(owner)
    local result = { reason = "ready", raw = {} }

    -- Records the first failed check as the status reason; later failures do not overwrite it.
    -- @param reason string  The reason to record on failure.
    -- @param ok any  Truthy when the check passed.
    local function check(reason, ok)
        if result.reason == "ready" and not ok then
            result.reason = reason
        end
    end

    local ownerTable = sequenceType(owner) == "table"
    local db = ownerTable and sequenceRawget(owner, "db") or nil
    local profile = sequenceType(db) == "table" and sequenceRawget(db, "profile") or nil
    local environment = sequenceType(sequenceEnvironment) == "table"
    local capability = sequenceType(sequenceGetfenv) == "function"
    check("owner", sequenceEqual(owner, addon))
    check("method", ownerTable and sequenceEqual(sequenceRawget(owner, "EvaluateRotationSequence"), ownedSequence))
    check("namespace", ownerTable and sequenceEqual(sequenceRawget(owner, "RotationData"), data))
    check("db", sequenceType(db) == "table")
    check("profile", sequenceType(profile) == "table")
    check("index-reader", sequenceType(readIndex) == "function")
    check("capability", capability)
    check("env", environment)
    check("public-env", capability and sequenceEqual(sequenceGetfenv(ownedSequence), sequenceEnvironment))
    local keys = { "type", "ipairs", "getfenv" }
    local pointers = { sequenceType, sequenceIpairs, sequenceGetfenv }

    for i = 1, 3 do
        local key = keys[i]
        local ok = environment and sequenceEqual(sequenceRawget(sequenceEnvironment, key), pointers[i]) or false
        result.raw[key] = ok
        check("raw-" .. key, ok)
    end

    local status = indexStatus and indexStatus(data) or {
        portable = { reason = "unbound" },
        index = { reason = "unbound" },
    }

    status.sequence = result
    return status
end

-- Hands main.lua the raw-method reader, the guarded run function, the status function and the original
-- EvaluateRotationSequence.
-- @param bind function  bind(rawMethod, run, status, original) receives them; anything else does nothing.
--
-- One-time handoff to main.lua, which calls it at load and then removes the name. Does nothing for any caller other
-- than the addon.
function addon:BindRotationSequenceReader(bind)
    if self ~= addon or sequenceType(bind) ~= "function" then
        return
    end

    -- Reads the owner's EvaluateRotationSequence without metamethods, so main.lua can detect a replaced method.
    -- @param owner any  The addon, as main.lua sees it.
    -- @return function|nil  The method; nil when the owner is not a table or has none.
    local function rawMethod(owner)
        return sequenceType(owner) == "table" and sequenceRawget(owner, "EvaluateRotationSequence") or nil
    end

    -- Only the admitted managed caller owns immutable execution bodies. Keep
    -- one private map; ordinary mutable callers retain the live index reader.
    local managedEntry

    -- Runs a sequence with ownership checks.
    -- @param owner table  The addon, as main.lua sees it.
    -- @param before function  The owner's EvaluateRotationSequence as read before the call.
    -- @param method function  The owner's EvaluateRotationSequence as read at the call.
    -- @param body table  The rotation body.
    -- @param evaluate function  evaluate(conditions, context) returns an observation.
    -- @param visit function  visit(step, ordinal, path) returns false to select the step.
    -- @param managed function|nil  The managed caller's ownership check; nil for an ordinary caller.
    -- @return table  The execute() result.
    --
    -- When the owner, method, namespace, profile or captured globals are not the original ones, the cached index is
    -- retired and the call falls back to the public `method` (or, for a managed caller, is unavailable). Otherwise rows
    -- come from the cached map (managed only) or a fresh index read. Only the admitted managed caller owns immutable
    -- execution bodies; ordinary mutable callers retain the live index reader.
    local function run(owner, before, method, body, evaluate, visit, managed)
        if managed and not managed('sequence') then
            return unavailable({ code = "retired-managed-sequence" })
        end

        local db = sequenceType(owner) == "table" and sequenceRawget(owner, "db") or nil
        local profile = sequenceType(db) == "table" and sequenceRawget(db, "profile") or nil

        if not (sequenceEqual(owner, addon)
            and sequenceEqual(before, ownedSequence)
            and sequenceEqual(method, ownedSequence)
            and sequenceEqual(sequenceRawget(owner, "RotationData"), data)
            and sequenceType(profile) == "table"
            and readIndex
            and sequenceType(sequenceEnvironment) == "table"
            and sequenceEqual(sequenceGetfenv(ownedSequence), sequenceEnvironment)
            and sequenceEqual(sequenceRawget(sequenceEnvironment, "type"), sequenceType)
            and sequenceEqual(sequenceRawget(sequenceEnvironment, "ipairs"), sequenceIpairs)
            and sequenceEqual(sequenceRawget(sequenceEnvironment, "getfenv"), sequenceGetfenv)) then
            if retireIndex then
                retireIndex()
            end

            if managed then
                return unavailable({ code = "unowned-managed-sequence" })
            end

            return method(owner, body, evaluate, visit)
        end

        local cached = managed and managedEntry
        local rows, ordinal

        if cached and sequenceEqual(cached.body, body) and sequenceEqual(cached.db, db) and sequenceEqual(
            cached.profile,
            profile
        ) then
            if sequenceType(evaluate) ~= "function" or sequenceType(visit) ~= "function" then
                return unavailable({ code = "invalid-sequence-callback", path = "$", severity = "error" })
            end

            rows, ordinal = cached.rows, cached.ordinal
        else
            local eligible, index, why = readIndex(body, profile, data, db)

            if managed and not managed('resume') then
                return unavailable({ code = "retired-managed-sequence" })
            end

            if not eligible then
                if managed then
                    return unavailable({ code = "unowned-managed-index" })
                end

                return method(owner, body, evaluate, visit)
            end

            if not index then
                return unavailable(why)
            end

            -- Preserve the ordinary reader's callback validation before any
            -- row-map iteration, including its original error ordering.
            if sequenceType(evaluate) ~= "function" or sequenceType(visit) ~= "function" then
                return unavailable({ code = "invalid-sequence-callback", path = "$", severity = "error" })
            end

            rows, ordinal = {}, 0

            for _, row in sequenceIpairs(index.rows) do
                if row.section == "rotation" then
                    rows[row.step] = row
                    ordinal = ordinal + 1
                end
            end

            if managed then
                -- A failed older invocation must not erase or replace a map
                -- published by a nested, newer managed continuation.
                if not managed('resume') then
                    return unavailable({ code = "retired-managed-sequence" })
                end

                managedEntry = { body = body, db = db, profile = profile, rows = rows, ordinal = ordinal }
            end
        end

        -- Reads type() through the captured environment, which the ownership check above proved still holds the
        -- originals.
        -- @param value any  The value.
        -- @return string  Its type name.
        local function kind(value)
            return sequenceEnvironment.type(value)
        end

        -- Reads ipairs() through the captured environment, which the ownership check above proved still holds the
        -- originals.
        -- @param list table  The list.
        -- @return function  The ipairs iterator, state and control values.
        local function each(list)
            return sequenceEnvironment.ipairs(list)
        end

        return execute(body, evaluate, visit, rows, ordinal, kind, each, managed)
    end

    bind(rawMethod, run, sequenceStatus, ownedSequence)
end
