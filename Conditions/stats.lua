-- Built In conditions on unit statistics: HEALTH, HEALTHPCT, MANA, MANAPCT, POWER, POWERPCT, POINT, RUNE,
-- RUNE_COOLDOWN, TT_HEALTH and TT_HEALTHPCT. Values come from addon.Platform observation readers and the forecast and
-- point services in Core/. A negative absolute value means "deficit from maximum"; percentage values are saved as
-- fractions from 0 to 1. Restricted clients (Retail, Forever): health, mana and power are secret while restrictions
-- apply, so Core/condition_support.lua declares those conditions unsupported there (docs/restricted-clients.md); any
-- value that still reaches a callback passes platform:CanReadValue first. Loaded from RotationMaster.toc after
-- Conditions/specialization.lua and before Conditions/ext_stats.lua. Callback bodies are recorded by
-- tools/generate_builtin_sources.py and saved copies bind to their exact text.
local addon_name, addon = ...

-- ============================================================================
-- Shared setup
-- ============================================================================

-- Records each definition with the lean-engine witness when Core/condition_runtime.lua is loaded, so the declaration at
-- the end of the file can prove it was not replaced; otherwise it passes the definition through unchanged.
local runtimeCondition = addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness(
    'Conditions/stats.lua'
)
    or function(_, definition) return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color, tonumber = color, tonumber
local helpers = addon.help_funcs

-- Canonical callback leaves preserve the native observations, resource keys,
-- arithmetic and cache lifetimes of these existing statistic predicates.
local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    cache = { getCached = addon.Functions.cache.getCached },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
    },
}

-- Declares the stable Built In identity of each leaf above so saved copies and the source collector can resolve it.
addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/stats.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
}

-- ============================================================================
-- Health
-- ============================================================================

-- HEALTH: compares the unit's current health with the saved amount; a negative amount compares the deficit (maximum
-- minus current) with its absolute value instead. False when the unit does not exist. Returns nil and a reason when the
-- health cannot be read. Stores unit, operator and value.
addon:RegisterCondition("HEALTH", {
    description = L["Health"],
    icon = addon.Artwork.condition["HEALTH"],
    fields = { unit = "string", operator = "string", value = "number" },
    -- Checks that the saved fields of the HEALTH condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Configuration check: a known operator, a selectable unit and a number.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil)
    end,
    -- Compares the unit's current health with the configured amount; a negative amount compares the deficit from
    -- maximum health instead.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Reads health once per poll through the evaluation cache; the maximum is requested only for a deficit.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitHealthObservation,addon.Platform,value.unit,value.value<0)
        if not record then return nil,reason end
        if not record.exists then return false end
        if value.value < 0 then
            return Functions.values.compare(value.operator, (record.maximum-record.current), -value.value)
        else
            return Functions.values.compare(value.operator, record.current, value.value)
        end
    end,
    -- Builds the readable rule summary for the HEALTH condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Rule summary, worded as a deficit when the saved amount is negative.
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s health deficit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), -value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s health"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    end,
    -- Builds the editor controls for the HEALTH condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor controls: the unit selector and the comparison with the health amount.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Health"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the HEALTH condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the unit, then the health amount and the deficit convention.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health"], L["Health"],
            "The raw health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
            "If this number is negative, it means the health deficit (from max health).")
    end,
})

