-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Buff conditions: BUFF (present), BUFF_REMAIN (time left), BUFF_STACKS (application count) and STEALABLE (the unit has
-- a buff that can be stolen). Each is a thin wrapper that hands its saved value to addon:EvaluateAuraCondition
-- (Core/aura_conditions.lua) with the "HELPFUL" filter and a mode; that function scans the unit's auras through
-- Platform adapters and returns nil and a reason when an aura field is hidden (restricted clients, Retail and Forever)
-- or unreadable, so nothing here reads a game value. The debuff counterparts live in Conditions/debuffs.lua, which
-- loads right after this file in the Conditions group of RotationMaster.toc. BUFF is enrolled with the lean engine's
-- condition runtime at the end of the file. The callback bodies are frozen: saved custom conditions bind to their exact
-- text, and the generated block at the end is written by tools/generate_builtin_sources.py.
local addon_name, addon = ...

local runtimeCondition = addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness(
    'Conditions/buffs.lua'
)
    or function(_, definition) return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs

-- Canonical pure leaves; aura observations, spell identity and rank stay owned
-- by the existing aura services and field callbacks.
local AuraLiteral = { phrase = addon.Functions.presentation.phrase }
local AuraSummary = { phrase = addon.Functions.presentation.phrase, predicate = addon.Functions.presentation.predicate }

local Functions = {
    collections = { deepcopy = addon.Functions.collections.deepcopy },
    values = { isin = addon.Functions.values.isin },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
        playerize = addon.Functions.presentation.playerize,
    },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/buffs.lua"] = {
    ["AuraLiteral.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["AuraSummary.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["AuraSummary.predicate"] = "builtin:Functions/presentation.lua:predicate",
    ["Functions.collections.deepcopy"] = "builtin:Functions/collections.lua:deepcopy",
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.presentation.playerize"] = "builtin:utils.lua:playerize",
}

-- ============================================================================
-- Buff on a unit
-- ============================================================================

-- BUFF tests that a unit has a helpful aura matching a spell (any rank unless the rank is pinned), optionally only one
-- you applied. Returns false when the unit does not exist or no aura matches, and nil and a reason when an aura read
-- fails and nothing else matched. Stores unit, spell, anyrank and ownbuff. It is declared pure for the lean engine (see
-- DeclareOwnedConditionRuntime below), hence the witness.
addon:RegisterCondition("BUFF", runtimeCondition('BUFF', {
    requiredFields = { "unit", "spell" },
    description = L["Buff Present"],
    icon = addon.Artwork.condition["BUFF"],
    fields = { unit = "string", spell = { "string", "number" }, anyrank = "boolean", ownbuff = "boolean" },
    -- Valid with a unit from the unit list and a spell.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil)
    end,
    -- Unavailable: the reasons addon:EvaluateAuraCondition returns (missing-api, api-error, restricted-value,
    -- invalid-api-result, an aura read reason, or aura-scan-limit after 256 auras). start is the poll's time.
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "present")
    end,
    -- Summary line for the condition list; "have" for the player, "has" for anyone else.
    print = function(_, value)
        return AuraLiteral.phrase(Functions.presentation.playerize(value.unit, L["{unit} {{!have|do not have}} {aura}"], L["{unit} {{!has|does not have}} {aura}"]), {
            unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            aura = string.format(value.ownbuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<buff>"])),
        })
    end,
    -- Editor: the unit picker, the Own Buff checkbox, the spell name box and the rank choice.
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
    -- Help page: the unit text, Own Buff, then the spell name and rank text.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Own Buff"] .. color.RESET .. " - " ..
                L["Only consider auras that you applied yourself."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        addon.layout_condition_aurarank_help(frame)
    end,
}))

