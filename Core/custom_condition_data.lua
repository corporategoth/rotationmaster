-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Pure validation of custom condition data: legal tags, field schemas and the import envelope.
-- It owns the rules about what a stored or imported custom condition may contain; it must not compile or run the code
-- text a condition carries, and it saves nothing. Loaded from RotationMaster.toc after Core/collection_data.lua. The
-- Normalize* helpers ParseCustomConditionImport calls (Core/custom_authoring.lua, Core/functions.lua,
-- Core/schema_authoring.lua) load after it and are resolved at call time, so they only matter once an import is parsed.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- The code-valued members of a custom condition: each is stored as source text and must be present on import.
local functions = {
    valid = true,
    evaluate = true,
    print = true,
    widget = true,
    help = true,
    on_register = true,
    on_unregister = true,
}

-- Field types a custom condition schema may name; `legacy` is the one old compound type spelled as a string.
local kinds = { string = true, number = true, boolean = true, condition = true, ['condition[]'] = true }
local legacy = '{ string, { string, number } }'

-- True when key is a legal custom condition tag: only letters, digits and underscore, not a grammar keyword, and at
-- most 256 characters unless compatibility is set (loading data saved before the limit existed).
function addon:IsCustomConditionIdentifier(key, compatibility)
    return type(key) == 'string'
        and (compatibility or #key <= 256)
        and key:match('^[A-Za-z0-9_]+$') ~= nil
        and not ({ AND = true, OR = true, NOT = true, DELETE = true })[key]
end

-- Validates a custom condition field schema and returns a fresh normalized copy, or nil and a reason code
-- (schema-limit, unknown-field-type, invalid-schema, invalid-field-name, invalid-schema-shape). The copy never shares
-- tables with the input. compatibility raises the size limits so existing saved schemas keep loading.
function addon:NormalizeCustomFieldSchema(fields, compatibility)
    local active, nodes = {}, 0
    local visit

    -- Validates one schema node and returns a normalized copy, or nil and a reason. Counts nodes and tracks the tables
    -- on the current path, so size limits and cycles are refused.
    visit = function(value, depth, root)
        nodes = nodes + 1

        if nodes > (compatibility and 20000 or 512) or depth > (compatibility and 64 or 16) then
            return nil, 'schema-limit'
        end

        if type(value) == 'string' and not root then
            if value == legacy then
                return { 'string', { 'string', 'number' } }
            end
            if kinds[value] then
                return value
            end

            return nil, 'unknown-field-type'
        end

        if type(value) ~= 'table' or getmetatable(value) or active[value] then
            return nil, 'invalid-schema'
        end

        active[value] = true
        local copy = {}
        local count, numeric, named, max = 0, false, false, 0

        for key, child in pairs(value) do
            count = count + 1

            if
                type(key) == 'string'
                and #key > 0
                and #key <= (compatibility and 262144 or 64)
                and not key:find('%c')
                and (compatibility or key:match('^[%a_][%w_]*$'))
            then
                named = true
            elseif not root and type(key) == 'number' and key >= 1 and key % 1 == 0 then
                numeric = true
                max = math.max(max, key)
            else
                return nil, 'invalid-field-name'
            end

            local result, why = visit(child, depth + 1, false)

            if not result then
                return nil, why
            end

            copy[key] = result
        end

        active[value] = nil

        if numeric and named or numeric and max ~= count or not root and count == 0 then
            return nil, 'invalid-schema-shape'
        end

        return copy
    end

    return visit(fields, 0, true)
end

-- Decodes and validates a pasted custom condition (bare, or in the RM-CustomCondition envelope). Returns
-- { name = ..., condition = copy }, or nil and a localized reason. Nothing is saved or executed here, and every
-- member is checked, so unknown keys and non-string code are refused.
function addon:ParseCustomConditionImport(text, codec)
    local decoded, why = codec:Decode(text)

    if not decoded then
        return nil, why
    end

    local value = decoded.value
    local name

    if type(value) == 'table' and value.format ~= nil then
        if value.format ~= 'RM-CustomCondition' or value.version ~= 1 or type(value.name) ~= 'string' then
            return nil, L['Invalid custom condition.']
        end

        name = value.name
        value = value.condition
    end

    if
        type(value) ~= 'table'
        or type(value.description) ~= 'string'
        or not value.description:find('%S')
        or not self:IsCategoryIcon(value.icon)
        or not self:NormalizeCustomFieldSchema(value.fields, true)
    then
        return nil, L['Invalid custom condition.']
    end

    for key, child in pairs(value) do
        if functions[key] then
            if type(child) ~= 'string' then
                return nil, L['Invalid custom condition.']
            end
        elseif key == 'parameters' then
            if not self:NormalizeCustomConditionParameters(child) then
                return nil, L['Invalid custom condition.']
            end
        elseif key == 'requiredFields' then
            if not self:NormalizeCustomConditionRequiredFields(child, value.fields) then
                return nil, L['Invalid custom condition.']
            end
        elseif key == 'bindings' then
            if not self:NormalizeFunctionBindings(child, {
                { name = 'value' },
                { name = 'cache' },
                { name = 'evalStart' },
                { name = 'spec' },
                { name = 'parent' },
                { name = 'frame' },
                { name = 'tag' },
            }) then
                return nil, L['Invalid custom condition.']
            end
        elseif key == 'fieldOrder' then
            if not self:NormalizeCustomFieldOrder(child, value.fields) then
                return nil, L['Invalid custom condition.']
            end
        elseif key == 'disabled' then
            if type(child) ~= 'boolean' then
                return nil, L['Invalid custom condition.']
            end
        elseif key ~= 'description' and key ~= 'icon' and key ~= 'fields' then
            return nil, L['Invalid custom condition.']
        end
    end

    for key in pairs(functions) do
        if type(value[key]) ~= 'string' then
            return nil, L['Invalid custom condition.']
        end
    end

    return { name = name, condition = self:CopySettingsData(value) }
end
