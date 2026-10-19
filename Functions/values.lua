local _,addon=...

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

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="compare" then return addon.Functions.values.compare end
        if name=="isin" then return addon.Functions.values.isin end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Functions/values.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Functions/values.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
