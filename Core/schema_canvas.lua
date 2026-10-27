local _, addon = ...

local function key(path)
    return table.concat(path, '/')
end

local function childPath(path, index)
    local result = {}

    for i, value in ipairs(path) do
        result[i] = value
    end

    result[#result + 1] = index
    return result
end

-- Validation and baseline comparisons belong to a model revision, never a
-- viewport lease. Each node and each sibling name is processed once.
function addon:GetFieldSchemaIndex(model, baseline)
    local cached = model.canvasIndex
    if cached and cached.revision == model.revision and cached.baseline == baseline then return cached end
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

function addon:BuildFieldSchemaScene(model, folded, width, baseline)
    local index = self:GetFieldSchemaIndex(model, baseline)
    local scene = { rows = {}, byKey = {}, gaps = {}, width = math.max(340, width or 700), index = index }
    local y = 4
    local stack = { { entry = index.byKey[''], next = 1, x = 0, width = scene.width, start = true } }

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
        if row.y > bottom then break end

        while row do
            if found[row.key] then break end
            if row.y + row.height >= top then found[row.key] = row end
            row = row.parentKey and scene.byKey[row.parentKey]
        end
    end

    for _, row in pairs(found) do
        result[#result + 1] = row
    end

    table.sort(result, function(a, b) return a.ordinal < b.ordinal end)
    return result
end
