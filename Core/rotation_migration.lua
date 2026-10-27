-- Rotation storage migrations: the one-way move of legacy profile rotation roots into the scoped rotation store, the
-- two in-place renames that follow it (body.handle to body.identifier, specialization evidence into body.specs), and
-- the plan/apply pairs for adopting an unassigned rotation into a class or character scope. Planning never writes;
-- each apply re-checks that nothing moved since its plan and refuses with a 'stale-...' reason otherwise. The scoped
-- migration is not reversible (docs/dev/architecture.md, "Saved data"). Loaded after Core/rotation_scope.lua; started
-- by InitializeScopedRotationStorage from Core/rotation_lifecycle.lua once the database exists.

local _, addon = ...
local data = addon.RotationData
local prepareRootRebind, runRootRebind
local activeCurrent = addon.IsActiveRotationTransitionCurrent

if type(addon.BindActiveRotationProfileRebind) == 'function' then
    addon:BindActiveRotationProfileRebind(function(prepare, run)
        prepareRootRebind, runRootRebind = prepare, run
    end)
end

-- Private plan records, keyed weakly by the opaque table a caller holds: only a plan this module made can be applied.
local migrations, adoptions = setmetatable({}, { __mode = 'k' }), setmetatable({}, { __mode = 'k' })

-- ============================================================================
-- Helpers
-- ============================================================================

-- True for a plain table with no metatable; anything else in saved state is treated as invalid.
local function plain(v)
    return type(v) == 'table' and getmetatable(v) == nil
end

-- True for a usable identifier string: 1 to 128 characters, not blank, no control characters.
local function text(v)
    return type(v) == 'string' and #v > 0 and #v <= 128 and v:find('%S') ~= nil and not v:find('[%z\1-\31\127]')
end

-- Deep copy of a data tree that preserves shared and cyclic references. Unlike data.CopyData it does no validation.
local function clone(v, seen)
    if type(v) ~= 'table' then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local result = {}
    seen[v] = result

    for k, child in pairs(v) do
        result[k] = clone(child, seen)
    end

    return result
end

-- Deep equality of two data trees.
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end

    for k, v in pairs(a) do
        if not same(v, b[k]) then return false end
    end

    for k in pairs(b) do
        if a[k] == nil then return false end
    end

    return true
end

-- Collects the four legacy roots of a profile (rotations, origins, imports, comparisons), each {} when absent. Returns
-- nil and a reason when the library or any root is not plain data.
local function legacy(profile)
    local library = profile.rotationLibrary
    if library ~= nil and not plain(library) then return nil, 'invalid-library-state' end
    local result = {}

    for _, kind in ipairs({ 'rotations', 'origins', 'imports', 'comparisons' }) do
        local value

        if kind == 'rotations' then
            value = profile.rotations
        elseif library then
            value = library[kind]
        end

        if value ~= nil and not plain(value) then return nil, 'invalid-legacy-state' end
        result[kind] = value == nil and {} or value
    end

    return result
end

-- Builds the replacement rotationLibrary kept after migration: empty provenance maps plus a detached copy of every
-- other key. Returns nil and a reason when a value cannot be copied.
local function retiredLibrary(library)
    if not library then return nil end
    local result = { origins = {}, imports = {}, comparisons = {} }

    for key, value in pairs(library) do
        if key ~= 'origins' and key ~= 'imports' and key ~= 'comparisons' then
            local detached, why = data.CopyData(value)
            if why then return nil, why.code end
            result[key] = detached
        end
    end

    return result
end

-- True when a map of per-spec row tables holds any row (or any non-table value).
local function nonempty(map)
    if type(map) ~= 'table' then return map ~= nil end

    for _, rows in pairs(map) do
        if type(rows) ~= 'table' or next(rows) ~= nil then return true end
    end

    return false
end

-- ============================================================================
-- Legacy roots to the scoped store
-- ============================================================================

