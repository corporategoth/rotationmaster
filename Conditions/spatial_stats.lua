-- Built In conditions that aggregate or count health and mana over the group members near a unit: PROXIMITY_HEALTH,
-- PROXIMITY_HEALTH_COUNT, PROXIMITY_HEALTHPCT, PROXIMITY_HEALTHPCT_COUNT and the four PROXIMITY_MANA* twins. Which
-- members are near the unit comes from addon.proximity_eval and addon.proximity_widgets (Conditions/spatial.lua,
-- loaded earlier); this file only reads each member's health or mana and reduces the numbers. Restricted clients
-- (Retail, Forever): health, and mana unless it is flagged never secret, are secret while restrictions apply, so
-- Core/condition_support.lua declares these conditions unsupported there (docs/restricted-clients.md); any value that
-- is read still passes platform:CanReadValue. Loaded from RotationMaster.toc after Conditions/range.lua and before
-- Conditions/weapon.lua. Callback and helper bodies are recorded by tools/generate_builtin_sources.py and saved copies
-- bind to their exact text.
local addon_name, addon = ...

-- ============================================================================
-- Shared setup
-- ============================================================================

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color, pairs = color, pairs
local helpers = addon.help_funcs

-- BEGIN SPATIAL STATS CALLBACK NAMESPACE
-- Explicit callback leaves; retain native statistic helper closures.
local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        phrase = addon.Functions.presentation.phrase,
        predicate = addon.Functions.presentation.predicate,
    },
    collections = { keys = addon.Functions.collections.keys },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/spatial_stats.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["Functions.presentation.predicate"] = "builtin:Functions/presentation.lua:predicate",
    ["Functions.collections.keys"] = "builtin:Functions/collections.lua:keys",
}

-- END SPATIAL STATS CALLBACK NAMESPACE

-- ============================================================================
-- Shared readers
-- ============================================================================

-- Reads one number for a unit by calling a native statistic API (UnitHealth, UnitHealthMax, UnitPower or UnitPowerMax)
-- through the evaluation cache; `power` true passes the Mana power type. Returns the number, or nil and a reason:
-- "missing-api", "api-error" (the call threw), "restricted-value" (secret) or "statistic-unavailable" (not a finite,
-- non-negative number).
local function observation(cache, method, unit, power)
    if type(method)~="function" then return nil,"missing-api" end
    local ok,current
    if power then ok,current=pcall(addon.getCached,cache,method,unit,Enum.PowerType.Mana)
    else ok,current=pcall(addon.getCached,cache,method,unit) end
    if not ok then return nil,"api-error" end
    if not addon.Platform:CanReadValue(current) then return nil,"restricted-value" end
    if type(current)~="number" or current~=current or current<0 or current==math.huge then return nil,"statistic-unavailable" end
    return current
end

-- Returns the unit's health (its mana when `mana` is true) in the form a condition compares: the current value, or with
-- `percentage` the current value as 0 to 100 of the maximum (which must be positive), or with `deficit` the maximum
-- minus the current value; `percentage` wins when both are set. Returns nil and the reason from observation, or
-- "statistic-unavailable", when a read fails.
local function statistic(cache, unit, mana, percentage, deficit)
    local method=UnitHealth;if mana then method=UnitPower end
    local current,reason=observation(cache,method,unit,mana)
    if current==nil then return nil,reason end
    if percentage or deficit then
        local maximumMethod=UnitHealthMax;if mana then maximumMethod=UnitPowerMax end
        local maximum,why=observation(cache,maximumMethod,unit,mana)
        if maximum==nil then return nil,why end
        if percentage then
            if maximum==0 then return nil,"statistic-unavailable" end
            local percent=current/maximum*100
            if percent~=percent or percent==math.huge then return nil,"statistic-unavailable" end
            return percent
        end
        return maximum-current
    end
    return current
end

