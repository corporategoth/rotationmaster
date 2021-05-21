local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color, tostring, tonumber, pairs = color, tostring, tonumber, pairs
local floor = math.floor

-- From constants
local operators, units, unitsPossessive, roles, debufftypes, zonepvp, instances, totems, points =
    addon.operators, addon.units, addon.unitsPossessive, addon.roles, addon.debufftypes,
    addon.zonepvp, addon.instances, addon.totems, addon.points

-- From utils
local compare, compareString, nullable, keys, tomap, isin, cleanArray, deepcopy, getCached =
    addon.compare, addon.compareString, addon.nullable, addon.keys, addon.tomap,
    addon.isin, addon.cleanArray, addon.deepcopy, addon.getCached

local helpers = addon.help_funcs
local CreateText, CreatePictureText, CreateButtonText, Indent, Gap =
helpers.CreateText, helpers.CreatePictureText, helpers.CreateButtonText, helpers.Indent, helpers.Gap

addon:RegisterCondition(L["Combat"], "HEALTH", {
    description = L["Health"],
    icon = "Interface\\Icons\\inv_potion_36",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local cur
        if RealMobHealth then
            cur = RealMobHealth.GetUnitHealth(value.unit)
        end
        if not cur then
            cur = getCached(cache, UnitHealth, value.unit)
        end
        return compare(value.operator, cur, value.value)
    end,
    print = function(spec, value)
        return compareString(value.operator, string.format(L["%s health"], nullable(unitsPossessive[value.unit], L["<unit>"])), nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Health"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health"], L["Health"],
            "The raw health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".")
    end
})

addon:RegisterCondition(L["Combat"], "HEALTHPCT", {
    description = L["Health Percentage"],
    icon = "Interface\\Icons\\inv_potion_35",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache, evalStart)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local health = getCached(cache, UnitHealth, value.unit) / getCached(cache, UnitHealthMax, value.unit) * 100;
        return compare(value.operator, health, value.value * 100)
    end,
    print = function(spec, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return compareString(value.operator, string.format(L["%s health"], nullable(unitsPossessive[value.unit], L["<unit>"])), nullable(v) .. "%")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Health"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Health Percentage"], L["Health"],
            "The health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
            "total health.")
    end
})

addon:RegisterCondition(L["Combat"], "MANA", {
    description = L["Mana"],
    icon = "Interface\\Icons\\inv_potion_71",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        if not getCached(cache, UnitExists, value.unit) then return false end
        return compare(value.operator, getCached(cache, UnitPower, value.unit, SPELL_POWER_MANA), value.value)
    end,
    print = function(spec, value)
        return compareString(value.operator, string.format(L["%s mana"], nullable(unitsPossessive[value.unit], L["<unit>"])), nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Mana"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana"], L["Mana"],
            "The raw mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".")
    end
})

addon:RegisterCondition(L["Combat"], "MANAPCT", {
    description = L["Mana Percentage"],
    icon = "Interface\\Icons\\inv_potion_70",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache, evalStart)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local mana = getCached(cache, UnitPower, value.unit, SPELL_POWER_MANA) / getCached(cache, UnitPowerMax, value.unit, SPELL_POWER_MANA) * 100;
        return compare(value.operator, mana, value.value * 100)
    end,
    print = function(spec, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return compareString(value.operator, string.format(L["%s mana"], nullable(unitsPossessive[value.unit], L["<unit>"])), nullable(v) .. "%")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Mana"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Mana Percentage"], L["Mana"],
            "The mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
            "total mana.")
    end
})

addon:RegisterCondition(L["Combat"], "POWER", {
    description = L["Power"],
    icon = "Interface\\Icons\\inv_potion_92",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local power
        if value.unit == "player" then
            power = getCached(addon.longtermCache, UnitPowerType, value.unit)
        else
            power = getCached(cache, UnitPowerType, value.unit)
        end

        if (power == nil) then
            return false
        end
        return compare(value.operator, getCached(cache, UnitPower, value.unit, power), value.value)
    end,
    print = function(spec, value)
        return compareString(value.operator, string.format(L["%s power"], nullable(unitsPossessive[value.unit], L["<unit>"])), nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Power"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Power"], L["Power"],
            "The raw power value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".  Power is a statistic " ..
            "that is class (and sometimes spec or form) specific (eg. Warriors have Rage.)")
    end
})

addon:RegisterCondition(L["Combat"], "POWERPCT", {
    description = L["Power Percentage"],
    icon = "Interface\\Icons\\inv_potion_91",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache, evalStart)
        if not getCached(cache, UnitExists, value.unit) then return false end
        if value.unit == "player" then
            power = getCached(addon.longtermCache, UnitPowerType, value.unit)
        else
            power = getCached(cache, UnitPowerType, value.unit * 100)
        end
        if (power == nil) then
            return false
        end
        local mana = getCached(cache, UnitPower, value.unit, power) / getCached(cache, UnitPowerMax, value.unit, power) * 100;
        return compare(value.operator, mana, value.value)
    end,
    print = function(spec, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return compareString(value.operator, string.format(L["%s power"], nullable(unitsPossessive[value.unit], L["<unit>"])), nullable(v) .. "%")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Power"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Power"], L["Power"],
            "The power value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
            "total power.  Power is a statistic that is class (and sometimes spec or form) specific (eg. Warriors " ..
            "have Rage.)")
    end
})

