local _,addon=...
local type,floor,tonumber,tostring=type,math.floor,tonumber,tostring

-- Canonical implementations. Legacy addon APIs reference these same functions.
local values={}
addon.Functions=addon.Functions or {}
addon.Functions.values=values

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

values.isin = function(array, value)
    return array[value] ~= nil
end

values.round = function (num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return floor(num * mult + 0.5) / mult
end

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
