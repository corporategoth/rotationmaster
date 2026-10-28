-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Observes what a rotation's validity depends on (the condition registry and its version, item sets, effects, the
-- profile and global tables) and hands the validator copies of those maps plus a stamp that changes whenever any of
-- them does. Owns the observation state, the validation stamp and the check that a body references no disabled
-- condition; it must never write to SavedVariables and must not materialize AceDB defaults (it reads with rawget where
-- a missing key could). With a managed dependency reader (Core/dependency_revisions.lua) observation is constant time;
-- without one it compares entry identities. Loaded from RotationMaster.toc after Core/itemset_services.lua; the private
-- proof helpers are handed once to Core/rotation_library.lua through addon:BindRotationValidationReader and to CPU
-- diagnostics at the end.

local _, addon = ...
local observed, stamp
local dependencyReader
local bindDependency = addon.BindRotationDependencyReader

if type(bindDependency) == 'function' then
    bindDependency(addon, function(reader)
        if type(reader) == 'function' then
            dependencyReader = reader
        end
    end)

    addon.BindRotationDependencyReader = nil
end

local dependencyIdentity = rawequal
local managed
local runtimeAuthority, ownedOptions, ownedDisabledDependency
-- Trusted standard primitives at module load; changed live pointers disable reuse.
local proofPairs, proofRawget, proofRawequal, proofType, proofGetmetatable = pairs, rawget, rawequal, type, getmetatable
-- Lua5.1 accepts a stack level or function; the checker declares only levels.
---@type fun(f: number|function): table
local proofGetfenv = getfenv
local proofEnvironment = proofType(proofGetfenv) == 'function' and proofGetfenv(1) or nil

-- ============================================================================
-- Entry maps and comparison helpers
-- ============================================================================

-- Returns a stable marker for a map entry.
-- @param value any  The entry.
-- @return table|boolean  The table itself, or false for anything else, so malformed entries compare equal each time.
local function normalized(value)
    return type(value) == 'table' and value or false
end

-- Copies a map into `{ key = table-or-false }`, never touching the source.
-- @param value any  The map; a non-table gives an empty copy.
-- @return table  The copy.
-- @return number  The number of entries.
local function entries(value)
    local result, count = {}, 0

    if type(value) == 'table' then
        for key, item in pairs(value) do
            result[key] = normalized(item)
            count = count + 1
        end
    end

    return result, count
end

-- Reports whether a map still holds exactly the entries recorded earlier, compared by identity.
-- @param value any  The map to check.
-- @param previous table  The entries recorded by entries().
-- @param expected number  The entry count recorded by entries().
-- @return boolean  True when it does.
local function sameEntries(value, previous, expected)
    local count = 0

    if type(value) == 'table' then
        for key, item in pairs(value) do
            if not rawequal(type(item) == 'table' and item or false, previous[key]) then
                return false
            end

            count = count + 1
        end
    end

    return count == expected
end

-- Reports whether each item-set map is absent or a table; anything else is treated as no item sets.
-- @param shared any  The shared item sets.
-- @param personal any  The per-profile item sets.
-- @return boolean  True when both are acceptable.
local function validItemsets(shared, personal)
    return (shared == nil or type(shared) == 'table') and (personal == nil or type(personal) == 'table')
end

-- Like sameEntries for the merged shared and personal item sets: a personal entry shadows the shared one of the same
-- key.
-- @param shared any  The shared item sets.
-- @param personal any  The per-profile item sets.
-- @param previous table  The entries recorded by itemsetEntries().
-- @param expected number  The entry count recorded by itemsetEntries().
-- @return boolean  True when they still match.
local function sameItemsets(shared, personal, previous, expected)
    if not validItemsets(shared, personal) then
        return expected == 0
    end

    local count = 0

    if shared then
        for key, item in pairs(shared) do
            -- Only actual personal entries shadow shared entries. A missing-key
            -- lookup could materialize an AceDB default and mutate the source.
            if not personal or rawget(personal, key) == nil then
                if not rawequal(type(item) == 'table' and item or false, previous[key]) then
                    return false
                end

                count = count + 1
            end
        end
    end

    if personal then
        for key, item in pairs(personal) do
            if not rawequal(type(item) == 'table' and item or false, previous[key]) then
                return false
            end

            count = count + 1
        end
    end

    return count == expected