-- Reduces the numbers collected for the members in range to one by operation "average", "minimum" or "maximum".
-- Returns nil and "no-units-in-range" for an empty list, "statistic-unavailable" when the sum is not finite, or
-- "invalid-operation" for any other operation.
local function aggregate(values, operation)
    if #values==0 then return nil,"no-units-in-range" end
    local value=values[1]
    if operation=="average" then
        local sum=0;for _,current in ipairs(values) do sum=sum+current end
        if sum==math.huge or sum==-math.huge or sum~=sum then return nil,"statistic-unavailable" end
        return sum/#values
    elseif operation=="minimum" or operation=="maximum" then
        for index=2,#values do
            if operation=="minimum" then value=math.min(value,values[index])
            else value=math.max(value,values[index]) end
        end
        return value
    end
    return nil,"invalid-operation"
end

-- ============================================================================
-- Health within range
-- ============================================================================

-- PROXIMITY_HEALTH: reduces the raw health of the members within `distance` yards of the unit (operation: average,
-- minimum or maximum) and compares the result with the saved amount; a negative amount works on the deficit from
-- maximum health instead. Returns nil and a reason when the scan is incomplete or uncertain, a read fails, or no member
-- is in range ("no-units-in-range"). Stores unit, operation, operator, value, distance, samegroup and includepets.
addon:RegisterCondition("PROXIMITY_HEALTH", {
    description = L["Health Within Range"],
    icon = addon.Artwork.condition["PROXIMITY_HEALTH"],
    fields = {
        unit = "string",
        operation = "string",
        operator = "string",
        value = "number",
        distance = "number",
        samegroup = "boolean",
        includepets = "boolean",
    },
    -- Configuration check: every saved field must be present and in range for this condition.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operation ~= nil and Functions.values.isin(addon.math_operations, value.operation) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and
                value.distance ~= nil and value.distance >= 0)
    end,
    -- Collects one health reading per member in range (addon.proximity_eval drives the scan), aggregates them and
    -- compares. Unavailable if the scan did not complete, any reading failed, or the list is empty.
    evaluate = function(value, cache)
        local values = {}
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,false,false,value.value<0)
            if cur==nil then return nil,why end
            table.insert(values, cur)
        end)
        if not complete then return nil,reason end

        local v,aggregateReason=aggregate(values,value.operation)
        if v==nil then return nil,aggregateReason end
        return Functions.values.compare(value.operator, v, math.abs(value.value))
    end,
    -- Rule summary from a localized phrase; fields that are not yet set show placeholders. A negative amount is worded
    -- as a deficit where the condition accepts one.
    print = function(_, value)
        local threshold = value.value
        local deficit = threshold ~= nil and threshold < 0
        if deficit then threshold = -threshold end
        return Functions.presentation.phrase(
                (deficit and L["The {operation} health deficit of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}"] or
                L["The {operation} health of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}"]),
                {
                    operation = Functions.presentation.nullable(addon.math_operations_prose[value.operation], L["<operation>"]),
                    members = value.samegroup and PARTY or L["Raid or Party"],
                    pets = value.includepets and " (" .. L["including pets"] .. ")" or "",
                    distance = Functions.presentation.nullable(value.distance, L["<distance>"]),
                    unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
                    comparison = Functions.presentation.predicate(value.operator, true),
                    threshold = Functions.presentation.nullable(threshold),
                })
    end,
    -- Editor controls: the unit selector, this condition's own comparison controls, then the shared distance, same
    -- group and include pets controls from addon.proximity_widgets.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = addon:CreateConditionDropdown()
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(addon.math_operations, Functions.collections.keys(addon.math_operations))
            if (value.operation ~= nil) then
                operation:SetValue(value.operation)
            end
        end
        parent:AddChild(operation)

        local operator_group = addon:Widget_OperatorWidget(value, L["Health"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    -- Help page: the unit, this condition's own fields, the shared distance, same group and include pets text, and the
    -- note on when the whole condition is unavailable.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided by the number of values")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health Within Range"], L["Health"],
                "The health value the " .. color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " result is compared with: " ..
                        "the lowest, average or highest health of the allies counted.  " ..
                        "If this number is negative, it compares their health deficit (from max health) instead.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end,
})

