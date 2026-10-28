-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Condition draft: an in-memory editable copy of one condition tree with a command interface (Replace, Wrap, Unwrap,
-- Add, Remove, Move, Group/Negate/Duplicate/Remove/Transfer on a selection, Rows, ...) for the condition editor.
-- Every command runs as one transaction on a detached copy and replaces the tree only when the result is still a valid
-- tree (4096 nodes, depth 64), so a failed edit leaves the draft untouched and each success is one undo step.
-- Nodes are addressed by paths of field names and list indexes. It must not evaluate conditions, read saved data or
-- keep references to the caller's tables.
-- Loaded from RotationMaster.toc after Data/tags.lua and before Data/rotation_draft.lua; uses data.CheckPortable
-- (Data/plain.lua). The field schemas come from the condition definitions passed to NewConditionDraft.
local _, addon = ...
local data = addon.RotationData

-- ============================================================================
-- Tree helpers
-- ============================================================================

-- Deep copies a portable condition tree.
-- @param value any  The condition tree.
-- @return table|nil  The deep copy; nil when the tree is not portable.
-- @return string|nil  The portability error code when the first return is nil; nil otherwise.
local function copy(value)
    local ok, why = data.CheckPortable(value)

    if not ok then
        return nil, why.code
    end

    -- Copies a value recursively.
    -- @param current any  The value to copy.
    -- @return any  The copy of a table; any other value as it is.
    --
    -- A condition tree has independent operands, even if its source reused a table. Portable checking bounds the total
    -- traversal before copying.
    local function visit(current)
        if type(current) ~= "table" then
            return current
        end

        local result = {}

        for key, child in pairs(current) do
            result[key] = visit(child)
        end

        return result
    end

    return visit(value)
end

-- Copies a path list, so a stored path is never altered by later edits to the original.
-- @param path table  The path.
-- @return table  The copy.
local function pathCopy(path)
    local result = {}

    for index, part in ipairs(path) do
        result[index] = part
    end

    return result
end

-- Whether a table is a dense list: only positive integer keys with no holes.
-- @param list any  The value to test.
-- @return boolean  True for such a table (an empty table counts).
local function dense(list)
    if type(list) ~= "table" then
        return false
    end

    local count, maximum = 0, 0

    for key in pairs(list) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end

        count = count + 1
        maximum = math.max(maximum, key)
    end

    return count == maximum
end

-- Extracts which fields of each condition tag hold nested conditions.
-- @param definitions table|nil  The registered condition definitions, keyed by tag.
-- @return table  tag -> { field -> "condition" | "condition[]" }.
--
-- Reads the raw field so a definition's metatable is never invoked.
local function schemas(definitions)
    local result = {}

    for tag, definition in pairs(definitions or {}) do
        local fields = type(definition) == "table" and rawget(definition, "fields")

        if type(tag) == "string" and type(fields) == "table" then
            result[tag] = {}

            for field, kind in pairs(fields) do
                if type(field) == "string" and (kind == "condition" or kind == "condition[]") then
                    result[tag][field] = kind
                end
            end
        end
    end

    return result
end

-- ============================================================================
-- Draft
-- ============================================================================

