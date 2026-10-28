-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In conditions on a unit's character stats: STAT (a primary stat or armor of the player or pet, read through
-- Platform:GetUnitStatObservation) and, from the optional Extended Character Stats addon, ECS_STAT and ECS_STAT_PCT
-- (any stat or percentage that addon reports). The ECS conditions are not registered here: they are stored in
-- addon.delayed_condition["ExtendedCharacterStats"] and main.lua registers them at startup only when that addon is
-- loaded. That addon exists only for Classic Era, TBC and progression clients (Integrations/catalog.lua), so its
-- values are read through its own API with no restricted-client handling; STAT does go through the Platform, where a
-- stat the client hides as a secret value is unavailable (nil, reason), also under NOT. Loaded from RotationMaster.toc
-- after Conditions/stats.lua. Callback bodies and the helpers they bind are hashed by saved copies and bundles: never
-- add or change text inside a function body, and leave the generated block at the end alone.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color, tonumber = color, tonumber
local helpers = addon.help_funcs

-- Explicit owning leaves; observation and deferred integration contracts stay intact.
local Functions = {
    cache = { getCached = addon.Functions.cache.getCached },
    collections = { deepcopy = addon.Functions.collections.deepcopy, keys = addon.Functions.collections.keys },
    presentation = {
        compareString = addon.Functions.presentation.compareString,
        nullable = addon.Functions.presentation.nullable,
        nullable_value = addon.Functions.presentation.nullable_value,
    },
    values = { compare = addon.Functions.values.compare, isin = addon.Functions.values.isin },
}

local ECSLabels = { phrase = addon.Functions.presentation.phrase, predicate = addon.Functions.presentation.predicate }
addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/ext_stats.lua"] = {
    ["ECSLabels.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["ECSLabels.predicate"] = "builtin:Functions/presentation.lua:predicate",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.collections.deepcopy"] = "builtin:Functions/collections.lua:deepcopy",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.collections.keys"] = "builtin:Functions/collections.lua:keys",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.nullable_value"] = "builtin:utils.lua:nullable_value",
}

-- ============================================================================
-- Character stat
-- ============================================================================

-- STAT: compares one stat of a unit (the stat index from addon.stats: the five primary stats or armor) with a number.
-- Stores `stat`, `operator`, `unit` and `value`. False when the unit does not exist; `nil, reason` when the stat
-- cannot be read.
addon:RegisterCondition("STAT", {
    description = L["Character Stat"],
    icon = addon.Artwork.condition["STAT"],
    fields = { stat = "number", operator = "string", unit = "string", value = "number" },
    -- Valid with a listed stat, a known operator and unit, and a non-negative number.
    valid = function(_, value)
        return (value.stat ~= nil and Functions.values.isin(addon.stats, value.stat) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0)
    end,
    -- Unavailable when the Platform cannot read the stat (including a secret value on a restricted client).
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitStatObservation,addon.Platform,value.unit,value.stat)
        if record==nil then return nil,reason end
        if not record.exists then return false end
        return Functions.values.compare(value.operator,record.value,value.value)
    end,
    -- Readable summary, for example the unit's possessive followed by the stat name.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, string.format("%s %s",
                Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]),
                Functions.presentation.nullable_value(value.stat, addon.stats, L["<stat>"])), Functions.presentation.nullable(value.value))
    end,
    -- widget builds a unit picker limited to player and pet, a stat dropdown and an operator-and-value control; help
    -- describes each.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }, true),
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local stat = addon:CreateConditionDropdown()
        stat:SetLabel(L["Character Stat"])
        stat:SetCallback("OnValueChanged", function(_, _, v)
            value.stat = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        stat.configure = function()
            stat:SetList(addon.stats)
            stat:SetValue(value.stat)
        end
        parent:AddChild(stat)

        local operator_group = addon:Widget_OperatorWidget(value, L["Character Stat"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Character Stat"] .. color.RESET .. " - " ..
                "The character statistic you are interested in."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Character Stat"], L["Character Stat"],
                "The current value of the selected stat for " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".")
    end,
})

-- ============================================================================
-- Extended Character Stats (optional addon)
-- ============================================================================

-- Conditions that need the Extended Character Stats addon wait in this table until main.lua sees the addon loaded.
if not addon.delayed_condition["ExtendedCharacterStats"] then
    addon.delayed_condition["ExtendedCharacterStats"] = {}
end

-- What the addon offers, filled in once by init_ecs: `data` is its Data module, `stats` maps a stat's reference name to
-- its menu path for stats reported as numbers, and `percentages` does the same for stats reported as percentage text.
local ecs_state = { stats = {}, percentages = {} }

