-- Structural rotation diff: DiffRotations lists field edits and ordered step additions, removals and moves between two
-- rotation envelopes, and CompareClone builds the three-way view (baseline to source, baseline to custom, source to
-- custom) of a cloned Built In with overlapping field edits flagged for review.
-- It works on portable data only and must never mutate its inputs, evaluate conditions or merge automatically. Output
-- is bounded: 500 changes, 100 conflicts and 4096-character paths, marking the result incomplete when a limit is hit.
-- Loaded from RotationMaster.toc after Data/catalog.lua; uses data.CheckPortable, CopyData (Data/plain.lua) and
-- IndexRotationSteps (Data/rotation_tree.lua). Callers are Core/rotation_library.lua and the import session.
local _, addon = ...
local data = addon.RotationData

-- ============================================================================
-- Indexing and ordering helpers
-- ============================================================================

-- Returns a failed diff result (valid = false, no changes) carrying one error diagnostic with the code and path.
local function failure(code, path)
    return {
        valid = false,
        complete = false,
        changes = {},
        diagnostics = { { code = code, path = path or "$", severity = "error" } },
    }
end

-- Returns the union of both tables' keys in a stable order (numbers first, then by value), so diffs are deterministic.
local function keys(left, right)
    local seen, result = {}, {}

    for key in pairs(left) do
        seen[key] = true
        result[#result + 1] = key
    end

    for key in pairs(right) do
        if not seen[key] then
            result[#result + 1] = key
        end
    end

    table.sort(result, function(a, b)
        if type(a) == type(b) then
            return a < b
        end

        return type(a) == "number"
    end)

    return result
end

-- Returns true for a step id: a non-empty string of at most 128 characters that starts alphanumeric and continues
-- with letters, digits or . _ : -.
local function validId(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and value:match("^[%w][%w._:%-]*$") ~= nil
end

-- Indexes one step list by canonical id (origins maps a clone's regenerated ids to the source ids). Returns
-- { ordered, byId }, or nil, a reason code and the failing path for a non-dense list, a bad id or a duplicate id.
local function index(list, origins, path)
    if list == nil then
        list = {}
    end

    if type(list) ~= "table" then
        return nil, "invalid-priority-list", path
    end
    if origins ~= nil and type(origins) ~= "table" then
        return nil, "invalid-origin-map", path
    end

    local count, maximum = 0, 0

    for key in pairs(list) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return nil, "invalid-priority-list", path
        end

        count, maximum = count + 1, math.max(maximum, key)
    end

    if maximum ~= count then
        return nil, "invalid-priority-list", path
    end

    local result = { ordered = {}, byId = {} }

    for i, step in ipairs(list) do
        if type(step) ~= "table" or not validId(step.id) then
            return nil, "ambiguous-step-identity", path .. "[" .. i .. "]"
        end

        local canonical = origins and origins[step.id] or step.id

        if not validId(canonical) or result.byId[canonical] then
            return nil, "ambiguous-step-identity", path .. "[" .. i .. "]"
        end

        local entry = { id = canonical, index = i, value = step }
        result.ordered[#result.ordered + 1] = entry
        result.byId[canonical] = entry
    end

    return result
end

-- Unique IDs reduce the common subsequence problem to a longest increasing
-- subsequence of original positions: bounded O(n log n), no n-by-n matrix.
-- Returns the set of ids that keep their relative order between the two indexed lists; every other shared id is
-- reported as moved.
local function stationary(left, right)
    local sequence = {}

    for _, entry in ipairs(right.ordered) do
        local original = left.byId[entry.id]

        if original then
            sequence[#sequence + 1] = { id = entry.id, position = original.index }
        end
    end

    local tails, tailIndices, previous = {}, {}, {}

    for i, entry in ipairs(sequence) do
        local low, high = 1, #tails

        while low <= high do
            local middle = math.floor((low + high) / 2)

            if tails[middle] < entry.position then
                low = middle + 1
            else
                high = middle - 1
            end
        end

        previous[i] = tailIndices[low - 1]
        tails[low], tailIndices[low] = entry.position, i
    end

    local result, cursor = {}, tailIndices[#tails]

    while cursor do
        result[sequence[cursor].id] = true
        cursor = previous[cursor]
    end

    return result
end

-- Structural segments drive list dispatch and ancestry. Rendered text is only
-- for display: a literal dotted key must never impersonate a nested field.
-- Returns a copy of the segment list with one more { kind, key } segment appended.
local function child(segments, kind, key)
    local result = {}

    for i, segment in ipairs(segments) do
        result[i] = segment
    end

    result[#result + 1] = { kind = kind, key = key }
    return result
end

-- Renders one key as a display path suffix: [n] for numbers, .name for identifiers, ["quoted"] otherwise.
local function fieldSuffix(key)
    if type(key) == "number" then
        return "[" .. key .. "]"
    end
    if key:match("^[%a_][%w_]*$") then
        return "." .. key
    end

    return "[" .. string.format("%q", key) .. "]"
end

-- Returns true when segment list a is a strict prefix of b (a change to a contains a change to b).
local function ancestor(a, b)
    if #a >= #b then
        return false
    end

    for i, segment in ipairs(a) do
        if segment.kind ~= b[i].kind or segment.key ~= b[i].key then
            return false
        end
    end

    return true
end

-- ============================================================================
-- Rotation diff
-- ============================================================================

-- Compares two rotation envelopes and returns { valid, complete, changes, diagnostics }. Each change has kind
-- (added, removed, changed or moved), a display path, structural segments and detached before/after values. options
-- may carry leftOrigins / rightOrigins (id maps for clones) and ignoreIdentity (skip root id and revision). Returns a
-- failed result for non-portable data or ambiguous step identity.
function data.DiffRotations(left, right, options)
    options = options or {}

    for _, value in ipairs({ left, right }) do
        local ok, why = data.CheckPortable(value)

        if not ok then
            return failure(why.code, why.path)
        end
        if type(value) ~= "table" then
            return failure("expected-rotation-object")
        end
    end

    if left == nil or right == nil then
        return failure("expected-rotation-object")
    end

    local lists = { left = {}, right = {} }
    local empty = index(nil, nil, "$")

    for _, side in ipairs({ "left", "right" }) do
        local envelope = side == "left" and left or right
        local origins = options[side .. "Origins"]

        if not data.CheckPortable(origins) or origins ~= nil and type(origins) ~= "table" then
            return failure("invalid-origin-map")
        end

        local body = type(envelope.body) == "table" and envelope.body or {}

        -- Keep the established diagnostics for malformed flat priority lists.
        for _, kind in ipairs({ "rotation", "cooldowns" }) do
            local indexed, code, path = index(body[kind], origins, "$.body." .. kind)

            if not indexed then
                return failure(code, path)
            end
        end

        local tree, problem = data.IndexRotationSteps(body)

        if not tree then
            local code = problem.code

            if code == "duplicate-step-id" or code == "invalid-step-id" then
                code = "ambiguous-step-identity"
            end

            return failure(code, problem.path)
        end

        local used = {}

        for _, list in ipairs(tree.lists) do
            local indexed, code, path = index(list.list, origins, "$.body")

            if not indexed then
                return failure(code, path)
            end

            for _, entry in ipairs(indexed.ordered) do
                if used[entry.id] then
                    return failure("ambiguous-step-identity", "$.body")
                end

                used[entry.id] = true
            end

            lists[side][list.list] = indexed
        end
    end

    local result = { valid = true, complete = true, changes = {}, diagnostics = {} }
    local limits = {}

    -- Marks the result incomplete and records one warning per limit code.
    local function limited(code)
        result.complete = false

        if not limits[code] then
            limits[code] = true
            result.diagnostics[#result.diagnostics + 1] = { code = code, path = "$", severity = "warning" }
        end
    end

    -- Appends one change with detached copies of its values, or records a limit warning when the path or change count
    -- is over the cap.
    local function emit(kind, path, segments, before, after, extra)
        if #path > 4096 then
            limited("diff-path-limit")
            return
        end

        if #result.changes >= 500 then
            limited("diff-change-limit")
            return
        end

        local change = { kind = kind, path = path, segments = data.CopyData(segments) }

        if before ~= nil then
            change.before = data.CopyData(before)
        end
        if after ~= nil then
            change.after = data.CopyData(after)
        end

        for key, value in pairs(extra or {}) do
            change[key] = value
        end

        result.changes[#result.changes + 1] = change
    end

    local walk

    -- Diffs two ordered step lists by id: removed steps first, then added and moved steps in the new order, recursing
    -- into every step present on both sides.
    local function priorities(leftList, rightList, path, segments)
        local a, b = lists.left[leftList] or empty, lists.right[rightList] or empty
        local stable = stationary(a, b)

        for _, entry in ipairs(a.ordered) do
            if not b.byId[entry.id] then
                emit("removed", path .. "[" .. entry.id .. "]", child(segments, "step", entry.id), entry.value, nil, {
                    stepId = entry.id,
                    fromIndex = entry.index,
                })
            end
        end

        for _, entry in ipairs(b.ordered) do
            local original = a.byId[entry.id]
            local where = path .. "[" .. entry.id .. "]"
            local location = child(segments, "step", entry.id)

            if not original then
                emit("added", where, location, nil, entry.value, { stepId = entry.id, toIndex = entry.index })
            else
                if not stable[entry.id] then
                    emit("moved", where, location, nil, nil, {
                        stepId = entry.id,
                        fromIndex = original.index,
                        toIndex = entry.index,
                    })
                end

                walk(original.value, entry.value, where, location, true)
            end
        end
    end

    -- Recursively compares two values at a path. The body's rotation and cooldowns lists and a Branch's onTrue/onFalse
    -- lists go through the id-based list diff; step is true for a step table, whose own id is not a change.
    walk = function(a, b, path, segments, step)
        if #path > 4096 then
            limited("diff-path-limit")
            return
        end

        if a == b then
            return
        end

        if
            #segments == 2
            and segments[1].kind == "field"
            and segments[1].key == "body"
            and segments[2].kind == "field"
            and (segments[2].key == "rotation" or segments[2].key == "cooldowns")
        then
            priorities(a, b, path, segments)
            return
        end

        if type(a) ~= "table" or type(b) ~= "table" then
            emit(a == nil and "added" or b == nil and "removed" or "changed", path, segments, a, b)
            return
        end

        for _, key in ipairs(keys(a, b)) do
            if
                not (step and key == "id")
                and not (#segments == 0 and options.ignoreIdentity and (key == "id" or key == "revision"))
                and not (#segments == 1
                    and segments[1].kind == "field"
                    and segments[1].key == "body"
                    and key == "revision")
            then
                local where, location = path .. fieldSuffix(key), child(segments, "field", key)

                if step and (a.type == "branch" or b.type == "branch") and (key == "onTrue" or key == "onFalse") then
                    priorities(a[key], b[key], where, location)
                else
                    walk(a[key], b[key], where, location, false)
                end
            end
        end
    end

    walk(left, right, "$", {}, false)
    return result
end

-- Deep structural equality over plain data (tables compare by content, using the stable key union).
local function equal(a, b)
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end

    for _, key in ipairs(keys(a, b)) do
        if not equal(a[key], b[key]) then
            return false
        end
    end

    return true
end

-- ============================================================================
-- Clone comparison
-- ============================================================================

-- Three-way comparison of a cloned Built In. clone carries envelope and lineage (baseline, step origins, source
-- identity); source carries envelope and reference. Returns sourceChanges, customChanges, currentDifferences and the
-- conflicts (changes that touch the same path or an ancestor on both sides), or a failed result when the lineage does
-- not match the source. Highlights overlaps only; it never merges.
function data.CompareClone(clone, source)
    if type(clone) ~= "table" or type(source) ~= "table" or getmetatable(clone) or getmetatable(source) then
        return failure("invalid-comparison-view")
    end

    for _, view in ipairs({ clone, source }) do
        local ok, why = data.CheckPortable(view.envelope)

        if not ok then
            return failure(why.code, why.path)
        end
        if type(view.envelope) ~= "table" then
            return failure("expected-rotation-object")
        end
    end

    local lineage, problem = data.CopyData(clone.lineage)

    if
        problem or type(lineage) ~= "table" or type(lineage.baseline) ~= "table" or type(lineage.stepOrigins) ~= "table"
    then
        return failure("invalid-lineage")
    end

    local reference = source.reference

    if
        type(reference) ~= "table"
        or getmetatable(reference)
        or reference.kind ~= lineage.sourceKind
        or reference.id ~= lineage.sourceId
        or source.envelope.id ~= lineage.sourceId
    then
        return failure("source-lineage-mismatch")
    end
    if lineage.baseline.id ~= lineage.sourceId or lineage.baseline.revision ~= lineage.sourceRevision then
        return failure("invalid-lineage")
    end

    local fromSource = data.DiffRotations(lineage.baseline, source.envelope, { ignoreIdentity = true })

    local fromCustom = data.DiffRotations(lineage.baseline, clone.envelope, {
        rightOrigins = lineage.stepOrigins,
        ignoreIdentity = true,
    })

    local current = data.DiffRotations(source.envelope, clone.envelope, {
        rightOrigins = lineage.stepOrigins,
        ignoreIdentity = true,
    })

    local result = {
        valid = fromSource.valid and fromCustom.valid and current.valid,
        complete = fromSource.complete and fromCustom.complete and current.complete,
        sourceChanges = fromSource,
        customChanges = fromCustom,
        currentDifferences = current,
        conflicts = {},
        conflictCoverage = "field-edits",
        diagnostics = {},
    }

    -- Highlight overlapping field edits for review. Ordered changes remain
    -- explicit in all three diffs; this is not an automatic merge algorithm.
    for _, a in ipairs(fromSource.changes) do
        for _, b in ipairs(fromCustom.changes) do
            local conflict = false

            if a.kind ~= "moved" and b.kind ~= "moved" then
                if a.path == b.path then
                    conflict = a.kind ~= b.kind or not equal(a.after, b.after)
                elseif ancestor(a.segments, b.segments) or ancestor(b.segments, a.segments) then
                    conflict = true
                end
            end

            if conflict then
                if #result.conflicts >= 100 then
                    result.complete = false

                    if #result.diagnostics == 0 then
                        result.diagnostics[1] = { code = "conflict-limit", path = "$", severity = "warning" }
                    end
                else
                    result.conflicts[#result.conflicts + 1] = {
                        path = a.path,
                        source = data.CopyData(a),
                        custom = data.CopyData(b),
                    }
                end
            end
        end
    end

    return result
end