end

-- Merges shared and personal item sets (personal wins).
-- @param shared any  The shared item sets.
-- @param personal any  The per-profile item sets.
-- @return table  The merged copy ({} when either map is invalid).
-- @return number  The merged entry count.
local function itemsetEntries(shared, personal)
    if not validItemsets(shared, personal) then
        return {}, 0
    end

    local result, count = entries(shared)

    if personal then
        for key, item in pairs(personal) do
            if result[key] == nil then
                count = count + 1
            end

            result[key] = normalized(item)
        end
    end

    return result, count
end

-- ============================================================================
-- Observing dependencies
-- ============================================================================

-- Condition support (Core/condition_support.lua) depends on the client. The
-- platform recomputes its client facts when GetClientInfo or the project
-- changes (only test harnesses do either); the same change advances the
-- condition registry version, so every validation stamp moves with it.
local clientGetter, clientProject

-- Advances the condition registry version when the platform's client facts changed (only test harnesses do that), so
-- every validation stamp moves with it.
-- @param owner table  The addon, whose conditionRegistryVersion is advanced.
local function observeClient(owner)
    local platform = rawget(addon, 'Platform')
    local getter = type(platform) == 'table' and platform.GetClientInfo or nil
    local project = WOW_PROJECT_ID

    if getter == clientGetter and project == clientProject then
        return
    end

    local first = clientGetter == nil and clientProject == nil
    clientGetter, clientProject = getter, project

    if not first then
        owner.conditionRegistryVersion = (owner.conditionRegistryVersion or 0) + 1
    end
end

-- Asks Core/condition_support.lua whether a condition works on this client.
-- @param tag string  The condition tag.
-- @param definition table|nil  The condition definition.
-- @param value table|nil  The condition value.
-- @return string|nil  The reason; nil when supported.
local function support(tag, definition, value)
    local check = addon.GetConditionSupport

    if type(check) == 'function' then
        return check(addon, tag, definition, value)
    end
end

-- Asks Core/raid_mark_buttons.lua whether a step works on this client (only a Set Mark step can be unsupported).
-- @param step table  The rotation step to check.
-- @return string|nil  The reason the step is unsupported on this client; nil when it is supported.
local function stepSupport(step)
    local check = addon.GetStepSupport

    if type(check) == 'function' then
        return check(addon, step)
    end
end

-- Observes the dependencies by comparing entry identities, replacing the stamp when anything changed.
-- @param owner table  The addon.
--
-- Observe identities without copying maps on the common unchanged path. Normalized false markers keep malformed/NaN
-- entries stable, as before.
local function observeLegacy(owner)
    observeClient(owner)
    local profile, global = owner.db.profile, owner.db.global
    local shared, personal = global.itemsets, profile.itemsets
    local conditions, effects = owner.conditionDefinitions, global.effects
    local version = owner.conditionRegistryVersion or 0

    if
        observed
        and observed.profile == profile
        and observed.global == global
        and observed.version == version
        and sameItemsets(shared, personal, observed.itemsets, observed.itemsetCount)
        and sameEntries(conditions, observed.conditions, observed.conditionCount)
        and sameEntries(effects, observed.effects, observed.effectCount)
    then
        return
    end

    local itemsets, itemsetCount = itemsetEntries(shared, personal)
    local conditionEntries, conditionCount = entries(conditions)
    local effectEntries, effectCount = entries(effects)

    observed = {
        profile = profile,
        global = global,
        version = version,
        itemsets = itemsets,
        itemsetCount = itemsetCount,
        conditions = conditionEntries,
        conditionCount = conditionCount,
        effects = effectEntries,
        effectCount = effectCount,
    }

    stamp = {}
end

