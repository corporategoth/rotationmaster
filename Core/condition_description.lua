-- Condition description service: returns one readable text for a whole condition tree, for the editor's summaries,
-- the unsaved-changes comparison and draft diffs. It prefers the registered printers, and falls back to a bounded,
-- data-only description that never runs custom code when the tree could be unsafe to print (custom definitions,
-- disabled nodes, malformed groups, oversized trees). It reads and never modifies the condition. Loaded after
-- Core/condition_canvas.lua; the printers themselves are in Core/conditions.lua and the Conditions/ files.

local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- ============================================================================
-- Deciding whether the printers are safe to run
-- ============================================================================

-- Returns the definition table registered for the node's type tag, or nil. Uses rawget so a metatable cannot intervene.
local function definitionFor(node, definitions)
    local tag = type(node) == "table" and rawget(node, "type")
    local definition = type(tag) == "string" and type(definitions) == "table" and rawget(definitions, tag)
    return type(definition) == "table" and definition or nil
end

-- Returns the length of a list whose keys are exactly 1..n, or nil when it has holes or any non-integer key.
local function denseSize(list)
    local size, maximum = 0, 0

    for key in pairs(list) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
            return nil
        end

        size = size + 1
        maximum = math.max(maximum, key)
    end

    if size ~= maximum then
        return nil
    end

    return size
end

-- True when the tree must be described from its data alone instead of through the registered printers: a custom or
-- unknown definition, a disabled node, a malformed group or NOT, an announcement target, or a tree beyond 4096 nodes
-- or 32 levels. Printers run user code and assume well-formed input, so any doubt takes the data-only path.
local function needsDataOnly(value, definitions)
    local count = 0

    -- Returns true as soon as this node or any descendant forces the data-only path.
    local function inspect(node, depth)
        count = count + 1

        if count > 4096 or depth > 32 then
            return true
        end
        if type(node) ~= "table" then
            return false
        end
        if node.unit == 'announcementtarget' then
            return true
        end
        if node.disabled then
            return true
        end
        if node.type == "NOT" and (type(node.value) ~= "table" or node.value.type == nil) then
            return true
        end

        if node.type == "AND" or node.type == "OR" then
            if type(node.value) ~= "table" or next(node.value) == nil or not denseSize(node.value) then
                return true
            end

            for _, operand in pairs(node.value) do
                if type(operand) ~= "table" or operand.type == nil then
                    return true
                end
            end
        end

        local definition = definitionFor(node, definitions)

        if definition and (getmetatable(definition) ~= nil or rawget(definition, "customCode")) then
            return true
        end
        if node.type and node.type ~= "AND" and node.type ~= "OR" and node.type ~= "NOT" and not definition then
            return true
        end

        for _, child in pairs(node) do
            if inspect(child, depth + 1) then
                return true
            end
        end

        return false
    end

    return inspect(value, 0)
end

-- ============================================================================
-- Data-only description
-- ============================================================================

