-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Owner of the active rotation: which rotation is selected for the current specialization, plus a detached private copy
-- of its body that the evaluation engines read. A selection change is a transition: Begin hands out a token and every
-- later step proves the token, profile, specialization and rotation are unchanged, so a nested or superseded change
-- ends as 'rotation-transition-superseded' instead of a half-applied selection. It re-checks after every call that
-- could run foreign code, reads with raw access, and advances the execution generation (Core/dependency_revisions.lua)
-- on each change so earlier lean plans retire. Loaded from the Core rotation group of RotationMaster.toc; writers call
-- the public names or receive the private functions once through addon:BindActiveRotationPublication.
local _, addon = ...
local readExecutionGeneration, advanceExecutionGeneration
---@type fun(...): any
local bindExecutionGeneration = addon.BindRotationExecutionGeneration

if type(bindExecutionGeneration) == 'function' then
    bindExecutionGeneration(addon, function(read, advance)
        readExecutionGeneration, advanceExecutionGeneration = read, advance
    end)
end

-- Advances the shared execution generation, if the owner handed it over, so plans compiled earlier stop being reused.
local function invalidateExecution()
    if advanceExecutionGeneration then
        advanceExecutionGeneration()
    end
end

-- ============================================================================
-- Data helpers
-- ============================================================================

local kind, raw, write, identity, meta, iterate = type, rawget, rawset, rawequal, getmetatable, next
local infinity, protect = math.huge, pcall
local operation, active

-- Deep-copies plain data into a table nothing else references. Returns nil (not a partial copy) for a metatable, a
-- cycle, a non-finite number, a function or userdata, a key that is not a string or positive integer, more than 20000
-- nodes or more than 64 levels. Reads with rawget and next so no metamethod runs.
local function detached(value)
    local seen, stack, nodes = {}, {}, 0

    local function copy(v, depth)
        nodes = nodes + 1

        if nodes > 20000 or depth > 64 then
            return nil
        end

        local t = kind(v)

        if t ~= 'table' then
            if t == 'string' or t == 'boolean' or t == 'nil' then
                return v
            end
            if t == 'number' and v == v and v ~= infinity and v ~= -infinity then
                return v
            end

            return nil
        end

        if meta(v) ~= nil or stack[v] then
            return nil
        end
        if seen[v] then
            return seen[v]
        end

        local result = {}
        seen[v] = result
        stack[v] = true

        for key in iterate, v do
            nodes = nodes + 1
            local tKey = kind(key)

            if nodes > 20000 or not (tKey == 'string' or tKey == 'number' and key >= 1 and key % 1 == 0) then
                return nil
            end

            local child = copy(raw(v, key), depth + 1)

            if child == nil then
                return nil
            end

            result[key] = child
        end

        stack[v] = nil
        return result
    end

    return copy(value, 0)
end

-- Structural equality for plain data; false for any table with a metatable. Raw reads only.
local function equal(a, b)
    if kind(a) ~= kind(b) then
        return false
    end
    if kind(a) ~= 'table' then
        return a == b
    end
    if meta(a) ~= nil or meta(b) ~= nil then
        return false
    end

    for key, value in iterate, a do
        if not equal(value, raw(b, key)) then
            return false
        end
    end

    for key in iterate, b do
        if raw(a, key) == nil then
            return false
        end
    end

    return true
end

-- ============================================================================
-- Transition tokens
-- ============================================================================

-- True when `self` is the real addon table (the only owner these functions accept).
local function owned(self)
    return identity(self, addon)
end

-- True while `token` belongs to the pending transition and the profile, specialization and current rotation still match
-- what it recorded. Cheap enough to call after every step that might have run foreign code.
local function current(self, token)
    if not owned(self) then
        return false
    end

    local pending = operation

    if not pending or not identity(pending.token, token) then
        return false
    end

    local db = self.db
    local profile = db and db.profile
    local spec, id = self.currentSpec, self.currentRotation

    return identity(operation, pending)
        and identity(profile, pending.profile)
        and identity(spec, pending.spec)
        and identity(id, pending.id)
