local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Mechanics that belong to particular editions, read through the platform
-- adapter (Platform/edition_state.lua). Each is declared unavailable on the
-- clients that do not have it (Core/condition_support.lua), so a rotation that
-- uses one elsewhere is incomplete rather than quietly wrong:
--   PET_HAPPINESS         hunter pet happiness: Classic Era, Burning Crusade, Wrath
--   STAGGER               Brewmaster Stagger: Mists of Pandaria, Retail, Forever
--   ECLIPSE_DIRECTION and
--   ECLIPSE_ENERGY        Balance Druid Eclipse: Wrath through Mists of Pandaria
--   RANGED_SWING_REMAIN   Auto Shot and wand timer: clients that expose the
--                         combat log (Era, Burning Crusade, Mists)
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString},
    cache={getCached=addon.Functions.cache.getCached},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/edition_state.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
}

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

addon:RegisterCondition("PET_HAPPINESS", {
    description = L["Pet Happiness"],
    icon = addon.Artwork.condition["PET_HAPPINESS"],
    requiredFields = { "value" },
    fields = { value = "number" },
    valid = function(_, value)
        return value.value ~= nil and Functions.values.isin(MOODS, value.value)
    end,
    evaluate = function(value, cache)
        local mood, reason = Functions.cache.getCached(cache, addon.Platform.GetPetHappinessObservation, addon.Platform)
        if mood == nil then return nil, reason end
        if mood == false then return false end
        return mood == value.value
    end,
    print = function(_, value)
        return string.format(L["your pet {{!is|is not}} %s"], Functions.presentation.nullable(MOODS[value.value], L["<mood>"]))
    end,
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

addon:RegisterCondition("STAGGER", {
    description = L["Stagger"],
    icon = addon.Artwork.condition["STAGGER"],
    requiredFields = { "operator", "value" },
    fields = { operator = "string", value = "number", percent = "boolean" },
    valid = function(_, value)
        return validCompare(value) and (value.percent == nil or type(value.percent) == "boolean")
    end,
    evaluate = function(value, cache)
        local stagger, reason = Functions.cache.getCached(cache, addon.Platform.GetStaggerObservation, addon.Platform, value.percent == true)
        if stagger == nil then return nil, reason end
        return Functions.values.compare(value.operator, stagger, value.value)
    end,
    print = function(_, value)
        if value.percent then
            return Functions.presentation.compareString(value.operator, L["your Stagger as a percent of your maximum health"],
                string.format(L["%s percent"], Functions.presentation.nullable(value.value)))
        end
        return Functions.presentation.compareString(value.operator, L["the damage in your Stagger pool"], Functions.presentation.nullable(value.value))
    end,
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

addon:RegisterCondition("ECLIPSE_DIRECTION", {
    description = L["Eclipse Direction"],
    icon = addon.Artwork.condition["ECLIPSE_DIRECTION"],
    requiredFields = { "value" },
    fields = { value = "string" },
    valid = function(_, value)
        return value.value ~= nil and Functions.values.isin(ECLIPSES, value.value)
    end,
    evaluate = function(value, cache)
        local direction, reason = Functions.cache.getCached(cache, addon.Platform.GetEclipseObservation, addon.Platform, "direction")
        if direction == nil then return nil, reason end
        return direction == value.value
    end,
    print = function(_, value)
        return string.format(L["your Eclipse bar {{!is|is not}} heading toward %s"], Functions.presentation.nullable(ECLIPSES[value.value], L["<Eclipse>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local direction = addon:CreateConditionDropdown()
        direction:SetLabel(L["Eclipse Direction"])
        direction:SetCallback("OnValueChanged", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        direction.configure = function()
            direction:SetList(ECLIPSES, ECLIPSE_ORDER)
            if value.value ~= nil then direction:SetValue(value.value) end
        end
        parent:AddChild(direction)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.ECLIPSE_DIRECTION"]))
    end,
})

addon:RegisterCondition("ECLIPSE_ENERGY", {
    description = L["Eclipse Energy"],
    icon = addon.Artwork.condition["ECLIPSE_ENERGY"],
    requiredFields = { "operator", "value" },
    fields = { operator = "string", value = "number" },
    valid = function(_, value)
        return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)
            and type(value.value) == "number" and value.value == value.value and value.value >= -100 and value.value <= 100
    end,
    evaluate = function(value, cache)
        local energy, reason = Functions.cache.getCached(cache, addon.Platform.GetEclipseObservation, addon.Platform, "energy")
        if energy == nil then return nil, reason end
        return Functions.values.compare(value.operator, energy, value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["your Eclipse energy"], Functions.presentation.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        parent:AddChild(addon:Widget_OperatorWidget(value, L["Energy"], function() top:SetStatusText(funcs:print(root, spec)) end))
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.ECLIPSE_ENERGY"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Eclipse Energy"], L["Energy"],
            L["The Eclipse bar, from -100 (a full Lunar Eclipse) to 100 (a full Solar Eclipse)."])
    end,
})

addon:RegisterCondition("RANGED_SWING_REMAIN", {
    description = L["Ranged Swing Time Remaining"],
    icon = addon.Artwork.condition["RANGED_SWING_REMAIN"],
    requiredFields = { "operator", "value" },
    fields = { operator = "string", value = "number" },
    valid = function(_, value)
        return validCompare(value)
    end,
    evaluate = function(value, cache, evalStart)
        local speed, reason = Functions.cache.getCached(cache, addon.Platform.GetRangedSwingSpeed, addon.Platform)
        if speed == nil then return nil, reason end
        if speed == false then return false end
        local lastShot = addon.lastRangedShot
        if lastShot == nil then return Functions.values.compare(value.operator, speed, value.value) end
        return Functions.values.compare(value.operator, math.max(speed - math.max(evalStart - lastShot, 0), 0), value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["your ranged swing time remaining"],
            string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        parent:AddChild(addon:Widget_OperatorWidget(value, L["Seconds"], function() top:SetStatusText(funcs:print(root, spec)) end))
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.RANGED_SWING_REMAIN"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Ranged Swing Time Remaining"], L["Seconds"],
            L["The amount of time (in seconds) until your next Auto Shot or wand shot."])
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="ECLIPSES" then return ECLIPSES end
        if name=="ECLIPSE_ORDER" then return ECLIPSE_ORDER end
        if name=="MOODS" then return MOODS end
        if name=="MOOD_ORDER" then return MOOD_ORDER end
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