-- PROXIMITY_HEALTH_COUNT: counts the members within `distance` yards of the unit whose raw health passes the health
-- comparison (a negative health compares each member's deficit from maximum) and compares that count with the saved
-- count. Returns nil and a reason when the scan is incomplete or uncertain or a read fails; an empty range counts 0.
-- Stores unit, healthoperator, health, operator, value (the count), distance, samegroup and includepets.
addon:RegisterCondition("PROXIMITY_HEALTH_COUNT", {
    description = L["Health Count Within Range"],
    icon = addon.Artwork.condition["PROXIMITY_HEALTH_COUNT"],
    fields = {
        unit = "string",
        healthoperator = "string",
        health = "number",
        operator = "string",
        value = "number",
        distance = "number",
        samegroup = "boolean",
        includepets = "boolean",
    },
    -- Configuration check: every saved field must be present and in range for this condition.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.healthoperator ~= nil and Functions.values.isin(addon.operators, value.healthoperator) and
                value.health ~= nil and type(value.health) == "number" and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    -- Counts members in range whose health passes the health comparison (addon.proximity_eval drives the scan), then
    -- compares the count. Unavailable if the scan did not complete or any reading failed.
    evaluate = function(value, cache)
        local count = 0
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,false,false,value.health<0)
            if cur==nil then return nil,why end
            if Functions.values.compare(value.healthoperator, cur, math.abs(value.health)) then
                count = count + 1
            end
        end)
        if not complete then return nil,reason end

        return Functions.values.compare(value.operator, count, value.value)
    end,
    -- Rule summary from a localized phrase; fields that are not yet set show placeholders. A negative amount is worded
    -- as a deficit where the condition accepts one.
    print = function(_, value)
        local threshold = value.health
        local deficit = threshold ~= nil and threshold < 0
        if deficit then threshold = -threshold end
        return Functions.presentation.phrase(
                (deficit and L["The number of {members} members{pets} within {distance} yards of {unit} whose health deficit {qualifier} {threshold} {comparison} {value}"] or
                L["The number of {members} members{pets} within {distance} yards of {unit} whose health {qualifier} {threshold} {comparison} {value}"]),
                {
                    members = value.samegroup and PARTY or L["Raid or Party"],
                    pets = value.includepets and " (" .. L["including pets"] .. ")" or "",
                    distance = Functions.presentation.nullable(value.distance, L["<distance>"]),
                    unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
                    comparison = Functions.presentation.predicate(value.operator, true),
                    threshold = Functions.presentation.nullable(threshold),
                    qualifier = Functions.presentation.predicate(value.healthoperator),
                    value = Functions.presentation.nullable(value.value),
                })
    end,
    -- Editor controls: the unit selector, this condition's own comparison controls, then the shared distance, same
    -- group and include pets controls from addon.proximity_widgets.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local healthoperator_group = addon:Widget_OperatorWidget(value, L["Health"],
                function() top:SetStatusText(funcs:print(root, spec)) end, "healthoperator", "health")
        parent:AddChild(healthoperator_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    -- Help page: the unit, this condition's own fields, the shared distance, same group and include pets text, and the
    -- note on when the whole condition is unavailable.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health"], L["Health"],
                "The health each ally within " .. color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " of " ..
                        color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " is compared with.  " ..
                        "If this number is negative, it compares each ally's health deficit (from max health) instead.")
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health Count Within Range"], L["Count"],
                "The number of allies within " .. color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " of " ..
                        color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " whose health passes that comparison.  " ..
                        "This only counts allies you are in a party or raid with.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end,
})

