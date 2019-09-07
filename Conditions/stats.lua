local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tostring, tonumber, pairs = tostring, tonumber, pairs
local floor = math.floor

-- From constants
local operators, units, unitsPossessive, classes, roles, debufftypes, zonepvp, instances, totems, points =
    addon.operators, addon.units, addon.unitsPossessive, addon.classes, addon.roles, addon.debufftypes,
    addon.zonepvp, addon.instances, addon.totems, addon.points

-- From utils
local compare, compareString, nullable, keys, tomap, isin, cleanArray, deepcopy, getCached =
    addon.compare, addon.compareString, addon.nullable, addon.keys, addon.tomap,
    addon.isin, addon.cleanArray, addon.deepcopy, addon.getCached

addon:RegisterCondition("HEALTH", {
    description = L["Health"],
    icon = "Interface\\Icons\\inv_potion_36",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        return compare(value.operator, getCached(cache, UnitHealth, value.unit), value.value)
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
})

addon:RegisterCondition("HEALTHPCT", {
    description = L["Health Percentage"],
    icon = "Interface\\Icons\\inv_potion_35",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache, evalStart)
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
})

addon:RegisterCondition("MANA", {
    description = L["Mana"],
    icon = "Interface\\Icons\\inv_potion_71",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
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
})

addon:RegisterCondition("MANAPCT", {
    description = L["Mana Percentage"],
    icon = "Interface\\Icons\\inv_potion_70",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache, evalStart)
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
})

addon:RegisterCondition("POWER", {
    description = L["Power"],
    icon = "Interface\\Icons\\inv_potion_92",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
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
})

addon:RegisterCondition("POWERPCT", {
    description = L["Power Percentage"],
    icon = "Interface\\Icons\\inv_potion_91",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    evaluate = function(value, cache, evalStart)
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
})

addon:RegisterCondition("POINT", {
    description = L["Points"],
    icon = "Interface\\Icons\\Inv_jewelry_amulet_01",
    valid = function(spec, value)
        return (value.operator ~= nil and isin(operators, value.operator) and
                value.unit ~= nil and isin(units, value.unit) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
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
})

