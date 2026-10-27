-- Scoped rotation coordinator: the single object (`current`) through which every read and write of rotations goes once
-- a profile has a rotationStore. addon:BindRotationProfile builds one per profile; it resolves references (a Built In
-- id or a custom address) to stable keys, lists roster headers, snapshots, drafts, commits, deletes, adopts legacy
-- rotations, imports and copies, and opens the runtime passes that evaluation reads bodies from. It fails closed: when
-- the profile, owner, library or dependencies changed it returns a reason rather than stale data. The store itself is
-- Data/rotation_store.lua (db.profile.rotationStore, rotationFallbackID). Loaded from the Core rotation group of
-- RotationMaster.toc after Core/rotation_library.lua; the end of the file is private plan-source handoffs to main.lua.
local addon_name, addon = ...

-- ============================================================================
-- Startup handoffs and plan integrity checks
-- ============================================================================

-- Consume the scalar refresh receiver before other startup binder callouts.
---@type fun(...): any
local consumeAvailability = addon.ConsumeConditionConsumerAvailability
---@type fun(...): any
local installConsumerAvailability

if type(consumeAvailability) == 'function' then
    installConsumerAvailability = consumeAvailability(addon)
    addon.ConsumeConditionConsumerAvailability = nil
end

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
    if advanceExecutionGeneration then advanceExecutionGeneration() end
end

local data = addon.RotationData
local ownedStoreFactory, ownedStoreEnvironment
local bindOwnedStoreFactory = data.BindOwnedRotationStoreFactory

if type(bindOwnedStoreFactory) == 'function' then
    bindOwnedStoreFactory(function(factory, environment)
        ownedStoreFactory, ownedStoreEnvironment = factory, environment
    end)

    data.BindOwnedRotationStoreFactory = nil
end

---@type fun(f: number|function): table
local storeGetfenv = getfenv
local storeScopeEnvironment = type(storeGetfenv) == 'function' and storeGetfenv(1) or nil
-- These public helpers receive the execution body/path in the default sequence.
-- Unknown helpers keep the public RuntimePass route before private data escapes.
local planIndex, planCopy, planPortable, planIpairs = data.IndexRotationSteps, data.CopyData, data.CheckPortable, ipairs
local planType, planRawget = type, rawget

local planPairs, planMeta, planTable, planSort, planMath, planHuge =
    pairs, getmetatable, table, table.sort, math, math.huge

-- True while the data helpers and the standard functions the plan path captured are still the originals, so a swapped
-- public helper cannot receive private execution data.
local function planDataCurrent(owner)
    return rawget(storeScopeEnvironment, 'ipairs') == planIpairs
        and rawget(owner, 'RotationData') == data
        and rawget(data, 'IndexRotationSteps') == planIndex
        and rawget(data, 'CopyData') == planCopy
        and rawget(data, 'CheckPortable') == planPortable
        and storeGetfenv(planIndex) == storeScopeEnvironment
        and storeGetfenv(planCopy) == storeScopeEnvironment
        and storeGetfenv(planPortable) == storeScopeEnvironment
end

-- Answers whether the plan may use the private route for one kind of receiver ('iterator', 'step', 'pathcopy',
-- 'sequence', 'condition', 'resume'): the captured functions that receiver relies on must still be the originals.
local function planExecutionSource(owner, receiver)
    if planRawget(storeScopeEnvironment, 'type') ~= planType then return false end

    if receiver == 'iterator' or receiver == 'step' then
        return planRawget(storeScopeEnvironment, 'pairs') == planPairs
            and planRawget(storeScopeEnvironment, 'ipairs') == planIpairs
    end

    if receiver == 'pathcopy' or receiver == 'sequence' then
        return planDataCurrent(owner)
            and planRawget(owner, 'RotationData') == data
            and planRawget(data, 'IndexRotationSteps') == planIndex
            and planRawget(data, 'CopyData') == planCopy
            and planRawget(data, 'CheckPortable') == planPortable
            and planRawget(storeScopeEnvironment, 'type') == planType
            and planRawget(storeScopeEnvironment, 'ipairs') == planIpairs
            and planRawget(storeScopeEnvironment, 'pairs') == planPairs
            and planRawget(storeScopeEnvironment, 'getmetatable') == planMeta
            and planRawget(storeScopeEnvironment, 'table') == planTable
            and planRawget(planTable, 'sort') == planSort
            and planRawget(storeScopeEnvironment, 'math') == planMath
            and planRawget(planMath, 'huge') == planHuge
    end

    return receiver == 'condition' or receiver == 'resume'
end

local prepareChoicePublication, finishChoicePublication
local consumeChoices = addon.ConsumeRotationChoicePublication

if type(consumeChoices) == 'function' then
    prepareChoicePublication, finishChoicePublication = consumeChoices(addon)
    addon.ConsumeRotationChoicePublication = nil
end

local invalidateChoiceContext = addon.InvalidateRotationChoiceContext
local prepareActivePublication, finishActivePublication, prepareActiveRebind, finishActiveRebind, readActiveRuntime, copyActiveRuntime
local activeCurrent = addon.IsActiveRotationTransitionCurrent
local protect, raise = pcall, error
local preparedBinding, bindGeneration
local bindIdentity = rawequal

if type(addon.BindActiveRotationPublication) == 'function' then
    addon:BindActiveRotationPublication(function(prepare, finish, rebind, complete, readRuntime, copyRuntime)
        prepareActivePublication, finishActivePublication, prepareActiveRebind, finishActiveRebind =
            prepare, finish, rebind, complete

        readActiveRuntime, copyActiveRuntime = readRuntime, copyRuntime
    end)
end

local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local libraryReader, libraryGenerationProof, libraryContextProof, libraryRuntimeContextGuard
local runtimeAuthority, planEligible, ownedRuntimeContext, ownedRuntimeReadValue, readLibraryRuntime
local currentPlanSource, ownedAcquireRuntimePass
local evaluationRequest, contextVersion
local privatePlanPass = {}
contextVersion = {}
local ownedRuntimePasses = setmetatable({}, { __mode = "kv" })
local bindLibrary = addon.BindRotationLibraryReader

if type(bindLibrary) == 'function' then
    bindLibrary(addon, function(
        reader,
        proof,
        contextProof,
        runtimeGuard,
        authority,
        eligible,
        contextMethod,
        readValue,
        generation
    )
        runtimeAuthority, planEligible, ownedRuntimeContext, ownedRuntimeReadValue, readLibraryRuntime =
            authority, eligible, contextMethod, readValue, generation

        libraryRuntimeContextGuard = runtimeGuard
        libraryReader = reader
        if type(proof) == 'function' then libraryGenerationProof = proof end
        if type(contextProof) == 'function' then libraryContextProof = contextProof end
    end)

    addon.BindRotationLibraryReader = nil
end

-- Reads the rotation context for `spec` from the library reader when it owns the context method, otherwise through the
-- public GetRotationContext. Returns the value, whether it came from the private path, and the method used.
local function rotationContext(owner, spec)
    local method = libraryReader and libraryReader.Context

    if type(method) == 'function' then
        local value, private = method(libraryReader, spec)
        return value, private, method
    end

    local fallback = owner.GetRotationContext
    local value = fallback(owner, spec)
    return value, false
end

local current, serial
serial = 0
-- Exposure survives explicit Refresh/rebinding while that canonical body lives.
local exposed = setmetatable({}, { __mode = 'k' })
local exposureVersion = {}

-- ============================================================================
-- Small helpers
-- ============================================================================

-- True for a table without a metatable.
local function plain(v)
    return type(v) == 'table' and getmetatable(v) == nil
end

-- True when a rotation without applicability facts opts into a special action context (pet, vehicle, ...) through its
-- switch condition.
local function bareContextOptIn(body, context)
    local matches = data and data.MatchesBareActionContext
    return type(matches) == 'function' and matches(body, context) == true
end

-- True for a printable string of 1 to `n` bytes with a non-space character and no control characters.
local function text(v, n)
    return type(v) == 'string' and #v > 0 and #v <= n and v:find('%S') ~= nil and not v:find('[%z\1-\31\127]')
end

-- Deep copy through the data module, which refuses anything that is not portable data.
local function copy(v)
    return data.CopyData(v)
end

-- Copies only the known string metadata fields (author, realm, email, website, version) for roster display.
local function metadataView(value)
    if not plain(value) then return nil end
    local result = {}

    for _, key in ipairs({ 'author', 'realm', 'email', 'website', 'version' }) do
        if type(value[key]) == 'string' then result[key] = value[key] end
    end

    return result
end

-- Normalized tag list for display; nil when absent and false when the saved tags are invalid.
local function tagsView(value)
    if value == nil then return nil end
    return data.NormalizeRotationTags(value) or false
end

-- Structural equality for plain data; false for any table with a metatable.
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

-- Flattens a custom rotation address to a string usable as a table key.
local function addressKey(a)
    return a.scope .. '\0' .. a.class .. '\0' .. a.owner .. '\0' .. a.spec .. '\0' .. a.id
end

-- True for a non-negative integer specialization index.
local function validSpec(v)
    return type(v) == 'number' and v >= 0 and v < math.huge and v % 1 == 0
end

-- True when `r` is a well-formed custom reference: only `kind` and `address`, an address with a class or character
-- scope, a valid class token, owner, specialization and id, and a class-scope owner equal to the class.
local function customReference(r)
    if not plain(r) or r.kind ~= 'custom' or not plain(r.address) then return false end

    for key in pairs(r) do
        if key ~= 'kind' and key ~= 'address' then return false end
    end

    for key in pairs(r.address) do
        if key ~= 'scope' and key ~= 'class' and key ~= 'owner' and key ~= 'spec' and key ~= 'id' then return false end
    end

    local a = r.address

    return (a.scope == 'class' or a.scope == 'character')
        and data.IsRotationClassToken(a.class)
        and text(a.owner, 512)
        and validSpec(a.spec)
        and text(a.id, 128)
        and (a.scope ~= 'class' or a.owner == a.class)
end

-- Copies the four persisted parts of a stored record: body, origin, imported and comparison.
local function copyRecord(r)
    local out = {}

    for _, k in ipairs({ 'body', 'origin', 'imported', 'comparison' }) do
        if r[k] ~= nil then out[k] = copy(r[k]) end
    end

    return out
end

-- Flattens a Built In or custom reference to a unique string for the coordinator's lookup tables.
local function referenceKey(r)
    return r.kind == 'builtin' and 'builtin\0' .. r.id or 'custom\0' .. addressKey(r.address)
end

-- ============================================================================
-- Owner context and profile binding
-- ============================================================================

-- Returns { class, character } for the player who owns custom rotations, or nil and 'missing-owner-context'. The
-- character key is dropped when it is not usable text. Uses the library's observation when it owns the context method.
function addon:GetRotationOwnerContext()
    local class
    local platform = self.Platform

    if
        libraryReader
        and type(libraryReader.OwnsContext) == 'function'
        and libraryReader:OwnsContext(self.GetRotationContext)
        and type(platform) == 'table'
        and type(platform.GetPlayerOwnerClassObservation) == 'function'
    then
        class = platform:GetPlayerOwnerClassObservation()
    else
        local context = self:GetRotationContext(self.currentSpec)
        class = context and context.class
    end

    if not data.IsRotationClassToken(class) then return nil, 'missing-owner-context' end
    local character = self.db.keys and self.db.keys.char
    if not text(character, 512) then character = nil end
    return { class = class, character = character }
end

local ownedOwnerContext = addon.GetRotationOwnerContext

-- Returns the coordinator bound to the current profile, or nil when none is bound.
function addon:GetScopedRotationCoordinator()
    -- Once scoped mode is bound, a profile transition must fail closed until
    -- the explicit event handler rebinds it; never reopen the old flat adapter.
    return current
end

local ownedScopedCoordinator = addon.GetScopedRotationCoordinator

-- Asks Core/rotation_active.lua to open a rebind for the selected rotation before the profile changes. Returns the
-- binding (ticket, reference, token, specialization, id) or nil when there is no active selection to carry over.
local function rebindContext()
    if not prepareActiveRebind then return nil end
    local ticket, reference, token, spec, id = prepareActiveRebind(DEFAULT)
    if not token then return nil end
    return { ticket = ticket, reference = reference, token = token, spec = spec, id = id }
end