-- PROXIMITY_HEALTHPCT: reduces the health percentage of the members within `distance` yards of the unit (operation:
-- average, minimum or maximum) and compares the result with the saved fraction (0 to 1, compared as percent). Returns
-- nil and a reason when the scan is incomplete or uncertain, a read fails, a maximum is not positive, or no member is
-- in range. Stores unit, operation, operator, value, distance, samegroup and includepets.
addon:RegisterCondition("PROXIMITY_HEALTHPCT", {
    description = L["Health Percentage Within Range"],
    icon = addon.Artwork.condition["PROXIMITY_HEALTHPCT"],
    fields = {
        unit = "string",
        operation = "string",
        operator = "string",
        value = "number",
        distance = "number",
        samegroup = "boolean",
        includepets = "boolean",
    },
    -- Configuration check: every saved field must be present and in range for this condition.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operation ~= nil and Functions.values.isin(addon.math_operations, value.operation) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00 and
                value.distance ~= nil and value.distance >= 0)
    end,
    -- Collects one health percentage per member in range (addon.proximity_eval drives the scan), aggregates them and
    -- compares. Unavailable if the scan did not complete, any reading failed, or the list is empty.
    evaluate = function(value, cache)
        local values = {}
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,false,true,false)
            if cur==nil then return nil,why end
            table.insert(values, cur)
        end)
        if not complete then return nil,reason end

        local v,aggregateReason=aggregate(values,value.operation)
        if v==nil then return nil,aggregateReason end
        return Functions.values.compare(value.operator, v, value.value * 100)
    end,
    -- Rule summary from a localized phrase; fields that are not yet set show placeholders. A negative amount is worded
    -- as a deficit where the condition accepts one.
    print = function(_, value)
        local threshold = value.value
        if threshold ~= nil then threshold = threshold * 100 end
        return Functions.presentation.phrase(
                L["The {operation} health percentage of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}%"],
                {
                    operation = Functions.presentation.nullable(addon.math_operations_prose[value.operation], L["<operation>"]),
                    members = value.samegroup and PARTY or L["Raid or Party"],
                    pets = value.includepets and " (" .. L["including pets"] .. ")" or "",
                    distance = Functions.presentation.nullable(value.distance, L["<distance>"]),
                    unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
                    comparison = Functions.presentation.predicate(value.operator, true),
                    threshold = Functions.presentation.nullable(threshold),
                })
    end,
    -- Editor controls: the unit selector, this condition's own comparison controls, then the shared distance, same
    -- group and include pets controls from addon.proximity_widgets.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = addon:CreateConditionDropdown()
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(addon.math_operations, Functions.collections.keys(addon.math_operations))
            if (value.operation ~= nil) then
                operation:SetValue(value.operation)
            end
        end
        parent:AddChild(operation)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Health"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    -- Help page: the unit, this condition's own fields, the shared distance, same group and include pets text, and the
    -- note on when the whole condition is unavailable.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided by the number of values")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health Percentage Within Range"], L["Health"],
                "The health percentage the " .. color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " result is compared with: " ..
                        "the lowest, average or highest health of the allies counted, each as a percentage of their total health.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end,
})

