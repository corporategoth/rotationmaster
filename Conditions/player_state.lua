-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In condition PLAYER_STATE: one fact about the player (mounted, swimming, flying, falling, in a rested area,
-- dead or ghost) chosen from a list. It reads Platform:GetPlayerStateObservation (Platform/world_state.lua) through the
-- per-poll cache, which answers only under the probe and restricted combat-data policies (Retail and Forever) and
-- reports "unsupported-policy" elsewhere; a value the client hides is "restricted-value". Either way the condition is
-- unavailable (nil, reason), also under NOT. Core/condition_support.lua checks the API each state needs. Loaded from
-- RotationMaster.toc after Conditions/bossmod.lua. Callback and helper bodies are hashed by saved copies and bundles:
-- never add or change text inside a function body, and leave the generated block at the end alone.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- One fact about the player's own state, chosen from a list: moving or resting
-- (mounted, swimming, flying, falling, in a rested area) and alive or not
-- (dead, ghost). Each is read through Platform:GetPlayerStateObservation
-- (Platform/world_state.lua) once per evaluation. No unit is chosen: it is
-- always you. A fact the game cannot answer, or answers with a secret value, is
-- unavailable (also under NOT); a readable "no" is an ordinary false. Stealth,
-- being outdoors and having full control are their own older conditions
-- (STEALTHED, OUTDOORS, INCONTROL), and "dead or ghost" of any unit is DEAD.
local Functions = {
    values = { isin = addon.Functions.values.isin },
    cache = { getCached = addon.Functions.cache.getCached },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/player_state.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
}

-- The states, in the order the editor lists them, and what each reads.
local STATE_ORDER = { "mounted", "swimming", "flying", "falling", "resting", "dead", "ghost" }

-- Returns the editor labels of the player states, keyed by state name.
-- @return table  The localized label of each state, keyed by state name (the STATE_ORDER entries).
local function stateNames()
    return {
        mounted = L["Mounted"], swimming = L["Swimming"], flying = L["Flying"], falling = L["Falling"],
        resting = L["In a Rested Area"], dead = L["Dead"], ghost = L["Ghost"],
    }
end

-- Gives the readable "you are / are not ..." sentence for a state.
-- @param state any  The state name.
-- @return string|nil  The localized sentence with its {{!are|are not}} alternatives; nil for an unknown state.
local function statePhrase(state)
    if state == "mounted" then return L["you {{!are|are not}} mounted"]
    elseif state == "swimming" then return L["you {{!are|are not}} swimming"]
    elseif state == "flying" then return L["you {{!are|are not}} flying"]
    elseif state == "falling" then return L["you {{!are|are not}} falling"]
    elseif state == "resting" then return L["you {{!are|are not}} in a rested area"]
    elseif state == "dead" then return L["you {{!are|are not}} dead"]
    elseif state == "ghost" then return L["you {{!are|are not}} a ghost"] end
end

-- PLAYER_STATE: true when the chosen fact about you holds. Stores `state`. False for a readable "no"; `nil, reason`
-- when the Platform cannot answer (unsupported client policy, a hidden value, a missing API).
addon:RegisterCondition("PLAYER_STATE", {
    description = L["Player State"],
    icon = addon.Artwork.condition["PLAYER_STATE"],
    requiredFields = { "state" },
    fields = { state = "string" },
    -- Checks that the saved fields of the PLAYER_STATE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid once one of the listed states is chosen.
    valid = function(_, value)
        return value.state ~= nil and Functions.values.isin(stateNames(), value.state)
    end,
    -- Decides whether the chosen fact about you (mounted, swimming, flying, falling, resting, dead or ghost) holds.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Returns the cached Platform observation for the state unchanged: a boolean, or nil and a reason.
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetPlayerStateObservation, addon.Platform, value.state)
    end,
    -- Builds the readable rule summary for the PLAYER_STATE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary; falls back to a generic sentence for an unknown state.
    print = function(_, value)
        return statePhrase(value.state) or string.format(L["you {{!are|are not}} %s"], L["<state>"])
    end,
    -- Builds the editor controls for the PLAYER_STATE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the state dropdown; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local state = addon:CreateConditionDropdown()
        state:SetLabel(L["State"])
        state:SetCallback("OnValueChanged", function(_, _, v)
            value.state = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        state.configure = function()
            state:SetList(stateNames(), STATE_ORDER)
            if value.state ~= nil then state:SetValue(value.state) end
        end
        parent:AddChild(state)
    end,
    -- Builds the help page for the PLAYER_STATE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.PLAYER_STATE"]))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="STATE_ORDER" then return STATE_ORDER end
        if name=="helpers" then return helpers end
        if name=="stateNames" then return stateNames end
        if name=="statePhrase" then return statePhrase end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/player_state.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/player_state.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
