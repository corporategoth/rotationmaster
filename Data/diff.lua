-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

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

-- Builds a failed diff result.
-- @param code string  The diagnostic code.
-- @param path string|nil  The path of the failure; "$" when missing.
-- @return table  A result with valid = false, no changes and one error diagnostic carrying the code and path.
local function failure(code, path)
    return {
        valid = false,
        complete = false,
        changes = {},
        diagnostics = { { code = code, path = path or "$", severity = "error" } },
    }
end

-- Lists the union of both tables' keys in a stable order, so diffs are deterministic.
-- @param left table  The first table.
-- @param right table  The second table.
-- @return table  The keys: numbers first, then by value.
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

-- Whether a value is a valid step id.
-- @param value any  The value to test.
-- @return boolean  True for a non-empty string of at most 128 characters that starts alphanumeric and continues with
--   letters, digits or . _ : -.
local function validId(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and value:match("^[%w][%w._:%-]*$") ~= nil
end

-- Indexes one step list by canonical id.
-- @param list table|nil  The step list; nil is an empty list.
-- @param origins table|nil  Maps a clone's regenerated ids to the source ids.
-- @param path string  The display path of the list, used in failure paths.
-- @return table|nil  { ordered, byId }; nil for a non-dense list, a bad id or a duplicate id.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
-- @return string|nil  The failing path when the first return is nil; nil otherwise.
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

-- Finds the steps that keep their relative order between two indexed lists.
-- @param left table  The indexed left list, as built by index.
-- @param right table  The indexed right list, as built by index.
-- @return table  The set of ids (id -> true) that keep their relative order; every other shared id is reported as
--   moved.
--
-- Unique ids reduce the common subsequence problem to a longest increasing subsequence of original positions: bounded
-- O(n log n), no n-by-n matrix.
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

-- Appends one segment to a segment list.
-- @param segments table[]  The segment list.
-- @param kind string  The kind of the new segment ("field" or "step").
-- @param key any  The key of the new segment.
-- @return table[]  A copy of the segment list with one more { kind, key } segment appended.
--
-- Structural segments drive list dispatch and ancestry. Rendered text is only for display: a literal dotted key must
-- never impersonate a nested field.
local function child(segments, kind, key)
    local result = {}

    for i, segment in ipairs(segments) do
        result[i] = segment
    end

    result[#result + 1] = { kind = kind, key = key }
    return result
end

-- Renders one key as a display path suffix.
-- @param key number|string  The key.
-- @return string  [n] for numbers, .name for identifiers, ["quoted"] otherwise.
local function fieldSuffix(key)
    if type(key) == "number" then
        return "[" .. key .. "]"
    end
    if key:match("^[%a_][%w_]*$") then
        return "." .. key
    end

    return "[" .. string.format("%q", key) .. "]"
end

-- Whether a segment list is a strict prefix of another (a change to a contains a change to b).
-- @param a table[]  The possible ancestor's segments.
-- @param b table[]  The possible descendant's segments.
-- @return boolean  True when a is a strict prefix of b.
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

-- Compares two rotation envelopes.
-- @param left table  The left envelope.
-- @param right table  The right envelope.
-- @param options table|nil  { leftOrigins, rightOrigins (id maps for clones), ignoreIdentity (skip root id and
--   revision) }.
-- @return table  { valid, complete, changes, diagnostics }. Each change has kind (added, removed, changed or moved), a
--   display path, structural segments and detached before/after values. A failed result for non-portable data or
--   ambiguous step identity.
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
    -- @param code string  The limit code.
    local function limited(code)
        result.complete = false

        if not limits[code] then
            limits[code] = true
            result.diagnostics[#result.diagnostics + 1] = { code = code, path = "$", severity = "warning" }
        end
    end

    -- Appends one change with detached copies of its values.
    -- @param kind string  The change kind: added, removed, changed or moved.
    -- @param path string  The display path.
    -- @param segments table[]  The structural segments.
    -- @param before any  The value before; nil if none.
    -- @param after any  The value after; nil if none.
    -- @param extra table|nil  Further fields merged into the change.
    --
    -- Records a limit warning instead when the path or change count is over the cap.
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

    -- Diffs two ordered step lists by id.
    -- @param leftList table|nil  The left step list.
    -- @param rightList table|nil  The right step list.
    -- @param path string  The display path of the list.
    -- @param segments table[]  The structural segments of the list.
    --
    -- Emits removed steps first, then added and moved steps in the new order, recursing into every step present on both
    -- sides.
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

    -- Recursively compares two values at a path.
    -- @param a any  The left value.
    -- @param b any  The right value.
    -- @param path string  The display path.
    -- @param segments table[]  The structural segments.
    -- @param step boolean  True for a step table, whose own id is not a change.
    --
    -- The body's rotation and cooldowns lists and a Branch's onTrue/onFalse lists go through the id-based list diff.
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

-- Deep structural equality over plain data.
-- @param a any  The first value.
-- @param b any  The second value.
-- @return boolean  True when equal (tables compare by content, using the stable key union).
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

-- Compares a cloned Built In three ways: baseline to source, baseline to custom and source to custom.
-- @param clone table  { envelope, lineage (baseline, step origins, source identity) }.
-- @param source table  { envelope, reference }.
-- @return table  { valid, complete, sourceChanges, customChanges, currentDifferences, conflicts, conflictCoverage,
--   diagnostics }, where conflicts are the changes that touch the same path or an ancestor on both sides; a failed
--   result when the lineage does not match the source.
--
-- Highlights overlaps only; it never merges.
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
