-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Scene model for the condition canvas (the card view of a rotation step's condition tree). It turns the editor's flat
-- row list into detached card, connector and drop-target geometry and answers viewport queries; it creates no widgets,
-- calls no condition printers and never edits the condition data. Loaded after Core/rotation_workspace.lua and drawn by
-- UI/condition_canvas.lua. A path is a list of keys from the condition root, and ConditionPathKey turns it into the
-- string key that view state (selection, collapsed, expanded) is stored under.

local _, addon = ...

-- ============================================================================
-- Path helpers
-- ============================================================================

-- Returns a new list with the same path parts, so scene records never share a path table with the model.
-- @param path (string|number)[]  The path to copy.
-- @return (string|number)[]  The copy.
local function copy(path)
    local result = {}

    for i, part in ipairs(path) do
        result[i] = part
    end

    return result
end

-- Returns a string key for a condition path, unique per path (parts are type-tagged and escaped).
-- @param path (string|number)[]  The keys from the condition root.
-- @return string  The key that view state (selection, collapsed, expanded) is stored under.
--
-- Called as a plain function, not a method.
function addon.ConditionPathKey(path)
    local result = {}

    for _, part in ipairs(path) do
        local encoded = tostring(part):gsub("%%", "%%25"):gsub("/", "%%2F")
        result[#result + 1] = type(part) .. ":" .. encoded
    end

    return table.concat(result, "/")
end

-- Returns the node found by following the path from root.
-- @param root table  The condition root.
-- @param path (string|number)[]  The keys to follow.
-- @return any  The value at the end of the path.
local function at(root, path)
    for _, part in ipairs(path) do
        root = root[part]
    end

    return root
end

-- Returns a measured size clamped to a maximum, or a fallback when the measurement is unusable.
-- @param value any  The measured size; a positive number is usable, while zero, negatives, NaN and non-numbers are not.
-- @param fallback number  The size to use when the measurement is unusable.
-- @param maximum number  The upper bound the measurement is clamped to.
-- @return number  The clamped measurement or the fallback.
local function dimension(value, fallback, maximum)
    return type(value) == "number" and value == value and value > 0 and math.min(value, maximum) or fallback
end

-- ============================================================================
-- Scene building
-- ============================================================================

-- Builds the card, connector and drop-target geometry for a condition tree.
-- @param root table  The condition root.
-- @param rows table[]  The editor's flat row list (path, depth, disabled, invalidDisabled, name ...) from the bounded
--   draft model.
-- @param view table|nil  The editor's state and measurements: width, cardStates, collapsed, expanded, selection, help,
--   hiddenChildren, label, summary and detail sizes, and definitions.
-- @param rowsComplete boolean|nil  False when the row list is known to be incomplete.
-- @return table|nil  The scene { cards, cardsByKey, commandPathsByKey, connectors, connectorsByTo, dropTargets,
--   dropTargetsByY, maxDropHeight, width, height, complete }; nil when the rows are incomplete or exceed 4096.
-- @return table|nil  { code = "condition-limit" } when the first return is nil; nil otherwise.
--
-- The input rows come from the bounded draft model. This scene holds plain, detached presentation values; it never
-- calls condition printers or widgets. NOT is stored as a node, but shown as a property of its operand. Both paths are
-- kept: structural commands act on the outer wrapper; fields act on the underlying operand. This is a projection, never
-- a data rewrite.
function addon:BuildConditionCanvas(root, rows, view, rowsComplete)
    if rowsComplete == false or #rows > 4096 then
        return nil, { code = "condition-limit" }
    end

    view = view or {}
    -- NOT is stored as a node, but shown as a property of its operand. Keep
    -- both paths: structural commands act on the outer wrapper; fields act
    -- on the underlying operand. This is a projection, never a data rewrite.
    local tree, ancestors
    ancestors = {}

    for _, row in ipairs(rows) do
        while #ancestors > 0 and ancestors[#ancestors].row.depth >= row.depth do
            table.remove(ancestors)
        end

        local branch = { row = row, node = at(root, row.path), children = {} }
        local parent = ancestors[#ancestors]

        if parent then
            parent.children[#parent.children + 1] = branch
        else
            tree = branch
        end

        ancestors[#ancestors + 1] = branch
    end

    local projected = {}

    -- Flattens one branch into the projected row list, folding a chain of NOT nodes into the negated flag of its
    -- operand, then recurses into the children.
    -- @param branch table  The branch { row, node, children } to flatten.
    -- @param depth number  The depth of the projected row.
    -- @param inactive boolean|nil  True for rows under a disabled ancestor, which are marked unreachable.
    local function project(branch, depth, inactive)
        local outer = branch
        local count = 0
        local disabled, invalidDisabled = false, false
        local disabledPath, name, namePath

        -- Accumulates the disabled flags and the first group name seen along the folded NOT chain.
        -- @param current table  The branch { row, node, children } to read.
        local function flags(current)
            if current.row.disabled and not disabledPath then
                disabledPath = copy(current.row.path)
            end

            disabled = disabled or current.row.disabled
            invalidDisabled = invalidDisabled or current.row.invalidDisabled

            if
                not name
                and (current.node.type == "AND" or current.node.type == "OR" or current.node.type == "NOT")
                and type(current.node.name) == "string"
            then
                name = current.node.name
                namePath = copy(current.row.path)
            end
        end

        flags(branch)

        while branch.node.type == "NOT" and #branch.children == 1 do
            count = count + 1
            branch = branch.children[1]
            flags(branch)
        end

        local siblingPath = copy(outer.row.path)
        local siblingIndex = table.remove(siblingPath)
        local siblings = type(siblingIndex) == 'number' and at(root, siblingPath) or nil
        local canMoveUp = type(siblings) == 'table' and siblingIndex > 1 or false
        local canMoveDown = type(siblings) == 'table' and siblingIndex < #siblings or false
        local missing = branch.node.type == "NOT" and #branch.children == 0

        if missing then
            count = count + 1
        end

        projected[#projected + 1] = {
            path = copy(outer.row.path),
            fieldPath = copy(branch.row.path),
            namePath = namePath or copy(branch.row.path),
            disabledPath = disabledPath or copy(outer.row.path),
            node = missing and {} or branch.node,
            type = not missing and branch.node.type or nil,
            negated = count % 2 == 1,
            missingOperand = missing,
            disabled = disabled,
            invalidDisabled = invalidDisabled,
            canMoveUp = canMoveUp,
            canMoveDown = canMoveDown,
            name = name,
            depth = depth,
            childCount = #branch.children,
            unreachable = inactive == true,
        }

        for _, child in ipairs(branch.children) do
            project(child, depth + 1, inactive or disabled)
        end
    end

    if tree then
        project(tree, 0)
    end

    rows = projected
    local width = math.max(340, dimension(view.width, 1000, 4000))

    local scene = {
        cards = {},
        cardsByKey = {},
        commandPathsByKey = {},
        connectors = {},
        connectorsByTo = {},
        dropTargets = {},
        width = width,
        complete = true,
    }

    local stack, y, hiddenDepth = {}, 8, nil

    -- Closes every open group at or below a depth: fixes its final height and grows its width to fit its children.
    -- @param depth number  The depth at or below which groups are closed.
    local function finish(depth)
        while #stack > 0 and stack[#stack].depth >= depth do
            local group = table.remove(stack)
            group.height = math.max(group.height, y - group.y)
            y = y + 8
            group.width = math.max(group.width, (group.contentRight or group.x + group.width) - group.x + 14)
            local parent = stack[#stack]

            if parent then
                parent.contentRight = math.max(parent.contentRight or 0, group.x + group.width)
            end
        end
    end

    -- Records a drop target for a card.
    -- @param card table  The card the target belongs to.
    -- @param kind string  'before', 'after' or 'inside'.
    -- @param destination table  What a drop command receives (path, field, index or relation).
    -- @param top number  The target's top edge.
    -- @param height number  The target's height.
    local function drop(card, kind, destination, top, height)
        scene.dropTargets[#scene.dropTargets + 1] = {
            cardKey = card.key,
            kind = kind,
            destination = destination,
            x = card.x,
            y = top,
            width = card.width,
            height = height,
        }
    end

    for _, row in ipairs(rows) do
        if hiddenDepth and row.depth <= hiddenDepth then
            hiddenDepth = nil
        end

        if not hiddenDepth then
            finish(row.depth)
            local node = row.node
            local key = addon.ConditionPathKey(row.path)
            local group = row.type == "AND" or row.type == "OR" or row.type == "NOT"

            local state = (view.cardStates or {})[key]
                or (group and view.collapsed and view.collapsed[key] and 'compact')
                or (not group and view.expanded and view.expanded[key] and 'expanded')
                or 'normal'

            local compact = state == 'compact'
            local collapsed = group and (((view.hiddenChildren or {})[key] or (view.collapsed or {})[key]) == true)
            local expanded = not compact and ((view.help and view.help[key] == true) or state == 'expanded') or false
            local headerHeight = 26 + ((not compact and not group and row.name and row.name ~= "") and 18 or 0)

            local ownHeight = compact and 28 or math.max(
                group and 88 or 72,
                headerHeight
                    + 4
                    + (expanded and dimension((view.detailsHeights or {})[key], group and 40 or 120, 5000) or math.max(
                        28,
                        dimension((view.summaryHeights or {})[key], 28, 3000)
                    ))
            )

            local x = 12 + math.min(row.depth, 12) * 26

            local card = {
                key = key,
                path = copy(row.path),
                type = row.type,
                depth = row.depth,
                group = group,
                collapsed = collapsed,
                compact = compact,
                state = state,
                expanded = expanded,
                childCount = row.childCount,
                disabled = row.disabled,
                invalidDisabled = row.invalidDisabled,
                unreachable = row.unreachable,
                canMoveUp = row.canMoveUp,
                canMoveDown = row.canMoveDown,
                name = row.name,
                negated = row.negated,
                fieldPath = copy(row.fieldPath),
                namePath = copy(row.namePath),
                disabledPath = copy(row.disabledPath),
                missingOperand = row.missingOperand,
                selected = view.selection and view.selection[key] == true or false,
                x = x,
                y = y,
                width = math.max(340, dimension((view.labelWidths or {})[key], 0, 1200) + 192),
                height = ownHeight,
                ownHeight = ownHeight,
                headerHeight = headerHeight,
            }

            local parent = stack[#stack]
            card.ordinal = #scene.cards + 1
            card.parentKey = parent and parent.key
            scene.cardsByKey[key] = card
            scene.commandPathsByKey[addon.ConditionPathKey(card.fieldPath)] = card.path
            scene.commandPathsByKey[addon.ConditionPathKey(card.namePath)] = card.path

            if parent then
                parent.contentRight = math.max(parent.contentRight or 0, x + card.width)
                local stemTop = parent.y + (parent.compact and 26 or 66)

                scene.connectors[#scene.connectors + 1] = {
                    x = parent.x + 10,
                    y = stemTop,
                    width = 2,
                    height = math.max(2, y + 22 - stemTop),
                    from = parent.key,
                    to = card.key,
                }

                scene.connectors[#scene.connectors + 1] = {
                    x = parent.x + 10,
                    y = y + 22,
                    width = math.max(2, x - parent.x - 10),
                    height = 2,
                    from = parent.key,
                    to = card.key,
                }
            end

            if parent then
                scene.connectorsByTo[key] = {
                    scene.connectors[#scene.connectors - 1],
                    scene.connectors[#scene.connectors],
                }
            end

            scene.cards[#scene.cards + 1] = card
            y = y + ownHeight + 8

            if type(row.path[#row.path]) == "number" then
                local parentPath = copy(row.path)
                local index = table.remove(parentPath)
                local field = table.remove(parentPath)
                drop(card, "before", { path = parentPath, field = field, index = index }, card.y, 8)

                drop(
                    card,
                    "after",
                    { path = copy(parentPath), field = field, index = index + 1 },
                    card.y + ownHeight,
                    8
                )
            else
                drop(card, "before", { path = copy(row.path), relation = "before" }, card.y, 8)
                drop(card, "after", { path = copy(row.path), relation = "after" }, card.y + ownHeight, 8)
            end

            if group then
                if collapsed or row.childCount == 0 then
                    drop(card, "inside", { path = copy(row.fieldPath) }, card.y + (compact and 8 or 36), 12)
                end

                if collapsed then
                    hiddenDepth = row.depth
                end
            else
                if next(node) == nil then
                    drop(card, "inside", { path = copy(row.fieldPath) }, card.y + (compact and 8 or 54), 12)
                end

                local slots = {}
                local definition = (view.definitions or {})[row.type]

                for field, kind in pairs(definition and definition.fields or {}) do
                    if
                        (kind == "condition[]" or kind == "condition") and (not node[field] or next(node[field]) == nil)
                    then
                        slots[#slots + 1] = field
                    end
                end

                table.sort(slots)

                for index, field in ipairs(slots) do
                    drop(
                        card,
                        "inside",
                        { path = copy(row.fieldPath), field = field },
                        card.y + (compact and 8 or 54),
                        12
                    )

                    local target = scene.dropTargets[#scene.dropTargets]
                    target.width = card.width / #slots
                    target.x = card.x + (index - 1) * target.width
                end
            end

            if not collapsed and row.childCount > 0 then
                stack[#stack + 1] = card
            end
        end
    end

    finish(-1)
    scene.height = math.max(1, y + 8)

    for _, card in ipairs(scene.cards) do
        scene.width = math.max(scene.width, card.x + card.width + 16)
    end

    local destinations, unique = {}, {}

    for _, target in ipairs(scene.dropTargets) do
        local card = scene.cardsByKey[target.cardKey]

        if card then
            if target.kind ~= "inside" then
                target.width = card.width
            end
            if target.kind == "after" then
                target.y = card.y + card.height
            end

            if target.kind == "inside" and target.destination.field == nil then
                target.x = card.x + 32
                target.width = card.width - 64
            end
        end

        if target.kind == "inside" then
            unique[#unique + 1] = target
        else
            local destination = target.destination

            local key = addon.ConditionPathKey(destination.path)
                .. "/field:"
                .. addon.ConditionPathKey({ destination.field or "value" })
                .. "/index:"
                .. tostring(destination.index)
                .. "/relation:"
                .. tostring(destination.relation)

            local gap = destinations[key]

            if not gap then
                gap = target
                destinations[key] = gap
                unique[#unique + 1] = gap
            end

            if target.kind == "before" then
                gap.nextY = target.y
            else
                gap.previousY = target.y
            end

            gap.width = math.max(gap.width, target.width)
        end
    end

    for _, target in ipairs(unique) do
        if target.kind ~= "inside" then
            local center = target.previousY and target.nextY and (target.previousY + target.nextY) / 2
                or target.previousY and target.previousY + 4
                or target.nextY - 4

            target.y = center - 4
            target.height = 8
        end
    end

    scene.dropTargets = unique
    scene.dropTargetsByY = {}
    scene.maxDropHeight = 0

    for i, target in ipairs(unique) do
        target.ordinal = i
        scene.dropTargetsByY[i] = target
        scene.maxDropHeight = math.max(scene.maxDropHeight, target.height)
    end

    table.sort(scene.dropTargetsByY, function(a, b)
        if a.y ~= b.y then
            return a.y < b.y
        end

        return a.ordinal < b.ordinal
    end)

    return scene
end

-- ============================================================================
-- Viewport query
-- ============================================================================

-- Returns the cards that intersect a rectangle, plus their ancestors that do.
-- @param scene table  The scene built by BuildConditionCanvas.
-- @param left number  The left edge of the rectangle, in canvas coordinates.
-- @param top number  The top edge.
-- @param right number  The right edge.
-- @param bottom number  The bottom edge.
-- @return table[]  The cards in card order.
--
-- Complete geometry is indexed independently of leased native controls; only nearby rows and their enclosing outlines
-- are needed for a viewport query. Cards are sorted by y, so the start is found by binary search and the scan stops at
-- the first card below the rectangle.
function addon:GetConditionCanvasViewport(scene, left, top, right, bottom)
    local cards = scene.cards
    local low, high = 1, #cards

    while low <= high do
        local middle = math.floor((low + high) / 2)

        if cards[middle].y < top then
            low = middle + 1
        else
            high = middle - 1
        end
    end

    local first = math.max(1, low - 1)
    local wanted, result = {}, {}

    -- Adds the card and each ancestor that intersects the rectangle; stops at one that is already included.
    -- @param card table|nil  The card to add.
    local function include(card)
        while card do
            if wanted[card.key] then
                break
            end

            if card.x + card.width >= left and card.x <= right and card.y + card.height >= top and card.y <= bottom then
                wanted[card.key] = card
            end

            card = card.parentKey and scene.cardsByKey[card.parentKey]
        end
    end

    for index = first, #cards do
        local card = cards[index]

        if card.y > bottom then
            break
        end

        include(card)
    end

    for _, card in pairs(wanted) do
        result[#result + 1] = card
    end

    table.sort(result, function(a, b) return a.ordinal < b.ordinal end)
    return result
end
