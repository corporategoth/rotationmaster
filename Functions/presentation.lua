local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color=color
local operators=addon.operators

-- Preserve the shared colors, captured positive map and live legacy dispatch.
local presentation={}
addon.Functions=addon.Functions or {}
addon.Functions.presentation=presentation

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

presentation.playerize = function(unit, player, nonplayer)
    if (unit == "player") then
        return player
    else
        return nonplayer
    end
end

presentation.compareString = function(operator, left, right, primary)
    local positive=addon.nullable(operators[operator], L["<operator>"])
    local negative=(addon.negatedOperators or {})[operator]
    local predicate=negative and ('{{'..(primary and '!' or '')..positive..'|'..negative..'}}') or positive
    return left .. " " .. predicate .. " " .. right
end

-- Named summaries delegate to one canonical manager, including editable clones.
presentation.phrase = function(template, values)
    return addon:CreateConditionSummaryPhrase(template, values)
end

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
