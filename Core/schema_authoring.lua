-- Pure editing model for a custom condition's field schema: path keys, field order and required-field reconciliation,
-- and the draft tree the schema editor works on with undo and redo. It owns the rules about what an editable schema may
-- look like; it draws nothing and writes no saved data, so the UI applies a Snapshot only on an explicit Apply.
-- Normalization of the stored forms comes from Core/custom_condition_data.lua. Loaded from RotationMaster.toc after
-- Core/function_data.lua; UI/schema_editor.lua and UI/custom_source_fields.lua drive it.

local _, addon = ...

-- ============================================================================
-- Schema helpers
-- ============================================================================

-- Returns a deep copy of settings data.
-- @param value any  The data to copy.
-- @return any  The copy.
local function copy(value)
    return addon:CopySettingsData(value)
end

-- Flattens a field path into one string, so paths can key a table.
-- @param path (string|number)[]  The field path: a list of string and number keys.
-- @return string  The flattened path; the key type is part of the text, so 1 and "1" differ.
local function pathKey(path)
    local parts = {}

    for _, key in ipairs(path) do
        parts[#parts + 1] = type(key) .. ':' .. tostring(key)
    end

    return table.concat(parts, '/')
end

-- Reports whether a name is a legal editable field name.
-- @param name any  The candidate name.
-- @param root boolean|nil  True at the top level, where the reserved condition keys type and disabled are refused.
-- @return boolean  True for a short identifier (at most 64 characters) that is not reserved at the top level.
function addon:IsEditableFieldSchemaName(name, root)
    return type(name) == 'string'
        and #name <= 64
        and name:match('^[%a_][%w_]*$') ~= nil
        and not (root and (name == 'type' or name == 'disabled'))
end

-- Validates a stored field display order against the schema.
-- @param order table|nil  A list of paths into the schema; nil means no order.
-- @param fields table  The schema the paths must exist in.
-- @return table[]|nil  A fresh copy (an empty list for nil); nil when `order` is not a dense list of distinct, existing
--   paths.
-- @return string|nil  'invalid-field-order' when the first return is nil; nil otherwise.
function addon:NormalizeCustomFieldOrder(order, fields)
    if order == nil then
        return {}
    end
    if type(order) ~= 'table' or getmetatable(order) then
        return nil, 'invalid-field-order'
    end

    local seen, result = {}, {}
    local entries = 0

    for index, path in pairs(order) do
        entries = entries + 1

        if
            type(index) ~= 'number'
            or index % 1 ~= 0
            or index < 1
            or index > #order
            or index > 4096
            or type(path) ~= 'table'
            or getmetatable(path)
            or #path == 0
            or #path > 64
        then
            return nil, 'invalid-field-order'
        end

        local value = fields
        local parts = 0

        for i, key in pairs(path) do
            parts = parts + 1

            if
                type(i) ~= 'number'
                or i % 1 ~= 0
                or i < 1
                or i > #path
                or (type(key) ~= 'string' and type(key) ~= 'number')
            then
                return nil, 'invalid-field-order'
            end
        end

        if parts ~= #path then
            return nil, 'invalid-field-order'
        end

        for _, key in ipairs(path) do
            value = type(value) == 'table' and value[key] or nil

            if value == nil then
                return nil, 'invalid-field-order'
            end
        end

        local key = pathKey(path)

        if seen[key] then
            return nil, 'invalid-field-order'
        end

        seen[key] = true
        result[index] = copy(path)
    end

    if entries ~= #order then
        return nil, 'invalid-field-order'
    end

    return result
end

-- Returns the names in a required-fields list that still exist in the schema.
-- @param required table|nil  The stored required-fields list.
-- @param fields table  The schema whose top-level names are checked.
-- @return string[]|nil  The names that still exist, deduplicated and capped at 128; nil when there is no list. Entries
--   that no longer match a field are dropped.
--
-- Reconcile only after an explicit schema edit/Apply, never while rendering.
function addon:FilterCustomRequiredFields(required, fields)
    if required == nil then
        return nil
    end

    local result, seen = {}, {}

    if type(required) == 'table' and not getmetatable(required) then
        for index = 1, math.min(128, #required) do
            local name = required[index]

            if type(name) == 'string' and fields[name] ~= nil and not seen[name] then
                seen[name] = true
                result[#result + 1] = name
            end
        end
    end

    return result
end

-- ============================================================================
-- Schema draft
-- ============================================================================

-- Builds the editable draft the schema editor works on from a stored schema, its field order and its required fields.
-- @param fields table  The stored schema.
-- @param fieldOrder table|nil  The stored field display order.
-- @param requiredFields table|nil  The stored required-fields list.
-- @return table|nil  The draft; nil when the stored schema or order does not normalize.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- The draft is a tree of nodes (record, union or a scalar kind); every method below changes it through Change so each
-- edit lands on the bounded undo stack, and Snapshot turns it back into stored form. A schema is data: records have
-- named children; numeric children describe alternatives, including list element schemas. Lua source is never
-- evaluated.
function addon:NewFieldSchemaDraft(fields, fieldOrder, requiredFields)
    local normalized, why = self:NormalizeCustomFieldSchema(fields, true)

    if not normalized then
        return nil, why
    end

    local order, errorCode = self:NormalizeCustomFieldOrder(fieldOrder, normalized)

    if not order then
        return nil, errorCode
    end

    local ranks = {}

    for i, path in ipairs(order) do
        ranks[pathKey(path)] = i
    end

    -- Turns a normalized schema value into a draft node: a scalar kind, or a record or union with children in field
    -- order.
    -- @param value table|string  The normalized schema value.
    -- @param path (string|number)[]  The field path of the value, used to look up its position in the stored order.
    -- @param name string|number|nil  The node's name (nil for the root).
    -- @return table  The draft node { name, kind, children }.
    local function build(value, path, name)
        if type(value) == 'string' then
            return { name = name, kind = value }
        end

        local node = { name = name, kind = value[1] ~= nil and 'union' or 'record', children = {} }
        local keys = {}

        for key in pairs(value) do
            keys[#keys + 1] = key
        end

        -- Sort order for the children of a node: numeric keys first by value, then named keys by their position in the
        -- stored
        -- field order, then by name.
        -- @param a string|number  The first key.
        -- @param b string|number  The second key.
        -- @return boolean  True when `a` sorts before `b`.
        table.sort(keys, function(a, b)
            if type(a) == 'number' then
                return a < b
            end

            local pa = copy(path)
            pa[#pa + 1] = a
            local pb = copy(path)
            pb[#pb + 1] = b
            local ra, rb = ranks[pathKey(pa)] or math.huge, ranks[pathKey(pb)] or math.huge

            if ra ~= rb then
                return ra < rb
            end

            return a < b
        end)

        for _, key in ipairs(keys) do
            local nextPath = copy(path)
            nextPath[#nextPath + 1] = key
            node.children[#node.children + 1] = build(value[key], nextPath, key)
        end

        return node
    end

    local d = { root = build(normalized, {}), undo = {}, redo = {}, revision = 0 }

    if requiredFields ~= nil then
        d.root.requiredFieldsPresent = true
        d.requiredFieldsInvalid = not self:NormalizeCustomConditionRequiredFields(requiredFields, normalized)
        local required = {}

        for _, name in ipairs(self:FilterCustomRequiredFields(requiredFields, normalized)) do
            required[name] = true
        end

        for _, node in ipairs(d.root.children) do
            if required[node.name] then
                node.required = true
            end
        end
    end

    -- Applies an edit function to the draft root.
    -- @param fn function  Called as fn(root) to edit the tree in place.
    -- @return boolean  True when the edit really changed the tree; false when it changed nothing.
    --
    -- Records an undo step (at most 50 are kept) only when the edit really changed the tree.
    function d:Change(fn)
        local before = copy(self.root)
        fn(self.root)

        if addon:SettingsDataEqual(before, self.root) then
            return false
        end

        self.revision = self.revision + 1
        self.undo[#self.undo + 1] = before
        self.redo = {}

        while #self.undo > 50 do
            table.remove(self.undo, 1)
        end

        return true
    end

    -- Moves one step back (or forward when redo is true) through the history.
    -- @param redo boolean|nil  True to move forward.
    -- @return boolean  True when a step was taken; false when there is nothing to move.
    function d:Travel(redo)
        local from = redo and self.redo or self.undo
        local to = redo and self.undo or self.redo

        if #from == 0 then
            return false
        end

        to[#to + 1] = copy(self.root)
        self.root = table.remove(from)
        self.revision = self.revision + 1
        return true
    end

    -- Returns the node at a path of child indexes.
    -- @param path number[]  The child indexes from the root; empty for the root.
    -- @return table|nil  The node; nil when the path does not lead to a node.
    function d:Node(path)
        local node = self.root

        for _, index in ipairs(path) do
            if type(index) ~= 'number' or index % 1 ~= 0 or not node.children then
                return
            end

            node = node.children[index]

            if not node then
                return
            end
        end

        return node
    end

    -- Marks or unmarks a top-level field as required.
    -- @param path number[]  The path of the field; only top-level fields (one index) can be required.
    -- @param required boolean  The new required state.
    -- @return boolean  True when anything changed.
    function d:SetRequired(path, required)
        if #path ~= 1 or type(required) ~= 'boolean' then
            return false
        end

        local node = self:Node(path)

        if not node or (node.required == true) == required then
            return false
        end

        return self:Change(function(root)
            node.required = required or nil
            root.requiredFieldsPresent = true
        end)
    end

    -- Returns the path of the node that contains the node at path.
    -- @param path number[]  A non-empty node path.
    -- @return number[]  The parent's path.
    local function parentPath(path)
        local result = copy(path)
        table.remove(result)
        return result
    end

    -- Picks a legal field name under a record that no sibling uses.
    -- @param parent table  The record node the name is for.
    -- @param base string|nil  The preferred name; anything illegal falls back to 'field'.
    -- @param except table|nil  A child that does not count as a sibling (the node being renamed).
    -- @return string  The name, shortened and numbered as needed and avoiding the reserved top-level names.
    local function uniqueName(parent, base, except)
        base = type(base) == 'string' and base:match('^[%a_][%w_]*$') and base or 'field'

        if parent == d.root and (base == 'type' or base == 'disabled') then
            base = 'field'
        end

        local used = {}

        for _, child in ipairs(parent.children) do
            if child ~= except then
                used[child.name] = true
            end
        end

        base = base:sub(1, 64)
        local name = base
        local suffix = 1

        while used[name] do
            suffix = suffix + 1
            local ending = '_' .. suffix
            name = base:sub(1, 64 - #ending) .. ending
        end

        return name
    end

    -- Adds a new field at the end of a container.
    -- @param path number[]  The path of the container node.
    -- @param kind string|nil  The kind of the new field; default 'string'.
    -- @return boolean  True when it changed the draft.
    function d:Add(path, kind)
        local parent = self:Node(path)

        if not parent or not parent.children then
            return false
        end

        return self:Change(function()
            parent.children[#parent.children + 1] = {
                name = uniqueName(parent, 'field'),
                kind = kind or 'string',
                children = (kind == 'record' or kind == 'union') and { { name = 'field', kind = 'string' } } or nil,
            }
        end)
    end

    -- Inserts a copy of a node right after it, with a fresh name when the container is a record.
    -- @param path number[]  The path of the node to copy; must not be the root.
    -- @return boolean  True when it changed the draft.
    function d:Duplicate(path)
        local node = self:Node(path)
        local parent = self:Node(parentPath(path))

        if #path == 0 or not node or not parent then
            return false
        end

        return self:Change(function()
            local duplicate = copy(node)

            if parent.kind == 'record' then
                duplicate.name = uniqueName(parent, tostring(node.name):sub(1, 59) .. '_copy')
            end

            table.insert(parent.children, path[#path] + 1, duplicate)
        end)
    end

    -- Removes the node at a path.
    -- @param path number[]  The path of the node; must not be the root.
    -- @return boolean  True when it changed the draft.
    function d:Remove(path)
        if #path == 0 or not self:Node(path) then
            return false
        end

        local parent = self:Node(parentPath(path))

        return self:Change(function()
            table.remove(parent.children, path[#path])
        end)
    end

    -- Changes a node's kind.
    -- @param path number[]  The path of the node; must not be the root.
    -- @param kind string  'record', 'union', 'string', 'number', 'boolean', 'condition' or 'condition[]'; unknown kinds
    --   are rejected.
    -- @return boolean  True when it changed the draft.
    --
    -- Creates a starter child when the node becomes a record or union, renames record children so they stay legal and
    -- unique, and drops the children of a scalar kind.
    function d:SetKind(path, kind)
        local node = self:Node(path)

        if not node or #path == 0 then
            return false
        end
        if
            kind ~= 'record'
            and kind ~= 'union'
            and kind ~= 'string'
            and kind ~= 'number'
            and kind ~= 'boolean'
            and kind ~= 'condition'
            and kind ~= 'condition[]'
        then
            return false
        end

        -- Edit applied by SetKind: sets the node's kind, giving a record or union a starter child and renaming record
        -- children so
        -- they stay legal and unique, or dropping the children of a scalar kind.
        return self:Change(function()
            node.kind = kind

            if kind == 'record' or kind == 'union' then
                node.children = node.children or { { name = 'field', kind = 'string' } }

                if kind == 'record' then
                    local used = {}

                    for i, child in ipairs(node.children) do
                        local base = type(child.name) == 'string' and child.name:match('^[%a_][%w_]*$') and child.name
                            or 'field' .. i

                        local name = base
                        local suffix = 1

                        while used[name] do
                            suffix = suffix + 1
                            name = base .. '_' .. suffix
                        end

                        child.name = name
                        used[name] = true
                    end
                end
            else
                node.children = nil
            end
        end)
    end

    -- Reports whether a node may be moved into another slot.
    -- @param path number[]  The path of the node to move.
    -- @param destination number[]  The path of the target container.
    -- @param gap number  The slot in the target container (1 to its child count + 1).
    -- @param tail boolean|nil  True to move every later sibling with the node.
    -- @return boolean  True when the slot exists, the move changes something, a container does not move inside itself,
    --   and record names do not collide.
    function d:CanTransfer(path, destination, gap, tail)
        if #path == 0 or not self:Node(path) then
            return false
        end

        local parent = self:Node(parentPath(path))
        local target = self:Node(destination)
        local index = path[#path]

        if
            not target
            or not target.children
            or type(gap) ~= 'number'
            or gap % 1 ~= 0
            or gap < 1
            or gap > #target.children + 1
        then
            return false
        end

        local last = tail and #parent.children or index

        if target == parent and gap >= index and gap <= last + 1 then
            return false
        end

        -- A container always carries its descendants. Never insert it inside itself.
        if #destination >= #path then
            local sameParent = true

            for i = 1, #path - 1 do
                if destination[i] ~= path[i] then
                    sameParent = false
                end
            end

            if sameParent and destination[#path] >= index and destination[#path] <= last then
                return false
            end
        end

        if target ~= parent and target.kind == 'record' then
            local used = {}

            for _, child in ipairs(target.children) do
                used[child.name] = true
            end

            for i = index, last do
                local name = parent.children[i].name

                if type(name) == 'string' then
                    if used[name] then
                        return false
                    end

                    used[name] = true
                end
            end
        end

        return true
    end

    -- Moves a node (or, with tail, it and its later siblings) to a slot of the destination container if CanTransfer
    -- allows.
    -- @param path number[]  The path of the node to move.
    -- @param destination number[]  The path of the target container.
    -- @param gap number  The slot in the target container.
    -- @param tail boolean|nil  True to move every later sibling with the node.
    -- @return boolean  True when it changed the draft.
    --
    -- A node moved anywhere but the top level loses its required flag.
    function d:Transfer(path, destination, gap, tail)
        if not self:CanTransfer(path, destination, gap, tail) then
            return false
        end

        local parent = self:Node(parentPath(path))
        local target = self:Node(destination)
        local index = path[#path]
        local count = tail and #parent.children - index + 1 or 1

        -- Edit applied by Transfer: moves the nodes to the destination slot, clearing the required flag of nodes that
        -- leave the
        -- top level and naming unnamed nodes that enter a record.
        return self:Change(function()
            local moved = {}

            for _ = 1, count do
                moved[#moved + 1] = table.remove(parent.children, index)
            end

            if parent == target and gap > index then
                gap = gap - count
            end

            for i, node in ipairs(moved) do
                if target ~= self.root then
                    node.required = nil
                end
                if target.kind == 'record' and type(node.name) ~= 'string' then
                    node.name = uniqueName(target, 'field')
                end

                table.insert(target.children, gap + i - 1, node)
            end
        end)
    end

    -- Converts the draft back to stored form.
    -- @return table|nil  The stored schema; nil when the draft is invalid.
    -- @return table[]|string  The field order (a list of paths) on success, or the reason code (schema-limit,
    --   invalid-field-name, duplicate-field, invalid-required-fields) when the first return is nil.
    -- @return string[]|nil  The required names; nil when the draft never had a required list.
    function d:Snapshot()
        local order = {}
        local count = 0
        local active = {}

        -- Turns a draft node back into stored schema form, collecting the field order.
        -- @param node table  The draft node.
        -- @param path (string|number)[]  The field path of the node.
        -- @param depth number  The nesting depth (0 for the root).
        -- @return table|string  The stored form of the node.
        --
        -- Raises schema-limit, invalid-field-name or duplicate-field, which Snapshot catches.
        local function encode(node, path, depth)
            count = count + 1

            if count > 512 or depth > 16 or active[node] then
                error('schema-limit', 0)
            end

            if node.kind ~= 'record' and node.kind ~= 'union' then
                return node.kind
            end

            active[node] = true
            local result = {}

            for i, child in ipairs(node.children) do
                local key = node.kind == 'record' and child.name or i

                if node.kind == 'record' and not addon:IsEditableFieldSchemaName(key, depth == 0) then
                    error('invalid-field-name', 0)
                end
                if result[key] ~= nil then
                    error('duplicate-field', 0)
                end

                local nextPath = copy(path)
                nextPath[#nextPath + 1] = key
                order[#order + 1] = nextPath
                result[key] = encode(child, nextPath, depth + 1)
            end

            active[node] = nil
            return result
        end

        local ok, value = pcall(encode, self.root, {}, 0)

        if not ok then
            return nil, value
        end

        local checked, problem = addon:NormalizeCustomFieldSchema(value)

        if not checked then
            return nil, problem
        end

        local required

        if self.root.requiredFieldsPresent then
            required = {}

            for _, node in ipairs(self.root.children) do
                if node.required then
                    required[#required + 1] = node.name
                end
            end

            if #required > 128 then
                return nil, 'invalid-required-fields'
            end
        end

        return checked, order, required
    end

    return d
end
