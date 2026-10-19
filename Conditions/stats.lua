local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color, tonumber = color, tonumber
local helpers = addon.help_funcs

-- Canonical callback leaves preserve the native observations, resource keys,
-- arithmetic and cache lifetimes of these existing statistic predicates.
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    cache={getCached=addon.Functions.cache.getCached},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/stats.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
}

addon:RegisterCondition("HEALTH", {
    description = L["Health"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\resources",
    fields = { unit = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local cur = Functions.cache.getCached(cache, UnitHealth, value.unit)
        if value.value < 0 then
            local max = Functions.cache.getCached(cache, UnitHealthMax, value.unit)
            return Functions.values.compare(value.operator, (max-cur), -value.value)
        else
            return Functions.values.compare(value.operator, cur, value.value)
        end
    end,
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s health defecit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), -value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s health"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Health"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health"], L["Health"],
            "The raw health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
            "If this number is negative, it means the health deficit (from max health).")
    end
})

addon:RegisterCondition("HEALTHPCT", {
    description = L["Health Percentage"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\resources",
    fields = { unit = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local health = Functions.cache.getCached(cache, UnitHealth, value.unit) / Functions.cache.getCached(cache, UnitHealthMax, value.unit) * 100;
        return Functions.values.compare(value.operator, health, value.value * 100)
    end,
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return Functions.presentation.compareString(value.operator, string.format(L["%s health"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(v) .. "%")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Health"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Health Percentage"], L["Health"],
            "The health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
            "total health.")
    end
})

addon:RegisterCondition("MANA", {
    description = L["Mana"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\resources",
    fields = { unit = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local cur = Functions.cache.getCached(cache, UnitPower, value.unit, Enum.PowerType.Mana)
        if value.value < 0 then
            local max = Functions.cache.getCached(cache, UnitPowerMax, value.unit, Enum.PowerType.Mana)
            return Functions.values.compare(value.operator, (max-cur), -value.value)
        else
            return Functions.values.compare(value.operator, cur, value.value)
        end
    end,
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s mana defecit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), -value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s mana"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Mana"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana"], L["Mana"],
            "The raw mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
            "If this number is negative, it means the mana deficit (from max mana).")
    end
})

addon:RegisterCondition("MANAPCT", {
    description = L["Mana Percentage"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\resources",
    fields = { unit = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local mana = Functions.cache.getCached(cache, UnitPower, value.unit, Enum.PowerType.Mana) / Functions.cache.getCached(cache, UnitPowerMax, value.unit, Enum.PowerType.Mana) * 100;
        return Functions.values.compare(value.operator, mana, value.value * 100)
    end,
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return Functions.presentation.compareString(value.operator, string.format(L["%s mana"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(v) .. "%")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Mana"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Mana Percentage"], L["Mana"],
            "The mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
            "total mana.")
    end
})

addon:RegisterCondition("POWER", {
    description = L["Power"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\resources",
    fields = { unit = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        -- Cannot use longterm cache for player as different forms may have different powers
        local power = Functions.cache.getCached(cache, UnitPowerType, value.unit)

        if (power == nil) then
            return false
        end

        local cur = Functions.cache.getCached(cache, UnitPower, value.unit, power)
        if value.value < 0 then
            local max = Functions.cache.getCached(cache, UnitPowerMax, value.unit, power)
            return Functions.values.compare(value.operator, (max-cur), -value.value)
        else
            return Functions.values.compare(value.operator, cur, value.value)
        end
    end,
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s power defecit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s power"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Power"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Power"], L["Power"],
            "The raw power value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".  Power is a statistic " ..
            "that is class (and sometimes spec or form) specific (eg. Warriors have Rage). " ..
            "If this number is negative, it means the power deficit (from max power).")
    end
})

addon:RegisterCondition("POWERPCT", {
    description = L["Power Percentage"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\resources",
    fields = { unit = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        -- Cannot use longterm cache for player as different forms may have different powers
        local power = Functions.cache.getCached(cache, UnitPowerType, value.unit)

        if (power == nil) then
            return false
        end
        local mana = Functions.cache.getCached(cache, UnitPower, value.unit, power) / Functions.cache.getCached(cache, UnitPowerMax, value.unit, power) * 100;
        return Functions.values.compare(value.operator, mana, value.value)
    end,
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return Functions.presentation.compareString(value.operator, string.format(L["%s power"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(v) .. "%")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Power"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Power"], L["Power"],
            "The power value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
            "total power.  Power is a statistic that is class (and sometimes spec or form) specific (eg. Warriors " ..
            "have Rage.)")
    end
})

addon:RegisterCondition("POINT", {
    description = L["Points"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\resources",
    fields = { unit = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local class
        if value.unit == "player" then
            class = select(2, Functions.cache.getCached(addon.longtermCache, UnitClass, value.unit))
        else
            class = select(2, Functions.cache.getCached(cache, UnitClass, value.unit))
        end
        if class ~= nil then
            local point = addon.points[class] or Enum.PowerType.ComboPoints
            local cur = Functions.cache.getCached(cache, UnitPower, value.unit, point)
            if value.value < 0 then
                local max = Functions.cache.getCached(cache, UnitPowerMax, value.unit, point)
                return Functions.values.compare(value.operator, (max-cur), -value.value)
            else
                return Functions.values.compare(value.operator, cur, value.value)
            end
        else
            return false
        end
    end,
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s point defecit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s points"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Points"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Points"], L["Points"],
            "The number of combo points " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " currently has.  " ..
            "Combo points are a statistic that is class (and sometimes spec or form) specific (eg. Mages have " ..
            "Arcane Charges).  " ..
            "If this number is negative, it means the point deficit (from max points).")
    end
})

if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT >= 2 and
    select(2, UnitClass("player")) == "DEATHKNIGHT") then
    addon:RegisterCondition("RUNE", {
        description = L["Runes"],
        icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\resources",
        fields = { rune = "number", operator = "string", value = "number" },
        valid = function(_, value)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    value.value ~= nil and value.value >= 0 and value.value <= 2 and
                    value.rune ~= nil and Functions.values.isin(addon.runes, value.rune))
        end,
        evaluate = function(value, cache)
            local count = 0
            for i=1,6 do
                if Functions.cache.getCached(cache, GetRuneType, i) == value.rune then
                    if select(3, Functions.cache.getCached(cache, GetRuneCooldown, i)) then count = count + 1 end
                end
            end
            return Functions.values.compare(value.operator, count, value.value)
        end,
        print = function(_, value)
            local rune_type = value.rune and addon.runes[value.rune] or L["<rune type>"]
            return Functions.presentation.compareString(value.operator, string.format(L["%s runes available"], rune_type),
                        Functions.presentation.nullable(value.value))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local rune = addon:CreateConditionDropdown()
            rune:SetLabel(L["Rune Type"])
            rune:SetCallback("OnValueChanged", function(_, _, v)
                value.rune = v
                top:SetStatusText(funcs:print(root, spec))
            end)
            rune.configure = function()
                rune:SetList(addon.runes)
                rune:SetValue(value.rune)
            end
            parent:AddChild(rune)

            local operator_group = addon:Widget_OperatorWidget(value, L["Runes"],
                    function() top:SetStatusText(funcs:print(root, spec)) end)
            parent:AddChild(operator_group)
        end,
        help = function(frame)
            addon.layout_condition_unitwidget_help(frame)
            frame:AddChild(helpers.Gap())
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Rune Type"] .. color.RESET .. " - " ..
                    "Which type of runes you wish to check."))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Blood"] .. color.RESET)))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Unholy"] .. color.RESET)))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Frost"] .. color.RESET)))
            frame:AddChild(helpers.Gap())
            addon.layout_condition_operatorwidget_help(frame, L["Runes"], L["Runes"],
                    "The number of runes currently available.")
        end
    })

    addon:RegisterCondition("RUNE_COOLDOWN", {
        description = L["Rune Cooldown"],
        icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\time",
        fields = { rune = "number", operator = "string", value = "number" },
        valid = function(_, value)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    value.value ~= nil and value.value >= 0 and
                    value.rune ~= nil and Functions.values.isin(addon.runes, value.rune))
        end,
        evaluate = function(value, cache)
            local now = GetTime()
            local lowest_remain
            for i=1,6 do
                if Functions.cache.getCached(cache, GetRuneType, i) == value.rune then
                    local start, duration = Functions.cache.getCached(cache, GetRuneCooldown, i)
                    local remain = math.max(addon.round(duration - (now - start), 3), 0)
                    if lowest_remain == nil or remain < lowest_remain then
                        lowest_remain = remain
                    end
                end
            end
            return Functions.values.compare(value.operator, lowest_remain, value.value)
        end,
        print = function(_, value)
            local rune_type = value.rune and addon.runes[value.rune] or L["<rune type>"]
            return string.format(L["the %s"],
                    Functions.presentation.compareString(value.operator, string.format(L["cooldown on %s rune"], rune_type),
                    string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local rune = addon:CreateConditionDropdown()
            rune:SetLabel(L["Rune Type"])
            rune:SetCallback("OnValueChanged", function(_, _, v)
                value.rune = v
                top:SetStatusText(funcs:print(root, spec))
            end)
            rune.configure = function()
                rune:SetList(addon.runes)
                rune:SetValue(value.rune)
            end
            parent:AddChild(rune)

            local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
                    function() top:SetStatusText(funcs:print(root, spec)) end)
            parent:AddChild(operator_group)
        end,
        help = function(frame)
            addon.layout_condition_unitwidget_help(frame)
            frame:AddChild(helpers.Gap())
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Rune Type"] .. color.RESET .. " - " ..
                    "Which type of runes you wish to check."))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Blood"] .. color.RESET)))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Unholy"] .. color.RESET)))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Frost"] .. color.RESET)))
            frame:AddChild(helpers.Gap())
            addon.layout_condition_operatorwidget_help(frame, L["Rune Cooldown"], L["Seconds"],
                    "The number of seconds until a " .. color.BLIZ_YELLOW .. L["Rune Type"] .. color.RESET ..
                    " rune becomes available.")
        end
    })
