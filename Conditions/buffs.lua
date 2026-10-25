local addon_name, addon = ...
local runtimeCondition=addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness('Conditions/buffs.lua') or function(_,definition)return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs

-- Canonical pure leaves; aura observations, spell identity and rank stay owned
-- by the existing aura services and field callbacks.
local AuraLiteral={phrase=addon.Functions.presentation.phrase}
local AuraSummary={phrase=addon.Functions.presentation.phrase,predicate=addon.Functions.presentation.predicate}
local Functions={
    collections={deepcopy=addon.Functions.collections.deepcopy},
    values={isin=addon.Functions.values.isin},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString,playerize=addon.Functions.presentation.playerize},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/buffs.lua"]={
    ["AuraLiteral.phrase"]="builtin:Functions/presentation.lua:phrase",
    ["AuraSummary.phrase"]="builtin:Functions/presentation.lua:phrase",
    ["AuraSummary.predicate"]="builtin:Functions/presentation.lua:predicate",
    ["Functions.collections.deepcopy"]="builtin:Functions/collections.lua:deepcopy",
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.presentation.playerize"]="builtin:utils.lua:playerize",
}

addon:RegisterCondition("BUFF", runtimeCondition('BUFF',{
    requiredFields = {"unit","spell"},
    description = L["Buff Present"],
    icon = addon.Artwork.condition["BUFF"],
    fields = { unit = "string", spell = {"string", "number"}, anyrank = "boolean", ownbuff = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "present")
    end,
    print = function(_, value)
        return AuraLiteral.phrase(Functions.presentation.playerize(value.unit, L["{unit} {{!have|do not have}} {aura}"], L["{unit} {{!has|does not have}} {aura}"]), {
            unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            aura = string.format(value.ownbuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<buff>"])),
        })
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
}))

addon:RegisterCondition("BUFF_REMAIN", {
    description = L["Buff Time Remaining"],
    icon = addon.Artwork.condition["BUFF_REMAIN"],
    fields = { unit = "string", spell = {"string", "number"}, anyrank = "boolean", ownbuff = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "remaining")
    end,
    print = function(_, value)
        return AuraSummary.phrase(Functions.presentation.playerize(value.unit, L["{unit} {{!have|do not have}} {aura} where {remaining} {comparison} {duration}"], L["{unit} {{!has|does not have}} {aura} where {remaining} {comparison} {duration}"]), {
            unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            aura = string.format(value.ownbuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<buff>"])),
            remaining = L["the remaining time"],
            comparison = AuraSummary.predicate(value.operator),
            duration = string.format(L["%s seconds"], Functions.presentation.nullable(value.value)),
        })
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
    icon = addon.Artwork.condition["BUFF_STACKS"],
    fields = { unit = "string", spell = {"string", "number"}, anyrank = "boolean", ownbuff = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "stacks")
    end,
    print = function(_, value)
        return AuraSummary.phrase(L["the number of stacks of {aura} on {unit} {comparison} {quantity}"], {
            unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            aura = string.format(value.ownbuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<buff>"])),
            comparison = AuraSummary.predicate(value.operator, true),
            quantity = Functions.presentation.nullable(value.value),
        })
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
    icon = addon.Artwork.condition["STEALABLE"],
    fields = { unit = "string" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit))
    end,
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "stealable")
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} a stealable buff"], L["%s {{!has|does not have}} a stealable buff"]), Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
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

-- Source-owned configuration validators and optional notification facts.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/buffs.lua',{ BUFF={pure=true,fact='aura',methods={'EvaluateAuraCondition'},platform={'GetAuraByIndex','ReadAuraField','GetSpellInfo','CanReadValue','GetClientInfo'},namespaces={C_UnitAuras={'GetAuraDataByIndex'},C_Spell={'GetSpellInfo'},C_Secrets={'HasSecretRestrictions'}},native={'UnitExists','UnitAura','C_UnitAuras','C_Spell','GetSpellInfo','issecretvalue','canaccessvalue','C_Secrets'}} })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/buffs.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/buffs.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