-- Observes the dependencies (the managed reader when there is one, else the legacy comparison).
-- @param owner table  The addon.
-- @return table  The observation (private maps and roots).
-- @return table  The validation stamp.
--
-- Managed ownership does not require plain/default-free maps. AceDB may materialize default metatables; contents change
-- through explicit publication. Public options copy actual source maps, never a retained private map.
local function observe(owner)
    if not dependencyReader or not dependencyIdentity(owner, addon) then
        observeLegacy(owner)
        return observed, stamp
    end

    observeClient(owner)
    local epoch = dependencyReader(owner)
    local db = owner.db
    local profile, global = db.profile, db.global
    local conditions, version = owner.conditionDefinitions, owner.conditionRegistryVersion or 0
    local shared, personal, effects = global.itemsets, profile.itemsets, global.effects

    if
        not managed
        or not dependencyIdentity(managed.epoch, epoch)
        or not dependencyIdentity(managed.db, db)
        or not dependencyIdentity(managed.profile, profile)
        or not dependencyIdentity(managed.global, global)
        or not dependencyIdentity(managed.conditions, conditions)
        or not dependencyIdentity(managed.shared, shared)
        or not dependencyIdentity(managed.personal, personal)
        or not dependencyIdentity(managed.effects, effects)
        or not dependencyIdentity(managed.version, version)
    then
        managed = {
            epoch = epoch,
            db = db,
            profile = profile,
            global = global,
            conditions = conditions,
            shared = shared,
            personal = personal,
            effects = effects,
            version = version,
            stamp = {},
        }
    end

    -- Public options copy actual source maps, never a retained private map.
    -- Capture this invocation's roots and generation before live iteration.
    return managed, managed.stamp
end

-- Returns the validation stamp, which changes whenever any dependency does.
-- @return table  The stamp (compare by identity).
--
-- Internal authority checks need the current stamp, not detached public maps. Keep checking every dependency at each
-- call, including reentrant mutations.
function addon:GetRotationValidationStamp()
    local _, current = observe(self)
    return current
end

local ownedValidationStamp = addon.GetRotationValidationStamp

-- ============================================================================
-- Proofs that observation is callback-free
-- ============================================================================

-- Reports whether the native primitives this module relies on are still the originals in the owned environment.
-- @return boolean  True only then.
--
-- Even protected metatable metadata can disguise a callback. Only native primitives stored directly in the owned
-- environment can certify this path.
local function proofGlobals()
    return proofType(proofEnvironment) == 'table'
        and proofRawequal(proofRawget(proofEnvironment, 'pairs'), proofPairs)
        and proofRawequal(proofRawget(proofEnvironment, 'rawget'), proofRawget)
        and proofRawequal(proofRawget(proofEnvironment, 'rawequal'), proofRawequal)
        and proofRawequal(proofRawget(proofEnvironment, 'type'), proofType)
        and proofRawequal(proofRawget(proofEnvironment, 'getmetatable'), proofGetmetatable)
        and proofRawequal(proofRawget(proofEnvironment, 'getfenv'), proofGetfenv)
        and proofRawequal(proofGetfenv(ownedValidationStamp), proofEnvironment)
        and proofRawequal(proofGetfenv(observe), proofEnvironment)
        and proofRawequal(proofGetfenv(observeLegacy), proofEnvironment)
        and proofRawequal(proofGetfenv(normalized), proofEnvironment)
        and proofRawequal(proofGetfenv(entries), proofEnvironment)
        and proofRawequal(proofGetfenv(sameEntries), proofEnvironment)
        and proofRawequal(proofGetfenv(validItemsets), proofEnvironment)
        and proofRawequal(proofGetfenv(sameItemsets), proofEnvironment)
        and proofRawequal(proofGetfenv(itemsetEntries), proofEnvironment)
end

-- Reports whether a value is a table without a metatable, the only layout whose reads are guaranteed callback-free.
-- @param value any  The value.
-- @return boolean  True for such a table.
local function proofPlain(value)
    return proofType(value) == 'table' and proofGetmetatable(value) == nil
end

