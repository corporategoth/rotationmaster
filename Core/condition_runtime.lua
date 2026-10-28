-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Private executor for the condition trees of the active rotation body (lean engine): compiles a body's condition roots
-- into nodes, remembers results of stable (event-driven) conditions between polls and invalidates them on level and
-- aura events, and hands main.lua a per-poll session that proves the plan is still current. Owns the compiled plan, the
-- declarations of Built In conditions allowed on this path (enrolled by Conditions/*.lua through
-- addon:DeclareOwnedConditionRuntime) and the event frame; it never evaluates custom conditions (those stay on
-- Core/conditions.lua) and must retire the plan whenever any proof fails. Restricted and unproven clients never reuse a
-- fact across polls. Loaded from RotationMaster.toc after Core/condition_support.lua; it takes the engine's pieces once
-- through addon.ConsumeConditionRuntimeEngine and main.lua takes `prepare` through addon:ConsumeConditionRuntime.

local _, addon = ...

-- Private active-body executor. The active-plan owner supplies the content /
-- dependency lifetime; this module owns condition structure and observation
-- dependencies. Public/custom evaluation continues through Core/conditions.
---@type fun(owner:table):table,function,function,function,function,function
local consumeEngine = addon.ConsumeConditionRuntimeEngine
local definitions, runLeaf, outcome, engineCurrent, isQuarantined, quarantineVersion = consumeEngine(addon)

-- Without the engine handoff from Core/conditions.lua this module does nothing and the ordinary evaluator stays in use.
if not definitions then
    return
end

addon.ConsumeConditionRuntimeEngine = nil

local type, pairs, ipairs, getmetatable, pcall, setmetatable, rawget, next =
    type, pairs, ipairs, getmetatable, pcall, setmetatable, rawget, next

---@type fun(f:number|function):table
local getfenv = getfenv
local declarations, generation = {}, 0
local sourceWitnesses = {}

-- ============================================================================
-- Enrolling Built In conditions
-- ============================================================================

-- Opens the witness for one Built In source module as it loads.
-- @param module string  The module's file path.
-- @return function|nil  record(tag, definition), which stores each registered definition with its original `valid` and
--   `evaluate` and returns the definition, so DeclareOwnedConditionRuntime can later prove the definition was not
--   replaced; nil when the caller is not the addon or the module already has a witness.
--
-- Called once per Built In source module as it loads.
function addon:CreateConditionRuntimeWitness(module)
    if self ~= addon or sourceWitnesses[module] then
        return
    end

    local witnesses = {}
    sourceWitnesses[module] = witnesses

    return function(tag, definition)
        witnesses[tag] = {
            definition = definition,
            valid = rawget(definition, 'valid'),
            evaluate = rawget(definition, 'evaluate'),
        }

        return definition
    end
end

local ownedHelpers = {}

-- Records the original public helper under a name so a declaration can prove the helper is still the shipped one.
-- @param name string  The helper's method name on the addon.
-- @param method function  The original function.
--
-- The first declaration of a name wins; calls not made on the addon are ignored.
function addon:DeclareConditionRuntimeHelper(name, method)
    if self == addon and ownedHelpers[name] == nil and type(method) == 'function' then
        ownedHelpers[name] = method
    end
end

local stats = {
    compiles = 0,
    legacyFallback = 0,
    leafEvaluations = 0,
    validatorCalls = 0,
    stableHits = 0,
    eventInvalidations = 0,
}

local active, consumed, latestSession
local platform = addon.Platform
local clientInfo = platform.GetClientInfo
local environment = getfenv(1)

-- Builds the baseline later compared with the live values of named members.
-- @param object table|nil  The table that holds the members; a non-table gives an empty list.
-- @param names string[]|nil  The member names.
-- @param host boolean|nil  True when the object is the addon or the global environment (its metatable is not checked).
-- @return table[]  One { object, name, value, environment, isHost } per named member.
local function references(object, names, host)
    local result = {}

    if type(object) ~= 'table' then
        return result
    end

    for _, name in ipairs(names or {}) do
        local value = rawget(object, name)
        result[#result + 1] = { object, name, value, type(value) == 'function' and getfenv(value) or nil, host }
    end

    return result
end

-- Appends every element of a list to another.
-- @param to table  The list that grows.
-- @param from table  The list to copy from.
local function append(to, from)
    for _, value in ipairs(from) do
        to[#to + 1] = value
    end
end

-- Enrolled at the end of the packaged source module, after its definitions.
-- Enrollment is not inferred from customCode=false or a user supplied tag.
local enrolled = {}

-- Enrolls the Built In conditions of a module for the private executor.
-- @param module string  The module's file path.
-- @param descriptors table  One descriptor per condition tag (methods, namespaces, platform members, natives, `pure`,
--   `fact`).
--
-- Called at the end of a Built In condition module. A tag is enrolled only when its registered definition is the
-- untouched one recorded by the witness and matches the packaged source catalog; anything else keeps the ordinary
-- evaluation path. Advances the generation so plans compiled earlier are discarded. Enrollment is not inferred from
-- customCode=false or a user supplied tag; a module enrolls once.
function addon:DeclareOwnedConditionRuntime(module, descriptors)
    if self ~= addon or enrolled[module] then
        return
    end

    enrolled[module] = true

    for tag, descriptor in pairs(descriptors) do
        local record = addon.BuiltinSourceCatalog and addon.BuiltinSourceCatalog.conditions[tag]
        local definition = definitions[tag]
        local witness = sourceWitnesses[module] and sourceWitnesses[module][tag]

        if
            witness
            and witness.definition == definition
            and getmetatable(definition) == nil
            and rawget(definition, 'valid') == witness.valid
            and rawget(definition, 'evaluate') == witness.evaluate
            and record
            and record.module == module
            and definition
            and type(definition.valid) == 'function'
            and type(definition.evaluate) == 'function'
        then
            local refs = references(addon, descriptor.methods, true)

            for namespace, names in pairs(descriptor.namespaces or {}) do
                append(refs, references(rawget(environment, namespace), names))
            end

            local helpers = true

            for _, name in ipairs(descriptor.methods or {}) do
                if type(ownedHelpers[name]) ~= 'function' or ownedHelpers[name] ~= rawget(addon, name) then
                    helpers = false
                end
            end

            append(refs, references(addon.Platform, descriptor.platform))
            append(refs, references(environment, descriptor.native, true))

            declarations[tag] = {
                tag = tag,
                definition = definition,
                valid = definition.valid,
                evaluate = definition.evaluate,
                env = getfenv(definition.evaluate),
                validEnv = getfenv(definition.valid),
                pure = descriptor.pure == true,
                fact = descriptor.fact,
                helpers = helpers,
                refs = refs,
                units = addon.units,
                operators = addon.operators,
                platform = addon.Platform,
            }
        end
    end

    generation = generation + 1
end

-- ============================================================================
-- Plan lifetime and event subscription
-- ============================================================================

-- Forgets the cached player level so the next read observes it again.
local function clearLevel()
    local cache = addon.longtermCache

    if type(cache) == 'table' then
        cache.conditionPlayerLevel = nil
        local native = cache[UnitLevel]

        if type(native) == 'table' then
            native.player = nil
        end
    end
end

-- Clears the cached result of a node and of every ancestor that depended on it.
-- @param node table  The compiled node.
local function dirty(node)
    node.result = nil

    for _, parent in ipairs(node.parents) do
        dirty(parent)
    end
end

-- Marks every node that depends on a fact dirty and advances the plan epoch, which blocks a result computed during the
-- event from being cached.
-- @param plan table  The compiled plan.
-- @param fact string  'level' or 'aura'.
local function invalidate(plan, fact)
    plan.epoch = plan.epoch + 1
    stats.eventInvalidations = stats.eventInvalidations + 1

    for _, node in ipairs(plan.dependencies[fact] or {}) do
        dirty(node)
    end
end

-- Drops the active plan and session: marks the plan retired, clears the level cache and unregisters its event frame.
local function retire()
    local plan = active
    active = nil
    latestSession = nil

    if plan then
        plan.retired = true
        clearLevel()

        if plan.frame then
            plan.frame:UnregisterAllEvents()
            plan.frame:SetScript('OnEvent', nil)
        end
    end
end

local levelEvents = { 'PLAYER_LEVEL_UP', 'UNIT_LEVEL', 'PLAYER_ENTERING_WORLD', 'PLAYER_LEAVING_WORLD' }

local auraEvents = {
    'UNIT_AURA',
    'SPELLS_CHANGED',
    'SPELL_DATA_LOAD_RESULT',
    'PLAYER_ENTERING_WORLD',
    'PLAYER_LEAVING_WORLD',
}

-- Creates the event frame for the facts the plan depends on.
-- @param plan table  The compiled plan.
--
-- If the frame cannot be created or any event cannot be registered, that fact is marked unsupported and its nodes are
-- re-evaluated every poll.
local function subscribe(plan)
    local wanted = false

    for fact in pairs(plan.dependencies) do
        if plan.support[fact] then
            wanted = true
        end
    end

    -- Marks every fact as unsupported, so its nodes are evaluated fresh on each poll.
    local function unavailable()
        for fact in pairs(plan.support) do
            plan.support[fact] = false
        end
    end

    if not wanted then
        return
    end

    if type(CreateFrame) ~= 'function' then
        unavailable()
        return
    end

    local ok, frame = pcall(CreateFrame, 'Frame')

    if not ok or not frame then
        unavailable()
        return
    end

    if
        type(frame.RegisterEvent) ~= 'function'
        or type(frame.IsEventRegistered) ~= 'function'
        or type(frame.UnregisterAllEvents) ~= 'function'
        or type(frame.SetScript) ~= 'function'
    then
        unavailable()
        return
    end

    plan.frame = frame

    for fact, nodes in pairs(plan.dependencies) do
        if #nodes > 0 and plan.support[fact] then
            local supported = true

            for _, event in ipairs(fact == 'level' and levelEvents or auraEvents) do
                local registered = pcall(frame.RegisterEvent, frame, event)
                local checked, present = pcall(frame.IsEventRegistered, frame, event)

                if not registered or not checked or not present then
                    supported = false
                end
            end

            plan.support[fact] = plan.support[fact] and supported
        end
    end

    -- Event handler of the plan's frame: invalidates the level and aura facts when the matching game events arrive.
    -- @param _ any  The frame; unused.
    -- @param event string  The event name.
    -- @param unit string|nil  The unit of a unit event; events for other units than the player are ignored.
    --
    -- PLAYER_LEVEL_UP also schedules a deferred re-read, and the fact stays volatile until then.
    frame:SetScript('OnEvent', function(_, event, unit)
        if active ~= plan or plan.retired then
            return
        end

        if event == 'UNIT_LEVEL' or event == 'UNIT_AURA' then
            local ok, readable = pcall(platform.CanReadValue, platform, unit)

            if not ok or not readable or type(unit) ~= 'string' then
                if event == 'UNIT_LEVEL' then
                    clearLevel()
                    invalidate(plan, 'level')
                else
                    invalidate(plan, 'aura')
                end

                return
            end

            if unit ~= 'player' then
                return
            end
        end

        if
            event == 'UNIT_LEVEL'
            or event == 'PLAYER_LEVEL_UP'
            or event == 'PLAYER_ENTERING_WORLD'
            or event == 'PLAYER_LEAVING_WORLD'
        then
            clearLevel()
            invalidate(plan, 'level')
        end

        if
            event == 'UNIT_AURA'
            or event == 'SPELLS_CHANGED'
            or event == 'SPELL_DATA_LOAD_RESULT'
            or event == 'PLAYER_ENTERING_WORLD'
            or event == 'PLAYER_LEAVING_WORLD'
        then
            invalidate(plan, 'aura')
        end

        if event == 'PLAYER_LEVEL_UP' then
            plan.levelPending = true

            if type(addon.ScheduleTimer) == 'function' then
                addon:ScheduleTimer(function()
                    if active ~= plan or plan.retired then
                        return
                    end

                    clearLevel()
                    invalidate(plan, 'level')
                    plan.levelPending = false
                end, 0.01)
            end  -- Without a deferred boundary, remain volatile until retirement.
        end
    end)
end

-- Decides whether facts may be reused across polls.
-- @return boolean  True only on Classic Era, TBC and the progression clients with the secret value API either absent or
--   reporting no restrictions.
-- @return string|nil  The client family ('era', 'tbc' or 'progression') when the first return is true; nil otherwise.
--
-- Written to avoid the full client classifier, which allocates on every call. No cross-poll gameplay fact reuse on
-- restricted or unproven clients.
local function securityAllowsFacts()
    if addon.Platform ~= platform or platform.GetClientInfo ~= clientInfo then
        return false
    end

    -- The stock client classifier's policy depends on project identity. Avoid
    -- allocating its complete build/locale/season metadata each polling pass.
    local project = WOW_PROJECT_ID
    local readOk, readable = pcall(platform.CanReadValue, platform, project)

    if not readOk or not readable or type(project) ~= 'number' then
        return false
    end

    local family

    if project == WOW_PROJECT_MAINLINE or project == WOW_PROJECT_CAMELOT then
        return false
    elseif project == WOW_PROJECT_CLASSIC then
        family = 'era'
    elseif project == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
        family = 'tbc'
    elseif
        project == WOW_PROJECT_WRATH_CLASSIC
        or project == WOW_PROJECT_CATACLYSM_CLASSIC
        or project == WOW_PROJECT_MISTS_CLASSIC
    then
        family = 'progression'
    else
        return false
    end

    -- No cross-poll gameplay fact reuse on restricted or unproven clients.
    if type(issecretvalue) == 'function' or type(canaccessvalue) == 'function' or C_Secrets ~= nil then
        if type(C_Secrets) ~= 'table' or type(C_Secrets.HasSecretRestrictions) ~= 'function' then
            return false
        end

        local ok, restricted = pcall(C_Secrets.HasSecretRestrictions)

        if not ok then
            return false
        end

        local known, accessible = pcall(platform.CanReadValue, platform, restricted)

        if not known or not accessible or restricted ~= false then
            return false
        end
    end

    return true, family
end

-- Reports whether level facts and aura facts may be reused across polls.
-- @return boolean  True when level facts may be reused.
-- @return boolean  True when aura facts may be reused; Classic Era never reuses aura facts.
local function supportedFacts()
    local safe, family = securityAllowsFacts()
    return safe == true, safe == true and family ~= 'era'
end

-- Reports whether an enrolled declaration is still the original.
-- @param declaration table  The declaration recorded by DeclareOwnedConditionRuntime.
-- @return boolean  True while the enrolled definition, its callbacks and function environments, and every referenced
--   method are still the originals and the definition is not disabled or quarantined.
local function declarationCurrent(declaration)
    local d = declaration.definition

    if not declaration.helpers or definitions[declaration.tag] ~= d or getmetatable(d) ~= nil or isQuarantined(d) then
        return false
    end
    if
        d.disabled
        or d.functionUnavailable
        or d.valid ~= declaration.valid
        or d.evaluate ~= declaration.evaluate
        or getfenv(d.valid) ~= declaration.validEnv
        or getfenv(d.evaluate) ~= declaration.env
        or addon.Platform ~= declaration.platform
        or addon.units ~= declaration.units
        or addon.operators ~= declaration.operators
    then
        return false
    end

    for _, ref in ipairs(declaration.refs) do
        if
            not ref[5] and getmetatable(ref[1]) ~= nil
            or rawget(ref[1], ref[2]) ~= ref[3]
            or ref[4] and getfenv(ref[3]) ~= ref[4]
        then
            return false
        end
    end

    return true
end

-- Reports whether a plan is still authorized to run.
-- @param plan table  The compiled plan.
-- @return boolean  True while the engine, the generation and the quarantine version are unchanged and every declaration
--   the plan uses is still current.
local function authority(plan)
    if not engineCurrent() or plan.generation ~= generation or plan.quarantineVersion ~= quarantineVersion() then
        return false
    end

    for _, declaration in ipairs(plan.declarations) do
        if not declarationCurrent(declaration) then
            return false
        end
    end

    return true
end

-- ============================================================================
-- Compiling a plan
-- ============================================================================

local noProviders = {}

-- Builds a plan for a rotation body.
-- @param body table  The rotation body (rotation and cooldowns).
-- @param token any  The owner's token for the body; the plan is tied to it.
-- @param levelSafe boolean  Whether level facts may be reused across polls.
-- @param auraSafe boolean  Whether aura facts may be reused across polls.
-- @return table|nil  The plan; nil when anything is malformed, too large or deep, or not enrolled, so the body stays on
--   the ordinary path.
--
-- Walks the rotation and cooldown steps (including branches) and compiles each step's condition tree into nodes.
local function compile(body, token, levelSafe, auraSafe)
    local plan = {
        body = body,
        token = token,
        generation = generation,
        quarantineVersion = quarantineVersion(),
        roots = {},
        declarations = {},
        dependencies = {},
        support = { level = levelSafe, aura = auraSafe },
        epoch = 0,
    }

    local used = {}

    -- Compiles one condition tree into the plan.
    -- @param value table|nil  The condition root; nil counts as compiled.
    -- @return boolean  False if any node cannot be compiled.
    local function root(value)
        if value == nil then
            return true
        end
        if plan.roots[value] then
            return true
        end

        local stack, count = {}, 0

        -- Compiles one condition node (constant, AND/OR, NOT or a Built In leaf) with its parents, fact dependency and
        -- stability.
        -- @param value table  The condition node.
        -- @param parent table|nil  The parent compiled node.
        -- @param depth number  The nesting depth.
        -- @param path string  The node's path, used in outcomes.
        -- @return table|nil  The compiled node; nil for a malformed or oversize tree.
        local function node(value, parent, depth, path)
            count = count + 1

            if count > 4096 or depth > 64 or type(value) ~= 'table' or getmetatable(value) ~= nil or stack[value] then
                return
            end
            if value.disabled ~= nil and type(value.disabled) ~= 'boolean' then
                return
            end

            local n = {
                value = value,
                parents = parent and { parent } or {},
                path = path,
                stable = true,
                providers = noProviders,
            }

            if value.disabled or next(value) == nil then
                n.kind = 'constant'
                return n
            end

            local kind = value.type

            if type(kind) ~= 'string' then
                return
            end

            n.kind = kind
            stack[value] = true

            if kind == 'AND' or kind == 'OR' then
                local children = value.value

                if children == nil then
                    children = {}
                end

                if type(children) ~= 'table' or getmetatable(children) ~= nil then
                    return
                end

                local length, largest = 0, 0

                for key in pairs(children) do
                    if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 then
                        return
                    end

                    length = length + 1

                    if key > largest then
                        largest = key
                    end
                end

                if length ~= largest or length > 4096 - count then
                    return
                end

                n.children = {}

                for i = 1, length do
                    local child = node(children[i], n, depth + 1, path .. '.value[' .. i .. ']')

                    if not child then
                        return
                    end

                    n.children[i] = child
                    n.stable = n.stable and child.stable
                end
            elseif kind == 'NOT' then
                local child = node(value.value, n, depth + 1, path .. '.value')

                if not child then
                    return
                end

                n.children = { child }
                n.stable = child.stable
            else
                local declaration = declarations[kind]

                if not declaration or not declarationCurrent(declaration) then
                    return
                end

                n.definition = declaration.definition
                n.providers = { declaration }

                if not used[declaration] then
                    used[declaration] = true
                    plan.declarations[#plan.declarations + 1] = declaration
                end

                if declaration.pure then
                    n.validation = {}
                end

                local fact = declaration.fact

                if fact == 'level' and (value.unit ~= 'player' or value.relative) then
                    fact = nil
                end
                if fact == 'aura' and value.unit ~= 'player' then
                    fact = nil
                end

                n.fact = fact
                n.stable = fact ~= nil and plan.support[fact] == true

                if fact then
                    plan.dependencies[fact] = plan.dependencies[fact] or {}
                    plan.dependencies[fact][#plan.dependencies[fact] + 1] = n
                end
            end

            stack[value] = nil
            return n
        end

        local compiled = node(value, nil, 0, 'condition')

        if not compiled then
            return false
        end

        plan.roots[value] = compiled
        return true
    end

    local seen = {}

    -- Compiles the conditions of a step list and, recursively, of every branch in it.
    -- @param list table  The step list.
    -- @param depth number  The nesting depth.
    -- @return boolean  False if any step cannot be compiled.
    local function steps(list, depth)
        if type(list) ~= 'table' or depth > 64 or seen[list] then
            return false
        end

        seen[list] = true

        for _, step in ipairs(list) do
            if type(step) ~= 'table' or not root(step.conditions) then
                return false
            end
            if
                step.type == 'branch'
                and (not steps(step.onTrue or {}, depth + 1) or not steps(step.onFalse or {}, depth + 1))
            then
                return false
            end
        end

        seen[list] = nil
        return true
    end

    if type(body) ~= 'table' or not steps(body.rotation or {}, 0) or not steps(body.cooldowns or {}, 0) then
        return
    end

    return plan
end

-- ============================================================================
-- Evaluating nodes
-- ============================================================================

-- Reports whether the providers a node's cached result depends on are still current.
-- @param node table  The compiled node.
-- @param session table  The poll session.
-- @return boolean  True while the session and every consulted provider are current.
--
-- Certificates describe only providers consulted for the cached result. In particular an OR prefix never certifies an
-- unreached sibling's producer.
local function providersCurrent(node, session)
    if not session:IsCurrent() or not engineCurrent() then
        return false
    end

    for _, declaration in ipairs(node.providers) do
        if not declarationCurrent(declaration) then
            return false
        end
    end

    if session.dispatchGuard and not session:CheckDispatch('condition') then
        return false
    end

    return session:IsCurrent()
end

-- Appends the declarations from a source list that the target does not yet hold.
-- @param target table  The list that grows.
-- @param seen table  A set of declarations already in the target.
-- @param source table  The declarations to add.
local function addProviders(target, seen, source)
    for _, declaration in ipairs(source) do
        if not seen[declaration] then
            seen[declaration] = true
            target[#target + 1] = declaration
        end
    end
end

-- Evaluates a node.
-- @param node table  The compiled node.
-- @param plan table  The compiled plan.
-- @param cache table  The per-evaluation cache.
-- @param start number  The poll's start time.
-- @param context table|nil  The evaluation context.
-- @param session table  The poll session.
-- @return table  An outcome { status = 'match' | 'no-match' | 'unavailable', reason, path }.
--
-- A stable node reuses its cached result only while its providers are still current; AND and OR stop at the first
-- deciding child, and only the providers actually consulted are certified.
local function evaluate(node, plan, cache, start, context, session)
    if node.stable and node.result and not (node.fact == 'level' and plan.levelPending) then
        if not providersCurrent(node, session) then
            return outcome('unavailable', 'condition-source-changed', node.path)
        end

        stats.stableHits = stats.stableHits + 1
        return node.result
    end

    local epoch = plan.epoch
    local result, consulted, seen

    if node.stable and (node.kind == 'AND' or node.kind == 'OR') then
        consulted, seen = {}, {}
    end

    if node.kind == 'constant' then
        result = outcome('match')
    elseif node.kind == 'AND' or node.kind == 'OR' then
        local matched = node.kind == 'AND'

        for _, child in ipairs(node.children) do
            local current = evaluate(child, plan, cache, start, context, session)

            if consulted then
                addProviders(consulted, seen, child.providers)
            end

            if current.status == 'unavailable' then
                result = current
                break
            end

            if node.kind == 'AND' and current.status == 'no-match' then
                matched = false
                break
            end

            if node.kind == 'OR' and current.status == 'match' then
                matched = true
                break
            end
        end

        result = result or outcome(matched and 'match' or 'no-match')
    elseif node.kind == 'NOT' then
        result = evaluate(node.children[1], plan, cache, start, context, session)

        if node.stable then
            consulted = node.children[1].providers
        end
        if result.status ~= 'unavailable' then
            result = outcome(result.status == 'match' and 'no-match' or 'match')
        end
    else
        result = runLeaf(
            node.value,
            node.definition,
            cache,
            start,
            node.path,
            context,
            node.validation,
            session.current,
            stats,
            providersCurrent,
            node,
            session,
            session.CheckResume
        )
    end

    if node.stable and result.status ~= 'unavailable' and epoch == plan.epoch and not plan.levelPending then
        if consulted then
            node.providers = consulted
        end

        -- A provider callback may have replaced its own method while returning.
        -- Never promote that old producer to a reusable fact certificate.
        if providersCurrent(node, session) then
            node.result = result
        end
    end

    return result
end

-- ============================================================================
-- Sessions
-- ============================================================================

local Session = {}
local sessionMeta = { __index = Session }

-- Reports whether this session is still the active one and the owner's lease still holds.
-- @return boolean  True while it is current.
function Session:IsCurrent()
    return not self.failed
        and active == self.plan
        and not self.plan.retired
        and self.plan.quarantineVersion == quarantineVersion()
        and self.current()
end

-- Runs the owner's full proof; a failure marks the session failed for the rest of the poll.
-- @return boolean  True when the proof holds.
function Session:CheckFull()
    if not self:IsCurrent() then
        return false
    end

    if not self.fullCurrent() or not self:IsCurrent() then
        self.failed = true
        return false
    end

    return true
end

-- Runs the optional managed dispatch guard; a failure marks the session failed.
-- @param kind string  The kind of dispatch being certified (for example 'condition' or 'resume').
-- @return boolean  True when the guard accepts.
--
-- Optional managed dispatch certifies only this actual input consumer. The five-argument path keeps its original full
-- postcallback proof unchanged.
function Session:CheckDispatch(kind)
    if not self:IsCurrent() then
        return false
    end

    if not self.dispatchGuard(kind) or not self:IsCurrent() then
        self.failed = true
        return false
    end

    return true
end

-- Asks for proof before continuing after an outside callback: the dispatch guard when the owner gave one, else the full
-- proof.
-- @return boolean  True when the proof holds.
function Session:CheckResume()
    if self.dispatchGuard then
        return self:CheckDispatch('resume')
    end

    return self:CheckFull()
end

-- Evaluates one condition root inside the session.
-- @param session table  The poll session.
-- @param root table|nil  The condition root; nil matches.
-- @param context table|nil  The evaluation context.
-- @return table  An outcome { status, reason, path }; 'unavailable' if the session is no longer current before or after
--   the evaluation.
local function rootResult(session, root, context)
    local plan = session.plan

    if not session:IsCurrent() then
        return outcome('unavailable', 'condition-owner-changed', 'condition')
    end

    local node = root ~= nil and plan.roots[root]

    if root ~= nil and not node then
        return outcome('unavailable', 'condition-root-not-in-plan', 'condition')
    end

    local result = node and evaluate(node, plan, {}, GetTime(), context, session) or outcome('match')

    if not session:IsCurrent() then
        return outcome('unavailable', 'condition-owner-changed', 'condition')
    end

    return result
end

-- Evaluates a condition root.
-- @param root table|nil  The condition root; nil matches.
-- @param context table|nil  The evaluation context.
-- @return table  A fresh { status, reason, path }.
function Session:EvaluateResult(root, context)
    local result = rootResult(self, root, context)
    -- Public-shaped results never expose memoized internal outcomes.
    return { status = result.status, reason = result.reason, path = result.path }
end

-- Evaluates a condition root and reports only whether it matched.
-- @param root table|nil  The condition root; nil matches.
-- @param context table|nil  The evaluation context.
-- @return boolean  True only for a match.
function Session:EvaluateBool(root, context)
    return rootResult(self, root, context).status == 'match'
end

-- Proves the plan is still current after an opaque outer callback.
-- @return boolean  True when the session and plan are still current; false (and the plan retired when its authority
--   failed) otherwise.
--
-- Only genuinely opaque outer callbacks use this fence. Source-owned leaf observations and unchanged primitive-only
-- publication preserve event facts. A stale continuation cannot retire a newer activation or nested invocation.
function Session:AfterOpaque()
    if not self:IsCurrent() then
        return false
    end
    if not self.dispatchGuard and not self:CheckFull() then
        return false
    end

    local plan = self.plan

    if not authority(plan) then
        if active == plan then
            retire()
        end

        return false
    end

    if self.dispatchGuard and not self:CheckResume() then
        return false
    end

    return self:IsCurrent()
end

-- ============================================================================
-- Preparing a poll
-- ============================================================================

-- Gives main.lua a session for one poll.
-- @param owner table  The addon; anything else is refused.
-- @param body table  The active rotation body.
-- @param token any  The owner's token for the body; nil counts as a legacy fallback.
-- @param leaseCurrent function  leaseCurrent() says whether the owner's lease still holds.
-- @param fullCurrent function|nil  The owner's full proof; defaults to leaseCurrent.
-- @param dispatchGuard function|nil  The managed dispatch guard, dispatchGuard(kind).
-- @return table|nil  The session when the body can run from a compiled plan; nil otherwise (counted as a legacy
--   fallback when the engine itself is unusable).
--
-- Called by main.lua each poll with the active body and the owner's leases. Recompiles when the body, token or fact
-- support changed and retires the plan whenever a proof fails.
local function prepare(owner, body, token, leaseCurrent, fullCurrent, dispatchGuard)
    if owner ~= addon then
        return
    end

    if token == nil or type(leaseCurrent) ~= 'function' then
        stats.legacyFallback = stats.legacyFallback + 1
        retire()
        return
    end

    if not leaseCurrent() then
        return
    end

    if addon.enabledState == false then
        retire()
        return
    end

    if not engineCurrent() then
        stats.legacyFallback = stats.legacyFallback + 1
        retire()
        return
    end

    local levelSafe, auraSafe = supportedFacts()

    -- Capability providers may invoke reentrant addon work. Never retire the
    -- newer graph from the superseded acquisition.
    if not leaseCurrent() then
        return
    end

    local plan = active

    if
        plan and (plan.token ~= token or plan.body ~= body or plan.levelSafe ~= levelSafe or plan.auraSafe ~= auraSafe)
    then
        retire()
        plan = nil
    end

    if not plan then
        plan = compile(body, token, levelSafe, auraSafe)

        if not plan then
            stats.legacyFallback = stats.legacyFallback + 1
            return
        end

        stats.compiles = stats.compiles + 1
        plan.levelSafe, plan.auraSafe = levelSafe, auraSafe
        active = plan
        subscribe(plan)

        if active ~= plan or not leaseCurrent() then
            if plan.frame then
                plan.frame:UnregisterAllEvents()
                plan.frame:SetScript('OnEvent', nil)
            end

            if active == plan then
                retire()
            end

            return
        end

        -- Applies event-registration failures to a node: a fact provider that failed makes its nodes volatile.
        -- @param node table  The compiled node.
        -- @return boolean  True when the node is stable.
        --
        -- Event registration failure affects only that fact provider.
        local function supported(node)
            if node.fact then
                node.stable = plan.support[node.fact] == true
            elseif node.children then
                node.stable = true

                for _, child in ipairs(node.children) do
                    node.stable = supported(child) and node.stable
                end
            end

            return node.stable
        end

        for _, node in pairs(plan.roots) do
            supported(node)
        end
    end

    if not leaseCurrent() then
        return
    end

    if not authority(plan) then
        stats.legacyFallback = stats.legacyFallback + 1

        if active == plan then
            retire()
        end

        return
    end

    local guard = fullCurrent or leaseCurrent
    local previous = latestSession
    local accepted

    if type(dispatchGuard) == 'function' then
        accepted = dispatchGuard('resume')
    else
        accepted = guard()
    end

    if not accepted then
        if leaseCurrent() and active == plan and latestSession == previous then
            retire()
        end

        return
    end

    if not leaseCurrent() then
        return
    end

    local session = setmetatable({
        plan = plan,
        current = leaseCurrent,
        fullCurrent = guard,
        dispatchGuard = type(dispatchGuard) == 'function' and dispatchGuard or nil,
    }, sessionMeta)

    latestSession = session
    return session
end

-- Hands main.lua the executor's three entry points, once.
-- @return function|nil  `prepare`; nil on a repeated call or when not called on the addon.
-- @return function|nil  retire(owner, priorSession), which ends the active plan only when the caller's prior session is
--   still the latest one and returns whether it is retired.
-- @return function|nil  afterOpaque(owner, session), the after-opaque-callback proof for a session.
--
-- One-time handoff to main.lua (a second call gets nothing).
function addon:ConsumeConditionRuntime()
    if self ~= addon or consumed then
        return
    end

    consumed = true

    return prepare,
        function(owner, priorSession)
            if owner ~= addon then
                return false
            end
            if active == nil and latestSession == nil then
                return true
            end
            if
                priorSession ~= nil
                and (priorSession == false and latestSession ~= nil
                    or priorSession ~= false and latestSession ~= priorSession)
            then
                return false
            end

            retire()
            return true
        end,
        function(owner, session)
            if owner ~= addon or type(session) ~= 'table' then
                return false
            end

            return session:AfterOpaque()
        end
end

-- Returns the executor's counters for a CPU capture.
-- @return table  { compiles, legacyFallback, leafEvaluations, validatorCalls, stableHits, eventInvalidations, active }.
--
-- Capture-boundary diagnostics expose counts only, never condition data.
function addon:GetConditionRuntimeDiagnostic()
    return {
        compiles = stats.compiles,
        legacyFallback = stats.legacyFallback,
        leafEvaluations = stats.leafEvaluations,
        validatorCalls = stats.validatorCalls,
        stableHits = stats.stableHits,
        eventInvalidations = stats.eventInvalidations,
        active = active ~= nil,
    }
end
