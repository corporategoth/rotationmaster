local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color, tonumber = color, tonumber
local helpers = addon.help_funcs

addon:RegisterCondition("STAT", {
    description = L["Character Stat"],
    icon = "Interface\\Icons\\inv_potion_36",
    fields = { stat = "number", operator = "string", unit = "string", value = "number" },
    valid = function(_, value)
        return (value.stat ~= nil and addon.isin(addon.stats, value.stat) and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        local cur
        if value.stat <= 5 then
            cur = select(2, addon.getCached(cache, UnitStat, value.unit, value.stat))
        else
            cur = select(2, addon.getCached(cache, UnitArmor, value.unit))
        end
        return addon.compare(value.operator, cur, value.value)
    end,
    print = function(_, value)
        return addon.compareString(value.operator, string.format("%s %s",
                addon.nullable(addon.unitsPossessive[value.unit], L["<unit>"]),
                addon.nullable_value(value.stat, addon.stats, L["<stat>"])), addon.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.deepcopy(addon.units, { "player", "pet" }, true),
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local stat = AceGUI:Create("Dropdown")
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

local ecs_data
local ecs_stats = {}
local ecs_stats_pct = {}

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
            local s = ecs_data:GetStatInfo(name)
            if s ~= nil then
                if type(s) == "number" then
                    ecs_stats[name] = text
                else
                    ecs_stats_pct[name] = text
                end
            end
        end
        for k,v in pairs(root) do
            if type(v) == "table" then
                recurse_ecs(text, v)
            end
        end
    end

    if not ecs_data then
        ecs_data = _G.ECSLoader:ImportModule("Data")
        recurse_ecs(nil, _G["ExtendedCharacterStats"].profile)
    end
end

addon.delayed_condition["ExtendedCharacterStats"]["ECS_STAT"] = {
    on_register = init_ecs,
    description = L["Extended Character Stat"],
    icon = "Interface\\Icons\\inv_potion_36",
    fields = { stat = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.stat ~= nil and addon.isin(ecs_stats, value.stat) and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local cur = addon.getCached(cache, ecs_data.GetStatInfo, ecs_data, value.stat)
        return addon.compare(value.operator, cur, value.value)
    end,
    print = function(_, value)
        return addon.compareString(value.operator,
                addon.nullable_value(value.stat, ecs_stats, L["<stat>"]), addon.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local stat = AceGUI:Create("Dropdown")
        stat:SetLabel(L["Character Stat"])
        stat:SetCallback("OnValueChanged", function(_, _, v)
            value.stat = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        stat.configure = function()
            stat:SetList(ecs_stats, addon.keys(ecs_stats))
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
    icon = "Interface\\Icons\\inv_potion_36",
    fields = { stat = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.stat ~= nil and addon.isin(ecs_stats_pct, value.stat) and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and type(value.value) == "number" and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local curs = addon.getCached(cache, ecs_data.GetStatInfo, ecs_data, value.stat)
        local cur = tonumber(curs:match("^(%d+%.?%d*)"))
        return addon.compare(value.operator, cur, value.value * 100)
    end,
    print = function(_, value)
        local v = value.value
        if v ~= nil then
            v = v * 100
        end
        return addon.compareString(value.operator,
                addon.nullable_value(value.stat, ecs_stats_pct, L["<stat>"]), addon.nullable(v) .. "%")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local stat = AceGUI:Create("Dropdown")
        stat:SetLabel(L["Character Stat"])
        stat:SetCallback("OnValueChanged", function(_, _, v)
            value.stat = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        stat.configure = function()
            stat:SetList(ecs_stats_pct, addon.keys(ecs_stats_pct))
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
