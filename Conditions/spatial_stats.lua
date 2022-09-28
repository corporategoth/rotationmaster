local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color, pairs = color, pairs
local helpers = addon.help_funcs

local function avg(t)
    local sum = 0
    for _,v in pairs(t) do -- Get the sum of all numbers in t
        sum = sum + v
    end
    return sum / #t
end

addon:RegisterCondition("PROXIMITY_HEALTH", {
    description = L["Health Within Range"],
    icon = "Interface\\Icons\\inv_potion_52",
    fields = { unit = "string", operation = "string", operator = "string", value = "number", distance = "number", samegroup = "boolean", includepets = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.operation ~= nil and addon.isin(addon.math_operations, value.operation) and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local values = {}
        addon.proximity_eval(value, cache, function(c, unit)
                    local cur = addon.getCached(c, UnitHealth, unit)
                    if value.value < 0 then
                        local max = addon.getCached(c, UnitHealthMax, unit)
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
        return addon.compare(value.operator, v, math.abs(value.value))
    end,
    print = function(_, value)
        local conditionstr = string.format(
                ((value.value ~= nil and value.value < 0) and
                        L["The %s health defecit of %s members%s within %d yards of %s"] or
                        L["The %s health of %s members%s within %d yards of %s"]),
                addon.nullable(value.operation, L["<operation>"]),
                (value.samegroup and PARTY or L["Raid or Party"]),
                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                addon.nullable(value.distance, L["<distance>"]),
                addon.nullable(addon.units[value.unit], L["<unit>"]))
        if value.value ~= nil and value.value < 0 then
            return addon.compareString(value.operator, conditionstr, -value.value)
        else
            return addon.compareString(value.operator, conditionstr, addon.nullable(value.value))
        end
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = AceGUI:Create("Dropdown")
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(addon.math_operations, addon.keys(addon.math_operations))
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
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided my the number of values")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health"], L["Health"],
                "The raw health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
                        "If this number is negative, it means the health deficit (from max health).")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count addon.units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.RED .. "This will only work for yourself if you are inside " ..
                "of an instance, and it will be less accurate than outside of an instance." .. color.RESET))
    end
})

addon:RegisterCondition("PROXIMITY_HEALTH_COUNT", {
    description = L["Health Count Within Range"],
    icon = "Interface\\Icons\\inv_potion_54",
    fields = { unit = "string", healthoperator = "string", health = "number", operator = "string", value = "number", distance = "number", samegroup = "boolean", includepets = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.healthoperator ~= nil and addon.isin(addon.operators, value.healthoperator) and
                value.health ~= nil and type(value.health) == "number" and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local count = 0
        addon.proximity_eval(value, cache, function(c, unit)
            local cur = addon.getCached(c, UnitHealth, unit)
            if value.value < 0 then
                local max = addon.getCached(c, UnitHealthMax, unit)
                cur = (max-cur)
            end
            if addon.compare(value.healthoperator, cur, math.abs(value.health)) then
                count = count + 1
            end
        end)

        return addon.compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        local conditionstr
        if value.health ~= nil and value.health < 0 then
            conditionstr = addon.compareString(value.healthoperator, L["%s health defecit"], -value.health)
        else
            conditionstr = addon.compareString(value.healthoperator, L["%s health"], addon.nullable(value.health))
        end
        return addon.compareString(value.operator,
                string.format(conditionstr,
                        string.format(L["The number %s members%s within %d yards of %s whose"],
                                (value.samegroup and PARTY or L["Raid or Party"]),
                                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                                addon.nullable(value.distance, L["<distance>"]),
                                addon.nullable(addon.units[value.unit], L["<unit>"]))),
                addon.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
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
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health"], L["Health"],
                "The raw health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
                        "If this number is negative, it means the health deficit (from max health).")
        addon.layout_condition_operatorwidget_help(frame, L["Allies Within Range"], L["Count"],
                "The number of allies whose proximity is measured in relation to " .. color.BLIZ_YELLOW .. L["Unit"] ..
                        ".  This will only measure the proximity of allies you are in a party or raid with.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count addon.units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.RED .. "This will only work for yourself if you are inside " ..
                "of an instance, and it will be less accurate than outside of an instance." .. color.RESET))
    end
})

addon:RegisterCondition("PROXIMITY_HEALTHPCT", {
    description = L["Health Percentage Within Range"],
    icon = "Interface\\Icons\\inv_potion_51",
    fields = { unit = "string", operation = "string", operator = "string", value = "number", distance = "number", samegroup = "boolean", includepets = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.operation ~= nil and addon.isin(addon.math_operations, value.operation) and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local values = {}
        addon.proximity_eval(value, cache, function(c, unit)
            local cur = addon.getCached(c, UnitHealth, unit)
            local max = addon.getCached(c, UnitHealthMax, unit)
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
        return addon.compare(value.operator, v, value.value * 100)
    end,
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return addon.compareString(value.operator,
                string.format(
                        L["The %s health percentage of %s members%s within %d yards of %s"],
                        addon.nullable(value.operation, L["<operation>"]),
                        (value.samegroup and PARTY or L["Raid or Party"]),
                        (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                        addon.nullable(value.distance, L["<distance>"]),
                        addon.nullable(addon.units[value.unit], L["<unit>"])),
                addon.nullable(v) .. '%')
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = AceGUI:Create("Dropdown")
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(addon.math_operations, addon.keys(addon.math_operations))
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
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided my the number of values")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health Percentage"], L["Health"],
                "The health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
                        "total health.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count addon.units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.RED .. "This will only work for yourself if you are inside " ..
                "of an instance, and it will be less accurate than outside of an instance." .. color.RESET))
    end
})