-- Finds the roots a callback-free validation observation reads.
-- @param owner any  The addon.
-- @param method function  The GetRotationValidationStamp method the caller is about to use.
-- @return table|nil  The db; nil (with nothing else) when the layout cannot be proved callback-free.
-- @return table  The profile.
-- @return table  The global table.
-- @return table  The condition definitions.
-- @return table  The shared item sets.
-- @return table  The per-profile item sets.
-- @return table  The effects.
-- @return number  The condition registry version.
-- @return table  The profile's rotation library state.
--
-- Only raw-present, callback-free layouts can join adjacent observations. AceAddon owners and AceDB db objects may have
-- metatables: every accessed slot is raw-present, and neither object participates in equality/tostring. Public option
-- copying uses live pairs; a prior override can retain its private input maps. Their later lookups must remain
-- callback-free too.
local function validationLayout(owner, method)
    if
        proofType(owner) ~= 'table'
        or method ~= ownedValidationStamp
        or proofRawget(owner, 'GetRotationValidationStamp') ~= ownedValidationStamp
    then
        return
    end

    -- Public option copying uses live pairs; a prior override can retain its
    -- private input maps. Their later lookups must remain callback-free too.
    if
        not proofPlain(observed)
        or not proofPlain(stamp)
        or not proofPlain(proofRawget(observed, 'itemsets'))
        or not proofPlain(proofRawget(observed, 'conditions'))
        or not proofPlain(proofRawget(observed, 'effects'))
    then
        return
    end

    local db = proofRawget(owner, 'db')

    if proofType(db) ~= 'table' then
        return
    end

    local profile, global = proofRawget(db, 'profile'), proofRawget(db, 'global')

    if not proofPlain(profile) or not proofPlain(global) then
        return
    end

    local conditions, version = proofRawget(owner, 'conditionDefinitions'), proofRawget(
        owner,
        'conditionRegistryVersion'
    )

    local shared, personal = proofRawget(global, 'itemsets'), proofRawget(profile, 'itemsets')
    local effects, state = proofRawget(global, 'effects'), proofRawget(profile, 'rotationLibrary')

    if
        not proofPlain(conditions)
        or proofType(version) ~= 'number'
        or not proofPlain(shared)
        or not proofPlain(personal)
        or not proofPlain(effects)
        or not proofPlain(state)
    then
        return
    end

    return db, profile, global, conditions, shared, personal, effects, version, state
end

-- Re-runs validationLayout and reports whether every root it finds is the identical object the caller recorded.
-- @param owner any  The addon.
-- @param method function  The GetRotationValidationStamp method.
-- @param db table  The recorded db.
-- @param profile table  The recorded profile.
-- @param global table  The recorded global table.
-- @param conditions table  The recorded condition definitions.
-- @param shared table  The recorded shared item sets.
-- @param personal table  The recorded per-profile item sets.
-- @param effects table  The recorded effects.
-- @param version number  The recorded condition registry version.
-- @param state table  The recorded rotation library state.
-- @return boolean  True only when every root is unchanged.
local function sameValidationLayout(
    owner,
    method,
    db,
    profile,
    global,
    conditions,
    shared,
    personal,
    effects,
    version,
    state
)
    local d, p, g, c, s, i, e, v, l = validationLayout(owner, method)

    return d ~= nil
        and proofRawequal(d, db)
        and proofRawequal(p, profile)
        and proofRawequal(g, global)
        and proofRawequal(c, conditions)
        and proofRawequal(s, shared)
        and proofRawequal(i, personal)
        and proofRawequal(e, effects)
        and proofRawequal(v, version)
        and proofRawequal(l, state)
end

-- Reads the validation stamp through a method for Core/rotation_library.lua.
-- @param owner table  The addon.
-- @param method function  The GetRotationValidationStamp method to call.
-- @param entryMethod function  The method as the caller first saw it.
-- @return table  The stamp.
-- @return table|nil  The db seen before the read; nil (with the eight below) when the owned scan could not be proved
--   callback-free, so the caller has nothing to confirm afterwards.
-- @return table|nil  The profile seen before the read.
-- @return table|nil  The global table seen before the read.
-- @return table|nil  The condition definitions seen before the read.
-- @return table|nil  The shared item sets seen before the read.
-- @return table|nil  The per-profile item sets seen before the read.
-- @return table|nil  The effects seen before the read.
-- @return number|nil  The condition registry version seen before the read.
-- @return table|nil  The profile's rotation library state seen before the read.
--
-- A successful PRE proof closes the owned scan. POST checks raw layout again, without repeating globals that no
-- permitted callback can change.
local function readValidationStamp(owner, method, entryMethod)
    if dependencyReader and dependencyIdentity(owner, addon) then
        local value = method(owner)
        return value
    end

    local db, profile, global, conditions, shared, personal, effects, version, state

    -- A successful PRE proof closes the owned scan. POST checks raw layout
    -- again, without repeating globals that no permitted callback can change.
    if entryMethod == ownedValidationStamp and proofGlobals() then
        db, profile, global, conditions, shared, personal, effects, version, state = validationLayout(owner, method)
    end

    local value = method(owner)

    if db then
        return value, db, profile, global, conditions, shared, personal, effects, version, state
    end

    return value