-- HEALTHPCT: compares the unit's health as a percentage of its maximum with the saved fraction (0 to 1, compared as
-- percent). False when the unit does not exist. Returns nil and a reason when health cannot be read, the maximum is not
-- positive ("invalid-health-maximum") or the percentage is not finite. Stores unit, operator and value.
addon:RegisterCondition("HEALTHPCT", runtimeCondition('HEALTHPCT', {
    description = L["Health Percentage"],
    icon = addon.Artwork.condition["HEALTHPCT"],
    fields = { unit = "string", operator = "string", value = "number" },
    -- Checks that the saved fields of the HEALTHPCT condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Configuration check: a known operator, a selectable unit and a fraction from 0 to 1.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    -- Compares the unit's health as a percentage of its maximum with the configured fraction; false when the unit does
    -- not exist.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Reads current and maximum health once per poll through the evaluation cache.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitHealthObservation,addon.Platform,value.unit,true)
        if not record then return nil,reason end
        if not record.exists then return false end
        if record.maximum<=0 then return nil,"invalid-health-maximum" end
        local health = record.current / record.maximum * 100
        if health~=health or health==math.huge or health==-math.huge then return nil,"invalid-health-percentage" end
        return Functions.values.compare(value.operator, health, value.value * 100)
    end,
    -- Builds the readable rule summary for the HEALTHPCT condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Rule summary with the fraction shown as a percentage.
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return Functions.presentation.compareString(value.operator, string.format(L["%s health"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(v) .. "%")
    end,
    -- Builds the editor controls for the HEALTHPCT condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor controls: the unit selector and the comparison with a health percentage.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Health"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the HEALTHPCT condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the unit, then the health percentage.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Health Percentage"], L["Health"],
            "The health value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
            "total health.")
    end,
}))

-- ============================================================================
-- Mana and power
-- ============================================================================

-- MANA: compares the unit's current mana with the saved amount; a negative amount compares the deficit (maximum minus
-- current) with its absolute value instead. Mana is read explicitly, whatever power bar the unit shows. False when the
-- unit does not exist. Returns nil and a reason when mana cannot be read. Stores unit, operator and value.
addon:RegisterCondition("MANA", {
    description = L["Mana"],
    icon = addon.Artwork.condition["MANA"],
    fields = { unit = "string", operator = "string", value = "number" },
    -- Checks that the saved fields of the MANA condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Configuration check: a known operator, a selectable unit and a number.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil)
    end,
    -- Compares the unit's current mana with the configured amount; a negative amount compares the deficit from maximum
    -- mana instead.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Reads mana once per poll through the evaluation cache; the maximum is requested only for a deficit.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitPowerObservation,addon.Platform,value.unit,"mana",value.value<0)
        if not record then return nil,reason end
        if not record.exists then return false end
        if value.value < 0 then
            return Functions.values.compare(value.operator, (record.maximum-record.current), -value.value)
        else
            return Functions.values.compare(value.operator, record.current, value.value)
        end
    end,
    -- Builds the readable rule summary for the MANA condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Rule summary, worded as a deficit when the saved amount is negative.
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s mana deficit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), -value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s mana"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    end,
    -- Builds the editor controls for the MANA condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor controls: the unit selector and the comparison with the mana amount.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Mana"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the MANA condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the unit, then the mana amount and the deficit convention.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana"], L["Mana"],
            "The raw mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ". " ..
            "If this number is negative, it means the mana deficit (from max mana).")
    end,
})

-- MANAPCT: compares the unit's mana as a percentage of its maximum mana with the saved fraction (0 to 1, compared as
-- percent). False when the unit does not exist. Returns nil and a reason when mana cannot be read, the maximum is not
-- positive ("invalid-power-maximum") or the percentage is not finite. Stores unit, operator and value.
addon:RegisterCondition("MANAPCT", {
    description = L["Mana Percentage"],
    icon = addon.Artwork.condition["MANAPCT"],
    fields = { unit = "string", operator = "string", value = "number" },
    -- Checks that the saved fields of the MANAPCT condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Configuration check: a known operator, a selectable unit and a fraction from 0 to 1.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    -- Compares the unit's mana as a percentage of its maximum mana with the configured fraction; false when the unit
    -- does not exist.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Reads current and maximum mana once per poll through the evaluation cache.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitPowerObservation,addon.Platform,value.unit,"mana",true)
        if not record then return nil,reason end
        if not record.exists then return false end
        if record.maximum<=0 then return nil,"invalid-power-maximum" end
        local percentage = record.current / record.maximum * 100
        if percentage~=percentage or percentage==math.huge or percentage==-math.huge then return nil,"invalid-power-percentage" end
        return Functions.values.compare(value.operator, percentage, value.value * 100)
    end,
    -- Builds the readable rule summary for the MANAPCT condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Rule summary with the fraction shown as a percentage.
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return Functions.presentation.compareString(value.operator, string.format(L["%s mana"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(v) .. "%")
    end,
    -- Builds the editor controls for the MANAPCT condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor controls: the unit selector and the comparison with a mana percentage.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Mana"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the MANAPCT condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the unit, then the mana percentage.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Mana Percentage"], L["Mana"],
            "The mana value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
            "total mana.")
    end,
})