addon:RegisterCondition("PROXIMITY_HEALTHPCT_COUNT", {
    description = L["Health Percentage Count Within Range"],
    icon = "Interface\\Icons\\inv_potion_53",
    fields = { unit = "string", healthoperator = "string", health = "number", operator = "string", value = "number", distance = "number", samegroup = "boolean", includepets = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.healthoperator ~= nil and addon.isin(addon.operators, value.healthoperator) and
                value.health ~= nil and value.health >= 0.00 and value.health <= 1.00 and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local count = 0
        addon.proximity_eval(value, cache, function(c, unit)
            local cur = addon.getCached(c, UnitHealth, unit)
            local max = addon.getCached(c, UnitHealthMax, unit)
            if addon.compare(value.healthoperator, cur / max * 100, value.value * 100) then
                count = count + 1
            end
        end)
        return addon.compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        local v = value.health
        if v ~= nil then
            v = v * 100
        end
        return addon.compareString(value.operator,
                addon.compareString(value.healthoperator,
                        string.format(L["The number %s members%s within %d yards of %s whose health percentage"],
                                (value.samegroup and PARTY or L["Raid or Party"]),
                                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                                addon.nullable(value.distance, L["<distance>"]),
                                addon.nullable(addon.units[value.unit], L["<unit>"])),
                        addon.nullable(v) .. "%"),
                addon.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
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
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health Percentage"], L["Health"],
                "The health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
                        "total health.")
        addon.layout_condition_operatorwidget_help(frame, L["Allies Within Range"], L["Count"],
                "The number of allies whose proximity is measured in relation to " .. color.BLIZ_YELLOW .. L["Unit"] ..
                        ".  This will only measure the proximity of allies you are in a party or raid with.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count addon.units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.RED .. "This will only work for yourself if you are inside " ..
                "of an instance, and it will be less accurate than outside of an instance." .. color.RESET))
    end
})
addon:RegisterCondition("PROXIMITY_MANA", {
    description = L["Mana Within Range"],
    icon = "Interface\\Icons\\inv_potion_73",
    fields = { unit = "string", operation = "string", operator = "string", value = "number", distance = "number", samegroup = "boolean", includepets = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.operation ~= nil and addon.isin(addon.math_operations, value.operation) and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local values = {}
        addon.proximity_eval(value, cache, function(c, unit)
            local cur = addon.getCached(c, UnitPower, unit, Enum.PowerType.Mana)
            if value.value < 0 then
                local max = addon.getCached(c, UnitPowerMax, unit, Enum.PowerType.Mana)
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
        return addon.compare(value.operator, v, math.abs(value.value))
    end,
    print = function(_, value)
        local conditionstr = string.format(
                ((value.value ~= nil and value.value < 0) and
                        L["The %s mana defecit of %s members%s within %d yards of %s"] or
                        L["The %s mana of %s members%s within %d yards of %s"]),
                addon.nullable(value.operation, L["<operation>"]),
                (value.samegroup and PARTY or L["Raid or Party"]),
                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                addon.nullable(value.distance, L["<distance>"]),
                addon.nullable(addon.units[value.unit], L["<unit>"]))
        if value.value ~= nil and value.value < 0 then
            return addon.compareString(value.operator, conditionstr, -value.value)
        else
            return addon.compareString(value.operator, conditionstr, addon.nullable(value.value))
        end
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = AceGUI:Create("Dropdown")
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(addon.math_operations, addon.keys(addon.math_operations))
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
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided my the number of values")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana"], L["Mana"],
                "The raw mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
                        "If this number is negative, it means the mana deficit (from max mana).")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count addon.units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.RED .. "This will only work for yourself if you are inside " ..
                "of an instance, and it will be less accurate than outside of an instance." .. color.RESET))
    end
})