end

-- Starts a transition, replacing any pending one (which then fails its checks), and records the profile,
-- specialization and rotation it began with. Returns its token, or nil and a reason.
local function begin(self)
    if not owned(self) then
        return nil, 'foreign-rotation-owner'
    end

    local pending = { token = {} }
    operation = pending
    invalidateExecution()
    local db = self.db
    pending.profile = db and db.profile
    pending.spec, pending.id = self.currentSpec, self.currentRotation

    if not identity(operation, pending) then
        return nil, 'rotation-transition-superseded'
    end

    return pending.token
end

-- Public entry for begin(); returns a transition token, or nil and a reason.
function addon:BeginActiveRotationTransition()
    return begin(self)
end

-- True while `token` is still the pending transition and nothing it recorded has changed.
function addon:IsActiveRotationTransitionCurrent(token)
    return current(self, token)
end

-- Moves the transition to a new specialization and sets addon.currentSpec. Returns a fresh token that replaces the
-- old one and clears any recorded cleanup selection, or nil and 'rotation-transition-superseded'.
function addon:AdvanceActiveRotationSpecialization(token, spec)
    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end

    local pending = operation
    invalidateExecution()
    self.currentSpec = spec

    if not identity(operation, pending) then
        return nil, 'rotation-transition-superseded'
    end

    local db = self.db
    local profile = db and db.profile
    local actualSpec, id = self.currentSpec, self.currentRotation

    if
        not identity(operation, pending)
        or not identity(profile, pending.profile)
        or not identity(actualSpec, spec)
        or not identity(id, pending.id)
    then
        return nil, 'rotation-transition-superseded'
    end

    invalidateExecution()
    local nextToken = {}
    pending.token = nextToken
    pending.spec = spec
    pending.cleanupSpec, pending.cleanupID = nil, nil
    return nextToken
end

-- ============================================================================
-- Retire and commit
-- ============================================================================

-- Clears the active rotation within the transition. The previous specialization and id are kept as the cleanup
-- selection so the caller can release what that rotation held. Returns true, or nil and a reason.
local function retire(self, token)
    local pending = operation

    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end

    local spec, id = self.currentSpec, self.currentRotation

    if not identity(operation, pending) or not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end

    if id ~= nil then
        pending.cleanupSpec, pending.cleanupID = spec, id
    end

    invalidateExecution()
    active = nil
    write(self, 'currentRotation', nil)
    pending.id = nil
    return true
end

addon.RetireActiveRotationTransition = retire

-- Returns the specialization, rotation id and token of the selection a transition retired and has not yet cleaned up,
-- or nil when there is no current transition.
function addon:GetActiveRotationCleanupSelection()
    local pending = operation

    if not owned(self) or not pending or not current(self, pending.token) then
        return nil
    end

    return pending.cleanupSpec, pending.cleanupID, pending.token
end