-- POWER: compares the unit's current value of whatever power type it uses (rage, energy, ...) with the saved amount; a
-- negative amount compares the deficit (maximum minus current) with its absolute value instead. False when the unit
-- does not exist. Returns nil and a reason when power cannot be read or the deficit is not finite. Stores unit,
-- operator and value.
addon:RegisterCondition("POWER", {
    description = L["Power"],
    icon = addon.Artwork.condition["POWER"],
    fields = { unit = "string", operator = "string", value = "number" },
    -- Checks that the saved fields of the POWER condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Configuration check: a known operator, a selectable unit and a number.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil)
    end,
    -- Compares the unit's current value of whatever power type it uses with the configured amount; a negative amount
    -- compares the deficit from maximum instead.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Reads power once per poll through the evaluation cache; the maximum is requested only for a deficit.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitPowerObservation,addon.Platform,value.unit,"current",value.value<0)
        if not record then return nil,reason end
        if not record.exists then return false end
        if value.value < 0 then
            local deficit = record.maximum-record.current
            if deficit~=deficit or deficit==math.huge or deficit==-math.huge then return nil,"invalid-power-deficit" end
            return Functions.values.compare(value.operator, deficit, -value.value)
        else
            return Functions.values.compare(value.operator, record.current, value.value)
        end
    end,
    -- Builds the readable rule summary for the POWER condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Rule summary, worded as a deficit when the saved amount is negative.
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s power deficit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), -value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s power"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    end,
    -- Builds the editor controls for the POWER condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor controls: the unit selector and the comparison with the power amount.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Power"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the POWER condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the unit, then the power amount and the deficit convention.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Power"], L["Power"],
            "The raw power value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".  Power is a statistic " ..
            "that is class (and sometimes spec or form) specific (eg. Warriors have Rage). " ..
            "If this number is negative, it means the power deficit (from max power).")
    end,
})

-- POWERPCT: compares the unit's power (of whatever type it uses) as a percentage of its maximum with the saved fraction
-- (0 to 1, compared as percent). False when the unit does not exist. Returns nil and a reason when power cannot be
-- read, the maximum is not positive ("invalid-power-maximum") or the percentage is not finite. Stores unit, operator
-- and value.
addon:RegisterCondition("POWERPCT", {
    description = L["Power Percentage"],
    icon = addon.Artwork.condition["POWERPCT"],
    fields = { unit = "string", operator = "string", value = "number" },
    -- Checks that the saved fields of the POWERPCT condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Configuration check: a known operator, a selectable unit and a fraction from 0 to 1.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00)
    end,
    -- Compares the unit's power, as a percentage of its maximum, with the configured fraction; false when the unit does
    -- not exist.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Reads current and maximum power once per poll through the evaluation cache.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitPowerObservation,addon.Platform,value.unit,"current",true)
        if not record then return nil,reason end
        if not record.exists then return false end
        if record.maximum<=0 then return nil,"invalid-power-maximum" end
        local percentage = record.current / record.maximum * 100
        if percentage~=percentage or percentage==math.huge or percentage==-math.huge then return nil,"invalid-power-percentage" end
        return Functions.values.compare(value.operator, percentage, value.value * 100)
    end,
    -- Builds the readable rule summary for the POWERPCT condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Rule summary with the fraction shown as a percentage.
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return Functions.presentation.compareString(value.operator, string.format(L["%s power"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(v) .. "%")
    end,
    -- Builds the editor controls for the POWERPCT condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor controls: the unit selector and the comparison with a power percentage.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Power"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the POWERPCT condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the unit, then the power percentage.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Power"], L["Power"],
            "The power value of " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " as a percentage of their " ..
            "total power.  Power is a statistic that is class (and sometimes spec or form) specific (eg. Warriors " ..
            "have Rage.)")
    end,
})