-- BUFF_REMAIN compares the seconds left on a matching buff. Permanent auras have no expiry and an absent aura gives
-- false, so neither satisfies a finite threshold; nil and a reason when the timing is hidden or unreadable. Stores
-- unit, spell, anyrank, ownbuff, operator and value (seconds).
addon:RegisterCondition("BUFF_REMAIN", {
    description = L["Buff Time Remaining"],
    icon = addon.Artwork.condition["BUFF_REMAIN"],
    fields = {
        unit = "string",
        spell = { "string", "number" },
        anyrank = "boolean",
        ownbuff = "boolean",
        operator = "string",
        value = "number",
    },
    -- Valid with a unit, a spell, a listed operator and a non-negative number of seconds.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    -- Unavailable: the reasons addon:EvaluateAuraCondition returns for its "remaining" mode; an aura field that cannot
    -- be read fails at once rather than waiting for another aura to match.
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "remaining")
    end,
    -- Summary line for the condition list; "have" for the player, "has" for anyone else.
    print = function(_, value)
        return AuraSummary.phrase(Functions.presentation.playerize(value.unit, L["{unit} {{!have|do not have}} {aura} where {remaining} {comparison} {duration}"], L["{unit} {{!has|does not have}} {aura} where {remaining} {comparison} {duration}"]), {
            unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            aura = string.format(value.ownbuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<buff>"])),
            remaining = L["the remaining time"],
            comparison = AuraSummary.predicate(value.operator),
            duration = string.format(L["%s seconds"], Functions.presentation.nullable(value.value)),
        })
    end,
    -- Editor: the BUFF controls, then the operator and seconds.
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
    -- Help page: the BUFF text, then the operator text describing permanent, absent and hidden timing.
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
    end,
})

-- BUFF_STACKS compares the application count of a matching buff (charges count too). An absent aura gives false; nil
-- and a reason when the count is hidden or unreadable. Stores unit, spell, anyrank, ownbuff, operator and value (a
-- count).
addon:RegisterCondition("BUFF_STACKS", {
    description = L["Buff Stacks"],
    icon = addon.Artwork.condition["BUFF_STACKS"],
    fields = {
        unit = "string",
        spell = { "string", "number" },
        anyrank = "boolean",
        ownbuff = "boolean",
        operator = "string",
        value = "number",
    },
    -- Valid with a unit, a spell, a listed operator and a non-negative count.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    -- Unavailable: the reasons addon:EvaluateAuraCondition returns for its "stacks" mode.
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "stacks")
    end,
    -- Summary line for the condition list.
    print = function(_, value)
        return AuraSummary.phrase(L["the number of stacks of {aura} on {unit} {comparison} {quantity}"], {
            unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            aura = string.format(value.ownbuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<buff>"])),
            comparison = AuraSummary.predicate(value.operator, true),
            quantity = Functions.presentation.nullable(value.value),
        })
    end,
    -- Editor: the BUFF controls, then the operator and stack count.
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
    -- Help page: the BUFF text, then the operator text describing what counts as a stack.
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
    end,
})

-- ============================================================================
-- Stealable buff
-- ============================================================================

-- STEALABLE tests that a unit has a buff the game marks as stealable. Returns false when the unit does not exist or has
-- none, and nil and a reason when an aura read fails and nothing else matched. Stores unit.
addon:RegisterCondition("STEALABLE", {
    description = L["Has Stealable Buff"],
    icon = addon.Artwork.condition["STEALABLE"],
    fields = { unit = "string" },
    -- Valid with a unit from the unit list.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit))
    end,
    -- Unavailable: the reasons addon:EvaluateAuraCondition returns for its "stealable" mode.
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HELPFUL", "stealable")
    end,
    -- Summary line for the condition list; "have" for the player, "has" for anyone else.
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} a stealable buff"], L["%s {{!has|does not have}} a stealable buff"]), Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    -- Editor: the unit picker, without the player and pet entries.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    -- Help page: the shared unit picker text.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end,
})

-- Source-owned configuration validators and optional notification facts.
-- Enrolls BUFF with the lean engine's condition runtime (Core/condition_runtime.lua), which accepts it only while the
-- registered definition is the untouched one; the descriptor lists the Platform members and native APIs its aura scan
-- may use.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/buffs.lua', {
        BUFF = {
            pure = true,
            fact = 'aura',
            methods = { 'EvaluateAuraCondition' },
            platform = { 'GetAuraByIndex', 'ReadAuraField', 'GetSpellInfo', 'CanReadValue', 'GetClientInfo' },
            namespaces = {
                C_UnitAuras = { 'GetAuraDataByIndex' },
                C_Spell = { 'GetSpellInfo' },
                C_Secrets = { 'HasSecretRestrictions' },
            },
            native = {
                'UnitExists',
                'UnitAura',
                'C_UnitAuras',
                'C_Spell',
                'GetSpellInfo',
                'issecretvalue',
                'canaccessvalue',
                'C_Secrets',
            },
        },
    })
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
