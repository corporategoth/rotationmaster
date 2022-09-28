local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs

local UnitBuff
if (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) then
    local LibClassicDurations = LibStub("LibClassicDurations")
    UnitBuff = function(unit, idx) return LibClassicDurations.UnitAuraDirect(unit, idx, "HELPFUL") end
else
    UnitBuff = function(unit, idx) return UnitAura(unit, idx, "HELPFUL") end
end

addon:RegisterCondition("BUFF", {
    description = L["Buff Present"],
    icon = "Interface\\Icons\\spell_holy_divinespirit",
    fields = { unit = "string", spell = "string", ownbuff = "boolean" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache)
        for i = 1, 40 do
            local name, _, _, _, _, _, caster = addon.getCached(cache, UnitBuff, value.unit, i)
            if (name == nil) then
                break
            end
            if name == value.spell then
                if (not value.ownbuff or caster == "player") then
                    return true
                end
            end
        end
        return false
    end,
    print = function(_, value)
        return string.format(addon.playerize(value.unit, L["%s have %s"], L["%s has %s"]),
                addon.nullable(addon.units[value.unit], L["<unit>"]),
                string.format(value.ownbuff and L["your own %s"] or "%s", addon.nullable(value.spell, L["<buff>"])))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function()
                    top:SetStatusText(funcs:print(root, spec))
                end)
        parent:AddChild(unit)

        local ownbuff = AceGUI:Create("CheckBox")
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
                end)
        parent:AddChild(spell_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.helpers.Gap())
        frame:AddChild(helpers.helpers.CreateText(color.BLIZ_YELLOW .. L["Own Buff"] .. color.RESET .. " - " ..
                "Should this condition only consider buffs that you have applied."))
        frame:AddChild(helpers.helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
    end
})

addon:RegisterCondition("BUFF_REMAIN", {
    description = L["Buff Time Remaining"],
    icon = "Interface\\Icons\\Spell_frost_stun",
    fields = { unit = "string", spell = "string", ownbuff = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        for i=1,40 do
            local name, _, _, _, _, expirationTime, caster = addon.getCached(cache, UnitBuff, value.unit, i)
            if (name == nil) then
                break
            end
            if name == value.spell then
                if (not value.ownbuff or caster == "player") then
                    local remain = expirationTime - GetTime()
                    return addon.compare(value.operator, remain, value.value)
                end
            end
        end
        return false
    end,
    print = function(_, value)
        return string.format(addon.playerize(value.unit, L["%s have %s where %s"], L["%s have %s where %s"]),
            addon.nullable(addon.units[value.unit], L["<unit>"]),
                string.format(value.ownbuff and L["your own %s"] or "%s", addon.nullable(value.spell, L["<buff>"])),
                addon.compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], addon.nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local ownbuff = AceGUI:Create("CheckBox")
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
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.helpers.Gap())
        frame:AddChild(helpers.helpers.CreateText(color.BLIZ_YELLOW .. L["Own Buff"] .. color.RESET .. " - " ..
                "Should this condition only consider buffs that you have applied."))
        frame:AddChild(helpers.helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        frame:AddChild(helpers.helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Buff Time Remaining"], L["Seconds"],
            "The number of seconds remaining on a buff applied to the " .. color.BLIZ_YELLOW .. L["Unit"] ..
            color.RESET .. ".  If the buff is not present, this condition will not be successful (regardless " ..
            "of the " .. color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
    end
})

addon:RegisterCondition("BUFF_STACKS", {
    description = L["Buff Stacks"],
    icon = "Interface\\Icons\\Inv_misc_coin_02",
    fields = { unit = "string", spell = "string", ownbuff = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        for i=1,40 do
            local name, _, count, _, _, _, caster = addon.getCached(cache, UnitBuff, value.unit, i)
            if (name == nil) then
                break
            end
            if name == value.spell then
                if (not value.ownbuff or caster == "player") then
                    return addon.compare(value.operator, count, value.value)
                end
            end
        end
        return false
    end,
    print = function(_, value)
        return addon.nullable(addon.unitsPossessive[value.unit], L["<unit>"]) .. " " ..
                addon.compareString(value.operator, string.format(L["stacks of %s"],
                string.format(value.ownbuff and L["your own %s"] or "%s", addon.nullable(value.spell, L["<buff>"]))),
                addon.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local ownbuff = AceGUI:Create("CheckBox")
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
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Stacks"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.helpers.Gap())
        frame:AddChild(helpers.helpers.CreateText(color.BLIZ_YELLOW .. L["Own Buff"] .. color.RESET .. " - " ..
                "Should this condition only consider buffs that you have applied."))
        frame:AddChild(helpers.helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        frame:AddChild(helpers.helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Buff Stacks"], L["Stacks"],
            "The number of stacks of a buff applied to the " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET ..
            ".  If the buff is not present, this condition will not be successful (regardless " ..
            "of the " .. color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
    end
})

addon:RegisterCondition("STEALABLE", {
    description = L["Has Stealable Buff"],
    icon = "Interface\\Icons\\Inv_weapon_shortblade_22",
    fields = { unit = "string" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit))
    end,
    evaluate = function(value, cache)
        for i=1,40 do
            local name, _, _, _, _, _, _, isStealable = addon.getCached(cache, UnitBuff, value.unit, i)
            if (name == nil) then
                break
            end
            if isStealable then
                return true
            end
        end
        return false
    end,
    print = function(_, value)
        return string.format(L["%s has a stealable buff"], addon.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})