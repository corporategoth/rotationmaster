local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

addon:RegisterCondition("CASTING", {
    description = L["Casting"],
    icon = "Interface\\Icons\\Spell_holy_holynova",
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and addon.isin(addon.units, value.unit)
    end,
    evaluate = function(value, cache)
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        local name = addon.getCached(cache, UnitCastingInfo, value.unit)
        return name ~= nil
    end,
    print = function(_, value)
        return string.format(addon.playerize(value.unit, L["%s are currently casting"], L["%s is currently casting"]),
            addon.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})

addon:RegisterCondition("CASTING_SPELL", {
    description = L["Specific Spell Casting"],
    icon = "Interface\\Icons\\Spell_holy_spellwarding",
    fields = { unit = "string", spell = "string" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache)
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        local name = addon.getCached(cache, UnitCastingInfo, value.unit)
        return name == value.spell
    end,
    print = function(_, value)
        return string.format(addon.playerize(value.unit, L["%s are currently casting %s"], L["%s is currently casting %s"]),
            addon.nullable(addon.units[value.unit], L["<unit>"]), addon.nullable(value.spell, L["<spell>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local spell_group = addon:Widget_SpellNameWidget(spec, "Spell_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
    end
})

addon:RegisterCondition("CASTING_REMAIN", {
    description = L["Cast Time Remaining"],
    icon = "Interface\\Icons\\Inv_misc_pocketwatch_02",
    fields = { unit = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        local name, _, _, _, endTimeMS = addon.getCached(cache, UnitCastingInfo, value.unit)
        if name ~= nil then
            return addon.compare(value.operator, endTimeMS - (GetTime()*1000), value.value)
        end
        return false
    end,
    print = function(_, value)
        return addon.nullable(addon.unitsPossessive[value.unit], L["<unit>"]) .. " " ..
            addon.compareString(value.operator, L["time remaining on spell cast"], string.format(L["%s seconds"], addon.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Cast Time Remaining"], L["Seconds"],
            "The number of seconds before the current spell being cast by " .. color.BLIZ_YELLOW .. L["Unit"] ..
            color.RESET .. " is complete.  If the " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " is " ..
            "not currently casting, this condition will not be successful (regardless of the " ..
            color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
    end
})

addon:RegisterCondition("CAST_INTERRUPTABLE", {
    description = L["Cast Interruptable"],
    icon = "Interface\\Icons\\Spell_shadow_curseofachimonde",
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and addon.isin(addon.units, value.unit)
    end,
    evaluate = function(value, cache)
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        local name, _, _, _, _, _, _, notInterruptible = addon.getCached(cache, UnitCastingInfo, value.unit)
        return name ~= nil and not notInterruptible
    end,
    print = function(_, value)
        return string.format(L["%s's spell is interruptable"], addon.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})
