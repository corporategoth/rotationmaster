-- String helpers (split, wrap, trim, starts_with, ends_with) for conditions, help text and saved custom code.
-- This file owns the canonical bodies; utils.lua re-exports them as addon.split, addon.wrap, addon.trim,
-- addon.starts_with and addon.ends_with so saved custom source that binds to those names keeps working.
-- Loaded from RotationMaster.toc with the other Functions/ files, before utils.lua. Pure string work, no game API.
-- The function bodies are recorded as Built In helpers and are frozen: saved copies hash their exact text.
local _, addon = ...
local string = string

-- Canonical text implementations; preserve the original captured string table.
local text = {}
addon.Functions = addon.Functions or {}
addon.Functions.text = text

-- Splits a string on a Lua pattern character class (whitespace by default) and returns the non-empty pieces as a list.
-- The separator is spliced into a character class, so it must be plain characters that are safe inside [^...].
text.split = function(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

-- Word-wraps a string by inserting newlines so lines stay near the limit (72 columns by default) without splitting
-- words; a single word longer than the limit stays whole.
text.wrap = function(str, limit)
    limit = limit or 72
    local here = 1

    -- the "".. is there because :gsub returns multiple values
    return ""..str:gsub("(%s+)()(%S+)()",
            function(_, st, word, fi)
                if fi-here > limit then
                    here = st
                    return "\n"..word
                end
            end)
end

-- Strips leading and trailing whitespace and returns only the string (not the gsub count).
text.trim = function(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Returns true when the string begins with the given plain prefix.
text.starts_with = function(str, start)
    return str:sub(1, #start) == start
end

-- Returns true when the string ends with the given plain suffix; an empty suffix always matches.
text.ends_with = function(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="ends_with" then return addon.Functions.text.ends_with end
        if name=="split" then return addon.Functions.text.split end
        if name=="starts_with" then return addon.Functions.text.starts_with end
        if name=="trim" then return addon.Functions.text.trim end
        if name=="wrap" then return addon.Functions.text.wrap end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Functions/text.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Functions/text.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
