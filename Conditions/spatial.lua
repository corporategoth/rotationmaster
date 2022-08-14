local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local RangeCheck = LibStub("LibRangeCheck-2.0")
local color, tostring, tonumber, pairs = color, tostring, tonumber, pairs

-- From constants
local units, operators = addon.units, addon.operators

-- From utils
local compare, compareString, nullable, keys, isin, getCached, playerize =
addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.getCached, addon.playerize

local helpers = addon.help_funcs
local CreateText, Gap = helpers.CreateText, helpers.Gap

local rcf = function(unit) return RangeCheck:GetRange(unit) end
local function calc_distance(cache, unit, unit_y, unit_x, unit_instance, otherunit)
    if unit == otherunit then
        return 0
    elseif unit_x ~= nil and unit_y ~= nil and unit_instance ~= nil then
        local y, x, _, instance = getCached(cache, UnitPosition, otherunit)
        if x ~= nil and y ~= nil and unit_instance == instance then
            return ((unit_x - x) ^ 2 + (unit_y - y) ^ 2) ^ 0.5
        end
    elseif unit == "player" then
        return getCached(cache, rcf, otherunit)
    end
end

addon.proximity_eval = function(value, cache, func)
    if not getCached(cache, UnitExists, value.unit) then return false end
    local prefix, size, group
    if getCached(cache, IsInRaid) and getCached(cache, UnitPlayerOrPetInRaid, value.unit) then
        prefix, size = "raid", 40
        if value.samegroup then
            local idx = getCached(cache, UnitInRaid, value.unit)
            if not idx then
                for i=1,size do
                    if getCached(cache, UnitIsUnit, value.unit, "raidpet" .. tostring(i)) then
                        idx = i
                        break
                    end
                end
            end
            group = select(3, GetRaidRosterInfo(idx))
        end
    elseif getCached(cache, IsInGroup) and getCached(cache, UnitPlayerOrPetInParty, value.unit) then
        prefix, size = "party", 4
    elseif not getCached(cache, IsInGroup) and (value.unit == "player" or value.unit == "pet") then
        prefix, size = "party", 0
    end
    if prefix ~= nil then
        local unit_y, unit_x, _, unit_instance = getCached(cache, UnitPosition, value.unit)
        if prefix == "party" then
            local distance = calc_distance(cache, value.unit, unit_y, unit_x, unit_instance, "player")
            if distance ~= nil and distance <= value.distance then
                func(cache, "player", distance)
            end
        end
        for i=1,size do
            local continue = true
            if group ~= nil then
                continue = (group == select(3, GetRaidRosterInfo(i)))
            end
            if continue then
                local distance = calc_distance(cache, value.unit, unit_y, unit_x, unit_instance, prefix .. tostring(i))
                if distance ~= nil and distance <= value.distance then
                    func(cache, prefix .. tostring(i), distance)
                end
            end
        end
        if value.includepets then
            if prefix == "party" then
                local distance = calc_distance(cache, value.unit, unit_y, unit_x, unit_instance, "pet")
                if distance ~= nil and distance <= value.distance then
                    func(cache, "pet", distance)
                end
            end
            for i=1,size do
                local continue = true
                if group ~= nil then
                    continue = (group == select(3, GetRaidRosterInfo(i)))
                end
                if continue then
                    local distance = calc_distance(cache, value.unit, unit_y, unit_x, unit_instance, prefix .. "pet" .. tostring(i))
                    if distance ~= nil and distance <= value.distance then
                        func(cache, prefix .. "pet" .. tostring(i), distance)
                    end
                end
            end
        end
    end
end

addon.proximity_widgets = function(top, root, funcs, parent, spec, value)
    local distance = AceGUI:Create("EditBox")
    distance:SetWidth(100)
    distance:SetLabel(L["Distance"])
    distance:SetText(value.distance)
    distance:SetCallback("OnEnterPressed", function(_, _, v)
        value.distance = tonumber(v)
        top:SetStatusText(funcs:print(root, spec))
    end)
    parent:AddChild(distance)

    local samegroup = AceGUI:Create("CheckBox")
    samegroup:SetWidth(100)
    samegroup:SetLabel(L["Same Group"])
    samegroup:SetValue(value.samegroup and true or false)
    samegroup:SetCallback("OnValueChanged", function(_, _, v)
        value.samegroup = v
        top:SetStatusText(funcs:print(root, spec))
    end)
    parent:AddChild(samegroup)

    local includepets = AceGUI:Create("CheckBox")
    includepets:SetWidth(100)
    includepets:SetLabel(L["Include Pets"])
    includepets:SetValue(value.includepets and true or false)
    includepets:SetCallback("OnValueChanged", function(_, _, v)
        value.includepets = v
        top:SetStatusText(funcs:print(root, spec))
    end)
    parent:AddChild(includepets)
