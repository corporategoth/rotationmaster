local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tostring, tonumber, pairs = tostring, tonumber, pairs

-- From constants
local units, friendly_distance, operators = addon.units, addon.friendly_distance, addon.operators

-- From utils
local compare, compareString, nullable, keys, isin, UnitCloserThan, getCached, playerize =
addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.UnitCloserThan, addon.getCached, addon.playerize

addon:RegisterCondition("PROXIMITY", {
    description = L["Allies Within Range"],
    icon = "Interface\\Icons\\Spell_holy_prayerofspirit",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        local count = 0
        local prefix, size
        if getCached(cache, IsInGroup) and getCached(cache, UnitInParty, value.unit) then
            prefix, size = "group", 5
        elseif getCached(cache, IsInRaid) and getCached(cache, UnitInRaid, value.unit) then
            prefix, size = "raid", 40
        end
        if prefix ~= nil and size > 0 then
            unit_y, unit_x, _, unit_instance = getCached(cache, UnitPosition, value.unit)
            for i=1,size do
                y, x, _, instance = getCached(cache, UnitPosition, prefix .. tostring(i))
                if x ~= nil and y ~= nil then
                    if unit_instance == instance then
                        local distance = ((unit_x - x) ^ 2 + (unit_y - y) ^ 2) ^ 0.5
                        if distance <= value.distance then
                            count = count + 1
                        end
                    end
                end
            end
        end
        return compare(value.operator, count, value.value)
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s have %s"], L["%s has %s"]),
                nullable(units[value.unit], L["<unit>"]),
                compareString(value.operator,
                        string.format(L["number of party or raid members within %d yards"], nullable(value.distance, L["<distance>"])),
                        nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
        local distance = AceGUI:Create("EditBox")
        parent:AddChild(distance)

        distance:SetLabel(L["Distance"])
        distance:SetWidth(100)
        distance:SetText(value.distance)
        distance:SetCallback("OnEnterPressed", function(widget, event, v)
            value.distance = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})

addon:RegisterCondition("DISTANCE", {
    description = L["Distance"],
    icon = "Interface\\Icons\\Spell_arcane_teleportorgrimmar",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and isin(friendly_distance, value.value))
    end,
    evaluate = function(value, cache, evalStart)
        return UnitCloserThan(cache, value.unit, value.value)
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s are %s"], L["%s is %s"]),
                nullable(value.unit, L["<unit>"]),
                string.format(L["closer than %s yards"], nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
        local distance = AceGUI:Create("Dropdown")
        parent:AddChild(distance)

        local distances = {}
        for key, _ in pairs(friendly_distance) do
            distances[key] = tostring(key) .. " " .. L["yards"]
        end

        distance:SetLabel(L["Distance"])
        distance:SetList(distances)
        distance:SetValue(value.value)
        distance:SetCallback("OnValueChanged", function(widget, event, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})

addon:RegisterCondition("DISTANCE_COUNT", {
    description = L["Distance Count"],
    icon = "Interface\\Icons\\Spell_arcane_teleportstormwind",
    valid = function(spec, value)
        return (value.value ~= nil and value.value >= 0 and
                value.operator ~= nil and isin(operators, value.operator) and
                value.enemy ~= nil and
                value.distance ~= nil and isin(friendly_distance, value.distance))
    end,
    evaluate = function(value, cache, evalStart)
        local count = 0
        for unit, entity in pairs(addon.unitsInRange) do
            if entity.enemy == value.enemy and UnitCloserThan(cache, unit, value.distance) then
                count = count + 1
            end
        end
        return compare(value.operator, count, value.value)
    end,
    print = function(spec, value)
        return compareString(value.operator,
                        string.format(L["Number of %s within %s yards"],
                            (value.enemy and L["enemies"] or "allies"),
                            nullable(value.distance, L["<distance>"])),
                        nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local enemy = AceGUI:Create("CheckBox")
        parent:AddChild(enemy)
        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
        local distance = AceGUI:Create("Dropdown")
        parent:AddChild(distance)

        enemy:SetLabel(L["Enemy"])
        enemy:SetWidth(100)
        if (value.enemy ~= nil) then
            enemy:SetValue(value.enemy)
        else
            value.enemy = false
            enemy:SetValue(false)
        end
        enemy:SetCallback("OnValueChanged", function(widget, event, v)
            value.enemy = v
            top:SetStatusText(funcs:print(root, spec))
        end)

        local distances = {}
        for key, _ in pairs(friendly_distance) do
            distances[key] = tostring(key) .. " " .. L["yards"]
        end

        distance:SetLabel(L["Distance"])
        distance:SetList(distances)
        distance:SetValue(value.distance)
        distance:SetCallback("OnValueChanged", function(widget, event, v)
            value.distance = v
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})

