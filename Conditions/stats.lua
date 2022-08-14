local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color, tonumber = color, tonumber

-- From constants
local operators, units, unitsPossessive, points, runes =
    addon.operators, addon.units, addon.unitsPossessive, addon.points, addon.runes

-- From utils
local compare, compareString, nullable, isin, getCached =
    addon.compare, addon.compareString, addon.nullable, addon.isin, addon.getCached

local round = math.round

local helpers = addon.help_funcs
local CreateText, Indent, Gap = helpers.CreateText, helpers.Indent, helpers.Gap

addon:RegisterCondition("HEALTH", {
    description = L["Health"],
    icon = "Interface\\Icons\\inv_potion_36",
    valid = function(_, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and type(value.value) == "number")
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local cur = getCached(cache, UnitHealth, value.unit)
        if value.value < 0 then
            local max = getCached(cache, UnitHealthMax, value.unit)
            return compare(value.operator, (max-cur), -value.value)
        else
            return compare(value.operator, cur, value.value)
        end
    end,
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return compareString(value.operator, string.format(L["%s health defecit"], nullable(unitsPossessive[value.unit], L["<unit>"])), -value.value)
        else
            return compareString(value.operator, string.format(L["%s health"], nullable(unitsPossessive[value.unit], L["<unit>"])), nullable(value.value))
        end
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
            "The raw health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
            "If this number is negative, it means the health deficit (from max health).")
    end
})

addon:RegisterCondition("HEALTHPCT", {
    description = L["Health Percentage"],
    icon = "Interface\\Icons\\inv_potion_35",
    valid = function(_, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local health = getCached(cache, UnitHealth, value.unit) / getCached(cache, UnitHealthMax, value.unit) * 100;
        return compare(value.operator, health, value.value * 100)
    end,
    print = function(_, value)
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

addon:RegisterCondition("MANA", {
    description = L["Mana"],
    icon = "Interface\\Icons\\inv_potion_71",
    valid = function(_, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and type(value.value) == "number")
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local cur = getCached(cache, UnitPower, value.unit, Enum.PowerType.Mana)
        if value.value < 0 then
            local max = getCached(cache, UnitPowerMax, value.unit, Enum.PowerType.Mana)
            return compare(value.operator, (max-cur), -value.value)
        else
            return compare(value.operator, cur, value.value)
        end
    end,
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return compareString(value.operator, string.format(L["%s mana defecit"], nullable(unitsPossessive[value.unit], L["<unit>"])), -value.value)
        else
            return compareString(value.operator, string.format(L["%s mana"], nullable(unitsPossessive[value.unit], L["<unit>"])), nullable(value.value))
        end
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
            "The raw mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
            "If this number is negative, it means the mana deficit (from max mana).")
    end
})

addon:RegisterCondition("MANAPCT", {
    description = L["Mana Percentage"],
    icon = "Interface\\Icons\\inv_potion_70",
    valid = function(_, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local mana = getCached(cache, UnitPower, value.unit, Enum.PowerType.Mana) / getCached(cache, UnitPowerMax, value.unit, Enum.PowerType.Mana) * 100;
        return compare(value.operator, mana, value.value * 100)
    end,
    print = function(_, value)
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

addon:RegisterCondition("POWER", {
    description = L["Power"],
    icon = "Interface\\Icons\\inv_potion_92",
    valid = function(_, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and type(value.value) == "number")
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        -- Cannot use longterm cache for player as different forms may have different powers
        local power = getCached(cache, UnitPowerType, value.unit)

        if (power == nil) then
            return false
        end

        local cur = getCached(cache, UnitPower, value.unit, power)
        if value.value < 0 then
            local max = getCached(cache, UnitPowerMax, value.unit, power)
            return compare(value.operator, (max-cur), -value.value)
        else
            return compare(value.operator, cur, value.value)
        end
    end,
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return compareString(value.operator, string.format(L["%s power defecit"], nullable(unitsPossessive[value.unit], L["<unit>"])), value.value)
        else
            return compareString(value.operator, string.format(L["%s power"], nullable(unitsPossessive[value.unit], L["<unit>"])), nullable(value.value))
        end
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
            "that is class (and sometimes spec or form) specific (eg. Warriors have Rage). " ..
            "If this number is negative, it means the power deficit (from max power).")
    end
})

addon:RegisterCondition("POWERPCT", {
    description = L["Power Percentage"],
    icon = "Interface\\Icons\\inv_potion_91",
    valid = function(_, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        -- Cannot use longterm cache for player as different forms may have different powers
        local power = getCached(cache, UnitPowerType, value.unit)

        if (power == nil) then
            return false
        end
        local mana = getCached(cache, UnitPower, value.unit, power) / getCached(cache, UnitPowerMax, value.unit, power) * 100;
        return compare(value.operator, mana, value.value)
    end,
    print = function(_, value)
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

addon:RegisterCondition("POINT", {
    description = L["Points"],
    icon = "Interface\\Icons\\Inv_jewelry_amulet_01",
    valid = function(_, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and type(value.value) == "number")
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local class
        if value.unit == "player" then
            class = select(2, getCached(addon.longtermCache, UnitClass, value.unit))
        else
            class = select(2, getCached(cache, UnitClass, value.unit))
        end
        if class ~= nil then
            local point = points[class] or Enum.PowerType.ComboPoints
            local cur = getCached(cache, UnitPower, value.unit, point)
            if value.value < 0 then
                local max = getCached(cache, UnitPowerMax, value.unit, point)
                return compare(value.operator, (max-cur), -value.value)
            else
                return compare(value.operator, cur, value.value)
            end
        else
            return false
        end
    end,
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return compareString(value.operator, string.format(L["%s point defecit"], nullable(unitsPossessive[value.unit], L["<unit>"])), value.value)
        else
            return compareString(value.operator, string.format(L["%s points"], nullable(unitsPossessive[value.unit], L["<unit>"])), nullable(value.value))
        end
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
            "Arcane Charges).  " ..
            "If this number is negative, it means the point deficit (from max points).")
    end
})

if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT >= 2 and
    select(2, UnitClass("player")) == "DEATHKNIGHT") then
    addon:RegisterCondition("RUNE", {
        description = L["Runes"],
        icon = "Interface\\Icons\\spell_deathknight_empowerruneblade",
        valid = function(_, value)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    value.value ~= nil and value.value >= 0 and value.value <= 2 and
                    value.rune ~= nil and isin(runes, value.rune))
        end,
        evaluate = function(value, cache)
            local points = 0
            for i=1,6 do
                if getCached(cache, GetRuneType, i) == value.rune then
                    if select(3, getCached(cache, GetRuneCooldown, i)) then points = points + 1 end
                end
            end
            return compare(value.operator, points, value.value)
        end,
        print = function(_, value)
            local rune_type = value.rune and addon.runes[value.rune] or L["<rune type>"]
            return compareString(value.operator, string.format(L["%s runes available"], rune_type),
                        nullable(value.value))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local rune = AceGUI:Create("Dropdown")
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
            frame:AddChild(Gap())
            frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Rune Type"] .. color.RESET .. " - " ..
                    "Which type of runes you wish to check."))
            frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Blood"] .. color.RESET)))
            frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Unholy"] .. color.RESET)))
            frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Frost"] .. color.RESET)))
            frame:AddChild(Gap())
            addon.layout_condition_operatorwidget_help(frame, L["Runes"], L["Runes"],
                    "The number of runes currently available.")
        end
    })

    addon:RegisterCondition("RUNE_COOLDOWN", {
        description = L["Rune Cooldown"],
        icon = "Interface\\Icons\\spell_deathknight_empowerruneblade2",
        valid = function(_, value)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    value.value ~= nil and value.value >= 0 and
                    value.rune ~= nil and isin(runes, value.rune))
        end,
        evaluate = function(value, cache)
            local points = 0
            local now = GetTime()
            local lowest_remain
            for i=1,6 do
                if getCached(cache, GetRuneType, i) == value.rune then
                    local start, duration = getCached(cache, GetRuneCooldown, i)
                    local remain = math.max(round(duration - (now - start), 3), 0)
                    if lowest_remain == nil or remain < lowest_remain then
                        lowest_remain = remain
                    end
                end
            end
            return compare(value.operator, lowest_remain, value.value)
        end,
        print = function(_, value)
            local rune_type = value.rune and addon.runes[value.rune] or L["<rune type>"]
            return string.format(L["the %s"],
                    compareString(value.operator, string.format(L["cooldown on %s rune"], rune_type),
                    string.format(L["%s seconds"], nullable(value.value))))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local rune = AceGUI:Create("Dropdown")
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
            frame:AddChild(Gap())
            frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Rune Type"] .. color.RESET .. " - " ..
                    "Which type of runes you wish to check."))
            frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Blood"] .. color.RESET)))
            frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Unholy"] .. color.RESET)))
            frame:AddChild(Indent(40, CreateText(color.GREEN .. L["Frost"] .. color.RESET)))
            frame:AddChild(Gap())
            addon.layout_condition_operatorwidget_help(frame, L["Rune Cooldown"], L["Seconds"],
                    "The number of seconds until a " .. color.BLIZ_YELLOW .. L["Rune Type"] .. color.RESET ..
                    " rune becomes available.")
        end
    })