end

addon:RegisterCondition("TT_HEALTH", {
    description = L["Time Until Health"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\resources",
    fields = { unit = "string", operator = "string", value = "number", health = "number", mode = "string" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and
                value.health ~= nil)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local target = Functions.cache.getCached(cache, UnitGUID, value.unit)
        if target then
            local health = Functions.cache.getCached(cache, UnitHealth, value.unit)

            local target_health = value.health
            if value.value < 0 then
                local max = Functions.cache.getCached(cache, UnitHealthMax, value.unit)
                target_health = target_health + max
            end
            if health == target_health then
                return Functions.values.compare(value.operator, 0, value.value)
            elseif addon.damageHistory[target] then
                local trend, seconds = addon.calculate_trend(addon.damageHistory[target], nil, value.mode == "noheals", value.mode == "nodmg")
                if trend and seconds > 2 then
                    local ttt = 0 -- Time Til Target
                    if trend < 0 then
                        if target_health < health then
                            ttt = (health - target_health) / -trend
                        end
                    elseif trend > 0 then
                        if target_health > health then
                            ttt = (target_health - health) / trend
                        end
                    end
                    return Functions.values.compare(value.operator, ttt, value.value)
                end
            end
        end
        return false
    end,
    print = function(_, value)
        local conditionstr
        if value.health ~= nil and value.health < 0 then
            conditionstr = string.format(L["time until %s is at %s health defecit"],
                    Functions.presentation.nullable(value.unit, L["<unit>"]), -value.health)
        else
            conditionstr = string.format(L["time until %s is at %s health"],
                    Functions.presentation.nullable(value.unit, L["<unit>"]), Functions.presentation.nullable(value.health))
        end
        return string.format(L["%s with %s"],
            Functions.presentation.compareString(value.operator, conditionstr,
            string.format(L["%s seconds"], Functions.presentation.nullable(value.value))), addon.trendmode[value.mode or "both"])
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local health = addon:CreateConditionEditBox()
        health:SetWidth(100)
        health:SetLabel(L["Health"])
        health:SetText(value.health)
        health:SetCallback("OnEnterPressed", function(_, _, v)
            value.health = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(health)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local mode = addon:CreateConditionDropdown()
        mode:SetLabel(L["Mode"])
        mode:SetCallback("OnValueChanged", function(_, _, v)
            value.mode = (v ~= "both" and v or nil)
            top:SetStatusText(funcs:print(root, spec))
        end)
        mode.configure = function()
            mode:SetList(addon.trendmode, { "both", "noheals", "nodmg" })
            mode:SetValue(value.mode or "both")
        end
        parent:AddChild(mode)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Health"] .. color.RESET .. " - " ..
                "The target health the rule is waiting for " .. color.BLIZ_YELLOW .. L["Unit"] ..
                color.RESET .. " to get to. " ..
                "If this number is negative, it means the health deficit (from max health)."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Time Until Health"], L["Seconds"],
            "How many seconds (estimated) until the target health is acehived on  " .. color.BLIZ_YELLOW ..
                L["Unit"] .. color.RESET)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "How the burn rate should be calculated, which is used to estimate the time to target health."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Damage and Heals"] .. color.RESET .. " - " ..
                "Both damage and heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored " ..
                "into the 'burn rate' (essentially mitigating damage with heals for a realistic burn rate)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Damage Only"] .. color.RESET .. " - " ..
                "Only damage on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', which will cause some spikes in time-to-target if they are healed.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Heals Only"] .. color.RESET .. " - " ..
                "Only heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', essentially pretending they are not being hit at all.")))
    end
})