-- Makes rotation `id` of `spec` the active one: reads its body (from `body`, or through GetRuntimeRotation), takes a
-- detached copy with its content revision and, with the scoped store, its reference, and publishes it. An unchanged
-- body keeps the previous handle so consumers do not see a new identity. Returns the handle, or nil and a reason such
-- as 'invalid-active-rotation' or 'rotation-unavailable'.
local function commit(self, token, spec, id, body)
    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end

    local pending = operation

    if
        kind(spec) ~= 'number' or spec < 0 or spec % 1 ~= 0 or spec ~= pending.spec or kind(id) ~= 'string' or id == ''
    then
        return nil, 'invalid-active-rotation'
    end

    if body == nil then
        local get = self.GetRuntimeRotation

        if not current(self, token) then
            return nil, 'rotation-transition-superseded'
        end

        body = get(self, spec, id)
    end

    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end

    local data = self.RotationData

    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end
    if kind(body) ~= 'table' or meta(body) ~= nil then
        return nil, 'rotation-unavailable'
    end

    local getRevision = data.GetRotationContentRevision

    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end

    local revision, why = getRevision(body)

    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end
    if not revision then
        return nil, why
    end

    local copy = data.CopyData

    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end

    local copied, problem = copy(body)

    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end
    if not copied then
        return nil, problem and problem.code or 'rotation-unavailable'
    end

    copied = detached(copied)

    if not copied then
        return nil, 'rotation-unavailable'
    end

    local available = self.GetScopedRotationCoordinator

    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end

    local coordinator

    if available then
        local get = self.GetScopedRotationCoordinator

        if not current(self, token) then
            return nil, 'rotation-transition-superseded'
        end

        coordinator = get(self)
    end

    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end

    local reference

    if coordinator then
        local resolve = coordinator.Resolve

        if not current(self, token) then
            return nil, 'rotation-transition-superseded'
        end

        reference, why = resolve(coordinator, spec, id)

        if not current(self, token) then
            return nil, 'rotation-transition-superseded'
        end
        if not reference then
            return nil, why
        end

        copy = data.CopyData

        if not current(self, token) then
            return nil, 'rotation-transition-superseded'
        end

        reference, problem = copy(reference)

        if not current(self, token) then
            return nil, 'rotation-transition-superseded'
        end
        if not reference then
            return nil, problem and problem.code or 'rotation-unavailable'
        end

        reference = detached(reference)

        if not reference then
            return nil, 'rotation-unavailable'
        end
    end

    local unchanged = active
        and identity(active.profile, pending.profile)
        and active.spec == spec
        and active.id == id
        and equal(active.reference, reference)
        and equal(active.body, copied)

    if not current(self, token) then
        return nil, 'rotation-transition-superseded'
    end

    local handle = unchanged and active.token or {}
    invalidateExecution()

    active = {
        token = handle,
        profile = pending.profile,
        spec = spec,
        id = id,
        reference = reference,
        body = copied,
        revision = revision,
    }

    pending.cleanupSpec, pending.cleanupID = nil, nil
    write(self, 'currentRotation', id)
    pending.id = id
    return handle
end

addon.CommitActiveRotationTransition = commit

-- Re-commits the current rotation after its content changed, following a rename from `previousKey` to `nextKey`. A
-- failed commit retires the rotation rather than leaving a stale body selected. Returns the handle, or nil and a
-- reason.
function addon:RefreshActiveRotation(spec, previousKey, nextKey)
    if not owned(self) then
        return nil, 'foreign-rotation-owner'
    end
    if spec ~= self.currentSpec or self.currentRotation == nil then
        return true
    end

    local token, why = begin(self)

    if not token then
        return nil, why
    end

    local id = self.currentRotation

    if previousKey and id == previousKey then
        id = nextKey or id
    end

    local handle, problem = commit(self, token, spec, id)

    if not handle and current(self, token) then
        retire(self, token)
    end

    return handle, problem
end

-- ============================================================================
-- Publication and rebind handoff
-- ============================================================================

