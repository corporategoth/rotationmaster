-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Scoped rotation store: the pure data layer over profile.rotationStore, where custom rotation records live under a
-- Class or Character owner, a specialization key and a rotation id, next to preserved unassigned legacy data.
-- It owns store validation (including aliasing checks), detached reads, fallback lookup, the legacy migration plan and
-- guarded create/replace/delete/move/adopt plans with a Commit step, plus the internal borrowed reader and the
-- publication and execution guards the runtime uses. A record is { body, origin | imported, comparison } kept together.
-- It must never write the persistence root on load, evaluate conditions or infer an owner for legacy data.
-- Loaded last of the Data/ modules from RotationMaster.toc (after Data/catalog.lua and Data/import_session.lua);
-- built by Core/rotation_scope.lua through data.NewRotationStore.
-- Saved shape and rules: docs/architecture/storage-scopes.md.
local _, addon = ...
local data = addon.RotationData
local isClass = data.IsRotationClassToken
---@type fun(f: number|function): table
local executionGetfenv = getfenv
local executionProtect = pcall
local executionClassEnvironment

if type(executionGetfenv) == 'function' then
    local ok, value = executionProtect(executionGetfenv, isClass)

    if ok and type(value) == 'table' then
        executionClassEnvironment = value
    end
end

-- These are source witnesses only. The private runtime guard never executes
-- address grammar or invokes a retained string receiver with record data.
local executionStringMeta = getmetatable('')
local executionStringIndex = type(executionStringMeta) == 'table' and rawget(executionStringMeta, '__index')
local executionStringLibrary = string

local executionFind = type(executionStringIndex) == 'table' and rawget(executionStringIndex, 'find') or type(
    executionStringLibrary
)
    == 'table'
    and rawget(executionStringLibrary, 'find')

local components = { 'body', 'origin', 'imported', 'comparison' }
local addressFields = { scope = true, class = true, owner = true, spec = true, id = true }
local stateFields = { version = true, classes = true, characters = true, legacy = true }
local recordFields = { body = true, origin = true, imported = true, comparison = true }
local characterBucketFields = { class = true, specs = true }
local legacyKinds = { rotations = 'body', origins = 'origin', imports = 'imported', comparisons = 'comparison' }

-- ============================================================================
-- Validation helpers
-- ============================================================================

-- Whether a value is a table with no metatable (the only kind of table the store accepts as data).
-- @param v any  The value to test.
-- @return boolean  True for a plain table.
local function plain(v)
    return type(v) == 'table' and getmetatable(v) == nil
end

-- Whether a value is a non-blank string of limited length with no control characters.
-- @param v any  The value to test.
-- @param limit number  The most bytes allowed.
-- @return boolean  True for such a string.
local function text(v, limit)
    return type(v) == 'string' and #v > 0 and #v <= limit and v:find('%S') ~= nil and not v:find('[%z\1-\31\127]')
end

-- Whether a value is a specialization key.
-- @param v any  The value to test.
-- @return boolean  True for a finite whole number of zero or more.
local function spec(v)
    return type(v) == 'number' and v >= 0 and v < math.huge and v % 1 == 0
end

-- Whether a value is a plain table whose keys are all in an allowed set.
-- @param v any  The value to test.
-- @param allowed table  The allowed keys (key -> true).
-- @return boolean  True for such a table.
local function fields(v, allowed)
    if not plain(v) then
        return false
    end

    for key in pairs(v) do
        if not allowed[key] then
            return false
        end
    end

    return true
end

-- Whether a value is a well-formed address.
-- @param a any  The address { scope, class, owner, spec, id }: a class-scope owner is its class token, a
--   character-scope owner is a character key.
-- @return boolean  True when well formed.
local function validAddress(a)
    return fields(a, addressFields)
        and isClass(a.class)
        and spec(a.spec)
        and text(a.id, 128)
        and (a.scope == 'class' and a.owner == a.class or a.scope == 'character' and text(a.owner, 512))
end

-- Tells whether an address belongs to the caller's owner context.
-- @param a table  The address.
-- @param c table  The owner context { class, character }.
-- @return boolean|nil  True for the same class, and for character scope the same character; nil otherwise.
-- @return string|nil  'missing-owner-context' or 'foreign-owner' when the first return is nil; nil otherwise.
local function visible(a, c)
    if not plain(c) or not isClass(c.class) then
        return nil, 'missing-owner-context'
    end
    if a.scope == 'character' and not text(c.character, 512) then
        return nil, 'missing-owner-context'
    end
    if c.class ~= a.class or a.scope == 'character' and a.owner ~= c.character then
        return nil, 'foreign-owner'
    end

    return true
end

-- Deep structural equality over plain data.
-- @param a any  The first value.
-- @param b any  The second value.
-- @return boolean  True when equal.
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

-- Makes a detached deep copy through the shared plain-data copier.
-- @param value any  The value to copy.
-- @return any|nil  The copy; nil for non-portable data.
-- @return table|nil  A diagnostic when the first return is nil; nil otherwise.
local function copied(value)
    return data.CopyData(value)
end

-- Copies a record's four components (body, origin, imported, comparison), dropping other keys.
-- @param record table  The record.
-- @return table  The detached copy.
local function copyRecord(record)
    local result = {}

    for _, key in ipairs(components) do
        if record[key] ~= nil then
            result[key] = copied(record[key])
        end
    end

    return result
end

-- Whether a value is a map of step id to origin step id.
-- @param value any  The value to test.
-- @return boolean  True when both are non-blank strings of at most 128 bytes.
local function originMap(value)
    if not plain(value) then
        return false
    end

    for key, origin in pairs(value) do
        if not text(key, 128) or not text(origin, 128) then
            return false
        end
    end

    return true
end

