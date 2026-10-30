-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Condition category helpers: validating a category icon, picking the icon a category shows, and parsing a category
-- import (either an "RM-ConditionCategory" envelope or a plain comma/space separated tag list). Pure data: it owns no
-- saved state and must not draw; the settings windows (UI/settings_conditions.lua) call it and do the writing. Loaded
-- from RotationMaster.toc after Core/reference_catalog.lua; needs addon.Artwork (Data/artwork.lua, generated) and the
-- condition registry (addon.conditionDefinitions, addon.conditionSpecials) at call time.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Reports whether a value can be used as a category icon.
-- @param value any  The candidate icon.
-- @return boolean  True for a texture path string up to 1024 bytes, or a positive whole file id.
function addon:IsCategoryIcon(value)
    return type(value) == 'string' and #value > 0 and #value <= 1024
        or type(value) == 'number' and value > 0 and value < math.huge and value % 1 == 0
end

local packagedCategoryIcons = addon.Artwork.category

-- Returns the icon a category shows.
-- @param group table|nil  The category record (icon, id, conditions); nil yields the DEFAULT icon.
-- @return string|number  The category's own explicit choice, else the packaged icon for its stable id, else the icon of
--   its first condition that has one, else the DEFAULT icon.
function addon:GetConditionCategoryIcon(group)
    if type(group) == 'table' then
        if self:IsCategoryIcon(group.icon) then
            return group.icon
        end

        -- Stable identity survives renames/reordering without inheriting an
        -- indexed AceDB default or changing a saved explicit icon choice.
        local packaged = packagedCategoryIcons[group.id]

        if packaged then
            return packaged
        end

        for _, tag in ipairs(group.conditions or {}) do
            local definition = (self.conditionDefinitions or {})[tag]

            if definition and definition.icon then
                return definition.icon
            end
        end
    end

    return packagedCategoryIcons.DEFAULT
end

-- Parses pasted category-import text into a category candidate.
-- @param text string  The pasted text (at most 128 KiB): an RM-ConditionCategory envelope or a plain comma/space
--   separated tag list.
-- @param codec table|nil  The codec whose Decode(text) method decodes an envelope; nil treats the text as a plain list.
-- @return table|nil  { conditions = string[], metadata = true|nil, name = string|nil, icon = string|number|nil } with
--   duplicate tags removed; nil when the text is invalid. metadata, name and icon are set only for an envelope.
-- @return string|nil  The localized reason when the first return is nil; nil otherwise.
--
-- Every tag must name a registered condition or special; the envelope's `codec` is supplied by the caller.
function addon:ParseConditionCategoryImport(text, codec)
    if type(text) ~= 'string' or #text > 131072 then
        return nil, L['Invalid import.']
    end

    local decoded = codec and codec:Decode(text)
    local value = decoded and decoded.value
    local result = { conditions = {} }

    if value then
        if
            type(value) ~= 'table'
            or value.format ~= 'RM-ConditionCategory'
            or value.version ~= 1
            or type(value.conditions) ~= 'table'
            or value.name ~= nil and (type(value.name) ~= 'string' or not value.name:find('%S'))
            or value.icon ~= nil and not self:IsCategoryIcon(value.icon)
        then
            return nil, L['Invalid import.']
        end

        result.metadata = true
        result.name = value.name
        result.icon = value.icon
        local count = 0

        for index, tag in pairs(value.conditions) do
            if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or type(tag) ~= 'string' then
                return nil, L['Invalid import.']
            end

            count = count + 1
        end

        if count ~= #value.conditions or count > 2000 then
            return nil, L['Invalid import.']
        end

        result.conditions = value.conditions
    else
        for tag in text:gmatch('[^,%s]+') do
            result.conditions[#result.conditions + 1] = tag

            if #result.conditions > 2000 then
                return nil, L['Invalid import.']
            end
        end
    end

    local seen, unique = {}, {}

    for _, tag in ipairs(result.conditions) do
        if not (self.conditionDefinitions or {})[tag] and not (self.conditionSpecials or {})[tag] then
            return nil, string.format(L['Unknown condition: %s'], tag)
        end

        if not seen[tag] then
            unique[#unique + 1] = tag
            seen[tag] = true
        end
    end

    result.conditions = unique
    return result
end