-- ============================================================================
-- Class points and runes
-- ============================================================================

-- POINT: compares the unit's points in its class resource (combo points, holy power, arcane charges and so on) with
-- the saved amount; a negative amount compares the deficit (maximum minus current) with its absolute value. Which
-- resource that is comes from addon:GetConditionPointResourceV2 (Core/point_conditions.lua), by edition, class and
-- specialization; the target's combo points are read from the player. False when the unit does not exist. Returns nil
-- and a reason when the resource or its value cannot be read, which on Retail and Forever covers every power type that
-- is not flagged never secret. Stores unit, operator and value.
addon:RegisterCondition("POINT", runtimeCondition('POINT', {
    description = L["Points"],
    icon = addon.Artwork.condition["POINT"],
    fields = { unit = "string", operator = "string", value = "number" },
    -- Checks that the saved fields of the POINT condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Configuration check: a known operator, a selectable unit and a number.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil)
    end,
    -- Compares the unit's points in its class resource (combo points, holy power, arcane charges and so on) with the
    -- configured amount; a negative amount compares the deficit from maximum.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Resolves the resource, then reads its current value (and the maximum for a deficit) through the evaluation cache.
    evaluate = function(value, cache)
        local point,reason,transport=addon:GetConditionPointResourceV2(value.unit,cache)
        if point==nil then return nil,reason end
        if point==false then return false end
        local cur,why
        if transport=="target-combo" then
            cur,why=Functions.cache.getCached(cache,addon.Platform.GetPlayerComboPointObservation,addon.Platform,point,"current")
        else
            cur,why=Functions.cache.getCached(cache,addon.Platform.GetUnitPointPowerObservation,addon.Platform,value.unit,point,"current")
        end
        if cur==nil then return nil,why end
        if value.value < 0 then
            local maximum,maximumReason
            if transport=="target-combo" then
                maximum,maximumReason=Functions.cache.getCached(cache,addon.Platform.GetPlayerComboPointObservation,addon.Platform,point,"maximum")
            else
                maximum,maximumReason=Functions.cache.getCached(cache,addon.Platform.GetUnitPointPowerObservation,addon.Platform,value.unit,point,"maximum")
            end
            if maximum==nil then return nil,maximumReason end
            local deficit=maximum-cur
            if deficit~=deficit or deficit==math.huge or deficit==-math.huge then return nil,"invalid-point-deficit" end
            return Functions.values.compare(value.operator, deficit, -value.value)
        else
            return Functions.values.compare(value.operator, cur, value.value)
        end
    end,
    -- Builds the readable rule summary for the POINT condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Rule summary, worded as a deficit when the saved amount is negative.
    print = function(_, value)
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s point deficit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), -value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s point total"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    end,
    -- Builds the editor controls for the POINT condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor controls: the unit selector and the comparison with the point amount.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Points"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the POINT condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the unit, then the point amount and the deficit convention.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Points"], L["Points"],
            "The number of combo points " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " currently has.  " ..
            "Combo points are a statistic that is class (and sometimes spec or form) specific (eg. Mages have " ..
            "Arcane Charges).  " ..
            "If this number is negative, it means the point deficit (from max points).")
    end,
}))

