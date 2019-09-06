local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tostring, tonumber, pairs = tostring, tonumber, pairs
local floor = math.floor

-- From constants
local units, unitsPossessive, classes, roles, operators =
    addon.units, addon.unitsPossessive, addon.classes, addon.roles, addon.operators

-- From utils
local nullable, keys, isin, deepcopy, getCached, playerize, compareString =
    addon.nullable, addon.keys, addon.isin, addon.deepcopy, addon.getCached, addon.playerize, addon.compareString

addon:RegisterCondition("CLASS", {
    description = L["Class"],
    icon = "Interface\\Icons\\achievement_general_stayclassy",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and isin(classes, value.value))
    end,
    evaluate = function(value, cache, evalStart)
        local _, englishClass = getCached(cache, UnitClass, "unit");
        return englishClass == value.value
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s are a %s"], L["%s is a %s"]),
            nullable(units[value.unit]), nullable(classes[value.value], L["<class>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
        local class = AceGUI:Create("Dropdown")
        parent:AddChild(class)

        class:SetLabel(L["Class"])
        class:SetList(classes, keys(classes))
        if (value.value ~= nil) then
            class:SetValue(value.value)
        end
        class:SetCallback("OnValueChanged", function(widget, event, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})

if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    addon:RegisterCondition("ROLE", {
        description = L["Role"],
        icon = "Interface\\Icons\\petbattle_health",
        valid = function(spec, value)
            return (value.unit ~= nil and isin(units, value.unit) and
                    value.value ~= nil and isin(roles, value.value))
        end,
        evaluate = function(value, cache, evalStart)
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

            local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
                function() top:SetStatusText(funcs:print(root, spec)) end)
            parent:AddChild(unit)
            local role = AceGUI:Create("Dropdown")
            parent:AddChild(role)

            role:SetLabel(L["Role"])
            role:SetList(roles, keys(roles))
            if (value.value ~= nil) then
                role:SetValue(value.value)
            end
            role:SetCallback("OnValueChanged", function(widget, event, v)
                value.value = v
                top:SetStatusText(funcs:print(root, spec))
            end)
        end,
    })

    addon:RegisterCondition("TALENT", {
        description = L["Talent"],
        icon = "Interface\\Icons\\Inv_misc_book_11",
        valid = function(spec, value)
            return value.value ~= nil and value.value >= 1 and value.value <= 21
        end,
        evaluate = function(value, cache, evalStart)
            local _, _, _, selected = getCached(addon.longtermCache, GetTalentInfo, floor((value.value-1) / 3) + 1, ((value.value-1) % 3) + 1, 1)
            return selected
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
            parent:AddChild(talentIcon)
            local talent = AceGUI:Create("Dropdown")
            parent:AddChild(talent)

            talentIcon:SetWidth(44)
            talentIcon:SetHeight(44)
            talentIcon:SetImageSize(36, 36)
            talentIcon:SetImage(addon:GetSpecTalentIcon(spec, value.value))

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
        end,
    })
else
    addon:RegisterCondition("TALENT", {
        description = L["Talent"],
        icon = "Interface\\Icons\\Inv_misc_book_11",
        valid = function(spec, value)
            return (value.tree ~= nil and value.tree >= 1 and value.tree <= GetNumTalentTabs() and
                    value.talent ~= nil and value.talent >= 1 and value.talent <= GetNumTalents(value.talent) and
                    value.operator ~= nil and isin(operators, value.operator) and
                    value.value ~= nil and value.value >= 0)
        end,
        evaluate = function(value, cache, evalStart)
            local _, _, _, _, rank = getCached(addon.longtermCache, GetTalentInfo, value.tree, value.talent)
            return compare(value.operator, rank, value.value)
        end,
        print = function(spec, value)
            return compareString(value.operator, string.format(L["talent points in %s (%s)"],
                    nullable((value.tree and value.talent) and GetTalentInfo(value.tree, value.talent) or nil, L["<talent>"]),
                    nullable(value.tree and GetTalentTabInfo(value.tree) or nil, L["<talent tree>"])),
                    nullable(value.value))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local talentTrees = {}
            local talentTreesOrder = {}
            for i=1,GetNumTalentTabs() do
                talentTrees[i] = GetTalentTabInfo(i)
                table.insert(talentTreesOrder, i)
            end

            local talents = {}
            local talentsOrder = {}
            if value.tree then
                for i=1,GetNumTalents(value.tree) do
                    talents[i] = GetTalentInfo(value.tree, i)
                    table.insert(talentsOrder, i)
                end
            end

            local talentTree = AceGUI:Create("Dropdown")
            parent:AddChild(talentTree)
            local talentIcon = AceGUI:Create("Icon")
            parent:AddChild(talentIcon)
            local talent = AceGUI:Create("Dropdown")
            parent:AddChild(talent)
            local operator = AceGUI:Create("Dropdown")
            parent:AddChild(operator)
            local health = AceGUI:Create("EditBox")
            parent:AddChild(health)

            local talentTreeName
            if value.tree then
                talentTreeName = GetTalentTabInfo(value.tree)
            else
                talent:SetDisabled(true)
            end
            local talentName, talentImage
            if value.tree and value.talent then
                talentName, talentImage = GetTalentInfo(value.tree, value.talent)
            end

            talentTree:SetLabel(L["Talent Tree"])
            talentTree:SetList(talentTrees, talentTreesOrder)
            if value.tree then
                talentTree:SetValue(value.tree)
            end
            talentTree:SetCallback("OnValueChanged", function(widget, event, v)
                if v == value.tree then
                    return
                end

                value.tree = v
                talentTreeName = GetTalentTabInfo(v)
                talentTree:SetValue(v)
                top:SetStatusText(funcs:print(root, spec))

                talents = {}
                talentsOrder = {}
                for i=1,GetNumTalents(value.tree) do
                    talents[i] = GetTalentInfo(value.tree, i)
                    table.insert(talentsOrder, i)
                end
                talentIcon:SetImage(nil)
                talent:SetList(talents, talentsOrder)
                talent:SetDisabled(false)
                talentName, talentImage = nil, nil
                talent:SetValue(nil)
                talent:SetText(nil)
            end)

            talentIcon:SetWidth(44)
            talentIcon:SetHeight(44)
            talentIcon:SetImageSize(36, 36)
            if value.tree and value.talent then
                talentIcon:SetImage(talentImage)
            end

            talent:SetLabel(L["Talent"])
            talent:SetList(talents, talentsOrder)
            if value.tree and value.talent then
                talent:SetValue(value.talent)
            end
            talent:SetCallback("OnValueChanged", function(widget, event, v)
                if v == value.talent then
                    return
                end

                value.talent = v
                talentName, talentImage = GetTalentInfo(value.tree, v)
                talentIcon:SetImage(talentImage)
                talent:SetValue(v)
                top:SetStatusText(funcs:print(root, spec))
            end)

            operator:SetLabel(L["Operator"])
            operator:SetList(operators, keys(operators))
            if (value.operator ~= nil) then
                operator:SetValue(value.operator)
            end
            operator:SetCallback("OnValueChanged", function(widget, event, v)
                value.operator = v
                top:SetStatusText(funcs:print(root, spec))
            end)

            health:SetLabel(L["Points"])
            health:SetWidth(100)
            if (value.value ~= nil) then
                health:SetText(value.value)
            end
            health:SetCallback("OnEnterPressed", function(widget, event, v)
                value.value = tonumber(v)
                top:SetStatusText(funcs:print(root, spec))
            end)
        end,
    })
end
