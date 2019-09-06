local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")
local tonumber, pairs = tonumber, pairs

-- From constants
local operators, units, unitsPossessive = addon.operators, addon.units, addon.unitsPossessive

-- From utils
local compare, compareString, nullable, keys, isin, isint, getCached, deepcopy, playerize =
    addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.isint, addon.getCached, addon.deepcopy, addon.playerize

addon:RegisterCondition("BUFF", {
    description = L["Buff Present"],
    icon = "Interface\\Icons\\spell_holy_divinespirit",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache, evalStart)
        for i=1,40 do
            local name = getCached(cache, UnitBuff, value.unit, i)
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
            nullable(units[value.unit], L["<unit>"]), nullable(value.spell, L["<spell>"]))
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
    end
})

addon:RegisterCondition("BUFF_REMAIN", {
    description = L["Buff Time Remaining"],
    icon = "Interface\\Icons\\Spell_frost_stun",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        for i=1,40 do
            local name, _, _, _, _, expirationTime = getCached(cache, UnitBuff, value.unit, i)
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
            nullable(units[value.unit], L["<unit>"]), nullable(value.spell, L["<buff>"]),
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

addon:RegisterCondition("BUFF_STACKS", {
    description = L["Buff Stacks"],
    icon = "Interface\\Icons\\Inv_misc_coin_02",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        for i=1,40 do
            local name, _, count = getCached(cache, UnitBuff, value.unit, i)
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
                compareString(value.operator, string.format(L["stacks of %s"], nullable(value.spell, L["<buff>"])), nullable(value.value))
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

addon:RegisterCondition("STEALABLE", {
    description = L["Has Stealable Buff"],
    icon = "Interface\\Icons\\Inv_weapon_shortblade_22",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit))
    end,
    evaluate = function(value, cache, evalStart)
        for i=1,40 do
            local name, _, _, _, _, _, _, isStealable = getCached(cache, UnitBuff, value.unit, i)
            if (name == nil) then
                break
            end
            if isStealable then
                return true
            end
        end
        return false
    end,
    print = function(spec, value)
        return string.format(L["%s has a stealable buff"], nullable(units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, deepcopy(units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
})

if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
    addon:RegisterCondition("WEAPON", {
        description = L["Weapon Enchant Present"],
        icon = "Interface\\Icons\\Inv_staff_18",
        valid = function(spec, value)
            return true
        end,
        evaluate = function(value, cache, evalStart)
            local mainEnchant, _, _, _, offEnchant, _, _, _ = getCached(cache, GetWeaponEnchantInfo)
            return (value.offhand and offEnchant or mainEnchant)
        end,
        print = function(spec, value)
            return string.format(L["Your %s weapon is enchanted"],
                (value.offhand and L["off hand"] or L["main hand"]))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local offhand = AceGUI:Create("CheckBox")
            parent:AddChild(offhand)

            offhand:SetLabel(L["Off Hand"])
            offhand:SetWidth(100)
            offhand:SetValue(value.offhand and true or false)
            offhand:SetCallback("OnValueChanged", function(widget, event, v)
                value.offhand = v
                top:SetStatusText(funcs:print(root, spec))
            end)
        end,
    })

    addon:RegisterCondition("WEAPON_REMAIN", {
        description = L["Weapon Enchant Time Remaining"],
        icon = "Interface\\Icons\\Inv_mace_13",
        valid = function(spec, value)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    value.value ~= nil and value.value >= 0)
        end,
        evaluate = function(value, cache, evalStart)
            local mainEnchant, mainExpires, _, _, offEnchant, offExpires, _, _ = getCached(cache, GetWeaponEnchantInfo)
            if (value.offhand and offEnchant or mainEnchant) then
                local remain = (value.offhands and offExpires or mainExpires) / 1000
                return compare(value.operator, remain, value.value)
            end
            return false
        end,
        print = function(spec, value)
            return string.format(L["Your %s weapon buff has %s"], (value.offhand and L["off hand"] or L["main hand"]),
                compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], nullable(value.value))))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local offhand = AceGUI:Create("CheckBox")
            parent:AddChild(offhand)
            local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
            parent:AddChild(operator_group)

            offhand:SetLabel(L["Off Hand"])
            offhand:SetWidth(100)
            offhand:SetValue(value.offhand and true or false)
            offhand:SetCallback("OnValueChanged", function(widget, event, v)
                value.offhand = v
                top:SetStatusText(funcs:print(root, spec))
            end)
        end,
    })

    addon:RegisterCondition("WEAPON_STACKS", {
        description = L["Weapon Enchant Stacks"],
        icon = "Interface\\Icons\\Inv_misc_coin_04",
        valid = function(spec, value)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    value.value ~= nil and value.value >= 0)
        end,
        evaluate = function(value, cache, evalStart)
            local mainEnchant, _, mainCharges, _, offEnchant, _, offCharges, _ = getCached(cache, GetWeaponEnchantInfo)
            if (value.offhand and offEnchant or mainEnchant) then
                return compare(value.operator, (value.offhand and offCharges or mainCharges), value.value)
            end
            return false
        end,
        print = function(spec, value)
            return string.format(L["Your %s weapon buff has %s"], (value.offhand and L["off hand"] or L["main hand"]),
                    compareString(value.operator, L["stacks"], nullable(value.value)))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local offhand = AceGUI:Create("CheckBox")
            parent:AddChild(offhand)
            local operator_group = addon:Widget_OperatorWidget(value, L["Stacks"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
            parent:AddChild(operator_group)

            offhand:SetLabel(L["Off Hand"])
            offhand:SetWidth(100)
            offhand:SetValue(value.offhand and true or false)
            offhand:SetCallback("OnValueChanged", function(widget, event, v)
                value.offhand = v
                top:SetStatusText(funcs:print(root, spec))
            end)
        end,
    })

end