-- The two rune conditions exist only for a Death Knight on a client that is not Retail (WOW_PROJECT_ID) and is at
-- expansion level 2 or later, so they are not registered anywhere else.
if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
    and LE_EXPANSION_LEVEL_CURRENT >= 2
    and select(2, UnitClass("player")) == "DEATHKNIGHT") then
    -- RUNE: counts the player's six runes of the chosen type that are ready and compares the count with the saved
    -- value (0 to 2). Returns nil and a reason when a rune's type or readiness cannot be read. Stores rune (the rune
    -- type), operator and value.
    addon:RegisterCondition("RUNE", {
        description = L["Runes"],
        icon = addon.Artwork.condition["RUNE"],
        fields = { rune = "number", operator = "string", value = "number" },
        -- Checks that the saved fields of the RUNE condition are complete and in range.
        -- @param _ any  Unused; the current specialization the engine passes.
        -- @param value table  The saved condition fields.
        -- @return boolean  True when the saved fields are complete and in range.
        --
        -- Configuration check: a known operator, a count from 0 to 2 and a known rune type.
        valid = function(_, value)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    value.value ~= nil and value.value >= 0 and value.value <= 2 and
                    value.rune ~= nil and Functions.values.isin(addon.runes, value.rune))
        end,
        -- Compares the number of the player's six runes of the chosen type that are ready with the configured count.
        -- @param value table  The saved condition fields.
        -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
        --     Functions.cache.getCached.
        -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
        -- @return string|nil  The reason code when the first value is nil; nil otherwise.
        --
        -- Reads each rune's type and, for matching runes, its readiness through the evaluation cache.
        evaluate = function(value, cache)
            local count = 0
            for i=1,6 do
                local runeType,reason=Functions.cache.getCached(cache, addon.Platform.GetRuneTypeObservation, addon.Platform, i)
                if runeType==nil then return nil,reason end
                if runeType == value.rune then
                    local observation,why=Functions.cache.getCached(cache, addon.Platform.GetRuneCooldownObservation, addon.Platform, i)
                    if observation==nil then return nil,why end
                    if observation.ready==nil then return nil,observation.readyReason end
                    if observation.ready then count = count + 1 end
                end
            end
            return Functions.values.compare(value.operator, count, value.value)
        end,
        -- Builds the readable rule summary for the RUNE condition.
        -- @param _ any  Unused; the specialization the summary is printed for.
        -- @param value table  The saved condition fields.
        -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
        --
        -- Rule summary naming the rune type, or a placeholder while none is chosen.
        print = function(_, value)
            local rune_type = value.rune and addon.runes[value.rune] or L["<rune type>"]
            return Functions.presentation.compareString(value.operator, string.format(L["the number of %s runes available"], rune_type),
                        Functions.presentation.nullable(value.value))
        end,
        -- Builds the editor controls for the RUNE condition's fields.
        -- @param parent table  The editor group the controls are added to.
        -- @param spec any  The specialization the condition is being edited for.
        -- @param value table  The saved condition fields; the controls edit it in place.
        --
        -- Editor controls: the rune type dropdown and the comparison with the rune count.
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local rune = addon:CreateConditionDropdown()
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
        -- Builds the help page for the RUNE condition.
        -- @param frame table  The help page container that text and example widgets are added to.
        --
        -- Help page: the rune types, then the rune count.
        help = function(frame)
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Rune Type"] .. color.RESET .. " - " ..
                    "Which type of runes you wish to check."))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Blood"] .. color.RESET)))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Unholy"] .. color.RESET)))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Frost"] .. color.RESET)))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Death"] .. color.RESET)))
            frame:AddChild(helpers.Gap())
            addon.layout_condition_operatorwidget_help(frame, L["Runes"], L["Runes"],
                    "The number of runes currently available.")
        end,
    })

    -- RUNE_COOLDOWN: compares the seconds until the next rune of the chosen type is ready (the smallest remaining time
    -- among those runes, rounded to three decimals and never below 0) with the saved value. False when the player has
    -- no rune of that type. Returns nil and a reason when a rune's type, timing or the evaluation time cannot be read,
    -- or a remaining time is not finite. Stores rune (the rune type), operator and value (seconds).
    addon:RegisterCondition("RUNE_COOLDOWN", {
        description = L["Rune Cooldown"],
        icon = addon.Artwork.condition["RUNE_COOLDOWN"],
        fields = { rune = "number", operator = "string", value = "number" },
        -- Checks that the saved fields of the RUNE_COOLDOWN condition are complete and in range.
        -- @param _ any  Unused; the current specialization the engine passes.
        -- @param value table  The saved condition fields.
        -- @return boolean  True when the saved fields are complete and in range.
        --
        -- Configuration check: a known operator, a non-negative number of seconds and a known rune type.
        valid = function(_, value)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    value.value ~= nil and value.value >= 0 and
                    value.rune ~= nil and Functions.values.isin(addon.runes, value.rune))
        end,
        -- Compares the seconds until the next rune of the chosen type is ready with the configured number; false when
        -- the player has no rune of that type.
        -- @param value table  The saved condition fields.
        -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
        --     Functions.cache.getCached.
        -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
        -- @return string|nil  The reason code when the first value is nil; nil otherwise.
        --
        -- Reads each rune's type and, for matching runes, its start and duration through the evaluation cache.
        evaluate = function(value, cache)
            local now,timeReason=addon.Platform:GetRuneEvaluationTime()
            local lowest_remain
            for i=1,6 do
                local runeType,reason=Functions.cache.getCached(cache, addon.Platform.GetRuneTypeObservation, addon.Platform, i)
                if runeType==nil then return nil,reason end
                if runeType == value.rune then
                    if now==nil then return nil,timeReason end
                    local observation,why=Functions.cache.getCached(cache, addon.Platform.GetRuneCooldownObservation, addon.Platform, i)
                    if observation==nil then return nil,why end
                    if observation.start==nil then return nil,observation.startReason end
                    if observation.duration==nil then return nil,observation.durationReason end
                    local remain = observation.duration - (now - observation.start)
                    if remain~=remain or remain>=math.huge or remain<=-math.huge then return nil,'invalid-rune-time' end
                    remain = addon.Functions.values.round(remain, 3)
                    if type(remain)~='number' or remain~=remain or remain>=math.huge or remain<=-math.huge then return nil,'invalid-rune-time' end
                    remain = math.max(remain, 0)
                    if lowest_remain == nil or remain < lowest_remain then
                        lowest_remain = remain
                    end
                end
            end
            if lowest_remain==nil then return false end
            return Functions.values.compare(value.operator, lowest_remain, value.value)
        end,
        -- Builds the readable rule summary for the RUNE_COOLDOWN condition.
        -- @param _ any  Unused; the specialization the summary is printed for.
        -- @param value table  The saved condition fields.
        -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
        --
        -- Rule summary naming the rune type, or a placeholder while none is chosen.
        print = function(_, value)
            local rune_type = value.rune and addon.runes[value.rune] or L["<rune type>"]
            return string.format(L["the %s"],
                    Functions.presentation.compareString(value.operator, string.format(L["cooldown on your next %s rune"], rune_type),
                    string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
        end,
        -- Builds the editor controls for the RUNE_COOLDOWN condition's fields.
        -- @param parent table  The editor group the controls are added to.
        -- @param spec any  The specialization the condition is being edited for.
        -- @param value table  The saved condition fields; the controls edit it in place.
        --
        -- Editor controls: the rune type dropdown and the seconds comparison.
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local rune = addon:CreateConditionDropdown()
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
        -- Builds the help page for the RUNE_COOLDOWN condition.
        -- @param frame table  The help page container that text and example widgets are added to.
        --
        -- Help page: the rune types, then the seconds until a rune is available.
        help = function(frame)
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Rune Type"] .. color.RESET .. " - " ..
                    "Which type of runes you wish to check."))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Blood"] .. color.RESET)))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Unholy"] .. color.RESET)))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Frost"] .. color.RESET)))
            frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Death"] .. color.RESET)))
            frame:AddChild(helpers.Gap())
            addon.layout_condition_operatorwidget_help(frame, L["Rune Cooldown"], L["Seconds"],
                    "The number of seconds until a " .. color.BLIZ_YELLOW .. L["Rune Type"] .. color.RESET ..
                    " rune becomes available.")
        end,
    })
