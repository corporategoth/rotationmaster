-- Display helpers (nullable, nullable_value, playerize, compareString, phrase, predicate) that condition print()
-- callbacks use to build the readable summary of a condition, painting missing values red.
-- This file owns the canonical bodies; utils.lua re-exports them as addon.nullable and friends for saved custom source.
-- Loaded from RotationMaster.toc with the other Functions/ files; needs the global color table (globals.lua), the
-- locale and addon.operators (constants.lua). phrase and predicate delegate to the summary manager in Core/.
-- The function bodies are recorded as Built In helpers and are frozen: saved copies hash their exact text.
local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local operators = addon.operators

-- Preserve the shared colors, captured positive map and live legacy dispatch.
local presentation = {}
addon.Functions = addon.Functions or {}
addon.Functions.presentation = presentation

-- Returns the value, or a red placeholder when it is nil.
-- @param value any  The value to show.
-- @param default string|nil  The placeholder text; nil means "<value>".
-- @return any  The value unchanged, or the red placeholder text when the value is nil.
presentation.nullable = function(value, default)
    if value == nil then
        if default ~= nil then
            return color.RED .. default .. color.RESET
        else
            return color.RED .. L["<value>"] .. color.RESET
        end
    end
    return value
end

-- Looks the value up in a label table and returns the label, or the red placeholder when the value or the table is
-- missing or the table has no entry for it.
-- @param value any  The key to look up.
-- @param array table|nil  The label table.
-- @param default string|nil  The placeholder text; nil means "<value>".
-- @return any  The label, or the red placeholder text.
presentation.nullable_value = function(value, array, default)
    if value == nil or array == nil or type(array) ~= "table" then
        if default ~= nil then
            return color.RED .. default .. color.RESET
        else
            return color.RED .. L["<value>"] .. color.RESET
        end
    end
    return addon.nullable(array[value], default)
end

-- Picks the wording for the player ("you") or another unit when a summary reads differently for each.
-- @param unit string  The unit token.
-- @param player any  The wording used when unit is "player".
-- @param nonplayer any  The wording used for any other unit.
-- @return any  player or nonplayer.
presentation.playerize = function(unit, player, nonplayer)
    if (unit == "player") then
        return player
    else
        return nonplayer
    end
end

-- Builds the text "left <operator text> right" for a stored operator.
-- @param operator string  The stored operator name (a key of addon.operators).
-- @param left string  The text before the operator.
-- @param right string  The text after the operator.
-- @param primary boolean|nil  True marks the predicate as the one that flips under negation.
-- @return string  The comparison text.
--
-- When the operator has a negated form the text carries a {{positive|negative}} alternative (marked with "!" when
-- primary) that the summary renderer picks from.
presentation.compareString = function(operator, left, right, primary)
    local positive=addon.nullable(operators[operator], L["<operator>"])
    local negative=(addon.negatedOperators or {})[operator]
    local predicate=negative and ('{{'..(primary and '!' or '')..positive..'|'..negative..'}}') or positive
    return left .. " " .. predicate .. " " .. right
end

-- Expands a summary phrase template with its values through the condition summary manager.
-- @param template string  The phrase template (see addon:CreateConditionSummaryPhrase).
-- @param values table  The values the template inserts, by name.
-- @return table  The summary object (the invalid object for bad input).
--
-- Named summaries delegate to one canonical manager, including editable clones.
presentation.phrase = function(template, values)
    return addon:CreateConditionSummaryPhrase(template, values)
end

-- Builds the summary predicate for a stored operator, with its negated alternative when one exists.
-- @param operator string  The stored operator name (a key of addon.operators).
-- @param primary boolean|nil  True marks the predicate as the one that flips under negation.
-- @return table  The summary predicate object (see addon:CreateConditionSummaryPredicate).
presentation.predicate = function(operator, primary)
    local positive=addon.nullable(operators[operator], L["<operator>"])
    return addon:CreateConditionSummaryPredicate(positive, (addon.negatedOperators or {})[operator], primary)
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="compareString" then return addon.Functions.presentation.compareString end
        if name=="nullable" then return addon.Functions.presentation.nullable end
        if name=="nullable_value" then return addon.Functions.presentation.nullable_value end
        if name=="operators" then return operators end
        if name=="phrase" then return addon.Functions.presentation.phrase end
        if name=="playerize" then return addon.Functions.presentation.playerize end
        if name=="predicate" then return addon.Functions.presentation.predicate end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Functions/presentation.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Functions/presentation.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
