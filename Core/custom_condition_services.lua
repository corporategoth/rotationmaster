-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Services for player-written custom conditions that do not depend on any window: the empty-condition template a new
-- custom condition starts from, the callback signatures, the loadstring-based compiler used for the historical
-- compatibility path, and registration of a saved custom condition into the condition registry. Must not draw; the
-- editors (UI/condition_source_pane.lua, UI/custom_condition_editor.lua) are callers. Saved custom conditions store
-- these callbacks as source text, so the template header text below is matched against saved source and must not
-- change. Loaded from RotationMaster.toc after Core/custom_authoring.lua, which supplies addon:CompileCustomCondition.

local _, addon = ...

local uuid = addon.uuid
local pairs = pairs

-- ============================================================================
-- Callback signatures and the empty template
-- ============================================================================

-- Parameter list each custom callback is compiled with; also the list of callbacks a custom condition must supply.
local function_signatures = {
    on_register = "function(tag)",
    on_unregister = "function(tag)",
    valid = "function(spec, value)",
    evaluate = "function(value, cache, evalStart)",
    print = "function(spec, value)",
    widget = "function(parent, spec, value)",
    help = "function(frame)",
}

-- The condition a new custom condition starts from. Each callback text begins with an explanatory comment header; the
-- loop below moves those headers into `templateHeaders`, so the stored template is the code after the header.
addon.empty_condition = {
    description = "",
    icon = "Interface\\Icons\\Inv_misc_questionmark",
    fields = {},
    on_register = [[
-- Call this when the condition is registered (could initialize some data or something).
-- Params:
--    tag - The tag (aka. type) this condition is registered as
]],
    on_unregister = [[
-- Call this when the condition is unregistered (could destroy some data or something).
-- Params:
--    tag - The tag (aka. type) this condition was registered as
]],
    valid = [[
-- Validate that the condition has all required values set and they are in
-- acceptable bounds.  This does not indicate if the condition is true or not.
-- Params:
--    spec - The talent specialization in use (as a number).
--    value - The storage for this condition (ie. where it's parameters are stored).
-- Return: true if the condition is valid

return true
]],
    evaluate = [[
-- Evaluate the condition at runtime, and let us know if the current situation
-- makes this condition pass.
-- Params:
--    value - The storage for this condition (ie. where it's parameters are stored).
--    cache - A cache for this evaluation run (it is reset every evaluation cycle).
--            You can also use addon.combatCache (only reset when going out of combat)
--            or addon.longtermCache (only reset when your skills are updated).
--    evalStart - The timestamp (GetTime()) of when this evaluation cycle started.
-- Return: true if the condition passes

return true
]],
    print = [[
-- Create a printable string that describes this condition in words.
-- Params:
--    spec - The talent specialization in use (as a number).
--    value - The storage for this condition (ie. where it's parameters are stored).
-- Return: A string that describes this condition

return ''
]],
    widget = [[
-- Create the widgets required to configure this condition.
-- Params:
--    parent - A bounding box that will contain this condition's widgets.
--    spec - The talent specialization in use (as a number).
--    value - The storage for this condition (ie. where it's parameters are stored).
local top = parent:GetUserData("top")
local root = top:GetUserData("root")
local funcs = top:GetUserData("funcs")

]],
    help = [[
-- Create the required help information for this condition
-- Params:
--    frame - The frame the help widgets will be layed out in.
local helpers = addon.help_funcs

]],
}

-- ============================================================================
-- Editor source preparation
-- ============================================================================

-- Retain exact old template headers only to recognize generated boilerplate in
-- saved conditions. Arbitrary user comments are preserved.
local templateHeaders = {}

for name in pairs(function_signatures) do
    local code = addon.empty_condition[name]
    local offset = 1

    while offset <= #code do
        local ending = code:find('\n', offset, true) or #code + 1
        local line = code:sub(offset, ending - 1)

        if line:match('^%s*%-%-') or line:match('^%s*$') then
            offset = ending + 1
        else
            break
        end
    end

    templateHeaders[name] = code:sub(1, offset - 1)
    addon.empty_condition[name] = code:sub(offset)
end

-- Returns a copy of a saved custom condition for editing.
-- @param source table  The saved custom condition.
-- @param preserveFormatting boolean|nil  True to return the copy untouched.
-- @return table  The copy; unless `preserveFormatting`, the generated boilerplate header is stripped from each callback
--   (user comments are kept) and the code is normalized for the editor.
function addon:PrepareCustomConditionEditorSource(source, preserveFormatting)
    local result = self:CopySettingsData(source)

    if preserveFormatting then
        return result
    end

    for name, prefix in pairs(templateHeaders) do
        if prefix ~= '' and type(result[name]) == 'string' and result[name]:sub(1, #prefix) == prefix then
            result[name] = result[name]:sub(#prefix + 1)
        end
    end

    for name in pairs(self.CustomConditionCallbacks) do
        if type(result[name]) == 'string' then
            result[name] = self:NormalizeLuaSourceForEditor(result[name])
        end
    end

    return result
end

-- ============================================================================
-- Compiling and registering
-- ============================================================================

-- Compiles one callback's source text into a function.
-- @param sel string  The callback name, which selects the signature (for example "evaluate").
-- @param val string  The callback's source text.
-- @return function|nil  The compiled function; nil when it does not compile.
--
-- The chunk runs in the global environment with `addon` and `L` as locals.
local function compile_function(sel, val)
    local funcid = uuid()

    local str = string.format(
        [[
_G.%s.funcDeserialize["%s"] = %s
local addon = _G.%s
local L = LibStub("AceLocale-3.0"):GetLocale("%s")
%s
end
]],
        addon.name,
        funcid,
        function_signatures[sel],
        addon.name,
        addon.name,
        val
    )

    local comp = loadstring(str)

    if not comp then
        return nil
    end

    comp()
    local rv = addon.funcDeserialize[funcid]
    addon.funcDeserialize[funcid] = nil
    return rv
end

-- Deep copy of a field schema table, cycle-safe through `seen`.
-- @param value any  The value to copy; non-tables are returned as they are.
-- @param seen table|nil  The copies made so far, keyed by original; callers leave it nil.
-- @return any  The copy.
local function copy_fields(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy

    for key, field in pairs(value) do
        copy[key] = copy_fields(field, seen)
    end

    return copy
end

-- Registers a saved custom condition under a tag.
-- @param key string  The condition tag.
-- @param condition table  The saved custom condition.
-- @return boolean  True after registering; false when any callback does not compile.
--
-- Uses addon:CompileCustomCondition when it exists, otherwise compiles each callback itself.
function addon:register_custom_condition(key, condition)
    if self.CompileCustomCondition then
        local compiled = self:CompileCustomCondition(key, condition, true)

        if not compiled then
            return false
        end

        self:RegisterCondition(key, compiled)
        return true
    end

    local newcond = {
        description = condition.description,
        icon = condition.icon,
        fields = copy_fields(condition.fields or {}),
        customCode = true,
    }

    for field, _ in pairs(function_signatures) do
        local func = compile_function(field, condition[field])

        if not func then
            return false
        end

        newcond[field] = func
    end

    addon:RegisterCondition(key, newcond)
    return true
end

-- Internal bridge for the historical editor; ordinary authoring has no GUI dependency.
addon.CustomConditionServices = { signatures = function_signatures, compile = compile_function }