end

-- ============================================================================
-- Time until health
-- ============================================================================

-- TT_HEALTH: compares the estimated seconds until the unit's health reaches the saved amount (negative means that much
-- below maximum) with the saved seconds. The estimate is addon:GetConditionHealthForecast
-- (Core/health_forecast_conditions.lua), from the unit's recent damage and healing history, and mode chooses whether
-- heals count. False when the unit is gone or no estimate exists yet. Returns nil and a reason when a value is secret,
-- not a finite number, or the forecast cannot be read; on Retail and Forever the combat log it needs is unavailable, so
-- Core/condition_support.lua declares it unsupported there. Stores unit, operator, value (seconds), health and mode.
addon:RegisterCondition("TT_HEALTH", {
    description = L["Time Until Health"],
    icon = addon.Artwork.condition["TT_HEALTH"],
    fields = { unit = "string", operator = "string", value = "number", health = "number", mode = "string" },
    -- Checks that the saved fields of the TT_HEALTH condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Configuration check: a known operator, a selectable unit, non-negative seconds and a target health amount.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and
                value.health ~= nil)
    end,
    -- Compares the estimated seconds until the unit's health reaches the configured amount with the configured number
    -- of seconds.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Asks the forecast for the ETA (false means no estimate), then checks it and the threshold before comparing.
    evaluate = function(value, cache)
        local eta,reason=addon:GetConditionHealthForecast(value.unit,value.health,false,value.mode,cache)
        if not addon.Platform:CanReadValue(eta) then return nil,'restricted-value' end
        if eta==nil then return nil,reason end
        if eta==false then return false end
        if type(eta)~='number' or eta~=eta or eta>=math.huge or eta<=-math.huge then return nil,'invalid-health-forecast-eta' end
        local threshold=value.value
        if not addon.Platform:CanReadValue(threshold) then return nil,'restricted-value' end
        if type(threshold)~='number' or threshold~=threshold or threshold>=math.huge or threshold<=-math.huge then return nil,'invalid-health-forecast-threshold' end
        return Functions.values.compare(value.operator,eta,threshold)
    end,
    -- Builds the readable rule summary for the TT_HEALTH condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Rule summary, worded as a deficit for a negative target and ending with the burn-rate mode.
    print = function(_, value)
        local conditionstr
        if value.health ~= nil and value.health < 0 then
            conditionstr = string.format(L["time until %s health deficit reaches %s"],
                    Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]), -value.health)
        else
            conditionstr = string.format(L["time until %s health reaches %s"],
                    Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]), Functions.presentation.nullable(value.health))
        end
        return string.format(L["%s with %s"],
            Functions.presentation.compareString(value.operator, conditionstr,
            string.format(L["%s seconds"], Functions.presentation.nullable(value.value))), addon.trendmode[value.mode or "both"])
    end,
    -- Builds the editor controls for the TT_HEALTH condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor controls: the unit selector, the target health, the seconds comparison and the burn-rate mode.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local health = addon:CreateConditionEditBox()
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

        local mode = addon:CreateConditionDropdown()
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
    -- Builds the help page for the TT_HEALTH condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the unit, the target health, the seconds comparison and the burn-rate modes.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Health"] .. color.RESET .. " - " ..
                "The target health the rule is waiting for " .. color.BLIZ_YELLOW .. L["Unit"] ..
                color.RESET .. " to get to. " ..
                "If this number is negative, it means the health deficit (from max health)."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Time Until Health"], L["Seconds"],
            "How many seconds (estimated) until " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET ..
                " reaches the target health.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "How the burn rate should be calculated, which is used to estimate the time to target health."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Damage and Heals"] .. color.RESET .. " - " ..
                "Both damage and heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored " ..
                "into the 'burn rate' (essentially mitigating damage with heals for a realistic burn rate)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Damage Only"] .. color.RESET .. " - " ..
                "Only damage on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', which will cause some spikes in time-to-target if they are healed.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Heals Only"] .. color.RESET .. " - " ..
                "Only heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', essentially pretending they are not being hit at all.")))
    end,
})