-- Creates a draft from a portable condition tree.
-- @param original table  The condition tree.
-- @param definitions table|nil  Maps condition tags to their definitions, so nested condition fields are known.
-- @return table|nil  The draft object; nil when the tree is not valid.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function data.NewConditionDraft(original, definitions)
    local root, reason = copy(original)

    if root == nil then
        return nil, reason or "invalid-condition"
    end
    if type(root) ~= "table" then
        return nil, "invalid-condition"
    end

    local declarations = schemas(definitions)

    -- Lists the child nodes of a node as edges.
    -- @param node any  The condition node.
    -- @return table[]|nil  The edges { node, parts, container, key, relation }: AND/OR children in their list, the NOT
    --   operand, and the nested-condition fields the node's definition declares (in sorted field order). nil for a
    --   malformed node.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    local function edges(node)
        if type(node) ~= "table" then
            return nil, "invalid-condition"
        end
        if node.type ~= nil and type(node.type) ~= "string" then
            return nil, "invalid-condition-type"
        end

        local result = {}

        -- Adds the edges of one nested-condition field of the node (a single child or a list) to the result.
        -- @param name string  The field name.
        -- @param kind string  "condition" or "condition[]".
        -- @return boolean|nil  True when added; nil for a malformed list.
        -- @return string|nil  The reason code when the first return is nil; nil otherwise.
        local function field(name, kind)
            local value = node[name]

            if value == nil then
                return true
            end

            if kind == "condition[]" then
                if not dense(value) then
                    return nil, "invalid-condition-list"
                end

                for index, child in ipairs(value) do
                    result[#result + 1] = {
                        node = child,
                        parts = { name, index },
                        container = value,
                        key = index,
                        relation = "list",
                    }
                end
            else
                result[#result + 1] = {
                    node = value,
                    parts = { name },
                    container = node,
                    key = name,
                    relation = "single",
                }
            end

            return true
        end

        if node.type == "AND" or node.type == "OR" then
            local ok, why = field("value", "condition[]")

            if not ok then
                return nil, why
            end
        elseif node.type == "NOT" then
            field("value", "condition")
        else
            local fields = declarations[node.type] or {}
            local names = {}

            for name in pairs(fields) do
                names[#names + 1] = name
            end

            table.sort(names)

            for _, name in ipairs(names) do
                local ok, why = field(name, fields[name])

                if not ok then
                    return nil, why
                end
            end
        end

        return result
    end

    -- Validates a whole candidate tree.
    -- @param candidate table  The tree.
    -- @return boolean|nil  True when valid; nil otherwise.
    -- @return string|nil  'condition-limit' (beyond 4096 nodes or depth 64) or a structural error from edges, when the
    --   first return is nil; nil otherwise.
    local function validate(candidate)
        local count = 0

        -- Counts and checks one node and everything below it.
        -- @param node any  The node.
        -- @param depth number  The nesting depth.
        -- @return boolean|nil  True when valid; nil otherwise.
        -- @return string|nil  The reason code when the first return is nil; nil otherwise.
        local function visit(node, depth)
            count = count + 1

            if count > 4096 or depth > 64 then
                return nil, "condition-limit"
            end

            local children, why = edges(node)

            if not children then
                return nil, why
            end

            for _, edge in ipairs(children) do
                local ok, errorCode = visit(edge.node, depth + 1)

                if not ok then
                    return nil, errorCode
                end
            end

            return true
        end

        return visit(candidate, 0)
    end

    local valid, why = validate(root)

    if not valid then
        return nil, why
    end

    -- Follows a path of field names and indexes from the root.
    -- @param candidate table  The tree.
    -- @param path table  The path.
    -- @return table|nil  The node found; nil when the path is invalid.
    -- @return table|nil  The container that holds the node.
    -- @return any  The key of the node in its container.
    -- @return string|nil  The relation: "root", "list" or "single".
    -- @return string|nil  'invalid-condition-path' when the node was not found; nil otherwise.
    local function resolve(candidate, path)
        if type(path) ~= "table" or not data.CheckPortable(path) or not dense(path) or #path > 128 then
            return nil, nil, nil, nil, "invalid-condition-path"
        end

        local node, container, key, relation = candidate, nil, nil, "root"
        local offset = 1

        while offset <= #path do
            local children = edges(node)
            local matched

            for _, edge in ipairs(children) do
                local same = true

                for index, part in ipairs(edge.parts) do
                    if path[offset + index - 1] ~= part then
                        same = false
                        break
                    end
                end

                if same then
                    matched = edge
                    break
                end
            end

            if not matched then
                return nil, nil, nil, nil, "invalid-condition-path"
            end

            node, container, key, relation = matched.node, matched.container, matched.key, matched.relation
            offset = offset + #matched.parts
        end

        return node, container, key, relation
    end

    -- Runs an edit on a detached copy of the tree.
    -- @param operation function  Takes the candidate tree and returns the changed tree (and optionally a reason and a
    --   selection result).
    -- @return boolean|nil  True when the edit was committed; nil with the draft unchanged on failure.
    -- @return any  The selection result of the operation; the reason code when the first return is nil.
    --
    -- The tree is copied again, validated and only then becomes the draft's root.
    local function transaction(operation)
        local candidate = assert(copy(root))
        local changed, problem, selection = operation(candidate)

        if not changed then
            return nil, problem
        end

        local checked, copyError = copy(changed)

        if not checked then
            return nil, copyError
        end

        local ok, shapeError = validate(checked)

        if not ok then
            return nil, shapeError
        end

        root = checked
        return true, selection
    end

    -- Runs a transaction on the node at a path: resolves it in the candidate and hands its position to the operation.
    -- @param path table  The path of the node.
    -- @param operation function  Called with node, container, key, relation and the candidate tree.
    -- @return boolean|nil  True when committed; nil on failure.
    -- @return any  The selection result; the reason code when the first return is nil.
    local function edit(path, operation)
        return transaction(function(candidate)
            local node, container, key, relation, errorCode = resolve(candidate, path)

            if not node then
                return nil, errorCode
            end

            return operation(node, container, key, relation, candidate)
        end)
    end

    -- Puts a value where a node was.
    -- @param container table|nil  The container of the node; nil for the root.
    -- @param key any  The key of the node in its container.
    -- @param value table  The new node.
    -- @param candidate table  The candidate tree.
    -- @return table  The new tree: the value itself for the root, otherwise the candidate with the slot updated.
    local function replace(container, key, value, candidate)
        if not container then
            return value
        end

        container[key] = value
        return candidate
    end

    local draft = {}

    -- Returns a detached copy of the current tree.
    -- @return table|nil  The copy.
    function draft:Snapshot()
        return copy(root)
    end

    -- Replaces the node at the path with a copy of the given condition table.
    -- @param path table  The path of the node.
    -- @param value table  The new condition.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    function draft:Replace(path, value)
        local replacement, errorCode = copy(value)

        if replacement == nil then
            return nil, errorCode or "invalid-condition"
        end
        if type(replacement) ~= "table" then
            return nil, "invalid-condition"
        end

        return edit(path, function(_, container, key, _, candidate)
            return replace(container, key, replacement, candidate)
        end)
    end

    -- Wraps the node at the path in an AND, OR or NOT group.
    -- @param path table  The path of the node.
    -- @param kind string  "AND", "OR" or "NOT".
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    function draft:Wrap(path, kind)
        if kind ~= "AND" and kind ~= "OR" and kind ~= "NOT" then
            return nil, "invalid-condition-group"
        end

        return edit(path, function(node, container, key, _, candidate)
            local wrapper = { type = kind, value = kind == "NOT" and node or { node } }
            return replace(container, key, wrapper, candidate)
        end)
    end

    -- Replaces a group with its contents.
    -- @param path table  The path of the group.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- A NOT or single-child group becomes its child; a multi-child AND/OR is spliced into a parent list of the same
    -- kind, and is refused as ambiguous anywhere else.
    function draft:Unwrap(path)
        return edit(path, function(node, container, key, relation, candidate)
            local child

            if node.type == "NOT" then
                child = node.value or {}
            elseif node.type == "AND" or node.type == "OR" then
                local values = node.value or {}

                if #values > 1 then
                    local parent = pathCopy(path)
                    table.remove(parent)
                    table.remove(parent)
                    local owner = resolve(candidate, parent)

                    if relation ~= "list" or not owner or owner.type ~= node.type then
                        return nil, "ambiguous-group-unwrapping"
                    end

                    table.remove(container, key)

                    for index = #values, 1, -1 do
                        table.insert(container, key, values[index])
                    end

                    return candidate
                end

                child = values[1] or {}
            else
                return nil, "not-a-condition-group"
            end

            return replace(container, key, child, candidate)
        end)
    end

    -- Adds a condition into the group at the path.
    -- @param path table  The path of the group.
    -- @param value table|nil  The condition to add; an empty one by default.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- An empty node or empty NOT is filled instead. Anything else is refused as 'not-an-empty-condition-group'.
    function draft:Add(path, value)
        if value == nil then
            value = {}
        end

        local child, errorCode = copy(value)

        if child == nil then
            return nil, errorCode or "invalid-condition"
        end
        if type(child) ~= "table" then
            return nil, "invalid-condition"
        end

        return edit(path, function(node, container, key, _, candidate)
            if node.type == "AND" or node.type == "OR" then
                node.value = node.value or {}
                table.insert(node.value, child)
            elseif node.type == "NOT" and (not node.value or next(node.value) == nil) then
                node.value = child
            elseif node.type == nil and next(node) == nil then
                return replace(container, key, child, candidate)
            else
                return nil, "not-an-empty-condition-group"
            end

            return candidate
        end)
    end

    -- Removes the node at the path.
    -- @param path table  The path of the node.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- Removed out of its list, or emptied (an empty condition) when it fills a single slot.
    function draft:Remove(path)
        return edit(path, function(_, container, key, relation, candidate)
            if relation == "list" then
                table.remove(container, key)
            elseif container then
                container[key] = {}
            else
                return {}
            end

            return candidate
        end)
    end

    -- Moves a list entry one place up or down within its group.
    -- @param path table  The path of the entry.
    -- @param delta number  -1 (up) or 1 (down).
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    function draft:Move(path, delta)
        if delta ~= -1 and delta ~= 1 then
            return nil, "invalid-condition-move"
        end

        return edit(path, function(_, container, key, relation, candidate)
            if relation ~= "list" or key + delta < 1 or key + delta > #container then
                return nil, "invalid-condition-move"
            end

            container[key], container[key + delta] = container[key + delta], container[key]
            return candidate
        end)
    end

    -- Sets or clears the disabled flag on exactly the node at the path.
    -- @param path table  The path of the node.
    -- @param disabled boolean  True to disable; false to clear the flag.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    function draft:SetDisabled(path, disabled)
        if type(disabled) ~= "boolean" then
            return nil, "invalid-disabled-flag"
        end

        return edit(path, function(node, _, _, _, candidate)
            node.disabled = disabled or nil
            return candidate
        end)
    end

    -- Whether one path is a prefix of (or equal to) another, i.e. left contains right.
    -- @param left table  The possible prefix path.
    -- @param right table  The other path.
    -- @return boolean  True when left is a prefix of right.
    local function prefix(left, right)
        if #left > #right then
            return false
        end

        for i, part in ipairs(left) do
            if right[i] ~= part then
                return false
            end
        end

        return true
    end

    -- Resolves a selection in the candidate.
    -- @param candidate table  The tree.
    -- @param paths table  A dense list of up to 4096 paths.
    -- @return table[]|nil  The records { node, container, key, relation, path } in document order; nil on failure.
    -- @return string|nil  The reason code when the first return is nil; overlapping selections (one inside another) are
    --   refused; nil otherwise.
    local function selected(candidate, paths)
        if not data.CheckPortable(paths) or not dense(paths) or #paths == 0 or #paths > 4096 then
            return nil, "invalid-condition-selection"
        end

        local result = {}

        for _, path in ipairs(paths) do
            local node, container, key, relation, why = resolve(candidate, path)

            if not node then
                return nil, why
            end

            for _, other in ipairs(result) do
                if prefix(path, other.path) or prefix(other.path, path) then
                    return nil, "overlapping-condition-selection"
                end
            end

            result[#result + 1] = {
                node = node,
                container = container,
                key = key,
                relation = relation,
                path = pathCopy(path),
            }
        end

        table.sort(result, function(a, b)
            for i, part in ipairs(a.path) do
                local other = b.path[i]

                if part ~= other then
                    if type(part) == type(other) then
                        return part < other
                    end

                    return type(part) == "string"
                end
            end

            return false
        end)

        return result
    end

    -- Finds where each of the given node tables ended up in the candidate, by identity.
    -- @param candidate table  The tree.
    -- @param nodes table[]  The node tables to find.
    -- @return table  Their paths in the same order; the editor uses it to keep its selection on nodes that moved.
    local function locations(candidate, nodes)
        local found = {}

        -- Visits a node and everything below it, recording the path of each wanted node.
        -- @param node table  The node.
        -- @param path table  The path of the node.
        local function visit(node, path)
            for index, wanted in ipairs(nodes) do
                if wanted == node then
                    found[index] = pathCopy(path)
                end
            end

            for _, edge in ipairs(edges(node)) do
                local child = pathCopy(path)

                for _, part in ipairs(edge.parts) do
                    child[#child + 1] = part
                end

                visit(edge.node, child)
            end
        end

        visit(candidate, {})
        return found
    end

    -- Removes the selected records from the candidate, last first so earlier list indexes stay valid.
    -- @param records table[]  The records returned by selected.
    local function remove(records)
        for i = #records, 1, -1 do
            local record = records[i]

            if record.relation == "list" then
                table.remove(record.container, record.key)
            elseif record.container then
                record.container[record.key] = {}
            end
        end
    end

    -- Wraps the selected conditions in one AND or OR group.
    -- @param paths table  A dense list of the paths of the conditions to group.
    -- @param kind string  "AND" or "OR".
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return table|string|nil  The new group's path (in a list); the reason code when the first return is nil.
    --
    -- Several must be siblings of one list; the group takes the first one's place.
    function draft:GroupSelection(paths, kind)
        if kind ~= "AND" and kind ~= "OR" then
            return nil, "invalid-condition-group"
        end

        return transaction(function(candidate)
            local records, why = selected(candidate, paths)

            if not records then
                return nil, why
            end

            local first = records[1]
            local wrapper = { type = kind, value = {} }

            for _, record in ipairs(records) do
                if #records > 1 and (record.relation ~= "list" or record.container ~= first.container) then
                    return nil, "condition-siblings-required"
                end

                wrapper.value[#wrapper.value + 1] = record.node
            end

            if #records > 1 then
                remove(records)
                table.insert(first.container, first.key, wrapper)
            else
                candidate = replace(first.container, first.key, wrapper, candidate)
            end

            return candidate, nil, locations(candidate, { wrapper })
        end)
    end

    -- Toggles NOT on each selected condition.
    -- @param paths table  A dense list of the paths of the conditions.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return table|string|nil  The new paths; the reason code when the first return is nil.
    --
    -- Wraps it, or unwraps an existing NOT (carrying its name and disabled flag over, and refusing when another
    -- property would be lost).
    function draft:NegateSelection(paths)
        return transaction(function(candidate)
            local records, why = selected(candidate, paths)

            if not records then
                return nil, why
            end

            local nodes = {}

            for _, record in ipairs(records) do
                local replacement = record.node.type == "NOT" and (record.node.value or {}) or {
                    type = "NOT",
                    value = record.node,
                }

                if record.node.type ~= "NOT" then
                    replacement.disabled = record.node.disabled
                    record.node.disabled = nil
                else
                    for key in pairs(record.node) do
                        if key ~= "type" and key ~= "value" and key ~= "name" and key ~= "disabled" then
                            return nil, "condition-property-conflict"
                        end
                    end

                    if record.node.name ~= nil then
                        if replacement.type ~= "AND" and replacement.type ~= "OR" and replacement.type ~= "NOT" then
                            return nil, "condition-property-conflict"
                        end
                        if replacement.name ~= nil and replacement.name ~= record.node.name then
                            return nil, "condition-property-conflict"
                        end

                        replacement.name = record.node.name
                    end

                    if record.node.disabled ~= nil then
                        if type(record.node.disabled) ~= "boolean" then
                            return nil, "condition-property-conflict"
                        end

                        if record.node.disabled then
                            replacement.disabled = true
                        end
                    end
                end

                candidate = replace(record.container, record.key, replacement, candidate)
                nodes[#nodes + 1] = replacement
            end

            return candidate, nil, locations(candidate, nodes)
        end)
    end

    -- Sets the disabled flag on the node at the path and clears it on the NOT wrappers and the condition beneath.
    -- @param path table  The path of the node.
    -- @param disabled boolean  True to disable; false to clear the flag.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    --
    -- One flag at the outermost level decides.
    function draft:SetProjectedDisabled(path, disabled)
        if type(disabled) ~= "boolean" then
            return nil, "invalid-disabled-flag"
        end

        return edit(path, function(node, _, _, _, candidate)
            local current = node

            while current.type == "NOT" and type(current.value) == "table" do
                current.disabled = nil
                current = current.value
            end

            current.disabled = nil
            node.disabled = disabled or nil
            return candidate
        end)
    end

    -- Duplicates every selected condition.
    -- @param paths table  A dense list of the paths of the conditions.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return table|string|nil  The paths of the copies; the reason code when the first return is nil.
    --
    -- Selection-wide Duplicate and Enable/Disable are one transaction, so one undo step, keeping the selection on the
    -- copies or the same nodes.
    function draft:DuplicateSelection(paths)
        return transaction(function(candidate)
            local records, why = selected(candidate, paths)

            if not records then
                return nil, why
            end

            local copies = {}

            for i = #records, 1, -1 do
                local record = records[i]
                local child = assert(copy(record.node))

                if record.relation == "list" then
                    table.insert(record.container, record.key + 1, child)
                else
                    candidate = replace(
                        record.container,
                        record.key,
                        { type = "AND", value = { record.node, child } },
                        candidate
                    )
                end

                table.insert(copies, 1, child)
            end

            return candidate, nil, locations(candidate, copies)
        end)
    end

    -- Sets or clears the disabled flag on every selected condition, the same way as SetProjectedDisabled.
    -- @param paths table  A dense list of the paths of the conditions.
    -- @param disabled boolean  True to disable; false to clear the flag.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return table|string|nil  The paths of the nodes; the reason code when the first return is nil.
    function draft:SetSelectionDisabled(paths, disabled)
        if type(disabled) ~= "boolean" then
            return nil, "invalid-disabled-flag"
        end

        return transaction(function(candidate)
            local records, why = selected(candidate, paths)

            if not records then
                return nil, why
            end

            local nodes = {}

            for _, record in ipairs(records) do
                local node = record.node
                local current = node

                while current.type == "NOT" and type(current.value) == "table" do
                    current.disabled = nil
                    current = current.value
                end

                current.disabled = nil
                node.disabled = disabled or nil
                nodes[#nodes + 1] = node
            end

            return candidate, nil, locations(candidate, nodes)
        end)
    end

    -- Removes every selected condition.
    -- @param paths table  A dense list of the paths of the conditions.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return table|string|nil  A list holding one empty path; the reason code when the first return is nil.
    --
    -- The whole tree becomes empty when the root is selected.
    function draft:RemoveSelection(paths)
        return transaction(function(candidate)
            local records, why = selected(candidate, paths)

            if not records then
                return nil, why
            end

            if records[1].relation == "root" then
                candidate = {}
            else
                remove(records)
            end

            return candidate, nil, { {} }
        end)
    end

    -- Moves the selected conditions to a destination.
    -- @param paths table  A dense list of the paths of the conditions.
    -- @param destination table  { path, field, index }: a group's list (the index is adjusted for entries removed ahead
    --   of it) or an empty single slot.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return table|string|nil  The new paths; the reason code when the first return is nil.
    --
    -- Refuses moving a node into itself.
    function draft:Transfer(paths, destination)
        if type(destination) ~= "table" or not data.CheckPortable(destination) then
            return nil, "invalid-condition-destination"
        end

        return transaction(function(candidate)
            local records, why = selected(candidate, paths)

            if not records then
                return nil, why
            end

            local target = resolve(candidate, destination.path)

            if not target then
                return nil, "invalid-condition-destination"
            end

            for _, record in ipairs(records) do
                if record.relation == "root" or prefix(record.path, destination.path) then
                    return nil, "cyclic-condition-transfer"
                end
            end

            local field = destination.field or "value"
            local kind

            if (target.type == "AND" or target.type == "OR") and field == "value" then
                kind = "condition[]"
            elseif target.type == "NOT" and field == "value" then
                kind = "condition"
            else
                kind = (declarations[target.type] or {})[field]
            end

            if not kind then
                return nil, "invalid-condition-destination"
            end

            local nodes = {}

            for _, record in ipairs(records) do
                nodes[#nodes + 1] = record.node
            end

            if kind == "condition[]" then
                local list = target[field] or {}
                local index = destination.index or #list + 1

                if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #list + 1 then
                    return nil, "invalid-condition-destination"
                end

                local adjusted = index

                for _, record in ipairs(records) do
                    if record.container == list and record.key < index then
                        adjusted = adjusted - 1
                    end
                end

                remove(records)
                target[field] = list

                for i, node in ipairs(nodes) do
                    table.insert(list, adjusted + i - 1, node)
                end
            else
                if #records ~= 1 or destination.index ~= nil or (target[field] and next(target[field]) ~= nil) then
                    return nil, "occupied-condition-slot"
                end

                remove(records)
                target[field] = nodes[1]
            end

            return candidate, nil, locations(candidate, nodes)
        end)
    end

    -- Inserts a condition after the node at the path.
    -- @param path table  The path of the node.
    -- @param value table|nil  The condition to insert; an empty one by default.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return table|string|nil  The new node's path; the reason code when the first return is nil.
    --
    -- A node outside a list is grouped with it under an AND instead.
    function draft:AddSibling(path, value)
        local child, why = copy(value == nil and {} or value)

        if type(child) ~= "table" then
            return nil, why or "invalid-condition"
        end

        return edit(path, function(node, container, key, relation, candidate)
            if relation == "list" then
                table.insert(container, key + 1, child)
            elseif next(node) == nil then
                candidate = replace(container, key, child, candidate)
            else
                candidate = replace(container, key, { type = "AND", value = { node, child } }, candidate)
            end

            return candidate, nil, locations(candidate, { child })
        end)
    end

    -- Copies the node at the path next to itself.
    -- @param path table  The path of the node.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return table|string|nil  The copy's path; the reason code when the first return is nil.
    --
    -- Grouped under an AND when the node is not in a list.
    function draft:Duplicate(path)
        return edit(path, function(node, container, key, relation, candidate)
            local child = assert(copy(node))

            if relation == "list" then
                table.insert(container, key + 1, child)
            else
                candidate = replace(container, key, { type = "AND", value = { node, child } }, candidate)
            end

            return candidate, nil, locations(candidate, { child })
        end)
    end

    -- Inserts a condition at a destination.
    -- @param destination table  { path, relation = "before"|"after", or field and index }: beside a node, into an empty
    --   node, or into a field the node's definition declares.
    -- @param value table|nil  The condition to insert; an empty one by default.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return table|string|nil  The new node's path; the reason code when the first return is nil.
    function draft:Insert(destination, value)
        if type(destination) ~= "table" or not data.CheckPortable(destination) then
            return nil, "invalid-condition-destination"
        end

        local child, why = copy(value == nil and {} or value)

        if type(child) ~= "table" then
            return nil, why or "invalid-condition"
        end

        return edit(destination.path, function(node, container, key, relation, candidate)
            if destination.relation then
                if destination.relation ~= "before" and destination.relation ~= "after" then
                    return nil, "invalid-condition-destination"
                end

                local before = destination.relation == "before"

                if relation == "list" then
                    table.insert(container, key + (before and 0 or 1), child)
                else
                    local values = before and { child, node } or { node, child }
                    candidate = replace(container, key, { type = "AND", value = values }, candidate)
                end
            elseif next(node) == nil and destination.field == nil and destination.index == nil then
                candidate = replace(container, key, child, candidate)
            else
                local field = destination.field or "value"
                local kind

                if (node.type == "AND" or node.type == "OR") and field == "value" then
                    kind = "condition[]"
                elseif node.type == "NOT" and field == "value" then
                    kind = "condition"
                else
                    kind = (declarations[node.type] or {})[field]
                end

                if kind == "condition[]" then
                    local list = node[field] or {}
                    local index = destination.index or #list + 1

                    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #list + 1 then
                        return nil, "invalid-condition-destination"
                    end

                    table.insert(list, index, child)
                    node[field] = list
                elseif kind == "condition" then
                    if destination.index ~= nil or (node[field] and next(node[field]) ~= nil) then
                        return nil, "occupied-condition-slot"
                    end

                    node[field] = child
                else
                    return nil, "invalid-condition-destination"
                end
            end

            return candidate, nil, locations(candidate, { child })
        end)
    end

    -- Names an AND, OR or NOT group.
    -- @param path table  The path of the group.
    -- @param name string  The name: trimmed, at most 512 characters, no control characters; an empty name clears it.
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    function draft:SetName(path, name)
        if type(name) ~= "string" or #name > 512 or name:find("%c") then
            return nil, "invalid-condition-name"
        end

        name = name:match("^%s*(.-)%s*$")

        return edit(path, function(node, _, _, _, candidate)
            if node.type ~= "AND" and node.type ~= "OR" and node.type ~= "NOT" then
                return nil, "not-a-condition-group"
            end

            node.name = name ~= "" and name or nil
            return candidate
        end)
    end

    -- Switches an AND group to OR or back, keeping its children.
    -- @param path table  The path of the group.
    -- @param kind string  "AND" or "OR".
    -- @return boolean|nil  True when applied; nil with the draft unchanged on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    function draft:SetGroupType(path, kind)
        if kind ~= "AND" and kind ~= "OR" then
            return nil, "invalid-condition-group"
        end

        return edit(path, function(node, _, _, _, candidate)
            if node.type ~= "AND" and node.type ~= "OR" then
                return nil, "not-a-condition-group"
            end

            node.type = kind
            return candidate
        end)
    end

    -- Flattens the tree into display rows.
    -- @param limit number|nil  The most rows to return (200 by default, 4096 at most).
    -- @return table[]  The rows { path, type, depth, childCount, disabled, invalidDisabled }.
    -- @return boolean  False when the limit cut the list short.
    function draft:Rows(limit)
        limit = type(limit) == "number" and limit == limit and limit % 1 == 0 and math.max(1, math.min(4096, limit))
            or 200

        local rows, complete = {}, true

        -- Adds the row of a node and then the rows of its children, stopping at the limit.
        -- @param node table  The node.
        -- @param path table  The path of the node.
        -- @param depth number  The nesting depth.
        local function visit(node, path, depth)
            if #rows >= limit then
                complete = false
                return
            end

            local children = edges(node)

            rows[#rows + 1] = {
                path = pathCopy(path),
                type = node.type,
                disabled = node.disabled == true,
                invalidDisabled = node.disabled ~= nil and type(node.disabled) ~= "boolean",
                depth = depth,
                childCount = #children,
            }

            for _, edge in ipairs(children) do
                local childPath = pathCopy(path)

                for _, part in ipairs(edge.parts) do
                    childPath[#childPath + 1] = part
                end

                visit(edge.node, childPath, depth + 1)

                if not complete then
                    break
                end
            end
        end

        visit(root, {}, 0)
        return rows, complete
    end

    return draft
end