end

addon:RegisterCondition("PROXIMITY", {
    description = L["Allies Within Range"],
    icon = "Interface\\Icons\\Spell_holy_prayerofspirit",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local count = 0
        addon.proximity_eval(value, cache, function(cache, unit)
            count = count + 1
        end)
        return compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        return string.format(playerize(value.unit, L["%s have %s"], L["%s has %s"]),
                nullable(units[value.unit], L["<unit>"]),
                compareString(value.operator,
                        string.format(L["number of %s members%s within %d yards"],
                                (value.samegroup and PARTY or L["Raid or Party"]),
                                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                                nullable(value.distance, L["<distance>"])),
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

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
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
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count units in the same raid group."))
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.RED .. "This will only work for yourself if you are inside " ..
                "of an instance, and it will be less accurate than outside of an instance." .. color.RESET))
    end
})

addon:RegisterCondition("DISTANCE", {
    description = L["Distance"],
    icon = "Interface\\Icons\\Spell_arcane_teleportorgrimmar",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0 and value.value <= 40)
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
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

addon:RegisterCondition("DISTANCE_COUNT", {
    description = L["Distance Count"],
    icon = "Interface\\Icons\\Spell_arcane_teleportstormwind",
    valid = function(_, value)
        return (value.value ~= nil and value.value >= 0 and
                value.operator ~= nil and isin(operators, value.operator) and value.enemy ~= nil and
                value.distance ~= nil and value.distance >= 0 and
                value.distance <= tonumber(C_CVar.GetCVar("nameplateMaxDistance")))
    end,
    evaluate = function(value, cache)
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
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(enemy)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local distance = AceGUI:Create("Slider")
        distance:SetWidth(150)
        distance:SetLabel(L["Distance"])
        if value.distance == nil then
            value.distance = tonumber(C_CVar.GetCVar("nameplateMaxDistance"))
        end

        distance:SetValue(value.distance)
        distance:SetSliderValues(1, tonumber(C_CVar.GetCVar("nameplateMaxDistance")), 1)
        distance:SetCallback("OnValueChanged", function(_, _, v)
            value.distance = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
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
                "This distance enemies or allies must be within, in yards.  There are significant restrictions " ..
                "on how accurately distances can be measured, and all distances are within a range.  This will " ..
                "assume all units are at their maximum of the measurable range.  The maximum range is set using " ..
                "Game Options -> Interface -> Game tab -> Names -> Nameplate Distance."))
        frame:AddChild(Gap())
    end
})

addon:RegisterCondition("ZONE", {
    description = L["Zone"],
    icon = "Interface\\Icons\\spell_nature_farsight",
    valid = function(_, value)
        return value.value ~= nil
    end,
    evaluate = function(value, cache)
        local zoneName = value.subzone and getCached(cache, GetSubZoneText) or getCached(cache, GetZoneText)
        return value.value == zoneName
    end,
    print = function(_, value)
        return string.format(L["in %s"], nullable(value.value, L["<zone>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local subzone = AceGUI:Create("CheckBox")
        subzone:SetWidth(100)
        subzone:SetLabel(L["SubZone"])
        subzone:SetValue(value.subzone and true or false)
        subzone:SetCallback("OnValueChanged", function(_, _, v)
            value.subzone = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(subzone)

        local zone = AceGUI:Create("EditBox")
        zone:SetLabel(L["Zone"])
        zone:SetCallback("OnEnterPressed", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        if (value.value ~= nil) then
            zone:SetText(value.value)
        end
        parent:AddChild(zone)
    end,
    help = function(frame)
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["SubZone"] .. color.RESET ..
                " - " .. "Use the SubZone text instead of Zone text (eg. Valley of Strength instead of Orgrimmar)"))
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Zone"] .. color.RESET ..
                " - " .. "The zone you are in."))
    end
})