-- PROXIMITY_HEALTHPCT_COUNT: counts the members within `distance` yards of the unit whose health percentage passes the
-- comparison with the saved fraction (0 to 1, compared as percent) and compares that count with the saved count.
-- Returns nil and a reason when the scan is incomplete or uncertain, a read fails or a maximum is not positive; an
-- empty range counts 0. Stores unit, healthoperator, health (the fraction), operator, value (the count), distance,
-- samegroup and includepets.
addon:RegisterCondition("PROXIMITY_HEALTHPCT_COUNT", {
    description = L["Health Percentage Count Within Range"],
    icon = addon.Artwork.condition["PROXIMITY_HEALTHPCT_COUNT"],
    fields = {
        unit = "string",
        healthoperator = "string",
        health = "number",
        operator = "string",
        value = "number",
        distance = "number",
        samegroup = "boolean",
        includepets = "boolean",
    },
    -- Configuration check: every saved field must be present and in range for this condition.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.healthoperator ~= nil and Functions.values.isin(addon.operators, value.healthoperator) and
                value.health ~= nil and value.health >= 0.00 and value.health <= 1.00 and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    -- Counts members in range whose health percentage passes the comparison (addon.proximity_eval drives the scan),
    -- then compares the count. Unavailable if the scan did not complete or any reading failed.
    evaluate = function(value, cache)
        local count = 0
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,false,true,false)
            if cur==nil then return nil,why end
            if Functions.values.compare(value.healthoperator, cur, value.health * 100) then
                count = count + 1
            end
        end)
        if not complete then return nil,reason end
        return Functions.values.compare(value.operator, count, value.value)
    end,
    -- Rule summary from a localized phrase; fields that are not yet set show placeholders. A negative amount is worded
    -- as a deficit where the condition accepts one.
    print = function(_, value)
        local threshold = value.health
        if threshold ~= nil then threshold = threshold * 100 end
        return Functions.presentation.phrase(
                L["The number of {members} members{pets} within {distance} yards of {unit} whose health percentage {qualifier} {threshold}% {comparison} {value}"],
                {
                    members = value.samegroup and PARTY or L["Raid or Party"],
                    pets = value.includepets and " (" .. L["including pets"] .. ")" or "",
                    distance = Functions.presentation.nullable(value.distance, L["<distance>"]),
                    unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
                    comparison = Functions.presentation.predicate(value.operator, true),
                    threshold = Functions.presentation.nullable(threshold),
                    qualifier = Functions.presentation.predicate(value.healthoperator),
                    value = Functions.presentation.nullable(value.value),
                })
    end,
    -- Editor controls: the unit selector, this condition's own comparison controls, then the shared distance, same
    -- group and include pets controls from addon.proximity_widgets.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local healthoperator_group = addon:Widget_OperatorPercentWidget(value, L["Health"],
                function() top:SetStatusText(funcs:print(root, spec)) end, "healthoperator", "health")
        parent:AddChild(healthoperator_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    -- Help page: the unit, this condition's own fields, the shared distance, same group and include pets text, and the
    -- note on when the whole condition is unavailable.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health Percentage"], L["Health"],
                "The health percentage each ally within " .. color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " of " ..
                        color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " is compared with, as a percentage of their total health.")
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Health Percentage Count Within Range"], L["Count"],
                "The number of allies within " .. color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " of " ..
                        color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " whose health percentage passes that comparison.  " ..
                        "This only counts allies you are in a party or raid with.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end,
})

-- ============================================================================
-- Mana within range
-- ============================================================================

-- PROXIMITY_MANA: reduces the raw mana of the members within `distance` yards of the unit (operation: average,
-- minimum or maximum) and compares the result with the saved amount; a negative amount works on the deficit from
-- maximum mana instead. Returns nil and a reason when the scan is incomplete or uncertain, a read fails, or no member
-- is in range ("no-units-in-range"). Stores unit, operation, operator, value, distance, samegroup and includepets.
addon:RegisterCondition("PROXIMITY_MANA", {
    description = L["Mana Within Range"],
    icon = addon.Artwork.condition["PROXIMITY_MANA"],
    fields = {
        unit = "string",
        operation = "string",
        operator = "string",
        value = "number",
        distance = "number",
        samegroup = "boolean",
        includepets = "boolean",
    },
    -- Configuration check: every saved field must be present and in range for this condition.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operation ~= nil and Functions.values.isin(addon.math_operations, value.operation) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and
                value.distance ~= nil and value.distance >= 0)
    end,
    -- Collects one mana reading per member in range (addon.proximity_eval drives the scan), aggregates them and
    -- compares. Unavailable if the scan did not complete, any reading failed, or the list is empty.
    evaluate = function(value, cache)
        local values = {}
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,true,false,value.value<0)
            if cur==nil then return nil,why end
            table.insert(values, cur)
        end)
        if not complete then return nil,reason end

        local v,aggregateReason=aggregate(values,value.operation)
        if v==nil then return nil,aggregateReason end
        return Functions.values.compare(value.operator, v, math.abs(value.value))
    end,
    -- Rule summary from a localized phrase; fields that are not yet set show placeholders. A negative amount is worded
    -- as a deficit where the condition accepts one.
    print = function(_, value)
        local threshold = value.value
        local deficit = threshold ~= nil and threshold < 0
        if deficit then threshold = -threshold end
        return Functions.presentation.phrase(
                (deficit and L["The {operation} mana deficit of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}"] or
                L["The {operation} mana of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}"]),
                {
                    operation = Functions.presentation.nullable(addon.math_operations_prose[value.operation], L["<operation>"]),
                    members = value.samegroup and PARTY or L["Raid or Party"],
                    pets = value.includepets and " (" .. L["including pets"] .. ")" or "",
                    distance = Functions.presentation.nullable(value.distance, L["<distance>"]),
                    unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
                    comparison = Functions.presentation.predicate(value.operator, true),
                    threshold = Functions.presentation.nullable(threshold),
                })
    end,
    -- Editor controls: the unit selector, this condition's own comparison controls, then the shared distance, same
    -- group and include pets controls from addon.proximity_widgets.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = addon:CreateConditionDropdown()
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(addon.math_operations, Functions.collections.keys(addon.math_operations))
            if (value.operation ~= nil) then
                operation:SetValue(value.operation)
            end
        end
        parent:AddChild(operation)

        local operator_group = addon:Widget_OperatorWidget(value, L["Mana"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    -- Help page: the unit, this condition's own fields, the shared distance, same group and include pets text, and the
    -- note on when the whole condition is unavailable.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided by the number of values")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana Within Range"], L["Mana"],
                "The mana value the " .. color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " result is compared with: " ..
                        "the lowest, average or highest mana of the allies counted.  " ..
                        "If this number is negative, it compares their mana deficit (from max mana) instead.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end,
})

