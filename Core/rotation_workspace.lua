-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Edit workspaces for rotations: the object the rotation editor holds while a rotation is open. A workspace wraps an
-- edit session over a detached copy of the body and decides whether the target is still the same, what Apply saves and
-- where. It owns the per-profile cache of open workspaces and the read-only import-preview workspace; it draws nothing,
-- and nothing reaches saved data until Apply (through the scoped coordinator, or directly in the unscoped layout).
-- Loaded from RotationMaster.toc after Core/rotation_editor.lua; the editor, browser and import code call it. Storage
-- model: docs/architecture/storage-scopes.md.

local _, addon = ...
local data = addon.RotationData

-- ============================================================================
-- Shared helpers
-- ============================================================================

-- Per-profile cache of live workspaces (profile table to list of workspaces), so reopening the same rotation gives back
-- the same unsaved edits. Keyed by the profile table itself, so a profile switch starts a fresh list.
local profiles = {}

-- True when two plain-data trees are equal by value. Non-portable data is never equal, so it always reads as changed.
local function equal(a, b)
    if not data.CheckPortable(a) or not data.CheckPortable(b) then
        return false
    end

    -- Recursive by-value comparison of two plain values.
    local function compare(x, y)
        if type(x) ~= type(y) then
            return false
        end
        if type(x) ~= 'table' then
            return x == y
        end

        for key, value in pairs(x) do
            if not compare(value, y[key]) then
                return false
            end
        end

        for key in pairs(y) do
            if x[key] == nil then
                return false
            end
        end

        return true
    end

    return compare(a, b)
end

-- Returns the saved rotation body for a specialization and id in the unscoped layout, or nil.
local function originalAt(profile, spec, id)
    local list = profile.rotations and profile.rotations[spec]
    return type(list) == 'table' and list[id] or nil
end

-- Returns the library records (origins, comparisons, imports) kept for one saved rotation, so an edit session can keep
-- their identities reserved. Missing kinds are simply absent.
local function retained(profile, spec, id)
    local result = {}
    local library = profile.rotationLibrary

    if type(library) == 'table' then
        for _, kind in ipairs({ 'origins', 'comparisons', 'imports' }) do
            local all = library[kind]
            local scope = type(all) == 'table' and all[spec]

            if type(scope) == 'table' then
                result[kind] = scope[id]
            end
        end
    end

    return result
end

-- ============================================================================
-- Scoped workspaces
-- ============================================================================

