-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The Built In rotation library: registration of the packaged rotations and their reusable step blocks, the per-profile
-- catalog built from them, eligibility for the player's client, class and context, and the runtime lookups that hand
-- rotations to the poll. It also owns clone, duplicate, compare and delete for rotations, and the narrow reader handed
-- once to Core/rotation_scope.lua. It must not draw, and it reads game facts only through addon.Platform and
-- CanReadValue. Loaded from RotationMaster.toc after Core/rotation_choice_preferences.lua; the load-on-demand class
-- modules register into it through Core/builtin_modules.lua. Saved data: profile.rotationLibrary (preferences, origins,
-- comparisons, imports). Docs: docs/architecture/storage-scopes.md and runtime-revisions.md.

local addon_name, addon = ...

-- ============================================================================
-- Handoffs and shared state
-- ============================================================================

-- The execution generation reader and advancer, handed to this file once by Core/dependency_revisions.lua through
-- addon:BindRotationExecutionGeneration.
local readExecutionGeneration, advanceExecutionGeneration
---@type fun(...): any
local bindExecutionGeneration = addon.BindRotationExecutionGeneration

if type(bindExecutionGeneration) == 'function' then
    bindExecutionGeneration(addon, function(read, advance)
        readExecutionGeneration, advanceExecutionGeneration = read, advance
    end)
end

-- Advances the execution generation so the lean evaluation plan and the other generation-keyed caches see that library
-- data changed. Does nothing until the generation has been bound.
local function invalidateExecution()
    if advanceExecutionGeneration then
        advanceExecutionGeneration()
    end
end

-- Entry points of earlier files captured at load: the choice-context invalidator, the rotation data module, and the
-- active-rotation transition guards (Core/rotation_active.lua).
local invalidateChoiceContext = addon.InvalidateRotationChoiceContext
local data = addon.RotationData
local activeCurrent = addon.IsActiveRotationTransitionCurrent
local beginActive = addon.BeginActiveRotationTransition
local retireActive = addon.RetireActiveRotationTransition
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
-- The registered Built In envelopes by id, and a counter that is bumped on every registration so caches can tell the
-- set changed.
local definitions, definitionVersion = {}, 0

-- ============================================================================
-- Display names
-- ============================================================================

-- A Built In names itself by a locale key (nameKey, "Default.<Edition>.<Class>.<Variant>.Name"), never by text, and
-- an export carries that key beside the body. The key must never be shown as a name. The locale table is read
-- with rawget: AceLocale reports a missing key to the error handler, and a user's own rotation name is not a key.
-- Only a Default.*.Name key that the locale registers is resolved; anything else a user typed stays as typed.
local BUILTIN_NAME_KEY = "^Default%.[%w%.]+%.Name$"

-- Returns the translated text for a Built In locale key, or nil when the value is not such a key or the locale has no
-- text for it.
local function registeredBuiltinName(key)
    if type(key) ~= "string" or not key:find(BUILTIN_NAME_KEY) then
        return nil
    end

    local text = rawget(L, key)

    if type(text) == "string" and text ~= "" and text ~= key then
        return text
    end
end

