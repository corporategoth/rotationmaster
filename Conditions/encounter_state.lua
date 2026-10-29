-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In conditions about the encounter around you, from the game itself rather than a boss mod: ENCOUNTER (a boss
-- encounter is in progress) and KEYSTONE_LEVEL (compares the active Mythic+ keystone level, 0 outside one). They read
-- Platform:GetEncounterObservation and GetKeystoneObservation (Platform/world_state.lua) through the per-poll cache.
-- The encounter reader answers only under the probe and restricted combat-data policies (Retail and Forever) and the
-- keystone reader only on Retail; elsewhere, or when a value is hidden, the condition is unavailable (nil, reason),
-- also under NOT. Boss mod encounters are in Conditions/bossmod.lua. Loaded from RotationMaster.toc after
-- Conditions/player_state.lua. Callback and helper bodies are hashed by saved copies and bundles: never add or change
-- text inside a function body, and leave the generated block at the end alone.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- What is going on around you, from the game itself (no boss mod): whether a
-- boss encounter is in progress, and the Mythic+ keystone level. The instance
-- difficulty and ID are optional parts of INSTANCE (Conditions/misc.lua). Each
-- is read through the platform adapter (Platform/world_state.lua), once per
-- evaluation, and an unreadable answer is unavailable (also under NOT).
local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
    },
    cache = { getCached = addon.Functions.cache.getCached },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/encounter_state.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
}

-- True for a finite number of 0 or more.
-- @param value any  The value to test.
-- @return boolean  True when value is a number, not NaN, at least 0 and below math.huge.
local function validNumber(value)
    return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

-- True when the saved fields carry a known operator and a finite, non-negative number to compare against.
-- @param value table  The saved condition fields; reads operator and value.
-- @return boolean  True when operator is one of addon.operators and value passes validNumber.
local function validCompare(value)
    return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and validNumber(value.value)
end

-- ENCOUNTER: true while a boss encounter is in progress. Stores no fields. False for a readable "no"; `nil, reason`
-- when the Platform cannot answer.
addon:RegisterCondition("ENCOUNTER", {
    description = L["Boss Encounter"],
    icon = addon.Artwork.condition["ENCOUNTER"],
    fields = {},
    -- Checks that the saved fields of the ENCOUNTER condition are complete and in range.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Nothing to configure, so always valid.
    valid = function()
        return true
    end,
    -- Decides whether a boss encounter is in progress.
    -- @param _ any  Unused; this condition has no fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Returns the cached Platform observation unchanged: a boolean, or nil and a reason.
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetEncounterObservation, addon.Platform)
    end,
    -- Builds the readable rule summary for the ENCOUNTER condition.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary; there are no fields to mention.
    print = function()
        return L["a boss encounter {{!is|is not}} in progress"]
    end,
    -- Builds the help page for the ENCOUNTER condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- help draws the help page; there is no widget because nothing is configurable.
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches while the game says a boss encounter is in progress. Unlike the Boss Mod Encounter condition it needs no boss mod, and it knows nothing of which boss or stage it is. It starts when the encounter starts and ends on a kill, a wipe or a reset. It reads in combat on every edition, Retail and Forever included."]))
    end,
})

-- KEYSTONE_LEVEL: compares the level of the Mythic+ keystone being run (0 when none is) with a number. Stores
-- `operator` and `value`. Returns `nil, reason` when the keystone cannot be read ("missing-api" off Retail).
addon:RegisterCondition("KEYSTONE_LEVEL", {
    description = L["Mythic+ Keystone Level"],
    icon = addon.Artwork.condition["KEYSTONE_LEVEL"],
    requiredFields = { "operator", "value" },
    fields = { operator = "string", value = "number" },
    -- Checks that the saved fields of the KEYSTONE_LEVEL condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a known operator and a finite, non-negative number.
    valid = function(_, value)
        return validCompare(value)
    end,
    -- Compares the level of the Mythic+ keystone being run (0 when none is) with the configured number.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the keystone observation fails; otherwise compares its level.
    evaluate = function(value, cache)
        local keystone, reason = Functions.cache.getCached(cache, addon.Platform.GetKeystoneObservation, addon.Platform)
        if not keystone then return nil, reason end
        return Functions.values.compare(value.operator, keystone.level, value.value)
    end,
    -- Builds the readable rule summary for the KEYSTONE_LEVEL condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary of the level comparison.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["the level of your active Mythic+ keystone"],
            Functions.presentation.nullable(value.value))
    end,
    -- Builds the editor controls for the KEYSTONE_LEVEL condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds an operator-and-level control; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        parent:AddChild(addon:Widget_OperatorWidget(value, L["Level"], function() top:SetStatusText(funcs:print(root, spec)) end))
    end,
    -- Builds the help page for the KEYSTONE_LEVEL condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["The level of the Mythic+ keystone you are running. It is 0 whenever you are not in a Mythic+ dungeon, so 'at least 10' is only true inside a run of that level. Retail only."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mythic+ Keystone Level"], L["Level"],
            L["The keystone level of the Mythic+ dungeon you are running; 0 when you are not in one."])
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="helpers" then return helpers end
        if name=="validCompare" then return validCompare end
        if name=="validNumber" then return validNumber end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/encounter_state.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/encounter_state.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
