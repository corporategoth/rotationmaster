-- Debuff conditions: DEBUFF (present), DEBUFF_REMAIN (time left), DEBUFF_STACKS (application count) and DISPELLABLE (a
-- debuff of a given type, optionally only a dispellable one). Each is a thin wrapper that hands its saved value to
-- addon:EvaluateAuraCondition (Core/aura_conditions.lua) with the "HARMFUL" filter and a mode; that function scans the
-- unit's auras through Platform adapters and returns nil and a reason when an aura field is hidden (restricted clients,
-- Retail and Forever) or unreadable, so nothing here reads a game value. The buff counterparts live in
-- Conditions/buffs.lua, which loads just before this file in the Conditions group of RotationMaster.toc. The callback
-- bodies are frozen: saved custom conditions bind to their exact text, and the generated block at the end is written
-- by a tool.
local addon_name, addon = ...

local runtimeCondition = addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness(
    'Conditions/debuffs.lua'
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
    collections = { keys = addon.Functions.collections.keys },
    values = { isin = addon.Functions.values.isin },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
        playerize = addon.Functions.presentation.playerize,
    },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/debuffs.lua"] = {
    ["AuraLiteral.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["AuraSummary.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["AuraSummary.predicate"] = "builtin:Functions/presentation.lua:predicate",
    ["Functions.collections.keys"] = "builtin:Functions/collections.lua:keys",
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.presentation.playerize"] = "builtin:utils.lua:playerize",
}

-- ============================================================================
-- Debuff on a unit
-- ============================================================================