addon:RegisterCondition("PROXIMITY_MANA_COUNT", {
    description = L["Mana Count Within Range"],
    icon = "Interface\\Icons\\inv_potion_72",
    fields = { unit = "string", manaoperator = "string", mana = "number", operator = "string", value = "number", distance = "number", samegroup = "boolean", includepets = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.manaoperator ~= nil and addon.isin(addon.operators, value.manaoperator) and
                value.mana ~= nil and type(value.mana) == "number" and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local count = 0
        addon.proximity_eval(value, cache, function(c, unit)
            local cur = addon.getCached(c, UnitPower, unit, Enum.PowerType.Mana)
            if value.mana < 0 then
                local max = addon.getCached(c, UnitPowerMax, unit, Enum.PowerType.Mana)
                cur = (max-cur)
            end
            if addon.compare(value.manaoperator, cur, math.abs(value.mana)) then
                count = count + 1
            end
        end)

        return addon.compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        local conditionstr
        if value.mana ~= nil and value.mana < 0 then
            conditionstr = addon.compareString(value.manaoperator, L["%s mana defecit"], -value.mana)
        else
            conditionstr = addon.compareString(value.manaoperator, L["%s mana"], addon.nullable(value.mana))
        end
        return addon.compareString(value.operator,
                string.format(conditionstr,
                        string.format(L["The number %s members%s within %d yards of %s whose"],
                                (value.samegroup and PARTY or L["Raid or Party"]),
                                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                                addon.nullable(value.distance, L["<distance>"]),
                                addon.nullable(addon.units[value.unit], L["<unit>"]))),
                addon.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
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
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana"], L["Mana"],
                "The raw mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
                        "If this number is negative, it means the mana deficit (from max mana).")
        addon.layout_condition_operatorwidget_help(frame, L["Allies Within Range"], L["Count"],
                "The number of allies whose proximity is measured in relation to " .. color.BLIZ_YELLOW .. L["Unit"] ..
                        ".  This will only measure the proximity of allies you are in a party or raid with.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count addon.units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.RED .. "This will only work for yourself if you are inside " ..
                "of an instance, and it will be less accurate than outside of an instance." .. color.RESET))
    end
})

addon:RegisterCondition("PROXIMITY_MANAPCT", {
    description = L["Mana Percentage Within Range"],
    icon = "Interface\\Icons\\inv_potion_75",
    fields = { unit = "string", operation = "string", operator = "string", value = "number", distance = "number", samegroup = "boolean", includepets = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.operation ~= nil and addon.isin(addon.math_operations, value.operation) and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local values = {}
        addon.proximity_eval(value, cache, function(c, unit)
            local cur = addon.getCached(c, UnitPower, unit, Enum.PowerType.Mana)
            local max = addon.getCached(c, UnitPowerMax, unit, Enum.PowerType.Mana)
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
        return addon.compare(value.operator, v, value.value * 100)
    end,
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return addon.compareString(value.operator,
                string.format(
                        L["The %s mana percentage of %s members%s within %d yards of %s"],
                        addon.nullable(value.operation, L["<operation>"]),
                        (value.samegroup and PARTY or L["Raid or Party"]),
                        (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                        addon.nullable(value.distance, L["<distance>"]),
                        addon.nullable(addon.units[value.unit], L["<unit>"])),
                addon.nullable(v) .. '%')
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = AceGUI:Create("Dropdown")
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(addon.math_operations, addon.keys(addon.math_operations))
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
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided my the number of values")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana Percentage"], L["Mana"],
                "The mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
                        "total mana.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count addon.units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.RED .. "This will only work for yourself if you are inside " ..
                "of an instance, and it will be less accurate than outside of an instance." .. color.RESET))
    end
})

addon:RegisterCondition("PROXIMITY_MANAPCT_COUNT", {
    description = L["Mana Percentage Count Within Range"],
    icon = "Interface\\Icons\\inv_potion_74",
    fields = { unit = "string", manaoperator = "string", mana = "number", operator = "string", value = "number", distance = "number", samegroup = "boolean", includepets = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.manaoperator ~= nil and addon.isin(addon.operators, value.manaoperator) and
                value.mana ~= nil and value.mana >= 0.00 and value.mana <= 1.00 and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    evaluate = function(value, cache)
        local count = 0
        addon.proximity_eval(value, cache, function(c, unit)
            local cur = addon.getCached(c, UnitPower, unit, Enum.PowerType.Mana)
            local max = addon.getCached(c, UnitPowerMax, unit, Enum.PowerType.Mana)
            if addon.compare(value.manaoperator, cur / max * 100, value.value * 100) then
                count = count + 1
            end
        end)
        return addon.compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        local v = value.mana
        if v ~= nil then
            v = v * 100
        end
        return addon.compareString(value.operator,
                addon.compareString(value.manaoperator,
                        string.format(L["The number %s members%s within %d yards of %s whose mana percentage"],
                                (value.samegroup and PARTY or L["Raid or Party"]),
                                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                                addon.nullable(value.distance, L["<distance>"]),
                                addon.nullable(addon.units[value.unit], L["<unit>"])),
                        addon.nullable(v) .. "%"),
                addon.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
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
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana Percentage"], L["Mana"],
                "The mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
                        "total mana.")
        addon.layout_condition_operatorwidget_help(frame, L["Allies Within Range"], L["Count"],
                "The number of allies whose proximity is measured in relation to " .. color.BLIZ_YELLOW .. L["Unit"] ..
                        ".  This will only measure the proximity of allies you are in a party or raid with.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count addon.units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.RED .. "This will only work for yourself if you are inside " ..
                "of an instance, and it will be less accurate than outside of an instance." .. color.RESET))
    end
})