-- PROXIMITY_MANA_COUNT: counts the members within `distance` yards of the unit whose raw mana passes the mana
-- comparison (a negative mana compares each member's deficit from maximum) and compares that count with the saved
-- count. Returns nil and a reason when the scan is incomplete or uncertain or a read fails; an empty range counts 0.
-- Stores unit, manaoperator, mana, operator, value (the count), distance, samegroup and includepets.
addon:RegisterCondition("PROXIMITY_MANA_COUNT", {
    description = L["Mana Count Within Range"],
    icon = addon.Artwork.condition["PROXIMITY_MANA_COUNT"],
    fields = {
        unit = "string",
        manaoperator = "string",
        mana = "number",
        operator = "string",
        value = "number",
        distance = "number",
        samegroup = "boolean",
        includepets = "boolean",
    },
    -- Configuration check: every saved field must be present and in range for this condition.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.manaoperator ~= nil and Functions.values.isin(addon.operators, value.manaoperator) and
                value.mana ~= nil and type(value.mana) == "number" and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    -- Counts members in range whose mana passes the mana comparison (addon.proximity_eval drives the scan), then
    -- compares the count. Unavailable if the scan did not complete or any reading failed.
    evaluate = function(value, cache)
        local count = 0
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,true,false,value.mana<0)
            if cur==nil then return nil,why end
            if Functions.values.compare(value.manaoperator, cur, math.abs(value.mana)) then
                count = count + 1
            end
        end)
        if not complete then return nil,reason end

        return Functions.values.compare(value.operator, count, value.value)
    end,
    -- Rule summary from a localized phrase; fields that are not yet set show placeholders. A negative amount is worded
    -- as a deficit where the condition accepts one.
    print = function(_, value)
        local threshold = value.mana
        local deficit = threshold ~= nil and threshold < 0
        if deficit then threshold = -threshold end
        return Functions.presentation.phrase(
                (deficit and L["The number of {members} members{pets} within {distance} yards of {unit} whose mana deficit {qualifier} {threshold} {comparison} {value}"] or
                L["The number of {members} members{pets} within {distance} yards of {unit} whose mana {qualifier} {threshold} {comparison} {value}"]),
                {
                    members = value.samegroup and PARTY or L["Raid or Party"],
                    pets = value.includepets and " (" .. L["including pets"] .. ")" or "",
                    distance = Functions.presentation.nullable(value.distance, L["<distance>"]),
                    unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
                    comparison = Functions.presentation.predicate(value.operator, true),
                    threshold = Functions.presentation.nullable(threshold),
                    qualifier = Functions.presentation.predicate(value.manaoperator),
                    value = Functions.presentation.nullable(value.value),
                })
    end,
    -- Editor controls: the unit selector, this condition's own comparison controls, then the shared distance, same
    -- group and include pets controls from addon.proximity_widgets.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local manaoperator_group = addon:Widget_OperatorWidget(value, L["Mana"],
                function() top:SetStatusText(funcs:print(root, spec)) end, "manaoperator", "mana")
        parent:AddChild(manaoperator_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    -- Help page: the unit, this condition's own fields, the shared distance, same group and include pets text, and the
    -- note on when the whole condition is unavailable.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana"], L["Mana"],
                "The mana each ally within " .. color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " of " ..
                        color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " is compared with.  " ..
                        "If this number is negative, it compares each ally's mana deficit (from max mana) instead.")
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana Count Within Range"], L["Count"],
                "The number of allies within " .. color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " of " ..
                        color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " whose mana passes that comparison.  " ..
                        "This only counts allies you are in a party or raid with.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end,
})

