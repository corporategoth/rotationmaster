-- Visual comparison model: turns a structural diff (Data/diff.lua) plus the two detached rotation snapshots into the
-- row-by-row model the comparison window draws (cooldown and rotation rows paired by step identity, with changed,
-- moved, added and removed flags and counts of changes the rows do not show).
-- It consumes trusted detached data only: it never evaluates conditions, reads saved data or touches the game, and it
-- caps itself at 200 rows and 500 changes (marking the model incomplete beyond that).
-- Loaded from RotationMaster.toc after Data/diff.lua; uses data.IndexRotationSteps (Data/rotation_tree.lua),
-- GetRotationTags (Data/tags.lua) and GetRotationPriority (Data/validation.lua). The window that draws the model is
-- UI/rotation_comparison.lua.
local _, addon = ...
local data = addon.RotationData

-- ============================================================================
-- Row pairing helpers
-- ============================================================================

-- Tells whether a changed step flag is not a real difference.
-- @param path table[]  The change's path segments, each { kind, key }.
-- @param row table|nil  The paired row, with left and right sides.
-- @param stepIndex number  The index of the step segment in path.
-- @return boolean  True when the change is to use_name, ranked or disabled and both sides resolve to the same value.
--
-- A missing flag reads as its implied default (use_name follows whether the step has a name).
local function equivalentStepDefault(path, row, stepIndex)
    if
        #path ~= stepIndex + 1
        or not path[stepIndex + 1]
        or path[stepIndex + 1].kind ~= "field"
        or not row
        or not row.left
        or not row.right
    then
        return false
    end

    local key = path[stepIndex + 1].key

    if key ~= "use_name" and key ~= "ranked" and key ~= "disabled" then
        return false
    end

    -- Resolves the flag on one step, applying the implied default when the field is absent.
    -- @param step table  The step.
    -- @return boolean  The flag value.
    local function flag(step)
        if step[key] ~= nil then
            return step[key]
        end
        if key == "use_name" then
            return type(step.name) == "string" and #step.name > 0
        end

        return false
    end

    return flag(row.left.step) == flag(row.right.step)
end

-- Step fields the comparison rows already display; a change to any other field is counted as an additional change.
local shownFields = {
    type = true,
    action = true,
    conditions = true,
    disabled = true,
    ranked = true,
    name = true,
    use_name = true,
    mode = true,
    onTrue = true,
    onFalse = true,
}