-- on_register hook of both ECS conditions, run when they register (so only with the addon loaded). Imports the addon's
-- Data module and walks its settings tree once, sorting every stat that has a reference name into ecs_state.stats or
-- ecs_state.percentages by the type its GetStatInfo returns. Later calls do nothing.
local function init_ecs()
    local function recurse_ecs(prefix, root)
        local text
        local name = root["refName"]
        if root["text"] then
            if prefix then
                text = prefix .. " -> " .. root["text"]
            else
                text = root["text"]
            end
        end
        if name and text and not name:match("Header$") then
            local s = ecs_state.data.GetStatInfo(name)
            if s ~= nil then
                if type(s) == "number" then
                    ecs_state.stats[name] = text
                else
                    ecs_state.percentages[name] = text
                end
            end
        end
        for k,v in pairs(root) do
            if type(v) == "table" then
                recurse_ecs(text, v)
            end
        end
    end

    if not ecs_state.data then
        ecs_state.data = _G.ECSLoader:ImportModule("Data")
        recurse_ecs(nil, _G["ExtendedCharacterStats"].profile)
    end
end

-- ECS_STAT: compares a numeric stat as Extended Character Stats reports it for you with a number. Stores `stat` (the
-- addon's reference name), `operator` and `value`. The value comes straight from the addon, so the callback has no
-- `nil, reason` path of its own.
addon.delayed_condition["ExtendedCharacterStats"]["ECS_STAT"] = {
    on_register = init_ecs,
    description = L["Extended Character Stat"],
    icon = addon.Artwork.condition["ECS_STAT"],
    fields = { stat = "string", operator = "string", value = "number" },
    -- Valid with a stat from the addon's numeric list, a known operator and a non-negative number.
    valid = function(_, value)
        return (value.stat ~= nil and Functions.values.isin(ecs_state.stats, value.stat) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and value.value >= 0)
    end,
    -- Reads the stat through the addon's GetStatInfo, cached for the poll.
    evaluate = function(value, cache)
        local cur = Functions.cache.getCached(cache, ecs_state.data.GetStatInfo, value.stat)
        return Functions.values.compare(value.operator, cur, value.value)
    end,
    -- Readable summary: the stat name, the comparison and the value.
    print = function(_, value)
        return ECSLabels.phrase(L["{stat} {comparison} {value}"], {
            stat = Functions.presentation.nullable_value(value.stat, ecs_state.stats, L["<stat>"]),
            comparison = ECSLabels.predicate(value.operator, true),
            value = Functions.presentation.nullable(value.value),
        })
    end,
    -- widget builds a dropdown of the addon's numeric stats and an operator-and-value control; help describes both.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local stat = addon:CreateConditionDropdown()
        stat:SetLabel(L["Character Stat"])
        stat:SetCallback("OnValueChanged", function(_, _, v)
            value.stat = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        stat.configure = function()
            stat:SetList(ecs_state.stats, Functions.collections.keys(ecs_state.stats))
            stat:SetValue(value.stat)
        end
        parent:AddChild(stat)

        local operator_group = addon:Widget_OperatorWidget(value, L["Character Stat"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Character Stat"] .. color.RESET .. " - " ..
                "The character statistic you are interested in."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Character Stat"], L["Character Stat"],
                "Your current value of the selected stat, as Extended Character Stats reports it.")
    end,
}

-- ECS_STAT_PCT: compares a percentage stat as Extended Character Stats reports it for you with a number. Stores `stat`
-- (the addon's reference name), `operator` and `value` (a fraction from 0 to 1, compared as value * 100 against the
-- percentage the addon shows).
addon.delayed_condition["ExtendedCharacterStats"]["ECS_STAT_PCT"] = {
    on_register = init_ecs,
    description = L["Extended Character Stat Percentage"],
    icon = addon.Artwork.condition["ECS_STAT_PCT"],
    fields = { stat = "string", operator = "string", value = "number" },
    -- Valid with a stat from the addon's percentage list, a known operator and a non-negative number.
    valid = function(_, value)
        return (value.stat ~= nil and Functions.values.isin(ecs_state.percentages, value.stat) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and value.value >= 0)
    end,
    -- The addon reports the percentage as text; the leading number is parsed out of it before comparing.
    evaluate = function(value, cache)
        local curs = Functions.cache.getCached(cache, ecs_state.data.GetStatInfo, value.stat)
        local cur = tonumber(curs:match("^(%-?%d+%.?%d*)"))
        return Functions.values.compare(value.operator, cur, value.value * 100)
    end,
    -- Shows the stored fraction as a percentage.
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return ECSLabels.phrase(L["{stat} {comparison} {value}%"], {
            stat = Functions.presentation.nullable_value(value.stat, ecs_state.percentages, L["<stat>"]),
            comparison = ECSLabels.predicate(value.operator, true),
            value = Functions.presentation.nullable(v),
        })
    end,
    -- widget builds a dropdown of the addon's percentage stats and an operator-and-percent control; help describes
    -- both.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local stat = addon:CreateConditionDropdown()
        stat:SetLabel(L["Character Stat"])
        stat:SetCallback("OnValueChanged", function(_, _, v)
            value.stat = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        stat.configure = function()
            stat:SetList(ecs_state.percentages, Functions.collections.keys(ecs_state.percentages))
            stat:SetValue(value.stat)
        end
        parent:AddChild(stat)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Character Stat"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Character Stat"] .. color.RESET .. " - " ..
                "The character statistic you are interested in."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Extended Character Stat Percentage"], L["Character Stat"],
                "Your current value of the selected stat, as a percentage, as Extended Character Stats reports it.")
    end,
}

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="ecs_state" then return ecs_state end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/ext_stats.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/ext_stats.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
