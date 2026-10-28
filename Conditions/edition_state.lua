-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In conditions for mechanics that exist only in some game editions: PET_HAPPINESS (hunter pet mood), STAGGER
-- (Brewmaster Stagger pool) and ECLIPSE (Balance Druid Eclipse direction or energy). Each reads one Platform
-- observation (Platform/edition_state.lua) through the per-poll cache; this file reads no game value itself. A reader
-- reports a reason on a client that lacks the mechanic or hides the value (a secret value on Retail and Forever), and
-- the condition is then unavailable (nil, reason), also under NOT; a readable "no" is an ordinary false.
-- Core/condition_support.lua declares each condition unsupported on the editions without it. Loaded from
-- RotationMaster.toc after Conditions/proc_glow.lua. Callback bodies and the helpers they bind are hashed by saved
-- copies and bundles: never add or change text inside a function body, and leave the generated block at the end alone.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Mechanics that belong to particular editions, read through the platform
-- adapter (Platform/edition_state.lua). Each is declared unavailable on the
-- clients that do not have it (Core/condition_support.lua), so a rotation that
-- uses one elsewhere is incomplete rather than quietly wrong:
--   PET_HAPPINESS         hunter pet happiness: Classic Era, Burning Crusade, Wrath
--   STAGGER               Brewmaster Stagger: Mists of Pandaria, Retail, Forever
--   ECLIPSE               Balance Druid Eclipse, its direction or its energy:
--                         Wrath through Mists of Pandaria
-- The Auto Shot and wand timer is the Ranged option of SWING_TIME and
-- SWING_TIME_REMAIN (Conditions/weapon.lua), which read
-- Platform:GetRangedSwingSpeed from this adapter.
local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
    },
    cache = { getCached = addon.Functions.cache.getCached },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/edition_state.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
}

-- ============================================================================
-- Shared helpers and lists
-- ============================================================================

-- True when value carries a known operator and a finite, non-negative number to compare against.
local function validCompare(value)
    return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)
        and type(value.value) == "number" and value.value == value.value and value.value >= 0 and value.value < math.huge
end

-- Hunter pet happiness, as GetPetHappiness numbers it.
local MOODS = { [1] = L["Unhappy"], [2] = L["Content"], [3] = L["Happy"] }
local MOOD_ORDER = { 1, 2, 3 }
-- The direction the Eclipse bar is heading, as GetEclipseDirection names it.
local ECLIPSES = { sun = L["a Solar Eclipse"], moon = L["a Lunar Eclipse"] }
local ECLIPSE_ORDER = { "sun", "moon" }

-- ============================================================================
-- Pet happiness
-- ============================================================================

-- PET_HAPPINESS: true when your hunter pet's mood is the chosen one (1 unhappy, 2 content, 3 happy). Stores `value`.
-- False when you have no hunter pet; `nil, reason` on an edition without pet happiness or when the mood cannot be
-- read.
addon:RegisterCondition("PET_HAPPINESS", {
    description = L["Pet Happiness"],
    icon = addon.Artwork.condition["PET_HAPPINESS"],
    requiredFields = { "value" },
    fields = { value = "number" },
    -- Valid once one of the three moods is chosen.
    valid = function(_, value)
        return value.value ~= nil and Functions.values.isin(MOODS, value.value)
    end,
    -- The Platform returns false (no hunter pet), the mood number, or nil and a reason.
    evaluate = function(value, cache)
        local mood, reason = Functions.cache.getCached(cache, addon.Platform.GetPetHappinessObservation, addon.Platform)
        if mood == nil then return nil, reason end
        if mood == false then return false end
        return mood == value.value
    end,
    -- Readable summary naming the mood.
    print = function(_, value)
        return string.format(L["your pet {{!is|is not}} %s"], Functions.presentation.nullable(MOODS[value.value], L["<mood>"]))
    end,
    -- widget builds the mood dropdown; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local mood = addon:CreateConditionDropdown()
        mood:SetLabel(L["Pet Happiness"])
        mood:SetCallback("OnValueChanged", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        mood.configure = function()
            mood:SetList(MOODS, MOOD_ORDER)
            if value.value ~= nil then mood:SetValue(value.value) end
        end
        parent:AddChild(mood)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.PET_HAPPINESS"]))
    end,
})

-- ============================================================================
-- Stagger
-- ============================================================================

-- STAGGER: compares the damage waiting in your Stagger pool, or with `percent` that pool as a percentage of your
-- maximum health, with a number. Stores `operator`, `value` and `percent`. Returns `nil, reason` on an edition without
-- Stagger or when the value cannot be read; the percentage form is unavailable on Retail and Forever, where maximum
-- health is hidden.
addon:RegisterCondition("STAGGER", {
    description = L["Stagger"],
    icon = addon.Artwork.condition["STAGGER"],
    requiredFields = { "operator", "value" },
    fields = { operator = "string", value = "number", percent = "boolean" },
    -- Valid with a known operator, a finite non-negative number and an optional boolean percent flag.
    valid = function(_, value)
        return validCompare(value) and (value.percent == nil or type(value.percent) == "boolean")
    end,
    -- Unavailable when the Platform cannot read the Stagger amount (percent flag passed through).
    evaluate = function(value, cache)
        local stagger, reason = Functions.cache.getCached(cache, addon.Platform.GetStaggerObservation, addon.Platform, value.percent == true)
        if stagger == nil then return nil, reason end
        return Functions.values.compare(value.operator, stagger, value.value)
    end,
    -- Readable summary; says whether the number is a percentage of maximum health or a damage amount.
    print = function(_, value)
        if value.percent then
            return Functions.presentation.compareString(value.operator, L["your Stagger as a percent of your maximum health"],
                string.format(L["%s percent"], Functions.presentation.nullable(value.value)))
        end
        return Functions.presentation.compareString(value.operator, L["the damage in your Stagger pool"], Functions.presentation.nullable(value.value))
    end,
    -- widget builds an operator-and-value control and the "as a percent of maximum health" checkbox; help draws the
    -- help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        parent:AddChild(addon:Widget_OperatorWidget(value, L["Value"], function() top:SetStatusText(funcs:print(root, spec)) end))

        local percent = addon:CreateConditionCheckBox()
        percent:SetWidth(300)
        percent:SetLabel(L["As a percent of maximum health"])
        percent:SetValue(value.percent and true or false)
        percent:SetCallback("OnValueChanged", function(_, _, v)
            value.percent = v or nil
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(percent)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.STAGGER"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Stagger"], L["Value"],
            L["The damage waiting in your Stagger pool, or the same as a percent of your maximum health when the box is ticked."])
    end,
})

