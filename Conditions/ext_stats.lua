local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color, tonumber = color, tonumber
local helpers = addon.help_funcs

-- Explicit owning leaves; observation and deferred integration contracts stay intact.
local Functions={
    cache={getCached=addon.Functions.cache.getCached},
    collections={deepcopy=addon.Functions.collections.deepcopy,keys=addon.Functions.collections.keys},
    presentation={compareString=addon.Functions.presentation.compareString,nullable=addon.Functions.presentation.nullable,nullable_value=addon.Functions.presentation.nullable_value},
    values={compare=addon.Functions.values.compare,isin=addon.Functions.values.isin},
}
local ECSLabels={phrase=addon.Functions.presentation.phrase,predicate=addon.Functions.presentation.predicate}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/ext_stats.lua"]={
    ["ECSLabels.phrase"]="builtin:Functions/presentation.lua:phrase",
    ["ECSLabels.predicate"]="builtin:Functions/presentation.lua:predicate",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.collections.deepcopy"]="builtin:Functions/collections.lua:deepcopy",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.collections.keys"]="builtin:Functions/collections.lua:keys",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.nullable_value"]="builtin:utils.lua:nullable_value",
}

addon:RegisterCondition("STAT", {
    description = L["Character Stat"],
    icon = addon.Artwork.condition["STAT"],
    fields = { stat = "number", operator = "string", unit = "string", value = "number" },
    valid = function(_, value)
        return (value.stat ~= nil and Functions.values.isin(addon.stats, value.stat) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitStatObservation,addon.Platform,value.unit,value.stat)
        if record==nil then return nil,reason end
        if not record.exists then return false end
        return Functions.values.compare(value.operator,record.value,value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, string.format("%s %s",
                Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]),
                Functions.presentation.nullable_value(value.stat, addon.stats, L["<stat>"])), Functions.presentation.nullable(value.value))
    end,
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
    end
})

if not addon.delayed_condition["ExtendedCharacterStats"] then
    addon.delayed_condition["ExtendedCharacterStats"] = {}
end

local ecs_state = { stats = {}, percentages = {} }

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

addon.delayed_condition["ExtendedCharacterStats"]["ECS_STAT"] = {
    on_register = init_ecs,
    description = L["Extended Character Stat"],
    icon = addon.Artwork.condition["ECS_STAT"],
    fields = { stat = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.stat ~= nil and Functions.values.isin(ecs_state.stats, value.stat) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local cur = Functions.cache.getCached(cache, ecs_state.data.GetStatInfo, value.stat)
        return Functions.values.compare(value.operator, cur, value.value)
    end,
    print = function(_, value)
        return ECSLabels.phrase(L["{stat} {comparison} {value}"], {
            stat = Functions.presentation.nullable_value(value.stat, ecs_state.stats, L["<stat>"]),
            comparison = ECSLabels.predicate(value.operator, true),
            value = Functions.presentation.nullable(value.value),
        })
    end,
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
                "The current value of the selected stat for " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".")
    end
}

addon.delayed_condition["ExtendedCharacterStats"]["ECS_STAT_PCT"] = {
    on_register = init_ecs,
    description = L["Extended Character Stat Percentage"],
    icon = addon.Artwork.condition["ECS_STAT_PCT"],
    fields = { stat = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.stat ~= nil and Functions.values.isin(ecs_state.percentages, value.stat) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local curs = Functions.cache.getCached(cache, ecs_state.data.GetStatInfo, value.stat)
        local cur = tonumber(curs:match("^(%-?%d+%.?%d*)"))
        return Functions.values.compare(value.operator, cur, value.value * 100)
    end,
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
                "The current value of the selected stat for " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".")
    end
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