end

-- Hands the private proof helpers to Core/rotation_library.lua.
-- @param bind function  Called with readValidationStamp, sameValidationLayout, the native primitives, runtimeAuthority,
--   the owned options method and the owned disabled-dependency method.
-- @return boolean|nil  True when handed over; nil when `bind` is not a function.
-- @return string|nil  'invalid-validation-reader-binder' when the first return is nil; nil otherwise.
--
-- Trusted private module handoff, retired by its consumer. This does not authenticate a hostile replacement of the
-- complete loader/binder itself.
function addon:BindRotationValidationReader(bind)
    if type(bind) ~= 'function' then
        return nil, 'invalid-validation-reader-binder'
    end

    bind(
        readValidationStamp,
        sameValidationLayout,
        proofRawget,
        proofRawequal,
        proofType,
        proofGetmetatable,
        runtimeAuthority,
        ownedOptions,
        ownedDisabledDependency
    )

    return true
end

-- ============================================================================
-- Validator options and disabled-dependency scan
-- ============================================================================

-- Returns the options the rotation validator runs under: fresh copies of the dependency maps.
-- @return table  { conditions, itemsets, effects, support }.
-- @return table  The validation stamp.
--
-- Dependency maps may carry AceDB defaults metatables. Observe their entries, without copying/traversing definitions or
-- writing into SavedVariables. Public maps remain fresh: consumers cannot poison private observations.
function addon:GetRotationValidationOptions()
    local snapshot, current = observe(self)
    -- Public maps remain fresh: consumers cannot poison private observations.
    local conditions = entries(snapshot.conditions)
    local itemsets

    if dependencyReader and dependencyIdentity(self, addon) then
        itemsets = itemsetEntries(snapshot.shared, snapshot.personal)
    else
        itemsets = entries(snapshot.itemsets)
    end

    local effects = entries(snapshot.effects)

    return {
        conditions = conditions,
        itemsets = itemsets,
        effects = effects,
        support = support,
        stepSupport = stepSupport,
    },
        current
end

ownedOptions = addon.GetRotationValidationOptions

-- Constant-time managed publication authority; unknown property layouts and public overrides retain the existing eager
-- reader. No membership scan.
-- @param owner table  The addon.
-- @param continuation boolean|nil  True to skip the layout checks for a continuation of an already-proved call.
-- @return table|nil  The dependency stamp; nil (with nothing else) when the managed reader cannot vouch.
-- @return table  The db.
-- @return table  The profile.
-- @return table  The global table.
-- @return table  The condition definitions.
-- @return number  The condition registry version.
-- @return table  The shared item sets.
-- @return table  The per-profile item sets.
-- @return table  The effects.
-- @return table  The profile's rotation library state.
runtimeAuthority = function(owner, continuation)
    if not dependencyReader or not dependencyIdentity(owner, addon) then
        return
    end
    if
        continuation ~= true
        and (proofRawget(owner, 'GetRotationValidationOptions') ~= ownedOptions
            or proofRawget(owner, 'GetRotationValidationStamp') ~= ownedValidationStamp
            or proofRawget(owner, 'HasDisabledRotationDependency') ~= ownedDisabledDependency
            or proofType(proofGetfenv) ~= 'function'
            or proofGetfenv(ownedOptions) ~= proofEnvironment
            or proofGetfenv(ownedValidationStamp) ~= proofEnvironment
            or proofGetfenv(ownedDisabledDependency) ~= proofEnvironment)
    then
        return
    end

    local db = proofRawget(owner, 'db')

    if proofType(db) ~= 'table' then
        return
    end

    local profile, global = proofRawget(db, 'profile'), proofRawget(db, 'global')

    if proofType(profile) ~= 'table' or proofType(global) ~= 'table' then
        return
    end

    local conditions, shared, personal, effects =
        proofRawget(owner, 'conditionDefinitions'),
        proofRawget(global, 'itemsets'),
        proofRawget(profile, 'itemsets'),
        proofRawget(global, 'effects')

    if
        continuation ~= true
        and (not proofPlain(conditions)
            or not proofPlain(shared)
            or not proofPlain(personal)
            or not proofPlain(effects))
    then
        return
    end

    return dependencyReader(owner),
        db,
        profile,
        global,
        conditions,
        proofRawget(owner, 'conditionRegistryVersion'),
        proofRawget(global, 'itemsets'),
        proofRawget(profile, 'itemsets'),
        proofRawget(global, 'effects'),
        proofRawget(profile, 'rotationLibrary')
