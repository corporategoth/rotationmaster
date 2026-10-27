local _, addon = ...
local observed, stamp
local dependencyReader
local bindDependency = addon.BindRotationDependencyReader

if type(bindDependency) == 'function' then
    bindDependency(addon, function(reader)
        if type(reader) == 'function' then dependencyReader = reader end
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

local function normalized(value)
    return type(value) == 'table' and value or false
end

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

local function sameEntries(value, previous, expected)
    local count = 0

    if type(value) == 'table' then
        for key, item in pairs(value) do
            if not rawequal(type(item) == 'table' and item or false, previous[key]) then return false end
            count = count + 1
        end
    end

    return count == expected
end

local function validItemsets(shared, personal)
    return (shared == nil or type(shared) == 'table') and (personal == nil or type(personal) == 'table')
end

local function sameItemsets(shared, personal, previous, expected)
    if not validItemsets(shared, personal) then return expected == 0 end
    local count = 0

    if shared then
        for key, item in pairs(shared) do
            -- Only actual personal entries shadow shared entries. A missing-key
            -- lookup could materialize an AceDB default and mutate the source.
            if not personal or rawget(personal, key) == nil then
                if not rawequal(type(item) == 'table' and item or false, previous[key]) then return false end
                count = count + 1
            end
        end
    end

    if personal then
        for key, item in pairs(personal) do
            if not rawequal(type(item) == 'table' and item or false, previous[key]) then return false end
            count = count + 1
        end
    end

    return count == expected
end

local function itemsetEntries(shared, personal)
    if not validItemsets(shared, personal) then return {}, 0 end
    local result, count = entries(shared)

    if personal then
        for key, item in pairs(personal) do
            if result[key] == nil then count = count + 1 end
            result[key] = normalized(item)
        end
    end

    return result, count
end

-- Condition support (Core/condition_support.lua) depends on the client. The
-- platform recomputes its client facts when GetClientInfo or the project
-- changes (only test harnesses do either); the same change advances the
-- condition registry version, so every validation stamp moves with it.
local clientGetter, clientProject

local function observeClient(owner)
    local platform = rawget(addon, 'Platform')
    local getter = type(platform) == 'table' and platform.GetClientInfo or nil
    local project = WOW_PROJECT_ID
    if getter == clientGetter and project == clientProject then return end
    local first = clientGetter == nil and clientProject == nil
    clientGetter, clientProject = getter, project
    if not first then owner.conditionRegistryVersion = (owner.conditionRegistryVersion or 0) + 1 end
end

local function support(tag, definition, value)
    local check = addon.GetConditionSupport
    if type(check) == 'function' then return check(addon, tag, definition, value) end
end

-- Observe identities without copying maps on the common unchanged path.
-- Normalized false markers keep malformed/NaN entries stable, as before.
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

-- Managed ownership does not require plain/default-free maps. AceDB may
-- materialize default metatables; contents change through explicit publication.
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

-- Internal authority checks need the current stamp, not detached public maps.
-- Keep checking every dependency at each call, including reentrant mutations.
function addon:GetRotationValidationStamp()
    local _, current = observe(self)
    return current
end

local ownedValidationStamp = addon.GetRotationValidationStamp

-- Even protected metatable metadata can disguise a callback. Only native
-- primitives stored directly in the owned environment can certify this path.
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

local function proofPlain(value)
    return proofType(value) == 'table' and proofGetmetatable(value) == nil
end

-- Only raw-present, callback-free layouts can join adjacent observations.
-- AceAddon owners and AceDB db objects may have metatables: every accessed
-- slot is raw-present, and neither object participates in equality/tostring.
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
    if proofType(db) ~= 'table' then return end
    local profile, global = proofRawget(db, 'profile'), proofRawget(db, 'global')
    if not proofPlain(profile) or not proofPlain(global) then return end

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
    if db then return value, db, profile, global, conditions, shared, personal, effects, version, state end
    return value
end

-- Trusted private module handoff, retired by its consumer. This does not
-- authenticate a hostile replacement of the complete loader/binder itself.
function addon:BindRotationValidationReader(bind)
    if type(bind) ~= 'function' then return nil, 'invalid-validation-reader-binder' end

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

-- Dependency maps may carry AceDB defaults metatables. Observe their entries,
-- without copying/traversing definitions or writing into SavedVariables.
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
    return { conditions = conditions, itemsets = itemsets, effects = effects, support = support }, current
end

ownedOptions = addon.GetRotationValidationOptions

-- Constant-time managed publication authority; unknown property layouts and
-- public overrides retain the existing eager reader. No membership scan.
runtimeAuthority = function(owner, continuation)
    if not dependencyReader or not dependencyIdentity(owner, addon) then return end

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
    if proofType(db) ~= 'table' then return end
    local profile, global = proofRawget(db, 'profile'), proofRawget(db, 'global')
    if proofType(profile) ~= 'table' or proofType(global) ~= 'table' then return end

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

-- Legacy bodies have no envelope. Inspect their semantic condition edges too,
-- so a disabled definition cannot be bypassed by a later priority action.
function addon:HasDisabledRotationDependency(body)
    local definitions = self.conditionDefinitions or {}
    local hasDisabled = false

    for _, definition in pairs(definitions) do
        if type(definition) == 'table' and definition.disabled then
            hasDisabled = true
            break
        end
    end

    if not hasDisabled then return false end
    local tree = self.RotationData.IndexRotationSteps(body, { allowMissingIds = true })
    if not tree then return true end
    local count = 0
    local condition, declared

    declared = function(value, schema, depth)
        if value == nil then return false end
        if depth > 64 then return true end
        if schema == 'condition' then return condition(value, depth + 1) end

        if schema == 'condition[]' then
            if type(value) ~= 'table' then return true end

            for _, child in ipairs(value) do
                if condition(child, depth + 1) then return true end
            end
        elseif type(schema) == 'table' and type(value) == 'table' then
            if schema[1] ~= nil then
                -- Union schemas may contain object/list alternatives. Inspect
                -- only alternatives that declare nested conditions.
                for _, alternative in ipairs(schema) do
                    if declared(value, alternative, depth + 1) then return true end
                end
            else
                for key, kind in pairs(schema) do
                    if declared(value[key], kind, depth + 1) then return true end
                end
            end
        end

        return false
    end

    condition = function(value, depth)
        if value == nil then return false end
        count = count + 1
        if count > 4096 or depth > 64 or type(value) ~= 'table' then return true end
        if value.type == 'AND' or value.type == 'OR' then return declared(value.value, 'condition[]', depth + 1) end
        if value.type == 'NOT' then return condition(value.value, depth + 1) end
        local definition = definitions[value.type]

        if type(definition) == 'table' then
            if definition.disabled then return true end

            for key, kind in pairs(definition.fields or {}) do
                if declared(value[key], kind, depth + 1) then return true end
            end
        end

        return false
    end

    if condition(body.switch, 0) then return true end

    for _, row in ipairs(tree.rows) do
        if condition(row.step.conditions, 0) then return true end
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