-- A bounded display-only projection; it never calls condition printers,
-- validators, providers or evaluators. Literal saved values are not templates.
-- Returns the text (with | doubled for display), a truncated flag and a reference flag (true when some part could only
-- be shown as a reference to its definition). Output is capped at 200 nodes, 16 levels and 8000 characters per part.
local function describeData(value, definitions, units)
    local count, truncated, reference = 0, false, false

    local templates = {
        FRIENDLY = {
            "{unit} {{!is friendly|is not friendly}}",
            "{unit} {{!are friendly|are not friendly}}",
            "Is Friendly",
        },
        DEAD = {
            "{unit} {{!is dead or a ghost|is alive}}",
            "{unit} {{!are dead or a ghost|are alive}}",
            "Is Dead or Ghost",
        },
        COMBAT = { "%s {{!is|is not}} in combat", "%s {{!are|are not}} in combat", "In Combat" },
        ENEMY = { "%s {{!is|is not}} an enemy", "%s {{!are|are not}} an enemy", "Hostile" },
        PVP = { "%s {{!is|is not}} PVP flagged", "%s {{!are|are not}} PVP flagged", "PVP Flagged" },
        ATTACKABLE = { "%s {{!is|is not}} attackable", "%s {{!are|are not}} attackable", "Attackable" },
    }

    -- Caps a text part at 8000 characters and records the truncation.
    ---@param text string
    local function bounded(text)
        if #text > 8000 then
            truncated = true
            return text:sub(1, 8000)
        end

        return text
    end

    -- Returns the display name for a unit token, or nil when it has none (the caller then asks for a unit).
    local function label(unit)
        if unit == 'announcementtarget' then
            return L['Announcement target']
        end
        if unit == 'spellrecipient' then
            return L['Spell recipient']
        end

        local text = type(unit) == 'string' and type(units) == 'table' and rawget(units, unit)

        if type(text) == 'string' and text ~= '' then
            return text:sub(1, 512)
        end
    end

    -- Expands a translated template for the positive or negated reading with the unit label filled in. Returns nil
    -- when the translation is oversized or still holds an unresolved alternative marker.
    local function phrase(key, unit, negated)
        local text = L[key]

        if type(text) ~= 'string' or #text > 2000 then
            return nil
        end

        -- Resolve only the authored template before inserting literal labels.
        text = text:gsub('{{!?([^|{}]*)|([^|{}]*)}}', function(positive, negative)
            return negated and negative or positive
        end)

        if text:find('{{', 1, true) then
            return nil
        end
        if text:find('{unit}', 1, true) then
            return (text:gsub('{unit}', function() return unit end))
        end

        local ok, result = pcall(string.format, text, unit)

        if ok then
            return result
        end
    end

    -- Describes the few simple unit conditions (friendly, dead, combat, enemy, PVP, attackable, group) from their
    -- data, but only when the definition is a plain, non-custom table whose description matches the built in text.
    -- Returns nil for everything else.
    local function projected(node, definition, negated)
        if not definition or getmetatable(definition) ~= nil or rawget(definition, 'customCode') then
            return nil
        end

        local fields = rawget(definition, 'fields')

        if type(fields) ~= 'table' or rawget(fields, 'unit') ~= 'string' then
            return nil
        end

        local tag = node.type

        if not templates[tag] and tag ~= 'GROUP' then
            return nil
        end
        if rawget(definition, 'description') ~= L[tag == 'GROUP' and 'In Group' or templates[tag][3]] then
            return nil
        end

        local unit = node.unit

        if tag == 'GROUP' and unit == nil then
            unit = 'player'
        end

        local subject = label(unit)

        if not subject then
            local text = L['Choose a unit for this condition.']
            return negated and L['NOT'] .. ' (' .. text .. ')' or text
        end

        if tag == 'GROUP' then
            if node.raid ~= nil and type(node.raid) ~= 'boolean' then
                local text = L['Group membership option is invalid.']
                return negated and L['NOT'] .. ' (' .. text .. ')' or text
            end

            local key

            if node.raid then
                key = unit == 'player' and '{unit} {{!are|are not}} in a raid' or '{unit} {{!is|is not}} in a raid'
            else
                key = unit == 'player' and '{unit} {{!are|are not}} in a party or raid'
                    or '{unit} {{!is|is not}} in a party or raid'
            end

            return phrase(key, subject, negated)
        end

        return phrase(templates[tag][unit == 'player' and 2 or 1], subject, negated)
    end

    -- Returns the node's keys in a stable order (numbers first, then by value), skipping those in `skip`.
    local function keys(node, skip)
        local result = {}

        for key in pairs(node) do
            if not skip or not skip[key] then
                result[#result + 1] = key
            end
        end

        table.sort(result, function(a, b)
            if type(a) == type(b) then
                return a < b
            end

            return type(a) == 'number'
        end)

        return result
    end

    -- Formats a saved value as text without interpreting it: strings are clipped, tables become [a; b; c].
    local function literal(item, depth)
        count = count + 1

        if count > 200 or depth > 16 then
            truncated = true
            return '...'
        end

        local kind = type(item)

        if kind == 'string' then
            if #item > 160 then
                truncated = true
            end

            return item:sub(1, 160)
        end

        if kind == 'boolean' then
            return item and L['Yes'] or L['No']
        end
        if kind == 'number' then
            return tostring(item)
        end
        if kind ~= 'table' then
            return L['Not specified']
        end

        local parts = {}

        for _, key in ipairs(keys(item)) do
            if count >= 200 then
                truncated = true
                parts[#parts + 1] = '...'
                break
            end

            parts[#parts + 1] = literal(item[key], depth + 1)
        end

        return bounded('[' .. table.concat(parts, '; ') .. ']')
    end

    -- Renders one node and its children. Returns the text and, for an AND/OR group shown positively, its type, so the
    -- parent can parenthesize a group of the other type. `negated` flips the reading for an enclosing NOT.
    local function render(node, depth, negated)
        count = count + 1

        if count > 200 or depth > 16 then
            truncated = true
            return '...'
        end

        if node == nil or type(node) == 'table' and next(node) == nil then
            return negated and L['Always false'] or L['Always']
        end

        if type(node) ~= 'table' then
            reference = true
            return L['Choose a condition']
        end

        local text, groupType

        if node.type == 'NOT' then
            if type(node.value) ~= 'table' then
                text = L['NOT'] .. ' (' .. L['Incomplete condition group: choose its conditions.'] .. ')'

                if negated then
                    text = L['NOT'] .. ' (' .. text .. ')'
                end
            else
                text, groupType = render(node.value, depth + 1, not negated)
            end
        elseif node.type == 'AND' or node.type == 'OR' then
            local size = type(node.value) == 'table' and denseSize(node.value)

            if not size then
                text = L['Incomplete condition group: choose its conditions.']
            else
                local parts = {}

                for index = 1, size do
                    if count >= 200 then
                        truncated = true
                        parts[#parts + 1] = '...'
                        break
                    end

                    local child = node.value[index]
                    local part, childType = render(child, depth + 1, false)

                    if childType and childType ~= node.type then
                        part = '(' .. part .. ')'
                    end

                    parts[#parts + 1] = part
                end

                if #parts == 0 then
                    text = node.type == 'AND' and L['Always (empty All group)'] or L['Never (empty Any group)']
                else
                    text = table.concat(parts, ' ' .. L[node.type] .. ' ')
                end
            end

            if negated then
                text = L['NOT'] .. ' (' .. text .. ')'
            end
            if not negated then
                groupType = node.type
            end
        else
            local definition = definitionFor(node, definitions)
            text = projected(node, definition, negated)

            if not text then
                reference = true
                local title = definition and rawget(definition, 'description')

                if type(title) ~= 'string' or title == '' then
                    title = type(node.type) == 'string' and string.format(L['Unknown condition: %s'], node.type:sub(
                        1,
                        160
                    ))
                        or L['Choose a condition']
                end

                text = title:sub(1, 512)
                local subject = label(node.unit)

                if subject then
                    text = text .. ' — ' .. string.format(L['For %s'], subject)
                end

                local values = {}

                for _, key in ipairs(keys(node, {
                    type = true,
                    name = true,
                    disabled = true,
                    unit = subject ~= nil,
                })) do
                    if count >= 200 then
                        truncated = true
                        values[#values + 1] = '...'
                        break
                    end

                    values[#values + 1] = literal(node[key], depth + 1)
                end

                if #values > 0 then
                    text = text .. ' — ' .. L['Saved settings'] .. ': ' .. table.concat(values, '; ')
                end
                if negated then
                    text = L['NOT'] .. ' (' .. text .. ')'
                end
            end

            if definition and (rawget(definition, 'disabled') or rawget(definition, 'functionUnavailable')) then
                text = string.format(L['Unavailable condition: %s'], text)
            end
        end

        if type(node.name) == 'string' and node.name ~= '' then
            text = node.name:sub(1, 512) .. ': ' .. text
        end
        if node.disabled then
            text = L['Disabled'] .. ': ' .. text
        end

        return bounded(text), groupType
    end

    local text = render(value, 0, false):gsub('|', '||')
    return text, truncated, reference
end

-- ============================================================================
-- Public API
-- ============================================================================

-- Returns the readable description of a condition tree for the given spec. Always returns a string: "Always" for an
-- empty tree, a notice for invalid data, otherwise the printed or data-only text capped at 64000 characters.
function addon:DescribeCondition(condition, spec)
    if self.RotationData and not self.RotationData.CheckPortable(condition) then
        return L["Condition description unavailable: invalid data."]
    end
    if type(condition) == "table" and next(condition) == nil then
        return L["Always"]
    end

    local definitions = self.conditionDefinitions or self.definitions or {}
    local text, truncated

    if not needsDataOnly(condition, definitions) then
        local value = self.RotationData and self.RotationData.CopyData(condition) or condition
        local ok, result = pcall(self.printCondition, self, value, spec)

        if ok and type(result) == "string" and result ~= "" then
            text = result
        end
    end

    if not text then
        local reference
        text, truncated, reference = describeData(condition, definitions, self.units)

        if reference then
            text = L["Condition reference (code is not run)."] .. " " .. text
        end
    end

    if #text > 64000 then
        text = text:sub(1, 64000)
        truncated = true
    end

    if truncated then
        text = text .. "\n" .. L["Condition description truncated; the draft is unchanged."]
    end

    return text
end

-- Disabled is a visual state on cards. Remove only flags on semantic condition
-- nodes in a detached copy; opaque custom payloads remain intact and data-only.
function addon:DescribeCardCondition(condition, spec)
    if not self.RotationData.CheckPortable(condition) then
        return self:DescribeCondition(condition, spec)
    end

    local value = self.RotationData.CopyData(condition)

    -- Clears the disabled flag on every AND/OR/NOT node of the copy, down to 32 levels.
    local function strip(node, depth)
        if type(node) ~= "table" or depth > 32 then
            return
        end

        node.disabled = nil

        if node.type == "AND" or node.type == "OR" then
            for _, child in ipairs(type(node.value) == "table" and node.value or {}) do
                strip(child, depth + 1)
            end
        elseif node.type == "NOT" then
            strip(node.value, depth + 1)
        end
    end

    strip(value, 0)
    return self:DescribeCondition(value, spec)
end
