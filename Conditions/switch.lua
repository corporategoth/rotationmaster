local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color = color

-- From constants
local units, zonepvp, instances, operators = addon.units, addon.zonepvp, addon.instances, addon.operators

-- From utils
local nullable, keys,  isin, deepcopy, playerize, compare, compareString, getCached =
    addon.nullable, addon.keys, addon.isin, addon.deepcopy, addon.playerize, addon.compare, addon.compareString, addon.getCached

local helpers = addon.help_funcs
local CreateText, CreatePictureText, CreateButtonText, Indent, Gap =
helpers.CreateText, helpers.CreatePictureText, helpers.CreateButtonText, helpers.Indent, helpers.Gap

addon:RegisterSwitchCondition("LEVEL", {
    description = L["Level"],
    icon = "Interface\\Icons\\spell_holy_blessedrecovery",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        return compare(value.operator, getCached(addon.longtermCache, UnitLevel, "player"), value.value)
    end,
    print = function(spec, value)
        return compareString(value.operator, L["your level"], nullable(value.value, L["<level>"]))
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

addon:RegisterSwitchCondition("PVP", {
    description = L["PVP Flagged"],
    icon = "Interface\\Icons\\Inv_banner_03",
    valid = function(spec, value)
        return value.unit ~= nil and isin(units, value.unit);
    end,
    evaluate = function(value, cache, evalStart)
        if not getCached(cache, UnitExists, value.unit) then return false end
        return UnitIsPVP(value.unit)
    end,
    print = function(spec, value)
        return string.format(playerize(value.uinit, L["%s are PVP flagged"], L["%s is PVP flagged"]),
            nullable(units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local units = deepcopy(units, { "pet" })

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})

addon:RegisterSwitchCondition("ZONEPVP", {
    description = L["Zone PVP"],
    icon = "Interface\\Icons\\Inv_bannerpvp_01",
    valid = function(spec, value)
        return value.value == nil or isin(zonepvp, value.value);
    end,
    evaluate = function(value, cache, evalStart)
        local pvpType = GetZonePVPInfo()
        return value.value == pvpType
    end,
    print = function(spec, value)
        return string.format(L["zone is a %s zone"], nullable(zonepvp[value.value], L["no PVP"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local zonepvp = deepcopy(zonepvp)
        zonepvp[""] = L["no PVP"]

        local zone = AceGUI:Create("Dropdown")
        zone:SetLabel(L["Mode"])
        zone:SetCallback("OnValueChanged", function(widget, event, v)
            if v == "" then
                value.vlaue = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        zone.configure = function()
            zone:SetList(zonepvp, keys(zonepvp))
            if (value.value ~= nil) then
                zone:SetValue(value.value)
            else
                zone:SetValue("")
            end
        end
        parent:AddChild(zone)
    end,
    help = function(frame)
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "The PVP status of the area you are in."))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["no PVP"] .. color.RESET .. " - " ..
                "This area does not allow PVP with other players.")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Arena"] .. color.RESET .. " - " ..
                "You are in an arena.  PVP is enabled in this area, but reset on exit.")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Controlled by your faction"] .. color.RESET .. " - " ..
                "This area is controlled by your faction.  You will not enter PVP in this region, however " ..
                "opposing factions will be automatically flagged for PVP upon entering.")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Contested"] .. color.RESET .. " - " ..
                "This area is contested, You will not automatically be flagged for PVP (on a PvE server), " ..
                "however you may attack the opposing faction, flagging for PVP.")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Controlled by opposing faction"] .. color.RESET .. " - " ..
                "This area is controlled by the opposing faction.  You will be automatically flagged for " ..
                "PVP, however opposing faction players may not be (if on a PvE server) unless they choose to.")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Sanctuary (no PVP)"] .. color.RESET .. " - " ..
                "This is a sactuary city.  No PVP is possible.")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Combat (auto-flagged)"] .. color.RESET .. " - " ..
                "This is a combat zone (eg. a battleground), all players will be automatically flagged as PVP.")))
    end
})

