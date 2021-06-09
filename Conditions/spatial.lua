local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local RangeCheck = LibStub("LibRangeCheck-2.0")
local color, tostring, tonumber, pairs = color, tostring, tonumber, pairs

-- From constants
local units, operators = addon.units, addon.operators

-- From utils
local compare, compareString, nullable, isin, getCached, playerize =
addon.compare, addon.compareString, addon.nullable, addon.isin, addon.getCached, addon.playerize

local helpers = addon.help_funcs
local CreateText, Gap = helpers.CreateText, helpers.Gap

addon:RegisterCondition(nil, "PROXIMITY", {
    description = L["Allies Within Range"],
    icon = "Interface\\Icons\\Spell_holy_prayerofspirit",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local count = 0
        local prefix, size
        if getCached(cache, IsInGroup) and getCached(cache, UnitInParty, value.unit) then
            prefix, size = "group", 5
        elseif getCached(cache, IsInRaid) and getCached(cache, UnitInRaid, value.unit) then
            prefix, size = "raid", 40
        end
        if prefix ~= nil and size > 0 then
            local unit_y, unit_x, _, unit_instance = getCached(cache, UnitPosition, value.unit)
            for i=1,size do
                local y, x, _, instance = getCached(cache, UnitPosition, prefix .. tostring(i))
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
    print = function(_, value)
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

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local distance = AceGUI:Create("EditBox")
        distance:SetWidth(100)
        distance:SetLabel(L["Distance"])
        distance:SetText(value.distance)
        distance:SetCallback("OnEnterPressed", function(_, _, v)
            value.distance = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(distance)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Allies Within Range"], L["Count"],
            "The number of allies whose proximity is measured in relation to " .. color.BLIZ_YELLOW .. L["Unit"] ..
            ".  This will only measure the proximity of allies you are in a party or raid with.")
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
            "The distance (in yards) allies are measured against."))
    end
})

addon:RegisterCondition(nil, "DISTANCE", {
    description = L["Distance"],
    icon = "Interface\\Icons\\Spell_arcane_teleportorgrimmar",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0 and value.value <= 40)
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local rcf = function(unit) return RangeCheck:GetRange(unit) end
        local maxRange = select(2, getCached(cache, rcf, value.unit))
        return maxRange and maxRange <= value.value
    end,
    print = function(_, value)
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

        local distance = AceGUI:Create("EditBox")
        distance:SetWidth(75)
        distance:SetLabel(L["Distance"])
        distance:SetText(value.value)
        distance:SetCallback("OnEnterPressed", function(_, _, v)
            value.value = tonumber(v)
        end)
        parent:AddChild(distance)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
            "This distance " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " must be within, in yards.  " ..
            "There are significant restrictions on how accurately distances can be measured, and all distances " ..
            "are within a range.  This will assume the unit is at the maximum of the measurable range.  Only " ..
            "distances less than or equal to 40 yards can be measured."))
    end
})

addon:RegisterCondition(nil, "DISTANCE_COUNT", {
    description = L["Distance Count"],
    icon = "Interface\\Icons\\Spell_arcane_teleportstormwind",
    valid = function(_, value)
        return (value.value ~= nil and value.value >= 0 and
                value.operator ~= nil and isin(operators, value.operator) and value.enemy ~= nil and
                value.distance ~= nil and value.distance >= 0 and value.distance <= 40)
    end,
    evaluate = function(value, cache)
        local rcf = function(unit) return RangeCheck:GetRange(unit) end
        local count = 0
        for _, entity in pairs(addon.unitsInRange) do
            if entity.enemy == value.enemy then
                local maxRange = select(2, getCached(cache, rcf, entity.unit))
                if maxRange and maxRange <= value.distance then
                    count = count + 1
                end
            end
        end
        return compare(value.operator, count, value.value)
    end,
    print = function(_, value)
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
        enemy:SetWidth(100)
        enemy:SetLabel(L["Enemy"])
        if (value.enemy ~= nil) then
            enemy:SetValue(value.enemy)
        else
            value.enemy = false
            enemy:SetValue(false)
        end
        enemy:SetCallback("OnValueChanged", function(_, _, v)
            value.enemy = v
            setDistances(value.enemy)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(enemy)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local distance = AceGUI:Create("EditBox")
        distance:SetWidth(75)
        distance:SetLabel(L["Distance"])
        distance:SetText(value.distance)
        distance:SetCallback("OnEnterPressed", function(_, _, v)
            value.distance = tonumber(v)
        end)
        parent:AddChild(distance)
    end,
    help = function(frame)
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Enemy"] .. color.RESET .. " - " ..
            "The units you are checking the distance of are enemies."))
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Distance Count"], L["Count"],
            "The number of enemies or allies whose proximity is measured in relation to you.")
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "This distance the measured enemies or allies must be within."))
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "This distance enemies or allies must be within, in yards.  There are significant restrictions " ..
                "on how accurately distances can be measured, and all distances are within a range.  This will " ..
                "assume all units are at their maximum of the measurable range.  Only distances less than or equal " ..
                "to 40 yards can be measured."))
    end
})

