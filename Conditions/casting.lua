local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Canonical callback leaves preserve the repaired observation contract and
-- the original filtered unit choices, wording and validation semantics.
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString,playerize=addon.Functions.presentation.playerize},
    cache={getCached=addon.Functions.cache.getCached},
    collections={deepcopy=addon.Functions.collections.deepcopy},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/casting.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.presentation.playerize"]="builtin:utils.lua:playerize",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.collections.deepcopy"]="builtin:Functions/collections.lua:deepcopy",
}

addon:RegisterCondition("CASTING", {
    description = L["Casting"],
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\casting",
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit)
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"cast")
        if not record then return nil,reason end
        if not record.active then return false end
        return true
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} currently casting"], L["%s {{!is|is not}} currently casting"]),
            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
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
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\casting",
    fields = { unit = "string", spell = "string" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"cast")
        if not record then return nil,reason end
        if not record.active then return false end
        return record.name==value.spell
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} currently casting %s"], L["%s {{!is|is not}} currently casting %s"]),
            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]), Functions.presentation.nullable(value.spell, L["<spell>"]))
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
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\time",
    fields = { unit = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"cast")
        if not record then return nil,reason end
        if not record.active then return false end
        if record.remainingSeconds==nil then return nil,record.remainingReason end
        return Functions.values.compare(value.operator,record.remainingSeconds,value.value)
    end,
    print = function(_, value)
        return Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]) .. " " ..
            Functions.presentation.compareString(value.operator, L["time remaining on spell cast"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
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
    icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\casting",
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit)
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"cast")
        if not record then return nil,reason end
        if not record.active then return false end
        if record.interruptible==nil then return nil,record.interruptibleReason end
        return record.interruptible
    end,
    print = function(_, value)
        return string.format(L["%s's spell {{!is|is not}} interruptable"], Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/casting.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/casting.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
