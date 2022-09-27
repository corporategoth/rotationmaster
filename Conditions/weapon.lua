local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color = color
local helpers = addon.help_funcs

if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
    addon:RegisterCondition("WEAPON", {
        description = L["Weapon Enchant Present"],
        icon = "Interface\\Icons\\Inv_staff_18",
        valid = function()
            return true
        end,
        evaluate = function(value, cache)
            local mainEnchant, _, _, _, offEnchant, _, _, _ = addon.getCached(cache, GetWeaponEnchantInfo)
            return (value.offhand and offEnchant or mainEnchant)
        end,
        print = function(_, value)
            return string.format(L["Your %s weapon is enchanted"],
                    (value.offhand and L["off hand"] or L["main hand"]))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local offhand = AceGUI:Create("CheckBox")
            offhand:SetWidth(100)
            offhand:SetLabel(L["Off Hand"])
            offhand:SetValue(value.offhand and true or false)
            offhand:SetCallback("OnValueChanged", function(_, _, v)
                value.offhand = v
                top:SetStatusText(funcs:print(root, spec))
            end)
            parent:AddChild(offhand)
        end,
        help = function(frame)
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Off Hand"] .. color.RESET .. " - " ..
                    "Should this condition affect your main or off-hand weapon.  If this is checked, it will affect " ..
                    "your off-hand weapon, otherwise it will affect your main-hand (or two-handed) weapon."))
        end
    })

    addon:RegisterCondition("WEAPON_REMAIN", {
        description = L["Weapon Enchant Time Remaining"],
        icon = "Interface\\Icons\\Inv_mace_13",
        valid = function(_, value)
            return (value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                    value.value ~= nil and value.value >= 0)
        end,
        evaluate = function(value, cache)
            local mainEnchant, mainExpires, _, _, offEnchant, offExpires, _, _ = addon.getCached(cache, GetWeaponEnchantInfo)
            if (value.offhand and offEnchant or mainEnchant) then
                local remain = (value.offhands and offExpires or mainExpires) / 1000
                return addon.compare(value.operator, remain, value.value)
            end
            return false
        end,
        print = function(_, value)
            return string.format(L["Your %s weapon buff has %s"], (value.offhand and L["off hand"] or L["main hand"]),
                    addon.compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], addon.nullable(value.value))))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local offhand = AceGUI:Create("CheckBox")
            offhand:SetWidth(100)
            offhand:SetLabel(L["Off Hand"])
            offhand:SetValue(value.offhand and true or false)
            offhand:SetCallback("OnValueChanged", function(_, _, v)
                value.offhand = v
                top:SetStatusText(funcs:print(root, spec))
            end)
            parent:AddChild(offhand)

            local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
                    function() top:SetStatusText(funcs:print(root, spec)) end)
            parent:AddChild(operator_group)
        end,
        help = function(frame)
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Off Hand"] .. color.RESET .. " - " ..
                    "Should this condition affect your main or off-hand weapon.  If this is checked, it will affect " ..
                    "your off-hand weapon, otherwise it will affect your main-hand (or two-handed) weapon."))

            frame:AddChild(helpers.Gap())
            addon.layout_condition_operatorwidget_help(frame, L["Weapon Enchant Time Remaining"], L["Seconds"],
                    "The amount of time (in seconds) your weapon buff has left before it expires.  If there is no buff " ..
                            "on your weapon, this condition will not be successful (regardless of the " .. color.BLIZ_YELLOW ..
                            "Operator" .. color.RESET .. " used.)")
        end
    })

    addon:RegisterCondition("WEAPON_STACKS", {
        description = L["Weapon Enchant Stacks"],
        icon = "Interface\\Icons\\Inv_misc_coin_04",
        valid = function(_, value)
            return (value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                    value.value ~= nil and value.value >= 0)
        end,
        evaluate = function(value, cache)
            local mainEnchant, _, mainCharges, _, offEnchant, _, offCharges, _ = addon.getCached(cache, GetWeaponEnchantInfo)
            if (value.offhand and offEnchant or mainEnchant) then
                return addon.compare(value.operator, (value.offhand and offCharges or mainCharges), value.value)
            end
            return false
        end,
        print = function(_, value)
            return string.format(L["Your %s weapon buff has %s"], (value.offhand and L["off hand"] or L["main hand"]),
                    addon.compareString(value.operator, L["stacks"], addon.nullable(value.value)))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local offhand = AceGUI:Create("CheckBox")
            offhand:SetWidth(100)
            offhand:SetLabel(L["Off Hand"])
            offhand:SetValue(value.offhand and true or false)
            offhand:SetCallback("OnValueChanged", function(_, _, v)
                value.offhand = v
                top:SetStatusText(funcs:print(root, spec))
            end)
            parent:AddChild(offhand)

            local operator_group = addon:Widget_OperatorWidget(value, L["Stacks"],
                    function() top:SetStatusText(funcs:print(root, spec)) end)
            parent:AddChild(operator_group)
        end,
        help = function(frame)
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Off Hand"] .. color.RESET .. " - " ..
                    "Should this condition affect your main or off-hand weapon.  If this is checked, it will affect " ..
                    "your off-hand weapon, otherwise it will affect your main-hand (or two-handed) weapon."))

            frame:AddChild(helpers.Gap())
            addon.layout_condition_operatorwidget_help(frame, L["Weapon Enchant Stacks"], L["Stacks"],
                    "The number of stacks of a buff applied to your weapon.  If there is no buff on your weapon, this " ..
                            "condition will not be successful (regardless of the " .. color.BLIZ_YELLOW .. "Operator" ..
                            color.RESET .. " used.)")
        end
    })