-- TT_HEALTHPCT: like TT_HEALTH, but the target health is a fraction of the unit's maximum health (0 to 1) instead of an
-- amount, so the forecast is asked for a percentage. Same results, unavailable cases and restricted-client support as
-- TT_HEALTH. Stores unit, operator, value (seconds), health (the fraction) and mode.
addon:RegisterCondition("TT_HEALTHPCT", {
    description = L["Time Until Health Percentage"],
    icon = addon.Artwork.condition["TT_HEALTHPCT"],
    fields = { unit = "string", operator = "string", value = "number", health = "number", mode = "string" },
    -- Checks that the saved fields of the TT_HEALTHPCT condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Configuration check: a known operator, a selectable unit, non-negative seconds and a health fraction from 0 to 1.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0.00 and
                value.health ~= nil and value.health >= 0.00 and value.health <= 1.00)
    end,
    -- Compares the estimated seconds until the unit's health reaches the configured fraction of its maximum with the
    -- configured number of seconds.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Asks the forecast for the ETA (false means no estimate), then checks it and the threshold before comparing.
    evaluate = function(value, cache)
        local eta,reason=addon:GetConditionHealthForecast(value.unit,value.health,true,value.mode,cache)
        if not addon.Platform:CanReadValue(eta) then return nil,'restricted-value' end
        if eta==nil then return nil,reason end
        if eta==false then return false end
        if type(eta)~='number' or eta~=eta or eta>=math.huge or eta<=-math.huge then return nil,'invalid-health-forecast-eta' end
        local threshold=value.value
        if not addon.Platform:CanReadValue(threshold) then return nil,'restricted-value' end
        if type(threshold)~='number' or threshold~=threshold or threshold>=math.huge or threshold<=-math.huge then return nil,'invalid-health-forecast-threshold' end
        return Functions.values.compare(value.operator,eta,threshold)
    end,
    -- Builds the readable rule summary for the TT_HEALTHPCT condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Rule summary with the target fraction shown as a percentage, ending with the burn-rate mode.
    print = function(_, value)
        local v = value.health
        if v ~= nil then
            v = v * 100
        end
        return string.format(L["%s with %s"],
            Functions.presentation.compareString(value.operator, string.format(L["time until %s health reaches %s%%"],
                                                           Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]), Functions.presentation.nullable(v)),
                            string.format(L["%s seconds"], Functions.presentation.nullable(value.value))),
                            addon.trendmode[value.mode or "both"])

    end,
    -- Builds the editor controls for the TT_HEALTHPCT condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor controls: the unit selector, a percentage slider for the target health, the seconds comparison and the
    -- burn-rate mode.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local health = addon:CreateConditionSlider()
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

        local mode = addon:CreateConditionDropdown()
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
    -- Builds the help page for the TT_HEALTHPCT condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page: the unit, the target health percentage, the seconds comparison and the burn-rate modes.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Health"] .. color.RESET .. " - " ..
                "The target health the rule is waiting for " .. color.BLIZ_YELLOW .. L["Unit"] ..
                color.RESET .. " to get to as a percentage of their total health."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Time Until Health Percentage"], L["Seconds"],
            "How many seconds (estimated) until " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET ..
                " reaches the target health percentage.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "How the burn rate should be calculated, which is used to estimate the time to target health."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Damage and Heals"] .. color.RESET .. " - " ..
                "Both damage and heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored " ..
                "into the 'burn rate' (essentially mitigating damage with heals for a realistic burn rate)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Damage Only"] .. color.RESET .. " - " ..
                "Only damage on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', which will cause some spikes in time-to-target if they are healed.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Heals Only"] .. color.RESET .. " - " ..
                "Only heals on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " will be factored into the " ..
                "'burn rate', essentially pretending they are not being hit at all.")))
    end,
})

-- ============================================================================
-- Lean-engine declarations
-- ============================================================================

-- Source-owned volatile observations; only configuration-only validators memoize.
-- `pure = true` says the condition's valid callback depends only on the saved fields. Only HEALTHPCT and POINT are
-- declared here, and they are the two registered through runtimeCondition above.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/stats.lua', { HEALTHPCT = { pure = true }, POINT = { pure = true } })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/stats.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/stats.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