-- PROXIMITY_MANAPCT: reduces the mana percentage of the members within `distance` yards of the unit (operation:
-- average, minimum or maximum) and compares the result with the saved fraction (0 to 1, compared as percent). Returns
-- nil and a reason when the scan is incomplete or uncertain, a read fails, a maximum is not positive, or no member is
-- in range. Stores unit, operation, operator, value, distance, samegroup and includepets.
addon:RegisterCondition("PROXIMITY_MANAPCT", {
    description = L["Mana Percentage Within Range"],
    icon = addon.Artwork.condition["PROXIMITY_MANAPCT"],
    fields = {
        unit = "string",
        operation = "string",
        operator = "string",
        value = "number",
        distance = "number",
        samegroup = "boolean",
        includepets = "boolean",
    },
    -- Configuration check: every saved field must be present and in range for this condition.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operation ~= nil and Functions.values.isin(addon.math_operations, value.operation) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0.00 and value.value <= 1.00 and
                value.distance ~= nil and value.distance >= 0)
    end,
    -- Collects one mana percentage per member in range (addon.proximity_eval drives the scan), aggregates them and
    -- compares. Unavailable if the scan did not complete, any reading failed, or the list is empty.
    evaluate = function(value, cache)
        local values = {}
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,true,true,false)
            if cur==nil then return nil,why end
            table.insert(values, cur)
        end)
        if not complete then return nil,reason end

        local v,aggregateReason=aggregate(values,value.operation)
        if v==nil then return nil,aggregateReason end
        return Functions.values.compare(value.operator, v, value.value * 100)
    end,
    -- Rule summary from a localized phrase; fields that are not yet set show placeholders. A negative amount is worded
    -- as a deficit where the condition accepts one.
    print = function(_, value)
        local threshold = value.value
        if threshold ~= nil then threshold = threshold * 100 end
        return Functions.presentation.phrase(
                L["The {operation} mana percentage of {members} members{pets} within {distance} yards of {unit} {comparison} {threshold}%"],
                {
                    operation = Functions.presentation.nullable(addon.math_operations_prose[value.operation], L["<operation>"]),
                    members = value.samegroup and PARTY or L["Raid or Party"],
                    pets = value.includepets and " (" .. L["including pets"] .. ")" or "",
                    distance = Functions.presentation.nullable(value.distance, L["<distance>"]),
                    unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
                    comparison = Functions.presentation.predicate(value.operator, true),
                    threshold = Functions.presentation.nullable(threshold),
                })
    end,
    -- Editor controls: the unit selector, this condition's own comparison controls, then the shared distance, same
    -- group and include pets controls from addon.proximity_widgets.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operation = addon:CreateConditionDropdown()
        operation:SetLabel(L["Operation"])
        operation:SetCallback("OnValueChanged", function(_, _, v)
            value.operation = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        operation.configure = function()
            operation:SetList(addon.math_operations, Functions.collections.keys(addon.math_operations))
            if (value.operation ~= nil) then
                operation:SetValue(value.operation)
            end
        end
        parent:AddChild(operation)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Mana"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    -- Help page: the unit, this condition's own fields, the shared distance, same group and include pets text, and the
    -- note on when the whole condition is unavailable.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " - " ..
                "Mathematical operation to perform"))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Minimum"] .. color.RESET .. " - " ..
                "The lowest value")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Average"] .. color.RESET .. " - " ..
                "The value that is the sum of all values divided by the number of values")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Maximum"] .. color.RESET .. " - " ..
                "The highest value")))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana Percentage Within Range"], L["Mana"],
                "The mana percentage the " .. color.BLIZ_YELLOW .. L["Operation"] .. color.RESET .. " result is compared with: " ..
                        "the lowest, average or highest mana of the allies counted, each as a percentage of their total mana.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end,
})