-- Checks the shape of one stored record against its address.
-- @param record table  The record: a portable body, at most one of origin (a clone's manifest and lineage) or imported
--   (an import's manifest and step origins), a manifest that matches the address id and class, and a comparison
--   pointer.
-- @param address table  The record's address.
-- @return boolean|nil  True when valid; nil otherwise.
-- @return string|nil  'invalid-record' or 'source-class-mismatch' when the first return is nil; nil otherwise.
--
-- The body may be incomplete; storage safety and runtime readiness are separate questions.
local function validRecord(record, address)
    if
        not fields(record, recordFields)
        or not plain(record.body)
        or not data.CheckPortable(record.body)
        or record.origin ~= nil and record.imported ~= nil
    then
        return nil, 'invalid-record'
    end

    for _, kind in ipairs({ 'origin', 'imported', 'comparison' }) do
        if record[kind] ~= nil and (not plain(record[kind]) or not data.CheckPortable(record[kind])) then
            return nil, 'invalid-record'
        end
    end

    local provenance = record.origin or record.imported

    if provenance then
        local manifest = provenance.manifest

        if not plain(manifest) or manifest.body ~= nil or manifest.id ~= address.id then
            return nil, 'invalid-record'
        end
        if manifest.applicability ~= nil and not plain(manifest.applicability) then
            return nil, 'invalid-record'
        end
        if
            manifest.applicability and manifest.applicability.class and manifest.applicability.class ~= address.class
        then
            return nil, 'source-class-mismatch'
        end

        -- Validate manifest structure independently of an incomplete current body.
        local envelope = copied(manifest)
        envelope.body = { rotation = {}, cooldowns = {} }

        if not data.ValidateEnvelope(envelope).valid then
            return nil, 'invalid-record'
        end

        if record.origin then
            if not fields(provenance, { manifest = true, lineage = true }) or not plain(provenance.lineage) then
                return nil, 'invalid-record'
            end

            local catalog = data.NewCatalog({
                state = { custom = { [address.id] = envelope }, lineage = { [address.id] = provenance.lineage } },
            })

            local view = catalog and catalog:Get({ kind = 'custom', id = address.id })

            if not view or view.lineageError then
                return nil, 'invalid-record'
            end
        elseif
            not fields(provenance, { manifest = true, sourceId = true, sourceRevision = true, stepOrigins = true })
            or not text(provenance.sourceId, 128)
            or provenance.sourceRevision ~= nil
                and (not spec(provenance.sourceRevision) or provenance.sourceRevision < 1)
            or not originMap(provenance.stepOrigins)
        then
            return nil, 'invalid-record'
        end
    end

    local comparison = record.comparison

    if
        comparison
        and (not fields(comparison, { kind = true, id = true, origins = true, sourceAddress = true })
            or comparison.kind ~= 'custom' and comparison.kind ~= 'builtin'
            or not text(comparison.id, 128)
            or not originMap(comparison.origins)
            or comparison.sourceAddress ~= nil
                and (comparison.kind ~= 'custom'
                    or not validAddress(comparison.sourceAddress)
                    or comparison.sourceAddress.id ~= comparison.id))
    then
        return nil, 'invalid-record'
    end

    return true
end

-- Walks a map of specialization key to { id = value } rows.
-- @param map any  The map; valid keys and ids are required.
-- @param visit function  Called as visit(value, id, spec) for each entry; returns true or nil and a reason.
-- @return boolean|nil  True when every entry was visited and passed; nil otherwise.
-- @return string|nil  'invalid-store' or the first failure's reason when the first return is nil; nil otherwise.
local function validSpecMap(map, visit)
    if not plain(map) then
        return nil, 'invalid-store'
    end

    for number, rows in pairs(map) do
        if not spec(number) or not plain(rows) then
            return nil, 'invalid-store'
        end

        for id, value in pairs(rows) do
            if not text(id, 128) then
                return nil, 'invalid-store'
            end

            local ok, why = visit(value, id, number)

            if not ok then
                return nil, why
            end
        end
    end

    return true
end

-- Checks the unassigned legacy archive (rotations, origins, imports, comparisons and evidence).
-- @param legacy any  The archive; only portable data under valid keys is allowed.
-- @return boolean|nil  True when valid; nil otherwise.
-- @return string|nil  'invalid-legacy-state' when the first return is nil; nil otherwise.
local function validLegacy(legacy)
    if not fields(legacy, {
        rotations = true,
        origins = true,
        imports = true,
        comparisons = true,
        evidence = true,
    }) then
        return nil, 'invalid-legacy-state'
    end

    for kind in pairs(legacyKinds) do
        if legacy[kind] ~= nil then
            local ok = validSpecMap(legacy[kind], function(value) return data.CheckPortable(value) end)

            if not ok then
                return nil, 'invalid-legacy-state'
            end
        end
    end

    if legacy.evidence ~= nil and not data.CheckPortable(legacy.evidence) then
        return nil, 'invalid-legacy-state'
    end

    return true
end

-- Whether no table reachable from a value is one of the store's own owner containers.
-- @param value any  The payload to search.
-- @param owned table  The set of owner containers (table -> true).
-- @return boolean  True when the payload is detached from them.
local function detachedPayload(value, owned)
    if type(value) ~= 'table' then
        return true
    end
    if owned[value] then
        return false
    end

    for _, child in pairs(value) do
        if not detachedPayload(child, owned) then
            return false
        end
    end

    return true
end

-- Checks that the store's containers are all distinct tables.
-- @param state table  The store state.
-- @return boolean  True when every container (state, owners, spec maps, rows, records) is a distinct table and no
--   record payload points back into those containers; otherwise a plain table write could change another owner's data.
local function distinctStructure(state)
    local owned, payloads = {}, {}

    -- Registers a container as owned.
    -- @param value table  The container.
    -- @return boolean  False if it was already registered (an alias); true otherwise.
    local function claim(value)
        if owned[value] then
            return false
        end

        owned[value] = true
        return true
    end

    -- Claims a spec map, its rows and records, and collects each record's components as payloads to check later.
    -- @param map table  The spec map.
    -- @return boolean  False when any container is an alias; true otherwise.
    local function maps(map)
        if not claim(map) then
            return false
        end

        for _, rows in pairs(map) do
            if not claim(rows) then
                return false
            end

            for _, record in pairs(rows) do
                if not claim(record) then
                    return false
                end

                for _, component in ipairs(components) do
                    if record[component] ~= nil then
                        payloads[#payloads + 1] = record[component]
                    end
                end
            end
        end

        return true
    end

    if not claim(state) or not claim(state.classes) or not claim(state.characters) or not claim(state.legacy) then
        return false
    end

    for _, map in pairs(state.classes) do
        if not maps(map) then
            return false
        end
    end

    for _, bucket in pairs(state.characters) do
        if not claim(bucket) or not maps(bucket.specs) then
            return false
        end
    end

    for kind in pairs(legacyKinds) do
        if state.legacy[kind] ~= nil then
            local map = state.legacy[kind]

            if not claim(map) then
                return false
            end

            for _, rows in pairs(map) do
                if not claim(rows) then
                    return false
                end

                for _, value in pairs(rows) do
                    payloads[#payloads + 1] = value
                end
            end
        end
    end

    if state.legacy.evidence ~= nil then
        payloads[#payloads + 1] = state.legacy.evidence
    end

    -- Repeated data references are legal; owner containers must never be data.
    -- Otherwise a later plain table write could mutate another owner's body.
    for _, value in ipairs(payloads) do
        if not detachedPayload(value, owned) then
            return false
        end
    end

    return true
end

-- ============================================================================
-- Store validation and migration planning
-- ============================================================================

-- Validates the whole store state.
-- @param state any  The state { version = 1, classes, characters, legacy }: every owner, record and legacy entry, plus
--   the aliasing rules.
-- @return boolean|nil  True when valid; nil otherwise.
-- @return string|nil  'invalid-store', 'aliased-store' or a record reason when the first return is nil; nil otherwise.
local function validState(state)
    if
        not fields(state, stateFields) or state.version ~= 1 or not plain(state.classes) or not plain(state.characters)
    then
        return nil, 'invalid-store'
    end

    for class, map in pairs(state.classes) do
        if not isClass(class) then
            return nil, 'invalid-store'
        end

        local ok, why = validSpecMap(map, function(record, id, number)
            return validRecord(record, { id = id, class = class, spec = number })
        end)

        if not ok then
            return nil, why
        end
    end

    for owner, bucket in pairs(state.characters) do
        if not text(owner, 512) or not fields(bucket, characterBucketFields) or not isClass(bucket.class) then
            return nil, 'invalid-store'
        end

        local ok, why = validSpecMap(bucket.specs, function(record, id, number)
            return validRecord(record, { id = id, class = bucket.class, spec = number })
        end)

        if not ok then
            return nil, why
        end
    end

    local ok, why = validLegacy(state.legacy)

    if not ok then
        return nil, why
    end
    if not distinctStructure(state) then
        return nil, 'aliased-store'
    end

    return true
end

-- Validates a store state; the public form of the store validation, for profile transport and repair.
-- @param state any  The store state.
-- @return boolean|nil  True when valid; nil otherwise.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function data.ValidateRotationStore(state)
    return validState(state)
end

-- Copies a legacy archive.
-- @param legacy table  The archive.
-- @return table  A detached copy.
local function copyLegacy(legacy)
    local result = {}

    for kind in pairs(legacyKinds) do
        if legacy[kind] ~= nil then
            local map = {}
            result[kind] = map

            for number, rows in pairs(legacy[kind]) do
                map[number] = {}

                for id, value in pairs(rows) do
                    map[number][id] = copied(value)
                end
            end
        end
    end

    if legacy.evidence ~= nil then
        result.evidence = copied(legacy.evidence)
    end

    return result
end

-- Plans the migration of a legacy archive into a new store.
-- @param legacy table  The legacy archive.
-- @return table|nil  A new empty store whose legacy section is a copy of the archive (nothing is assigned to an
--   owner); nil when the archive is not valid.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- A proposal only: no source ownership is inferred and no live profile is changed.
function data.PlanRotationStoreMigration(legacy)
    local ok, why = validState({ version = 1, classes = {}, characters = {}, legacy = legacy })

    if not ok then
        return nil, why
    end

    return { version = 1, classes = {}, characters = {}, legacy = copyLegacy(legacy) }
end

-- ============================================================================
-- Store service
-- ============================================================================

-- Creates the scoped rotation store service over one profile-owned state object.
-- @param options table  { state (the profile's store, validated first), fallbackID, validation (passed to the body
--   validator), requireValidWrites, bindInternalReader (function receiving the internal borrowed reader) }.
-- @return table|nil  The service (Get, ListVisible, GetFallback, Refresh, AllStored, Plan*, Commit); nil on failure.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
-- @return function|nil  The private publication guard factory for the trusted runtime facade.
-- @return function|nil  The private execution guard factory for the trusted runtime facade.
--
-- The caller provides identity and configuration explicitly. Bodies may be incomplete; storage safety and runtime
-- readiness are separate.
function data.NewRotationStore(options)
    if not plain(options) or options.bindInternalReader ~= nil and type(options.bindInternalReader) ~= 'function' then
        return nil, 'invalid-store-options'
    end

    local state = options.state

    if not text(options.fallbackID, 128) then
        return nil, 'invalid-fallback-id'
    end

    local ok, why = validState(state)

    if not ok then
        return nil, why
    end

    local service = {}
    local tokens = setmetatable({}, { __mode = 'k' })
    local plans = setmetatable({}, { __mode = 'k' })

    -- Returns the three root tables of the state; a leased or indexed view is stale once any of them is replaced.
    -- @return table  { classes, characters, legacy }.
    local function roots()
        return { state.classes, state.characters, state.legacy }
    end

    -- Whether the state still has the same three root tables as a recorded list from roots().
    -- @param previous table  The recorded list.
    -- @return boolean  True when the roots are unchanged.
    local function sameRoots(previous)
        return previous[1] == state.classes and previous[2] == state.characters and previous[3] == state.legacy
    end

    -- Builds a structural index of the state.
    -- @return table  For each owner its bucket, spec map and, per specialization, the rows table, record table and
    --   count, plus the set of every container the store owns. Reads check it against the raw state so an outside
    --   change is caught as 'stale-store-index' instead of being trusted.
    --
    -- Built only after full validation or our own detached plain-table writes.
    local function buildIndex()
        local result = { roots = roots(), classes = {}, characters = {}, owned = { [state] = true } }

        for _, root in ipairs(result.roots) do
            result.owned[root] = true
        end

        -- Indexes one owner's spec map and marks its containers as owned.
        -- @param bucket table  The owner's bucket.
        -- @param map table  The owner's spec map.
        -- @return table  The owner's index entry.
        local function add(bucket, map)
            result.owned[bucket] = true
            result.owned[map] = true
            local owner = { bucket = bucket, map = map, specs = {} }

            for number, rows in pairs(map) do
                result.owned[rows] = true
                local scope = { rows = rows, records = {}, count = 0 }
                owner.specs[number] = scope

                for id, record in pairs(rows) do
                    scope.records[id] = record
                    scope.count = scope.count + 1
                    result.owned[record] = true
                end
            end

            return owner
        end

        for class, map in pairs(state.classes) do
            result.classes[class] = add(map, map)
        end

        for name, bucket in pairs(state.characters) do
            local owner = add(bucket, bucket.specs)
            owner.class = bucket.class
            result.characters[name] = owner
        end

        for kind in pairs(legacyKinds) do
            if state.legacy[kind] then
                local map = state.legacy[kind]
                result.owned[map] = true

                for _, rows in pairs(map) do
                    result.owned[rows] = true
                end
            end
        end

        return result
    end

    local index = buildIndex()

    -- Finds the record at an address straight in the state.
    -- @param a table  The address.
    -- @return table|nil  The record; nil when absent.
    -- @return table  The chain of containers walked (root, owner bucket, spec map, rows; false where one is missing),
    --   which leases compare by identity.
    local function locate(a)
        local root = a.scope == 'class' and state.classes or state.characters
        local bucket = root[a.owner]
        local map = a.scope == 'class' and bucket or bucket and bucket.specs
        local rows = map and map[a.spec]
        return rows and rows[a.id], { root, bucket or false, map or false, rows or false }
    end

    -- Records a lease on an address.
    -- @param a table  The address.
    -- @return table  { address, record, chain, roots, baseline }: the record, its container chain, the roots and a
    --   detached baseline copy. A lease is what a read token or a plan holds to prove later that nothing underneath has
    --   changed.
    local function capture(a)
        local record, chain = locate(a)

        return {
            address = copied(a),
            record = record,
            chain = chain,
            roots = roots(),
            baseline = record and copyRecord(record),
        }
    end

    -- Tells whether a lease still holds.
    -- @param lease table  The lease from capture.
    -- @return boolean  True while the roots, the record object with its content and the container chain are unchanged.
    local function alive(lease)
        if not sameRoots(lease.roots) then
            return false
        end

        local current, chain = locate(lease.address)

        if current ~= lease.record or not equal(current, lease.baseline) then
            return false
        end

        for i = 1, 4 do
            if chain[i] ~= lease.chain[i] then
                return false
            end
        end

        return true
    end

    -- Checks that a write may target an address.
    -- @param a table  The address.
    -- @param c table  The owner context { class, character }.
    -- @return boolean|nil  True when the address is valid and visible to the caller, the whole store is valid and a
    --   Character bucket has the same class; nil otherwise.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    local function target(a, c)
        if not validAddress(a) then
            return nil, 'invalid-address'
        end

        local allowed, reason = visible(a, c)

        if not allowed then
            return nil, reason
        end

        local valid, problem = validState(state)

        if not valid then
            return nil, problem
        end

        local bucket = a.scope == 'character' and state.characters[a.owner]

        if bucket and bucket.class ~= a.class then
            return nil, 'foreign-owner'
        end

        return true
    end

    -- Reads the rows of one owner and specialization on the cheap read path.
    -- @param a table  The address.
    -- @param c table  The owner context { class, character }.
    -- @param source table|nil  A reader index to compare against; the main index by default.
    -- @return boolean|nil  True when read (a missing owner is not an error); nil otherwise.
    -- @return table|string|nil  The rows table, or nil with no rows; the reason code (such as 'stale-store-index' when
    --   an outside change moved a container) when the first return is nil.
    -- @return table|nil  The index scope for the specialization.
    --
    -- Validates only the address, the state header and the one owner and specialization involved, and compares them
    -- with the index.
    local function readRows(a, c, source)
        source = source or index

        if not validAddress(a) then
            return nil, 'invalid-address'
        end

        local allowed, reason = visible(a, c)

        if not allowed then
            return nil, reason
        end
        if
            not fields(state, stateFields)
            or state.version ~= 1
            or not plain(state.classes)
            or not plain(state.characters)
            or not plain(state.legacy)
        then
            return nil, 'invalid-store'
        end
        if not sameRoots(source.roots) then
            return nil, 'stale-store-index'
        end

        local root = a.scope == 'class' and state.classes or state.characters
        local indexed = (a.scope == 'class' and source.classes or source.characters)[a.owner]
        local bucket = root[a.owner]

        if bucket ~= nil and not plain(bucket) then
            return nil, 'invalid-store'
        end
        if a.scope == 'character' and bucket and bucket.class ~= a.class then
            return nil, 'foreign-owner'
        end
        if bucket ~= (indexed and indexed.bucket) then
            return nil, 'stale-store-index'
        end
        if not indexed then
            return true
        end
        if a.scope == 'character' and bucket.class ~= indexed.class then
            return nil, 'stale-store-index'
        end
        if a.scope == 'character' and not fields(bucket, characterBucketFields) then
            return nil, 'invalid-store'
        end

        local map = a.scope == 'class' and bucket or bucket.specs

        if not plain(map) then
            return nil, 'invalid-store'
        end
        if map ~= indexed.map then
            return nil, 'stale-store-index'
        end

        local rows, scope = map[a.spec], indexed.specs[a.spec]

        if rows ~= (scope and scope.rows) then
            return nil, 'stale-store-index'
        end
        if rows ~= nil and not plain(rows) then
            return nil, 'invalid-store'
        end

        return true, rows, scope
    end

    -- Validates the one record being read and checks its payload does not alias a store container.
    -- @param record table  The record.
    -- @param a table  The address.
    -- @return boolean|nil  True when valid; nil otherwise.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    local function selected(record, a)
        local valid, reason = validRecord(record, a)

        if not valid then
            return nil, reason
        end

        for _, component in ipairs(components) do
            if not detachedPayload(record[component], index.owned) then
                return nil, 'aliased-store'
            end
        end

        return true
    end

    -- Reads the live record at an address.
    -- @param a table  The address.
    -- @param c table  The owner context { class, character }.
    -- @return boolean|nil  True when read; nil when the index is stale or the record is invalid.
    -- @return table|string|nil  The live (not copied) record, nil when absent; the reason code when the first return is
    --   nil. Callers copy before handing anything out.
    local function readRecord(a, c)
        local allowed, rows, scope = readRows(a, c)

        if not allowed then
            return nil, rows
        end

        local record = rows and rows[a.id]

        if record ~= (scope and scope.records[a.id]) then
            return nil, 'stale-store-index'
        end

        if record then
            local valid, reason = selected(record, a)

            if not valid then
                return nil, reason
            end
        end

        return true, record
    end

    -- Resolves a read token into its lease.
    -- @param a table  The address the edit targets.
    -- @param expected table  The token the caller says it based the edit on.
    -- @return table|nil  The lease; nil when the token was not issued for this address or is no longer alive.
    -- @return string|nil  'stale-rotation-record' when the first return is nil; nil otherwise.
    local function checkExpected(a, expected)
        local lease = tokens[expected]

        if not lease or not equal(lease.address, a) or not alive(lease) then
            return nil, 'stale-rotation-record'
        end

        return lease
    end

    -- Validates a record for writing and returns a detached copy.
    -- @param record table  The record.
    -- @param a table  The address.
    -- @return table|nil  The copy; nil when invalid.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- The body is validated too when requireValidWrites is set.
    local function prepare(record, a)
        local valid, reason = validRecord(record, a)

        if not valid then
            return nil, reason
        end
        if options.requireValidWrites and not data.ValidateBody(record.body, options.validation).valid then
            return nil, 'invalid-rotation-body'
        end

        return copyRecord(record)
    end

    -- Creates a plan.
    -- @param operation string  'create', 'replace', 'delete', 'move' or 'adopt'.
    -- @param a table  The address.
    -- @param c table  The owner context { class, character }.
    -- @param lease table|nil  The lease on the source record.
    -- @param payload table|nil  The prepared record.
    -- @param destination table|nil  The destination address, for a move or an adoption.
    -- @return table  A public handle { operation, address, destination } that callers pass back to Commit.
    --
    -- A private entry holds the leases, payload and context that Commit re-checks.
    local function plan(operation, a, c, lease, payload, destination)
        local public = { operation = operation, address = copied(a), destination = destination and copied(destination) }

        plans[public] = {
            operation = operation,
            address = copied(a),
            source = lease,
            record = payload,
            destination = destination and copied(destination),
            target = capture(destination or a),
            roots = roots(),
            context = { class = c.class, character = c.character },
        }

        return public
    end

    -- Internal borrowed reader, with the read seals, the publication guard and the execution guard built on it.
    -- This capability is bound only to trusted facade code. Canonical borrows
    -- must not escape its synchronous projectors; UI keeps snapshot APIs.
    local reader, readerState, readerBusy = {}, 'binding', false
    local readIndex, readEpoch, readRevision = nil, 0, 0
    local publicationWriteVersion = 0
    -- One selected execution watch per profile store; unrelated writes leave it
    -- untouched. The cold planner supplies a captured notification closure.
    local executionWatch

    -- Drops the selected execution watch and calls its notification, so the runtime sees the change and discards a plan
    -- compiled against the old record.
    local function invalidateExecutionWatch()
        local watch = executionWatch
        executionWatch = nil

        if watch then
            watch.notify()
        end
    end

    -- Whether an address is the record the execution watch is following.
    -- @param a table|nil  The address.
    -- @return boolean  True when it is the watched record.
    local function watchedAddress(a)
        local watch = executionWatch

        if not watch or not a then
            return false
        end

        local selected = watch.meta.address

        return a.scope == selected.scope
            and a.class == selected.class
            and a.owner == selected.owner
            and a.spec == selected.spec
            and a.id == selected.id
    end

    local readSeals = setmetatable({}, { __mode = 'k' })
    local nilCharacter = {}

    -- Copies just the five address fields, dropping anything else the caller's table carried.
    -- @param a table  The address.
    -- @return table  { scope, class, owner, spec, id }.
    local function detachedAddress(a)
        return { scope = a.scope, class = a.class, owner = a.owner, spec = a.spec, id = a.id }
    end

    -- Copies an owner context.
    -- @param c table  The context.
    -- @return table  { class, character }.
    local function contextCopy(c)
        return { class = c.class, character = c.character }
    end

    -- Whether a value is a usable owner context.
    -- @param c any  The context.
    -- @return boolean  True for a class token and an optional valid character key.
    local function privateContext(c)
        return plain(c) and isClass(c.class) and (c.character == nil or text(c.character, 512))
    end

    -- Whether a context table still names the same class and character as the recorded copy.
    -- @param a table  The recorded copy.
    -- @param c any  The context table.
    -- @return boolean  True when they match.
    local function sameContext(a, c)
        return plain(c) and a.class == c.class and a.character == c.character
    end

    -- Tells whether the internal reader is ready.
    -- @param checkBusy boolean|nil  True to also refuse while inside a projector call.
    -- @return boolean|nil  True when the reader is active; nil otherwise.
    -- @return string|nil  'retired-rotation-reader', 'rotation-reader-not-ready' or 'reentrant-rotation-read' when the
    --   first return is nil; nil otherwise.
    local function readerReady(checkBusy)
        if readerState == 'retired' then
            return nil, 'retired-rotation-reader'
        end
        if readerState ~= 'active' then
            return nil, 'rotation-reader-not-ready'
        end
        if checkBusy and readerBusy then
            return nil, 'reentrant-rotation-read'
        end

        return true
    end

    -- Builds the reader's metadata for one record.
    -- @param a table  The address.
    -- @param record table  The record.
    -- @return table  { address (detached), record, chain (its container chain), payload (its component identities),
    --   revision (a new revision number), seals (the seals issued for it) }.
    local function recordMetadata(a, record)
        readRevision = readRevision + 1
        local _, chain = locate(a)
        local payload = {}

        for _, component in ipairs(components) do
            payload[component] = record[component]
        end

        return {
            address = detachedAddress(a),
            record = record,
            chain = chain,
            payload = payload,
            revision = readRevision,
            seals = setmetatable({}, { __mode = 'v' }),
        }
    end

    -- Rebuilds the reader's index and metadata from the current state and advances the read epoch.
    --
    -- This makes every seal issued before it stale. Used at start and on Refresh, the only points where outside changes
    -- are blessed.
    local function resetReaderIndex()
        local beforeNotification = executionWatch and executionWatch.notify
        invalidateExecutionWatch()
        local replacement = buildIndex()

        -- Adds metadata for every record of one owner to the replacement index.
        -- @param kind string  'class' or 'character'.
        -- @param name string  The owner name.
        -- @param owner table  The owner's index entry.
        local function add(kind, name, owner)
            for number, scope in pairs(owner.specs) do
                scope.metadata = {}

                for id, record in pairs(scope.records) do
                    scope.metadata[id] = recordMetadata({
                        scope = kind,
                        class = kind == 'class' and name or owner.class,
                        owner = name,
                        spec = number,
                        id = id,
                    }, record)
                end
            end
        end

        for name, owner in pairs(replacement.classes) do
            add('class', name, owner)
        end

        for name, owner in pairs(replacement.characters) do
            add('character', name, owner)
        end

        -- A callback during reconstruction may have captured the post-entry
        -- stamp on the old index. Retire it at the final publication too.
        if executionWatch then
            invalidateExecutionWatch()
        elseif beforeNotification then
            beforeNotification()
        end

        readIndex = replacement
        readEpoch = readEpoch + 1
    end

    -- Brings the reader index up to date for one address just written by Commit.
    -- @param a table  The address.
    --
    -- Creates the owner or specialization entry if needed, adjusts the count and refreshes the record's metadata. Only
    -- addresses actually written by this service are updated; rebuilding from raw state would accidentally bless
    -- external component and container changes.
    local function advanceReaderAddress(a)
        local root = a.scope == 'class' and state.classes or state.characters
        local owners = a.scope == 'class' and readIndex.classes or readIndex.characters
        local bucket = root[a.owner]
        local map = a.scope == 'class' and bucket or bucket.specs
        local owner = owners[a.owner]

        if not owner then
            owner = { bucket = bucket, map = map, specs = {}, class = a.scope == 'character' and bucket.class or nil }
            owners[a.owner] = owner
        end

        local rows = map[a.spec]
        local scope = owner.specs[a.spec]

        if not scope then
            scope = { rows = rows, records = {}, metadata = {}, count = 0 }
            owner.specs[a.spec] = scope
        end

        local record = rows[a.id]
        local previous = scope.records[a.id]

        if previous == nil and record ~= nil then
            scope.count = scope.count + 1
        elseif previous ~= nil and record == nil then
            scope.count = scope.count - 1
        end

        scope.records[a.id] = record
        scope.metadata[a.id] = record and recordMetadata(a, record) or nil
    end

    -- Reads the reader's metadata for the record at an address.
    -- @param a table  The address.
    -- @param c table  The owner context.
    -- @return table|nil  The metadata, after re-checking the raw state against it (same containers, same component
    --   tables, plain data); nil on failure.
    -- @return string|nil  The reason code (such as 'stale-store-index') when the first return is nil; nil otherwise.
    local function privateRecord(a, c)
        local allowed, rows, scope = readRows(a, c, readIndex)

        if not allowed then
            return nil, rows
        end

        local record = rows and rows[a.id]

        if record ~= (scope and scope.records[a.id]) then
            return nil, 'stale-store-index'
        end
        if not record then
            return nil, 'unknown-rotation'
        end

        local meta = scope.metadata[a.id]

        if not fields(record, recordFields) or not plain(record.body) then
            return nil, 'invalid-record'
        end

        local _, chain = locate(a)

        for i = 1, 4 do
            if chain[i] ~= meta.chain[i] then
                return nil, 'stale-store-index'
            end
        end

        for _, component in ipairs(components) do
            if record[component] ~= meta.payload[component] then
                return nil, 'stale-store-index'
            end
            if record[component] ~= nil and not plain(record[component]) then
                return nil, 'invalid-record'
            end
        end

        return meta
    end

    -- Returns the seal for a record and owner context, creating it on first use.
    -- @param meta table  The record's metadata.
    -- @param c table  The owner context; one seal exists per character.
    -- @return table  The seal: an opaque token the reader later accepts as proof that the record has not changed since
    --   it was read.
    local function recordSeal(meta, c)
        local key = c.character

        if key == nil then
            key = nilCharacter
        end

        local seal = meta.seals[key]

        if not seal then
            seal = {}
            meta.seals[key] = seal
            readSeals[seal] = { kind = 'record', epoch = readEpoch, meta = meta, context = contextCopy(c) }
        end

        return seal
    end

    -- Lists the reader metadata of every record the owner context can run.
    -- @param number number  The specialization key whose fallback applies.
    -- @param c table  The owner context { class, character }.
    -- @return table[]|nil  The metadata of every record of the class owner and the caller's character owner, in a
    --   stable order; nil on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- Covers every partition of the owner: a rotation's specializations are its own property (body.specs), so the
    -- namespace it was saved under no longer hides it. `number` still names the partition whose fallback applies.
    local function privateRows(number, c)
        if not spec(number) then
            return nil, 'invalid-specialization'
        end
        if not privateContext(c) then
            return nil, 'missing-owner-context'
        end

        local result = {}

        -- Appends the metadata of every record in one owner and specialization, checking the index counts as it goes.
        -- @param kind string  'class' or 'character'.
        -- @param name string  The owner name.
        -- @param value number  The specialization key.
        -- @return boolean|nil  True when appended; nil on failure.
        -- @return string|nil  The reason code when the first return is nil; nil otherwise.
        local function partition(kind, name, value)
            local a = { scope = kind, class = c.class, owner = name, spec = value, id = options.fallbackID }
            local allowed, rows, scope = readRows(a, c, readIndex)

            if not allowed then
                return nil, rows
            end

            local count = 0

            for id, record in pairs(rows or {}) do
                if not text(id, 128) or scope.records[id] ~= record then
                    return nil, 'stale-store-index'
                end

                a.id = id
                local meta, reason = privateRecord(a, c)

                if not meta then
                    return nil, reason
                end

                count = count + 1
                result[#result + 1] = meta
            end

            if count ~= (scope and scope.count or 0) then
                return nil, 'stale-store-index'
            end

            return true
        end

        -- Adds every specialization partition of one owner: the requested number first, then all others found in the
        -- state or in the index.
        -- @param kind string  'class' or 'character'.
        -- @param name string  The owner name.
        -- @return boolean|nil  True when added; nil on failure.
        -- @return string|nil  The reason code when the first return is nil; nil otherwise.
        local function add(kind, name)
            local allowed, reason = partition(kind, name, number)

            if not allowed then
                return nil, reason
            end

            local root = kind == 'class' and state.classes or state.characters
            local bucket = root[name]
            local map = kind == 'class' and bucket or plain(bucket) and bucket.specs
            local indexed = (kind == 'class' and readIndex.classes or readIndex.characters)[name]
            local numbers, seen = {}, { [number] = true }

            for value in pairs(plain(map) and map or {}) do
                if not seen[value] then
                    seen[value] = true
                    numbers[#numbers + 1] = value
                end
            end

            for value in pairs(indexed and indexed.specs or {}) do
                if not seen[value] then
                    seen[value] = true
                    numbers[#numbers + 1] = value
                end
            end

            for _, value in ipairs(numbers) do
                if not spec(value) then
                    return nil, 'invalid-store'
                end

                allowed, reason = partition(kind, name, value)

                if not allowed then
                    return nil, reason
                end
            end

            return true
        end

        local allowed, reason = add('class', c.class)

        if not allowed then
            return nil, reason
        end

        local character = type(c.character) == 'string' and state.characters[c.character]

        if character ~= nil and character ~= false and not plain(character) then
            return nil, 'invalid-store'
        end

        if not character or character.class == c.class then
            if text(c.character, 512) then
                allowed, reason = add('character', c.character)

                if not allowed then
                    return nil, reason
                end
            end
        end

        table.sort(result, function(a, b)
            local x, y = a.address, b.address

            if x.scope ~= y.scope then
                return x.scope < y.scope
            end
            if x.id ~= y.id then
                return x.id < y.id
            end

            return x.spec < y.spec
        end)

        return result
    end

    -- Tells whether a seal from Read or ListOwned is still valid for a context.
    -- @param seal table  The seal.
    -- @param c table  The owner context.
    -- @return boolean|nil  True for the same epoch, the same owner, and the record (or the whole list) unchanged; nil
    --   otherwise.
    -- @return string|nil  A reason such as 'stale-rotation-read-seal' when the first return is nil; nil otherwise.
    function reader:IsCurrent(seal, c)
        local ready, reason = readerReady()

        if not ready then
            return nil, reason
        end

        local entry = readSeals[seal]

        if not entry then
            return nil, 'invalid-rotation-read-seal'
        end
        if not privateContext(c) then
            return nil, 'missing-owner-context'
        end
        if not sameContext(entry.context, c) then
            return nil, 'foreign-owner'
        end
        if entry.epoch ~= readEpoch then
            return nil, 'stale-rotation-read-seal'
        end

        if entry.kind == 'record' then
            local meta = privateRecord(entry.meta.address, c)

            if meta ~= entry.meta then
                return nil, 'stale-rotation-read-seal'
            end
        else
            local current = privateRows(entry.spec, c)

            if not current or #current ~= #entry.items then
                return nil, 'stale-rotation-read-seal'
            end

            for i, meta in ipairs(current) do
                if meta ~= entry.items[i] then
                    return nil, 'stale-rotation-read-seal'
                end
            end
        end

        return true
    end

    local ownedReaderIsCurrent = reader.IsCurrent
    -- Only an owned factory admission may consume this private capability.
    local guardType, guardPairs, guardGetmetatable, guardRawget = type, pairs, getmetatable, rawget

    -- Builds the pair of checks the runtime uses to publish a plan compiled from one record.
    -- @param _ any  Unused.
    -- @param seal table  The record seal.
    -- @param c table|nil  The owner context; the seal's own by default.
    -- @param notify function|nil  Called when the watched record changes; given, it also starts the single execution
    --   watch.
    -- @return function|nil  fullCurrent, which re-proves everything (reader state, epoch, write version, state header,
    --   container chain, component identities, plain data); nil for a seal that is not a record seal.
    -- @return function|nil  continuationCurrent, which re-checks only raw identities between callouts, never running
    --   extension code.
    local function makePublicationGuard(_, seal, c, notify)
        local entry = readSeals[seal]

        if not entry or entry.kind ~= 'record' then
            return nil
        end

        local meta = entry.meta
        local a = meta.address
        c = c or entry.context
        local owners = a.scope == 'class' and readIndex.classes or readIndex.characters
        local owner = owners[a.owner]
        local scope = owner and owner.specs[a.spec]
        local epoch, writeVersion = entry.epoch, publicationWriteVersion
        local expectedRoots = readIndex.roots
        local chain = meta.chain
        local record, payload = meta.record, meta.payload

        -- Runs the full check.
        -- @return boolean|nil  True when the record is still the one that was sealed; false when it is no longer; nil
        --   when a captured primitive (type, pairs, getmetatable, rawget) was replaced.
        local function fullCurrent()
            if
                reader.IsCurrent ~= ownedReaderIsCurrent
                or type ~= guardType
                or pairs ~= guardPairs
                or getmetatable ~= guardGetmetatable
                or rawget ~= guardRawget
            then
                return nil
            end

            -- Preserve public-reader admission and its actual string receivers.
            if readerState ~= 'active' then
                return false
            end
            if not privateContext(c) or not sameContext(entry.context, c) then
                return false
            end
            if readEpoch ~= epoch then
                return false
            end
            if not validAddress(a) or not visible(a, c) then
                return false
            end
            if
                readerState ~= 'active'
                or readEpoch ~= epoch
                or publicationWriteVersion ~= writeVersion
                or not scope
                or scope.metadata[a.id] ~= meta
            then
                return false
            end

            -- Preserve all raw state/header/container/component witnesses checked
            -- by readRows/privateRecord, without allocating a locate chain or
            -- repeating plain checks of the same class map/body.
            if not fields(state, stateFields) or state.version ~= 1 then
                return false
            end

            local classes, characters, legacy = state.classes, state.characters, state.legacy

            if
                classes ~= expectedRoots[1]
                or characters ~= expectedRoots[2]
                or legacy ~= expectedRoots[3]
                or not plain(classes)
                or not plain(characters)
                or not plain(legacy)
            then
                return false
            end

            local root = a.scope == 'class' and classes or characters

            if root ~= chain[1] then
                return false
            end

            local bucket = root[a.owner]

            if bucket ~= chain[2] or not plain(bucket) then
                return false
            end

            local map = bucket

            if a.scope == 'character' then
                if
                    bucket.class ~= a.class or bucket.class ~= owner.class or not fields(bucket, characterBucketFields)
                then
                    return false
                end

                map = bucket.specs

                if not plain(map) then
                    return false
                end
            end

            if map ~= chain[3] then
                return false
            end

            local rows = map[a.spec]

            if rows ~= chain[4] or not plain(rows) or rows[a.id] ~= record then
                return false
            end
            if not fields(record, recordFields) then
                return false
            end

            for _, component in ipairs(components) do
                local value = record[component]

                if value ~= payload[component] or value ~= nil and not plain(value) then
                    return false
                end
            end

            return true
        end

        -- Cheap check with raw reads only: epoch, write version and the identity of every container and component.
        -- @return boolean  True while they are unchanged.
        --
        -- The configuration was admitted by fullCurrent. Between real callouts, only raw identity and epoch witnesses
        -- are used; extension code is never invoked.
        local function continuationCurrent()
            if
                readerState ~= 'active'
                or readEpoch ~= epoch
                or publicationWriteVersion ~= writeVersion
                or not scope
                or scope.metadata[a.id] ~= meta
            then
                return false
            end
            if
                guardRawget(state, 'version') ~= 1
                or guardRawget(state, 'classes') ~= expectedRoots[1]
                or guardRawget(state, 'characters') ~= expectedRoots[2]
                or guardRawget(state, 'legacy') ~= expectedRoots[3]
            then
                return false
            end
            if guardRawget(chain[1], a.owner) ~= chain[2] then
                return false
            end
            if
                a.scope == 'character'
                and (guardRawget(chain[2], 'class') ~= a.class or guardRawget(chain[2], 'specs') ~= chain[3])
            then
                return false
            end
            if guardRawget(chain[3], a.spec) ~= chain[4] or guardRawget(chain[4], a.id) ~= record then
                return false
            end

            for index = 1, #components do
                local component = components[index]

                if guardRawget(record, component) ~= payload[component] then
                    return false
                end
            end

            return true
        end

        if notify ~= nil then
            if type(notify) ~= 'function' or not fullCurrent() then
                return nil
            end

            executionWatch = { meta = meta, notify = notify }
        end

        return fullCurrent, continuationCurrent
    end

    -- Builds the execution guard for one record, like the publication guard but with stronger witnesses.
    -- @param _ any  Unused.
    -- @param seal table  The record seal.
    -- @param c table|nil  The owner context; the seal's own by default.
    -- @param notify function|nil  Called when the watched record changes; given, it also starts the single execution
    --   watch.
    -- @return function|nil  The current check; nil (nothing is returned) on a client without getfenv or when any
    --   witness already differs.
    -- @return function|nil  The continuation check.
    --
    -- Only the literal owned executor consumes this fourth factory capability. Besides the publication checks it
    -- witnesses that the global environment, the string library and every table involved are untouched (no
    -- metatables). Schema and address validation is cold; publication checks relevant identities and table metatables
    -- without re-walking closed field schemas each time.
    local function makeExecutionGuard(_, seal, c, notify)
        if
            type(executionGetfenv) ~= 'function'
            or not executionClassEnvironment
            or type(executionFind) ~= 'function'
            or type(executionStringMeta) ~= 'table'
            or executionStringIndex ~= nil and type(executionStringIndex) ~= 'table'
        then
            return
        end

        local full, continuation = makePublicationGuard(reader, seal, c)

        if not full or full() ~= true then
            return
        end

        local entry = readSeals[seal]
        local meta = entry.meta
        c = c or entry.context
        local tables, seen = {}, {}

        -- Remembers a table once so current() can check later that it still has no metatable.
        -- @param value any  The value; anything that is not a table is ignored.
        local function add(value)
            if guardType(value) == 'table' and not seen[value] then
                seen[value] = true
                tables[#tables + 1] = value
            end
        end

        add(state)
        add(c)
        add(meta.record)

        for i = 1, 3 do
            add(readIndex.roots[i])
        end

        for i = 1, 4 do
            add(meta.chain[i])
        end

        for i = 1, #components do
            add(meta.payload[components[i]])
        end

        local expectedClass, expectedCharacter = entry.context.class, entry.context.character

        -- Tells whether every witness still holds.
        -- @return boolean  True while the environment and string-library witnesses hold, no involved table has a
        --   metatable, the owner context is the same, and the continuation check passes.
        local function current()
            local classReadable, classEnvironment = executionProtect(executionGetfenv, isClass)

            if not classReadable or classEnvironment ~= executionClassEnvironment then
                return false
            end
            if
                reader.IsCurrent ~= ownedReaderIsCurrent
                or type ~= guardType
                or pairs ~= guardPairs
                or getmetatable ~= guardGetmetatable
                or rawget ~= guardRawget
                or getfenv ~= executionGetfenv
                or guardGetmetatable('') ~= executionStringMeta
                or guardRawget(executionStringMeta, '__index') ~= executionStringIndex
            then
                return false
            end

            local findSource = executionStringIndex or executionStringLibrary

            if guardRawget(findSource, 'find') ~= executionFind then
                return false
            end

            for i = 1, #tables do
                if guardGetmetatable(tables[i]) ~= nil then
                    return false
                end
            end

            if guardRawget(c, 'class') ~= expectedClass or guardRawget(c, 'character') ~= expectedCharacter then
                return false
            end

            return continuation() == true
        end

        if not current() then
            return
        end

        if notify ~= nil then
            if guardType(notify) ~= 'function' then
                return
            end

            executionWatch = { meta = meta, notify = notify }
        end

        return current, continuation
    end

    -- Lists every record the owner context can run, with record seals.
    -- @param number number  The specialization key whose fallback applies.
    -- @param c table  The owner context { class, character }.
    -- @return table[]|nil  The rows { address (detached), seal } for the class and character owners, all specialization
    --   partitions; nil when not ready.
    -- @return table|string  A seal for the whole list; the reason code when the first return is nil.
    function reader:ListOwned(number, c)
        local ready, reason = readerReady(true)

        if not ready then
            return nil, reason
        end

        local items, problem = privateRows(number, c)

        if not items then
            return nil, problem
        end

        local rows = {}

        for _, meta in ipairs(items) do
            rows[#rows + 1] = { address = detachedAddress(meta.address), seal = recordSeal(meta, c) }
        end

        local seal = {}
        readSeals[seal] = { kind = 'list', epoch = readEpoch, spec = number, items = items, context = contextCopy(c) }
        return rows, seal
    end

    -- Lends the live record to a projector callback.
    -- @param a table  The address.
    -- @param c table  The owner context { class, character }.
    -- @param project function  Called as project(record, seal); it must run synchronously (not in a coroutine), must
    --   not re-enter the reader and must not keep the record.
    -- @return boolean|nil  True when read; nil on failure.
    -- @return any  The projector's value; the reason code when the first return is nil.
    -- @return table|nil  The record seal.
    --
    -- The seal is checked again afterward and the read fails if the record changed meanwhile.
    function reader:Read(a, c, project)
        local ready, reason = readerReady(true)

        if not ready then
            return nil, reason
        end
        if coroutine.running() ~= nil then
            return nil, 'invalid-rotation-read-context'
        end
        if type(project) ~= 'function' then
            return nil, 'invalid-rotation-read-callback'
        end

        -- Validate before copying the small address/context; never copy payload.
        if not validAddress(a) then
            return nil, 'invalid-address'
        end
        if not privateContext(c) then
            return nil, 'missing-owner-context'
        end

        local allowed, problem = visible(a, c)

        if not allowed then
            return nil, problem
        end

        local address, context = detachedAddress(a), contextCopy(c)
        local meta, errorText = privateRecord(address, context)

        if not meta then
            return nil, errorText
        end

        local seal = recordSeal(meta, context)
        readerBusy = true
        local ok, value = pcall(project, meta.record, seal)
        readerBusy = false

        if not ok then
            return nil, 'rotation-read-callback-failed'
        end
        if not sameContext(context, c) then
            return nil, 'rotation-read-context-changed'
        end

        ready, reason = self:IsCurrent(seal, context)

        if not ready then
            return nil, reason
        end

        return true, value, seal
    end

    -- Permanently disables the reader and drops the execution watch; later reads answer 'retired-rotation-reader'.
    -- @return boolean  Always true.
    function reader:Retire()
        invalidateExecutionWatch()
        readerState = 'retired'
        return true
    end

    -- Reads a record.
    -- @param a table  The address.
    -- @param c table  The owner context { class, character }.
    -- @return table|nil  A detached copy of the record at the address; nil on failure.
    -- @return table|string|nil  A token to pass back as `expected` when planning an edit; the reason code
    --   ('unknown-rotation' when absent) when the first return is nil.
    -- @return table|nil  The body's validation result.
    function service:Get(a, c)
        local allowed, record = readRecord(a, c)

        if not allowed then
            return nil, record
        end
        if not record then
            return nil, 'unknown-rotation'
        end

        local lease = capture(a)
        local token = {}
        tokens[token] = lease
        return copyRecord(record), token, data.ValidateBody(record.body, options.validation)
    end

    -- Builds a result row.
    -- @param a table  The address.
    -- @param record table  The record.
    -- @return table  { address (detached), record (a detached copy), validation (of the body) }.
    local function row(a, record)
        return {
            address = copied(a),
            record = copyRecord(record),
            validation = data.ValidateBody(record.body, options.validation),
        }
    end

    -- Sorts rows in place by scope, class, owner, specialization and id.
    -- @param rows table[]  The rows.
    -- @return table[]  The same rows.
    local function sort(rows)
        table.sort(rows, function(a, b)
            local x, y = a.address, b.address

            for _, key in ipairs({ 'scope', 'class', 'owner' }) do
                if x[key] ~= y[key] then
                    return (x[key] or '') < (y[key] or '')
                end
            end

            if x.spec ~= y.spec then
                return x.spec < y.spec
            end

            return x.id < y.id
        end)

        return rows
    end

    -- Lists the rows saved under one specialization key for the caller's class owner and character owner.
    -- @param number number  The specialization key.
    -- @param c table  The owner context { class, character }.
    -- @return table[]|nil  The sorted rows (detached copies with validation); nil on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- Work is proportional to those two partitions, not to the whole store.
    function service:ListVisible(number, c)
        if not spec(number) then
            return nil, 'invalid-specialization'
        end
        if not plain(c) or not isClass(c.class) then
            return nil, 'missing-owner-context'
        end

        local result = {}

        -- Appends the rows of one owner at the requested specialization key, checking the index count.
        -- @param kind string  'class' or 'character'.
        -- @param owner string  The owner name.
        -- @return boolean|nil  True when appended; nil on failure.
        -- @return string|nil  The reason code when the first return is nil; nil otherwise.
        local function add(kind, owner)
            local a = { scope = kind, class = c.class, owner = owner, spec = number, id = options.fallbackID }
            local allowed, rows, scope = readRows(a, c)

            if not allowed then
                return nil, rows
            end

            local count = 0

            for id, record in pairs(rows or {}) do
                if not text(id, 128) or scope.records[id] ~= record then
                    return nil, 'stale-store-index'
                end

                count = count + 1
                a.id = id
                local valid, reason = selected(record, a)

                if not valid then
                    return nil, reason
                end

                result[#result + 1] = row(a, record)
            end

            if count ~= (scope and scope.count or 0) then
                return nil, 'stale-store-index'
            end

            return true
        end

        local allowed, reason = add('class', c.class)

        if not allowed then
            return nil, reason
        end

        local character

        if type(c.character) == 'string' then
            character = state.characters[c.character]
        end

        if character ~= nil and not plain(character) then
            return nil, 'invalid-store'
        end

        if not character or character.class == c.class then
            if text(c.character, 512) then
                allowed, reason = add('character', c.character)

                if not allowed then
                    return nil, reason
                end
            end
        end

        return sort(result)
    end

    -- Reads the fallback rotation row for a specialization key.
    -- @param number number  The specialization key.
    -- @param c table  The owner context { class, character }.
    -- @return table|nil  The character's own row when it has one, else the class's; nil when neither exists.
    -- @return string|nil  'invalid-fallback' or 'unavailable-fallback' when the row is found but cannot be used;
    --   'unknown-rotation' or another reason when the first return is nil; nil otherwise.
    function service:GetFallback(number, c)
        if not plain(c) or not isClass(c.class) or not text(c.character, 512) then
            return nil, 'missing-owner-context'
        end
        if not spec(number) then
            return nil, 'invalid-specialization'
        end

        local found

        for _, kind in ipairs({ 'character', 'class' }) do
            local a = {
                scope = kind,
                class = c.class,
                owner = kind == 'class' and c.class or c.character,
                spec = number,
                id = options.fallbackID,
            }

            local allowed, record = readRecord(a, c)

            if not allowed then
                return nil, record
            end

            if record then
                found = row(a, record)
                break
            end
        end

        if not found then
            return nil, 'unknown-rotation'
        end
        if not found.validation.valid then
            return found, 'invalid-fallback'
        end
        if not found.validation.supported or not found.validation.resolved then
            return found, 'unavailable-fallback'
        end

        return found
    end

    -- Re-validates the whole state and rebuilds the indexes.
    -- @return boolean|nil  True when refreshed; nil when validation fails, in which case nothing is replaced.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- Needed after any outside change to the store; it retires every outstanding token and plan.
    function service:Refresh()
        local valid, reason = validState(state)

        if not valid then
            return nil, reason
        end

        local replacement = buildIndex()
        index = replacement
        tokens = setmetatable({}, { __mode = 'k' })
        plans = setmetatable({}, { __mode = 'k' })

        if readIndex then
            resetReaderIndex()
        end

        return true
    end

    -- Lists every stored record of every owner, plus one row per unassigned legacy entry (scope 'legacy').
    -- @return table[]|nil  The sorted rows; nil on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- Validates the whole store, so it is the expensive full inventory.
    function service:AllStored()
        local valid, reason = validState(state)

        if not valid then
            return nil, reason
        end

        local result = {}

        -- Appends rows for every record in one owner's spec map.
        -- @param scope string  'class' or 'character'.
        -- @param owner string  The owner name.
        -- @param class string  The class token.
        -- @param map table  The owner's spec map.
        local function add(scope, owner, class, map)
            for number, rows in pairs(map) do
                for id, record in pairs(rows) do
                    result[#result + 1] = row({
                        scope = scope,
                        class = class,
                        owner = owner,
                        spec = number,
                        id = id,
                    }, record)
                end
            end
        end

        for class, map in pairs(state.classes) do
            add('class', class, class, map)
        end

        for owner, bucket in pairs(state.characters) do
            add('character', owner, bucket.class, bucket.specs)
        end

        local union = {}

        for kind, component in pairs(legacyKinds) do
            for number, rows in pairs(state.legacy[kind] or {}) do
                union[number] = union[number] or {}

                for id, value in pairs(rows) do
                    local record = union[number][id] or {}
                    union[number][id] = record
                    record[component] = copied(value)
                end
            end
        end

        for number, rows in pairs(union) do
            for id, record in pairs(rows) do
                result[#result + 1] = {
                    address = { scope = 'legacy', spec = number, id = id },
                    record = record,
                    validation = data.ValidateBody(record.body, options.validation),
                }
            end
        end

        return sort(result)
    end

    -- Plans adding a new record at an unused address.
    -- @param a table  The address.
    -- @param record table  The record to add.
    -- @param c table  The owner context { class, character }.
    -- @return table|nil  A plan to pass to Commit; nil on failure.
    -- @return string|nil  The reason code (such as 'rotation-id-collision') when the first return is nil; nil
    --   otherwise.
    --
    -- Nothing is written until Commit.
    function service:PlanCreate(a, record, c)
        local allowed, reason = target(a, c)

        if not allowed then
            return nil, reason
        end
        if locate(a) ~= nil then
            return nil, 'rotation-id-collision'
        end

        local payload, problem = prepare(record, a)

        if not payload then
            return nil, problem
        end

        return plan('create', a, c, nil, payload)
    end

    -- Plans replacing the record at an address.
    -- @param a table  The address.
    -- @param record table  The new record.
    -- @param c table  The owner context { class, character }.
    -- @param expected table  The token from Get; the plan fails as 'stale-rotation-record' if the record changed since.
    -- @return table|nil  A plan to pass to Commit; nil on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    function service:PlanReplace(a, record, c, expected)
        local allowed, reason = target(a, c)

        if not allowed then
            return nil, reason
        end

        local lease, problem = checkExpected(a, expected)

        if not lease then
            return nil, problem
        end

        local payload, errorText = prepare(record, a)

        if not payload then
            return nil, errorText
        end

        return plan('replace', a, c, lease, payload)
    end

    -- Plans deleting the record at an address.
    -- @param a table  The address.
    -- @param c table  The owner context { class, character }.
    -- @param expected table  The token from Get.
    -- @return table|nil  A plan to pass to Commit; nil on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    function service:PlanDelete(a, c, expected)
        local allowed, reason = target(a, c)

        if not allowed then
            return nil, reason
        end

        local lease, problem = checkExpected(a, expected)

        if not lease then
            return nil, problem
        end

        return plan('delete', a, c, lease)
    end

    -- Plans moving a record to a different owner (for example class to character).
    -- @param a table  The source address.
    -- @param destination table  The destination address, with the same id, specialization and class; it must be free.
    -- @param c table  The owner context { class, character }.
    -- @param expected table  The token from Get.
    -- @param replacement table|nil  A replacement record; the record keeps its content unless one is given.
    -- @return table|nil  A plan to pass to Commit; nil on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    function service:PlanMove(a, destination, c, expected, replacement)
        local allowed, reason = target(a, c)

        if not allowed then
            return nil, reason
        end

        allowed, reason = target(destination, c)

        if not allowed then
            return nil, reason
        end
        if
            a.id ~= destination.id
            or a.spec ~= destination.spec
            or a.class ~= destination.class
            or a.scope == destination.scope and a.owner == destination.owner
        then
            return nil, 'invalid-move-destination'
        end

        local lease, problem = checkExpected(a, expected)

        if not lease then
            return nil, problem
        end
        if locate(destination) ~= nil then
            return nil, 'rotation-id-collision'
        end

        local payload, errorText = prepare(replacement or lease.baseline, destination)

        if not payload then
            return nil, errorText
        end

        return plan('move', a, c, lease, payload, destination)
    end

    -- Records a lease on one legacy archive entry across the four legacy maps, with a baseline copy.
    -- @param selection table  The entry { spec, id }.
    -- @return table  { selection, record, baseline, chain, roots }.
    local function legacyCapture(selection)
        local record, chain = {}, {}

        for kind, component in pairs(legacyKinds) do
            local map = state.legacy[kind]
            local rows = map and map[selection.spec]
            local value = rows and rows[selection.id]
            record[component] = value
            chain[kind] = { map or false, rows or false, value }
        end

        return {
            selection = copied(selection),
            record = record,
            baseline = copyRecord(record),
            chain = chain,
            roots = roots(),
        }
    end

    -- Tells whether a legacy lease still holds.
    -- @param lease table  The lease from legacyCapture.
    -- @return boolean  True while the roots, the containers and the content are unchanged.
    local function legacyAlive(lease)
        if not sameRoots(lease.roots) then
            return false
        end

        local current = legacyCapture(lease.selection)

        if not equal(current.record, lease.baseline) then
            return false
        end

        for kind, chain in pairs(lease.chain) do
            for i = 1, 3 do
                if chain[i] ~= current.chain[kind][i] then
                    return false
                end
            end
        end

        return true
    end

    -- Plans adopting one unassigned legacy entry into an owner.
    -- @param selection table  The legacy entry { spec, id }.
    -- @param destination table  The destination address (same id and specialization).
    -- @param c table  The owner context { class, character }.
    -- @return table|nil  A plan to pass to Commit; nil on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- The entry's body and sidecars become a record at the destination and the legacy entry is removed on Commit.
    function service:PlanLegacyAdoption(selection, destination, c)
        if
            not fields(selection, { spec = true, id = true }) or not spec(selection.spec) or not text(selection.id, 128)
        then
            return nil, 'invalid-legacy-selection'
        end

        local allowed, reason = target(destination, c)

        if not allowed then
            return nil, reason
        end
        if selection.id ~= destination.id or selection.spec ~= destination.spec then
            return nil, 'invalid-move-destination'
        end
        if locate(destination) ~= nil then
            return nil, 'rotation-id-collision'
        end

        local lease = legacyCapture(selection)

        if lease.record.body == nil then
            return nil, 'unknown-rotation'
        end

        local payload, problem = prepare(lease.record, destination)

        if not payload then
            return nil, problem
        end

        return plan('adopt', destination, c, lease, payload, destination)
    end

    -- Stores a record (or removes it) at an address, creating the owner bucket and specialization rows when missing.
    -- @param a table  The address.
    -- @param value table|nil  The record; nil removes it.
    --
    -- Plain table assignments only; callers have validated everything first.
    local function write(a, value)
        local root = a.scope == 'class' and state.classes or state.characters
        local bucket = root[a.owner]

        if not bucket then
            bucket = a.scope == 'class' and {} or { class = a.class, specs = {} }
            root[a.owner] = bucket
        end

        local map = a.scope == 'class' and bucket or bucket.specs
        local rows = map[a.spec]

        if not rows then
            rows = {}
            map[a.spec] = rows
        end

        rows[a.id] = value
    end

    -- Applies a plan once.
    -- @param public table  The plan returned by a Plan* method.
    -- @param c table  The owner context { class, character }.
    -- @return boolean|nil  True when applied; nil on failure.
    -- @return table|string|nil  The destination address; the reason code ('invalid-plan', 'stale-rotation-record', ...)
    --   when the first return is nil.
    --
    -- Everything is re-checked first (owner context, roots, leases, collisions, the payload), the writes are plain
    -- assignments with no callbacks, then the indexes advance and the plan is consumed.
    function service:Commit(public, c)
        local pending = plans[public]

        if not pending then
            return nil, 'invalid-plan'
        end

        local destination = pending.destination or pending.address
        local allowed, reason = target(destination, c)

        if not allowed then
            return nil, reason
        end

        if pending.operation ~= 'adopt' then
            allowed, reason = target(pending.address, c)

            if not allowed then
                return nil, reason
            end
        end

        if c.class ~= pending.context.class or c.character ~= pending.context.character then
            return nil, 'foreign-owner'
        end
        if not sameRoots(pending.roots) then
            return nil, 'stale-rotation-record'
        end
        if
            pending.source
            and not (pending.operation == 'adopt' and legacyAlive(pending.source) or pending.operation ~= 'adopt'
                and alive(pending.source))
        then
            return nil, 'stale-rotation-record'
        end

        if pending.operation == 'create' or pending.operation == 'move' or pending.operation == 'adopt' then
            if locate(destination) ~= nil then
                return nil, 'rotation-id-collision'
            end
            if not alive(pending.target) then
                return nil, 'stale-rotation-record'
            end
        end

        local payload

        if pending.record then
            payload, reason = prepare(pending.record, destination)

            if not payload then
                return nil, reason
            end
        end

        local advanceDestination, advanceSource

        if readIndex then
            advanceDestination = readRows(destination, c, readIndex)

            if pending.operation == 'move' then
                advanceSource = readRows(pending.address, c, readIndex)
            end
        end

        -- A successful write with an unadvanceable stale
        -- index must retire private publication witnesses, without blessing it
        -- or changing public unrelated-record seal semantics.
        if readIndex and (not advanceDestination or pending.operation == 'move' and not advanceSource) then
            invalidateExecutionWatch()
            publicationWriteVersion = publicationWriteVersion + 1
        end

        if watchedAddress(destination) or watchedAddress(pending.address) then
            invalidateExecutionWatch()
        end

        -- All checks and copies precede plain table assignments; no callbacks run.
        if pending.operation == 'delete' then
            write(pending.address, nil)
        else
            write(destination, payload)

            if pending.operation == 'move' then
                write(pending.address, nil)
            elseif pending.operation == 'adopt' then
                for kind in pairs(legacyKinds) do
                    local map = state.legacy[kind]
                    local rows = map and map[pending.source.selection.spec]

                    if rows then
                        rows[pending.source.selection.id] = nil
                    end
                end
            end
        end

        index = buildIndex()

        if advanceDestination then
            advanceReaderAddress(destination)
        end
        if advanceSource then
            advanceReaderAddress(pending.address)
        end

        plans[public] = nil
        return true, copied(destination)
    end

    if options.bindInternalReader then
        local bound = pcall(options.bindInternalReader, reader)

        if not bound then
            readerState = 'retired'
            return nil, 'internal-reader-bind-failed'
        end

        if readerState == 'retired' then
            return nil, 'retired-rotation-reader'
        end

        local valid, reason = validState(state)

        if not valid then
            readerState = 'retired'
            return nil, reason
        end

        index = buildIndex()
        resetReaderIndex()
        readerState = 'active'
    end

    -- Keep this capability out of the mutable reader callback transport.
    return service, nil, makePublicationGuard, makeExecutionGuard
end

local ownedRotationStoreFactory = data.NewRotationStore
local storeFactoryEnvironment = type(getfenv) == 'function' and getfenv(1) or nil

-- Hands the owned store factory (and the environment it was loaded in) to a trusted binder.
-- @param bind function  Called with the factory and the environment.
--
-- Core/rotation_scope.lua captures both at load and then removes this public name, so it can tell the original factory
-- from a replacement.
function data.BindOwnedRotationStoreFactory(bind)
    if type(bind) == 'function' then
        bind(ownedRotationStoreFactory, storeFactoryEnvironment)
    end
end

-- BEGIN CPU RUNTIME WORK HANDOFF
do
    local bind = addon.BindCPURuntimeWorkDiagnostic

    if type(bind) == 'function' then
        bind(addon, 'store', data.NewRotationStore, function() return plain, fields, validAddress end)
    end
end
-- END CPU RUNTIME WORK HANDOFF
