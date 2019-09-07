local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tostring, tonumber, pairs, table, select = tostring, tonumber, pairs, table, select
local floor = math.floor

-- From constants
local units, zonepvp, instances, forms = addon.units, addon.zonepvp, addon.instances, addon.forms

-- From utils
local nullable, keys,  isin, deepcopy, playerize =
    addon.nullable, addon.keys, addon.isin, addon.deepcopy, addon.playerize

addon:RegisterSwitchCondition("PVP", {
    description = L["PVP Flagged"],
    icon = "Interface\\Icons\\Inv_banner_03",
    valid = function(spec, value)
        return value.unit ~= nil and isin(units, value.unit);
    end,
    evaluate = function(value, cache, evalStart)
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