-- Plans the move of a profile's legacy rotation roots into rotationStore. Returns an opaque plan
-- ({ unchanged = bool }), or nil and a reason ('missing-fallback-configuration', 'conflicting-legacy-rotation-roots',
-- ...). A profile that already has a store plans as unchanged but must have no legacy rows left over. Writes nothing.
function addon:PlanRotationProfileMigration(profile, fallbackID)
    if type(profile) ~= 'table' then return nil, 'invalid-profile' end
    local old, legacyReason = legacy(profile)
    if not old then return nil, legacyReason end

    if profile.rotationStore ~= nil then
        if not text(profile.rotationFallbackID) then return nil, 'missing-fallback-configuration' end
        local valid, why = data.ValidateRotationStore(profile.rotationStore)
        if not valid then return nil, why end

        for _, map in pairs(old) do
            if nonempty(map) then return nil, 'conflicting-legacy-rotation-roots' end
        end

        local public = { unchanged = true }
        migrations[public] = { profile = profile, store = profile.rotationStore, fallback = profile.rotationFallbackID }
        return public
    end

    if not text(fallbackID) then return nil, 'missing-fallback-configuration' end
    local proposed, planReason = data.PlanRotationStoreMigration(old)
    if not proposed then return nil, planReason end
    local public = { unchanged = false }

    migrations[public] = {
        profile = profile,
        store = nil,
        fallback = fallbackID,
        proposed = proposed,
        rotations = profile.rotations,
        library = profile.rotationLibrary,
        baseline = proposed.legacy,
        previousFallback = profile.rotationFallbackID,
    }

    return public
end

-- Applies a plan from PlanRotationProfileMigration. Returns true, or nil and a reason ('stale-migration-plan' when the
-- profile changed since planning). The old roots are archived into the store before they are emptied, and the profile
-- version becomes 3. A plan can be applied once.
function addon:ApplyRotationProfileMigration(public)
    local plan = migrations[public]
    if not plan then return nil, 'invalid-migration-plan' end
    local profile = plan.profile

    if plan.store then
        if profile.rotationStore ~= plan.store or profile.rotationFallbackID ~= plan.fallback then
            return nil, 'stale-migration-plan'
        end

        local valid, why = data.ValidateRotationStore(plan.store)
        if not valid then return nil, why end
        local old, legacyReason = legacy(profile)
        if not old then return nil, legacyReason end

        for _, map in pairs(old) do
            if nonempty(map) then return nil, 'conflicting-legacy-rotation-roots' end
        end

        migrations[public] = nil
        return true
    end

    if
        profile.rotationStore ~= nil
        or profile.rotations ~= plan.rotations
        or profile.rotationLibrary ~= plan.library
        or profile.rotationFallbackID ~= plan.previousFallback
    then
        return nil, 'stale-migration-plan'
    end

    local old, legacyReason = legacy(profile)
    if not old then return nil, legacyReason end
    local checked, checkReason = data.PlanRotationStoreMigration(old)
    if not checked then return nil, checkReason end
    if not same(checked.legacy, plan.baseline) then return nil, 'stale-migration-plan' end
    local replacement, libraryReason = retiredLibrary(profile.rotationLibrary)
    if libraryReason then return nil, libraryReason end
    -- Archive all four roots before retiring their old active homes. Ownership
    -- remains unknown even when a retained manifest happens to declare a class.
    profile.rotationStore = plan.proposed
    profile.rotationFallbackID = plan.fallback
    profile.rotations = {}
    if profile.rotationLibrary then profile.rotationLibrary = replacement end
    profile.version = 3
    migrations[public] = nil
    return true
end

-- body.handle was renamed body.identifier. Move a saved one across (a body
-- already holding an identifier keeps it), in every stored body of a profile:
-- owned records and their source baselines, the preserved legacy map and the
-- flat pre-scope map. Idempotent and cheap, so it runs on every refresh and
-- also catches an old profile imported later.
-- ============================================================================
-- Handle to identifier rename
-- ============================================================================

