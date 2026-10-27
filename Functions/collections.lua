local _, addon = ...
local pairs, tostring = pairs, tostring

-- Canonical implementations; original addon APIs remain direct aliases.
local collections = {}
addon.Functions = addon.Functions or {}
addon.Functions.collections = collections

collections.keys = function(array)
    local rv = {}
    for k,_ in pairs(array) do
        table.insert(rv, k)
    end
    -- Sort the keys
    table.sort(rv, function (lhs, rhs) return array[lhs] < array[rhs] end)
    return rv
end

collections.spairs = function(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

collections.tomap = function(array)
    local rv = {}
    for k,v in pairs(array) do
        rv[tostring(k)] = v
    end
    return rv
end

collections.index = function(array, value)
    if not array then return nil end

    for idx,v in pairs(array) do
        if (v == value) then
            return idx
        end
    end
end

collections.tablelength = function(T)
    if T == nil then return 0 end
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

collections.multiinsert = function(t, values)
    for i,v in ipairs(values) do
	    table.insert(t, i, v)
    end
end

collections.cleanArray = function(array, except, invert)
    if array == nil then
        return
    end
    if invert == nil then
        invert = false
    end

    for k,_ in pairs(array) do
        local skip = invert
        if except ~= nil then
            for _,v2 in pairs(except) do
                if (k == v2) then
                    skip = not invert
                    break
                end
            end
        end
        if not skip then
            array[k] = nil
        end
    end
end

collections.deepcopy = function(array, except, invert)
    if array == nil then
        return nil
    end
    if invert == nil then
        invert = false
    end

    local rv = {}
    for k,v in pairs(array) do
        local skip = invert
        if except ~= nil then
            for _,v2 in pairs(except) do
                if (k == v2) then
                    skip = not invert
                    break
                end
            end
        end
        if not skip then
            rv[k] = v
        end
    end
    return rv
end

collections.compareArray = function(lhs, rhs)
    for k,v in pairs(lhs) do
        if rhs[k] ~= v then
            return false
        end
    end
    for k,v in pairs(rhs) do
        if lhs[k] ~= v then
            return false
        end
    end
    return true
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="cleanArray" then return addon.Functions.collections.cleanArray end
        if name=="compareArray" then return addon.Functions.collections.compareArray end
        if name=="deepcopy" then return addon.Functions.collections.deepcopy end
        if name=="index" then return addon.Functions.collections.index end
        if name=="keys" then return addon.Functions.collections.keys end
        if name=="multiinsert" then return addon.Functions.collections.multiinsert end
        if name=="spairs" then return addon.Functions.collections.spairs end
        if name=="tablelength" then return addon.Functions.collections.tablelength end
        if name=="tomap" then return addon.Functions.collections.tomap end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Functions/collections.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Functions/collections.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
