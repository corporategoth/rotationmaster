local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color, pairs = color, pairs

-- From constants
local units, operators, math_operations = addon.units, addon.operators, addon.math_operations

local function avg(t)
    local sum = 0
    for _,v in pairs(t) do -- Get the sum of all numbers in t
        sum = sum + v
    end
    return sum / #t
end

-- From utils
local compare, compareString, nullable, keys, isin, getCached =
addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.getCached

local helpers = addon.help_funcs
local CreateText, Indent, Gap = helpers.CreateText, helpers.Indent, helpers.Gap
local proximity_eval, proximity_widgets = addon.proximity_eval, addon.proximity_widgets

addon:RegisterCondition("PROXIMITY_HEALTH", {
    description = L["Health Within Range"],
    icon = "Interface\\Icons\\inv_potion_52",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.operation ~= nil and isin(math_operations, value.operation) and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local values = {}
        proximity_eval(value, cache, function(c, unit)
                    local cur = getCached(c, UnitHealth, unit)
                    if value.value < 0 then
                        local max = getCached(c, UnitHealthMax, unit)
                        cur = (max-cur)
                    end
                    table.insert(values, cur)
        end)

        local v
        if value.operation == "minimum" then
            v = math.min(values)
        elseif value.operation == "average" then
            v = avg(values)
        elseif value.operation == "maximum" then
            v = math.max(values)
        end
        return compare(value.operator, v, math.abs(value.value))
    end,
    print = function(_, value)
        local conditionstr = string.format(
                ((value.value ~= nil and value.value < 0) and
                        L["The %s health defecit of %s members%s within %d yards of %s"] or
                        L["The %s health of %s members%s within %d yards of %s"]),
                nullable(value.operation, L["<operation>"]),
                (value.samegroup and PARTY or L["Raid or Party"]),
                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                nullable(value.distance, L["<distance>"]),
                nullable(units[value.unit], L["<unit>"]))
        if value.value ~= nil and value.value < 0 then
            return compareString(value.operator, conditionstr, -value.value)
        else
            return compareString(value.operator, conditionstr, nullable(value.value))
        end
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = AceGUI:Create("Dropdown")
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(math_operations, keys(math_operations))
            if (value.operation ~= nil) then
                operation:SetValue(value.operation)
            end
        end
        parent:AddChild(operation)

        local operator_group = addon:Widget_OperatorWidget(value, L["Health"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided my the number of values")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health"], L["Health"],
                "The raw health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
                        "If this number is negative, it means the health deficit (from max health).")
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

addon:RegisterCondition("PROXIMITY_HEALTH_COUNT", {
    description = L["Health Count Within Range"],
    icon = "Interface\\Icons\\inv_potion_54",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.healthoperator ~= nil and isin(operators, value.healthoperator) and
                value.health ~= nil and type(value.health) == "number" and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local count = 0
        proximity_eval(value, cache, function(c, unit)
            local cur = getCached(c, UnitHealth, unit)
            if value.value < 0 then
                local max = getCached(c, UnitHealthMax, unit)
                cur = (max-cur)
            end
            if compare(value.healthoperator, cur, math.abs(value.health)) then
                count = count + 1
            end
        end)

        return compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        local conditionstr
        if value.health ~= nil and value.health < 0 then
            conditionstr = compareString(value.healthoperator, L["%s health defecit"], -value.health)
        else
            conditionstr = compareString(value.healthoperator, L["%s health"], nullable(value.health))
        end
        return compareString(value.operator,
                string.format(conditionstr,
                        string.format(L["The number %s members%s within %d yards of %s whose"],
                                (value.samegroup and PARTY or L["Raid or Party"]),
                                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                                nullable(value.distance, L["<distance>"]),
                                nullable(units[value.unit], L["<unit>"]))),
                nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local healthoperator_group = addon:Widget_OperatorWidget(value, L["Health"],
                function() top:SetStatusText(funcs:print(root, spec)) end, "healthoperator", "health")
        parent:AddChild(healthoperator_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health"], L["Health"],
                "The raw health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
                        "If this number is negative, it means the health deficit (from max health).")
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

addon:RegisterCondition("PROXIMITY_HEALTHPCT", {
    description = L["Health Percentage Within Range"],
    icon = "Interface\\Icons\\inv_potion_51",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.operation ~= nil and isin(math_operations, value.operation) and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local values = {}
        proximity_eval(value, cache, function(c, unit)
            local cur = getCached(c, UnitHealth, unit)
            local max = getCached(c, UnitHealthMax, unit)
            table.insert(values, cur / max * 100)
        end)

        local v
        if value.operation == "minimum" then
            v = math.min(values)
        elseif value.operation == "average" then
            v = avg(values)
        elseif value.operation == "maximum" then
            v = math.max(values)
        end
        return compare(value.operator, v, value.value * 100)
    end,
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return compareString(value.operator,
                string.format(
                        L["The %s health percentage of %s members%s within %d yards of %s"],
                        nullable(value.operation, L["<operation>"]),
                        (value.samegroup and PARTY or L["Raid or Party"]),
                        (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                        nullable(value.distance, L["<distance>"]),
                        nullable(units[value.unit], L["<unit>"])),
                nullable(v) .. '%')
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = AceGUI:Create("Dropdown")
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(math_operations, keys(math_operations))
            if (value.operation ~= nil) then
                operation:SetValue(value.operation)
            end
        end
        parent:AddChild(operation)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Health"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided my the number of values")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health Percentage"], L["Health"],
                "The health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
                        "total health.")
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

addon:RegisterCondition("PROXIMITY_HEALTHPCT_COUNT", {
    description = L["Health Percentage Count Within Range"],
    icon = "Interface\\Icons\\inv_potion_53",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.healthoperator ~= nil and isin(operators, value.healthoperator) and
                value.health ~= nil and value.health >= 0.00 and value.health <= 1.00 and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local count = 0
        proximity_eval(value, cache, function(c, unit)
            local cur = getCached(c, UnitHealth, unit)
            local max = getCached(c, UnitHealthMax, unit)
            if compare(value.healthoperator, cur / max * 100, value.value * 100) then
                count = count + 1
            end
        end)
        return compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        local v = value.health
        if v ~= nil then
            v = v * 100
        end
        return compareString(value.operator,
                compareString(value.healthoperator,
                        string.format(L["The number %s members%s within %d yards of %s whose health percentage"],
                                (value.samegroup and PARTY or L["Raid or Party"]),
                                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                                nullable(value.distance, L["<distance>"]),
                                nullable(units[value.unit], L["<unit>"])),
                        nullable(v) .. "%"),
                nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local healthoperator_group = addon:Widget_OperatorPercentWidget(value, L["Health"],
                function() top:SetStatusText(funcs:print(root, spec)) end, "healthoperator", "health")
        parent:AddChild(healthoperator_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health Percentage"], L["Health"],
                "The health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
                        "total health.")
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
addon:RegisterCondition("PROXIMITY_MANA", {
    description = L["Mana Within Range"],
    icon = "Interface\\Icons\\inv_potion_73",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.operation ~= nil and isin(math_operations, value.operation) and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local values = {}
        proximity_eval(value, cache, function(c, unit)
            local cur = getCached(c, UnitPower, unit, Enum.PowerType.Mana)
            if value.value < 0 then
                local max = getCached(c, UnitPowerMax, unit, Enum.PowerType.Mana)
                cur = (max-cur)
            end
            table.insert(values, cur)
        end)

        local v
        if value.operation == "minimum" then
            v = math.min(values)
        elseif value.operation == "average" then
            v = avg(values)
        elseif value.operation == "maximum" then
            v = math.max(values)
        end
        return compare(value.operator, v, math.abs(value.value))
    end,
    print = function(_, value)
        local conditionstr = string.format(
                ((value.value ~= nil and value.value < 0) and
                        L["The %s mana defecit of %s members%s within %d yards of %s"] or
                        L["The %s mana of %s members%s within %d yards of %s"]),
                nullable(value.operation, L["<operation>"]),
                (value.samegroup and PARTY or L["Raid or Party"]),
                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                nullable(value.distance, L["<distance>"]),
                nullable(units[value.unit], L["<unit>"]))
        if value.value ~= nil and value.value < 0 then
            return compareString(value.operator, conditionstr, -value.value)
        else
            return compareString(value.operator, conditionstr, nullable(value.value))
        end
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = AceGUI:Create("Dropdown")
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(math_operations, keys(math_operations))
            if (value.operation ~= nil) then
                operation:SetValue(value.operation)
            end
        end
        parent:AddChild(operation)

        local operator_group = addon:Widget_OperatorWidget(value, L["Mana"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided my the number of values")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana"], L["Mana"],
                "The raw mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
                        "If this number is negative, it means the mana deficit (from max mana).")
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

addon:RegisterCondition("PROXIMITY_MANA_COUNT", {
    description = L["Mana Count Within Range"],
    icon = "Interface\\Icons\\inv_potion_72",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.manaoperator ~= nil and isin(operators, value.manaoperator) and
                value.mana ~= nil and type(value.mana) == "number" and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local count = 0
        proximity_eval(value, cache, function(c, unit)
            local cur = getCached(c, UnitPower, unit, Enum.PowerType.Mana)
            if value.mana < 0 then
                local max = getCached(c, UnitPowerMax, unit, Enum.PowerType.Mana)
                cur = (max-cur)
            end
            if compare(value.manaoperator, cur, math.abs(value.mana)) then
                count = count + 1
            end
        end)

        return compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        local conditionstr
        if value.mana ~= nil and value.mana < 0 then
            conditionstr = compareString(value.manaoperator, L["%s mana defecit"], -value.mana)
        else
            conditionstr = compareString(value.manaoperator, L["%s mana"], nullable(value.mana))
        end
        return compareString(value.operator,
                string.format(conditionstr,
                        string.format(L["The number %s members%s within %d yards of %s whose"],
                                (value.samegroup and PARTY or L["Raid or Party"]),
                                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                                nullable(value.distance, L["<distance>"]),
                                nullable(units[value.unit], L["<unit>"]))),
                nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local manaoperator_group = addon:Widget_OperatorWidget(value, L["Mana"],
                function() top:SetStatusText(funcs:print(root, spec)) end, "manaoperator", "mana")
        parent:AddChild(manaoperator_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana"], L["Mana"],
                "The raw mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
                        "If this number is negative, it means the mana deficit (from max mana).")
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

addon:RegisterCondition("PROXIMITY_MANAPCT", {
    description = L["Mana Percentage Within Range"],
    icon = "Interface\\Icons\\inv_potion_75",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.operation ~= nil and isin(math_operations, value.operation) and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local values = {}
        proximity_eval(value, cache, function(c, unit)
            local cur = getCached(c, UnitPower, unit, Enum.PowerType.Mana)
            local max = getCached(c, UnitPowerMax, unit, Enum.PowerType.Mana)
            table.insert(values, cur / max * 100)
        end)

        local v
        if value.operation == "minimum" then
            v = math.min(values)
        elseif value.operation == "average" then
            v = avg(values)
        elseif value.operation == "maximum" then
            v = math.max(values)
        end
        return compare(value.operator, v, value.value * 100)
    end,
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return compareString(value.operator,
                string.format(
                        L["The %s mana percentage of %s members%s within %d yards of %s"],
                        nullable(value.operation, L["<operation>"]),
                        (value.samegroup and PARTY or L["Raid or Party"]),
                        (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                        nullable(value.distance, L["<distance>"]),
                        nullable(units[value.unit], L["<unit>"])),
                nullable(v) .. '%')
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = AceGUI:Create("Dropdown")
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(math_operations, keys(math_operations))
            if (value.operation ~= nil) then
                operation:SetValue(value.operation)
            end
        end
        parent:AddChild(operation)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Mana"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided my the number of values")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana Percentage"], L["Mana"],
                "The mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
                        "total mana.")
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

addon:RegisterCondition("PROXIMITY_MANAPCT_COUNT", {
    description = L["Mana Percentage Count Within Range"],
    icon = "Interface\\Icons\\inv_potion_74",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.manaoperator ~= nil and isin(operators, value.manaoperator) and
                value.mana ~= nil and value.mana >= 0.00 and value.mana <= 1.00 and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local count = 0
        proximity_eval(value, cache, function(c, unit)
            local cur = getCached(c, UnitPower, unit, Enum.PowerType.Mana)
            local max = getCached(c, UnitPowerMax, unit, Enum.PowerType.Mana)
            if compare(value.manaoperator, cur / max * 100, value.value * 100) then
                count = count + 1
            end
        end)
        return compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        local v = value.mana
        if v ~= nil then
            v = v * 100
        end
        return compareString(value.operator,
                compareString(value.manaoperator,
                        string.format(L["The number %s members%s within %d yards of %s whose mana percentage"],
                                (value.samegroup and PARTY or L["Raid or Party"]),
                                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                                nullable(value.distance, L["<distance>"]),
                                nullable(units[value.unit], L["<unit>"])),
                        nullable(v) .. "%"),
                nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local manaoperator_group = addon:Widget_OperatorPercentWidget(value, L["Mana"],
                function() top:SetStatusText(funcs:print(root, spec)) end, "manaoperator", "mana")
        parent:AddChild(manaoperator_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana Percentage"], L["Mana"],
                "The mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
                        "total mana.")
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
