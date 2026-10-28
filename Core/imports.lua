-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Rotation import and export services: validates and stores an imported rotation (with its manifest and step origins),
-- applies a prepared import to a new or an existing custom rotation and refreshes the engine afterwards, and builds the
-- envelope that export serializes. It does not parse or encode text (Data/codec.lua and UI/transfer.lua do),
-- and it writes saved data only after every check has passed. Loaded after Core/rotation_tags.lua. When the scoped
-- coordinator exists it does the storage work; the profile-library branches below are the legacy path.

local _, addon = ...
local data = addon.RotationData
local activeCurrent = addon.IsActiveRotationTransitionCurrent
local beginActive = addon.BeginActiveRotationTransition
local prepareActivePublication, finishActivePublication

if type(addon.BindActiveRotationPublication) == 'function' then
    addon:BindActiveRotationPublication(function(prepare, finish)
        prepareActivePublication, finishActivePublication = prepare, finish
    end)
end

-- True for a plain table with no metatable; saved state that is anything else is treated as invalid.
local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

-- Returns the validation options an import runs under (the same ones the rest of the addon validates rotations with).
local function settings(self)
    local options = self:GetRotationValidationOptions()
    return options
end

-- Public alias of the import validation options, for the editors that validate a body the way an import would.
function addon:GetImportValidationOptions()
    return settings(self)
end

-- ============================================================================
-- Reading imported rotations
-- ============================================================================

-- Returns a view { envelope, applicability, validation, sourceId, sourceRevision, stepOrigins } of an imported
-- rotation, rebuilt from its retained manifest and current body, or nil and 'not-imported' / 'invalid-import-state'.
function addon:GetImportedRotationView(spec, id)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        return scoped:SourceView(spec, id, true)
    end

    local state = self.db.profile.rotationLibrary

    if state == nil then
        return nil, "not-imported"
    end
    if not plain(state) then
        return nil, "invalid-import-state"
    end
    if state.imports == nil then
        return nil, "not-imported"
    end
    if not plain(state.imports) then
        return nil, "invalid-import-state"
    end

    local rows = state.imports[spec]

    if rows == nil then
        return nil, "not-imported"
    end
    if not plain(rows) then
        return nil, "invalid-import-state"
    end
    if rows[id] == nil then
        return nil, "not-imported"
    end

    local record, why = data.CopyData(rows[id])

    if
        why
        or not plain(record)
        or not plain(record.manifest)
        or record.manifest.id ~= id
        or type(record.sourceId) ~= "string"
        or not plain(record.stepOrigins)
    then
        return nil, "invalid-import-state"
    end

    local body = self:GetEditableRotation(spec, id)
    local envelope = data.CopyData(record.manifest)
    envelope.body = data.CopyData(body)

    if not envelope.body then
        return nil, "invalid-import-state"
    end

    return {
        envelope = envelope,
        applicability = envelope.applicability,
        enabled = true,
        validation = data.ValidateEnvelope(envelope, settings(self)),
        sourceId = record.sourceId,
        sourceRevision = record.sourceRevision,
        stepOrigins = record.stepOrigins,
    }
end

-- ============================================================================
-- Creating and applying imports
-- ============================================================================