local function moveHandle(body)
    if not plain(body) or body.handle == nil then return end
    if body.identifier == nil then body.identifier = body.handle end
    body.handle = nil
end

-- Renames the handle on the baseline body that a lineage sidecar (origin or import record) retains.
local function moveSidecar(sidecar)
    if plain(sidecar) and plain(sidecar.lineage) then moveHandle(sidecar.lineage.baseline) end
end

-- Calls visit(value) for every value of every per-spec row table in map; non-plain levels are skipped.
local function eachRow(map, visit)
    if not plain(map) then return end

    for _, rows in pairs(map) do
        if plain(rows) then
            for _, value in pairs(rows) do
                visit(value)
            end
        end
    end
end

-- Renames the handle on a stored record's body and on the baselines of its origin and import sidecars.
local function moveRecord(record)
    if not plain(record) then return end
    moveHandle(record.body)
    moveSidecar(record.origin)
    moveSidecar(record.imported)
end

-- Applies the handle rename to every stored body of a profile (see above). Safe to run repeatedly.
function addon:MoveRotationHandlesToIdentifiers(profile)
    if not plain(profile) then return end
    local store = profile.rotationStore

    if plain(store) then
        if plain(store.classes) then
            for _, map in pairs(store.classes) do
                eachRow(map, moveRecord)
            end
        end

        if plain(store.characters) then
            for _, bucket in pairs(store.characters) do
                if plain(bucket) then eachRow(bucket.specs, moveRecord) end
            end
        end

        if plain(store.legacy) then
            eachRow(store.legacy.rotations, moveHandle)
            eachRow(store.legacy.origins, moveSidecar)
            eachRow(store.legacy.imports, moveSidecar)
        end
    end

    eachRow(profile.rotations, moveHandle)
end

-- A rotation's specializations became its own property (body.specs). This
-- moves the old evidence into it once per profile, then marks the profile
-- (rotationSpecsMigrated), because an absent body.specs afterwards means
-- "any specialization" by choice:
--   * Where the saved namespace is a specialization value (Retail: the
--     specialization ID; Wrath and Cataclysm Classic: the talent group), a
--     rotation saved under it was only ever offered there, so it gets that
--     value. The fallback stays tied to its namespace and is left alone.
--   * Where SPECIALIZATION reads the game's specialization ID (Retail, Mists
--     of Pandaria Classic), a switch condition of exactly one of the shapes
--     that used to file a Built In under a specialization moves into
--     body.specs: SPECIALIZATION itself, an OR of only SPECIALIZATION, or an
--     AND with one SPECIALIZATION child (the rest stays; an AND left with one
--     child becomes that child). A switch left with nothing is left empty: no
--     switch condition matches whenever the rotation otherwise applies, which
--     is what a switch of only a specialization did. Anything
--     else (under NOT, mixed into an OR, two different ones in an AND, a
--     disabled one) stays an ordinary condition. On Retail the switch's
--     specializations must include the namespace's, which is what stays.
--   * Elsewhere (Era, TBC, Forever, and the talent-group namespaces of Mists
--     Classic) SPECIALIZATION tests talent trees or is unavailable, and the
--     namespace is not a specialization, so nothing moves.
-- ============================================================================
-- Specializations as a rotation property
-- ============================================================================

-- True for an enabled SPECIALIZATION condition with a valid numeric spec; these are the only leaves that may move.
local function specCondition(c)
    return plain(c)
        and c.type == 'SPECIALIZATION'
        and not c.disabled
        and type(c.spec) == 'number'
        and c.spec >= 0
        and c.spec % 1 == 0
end

