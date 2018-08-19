local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tostring, tonumber, pairs = tostring, tonumber, pairs
local floor = math.floor

-- From constants
local units, unitsPossessive, classes, roles =
    addon.units, addon.unitsPossessive, addon.classes, addon.roles

-- From utils
local nullable, keys, isin, deepcopy, getCached, playerize =
    addon.nullable, addon.keys, addon.isin, addon.deepcopy, addon.getCached, addon.playerize

addon:RegisterCondition("ROLE", {
    description = L["Role"],
    icon = "Interface\\Icons\\petbattle_health",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and isin(roles, value.value))
    end,
    evaluate = function(value, cache)
        local id, name, description, icon, background, role, class
        = getCached(cache, GetSpecializationInfoByID, getCached(cache, GetInspectSpecialization, value.unit))
        return role == value.value
    end,
    print = function(spec, value)
        return string.format(L["%s is in a %s role"],
            nullable(unitsPossessive[value.unit], L["<unit>"]),
            nullable(roles[value.value], L["<role>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local units = deepcopy(units, { "player", "pet" })

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

        local role = AceGUI:Create("Dropdown")
        role:SetLabel(L["Role"])
        role:SetList(roles, keys(roles))
        if (value.value ~= nil) then
            role:SetValue(value.value)
        end
        role:SetCallback("OnValueChanged", function(widget, event, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(role)
    end,
})

addon:RegisterCondition("CLASS", {
    description = L["Class"],
    icon = "Interface\\Icons\\achievement_general_stayclassy",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and isin(classes, value.value))
    end,
    evaluate = function(value, cache)
        local _, englishClass = getCached(cache, UnitClass, "unit");
        return englishClass == value.value
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s are a %s"], L["%s is a %s"]),
            nullable(units[value.unit]) .. is(value.unit),
            nullable(classes[value.value], L["<class>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local units = deepcopy(units, { "player", "pet" })

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

        local class = AceGUI:Create("Dropdown")
        class:SetLabel(L["Class"])
        class:SetList(classes, keys(classes))
        if (value.value ~= nil) then
            class:SetValue(value.value)
        end
        class:SetCallback("OnValueChanged", function(widget, event, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(class)
    end,
})

addon:RegisterCondition("TALENT", {
    description = L["Talent"],
    icon = "Interface\\Icons\\inv_7xp_inscription_talenttome02",
    valid = function(spec, value)
        return value.value ~= nil and value.value >= 1 and value.value <= 21
    end,
    evaluate = function(value, cache)
		if (value.value) then
			local _, _, _, selected = getCached(addon.longtermCache, GetTalentInfo, floor((value.value-1) / 3) + 1, ((value.value-1) % 3) + 1, 1)
			return selected
		else
			return false
		end
    end,
    print = function(spec, value)
        return string.format(L["you are talented in %s"], nullable(addon:GetSpecTalentName(spec, value.value), L["<talent>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local talents = {}
        local talentsOrder = {}
        for i=1,21 do
            talents[i] = addon:GetSpecTalentName(spec, i)
            table.insert(talentsOrder, i)
        end

        local talentIcon = AceGUI:Create("Icon")
        talentIcon:SetWidth(44)
        talentIcon:SetHeight(44)
        talentIcon:SetImageSize(36, 36)
        talentIcon:SetImage(addon:GetSpecTalentIcon(spec, value.value))
        parent:AddChild(talentIcon)

        local talent = AceGUI:Create("Dropdown")
        talent:SetLabel(L["Talent"])
        talent:SetList(talents, talentsOrder)
        if (value.value) then
            talent:SetValue(value.value)
        end
        talent:SetCallback("OnValueChanged", function(widget, event, v)
            value.value = v
	    talentIcon:SetImage(addon:GetSpecTalentIcon(spec, value.value))
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(talent)
    end,
})