-- Stores a prepared import as a custom rotation under `spec` and returns its new (or replaced) id, nil, nil and the
-- active transition. `replacement` ({ id, valid }) overwrites that rotation instead. Returns nil and a reason when
-- validation or any ownership re-check fails; nothing is written until every id is allocated and every check passed.
function addon:CreateImportedRotation(prepared, spec, name, replacement, options)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        return scoped:Import(prepared, spec, name, replacement, options)
    end
    if type(spec) ~= "number" or spec < 0 or spec % 1 ~= 0 then
        return nil, "invalid-specialization"
    end
    if type(name) ~= "string" or #name == 0 or #name > 256 then
        return nil, "invalid-name"
    end

    local profile = self.db.profile
    local rotationsRoot = profile.rotations

    if rotationsRoot ~= nil and not plain(rotationsRoot) then
        return nil, "invalid-rotation-storage"
    end
    if rotationsRoot and rotationsRoot[spec] ~= nil and not plain(rotationsRoot[spec]) then
        return nil, "invalid-rotation-storage"
    end

    local body, problem = data.CopyData(prepared.body)

    if problem or not plain(body) then
        return nil, "invalid-import"
    end

    local manifest = prepared.manifest and data.CopyData(prepared.manifest)

    if prepared.manifest and not manifest then
        return nil, "invalid-import"
    end

    local result

    if manifest then
        local envelope = data.CopyData(manifest)
        envelope.body = body
        result = data.ValidateEnvelope(envelope, settings(self))
    else
        result = data.ValidateBody(body, settings(self))
    end

    if not result.valid or not result.supported or not result.resolved then
        return nil, "import-not-ready"
    end

    local ok, why = self:InitializeRotationLibrary()

    if not ok then
        return nil, why
    end

    local state = self.db.profile.rotationLibrary

    for _, kind in ipairs({ "origins", "comparisons", "imports" }) do
        if state[kind][spec] ~= nil and not plain(state[kind][spec]) then
            return nil, "invalid-import-state"
        end
    end

    local used = {}

    -- Reserve identities in live bodies and retained provenance; never discard
    -- malformed unrelated saved data while allocating a new rotation.
    -- Marks every string in the value as an identity already in use, so a fresh id cannot collide with any of them.
    local function reserve(value)
        if type(value) == "string" then
            used[value] = true
        elseif type(value) == "table" then
            for key, child in pairs(value) do
                reserve(key)
                reserve(child)
            end
        end
    end

    for _, rotations in pairs(rotationsRoot or {}) do
        if plain(rotations) then
            for id, rotation in pairs(rotations) do
                used[id] = true
                local copy = data.CopyData(rotation)

                if copy then
                    reserve(copy)
                end
            end
        end
    end

    for _, kind in ipairs({ "origins", "comparisons", "imports" }) do
        for _, rows in pairs(state[kind]) do
            if plain(rows) then
                for id, record in pairs(rows) do
                    used[id] = true
                    local copy = data.CopyData(record)

                    if copy then
                        reserve(copy)
                    end
                end
            end
        end
    end

    for _, row in ipairs(self:ListDefaultRotations(spec)) do
        reserve(row.envelope)
    end

    reserve(body)
    reserve(manifest)

    -- Allocates a new unused id from the id provider. Returns the id, or nil and a reason code.
    local function fresh()
        local success, id = pcall(self.uuid)

        if not success or type(id) ~= "string" or #id > 128 or not id:match("^[%w][%w._:%-]*$") then
            return nil, "invalid-id-provider"
        end
        if used[id] then
            return nil, "id-collision"
        end

        used[id] = true
        return id
    end

    local id, errorCode

    if replacement then
        id = replacement.id
    else
        id, errorCode = fresh()
    end

    if not id then
        return nil, errorCode
    end

    local sourceId = prepared.sourceId or manifest and manifest.id
    local sourceRevision = prepared.sourceRevision or manifest and manifest.revision
    local origins = {}
    local tree, treeError = data.IndexRotationSteps(body)

    if not tree then
        return nil, treeError.code
    end

    for _, row in ipairs(tree.rows) do
        local step = row.step
        local stepId, reason = fresh()

        if not stepId then
            return nil, reason
        end

        origins[stepId] = prepared.stepOrigins and prepared.stepOrigins[step.id] or step.id
        step.id = stepId
    end

    body.name = name
    local previous = replacement and self:GetEditableRotation(spec, id) or nil

    local revised, revisionError = data.PrepareRotationContentRevision(
        body,
        previous,
        replacement and 'edit' or 'import',
        replacement ~= nil
    )

    if not revised then
        return nil, revisionError
    end

    body = revised

    if manifest then
        manifest.id = id
        manifest.revision = 1
        manifest.nameKey = name
    end

    local publication = prepareActivePublication and prepareActivePublication(spec, id, nil, nil, body)

    -- Commit only after every validation/copy/allocation succeeds. Imported
    -- bodies have one saved home; the manifest contains no duplicate body.
    if replacement and not replacement.valid() then
        return nil, 'rotation-changed-externally'
    end
    if self.db.profile ~= profile or profile.rotations ~= rotationsRoot or profile.rotationLibrary ~= state then
        return nil, 'rotation-changed-externally'
    end

    local rotations = rotationsRoot and rotationsRoot[spec] or {}

    if replacement and rotations[id] ~= previous then
        return nil, 'rotation-changed-externally'
    end
    if not replacement and rotations[id] ~= nil then
        return nil, 'id-collision'
    end

    self.db.profile.rotations = rotationsRoot or {}
    self.db.profile.rotations[spec] = rotations
    rotations[id] = body

    if replacement then
        for _, kind in ipairs({ 'origins', 'comparisons', 'imports' }) do
            if type(state[kind][spec]) == 'table' then
                state[kind][spec][id] = nil
            end
        end
    end

    if manifest then
        local rows = state.imports[spec] or {}
        state.imports[spec] = rows
        rows[id] = { manifest = manifest, sourceId = sourceId, sourceRevision = sourceRevision, stepOrigins = origins }
    end

    local transition

    if finishActivePublication then
        local _, change = finishActivePublication(publication)
        transition = change
    end

    return id, nil, nil, transition
