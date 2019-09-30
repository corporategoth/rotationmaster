local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color = color

-- From constants
local units, unitsPossessive, operators = addon.units, addon.unitsPossessive, addon.operators

-- From utils
local compare, compareString, nullable, keys, isin, isint, getCached, playerize, deepcopy =
    addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.isint, addon.getCached, addon.playerize, addon.deepcopy

local helpers = addon.help_funcs
local Gap = helpers.Gap

addon:RegisterCondition(L["Combat"], "CASTING", {
    description = L["Casting"],
    icon = "Interface\\Icons\\Spell_holy_holynova",
    valid = function(spec, value)
        return value.unit ~= nil and isin(units, value.unit)
    end,
    evaluate = function(value, cache, evalStart)
        local name = getCached(cache, UnitCastingInfo, value.unit)
        return name ~= nil
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s are currently casting"], L["%s is currently casting"]),
            nullable(units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})

addon:RegisterCondition(L["Combat"], "CASTING_SPELL", {
    description = L["Specific Spell Casting"],
    icon = "Interface\\Icons\\Spell_holy_spellwarding",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache, evalStart)
        local name = getCached(cache, UnitCastingInfo, value.unit)
        return name == value.spell
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s are currently casting %s"], L["%s is currently casting %s"]),
            nullable(units[value.unit], L["<unit>"]), nullable(value.spell, L["<spell>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local spell_group = addon:Widget_SpellNameWidget(spec, "Spell_EditBox", value,
            function(v) return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_spellnamewidget_help(frame)
    end
})

addon:RegisterCondition(L["Combat"], "CASTING_REMAIN", {
    description = L["Cast Time Remaining"],
    icon = "Interface\\Icons\\Inv_misc_pocketwatch_02",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        local name, _, _, _, endTimeMS = getCached(cache, UnitCastingInfo, value.unit)
        if name ~= nil then
            return compare(value.operator, endTimeMS - (GetTime()*1000), value.value)
        end
        return false
    end,
    print = function(spec, value)
        return nullable(unitsPossessive[value.unit], L["<unit>"]) ..
            compareString(value.operator, L["time remaining on spell cast"], string.format(L["%s seconds"], nullable(value.value)))
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
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Cast Time Remaining"], L["Seconds"],
            "The number of seconds before the current spell being cast by " .. color.BLIZ_YELLOW .. L["Unit"] ..
            color.RESET .. " is complete.  If the " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " is " ..
            "not currently casting, this condition will not be successful (regardless of the " ..
            color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
    end
})

addon:RegisterCondition(L["Combat"], "CAST_INTERRUPTABLE", {
    description = L["Cast Interruptable"],
    icon = "Interface\\Icons\\Spell_shadow_curseofachimonde",
    valid = function(spec, value)
        return value.unit ~= nil and isin(units, value.unit)
    end,
    evaluate = function(value, cache, evalStart)
        local name, _, _, _, _, _, _, notInterruptible = getCached(cache, UnitCastingInfo, value.unit)
        return name ~= nil and not notInterruptible
    end,
    print = function(spec, value)
        return string.format(L["%s's spell is interruptable"], nullable(units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})
