-- Rotation validation: pure, data-only checks of a rotation envelope or bare body (ValidateEnvelope, ValidateBody)
-- that return a result with valid, supported and resolved flags and a bounded diagnostic list, plus the small value
-- rules they share (class tokens, action contexts, identifiers, specializations, priority).
-- It must never evaluate conditions, call game APIs or touch saved data; what the current client can resolve (known
-- conditions, item sets, effects, support) is passed in through options by the caller.
-- Loaded from RotationMaster.toc after Data/codec.lua; uses data.CheckPortable, IndexRotationSteps and
-- NormalizeRotationTags. Used by the catalog, the import session and the editor. Diagnostics cap at 100.
local _, addon = ...
local data = addon.RotationData

-- ============================================================================
-- Value rules
-- ============================================================================

local families = { retail = true, era = true, progression = true, tbc = true, forever = true }
local contexts = { player = true, pet = true, vehicle = true, possession = true, override = true, petbattle = true }

local classes = {
    WARRIOR = true,
    PALADIN = true,
    HUNTER = true,
    ROGUE = true,
    PRIEST = true,
    DEATHKNIGHT = true,
    SHAMAN = true,
    MAGE = true,
    WARLOCK = true,
    MONK = true,
    DRUID = true,
    DEMONHUNTER = true,
    EVOKER = true,
}

-- Returns true for one of the thirteen upper-case class tokens (WARRIOR ... EVOKER).
function data.IsRotationClassToken(value)
    return type(value) == "string" and classes[value] == true
end