end

addon:RegisterCondition("TT_HEALTH", {
    description = L["Time Until Health"],
    icon = "Interface\\Icons\\inv_potion_21",
    valid = function(_, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and
                value.health ~= nil and type(value.health) == "number")
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        local target = getCached(cache, UnitGUID, value.unit)
        if target then
            local health = getCached(cache, UnitHealth, value.unit)

            local target_health = value.health
            if value.value < 0 then
                local max = getCached(cache, UnitHealthMax, value.unit)
                target_health = target_health + max
            end
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
    print = function(_, value)
        local conditionstr
        if value.health ~= nil and value.health < 0 then
            conditionstr = string.format(L["time until %s is at %s health defecit"],
                    nullable(value.unit, L["<unit>"]), -value.health)
        else
            conditionstr = string.format(L["time until %s is at %s health"],
                    nullable(value.unit, L["<unit>"]), nullable(value.health))
        end
        return string.format(L["%s with %s"],
            compareString(value.operator, conditionstr,
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
        health:SetCallback("OnEnterPressed", function(_, _, v)
            value.health = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(health)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local mode = AceGUI:Create("Dropdown")
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
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Health"] .. color.RESET .. " - " ..
                "The target health the rule is waiting for " .. color.BLIZ_YELLOW .. L["Unit"] ..
                color.RESET .. " to get to. " ..
                "If this number is negative, it means the health deficit (from max health)."))
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

addon:RegisterCondition("TT_HEALTHPCT", {
    description = L["Time Until Health Percentage"],
    icon = "Interface\\Icons\\inv_potion_24",
    valid = function(_, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and
                value.health ~= nil and value.health >= 0.00 and value.health <= 1.00)
    end,
    evaluate = function(value, cache)
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
    print = function(_, value)
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
        health:SetCallback("OnValueChanged", function(_, _, v)
            value.health = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(health)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local mode = AceGUI:Create("Dropdown")
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