end

-- Reports whether a rotation body references a disabled condition.
-- @param body table  The rotation body.
-- @return boolean  True when a disabled definition is referenced, or the body cannot be inspected.
--
-- Legacy bodies have no envelope. Inspect their semantic condition edges too, so a disabled definition cannot be
-- bypassed by a later priority action.
function addon:HasDisabledRotationDependency(body)
    local definitions = self.conditionDefinitions or {}
    local hasDisabled = false

    for _, definition in pairs(definitions) do
        if type(definition) == 'table' and definition.disabled then
            hasDisabled = true
            break
        end
    end

    if not hasDisabled then
        return false
    end

    local tree = self.RotationData.IndexRotationSteps(body, { allowMissingIds = true })

    if not tree then
        return true
    end

    local count = 0
    local condition, declared

    -- Walks a value against its schema (a condition, a list of conditions, a union of schemas or a field table).
    -- @param value any  The value.
    -- @param schema any  The schema: 'condition', 'condition[]', a union table or a field table.
    -- @param depth number  The nesting depth.
    -- @return boolean  True when a disabled condition is reached or the value is malformed or nested too deeply.
    declared = function(value, schema, depth)
        if value == nil then
            return false
        end
        if depth > 64 then
            return true
        end
        if schema == 'condition' then
            return condition(value, depth + 1)
        end

        if schema == 'condition[]' then
            if type(value) ~= 'table' then
                return true
            end

            for _, child in ipairs(value) do
                if condition(child, depth + 1) then
                    return true
                end
            end
        elseif type(schema) == 'table' and type(value) == 'table' then
            if schema[1] ~= nil then
                -- Union schemas may contain object/list alternatives. Inspect
                -- only alternatives that declare nested conditions.
                for _, alternative in ipairs(schema) do
                    if declared(value, alternative, depth + 1) then
                        return true
                    end
                end
            else
                for key, kind in pairs(schema) do
                    if declared(value[key], kind, depth + 1) then
                        return true
                    end
                end
            end
        end

        return false
    end

    -- Checks one condition node. AND, OR and NOT recurse into their operands.
    -- @param value any  The condition node.
    -- @param depth number  The nesting depth.
    -- @return boolean  True when it is disabled, malformed, past the depth or node limits, or references a disabled
    --   condition in any of its declared fields.
    condition = function(value, depth)
        if value == nil then
            return false
        end

        count = count + 1

        if count > 4096 or depth > 64 or type(value) ~= 'table' then
            return true
        end
        if value.type == 'AND' or value.type == 'OR' then
            return declared(value.value, 'condition[]', depth + 1)
        end
        if value.type == 'NOT' then
            return condition(value.value, depth + 1)
        end

        local definition = definitions[value.type]

        if type(definition) == 'table' then
            if definition.disabled then
                return true
            end

            for key, kind in pairs(definition.fields or {}) do
                if declared(value[key], kind, depth + 1) then
                    return true
                end
            end
        end

        return false
    end

    if condition(body.switch, 0) then
        return true
    end

    for _, row in ipairs(tree.rows) do
        if condition(row.step.conditions, 0) then
            return true
        end
    end

    return false
end

ownedDisabledDependency = addon.HasDisabledRotationDependency

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
    local bind = addon.BindCPUValidationScopeDiagnostic

    if type(bind) == 'function' then
        bind(addon, 'references', ownedValidationStamp, function()
            return observe, sameEntries, sameItemsets, proofGlobals
        end)
    end
end
-- END PRIVATE VALIDATION CPU HANDOFF
