-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

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
local function copy(value)
    return addon:CopySettingsData(value)
end

-- Flattens a field path (a list of string and number keys) into one string, so paths can key a table; the key type is
-- part of the text, so 1 and "1" differ.
local function pathKey(path)
    local parts = {}

    for _, key in ipairs(path) do
        parts[#parts + 1] = type(key) .. ':' .. tostring(key)
    end

    return table.concat(parts, '/')
end

-- True when name is a legal editable field name: a short identifier, and at the top level not one of the reserved
-- condition keys type and disabled.
function addon:IsEditableFieldSchemaName(name, root)
    return type(name) == 'string'
        and #name <= 64
        and name:match('^[%a_][%w_]*$') ~= nil
        and not (root and (name == 'type' or name == 'disabled'))
end

-- Validates a stored field display order (a list of paths into the schema) against the schema. Returns a fresh copy, an
-- empty list for nil, or nil and invalid-field-order when it is not a dense list of distinct, existing paths.
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

-- Returns the names in a required-fields list that still exist in the schema, deduplicated and capped at 128, or nil
-- when there is no list. Entries that no longer match a field are dropped.
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
-- Returns the draft, or nil and a reason code when the stored schema does not normalize. The draft is a tree of nodes
-- (record, union or a scalar kind); every method below changes it through Change so each edit lands on the bounded undo
-- stack, and Snapshot turns it back into stored form.
-- A schema is data: records have named children; numeric children describe
-- alternatives, including list element schemas. Lua source is never evaluated.
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
    local function build(value, path, name)
        if type(value) == 'string' then
            return { name = name, kind = value }
        end

        local node = { name = name, kind = value[1] ~= nil and 'union' or 'record', children = {} }
        local keys = {}

        for key in pairs(value) do
            keys[#keys + 1] = key
        end

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

    -- Applies an edit function to the draft root. Returns true and records an undo step (at most 50 are kept) only when
    -- the edit really changed the tree.
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

    -- Moves one step back (or forward when redo is true) through the history. Returns false when there is nothing to
    -- move.
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

    -- Returns the node at a path of child indexes (the root for an empty path), or nil when the path does not lead to a
    -- node.
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

    -- Marks or unmarks a top-level field as required. Only top-level fields can be required; returns whether anything
    -- changed.
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
    local function parentPath(path)
        local result = copy(path)
        table.remove(result)
        return result
    end

    -- Picks a legal field name under a record that no sibling (other than except) uses, shortening and numbering it as
    -- needed and avoiding the reserved top-level names.
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

    -- Adds a new field of the given kind (default string) at the end of the container at path; returns whether it
    -- changed.
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

    -- Inserts a copy of the node right after it, with a fresh name when the container is a record.
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

    -- Removes the node at path.
    function d:Remove(path)
        if #path == 0 or not self:Node(path) then
            return false
        end

        local parent = self:Node(parentPath(path))

        return self:Change(function()
            table.remove(parent.children, path[#path])
        end)
    end

    -- Changes a node's kind, creating a starter child when it becomes a record or union, renaming record children so
    -- they stay legal and unique, and dropping the children of a scalar kind. Rejects unknown kinds.
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

    -- True when the node at path (and, with tail, every later sibling) may be moved into the container at destination
    -- at slot gap: the slot must exist, the move must change something, a container may not move inside itself, and
    -- record names may not collide.
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

    -- Moves the node (or, with tail, it and its later siblings) to slot gap of the destination container if CanTransfer
    -- allows it. A node moved anywhere but the top level loses its required flag.
    function d:Transfer(path, destination, gap, tail)
        if not self:CanTransfer(path, destination, gap, tail) then
            return false
        end

        local parent = self:Node(parentPath(path))
        local target = self:Node(destination)
        local index = path[#path]
        local count = tail and #parent.children - index + 1 or 1

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

    -- Converts the draft back to stored form and returns schema, field order, required names (nil when the draft never
    -- had a required list); or nil and a reason code when it is invalid (schema-limit, invalid-field-name,
    -- duplicate-field, invalid-required-fields).
    function d:Snapshot()
        local order = {}
        local count = 0
        local active = {}

        -- Turns a draft node back into stored schema form, collecting the field order. Raises schema-limit,
        -- invalid-field-name or duplicate-field, which Snapshot catches.
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