end

addon:RegisterCondition("SWING_TIME", {
    description = L["Weapon Swing Time"],
    icon = 135561,
    valid = function(_, value)
        return (value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local mainSpeed, offSpeed = addon.getCached(cache, UnitAttackSpeed, "player")
        return addon.compare(value.operator, value.offhand and offSpeed or mainSpeed, value.value)
    end,
    print = function(_, value)
        return string.format(L["Your %s weapon %s"], (value.offhand and L["off hand"] or L["main hand"]),
                addon.compareString(value.operator, L["attack speed"], string.format(L["%s seconds"], addon.nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local offhand = AceGUI:Create("CheckBox")
        offhand:SetWidth(100)
        offhand:SetLabel(L["Off Hand"])
        offhand:SetValue(value.offhand and true or false)
        offhand:SetCallback("OnValueChanged", function(_, _, v)
            value.offhand = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(offhand)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Off Hand"] .. color.RESET .. " - " ..
                "Should this condition affect your main or off-hand weapon.  If this is checked, it will affect " ..
                "your off-hand weapon, otherwise it will affect your main-hand (or two-handed) weapon."))

        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Attack Speed"], L["Seconds"],
                "The amount of time (in seconds) between swing times for your weapon.")
    end
})

addon:RegisterCondition("SWING_TIME_REMAIN", {
    description = L["Weapon Swing Time Remaining"],
    icon = 135672,
    valid = function(_, value)
        return (value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        local mainSpeed, offSpeed = addon.getCached(cache, UnitAttackSpeed, "player")
        if (value.offhand and (addon.lastOffSwing == nil) or (addon.lastMainSwing == nil)) or
            addon.getCached(cache, UnitCastingInfo, "player") or addon.getCached(cache, UnitChannelingInfo, "player") then
            return addon.compare(value.operator, value.offhand and offSpeed or mainSpeed, value.value)
        end
        return addon.compare(value.operator, value.offhand and (offSpeed - math.max(evalStart - addon.lastOffSwing, 0)) or
                (mainSpeed - math.max(evalStart - addon.lastMainSwing, 0)), value.value)
    end,
    print = function(_, value)
        return string.format(L["Your %s weapon %s"], (value.offhand and L["off hand"] or L["main hand"]),
                addon.compareString(value.operator, L["swing time remaining"], string.format(L["%s seconds"], addon.nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local offhand = AceGUI:Create("CheckBox")
        offhand:SetWidth(100)
        offhand:SetLabel(L["Off Hand"])
        offhand:SetValue(value.offhand and true or false)
        offhand:SetCallback("OnValueChanged", function(_, _, v)
            value.offhand = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(offhand)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Off Hand"] .. color.RESET .. " - " ..
                "Should this condition affect your main or off-hand weapon.  If this is checked, it will affect " ..
                "your off-hand weapon, otherwise it will affect your main-hand (or two-handed) weapon."))

        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Swing Time Remaining"], L["Seconds"],
                "The amount of time (in seconds) until your next weapon swing.")
    end
})