addon:RegisterCondition(L["Combat"], "POINT", {
    description = L["Points"],
    icon = "Interface\\Icons\\Inv_jewelry_amulet_01",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local class
        if value.unit == "player" then
            class = select(2, getCached(addon.longtermCache, UnitClass, value.unit))
        else
            class = select(2, getCached(cache, UnitClass, value.unit))
        end
        if class ~= nil then
            local point = points[class] or Enum.PowerType.ComboPoints
            return compare(value.operator, getCached(cache, UnitPower, value.unit, point), value.value)
        else
            return false
        end
    end,
    print = function(spec, value)
        return compareString(value.operator, string.format(L["%s points"], nullable(unitsPossessive[value.unit], L["<unit>"])), nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Points"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Points"], L["Points"],
            "The number of combo points " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " currently has.  " ..
            "Combo points are a statistic that is class (and sometimes spec or form) specific (eg. Mages have " ..
            "Arcane Charges.)")
    end
})

addon:RegisterCondition(L["Combat"], "TT_HEALTH", {
    description = L["Time Until Health"],
    icon = "Interface\\Icons\\inv_potion_21",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and
                value.health ~= nil and value.health >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local target = getCached(cache, UnitGUID, value.unit)
        if target then
            local health
            if RealMobHealth then
                health = RealMobHealth.GetUnitHealth(value.unit)
            end
            if not health then
                health = getCached(cache, UnitHealth, value.unit)
            end

            local target_health = value.health
            if health == target_health then
                return compare(value.operator, 0, value.value)
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
                    return compare(value.operator, ttt, value.value)
                end
            end
        end
        return false
    end,
    print = function(spec, value)
        return string.format(L["%s with %s"],
            compareString(value.operator, string.format(L["time until %s is at %s health"],
            nullable(value.unit, L["<unit>"]), nullable(value.health)),
            string.format(L["%s seconds"], nullable(value.value))), addon.trendmode[value.mode or "both"])
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local health = AceGUI:Create("EditBox")
        health:SetWidth(100)
        health:SetLabel(L["Health"])
        health:SetText(value.health)
        health:SetCallback("OnEnterPressed", function(widget, event, v)
            value.health = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(health)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local mode = AceGUI:Create("Dropdown")
        mode:SetLabel(L["Mode"])
        mode:SetCallback("OnValueChanged", function(widget, event, v)
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
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Health"] .. color.RESET .. " - " ..
                "The target health the rule is waiting for " .. color.BLIZ_YELLOW .. L["Unit"] ..
                color.RESET .. " to get to."))
        frame:AddChild(Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Time Until Health"], L["Seconds"],
            "How many seconds (estimated) until the target health is acehived on  " .. color.BLIZ_YELLOW ..
                L["Unit"] .. color.RESET)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "How the burn rate should be calculated, which is used to estimate the time to target health."))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Damage and Heals"] .. color.RESET .. " - " ..
                "Both damage and heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored " ..
                "into the 'burn rate' (essentially mitigating damage with heals for a realistic burn rate)")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Damage Only"] .. color.RESET .. " - " ..
                "Only damage on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', which will cause some spikes in time-to-target if they are healed.")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Heals Only"] .. color.RESET .. " - " ..
                "Only heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', essentially pretending they are not being hit at all.")))
    end
})

addon:RegisterCondition(L["Combat"], "TT_HEALTHPCT", {
    description = L["Time Until Health Percentage"],
    icon = "Interface\\Icons\\inv_potion_24",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and
                value.health ~= nil and value.health >= 0.00 and value.health <= 1.00)
    end,
    evaluate = function(value, cache, evalStart)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local target = getCached(cache, UnitGUID, value.unit)
        if target then
            local health, maxhealth
            if RealMobHealth then
                health, maxhealth = RealMobHealth.GetUnitHealth(value.unit)
            end
            if not health then
                health = getCached(cache, UnitHealth, value.unit)
            end
            if not maxhealth then
                maxhealth = getCached(cache, UnitHealthMax, value.unit)
            end

            local target_health = (maxhealth * value.health)
            if health == target_health then
                return compare(value.operator, 0, value.value)
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
                    return compare(value.operator, ttt, value.value)
                end
            end
        end
        return false
    end,
    print = function(spec, value)
        local v = value.health
        if v ~= nil then
            v = v * 100
        end
        return string.format(L["%s with %s"],
            compareString(value.operator, string.format(L["time until %s is at %s%% health"],
                                                           nullable(value.unit, L["<unit>"]), nullable(v)),
                            string.format(L["%s seconds"], nullable(value.value))),
                            addon.trendmode[value.mode or "both"])

    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local health = AceGUI:Create("Slider")
        health:SetLabel(L["Health"])
        if (value.value ~= nil) then
            health:SetValue(value.health)
        end
        health:SetSliderValues(0, 1, 0.01)
        health:SetWidth(150)
        health:SetIsPercent(true)
        health:SetCallback("OnValueChanged", function(widget, event, v)
            value.health = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(health)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local mode = AceGUI:Create("Dropdown")
        mode:SetLabel(L["Mode"])
        mode:SetCallback("OnValueChanged", function(widget, event, v)
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
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Health"] .. color.RESET .. " - " ..
                "The target health the rule is waiting for " .. color.BLIZ_YELLOW .. L["Unit"] ..
                color.RESET .. " to get to as a percentage of their total health."))
        frame:AddChild(Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Time Until Health Percentage"], L["Seconds"],
            "The health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
                    "total health.")
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "How the burn rate should be calculated, which is used to estimate the time to target health."))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Damage and Heals"] .. color.RESET .. " - " ..
                "Both damage and heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored " ..
                "into the 'burn rate' (essentially mitigating damage with heals for a realistic burn rate)")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Damage Only"] .. color.RESET .. " - " ..
                "Only damage on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', which will cause some spikes in time-to-target if they are healed.")))
        frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Heals Only"] .. color.RESET .. " - " ..
                "Only heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', essentially pretending they are not being hit at all.")))
    end
})

