local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- These pure dependencies are selected from their owning modules and remain
-- private to the authored callbacks and their editable source copies.
local Functions={
    cache={getCached=addon.Functions.cache.getCached},
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={compareString=addon.Functions.presentation.compareString,nullable=addon.Functions.presentation.nullable},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/weapon.lua"]={
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
}

-- Select the requested hand before interpreting observations. Lua's and/or
-- shorthand falls through to the other hand when the selected value is false.
local function enchantObservation(value, cache)
    if type(GetWeaponEnchantInfo)~="function" then return nil,nil,nil,"missing-api" end
    -- The protected cached API returns both hands' original tuple unchanged.
    ---@diagnostic disable-next-line: unbalanced-assignments
    local ok, main, mainExpires, mainCharges, _, off, offExpires, offCharges = pcall(addon.getCached, cache, GetWeaponEnchantInfo)
    if not ok then return nil,nil,nil,"api-error" end
    local enchanted, expires, charges=main,mainExpires,mainCharges
    if value.offhand then enchanted,expires,charges=off,offExpires,offCharges end
    if not addon.Platform:CanReadValue(enchanted) then return nil,nil,nil,"restricted-value" end
    if enchanted==nil or enchanted==false or enchanted==0 then return false end
    if enchanted~=true and enchanted~=1 then return nil,nil,nil,"invalid-weapon-observation" end
    return true,expires,charges
end
local function numericObservation(value)
    if not addon.Platform:CanReadValue(value) then return nil,"restricted-value" end
    if type(value)~="number" or value~=value or value<0 or value==math.huge then return nil,"invalid-weapon-observation" end
    return value
end
local function swingSpeed(value,cache)
    if type(UnitAttackSpeed)~="function" then return nil,"missing-api" end
    -- pcall forwards the mainhand and offhand speeds from the observation.
    ---@diagnostic disable-next-line: unbalanced-assignments
    local ok,main,off=pcall(addon.getCached,cache,UnitAttackSpeed,"player")
    if not ok then return nil,"api-error" end
    local speed=main;if value.offhand then speed=off end
    return numericObservation(speed)
end

if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
    addon:RegisterCondition("WEAPON", {
        description = L["Weapon Enchant Present"],
        icon = addon.Artwork.condition["WEAPON"],
        fields = { offhand = "boolean" },
        valid = function()
            return true
        end,
        evaluate = function(value, cache)
            local enchanted, _, _, reason=enchantObservation(value,cache)
            return enchanted,reason
        end,
        print = function(_, value)
            return string.format(L["Your %s weapon {{!is|is not}} enchanted"],
                    (value.offhand and L["off hand"] or L["main hand"]))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local offhand = addon:CreateConditionCheckBox()
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
        icon = addon.Artwork.condition["WEAPON_REMAIN"],
        fields = { offhand = "boolean", operator = "string", value = "number" },
        valid = function(_, value)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    value.value ~= nil and value.value >= 0)
        end,
        evaluate = function(value, cache)
            local enchanted, expires, _, reason=enchantObservation(value,cache)
            if enchanted==nil then return nil,reason end
            if not enchanted then return false end
            local duration,why=numericObservation(expires)
            if duration==nil then return nil,why end
            return Functions.values.compare(value.operator,duration/1000,value.value)
        end,
        print = function(_, value)
            return string.format(L["Your %s weapon buff has %s"], (value.offhand and L["off hand"] or L["main hand"]),
                    Functions.presentation.compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local offhand = addon:CreateConditionCheckBox()
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
        icon = addon.Artwork.condition["WEAPON_STACKS"],
        fields = { offhand = "boolean", operator = "string", value = "number" },
        valid = function(_, value)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    value.value ~= nil and value.value >= 0)
        end,
        evaluate = function(value, cache)
            local enchanted, _, charges, reason=enchantObservation(value,cache)
            if enchanted==nil then return nil,reason end
            if not enchanted then return false end
            local count,why=numericObservation(charges)
            if count==nil then return nil,why end
            return Functions.values.compare(value.operator,count,value.value)
        end,
        print = function(_, value)
            return string.format(L["Your %s weapon buff has %s"], (value.offhand and L["off hand"] or L["main hand"]),
                    Functions.presentation.compareString(value.operator, L["stacks"], Functions.presentation.nullable(value.value)))
        end,
        widget = function(parent, spec, value)
            local top = parent:GetUserData("top")
            local root = top:GetUserData("root")
            local funcs = top:GetUserData("funcs")

            local offhand = addon:CreateConditionCheckBox()
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
    icon = addon.Artwork.condition["SWING_TIME"],
    fields = { offhand = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local speed,reason=swingSpeed(value,cache)
        if speed==nil then return nil,reason end
        return Functions.values.compare(value.operator,speed,value.value)
    end,
    print = function(_, value)
        return string.format(L["Your %s weapon %s"], (value.offhand and L["off hand"] or L["main hand"]),
                Functions.presentation.compareString(value.operator, L["attack speed"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local offhand = addon:CreateConditionCheckBox()
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
    icon = addon.Artwork.condition["SWING_TIME_REMAIN"],
    fields = { offhand = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        local speed,reason=swingSpeed(value,cache)
        if speed==nil then return nil,reason end
        local lastSwing=addon.lastMainSwing;if value.offhand then lastSwing=addon.lastOffSwing end
        if lastSwing==nil or Functions.cache.getCached(cache, UnitCastingInfo, "player") or Functions.cache.getCached(cache, UnitChannelInfo, "player") then
            return Functions.values.compare(value.operator,speed,value.value)
        end
        return Functions.values.compare(value.operator,speed-math.max(evalStart-lastSwing,0),value.value)
    end,
    print = function(_, value)
        return string.format(L["Your %s weapon %s"], (value.offhand and L["off hand"] or L["main hand"]),
                Functions.presentation.compareString(value.operator, L["swing time remaining"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local offhand = addon:CreateConditionCheckBox()
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

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="enchantObservation" then return enchantObservation end
        if name=="helpers" then return helpers end
        if name=="numericObservation" then return numericObservation end
        if name=="swingSpeed" then return swingSpeed end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/weapon.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/weapon.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
