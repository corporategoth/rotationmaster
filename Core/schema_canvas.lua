-- Scene model for the field schema canvas (the card editor for a custom condition's field schema). It indexes a schema
-- model, lays its nodes out as rows and insertion gaps in canvas coordinates, and picks the rows that intersect a
-- viewport; it creates no widgets and never edits the model. Loaded after Core/schema_authoring.lua; drawn by
-- UI/schema_cards.lua. Paths are lists of child positions from the root, and a node's key is its path joined by '/'.

local _, addon = ...

-- ============================================================================
-- Index
-- ============================================================================

-- Returns the string key for a path of child positions.
-- @param path number[]  The child positions from the root; empty for the root.
-- @return string  The positions joined by '/' ('' is the root).
local function key(path)
    return table.concat(path, '/')
end

-- Returns a new path that is the given path extended by one child position; the argument is not modified.
-- @param path number[]  The path to extend.
-- @param index number  The child position to append.
-- @return number[]  The new path.
local function childPath(path, index)
    local result = {}

    for i, value in ipairs(path) do
        result[i] = value
    end

    result[#result + 1] = index
    return result
end

-- Returns the index of a schema model: its nodes with change and validity flags.
-- @param model table  The schema model (root, revision); the index is cached in model.canvasIndex.
-- @param baseline table|nil  The original root node to compare against; nil marks every node as changed.
-- @return table  { revision, baseline, nodes = entry[] in pre-order, byKey = table<string, entry>, dirty = boolean },
--   with per-node `changed` and `invalid` (propagated to ancestors).
--
-- Validation and baseline comparisons belong to a model revision, never a viewport lease. Each node and each sibling
-- name is processed once. The index is stored on the model and rebuilt only when the revision or the baseline changes.
function addon:GetFieldSchemaIndex(model, baseline)
    local cached = model.canvasIndex

    if cached and cached.revision == model.revision and cached.baseline == baseline then
        return cached
    end

    local index = { revision = model.revision, baseline = baseline, byKey = {}, nodes = {} }
    local stack = { { node = model.root, original = baseline, path = {}, key = '' } }

    while #stack > 0 do
        local entry = table.remove(stack)
        local node = entry.node
        local original = entry.original
        index.nodes[#index.nodes + 1] = entry
        index.byKey[entry.key] = entry

        entry.changed = not original
            or node.name ~= original.name
            or node.kind ~= original.kind
            or node.required ~= original.required
            or node.requiredFieldsPresent ~= original.requiredFieldsPresent
            or #(node.children or {}) ~= #(original.children or {})

        local counts = {}

        if node.kind == 'record' then
            for _, child in ipairs(node.children or {}) do
                counts[child.name or false] = (counts[child.name or false] or 0) + 1
            end
        end

        if node.children then
            entry.invalid = entry.invalid or entry.parent and #node.children == 0 or false

            for i = #node.children, 1, -1 do
                local child = node.children[i]
                local path = childPath(entry.path, i)

                local bad = node.kind == 'record'
                    and (not addon:IsEditableFieldSchemaName(child.name, node == model.root)
                        or counts[child.name or false] > 1)
                    or false

                stack[#stack + 1] = {
                    node = child,
                    original = original and original.children and original.children[i],
                    path = path,
                    key = key(path),
                    parent = entry,
                    invalid = bad,
                }
            end
        end
    end

    for i = #index.nodes, 2, -1 do
        local entry = index.nodes[i]
        local parent = entry.parent
        parent.invalid = parent.invalid or entry.invalid
        parent.changed = parent.changed or entry.changed
    end

    index.dirty = index.nodes[1].changed == true
    model.canvasIndex = index
    return index
end

-- ============================================================================
-- Scene layout
-- ============================================================================

-- Lays the schema out top to bottom in canvas coordinates.
-- @param model table  The schema model.
-- @param folded table  Maps a node key to true for each folded node, whose children are skipped.
-- @param width number|nil  The canvas width; at least 340, default 700.
-- @param baseline table|nil  The original root node, passed to GetFieldSchemaIndex.
-- @return table  The scene { rows, byKey, gaps, width, height, index }: one row per visible node, the add-field slots
--   of each container, and a list of insertion gaps sorted by y.
--
-- The walk is iterative so a deep schema cannot overflow the stack.
function addon:BuildFieldSchemaScene(model, folded, width, baseline)
    local index = self:GetFieldSchemaIndex(model, baseline)
    local scene = { rows = {}, byKey = {}, gaps = {}, width = math.max(340, width or 700), index = index }
    local y = 4
    local stack = { { entry = index.byKey[''], next = 1, x = 0, width = scene.width, start = true } }

    -- Records the drop target before a child position of the container being walked.
    -- @param state table  The walk state of the container (entry, x, width).
    -- @param number number  The child position the gap sits before.
    local function gap(state, number)
        scene.gaps[#scene.gaps + 1] = {
            path = state.entry.path,
            key = state.entry.key,
            gap = number,
            y = y - 5,
            x = state.x,
            width = state.width,
            height = 10,
        }
    end

    while #stack > 0 do
        local state = stack[#stack]
        local node = state.entry.node

        if state.start then
            state.start = nil
            gap(state, 1)
        end

        local child = node.children[state.next]

        if child then
            local position = state.next
            state.next = position + 1
            local path = childPath(state.entry.path, position)
            local id = key(path)
            local entry = index.byKey[id]

            local row = {
                key = id,
                path = path,
                node = child,
                parentKey = state.entry.key ~= '' and state.entry.key or nil,
                parent = node,
                index = position,
                x = state.x,
                y = y,
                width = state.width,
                height = 70,
                ordinal = #scene.rows + 1,
            }

            scene.rows[#scene.rows + 1] = row
            scene.byKey[id] = row

            if child.children and not folded[id] then
                y = y + 72
                local indent = math.max(0, math.min(28, state.width - 326))

                stack[#stack + 1] = {
                    entry = entry,
                    next = 1,
                    x = state.x + indent,
                    width = math.max(320, state.width - indent - 6),
                    row = row,
                    start = true,
                }
            else
                y = y + 76
                gap(state, state.next)
            end
        else
            if state.row then
                local row = state.row
                row.addY = y
                row.addX = state.x
                row.addWidth = state.width
                y = y + 32
                row.height = y - row.y
                y = y + 6
                table.remove(stack)
                gap(stack[#stack], stack[#stack].next)
            else
                table.remove(stack)
            end
        end
    end

    scene.height = math.max(1, y + 12)
    table.sort(scene.gaps, function(a, b) return a.y < b.y end)
    return scene
end

-- ============================================================================
-- Viewport query
-- ============================================================================

-- Returns the scene rows that intersect a vertical range.
-- @param scene table  The scene built by BuildFieldSchemaScene.
-- @param top number  The top of the visible range, in canvas coordinates.
-- @param bottom number  The bottom of the visible range, in canvas coordinates.
-- @return table[]  The intersecting rows in row order, together with their ancestors so a container stays drawable when
--   only a child is visible.
--
-- Uses a binary search on row y, so it suits per-frame calls.
function addon:GetFieldSchemaViewport(scene, top, bottom)
    local rows = scene.rows
    local low, high = 1, #rows

    while low <= high do
        local mid = math.floor((low + high) / 2)

        if rows[mid].y < top then
            low = mid + 1
        else
            high = mid - 1
        end
    end

    local found, result = {}, {}

    for i = math.max(1, low - 1), #rows do
        local row = rows[i]

        if row.y > bottom then
            break
        end

        while row do
            if found[row.key] then
                break
            end

            if row.y + row.height >= top then
                found[row.key] = row
            end

            row = row.parentKey and scene.byKey[row.parentKey]
        end
    end

    for _, row in pairs(found) do
        result[#result + 1] = row
    end

    table.sort(result, function(a, b) return a.ordinal < b.ordinal end)
    return result
end
