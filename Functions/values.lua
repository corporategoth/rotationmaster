-- Numeric and comparison helpers (compare, isin, round, isint) used by conditions and saved custom code.
-- This file owns the canonical bodies; utils.lua re-exports them as addon.compare, addon.isin, addon.round and
-- addon.isint so saved custom source that binds to those names keeps working.
-- Loaded from RotationMaster.toc with the other Functions/ files, after constants.lua and before utils.lua.
-- Pure functions with no game API reads; callers must guard restricted values with platform:CanReadValue first.
-- The function bodies are recorded as Built In helpers and are frozen: saved copies hash their exact text.
local _, addon = ...
local type, floor, tonumber, tostring = type, math.floor, tonumber, tostring

-- Canonical implementations. Legacy addon APIs reference these same functions.
local values = {}
addon.Functions = addon.Functions or {}
addon.Functions.values = values

-- Applies a stored operator name (LESSTHAN, EQUALS, DIVISIBLE, ...) to two values.
-- @param operator string  The stored operator name.
-- @param left any  The left value; callers must pass comparable (readable) values.
-- @param right any  The right value.
-- @return boolean|nil  The result; nil (after logging a warning) for an unknown operator.
values.compare = function(operator, left, right)
    if operator == "LESSTHAN" then
        return left < right
    elseif operator == "LESSTHANOREQUALS" then
        return left <= right
    elseif operator == "GREATERTHAN" then
        return left > right
    elseif operator == "GREATERTHANOREQUALS" then
        return left >= right
    elseif operator == "EQUALS" then
        return left == right
    elseif operator == "NOTEQUALS" then
        return left ~= right
    elseif operator == "DIVISIBLE" then
        return (left % right) == 0
    else
        addon:warn("Invalid Operator %s", operator)
    end
end

-- Tells whether the set-style table has a non-nil entry under the key.
-- @param array table  A table keyed by value, not a list.
-- @param value any  The key to test.
-- @return boolean  True when array[value] is not nil.
values.isin = function(array, value)
    return array[value] ~= nil
end

-- Rounds half up to the given number of decimal places.
-- @param num number  The number to round.
-- @param numDecimalPlaces number|nil  The decimal places; nil means zero.
-- @return number  The rounded number.
values.round = function(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return floor(num * mult + 0.5) / mult
end

-- Tells whether a value is a whole number, given as a number or as a string that reads back unchanged.
-- @param num number|string  The value to test; "5" passes and "5.0" or "05" does not.
-- @return boolean  True for a whole number.
values.isint = function(num)
    if type(num) == "number" then
        return floor(num) == num
    elseif type(num) == "string" then
        local tmp = tonumber(num)
        if tmp ~= nil then
            return tostring(floor(tmp)) == num
        end
    end
    return false
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="compare" then return addon.Functions.values.compare end
        if name=="floor" then return floor end
        if name=="isin" then return addon.Functions.values.isin end
        if name=="isint" then return addon.Functions.values.isint end
        if name=="round" then return addon.Functions.values.round end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Functions/values.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Functions/values.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