-- Splits a switch condition into the specializations it only existed to select and the condition that remains.
-- Returns specs, remainder (remainder {} when nothing is left), or nil when the switch is not one of the movable
-- shapes. Works on copies; the switch is not modified.
function addon:SplitSwitchSpecializations(switch)
    if not plain(switch) or switch.disabled then return nil end
    if specCondition(switch) then return { switch.spec }, {} end
    if not plain(switch.value) then return nil end

    if switch.type == 'OR' then
        local specs = {}

        for i, child in ipairs(switch.value) do
            if not specCondition(child) then return nil end
            specs[i] = child.spec
        end

        if #specs == 0 then return nil end
        return data.NormalizeRotationSpecs(specs), {}
    elseif switch.type == 'AND' then
        local spec, rest

        for _, child in ipairs(switch.value) do
            if specCondition(child) then
                if spec and spec ~= child.spec then return nil end
                spec = child.spec
            else
                rest = rest or {}
                rest[#rest + 1] = clone(child)
            end
        end

        if not spec then return nil end
        if not rest then return { spec }, {} end
        if #rest == 1 then return { spec }, rest[1] end
        local remainder = clone(switch)
        remainder.value = rest
        return { spec }, remainder
    end
end

-- Fills body.specs of one stored body from the namespace key it is saved under (when that key is a specialization
-- value) or from its switch condition, removing the part of the switch that moved. A body that already has specs is
-- left alone.
local function migrateBody(owner, body, key, kind, keyIsValue)
    if not plain(body) or body.specs ~= nil then return end
    local specs, remainder
    if kind == 'portable' then specs, remainder = owner:SplitSwitchSpecializations(body.switch) end

    if keyIsValue and key ~= 0 then
        if specs then
            local found = false

            for _, value in ipairs(specs) do
                if value == key then
                    found = true
                    break
                end
            end

            if found then body.switch = remainder end
        end

        body.specs = { key }
    elseif specs then
        body.specs = specs
        body.switch = remainder
    end
end

-- Runs the specialization migration once per profile and marks it (rotationSpecsMigrated). Returns true when it ran,
-- false when it was already done or the store or client kind is not ready. The fallback rotation is never touched.
function addon:MoveRotationSpecsToProperty(profile)
    if not plain(profile) or profile.rotationSpecsMigrated then return false end
    local platform = self.Platform
    local kind = platform and platform.GetRotationSpecKind and platform:GetRotationSpecKind()
    if not kind then return false end
    local keyIsValue = platform:RotationKeyIsSpecValue() == true
    local store = profile.rotationStore
    if not plain(store) then return false end
    local fallback = profile.rotationFallbackID

    -- Migrates every body in a map keyed by numeric specialization namespace, skipping the fallback rotation.
    local function each(map)
        if not plain(map) then return end

        for key, rows in pairs(map) do
            if type(key) == 'number' and plain(rows) then
                for id, record in pairs(rows) do
                    if id ~= fallback and plain(record) then migrateBody(self, record.body, key, kind, keyIsValue) end
                end
            end
        end
    end

    if plain(store.classes) then
        for _, map in pairs(store.classes) do
            each(map)
        end
    end

    if plain(store.characters) then
        for _, bucket in pairs(store.characters) do
            if plain(bucket) then each(bucket.specs) end
        end
    end

    profile.rotationSpecsMigrated = true
    return true
end

-- Explicit startup entry point; the caller activates it only when every UI and
-- runtime route is ready. Profiles migrate independently; char archives stay put.
-- ============================================================================
-- Startup entry point
-- ============================================================================

-- Returns ok, reason and a per-profile list of { profile, ok, reason } results. Order matters: handles are renamed
-- first, then each profile (all saved ones, then the active one if it was not among them) is migrated to the scoped
-- store, then specs are moved, and only then is the active profile bound. A profile that fails to migrate does not stop
-- the others.
function addon:InitializeScopedRotationStorage()
    for _, profile in pairs(self.db.sv and self.db.sv.profiles or {}) do
        self:MoveRotationHandlesToIdentifiers(profile)
    end

    self:MoveRotationHandlesToIdentifiers(self.db.profile)
    local results = {}
    local visited = {}

    for name, profile in pairs(self.db.sv and self.db.sv.profiles or {}) do
        visited[profile] = true
        local plan, why = self:PlanRotationProfileMigration(profile, profile.rotationFallbackID or DEFAULT)
        local ok
        if plan then ok, why = self:ApplyRotationProfileMigration(plan) end
        results[#results + 1] = { profile = name, ok = ok == true, reason = why }
    end

    if not visited[self.db.profile] then
        local p = self.db.profile
        local plan, why = self:PlanRotationProfileMigration(p, p.rotationFallbackID or DEFAULT)
        local ok
        if plan then ok, why = self:ApplyRotationProfileMigration(plan) end
        results[#results + 1] = { profile = false, ok = ok == true, reason = why }
    end

    for _, profile in pairs(self.db.sv and self.db.sv.profiles or {}) do
        self:MoveRotationSpecsToProperty(profile)
    end

    self:MoveRotationSpecsToProperty(self.db.profile)
    local ok, why = self:BindRotationProfile()
    return ok, why, results
end

-- ============================================================================
-- Unassigned rotations and adoption
-- ============================================================================

-- Returns the saved character record for the current character, the owner context and the character root, or nil and a
-- reason when the owner context is unavailable.
local function currentCharacter(owner)
    local c, why = owner:GetRotationOwnerContext()
    if not c or not c.character then return nil, why or 'missing-owner-context' end
    local root = owner.db.sv and owner.db.sv.char
    local char = root and root[c.character]
    return char, c, root
end

-- True for a selection table with exactly kind ('profile' or 'character'), a valid spec number and an id.
local function validSelection(selection)
    if
        not plain(selection)
        or (selection.kind ~= 'profile' and selection.kind ~= 'character')
        or type(selection.spec) ~= 'number'
        or selection.spec < 0
        or selection.spec == math.huge
        or selection.spec % 1 ~= 0
        or not text(selection.id)
    then
        return false
    end

    for key in pairs(selection) do
        if key ~= 'kind' and key ~= 'spec' and key ~= 'id' then return false end
    end

    return true
end

-- Inspection is a detached recovery boundary, never an ownership decision or
-- an adoption. Orphan source components remain available without a body.
-- Returns a detached record ({ body, ... }) for one unassigned rotation, or nil and a reason such as
-- 'unknown-rotation'. Read only.
function addon:GetUnassignedRotationSnapshot(selection)
    if not validSelection(selection) then return nil, 'invalid-legacy-selection' end
    local coordinator = self:GetScopedRotationCoordinator()
    if not coordinator then return nil, 'rotation-profile-not-bound' end
    local ready, why = coordinator:CheckReady()
    if not ready then return nil, why end
    local context, contextReason = self:GetRotationOwnerContext()
    if not context then return nil, contextReason end

    if selection.kind == 'profile' then
        local rows, reason = coordinator:Unassigned()
        if not rows then return nil, reason end

        for _, row in ipairs(rows) do
            if row.address.spec == selection.spec and row.address.id == selection.id then return row.record end
        end
    else
        local char, c = currentCharacter(self)
        if not char then return nil, type(c) == 'string' and c or 'unknown-rotation' end
        if not plain(char) then return nil, 'invalid-legacy-state' end
        local archive, reason = data.PlanRotationStoreMigration({ rotations = char.rotations })
        if not archive then return nil, reason end
        local rows = archive.legacy.rotations and archive.legacy.rotations[selection.spec]
        local body = rows and rows[selection.id]
        if body ~= nil then return { body = body } end
    end

    return nil, 'unknown-rotation'
end

-- Lists rotations that have no owner yet: those left in the profile after migration and those archived under the
-- current character. Returns rows { selection, kind, spec, id, name, hasBody, validation } sorted by kind, spec, id; or
-- nil and a reason. Read only.
function addon:ListUnassignedRotations()
    local coordinator = self:GetScopedRotationCoordinator()
    if not coordinator then return nil, 'rotation-profile-not-bound' end
    local ready, readinessReason = coordinator:CheckReady()
    if not ready then return nil, readinessReason end
    local rows, why = coordinator:Unassigned()
    if not rows then return nil, why end
    local result = {}

    -- Appends one list row for an unassigned rotation, naming it by its body name or else its id.
    local function add(kind, number, id, record, validation)
        local body = record.body

        result[#result + 1] = {
            selection = { kind = kind, spec = number, id = id },
            kind = kind,
            spec = number,
            id = id,
            name = type(body) == 'table' and type(body.name) == 'string' and body.name or id,
            hasBody = body ~= nil,
            validation = validation,
        }
    end

    for _, row in ipairs(rows) do
        add('profile', row.address.spec, row.address.id, row.record, row.validation)
    end

    local char, c = currentCharacter(self)

    if char and char.rotations ~= nil then
        local proposed, why = data.PlanRotationStoreMigration({ rotations = char.rotations })
        if not proposed then return nil, why end

        for number, map in pairs(proposed.legacy.rotations) do
            for id, body in pairs(map) do
                add(
                    'character',
                    number,
                    id,
                    { body = body },
                    data.ValidateBody(body, self:GetRotationValidationOptions())
                )
            end
        end
    end

    table.sort(result, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        if a.spec ~= b.spec then return a.spec < b.spec end
        return a.id < b.id
    end)

    return result
end

-- Plans adopting an unassigned rotation as a class or character rotation (`scope`, default 'class'). Returns an opaque
-- plan, or nil and a reason. A profile selection is planned by the coordinator; a character-archive selection is
-- built here against a copy of the store, so nothing is written until ApplyRotationAdoption.
function addon:PlanRotationAdoption(selection, scope)
    if not validSelection(selection) then return nil, 'invalid-legacy-selection' end
    scope = scope or 'class'
    local coordinator = self:GetScopedRotationCoordinator()
    if not coordinator then return nil, 'rotation-profile-not-bound' end
    local ready, readinessReason = coordinator:CheckReady()
    if not ready then return nil, readinessReason end

    if selection.kind == 'profile' then
        local plan, why = coordinator:PlanAdoption(selection, scope or 'class')
        if not plan then return nil, why end
        adoptions[plan] = { coordinator = coordinator }
        return plan
    end

    local char, c, charRoot = currentCharacter(self)
    if not char then return nil, type(c) == 'string' and c or 'unknown-rotation' end
    if scope ~= 'class' and scope ~= 'character' then return nil, 'invalid-owner-scope' end
    local archive, why = data.PlanRotationStoreMigration({ rotations = char.rotations })
    if not archive then return nil, why end
    local rows = archive.legacy.rotations and archive.legacy.rotations[selection.spec]
    local body = rows and rows[selection.id]
    if not body then return nil, 'unknown-rotation' end
    local original = self.db.profile.rotationStore
    local valid, stateReason = data.ValidateRotationStore(original)
    if not valid then return nil, stateReason end
    local proposed = clone(original)

    local service, storeReason = data.NewRotationStore({
        state = proposed,
        fallbackID = self.db.profile.rotationFallbackID,
    })

    if not service then return nil, storeReason end

    local address = {
        scope = scope,
        class = c.class,
        owner = scope == 'class' and c.class or c.character,
        spec = selection.spec,
        id = selection.id,
    }

    local transaction, planReason = service:PlanCreate(address, { body = body }, c)
    if not transaction then return nil, planReason end
    local committed, commitReason = service:Commit(transaction, c)
    if not committed then return nil, commitReason end
    rows[selection.id] = nil

    local public = {
        reference = { kind = 'custom', address = clone(address) },
        selection = clone(selection),
        scope = scope,
    }

    adoptions[public] = {
        coordinator = coordinator,
        profile = self.db.profile,
        fallback = self.db.profile.rotationFallbackID,
        context = c,
        char = char,
        charRoot = charRoot,
        original = original,
        baseline = clone(original),
        rotations = char.rotations,
        charBaseline = data.PlanRotationStoreMigration({ rotations = char.rotations }),
        proposed = proposed,
        charReplacement = archive.legacy.rotations,
        reference = clone(public.reference),
    }

    return public
end

-- Applies a plan from PlanRotationAdoption and rebinds the active rotation store. Returns true and a reference to the
-- adopted rotation, or nil and a reason ('stale-adoption-plan' when the profile, the character or the store changed
-- since planning). The checks are repeated once the rebind is prepared, in case anything moved meanwhile.
function addon:ApplyRotationAdoption(public)
    local plan = adoptions[public]
    if not plan or self:GetScopedRotationCoordinator() ~= plan.coordinator then return nil, 'invalid-adoption-plan' end
    local ready, readinessReason = plan.coordinator:CheckReady()
    if not ready then return nil, readinessReason end

    if not plan.profile then
        local ok, reference = plan.coordinator:ApplyAdoption(public)
        if ok then adoptions[public] = nil end
        return ok, reference
    end

    local char, c, charRoot = currentCharacter(self)

    if
        self.db.profile ~= plan.profile
        or not same(c, plan.context)
        or char ~= plan.char
        or charRoot ~= plan.charRoot
        or char.rotations ~= plan.rotations
        or plan.profile.rotationStore ~= plan.original
        or plan.profile.rotationFallbackID ~= plan.fallback
    then
        return nil, 'stale-adoption-plan'
    end

    local valid, why = data.ValidateRotationStore(plan.original)
    if not valid then return nil, why end
    local now, archiveReason = data.PlanRotationStoreMigration({ rotations = char.rotations })
    if not now then return nil, archiveReason end

    if not same(plan.original, plan.baseline) or not same(now, plan.charBaseline) then
        return nil, 'stale-adoption-plan'
    end

    local binding = prepareRootRebind and prepareRootRebind()
    local freshChar, freshContext, freshRoot = currentCharacter(self)

    if
        self.db.profile ~= plan.profile
        or not same(freshContext, plan.context)
        or freshChar ~= plan.char
        or freshRoot ~= plan.charRoot
        or char.rotations ~= plan.rotations
        or plan.profile.rotationStore ~= plan.original
        or plan.profile.rotationFallbackID ~= plan.fallback
    then
        return nil, 'stale-adoption-plan'
    end

    local freshArchive, freshArchiveReason = data.PlanRotationStoreMigration({ rotations = char.rotations })
    if not freshArchive then return nil, freshArchiveReason end

    if not same(plan.original, plan.baseline) or not same(freshArchive, plan.charBaseline) then
        return nil, 'stale-adoption-plan'
    end

    if
        self.db.profile ~= plan.profile
        or char.rotations ~= plan.rotations
        or plan.profile.rotationStore ~= plan.original
        or plan.profile.rotationFallbackID ~= plan.fallback
    then
        return nil, 'stale-adoption-plan'
    end

    plan.profile.rotationStore = plan.proposed
    char.rotations = plan.charReplacement
    adoptions[public] = nil
    if binding and not activeCurrent(self, binding.token) then return true, clone(plan.reference) end
    local bind = self.BindRotationProfile
    if binding and not activeCurrent(self, binding.token) then return true, clone(plan.reference) end
    local bound, bindReason

    if binding and runRootRebind then
        bound, bindReason = runRootRebind(self, binding, bind)
    else
        bound, bindReason = bind(self)
    end

    if binding and not activeCurrent(self, binding.token) then return true, clone(plan.reference) end
    if not bound then return nil, bindReason end
    return true, clone(plan.reference)
end
