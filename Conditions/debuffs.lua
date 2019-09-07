local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")
local tonumber = tonumber

-- From constants
local operators, units, unitsPossessive, debufftypes = addon.operators, addon.units, addon.unitsPossessive,addon.debufftypes

-- From utils
local compare, compareString, nullable, keys, isin, isint, deepcopy, getCached, playerize =
    addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.isint, addon.deepcopy, addon.getCached, addon.playerize

addon:RegisterCondition("DEBUFF", {
    description = L["Debuff Present"],
    icon = "Interface\\Icons\\spell_shadow_curseoftounges",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache, evalStart)
        for i=1,40 do
            local name = getCached(cache, UnitDebuff, value.unit, i)
            if (name == nil) then
                break
            end
            if name == value.spell then
                return true
            end
        end
        return false
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s have %s"], L["%s has %s"]),
            nullable(units[value.unit], L["<unit>"]), nullable(value.spell, L["<debuff>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local spell_group = addon:Widget_SpellNameWidget(spec, "Spell_EditBox", value,
            function(v) return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
})

addon:RegisterCondition("DEBUFF_REMAIN", {
    description = L["Debuff Time Remaining"],
    icon = "Interface\\Icons\\ability_creature_cursed_04",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        for i=1,40 do
            local name, _, _, _, _, expirationTime = getCached(cache, UnitDebuff, value.unit, i)
            if (name == nil) then
                break
            end
            if name == value.spell then
                local remain = expirationTime - GetTime()
                return compare(value.operator, remain, value.value)
            end
        end
        return false
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s have %s where %s"], L["%s have %s where %s"]),
            nullable(units[value.unit], L["<unit>"]), nullable(value.spell, L["<debuff>"]),
            compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local spell_group = addon:Widget_SpellNameWidget(spec, "Spell_EditBox", value,
            function(v) return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        spell_group:SetRelativeWidth(0.5)
        operator_group:SetRelativeWidth(0.5)
    end,
})

addon:RegisterCondition("DEBUFF_STACKS", {
    description = L["Debuff Stacks"],
    icon = "Interface\\Icons\\Inv_misc_coin_06",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        for i=1,40 do
            local name, _, count = getCached(cache, UnitDebuff, value.unit, i)
            if (name == nil) then
                break
            end
            if name == value.spell then
                return compare(value.operator, count, value.value)
            end
        end
        return false
    end,
    print = function(spec, value)
        return nullable(unitsPossessive[value.unit], L["<unit>"]) .. " " ..
                compareString(value.operator, string.format(L["stacks of %s"], nullable(value.spell, L["<debuff>"])), nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local spell_group = addon:Widget_SpellNameWidget(spec, "Spell_EditBox", value,
            function(v) return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Stacks"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        spell_group:SetRelativeWidth(0.5)
        operator_group:SetRelativeWidth(0.5)
    end,
})

addon:RegisterCondition("DISPELLABLE", {
    description = L["Has Dispellable Debuff"],
    icon = "Interface\\Icons\\spell_shadow_curseofsargeras",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.debufftype ~= nil and isin(debufftypes, value.debufftype))
    end,
    evaluate = function(value, cache, evalStart)
        for i=1,40 do
            local name, _, _, debuffType = getCached(cache, UnitDebuff, value.unit, i)
            if (name == nil) then
                break
            end
            if value.debufftype == "Enrage" and debuffType == "" then
                return true
            elseif debuffType == value.debufftype then
                return true
            end
        end
        return false
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s have a %s debuff"], L["%s has a %s debuff"]),
            nullable(units[value.unit], L["<unit>"]), nullable(debufftypes[value.debufftype], L["<debuff type>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local debufftype = AceGUI:Create("Dropdown")
        parent:AddChild(debufftype)
        debufftype.configure = function()
            debufftype:SetLabel(L["Debuff Type"])
            debufftype:SetList(debufftypes, keys(debufftypes))
            debufftype:SetValue(value.debufftype)
            debufftype:SetCallback("OnValueChanged", function(widget, event, v)
                value.debufftype = v
                top:SetStatusText(funcs:print(root, spec))
            end)
        end

        return nil
    end,
})