-- A rotation without a source manifest belongs to the player's own action bar.
-- It opts into a vehicle, possession, override bar or pet battle only through
-- its switch condition: an enabled ACTION_CONTEXT leaf naming that context,
-- reached through AND/OR (never under NOT). Bounded, data-only traversal.
-- Returns true when the body may run in the given context (always true for the player's own bar).
function data.MatchesBareActionContext(body, context)
    if context == "player" then
        return true
    end
    if type(body) ~= "table" or not contexts[context] then
        return false
    end

    local budget = 256

    -- Looks for an enabled ACTION_CONTEXT leaf for the context, within a budget of 256 nodes and depth 32.
    local function visit(node, depth)
        budget = budget - 1

        if budget < 0 or depth > 32 or type(node) ~= "table" or node.disabled == true then
            return false
        end
        if node.type == "ACTION_CONTEXT" then
            return node.context == context
        end

        if (node.type == "AND" or node.type == "OR") and type(node.value) == "table" then
            for _, child in ipairs(node.value) do
                if visit(child, depth + 1) then
                    return true
                end
            end
        end

        return false
    end

    return visit(body.switch, 0)
end

-- Returns true for a whole number at or above the minimum.
local function integer(value, minimum)
    return type(value) == "number" and value >= minimum and value % 1 == 0
end

-- A rotation identifier (ID): a short name for /rm set and lists. A letter,
-- then letters, digits, _ or -; at most 32 characters; compared without case
-- and stored lower-case. auto and default are reserved for /rm set.
local reservedIdentifiers = { auto = true, default = true }

-- Returns the lower-case identifier, or nil and 'invalid-identifier' / 'reserved-identifier'.
function data.NormalizeRotationIdentifier(value)
    if type(value) ~= "string" or #value < 1 or #value > 32 or not value:match("^[A-Za-z][A-Za-z0-9_%-]*$") then
        return nil, "invalid-identifier"
    end

    local id = value:lower()

    if reservedIdentifiers[id] then
        return nil, "reserved-identifier"
    end

    return id
end

-- An identifier made from a name: other characters become -, repeats collapse,
-- the ends are trimmed, and a leading digit gets an r prefix.
-- Always returns a usable identifier (at most 32 characters, never a reserved word), "rotation" for an empty name.
function data.SlugRotationIdentifier(name)
    local text = type(name) == "string" and name:lower() or ""
    text = text:gsub("[^%w_%-]+", "-"):gsub("%-%-+", "-"):gsub("^[-_]+", ""):gsub("[-_]+$", "")

    if text == "" then
        text = "rotation"
    end
    if not text:match("^%a") then
        text = "r-" .. text
    end

    text = text:sub(1, 32):gsub("[-_]+$", "")

    if reservedIdentifiers[text] then
        text = text .. "-rotation"
    end

    return text
end

-- A rotation's specializations (body.specs): the specialization values it is
-- for (Platform/specializations.lua GetRotationSpecKind says which kind),
-- at most 16, each a whole number. Absent or empty means any specialization.
-- Returns a sorted copy without duplicates, nil for "any", or false when the
-- value is malformed.
function data.NormalizeRotationSpecs(value)
    if value == nil then
        return nil
    end
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        return false
    end

    local count = 0

    for _ in pairs(value) do
        count = count + 1
    end

    if count ~= #value or count > 16 then
        return false
    end

    local seen, list = {}, {}

    for _, entry in ipairs(value) do
        if not integer(entry, 0) or entry >= 2 ^ 31 then
            return false
        end

        if not seen[entry] then
            seen[entry] = true
            list[#list + 1] = entry
        end
    end

    if #list == 0 then
        return nil
    end

    table.sort(list)
    return list
end

-- Whether a rotation restricted to `specs` applies to specialization value
-- `value`; nil (unknown) only matches an unrestricted rotation.
function data.RotationSpecsMatch(specs, value)
    if type(specs) ~= "table" or #specs == 0 then
        return true
    end
    if value == nil then
        return false
    end

    for _, entry in ipairs(specs) do
        if entry == value then
            return true
        end
    end

    return false
end

-- Returns a rotation's priority: 0 when absent, the value when it is a whole number in [-100000, 100000], otherwise
-- nil (invalid).
function data.GetRotationPriority(value)
    if value == nil then
        return 0
    end
    if integer(value, -100000) and value <= 100000 then
        return value
    end
end

-- Returns true for a non-empty string.
local function nonempty(value)
    return type(value) == "string" and #value > 0
end

-- Returns true for a valid rotation or step id: at most 128 characters, starting alphanumeric, then letters, digits
-- or . _ : -.
local function identifier(value)
    return nonempty(value) and #value <= 128 and value:match("^[%w][%w._:%-]*$") ~= nil
end

-- Returns the table's keys in a stable order (numbers first), so diagnostics come out in the same order every time.
local function sortedKeys(value)
    local keys = {}

    for key in pairs(value) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(a, b)
        if type(a) == type(b) then
            return a < b
        end

        return type(a) == "number"
    end)

    return keys
end

-- Returns true when the value is a table with only positive integer keys and no holes (an empty table counts).
local function dense(value)
    if type(value) ~= "table" then
        return false
    end

    local count, maximum = 0, 0

    for key in pairs(value) do
        if not integer(key, 1) then
            return false
        end

        count, maximum = count + 1, math.max(maximum, key)
    end

    return maximum == count
end

-- ============================================================================
-- Field schema matching
-- ============================================================================

-- Match the documented primitive/union/nested-list/record declarations without
-- invoking a live valid/evaluate callback. Missing fields are handled separately.
local matchesType, matchesTable

-- Returns true when the value is a table that fits a list schema (every element matches) or a record schema (every
-- key is declared and its value matches). Depth is capped at 32.
matchesTable = function(value, schema, depth)
    if depth > 32 or type(value) ~= "table" then
        return false
    end

    if schema[1] ~= nil then
        if not dense(value) then
            return false
        end

        for _, child in ipairs(value) do
            if not matchesType(child, schema, depth + 1) then
                return false
            end
        end
    else
        for key, child in pairs(value) do
            if schema[key] == nil or not matchesType(child, schema[key], depth + 1) then
                return false
            end
        end
    end

    return true
end

-- Returns true when the value fits a field declaration: a type name, "condition", "<type>[]", a record table or a list
-- of alternatives. Conditions only need to be tables here; their content is checked separately.
matchesType = function(value, schema, depth)
    depth = depth or 0

    if depth > 32 then
        return false
    end

    if type(schema) == "string" then
        if schema == "condition" then
            return type(value) == "table"
        end

        local base = schema:match("^(.-)%[%]$")

        if base then
            if not dense(value) then
                return false
            end

            for _, child in ipairs(value) do
                if not matchesType(child, base, depth + 1) then
                    return false
                end
            end

            return true
        end

        return type(value) == schema
    end

    if type(schema) ~= "table" then
        return false
    end
    if schema[1] == nil then
        return matchesTable(value, schema, depth + 1)
    end

    for _, alternative in ipairs(schema) do
        if type(alternative) == "table" then
            if matchesTable(value, alternative, depth + 1) then
                return true
            end
        elseif matchesType(value, alternative, depth + 1) then
            return true
        end
    end

    return false
end

-- ============================================================================
-- Envelope and body validation
-- ============================================================================

-- Validates an envelope (or, with bodyOnly, a bare body) and returns { valid, supported, resolved, diagnostics,
-- semanticStatus, executionStatus, qualityStatus }. valid is false on any error; supported is false for things this
-- version cannot represent (an unknown field, schema or format); resolved is false when a condition, item set or effect
-- is not available here. executionStatus becomes "unavailable" unless all three are true. options carries
-- conditions, support, itemsets and effects from the caller.
local function validate(envelope, options, bodyOnly)
    options = options or {}

    local result = {
        valid = true,
        supported = true,
        resolved = true,
        diagnostics = {},
        semanticStatus = "not-evaluated",
        executionStatus = "unchecked",
        qualityStatus = "unreviewed",
    }

    -- Records one diagnostic (the first 100 are kept) and updates the flags: an error clears valid, kind "unsupported"
    -- clears supported and kind "unresolved" clears resolved.
    local function issue(code, path, severity, kind, condition, reason)
        severity = severity or "error"

        if severity == "error" then
            result.valid = false
        end
        if kind == "unsupported" then
            result.supported = false
        end
        if kind == "unresolved" then
            result.resolved = false
        end
        if #result.diagnostics < 100 then
            result.diagnostics[#result.diagnostics + 1] = {
                code = code,
                path = path,
                severity = severity or "error",
                condition = condition,
                reason = reason,
            }
        end
    end

    -- Marks the result unavailable for execution when anything failed, and returns it.
    local function finish()
        if not result.valid or not result.supported or not result.resolved then
            result.executionStatus = "unavailable"
        end

        return result
    end

    local portable, why = data.CheckPortable(envelope)

    if not portable then
        issue(why.code, why.path, "error")
        return finish()
    end

    if type(envelope) ~= "table" then
        issue("expected-object", "$", "error")
        return finish()
    end

    -- Returns true for a table; otherwise records missing-field or expected-object and returns false.
    local function object(value, path)
        if type(value) == "table" then
            return true
        end

        issue(value == nil and "missing-field" or "expected-object", path, "error")
        return false
    end

    -- Returns true for a dense list. A missing optional list is just false; a missing required one, a non-table and a
    -- list with holes are recorded as errors.
    local function list(value, path, required)
        if value == nil and not required then
            return false
        end

        if value == nil then
            issue("missing-field", path, "error")
            return false
        end

        if not dense(value) then
            issue(type(value) == "table" and "sparse-list" or "expected-list", path, "error")
            return false
        end

        return true
    end

    -- Runs a predicate on a field and records missing-field or invalid-field-value when it fails.
    local function check(value, predicate, path)
        if not predicate(value) then
            issue(value == nil and "missing-field" or "invalid-field-value", path, "error")
            return false
        end

        return true
    end

    -- Warns (as unsupported, not an error) about every key of the table that is not in the allowed set, so data from a
    -- newer version still loads and is reported.
    local function unknown(value, allowed, path)
        for _, key in ipairs(sortedKeys(value)) do
            if not allowed[key] then
                issue("unknown-field", path .. "." .. key, "warning", "unsupported")
            end
        end
    end

    -- Records an error when an optional field is present with the wrong Lua type.
    local function optionalType(value, kind, path)
        if value ~= nil and type(value) ~= kind then
            issue("invalid-field-type", path, "error")
        end
    end

    if not bodyOnly then
        if envelope.format ~= "RotationMaster" then
            issue("unsupported-format", "$.format", "warning", "unsupported")
        end

        if not check(envelope.schemaVersion, function(v) return integer(v, 1) end, "$.schemaVersion") then
            return finish()
        end

        if envelope.schemaVersion ~= 1 then
            issue("unsupported-schema-version", "$.schemaVersion", "warning", "unsupported")
            return finish()
        end

        unknown(
            envelope,
            {
                format = true,
                schemaVersion = true,
                id = true,
                revision = true,
                nameKey = true,
                descriptionKey = true,
                applicability = true,
                tags = true,
                sources = true,
                body = true,
                dependencies = true,
            },
            "$"
        )

        check(envelope.id, identifier, "$.id")
        check(envelope.revision, function(v) return integer(v, 1) end, "$.revision")
        check(envelope.nameKey, nonempty, "$.nameKey")
        check(envelope.descriptionKey, nonempty, "$.descriptionKey")
        local scope = envelope.applicability

        if object(scope, "$.applicability") then
            unknown(
                scope,
                {
                    families = true,
                    actionContext = true,
                    class = true,
                    universal = true,
                    specs = true,
                    minLevel = true,
                    maxLevel = true,
                    roles = true,
                    intent = true,
                    minBuild = true,
                    maxBuild = true,
                    minExpansion = true,
                    maxExpansion = true,
                    rulesets = true,
                },
                "$.applicability"
            )

            if list(scope.families, "$.applicability.families", true) then
                if #scope.families == 0 then
                    issue("empty-edition-scope", "$.applicability.families", "error")
                end

                for i, family in ipairs(scope.families) do
                    local path = "$.applicability.families[" .. i .. "]"

                    if check(family, nonempty, path) and not families[family] then
                        issue("unknown-edition", path, "warning", "unsupported")
                    end
                end
            end

            if
                check(scope.actionContext, nonempty, "$.applicability.actionContext")
                and not contexts[scope.actionContext]
            then
                issue("unknown-action-context", "$.applicability.actionContext", "warning", "unsupported")
            end
            if
                scope.class ~= nil
                and check(scope.class, nonempty, "$.applicability.class")
                and not classes[scope.class]
            then
                issue("unknown-class", "$.applicability.class", "warning", "unsupported")
            end

            optionalType(scope.universal, "boolean", "$.applicability.universal")

            if scope.universal == true and scope.class ~= nil then
                issue("conflicting-class-scope", "$.applicability.universal", "error")
            end

            -- Expansions are LE_EXPANSION_LEVEL_CURRENT (Classic Era is 0). Build
            -- numbers are shared across products, so only this tells MoP from Wrath.
            for _, pair in ipairs({
                { "minLevel", "maxLevel", 1 },
                { "minBuild", "maxBuild", 1 },
                { "minExpansion", "maxExpansion", 0 },
            }) do
                local minimum = pair[3]

                for i = 1, 2 do
                    local key = pair[i]

                    if scope[key] ~= nil then
                        check(scope[key], function(v) return integer(v, minimum) end, "$.applicability." .. key)
                    end
                end

                if
                    integer(scope[pair[1]], minimum)
                    and integer(scope[pair[2]], minimum)
                    and scope[pair[1]] > scope[pair[2]]
                then
                    issue("inverted-range", "$.applicability." .. pair[2], "error")
                end
            end

            for _, key in ipairs({ "specs", "roles", "rulesets" }) do
                if list(scope[key], "$.applicability." .. key, false) then
                    if #scope[key] == 0 then
                        issue("empty-selector", "$.applicability." .. key, "error")
                    end

                    for i, value in ipairs(scope[key]) do
                        check(
                            value,
                            key == "specs" and function(v) return integer(v, 0) end or nonempty,
                            "$.applicability." .. key .. "[" .. i .. "]"
                        )
                    end
                end
            end

            optionalType(scope.intent, "string", "$.applicability.intent")
        end

        if envelope.tags ~= nil and not data.NormalizeRotationTags(envelope.tags) then
            issue("invalid-tags", "$.tags", "error")
        end

        if list(envelope.tags, "$.tags", false) then
            for i, tag in ipairs(envelope.tags) do
                check(tag, nonempty, "$.tags[" .. i .. "]")
            end
        end

        if list(envelope.sources, "$.sources", false) then
            for i, source in ipairs(envelope.sources) do
                local path = "$.sources[" .. i .. "]"

                if object(source, path) then
                    unknown(
                        source,
                        { url = true, title = true, reviewedAt = true, revision = true, notes = true },
                        path
                    )

                    check(
                        source.url,
                        function(v) return nonempty(v) and v:match("^https?://[^%s]+$") ~= nil end,
                        path .. ".url"
                    )

                    optionalType(source.title, "string", path .. ".title")
                    optionalType(source.reviewedAt, "string", path .. ".reviewedAt")
                    optionalType(source.revision, "string", path .. ".revision")
                    optionalType(source.notes, "string", path .. ".notes")
                end
            end
        end

        if list(envelope.dependencies, "$.dependencies", false) and #envelope.dependencies > 0 then
            issue("unsupported-dependencies", "$.dependencies", "warning", "unsupported")
        end
    end

    local condition, declaredConditions

    -- Validates the nested conditions inside a record or list value, following the schema's shape.
    local function tableConditions(value, schema, path)
        if schema[1] ~= nil then
            for i, child in ipairs(value) do
                declaredConditions(child, schema, path .. "[" .. i .. "]")
            end
        else
            for _, key in ipairs(sortedKeys(value)) do
                declaredConditions(value[key], schema[key], path .. "." .. key)
            end
        end
    end

    -- Finds the nested conditions a condition's field declares ("condition", "condition[]", or inside a record or the
    -- first union alternative that matches) and validates each one.
    declaredConditions = function(value, schema, path)
        if schema == "condition" then
            condition(value, path)
        elseif schema == "condition[]" then
            for i, child in ipairs(value) do
                condition(child, path .. "[" .. i .. "]")
            end
        elseif type(schema) == "table" then
            if schema[1] == nil then
                tableConditions(value, schema, path)
            else
                for _, alternative in ipairs(schema) do
                    if type(alternative) == "table" then
                        if matchesTable(value, alternative, 0) then
                            tableConditions(value, alternative, path)
                            return
                        end
                    elseif matchesType(value, alternative) then
                        declaredConditions(value, alternative, path)
                        return
                    end
                end
            end
        end
    end

    -- Validates one condition node. AND, OR and NOT are structural; any other type is looked up in options.conditions:
    -- an unknown, disabled, function-unavailable or client-unsupported condition is "unresolved" (a warning), its
    -- fields are type-checked against the definition, and required fields must be present.
    condition = function(value, path)
        if value == nil then
            return
        end
        if not object(value, path) then
            return
        end
        if next(value) == nil then
            return
        end
        if not check(value.type, nonempty, path .. ".type") then
            return
        end

        optionalType(value.disabled, "boolean", path .. ".disabled")

        if value.type == "AND" or value.type == "OR" or value.type == "NOT" then
            if value.name ~= nil and (type(value.name) ~= "string" or #value.name > 512 or value.name:find("%c")) then
                issue("invalid-group-name", path .. ".name", "error")
            end
        end

        if value.type == "AND" or value.type == "OR" then
            unknown(value, { type = true, disabled = true, value = true, name = true }, path)

            if list(value.value, path .. ".value", true) then
                for i, child in ipairs(value.value) do
                    condition(child, path .. ".value[" .. i .. "]")
                end
            end
        elseif value.type == "NOT" then
            unknown(value, { type = true, disabled = true, value = true, name = true }, path)

            if object(value.value, path .. ".value") then
                condition(value.value, path .. ".value")
            end
        else
            local definition = options.conditions and options.conditions[value.type]

            if type(definition) ~= "table" or type(definition.fields) ~= "table" then
                issue("unknown-condition", path .. ".type", "warning", "unresolved")
                return
            end

            if definition.disabled then
                issue('disabled-condition', path .. '.type', 'warning', 'unresolved')
            end
            if definition.functionUnavailable then
                issue('unavailable-function', path .. '.type', 'warning', 'unresolved')
            end

            -- Declared client capabilities (Core/condition_support.lua): a
            -- condition that can never work on this client is unresolved.
            local support = options.support

            if type(support) == "function" then
                local reason = support(value.type, definition, value)

                if type(reason) == "string" then
                    issue('unsupported-condition', path .. '.type', 'warning', 'unresolved', value.type, reason)
                end
            end

            for _, key in ipairs(sortedKeys(value)) do
                if key ~= "type" and key ~= "disabled" then
                    if definition.fields[key] == nil then
                        issue("unknown-field", path .. "." .. key, "warning", "unsupported")
                    elseif not matchesType(value[key], definition.fields[key]) then
                        issue("invalid-field-type", path .. "." .. key, "error")
                    else
                        declaredConditions(value[key], definition.fields[key], path .. "." .. key)
                    end
                end
            end

            for _, key in ipairs(definition.requiredFields or {}) do
                if value[key] == nil then
                    issue("missing-field", path .. "." .. key, "error")
                end
            end
        end
    end

    if not object(envelope.body, "$.body") then
        return finish()
    end

    local body = envelope.body

    unknown(
        body,
        {
            name = true,
            description = true,
            metadata = true,
            tags = true,
            revision = true,
            priority = true,
            disabled = true,
            switch = true,
            rotation = true,
            cooldowns = true,
            identifier = true,
            specs = true,
        },
        "$.body"
    )

    if data.NormalizeRotationSpecs(body.specs) == false then
        issue('invalid-specs', '$.body.specs', 'error')
    end
    if body.identifier ~= nil and data.NormalizeRotationIdentifier(body.identifier) ~= body.identifier then
        issue('invalid-identifier', '$.body.identifier', 'error')
    end
    if not data.GetRotationPriority(body.priority) then
        issue('invalid-priority', '$.body.priority', 'error')
    end
    if body.revision ~= nil then
        check(
            body.revision,
            function(v) return type(v) == "number" and v >= 1 and v <= 9007199254740991 and v % 1 == 0 end,
            "$.body.revision"
        )
    end

    optionalType(body.name, "string", "$.body.name")
    optionalType(body.description, "string", "$.body.description")

    if body.tags ~= nil and not data.NormalizeRotationTags(body.tags) then
        issue("invalid-tags", "$.body.tags", "error")
    end

    if body.metadata ~= nil and object(body.metadata, "$.body.metadata") then
        local allowed = { author = true, realm = true, email = true, website = true, version = true }
        unknown(body.metadata, allowed, "$.body.metadata")

        for key in pairs(allowed) do
            optionalType(body.metadata[key], "string", "$.body.metadata." .. key)
        end
    end

    optionalType(body.disabled, "boolean", "$.body.disabled")
    condition(body.switch, "$.body.switch")
    local rootsValid = true

    for _, key in ipairs({ "rotation", "cooldowns" }) do
        if not list(body[key], "$.body." .. key, true) then
            rootsValid = false
        end
    end

    if not rootsValid then
        return finish()
    end

    -- Pure validation preserves future branch metadata as unsupported. Runtime
    -- indexing remains strict, so these records cannot silently execute.
    local tree, problem = data.IndexRotationSteps(body, { allowUnknownBranchFields = true })

    if not tree then
        issue(problem.code, "$.body" .. problem.path:sub(2), "error")
        return finish()
    end

    for _, row in ipairs(tree.rows) do
        local step, where = row.step, "$.body"

        for _, key in ipairs(row.path) do
            where = where .. (type(key) == "number" and "[" .. key .. "]" or "." .. key)
        end

        if step.type == "branch" then
            unknown(
                step,
                { id = true, type = true, mode = true, name = true, conditions = true, onTrue = true, onFalse = true },
                where
            )

            optionalType(step.name, "string", where .. ".name")
        else
            unknown(
                step,
                {
                    id = true,
                    type = true,
                    action = true,
                    ranked = true,
                    name = true,
                    use_name = true,
                    disabled = true,
                    conditions = true,
                    suppress_attack = true,
                    effect = true,
                    color = true,
                    magnification = true,
                    setpoint = true,
                    xoffs = true,
                    yoffs = true,
                    announce = true,
                    announce_sound = true,
                    unit = true,
                },
                where
            )

            if check(step.type, nonempty, where .. ".type") then
                if step.type == "spell" or step.type == "pet" or step.type == "any" then
                    check(step.action, function(v) return integer(v, 1) end, where .. ".action")
                elseif step.type == "item" then
                    if type(step.action) == "string" then
                        if
                            check(step.action, identifier, where .. ".action")
                            and not (options.itemsets and options.itemsets[step.action])
                        then
                            issue("missing-itemset", where .. ".action", "warning", "unresolved")
                        end
                    elseif list(step.action, where .. ".action", true) then
                        if #step.action == 0 then
                            issue("empty-item-list", where .. ".action", "error")
                        end

                        for j, item in ipairs(step.action) do
                            check(
                                item,
                                function(v) return integer(v, 1) or nonempty(v) end,
                                where .. ".action[" .. j .. "]"
                            )
                        end
                    end
                elseif step.type == "assisted" then
                    -- Blizzard's Assisted Combat suggestion: the spell is read at
                    -- evaluation time, so the step names none. Rotation list only.
                    if step.action ~= nil then
                        issue("unexpected-assisted-action", where .. ".action", "warning", "unsupported")
                    end
                    if row.section ~= "rotation" then
                        issue("assisted-in-optional-list", where .. ".type", "warning", "unsupported")
                    end
                elseif step.type == "mark" then
                    -- Set Mark: a unit token and a mark word, both looked up in fixed whitelists when the step runs
                    -- (Platform/raid_mark_actions.lua). A client that cannot place marks, or a value outside the
                    -- whitelists, leaves the step unresolved: flagged and kept, never dropped. Rotation list only.
                    check(step.action, nonempty, where .. ".action")
                    check(step.unit, nonempty, where .. ".unit")
                    local stepSupport = options.stepSupport

                    if type(stepSupport) == "function" then
                        local reason = stepSupport(step)

                        if type(reason) == "string" then
                            issue("unsupported-mark-step", where .. ".type", "warning", "unresolved", nil, reason)
                        end
                    end

                    if row.section ~= "rotation" then
                        issue("mark-in-optional-list", where .. ".type", "warning", "unsupported")
                    end
                elseif step.type ~= "stop" then
                    issue("unknown-action-type", where .. ".type", "warning", "unsupported")
                end
            end

            for _, flag in ipairs({ "ranked", "use_name", "disabled" }) do
                optionalType(step[flag], "boolean", where .. "." .. flag)
            end

            optionalType(step.suppress_attack, "boolean", where .. ".suppress_attack")

            if step.unit ~= nil and step.type ~= "mark" then
                issue("unexpected-mark-option", where .. ".unit", "warning", "unsupported")
            end
            if step.suppress_attack ~= nil and step.type ~= "stop" then
                issue("unexpected-stop-option", where .. ".suppress_attack", "warning", "unsupported")
            end

            for _, label in ipairs({ "name", "effect", "setpoint", "announce", "announce_sound" }) do
                optionalType(step[label], "string", where .. "." .. label)
            end

            for _, number in ipairs({ "magnification", "xoffs", "yoffs" }) do
                optionalType(step[number], "number", where .. "." .. number)
            end

            if step.effect and not (options.effects and options.effects[step.effect]) then
                issue("missing-effect", where .. ".effect", "warning", "unresolved")
            end

            if step.color ~= nil and object(step.color, where .. ".color") then
                unknown(step.color, { r = true, g = true, b = true, a = true }, where .. ".color")

                for _, channel in ipairs({ "r", "g", "b", "a" }) do
                    check(
                        step.color[channel],
                        function(v) return type(v) == "number" and v >= 0 and v <= 1 end,
                        where .. ".color." .. channel
                    )
                end
            end
        end

        condition(step.conditions, where .. ".conditions")
    end

    return finish()
end

-- Validates a full rotation envelope (format, schema, id, revision, applicability, sources, body).
function data.ValidateEnvelope(envelope, options)
    return validate(envelope, options, false)
end

-- Validates a bare rotation body (a legacy import or an editor draft) without inventing an envelope or a scope.
function data.ValidateBody(body, options)
    return validate({ body = body }, options, true)
end
