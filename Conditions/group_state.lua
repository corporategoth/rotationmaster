-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In condition GROUP_COUNT: compares a count taken over your party or raid (its size, the members with an
-- assigned tank, healer or damage role, or the dead or ghost members; optionally as a percent of the group) with a
-- number. It reads one cached Platform:GetGroupSnapshot (Platform/world_state.lua) per evaluation. Group members
-- are never identity-restricted, so it works on Retail and Forever too; a member whose value cannot be read makes
-- the count unavailable (nil, reason), also under NOT, rather than understating it. Loaded from RotationMaster.toc
-- after Conditions/encounter_state.lua. Callback and helper bodies are hashed by saved copies and bundles: never add
-- or change text inside a function body, and leave the generated block at the end alone.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Your party or raid as numbers, in one condition: how many players it has, how
-- many hold an assigned role (tanks, healers, damage dealers) and how many are
-- dead or ghosts. Every count includes you, and each can be compared as a
-- number of players or as a percent of the whole group (you included). One pass
-- over the party or raid tokens (Platform:GetGroupSnapshot, Platform/world_state.lua)
-- answers a measure, once per evaluation, reading only what that measure needs. Group members are never
-- identity-restricted, so these read on Retail and Forever as well; a member
-- whose value cannot be read makes the count unavailable (also under NOT)
-- instead of understating it.
local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
    },
    cache = { getCached = addon.Functions.cache.getCached },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/group_state.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
}

-- What can be counted, in the order the editor lists it.
local MEASURE_ORDER = { "size", "TANK", "HEALER", "DAMAGER", "dead" }

-- Returns the editor labels of the measures, keyed by measure name.
local function measureNames()
    return {
        size = L["Players in the group"], TANK = L["Tanks"], HEALER = L["Healers"], DAMAGER = L["Damage dealers"],
        dead = L["Dead or ghost members"],
    }
end

-- True when value carries a known operator and a finite, non-negative number to compare against (at most 100 when
-- value.percent is set).
local function validCompare(value)
    if value.operator == nil or not Functions.values.isin(addon.operators, value.operator) then return false end
    if type(value.value) ~= "number" or value.value ~= value.value or value.value < 0 or value.value >= math.huge then return false end
    return value.percent ~= true or value.value <= 100
end

-- GROUP_COUNT: compares the chosen `measure` ("size", "TANK", "HEALER", "DAMAGER" or "dead"; every count includes you)
-- with `value`, as a number of players or, with `percent`, as a percent of the whole group. Stores `measure`,
-- `percent`, `operator` and `value`. Returns `nil, reason` when the group snapshot, or the role or death data a
-- member needs, cannot be read ("group-data-unavailable" when the snapshot gives no reason).
addon:RegisterCondition("GROUP_COUNT", {
    description = L["Group Count"],
    icon = addon.Artwork.condition["GROUP_COUNT"],
    requiredFields = { "measure", "operator", "value" },
    fields = { measure = "string", percent = "boolean", operator = "string", value = "number" },
    -- Valid with a listed measure, a valid comparison, and a percent flag that is not set on "size" (the group is
    -- always 100 percent of itself).
    valid = function(_, value)
        return value.measure ~= nil and Functions.values.isin(measureNames(), value.measure)
            and (value.percent == nil or type(value.percent) == "boolean" and (value.percent ~= true or value.measure ~= "size"))
            and validCompare(value)
    end,
    -- Asks the snapshot only for what the measure needs ("size", "roles" or "dead"), so a size check never calls the
    -- role or death APIs.
    evaluate = function(value, cache)
        local group, reason = Functions.cache.getCached(cache, addon.Platform.GetGroupSnapshot, addon.Platform,
            value.measure == "dead" and "dead" or value.measure ~= "size" and "roles" or "size")
        if not group then return nil, reason end
        local count
        if value.measure == "size" then count = group.size
        elseif value.measure == "dead" then
            if group.dead == nil then return nil, group.deadReason or "group-data-unavailable" end
            count = group.dead
        else
            if group.roles == nil then return nil, group.rolesReason or "group-data-unavailable" end
            count = group.roles[value.measure] or 0
        end
        if value.percent then count = count / group.size * 100 end
        return Functions.values.compare(value.operator, count, value.value)
    end,
    -- Readable summary; the subject differs for a count of players and a percent of the group.
    print = function(_, value)
        local names, measure = measureNames(), value.measure
        local subject, quantity
        if value.percent then
            if measure == "dead" then subject = L["the percent of your group that is dead or a ghost"]
            elseif measure == "TANK" or measure == "HEALER" or measure == "DAMAGER" then
                subject = string.format(L["the percent of your group whose assigned role is %s"], addon.roles[measure])
            else subject = string.format(L["the percent of your group counted as %s"], Functions.presentation.nullable(names[measure], L["<measure>"])) end
            quantity = string.format(L["%s percent"], Functions.presentation.nullable(value.value))
        else
            if measure == "size" then subject = L["the number of players in your group"]
            elseif measure == "dead" then subject = L["the number of dead or ghost members of your group"]
            elseif measure == "TANK" or measure == "HEALER" or measure == "DAMAGER" then
                subject = string.format(L["the number of group members whose assigned role is %s"], addon.roles[measure])
            else subject = string.format(L["the number of group members counted as %s"], Functions.presentation.nullable(names[measure], L["<measure>"])) end
            quantity = Functions.presentation.nullable(value.value)
        end
        return Functions.presentation.compareString(value.operator, subject, quantity)
    end,
    -- widget builds the measure dropdown, the "as a percent of the group" checkbox and an operator-and-value control;
    -- help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local percent = addon:CreateConditionCheckBox()
        local measure = addon:CreateConditionDropdown()
        measure:SetLabel(L["Count"])
        measure:SetCallback("OnValueChanged", function(_, _, v)
            value.measure = v
            -- The size of the group is always 100 percent of itself.
            if v == "size" then value.percent = nil;percent:SetValue(false) end
            top:SetStatusText(funcs:print(root, spec))
        end)
        measure.configure = function()
            measure:SetList(measureNames(), MEASURE_ORDER)
            if value.measure ~= nil then measure:SetValue(value.measure) end
        end
        parent:AddChild(measure)

        percent:SetWidth(300)
        percent:SetLabel(L["As a percent of the group"])
        percent:SetValue(value.percent and true or false)
        percent:SetCallback("OnValueChanged", function(_, _, v)
            value.percent = v or nil
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(percent)

        parent:AddChild(addon:Widget_OperatorWidget(value, L["Value"], function() top:SetStatusText(funcs:print(root, spec)) end))
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.GROUP_COUNT"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Group Count"], L["Value"],
            L["A number of players, or a percent of the whole group when the box is ticked. You are always part of the group and of every count you fit."])
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="MEASURE_ORDER" then return MEASURE_ORDER end
        if name=="helpers" then return helpers end
        if name=="measureNames" then return measureNames end
        if name=="validCompare" then return validCompare end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/group_state.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/group_state.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
