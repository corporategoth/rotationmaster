-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

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

-- Splits a string on a Lua pattern character class (whitespace by default).
-- @param inputstr string  The string to split.
-- @param sep string|nil  The separator characters, spliced into a character class; nil means "%s".
-- @return string[]  The non-empty pieces.
--
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

-- Word-wraps a string by inserting newlines so lines stay near the limit without splitting words.
-- @param str string  The text to wrap.
-- @param limit number|nil  The line length; nil means 72 columns.
-- @return string  The wrapped text; a single word longer than the limit stays whole.
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

-- Strips leading and trailing whitespace.
-- @param s string  The string to trim.
-- @return string  The trimmed string (not the gsub count).
text.trim = function(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Tells whether the string begins with the given plain prefix.
-- @param str string  The string to test.
-- @param start string  The prefix.
-- @return boolean  True when str begins with start.
text.starts_with = function(str, start)
    return str:sub(1, #start) == start
end

-- Tells whether the string ends with the given plain suffix.
-- @param str string  The string to test.
-- @param ending string  The suffix; an empty suffix always matches.
-- @return boolean  True when str ends with ending.
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
