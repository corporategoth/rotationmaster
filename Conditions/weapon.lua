-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Weapon conditions: WEAPON, WEAPON_REMAIN and WEAPON_STACKS (a temporary enchant such as a poison or imbue on the main
-- or off hand) and SWING_TIME and SWING_TIME_REMAIN (the melee or ranged attack interval, and the time left in it).
-- Enchant reads come from GetWeaponEnchantInfo, or on Retail from the tuple Platform/items.lua composes out of
-- C_PaperDollInfo.GetTemporaryEnchantmentInfo; swing speeds come from UnitAttackSpeed and Platform:GetRangedSwingSpeed,
-- and the swing remainder needs the timestamps main.lua records from the combat log (addon.lastMainSwing,
-- lastOffSwing, lastRangedShot), so it cannot work where the log is hidden (Core/condition_support.lua). Every value
-- passes platform:CanReadValue before it is compared; an unreadable one is unavailable, not false. Loaded from the
-- Conditions group of RotationMaster.toc, after Conditions/spatial_stats.lua. The callback and helper bodies are
-- frozen: saved custom conditions bind to their exact text, and the generated block at the end is written by a tool.
local addon_name, addon = ...

local runtimeCondition = addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness(
    'Conditions/weapon.lua'
)
    or function(_, definition) return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- These pure dependencies are selected from their owning modules and remain
-- private to the authored callbacks and their editable source copies.
local Functions = {
    cache = { getCached = addon.Functions.cache.getCached },
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        compareString = addon.Functions.presentation.compareString,
        nullable = addon.Functions.presentation.nullable,
    },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/weapon.lua"] = {
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
}

-- ============================================================================
-- Observation helpers
-- ============================================================================

-- Select the requested hand before interpreting observations. Lua's and/or
-- shorthand falls through to the other hand when the selected value is false.
-- The Platform reader is GetWeaponEnchantInfo, or the same tuple composed from
-- Retail's C_PaperDollInfo.GetTemporaryEnchantmentInfo where that exists.
-- Returns true, expiresMilliseconds, charges when the hand is enchanted, false when it is not, and nil, nil, nil and a
-- reason (missing-api, api-error, restricted-value, invalid-weapon-observation) when it cannot be read.
local function enchantObservation(value, cache)
    local reader=GetWeaponEnchantInfo
    if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then reader=addon.Platform.ComposedWeaponEnchantInfo end
    if type(reader)~="function" then return nil,nil,nil,"missing-api" end
    -- The protected cached API returns both hands' original tuple unchanged.
    ---@diagnostic disable-next-line: unbalanced-assignments
    local ok, main, mainExpires, mainCharges, _, off, offExpires, offCharges = pcall(addon.getCached, cache, reader)
    if not ok then return nil,nil,nil,"api-error" end
    local enchanted, expires, charges=main,mainExpires,mainCharges
    if value.offhand then enchanted,expires,charges=off,offExpires,offCharges end
    if not addon.Platform:CanReadValue(enchanted) then return nil,nil,nil,"restricted-value" end
    if enchanted==nil or enchanted==false or enchanted==0 then return false end
    if enchanted~=true and enchanted~=1 then return nil,nil,nil,"invalid-weapon-observation" end
    return true,expires,charges
end

-- Accepts one numeric weapon reading: returns it, or nil and a reason (restricted-value when hidden,
-- invalid-weapon-observation when it is not a finite, non-negative number).
local function numericObservation(value)
    if not addon.Platform:CanReadValue(value) then return nil,"restricted-value" end
    if type(value)~="number" or value~=value or value<0 or value==math.huge then return nil,"invalid-weapon-observation" end
    return value
end

-- The swing interval in seconds for the hand or the ranged weapon the condition selects. Returns the seconds, false
-- when there is no off-hand weapon (or no ranged attack), or nil and a reason when the speed is unreadable.
local function swingSpeed(value, cache)
    -- Ranged: the Auto Shot or wand interval (UnitRangedDamage), false with no
    -- ranged attack; the melee hands read UnitAttackSpeed.
    if value.ranged then
        local speed,reason=Functions.cache.getCached(cache,addon.Platform.GetRangedSwingSpeed,addon.Platform)
        if speed==nil then return nil,reason end
        return speed
    end
    if type(UnitAttackSpeed)~="function" then return nil,"missing-api" end
    -- pcall forwards the mainhand and offhand speeds from the observation.
    ---@diagnostic disable-next-line: unbalanced-assignments
    local ok,main,off=pcall(addon.getCached,cache,UnitAttackSpeed,"player")
    if not ok then return nil,"api-error" end
    local speed=main
    if value.offhand then
        speed=off
        -- No off-hand weapon: the API returns no off-hand speed. That is a
        -- reading (nothing to swing), so off-hand checks are false.
        if speed==nil then return false end
    end
    return numericObservation(speed)
