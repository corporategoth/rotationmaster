-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Table helpers (keys, spairs, tomap, index, tablelength, multiinsert, cleanArray, deepcopy, compareArray) for
-- conditions, the UI and saved custom code.
-- This file owns the canonical bodies; utils.lua re-exports them as addon.keys, addon.spairs and the rest so saved
-- custom source that binds to those names keeps working.
-- Loaded from RotationMaster.toc with the other Functions/ files, before Functions/cache.lua and utils.lua.
-- Pure table work, no game API reads. Note deepcopy is a shallow copy of the top level, despite its name.
-- The function bodies are recorded as Built In helpers and are frozen: saved copies hash their exact text.
local _, addon = ...
local pairs, tostring = pairs, tostring

-- Canonical implementations; original addon APIs remain direct aliases.
local collections = {}
addon.Functions = addon.Functions or {}
addon.Functions.collections = collections

-- Returns the keys of a table sorted by their values (not by the keys themselves).
-- @param array table  The table whose values are compared; the values must be comparable with <.
-- @return any[]  The keys, ordered by their values.
collections.keys = function(array)
    local rv = {}
    for k,_ in pairs(array) do
        table.insert(rv, k)
    end
    -- Sort the keys
    table.sort(rv, function (lhs, rhs) return array[lhs] < array[rhs] end)
    return rv
end

-- Iterates a table in sorted key order, or in the order given by order(t, a, b) over the keys.
-- @param t table  The table to iterate.
-- @param order function|nil  Called as order(t, a, b) with two keys; returns true when a comes before b. nil sorts the
--   keys with <.
-- @return function  An iterator that returns the next key and its value, and nothing at the end.
--
-- The keys are snapshotted first, so changing values during the loop is safe but added keys are not visited.
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

-- Returns a copy of the table with every key converted to a string (so numeric keys become "1", "2", ...).
-- @param array table  The table to copy.
-- @return table  The copy, keyed by strings.
collections.tomap = function(array)
    local rv = {}
    for k,v in pairs(array) do
        rv[tostring(k)] = v
    end
    return rv
end

-- Finds the key under which the table holds a value.
-- @param array table|nil  The table to search.
-- @param value any  The value to look for (compared with ==).
-- @return any|nil  The first key found, in pairs order; nil when absent or when array is nil.
collections.index = function(array, value)
    if not array then return nil end

    for idx,v in pairs(array) do
        if (v == value) then
            return idx
        end
    end
end

-- Counts every entry of a table, hash part included (the # operator counts only a sequence).
-- @param T table|nil  The table to count; nil counts as zero.
-- @return number  The number of entries.
collections.tablelength = function(T)
    if T == nil then return 0 end
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

-- Inserts the list at the front of the target, item by item at positions 1..n, so the new items keep their order.
-- @param t table  The target list; changed in place.
-- @param values any[]  The items to insert.
collections.multiinsert = function(t, values)
    for i,v in ipairs(values) do
	    table.insert(t, i, v)
    end
end

-- Clears the table in place, keeping the keys listed in except; with invert true it clears only those keys instead.
-- @param array table|nil  The table to clear; nil does nothing.
-- @param except any[]|nil  The keys to keep (or, with invert, to clear).
-- @param invert boolean|nil  True to clear only the keys listed in except; nil means false.
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

-- Returns a new table with the top-level entries, dropping the keys listed in except (or keeping only them with invert
-- true).
-- @param array table|nil  The table to copy.
-- @param except any[]|nil  The keys to drop (or, with invert, to keep).
-- @param invert boolean|nil  True to keep only the keys listed in except; nil means false.
-- @return table|nil  The copy; nil when array is nil.
--
-- Nested tables are shared with the source, not copied.
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

-- Tells whether both tables hold the same keys with equal values.
-- @param lhs table  The first table.
-- @param rhs table  The second table.
-- @return boolean  True when every key has an equal value in both; values are compared with ==, so nested tables must
--   be the same table.
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
