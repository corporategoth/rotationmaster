local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Explicit callback leaves; retain raw game observations and argument order.
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString,playerize=addon.Functions.presentation.playerize},
    cache={getCached=addon.Functions.cache.getCached},
    collections={deepcopy=addon.Functions.collections.deepcopy,keys=addon.Functions.collections.keys},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/misc.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.presentation.playerize"]="builtin:utils.lua:playerize",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.collections.deepcopy"]="builtin:Functions/collections.lua:deepcopy",
    ["Functions.collections.keys"]="builtin:Functions/collections.lua:keys",
}

addon:RegisterCondition("SELF_LEVEL", {
    description = L["Level"],
    icon = addon.Artwork.condition["SELF_LEVEL"],
    fields = { operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local level,reason=addon:GetConditionUnitLevel("player",cache)
        if level==nil then return nil,reason end
        if level==false then return false end
        return Functions.values.compare(value.operator, level, value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["your level"], Functions.presentation.nullable(value.value, L["<level>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local operator_group = addon:Widget_OperatorWidget(value, L["Level"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_operatorwidget_help(frame, L["Level"], L["Level"],
                "The level you are at.")
    end
})

addon:RegisterCondition("PVP", {
    description = L["PVP Flagged"],
    icon = addon.Artwork.condition["PVP"],
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return Functions.cache.getCached(cache, UnitIsPVP, value.unit)
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} PVP flagged"], L["%s {{!is|is not}} PVP flagged"]),
                Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local funits = Functions.collections.deepcopy(addon.units, { "pet" })

        local unit = addon:Widget_UnitWidget(value, funits,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})

addon:RegisterCondition("ZONEPVP", {
    description = L["Zone PVP"],
    icon = addon.Artwork.condition["ZONEPVP"],
    fields = { value = "string" },
    valid = function(_, value)
        return value.value == nil or Functions.values.isin(addon.zonepvp, value.value)
    end,
    evaluate = function(value, cache)
        local pvpType = Functions.cache.getCached(cache, GetZonePVPInfo)
        return value.value == pvpType
    end,
    print = function(_, value)
        return string.format(L["zone {{!is|is not}} a %s zone"], Functions.presentation.nullable(addon.zonepvp[value.value], L["no PVP"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local zonepvp_local = Functions.collections.deepcopy(addon.zonepvp)
        zonepvp_local[""] = L["no PVP"]

        local zone = addon:CreateConditionDropdown()
        zone:SetLabel(L["Mode"])
        zone:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then
                value.vlaue = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        zone.configure = function()
            zone:SetList(zonepvp_local, Functions.collections.keys(zonepvp_local))
            if (value.value ~= nil) then
                zone:SetValue(value.value)
            else
                zone:SetValue("")
            end
        end
        parent:AddChild(zone)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "The PVP status of the area you are in."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["no PVP"] .. color.RESET .. " - " ..
                "This area does not allow PVP with other players.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Arena"] .. color.RESET .. " - " ..
                "You are in an arena.  PVP is enabled in this area, but reset on exit.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Controlled by your faction"] .. color.RESET .. " - " ..
                "This area is controlled by your faction.  You will not enter PVP in this region, however " ..
                "opposing factions will be automatically flagged for PVP upon entering.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Contested"] .. color.RESET .. " - " ..
                "This area is contested, You will not automatically be flagged for PVP (on a PvE server), " ..
                "however you may attack the opposing faction, flagging for PVP.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Controlled by opposing faction"] .. color.RESET .. " - " ..
                "This area is controlled by the opposing faction.  You will be automatically flagged for " ..
                "PVP, however opposing faction players may not be (if on a PvE server) unless they choose to.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Sanctuary (no PVP)"] .. color.RESET .. " - " ..
                "This is a sactuary city.  No PVP is possible.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Combat (auto-flagged)"] .. color.RESET .. " - " ..
                "This is a combat zone (eg. a battleground), all players will be automatically flagged as PVP.")))
    end
})

addon:RegisterCondition("INSTANCE", {
    description = L["Instance"],
    icon = addon.Artwork.condition["INSTANCE"],
    fields = { value = "string" },
    valid = function(_, value)
        return value.value == nil or Functions.values.isin(addon.instances, value.value);
    end,
    evaluate = function(value, cache)
        local inInstance, instanceType = Functions.cache.getCached(cache, IsInInstance)
        if value.value == "none" then return not inInstance end
        return inInstance and value.value == instanceType
    end,
    print = function(_, value)
        return string.format(L["you {{!are|are not}} in a %s instance"],
                Functions.presentation.nullable(addon.instances[value.value], L["Other (scenario)"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local instance = addon:CreateConditionDropdown()
        instance:SetLabel(L["Mode"])
        instance:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then
                value.vlaue = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        instance.configure = function()
            instance:SetList(addon.instances, Functions.collections.keys(addon.instances))
            if (value.value ~= nil) then
                instance:SetValue(value.value)
            else
                instance:SetValue("")
            end
        end
        parent:AddChild(instance)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "The type of instance you are in."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Outside"] .. color.RESET .. " - " ..
                "You are not in an instance (this does not necessarily mean you are outdoors, just not in any " ..
                "kind of instance.)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Battleground"] .. color.RESET .. " - " ..
                "You are in a battleground (an ad-hoc instance where the opponant is the opposing faction.)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Arena"] .. color.RESET .. " - " ..
                "A close quarters fight with the opposing faction, where death is a loss.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Dungeon"] .. color.RESET .. " - " ..
                "A five-person dungeon, where your opponants are all NPCs.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Raid"] .. color.RESET .. " - " ..
                "An instance that accommodates more than five people, where your opponants are all NPCs.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Scenario"] .. color.RESET .. " - " ..
                "A single-person instance, similar to a dungeon but completed solo.")))
    end
})

addon:RegisterCondition("OUTDOORS", {
    description = L["Outdoors"],
    icon = addon.Artwork.condition["OUTDOORS"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, IsOutdoors)
    end,
    print = function()
        return L["you {{!are|are not}} in a outdoors"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches when the game reports that you are outdoors. Being outdoors is different from being outside an instance."] ))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/misc.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/misc.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