end

-- ============================================================================
-- Temporary weapon enchants
-- ============================================================================

-- Temporary weapon enchants on every client, Retail included: Shaman imbues
-- are weapon enchants there again. Unreadable values stay unavailable.
do
    -- WEAPON tests that the selected hand carries a temporary enchant. Returns false when it does not, and nil and a
    -- reason when the enchant data cannot be read. Stores offhand (main hand when unset). It is also the one
    -- condition here declared pure for the lean engine (see DeclareOwnedConditionRuntime below), hence the witness.
    addon:RegisterCondition("WEAPON", runtimeCondition('WEAPON', {
        description = L["Weapon Enchant Present"],
        icon = addon.Artwork.condition["WEAPON"],
        fields = { offhand = "boolean" },
        -- Always valid: the only field is an optional checkbox.
        valid = function()
            return true
        end,
        -- Unavailable: missing-api, api-error, restricted-value or invalid-weapon-observation from the enchant read.
        evaluate = function(value, cache)
            local enchanted, _, _, reason=enchantObservation(value,cache)
            return enchanted,reason
        end,
        -- Summary line for the condition list.
        print = function(_, value)
            return string.format(L["Your %s weapon {{!is|is not}} enchanted"],
                    (value.offhand and L["off hand"] or L["main hand"]))
        end,
        -- Editor: the Off Hand checkbox.
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
        -- Help page: what the Off Hand checkbox selects.
        help = function(frame)
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Off Hand"] .. color.RESET .. " - " ..
                    "Should this condition affect your main or off-hand weapon.  If this is checked, it will affect " ..
                    "your off-hand weapon, otherwise it will affect your main-hand (or two-handed) weapon."))
        end,
    }))

    -- WEAPON_REMAIN compares the seconds left on the selected hand's temporary enchant. Returns false when the hand has
    -- no enchant, and nil and a reason when the enchant or its expiry cannot be read. Stores offhand, operator and
    -- value (seconds); the game reports the expiry in milliseconds.
    addon:RegisterCondition("WEAPON_REMAIN", {
        description = L["Weapon Enchant Time Remaining"],
        icon = addon.Artwork.condition["WEAPON_REMAIN"],
        fields = { offhand = "boolean", operator = "string", value = "number" },
        -- Valid with a listed operator and a non-negative number of seconds.
        valid = function(_, value)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    value.value ~= nil and value.value >= 0)
        end,
        -- Unavailable: any reason from the enchant read, or restricted-value or invalid-weapon-observation for the
        -- expiry.
        evaluate = function(value, cache)
            local enchanted, expires, _, reason=enchantObservation(value,cache)
            if enchanted==nil then return nil,reason end
            if not enchanted then return false end
            local duration,why=numericObservation(expires)
            if duration==nil then return nil,why end
            return Functions.values.compare(value.operator,duration/1000,value.value)
        end,
        -- Summary line for the condition list.
        print = function(_, value)
            return Functions.presentation.compareString(value.operator,
                    string.format(L["the time remaining on your %s weapon buff"], (value.offhand and L["off hand"] or L["main hand"])),
                    string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
        end,
        -- Editor: the Off Hand checkbox, then the operator and seconds.
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
        -- Help page: the Off Hand checkbox, then the operator text.
        help = function(frame)
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Off Hand"] .. color.RESET .. " - " ..
                    "Should this condition affect your main or off-hand weapon.  If this is checked, it will affect " ..
                    "your off-hand weapon, otherwise it will affect your main-hand (or two-handed) weapon."))

            frame:AddChild(helpers.Gap())
            addon.layout_condition_operatorwidget_help(frame, L["Weapon Enchant Time Remaining"], L["Seconds"],
                    "The amount of time (in seconds) your weapon buff has left before it expires.  If there is no buff " ..
                            "on your weapon, this condition will not be successful (regardless of the " .. color.BLIZ_YELLOW ..
                            "Operator" .. color.RESET .. " used.)")
        end,
    })

    -- WEAPON_STACKS compares the charges (stacks) of the selected hand's temporary enchant. Returns false when the
    -- hand has no enchant, and nil and a reason when the enchant or its charge count cannot be read. Stores offhand,
    -- operator and value (a count).
    addon:RegisterCondition("WEAPON_STACKS", {
        description = L["Weapon Enchant Stacks"],
        icon = addon.Artwork.condition["WEAPON_STACKS"],
        fields = { offhand = "boolean", operator = "string", value = "number" },
        -- Valid with a listed operator and a non-negative count.
        valid = function(_, value)
            return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                    value.value ~= nil and value.value >= 0)
        end,
        -- Unavailable: any reason from the enchant read, or restricted-value or invalid-weapon-observation for the
        -- count.
        evaluate = function(value, cache)
            local enchanted, _, charges, reason=enchantObservation(value,cache)
            if enchanted==nil then return nil,reason end
            if not enchanted then return false end
            local count,why=numericObservation(charges)
            if count==nil then return nil,why end
            return Functions.values.compare(value.operator,count,value.value)
        end,
        -- Summary line for the condition list.
        print = function(_, value)
            return Functions.presentation.compareString(value.operator,
                    string.format(L["the number of stacks of your %s weapon buff"], (value.offhand and L["off hand"] or L["main hand"])),
                    Functions.presentation.nullable(value.value))
        end,
        -- Editor: the Off Hand checkbox, then the operator and stack count.
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
        -- Help page: the Off Hand checkbox, then the operator text.
        help = function(frame)
            frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Off Hand"] .. color.RESET .. " - " ..
                    "Should this condition affect your main or off-hand weapon.  If this is checked, it will affect " ..
                    "your off-hand weapon, otherwise it will affect your main-hand (or two-handed) weapon."))

            frame:AddChild(helpers.Gap())
            addon.layout_condition_operatorwidget_help(frame, L["Weapon Enchant Stacks"], L["Stacks"],
                    "The number of stacks of a buff applied to your weapon.  If there is no buff on your weapon, this " ..
                            "condition will not be successful (regardless of the " .. color.BLIZ_YELLOW .. "Operator" ..
                            color.RESET .. " used.)")
        end,
    })