-- Returns the edit workspace for a rotation reference in the scoped store, creating it (and caching it for the profile)
-- when none is live. value is anything the coordinator can resolve: a reference, an id, or a legacy draft id. Returns
-- nil and a reason when the rotation is unknown or its snapshot cannot be taken. A workspace is detached from the saved
-- rotation: nothing is written until Apply, and every write goes through the coordinator's compare-and-commit.
local function scopedWorkspace(owner, coordinator, spec, value)
    local reference, why = coordinator:Resolve(spec, value)

    if not reference and why == 'unknown-rotation' and type(value) == 'string' then
        reference, why = coordinator:LegacyDraft(spec, value)
    end

    if not reference then
        return nil, why
    end

    local profile = owner.db.profile
    local key = coordinator:Key(reference)
    local cache = profiles[profile]

    if not cache then
        cache = {}
        profiles[profile] = cache
    end

    for _, w in ipairs(cache) do
        if w.spec == spec and w.id == key and w:ValidTarget() then
            return w
        end
    end

    local pending = coordinator:IsPending(reference)
    local record, expected, status

    if not pending then
        record, expected, status = coordinator:Snapshot(spec, reference)

        if not record then
            return nil, expected
        end
    end

    local builtin = reference.kind == 'builtin' and reference.id or nil

    if not record then
        local fallback = reference.address.id == profile.rotationFallbackID
        -- A new rotation is for the specialization the list shows (any, when it shows all).
        local specs = not fallback and owner.DefaultNewRotationSpecs and owner:DefaultNewRotationSpecs() or nil

        record = {
            body = {
                name = fallback and profile.rotationFallbackID or NEW,
                specs = specs,
                switch = {},
                rotation = {},
                cooldowns = {},
            },
        }
    end

    local sourceReference = data.CopyData(reference)

    local workspace = {
        spec = spec,
        id = key,
        canonicalId = builtin or reference.address.id,
        reference = data.CopyData(reference),
        builtin = builtin,
        readOnly = builtin ~= nil,
        fallback = not builtin and reference.address.id == profile.rotationFallbackID or false,
        pending = pending,
        original = pending and nil or data.CopyData(record.body),
        title = record.body.name or NEW,
        description = record.body.description or '',
    }

    workspace.source = record.source
    local baseline = data.CopyData(record.body)

    -- Refreshes the derived flags after any change: the effective scope, a pending rotation's staged reference, and
    -- whether this rotation is the one the specialization currently resolves as its fallback.
    local function flags()
        workspace.scope = workspace.session and workspace.session:Ownership()
            or (not builtin and workspace.reference.address.scope)

        if workspace.pending and workspace.session then
            local staged = coordinator:StagePending(sourceReference, workspace.scope)

            if staged then
                workspace.reference = staged
            end
        end

        local effective = coordinator:Resolve(spec, DEFAULT)
        workspace.effectiveFallback = effective and equal(effective, workspace.reference) or false
    end

    -- True while this workspace still edits what it was opened on: not discarded, the same coordinator, and the stored
    -- rotation unchanged since the snapshot (or, for a new rotation, still pending).
    function workspace:ValidTarget()
        if self.discarded or owner:GetScopedRotationCoordinator() ~= coordinator then
            return false
        end
        if builtin then
            return coordinator:Resolve(spec, sourceReference) ~= nil
        end
        if self.pending then
            return coordinator:IsPending(sourceReference) and coordinator:Resolve(spec, sourceReference) ~= nil
        end

        return coordinator:TokenCurrent(expected)
    end

    -- Opens an edit session over a body, reserving the identities of the saved origin, import and comparison records so
    -- new ids never collide with them. Returns the session, or nil and a problem code. Commit goes to the coordinator,
    -- which rejects a write when the stored rotation changed meanwhile.
    local function sessionFor(body)
        workspace.reserved = {
            origins = data.CopyData(record.origin),
            imports = data.CopyData(record.imported),
            comparisons = data.CopyData(record.comparison),
        }

        local used = {}

        for _, component in pairs(workspace.reserved) do
            local ok, problem = data.ReserveRotationIdentities(component, used)

            if not ok then
                return nil, problem.code
            end
        end

        -- Returns an unused uuid, or nil after 100 collisions.
        local function fresh()
            for _ = 1, 100 do
                local id = owner.uuid()

                if not used[id] then
                    used[id] = true
                    return id
                end
            end
        end

        return owner:NewRotationEditSession(spec, body, {
            readOnly = workspace.readOnly,
            newId = fresh,
            ownership = not builtin and sourceReference.address.scope or nil,
            setOwnershipAllowed = not builtin,
            targetValid = function() return workspace:ValidTarget() end,
            commit = function(candidate, scope)
                local replacement = {
                    body = candidate,
                    origin = record.origin,
                    imported = record.imported,
                    comparison = record.comparison,
                }

                local saved, problem = coordinator:Commit(sourceReference, expected, replacement, scope)

                if not saved then
                    return nil, problem
                end

                return true, saved
            end,
        })
    end

    local session, problem = sessionFor(baseline)

    if not session then
        return nil, problem
    end

    workspace.session = session
    flags()

    -- Returns a copy of the body as edited so far.
    function workspace:Snapshot()
        flags()
        return self.session:Snapshot()
    end

    -- The class this rotation is for: the owner class of a saved rotation, the
    -- declared class of a Built In (nil when it declares none, which is the
    -- player's class). Tree conditions are named for it (Data/talent_trees.lua).
    function workspace:RotationClass()
        local address = self.reference and self.reference.address

        if type(address) == 'table' and data.IsRotationClassToken(address.class) then
            return address.class
        end

        local scope = type(self.source) == 'table' and self.source.applicability

        if type(scope) == 'table' and data.IsRotationClassToken(scope.class) then
            return scope.class
        end
    end

    -- Returns the reference this workspace would be saved under, using the chosen scope and the current owner, or nil
    -- and missing-owner-context when the character or class is unknown.
    function workspace:TargetReference()
        local result = data.CopyData(self.reference)

        if not self.readOnly then
            local c = owner:GetRotationOwnerContext()

            if not c then
                return nil, 'missing-owner-context'
            end

            result.address.scope = self.session:Ownership()
            result.address.owner = result.address.scope == 'class' and c.class or c.character

            if not result.address.owner then
                return nil, 'missing-owner-context'
            end
        end

        return result
    end

    -- Returns what the editor shows about the rotation besides its body: id, reference, scope, kind (builtin or
    -- custom), metadata and the preserved source records.
    function workspace:Metadata()
        return {
            id = self.id,
            reference = self:TargetReference(),
            scope = self.session:Ownership(),
            kind = self.readOnly and 'builtin' or 'custom',
            metadata = data.CopyData(self:Snapshot().metadata or {}),
            source = self.source or self.reserved,
        }
    end

    -- True when there are unsaved edits; a Built In is never dirty because it cannot be edited.
    function workspace:IsDirty()
        flags()
        return not self.readOnly and self.session:IsDirty()
    end

    -- Runs one edit command on the session. Refuses when the target changed underneath, protects the fallback's name,
    -- and refuses a character scope with no character context.
    function workspace:Command(name, ...)
        if not self:ValidTarget() then
            return nil, 'rotation-target-missing'
        end
        if self.fallback and name == 'SetBodyField' and (...) == 'name' then
            return nil, 'protected-rotation-name'
        end

        if name == 'SetOwnership' and (...) == 'character' then
            local c = owner:GetRotationOwnerContext()

            if not c or not c.character then
                return nil, 'missing-owner-context'
            end
        end

        local ok, result = self.session:Command(name, ...)
        flags()
        return ok, result
    end

    -- Saves the edits through the coordinator. A new rotation needs a real name (not the placeholders). On success the
    -- workspace re-baselines on the saved record and opens a fresh session, so it can be edited and applied again.
    -- Returns true, nil, the saved reference; or nil and a reason.
    function workspace:Apply()
        if self.pending and not self.fallback then
            local name = self:Snapshot().name

            if type(name) ~= 'string' or not name:find('%S') or name == NEW or name == DEFAULT then
                return nil, 'invalid-rotation-name'
            end
        end

        local ok, why, saved = self.session:Apply()

        if not ok then
            return nil, why, saved
        end

        sourceReference = data.CopyData(saved)
        self.reference = data.CopyData(saved)
        self.id = coordinator:Key(saved)
        self.canonicalId = saved.address.id
        self.pending = false
        record, expected, status = coordinator:Snapshot(spec, saved)
        baseline = data.CopyData(record.body)
        self.original = data.CopyData(record.body)
        self.title = record.body.name or self.canonicalId
        self.description = record.body.description or ''
        local nextSession, problem = sessionFor(baseline)

        if not nextSession then
            return nil, problem
        end

        self.session = nextSession
        flags()
        return true, nil, data.CopyData(saved)
    end

    -- Throws away the unsaved edits by swapping in a session over the baseline; the saved rotation is untouched.
    function workspace:Discard()
        if not self:ValidTarget() then
            return nil, 'rotation-target-missing'
        end

        local replacement, why = sessionFor(baseline)

        if not replacement then
            return nil, why
        end

        self.session:Cancel()
        self.session = replacement
        flags()
        return true
    end

    -- Returns the target the condition editor works on for the switch or one step: a detached copy of the condition, a
    -- validity check that fails if the session or condition changed meanwhile, and a commit that writes the result back
    -- through SetCondition. Read-only workspaces refuse the commit.
    function workspace:ConditionEditorTarget(target)
        local captured = self.session

        -- Reads the targeted condition tree from the captured session's current snapshot.
        local function condition()
            local body = captured:Snapshot()

            if type(target) == 'table' and target.kind == 'switch' then
                return body.switch or {}
            end

            local tree = data.IndexRotationSteps(body)
            local row = tree and tree.byId[target]
            return row and (row.step.conditions or {})
        end

        local baselineCondition = condition()

        if not baselineCondition then
            return nil, 'missing-rotation-step'
        end

        local committed = false

        -- True while the editor's target is still the same session, unchanged and not yet committed.
        local function valid()
            return not committed and workspace.session == captured and workspace:ValidTarget() and equal(
                baselineCondition,
                condition()
            )
        end

        return {
            condition = data.CopyData(baselineCondition),
            readOnly = self.readOnly,
            valid = valid,
            commit = function(edited)
                if workspace.readOnly then
                    return nil, 'readonly-rotation'
                end
                if not valid() then
                    return nil, 'condition-target-changed'
                end

                local ok, why = workspace:Command('SetCondition', target, edited)

                if ok then
                    committed = true
                end

                return ok, why
            end,
        }
    end

    cache[#cache + 1] = workspace
    return workspace
end

-- ============================================================================
-- Unscoped workspaces
-- ============================================================================

-- Returns the edit workspace for a rotation id in a specialization. With a scoped store this defers to scopedWorkspace;
-- otherwise it works directly on profile.rotations (the pre-scope layout), where a Built In is read-only and a new
-- rotation is saved into the profile table on Apply. Returns nil and a reason code when the target is invalid.
function addon:GetRotationEditWorkspace(spec, id)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        return scopedWorkspace(self, scoped, spec, id)
    end
    if type(spec) ~= 'number' or spec < 0 or spec % 1 ~= 0 or type(id) ~= 'string' or id == '' then
        return nil, 'invalid-rotation-target'
    end

    local profile = self.db.profile

    if type(profile.rotations) ~= 'table' then
        return nil, 'invalid-rotation-storage'
    end

    local builtin = self:GetDefaultIdForRuntime(spec, id)
    local source, original

    if builtin then
        for _, entry in ipairs(self:ListDefaultRotations(spec)) do
            if entry.id == builtin then
                source = entry
                break
            end
        end

        if not source or not source.envelope then
            return nil, 'unknown-default-rotation'
        end
    else
        original = originalAt(profile, spec, id)
    end

    local cache = profiles[profile]

    if not cache then
        cache = {}
        profiles[profile] = cache
    end

    for _, workspace in ipairs(cache) do
        if
            workspace.spec == spec
            and workspace.id == id
            and workspace.builtin == builtin
            and (builtin or workspace.original == original)
            and workspace:ValidTarget()
        then
            return workspace
        end
    end

    local workspace = {
        spec = spec,
        id = id,
        canonicalId = id,
        builtin = builtin,
        readOnly = builtin ~= nil,
        fallback = not builtin and id == DEFAULT or false,
        title = source and source.name or id == DEFAULT and DEFAULT or original and original.name or NEW,
        description = source and source.description or original and original.description or '',
        source = source,
        original = original,
        pending = not builtin and original == nil,
    }

    local capturedRoot = profile.rotations
    local value = source and data.CopyData(source.envelope.body) or original

    if not value then
        value = { name = id == DEFAULT and DEFAULT or NEW, switch = {}, rotation = {}, cooldowns = {} }
    end
    if builtin then
        value.name = source.name
    end

    -- True while the profile and its rotation table are the ones this workspace was opened on and the rotation is
    -- unchanged.
    function workspace:ValidTarget()
        if self.discarded or addon.db.profile ~= profile or profile.rotations ~= capturedRoot then
            return false
        end
        if self.builtin then
            return addon:GetDefaultIdForRuntime(spec, id) == self.builtin
        end

        return originalAt(profile, spec, id) == self.original and not addon:GetDefaultIdForRuntime(spec, id)
    end

    -- Opens an edit session over a body, bound to this workspace's validity and reserved identities.
    local function sessionFor(body)
        return addon:NewRotationEditSession(spec, body, {
            readOnly = workspace.readOnly,
            newId = addon.uuid,
            reserved = workspace.reserved,
            newRecord = workspace.pending,
            targetValid = function() return workspace:ValidTarget() end,
        })
    end

    local reservations, copyError = data.CopyData(retained(profile, spec, id))

    if not reservations then
        return nil, copyError.code
    end

    workspace.reserved = reservations
    local session, why = sessionFor(value)

    if not session then
        return nil, why
    end

    workspace.session = session

    -- Returns a copy of the body as edited so far.
    function workspace:Snapshot()
        return self.session:Snapshot()
    end

    -- Returns what the editor shows about the rotation besides its body: id, kind, metadata and the source envelope or
    -- reserved records.
    function workspace:Metadata()
        return {
            id = id,
            kind = self.readOnly and 'builtin' or 'custom',
            metadata = data.CopyData(self:Snapshot().metadata or {}),
            source = self.source and data.CopyData(self.source.envelope) or data.CopyData(self.reserved),
        }
    end

    -- True when there are unsaved edits; never for a Built In.
    function workspace:IsDirty()
        return not self.readOnly and self.session:IsDirty()
    end

    -- Runs one edit command on the session, refusing it when the target changed or when it would rename the fallback.
    function workspace:Command(name, ...)
        if not self:ValidTarget() then
            return nil, 'rotation-target-missing'
        end
        if id == DEFAULT and name == 'SetBodyField' and (...) == 'name' then
            return nil, 'protected-rotation-name'
        end

        return self.session:Command(name, ...)
    end

    -- Applies the session and, for a new rotation, stores the body in the profile table. Returns true, or nil and a
    -- reason.
    function workspace:Apply()
        if self.pending and id ~= DEFAULT then
            local name = self:Snapshot().name

            if type(name) ~= 'string' or not name:find('%S') or name == NEW or name == DEFAULT then
                return nil, 'invalid-rotation-name'
            end
        end

        local ok, reason, details = self.session:Apply()

        if not ok then
            return nil, reason, details
        end

        if self.pending then
            local list = profile.rotations[spec] or {}
            profile.rotations[spec] = list
            list[id] = value
            self.original = value
            self.pending = false
        end

        self.title = value.name or id
        local replacement, problem = sessionFor(value)

        if not replacement then
            return nil, problem
        end

        self.session = replacement
        return true
    end

    -- Throws away the unsaved edits by swapping in a session over the stored body.
    function workspace:Discard()
        if not self:ValidTarget() then
            return nil, 'rotation-target-missing'
        end

        local replacement, problem = sessionFor(value)

        if not replacement then
            return nil, problem
        end

        self.session:Cancel()
        self.session = replacement
        return true
    end

    -- Returns the condition editor target for the switch or one step; same contract as the scoped workspace's.
    function workspace:ConditionEditorTarget(target)
        local sessionToken = self.session

        -- Reads the targeted condition tree from the captured session's current snapshot.
        local function condition()
            local snapshot = sessionToken:Snapshot()

            if type(target) == 'table' and target.kind == 'switch' then
                return snapshot.switch or {}
            end

            local tree = data.IndexRotationSteps(snapshot)
            local row = tree and tree.byId[target]
            return row and (row.step.conditions or {})
        end

        local baseline = condition()

        if not baseline then
            return nil, 'missing-rotation-step'
        end

        local committed = false

        -- True while the editor's target is still the same session, unchanged and not yet committed.
        local function valid()
            return not committed and workspace.session == sessionToken and workspace:ValidTarget() and equal(
                baseline,
                condition()
            )
        end

        return {
            condition = data.CopyData(baseline),
            readOnly = self.readOnly,
            valid = valid,
            commit = function(edited)
                if workspace.readOnly then
                    return nil, 'readonly-rotation'
                end
                if not valid() then
                    return nil, 'condition-target-changed'
                end

                local ok, reason = workspace:Command('SetCondition', target, edited)

                if ok then
                    committed = true
                end

                return ok, reason
            end,
        }
    end

    cache[#cache + 1] = workspace
    return workspace
end

-- ============================================================================
-- Import preview, lookup and drafts
-- ============================================================================

-- A detached, read-only workspace for an incoming rotation (an import preview).
-- The editor draws it exactly as it draws a Built In, but it belongs to no
-- profile: it is a private copy of the candidate, never cached, listed or
-- resolved by reference, and every write is refused. Close it when the window
-- that shows it closes.
function addon:NewRotationPreviewWorkspace(spec, preview)
    if type(spec) ~= 'number' or type(preview) ~= 'table' or type(preview.body) ~= 'table' then
        return nil, 'no-previewable-body'
    end

    local body, why = data.CopyData(preview.body)

    if not body then
        return nil, why.code
    end

    local manifest

    if preview.manifest ~= nil then
        manifest, why = data.CopyData(preview.manifest)

        if not manifest then
            return nil, why.code
        end
    end

    local session, problem = self:NewRotationEditSession(spec, body, { readOnly = true, newId = self.uuid })

    if not session then
        return nil, problem
    end

    local workspace = {
        spec = spec,
        id = 'import-preview',
        canonicalId = 'import-preview',
        readOnly = true,
        preview = true,
        fallback = false,
        pending = false,
        title = type(body.name) == 'string' and body.name or '',
        description = type(body.description) == 'string' and body.description or '',
        original = data.CopyData(body),
        session = session,
        reserved = manifest and { imports = { manifest = manifest } } or {},
    }

    -- True until the preview is closed.
    function workspace:ValidTarget()
        return not self.closed
    end

    -- Returns a copy of the previewed body.
    function workspace:Snapshot()
        return self.session:Snapshot()
    end

    -- Returns the preview's metadata and the import manifest, if any.
    function workspace:Metadata()
        return {
            id = self.id,
            kind = 'preview',
            metadata = data.CopyData(self:Snapshot().metadata or {}),
            source = data.CopyData(self.reserved),
        }
    end

    -- A preview is never dirty.
    function workspace:IsDirty()
        return false
    end

    -- Every write to a preview is refused.
    function workspace:Command()
        return nil, 'readonly-rotation'
    end

    -- Refused: a preview cannot be applied.
    function workspace:Apply()
        return nil, 'readonly-rotation'
    end

    -- Refused: a preview has nothing to discard.
    function workspace:Discard()
        return nil, 'readonly-rotation'
    end

    -- Ends the preview and cancels its session; safe to call twice.
    function workspace:Close()
        if not self.closed then
            self.closed = true
            self.session:Cancel()
        end
    end

    -- Returns a read-only condition target for the previewed switch or step; commit is always refused.
    function workspace:ConditionEditorTarget(target)
        -- Reads the targeted condition tree from the preview's current snapshot.
        local function condition()
            local snapshot = self.session:Snapshot()

            if type(target) == 'table' and target.kind == 'switch' then
                return snapshot.switch or {}
            end

            local tree = data.IndexRotationSteps(snapshot)
            local row = tree and tree.byId[target]
            return row and (row.step.conditions or {})
        end

        local baseline = condition()

        if not baseline then
            return nil, 'missing-rotation-step'
        end

        return {
            condition = data.CopyData(baseline),
            readOnly = true,
            valid = function() return not self.closed and equal(baseline, condition()) end,
            commit = function() return nil, 'readonly-rotation' end,
        }
    end

    return workspace
end

-- Returns the live, still-valid workspace already open for a specialization and id or reference, or nil. It never
-- creates one.
function addon:GetRotationWorkspace(spec, value)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    local reference = scoped and scoped:Resolve(spec, value)

    for _, w in ipairs(profiles[self.db.profile] or {}) do
        if
            w.spec == spec
            and (w.id == value or scoped and reference and equal(w.reference, reference))
            and w:ValidTarget()
        then
            return w
        end
    end
end

-- Throws away a new rotation that was never saved: it leaves the roster and
-- cannot be selected or applied any more. Saved rotations, Built Ins and the
-- fallback are refused. Safe to repeat.
function addon:DiscardPendingRotation(workspace)
    if type(workspace) ~= 'table' then
        return nil, 'invalid-rotation-target'
    end
    if workspace.discarded then
        return true
    end
    if not workspace.pending or workspace.readOnly or workspace.fallback then
        return nil, 'not-a-new-rotation'
    end

    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped and workspace.reference then
        local ok, why = scoped:DiscardPending(workspace.reference)

        if not ok and why ~= 'unknown-rotation' then
            return nil, why
        end
    end

    local list = profiles[self.db.profile]

    for index = #(list or {}), 1, -1 do
        if list[index] == workspace then
            table.remove(list, index)
        end
    end

    workspace.discarded = true

    if workspace.session and workspace.session.Cancel then
        workspace.session:Cancel()
    end

    return true
end

-- Returns one list row for every new, unsaved rotation open for the specialization, so the browser can show it beside
-- the saved ones.
function addon:ListPendingRotationDrafts(spec)
    local result = {}

    for _, workspace in ipairs(profiles[self.db.profile] or {}) do
        if workspace.spec == spec and workspace.pending and workspace.id ~= DEFAULT and workspace:ValidTarget() then
            local snapshot = workspace:Snapshot()

            result[#result + 1] = {
                id = workspace.id,
                key = workspace.id,
                reference = workspace.TargetReference and workspace:TargetReference(),
                canonicalId = workspace.canonicalId,
                scope = workspace.scope,
                pending = true,
                fallback = workspace.fallback,
                effectiveFallback = false,
                name = snapshot.name or NEW,
                presentation = {
                    name = snapshot.name,
                    description = snapshot.description,
                    priority = snapshot.priority,
                    tags = snapshot.tags,
                    metadata = snapshot.metadata,
                },
            }
        end
    end

    return result
end
