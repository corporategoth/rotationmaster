local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color, pairs = color, pairs
local helpers = addon.help_funcs

local function observation(cache,method,unit,power)
    if type(method)~="function" then return nil,"missing-api" end
    local ok,current
    if power then ok,current=pcall(addon.getCached,cache,method,unit,Enum.PowerType.Mana)
    else ok,current=pcall(addon.getCached,cache,method,unit) end
    if not ok then return nil,"api-error" end
    if not addon.Platform:CanReadValue(current) then return nil,"restricted-value" end
    if type(current)~="number" or current~=current or current<0 or current==math.huge then return nil,"statistic-unavailable" end
    return current
end
local function statistic(cache,unit,mana,percentage,deficit)
    local method=UnitHealth;if mana then method=UnitPower end
    local current,reason=observation(cache,method,unit,mana)
    if current==nil then return nil,reason end
    if percentage or deficit then
        local maximumMethod=UnitHealthMax;if mana then maximumMethod=UnitPowerMax end
        local maximum,why=observation(cache,maximumMethod,unit,mana)
        if maximum==nil then return nil,why end
        if percentage then
            if maximum==0 then return nil,"statistic-unavailable" end
            local percent=current/maximum*100
            if percent~=percent or percent==math.huge then return nil,"statistic-unavailable" end
            return percent
        end
        return maximum-current
    end
    return current
end

local function aggregate(values,operation)
    if #values==0 then return nil,"no-units-in-range" end
    local value=values[1]
    if operation=="average" then
        local sum=0;for _,current in ipairs(values) do sum=sum+current end
        if sum==math.huge or sum==-math.huge or sum~=sum then return nil,"statistic-unavailable" end
        return sum/#values
    elseif operation=="minimum" or operation=="maximum" then
        for index=2,#values do
            if operation=="minimum" then value=math.min(value,values[index])
            else value=math.max(value,values[index]) end
        end
        return value
    end
    return nil,"invalid-operation"
end

addon:RegisterCondition("PROXIMITY_HEALTH", {
    description = L["Health Within Range"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\spatial",
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
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,false,false,value.value<0)
            if cur==nil then return nil,why end
            table.insert(values, cur)
        end)
        if not complete then return nil,reason end

        local v,aggregateReason=aggregate(values,value.operation)
        if v==nil then return nil,aggregateReason end
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

        local operation = addon:CreateConditionDropdown()
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

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
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
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end
})

addon:RegisterCondition("PROXIMITY_HEALTH_COUNT", {
    description = L["Health Count Within Range"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\spatial",
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
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,false,false,value.health<0)
            if cur==nil then return nil,why end
            if addon.compare(value.healthoperator, cur, math.abs(value.health)) then
                count = count + 1
            end
        end)
        if not complete then return nil,reason end

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
                addon.nullable(value.value),true)
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

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
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
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end
})

addon:RegisterCondition("PROXIMITY_HEALTHPCT", {
    description = L["Health Percentage Within Range"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\spatial",
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
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,false,true,false)
            if cur==nil then return nil,why end
            table.insert(values, cur)
        end)
        if not complete then return nil,reason end

        local v,aggregateReason=aggregate(values,value.operation)
        if v==nil then return nil,aggregateReason end
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

        local operation = addon:CreateConditionDropdown()
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

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
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
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end
})

addon:RegisterCondition("PROXIMITY_HEALTHPCT_COUNT", {
    description = L["Health Percentage Count Within Range"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\spatial",
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
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,false,true,false)
            if cur==nil then return nil,why end
            if addon.compare(value.healthoperator, cur, value.health * 100) then
                count = count + 1
            end
        end)
        if not complete then return nil,reason end
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
                addon.nullable(value.value),true)
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

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
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
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end
})
addon:RegisterCondition("PROXIMITY_MANA", {
    description = L["Mana Within Range"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\spatial",
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
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,true,false,value.value<0)
            if cur==nil then return nil,why end
            table.insert(values, cur)
        end)
        if not complete then return nil,reason end

        local v,aggregateReason=aggregate(values,value.operation)
        if v==nil then return nil,aggregateReason end
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

        local operation = addon:CreateConditionDropdown()
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

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
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
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end
})

addon:RegisterCondition("PROXIMITY_MANA_COUNT", {
    description = L["Mana Count Within Range"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\spatial",
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
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,true,false,value.mana<0)
            if cur==nil then return nil,why end
            if addon.compare(value.manaoperator, cur, math.abs(value.mana)) then
                count = count + 1
            end
        end)
        if not complete then return nil,reason end

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
                addon.nullable(value.value),true)
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

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
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
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end
})

addon:RegisterCondition("PROXIMITY_MANAPCT", {
    description = L["Mana Percentage Within Range"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\spatial",
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
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,true,true,false)
            if cur==nil then return nil,why end
            table.insert(values, cur)
        end)
        if not complete then return nil,reason end

        local v,aggregateReason=aggregate(values,value.operation)
        if v==nil then return nil,aggregateReason end
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

        local operation = addon:CreateConditionDropdown()
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

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
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
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end
})

addon:RegisterCondition("PROXIMITY_MANAPCT_COUNT", {
    description = L["Mana Percentage Count Within Range"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\spatial",
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
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,true,true,false)
            if cur==nil then return nil,why end
            if addon.compare(value.manaoperator, cur, value.mana * 100) then
                count = count + 1
            end
        end)
        if not complete then return nil,reason end
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
                addon.nullable(value.value),true)
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

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
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
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="aggregate" then return aggregate end
        if name=="color" then return color end
        if name=="helpers" then return helpers end
        if name=="observation" then return observation end
        if name=="statistic" then return statistic end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/spatial_stats.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/spatial_stats.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
