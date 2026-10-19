local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Canonical pure leaves; aura observations, spell identity and rank stay owned
-- by the existing aura services and field callbacks.
local Functions={
    collections={keys=addon.Functions.collections.keys},
    values={isin=addon.Functions.values.isin},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString,playerize=addon.Functions.presentation.playerize},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/debuffs.lua"]={
    ["Functions.collections.keys"]="builtin:Functions/collections.lua:keys",
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.presentation.playerize"]="builtin:utils.lua:playerize",
}

addon:RegisterCondition("DEBUFF", {
    description = L["Debuff Present"],
    icon = addon.Artwork.condition["DEBUFF"],
    fields = { unit = "string", spell = {"string", "number"}, anyrank = "boolean", owndebuff = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HARMFUL", "present")
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} %s"], L["%s {{!has|does not have}} %s"]),
            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            string.format(value.owndebuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<debuff>"])))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local owndebuff = addon:CreateConditionCheckBox()
        owndebuff:SetWidth(100)
        owndebuff:SetLabel(L["Own Debuff"])
        owndebuff:SetValue(value.owndebuff and true or false)
        owndebuff:SetCallback("OnValueChanged", function(_, _, v)
            value.owndebuff = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(owndebuff)

        local spell_group = addon:Widget_SpellNameWidget(spec, "Spell_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end,true)
        parent:AddChild(spell_group)
        parent:AddChild(addon:Widget_AuraRankWidget(value,function() top:SetStatusText(funcs:print(root,spec)) end))
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Own Debuff"] .. color.RESET .. " - " ..
                L["Only consider auras that you applied yourself."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        addon.layout_condition_aurarank_help(frame)
    end
})

addon:RegisterCondition("DEBUFF_REMAIN", {
    description = L["Debuff Time Remaining"],
    icon = addon.Artwork.condition["DEBUFF_REMAIN"],
    fields = { unit = "string", spell = {"string", "number"}, anyrank = "boolean", owndebuff = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HARMFUL", "remaining")
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} %s where %s"], L["%s {{!have|do not have}} %s where %s"]),
            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            string.format(value.owndebuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<debuff>"])),
            Functions.presentation.compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local owndebuff = addon:CreateConditionCheckBox()
        owndebuff:SetWidth(100)
        owndebuff:SetLabel(L["Own Debuff"])
        owndebuff:SetValue(value.owndebuff and true or false)
        owndebuff:SetCallback("OnValueChanged", function(_, _, v)
            value.owndebuff = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(owndebuff)

        local spell_group = addon:Widget_SpellNameWidget(spec, "Spell_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end,true)
        parent:AddChild(spell_group)
        parent:AddChild(addon:Widget_AuraRankWidget(value,function() top:SetStatusText(funcs:print(root,spec)) end))

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Own Debuff"] .. color.RESET .. " - " ..
                L["Only consider auras that you applied yourself."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        addon.layout_condition_aurarank_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Debuff Time Remaining"], L["Seconds"],
            L["Remaining aura time is measured in seconds. Permanent auras have no expiration and do not satisfy a finite refresh threshold. An absent aura does not satisfy this condition. Restricted or unknown timing is unavailable, including under NOT."])
    end
})

addon:RegisterCondition("DEBUFF_STACKS", {
    description = L["Debuff Stacks"],
    icon = addon.Artwork.condition["DEBUFF_STACKS"],
    fields = { unit = "string", spell = {"string", "number"}, anyrank = "boolean", owndebuff = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HARMFUL", "stacks")
    end,
    print = function(_, value)
        return Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]) .. " " ..
                Functions.presentation.compareString(value.operator, string.format(L["stacks of %s"],
                string.format(value.owndebuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<debuff>"]))),
                Functions.presentation.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local owndebuff = addon:CreateConditionCheckBox()
        owndebuff:SetWidth(100)
        owndebuff:SetLabel(L["Own Debuff"])
        owndebuff:SetValue(value.owndebuff and true or false)
        owndebuff:SetCallback("OnValueChanged", function(_, _, v)
            value.owndebuff = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(owndebuff)

        local spell_group = addon:Widget_SpellNameWidget(spec, "Spell_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end,true)
        parent:AddChild(spell_group)
        parent:AddChild(addon:Widget_AuraRankWidget(value,function() top:SetStatusText(funcs:print(root,spec)) end))

        local operator_group = addon:Widget_OperatorWidget(value, L["Stacks"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Own Debuff"] .. color.RESET .. " - " ..
                L["Only consider auras that you applied yourself."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        addon.layout_condition_aurarank_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Debuff Stacks"], L["Stacks"],
            L["Compare the application count of a matching aura, including charges such as Earth Shield. An absent aura does not satisfy this condition; an unreadable count is unavailable."])
    end
})

addon:RegisterCondition("DISPELLABLE", {
    description = L["Debuff Type Present"],
    icon = addon.Artwork.condition["DISPELLABLE"],
    fields = { unit = "string", debufftype = "string", owndebuff = "boolean", dispellable = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.debufftype ~= nil and Functions.values.isin(addon.debufftypes, value.debufftype))
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HARMFUL", "dispel")
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} a %s debuff"], L["%s {{!has|does not have}} a %s debuff"]),
            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            string.format(value.owndebuff and L["your own %s"] or "%s", Functions.presentation.nullable(addon.debufftypes[value.debufftype], L["<debuff type>"]))) ..
            (value.dispellable and " " .. L["that is dispellable"] or "")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local debufftype = addon:CreateConditionDropdown()
        debufftype:SetLabel(L["Debuff Type"])
        debufftype:SetCallback("OnValueChanged", function(_, _, v)
            value.debufftype = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        debufftype.configure = function()
            debufftype:SetList(addon.debufftypes, Functions.collections.keys(addon.debufftypes))
            debufftype:SetValue(value.debufftype)
        end
        parent:AddChild(debufftype)

        local owndebuff = addon:CreateConditionCheckBox()
        owndebuff:SetWidth(100)
        owndebuff:SetLabel(L["Own Debuff"])
        owndebuff:SetValue(value.owndebuff and true or false)
        owndebuff:SetCallback("OnValueChanged", function(_, _, v)
            value.owndebuff = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(owndebuff)

        local dispellable = addon:CreateConditionCheckBox()
        dispellable:SetWidth(100)
        dispellable:SetLabel(L["Dispellable"])
        dispellable:SetValue(value.dispellable and true or false)
        dispellable:SetCallback("OnValueChanged", function(_, _, v)
            value.dispellable = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(dispellable)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Debuff Type"] .. color.RESET .. " - " ..
            "The type of debuff that is on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. "."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Own Debuff"] .. color.RESET .. " - " ..
                L["Only consider auras that you applied yourself."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Dispellable"] .. color.RESET .. " - " ..
                L["Only consider debuffs returned by the game's dispellable aura filter. This does not guarantee your dispel is ready or in range."]))
    end
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/debuffs.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/debuffs.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