-- Trusted module handoff: writers prepare before their final authority checks;
-- the owned completion has no extension/native/copy/iterator callouts.
-- Step one of a writer that changes a rotation's saved content. Decides whether the written rotation is the selected
-- one and, if so, prepares a detached copy of its new body and reference. Returns a ticket for finishPublication,
-- or nil when the write must not proceed. All copying happens here, so finishPublication can stay callout-free.
local function preparePublication(spec, previousKey, previousReference, nextReference, body, original, fallbackKey)
    if not identity(spec, raw(addon, 'currentSpec')) or raw(addon, 'currentRotation') == nil then
        return nil
    end

    local token = begin(addon)

    if not current(addon, token) then
        return nil
    end

    local pending = operation
    local id = pending.id
    local selected = previousKey ~= nil and id == previousKey

    if previousReference then
        local reference = active and active.reference

        if not reference then
            local available = addon.GetScopedRotationCoordinator

            if not current(addon, token) then
                return nil
            end

            local coordinator

            if available then
                local get = addon.GetScopedRotationCoordinator

                if not current(addon, token) then
                    return nil
                end

                coordinator = get(addon)
            end

            if not current(addon, token) then
                return nil
            end

            if coordinator then
                local resolve = coordinator.Resolve

                if not current(addon, token) then
                    return nil
                end

                reference = resolve(coordinator, spec, id)
            end

            if not current(addon, token) then
                return nil
            end
        end

        selected = selected or equal(reference, previousReference)

        if fallbackKey and id == fallbackKey and nextReference then
            local nextAddress = raw(nextReference, 'address')
            local oldAddress = kind(reference) == 'table' and raw(reference, 'address')

            selected = selected
                or kind(nextAddress) == 'table'
                    and (raw(nextAddress, 'scope') == 'character'
                        or kind(oldAddress) == 'table' and raw(oldAddress, 'scope') == 'class')
        end
    elseif original then
        local roots = kind(pending.profile) == 'table' and raw(pending.profile, 'rotations')
        local rows = kind(roots) == 'table' and raw(roots, spec)
        local selectedBody = kind(rows) == 'table' and raw(rows, id)
        selected = identity(selectedBody, original)
    end

    local ticket = {}
    pending.publication = { token = ticket, selected = selected }

    if not selected then
        return ticket
    end

    local copied = detached(body)
    local reference = nextReference and detached(nextReference)

    if not copied or nextReference and not reference then
        return nil
    end

    local revision = raw(copied, 'revision')

    if
        revision ~= nil
        and (kind(revision) ~= 'number' or revision < 1 or revision > 9007199254740991 or revision % 1 ~= 0)
    then
        return nil
    end

    local unchanged = active
        and identity(active.profile, pending.profile)
        and active.spec == spec
        and active.id == id
        and equal(active.reference, reference)
        and equal(active.body, copied)

    pending.publication = {
        token = ticket,
        selected = true,
        body = copied,
        reference = reference,
        revision = revision or 1,
        handle = unchanged and active.token or {},
        previousKey = previousKey,
    }

    return ticket
end

-- Step two: after the writer has stored the content, installs the prepared body as the active rotation (renamed to
-- `nextKey` when the id changed). Returns the handle and transition token, true for a nil ticket, or nil when the
-- profile, specialization or rotation changed since prepare.
local function finishPublication(ticket, nextKey)
    if ticket == nil then
        return true
    end

    local pending = operation
    local prepared = pending and pending.publication

    if not prepared or not identity(prepared.token, ticket) then
        return nil
    end

    local db = raw(addon, 'db')

    if
        kind(db) ~= 'table'
        or not identity(raw(db, 'profile'), pending.profile)
        or not identity(raw(addon, 'currentSpec'), pending.spec)
        or not identity(raw(addon, 'currentRotation'), pending.id)
    then
        return nil
    end

    pending.publication = nil

    if not prepared.selected then
        return true, pending.token
    end

    local id = pending.id

    if nextKey and prepared.previousKey == id then
        id = nextKey
    end

    invalidateExecution()

    active = {
        token = prepared.handle,
        profile = pending.profile,
        spec = pending.spec,
        id = id,
        reference = prepared.reference,
        body = prepared.body,
        revision = prepared.revision,
    }

    pending.cleanupSpec, pending.cleanupID = nil, nil
    write(addon, 'currentRotation', id)
    pending.id = id
    return prepared.handle, pending.token
end

-- Step one of a writer that moves or replaces rotations in bulk (an import, a restore). Begins a transition, makes sure
-- the active rotation has a detached reference, and returns a ticket, that reference and the transition facts.
-- With no current rotation it just clears the active record and returns nil.
local function prepareRebind(fallbackKey)
    if raw(addon, 'currentRotation') == nil then
        invalidateExecution()
        active = nil
        return nil
    end

    local token = begin(addon)

    if not token or not current(addon, token) then
        return nil, nil, token
    end

    local pending = operation
    local spec, id = pending.spec, pending.id

    if id == nil then
        return nil, nil, token, spec, id
    end

    -- A managed active selection already owns a detached body/reference.
    -- Re-reading its public getter would expose the canonical body merely to
    -- rediscover that reference. Legacy selections still use that real getter.
    if not (active
        and identity(active.profile, pending.profile)
        and active.spec == spec
        and active.id == id
        and active.reference) then
        protect(commit, addon, token, spec, id)
    end

    if not current(addon, token) then
        return nil, nil, token, spec, id
    end

    local reference

    if active and identity(active.profile, pending.profile) and active.spec == spec and active.id == id then
        reference = active.reference
    end

    local ticket = {}
    pending.rebind = { token = ticket, reference = reference and detached(reference), fallbackKey = fallbackKey }
    return ticket, reference and detached(reference), token, spec, id
