local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color = color
local helpers = addon.help_funcs

addon:RegisterCondition("SELF_LEVEL", {
    description = L["Level"],
    icon = "Interface\\Icons\\spell_holy_blessedrecovery",
    valid = function(_, value)
        return (value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value)
        return addon.compare(value.operator, addon.getCached(addon.longtermCache, UnitLevel, "player"), value.value)
    end,
    print = function(_, value)
        return addon.compareString(value.operator, L["your level"], addon.nullable(value.value, L["<level>"]))
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
    icon = "Interface\\Icons\\Inv_banner_03",
    valid = function(_, value)
        return value.unit ~= nil and addon.isin(addon.units, value.unit);
    end,
    evaluate = function(value, cache)
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        return addon.getCached(cache, UnitIsPVP, value.unit)
    end,
    print = function(_, value)
        return string.format(addon.playerize(value.uinit, L["%s are PVP flagged"], L["%s is PVP flagged"]),
                addon.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local funits = addon.deepcopy(addon.units, { "pet" })

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
    icon = "Interface\\Icons\\Inv_bannerpvp_01",
    valid = function(_, value)
        return value.value == nil or addon.isin(addon.zonepvp, value.value);
    end,
    evaluate = function(value, cache)
        local pvpType = addon.getCached(cache, GetZonePVPInfo)
        return value.value == pvpType
    end,
    print = function(_, value)
        return string.format(L["zone is a %s zone"], addon.nullable(addon.zonepvp[value.value], L["no PVP"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local zonepvp_local = addon.deepcopy(addon.zonepvp)
        zonepvp_local[""] = L["no PVP"]

        local zone = AceGUI:Create("Dropdown")
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
            zone:SetList(zonepvp_local, addon.keys(zonepvp_local))
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
    icon = "Interface\\Icons\\Spell_nature_astralrecal",
    valid = function(_, value)
        return value.value == nil or addon.isin(addon.zonepvp, value.value);
    end,
    evaluate = function(value, cache)
        local inInstance, instanceType = addon.getCached(cache, IsInInstance)
        return inInstance and value.value == instanceType
    end,
    print = function(_, value)
        return string.format(L["you are in a %s instance"],
                addon.nullable(addon.zonepvp[value.value], L["Other (scenario)"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local instance = AceGUI:Create("Dropdown")
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
            instance:SetList(addon.instances, addon.keys(addon.instances))
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
    icon = "Interface\\Icons\\Inv_misc_flower_02",
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return addon.getCached(cache, IsOutdoors)
    end,
    print = function()
        return L["you are in a outdoors"]
    end,
})