end

-- Deep equality of two plain data trees, used to detect that a rotation changed since the import was previewed.
local function equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= 'table' then
        return a == b
    end

    for key, value in pairs(a) do
        if not equal(value, b[key]) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end

-- Applies the import held by `session` (identified by `token`) as a new rotation, or over `target` when given.
-- `expected` is what the caller saw when it previewed the replacement; if the rotation, its profile or its record
-- changed, or it has unsaved edits open, nothing is written. Returns the id, or nil and a reason ('rotation-changed-
-- externally', 'rotation-has-unsaved-changes', ...). Afterwards it refreshes autoswitch, the active rotation and glows.
function addon:ApplyRotationImport(session, token, spec, name, target, expected, options)
    local change = beginActive(self)

    -- True while no newer rotation transition has superseded this import's. Checked after every step that can call
    -- out.
    local function current()
        return activeCurrent(self, change)
    end

    -- Calls a method that may not be loaded yet, re-reading it after the first check. Returns whether this import is
    -- still current.
    local function optional(name, ...)
        local available = self[name]

        if not current() then
            return false
        end

        if available then
            local method = self[name]

            if not current() then
                return false
            end

            method(self, ...)
        end

        return current()
    end

    -- Re-selects the rotation through SwitchRotation and adopts the transition it returns. Returns whether this import
    -- is still current.
    local function switch()
        local available = self.SwitchRotation

        if not current() then
            return false
        end

        if available then
            local method = self.SwitchRotation

            if not current() then
                return false
            end

            local _, nextChange = method(self)
            change = nextChange or change
        end

        return current()
    end

    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        local prepared, why = session:GetReady(token)

        if not prepared then
            return nil, why
        end
        if not target then
            return self:CreateImportedRotation(prepared, spec, name, nil, options)
        end

        local reference, referenceReason = scoped:Resolve(spec, target)

        if not reference then
            return nil, referenceReason
        end
        if reference.kind ~= 'custom' then
            return nil, 'read-only-rotation'
        end
        if type(expected) ~= 'table' or expected.profile ~= self.db.profile then
            return nil, 'rotation-changed-externally'
        end

        local workspace = self.GetRotationWorkspace and self:GetRotationWorkspace(spec, reference)

        if workspace and workspace:IsDirty() then
            return nil, 'rotation-has-unsaved-changes'
        end

        local record, token = scoped:Snapshot(spec, reference)

        if not record then
            return nil, token
        end

        if expected.recordToken then
            if not equal(expected.reference, reference) then
                return nil, 'rotation-changed-externally'
            end

            token = expected.recordToken
        else
            local original = self:GetEditableRotation(spec, reference)

            if
                expected.target ~= original or not data.CheckPortable(original) or not equal(original, expected.body)
            then
                return nil, 'rotation-changed-externally'
            end
        end

        local id, commitReason, saved, transition = self:CreateImportedRotation(
            prepared,
            spec,
            record.body.name or name,
            { profile = self.db.profile, reference = reference, recordToken = token },
            options
        )

        if not id then
            return nil, commitReason
        end

        change = transition or change

        if not current() then
            return id, nil, saved
        end
        if not optional('UpdateAutoSwitch') then
            return id, nil, saved
        end
        if not current() then
            return id, nil, saved
        end
        if not switch() then
            return id, nil, saved
        end
        if not current() then
            return id, nil, saved
        end

        optional('EvaluateNextAction')
        return id, nil, saved
    end

    local prepared, why = session:GetReady(token)

    if not prepared then
        return nil, why
    end
    if not target then
        return self:CreateImportedRotation(prepared, spec, name)
    end

    local profile = self.db.profile
    local original = self:GetEditableRotation(spec, target)

    -- True while the rotation being replaced is still the exact record and profile the caller previewed.
    local function valid()
        return self.db.profile == profile
            and type(expected) == 'table'
            and expected.profile == profile
            and expected.target == original
            and original ~= nil
            and self:GetEditableRotation(spec, target) == original
            and equal(original, expected.body)
            and not self:GetDefaultIdForRuntime(spec, target)
    end

    if not valid() then
        return nil, 'rotation-changed-externally'
    end

    if self.GetRotationWorkspace then
        local workspace = self:GetRotationWorkspace(spec, target)

        if workspace and workspace:IsDirty() then
            return nil, 'rotation-has-unsaved-changes'
        end
    end

    local id, reason, _, transition = self:CreateImportedRotation(prepared, spec, original.name or name, {
        id = target,
        valid = valid,
    })

    if not id then
        return nil, reason
    end

    change = transition or change

    if not current() then
        return id
    end

    if self.currentSpec == spec and self.currentRotation == target then
        local available = self.RemoveAllCurrentGlows

        if not current() then
            return id
        end

        if available then
            local remove = self.RemoveAllCurrentGlows

            if not current() then
                return id
            end

            remove(self)
        elseif not optional('GlowClear') then
            return id
        end

        if not current() then
            return id
        end

        self.currentSpell = nil
        self.avail_announced = {}
        self.announced = {}
        self.skipAnnounce = true
    end

    if not optional('UpdateAutoSwitch') then
        return id
    end
    if not current() then
        return id
    end
    if not switch() then
        return id
    end
    if not current() then
        return id
    end

    optional('EvaluateNextAction')
    return id
end

-- Specializations across accounts. Where body.specs holds talent groups
-- (dual-specialization clients, Platform/specializations.lua), group 2 on
-- one character is not group 2 on another: an export carries no specs and an
-- import is for the talent group it is imported into (chosen by the caller,
-- the Rotations list's specialization; else the one you are playing). A
-- replacement keeps the replaced rotation's own specs. Where it holds
-- specialization IDs they travel as they are, and a rotation only for
-- another class's specializations is refused like any other class mismatch.
-- Removes the body's specs when this client keeps talent groups (slot kind), since slot numbers do not travel between
-- characters. Returns the body.
local function stripSlotSpecs(self, body)
    if
        type(body) == 'table'
        and body.specs ~= nil
        and self.GetRotationSpecKind
        and self:GetRotationSpecKind() ~= 'portable'
    then
        body.specs = nil
    end

    return body
end

-- Decides which specs an imported rotation gets on this client. Returns the spec list (possibly nil), or nil and
-- 'invalid-import' / 'class-mismatch'. Talent-group clients use the caller's choice or the current group; other
-- clients keep the incoming specs and refuse ones that belong only to another class.
function addon:PrepareImportedRotationSpecs(specs, chosen, replacement)
    local kind = self.GetRotationSpecKind and self:GetRotationSpecKind()

    if kind == 'slot' then
        if replacement then
            return nil
        end
        if type(chosen) == 'table' then
            return data.NormalizeRotationSpecs(chosen) or nil
        end
        if type(chosen) == 'number' then
            return { chosen }
        end

        local value = self:GetCurrentRotationSpecValue()
        return value ~= nil and { value } or nil
    end

    local normalized = data.NormalizeRotationSpecs(specs)

    if normalized == false then
        return nil, 'invalid-import'
    end

    if kind == 'portable' and normalized and self.GetSpecializationClassToken then
        local class

        if type(UnitClass) == 'function' then
            local ok, _, token = pcall(UnitClass, 'player')

            -- UnitClass is a game value: use it only after Platform:CanReadValue accepts it (restricted clients).
            if ok and self.Platform:CanReadValue(token) and type(token) == 'string' then
                class = token
            end
        end

        local mine, known = false, false

        for _, value in ipairs(normalized) do
            local owner = self:GetSpecializationClassToken(value)

            if owner then
                known = true

                if owner == class then
                    mine = true
                end
            end
        end

        if known and not mine and class then
            return nil, 'class-mismatch'
        end
    end

    return normalized
end

-- ============================================================================
-- Export
-- ============================================================================

-- Builds the export envelope for a rotation: its Built In, sourced or imported envelope when it has one, else the
-- bare body, with talent-group specs removed and body tags mirrored onto the envelope. Returns nil and a reason on
-- failure.
local function exportData(self, spec, id)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        local record, why = scoped:Snapshot(spec, id)

        if not record then
            return nil, why
        end

        local result

        if record.source then
            result = record.source.envelope
        elseif record.origin or record.imported then
            local retained = record.origin or record.imported
            result = data.CopyData(retained.manifest)
            result.body = record.body
        else
            return stripSlotSpecs(self, record.body)
        end

        stripSlotSpecs(self, result.body)

        if result.body.tags ~= nil then
            result.tags = data.CopyData(result.body.tags)
        end

        return result
    end

    -- Returns a copy of the envelope whose tags match the body's current tags (the body is where edits land).
    local function currentTags(envelope)
        if type(envelope) == 'table' and type(envelope.body) == 'table' and envelope.body.tags ~= nil then
            local copy, why = data.CopyData(envelope)

            if not copy then
                return nil, why
            end

            copy.tags = data.CopyData(copy.body.tags)
            return copy
        end

        return envelope
    end

    local defaultId = self:GetDefaultIdForRuntime(spec, id)

    if defaultId then
        return currentTags(self:GetDefaultRotation(defaultId).envelope)
    end

    local source, why = self:GetSourcedRotationView(spec, id)

    if source then
        return currentTags(source.envelope)
    end
    if why ~= "no-source-baseline" then
        return nil, why
    end

    local imported, reason = self:GetImportedRotationView(spec, id)

    if imported then
        return currentTags(imported.envelope)
    end
    if reason ~= "not-imported" then
        return nil, reason
    end

    return stripSlotSpecs(self, data.CopyData(self:GetEditableRotation(spec, id)))
end

-- A Built In's envelope carries its name as a locale key (nameKey), and every importer shows that as the name. The
-- export names the rotation in the exporting client's language (body.name); nameKey stays, it is what the envelope is.
local function exportName(self, exported)
    if type(exported) ~= 'table' then
        return exported
    end

    local body = type(exported.body) == 'table' and exported.body or exported
    local name = self:RotationDisplayName(exported)

    if not name or name == body.name or name == exported.nameKey then
        return exported
    end

    local copy = data.CopyData(exported)

    if not copy then
        return exported
    end

    local target = type(copy.body) == 'table' and copy.body or copy
    target.name = name
    return copy
end

-- Returns the export envelope or body for a rotation, named for the exporting client's language; or nil and a reason.
function addon:GetRotationExportData(spec, id)
    local exported, why = exportData(self, spec, id)
    return exportName(self, exported), why
end