-- Re-selects the previously active rotation in the new coordinator once it exists. The selection is resolved by its old
-- reference (or the fallback) and handed back to finishActiveRebind; if it cannot be resolved the selection is cleared
-- and manual mode is turned off. Every step re-checks that the transition is still current.
local function completeRebind(binding, coordinator, problem)
    if not binding or not binding.ticket or not activeCurrent(addon, binding.token) then return end

    -- Calls object[name] and returns its result, or nil if the transition was superseded before or after the call.
    local function read(object, name, ...)
        if not activeCurrent(addon, binding.token) then return nil end
        local method = object[name]
        if not activeCurrent(addon, binding.token) then return nil end
        local value = method(object, ...)
        if not activeCurrent(addon, binding.token) then return nil end
        return value
    end

    -- Looks up the previous selection in the new coordinator. Returns its key, reference and body, or nothing.
    local function resolve()
        if problem then return nil end
        local key = binding.id

        if key ~= DEFAULT then
            if not binding.reference then return nil end
            local reference = read(coordinator, 'Resolve', binding.spec, binding.reference)
            if not reference then return nil end
            key = read(coordinator, 'Key', reference)
        end

        if not key then return nil end
        local reference = read(coordinator, 'Resolve', binding.spec, key)
        local pass
        local sourcePass = ownedRuntimePasses[coordinator]

        if reference and rawget(coordinator, 'RuntimePass') == sourcePass then
            if not activeCurrent(addon, binding.token) then return nil end
            pass = sourcePass(coordinator, binding.spec, privatePlanPass)
            if not activeCurrent(addon, binding.token) then return nil end
        elseif reference then
            pass = read(coordinator, 'RuntimePass', binding.spec)
        end

        local body = pass and read(pass, 'Get', key)
        return key, reference, body
    end

    local ok, key, reference, body = protect(resolve)
    if not activeCurrent(addon, binding.token) then return end

    local handle, token = finishActiveRebind(
        binding.ticket,
        ok and key or nil,
        ok and reference or nil,
        ok and body or nil
    )

    if not handle and token and activeCurrent(addon, token) then addon.manualRotation = false end
end

-- Runs `method` with `binding` as the prepared rebind, so a BindRotationProfile call inside it reuses the binding
-- instead of opening its own. Errors propagate unchanged after the previous binding is restored.
local function runPreparedBind(owner, binding, method)
    local previous = preparedBinding
    preparedBinding = binding
    local ok, result, reason = protect(method, owner)
    if preparedBinding == binding then preparedBinding = previous end
    if not ok then raise(result, 0) end
    return result, reason
end

-- One-time handoff of rebindContext and runPreparedBind to the module that switches profiles.
function addon:BindActiveRotationProfileRebind(receiver)
    if self ~= addon or type(receiver) ~= 'function' then return nil end
    receiver(rebindContext, runPreparedBind)
    return true
end