-- Builds a string key from the path segments 2 through last.
-- @param path table[]  The path segments, each { kind, key }.
-- @param last number  The index of the last segment to include.
-- @return string  The key; each segment is length-prefixed so no key can impersonate another segment.
--
-- Only structural field and step segments form identity locations. Numeric source positions are replaced with
-- canonical ids, so same-arm reordering still pairs but moving across parents or arms stays an explicit removal plus
-- addition.
local function locationKey(path, last)
    local parts = {}

    for i = 2, last do
        local segment = path[i]
        local text = tostring(segment.key)
        parts[#parts + 1] = segment.kind .. ":" .. #text .. ":" .. text
    end

    return table.concat(parts, "/")
end

-- Computes the location key of the step at a numeric body path.
-- @param body table  The rotation body.
-- @param path table  The numeric body path to the step.
-- @param origins table  Maps a clone's regenerated step ids back to the source ids.
-- @return string  The location key, with each position replaced by the step's canonical id so the same step pairs
--   across both sides.
local function rowLocation(body, path, origins)
    local cursor = body
    local segments = { { kind = "field", key = "body" } }

    for _, key in ipairs(path) do
        cursor = cursor[key]

        segments[#segments + 1] = type(key) == "number" and { kind = "step", key = origins[cursor.id] or cursor.id }
            or { kind = "field", key = key }
    end

    return locationKey(segments, #segments)
end

-- ============================================================================
-- Comparison model
-- ============================================================================

-- Builds the visual comparison model from a structural diff and the two snapshots.
-- @param view table  { diff, left, right, leftOrigins?, rightOrigins? }.
-- @return table|nil  The model (groups.cooldowns and groups.rotation rows, name, switch, tag and priority fields,
--   change flags and counts); nil for malformed or over-limit input.
-- @return string|nil  'invalid-comparison' when the first return is nil; nil otherwise.
--
-- Consumes the trusted structural diff and detached snapshots supplied by the library facade. Canonical identities
-- never depend on rendered path strings.
function data.BuildVisualComparison(view)
    if
        type(view) ~= "table"
        or type(view.diff) ~= "table"
        or not view.diff.valid
        or type(view.left) ~= "table"
        or type(view.right) ~= "table"
    then
        return nil, "invalid-comparison"
    end

    -- Each snapshot already has its own portable-data budget. Re-counting the
    -- duplicated before/after values in a diff rejects valid large rotations.
    for _, key in ipairs({ "left", "right", "leftOrigins", "rightOrigins" }) do
        if not data.CheckPortable(view[key]) then
            return nil, "invalid-comparison"
        end
    end

    if type(view.diff.changes) ~= "table" or #view.diff.changes > 500 then
        return nil, "invalid-comparison"
    end

    for _, change in ipairs(view.diff.changes) do
        if type(change) ~= "table" or not data.CheckPortable(change) then
            return nil, "invalid-comparison"
        end
    end

    local model = { groups = {}, complete = view.diff.complete == true, additionalChanges = 0, displayChangeCount = 0 }
    local a, b = view.left.body or {}, view.right.body or {}
    model.leftName = a.name
    model.rightName = b.name
    model.leftNameKey = view.left.nameKey
    model.rightNameKey = view.right.nameKey
    model.leftSwitch = data.CopyData(a.switch)
    model.rightSwitch = data.CopyData(b.switch)
    model.leftTags = data.GetRotationTags(view.left) or {}
    model.rightTags = data.GetRotationTags(view.right) or {}
    model.leftPriority = data.GetRotationPriority(a.priority)
    model.rightPriority = data.GetRotationPriority(b.priority)
    local indexes = {}
    local total = 0

    for _, kind in ipairs({ "cooldowns", "rotation" }) do
        local rows, byId = {}, {}
        model.groups[kind] = rows
        indexes[kind] = byId

        for _, side in ipairs({ "left", "right" }) do
            local body = side == "left" and a or b
            local origins = view[side .. "Origins"] or {}
            local tree = data.IndexRotationSteps(body)

            if not tree then
                return nil, "invalid-comparison"
            end

            for _, entry in ipairs(tree.rows) do
                if entry.section == kind then
                    local step, index = entry.step, entry.index
                    local id = origins[step.id] or step.id
                    local location = rowLocation(body, entry.path, origins)
                    local row = byId[location]

                    if not row then
                        if total >= 200 then
                            model.complete = false
                        else
                            row = { id = id }
                            byId[location] = row
                            rows[#rows + 1] = row
                            total = total + 1
                        end
                    end

                    if row then
                        local branchPath = {}
                        local ancestor = entry

                        while ancestor.parentId do
                            local parent = tree.byId[ancestor.parentId]

                            table.insert(branchPath, 1, {
                                id = origins[parent.step.id] or parent.step.id,
                                name = parent.step.name,
                                arm = ancestor.arm,
                            })

                            ancestor = parent
                        end

                        local value = {}

                        for key, field in pairs(step) do
                            if not (step.type == "branch" and (key == "onTrue" or key == "onFalse")) then
                                value[key] = field
                            end
                        end

                        row[side] = {
                            index = index,
                            step = data.CopyData(value),
                            depth = entry.depth,
                            arm = entry.arm,
                            branchPath = branchPath,
                        }
                    end
                end
            end
        end

        for _, row in ipairs(rows) do
            row.added = row.left == nil
            row.removed = row.right == nil
        end
    end

    for _, change in ipairs(view.diff.changes or {}) do
        local path = change.segments or {}
        local kind = path[2] and path[2].key

        if
            path[1]
            and path[1].kind == "field"
            and path[1].key == "body"
            and path[2]
            and path[2].kind == "field"
            and indexes[kind]
            and path[3]
            and path[3].kind == "step"
        then
            local stepIndex = 3

            for i = 4, #path do
                if path[i].kind == "step" then
                    stepIndex = i
                end
            end

            local row = indexes[kind][locationKey(path, stepIndex)]

            if not equivalentStepDefault(path, row, stepIndex) then
                model.displayChangeCount = model.displayChangeCount + 1

                if row then
                    if change.kind == "moved" then
                        row.moved = true
                    elseif row.left and row.right then
                        row.changed = true
                    end
                end

                if path[stepIndex + 1] and not shownFields[path[stepIndex + 1].key] then
                    model.additionalChanges = model.additionalChanges + 1
                end

                if #path == stepIndex then
                    local whole = change.after or change.before

                    if type(whole) == "table" then
                        for key in pairs(whole) do
                            if key ~= "id" and not shownFields[key] then
                                model.additionalChanges = model.additionalChanges + 1
                            end
                        end
                    end
                end
            end
        elseif not (#path == 2
            and path[1].kind == 'field'
            and path[1].key == 'body'
            and path[2].kind == 'field'
            and kind == 'priority'
            and model.leftPriority ~= nil
            and model.leftPriority == model.rightPriority) then
            model.displayChangeCount = model.displayChangeCount + 1
            model.settingsChanged = true
            local rootName = #path == 1 and path[1].kind == "field" and path[1].key == "nameKey"

            local bodyName = #path == 2
                and path[1].kind == "field"
                and path[1].key == "body"
                and path[2].kind == "field"
                and kind == "name"

            if kind == "switch" then
                model.switchChanged = true
            elseif rootName or bodyName then
                model.namesChanged = true
            elseif kind == "tags" or path[1] and path[1].kind == "field" and path[1].key == "tags" then
                model.tagsChanged = true
            elseif kind == 'priority' then
                model.priorityChanged = true
            else
                model.additionalChanges = model.additionalChanges + 1
            end
        end
    end

    return model
end
