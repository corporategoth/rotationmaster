local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tostring, tonumber, pairs = tostring, tonumber, pairs
local floor = math.floor

-- From constants
local units, zonepvp, instances = addon.units, addon.zonepvp, addon.instances

-- From utils
local nullable, keys,  isin, deepcopy, playerize =
    addon.nullable, addon.keys, addon.isin, addon.deepcopy, addon.playerize

addon:RegisterSwitchCondition("COMBAT", {
    description = L["PVP Flagged"],
    icon = "Interface\\Icons\\achievement_guildperk_honorablemention",
    valid = function(spec, value)
        return value.unit ~= nil and isin(units, value.unit);
    end,
    evaluate = function(value, cache)
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

        local unit = AceGUI:Create("Dropdown")
        unit:SetLabel(L["Unit"])
        unit:SetList(units, keys(units))
        if (value.unit ~= nil) then
            unit:SetValue(value.unit)
        end
        unit:SetCallback("OnValueChanged", function(widget, event, v)
            value.unit = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(unit)
    end,
})

addon:RegisterSwitchCondition("ZONEPVP", {
    description = L["Zone PVP"],
    icon = "Interface\\Icons\\achievement_guildperk_honorablemention_rank2",
    valid = function(spec, value)
        return value.value == nil or isin(zonepvp, value.value);
    end,
    evaluate = function(value, cache)
        local pvpType = GetZonePVPInfo()
        return value.value == pvpType
    end,
    print = function(spec, value)
        return format.string(L["zone is a %s zone"], nullable(zonepvp[value.value], L["no PVP"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local zonepvp = deepcopy(zonepvp)
        zonepvp[""] = L["no PVP"]

        local mode = AceGUI:Create("Dropdown")
        mode:SetLabel(L["Mode"])
        mode:SetList(zonepvp, keys(zonepvp))
        if (value.value ~= nil) then
            mode:SetValue(value.value)
        else
            mode:SetValue("")
        end
        mode:SetCallback("OnValueChanged", function(widget, event, v)
            if v == "" then
                value.vlaue = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(mode)
    end,
})

addon:RegisterSwitchCondition("INSTANCE", {
    description = L["Instance"],
    icon = "Interface\\Icons\\achievement_boss_hellfire_zone",
    valid = function(spec, value)
        return value.value == nil or isin(zonepvp, value.value);
    end,
    evaluate = function(value, cache)
        local inInstance, instanceType = IsInInstance()
        return inInstance and value.value == instanceType
    end,
    print = function(spec, value)
        return strings.format(L["you are in a %s instance"],
             nullable(zonepvp[value.value], L["Other (scenario)"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local instances = deepcopy(instances)
        instances[""] = "Other (scenario)"

        local instance = AceGUI:Create("Dropdown")
        instance:SetLabel(L["Mode"])
        instance:SetList(instances, keys(instances))
        if (value.value ~= nil) then
            instance:SetValue(value.value)
        else
            instance:SetValue("")
        end
        instance:SetCallback("OnValueChanged", function(widget, event, v)
            if v == "" then
                value.vlaue = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(instance)
    end,
})

addon:RegisterSwitchCondition("ZONE", {
    description = L["Zone"],
    icon = "Interface\\Icons\\achievement_zone_kalimdor_01",
    valid = function(spec, value)
        return value.value ~= nil
    end,
    evaluate = function(value, cache)
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

        local mode = AceGUI:Create("EditBox")
        mode:SetLabel(L["Zone"])
        if (value.value ~= nil) then
            mode:SetText(value.value)
        end
        mode:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(mode)
    end,
})

addon:RegisterSwitchCondition("SUBZONE", {
    description = L["SubZone"],
    icon = "Interface\\Icons\\achievement_zone_easternkingdoms_01",
    valid = function(spec, value)
        return value.value ~= nil
    end,
    evaluate = function(value, cache)
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

        local mode = AceGUI:Create("EditBox")
        mode:SetLabel(L["SubZone"])
        if (value.value ~= nil) then
            mode:SetText(value.value)
        end
        mode:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(mode)
    end,
})

addon:RegisterSwitchCondition("GROUP", {
    description = L["In Group"],
    icon = "Interface\\Icons\\inv_helm_misc_starpartyhat",
    valid = function(spec, value)
        return true
    end,
    evaluate = function(value, cache)
        return IsInGroup()
    end,
    print = function(spec, value)
        return L["you are in a group"]
    end,
})

addon:RegisterSwitchCondition("RAID", {
    description = L["In Raid"],
    icon = "Interface\\Icons\\inv_misc_groupneedmore",
    valid = function(spec, value)
        return true
    end,
    evaluate = function(value, cache)
        return IsInRaid()
    end,
    print = function(spec, value)
        return L["you are in a raid"]
    end,
})

addon:RegisterSwitchCondition("OUTDOORS", {
    description = L["Outdoors"],
    icon = "Interface\\Icons\\achievement_zone_barrens_01",
    valid = function(spec, value)
        return true
    end,
    evaluate = function(value, cache)
        return IsOutdoors()
    end,
    print = function(spec, value)
        return L["you are in a outdoors"]
    end,
})