-- Builds a new coordinator for the current profile and retires the previous one. Returns true, or nil and the reason
-- the coordinator is unusable (the coordinator still exists and reports that reason from every call). A later bind or a
-- superseded transition makes this call return 'rotation-transition-superseded'.
function addon:BindRotationProfile()
    invalidateExecution()
    if invalidateChoiceContext then invalidateChoiceContext(addon) end
    local bindToken = {}
    bindGeneration = bindToken
    local binding, profile

    -- True while this bind is still the newest one, its rebind binding is current and the profile is unchanged.
    local function bindingCurrent()
        if bindGeneration ~= bindToken or binding and not activeCurrent(self, binding.token) then return false end

        if profile then
            local db = self.db
            if not bindIdentity(db and db.profile, profile) then return false end
        end

        return bindGeneration == bindToken
    end

    if self == addon then
        binding = preparedBinding or rebindContext()

        if binding then
            if binding.used or not bindingCurrent() then return nil, 'rotation-transition-superseded' end
            binding.used = true
        end
    end

    if not bindingCurrent() then return nil, 'rotation-transition-superseded' end
    local previous = current

    if previous then
        local retire = previous.Retire
        if not bindingCurrent() then return nil, 'rotation-transition-superseded' end
        retire(previous)
        if not bindingCurrent() then return nil, 'rotation-transition-superseded' end
    end

    local owner = self
    profile = self.db.profile
    local state = profile.rotationStore
    local fallbackID = profile.rotationFallbackID
    local reader, store, problem, ownedPublicationGuard, ownedExecutionGuard
    local alive = true
    local managedStoreReader = false

    if not libraryReader then
        problem = 'rotation-library-not-ready'
    elseif not text(profile.rotationFallbackID, 128) then
        problem = 'missing-fallback-configuration'
    else
        local construct = data.NewRotationStore
        if not bindingCurrent() then return nil, 'rotation-transition-superseded' end
        local getOptions = self.GetRotationValidationOptions
        if not bindingCurrent() then return nil, 'rotation-transition-superseded' end
        local validation = getOptions(self)
        if not bindingCurrent() then return nil, 'rotation-transition-superseded' end

        store, problem, ownedPublicationGuard, ownedExecutionGuard = construct({
            state = state,
            fallbackID = profile.rotationFallbackID,
            validation = validation,
            bindInternalReader = function(value) reader = value end,
        })

        managedStoreReader = construct == ownedStoreFactory
            and ownedStoreEnvironment ~= nil
            and type(storeGetfenv) == 'function'
            and getfenv == storeGetfenv
            and storeGetfenv(construct) == ownedStoreEnvironment
    end

    if not bindingCurrent() then return nil, 'rotation-transition-superseded' end
    invalidateExecution()
    local coordinator = {}
    current = coordinator
    local rosterStamp, rosterOwned, rosterLibrary, rosterValidation, rosterVirtual, rosterBuiltin

    local byKey, byReference, expected, pending, assets, headers, cleanup =
        {}, {}, setmetatable({}, { __mode = 'k' }), {}, {}, {}, {}

    -- ============================================================================
    -- Coordinator: references
    -- ============================================================================

    -- Owner context for this coordinator; every operation re-reads it to detect a character or class change.
    local function context()
        return owner:GetRotationOwnerContext()
    end

    -- Returns true while this coordinator is alive and the profile, store and fallback id are the ones it was built
    -- for, otherwise nil and 'rotation-profile-changed' (or the reason the store could not be built).
    local function ready()
        if
            not alive
            or owner.db.profile ~= profile
            or profile.rotationStore ~= state
            or profile.rotationFallbackID ~= fallbackID
        then
            return nil, 'rotation-profile-changed'
        end

        if problem then return nil, problem end
        return true
    end

    -- Returns the opaque session key for a reference, issuing one the first time it is seen. Keys are not saved and are
    -- only meaningful to this coordinator.
    local function keyFor(reference)
        local index = referenceKey(reference)
        local key = byReference[index]

        if not key then
            serial = serial + 1
            key = string.char(1) .. 'rm:rotation:' .. serial
            byReference[index] = key
            byKey[key] = copy(reference)
        end

        return key
    end

    -- Returns a validated copy of a reference for specialization `number`, or nil and a reason. A Built In must be
    -- readable from the library; a custom one must be well formed, belong to this class and character, not be another
    -- specialization's fallback, and exist in the store.
    local function validateReference(reference, number)
        if plain(reference) and reference.kind == 'builtin' and text(reference.id, 128) then
            local ok, why = libraryReader:Read(number, reference.id, function() return true end)
            if not ok then return nil, why end
            return { kind = 'builtin', id = reference.id }
        end

        if not customReference(reference) then return nil, 'invalid-rotation-reference' end
        local a = reference.address
        local c, contextReason = context()
        if not c then return nil, contextReason end
        if c.class ~= a.class or a.scope == 'character' and c.character ~= a.owner then return nil, 'foreign-owner' end
        -- Only a fallback belongs to one namespace; any other rotation is
        -- reachable from every one (body.specs decides where it applies).
        if a.spec ~= number and a.id == profile.rotationFallbackID then return nil, 'invalid-specialization' end
        -- The private store performs the complete typed address/class gate.
        local ok, reason = reader:Read(a, c, function() return true end)
        if not ok then return nil, reason end
        return copy(reference)
    end

    -- Finds the fallback rotation of a specialization, preferring the character's copy over the class copy. Returns nil
    -- and 'unknown-rotation' when neither is saved.
    local function fallbackReference(number)
        local c, why = context()
        if not c or not c.character then return nil, why or 'missing-owner-context' end

        for _, scope in ipairs({ 'character', 'class' }) do
            local reference = {
                kind = 'custom',
                address = {
                    scope = scope,
                    class = c.class,
                    owner = scope == 'class' and c.class or c.character,
                    spec = number,
                    id = profile.rotationFallbackID,
                },
            }

            local ok, reason = reader:Read(reference.address, c, function() return true end)
            if ok then return reference end
            if reason ~= 'unknown-rotation' then return nil, reason end
        end

        return nil, 'unknown-rotation'
    end

    -- Returns true, or nil and the reason this coordinator cannot be used.
    function coordinator:CheckReady()
        return ready()
    end

    -- True when `value` is the profile table this coordinator was built for.
    function coordinator:OwnsProfile(value)
        return value == profile
    end

    -- Ends this coordinator: every later call fails with 'rotation-profile-changed', the store reader is retired and
    -- the execution generation advances if this is still the current coordinator. Returns true.
    function coordinator:Retire()
        if current == coordinator then invalidateExecution() end
        alive = false
        if reader then reader:Retire() end
        return true
    end

    -- Resolves `value` to a reference table for specialization `number`. `value` may be a reference, a key issued by
    -- Key, the DEFAULT constant (the fallback) or a bare rotation id. Returns the reference, or nil and a reason such
    -- as 'unknown-rotation', 'ambiguous-rotation-reference', 'foreign-owner' or 'invalid-specialization'.
    function coordinator:Resolve(number, value)
        local ok, why = ready()
        if not ok then return nil, why end
        if not validSpec(number) then return nil, 'invalid-specialization' end
        local ownerContext, ownerReason = context()
        if not ownerContext then return nil, ownerReason end

        if type(value) == 'table' then
            if value.kind == 'builtin' then return validateReference(value, number) end

            if customReference(value) then
                local p = pending[referenceKey(value)]
                if p then return self:PendingReference(number, p.reference) end
                return validateReference(value, number)
            end

            return nil, 'invalid-rotation-reference'
        end

        if type(value) ~= 'string' then return nil, 'invalid-rotation-reference' end

        if byKey[value] then
            local reference = byKey[value]
            if pending[referenceKey(reference)] then return self:PendingReference(number, reference) end
            return validateReference(reference, number)
        end

        if value == DEFAULT then return fallbackReference(number) end
        local c, errorText = context()
        if not c then return nil, errorText end
        local rows, reason = reader:ListOwned(number, c)
        if not rows then return nil, reason end
        local found

        for _, row in ipairs(rows) do
            if
                row.address.id == value and (row.address.id ~= profile.rotationFallbackID or row.address.spec == number)
            then
                if found then return nil, 'ambiguous-rotation-reference' end
                found = { kind = 'custom', address = row.address }
            end
        end

        return found or nil, not found and 'unknown-rotation' or nil
    end

    -- Returns a copy of an unsaved draft's reference after checking it belongs to this owner and specialization.
    function coordinator:PendingReference(number, r)
        local c, contextReason = context()
        if not c then return nil, contextReason end
        local a = r.address
        if a.spec ~= number and a.id == profile.rotationFallbackID then return nil, 'invalid-specialization' end
        if a.class ~= c.class or a.scope == 'character' and a.owner ~= c.character then return nil, 'foreign-owner' end
        return copy(r)
    end

    -- Returns the session key for a reference (see keyFor).
    function coordinator:Key(reference)
        return keyFor(reference)
    end

    -- True for a custom reference that is a registered draft and has not been saved.
    function coordinator:IsPending(reference)
        return customReference(reference) and pending[referenceKey(reference)] ~= nil
    end

    -- Moves an unsaved draft to the class or character scope before its first save, keeping its key. Returns the new
    -- reference. When the other scope already holds a saved rotation of that id the target is returned without
    -- re-pointing the key.
    function coordinator:StagePending(reference, scope)
        if not customReference(reference) then return nil, 'invalid-rotation-reference' end
        local initial = referenceKey(reference)
        local draft = pending[initial]
        if not draft then return nil, 'unknown-rotation' end
        local c, contextReason = context()
        if not c then return nil, contextReason end
        if scope ~= 'class' and scope ~= 'character' then return nil, 'invalid-owner-scope' end
        if scope == 'character' and not c.character then return nil, 'missing-owner-context' end
        local target = copy(reference)
        target.address.scope = scope
        target.address.owner = scope == 'class' and c.class or c.character
        local index = referenceKey(target)
        -- A staged collision must not steal the existing owner's issued key.
        if byReference[index] and byReference[index] ~= draft.key then return copy(target) end

        if draft.alias and draft.alias ~= initial and draft.alias ~= index then
            pending[draft.alias] = nil
            byReference[draft.alias] = nil
        end

        draft.alias = index
        draft.reference = target
        pending[index] = draft
        byReference[index] = draft.key
        byKey[draft.key] = copy(target)
        return copy(target)
    end

    -- True while the record a Snapshot token was issued for is unchanged in the store (same owner context, same body,
    -- origin, import and comparison parts).
    function coordinator:TokenCurrent(token)
        local issued = expected[token]
        if not issued or not ready() then return false end
        local c = context()
        if not c or not same(c, issued.context) then return false end

        local ok, value = reader:Read(issued.reference.address, c, function(record, seal)
            if seal ~= issued.seal then return false end

            for _, key in ipairs({ 'body', 'origin', 'imported', 'comparison' }) do
                if not data.CheckPortable(record[key]) or not same(record[key], issued.baseline[key]) then
                    return false
                end
            end

            return true
        end)

        return ok and value == true
    end

    -- Returns a detached copy of a rotation record, a public token to pass back to Commit or Delete (nil for a Built
    -- In), and the validation of its body. A Built In record carries `source` instead of a token.
    function coordinator:Snapshot(number, value)
        local reference, why = self:Resolve(number, value)
        if not reference then return nil, why end

        if reference.kind == 'builtin' then
            local ok, record = libraryReader:Read(number, reference.id, function(view, body)
                return { body = copy(body), source = copy(view) }
            end)

            if not ok then return nil, record end
            return record, nil, record.source.validation
        end

        local c, errorText = context()
        if not c then return nil, errorText end
        local record, token = store:Get(reference.address, c)
        if not record then return nil, token end
        local _, _, seal = reader:Read(reference.address, c, function() return true end)
        local public = {}

        expected[public] = {
            reference = copy(reference),
            token = token,
            context = c,
            seal = seal,
            baseline = copyRecord(record),
        }

        return record, public, data.ValidateBody(record.body, owner:GetRotationValidationOptions())
    end

    -- ============================================================================
    -- Coordinator: drafts, commit and delete
    -- ============================================================================

    -- Registers an unsaved custom rotation under a fresh unique id (or the fallback id when `fallback` is set) in the
    -- class or character scope. Returns its reference and key; asking again for the same draft returns the existing
    -- one. Gives up after 100 failed id attempts with 'id-allocation-exhausted'.
    function coordinator:NewDraft(number, scope, fallback)
        if not validSpec(number) then return nil, 'invalid-specialization' end
        local ok, why = ready()
        if not ok then return nil, why end
        local c, reason = context()
        if not c then return nil, reason end
        scope = scope or 'class'
        if scope ~= 'class' and scope ~= 'character' then return nil, 'invalid-owner-scope' end
        if scope == 'character' and not c.character then return nil, 'missing-owner-context' end
        local id = profile.rotationFallbackID

        if not fallback then
            local used = {}
            if libraryReader then libraryReader:Reserve(used) end
            local rows, errorText = store:AllStored()
            if not rows then return nil, errorText end

            for _, row in ipairs(rows) do
                used[row.address.id] = true

                for _, component in pairs(row.record) do
                    local ok, why = data.ReserveRotationIdentities(component, used)
                    if not ok then return nil, why.code end
                end
            end

            for _, draft in pairs(pending) do
                used[draft.reference.address.id] = true
            end

            for _ = 1, 100 do
                local success, candidate = pcall(owner.uuid)

                if
                    success and text(candidate, 128) and not used[candidate] and candidate ~= profile.rotationFallbackID
                then
                    id = candidate
                    break
                end

                id = nil
            end

            if not id then return nil, 'id-allocation-exhausted' end
        end

        local reference = {
            kind = 'custom',
            address = {
                scope = scope,
                class = c.class,
                owner = scope == 'class' and c.class or c.character,
                spec = number,
                id = id,
            },
        }

        local previous = pending[referenceKey(reference)]

        if previous then
            local resolved, pendingReason = self:PendingReference(number, previous.reference)
            if not resolved then return nil, pendingReason end
            return resolved, previous.key
        end

        local exists, lookupReason = reader:Read(reference.address, c, function() return true end)
        if exists then return nil, 'rotation-id-collision' end
        if lookupReason ~= 'unknown-rotation' then return nil, lookupReason end
        local key = keyFor(reference)
        pending[referenceKey(reference)] = { reference = copy(reference), key = key }
        return copy(reference), key
    end

    -- A new rotation that was never saved is only a registered draft: dropping
    -- it retires every alias and key, so it leaves the roster. The fallback's
    -- virtual draft is not one: it is re-created whenever it is listed.
    function coordinator:DiscardPending(reference)
        if not customReference(reference) then return nil, 'invalid-rotation-reference' end
        local draft = pending[referenceKey(reference)]
        if not draft then return nil, 'unknown-rotation' end
        if draft.reference.address.id == profile.rotationFallbackID then return nil, 'protected-rotation' end

        for index, value in pairs(pending) do
            if value == draft then
                pending[index] = nil
                if byReference[index] == draft.key then byReference[index] = nil end
            end
        end

        byKey[draft.key] = nil
        headers[draft.key] = nil
        return true
    end

    -- Registers a draft for an id that so far exists only in the legacy flat list, class scope, so it can be edited and
    -- adopted. Refuses an id already used by a stored rotation or Built In.
    function coordinator:LegacyDraft(number, id)
        local ok, why = ready()
        if not ok then return nil, why end
        if not validSpec(number) or not text(id, 128) then return nil, 'invalid-rotation-target' end
        if id == DEFAULT then return self:NewDraft(number, 'class', true) end
        local c, contextReason = context()
        if not c then return nil, contextReason end

        local reference = {
            kind = 'custom',
            address = { scope = 'class', class = c.class, owner = c.class, spec = number, id = id },
        }

        local draft = pending[referenceKey(reference)]

        if draft then
            local resolved, pendingReason = self:PendingReference(number, draft.reference)
            if not resolved then return nil, pendingReason end
            return resolved, draft.key
        end

        local rows, inventoryReason = store:AllStored()
        if not rows then return nil, inventoryReason end
        local used = {}
        if libraryReader then libraryReader:Reserve(used) end

        for _, row in ipairs(rows) do
            used[row.address.id] = true

            for _, component in pairs(row.record) do
                data.ReserveRotationIdentities(component, used)
            end
        end

        if used[id] then return nil, 'unknown-rotation' end
        local key = keyFor(reference)
        pending[referenceKey(reference)] = { reference = copy(reference), key = key }
        return reference, key
    end

    -- Saves a custom rotation. Without a token it creates; with a Snapshot token it replaces, or moves when `scope`
    -- differs. The active-rotation and choice-preference publications are prepared first, the owner is re-verified,
    -- then the store plan is committed and the keys, drafts and publications follow. `revisionPolicy` is nil or
    -- 'import'. Returns the target reference, nil and the active-rotation transition, or nil and a reason such as
    -- 'stale-rotation-record'.
    function coordinator:Commit(reference, token, record, scope, revisionPolicy)
        local ok, why = ready()
        if not ok then return nil, why end
        local c, errorText = context()
        if not c then return nil, errorText end
        if not customReference(reference) then return nil, 'invalid-rotation-reference' end
        local a = reference.address
        scope = scope or a.scope
        if scope ~= 'class' and scope ~= 'character' then return nil, 'invalid-owner-scope' end
        if scope == 'character' and not c.character then return nil, 'missing-owner-context' end
        local destination = copy(a)
        destination.scope = scope
        destination.owner = scope == 'class' and c.class or c.character
        local issued = token and expected[token]
        local plan, reason
        if revisionPolicy ~= nil and revisionPolicy ~= 'import' then return nil, 'invalid-rotation-revision-policy' end
        if not plain(record) then return nil, 'invalid-record' end

        if token and (not issued or not same(issued.reference, reference) or not same(issued.context, c)) then
            return nil, 'stale-rotation-record'
        end

        local previousKey = byReference[referenceKey(reference)]
        local moved = a.scope ~= destination.scope or a.owner ~= destination.owner
        local previous

        if issued then
            -- Compare the editor's existing empty-list normalization on a
            -- detached public snapshot; keep the issued authority seal exact.
            local snapshot, snapshotProblem = store:Get(a, c)
            if not snapshot then return nil, snapshotProblem end
            previous = snapshot.body

            if plain(previous) and plain(record.body) then
                if previous.rotation == nil and record.body.rotation ~= nil then previous.rotation = {} end
                if previous.cooldowns == nil and record.body.cooldowns ~= nil then previous.cooldowns = {} end
            end
        end

        local body, problem = data.PrepareRotationContentRevision(
            record.body,
            previous,
            token and 'edit' or revisionPolicy == 'import' and 'import' or 'create',
            moved or revisionPolicy == 'import'
        )

        if not body then return nil, problem end
        local detached = copy(record)
        if not detached then return nil, 'invalid-record' end
        record = detached
        record.body = body
        local target = { kind = 'custom', address = destination }
        local fallbackKey = destination.id == profile.rotationFallbackID and DEFAULT or nil
        -- The live rotation is resolved in the character's namespace; only a
        -- fallback is tied to the namespace it is saved under.
        local publishSpec = a.spec

        if a.id ~= profile.rotationFallbackID and rawget(owner, 'currentSpec') ~= nil then
            publishSpec = rawget(owner, 'currentSpec')
        end

        local publication = prepareActivePublication and prepareActivePublication(
            publishSpec,
            previousKey,
            reference,
            target,
            body,
            nil,
            fallbackKey
        )

        local choicePublication = prepareChoicePublication and prepareChoicePublication(profile, reference, target)
        local now, contextProblem = context()
        local readyNow, currentProblem = ready()
        if not readyNow then return nil, currentProblem end
        if not now then return nil, contextProblem end
        if not same(now, c) then return nil, 'rotation-owner-changed' end

        if token then
            if not issued or not same(issued.reference, reference) or not same(issued.context, c) then
                return nil, 'stale-rotation-record'
            end

            if a.scope ~= destination.scope or a.owner ~= destination.owner then
                plan, reason = store:PlanMove(a, destination, c, issued.token, record)
            else
                plan, reason = store:PlanReplace(a, record, c, issued.token)
            end
        else
            plan, reason = store:PlanCreate(destination, record, c)
        end

        if not plan then return nil, reason end
        local committed, problemText = store:Commit(plan, c)
        if not committed then return nil, problemText end
        if finishChoicePublication then finishChoicePublication(choicePublication, alive and current == coordinator) end
        if token then expected[token] = nil end
        local oldIndex = referenceKey(reference)
        local targetIndex = referenceKey(target)
        local draft = pending[oldIndex]

        if draft then
            for index, value in pairs(pending) do
                if value == draft then
                    pending[index] = nil
                    if index ~= targetIndex then byReference[index] = nil end
                end
            end

            byReference[targetIndex] = draft.key
            byKey[draft.key] = copy(target)
        elseif oldIndex ~= targetIndex then
            local oldKey = byReference[oldIndex]

            if oldKey then
                cleanup[oldKey] = assets[oldIndex] and assets[oldIndex].body
                byKey[oldKey] = nil
                byReference[oldIndex] = nil
            end
        end

        local nextKey = keyFor(target)
        local transition

        if finishActivePublication then
            local _, change = finishActivePublication(publication, nextKey)
            transition = change
        end

        return target, nil, transition
    end

    -- Deletes a saved custom rotation using its Snapshot token and removes any choice preference that pointed at it.
    -- The fallback is read-only. Returns true, or nil and a reason.
    function coordinator:Delete(reference, token)
        local ok, why = ready()
        if not ok then return nil, why end
        local c, errorText = context()
        if not c then return nil, errorText end
        local issued = expected[token]

        if not issued or not same(issued.reference, reference) or not same(issued.context, c) then
            return nil, 'stale-rotation-record'
        end

        if reference.address.id == profile.rotationFallbackID then return nil, 'read-only-rotation' end
        local choicePublication = prepareChoicePublication and prepareChoicePublication(profile, reference, nil)
        local plan, reason = store:PlanDelete(reference.address, c, issued.token)
        if not plan then return nil, reason end
        local committed, problemText = store:Commit(plan, c)
        if not committed then return nil, problemText end
        if finishChoicePublication then finishChoicePublication(choicePublication, alive and current == coordinator) end
        local index = referenceKey(reference)
        local key = byReference[index]

        if key then
            cleanup[key] = assets[index] and assets[index].body
            byKey[key] = nil
            byReference[index] = nil
            headers[key] = nil
        end

        assets[index] = nil
        expected[token] = nil
        return true
    end

    -- Returns the body a deleted or replaced rotation was last running, so the caller can release what that body held,
    -- or the current body when the rotation still exists. A caller that is not the private plan path marks the body
    -- borrowed.
    function coordinator:Cleanup(number, value, privateToken)
        if cleanup[value] then return cleanup[value] end
        local reference = type(value) == 'string' and byKey[value]

        if reference and assets[referenceKey(reference)] then
            local asset = assets[referenceKey(reference)]

            if privateToken ~= privatePlanPass then
                if not asset.borrowed and readActiveRuntime and readActiveRuntime(owner, number, value) then
                    invalidateExecution()
                end

                asset.borrowed = true
            end

            return asset.body
        end

        local pass = self:RuntimePass(number, privateToken)
        return pass and pass:Get(value)
    end

    -- ============================================================================
    -- Coordinator: read views
    -- ============================================================================

    -- Returns the roster metadata of a rotation (name, description, priority, tags, metadata and import sources)
    -- without copying its action tree. Returns nil and a reason when it cannot be resolved.
    function coordinator:TagView(number, value)
        local reference, why = self:Resolve(number, value)
        if not reference then return nil, why end

        if reference.kind == 'builtin' then
            local ok, result = libraryReader:Read(number, reference.id, function(view)
                return {
                    tags = copy(view.envelope.tags),
                    sources = copy(view.envelope.sources),
                    body = { name = L[view.nameKey or reference.id] },
                }
            end)

            if not ok then return nil, result end
            return result
        end

        local c = context()

        local ok, result = reader:Read(reference.address, c, function(record)
            local body = record.body
            local retained = record.origin or record.imported
            local manifest = retained and retained.manifest

            return {
                body = {
                    name = body.name,
                    description = body.description,
                    priority = body.priority,
                    tags = tagsView(body.tags),
                    metadata = metadataView(body.metadata),
                },
                tags = manifest and copy(manifest.tags),
                sources = manifest and copy(manifest.sources),
            }
        end)

        if not ok then return nil, result end
        return result
    end

    -- Returns every stored record row of the profile, for usage scans. Returns nil and a reason when not ready.
    function coordinator:StoredRecords()
        local ok, why = ready()
        if not ok then return nil, why end
        return store:AllStored()
    end

    -- Returns the stored rows still in the legacy scope that have not been adopted into a class or character scope.
    function coordinator:Unassigned()
        local ok, why = ready()
        if not ok then return nil, why end
        local rows, inventoryReason = store:AllStored()
        if not rows then return nil, inventoryReason end
        local result = {}

        for _, row in ipairs(rows) do
            if row.address.scope == 'legacy' then result[#result + 1] = row end
        end

        return result
    end

    -- ============================================================================
    -- Coordinator: legacy adoption, import and copy
    -- ============================================================================

    local adoptionPlans = setmetatable({}, { __mode = 'k' })

    -- Plans moving the legacy rotation `selection` ({ spec, id }) into the class or character scope. Writes nothing;
    -- returns a public plan for ApplyAdoption, or nil and a reason.
    function coordinator:PlanAdoption(selection, scope)
        local ok, why = ready()
        if not ok then return nil, why end
        local c, contextReason = context()
        if not c then return nil, contextReason end
        if scope ~= 'class' and scope ~= 'character' then return nil, 'invalid-owner-scope' end
        if scope == 'character' and not c.character then return nil, 'missing-owner-context' end

        local target = {
            scope = scope,
            class = c.class,
            owner = scope == 'class' and c.class or c.character,
            spec = selection.spec,
            id = selection.id,
        }

        local plan, planReason = store:PlanLegacyAdoption({ spec = selection.spec, id = selection.id }, target, c)
        if not plan then return nil, planReason end

        local public = {
            reference = { kind = 'custom', address = copy(target) },
            selection = copy(selection),
            scope = scope,
        }

        adoptionPlans[public] = { plan = plan, context = c, target = target }
        return public
    end

    -- Commits an adoption plan if the owner is unchanged, retires any draft with the same address (its pending
    -- workspace keeps its text but can no longer write over the new entity) and publishes the active selection. Returns
    -- true and the reference.
    function coordinator:ApplyAdoption(public)
        local ok, why = ready()
        if not ok then return nil, why end
        local adoption = adoptionPlans[public]
        if not adoption then return nil, 'invalid-adoption-plan' end
        local c, contextReason = context()
        if not c or not same(c, adoption.context) then return nil, contextReason or 'rotation-owner-changed' end
        local reference = { kind = 'custom', address = copy(adoption.target) }
        local rows = profile.rotationStore.legacy.rotations[adoption.target.spec]
        local body = rows and rows[adoption.target.id]
        local fallbackKey = adoption.target.id == profile.rotationFallbackID and DEFAULT or nil

        local publication = prepareActivePublication and prepareActivePublication(
            adoption.target.spec,
            nil,
            reference,
            reference,
            body,
            nil,
            fallbackKey
        )

        local current, currentReason = ready()
        if not current then return nil, currentReason end
        local now, ownerReason = context()
        if not now or not same(now, c) then return nil, ownerReason or 'rotation-owner-changed' end
        local committed, commitReason = store:Commit(adoption.plan, c)
        if not committed then return nil, commitReason end
        if finishChoicePublication then finishChoicePublication(nil) end
        local draft = pending[referenceKey(reference)]

        if draft then
            -- Adoption creates a saved entity, not the old virtual draft's
            -- first Apply. Retire every alias/key so dirty pending workspaces
            -- retain their text but cannot authorize a write over that entity.
            for index, value in pairs(pending) do
                if value == draft then
                    pending[index] = nil
                    if byReference[index] == draft.key then byReference[index] = nil end
                end
            end

            byKey[draft.key] = nil
            headers[draft.key] = nil
        end

        adoptionPlans[public] = nil
        keyFor(reference)
        if finishActivePublication then finishActivePublication(publication) end
        return true, reference
    end

    -- Returns the retained source of a rotation as a validated view: its import manifest when `imported`, otherwise its
    -- Built In origin with lineage. Returns nil and 'not-imported' or 'no-source-baseline' when there is none.
    function coordinator:SourceView(number, value, imported)
        local record, why = self:Snapshot(number, value)
        if not record then return nil, why end
        if record.source then return nil, imported and 'not-imported' or 'no-source-baseline' end
        local retained

        if imported then
            retained = record.imported
        else
            retained = record.origin
        end

        if not retained then return nil, imported and 'not-imported' or 'no-source-baseline' end
        local envelope = copy(retained.manifest)
        envelope.body = record.body

        if imported then
            return {
                envelope = envelope,
                applicability = envelope.applicability,
                enabled = true,
                validation = data.ValidateEnvelope(envelope, owner:GetRotationValidationOptions()),
                sourceId = retained.sourceId,
                sourceRevision = retained.sourceRevision,
                stepOrigins = copy(retained.stepOrigins),
            }
        end

        local catalog, catalogReason = data.NewCatalog({
            state = { custom = { [envelope.id] = envelope }, lineage = { [envelope.id] = retained.lineage } },
            validation = owner:GetRotationValidationOptions(),
        })

        local view = catalog and catalog:Get({ kind = 'custom', id = envelope.id })
        if not view or view.lineageError then return nil, catalogReason or 'invalid-origin-state' end
        return view
    end

    -- Returns the identity ({ kind, id, origins }) a rotation is compared against, following its origin or import
    -- through clones. A Built In returns itself; a custom rotation with no source returns its own address.
    function coordinator:ComparisonIdentity(number, value)
        local reference, why = self:Resolve(number, value)
        if not reference then return nil, why end
        if reference.kind == 'builtin' then return { kind = 'builtin', id = reference.id } end
        local record, reason = self:Snapshot(number, reference)
        if not record then return nil, reason end
        local identity = copy(record.comparison)

        if record.origin then
            local lineage = record.origin.lineage
            identity = identity or { kind = lineage.sourceKind, id = lineage.sourceId, origins = {} }

            if identity.kind ~= lineage.sourceKind or identity.id ~= lineage.sourceId then
                return nil, 'invalid-comparison-origin'
            end

            for key, origin in pairs(lineage.stepOrigins) do
                identity.origins[key] = origin
            end
        elseif record.imported then
            return { kind = 'import', id = record.imported.sourceId, origins = copy(record.imported.stepOrigins) }
        end

        return identity or { kind = 'custom', id = reference.address.id, sourceAddress = copy(reference.address) }
    end

    -- Returns a function that yields ids unused by any stored rotation, step, Built In or draft (nil when the generator
    -- fails), or nil and a reason when the inventory cannot be read.
    function coordinator:Allocator()
        local used = {}
        if libraryReader then libraryReader:Reserve(used) end
        local rows, inventoryReason = store:AllStored()
        if not rows then return nil, inventoryReason end

        for _, row in ipairs(rows) do
            used[row.address.id] = true

            for _, component in pairs(row.record) do
                local ok, why = data.ReserveRotationIdentities(component, used)
                if not ok then return nil, why.code end
            end
        end

        for _, draft in pairs(pending) do
            used[draft.reference.address.id] = true
        end

        return function()
            local ok, id = pcall(owner.uuid)
            if not ok or not text(id, 128) or not id:match('^[%w][%w._:%-]*$') then return nil end
            if used[id] then return nil end
            used[id] = true
            return id
        end
    end

    -- Saves a prepared import as a new custom rotation, or over `replacement` when given. Validates the body and class,
    -- applies the spec policy, keeps a free identifier, gives every step a fresh id while recording its origin, retains
    -- the import manifest and commits with the 'import' revision policy. Returns id, nil, the saved reference and the
    -- active transition, or nil and a reason.
    function coordinator:Import(prepared, number, name, replacement, options)
        if options ~= nil and not plain(options) then return nil, 'invalid-rotation-options' end
        if replacement ~= nil and not plain(replacement) then return nil, 'invalid-replacement-target' end
        if not validSpec(number) then return nil, 'invalid-specialization' end
        if type(name) ~= 'string' or not name:find('%S') or #name > 256 then return nil, 'invalid-name' end
        local ok, why = ready()
        if not ok then return nil, why end
        local c, contextReason = context()
        if not c then return nil, contextReason end
        if not plain(prepared) then return nil, 'invalid-import' end
        local body = data.CopyData(prepared.body)
        if not plain(body) then return nil, 'invalid-import' end

        -- Specializations (body.specs) travel only where they mean the same on
        -- every account; see addon:PrepareImportedRotationSpecs.
        if owner.PrepareImportedRotationSpecs then
            local specs, specReason = owner:PrepareImportedRotationSpecs(
                body.specs,
                options and options.specs,
                replacement
            )

            if specReason then return nil, specReason end
            body.specs = specs
        end

        local manifest = prepared.manifest and copy(prepared.manifest)
        if prepared.manifest and not manifest then return nil, 'invalid-import' end

        if
            manifest
            and manifest.applicability
            and manifest.applicability.class
            and manifest.applicability.class ~= c.class
        then
            return nil, 'class-mismatch'
        end

        local validation

        if manifest then
            local envelope = copy(manifest)
            envelope.body = body
            validation = data.ValidateEnvelope(envelope, owner:GetRotationValidationOptions())
        else
            validation = data.ValidateBody(body, owner:GetRotationValidationOptions())
        end

        if not validation.valid or not validation.supported or not validation.resolved then
            return nil, 'import-not-ready'
        end

        local reference, token, legacyValid

        if replacement then
            if replacement.profile and replacement.profile ~= profile then return nil, 'rotation-changed-externally' end
            reference, why = self:Resolve(number, replacement.reference or replacement.id)
            if not reference then return nil, why end
            if reference.kind ~= 'custom' then return nil, 'read-only-rotation' end
            token = replacement.recordToken

            if not token then
                if type(replacement.valid) ~= 'function' then return nil, 'stale-rotation-record' end
                local record
                record, token = self:Snapshot(number, reference)
                if not record then return nil, token end
                legacyValid = replacement.valid
            end
        end

        -- An imported identifier is kept when it is free here; a taken one is
        -- dropped, so the identifier is made from the rotation's name instead.
        if body.identifier ~= nil and owner.CheckRotationIdentifier then
            local except = reference and keyFor(reference) or nil
            if owner:CheckRotationIdentifier(number, except, body.identifier) then body.identifier = nil end
        end

        local allocate, allocationReason = self:Allocator()
        if not allocate then return nil, allocationReason end
        local id = reference and reference.address.id or allocate()
        if not id then return nil, 'id-collision' end
        local origins = {}
        local tree, treeError = data.IndexRotationSteps(body)
        if not tree then return nil, treeError.code end

        for _, row in ipairs(tree.rows) do
            local old = row.step.id
            local id = allocate()
            if not id then return nil, 'id-collision' end
            row.step.id = id
            origins[id] = prepared.stepOrigins and prepared.stepOrigins[old] or old
        end

        body.name = name
        local record = { body = body }

        if manifest then
            local sourceId = prepared.sourceId or manifest.id
            local sourceRevision = prepared.sourceRevision or manifest.revision
            manifest.id = id
            manifest.revision = 1
            manifest.nameKey = name

            record.imported = {
                manifest = manifest,
                sourceId = sourceId,
                sourceRevision = sourceRevision,
                stepOrigins = origins,
            }
        end

        local scope = reference and reference.address.scope or options and options.scope or 'class'
        if scope ~= 'class' and scope ~= 'character' then return nil, 'invalid-owner-scope' end
        if scope == 'character' and not c.character then return nil, 'missing-owner-context' end

        reference = reference or {
            kind = 'custom',
            address = {
                scope = scope,
                class = c.class,
                owner = scope == 'class' and c.class or c.character,
                spec = number,
                id = id,
            },
        }

        if legacyValid then
            local ok, valid = pcall(legacyValid)
            if not ok or not valid then return nil, 'rotation-changed-externally' end
        end

        local saved, commitReason, transition = self:Commit(reference, token, record, scope, 'import')
        if not saved then return nil, commitReason end
        return id, nil, saved, transition
    end

    -- Clones a Built In or custom rotation under `name` into the class or character scope, with fresh step ids and the
    -- lineage or correspondence needed to compare the copy with its source. The copy never keeps the source's
    -- identifier. Returns the new id, nil and the saved reference, or nil and a reason.
    function coordinator:Copy(number, value, name, options)
        if options ~= nil and not plain(options) then return nil, 'invalid-rotation-options' end
        if type(name) ~= 'string' or not name:find('%S') or #name > 256 then return nil, 'invalid-name' end
        local reference, why = self:Resolve(number, value)
        if not reference then return nil, why end
        local record, reason = self:Snapshot(number, reference)
        if not record then return nil, reason end
        local allocate, allocationReason = self:Allocator()
        if not allocate then return nil, allocationReason end
        local body = record.body
        local copiedRecord = {}
        local id

        if reference.kind == 'builtin' then
            local source = record.source
            local state = {}
            local catalog = data.NewCatalog({ state = state, newId = allocate })
            assert(catalog:RegisterBuiltin(source.envelope))
            id, why = catalog:Clone({ kind = 'builtin', id = reference.id }, name)
            if not id then return nil, why end
            local view = catalog:Get({ kind = 'custom', id = id })
            local manifest = view.envelope
            copiedRecord.body = manifest.body
            manifest.body = nil

            if manifest.applicability.universal then
                manifest.applicability.universal = nil
                manifest.applicability.class = context().class
            end

            copiedRecord.origin = { manifest = manifest, lineage = view.lineage }
        else
            id = allocate()
            if not id then return nil, 'id-collision' end
            local identity, why = self:ComparisonIdentity(number, reference)
            if not identity then return nil, why end

            local correspondence = {
                kind = identity.kind == 'import' and 'custom' or identity.kind,
                id = identity.id,
                origins = {},
                sourceAddress = copy(identity.sourceAddress),
            }

            local tree, errorText = data.IndexRotationSteps(body, { allowMissingIds = true })
            if not tree then return nil, errorText.code end
            copiedRecord = copyRecord(record)
            copiedRecord.body = body
            local lineage = copiedRecord.origin and copiedRecord.origin.lineage
            local oldOrigins = lineage and copy(lineage.stepOrigins)

            if lineage then
                lineage.clonedFrom = reference.address.id
                lineage.stepOrigins = {}
            end

            local imported = copiedRecord.imported
            local oldImported = imported and copy(imported.stepOrigins)
            if imported then imported.stepOrigins = {} end

            for _, row in ipairs(tree.rows) do
                local old = row.step.id
                local new = allocate()
                if not new then return nil, 'id-collision' end
                row.step.id = new
                correspondence.origins[new] = identity.origins and identity.origins[old] or old
                if lineage then lineage.stepOrigins[new] = oldOrigins[old] end
                if imported then imported.stepOrigins[new] = oldImported[old] or old end
            end

            body.name = name

            for _, source in ipairs({ copiedRecord.origin or false, copiedRecord.imported or false }) do
                if source then
                    source.manifest.id = id
                    source.manifest.revision = 1
                    source.manifest.nameKey = name
                end
            end

            if not imported then
                copiedRecord.comparison = correspondence
            else
                copiedRecord.comparison = nil
            end
        end

        local c, contextReason = context()
        if not c then return nil, contextReason end
        local scope = options and options.scope or 'class'
        if scope ~= 'class' and scope ~= 'character' then return nil, 'invalid-owner-scope' end
        if scope == 'character' and not c.character then return nil, 'missing-owner-context' end

        local target = {
            kind = 'custom',
            address = {
                scope = scope,
                class = c.class,
                owner = scope == 'class' and c.class or c.character,
                spec = number,
                id = id,
            },
        }

        -- A copy never keeps its source's identifier; until you set one, its
        -- identifier is made from its new name (ListRotationIdentifiers).
        if type(copiedRecord.body) == 'table' then copiedRecord.body.identifier = nil end
        local saved, commitReason = self:Commit(target, nil, copiedRecord, scope)
        if not saved then return nil, commitReason end
        return id, nil, saved
    end

    -- Returns the live canonical body of a custom rotation for the older in-place editors. First rewrites the record so
    -- the body is independent of any shared table, keeping valid Snapshot tokens, then marks it exposed so later passes
    -- revalidate it. A Built In returns 'readonly-rotation'.
    function coordinator:GetEditableRotation(number, value)
        local reference, why = self:Resolve(number, value)
        if not reference then return nil, why end
        if reference.kind == 'builtin' then return nil, 'readonly-rotation' end
        local c, reason = context()
        if not c then return nil, reason end

        local readable, alreadyExposed, previousSeal = reader:Read(reference.address, c, function(record)
            return exposed[record.body] == true
        end)

        if not readable then return nil, alreadyExposed end

        if not alreadyExposed then
            -- A portable store may legitimately share payload tables between
            -- records or history. The mutable legacy escape must first acquire
            -- an independent canonical body, without changing any data values.
            local detached, token = store:Get(reference.address, c)
            if not detached then return nil, token end
            local plan, planReason = store:PlanReplace(reference.address, detached, c, token)
            if not plan then return nil, planReason end
            local committed, commitReason = store:Commit(plan, c)
            if not committed then return nil, commitReason end
            if finishChoicePublication then finishChoicePublication(nil) end
            -- This transaction changed identity only. Preserve UI authorities
            -- that still describe the exact complete value being detached.
            local _, freshToken = store:Get(reference.address, c)
            local _, _, freshSeal = reader:Read(reference.address, c, function() return true end)

            for _, issued in pairs(expected) do
                if
                    issued.seal == previousSeal
                    and same(issued.reference, reference)
                    and same(issued.context, c)
                    and same(issued.baseline, detached)
                then
                    issued.token = freshToken
                    issued.seal = freshSeal
                end
            end
        end

        local ok, body = reader:Read(reference.address, c, function(record)
            exposureVersion = {}
            invalidateExecution()
            exposed[record.body] = true
            local asset = assets[referenceKey(reference)]
            if asset then asset.untracked = true end
            return record.body
        end)

        if not ok then return nil, body end
        return body
    end

    -- ============================================================================
    -- Coordinator: roster headers
    -- ============================================================================

    -- Builds the roster rows for specialization `number`: saved custom rotations (projections cached by record seal),
    -- the fallback's virtual draft when none is saved, and Built In rotations. Returns the rows and a roster stamp that
    -- changes only when something the roster shows has changed.
    function coordinator:Headers(number)
        local ok, why = ready()
        if not ok then return nil, why end
        local c, reason = context()
        if not c then return nil, reason end
        local rows, stamp = reader:ListOwned(number, c)
        if not rows then return nil, stamp end
        local fallback = fallbackReference(number)
        local result = {}
        local presentationChanged = false
        local virtualSignature
        local validation, validationStamp = owner:GetRotationValidationOptions()

        for _, row in ipairs(rows) do
            if row.address.id ~= profile.rotationFallbackID or row.address.spec == number then
                local reference = { kind = 'custom', address = row.address }
                local key = keyFor(reference)
                local header = headers[key]
                local valid = header and reader:IsCurrent(header.seal, c)

                local projected, view = reader:Read(row.address, c, function(record)
                    if header and valid and header.stamp == validationStamp and not exposed[record.body] then
                        return header.view
                    end

                    local body = record.body

                    local manifest = record.origin and record.origin.manifest
                        or record.imported and record.imported.manifest

                    local status = data.ValidateBody(body, validation)

                    if manifest then
                        local envelope = {}

                        for k, v in pairs(manifest) do
                            envelope[k] = v
                        end

                        envelope.body = body
                        status = data.ValidateEnvelope(envelope, validation)
                    end

                    local state = not status.valid and 'invalid'
                        or not status.supported and 'unsupported'
                        or not status.resolved and 'unresolved'
                        or 'valid'

                    local first = status.diagnostics[1]

                    local projection = {
                        validationState = state,
                        problem = first and {
                            code = first.code,
                            path = first.path,
                            condition = first.condition,
                            reason = first.reason,
                        },
                        body = {
                            name = type(body.name) == 'string' and body.name or nil,
                            description = type(body.description) == 'string' and body.description or nil,
                            priority = body.priority,
                            disabled = body.disabled,
                            identifier = type(body.identifier) == 'string' and body.identifier or nil,
                            tags = tagsView(body.tags),
                            metadata = metadataView(body.metadata),
                            specs = data.NormalizeRotationSpecs(body.specs) or nil,
                        },
                        tags = manifest and copy(manifest.tags),
                        sources = manifest and copy(manifest.sources),
                    }

                    return projection
                end)

                if not projected then return nil, view end
                if not header or not same(header.view, view) then presentationChanged = true end
                headers[key] = { seal = row.seal, view = view, stamp = validationStamp }

                result[#result + 1] = {
                    key = key,
                    reference = copy(reference),
                    canonicalId = row.address.id,
                    kind = 'custom',
                    scope = row.address.scope,
                    name = view.body.name or L['Unnamed rotation'],
                    description = view.body.description or '',
                    enabled = not view.body.disabled,
                    priority = data.GetRotationPriority(view.body.priority),
                    identifier = view.body.identifier,
                    tags = data.GetRotationTags(view) or {},
                    search = data.RotationSearchText(view, view.body.name or '', view.body.description or ''),
                    readOnly = false,
                    pending = false,
                    virtual = false,
                    fallback = row.address.id == profile.rotationFallbackID,
                    effectiveFallback = fallback and same(fallback, reference) or false,
                    validationState = view.validationState,
                    problem = view.problem,
                    specs = copy(view.body.specs),
                }
            end
        end

        local virtual = {
            kind = 'custom',
            address = {
                scope = 'class',
                class = c.class,
                owner = c.class,
                spec = number,
                id = profile.rotationFallbackID,
            },
        }

        local exists, missing = reader:Read(virtual.address, c, function() return true end)

        if not exists and missing == 'unknown-rotation' then
            local reference, key = self:NewDraft(number, 'class', true)

            if reference then
                virtualSignature = key .. referenceKey(reference)

                result[#result + 1] = {
                    key = key,
                    reference = reference,
                    canonicalId = profile.rotationFallbackID,
                    kind = 'custom',
                    scope = 'class',
                    name = profile.rotationFallbackID,
                    description = '',
                    enabled = true,
                    priority = 0,
                    tags = {},
                    search = profile.rotationFallbackID:lower(),
                    readOnly = false,
                    pending = true,
                    virtual = true,
                    fallback = true,
                    effectiveFallback = false,
                    validationState = 'pending',
                }
            end
        elseif not exists then
            return nil, missing
        end

        local builtinPresentation = {}

        if libraryReader then
            local rows, why = libraryReader:List(number, function(id, view, body)
                local reference = { kind = 'builtin', id = id }
                local name = L[view.nameKey or id]
                local description = L[view.descriptionKey or '']
                local eligible, eligibilityReason = libraryReader:Eligible(view, number, false)
                local first = view.validation.diagnostics and view.validation.diagnostics[1]

                local problem = first and {
                    code = first.code,
                    path = first.path,
                    condition = first.condition,
                    reason = first.reason,
                }

                local _, builtinState = owner:GetBuiltinSwitch(id)

                builtinPresentation[id] = {
                    name = name,
                    description = description,
                    eligible = eligible,
                    reason = eligibilityReason,
                    problem = problem,
                    state = builtinState,
                }

                local specs = type(view.envelope) == 'table'
                    and type(view.envelope.body) == 'table'
                    and data.NormalizeRotationSpecs(view.envelope.body.specs)
                    or nil

                return {
                    key = keyFor(reference),
                    reference = reference,
                    canonicalId = id,
                    kind = 'builtin',
                    name = name,
                    description = description,
                    specs = specs,
                    identifier = owner.GetBuiltinIdentifier and owner:GetBuiltinIdentifier(id) or nil,
                    enabled = view.enabled,
                    switchedOn = view.switchedOn == true,
                    builtinState = builtinState,
                    eligible = eligible,
                    eligibilityReason = eligibilityReason,
                    priority = data.GetRotationPriority(body.priority),
                    tags = data.GetRotationTags(view.envelope) or {},
                    search = data.RotationSearchText(view.envelope, name, description),
                    readOnly = true,
                    pending = false,
                    virtual = false,
                    fallback = false,
                    effectiveFallback = false,
                    validationState = view.validation.valid and 'valid' or 'invalid',
                    problem = problem,
                }
            end)

            if not rows then return nil, why end

            for _, row in ipairs(rows) do
                result[#result + 1] = row
            end
        end

        local libraryStamp = libraryReader and libraryReader:Generation()
        local ownedCurrent = rosterOwned and reader:IsCurrent(rosterOwned, c)

        if
            not rosterStamp
            or not ownedCurrent
            or rosterLibrary ~= libraryStamp
            or rosterValidation ~= validationStamp
            or rosterVirtual ~= virtualSignature
            or not same(rosterBuiltin, builtinPresentation)
            or presentationChanged
        then
            rosterStamp = {}
        end

        if not ownedCurrent then rosterOwned = stamp end
        rosterLibrary = libraryStamp
        rosterValidation = validationStamp
        rosterVirtual = virtualSignature
        rosterBuiltin = builtinPresentation
        return result, rosterStamp
    end

    -- ============================================================================
    -- Coordinator: runtime pass
    -- ============================================================================

    -- Opens a read pass for specialization `number` that evaluation takes rotation bodies from. A pass records the
    -- owner context, library generation, validation stamp and the record seals it read, and reports through IsCurrent
    -- when any of them changed. Methods: IsCurrent(), Get(value, candidates) and Candidates(candidates). `privateToken`
    -- marks the plan path, whose bodies are not treated as borrowed. Returns the pass, or nil and a reason.
    function coordinator:RuntimePass(number, privateToken)
        local request = evaluationRequest
        evaluationRequest = nil
        local private = request ~= nil or privateToken == privatePlanPass
        local version = contextVersion
        local ok, why = ready()
        if not ok then return nil, why end
        local c, reason = context()
        if not c then return nil, reason end
        local validation, referenceStamp = owner:GetRotationValidationOptions()
        local revision = owner.conditionRegistryVersion
        local generation = libraryReader and libraryReader:Generation()
        local pass = {}
        local selected, untracked, listSeal = {}, {}, nil
        local publicationSelected = {}
        local makePublicationGuard = managedStoreReader and ownedPublicationGuard
        local observedPrivate, observedMethod

        -- Returns the context eligibility is judged against: the private library value when the context method is
        -- proven to be the library's own, otherwise a copy of only the fields eligibility reads.
        local function eligibilityContext()
            local value, private, method = rotationContext(owner, number)

            if
                libraryContextProof
                and libraryContextProof(method, eligibilityContext, rotationContext)
                and private == true
            then
                observedPrivate, observedMethod = true, method
                return value
            end

            observedPrivate = false
            local result = {}

            for _, key in ipairs({
                'family',
                'class',
                'spec',
                'actionContext',
                'level',
                'build',
                'combatDataPolicy',
            }) do
                result[key] = value and value[key]
            end

            return result
        end

        local observedContext = eligibilityContext()

        local contextGuard = request and observedPrivate and libraryRuntimeContextGuard and libraryRuntimeContextGuard(
            observedContext,
            observedMethod,
            eligibilityContext,
            rotationContext
        )

        -- Checks everything a pass depends on except the record seals: coordinator readiness, owner context, evaluation
        -- context, library generation, validation stamp and condition registry version. Returns true, or nil and a
        -- reason.
        local function baseCurrent()
            local readyNow, problemText = ready()
            if not readyNow then return nil, problemText end
            local now = context()
            if not now or not same(now, c) then return nil, 'rotation-owner-changed' end
            if request and version ~= contextVersion then return nil, 'rotation-context-changed' end

            if contextGuard then
                local unchanged = contextGuard()
                if request and version ~= contextVersion then return nil, 'rotation-context-changed' end
                if unchanged == false then return nil, 'rotation-context-changed' end
                if unchanged == nil then contextGuard = nil end
            end

            if not contextGuard and not same(observedContext, eligibilityContext()) then
                return nil, 'rotation-context-changed'
            end

            local stamp

            if libraryReader then
                local eligible = libraryGenerationProof and libraryGenerationProof(nil, referenceStamp, generation)
                local method = libraryReader.Generation
                local currentGeneration, _, checked, proof = method(libraryReader)
                if currentGeneration ~= generation then return nil, 'rotation-library-changed' end

                if eligible and proof and libraryGenerationProof(method, referenceStamp, generation) then
                    stamp = checked
                end
            end

            -- Only the immediately preceding owned, unchanged library check can
            -- supply this observation; every uncertain path repeats the public read.
            if stamp == nil then stamp = owner:GetRotationValidationStamp() end

            if stamp ~= referenceStamp or owner.conditionRegistryVersion ~= revision then
                return nil, 'rotation-dependencies-changed'
            end

            return true
        end

        -- True while the pass's checks and every record it has read are unchanged; otherwise nil and the reason.
        function pass:IsCurrent()
            local current, problemText = baseCurrent()
            if not current then return nil, problemText end

            if listSeal then
                if not reader:IsCurrent(listSeal, c) then return nil, 'rotation-records-changed' end
            else
                for _, seal in pairs(selected) do
                    if not reader:IsCurrent(seal, c) then return nil, 'rotation-records-changed' end
                end
            end

            for _, watch in pairs(untracked) do
                local readable, unchanged = reader:Read(watch.address, c, function(record)
                    return data.CheckPortable(record.body) and same(record.body, watch.baseline)
                end)

                if not readable or not unchanged then return nil, 'rotation-records-changed' end
            end

            return true
        end

        -- Reads the owner's record list once and keeps its seal, so a later change to the list invalidates the pass.
        local function observeList()
            if listSeal then return true end
            local rows, seal = reader:ListOwned(number, c)
            if not rows then return nil, seal end
            listSeal = seal
            return true
        end

        -- Batch candidates validate their complete list once before publication.
        -- Rechecking an ever-growing selected set for each row would be O(n^2).
        -- Returns the evaluation body for one rotation, or nil and a reason ('disabled', 'specialization-mismatch',
        -- 'action-context-mismatch', 'disabled-dependency', 'invalid-fallback', ...). The body is validated and cached
        -- per record seal. `batch` skips the per-call currency check because Candidates validates the whole list once.
        local function get(value, candidates, batch)
            local readyNow, problemText

            if batch then
                readyNow, problemText = baseCurrent()
            else
                readyNow, problemText = pass:IsCurrent()
            end

            if not readyNow then return nil, problemText end
            local reference, errorText = coordinator:Resolve(number, value)
            if not reference then return nil, errorText end
            local index = referenceKey(reference)

            if reference.kind == 'builtin' then
                local readable, item = libraryReader:Read(
                    number,
                    reference.id,
                    function(view, body, allowed, eligibilityReason)
                        if not allowed then return { reason = eligibilityReason } end
                        local asset = assets[index]

                        if not asset or asset.generation ~= generation then
                            asset = { body = copy(body), generation = generation }
                            assets[index] = asset
                        end

                        return asset
                    end,
                    candidates
                )

                if not readable then return nil, item end
                if item.reason then return nil, item.reason end

                if not batch then
                    local current, problemText = pass:IsCurrent()
                    if not current then return nil, problemText end
                end

                -- A public caller keeps the body it is given, so mark it borrowed and retire the plan built on it;
                -- the private plan path never hands a body out.
                if not private then
                    if not item.borrowed and readActiveRuntime and readActiveRuntime(
                        owner,
                        number,
                        byReference[index]
                    ) then
                        invalidateExecution()
                    end

                    item.borrowed = true
                end

                return item.body
            end

            if reference.address.id == fallbackID then
                local observed, problemText = observeList()
                if not observed then return nil, problemText end
                local effective, fallbackReason = coordinator:Resolve(number, DEFAULT)
                if not effective then return nil, fallbackReason end
                if not same(reference, effective) then return nil, 'inactive-fallback' end
            end

            local okRead, asset, seal = reader:Read(reference.address, c, function(record, recordSeal)
                local previous = assets[index]

                if
                    previous
                    and previous.seal == recordSeal
                    and previous.stamp == referenceStamp
                    and not exposed[record.body]
                then
                    return previous
                end

                local portable = data.CheckPortable(record.body)
                if not portable then return { unavailable = 'invalid-rotation-body' } end

                if
                    previous
                    and previous.seal == recordSeal
                    and previous.stamp == referenceStamp
                    and exposed[record.body]
                    and same(record.body, previous.baseline)
                then
                    return previous
                end

                local status = data.ValidateBody(record.body, validation)
                local provenance = record.origin or record.imported
                local source = provenance and copy(provenance.manifest)

                if source then
                    source.body = copy(record.body)
                    status = data.ValidateEnvelope(source, validation)
                end

                local item = {
                    seal = recordSeal,
                    stamp = referenceStamp,
                    baseline = copy(record.body),
                    body = copy(record.body),
                    validation = status,
                    applicability = source and source.applicability,
                    untracked = exposed[record.body] == true,
                }

                assets[index] = item
                return item
            end)

            if not okRead then return nil, asset end
            selected[index] = seal

            if request and type(makePublicationGuard) == 'function' then
                publicationSelected[index] = makePublicationGuard(reader, seal, c)
            end

            if asset.untracked then
                untracked[index] = { address = copy(reference.address), baseline = asset.baseline }
            end

            if not batch then
                local current, problemText = pass:IsCurrent()
                if not current then return nil, problemText end
            end

            local status = asset.validation

            if asset.unavailable or not status.valid or not status.supported or not status.resolved then
                return nil,
                    reference.address.id == fallbackID and 'invalid-fallback'
                        or asset.unavailable
                        or 'rotation-unavailable'
            end

            if asset.body.disabled then return nil, 'disabled' end

            -- A rotation restricted to other specializations (body.specs);
            -- the fallback belongs to its namespace instead.
            if
                not candidates
                and reference.address.id ~= fallbackID
                and type(asset.body.specs) == 'table'
                and owner.RotationSpecsApply
                and not owner:RotationSpecsApply(asset.body.specs, number)
            then
                return nil, 'specialization-mismatch'
            end

            if asset.applicability then
                local allowed, eligibilityReason = libraryReader:Eligible({
                    enabled = true,
                    validation = status,
                    applicability = asset.applicability,
                }, number, candidates)

                if not allowed then return nil, eligibilityReason end
            else
                local info = rotationContext(owner, number)

                -- A bare record acts through the player's own bar unless its
                -- switch condition opts into the current special context.
                if not candidates and info.actionContext ~= 'player' then
                    local optIn = asset.contextOptIn

                    if not optIn then
                        optIn = {}
                        asset.contextOptIn = optIn
                    end

                    if optIn[info.actionContext] == nil then
                        optIn[info.actionContext] = bareContextOptIn(asset.body, info.actionContext)
                    end

                    if not optIn[info.actionContext] then return nil, 'action-context-mismatch' end
                end
            end

            if owner:HasDisabledRotationDependency(asset.body) then return nil, 'disabled-dependency' end

            if not batch then
                local current, problemText = pass:IsCurrent()
                if not current then return nil, problemText end
            end

            if not private then
                if not asset.borrowed and readActiveRuntime and readActiveRuntime(
                    owner,
                    number,
                    byReference[index]
                ) then
                    invalidateExecution()
                end

                asset.borrowed = true
            end

            return asset.body
        end

        -- Public read of one rotation by reference, key or id; see get.
        function pass:Get(value, candidates)
            return get(value, candidates, false)
        end

        -- Returns a table of key to body for every rotation that can be considered (saved ones, the effective fallback
        -- and Built In), or an empty table and a reason when the pass is not current.
        function pass:Candidates(candidates)
            local current, problemText = self:IsCurrent()
            if not current then return {}, problemText end
            if candidates == nil then candidates = true end
            local rows, seal = reader:ListOwned(number, c)
            if not rows then return {}, seal end
            -- Keep the original seal when a caller repeats Candidates on the
            -- same pass: stale authority must never be refreshed implicitly.
            listSeal = listSeal or seal
            local fallback = coordinator:Resolve(number, DEFAULT)
            local result = {}

            for _, row in ipairs(rows) do
                local reference = { kind = 'custom', address = row.address }
                local effective = row.address.id == fallbackID and fallback and same(reference, fallback)

                if row.address.id ~= fallbackID or effective then
                    local body = get(reference, candidates, true)
                    if body then result[effective and DEFAULT or keyFor(reference)] = body end
                end
            end

            if libraryReader then
                local views, libraryReason = libraryReader:List(number, function(id)
                    return { kind = 'builtin', id = id }
                end)

                if not views then return {}, libraryReason end

                for _, reference in ipairs(views) do
                    local body = get(reference, candidates, true)
                    if body then result[keyFor(reference)] = body end
                end
            end

            local complete, completionReason = self:IsCurrent()
            if not complete then return {}, completionReason end
            return result
        end

        if request and managedStoreReader then
            local originalCurrent = pass.IsCurrent
            request.pass = pass

            request.publication = function()
                -- Public overrides and list/fallback semantics retain the full route.
                if
                    pass.IsCurrent ~= originalCurrent
                    or listSeal
                    or not storeScopeEnvironment
                    or getfenv ~= storeGetfenv
                    or storeGetfenv(originalCurrent) ~= storeScopeEnvironment
                then
                    return pass:IsCurrent()
                end

                local current, problemText = baseCurrent()
                if not current then return nil, problemText end

                if listSeal then
                    if not reader:IsCurrent(listSeal, c) then return nil, 'rotation-records-changed' end
                else
                    for index, seal in pairs(selected) do
                        local guard = publicationSelected[index]
                        local unchanged = guard and guard()
                        -- Base authority has already run. Fall back only this
                        -- selected-store check, without repeating callbacks.
                        if unchanged == nil then unchanged = reader:IsCurrent(seal, c) end
                        if not unchanged then return nil, 'rotation-records-changed' end
                    end
                end

                -- Retain the supported mutable canonical-body watcher verbatim.
                for _, watch in pairs(untracked) do
                    local readable, unchanged = reader:Read(watch.address, c, function(record)
                        return data.CheckPortable(record.body) and same(record.body, watch.baseline)
                    end)

                    if not readable or not unchanged then return nil, 'rotation-records-changed' end
                end

                return true
            end
        end

        return pass
    end

    -- ============================================================================
    -- Coordinator: cold plan source
    -- ============================================================================

    -- Main alone receives this cold planner; public RuntimePass stays eager.
    local ownedResolve, ownedPass = coordinator.Resolve, coordinator.RuntimePass
    local ownerPlatform = rawget(owner, 'Platform')
    local ownerClass = type(ownerPlatform) == 'table' and rawget(ownerPlatform, 'GetPlayerOwnerClassObservation')

    -- Builds the private plan source for the active custom rotation: a detached execution body, the cooldown
    -- presentation views and the currency checks (entry, current, conditionCurrent, authority) that let the lean engine
    -- reuse a plan. Returns nothing unless every captured function, the profile, the store, the library and the active
    -- selection are the originals and the body has not been exposed or borrowed.
    currentPlanSource = function(spec, key)
        if
            current ~= coordinator
            or not alive
            or not managedStoreReader
            or not readActiveRuntime
            or not copyActiveRuntime
            or not planDataCurrent(owner)
            or not runtimeAuthority
            or not readLibraryRuntime
            or not planEligible
            or rawget(owner, 'AcquireRotationRuntimePass') ~= ownedAcquireRuntimePass
            or storeGetfenv(ownedAcquireRuntimePass) ~= storeScopeEnvironment
            or rawget(owner, 'GetScopedRotationCoordinator') ~= ownedScopedCoordinator
            or rawget(coordinator, 'Resolve') ~= ownedResolve
            or rawget(coordinator, 'RuntimePass') ~= ownedPass
            or rawget(owner, 'GetRotationOwnerContext') ~= ownedOwnerContext
            or rawget(owner, 'GetRotationContext') ~= ownedRuntimeContext
            or rawget(owner, 'Platform') ~= ownerPlatform
            or not ownerPlatform
            or rawget(ownerPlatform, 'CanReadValue') ~= ownedRuntimeReadValue
            or rawget(ownerPlatform, 'GetPlayerOwnerClassObservation') ~= ownerClass
        then
            return
        end

        local known = byKey[key]
        if not known or known.kind ~= 'custom' or known.address.id == fallbackID then return end
        local existing = assets[referenceKey(known)]
        if existing and (existing.untracked or existing.borrowed) then return end
        local handle, revision = readActiveRuntime(owner, spec, key)
        if not handle then return end
        local epoch, db, p, g, defs, registry, shared, personal, effects, libraryState = runtimeAuthority(owner)
        if not epoch then return end
        local pass = ownedPass(coordinator, spec, privatePlanPass)
        local body = pass and pass:Get(key)
        if not body or not pass:IsCurrent() then return end
        local reference = ownedResolve(coordinator, spec, key)
        if not reference or reference.kind ~= 'custom' or reference.address.id == fallbackID then return end
        local contextValue = context()
        if not contextValue then return end
        local ok, selected, seal = reader:Read(reference.address, contextValue, function(record) return record end)
        if not ok or exposed[selected.body] then return end
        local guard, storeContinuation
        local executionGuard = ownedExecutionGuard or ownedPublicationGuard

        if executionGuard then
            guard, storeContinuation = executionGuard(reader, seal, contextValue, function()
                if alive and current == coordinator then invalidateExecution() end
            end)
        end

        if not guard or not storeContinuation or guard() ~= true then return end
        local execution = copyActiveRuntime(owner, handle, body)
        if not execution then return end
        local asset = assets[referenceKey(reference)]
        if not asset or not asset.validation then return end
        local generation, definitionVersion = readLibraryRuntime()
        local exposure = exposureVersion

        -- Full proof that the plan's inputs are unchanged. Returns whether it holds, plus the active handle, revision
        -- and transition token it observed.
        local function authority()
            local nextEpoch, nextDB, nextProfile, nextGlobal, nextDefs, nextRegistry, nextShared, nextPersonal, nextEffects, nextLibrary = runtimeAuthority(
                owner
            )

            local libraryGeneration, libraryVersion = readLibraryRuntime()

            if not (alive
                and current == coordinator
                and rawget(profile, 'rotationStore') == state
                and rawget(profile, 'rotationFallbackID') == fallbackID
                and rawget(owner, 'AcquireRotationRuntimePass') == ownedAcquireRuntimePass
                and storeGetfenv(ownedAcquireRuntimePass) == storeScopeEnvironment
                and planDataCurrent(owner)
                and bindIdentity(nextEpoch, epoch)
                and bindIdentity(nextDB, db)
                and bindIdentity(nextProfile, p)
                and bindIdentity(nextGlobal, g)
                and bindIdentity(nextDefs, defs)
                and bindIdentity(nextRegistry, registry)
                and bindIdentity(nextShared, shared)
                and bindIdentity(nextPersonal, personal)
                and bindIdentity(nextEffects, effects)
                and bindIdentity(nextLibrary, libraryState)
                and bindIdentity(libraryGeneration, generation)
                and libraryVersion == definitionVersion
                and exposure == exposureVersion
                and not exposed[selected.body]
                and not asset.borrowed
                and rawget(owner, 'GetScopedRotationCoordinator') == ownedScopedCoordinator
                and rawget(coordinator, 'Resolve') == ownedResolve
                and rawget(coordinator, 'RuntimePass') == ownedPass
                and rawget(owner, 'GetRotationOwnerContext') == ownedOwnerContext
                and rawget(owner, 'GetRotationContext') == ownedRuntimeContext
                and rawget(owner, 'Platform') == ownerPlatform
                and ownerPlatform
                and rawget(ownerPlatform, 'CanReadValue') == ownedRuntimeReadValue
                and rawget(ownerPlatform, 'GetPlayerOwnerClassObservation') == ownerClass
                and guard() == true) then
                return false
            end

            -- The Store environment certificate can call a captured getter.
            -- Snapshot active authority after it, never before that boundary.
            local activeHandle, activeRevision, operation = readActiveRuntime(owner, spec, key)

            return bindIdentity(activeHandle, handle) and activeRevision == revision,
                activeHandle,
                activeRevision,
                operation
        end

        if not authority() then return end
        local view = { enabled = true, validation = asset.validation, applicability = asset.applicability }

        -- Plan's private caller has just proved cache authority. Recheck only
        -- the actual inputs to context/eligibility before those handoffs; the
        -- complete proof follows their callbacks at the end of entry.
        -- True while the functions the context and eligibility handoffs call are still the captured originals.
        local function contextInputsCurrent()
            return planRawget(storeScopeEnvironment, 'type') == planType
                and planRawget(storeScopeEnvironment, 'ipairs') == planIpairs
                and planRawget(owner, 'GetRotationOwnerContext') == ownedOwnerContext
                and planRawget(owner, 'GetRotationContext') == ownedRuntimeContext
                and planRawget(owner, 'Platform') == ownerPlatform
                and planRawget(ownerPlatform, 'CanReadValue') == ownedRuntimeReadValue
                and planRawget(ownerPlatform, 'GetPlayerOwnerClassObservation') == ownerClass
                and storeGetfenv(planEligible) == storeScopeEnvironment
        end

        -- Evaluates context and eligibility for the plan. Returns { version, operation, allowed, reason }, or nothing
        -- when any input or authority check fails.
        local function entry()
            if not contextInputsCurrent() then return end
            local actor = context()

            if
                not contextInputsCurrent()
                or not actor
                or actor.class ~= contextValue.class
                or actor.character ~= contextValue.character
            then
                return
            end

            local info, private, method = rotationContext(owner, spec)

            if
                not contextInputsCurrent() or private ~= true or not libraryContextProof(method, entry, rotationContext)
            then
                return
            end

            local allowed, reason

            if view.applicability then
                allowed, reason = planEligible(view, info, false)
            else
                allowed = true

                if info.actionContext ~= 'player' and not bareContextOptIn(body, info.actionContext) then
                    allowed, reason = false, 'action-context-mismatch'
                end
            end

            local _, _, operation = readActiveRuntime(owner, spec, key)
            if not authority() then return end
            return { version = contextVersion, operation = operation, allowed = allowed == true, reason = reason }
        end

        -- True while an entry result still matches the context version and authority.
        local function currentEntry(value)
            if not value or value.version ~= contextVersion then return false end
            local valid, activeHandle, activeRevision, operation = authority()
            return valid and bindIdentity(operation, value.operation), activeHandle, activeRevision, operation
        end

        -- Cheaper currency check for the condition phase: the same authorities as `authority` without the ownership
        -- checks already proved by the preceding entry.
        local function conditionCurrent(value)
            if
                not value
                or value.version ~= contextVersion
                or not alive
                or current ~= coordinator
                or rawget(profile, 'rotationStore') ~= state
                or rawget(profile, 'rotationFallbackID') ~= fallbackID
                or exposure ~= exposureVersion
                or exposed[selected.body]
                or asset.borrowed
                or not planDataCurrent(owner)
            then
                return false
            end

            local activeHandle, activeRevision, operation = readActiveRuntime(owner, spec, key)

            if
                not bindIdentity(activeHandle, handle)
                or activeRevision ~= revision
                or not bindIdentity(operation, value.operation)
            then
                return false
            end

            local nextEpoch, nextDB, nextProfile, nextGlobal, nextDefs, nextRegistry, nextShared, nextPersonal, nextEffects, nextLibrary = runtimeAuthority(
                owner,
                true
            )

            if
                not bindIdentity(nextEpoch, epoch)
                or not bindIdentity(nextDB, db)
                or not bindIdentity(nextProfile, p)
                or not bindIdentity(nextGlobal, g)
                or not bindIdentity(nextDefs, defs)
                or not bindIdentity(nextRegistry, registry)
                or not bindIdentity(nextShared, shared)
                or not bindIdentity(nextPersonal, personal)
                or not bindIdentity(nextEffects, effects)
                or not bindIdentity(nextLibrary, libraryState)
            then
                return false
            end

            local libraryGeneration, libraryVersion = readLibraryRuntime()

            return bindIdentity(libraryGeneration, generation)
                and libraryVersion == definitionVersion
                and storeContinuation() == true
        end

        -- Only the literal native cooldown publisher receives these views.
        -- Runtime colors already belong to one CopyData graph, separate from
        -- execution: retain sibling aliases and later eager-fallback mutations.
        local presentation = {}

        for index, step in planIpairs(execution.cooldowns or {}) do
            local public = body.cooldowns[index]

            presentation[step] = {
                id = public.id,
                effect = public.effect,
                color = public.color,
                magnification = public.magnification,
                setpoint = public.setpoint,
                xoffs = public.xoffs,
                yoffs = public.yoffs,
                angle = public.angle,
            }
        end

        return {
            body = execution,
            presentation = presentation,
            handle = handle,
            token = {},
            entry = entry,
            current = currentEntry,
            conditionCurrent = conditionCurrent,
            authority = authority,
            executionSource = function(receiver) return planExecutionSource(owner, receiver) end,
        }
    end

    ownedRuntimePasses[coordinator] = coordinator.RuntimePass
    completeRebind(binding, coordinator, problem)
    if problem then return nil, problem end
    return true
end

-- ============================================================================
-- Public wrappers and startup handoffs
-- ============================================================================

-- Returns the bound coordinator, or nil and 'rotation-profile-not-bound'.
local function bound()
    local value = addon:GetScopedRotationCoordinator()
    if not value then return nil, 'rotation-profile-not-bound' end
    return value
end

-- Public wrapper for coordinator:Resolve.
function addon:ResolveRotationReference(spec, value)
    local c, why = bound()
    if not c then return nil, why end
    return c:Resolve(spec, value)
end

-- Public wrapper for coordinator:Headers.
function addon:ListRotationHeaders(spec)
    local c, why = bound()
    if not c then return nil, why end
    return c:Headers(spec)
end

-- Public wrapper for coordinator:Snapshot.
function addon:GetRotationRecordSnapshot(spec, value)
    local c, why = bound()
    if not c then return nil, why end
    return c:Snapshot(spec, value)
end

-- Public wrapper for coordinator:NewDraft.
function addon:NewRotationDraftTarget(spec, scope, fallback)
    local c, why = bound()
    if not c then return nil, why end
    return c:NewDraft(spec, scope, fallback)
end

-- Public wrapper for coordinator:Commit.
function addon:CommitRotationDraft(reference, token, record, scope)
    local c, why = bound()
    if not c then return nil, why end
    return c:Commit(reference, token, record, scope)
end

-- Public wrapper for coordinator:Delete.
function addon:DeleteRotationRecord(reference, token)
    local c, why = bound()
    if not c then return nil, why end
    return c:Delete(reference, token)
end

-- Public wrapper for coordinator:RuntimePass; evaluation in main.lua normally takes the private route instead.
function addon:AcquireRotationRuntimePass(spec)
    local c, why = bound()
    if not c then return nil, why end
    return c:RuntimePass(spec)
end

ownedAcquireRuntimePass = addon.AcquireRotationRuntimePass
local ownedGetCleanup = addon.GetRotationForCleanup

if type(installConsumerAvailability) == 'function' then
    installConsumerAvailability(function(owner)
        -- Decline before callback-capable work so public override/error dispatch
        -- follows the original eager sequence exactly once.
        if
            owner ~= addon
            or rawget(owner, 'AcquireRotationRuntimePass') ~= ownedAcquireRuntimePass
            or storeGetfenv(ownedAcquireRuntimePass) ~= storeScopeEnvironment
            or rawget(owner, 'GetScopedRotationCoordinator') ~= ownedScopedCoordinator
            or storeGetfenv(ownedScopedCoordinator) ~= storeScopeEnvironment
            or not current
            or type(ownedRuntimePasses[current]) ~= 'function'
            or rawget(current, 'RuntimePass') ~= ownedRuntimePasses[current]
            or storeGetfenv(ownedRuntimePasses[current]) ~= storeScopeEnvironment
            or not runtimeAuthority
            or not runtimeAuthority(owner)
            or not planDataCurrent(owner)
        then
            return nil
        end

        local pass = current:RuntimePass(owner.currentSpec, privatePlanPass)
        local body

        if pass then
            body = pass:Get(owner.currentRotation)
        else
            body = owner:GetRuntimeRotation(owner.currentSpec, owner.currentRotation)
        end

        return not not body
    end)
end

-- Only main receives this capability. Public/manual RuntimePass callers retain
-- the fresh provider route, and every main invocation starts a new observation.
-- Hands main.lua four private functions, in order: acquire a pass (starting a fresh observation), invalidate the
-- evaluation context, acquire a plan pass, and read the cleanup body. Each falls back to the public method when the
-- owner or coordinator is not the original. Returns true.
function addon:BindRuntimeEvaluationContext(bind)
    if self ~= addon or type(bind) ~= 'function' then return nil end

    bind(function(owner, spec)
        contextVersion = {}
        invalidateExecution()

        if
            owner ~= addon
            or owner.AcquireRotationRuntimePass ~= ownedAcquireRuntimePass
            or owner.GetScopedRotationCoordinator ~= ownedScopedCoordinator
            or not current
            or current.RuntimePass ~= ownedRuntimePasses[current]
        then
            return owner:AcquireRotationRuntimePass(spec)
        end

        local previous = evaluationRequest
        local request = {}
        evaluationRequest = request
        local ok, pass, reason = protect(ownedAcquireRuntimePass, owner, spec)
        evaluationRequest = previous
        if not ok then raise(pass, 0) end
        return pass, reason, request.pass == pass and request.publication or nil
    end, function()
        contextVersion = {}
        invalidateExecution()
    end, function(owner, spec)
        if
            owner ~= addon
            or rawget(owner, 'AcquireRotationRuntimePass') ~= ownedAcquireRuntimePass
            or storeGetfenv(ownedAcquireRuntimePass) ~= storeScopeEnvironment
            or rawget(owner, 'GetScopedRotationCoordinator') ~= ownedScopedCoordinator
            or not current
            or rawget(current, 'RuntimePass') ~= ownedRuntimePasses[current]
        then
            return owner:AcquireRotationRuntimePass(spec)
        end

        return current:RuntimePass(spec, privatePlanPass)
    end, function(owner, spec, key, capturedMethod)
        if
            owner ~= addon
            or capturedMethod ~= ownedGetCleanup
            or rawget(owner, 'GetRotationForCleanup') ~= ownedGetCleanup
            or storeGetfenv(ownedGetCleanup) ~= storeScopeEnvironment
            or rawget(owner, 'GetScopedRotationCoordinator') ~= ownedScopedCoordinator
            or not current
            or rawget(current, 'RuntimePass') ~= ownedRuntimePasses[current]
        then
            return capturedMethod(owner, spec, key)
        end

        return current:Cleanup(spec, key, privatePlanPass)
    end)

    return true
end

-- Inspection of another profile never switches the active database or grants
-- edit authority. Only detached saved headers for the current owner leave here.
-- Returns detached roster headers (all specializations) for the current owner's custom rotations in `profile`, or nil
-- and a reason. Opens a throwaway store reader over that profile and retires it before returning.
function addon:GetProfileRotationHeaders(profile)
    if not plain(profile) then return nil, 'invalid-profile' end
    if profile.rotationStore == nil then return nil, 'rotation-profile-recovery-required' end
    if not text(profile.rotationFallbackID, 128) then return nil, 'missing-fallback-configuration' end
    local c, why = self:GetRotationOwnerContext()
    if not c then return nil, why end
    local state, fallback = profile.rotationStore, profile.rotationFallbackID
    local reader

    local store, reason = data.NewRotationStore({
        state = state,
        fallbackID = fallback,
        validation = self:GetRotationValidationOptions(),
        bindInternalReader = function(value) reader = value end,
    })

    if not store then return nil, reason end

    -- Retires the temporary reader, then passes the result through.
    local function finish(value, problem)
        reader:Retire()
        return value, problem
    end

    local numbers = {}
    local class = state.classes[c.class]

    for number in pairs(class or {}) do
        numbers[number] = true
    end

    local character = c.character and state.characters[c.character]
    if character and character.class ~= c.class then return finish(nil, 'foreign-owner') end

    for number in pairs(character and character.specs or {}) do
        numbers[number] = true
    end

    local specs = {}

    for number in pairs(numbers) do
        specs[#specs + 1] = number
    end

    table.sort(specs)
    local result = {}

    for _, number in ipairs(specs) do
        local rows, problem = reader:ListOwned(number, c)
        if not rows then return finish(nil, problem) end

        for _, row in ipairs(rows) do
            if row.address.spec == number then
                local ok, view = reader:Read(row.address, c, function(record)
                    local body = record.body

                    local manifest = record.origin and record.origin.manifest
                        or record.imported and record.imported.manifest

                    local projection = {
                        body = {
                            name = type(body.name) == 'string' and body.name or nil,
                            description = type(body.description) == 'string' and body.description or nil,
                            tags = tagsView(body.tags),
                            metadata = metadataView(body.metadata),
                        },
                        tags = manifest and copy(manifest.tags),
                        sources = manifest and copy(manifest.sources),
                    }

                    return {
                        reference = { kind = 'custom', address = copy(row.address) },
                        canonicalId = row.address.id,
                        kind = 'custom',
                        scope = row.address.scope,
                        spec = number,
                        name = projection.body.name or L['Unnamed rotation'],
                        description = projection.body.description or '',
                        enabled = not body.disabled,
                        priority = data.GetRotationPriority(body.priority),
                        tags = data.GetRotationTags(projection) or {},
                        search = data.RotationSearchText(
                            projection,
                            projection.body.name or '',
                            projection.body.description or ''
                        ),
                        fallback = row.address.id == fallback,
                        readOnly = false,
                        pending = false,
                    }
                end)

                if not ok then return finish(nil, view) end
                result[#result + 1] = view
            end
        end
    end

    local now = self:GetRotationOwnerContext()

    if not now or not same(c, now) or profile.rotationStore ~= state or profile.rotationFallbackID ~= fallback then
        return finish(nil, 'rotation-profile-changed')
    end

    return finish(result)
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
    local bind = addon.BindCPUValidationScopeDiagnostic
    if type(bind) == 'function' then bind(addon, 'scope', addon.BindRotationProfile, function() return same end) end
end

-- END PRIVATE VALIDATION CPU HANDOFF

-- Cold-consumed by Core/active_runtime_plan, never a public body getter.
-- Hands Core/active_runtime_plan.lua the plan-source function and the active-runtime reader. The receiver gets nothing
-- for any other caller.
function addon:BindScopedActiveRuntimePlan(receiver)
    if self ~= addon or type(receiver) ~= 'function' then return end

    receiver(function(owner, spec, key)
        if owner ~= addon or not currentPlanSource then return end
        return currentPlanSource(spec, key)
    end, readActiveRuntime)
end