-- PROXIMITY_MANAPCT_COUNT: counts the members within `distance` yards of the unit whose mana percentage passes the
-- comparison with the saved fraction (0 to 1, compared as percent) and compares that count with the saved count.
-- Returns nil and a reason when the scan is incomplete or uncertain, a read fails or a maximum is not positive; an
-- empty range counts 0. Stores unit, manaoperator, mana (the fraction), operator, value (the count), distance,
-- samegroup and includepets.
addon:RegisterCondition("PROXIMITY_MANAPCT_COUNT", {
    description = L["Mana Percentage Count Within Range"],
    icon = addon.Artwork.condition["PROXIMITY_MANAPCT_COUNT"],
    fields = {
        unit = "string",
        manaoperator = "string",
        mana = "number",
        operator = "string",
        value = "number",
        distance = "number",
        samegroup = "boolean",
        includepets = "boolean",
    },
    -- Configuration check: every saved field must be present and in range for this condition.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.manaoperator ~= nil and Functions.values.isin(addon.operators, value.manaoperator) and
                value.mana ~= nil and value.mana >= 0.00 and value.mana <= 1.00 and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    -- Counts members in range whose mana percentage passes the comparison (addon.proximity_eval drives the scan), then
    -- compares the count. Unavailable if the scan did not complete or any reading failed.
    evaluate = function(value, cache)
        local count = 0
        local complete,reason=addon.proximity_eval(value, cache, function(c, unit)
            local cur,why=statistic(c,unit,true,true,false)
            if cur==nil then return nil,why end
            if Functions.values.compare(value.manaoperator, cur, value.mana * 100) then
                count = count + 1
            end
        end)
        if not complete then return nil,reason end
        return Functions.values.compare(value.operator, count, value.value)
    end,
    -- Rule summary from a localized phrase; fields that are not yet set show placeholders. A negative amount is worded
    -- as a deficit where the condition accepts one.
    print = function(_, value)
        local threshold = value.mana
        if threshold ~= nil then threshold = threshold * 100 end
        return Functions.presentation.phrase(
                L["The number of {members} members{pets} within {distance} yards of {unit} whose mana percentage {qualifier} {threshold}% {comparison} {value}"],
                {
                    members = value.samegroup and PARTY or L["Raid or Party"],
                    pets = value.includepets and " (" .. L["including pets"] .. ")" or "",
                    distance = Functions.presentation.nullable(value.distance, L["<distance>"]),
                    unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
                    comparison = Functions.presentation.predicate(value.operator, true),
                    threshold = Functions.presentation.nullable(threshold),
                    qualifier = Functions.presentation.predicate(value.manaoperator),
                    value = Functions.presentation.nullable(value.value),
                })
    end,
    -- Editor controls: the unit selector, this condition's own comparison controls, then the shared distance, same
    -- group and include pets controls from addon.proximity_widgets.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local manaoperator_group = addon:Widget_OperatorPercentWidget(value, L["Mana"],
                function() top:SetStatusText(funcs:print(root, spec)) end, "manaoperator", "mana")
        parent:AddChild(manaoperator_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    -- Help page: the unit, this condition's own fields, the shared distance, same group and include pets text, and the
    -- note on when the whole condition is unavailable.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana Percentage"], L["Mana"],
                "The mana percentage each ally within " .. color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " of " ..
                        color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " is compared with, as a percentage of their total mana.")
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Mana Percentage Count Within Range"], L["Count"],
                "The number of allies within " .. color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " of " ..
                        color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " whose mana percentage passes that comparison.  " ..
                        "This only counts allies you are in a party or raid with.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="aggregate" then return aggregate end
        if name=="color" then return color end
        if name=="helpers" then return helpers end
        if name=="observation" then return observation end
        if name=="statistic" then return statistic end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/spatial_stats.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/spatial_stats.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