-- DEBUFF tests that a unit has a harmful aura matching a spell (any rank unless the rank is pinned), optionally only
-- one you applied. Returns false when the unit does not exist or no aura matches, and nil and a reason when an aura
-- read fails and nothing else matched. Stores unit, spell, anyrank and owndebuff. It is declared pure for the lean
-- engine (see DeclareOwnedConditionRuntime below), hence the witness.
addon:RegisterCondition("DEBUFF", runtimeCondition('DEBUFF', {
    description = L["Debuff Present"],
    icon = addon.Artwork.condition["DEBUFF"],
    fields = { unit = "string", spell = { "string", "number" }, anyrank = "boolean", owndebuff = "boolean" },
    -- Checks that the saved fields of the DEBUFF condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a unit from the unit list and a spell.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil)
    end,
    -- Decides whether the unit has a harmful aura matching the chosen spell, optionally only one you applied.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param start number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: the reasons addon:EvaluateAuraCondition returns (missing-api, api-error, restricted-value,
    -- invalid-api-result, an aura read reason, or aura-scan-limit after 256 auras). start is the poll's time.
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HARMFUL", "present")
    end,
    -- Builds the readable rule summary for the DEBUFF condition.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list; "have" for the player, "has" for anyone else.
    print = function(_, value)
        return AuraLiteral.phrase(Functions.presentation.playerize(value.unit, L["{unit} {{!have|do not have}} {aura}"], L["{unit} {{!has|does not have}} {aura}"]), {
            unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            aura = string.format(value.owndebuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<debuff>"])),
        })
    end,
    -- Builds the editor controls for the DEBUFF condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The current specialization (addon.currentSpec).
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the unit picker, the Own Debuff checkbox, the spell name box and the rank choice.
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
    -- Builds the help page for the DEBUFF condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the unit text, Own Debuff, then the spell name and rank text.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Own Debuff"] .. color.RESET .. " - " ..
                L["Only consider auras that you applied yourself."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        addon.layout_condition_aurarank_help(frame)
    end,
}))

-- DEBUFF_REMAIN compares the seconds left on a matching debuff. Permanent auras have no expiry and an absent aura
-- gives false, so neither satisfies a finite threshold; nil and a reason when the timing is hidden or unreadable.
-- Stores unit, spell, anyrank, owndebuff, operator and value (seconds).
addon:RegisterCondition("DEBUFF_REMAIN", {
    description = L["Debuff Time Remaining"],
    icon = addon.Artwork.condition["DEBUFF_REMAIN"],
    fields = {
        unit = "string",
        spell = { "string", "number" },
        anyrank = "boolean",
        owndebuff = "boolean",
        operator = "string",
        value = "number",
    },
    -- Checks that the saved fields of the DEBUFF_REMAIN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a unit, a spell, a listed operator and a non-negative number of seconds.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    -- Compares the seconds left on a matching harmful aura with the configured number.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param start number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: the reasons addon:EvaluateAuraCondition returns for its "remaining" mode; an aura field that cannot
    -- be read fails at once rather than waiting for another aura to match.
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HARMFUL", "remaining")
    end,
    -- Builds the readable rule summary for the DEBUFF_REMAIN condition.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list; "have" for the player, "has" for anyone else.
    print = function(_, value)
        return AuraSummary.phrase(Functions.presentation.playerize(value.unit, L["{unit} {{!have|do not have}} {aura} where {remaining} {comparison} {duration}"], L["{unit} {{!has|does not have}} {aura} where {remaining} {comparison} {duration}"]), {
            unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            aura = string.format(value.owndebuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<debuff>"])),
            remaining = L["the remaining time"],
            comparison = AuraSummary.predicate(value.operator),
            duration = string.format(L["%s seconds"], Functions.presentation.nullable(value.value)),
        })
    end,
    -- Builds the editor controls for the DEBUFF_REMAIN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The current specialization (addon.currentSpec).
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the DEBUFF controls, then the operator and seconds.
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
    -- Builds the help page for the DEBUFF_REMAIN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the DEBUFF text, then the operator text describing permanent, absent and hidden timing.
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
    end,
})

-- DEBUFF_STACKS compares the application count of a matching debuff (charges count too). An absent aura gives false;
-- nil and a reason when the count is hidden or unreadable. Stores unit, spell, anyrank, owndebuff, operator and value
-- (a count).
addon:RegisterCondition("DEBUFF_STACKS", {
    description = L["Debuff Stacks"],
    icon = addon.Artwork.condition["DEBUFF_STACKS"],
    fields = {
        unit = "string",
        spell = { "string", "number" },
        anyrank = "boolean",
        owndebuff = "boolean",
        operator = "string",
        value = "number",
    },
    -- Checks that the saved fields of the DEBUFF_STACKS condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a unit, a spell, a listed operator and a non-negative count.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    -- Compares the application count of a matching harmful aura with the configured number.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param start number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: the reasons addon:EvaluateAuraCondition returns for its "stacks" mode.
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HARMFUL", "stacks")
    end,
    -- Builds the readable rule summary for the DEBUFF_STACKS condition.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list.
    print = function(_, value)
        return AuraSummary.phrase(L["the number of stacks of {aura} on {unit} {comparison} {quantity}"], {
            unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            aura = string.format(value.owndebuff and L["your own %s"] or "%s", (value.spell and addon:AuraSpellLabel(value) or L["<debuff>"])),
            comparison = AuraSummary.predicate(value.operator, true),
            quantity = Functions.presentation.nullable(value.value),
        })
    end,
    -- Builds the editor controls for the DEBUFF_STACKS condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The current specialization (addon.currentSpec).
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the DEBUFF controls, then the operator and stack count.
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
    -- Builds the help page for the DEBUFF_STACKS condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the DEBUFF text, then the operator text describing what counts as a stack.
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
    end,
})

-- ============================================================================
-- Debuff type
-- ============================================================================

-- DISPELLABLE tests that a unit has a debuff of a given type (Magic, Disease, Poison, Curse, Enrage), optionally one
-- you applied and optionally only one the game's dispellable filter returns. Returns false when none is present, and
-- nil and a reason when an aura read fails and nothing else matched. Stores unit, debufftype, owndebuff and
-- dispellable.
addon:RegisterCondition("DISPELLABLE", {
    description = L["Debuff Type Present"],
    icon = addon.Artwork.condition["DISPELLABLE"],
    fields = { unit = "string", debufftype = "string", owndebuff = "boolean", dispellable = "boolean" },
    -- Checks that the saved fields of the DISPELLABLE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a unit from the unit list and a listed debuff type.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.debufftype ~= nil and Functions.values.isin(addon.debufftypes, value.debufftype))
    end,
    -- Decides whether the unit has a harmful aura of the chosen debuff type, optionally only one you applied or one the
    -- game's dispellable filter returns.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @param start number  The GetTime() reading taken when this evaluation pass began.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable: the reasons addon:EvaluateAuraCondition returns for its "dispel" mode, which switches the filter to
    -- "HARMFUL|RAID" when dispellable is set.
    evaluate = function(value, cache, start)
        return addon:EvaluateAuraCondition(value, cache, start, "HARMFUL", "dispel")
    end,
    -- Builds the readable rule summary for the DISPELLABLE condition.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Summary line for the condition list; "have" for the player, "has" for anyone else.
    print = function(_, value)
        local template
        if value.owndebuff then
            template = Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} a debuff you applied of type %s"], L["%s {{!has|does not have}} a debuff you applied of type %s"])
        else
            template = Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} a debuff of type %s"], L["%s {{!has|does not have}} a debuff of type %s"])
        end
        return string.format(template, Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            Functions.presentation.nullable(addon.debufftypes[value.debufftype], L["<debuff type>"])) ..
            (value.dispellable and " " .. L["that is dispellable"] or "")
    end,
    -- Builds the editor controls for the DISPELLABLE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The current specialization (addon.currentSpec).
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: the unit picker, the debuff type dropdown, and the Own Debuff and Dispellable checkboxes.
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
    -- Builds the help page for the DISPELLABLE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the unit text, then the Debuff Type, Own Debuff and Dispellable options.
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
    end,
})

-- Source-owned volatile observations; only configuration-only validators memoize.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/debuffs.lua', {
        DEBUFF = { pure = true, methods = { 'EvaluateAuraCondition' } },
    })
end

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