end

-- Step two: re-selects the rotation under `key`, but only if it is the same rotation (its reference matches the one
-- prepared) or the writer's fallback. An invalid result retires the selection and returns nil. Otherwise returns the
-- new handle and the transition token.
local function finishRebind(ticket, key, reference, body)
    if ticket == nil then
        return true
    end

    local pending = operation
    local prepared = pending and pending.rebind

    if not prepared or not identity(prepared.token, ticket) then
        return nil
    end

    local db = raw(addon, 'db')

    if
        kind(db) ~= 'table'
        or not identity(raw(db, 'profile'), pending.profile)
        or not identity(raw(addon, 'currentSpec'), pending.spec)
        or not identity(raw(addon, 'currentRotation'), pending.id)
    then
        return nil
    end

    local copied = detached(body)
    local resolved = detached(reference)

    local valid = kind(key) == 'string'
        and key ~= ''
        and copied
        and resolved
        and (pending.id == prepared.fallbackKey or prepared.reference and equal(prepared.reference, resolved))

    pending.rebind = nil
    pending.cleanupSpec, pending.cleanupID = nil, nil

    if not valid then
        invalidateExecution()
        active = nil
        write(addon, 'currentRotation', nil)
        pending.id = nil
        return nil, pending.token
    end

    local revision = raw(copied, 'revision') or 1

    if kind(revision) ~= 'number' or revision < 1 or revision > 9007199254740991 or revision % 1 ~= 0 then
        invalidateExecution()
        active = nil
        write(addon, 'currentRotation', nil)
        pending.id = nil
        return nil, pending.token
    end

    local handle = {}
    invalidateExecution()

    active = {
        token = handle,
        profile = pending.profile,
        spec = pending.spec,
        id = key,
        reference = resolved,
        body = copied,
        revision = revision,
    }

    write(addon, 'currentRotation', key)
    pending.id = key
    return handle, pending.token
end

-- ============================================================================
-- Runtime access
-- ============================================================================

-- Source-private runtime access: the identity body never leaves this module.
-- Returns the active handle, its content revision and the pending transition token when the active rotation is for
-- `spec` and `key` in the current profile; nothing otherwise.
local function runtimeIdentity(owner, spec, key)
    if not owned(owner) or not active or kind(raw(owner, 'db')) ~= 'table' then
        return
    end
    if
        not identity(raw(raw(owner, 'db'), 'profile'), active.profile)
        or not identity(raw(owner, 'currentSpec'), spec)
        or not identity(active.spec, spec)
        or not identity(raw(owner, 'currentRotation'), key)
        or not identity(active.id, key)
    then
        return
    end

    return active.token, active.revision, operation and operation.token
end

-- Returns a fresh detached copy of the active body when `handle` is still the active one, and when `expected` is given
-- the body equals it. Returns nothing otherwise.
local function runtimeBody(owner, handle, expected)
    if not active or not identity(active.token, handle) or not runtimeIdentity(owner, active.spec, active.id) then
        return
    end
    if expected ~= nil and not equal(active.body, expected) then
        return
    end

    return detached(active.body)
end

-- One trusted handoff: gives `receiver` the private publication, rebind and runtime-access functions (in that order:
-- prepare, finish, prepareRebind, finishRebind, runtimeIdentity, runtimeBody). Returns true; nil for a foreign caller.
function addon:BindActiveRotationPublication(receiver)
    if not owned(self) or kind(receiver) ~= 'function' then
        return nil
    end

    receiver(preparePublication, finishPublication, prepareRebind, finishRebind, runtimeIdentity, runtimeBody)
    return true
end
