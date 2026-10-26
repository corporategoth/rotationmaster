local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Five independent facts about how the player is moving or resting, each read
-- through Platform:GetPlayerStateObservation (Platform/world_state.lua) once
-- per evaluation. They need no unit and no fields. A fact the game cannot
-- answer, or answers with a secret value, is unavailable (also under NOT);
-- a readable "no" is an ordinary false.
local Functions={
    cache={getCached=addon.Functions.cache.getCached},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/player_state.lua"]={
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
}

addon:RegisterCondition("MOUNTED", {
    description = L["Mounted"],
    icon = addon.Artwork.condition["MOUNTED"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetPlayerStateObservation, addon.Platform, "mounted")
    end,
    print = function()
        return L["you {{!are|are not}} mounted"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.MOUNTED"]))
    end,
})

addon:RegisterCondition("SWIMMING", {
    description = L["Swimming"],
    icon = addon.Artwork.condition["SWIMMING"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetPlayerStateObservation, addon.Platform, "swimming")
    end,
    print = function()
        return L["you {{!are|are not}} swimming"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.SWIMMING"]))
    end,
})

addon:RegisterCondition("FALLING", {
    description = L["Falling"],
    icon = addon.Artwork.condition["FALLING"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetPlayerStateObservation, addon.Platform, "falling")
    end,
    print = function()
        return L["you {{!are|are not}} falling"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.FALLING"]))
    end,
})

addon:RegisterCondition("FLYING", {
    description = L["Flying"],
    icon = addon.Artwork.condition["FLYING"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetPlayerStateObservation, addon.Platform, "flying")
    end,
    print = function()
        return L["you {{!are|are not}} flying"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.FLYING"]))
    end,
})

addon:RegisterCondition("RESTING", {
    description = L["In a Rested Area"],
    icon = addon.Artwork.condition["RESTING"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetPlayerStateObservation, addon.Platform, "resting")
    end,
    print = function()
        return L["you {{!are|are not}} in a rested area"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.RESTING"]))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/player_state.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/player_state.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