addon:RegisterSwitchCondition("INSTANCE", {
    description = L["Instance"],
    icon = "Interface\\Icons\\Spell_nature_astralrecal",
    valid = function(spec, value)
        return value.value == nil or isin(zonepvp, value.value);
    end,
    evaluate = function(value, cache, evalStart)
        local inInstance, instanceType = IsInInstance()
        return inInstance and value.value == instanceType
    end,
    print = function(spec, value)
        return string.format(L["you are in a %s instance"],
             nullable(zonepvp[value.value], L["Other (scenario)"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local instance = AceGUI:Create("Dropdown")
        instance:SetLabel(L["Mode"])
        instance:SetCallback("OnValueChanged", function(widget, event, v)
            if v == "" then
                value.vlaue = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        instance.configure = function()
            instance:SetList(instances, keys(instances))
            if (value.value ~= nil) then
                instance:SetValue(value.value)
            else
                instance:SetValue("")
            end
        end
        parent:AddChild(instance)
    end,
    help = function(frame)
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "The type of instance you are in."))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Outside"] .. color.RESET .. " - " ..
                "You are not in an instance (this does not necessarily mean you are outdoors, just not in any " ..
                "kind of instance.)")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Battleground"] .. color.RESET .. " - " ..
                "You are in a battleground (an ad-hoc instance where the opponant is the opposing faction.)")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Arena"] .. color.RESET .. " - " ..
                "A close quarters fight with the opposing faction, where death is a loss.")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Dungeon"] .. color.RESET .. " - " ..
                "A five-person dungeon, where your opponants are all NPCs.")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Raid"] .. color.RESET .. " - " ..
                "An instance that accommodates more than five people, where your opponants are all NPCs.")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Scenario"] .. color.RESET .. " - " ..
                "A single-person instance, similar to a dungeon but completed solo.")))
    end
})

addon:RegisterSwitchCondition("ZONE", {
    description = L["Zone"],
    icon = "Interface\\Icons\\spell_nature_farsight",
    valid = function(spec, value)
        return value.value ~= nil
    end,
    evaluate = function(value, cache, evalStart)
        local zoneName = GetZoneText()
        return value.value == zoneName
    end,
    print = function(spec, value)
        return string.format(L["in %s"], nullable(value.value, L["<zone>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local zone = AceGUI:Create("EditBox")
        zone:SetLabel(L["Zone"])
        zone:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        if (value.value ~= nil) then
            zone:SetText(value.value)
        end
        parent:AddChild(zone)
    end,
    help = function(frame)
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Zone"] .. color.RESET .. " - " ..
            "The zone you are in."))
    end
})

addon:RegisterSwitchCondition("SUBZONE", {
    description = L["SubZone"],
    icon = "Interface\\Icons\\Ability_townwatch",
    valid = function(spec, value)
        return value.value ~= nil
    end,
    evaluate = function(value, cache, evalStart)
        local zoneName = GetSubZoneText()
        return value.value == zoneName
    end,
    print = function(spec, value)
        return string.format(L["in %s"], nullable(value.value, L["<zone>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local zone = AceGUI:Create("EditBox")
        zone:SetLabel(L["SubZone"])
        if (value.value ~= nil) then
            zone:SetText(value.value)
        end
        zone:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(zone)
        help = function(frame)
            frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Zone"] .. color.RESET .. " - " ..
                "The subzone you are in (ie. not the larger region such as The Barrens, but more Crossroads.)"))
        end
    end,
})

addon:RegisterSwitchCondition("GROUP", {
    description = L["In Group"],
    icon = "Interface\\Icons\\ability_warrior_charge",
    valid = function(spec, value)
        return true
    end,
    evaluate = function(value, cache, evalStart)
        return IsInGroup()
    end,
    print = function(spec, value)
        return L["you are in a group"]
    end,
})

addon:RegisterSwitchCondition("RAID", {
    description = L["In Raid"],
    icon = "Interface\\Icons\\Ability_warrior_challange",
    valid = function(spec, value)
        return true
    end,
    evaluate = function(value, cache, evalStart)
        return IsInRaid()
    end,
    print = function(spec, value)
        return L["you are in a raid"]
    end,
})

addon:RegisterSwitchCondition("OUTDOORS", {
    description = L["Outdoors"],
    icon = "Interface\\Icons\\Inv_misc_flower_02",
    valid = function(spec, value)
        return true
    end,
    evaluate = function(value, cache, evalStart)
        return IsOutdoors()
    end,
    print = function(spec, value)
        return L["you are in a outdoors"]
    end,
})

addon:RegisterSwitchCondition("FORM", addon.condition_form)

addon:RegisterSwitchCondition("STEALTHED", {
    description = L["Stealth"],
    icon = "Interface\\Icons\\ability_stealth",
    valid = function(spec, value)
        return true
    end,
    evaluate = function(value, cache, evalStart)
        return getCached(cache, IsStealthed)
    end,
    print = function(spec, value)
        return L["you are stealthed"]
    end,
})