end

-- ============================================================================
-- Swing timers
-- ============================================================================

-- SWING_TIME compares the weapon's full attack interval in seconds (its attack speed). Returns false when the chosen
-- off-hand or ranged weapon does not exist, and nil and a reason when the speed cannot be read. Stores offhand, ranged,
-- operator and value; valid refuses a condition that selects both the off hand and the ranged weapon.
addon:RegisterCondition("SWING_TIME", {
    description = L["Weapon Swing Time"],
    icon = addon.Artwork.condition["SWING_TIME"],
    fields = { offhand = "boolean", ranged = "boolean", operator = "string", value = "number" },
    -- Valid with a listed operator, a non-negative number of seconds, and not both offhand and ranged.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and (value.ranged == nil or type(value.ranged) == "boolean") and
                not (value.ranged and value.offhand))
    end,
    -- Unavailable: missing-api, api-error, restricted-value, invalid-weapon-observation, or the reason from
    -- Platform:GetRangedSwingSpeed for the ranged weapon.
    evaluate = function(value, cache)
        local speed,reason=swingSpeed(value,cache)
        if speed==nil then return nil,reason end
        if speed==false then return false end
        return Functions.values.compare(value.operator,speed,value.value)
    end,
    -- Summary line for the condition list.
    print = function(_, value)
        return string.format(L["Your %s weapon %s"], (value.ranged and L["ranged"] or value.offhand and L["off hand"] or L["main hand"]),
                Functions.presentation.compareString(value.operator, L["attack speed"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    -- Editor: the Off Hand and Ranged checkboxes (ticking one clears the other), then the operator and seconds.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local offhand = addon:CreateConditionCheckBox()
        local ranged = addon:CreateConditionCheckBox()
        offhand:SetWidth(100)
        offhand:SetLabel(L["Off Hand"])
        offhand:SetValue(value.offhand and true or false)
        offhand:SetCallback("OnValueChanged", function(_, _, v)
            value.offhand = v
            -- One weapon at a time: the off hand and the ranged weapon exclude each other.
            if v and value.ranged then value.ranged = nil;ranged:SetValue(false) end
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(offhand)

        ranged:SetWidth(100)
        ranged:SetLabel(L["Ranged"])
        ranged:SetValue(value.ranged and true or false)
        ranged:SetCallback("OnValueChanged", function(_, _, v)
            value.ranged = v or nil
            if v and value.offhand then value.offhand = nil;offhand:SetValue(false) end
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(ranged)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Help page: the Off Hand and Ranged checkboxes, then the operator text.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Off Hand"] .. color.RESET .. " - " ..
                "Should this condition affect your main or off-hand weapon.  If this is checked, it will affect " ..
                "your off-hand weapon, otherwise it will affect your main-hand (or two-handed) weapon."))
        frame:AddChild(helpers.CreateText(L["With no off-hand weapon equipped, an off-hand check is false (and true under NOT)."]))
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Ranged"] .. color.RESET .. " - " .. L["Help.Conditions.SWING_RANGED"]))

        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Attack Speed"], L["Seconds"],
                "The amount of time (in seconds) between swing times for your weapon.")
    end,
})

-- SWING_TIME_REMAIN compares the seconds left until the weapon's next swing. The remainder is the attack interval minus
-- the time since the last swing or ranged shot that main.lua saw in the combat log; with no recorded swing, or while a
-- cast or channel is running, it reads the full interval. Returns false for a missing off-hand or ranged weapon, and
-- nil and a reason when the speed is unreadable. Stores offhand, ranged, operator and value.
addon:RegisterCondition("SWING_TIME_REMAIN", {
    description = L["Weapon Swing Time Remaining"],
    icon = addon.Artwork.condition["SWING_TIME_REMAIN"],
    fields = { offhand = "boolean", ranged = "boolean", operator = "string", value = "number" },
    -- Valid with a listed operator, a non-negative number of seconds, and not both offhand and ranged.
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and (value.ranged == nil or type(value.ranged) == "boolean") and
                not (value.ranged and value.offhand))
    end,
    -- Unavailable: the same reasons as SWING_TIME. evalStart is the poll's time, which the last swing is measured from.
    evaluate = function(value, cache, evalStart)
        local speed,reason=swingSpeed(value,cache)
        if speed==nil then return nil,reason end
        if speed==false then return false end
        if value.ranged then
            -- The ranged timer runs from the last Auto Shot or wand shot the combat log
            -- showed. It is not reset by a cast or a target change; before the first
            -- shot of a fight it reads the full weapon interval.
            local lastShot=addon.lastRangedShot
            if lastShot==nil then return Functions.values.compare(value.operator,speed,value.value) end
            return Functions.values.compare(value.operator,math.max(speed-math.max(evalStart-lastShot,0),0),value.value)
        end
        local lastSwing=addon.lastMainSwing;if value.offhand then lastSwing=addon.lastOffSwing end
        if lastSwing==nil or Functions.cache.getCached(cache, UnitCastingInfo, "player") or Functions.cache.getCached(cache, UnitChannelInfo, "player") then
            return Functions.values.compare(value.operator,speed,value.value)
        end
        return Functions.values.compare(value.operator,math.max(speed-math.max(evalStart-lastSwing,0),0),value.value)
    end,
    -- Summary line for the condition list.
    print = function(_, value)
        return string.format(L["Your %s weapon %s"], (value.ranged and L["ranged"] or value.offhand and L["off hand"] or L["main hand"]),
                Functions.presentation.compareString(value.operator, L["swing time remaining"], string.format(L["%s seconds"], Functions.presentation.nullable(value.value))))
    end,
    -- Editor: the Off Hand and Ranged checkboxes (ticking one clears the other), then the operator and seconds.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local offhand = addon:CreateConditionCheckBox()
        local ranged = addon:CreateConditionCheckBox()
        offhand:SetWidth(100)
        offhand:SetLabel(L["Off Hand"])
        offhand:SetValue(value.offhand and true or false)
        offhand:SetCallback("OnValueChanged", function(_, _, v)
            value.offhand = v
            -- One weapon at a time: the off hand and the ranged weapon exclude each other.
            if v and value.ranged then value.ranged = nil;ranged:SetValue(false) end
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(offhand)

        ranged:SetWidth(100)
        ranged:SetLabel(L["Ranged"])
        ranged:SetValue(value.ranged and true or false)
        ranged:SetCallback("OnValueChanged", function(_, _, v)
            value.ranged = v or nil
            if v and value.offhand then value.offhand = nil;offhand:SetValue(false) end
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(ranged)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Help page: the Off Hand and Ranged checkboxes, then the operator text.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Off Hand"] .. color.RESET .. " - " ..
                "Should this condition affect your main or off-hand weapon.  If this is checked, it will affect " ..
                "your off-hand weapon, otherwise it will affect your main-hand (or two-handed) weapon."))
        frame:AddChild(helpers.CreateText(L["With no off-hand weapon equipped, an off-hand check is false (and true under NOT)."]))
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Ranged"] .. color.RESET .. " - " .. L["Help.Conditions.SWING_RANGED"]))

        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Swing Time Remaining"], L["Seconds"],
                "The amount of time (in seconds) until your next weapon swing.")
    end,
})

-- Source-owned configuration validators and optional notification facts.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/weapon.lua', { WEAPON = { pure = true } })
end

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
