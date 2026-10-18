local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs

addon:RegisterCondition("BUFF", {
    requiredFields = {"unit","spell"},
    description = L["Buff Present"],
    icon = "Interface\\Icons\\spell_holy_divinespirit",
    fields = { unit = "string", spell = {"string", "number"}, anyrank = "boolean", ownbuff = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "present")
    end,
    print = function(_, value)
        return string.format(addon.playerize(value.unit, L["%s have %s"], L["%s has %s"]),
                addon.nullable(addon.units[value.unit], L["<unit>"]),
                string.format(value.ownbuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<buff>"])))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function()
                    top:SetStatusText(funcs:print(root, spec))
                end)
        parent:AddChild(unit)

        local ownbuff = addon:CreateConditionCheckBox()
        ownbuff:SetWidth(100)
        ownbuff:SetLabel(L["Own Buff"])
        ownbuff:SetValue(value.ownbuff and true or false)
        ownbuff:SetCallback("OnValueChanged", function(_, _, v)
            value.ownbuff = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(ownbuff)

        local spell_group = addon:Widget_SpellNameWidget(spec, "Spell_EditBox", value,
                function()
                    return true
                end,
                function()
                    top:SetStatusText(funcs:print(root, spec))
                end,true)
        parent:AddChild(spell_group)
        parent:AddChild(addon:Widget_AuraRankWidget(value,function() top:SetStatusText(funcs:print(root,spec)) end))
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Own Buff"] .. color.RESET .. " - " ..
                L["Only consider auras that you applied yourself."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        addon.layout_condition_aurarank_help(frame)
    end
})

addon:RegisterCondition("BUFF_REMAIN", {
    description = L["Buff Time Remaining"],
    icon = "Interface\\Icons\\Spell_frost_stun",
    fields = { unit = "string", spell = {"string", "number"}, anyrank = "boolean", ownbuff = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "remaining")
    end,
    print = function(_, value)
        return string.format(addon.playerize(value.unit, L["%s have %s where %s"], L["%s have %s where %s"]),
            addon.nullable(addon.units[value.unit], L["<unit>"]),
                string.format(value.ownbuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<buff>"])),
                addon.compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], addon.nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local ownbuff = addon:CreateConditionCheckBox()
        ownbuff:SetWidth(100)
        ownbuff:SetLabel(L["Own Buff"])
        ownbuff:SetValue(value.ownbuff and true or false)
        ownbuff:SetCallback("OnValueChanged", function(_, _, v)
            value.ownbuff = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(ownbuff)

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
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Own Buff"] .. color.RESET .. " - " ..
                L["Only consider auras that you applied yourself."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        addon.layout_condition_aurarank_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Buff Time Remaining"], L["Seconds"],
            L["Remaining aura time is measured in seconds. Permanent auras have no expiration and do not satisfy a finite refresh threshold. An absent aura does not satisfy this condition. Restricted or unknown timing is unavailable, including under NOT."])
    end
})

addon:RegisterCondition("BUFF_STACKS", {
    description = L["Buff Stacks"],
    icon = "Interface\\Icons\\Inv_misc_coin_02",
    fields = { unit = "string", spell = {"string", "number"}, anyrank = "boolean", ownbuff = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "stacks")
    end,
    print = function(_, value)
        return addon.nullable(addon.unitsPossessive[value.unit], L["<unit>"]) .. " " ..
                addon.compareString(value.operator, string.format(L["stacks of %s"],
                string.format(value.ownbuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<buff>"]))),
                addon.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local ownbuff = addon:CreateConditionCheckBox()
        ownbuff:SetWidth(100)
        ownbuff:SetLabel(L["Own Buff"])
        ownbuff:SetValue(value.ownbuff and true or false)
        ownbuff:SetCallback("OnValueChanged", function(_, _, v)
            value.ownbuff = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(ownbuff)

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
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Own Buff"] .. color.RESET .. " - " ..
                L["Only consider auras that you applied yourself."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        addon.layout_condition_aurarank_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Buff Stacks"], L["Stacks"],
            L["Compare the application count of a matching aura, including charges such as Earth Shield. An absent aura does not satisfy this condition; an unreadable count is unavailable."])
    end
})

addon:RegisterCondition("STEALABLE", {
    description = L["Has Stealable Buff"],
    icon = "Interface\\Icons\\Inv_weapon_shortblade_22",
    fields = { unit = "string" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit))
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "stealable")
    end,
    print = function(_, value)
        return string.format(L["%s has a stealable buff"], addon.nullable(addon.units[value.unit], L["<unit>"]))
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