addon:RegisterCondition("TT_HEALTHPCT", {
    description = L["Time Until Health Percentage"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\resources",
    fields = { unit = "string", operator = "string", value = "number", health = "number", mode = "string" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and
                value.health ~= nil and value.health >= 0.00 and value.health <= 1.00)
    end,
    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local target = Functions.cache.getCached(cache, UnitGUID, value.unit)
        if target then
            local health, maxhealth
            if RealMobHealth then
                health, maxhealth = RealMobHealth.GetUnitHealth(value.unit)
            end
            if not health then
                health = Functions.cache.getCached(cache, UnitHealth, value.unit)
            end
            if not maxhealth then
                maxhealth = Functions.cache.getCached(cache, UnitHealthMax, value.unit)
            end

            local target_health = (maxhealth * value.health)
            if health == target_health then
                return Functions.values.compare(value.operator, 0, value.value)
            elseif addon.damageHistory[target] then
                local trend, seconds = addon.calculate_trend(addon.damageHistory[target], nil, value.mode == "noheals", value.mode == "nodmg")
                if trend and seconds > 2 then
                    local ttt = 0 -- Time Til Target
                    if trend < 0 then
                        if target_health < health then
                            ttt = (health - target_health) / -trend
                        end
                    elseif trend > 0 then
                        if target_health > health then
                            ttt = (target_health - health) / trend
                        end
                    end
                    return Functions.values.compare(value.operator, ttt, value.value)
                end
            end
        end
        return false
    end,
    print = function(_, value)
        local v = value.health
        if v ~= nil then
            v = v * 100
        end
        return string.format(L["%s with %s"],
            Functions.presentation.compareString(value.operator, string.format(L["time until %s is at %s%% health"],
                                                           Functions.presentation.nullable(value.unit, L["<unit>"]), Functions.presentation.nullable(v)),
                            string.format(L["%s seconds"], Functions.presentation.nullable(value.value))),
                            addon.trendmode[value.mode or "both"])

    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local health = addon:CreateConditionSlider()
        health:SetLabel(L["Health"])
        if (value.value ~= nil) then
            health:SetValue(value.health)
        end
        health:SetSliderValues(0, 1, 0.01)
        health:SetWidth(150)
        health:SetIsPercent(true)
        health:SetCallback("OnValueChanged", function(_, _, v)
            value.health = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(health)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local mode = addon:CreateConditionDropdown()
        mode:SetLabel(L["Mode"])
        mode:SetCallback("OnValueChanged", function(_, _, v)
            value.mode = (v ~= "both" and v or nil)
            top:SetStatusText(funcs:print(root, spec))
        end)
        mode.configure = function()
            mode:SetList(addon.trendmode, { "both", "noheals", "nodmg" })
            mode:SetValue(value.mode or "both")
        end
        parent:AddChild(mode)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Health"] .. color.RESET .. " - " ..
                "The target health the rule is waiting for " .. color.BLIZ_YELLOW .. L["Unit"] ..
                color.RESET .. " to get to as a percentage of their total health."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Time Until Health Percentage"], L["Seconds"],
            "The health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
                    "total health.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "How the burn rate should be calculated, which is used to estimate the time to target health."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Damage and Heals"] .. color.RESET .. " - " ..
                "Both damage and heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored " ..
                "into the 'burn rate' (essentially mitigating damage with heals for a realistic burn rate)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Damage Only"] .. color.RESET .. " - " ..
                "Only damage on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', which will cause some spikes in time-to-target if they are healed.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Heals Only"] .. color.RESET .. " - " ..
                "Only heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', essentially pretending they are not being hit at all.")))
    end
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/stats.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/stats.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
