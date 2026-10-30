-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Rotation catalog: the store of saved custom rotation envelopes plus the registered Built In ones, with enable
-- preferences, withdrawn Built Ins and clone lineage. Every read returns a validated, detached snapshot; every write
-- validates first and stamps the content and envelope revisions.
-- It owns the rules for what may be saved (ids, revisions, read-only Built Ins, clone lineage) and works on the
-- state table it is given (the catalog's SavedVariables namespace); it must not evaluate conditions or touch the game.
-- Loaded from RotationMaster.toc after Data/validation.lua and before Data/diff.lua; built through data.NewCatalog by
-- Core/rotation_library.lua and Core/rotation_scope.lua. Uses data.ValidateEnvelope, CopyData, IndexRotationSteps and
-- PrepareRotationContentRevision.
local _, addon = ...
local data = addon.RotationData

-- ============================================================================
-- Helpers
-- ============================================================================

-- Whether a value is a valid rotation or step id.
-- @param value any  The value to test.
-- @return boolean  True for a string of at most 128 characters, starting alphanumeric, then letters, digits or . _ : -.
local function id(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and value:match("^[%w][%w._:%-]*$") ~= nil
end

-- Calls a callback for every step of an envelope's body (cooldowns, rotation and nested Branch arms).
-- @param envelope table  The envelope whose body is walked.
-- @param callback function  Called with each step; it may edit the step in place.
-- @return boolean|nil  True when walked; nil when the steps cannot be indexed, or nothing when the envelope has no
--   body table.
-- @return table|nil  The indexing error when the first return is nil; nil otherwise.
local function steps(envelope, callback)
    if type(envelope) ~= "table" or type(envelope.body) ~= "table" then
        return
    end

    local index, why = data.IndexRotationSteps(envelope.body)

    if not index then
        return nil, why
    end

    for _, row in ipairs(index.rows) do
        callback(row.step)
    end

    return true
end

-- Whether a stored clone lineage is intact.
-- @param value any  The lineage record.
-- @return boolean  True for a valid source id and kind, a revision, a baseline envelope that matches them and
--   validates, and a step-origin map whose targets are all steps of that baseline.
local function validLineage(value)
    if
        type(value) ~= "table"
        or not id(value.sourceId)
        or (value.sourceKind ~= "builtin" and value.sourceKind ~= "custom")
        or type(value.sourceRevision) ~= "number"
        or value.sourceRevision < 1
        or value.sourceRevision % 1 ~= 0
        or type(value.baseline) ~= "table"
        or value.baseline.format ~= "RotationMaster"
        or value.baseline.schemaVersion ~= 1
        or value.baseline.id ~= value.sourceId
        or value.baseline.revision ~= value.sourceRevision
        or type(value.stepOrigins) ~= "table"
    then
        return false
    end

    -- Validate historical envelope structure independently of today's condition
    -- catalog. An unavailable old condition must not erase source evidence.
    if not data.ValidateEnvelope(value.baseline).valid then
        return false
    end

    local baselineIds = {}

    if not steps(value.baseline, function(step)
        baselineIds[step.id] = true
    end) then
        return false
    end

    for key, origin in pairs(value.stepOrigins) do
        if not id(key) or not id(origin) or not baselineIds[origin] then
            return false
        end
    end

    return true
end

-- ============================================================================
-- Catalog
-- ============================================================================

-- Creates a catalog of saved custom rotation envelopes and registered Built In ones.
-- @param options table|nil  { state = the catalog's SavedVariables namespace (custom, preferences and lineage tables,
--   created when missing), validation = options passed to the validators, newId = function allocating ids for clones }.
-- @return table|nil  The catalog (RegisterBuiltin, Get, List, SetEnabled, Save, AddCustom, Rename, Delete,
--   WithdrawBuiltin, Clone); nil when the state is malformed.
-- @return string|nil  'invalid-catalog-state' or 'invalid-custom-id' when the first return is nil; nil otherwise.
--
-- State is the catalog's SavedVariables namespace, not an entire legacy profile. Validation catalogs and newId are
-- trusted application dependencies.
function data.NewCatalog(options)
    options = options or {}
    local state = options.state

    if state == nil then
        state = {}
    end

    if type(state) ~= "table" or getmetatable(state) ~= nil then
        return nil, "invalid-catalog-state"
    end

    for _, key in ipairs({ "custom", "preferences", "lineage" }) do
        if state[key] ~= nil and (type(state[key]) ~= "table" or getmetatable(state[key]) ~= nil) then
            return nil, "invalid-catalog-state"
        end
    end

    if state.custom then
        for key in pairs(state.custom) do
            if not id(key) then
                return nil, "invalid-custom-id"
            end
        end
    end

    state.custom, state.preferences, state.lineage = state.custom or {}, state.preferences or {}, state.lineage or {}
    local builtins, withdrawn = {}, {}
    local catalog = {}

    -- Turns a reference into kind and id.
    -- @param reference string|table  An id string, or { kind, id }. A bare id is a Built In when one is registered
    --   under it, otherwise custom.
    -- @return string|nil  "builtin" or "custom"; nothing for a malformed reference.
    -- @return string|nil  The id.
    local function resolve(reference)
        if type(reference) == "table" then
            if (reference.kind == "builtin" or reference.kind == "custom") and id(reference.id) then
                return reference.kind, reference.id
            end
        elseif id(reference) then
            return builtins[reference] and "builtin" or "custom", reference
        end
    end

    -- Resolves a reference to a saved custom rotation the caller may change.
    -- @param reference string|table  An id string, or { kind, id }.
    -- @return string|nil  The id; nil when it may not be changed.
    -- @return string|nil  'read-only' (a Built In) or 'unknown-rotation' when the first return is nil; nil otherwise.
    local function owned(reference)
        local kind, key = resolve(reference)

        if kind == "builtin" then
            return nil, "read-only"
        end
        if not key or state.custom[key] == nil then
            return nil, "unknown-rotation"
        end

        return key
    end

    -- Tells whether a rotation is switched on.
    -- @param kind string  "builtin" or "custom".
    -- @param key string  The rotation id.
    -- @param envelope table|nil  The detached envelope.
    -- @return boolean  False for a withdrawn Built In; then a saved Built In preference decides; otherwise the
    --   envelope's own disabled flag.
    local function enabled(kind, key, envelope)
        if kind == "builtin" then
            if withdrawn[key] then
                return false
            end

            -- A saved choice wins; an entry without one (e.g. only a priority)
            -- leaves the shipped default in force.
            local preference = state.preferences[key]

            if preference ~= nil then
                if type(preference) ~= "table" or getmetatable(preference) ~= nil then
                    return false
                end
                if preference.enabled ~= nil then
                    return preference.enabled == true
                end
            end
        end

        return type(envelope) == "table" and type(envelope.body) == "table" and envelope.body.disabled ~= true
    end

    -- Builds the detached view of one rotation.
    -- @param kind string  "builtin" or "custom".
    -- @param key string  The rotation id.
    -- @param summary boolean  True for a summary; false for a full view, which adds the envelope copy and, for a clone,
    --   its lineage.
    -- @return table|nil  The view: identity, validation result, enabled state, withdrawal, name and description keys,
    --   revision, applicability and tags; nil when the rotation does not exist.
    local function snapshot(kind, key, summary)
        local source

        if kind == "builtin" then
            source = builtins[key]
        else
            source = state.custom[key]
        end

        if source == nil then
            return nil
        end

        local validation = data.ValidateEnvelope(source, options.validation)
        local cleanSource, copyError = data.CopyData(source)

        if type(cleanSource) == "table" and cleanSource.id ~= key then
            validation.valid, validation.executionStatus = false, "unavailable"

            if #validation.diagnostics < 100 then
                validation.diagnostics[#validation.diagnostics + 1] = {
                    code = "catalog-id-mismatch",
                    path = "$.id",
                    severity = "error",
                }
            end
        end

        local view = {
            id = key,
            reference = { kind = kind, id = key },
            builtin = kind == "builtin",
            readOnly = kind == "builtin",
            enabled = validation.valid and not copyError and enabled(kind, key, cleanSource),
            validation = validation,
            -- The on/off switch alone (saved choice, else shipped default), apart
            -- from whether the definition is valid here: what a toggle shows.
            switchedOn = not copyError and enabled(kind, key, cleanSource),
            withdrawn = withdrawn[key] ~= nil and kind == "builtin",
        }

        if view.withdrawn then
            view.withdrawalReason = withdrawn[key]
        end

        if type(cleanSource) == "table" then
            view.nameKey = type(cleanSource.nameKey) == "string" and cleanSource.nameKey ~= "" and cleanSource.nameKey
                or nil

            view.descriptionKey = type(cleanSource.descriptionKey) == "string"
                and cleanSource.descriptionKey ~= ""
                and cleanSource.descriptionKey
                or nil

            local revision = cleanSource.revision
            view.revision = type(revision) == "number" and revision >= 1 and revision % 1 == 0 and revision or nil

            if validation.valid and cleanSource.schemaVersion == 1 then
                view.applicability, view.tags = data.CopyData(cleanSource.applicability), data.CopyData(
                    cleanSource.tags
                )
            end
        end

        if not summary then
            view.envelope, view.dataError = cleanSource, copyError

            if kind == "custom" and state.lineage[key] ~= nil then
                local lineage, problem = data.CopyData(state.lineage[key])

                if not problem and validLineage(lineage) then
                    view.lineage = lineage
                else
                    view.lineageError = { code = "invalid-lineage", path = "lineage", severity = "error" }
                end
            end
        end

        return view
    end

    -- Validates an envelope for storage and returns a detached copy.
    -- @param envelope table  The envelope; it must carry a valid id and a positive integer revision.
    -- @param structuralOnly boolean|nil  True to skip the current condition catalog (used for Built Ins).
    -- @return table|nil  The detached copy; nil on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    -- @return table|nil  The validation result when the first return is nil; nil otherwise.
    local function storable(envelope, structuralOnly)
        local validation = data.ValidateEnvelope(envelope, not structuralOnly and options.validation or nil)

        if
            not validation.valid
            or not id(envelope.id)
            or type(envelope.revision) ~= "number"
            or envelope.revision < 1
            or envelope.revision % 1 ~= 0
        then
            return nil, "invalid-envelope", validation
        end

        local copy, why = data.CopyData(envelope)

        if not copy then
            return nil, why.code, validation
        end

        return copy
    end

    -- Registers (or upgrades) a shipped Built In envelope.
    -- @param envelope table  The Built In envelope; an equal or older revision than a registered one is refused.
    -- @return boolean  True when registered.
    -- @return string|nil  The reason code when false; nil otherwise.
    -- @return table|nil  The validation result when the envelope was not storable; nil otherwise.
    --
    -- A changed extension schema can invalidate an otherwise intact shipped definition. Its source is retained;
    -- snapshots expose current diagnostics and runtime eligibility keeps it inert. Custom saves remain strictly
    -- checked.
    function catalog:RegisterBuiltin(envelope)
        -- A changed extension schema can invalidate an otherwise intact shipped
        -- definition. Retain its source; snapshots expose current diagnostics and
        -- runtime eligibility keeps it inert. Custom saves remain strictly checked.
        local copy, why, validation = storable(envelope, true)

        if not copy then
            return false, why, validation
        end

        local previous = builtins[copy.id]

        if previous and copy.revision <= previous.revision then
            return false, "revision-not-newer"
        end

        builtins[copy.id] = copy
        return true
    end

    -- Reads the full view of one rotation (including a copy of its envelope).
    -- @param reference string|table  An id string, or { kind, id }.
    -- @return table|nil  The view; nil when unknown.
    function catalog:Get(reference)
        local kind, key = resolve(reference)

        if not key then
            return nil
        end

        return snapshot(kind, key, false)
    end

    -- Lists summary views of every Built In and custom rotation.
    -- @return table[]  The summaries sorted by id (a Built In before a custom one that shares its id).
    function catalog:List()
        local rows = {}

        for key in pairs(builtins) do
            rows[#rows + 1] = snapshot("builtin", key, true)
        end

        for key in pairs(state.custom) do
            rows[#rows + 1] = snapshot("custom", key, true)
        end

        table.sort(rows, function(a, b)
            if a.id == b.id then
                return a.builtin and not b.builtin
            end

            return a.id < b.id
        end)

        return rows
    end

    -- Switches a rotation on or off.
    -- @param reference string|table  An id string, or { kind, id }.
    -- @param value boolean  True to switch on.
    -- @return boolean  True when changed.
    -- @return string|nil  The reason code when false; nil otherwise.
    --
    -- A Built In stores a preference; a custom rotation is saved with its disabled flag changed (so it gets a new
    -- revision).
    function catalog:SetEnabled(reference, value)
        if type(value) ~= "boolean" then
            return false, "invalid-enabled-value"
        end

        local kind, key = resolve(reference)

        if not key then
            return false, "unknown-rotation"
        end

        if kind == "builtin" then
            if not builtins[key] then
                return false, "unknown-rotation"
            end
            if withdrawn[key] then
                return false, "withdrawn-built-in"
            end
            if type(state.preferences[key]) == "table" and getmetatable(state.preferences[key]) ~= nil then
                return false, "invalid-preference"
            end

            if type(state.preferences[key]) ~= "table" then
                state.preferences[key] = {}
            end

            state.preferences[key].enabled = value
            return true
        end

        local view = self:Get(reference)

        if not view then
            return false, "unknown-rotation"
        end
        if not view.validation.valid or type(view.envelope.body) ~= "table" then
            return false, "invalid-envelope"
        end

        view.envelope.body.disabled = not value
        return self:Save(reference, view.envelope)
    end

    -- Authority seals never enter live copy/iteration callbacks. The plain-data
    -- limits match Data/plain; ordinary preparation still uses public helpers.
    local sealType, sealNext, sealRaw, sealMeta, sealEqual, sealInfinity =
        type, next, rawget, getmetatable, rawequal, math.huge

    -- Takes an exact private copy of a stored value using only the captured raw primitives.
    -- @param value any  The stored value.
    -- @return table|nil  The copy; nil for anything that is not plain data within the node and depth limits.
    --
    -- A metatable or an overridden helper cannot change what is copied.
    local function savedSeal(value)
        local copies, visiting, nodes = {}, {}, 0

        -- Recursive step of savedSeal; shared tables are copied once and a cycle makes the copy fail.
        -- @param current any  The value to copy.
        -- @param depth number  The nesting depth.
        -- @return any|nil  The copy; nil on failure.
        local function copy(current, depth)
            nodes = nodes + 1

            if nodes > 20000 or depth > 64 then
                return nil
            end

            local kind = sealType(current)

            if kind ~= 'table' then
                if kind == 'nil' or kind == 'boolean' or kind == 'string' then
                    return current
                end
                if kind == 'number' and current == current and current ~= sealInfinity and current ~= -sealInfinity then
                    return current
                end

                return nil
            end

            if sealMeta(current) ~= nil or visiting[current] then
                return nil
            end
            if copies[current] then
                return copies[current]
            end

            local result = {}
            copies[current] = result
            visiting[current] = true

            for key in sealNext, current do
                nodes = nodes + 1
                local keyType = sealType(key)

                if nodes > 20000 or not (keyType == 'string' or keyType == 'number' and key >= 1 and key % 1 == 0) then
                    return nil
                end

                local child = copy(sealRaw(current, key), depth + 1)

                if child == nil then
                    return nil
                end

                result[key] = child
            end

            visiting[current] = nil
            return result
        end

        return copy(value, 0)
    end

    -- Compares two stored values for deep equality using the raw primitives.
    -- @param a any  The first value.
    -- @param b any  The second value.
    -- @param mode string  'envelope' (the envelope and body revisions are ignored), 'body' or 'exact' (compares
    --   everything).
    -- @return boolean  True when equal.
    --
    -- A revision preparation can call overridable copy helpers, so the canonical body is kept exact until that new
    -- stage has completed.
    local function sameSavedValue(a, b, mode)
        if sealType(a) ~= sealType(b) then
            return false
        end
        if sealType(a) ~= 'table' then
            return a == b
        end
        if sealMeta(a) ~= nil or sealMeta(b) ~= nil then
            return false
        end

        for key, value in sealNext, a do
            if not (key == 'revision' and (mode == 'envelope' or mode == 'body')) then
                local child = mode == 'envelope' and key == 'body' and 'body' or 'exact'

                if not sameSavedValue(value, sealRaw(b, key), child) then
                    return false
                end
            end
        end

        for key in sealNext, b do
            if not (key == 'revision' and (mode == 'envelope' or mode == 'body')) and sealRaw(a, key) == nil then
                return false
            end
        end

        return true
    end

    -- Saves an edited custom envelope over its stored one.
    -- @param reference string|table  An id string, or { kind, id } of a custom rotation.
    -- @param envelope table  The edited envelope; its id must not change.
    -- @return boolean  True when saved.
    -- @return string|nil  The reason code when false; nil otherwise.
    -- @return table|nil  The validation result when the envelope was not storable; nil otherwise.
    --
    -- For schema 1 the content revision moves only when the content changed and the envelope revision always increases.
    -- The save is refused with 'rotation-changed-externally' if the stored value changed while the revision was being
    -- prepared (that stage can call overridable helpers).
    function catalog:Save(reference, envelope)
        local key, why = owned(reference)

        if not key then
            return false, why
        end

        local copy, reason, validation = storable(envelope)

        if not copy then
            return false, reason, validation
        end
        if copy.id ~= key then
            return false, "id-mismatch"
        end

        local custom = state.custom
        local previous = custom[key]

        if copy.schemaVersion == 1 then
            local oldBody = sealType(previous) == 'table' and sealRaw(previous, 'body')
            local baseline

            if type(oldBody) == 'table' then
                baseline = savedSeal(previous)

                if not baseline then
                    return false, 'invalid-rotation-body'
                end
            end

            -- Whether the stored rotation is still the one that was read at the start of the save.
            -- @return boolean  True when unchanged.
            local function unchanged()
                return sealEqual(sealRaw(state, 'custom'), custom)
                    and (sealEqual(sealRaw(custom, key), previous) or sealType(previous) == 'number'
                        and previous ~= previous
                        and sealType(sealRaw(custom, key)) == 'number'
                        and sealRaw(custom, key) ~= sealRaw(custom, key))
                    and (not baseline or sameSavedValue(previous, baseline, 'exact'))
            end

            local comparison

            if baseline then
                local problem
                comparison, problem = data.CopyData(oldBody)

                if not comparison then
                    return false, problem and problem.code or 'invalid-rotation-body'
                end
                if not unchanged() then
                    return false, 'rotation-changed-externally'
                end
            end

            local changed = baseline and not sameSavedValue(baseline, copy, 'envelope') or false

            local body, problem = data.PrepareRotationContentRevision(
                copy.body,
                comparison,
                type(oldBody) == 'table' and 'edit' or 'create',
                changed
            )

            if not body then
                return false, problem
            end
            if not unchanged() then
                return false, 'rotation-changed-externally'
            end

            copy.body = body
            local revision = type(previous) == "table" and previous.revision

            if type(revision) == "number" and revision >= 1 and revision < 9007199254740991 and revision % 1 == 0 then
                copy.revision = revision + 1
            else
                copy.revision = 1
            end
        end

        state.custom[key] = copy
        return true
    end

    -- Adds a new custom envelope under its own id.
    -- @param envelope table  The envelope; an id that is a Built In or already saved is refused.
    -- @return boolean  True when added.
    -- @return string|nil  The reason code when false; nil otherwise.
    -- @return table|nil  The validation result when the envelope was not storable; nil otherwise.
    --
    -- Schema 1 bodies are stamped as an import.
    function catalog:AddCustom(envelope)
        local copy, why, validation = storable(envelope)

        if not copy then
            return false, why, validation
        end
        if builtins[copy.id] then
            return false, "read-only"
        end
        if state.custom[copy.id] ~= nil then
            return false, "duplicate-id"
        end

        local custom = state.custom

        if copy.schemaVersion == 1 then
            local body, reason = data.PrepareRotationContentRevision(copy.body, nil, 'import')

            if not body then
                return false, reason
            end

            copy.body = body
        end

        if not rawequal(state.custom, custom) then
            return false, 'rotation-changed-externally'
        end
        if builtins[copy.id] then
            return false, 'read-only'
        end
        if state.custom[copy.id] ~= nil then
            return false, 'duplicate-id'
        end

        state.custom[copy.id] = copy
        return true
    end

    -- Renames a custom rotation by saving it with the new name (the envelope name key and the body name both change).
    -- @param reference string|table  An id string, or { kind, id } of a custom rotation.
    -- @param name string  The new name; non-empty.
    -- @return boolean  True when renamed.
    -- @return string|nil  The reason code when false; nil otherwise.
    function catalog:Rename(reference, name)
        local key, why = owned(reference)

        if not key then
            return false, why
        end
        if type(name) ~= "string" or name == "" then
            return false, "invalid-name"
        end

        local view = self:Get({ kind = "custom", id = key })

        if not view.envelope or type(view.envelope.body) ~= "table" then
            return false, "invalid-envelope"
        end

        view.envelope.nameKey, view.envelope.body.name = name, name
        return self:Save({ kind = "custom", id = key }, view.envelope)
    end

    -- Deletes a custom rotation and its clone lineage.
    -- @param reference string|table  An id string, or { kind, id } of a custom rotation.
    -- @return boolean  True when deleted.
    -- @return string|nil  The reason code when false; nil otherwise.
    --
    -- Built Ins cannot be deleted.
    function catalog:Delete(reference)
        local key, why = owned(reference)

        if not key then
            return false, why
        end

        state.custom[key], state.lineage[key] = nil, nil
        return true
    end

    -- Marks a registered Built In as withdrawn.
    -- @param reference string|table  An id string, or { kind, id } of a Built In.
    -- @param reason string  The reason shown to the user; non-empty.
    -- @return boolean  True when withdrawn.
    -- @return string|nil  The reason code when false; nil otherwise.
    --
    -- A withdrawn Built In is never enabled.
    function catalog:WithdrawBuiltin(reference, reason)
        local kind, key = resolve(reference)

        if kind ~= "builtin" or not builtins[key] then
            return false, "unknown-built-in"
        end
        if type(reason) ~= "string" or reason == "" then
            return false, "missing-withdrawal-reason"
        end

        withdrawn[key] = reason
        return true
    end

    -- Clones a rotation as a new custom one.
    -- @param reference string|table  An id string, or { kind, id } of the rotation to clone.
    -- @param name string|nil  The optional new name.
    -- @return string|nil  The new id; nil on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- The clone has revision 1, fresh step ids and a lineage record (the source baseline plus a map from each new step
    -- id back to the original) that later source-versus-custom comparisons use. Every id already in use anywhere is
    -- reserved first.
    function catalog:Clone(reference, name)
        local source = self:Get(reference)

        if not source then
            return nil, "unknown-rotation"
        end
        if source.lineageError then
            return nil, "invalid-lineage"
        end
        if not source.validation.valid or not source.envelope or source.envelope.schemaVersion ~= 1 then
            return nil, "unsupported-source"
        end
        if type(options.newId) ~= "function" then
            return nil, "missing-id-provider"
        end
        if name ~= nil and (type(name) ~= "string" or name == "") then
            return nil, "invalid-name"
        end

        local used = {}

        for _, rows in ipairs({ builtins, state.custom }) do
            for key, envelope in pairs(rows) do
                used[key] = true

                if data.CheckPortable(envelope) then
                    data.ReserveRotationIdentities(envelope, used)
                end
            end
        end

        for key, retained in pairs(state.lineage) do
            used[key] = true
            data.ReserveRotationIdentities(retained, used)
        end

        if source.lineage and type(source.lineage.stepOrigins) == "table" then
            for _, origin in pairs(source.lineage.stepOrigins) do
                if id(origin) then
                    used[origin] = true
                end
            end
        end

        -- Allocates one unused id from the injected provider.
        -- @return string|nil  The id; nil when the provider fails or collides.
        -- @return string|nil  The reason code when the first return is nil; nil otherwise.
        local function fresh()
            local ok, value = pcall(options.newId)

            if not ok or not id(value) then
                return nil, "invalid-id-provider"
            end
            if used[value] then
                return nil, "id-collision"
            end

            used[value] = true
            return value
        end

        local newId, why = fresh()

        if not newId then
            return nil, why
        end

        local clone = source.envelope
        local baseline = source.lineage and source.lineage.baseline or data.CopyData(source.envelope)

        local lineage = {
            sourceId = source.lineage and source.lineage.sourceId or source.id,
            sourceKind = source.lineage and source.lineage.sourceKind or source.reference.kind,
            sourceRevision = source.lineage and source.lineage.sourceRevision or clone.revision,
            baseline = baseline,
            stepOrigins = {},
            clonedFrom = source.id,
        }

        clone.id, clone.revision = newId, 1
        clone.body.revision = 1

        if name then
            clone.nameKey, clone.body.name = name, name
        end

        local failed

        local indexed, indexError = steps(clone, function(step)
            if failed then
                return
            end

            local original = step.id
            local generated, reason = fresh()

            if not generated then
                failed = reason
                return
            end

            step.id = generated

            if source.lineage then
                lineage.stepOrigins[generated] = source.lineage.stepOrigins and source.lineage.stepOrigins[original]
            else
                lineage.stepOrigins[generated] = original
            end
        end)

        if not indexed then
            return nil, indexError and indexError.code or "invalid-priority-list"
        end
        if failed then
            return nil, failed
        end

        local cleanLineage, problem = data.CopyData(lineage)

        if not cleanLineage then
            return nil, problem.code
        end

        local ok, reason = self:AddCustom(clone)

        if not ok then
            return nil, reason
        end

        state.lineage[newId] = cleanLineage
        return newId
    end

    return catalog
end
