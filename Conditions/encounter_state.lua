local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- What is going on around you, from the game itself (no boss mod): whether a
-- boss encounter is in progress, and the Mythic+ keystone level. The instance
-- difficulty and ID are optional parts of INSTANCE (Conditions/misc.lua). Each
-- is read through the platform adapter (Platform/world_state.lua), once per
-- evaluation, and an unreadable answer is unavailable (also under NOT).
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString},
    cache={getCached=addon.Functions.cache.getCached},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/encounter_state.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
}

local function validNumber(value)
    return type(value) == "number" and value == value and value >= 0 and value < math.huge
end
local function validCompare(value)
    return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and validNumber(value.value)
end

addon:RegisterCondition("ENCOUNTER", {
    description = L["Boss Encounter"],
    icon = addon.Artwork.condition["ENCOUNTER"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetEncounterObservation, addon.Platform)
    end,
    print = function()
        return L["a boss encounter {{!is|is not}} in progress"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.ENCOUNTER"]))
    end,
})

addon:RegisterCondition("KEYSTONE_LEVEL", {
    description = L["Mythic+ Keystone Level"],
    icon = addon.Artwork.condition["KEYSTONE_LEVEL"],
    requiredFields = { "operator", "value" },
    fields = { operator = "string", value = "number" },
    valid = function(_, value)
        return validCompare(value)
    end,
    evaluate = function(value, cache)
        local keystone, reason = Functions.cache.getCached(cache, addon.Platform.GetKeystoneObservation, addon.Platform)
        if not keystone then return nil, reason end
        return Functions.values.compare(value.operator, keystone.level, value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["the level of your active Mythic+ keystone"],
            Functions.presentation.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        parent:AddChild(addon:Widget_OperatorWidget(value, L["Level"], function() top:SetStatusText(funcs:print(root, spec)) end))
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.KEYSTONE_LEVEL"]))
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