-- "Default.Era.Druid.Feral.WarcraftTavern.Name" with no translation (a Built In from another version): the
-- variant after the edition and the class, split at its capitals: "Feral Warcraft Tavern".
local function readableBuiltinKey(key)
    local parts = {}

    for part in key:gsub("^Default%.", ""):gsub("%.Name$", ""):gmatch("[^%.]+") do
        parts[#parts + 1] = part
    end

    if #parts >= 3 then
        table.remove(parts, 1)
        table.remove(parts, 1)
    end

    local words = {}

    for _, part in ipairs(parts) do
        words[#words + 1] = part:gsub("(%l)(%u)", "%1 %2")
    end

    return table.concat(words, " ")
end

---The name to show for a rotation, in the client's language. Takes a name (string), or an envelope, body or
---legacy export (table). A body.name wins; an envelope's nameKey stands in for a name only when there is none.
---@param rotation string|table|nil
---@return string|nil
function addon:RotationDisplayName(rotation)
    if type(rotation) == "string" then
        return registeredBuiltinName(rotation) or rotation
    end
    if type(rotation) ~= "table" then
        return nil
    end

    local body = type(rotation.body) == "table" and rotation.body or rotation
    local name = body.name

    if type(name) == "string" and name ~= "" then
        return registeredBuiltinName(name) or name
    end

    local key = rotation.nameKey

    if type(key) ~= "string" or key == "" then
        key = rotation.name
    end

    if type(key) ~= "string" or key == "" then
        return nil
    end

    return registeredBuiltinName(key) or key:find(BUILTIN_NAME_KEY) and readableBuiltinKey(key) or key
end

-- The built library for the current profile (catalog, views, runtime bodies, clone scopes and generation), or nil until
-- InitializeRotationLibrary succeeds. The locals below receive the validation-proof helpers that
-- Core/rotation_references.lua hands over once through addon:BindRotationValidationReader, which is then retired.
local active
local readValidationStamp, checkValidationLayout, validationRawget, validationRawequal, validationType, validationGetmetatable
local runtimeAuthority, ownedOptions, ownedDisabledDependency
local bindValidation = addon.BindRotationValidationReader

if type(bindValidation) == 'function' then
    bindValidation(addon, function(read, check, raw, identity, kind, meta, authority, options, disabled)
        if
            type(read) == 'function'
            and type(check) == 'function'
            and type(raw) == 'function'
            and type(identity) == 'function'
            and type(kind) == 'function'
            and type(meta) == 'function'
        then
            readValidationStamp, checkValidationLayout, validationRawget, validationRawequal, validationType, validationGetmetatable =
                read, check, raw, identity, kind, meta

            runtimeAuthority, ownedOptions, ownedDisabledDependency = authority, options, disabled
        end
    end)

    addon.BindRotationValidationReader = nil
end

-- ============================================================================
-- Eligibility
-- ============================================================================

-- True for a table with no metatable, judged with the captured type and metatable readers so a later replacement of the
-- globals cannot change the answer.
local function validationPlain(value)
    return validationType(value) == 'table' and validationGetmetatable(value) == nil
end

-- True when the list holds the value; a nil list holds nothing.
local function contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end

    return false
end

-- True when the rotation is not scoped to a class, or is scoped to the player's class.
local function matchesClass(view, context)
    local scope = view.applicability
    return not scope or not scope.class or scope.class == context.class
end

-- Shipped premades keep only load-time facts in applicability. A rotation's
-- specializations are its own property, body.specs (absent or empty: any),
-- because a respec changes the choice without a reload; level lives in the
-- switch condition. The switch condition is never read to decide whether a
-- rotation is listed or can be chosen by hand: it only drives automatic
-- switching. specValue is the character's specialization value for the
-- context's namespace (Platform/specializations.lua GetRotationSpecKind).
local function specValue(context)
    local platform = addon.Platform

    if type(platform) ~= 'table' or type(platform.GetRotationSpecKind) ~= 'function' then
        return nil, false
    end
    if not platform:GetRotationSpecKind() then
        return nil, false
    end
    if context.specValue ~= nil then
        return context.specValue, true
    end

    local spec = context.spec

    if spec ~= nil and platform:RotationKeyIsSpecValue() then
        return spec, true
    end

    -- Another namespace than the one being played has no known value here.
    if spec == nil or addon.currentSpec ~= nil and spec ~= addon.currentSpec then
        return nil, true
    end

    local value

    if type(addon.GetRotationSpecValue) == 'function' then
        value = addon:GetRotationSpecValue()
    else
        value = platform:GetRotationSpecValue()
    end

    return value, true
end

-- Returns the specialization list a rotation declares (the envelope body's specs, else the view's), or nil when it
-- declares none.
local function bodySpecs(view)
    local envelope = view.envelope
    local body = type(envelope) == "table" and envelope.body

    if type(body) == "table" then
        return body.specs
    end

    return view.specs
end

-- Exposed for the runtime pass (custom bodies) and the editor list.
function addon:RotationSpecsApply(specs, spec)
    if type(specs) ~= "table" or #specs == 0 then
        return true
    end

    local value, known = specValue({ spec = spec })

    if not known then
        return true
    end

    return data.RotationSpecsMatch(specs, value)
end

-- Decides whether a rotation view may run in a context. Returns true, or false and a reason code
-- (invalid-or-unsupported, disabled, class-mismatch, edition-mismatch, specialization-mismatch,
-- action-context-mismatch, level, build or expansion mismatch, ruleset-mismatch, unsupported-context-selector). With
-- candidates set it stops after the class check, so identities survive level and context changes. Reasons are ordered:
-- validity first, so an unusable definition is never reported as disabled.
local function eligible(view, context, candidates)
    -- Validity first: a definition that cannot run here is not "disabled".
    if not view.validation.valid or not view.validation.supported or not view.validation.resolved then
        return false, "invalid-or-unsupported"
    end
    if not view.enabled then
        return false, "disabled"
    end
    if not matchesClass(view, context) then
        return false, "class-mismatch"
    end
    if candidates then
        return true
    end

    local scope = view.applicability

    if not scope or not contains(scope.families, context.family) then
        return false, "edition-mismatch"
    end
    if scope.specs and not contains(scope.specs, context.spec) then
        return false, "specialization-mismatch"
    end

    local specs = bodySpecs(view)

    if type(specs) == "table" and #specs > 0 then
        local value, known = specValue(context)

        if known and not data.RotationSpecsMatch(specs, value) then
            return false, "specialization-mismatch"
        end
    end

    if scope.actionContext ~= context.actionContext then
        return false, "action-context-mismatch"
    end

    for _, range in ipairs({ { "minLevel", "maxLevel", "level" }, { "minBuild", "maxBuild", "build" } }) do
        local value = context[range[3]]

        if scope[range[1]] or scope[range[2]] then
            if type(value) ~= "number" then
                return false, "missing-" .. range[3]
            end
            if scope[range[1]] and value < scope[range[1]] or scope[range[2]] and value > scope[range[2]] then
                return false, range[3] .. "-mismatch"
            end
        end
    end

    -- The client's expansion (LE_EXPANSION_LEVEL_CURRENT). Build numbers are
    -- shared across Blizzard products, so only this separates MoP from Wrath.
    local minExpansion, maxExpansion = scope.minExpansion, scope.maxExpansion

    if minExpansion or maxExpansion then
        local value = context.expansion

        if type(value) ~= "number" then
            return false, "missing-expansion"
        end
        if minExpansion and value < minExpansion or maxExpansion and value > maxExpansion then
            return false, "expansion-mismatch"
        end
    end

    -- These selectors need dedicated context providers before execution is safe.
    -- Keep their definitions visible for reference rather than assuming a match.
    if scope.intent or scope.roles then
        return false, "unsupported-context-selector"
    end

    -- Rulesets (season, hardcore, self-found, standard) come from the cached
    -- build context; any listed ruleset that is active matches.
    if scope.rulesets then
        local provider = addon.GetBuildRulesets
        local active = type(provider) == "function" and provider(addon) or nil

        if type(active) ~= "table" then
            return false, "unsupported-context-selector"
        end

        local matched = false

        for _, ruleset in ipairs(scope.rulesets) do
            if active[ruleset] then
                matched = true
                break
            end
        end

        if not matched then
            return false, "ruleset-mismatch"
        end
    end

    -- Restricted clients (Retail, Forever) run complete rotations like any
    -- other; a condition that cannot work here leaves the body unresolved.
    return true
end

-- True for a table with no metatable.
local function plainTable(value)
    return type(value) == "table" and getmetatable(value) == nil
end

-- True when the body opts in to being run on a bar other than the player's own, through
-- addon.RotationData.MatchesBareActionContext.
local function bareContextOptIn(body, context)
    local matches = data and data.MatchesBareActionContext
    return type(matches) == "function" and matches(body, context) == true
end

-- ============================================================================
-- Built In composition (blocks)
-- ============================================================================

-- Built In composition: authoring-time reuse of named step blocks by packaged
-- definitions only. Expansion runs once, here at registration; the catalog,
-- editor, clone, export and runtime only ever see the expanded independent
-- tree. A user can neither see nor author a reference. See Modules/README.md.
local blocks, compositions = {}, {}
local blockFields = { id = true, revision = true, families = true, class = true, steps = true, overrides = true }
local overrideFields = { families = true, specs = true, steps = true }
local referenceFields = { id = true, type = true, block = true, prefix = true }

-- True for a legal block or step identifier: a short string of letters, digits and . _ : - starting with a letter or
-- digit.
local function blockName(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and value:match("^[%w][%w._:%-]*$") ~= nil
end

-- True for a plain gap-free array.
local function denseList(value)
    if not plainTable(value) then
        return false
    end

    local count = 0

    for _ in pairs(value) do
        count = count + 1
    end

    return count == #value
end

-- Turns a gap-free list of distinct names (or of distinct non-negative whole numbers when integers is set) into a set,
-- or returns nil when it is empty, malformed or has a repeat.
local function stringSet(value, integers)
    if not denseList(value) or #value == 0 then
        return nil
    end

    local set = {}

    for _, entry in ipairs(value) do
        if
            integers and not (type(entry) == "number" and entry >= 0 and entry % 1 == 0)
            or not integers and not blockName(entry)
            or set[entry]
        then
            return nil
        end

        set[entry] = true
    end

    return set
end

-- 'all' when every consumer value is selected, 'none' when none is, else
-- 'some'. A nil consumer list means every value (e.g. no declared specs).
local function coverage(consumer, selector)
    if selector == nil then
        return "all"
    end
    if consumer == nil then
        return "some"
    end

    local hits = 0

    for _, value in ipairs(consumer) do
        if selector[value] then
            hits = hits + 1
        end
    end

    return hits == #consumer and "all" or hits == 0 and "none" or "some"
end

-- Formats a composition problem record (code, path, optional via and detail) as one line for the registration result.
local function message(problem)
    return problem.code
        .. " at "
        .. problem.path
        .. (problem.via and " (via " .. problem.via .. ")" or "")
        .. (problem.detail and ": " .. problem.detail or "")
end

-- Block-local IDs are unique per variant; references keep only their fields.
local function checkBlockSteps(list, path, ids)
    if not denseList(list) then
        return { code = "invalid-block-steps", path = path }
    end

    for index, step in ipairs(list) do
        local at = path .. "[" .. index .. "]"

        if not plainTable(step) then
            return { code = "invalid-block-step", path = at }
        end
        if not blockName(step.id) then
            return { code = "invalid-block-step-id", path = at .. ".id" }
        end
        if ids[step.id] then
            return { code = "duplicate-block-step-id", path = at .. ".id", detail = step.id }
        end

        ids[step.id] = true

        if step.type == "block" then
            for key in pairs(step) do
                if not referenceFields[key] then
                    return { code = "invalid-block-reference", path = at .. "." .. tostring(key) }
                end
            end

            if not blockName(step.block) or step.prefix ~= nil and not blockName(step.prefix) then
                return { code = "invalid-block-reference", path = at }
            end
        elseif step.type == "branch" then
            for _, arm in ipairs({ "onTrue", "onFalse" }) do
                if step[arm] ~= nil then
                    local problem = checkBlockSteps(step[arm], at .. "." .. arm, ids)

                    if problem then
                        return problem
                    end
                end
            end
        end
    end
end

-- Only this character's packs are kept: other editions and other classes can
-- never apply to it, and registering them would hold every premade in memory
-- on every client. Their files still load; what they build is garbage. Offline
-- tools and cross-edition/cross-class tests set loadAllDefaults.
-- A pack scoped to other expansions (minExpansion/maxExpansion) is skipped
-- too: a Mists pack never registers on a Wrath progression client. Only a
-- readable client expansion outside the declared range filters; anything
-- unprovable registers, and eligibility refuses it later.
local function notForThisCharacter(families, class, minExpansion, maxExpansion)
    if addon.loadAllDefaults then
        return false
    end

    local platform = addon.Platform
    local family = platform and type(platform.GetClientFamily) == "function" and platform:GetClientFamily()

    if type(family) == "string" and type(families) == "table" then
        local listed = false

        for _, value in ipairs(families) do
            if value == family then
                listed = true
                break
            end
        end

        if not listed then
            return true
        end
    end

    if
        (type(minExpansion) == "number" or type(maxExpansion) == "number")
        and platform
        and type(platform.GetClientInfo) == "function"
    then
        local ok, info = pcall(platform.GetClientInfo, platform)
        local expansion = ok and type(info) == "table" and info.expansion or nil

        if
            platform:CanReadValue(expansion)
            and (not canaccessvalue or canaccessvalue(expansion))
            and type(expansion) == "number"
            and (type(minExpansion) == "number" and expansion < minExpansion
                or type(maxExpansion) == "number" and expansion > maxExpansion)
        then
            return true
        end
    end

    if type(class) == "string" and type(UnitClass) == "function" then
        local ok, _, token = pcall(UnitClass, "player")

        if
            ok
            and platform
            and platform:CanReadValue(token)
            and (not canaccessvalue or canaccessvalue(token))
            and type(token) == "string"
            and token ~= class
        then
            return true
        end
    end

    return false
end

-- Registers a reusable named block of steps shared by packs of one edition or class. Returns true, or false and a
-- one-line problem. A block for another character's edition or class is accepted and dropped (true, "other-character").
-- The block is validated field by field, copied, and rejected when its id is already registered.
function addon:RegisterDefaultBlock(block)
    if not plainTable(block) then
        return false, "invalid-block"
    end
    if notForThisCharacter(block.families, block.class) then
        return true, "other-character"
    end

    for key in pairs(block) do
        if not blockFields[key] then
            return false, message({
                code = "unknown-block-field",
                path = (blockName(block.id) and block.id or "$") .. "." .. tostring(key),
            })
        end
    end

    if not blockName(block.id) then
        return false, message({ code = "invalid-block-id", path = "$.id" })
    end

    local where = block.id

    if not (type(block.revision) == "number" and block.revision >= 1 and block.revision % 1 == 0) then
        return false, message({ code = "invalid-block-revision", path = where .. ".revision" })
    end

    local families = stringSet(block.families)

    if not families then
        return false, message({ code = "invalid-block-families", path = where .. ".families" })
    end
    if block.class ~= nil and not data.IsRotationClassToken(block.class) then
        return false, message({ code = "invalid-block-class", path = where .. ".class" })
    end

    local problem = checkBlockSteps(block.steps, where .. ".steps", {})

    if not problem and #block.steps == 0 then
        problem = { code = "empty-block", path = where .. ".steps" }
    end

    if not problem and block.overrides ~= nil then
        if not denseList(block.overrides) then
            problem = { code = "invalid-block-overrides", path = where .. ".overrides" }
        end

        for index, override in ipairs(problem and {} or block.overrides) do
            local at = where .. ".overrides[" .. index .. "]"

            if not plainTable(override) then
                problem = { code = "invalid-block-override", path = at }
                break
            end

            for key in pairs(override) do
                if not overrideFields[key] then
                    problem = { code = "unknown-block-field", path = at .. "." .. tostring(key) }
                end
            end

            if problem then
                break
            end

            local scoped = override.families ~= nil and stringSet(override.families)

            if
                override.families == nil and override.specs == nil
                or override.families ~= nil and not scoped
                or override.specs ~= nil and not stringSet(override.specs, true)
            then
                problem = { code = "invalid-block-override-selector", path = at }
                break
            end

            -- An override narrows a block; it never widens the reviewed editions.
            for family in pairs(scoped or {}) do
                if not families[family] then
                    problem = { code = "incompatible-block-edition", path = at .. ".families", detail = family }
                end
            end

            if problem then
                break
            end

            problem = checkBlockSteps(override.steps, at .. ".steps", {})

            if not problem and #override.steps == 0 then
                problem = { code = "empty-block", path = at .. ".steps" }
            end

            if problem then
                break
            end
        end
    end

    if problem then
        return false, message(problem)
    end
    if blocks[block.id] then
        return false, message({ code = "duplicate-block-id", path = where })
    end

    local copy, why = data.CopyData(block)

    if not copy then
        return false, why.code
    end

    blocks[copy.id] = copy
    return true
end

-- Returns the expanded envelope, its composition record (nil when the
-- definition uses no blocks) or nil plus a diagnostic. A definition without a
-- manifest-level `blocks` declaration is returned untouched (not copied).
-- Expanded step ID = reference prefix (default `<reference id>.`) .. block step
-- ID, prefixes compounding through nested references: stable across reloads
-- and distinct for every inclusion. Each inclusion is a fresh copy.
local function expandDefinition(envelope)
    if not plainTable(envelope) then
        return envelope
    end

    local body, declared = envelope.body, envelope.blocks

    if declared == nil then
        -- Every reference must be declared; never let one reach validation.
        local seen = {}

        -- Looks for a block reference in a definition that declares no blocks and returns a problem record for the
        -- first one, so a reference can never reach validation unresolved.
        local function stray(list, path)
            if not plainTable(list) or seen[list] then
                return
            end

            seen[list] = true

            for index, step in ipairs(list) do
                local at = path .. "[" .. index .. "]"

                if plainTable(step) then
                    if step.type == "block" then
                        return { code = "undeclared-block-dependency", path = at, detail = tostring(step.block) }
                    end

                    local problem = stray(step.onTrue, at .. ".onTrue") or stray(step.onFalse, at .. ".onFalse")

                    if problem then
                        return problem
                    end
                end
            end
        end

        local problem = plainTable(body)
            and (stray(body.rotation, "$.body.rotation") or stray(body.cooldowns, "$.body.cooldowns"))

        if problem then
            return nil, nil, message(problem)
        end

        return envelope
    end

    local pins = {}

    if not plainTable(declared) or next(declared) == nil then
        return nil, nil, message({ code = "invalid-block-dependencies", path = "$.blocks" })
    end

    for key, revision in pairs(declared) do
        if not blockName(key) or not (type(revision) == "number" and revision >= 1 and revision % 1 == 0) then
            return nil, nil, message({ code = "invalid-block-dependencies", path = "$.blocks." .. tostring(key) })
        end

        pins[key] = revision
    end

    local scope = plainTable(envelope.applicability) and envelope.applicability or {}

    if not stringSet(scope.families) or scope.specs ~= nil and not stringSet(scope.specs, true) then
        return nil, nil, message({ code = "invalid-block-consumer-scope", path = "$.applicability" })
    end

    local used, active, problem = {}, {}, nil

    -- Records the first problem found during expansion and returns nil so callers can unwind.
    local function fail(value)
        problem = problem or value
        return nil
    end

    -- The selected variant must suit the whole consumer scope; a partial
    -- edition/spec match cannot be expressed by one expanded tree.
    local function variant(block, at, via)
        for _, family in ipairs(scope.families) do
            if not stringSet(block.families)[family] then
                return fail({
                    code = "incompatible-block-edition",
                    path = at,
                    via = via,
                    detail = block.id .. " lacks " .. family,
                })
            end
        end

        if block.class ~= nil and scope.class ~= block.class then
            return fail({
                code = "incompatible-block-class",
                path = at,
                via = via,
                detail = block.id .. " requires " .. block.class,
            })
        end

        local chosen, where, picked = block.steps, block.id .. ".steps", false

        for index, override in ipairs(block.overrides or {}) do
            local editions = coverage(scope.families, override.families and stringSet(override.families))
            local specs = coverage(scope.specs, override.specs and stringSet(override.specs, true))

            if editions ~= "none" and specs ~= "none" then
                local selected = block.id .. ".overrides[" .. index .. "]"

                if editions == "some" or specs == "some" or picked then
                    return fail({ code = "ambiguous-block-override", path = selected, via = via })
                end

                chosen, where, picked = override.steps, selected .. ".steps", true
            end
        end

        return chosen, where
    end

    local expandList

    -- Expands one step into out: a plain step is copied (its id prefixed inside a block), a block reference is replaced
    -- by the steps of the pinned block variant, and a branch expands both arms. Returns true, or nil after recording a
    -- problem through fail (missing block, cycle, depth over 16, undeclared or stale pin, invalid id).
    local function expandStep(step, at, prefix, out, via, depth)
        if not plainTable(step) then
            out[#out + 1] = step
            return true
        end

        if step.type == "block" then
            for key in pairs(step) do
                if not referenceFields[key] then
                    return fail({ code = "invalid-block-reference", path = at .. "." .. tostring(key), via = via })
                end
            end

            if not blockName(step.id) or step.prefix ~= nil and not blockName(step.prefix) then
                return fail({ code = "invalid-block-reference", path = at, via = via })
            end

            local block = blockName(step.block) and blocks[step.block]

            if not block then
                return fail({ code = "missing-block", path = at .. ".block", via = via, detail = tostring(step.block) })
            end
            if active[block.id] then
                return fail({
                    code = "block-cycle",
                    path = at,
                    via = via,
                    detail = table.concat(active, ' > ') .. " > " .. block.id,
                })
            end
            if depth >= 16 then
                return fail({ code = "block-depth-limit", path = at, via = via })
            end
            if pins[block.id] == nil then
                return fail({ code = "undeclared-block-dependency", path = at, via = via, detail = block.id })
            end
            if pins[block.id] ~= block.revision then
                return fail({
                    code = "stale-block-revision",
                    path = "$.blocks." .. block.id,
                    detail = "pinned " .. pins[block.id] .. ", registered " .. block.revision,
                })
            end

            local steps, where = variant(block, at, via)

            if not steps then
                return nil
            end

            used[block.id] = true
            active[block.id] = true
            active[#active + 1] = block.id

            local ok = expandList(
                steps,
                where,
                prefix .. (step.prefix or step.id .. "."),
                out,
                via and via .. " > " .. at or at,
                depth + 1
            )

            active[block.id] = nil
            active[#active] = nil
            return ok
        end

        local copy, why = data.CopyData(step)

        if not copy then
            return fail({ code = why.code, path = at, via = via })
        end

        if prefix ~= "" then
            copy.id = type(step.id) == "string" and prefix .. step.id or nil

            if not blockName(copy.id) then
                return fail({
                    code = "invalid-expanded-step-id",
                    path = at .. ".id",
                    via = via,
                    detail = tostring(copy.id),
                })
            end
        end

        for _, arm in ipairs({ "onTrue", "onFalse" }) do
            if step.type == "branch" and step[arm] ~= nil then
                copy[arm] = {}

                if not expandList(step[arm], at .. "." .. arm, prefix, copy[arm], via, depth) then
                    return nil
                end
            end
        end

        out[#out + 1] = copy
        return true
    end

    -- Expands every step of a list in order into out; returns true, or nil when any step failed.
    expandList = function(list, at, prefix, out, via, depth)
        if not denseList(list) then
            return fail({ code = "invalid-priority-list", path = at, via = via })
        end

        for index, step in ipairs(list) do
            if not expandStep(step, at .. "[" .. index .. "]", prefix, out, via, depth) then
                return nil
            end
        end

        return true
    end

    local expanded, why = data.CopyData(envelope)

    if not expanded then
        return nil, nil, why.code
    end

    expanded.blocks = nil

    if plainTable(body) then
        for _, section in ipairs({ "rotation", "cooldowns" }) do
            if body[section] ~= nil then
                local list = {}

                if not expandList(body[section], "$.body." .. section, "", list, nil, 0) then
                    return nil, nil, message(problem)
                end

                expanded.body[section] = list
            end
        end
    end

    for key in pairs(pins) do
        if not used[key] then
            return nil, nil, message({ code = "unused-block-dependency", path = "$.blocks." .. key })
        end
    end

    -- Authored IDs (references included) are unique; expanded IDs are unique and
    -- never reuse a vanished reference's ID, so diagnostics stay unambiguous.
    local ids, references

    local function unique(list, at)
        for index, step in ipairs(list) do
            local where = at .. "[" .. index .. "]"

            if plainTable(step) and step.id ~= nil then
                if ids[step.id] or references and references[step.id] then
                    return { code = "duplicate-step-id", path = where .. ".id", detail = tostring(step.id) }
                end

                ids[step.id] = step.type == "block" and "reference" or true
            end

            if plainTable(step) and step.type == "branch" then
                for _, arm in ipairs({ "onTrue", "onFalse" }) do
                    if denseList(step[arm]) then
                        local found = unique(step[arm], where .. "." .. arm)

                        if found then
                            return found
                        end
                    end
                end
            end
        end
    end

    for pass, tree in ipairs({ body, expanded.body }) do
        ids = {}

        for _, section in ipairs({ "rotation", "cooldowns" }) do
            local found = plainTable(tree) and denseList(tree[section]) and unique(tree[section], "$.body." .. section)

            if found then
                return nil, nil, message(found)
            end
        end

        if pass == 1 then
            references = {}

            for key, kind in pairs(ids) do
                if kind == "reference" then
                    references[key] = true
                end
            end
        end
    end

    return expanded, { blocks = pins }
end

-- ============================================================================
-- Registering Built Ins
-- ============================================================================

-- Offline tools and corpus checks read the exact tree registration consumes.
function addon:ExpandDefaultRotation(envelope)
    local expanded, composition, problem = expandDefinition(envelope)

    if not expanded then
        return nil, problem
    end

    if expanded == envelope then
        expanded = data.CopyData(envelope)
    end

    return expanded, composition and data.CopyData(composition)
end

-- The manifest-level block dependencies (id -> pinned revision) a registered
-- Built In was expanded from; nil when it uses no blocks. Never user data.
function addon:GetDefaultRotationComposition(id)
    return compositions[id] and data.CopyData(compositions[id])
end

-- Registers a packaged Built In rotation envelope: expands its blocks, validates the envelope, and stores it by id.
-- Returns true, or false and a reason (invalid-envelope, missing-class-scope, duplicate-default-id, or the composition
-- problem). An envelope for another character's edition, class or expansion is accepted and dropped (true,
-- "other-character"). Advances the execution generation and the definition version.
function addon:RegisterDefaultRotation(envelope)
    local scope = type(envelope) == "table" and envelope.applicability

    if type(scope) == "table" and notForThisCharacter(
        scope.families,
        scope.class,
        scope.minExpansion,
        scope.maxExpansion
    ) then
        return true, "other-character"
    end

    local expanded, composition, problem = expandDefinition(envelope)

    if not expanded then
        return false, problem
    end

    local copy, why = data.CopyData(expanded)

    if not copy then
        return false, why.code
    end
    if copy.format ~= "RotationMaster" or copy.schemaVersion ~= 1 or not data.ValidateEnvelope(copy).valid then
        return false, "invalid-envelope"
    end
    if not copy.applicability.class and copy.applicability.universal ~= true then
        return false, "missing-class-scope"
    end
    if definitions[copy.id] then
        return false, "duplicate-default-id"
    end

    invalidateExecution()
    definitions[copy.id] = copy
    compositions[copy.id] = composition
    definitionVersion = definitionVersion + 1
    return true
end

-- ============================================================================
-- Library initialization
-- ============================================================================

-- One-time repair, per profile and class: the Built In toggle used to show a
-- pack that could not be validated as "Disabled" and wrote each click as the
-- opposite of that, so packs the player never meant to switch off were saved
-- as enabled=false. Those choices cannot be told apart from deliberate ones,
-- so for packs that ship enabled they are removed once (the shipped default
-- applies again), and one chat line names them. Packs that ship disabled, and
-- every enabled=true, are left alone.
local function repairBuiltinPreferences(self, profile, state)
    if type(UnitClass) ~= "function" then
        return
    end

    local ok, _, class = pcall(UnitClass, "player")

    if
        not ok
        or not self.Platform:CanReadValue(class)
        or canaccessvalue and not canaccessvalue(class)
        or type(class) ~= "string"
    then
        return
    end

    local repairs = profile.builtinPreferenceRepairs

    if repairs ~= nil and not plainTable(repairs) then
        return
    end
    if repairs and repairs[class] then
        return
    end

    local preferences = state.preferences

    if preferences ~= nil and not plainTable(preferences) then
        return
    end

    local restored = {}

    for id, definition in pairs(definitions) do
        local preference = preferences and preferences[id]
        local scope = definition.applicability

        if
            plainTable(preference)
            and preference.enabled == false
            and not (plainTable(definition.body) and definition.body.disabled == true)
            and (not plainTable(scope) or scope.class == nil or scope.class == class)
        then
            preference.enabled = nil

            if next(preference) == nil then
                preferences[id] = nil
            end

            restored[#restored + 1] = L[definition.nameKey or id]
        end
    end

    repairs = repairs or {}
    repairs[class] = true
    profile.builtinPreferenceRepairs = repairs

    if #restored > 0 then
        table.sort(restored)

        if self.info then
            self:info(
                L["Built In rotations turned back on (they had been switched off without your choice): %s"],
                table.concat(restored, ", ")
            )
        end
    end
end

-- Builds the library for the current profile: validates the saved library state, applies the one-time preference
-- repair, registers every Built In in a fresh catalog, and prepares the runtime body copies (player priority applied,
-- packaged disabled flag cleared) and the clone scopes. Returns true, or false and a reason (invalid-library-state or
-- the catalog's own). On failure active is cleared, so nothing half-built is ever served.
function addon:InitializeRotationLibrary()
    invalidateExecution()
    local profile = self.db.profile
    local validation, referenceStamp = self:GetRotationValidationOptions()
    local state = profile.rotationLibrary

    if state == nil then
        state = {}
        profile.rotationLibrary = state
    end

    if not plainTable(state) then
        invalidateExecution()
        active = nil
        return false, "invalid-library-state"
    end

    for _, key in ipairs({ "preferences", "origins", "comparisons", "imports" }) do
        if state[key] ~= nil and not plainTable(state[key]) then
            invalidateExecution()
            active = nil
            return false, "invalid-library-state"
        end
    end

    state.preferences, state.origins, state.comparisons, state.imports =
        state.preferences or {}, state.origins or {}, state.comparisons or {}, state.imports or {}

    if next(definitions) ~= nil then
        repairBuiltinPreferences(self, profile, state)
    end

    -- Only preferences are shared with the persisted namespace. Clone construction
    -- uses a temporary catalog; the legacy editor retains the sole saved body.
    local catalog, why = data.NewCatalog({
        state = { preferences = state.preferences },
        validation = validation,
        newId = self.uuid,
    })

    if not catalog then
        invalidateExecution()
        active = nil
        return false, why
    end

    local views, bodies = {}, {}

    for id, envelope in pairs(definitions) do
        local ok, reason = catalog:RegisterBuiltin(envelope)

        if not ok then
            invalidateExecution()
            active = nil
            return false, reason
        end

        views[id] = catalog:Get({ kind = "builtin", id = id })
        bodies[id] = data.CopyData(views[id].envelope.body)
        bodies[id].name = L[views[id].nameKey]
        -- A packaged body's disabled flag is only its default; the player's
        -- preference decides, and eligible() already applies it. Left on the
        -- runtime copy it would keep an enabled pack out of auto-switching.
        bodies[id].disabled = nil
        -- The player's priority for this pack (profile, keyed by id, so it
        -- survives revisions) replaces the shipped one on the runtime copy.
        local override = plainTable(state.preferences[id]) and data.GetRotationPriority(state.preferences[id].priority)

        if override and state.preferences[id].priority ~= nil then
            bodies[id].priority = override
        end
    end

    invalidateExecution()

    active = {
        profile = profile,
        state = state,
        catalog = catalog,
        views = views,
        bodies = bodies,
        cloneScopes = {},
        version = definitionVersion,
        referenceStamp = referenceStamp,
        generation = {},
    }

    for spec, origins in pairs(state.origins) do
        if type(spec) == "number" and plainTable(origins) then
            active.cloneScopes[spec] = {}

            for id in pairs(origins) do
                local view = self:GetSourcedRotationView(spec, id)

                if view then
                    view.validation = data.ValidateEnvelope(view.envelope, validation)
                    view.enabled = true
                end

                active.cloneScopes[spec][id] = view or false
            end
        end
    end

    return true
end

-- ============================================================================
-- Keeping the library current
-- ============================================================================

-- The addon's own initializer, kept so ensure can tell it from a replaced one when deciding whether proof may be
-- issued.
local ownedInitializeRotationLibrary = addon.InitializeRotationLibrary

-- Makes sure the library built for this profile is still current, and rebuilds it when the profile, the saved library
-- state, the registered Built In set or the validation stamp changed. Returns true, or nil and a reason. With needProof
-- it may also return the reference stamp and true: the witness that nothing changed since the last build, which the
-- scoped coordinator uses to skip re-proving. A fresh initialization never issues that witness.
local function ensure(self, needProof)
    local referenceStamp, method, db, profile, global, conditions, shared, personal, effects, version, state
    local plainStamps = false

    if needProof and readValidationStamp then
        local entryMethod = validationType(self) == 'table' and validationRawget(self, 'GetRotationValidationStamp')
            or nil

        method = self.GetRotationValidationStamp

        referenceStamp, db, profile, global, conditions, shared, personal, effects, version, state = readValidationStamp(
            self,
            method,
            entryMethod
        )

        plainStamps = db ~= nil
            and validationPlain(referenceStamp)
            and active ~= nil
            and validationPlain(active.referenceStamp)
            and validationPlain(active.generation)
    else
        referenceStamp = self:GetRotationValidationStamp()
    end

    if
        not active
        or active.profile ~= self.db.profile
        or active.state ~= self.db.profile.rotationLibrary
        or active.version ~= definitionVersion
        or active.referenceStamp ~= referenceStamp
    then
        -- Initializer overrides may return arbitrary extras; none can authorize
        -- the private unchanged-branch witness. Generation historically used two.
        if needProof then
            local ok, why = self:InitializeRotationLibrary()
            return ok, why
        end

        return self:InitializeRotationLibrary()
    end

    -- An initializer call never issues proof, even if it returns the same generation.
    if
        plainStamps
        and validationRawequal(validationRawget(self, 'InitializeRotationLibrary'), ownedInitializeRotationLibrary)
        and checkValidationLayout(
            self,
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
    then
        return true, nil, referenceStamp, true
    end

    return true
end

-- ============================================================================
-- Rotation context (client facts)
-- ============================================================================

-- The bar the player is acting through. A vehicle, override bar, possession
-- (mind control, quest possession) or pet battle replaces the player's own
-- actions; each is a separate rotation applicability domain. Every API is
-- feature-detected: TBC/Era clients have possession, Wrath+ add vehicles and
-- override bars, and only Retail has pet battles. Vehicle and pet battle keep
-- their historical read order (one call each per observation).
local function observeActionContext(read)
    local vehicle = read(UnitHasVehicleUI, "player")

    if vehicle == nil then
        vehicle = read(UnitInVehicle, "player")
    end

    if C_PetBattles and read(C_PetBattles.IsInBattle) then
        return "petbattle"
    end

    -- Retail 12.0 keeps these bar queries in C_ActionBar; the globals exist
    -- there only behind the loadDeprecationFallbacks CVar.
    local bars = type(C_ActionBar) == "table" and C_ActionBar or nil

    if vehicle or read(bars and bars.HasVehicleActionBar or HasVehicleActionBar) then
        return "vehicle"
    end
    if read(bars and bars.HasOverrideActionBar or HasOverrideActionBar) then
        return "override"
    end
    if read(bars and bars.IsPossessBarVisible or IsPossessBarVisible) then
        return "possession"
    end

    return "player"
end

-- Fresh observation for the event-driven cache in main.lua; never polled.
local function readActionContextValue(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, value = pcall(fn, ...)

    if ok and addon.Platform:CanReadValue(value) then
        return value
    end
end

-- Reads the action context now (player, vehicle, override, possession or petbattle). Called by main.lua's event-driven
-- cache, not on the poll.
function addon:ReadActionContext()
    return observeActionContext(readActionContextValue)
end

-- Platform facts used for selection are public identity/context observations.
-- Restricted results never enter comparisons or portable-data traversal.
function addon:GetRotationContext(spec)
    local context = self.Platform:GetClientInfo()

    -- Calls fn protected and returns its value only when the client allows reading it.
    local function read(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end

        local ok, value = pcall(fn, ...)

        if ok and self.Platform:CanReadValue(value) then
            return value
        end
    end

    -- Returns the player's class token.
    local function class()
        local _, token = UnitClass("player")
        return token
    end

    context.class = read(class)
    context.level = read(UnitLevel, "player")
    context.build = tonumber(context.build)
    context.spec = spec
    context.actionContext = observeActionContext(read)
    return context
end

-- Captured owned methods and library functions, used to tell the addon's own context reader from a replacement; the
-- reader handed out below checks them.
local ownedRotationContext = addon.GetRotationContext
local clientContextReader
local ownedReadValue = addon.Platform.CanReadValue
local contextIpairs, contextRawget, contextEqual = ipairs, rawget, rawequal
local contextPairs = pairs
---@type fun(f: number|function): table
local contextGetfenv = getfenv
local contextEnvironment = type(contextGetfenv) == "function" and contextGetfenv(1) or nil
local bindClient = addon.BindRotationClientReader

if type(bindClient) == 'function' then
    bindClient(addon, function(reader)
        clientContextReader = reader
    end)

    addon.BindRotationClientReader = nil
end

-- Only the exact owned methods use the narrow projection. Overrides retain
-- their actual receiver, first result, shared table and error behavior.
local function rotationContext(owner, spec)
    local method = owner.GetRotationContext

    if method ~= ownedRotationContext or not clientContextReader then
        local value = method(owner, spec)
        return value, false
    end

    local context, private = clientContextReader(owner.Platform)

    -- Calls fn protected and returns its value only when the client allows reading it.
    local function read(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end

        local ok, value = pcall(fn, ...)

        if ok and owner.Platform:CanReadValue(value) then
            return value
        end
    end

    -- Returns the player's class token.
    local function class()
        local _, token = UnitClass("player")
        return token
    end

    context.class = read(class)
    context.level = read(UnitLevel, "player")
    context.build = tonumber(context.build)
    context.spec = spec
    context.actionContext = observeActionContext(read)
    return context, private == true
end

-- Uncovered vehicle/pet-battle notifications retain fresh observation at every
-- publication boundary, even when the other owned eligibility facts are reused.
local function runtimeActionContext(owner)
    -- Calls fn protected and returns its value only when the client allows reading it.
    local function read(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end

        local ok, value = pcall(fn, ...)

        if ok and owner.Platform:CanReadValue(value) then
            return value
        end
    end

    return observeActionContext(read)
end

-- Returns the runtime key of a Built In among a spec's custom rotations: "RM-BUILTIN:<id>", prefixed with colons until
-- it collides with no custom key.
local function runtimeKey(id, custom)
    local key = "RM-BUILTIN:" .. id

    while custom[key] ~= nil do
        key = ":" .. key
    end

    return key
end

-- ============================================================================
-- Reader handed to the scoped coordinator
-- ============================================================================

-- One-time handoff to the scoped coordinator. No canonical source getter stays
-- on the addon surface after its consumer captures this private reader.
function addon:BindRotationLibraryReader(bind)
    if type(bind) ~= 'function' then
        return nil, 'invalid-library-reader-binder'
    end

    local owner = self
    local reader = {}

    -- True when fn is the addon's own context reader.
    function reader:OwnsContext(fn)
        return fn == ownedRotationContext
    end

    -- The context reader the coordinator receives: the addon's own narrow projection of the client context for a spec.
    local function contextMethod(self, spec)
        return rotationContext(owner, spec)
    end

    reader.Context = contextMethod

    -- True when the context method, projection and dispatch functions are the ones this file owns and still share its
    -- environment, so a replaced reader cannot authorize a result.
    local function ownsPrivateContext(method, projection, dispatch)
        return contextGetfenv
            and contextEnvironment
            and contextEqual(method, contextMethod)
            and contextEqual(contextRawget(reader, 'Context'), contextMethod)
            and contextEqual(contextGetfenv(contextMethod), contextEnvironment)
            and contextEqual(contextGetfenv(rotationContext), contextEnvironment)
            and contextEqual(contextGetfenv(projection), contextEnvironment)
            and contextEqual(contextGetfenv(dispatch), contextEnvironment)
            and contextEqual(contextRawget(contextEnvironment, 'ipairs'), contextIpairs)
    end

    -- Validates a context value read through the owned reader. Returns nil when a reader was replaced or the value is
    -- implausible (no class, level or build, unknown family); otherwise returns a function that re-checks the captured
    -- client functions and returns true when a fresh action-context read still equals the value's actionContext.
    local function runtimeContextGuard(value, method, projection, dispatch)
        local platform = owner.Platform

        if
            not ownsPrivateContext(method, projection, dispatch)
            or owner.GetRotationContext ~= ownedRotationContext
            or platform.CanReadValue ~= ownedReadValue
            or type(value) ~= 'table'
            or value.class == nil
            or type(value.level) ~= 'number'
            or value.level ~= value.level
            or value.level <= 0
            or value.level >= math.huge
            or type(value.build) ~= 'number'
            or value.build ~= value.build
            or value.build <= 0
            or value.build >= math.huge
            or value.family == 'unknown'
            or contextRawget(contextEnvironment, 'pairs') ~= contextPairs
        then
            return nil
        end

        local client, readValue = platform.GetClientInfo, platform.CanReadValue

        local unitClass, unitLevel, buildInfo, project, expansion =
            UnitClass, UnitLevel, GetBuildInfo, WOW_PROJECT_ID, LE_EXPANSION_LEVEL_CURRENT

        local hasVehicle, inVehicle, petBattles = UnitHasVehicleUI, UnitInVehicle, C_PetBattles
        local vehicleBar, overrideBar, possessBar = HasVehicleActionBar, HasOverrideActionBar, IsPossessBarVisible
        local inBattle = petBattles and petBattles.IsInBattle
        local secret, access = issecretvalue, canaccessvalue

        -- The re-check handed back by runtimeContextGuard: it fails when any captured client function was replaced and
        -- otherwise tells whether the live action context still equals the one in the value.
        return function()
            if
                not ownsPrivateContext(method, projection, dispatch)
                or owner.GetRotationContext ~= ownedRotationContext
                or owner.Platform ~= platform
                or platform.GetClientInfo ~= client
                or platform.CanReadValue ~= readValue
                or UnitClass ~= unitClass
                or UnitLevel ~= unitLevel
                or GetBuildInfo ~= buildInfo
                or WOW_PROJECT_ID ~= project
                or LE_EXPANSION_LEVEL_CURRENT ~= expansion
                or UnitHasVehicleUI ~= hasVehicle
                or UnitInVehicle ~= inVehicle
                or C_PetBattles ~= petBattles
                or HasVehicleActionBar ~= vehicleBar
                or HasOverrideActionBar ~= overrideBar
                or IsPossessBarVisible ~= possessBar
                or (petBattles and petBattles.IsInBattle) ~= inBattle
                or issecretvalue ~= secret
                or canaccessvalue ~= access
                or contextGetfenv(runtimeActionContext) ~= contextEnvironment
                or contextGetfenv(readValue) ~= contextEnvironment
                or contextGetfenv(client) ~= contextEnvironment
                or contextRawget(contextEnvironment, 'pairs') ~= contextPairs
            then
                return nil
            end

            return runtimeActionContext(owner) == value.actionContext
        end
    end

    -- Returns the library generation table after making the library current, with the proof results of ensure; or nil
    -- and a reason.
    local function generationMethod(self)
        local ok, why, checked, proof = ensure(owner, true)

        if not ok then
            return nil, why
        end

        return active.generation, nil, checked, proof
    end

    reader.Generation = generationMethod

    -- The checker captures the definition-owned method; a replaced reader field
    -- cannot authorize its own returned proof. Nil checks the pre-dispatch layout.
    local function provesGeneration(method, reference, generation)
        return validationRawget ~= nil
            and validationPlain(reader)
            and validationPlain(reference)
            and validationPlain(generation)
            and validationRawequal(validationRawget(reader, 'Generation'), generationMethod)
            and (method == nil or validationRawequal(method, generationMethod))
    end

    -- Returns true, the projected row and the generation for one Built In if it exists, matches the class and has been
    -- made current; or nil and a reason (unknown-rotation, class-mismatch, or the library's). project builds the row
    -- from the view, the runtime body and the eligibility answer.
    function reader:Read(spec, id, project, candidates)
        local ok, why = ensure(owner)

        if not ok then
            return nil, why
        end

        local view = active.views[id]

        if not view then
            return nil, 'unknown-rotation'
        end

        local context = rotationContext(owner, spec)
        context.spec = spec

        if not matchesClass(view, context) then
            return nil, 'class-mismatch'
        end

        local allowed, reason = eligible(view, context, candidates)
        return true, project(view, active.bodies[id], allowed, reason), active.generation
    end

    -- Returns one projected row per Built In of the player's class, with the generation; or nil and a reason.
    function reader:List(spec, project)
        local ok, why = ensure(owner)

        if not ok then
            return nil, why
        end

        local context = rotationContext(owner, spec)
        context.spec = spec
        local rows = {}

        for id, view in pairs(active.views) do
            if matchesClass(view, context) then
                rows[#rows + 1] = project(id, view, active.bodies[id])
            end
        end

        return rows, active.generation
    end

    -- Answers eligible() for a view in the context of a spec.
    function reader:Eligible(view, spec, candidates)
        local context = rotationContext(owner, spec)
        context.spec = spec
        return eligible(view, context, candidates)
    end

    -- Marks every Built In id (and the step ids inside) as taken in the used set, so new identities never collide with
    -- a shipped one.
    function reader:Reserve(used)
        for id, envelope in pairs(definitions) do
            used[id] = true
            data.ReserveRotationIdentities(envelope, used)
        end
    end

    -- Returns the current generation table (nil before the library is built) and the definition version.
    local function runtimeGeneration()
        return active and active.generation, definitionVersion
    end

    bind(
        reader,
        provesGeneration,
        ownsPrivateContext,
        runtimeContextGuard,
        runtimeAuthority,
        eligible,
        ownedRotationContext,
        ownedReadValue,
        runtimeGeneration
    )

    return true
end

-- ============================================================================
-- Built In listing and preferences
-- ============================================================================

-- Returns the Built In rows for the player's class sorted by name, each with its runtime key, eligibility and reason,
-- localized name and description. A pack for another edition says so (its scope reason) in preference to naming a
-- condition unavailable only because it belongs to that edition. For menus and the editor, not the poll.
function addon:ListDefaultRotations(spec)
    local ok, why = ensure(self)

    if not ok then
        return {}, why
    end

    local context = self:GetRotationContext(spec)
    context.spec = spec
    local custom = (self.db.profile.rotations or {})[spec] or {}
    local rows = {}

    for id, view in pairs(active.views) do
        if matchesClass(view, context) then
            local row = data.CopyData(view)
            local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
            row.runtimeKey = scoped and scoped:Key({ kind = 'builtin', id = id }) or runtimeKey(id, custom)
            row.eligible, row.eligibilityReason = eligible(view, context)

            -- A pack for another edition says so, before naming a condition
            -- that is unavailable here only because it is that other edition's.
            if
                row.eligibilityReason == "invalid-or-unsupported"
                and view.validation.valid
                and view.validation.supported
            then
                local scoped, scopeReason = eligible({
                    enabled = true,
                    validation = { valid = true, supported = true, resolved = true },
                    applicability = view.applicability,
                    readOnly = view.readOnly,
                    envelope = view.envelope,
                }, context)

                if not scoped then
                    row.eligibilityReason = scopeReason
                end
            end

            row.name = L[row.nameKey or id]
            row.description = L[row.descriptionKey or ""]
            rows[#rows + 1] = row
        end
    end

    table.sort(rows, function(a, b)
        if a.name == b.name then
            return a.id < b.id
        end

        return a.name < b.name
    end)

    return rows
end

-- Every Built In for this class and why it is or is not on: state is
-- 'enabled', 'user-disabled' (the player switched it off), 'shipped-disabled'
-- (an alternative that ships off) or 'invalid' (it cannot be validated here).
-- applies/reason say whether it would be selectable for `spec` if it were on.
-- Commands, menus and the editor only; never while polling.
function addon:GetBuiltinStates(spec)
    local ok, why = ensure(self)

    if not ok then
        return {}, why
    end

    local context = self:GetRotationContext(spec)
    context.spec = spec
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    local custom = (self.db.profile.rotations or {})[spec] or {}
    local rows = {}

    for id, view in pairs(active.views) do
        if matchesClass(view, context) then
            local preference = active.state.preferences[id]
            local saved = nil

            if plainTable(preference) and type(preference.enabled) == 'boolean' then
                saved = preference.enabled
            end

            local definition = definitions[id]
            local shipped = plainTable(definition) and plainTable(definition.body) and definition.body.disabled == true
            local state

            if not view.validation.valid then
                state = 'invalid'
            elseif saved == false then
                state = 'user-disabled'
            elseif saved == true or not shipped then
                state = 'enabled'
            else
                state = 'shipped-disabled'
            end

            local applies, reason = eligible({
                enabled = true,
                validation = view.validation,
                applicability = view.applicability,
                readOnly = view.readOnly,
                envelope = view.envelope,
            }, context)

            -- Whether its scope (edition, class, specialization, level...) fits,
            -- whatever its validity: a pack that fits but cannot run says why.
            local fits = applies or reason == 'invalid-or-unsupported' and eligible({
                enabled = true,
                validation = { valid = true, supported = true, resolved = true },
                applicability = view.applicability,
                readOnly = view.readOnly,
                envelope = view.envelope,
            }, context)

            rows[#rows + 1] = {
                id = id,
                name = L[view.nameKey or id],
                state = state,
                shippedDisabled = shipped,
                userChoice = saved,
                applies = applies,
                reason = reason,
                fits = fits == true,
                key = scoped and scoped:Key({ kind = 'builtin', id = id }) or runtimeKey(id, custom),
                body = active.bodies[id],
            }
        end
    end

    table.sort(rows, function(a, b)
        if a.name == b.name then
            return a.id < b.id
        end

        return a.name < b.name
    end)

    return rows
end

-- One Built In's switch: true (on), false (off) and the state name from
-- GetBuiltinStates; nil when unknown. Live, never a cached copy.
function addon:GetBuiltinSwitch(id)
    if not ensure(self) then
        return nil
    end

    local view = active.views[id]

    if not view then
        return nil
    end

    local preference = active.state.preferences[id]
    local definition = definitions[id]
    local shipped = plainTable(definition) and plainTable(definition.body) and definition.body.disabled == true
    local saved = nil

    if plainTable(preference) and type(preference.enabled) == 'boolean' then
        saved = preference.enabled
    end

    local on = view.switchedOn == true

    local state = not view.validation.valid and 'invalid'
        or saved == false and 'user-disabled'
        or (saved == true or not shipped) and 'enabled'
        or 'shipped-disabled'

    return on, state, shipped
end

-- Returns the catalog view of a Built In by id, or nil.
function addon:GetDefaultRotation(id)
    if not ensure(self) then
        return nil
    end

    return active.catalog:Get({ kind = "builtin", id = id })
end

-- Switches a Built In on or off for the profile through the catalog, keeping a preference only when it differs from the
-- shipped default. Turning off the rotation that is currently selected also stops it. Returns the catalog's saved flag
-- and reason, or false and a reason when a newer rotation transition superseded this call.
function addon:SetDefaultRotationEnabled(id, value)
    local change = beginActive(self)
    local ok, why = ensure(self)

    if not ok then
        return false, why
    end

    local selected = self.currentRotation and self:GetDefaultIdForRuntime(self.currentSpec, self.currentRotation) == id

    if not activeCurrent(self, change) then
        return false, 'rotation-transition-superseded'
    end

    local saved, reason = active.catalog:SetEnabled({ kind = "builtin", id = id }, value)

    -- Only a choice that differs from the shipped default is kept; choosing
    -- the default again removes it, so a later revision's default applies.
    if saved then
        local preference = active.state.preferences[id]
        local definition = definitions[id]

        local shippedOn = not (plainTable(definition)
            and plainTable(definition.body)
            and definition.body.disabled == true)

        if plainTable(preference) and preference.enabled == shippedOn then
            preference.enabled = nil

            if next(preference) == nil then
                active.state.preferences[id] = nil
            end
        end
    end

    if saved then
        invalidateExecution()
        active.views[id] = active.catalog:Get({ kind = "builtin", id = id })
        invalidateExecution()
        active.generation = {}

        if invalidateChoiceContext then
            invalidateChoiceContext(self)
        end
    end

    if saved and not value and selected and activeCurrent(self, change) then
        local disable = self.DisableRotation

        if not activeCurrent(self, change) then
            return saved, reason
        end

        if type(disable) == 'function' then
            local _, nextChange, stopped = disable(self)

            if stopped ~= false and activeCurrent(self, nextChange or change) then
                self.manualRotation = false
            end
        elseif retireActive(self, change) and activeCurrent(self, change) then
            self.manualRotation = false
        end
    end

    return saved, reason
end

-- A Built In's identifier: its pack's explicit body.identifier, else its id without
-- the rm.<edition>.<class>. prefix, dots as dashes (rm.retail.monk.brewmaster
-- .guide -> brewmaster-guide). Unique among the packs registered here; a
-- clash takes the edition, then a number, as a suffix.
local identifierCache, identifierVersion

local function builtinIdentifiers()
    if identifierVersion == definitionVersion and identifierCache then
        return identifierCache
    end

    local ids = {}

    for id in pairs(definitions) do
        ids[#ids + 1] = id
    end

    table.sort(ids)
    local byId, used = {}, {}

    for _, id in ipairs(ids) do
        local definition = definitions[id]
        local scope = plainTable(definition.applicability) and definition.applicability or {}

        local group = (type(scope.families) == 'table' and table.concat(scope.families, '+') or '') .. ':' .. tostring(
            scope.class
        )

        used[group] = used[group] or {}
        local explicit = plainTable(definition.body) and data.NormalizeRotationIdentifier(definition.body.identifier)
        local rest = id:match('^rm%.[^.]+%.[^.]+%.(.+)$') or id

        local identifier = explicit
            or data.NormalizeRotationIdentifier((rest:gsub('%.', '-')))
            or data.SlugRotationIdentifier(rest)

        if used[group][identifier] then
            local edition = type(scope.families) == 'table' and scope.families[1] or 'pack'
            local candidate = data.SlugRotationIdentifier(identifier .. '-' .. edition)
            local n = 2

            while used[group][candidate] do
                candidate = data.SlugRotationIdentifier(identifier .. '-' .. n)
                n = n + 1
            end

            identifier = candidate
        end

        used[group][identifier] = true
        byId[id] = identifier
    end

    identifierCache, identifierVersion = byId, definitionVersion
    return byId
end

-- Returns the unique identifier of a Built In (see builtinIdentifiers), or nil for an unknown id.
function addon:GetBuiltinIdentifier(id)
    return builtinIdentifiers()[id]
end

-- Per-profile Built In overrides live in rotationLibrary.preferences[id]
-- ({enabled=, priority=}); the rotation itself is never copied. A value equal
-- to the shipped one is not stored.
-- Returns the priority the pack ships with (0 when it declares none).
local function shippedPriority(id)
    local definition = definitions[id]

    return plainTable(definition) and plainTable(definition.body) and data.GetRotationPriority(definition.body.priority)
        or 0
end

-- Returns the profile's overrides of one Built In next to the shipped values and the effective ones, or nil when the id
-- is unknown. Reads live; nothing is copied into the profile.
function addon:GetBuiltinOverrides(id)
    if not ensure(self) then
        return nil
    end
    if not active.views[id] then
        return nil
    end

    local preference = active.state.preferences[id]
    local definition = definitions[id]
    local shippedOn = not (plainTable(definition) and plainTable(definition.body) and definition.body.disabled == true)
    local result = { shippedEnabled = shippedOn, shippedPriority = shippedPriority(id) }

    if plainTable(preference) then
        if type(preference.enabled) == 'boolean' then
            result.enabled = preference.enabled
        end
        if preference.priority ~= nil then
            result.priority = data.GetRotationPriority(preference.priority)
        end
    end

    result.effectiveEnabled = result.enabled == nil and shippedOn or result.enabled == true
    result.effectivePriority = result.priority or result.shippedPriority
    result.overridden = result.enabled ~= nil or result.priority ~= nil
    return result
end

-- Sets the player's priority for a Built In (nil removes it), storing it only when it differs from the shipped
-- priority, and applies it to the runtime body at once. Returns true, or false and a reason (unknown-rotation,
-- invalid-priority, invalid-preference).
function addon:SetBuiltinPriority(id, value)
    local ok, why = ensure(self)

    if not ok then
        return false, why
    end
    if not active.views[id] then
        return false, 'unknown-rotation'
    end
    if value ~= nil and not data.GetRotationPriority(value) then
        return false, 'invalid-priority'
    end

    local preferences = active.state.preferences
    local preference = preferences[id]

    if preference ~= nil and not plainTable(preference) then
        return false, 'invalid-preference'
    end

    if value ~= nil and value ~= shippedPriority(id) then
        if not preference then
            preference = {}
            preferences[id] = preference
        end

        preference.priority = value
    elseif preference then
        preference.priority = nil

        if next(preference) == nil then
            preferences[id] = nil
        end
    end

    invalidateExecution()
    active.bodies[id].priority = value ~= nil and value or shippedPriority(id)
    active.generation = {}

    if invalidateChoiceContext then
        invalidateChoiceContext(self)
    end

    return true
end

-- Back to the shipped switch and priority: the preference entry is removed.
function addon:ResetBuiltinOverrides(id)
    local current = self:GetBuiltinOverrides(id)

    if not current then
        return false, 'unknown-rotation'
    end

    local ok, why = self:SetBuiltinPriority(id, nil)

    if not ok then
        return false, why
    end
    if current.enabled ~= nil then
        return self:SetDefaultRotationEnabled(id, current.shippedEnabled)
    end

    return true
end

-- Returns the saved (editable) body of a custom rotation, or nil. With a scoped store the coordinator decides;
-- otherwise it reads the profile table.
function addon:GetEditableRotation(spec, id)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        return scoped:GetEditableRotation(spec, id)
    end

    local rotations = self.db.profile.rotations[spec]
    return rotations and rotations[id]
end

-- True when the condition table belongs to the step in the saved body of that rotation, so a callback can prove it was
-- handed the real one.
function addon:OwnsRotationCondition(spec, id, step, condition)
    local body = self:GetEditableRotation(spec, id)
    local tree = body and data.IndexRotationSteps(body, { allowMissingIds = true })

    if not tree then
        return false
    end

    for _, row in ipairs(tree.rows) do
        if row.step == step and step.conditions == condition then
            return true
        end
    end

    return false
end

-- ============================================================================
-- Runtime rotations
-- ============================================================================

-- Returns the rotations the poll may run for a spec, keyed by runtime key. With a scoped store it comes from the
-- coordinator's runtime pass; otherwise custom bodies and eligible Built Ins are merged here. internal gives the
-- trusted engine the private Built In bodies (never to be edited); public callers get copies. candidates keeps
-- rotations that fit the class but not the current level or context.
function addon:GetRuntimeRotations(spec, internal, candidates)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        local pass, why = scoped:RuntimePass(spec)

        if not pass then
            return {}, why
        end

        local rows, reason = pass:Candidates(candidates == true)

        for key, body in pairs(rows) do
            local ref = scoped:Resolve(spec, key)

            if ref and ref.kind == 'custom' then
                rows[key] = scoped:GetEditableRotation(spec, key)
            else
                rows[key] = data.CopyData(body)
            end
        end

        return rows, reason
    end

    local rotations = {}

    if spec == nil then
        return rotations
    end

    local ready = ensure(self)
    local context = self:GetRotationContext(spec)
    context.spec = spec
    -- Editing/export use the saved-data facade independently. Every client
    -- runs complete rotations; client support is checked by validation.
    local origins = ready and active.state.origins[spec]
    local scopes = ready and active.cloneScopes[spec]

    for id, body in pairs(self.db.profile.rotations[spec] or {}) do
        local scoped = scopes and scopes[id]
        local imported, importError

        if self.GetImportedRotationView then
            imported, importError = self:GetImportedRotationView(spec, id)
        end

        if scoped then
            -- The legacy editor mutates the saved body directly. Inspect its
            -- current structure without copying/traversing the historical baseline.
            scoped.envelope.body = body
            scoped.validation = data.ValidateEnvelope(scoped.envelope, self:GetRotationValidationOptions())
            scoped.applicability = scoped.envelope.applicability
        end

        local bare = not origins or plainTable(origins) and origins[id] == nil

        if bare or scoped and eligible(scoped, context, candidates) then
            local plainBody = bare and (not self.GetImportedRotationView or importError == "not-imported")

            if
                (not self.GetImportedRotationView or importError == "not-imported" or imported and eligible(
                    imported,
                    context,
                    candidates
                ))
                and (not plainBody or candidates or context.actionContext == "player" or bareContextOptIn(
                    body,
                    context.actionContext
                ))
                and not self:HasDisabledRotationDependency(body)
            then
                rotations[id] = body
            end
        end
    end

    if not ready then
        return rotations
    end

    for id, view in pairs(active.views) do
        if eligible(view, context, candidates) then
            local body = internal and active.bodies[id] or data.CopyData(active.bodies[id])
            -- Only the trusted engine receives private bodies; it must never edit.
            -- Public callers receive independent snapshots.
            rotations[runtimeKey(id, rotations)] = body
        end
    end

    return rotations
end

-- Returns one rotation for the runtime by key, or nil and a reason. Custom bodies are the live saved tables; Built In
-- bodies are copies.
function addon:GetRuntimeRotation(spec, id)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        local pass, why = scoped:RuntimePass(spec)

        if not pass then
            return nil, why
        end

        local body, bodyReason = pass:Get(id)

        if not body then
            return nil, bodyReason
        end

        local reference = scoped:Resolve(spec, id)

        if reference.kind == 'custom' then
            return scoped:GetEditableRotation(spec, reference)
        end

        return data.CopyData(body)
    end

    return self:GetRuntimeRotations(spec, true)[id]
end

-- ============================================================================
-- Cloning, sources and comparison
-- ============================================================================

-- Clones a Built In into a new custom rotation named name. With a scoped store the coordinator does it; otherwise the
-- clone is built in a temporary catalog, stored in the profile with its origin record, and registered as a clone scope.
-- Returns the new id, or nil and a reason (unknown-rotation, class-mismatch, id-collision,
-- rotation-changed-externally...).
function addon:CloneDefaultRotation(spec, id, name, options)
    local coordinator = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if coordinator then
        return coordinator:Copy(spec, { kind = 'builtin', id = id }, name, options)
    end

    local ok, why = ensure(self)

    if not ok then
        return nil, why
    end

    local profile = self.db.profile
    local roots, library = profile.rotations, profile.rotationLibrary
    local source = active.catalog:Get({ kind = "builtin", id = id })

    if not source then
        return nil, "unknown-rotation"
    end

    local context = self:GetRotationContext(spec)

    if not data.IsRotationClassToken(context.class) or not matchesClass(source, context) then
        return nil, "class-mismatch"
    end

    local state = {}
    local temporary = data.NewCatalog({ state = state, newId = self.uuid })
    assert(temporary:RegisterBuiltin(source.envelope))
    local generated, reason = temporary:Clone({ kind = "builtin", id = id }, name)

    if not generated then
        return nil, reason
    end
    if self.db.profile ~= profile or profile.rotations ~= roots or profile.rotationLibrary ~= library then
        return nil, 'rotation-changed-externally'
    end

    local rotations = self.db.profile.rotations[spec] or {}

    if rotations[generated] ~= nil then
        return nil, "id-collision"
    end

    local view = temporary:Get({ kind = "custom", id = generated })
    local manifest = view.envelope
    local body = manifest.body
    manifest.body = nil

    if manifest.applicability.universal then
        manifest.applicability.universal = nil
        manifest.applicability.class = context.class
    end

    local origins = active.state.origins[spec]

    if origins ~= nil and not plainTable(origins) then
        return nil, "invalid-origin-state"
    end

    origins = origins or {}

    if origins[generated] ~= nil then
        return nil, "id-collision"
    end

    self.db.profile.rotations[spec] = rotations
    rotations[generated] = body
    active.state.origins[spec] = origins
    origins[generated] = { manifest = manifest, lineage = view.lineage }
    local scoped = self:GetSourcedRotationView(spec, generated)
    scoped.validation = data.ValidateEnvelope(scoped.envelope, self:GetRotationValidationOptions())
    scoped.enabled = true
    active.cloneScopes[spec] = active.cloneScopes[spec] or {}
    active.cloneScopes[spec][generated] = scoped
    return generated
end

-- Returns the validated source view (envelope, lineage) of a cloned rotation, or nil and a reason (no-source-baseline
-- when it was never a clone, invalid-origin-state when the retained record is damaged).
function addon:GetSourcedRotationView(spec, id)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        return scoped:SourceView(spec, id, false)
    end

    local ok, why = ensure(self)

    if not ok then
        return nil, why
    end

    local origins = active.state.origins[spec]

    if origins == nil then
        return nil, "no-source-baseline"
    end
    if not plainTable(origins) then
        return nil, "invalid-origin-state"
    end
    if origins[id] == nil then
        return nil, "no-source-baseline"
    end

    local origin, problem = data.CopyData(origins[id])

    if problem or not plainTable(origin) or not plainTable(origin.manifest) or origin.manifest.id ~= id then
        return nil, "invalid-origin-state"
    end

    local body = self:GetEditableRotation(spec, id)

    if not body then
        return nil, "unknown-rotation"
    end

    local envelope = data.CopyData(origin.manifest)
    envelope.body = data.CopyData(body)

    if not envelope.body then
        return nil, "invalid-custom-body"
    end

    -- Catalog validates both current structure and retained historical lineage.
    local state = { custom = { [id] = envelope }, lineage = { [id] = origin.lineage } }
    local catalog, reason = data.NewCatalog({ state = state })

    if not catalog then
        return nil, reason
    end

    local view = catalog:Get({ kind = "custom", id = id })

    if view.lineageError then
        return nil, "invalid-origin-state"
    end

    return view
end

-- True when the runtime key belongs to a Built In.
function addon:IsDefaultRuntimeRotation(spec, key)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        return self:GetDefaultIdForRuntime(spec, key) ~= nil
    end
    if not ensure(self) then
        return false
    end

    local custom = (self.db.profile.rotations or {})[spec] or {}

    for id in pairs(active.views) do
        if runtimeKey(id, custom) == key then
            return true
        end
    end

    return false
end

-- Returns the Built In id behind a runtime key, or nil when the key is a custom rotation.
function addon:GetDefaultIdForRuntime(spec, key)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        local ref = scoped:Resolve(spec, key)
        return ref and ref.kind == 'builtin' and ref.id or nil
    end

    if not ensure(self) then
        return nil
    end

    local custom = (self.db.profile.rotations or {})[spec] or {}

    for id in pairs(active.views) do
        if runtimeKey(id, custom) == key then
            return id
        end
    end
end

-- Candidate identities survive level/context changes within the declared class.
-- Current eligibility is
-- always checked again by the runtime facade when switching or evaluating.
function addon:GetRotationCandidates(spec)
    return self:GetRuntimeRotations(spec, true, true)
end

-- Returns the body to use when cleaning up references to a rotation key: the custom body if there is one, else the
-- Built In runtime body.
function addon:GetRotationForCleanup(spec, key)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        return scoped:Cleanup(spec, key)
    end

    local custom = self:GetEditableRotation(spec, key)

    if custom then
        return custom
    end
    if not ensure(self) then
        return nil
    end

    local saved = self.db.profile.rotations[spec] or {}

    for id, body in pairs(active.bodies) do
        if runtimeKey(id, saved) == key then
            return body
        end
    end
end

-- Correspondence for ordinary duplicates needs only origin IDs. It must not
-- pretend an incomplete legacy body is a validated historical envelope.
function addon:GetRotationComparisonIdentity(spec, id)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        return scoped:ComparisonIdentity(spec, id)
    end
    if not ensure(self) then
        return nil, "invalid-library-state"
    end

    local rows = active.state.comparisons[spec]

    if rows ~= nil and not plainTable(rows) then
        return nil, "invalid-comparison-origin"
    end

    local identity

    if rows and rows[id] ~= nil then
        local why
        identity, why = data.CopyData(rows[id])

        if
            why
            or not plainTable(identity)
            or (identity.kind ~= "custom" and identity.kind ~= "builtin")
            or type(identity.id) ~= "string"
            or not plainTable(identity.origins)
        then
            return nil, "invalid-comparison-origin"
        end
    end

    local view, viewError = self:GetSourcedRotationView(spec, id)

    if not view and viewError ~= "no-source-baseline" then
        return nil, viewError
    end

    if view then
        if identity and (identity.kind ~= view.lineage.sourceKind or identity.id ~= view.lineage.sourceId) then
            return nil, "invalid-comparison-origin"
        end

        identity = identity or { kind = view.lineage.sourceKind, id = view.lineage.sourceId, origins = {} }

        for key, origin in pairs(view.lineage.stepOrigins) do
            identity.origins[key] = origin
        end

        return identity
    end

    if self.GetImportedRotationView then
        local imported, why = self:GetImportedRotationView(spec, id)

        if imported then
            return { kind = "import", id = imported.sourceId, origins = imported.stepOrigins }
        elseif why ~= "not-imported" then
            return nil, why
        end
    end

    return identity or { kind = "custom", id = id }
end

-- Transitional legacy editing still writes bodies directly. Duplication must use
-- a real data copy, fresh step identities, and explicitly retain source lineage.
function addon:DuplicateCustomRotation(spec, id, name, options)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        return scoped:Copy(spec, id, name, options)
    end

    local profile = self.db.profile
    local roots, library = profile.rotations, profile.rotationLibrary

    if self.GetImportedRotationView then
        local imported, reason = self:GetImportedRotationView(spec, id)

        if imported then
            local prepared = {
                body = imported.envelope.body,
                manifest = data.CopyData(imported.envelope),
                sourceId = imported.sourceId,
                sourceRevision = imported.sourceRevision,
                stepOrigins = imported.stepOrigins,
            }

            local revision, problem = data.GetRotationContentRevision(prepared.body)

            if not revision then
                return nil, problem
            end

            prepared.manifest.body = nil
            prepared.body.revision = 1

            if self.db.profile ~= profile or profile.rotations ~= roots or profile.rotationLibrary ~= library then
                return nil, 'rotation-changed-externally'
            end

            return self:CreateImportedRotation(prepared, spec, name)
        elseif reason ~= "not-imported" then
            return nil, reason
        end
    end

    local source = self:GetEditableRotation(spec, id)
    local body, problem = data.CopyData(source)

    if problem or type(body) ~= "table" then
        return nil, "invalid-custom-body"
    end

    local revision, revisionError = data.GetRotationContentRevision(body)

    if not revision then
        return nil, revisionError
    end
    if type(name) ~= "string" or name == "" then
        return nil, "invalid-name"
    end
    if self.db.profile ~= profile or profile.rotations ~= roots or profile.rotationLibrary ~= library then
        return nil, 'rotation-changed-externally'
    end

    local ok, why = ensure(self)

    if not ok then
        return nil, why
    end

    if library == nil then
        library = profile.rotationLibrary
    end

    local origins = active.state.origins[spec]

    if origins ~= nil and not plainTable(origins) then
        return nil, "invalid-origin-state"
    end

    local sourceView

    if origins and origins[id] ~= nil then
        sourceView, why = self:GetSourcedRotationView(spec, id)

        if not sourceView then
            return nil, why
        end
    end

    local identity, identityError = self:GetRotationComparisonIdentity(spec, id)

    if not identity then
        return nil, identityError
    end

    local correspondence = { kind = identity.kind, id = identity.id, origins = {} }
    local comparisonRows = active.state.comparisons[spec]

    if comparisonRows ~= nil and not plainTable(comparisonRows) then
        return nil, "invalid-comparison-origin"
    end

    local used = {}

    for _, rotations in pairs(self.db.profile.rotations) do
        if type(rotations) == "table" then
            for key, rotation in pairs(rotations) do
                used[key] = true
                data.ReserveRotationIdentities(rotation, used)
            end
        end
    end

    -- Marks a string as a taken identity.
    local function reserve(value)
        if type(value) == "string" then
            used[value] = true
        end
    end

    -- Marks an envelope's own id and every identity inside it as taken.
    local function reserveEnvelope(envelope)
        reserve(envelope.id)
        data.ReserveRotationIdentities(envelope, used)
    end

    for _, envelope in pairs(definitions) do
        reserveEnvelope(envelope)
    end

    for _, rows in pairs(active.state.origins) do
        if plainTable(rows) then
            for key, raw in pairs(rows) do
                reserve(key)
                local entry = data.CopyData(raw)
                local retained = type(entry) == "table" and entry.lineage

                if type(retained) == "table" then
                    reserve(retained.sourceId)
                    reserve(retained.clonedFrom)

                    if type(retained.baseline) == "table" then
                        reserveEnvelope(retained.baseline)
                    end

                    if type(retained.stepOrigins) == "table" then
                        for step, origin in pairs(retained.stepOrigins) do
                            reserve(step)
                            reserve(origin)
                        end
                    end
                end
            end
        end
    end

    for _, rows in pairs(active.state.comparisons) do
        if plainTable(rows) then
            for key, raw in pairs(rows) do
                reserve(key)
                local retained = data.CopyData(raw)

                if type(retained) == "table" then
                    reserve(retained.id)

                    if type(retained.origins) == "table" then
                        for step, origin in pairs(retained.origins) do
                            reserve(step)
                            reserve(origin)
                        end
                    end
                end
            end
        end
    end

    -- Returns a new identity from the id provider that is well formed and unused, or nil and invalid-id-provider or
    -- id-collision.
    local function fresh()
        local generatedOk, value = pcall(self.uuid)

        if not generatedOk or type(value) ~= "string" or #value > 128 or not value:match("^[%w][%w._:%-]*$") then
            return nil, "invalid-id-provider"
        end
        if used[value] or definitions[value] then
            return nil, "id-collision"
        end

        used[value] = true
        return value
    end

    local generated, reason = fresh()

    if not generated then
        return nil, reason
    end

    local lineage = sourceView and data.CopyData(sourceView.lineage)
    local previousOrigins = lineage and lineage.stepOrigins

    if lineage then
        lineage.clonedFrom = id
        lineage.stepOrigins = {}
    end

    local indexed, indexError = data.IndexRotationSteps(body, { allowMissingIds = true })

    if not indexed then
        return nil, indexError.code
    end

    for _, row in ipairs(indexed.rows) do
        local entry = row.step
        local stepId, errorCode = fresh()

        if not stepId then
            return nil, errorCode
        end

        if lineage then
            lineage.stepOrigins[stepId] = previousOrigins[entry.id]
        end

        correspondence.origins[stepId] = identity.origins and identity.origins[entry.id] or entry.id
        entry.id = stepId
    end

    body.name = name
    body.revision = 1
    local metadata

    if sourceView then
        local manifest = data.CopyData(sourceView.envelope)
        manifest.body = nil
        manifest.id = generated
        manifest.revision = 1
        manifest.nameKey = name
        metadata = { manifest = manifest, lineage = lineage }
    end

    if origins and origins[generated] ~= nil or comparisonRows and comparisonRows[generated] ~= nil then
        return nil, "id-collision"
    end
    if self.db.profile ~= profile or profile.rotations ~= roots or profile.rotationLibrary ~= library then
        return nil, 'rotation-changed-externally'
    end

    self.db.profile.rotations[spec][generated] = body

    if metadata then
        origins[generated] = metadata
    end

    comparisonRows = comparisonRows or {}
    active.state.comparisons[spec] = comparisonRows
    comparisonRows[generated] = correspondence
    self:InitializeRotationLibrary()
    return generated
end

-- Compares a custom rotation with a target (another custom rotation or a Built In) and returns the difference with the
-- views the comparison window shows, or nil and a reason (self-comparison, unknown-rotation,
-- missing-comparison-target...). A clone compared with its own source gets three views (current, source changes, custom
-- changes); anything else gets one.
function addon:BuildRotationComparison(spec, id, target)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        local reference, why = scoped:Resolve(spec, id)

        if not reference then
            return nil, why
        end
        if not target then
            return nil, 'missing-comparison-target'
        end

        local targetReference

        if type(target) == 'table' and target.kind == 'custom' and not target.address then
            targetReference, why = scoped:Resolve(spec, target.id)
        else
            targetReference, why = scoped:Resolve(spec, target)
        end

        if not targetReference then
            return nil, why
        end

        -- True when two rotation references name the same rotation.
        local function sameAddress(a, b)
            if a.kind ~= b.kind then
                return false
            end
            if a.kind == 'builtin' then
                return a.id == b.id
            end

            for _, key in ipairs({ 'scope', 'class', 'owner', 'spec', 'id' }) do
                if a.address[key] ~= b.address[key] then
                    return false
                end
            end

            return true
        end

        if sameAddress(reference, targetReference) then
            return nil, 'self-comparison'
        end

        local current, currentReason = scoped:Snapshot(spec, reference)

        if not current then
            return nil, currentReason
        end

        local other, targetReason = scoped:Snapshot(spec, targetReference)

        if not other then
            return nil, targetReason
        end

        local view = scoped:SourceView(spec, reference, false)

        if
            view
            and targetReference.kind == 'builtin'
            and view.lineage.sourceKind == 'builtin'
            and view.lineage.sourceId == targetReference.id
        then
            local source = other.source
            local result = data.CompareClone(view, source)

            result.views = {
                {
                    key = 'current',
                    left = data.CopyData(source.envelope),
                    right = data.CopyData(view.envelope),
                    rightOrigins = data.CopyData(view.lineage.stepOrigins),
                    diff = result.currentDifferences,
                },
                {
                    key = 'source',
                    left = data.CopyData(view.lineage.baseline),
                    right = data.CopyData(source.envelope),
                    diff = result.sourceChanges,
                },
                {
                    key = 'custom',
                    left = data.CopyData(view.lineage.baseline),
                    right = data.CopyData(view.envelope),
                    rightOrigins = data.CopyData(view.lineage.stepOrigins),
                    diff = result.customChanges,
                },
            }

            return result
        end

        local left, leftError = scoped:ComparisonIdentity(spec, targetReference)
        local right, rightError = scoped:ComparisonIdentity(spec, reference)

        if not left or not right then
            return nil, leftError or rightError
        end

        local options = {}

        local exact = left.kind == 'builtin' or left.kind == 'import' or left.kind == 'custom'
            and left.sourceAddress
            and right.sourceAddress
            and sameAddress({ kind = 'custom', address = left.sourceAddress }, {
                kind = 'custom',
                address = right.sourceAddress,
            })

        if exact and left.kind == right.kind and left.id == right.id then
            options.leftOrigins, options.rightOrigins = left.origins, right.origins
        end

        local leftValue = data.RotationComparisonValue(other.body, self:GetRotationTags(spec, targetReference))
        local rightValue = data.RotationComparisonValue(current.body, self:GetRotationTags(spec, reference))
        local result = data.DiffRotations(leftValue, rightValue, options)

        result.views = {
            {
                key = 'current',
                left = leftValue,
                right = rightValue,
                leftOrigins = data.CopyData(options.leftOrigins),
                rightOrigins = data.CopyData(options.rightOrigins),
                diff = data.CopyData(result),
            },
        }

        return result
    end

    if target and target.kind == "custom" and target.id == id then
        return nil, "self-comparison"
    end

    local body = self:GetEditableRotation(spec, id)

    if not body then
        return nil, "unknown-rotation"
    end

    local view, viewError = self:GetSourcedRotationView(spec, id)

    if not view and viewError ~= "no-source-baseline" then
        return nil, viewError
    end

    if target and target.kind == "builtin" then
        local source = self:GetDefaultRotation(target.id)

        if not source then
            return nil, "unknown-rotation"
        end

        if view and view.lineage.sourceKind == "builtin" and view.lineage.sourceId == target.id then
            local result = data.CompareClone(view, source)

            result.views = {
                {
                    key = "current",
                    left = data.CopyData(source.envelope),
                    right = data.CopyData(view.envelope),
                    rightOrigins = data.CopyData(view.lineage.stepOrigins),
                    diff = result.currentDifferences,
                },
                {
                    key = "source",
                    left = data.CopyData(view.lineage.baseline),
                    right = data.CopyData(source.envelope),
                    diff = result.sourceChanges,
                },
                {
                    key = "custom",
                    left = data.CopyData(view.lineage.baseline),
                    right = data.CopyData(view.envelope),
                    rightOrigins = data.CopyData(view.lineage.stepOrigins),
                    diff = result.customChanges,
                },
            }

            return result
        end

        local leftValue = data.RotationComparisonValue(source.envelope.body, source.envelope.tags)
        local rightValue = data.RotationComparisonValue(body, self:GetRotationTags(spec, id))
        local result = data.DiffRotations(leftValue, rightValue)
        leftValue.nameKey = source.envelope.nameKey
        result.views = { { key = "current", left = leftValue, right = rightValue, diff = data.CopyData(result) } }
        return result
    elseif target and target.kind == "custom" then
        local other = self:GetEditableRotation(spec, target.id)

        if not other then
            return nil, "unknown-rotation"
        end

        local left, leftError = self:GetRotationComparisonIdentity(spec, target.id)
        local right, rightError = self:GetRotationComparisonIdentity(spec, id)

        if not left or not right then
            return nil, leftError or rightError
        end

        local options = {}

        if left.kind == right.kind and left.id == right.id then
            options.leftOrigins, options.rightOrigins = left.origins, right.origins
        end

        local leftValue = data.RotationComparisonValue(other, self:GetRotationTags(spec, target.id))
        local rightValue = data.RotationComparisonValue(body, self:GetRotationTags(spec, id))
        local result = data.DiffRotations(leftValue, rightValue, options)

        result.views = {
            {
                key = "current",
                left = leftValue,
                right = rightValue,
                leftOrigins = data.CopyData(options.leftOrigins),
                rightOrigins = data.CopyData(options.rightOrigins),
                diff = data.CopyData(result),
            },
        }

        return result
    end

    return nil, "missing-comparison-target"
end

-- ============================================================================
-- Deleting
-- ============================================================================

-- Deletes a custom rotation and every record kept about it. Built Ins are refused (read-only-rotation). When the
-- rotation being deleted is the one currently running, it is retired first and the glows removed, guarded against a
-- newer transition at each step. Returns true, or nil and a reason.
function addon:DeleteCustomRotation(spec, id, expected)
    local change = beginActive(self)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        local reference, why = scoped:Resolve(spec, id)

        if not reference then
            return nil, why
        end
        if reference.kind == 'builtin' then
            return nil, 'read-only-rotation'
        end

        if not expected then
            local record
            record, expected = scoped:Snapshot(spec, reference)

            if not record then
                return nil, expected
            end
        end

        local currentReference = self.currentRotation
            and (self.currentSpec == nil or self.currentSpec == spec)
            and scoped:Resolve(spec, self.currentRotation)

        local deletingCurrent = currentReference and currentReference.kind == 'custom'

        if deletingCurrent then
            for _, field in ipairs({ 'scope', 'class', 'owner', 'spec', 'id' }) do
                if currentReference.address[field] ~= reference.address[field] then
                    deletingCurrent = false
                    break
                end
            end
        end

        local ok, problem = scoped:Delete(reference, expected)

        if not ok then
            return nil, problem
        end

        if deletingCurrent and activeCurrent(self, change) then
            if retireActive(self, change) and activeCurrent(self, change) then
                self.manualRotation = false
                local available = self.RemoveAllCurrentGlows

                if available and activeCurrent(self, change) then
                    local remove = self.RemoveAllCurrentGlows

                    if activeCurrent(self, change) then
                        remove(self)
                    end
                end
            end
        end

        return true
    end

    if id == (DEFAULT or L['Default']) or self:GetDefaultIdForRuntime(spec, id) then
        return nil, 'read-only-rotation'
    end

    local body = self:GetEditableRotation(spec, id)

    if type(body) ~= 'table' then
        return nil, 'unknown-rotation'
    end

    local ready, why = ensure(self)

    if not ready then
        return nil, why
    end

    for _, key in ipairs({ 'origins', 'comparisons', 'imports' }) do
        if active.state[key][spec] ~= nil and not plainTable(active.state[key][spec]) then
            return nil, 'invalid-library-state'
        end
    end

    if self.currentRotation == id and (self.currentSpec == nil or self.currentSpec == spec) and activeCurrent(
        self,
        change
    ) then
        if retireActive(self, change) and activeCurrent(self, change) then
            self.manualRotation = false
            local available = self.RemoveAllCurrentGlows

            if available and activeCurrent(self, change) then
                local remove = self.RemoveAllCurrentGlows

                if activeCurrent(self, change) then
                    remove(self)
                end
            end
        end
    end

    if not activeCurrent(self, change) then
        return nil, 'rotation-transition-superseded'
    end

    self.db.profile.rotations[spec][id] = nil

    for _, key in ipairs({ 'origins', 'comparisons', 'imports' }) do
        if active.state[key][spec] then
            active.state[key][spec][id] = nil
        end
    end

    if active.cloneScopes[spec] then
        active.cloneScopes[spec][id] = nil
    end

    return true
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
    local bind = addon.BindCPUValidationScopeDiagnostic

    if type(bind) == 'function' then
        bind(addon, 'library', ownedInitializeRotationLibrary, function() return ensure, eligible end)
    end
end
-- END PRIVATE VALIDATION CPU HANDOFF
