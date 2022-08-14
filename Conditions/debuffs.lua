local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color = color

-- From constants
local operators, units, unitsPossessive, debufftypes = addon.operators, addon.units, addon.unitsPossessive,addon.debufftypes

-- From utils
local compare, compareString, nullable, keys, isin, getCached, playerize =
    addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.getCached, addon.playerize

local helpers = addon.help_funcs
local CreateText, Gap = helpers.CreateText, helpers.Gap

local UnitDebuff
if (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) then
    local LibClassicDurations = LibStub("LibClassicDurations")
    UnitDebuff = function(unit, idx) return LibClassicDurations.UnitAuraDirect(unit, idx, "HARMFUL") end
else
    UnitDebuff = function(unit, idx) return UnitAura(unit, idx, "HARMFUL") end
end

addon:RegisterCondition("DEBUFF", {
    description = L["Debuff Present"],
    icon = "Interface\\Icons\\spell_shadow_curseoftounges",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        for i=1,40 do
            local name, _, _, _, _, _, caster = getCached(cache, UnitDebuff, value.unit, i)
            if (name == nil) then
                break
            end
            if name == value.spell then
                if (not value.owndebuff or caster == "player") then
                    return true
                end
            end
        end
        return false
    end,
    print = function(_, value)
        return string.format(playerize(value.unit, L["%s have %s"], L["%s has %s"]),
            nullable(units[value.unit], L["<unit>"]),
            string.format(value.owndebuff and L["your own %s"] or "%s", nullable(value.spell, L["<debuff>"])))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local owndebuff = AceGUI:Create("CheckBox")
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
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Own Debuff"] .. color.RESET .. " - " ..
                "Should this condition only consider debuffs that you have applied."))
        frame:AddChild(Gap())
        addon.layout_condition_spellnamewidget_help(frame)
    end
})

addon:RegisterCondition("DEBUFF_STACKS", {
    description = L["Debuff Time Remaining"],
    icon = "Interface\\Icons\\ability_creature_cursed_04",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        for i=1,40 do
            local name, _, _, _, _, expirationTime, caster = getCached(cache, UnitDebuff, value.unit, i)
            if (name == nil) then
                break
            end
            if name == value.spell then
                if (not value.owndebuff or caster == "player") then
                    local remain = expirationTime - GetTime()
                    return compare(value.operator, remain, value.value)
                end
            end
        end
        return false
    end,
    print = function(_, value)
        return string.format(playerize(value.unit, L["%s have %s where %s"], L["%s have %s where %s"]),
            nullable(units[value.unit], L["<unit>"]),
            string.format(value.owndebuff and L["your own %s"] or "%s", nullable(value.spell, L["<debuff>"])),
            compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local owndebuff = AceGUI:Create("CheckBox")
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
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Own Debuff"] .. color.RESET .. " - " ..
                "Should this condition only consider debuffs that you have applied."))
        frame:AddChild(Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Debuff Time Remaining"], L["Seconds"],
            "The number of seconds remaining on a debuff applied to the " .. color.BLIZ_YELLOW .. L["Unit"] ..
            color.RESET .. ".  If the debuff is not present, this condition will not be successful (regardless " ..
            "of the " .. color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
    end
})

addon:RegisterCondition("DEBUFF_STACKS", {
    description = L["Debuff Stacks"],
    icon = "Interface\\Icons\\Inv_misc_coin_06",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        for i=1,40 do
            local name, _, count, _, _, _, caster = getCached(cache, UnitDebuff, value.unit, i)
            if (name == nil) then
                break
            end
            if name == value.spell then
                if (not value.owndebuff or caster == "player") then
                    return compare(value.operator, count, value.value)
                end
            end
        end
        return false
    end,
    print = function(_, value)
        return nullable(unitsPossessive[value.unit], L["<unit>"]) .. " " ..
                compareString(value.operator, string.format(L["stacks of %s"],
                string.format(value.owndebuff and L["your own %s"] or "%s", nullable(value.spell, L["<debuff>"]))),
                nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local owndebuff = AceGUI:Create("CheckBox")
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
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Stacks"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Own Debuff"] .. color.RESET .. " - " ..
                "Should this condition only consider debuffs that you have applied."))
        frame:AddChild(Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Debuff Stacks"], L["Stacks"],
            "The number of stacks of a deuff applied to the " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET ..
            ".  If the deuff is not present, this condition will not be successful (regardless " ..
            "of the " .. color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
    end
})

addon:RegisterCondition("DISPELLABLE", {
    description = L["Debuff Type Present"],
    icon = "Interface\\Icons\\spell_shadow_curseofsargeras",
    valid = function(_, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.debufftype ~= nil and isin(debufftypes, value.debufftype))
    end,
    evaluate = function(value, cache)
        if not getCached(cache, UnitExists, value.unit) then return false end
        for i=1,40 do
            local name, _, _, debuffType, _, _, caster = getCached(cache, UnitDebuff, value.unit, i, value.dispellable)
            if (name == nil) then
                break
            end

            if (not value.owndebuff or caster == "player") then
                if value.debufftype == "Enrage" and debuffType == "" then
                    return true
                elseif debuffType == value.debufftype then
                    return true
                end
            end
        end
        return false
    end,
    print = function(_, value)
        return string.format(playerize(value.unit, L["%s have a %s debuff"], L["%s has a %s debuff"]),
            nullable(units[value.unit], L["<unit>"]),
            string.format(value.owndebuff and L["your own %s"] or "%s", nullable(debufftypes[value.debufftype], L["<debuff type>"]))) ..
            (value.dispellable and " " .. L["that is dispellable"] or "")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local debufftype = AceGUI:Create("Dropdown")
        debufftype:SetLabel(L["Debuff Type"])
        debufftype:SetCallback("OnValueChanged", function(_, _, v)
            value.debufftype = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        debufftype.configure = function()
            debufftype:SetList(debufftypes, keys(debufftypes))
            debufftype:SetValue(value.debufftype)
        end
        parent:AddChild(debufftype)

        local owndebuff = AceGUI:Create("CheckBox")
        owndebuff:SetWidth(100)
        owndebuff:SetLabel(L["Own Debuff"])
        owndebuff:SetValue(value.owndebuff and true or false)
        owndebuff:SetCallback("OnValueChanged", function(_, _, v)
            value.owndebuff = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(owndebuff)

        local dispellable = AceGUI:Create("CheckBox")
        dispellable:SetWidth(100)
        dispellable:SetLabel(L["Dispellable"])
        dispellable:SetValue(value.dispellable and true or false)
        dispellable:SetCallback("OnValueChanged", function(_, _, v)
            value.dispellable = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(dispellable)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Debuff Type"] .. color.RESET .. " - " ..
            "The type of debuff that is on " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. "."))
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Own Debuff"] .. color.RESET .. " - " ..
                "Should this condition only consider debuffs that you have applied."))
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. L["Dispellable"] .. color.RESET .. " - " ..
                "Should this condition only consider debuffs that you can dispell."))
    end
})