-- ============================================================================
-- Eclipse
-- ============================================================================

-- The two things the Eclipse bar tells you, in the order the editor lists them.
local ECLIPSE_MEASURES_ORDER = { "direction", "energy" }

-- Returns the labels of the two Eclipse measures, keyed by measure name.
local function eclipseMeasures()
    return { direction = L["Direction"], energy = L["Energy"] }
end

-- ECLIPSE: for the chosen `measure`, either true when the Eclipse bar is heading toward the chosen `direction` (sun or
-- moon), or a comparison of its energy (-100 full Lunar to 100 full Solar) with `value` using `operator`. Stores
-- `measure`, `direction`, `operator` and `value`. Returns `nil, reason` for a class without an Eclipse bar, on an
-- edition without Eclipse, or when the bar cannot be read.
addon:RegisterCondition("ECLIPSE", {
    description = L["Eclipse"],
    icon = addon.Artwork.condition["ECLIPSE"],
    requiredFields = { "measure" },
    fields = { measure = "string", direction = "string", operator = "string", value = "number" },
    -- Valid per measure: a direction needs a listed direction; energy needs a known operator and a number from -100
    -- to 100.
    valid = function(_, value)
        if value.measure == "direction" then
            return value.direction ~= nil and Functions.values.isin(ECLIPSES, value.direction)
        elseif value.measure == "energy" then
            return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)
                and type(value.value) == "number" and value.value == value.value and value.value >= -100 and value.value <= 100
        end
        return false
    end,
    -- Reads the direction or the energy from the same Platform observation; either is unavailable when the bar cannot
    -- be read, and a direction of "none" simply fails to match.
    evaluate = function(value, cache)
        if value.measure == "direction" then
            local direction, reason = Functions.cache.getCached(cache, addon.Platform.GetEclipseObservation, addon.Platform, "direction")
            if direction == nil then return nil, reason end
            return direction == value.direction
        end
        local energy, reason = Functions.cache.getCached(cache, addon.Platform.GetEclipseObservation, addon.Platform, "energy")
        if energy == nil then return nil, reason end
        return Functions.values.compare(value.operator, energy, value.value)
    end,
    -- Readable summary for whichever measure is chosen.
    print = function(_, value)
        if value.measure == "energy" then
            return Functions.presentation.compareString(value.operator, L["your Eclipse energy"], Functions.presentation.nullable(value.value))
        end
        return string.format(L["your Eclipse bar {{!is|is not}} heading toward %s"], Functions.presentation.nullable(ECLIPSES[value.direction], L["<Eclipse>"]))
    end,
    -- widget builds the measure dropdown, the direction dropdown and the energy operator control (all three are always
    -- added); help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local direction = addon:CreateConditionDropdown()
        local operator = addon:Widget_OperatorWidget(value, L["Energy"], function() top:SetStatusText(funcs:print(root, spec)) end)

        local measure = addon:CreateConditionDropdown()
        measure:SetLabel(L["Measure"])
        measure:SetCallback("OnValueChanged", function(_, _, v)
            value.measure = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        measure.configure = function()
            measure:SetList(eclipseMeasures(), ECLIPSE_MEASURES_ORDER)
            if value.measure ~= nil then measure:SetValue(value.measure) end
        end
        parent:AddChild(measure)

        direction:SetLabel(L["Eclipse Direction"])
        direction:SetCallback("OnValueChanged", function(_, _, v)
            value.direction = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        direction.configure = function()
            direction:SetList(ECLIPSES, ECLIPSE_ORDER)
            if value.direction ~= nil then direction:SetValue(value.direction) end
        end
        parent:AddChild(direction)

        parent:AddChild(operator)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.ECLIPSE"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Eclipse"], L["Energy"],
            L["The Eclipse bar, from -100 (a full Lunar Eclipse) to 100 (a full Solar Eclipse)."])
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="ECLIPSES" then return ECLIPSES end
        if name=="ECLIPSE_MEASURES_ORDER" then return ECLIPSE_MEASURES_ORDER end
        if name=="ECLIPSE_ORDER" then return ECLIPSE_ORDER end
        if name=="MOODS" then return MOODS end
        if name=="MOOD_ORDER" then return MOOD_ORDER end
        if name=="eclipseMeasures" then return eclipseMeasures end
        if name=="helpers" then return helpers end
        if name=="validCompare" then return validCompare end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/edition_state.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/edition_state.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
