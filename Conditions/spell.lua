local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color = color

-- From constants
local operators = addon.operators

-- From utils
local compare, compareString, nullable, isin, getCached, round, isSpellOnSpec =
    addon.compare, addon.compareString, addon.nullable, addon.isin, addon.getCached, addon.round, addon.isSpellOnSpec

local helpers = addon.help_funcs
local CreateText, CreatePictureText, CreateButtonText, Indent, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.CreateButtonText, helpers.Indent, helpers.Gap

addon:RegisterCondition(L["Spells / Items"], "SPELL_AVAIL", {
    description = L["Spell Available"],
    icon = "Interface\\Icons\\Spell_holy_renew",
    valid = function(spec, value)
        if value.spell ~= nil then
            local name = GetSpellInfo(value.spell)
            return name ~= nil
        else
            return false
        end
    end,
    evaluate = function(value, cache, evalStart)
        local spellid = addon:Widget_GetSpellId(value.spell, value.ranked)
        local start, duration, enabled = getCached(cache, GetSpellCooldown, spellid)
        if start == 0 and duration == 0 then
            return true
        else
            -- A special spell that shows if the GCD is active ...
            local gcd_start, gcd_duration, gcd_enabled = getCached(cache, GetSpellCooldown, 61304)
            if gcd_start ~= 0 and gcd_duration ~= 0 then
                local time = GetTime()
                local gcd_remain = round(gcd_duration - (time - gcd_start), 3)
                local remain = round(duration - (time - start), 3)
                if (remain <= gcd_remain) then
                    return true
                -- We factor in a fuzziness because we don't know exactly when the spell cooldown calls
                -- were made, so we say any value between now and the evaluation start is essentially 0
                elseif (remain - gcd_remain <= time - evalStart) then
                    return true
                else
                    return false
                end
            end
            return false
        end
    end,
    print = function(spec, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s is available"], nullable(link, L["<spell>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
                                    function(v) return addon:GetSpecSpellID(spec, v) end,
                                    function(v) return isSpellOnSpec(spec, v) end,
                                    function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end
})

addon:RegisterCondition(L["Spells / Items"], "SPELL_COOLDOWN", {
    description = L["Spell Cooldown"],
    icon = "Interface\\Icons\\spell_nature_timestop",
    valid = function(spec, value)
        if value.spell ~= nil then
            local name = GetSpellInfo(value.spell)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    name ~= nil and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    evaluate = function(value, cache, evalStart) -- Cooldown until the spell is available
        local spellid = addon:Widget_GetSpellId(value.spell, value.ranked)
        local start, duration, enabled = getCached(cache, GetSpellCooldown, spellid)
        local remain = 0
        if start ~= 0 and duration ~= 0 then
            remain = round(duration - (GetTime() - start), 3)
            if (remain < 0) then remain = 0 end
        end
        return compare(value.operator, remain, value.value)
    end,
    print = function(spec, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["the %s"],
                compareString(value.operator, string.format(L["cooldown on %s"],  nullable(link, L["<spell>"])),
                string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
                                    function(v) return addon:GetSpecSpellID(spec, v) end,
                                    function(v) return isSpellOnSpec(spec, v) end,
                                    function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
                                    function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Cooldown"], L["Seconds"],
            "The number of seconds before you can cast " .. color.BLIZ_YELLOW .. L["Spell"] .. color.RESET .. ".")
    end
})

addon:RegisterCondition(L["Spells / Items"], "SPELL_REMAIN", {
    description = L["Spell Time Remaining"],
    icon = "Interface\\Icons\\inv_misc_pocketwatch_03",
    valid = function(spec, value)
        if value.spell ~= nil then
            local name = GetSpellInfo(value.spell)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    name ~= nil and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    evaluate = function(value, cache, evalStart) -- How long the spell remains effective
        local spellid = addon:Widget_GetSpellId(value.spell, value.ranked)
        local charges, maxcharges, start, duration = getCached(cache, GetSpellCharges, spellid)
        local remain = 0
        if (charges and charges >= 0) then
            remain = duration - (GetTime() - start)
        end
        return compare(value.operator, remain, value.value)
    end,
    print = function(spec, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["the %s"],
            compareString(value.operator, string.format(L["remaining time on %s"], nullable(link, L["<spell>"])),
                            string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon:GetSpecSpellID(spec, v) end,
            function(v) return isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Time Remaining"], L["Seconds"],
            "The number of seconds the effect of " .. color.BLIZ_YELLOW .. L["Spell"] .. color.RESET ..
            " has left.")
    end
})

addon:RegisterCondition(L["Spells / Items"], "SPELL_CHARGES", {
    description = L["Spell Charges"],
    icon = "Interface\\Icons\\Spell_nature_astralrecalgroup",
    valid = function(spec, value)
        if value.spell ~= nil then
            local name = GetSpellInfo(value.spell)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    name ~= nil and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    evaluate = function(value, cache, evalStart)
        local spellid = addon:Widget_GetSpellId(value.spell, value.ranked)
        local charges, maxcharges, start, duration = getCached(cache, GetSpellCharges, spellid)
        return compare(value.operator, charges, value.value)
    end,
    print = function(spec, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["the %s"],
            compareString(value.operator, string.format(L["number of charges on %s"], nullable(link, L["<spell>"])), nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon:GetSpecSpellID(spec, v) end,
            function(v) return isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Charges"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Charges"], L["Charges"],
            "The number of charges of " .. color.BLIZ_YELLOW .. L["Spell"] .. color.RESET .. " currently active.")
    end
})

addon:RegisterCondition(L["Spells / Items"], "SPELL_HISTORY", {
    description = L["Spell Cast History"],
    icon = "Interface\\Icons\\Spell_shadow_nightofthedead",
    valid = function(spec, value)
        if value.spell ~= nil then
            local name = GetSpellInfo(value.spell)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    name ~= nil and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    evaluate = function(value, cache, evalStart)
        for idx, entry in pairs(addon.spellHistory) do
            if entry.spell == value.spell then
                local spellid = addon:Widget_GetSpellId(value.spell, value.ranked)
                return compare(value.operator, idx, spellid)
            end
        end
        return false
    end,
    print = function(spec, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return compareString(value.operator, string.format(L["%s was cast"], nullable(link, L["<spell>"])),
                        string.format(L["%s casts ago"], nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon:GetSpecSpellID(spec, v) end,
            function(v) return isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Cast History"], L["Count"],
            "How far back in your spell history to look for a casting of " .. color.BLIZ_YELLOW .. L["Spell"] ..
            color.RESET .. " (by count).  A value of 1 means your last spell cast, 2 means two spells ago, etc.  " ..
            "Each instance of a the same spell cast is treated separately.  Any spell cast more than the setting " ..
            "of " .. color.BLUE .. L["Spell History Memory (seconds)"] .. color.RESET .. " in the primary Rotation " ..
            "Master configuration screen ago will not be available.")
    end
})

addon:RegisterCondition(L["Spells / Items"], "SPELL_HISTORY_TIME", {
    description = L["Spell Cast History Time"],
    icon = "Interface\\Icons\\Spell_fire_sealoffire",
    valid = function(spec, value)
        if value.spell ~= nil then
            local name = GetSpellInfo(value.spell)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    name ~= nil and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    evaluate = function(value, cache, evalStart) -- Cooldown until the spell is available
        for idx, entry in pairs(addon.spellHistory) do
            local spellid = addon:Widget_GetSpellId(value.spell, value.ranked)
            if entry.spell == spellid then
                return compare(value.operator, (evalStart - entry.time), value.value)
            end
        end
        return false
    end,
    print = function(spec, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return compareString(value.operator, string.format(L["%s was cast"], nullable(link, L["<spell>"])),
                string.format(L["%s seconds ago"], nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spec_EditBox", value,
            function(v) return addon:GetSpecSpellID(spec, v) end,
            function(v) return isSpellOnSpec(spec, v) end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
        frame:AddChild(Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Spell Cast History Time"], L["Seconds"],
            "How far back in your spell history to look for a casting of " .. color.BLIZ_YELLOW .. L["Spell"] ..
            color.RESET .. " (by time).  Any spell cast more than the setting of " .. color.BLUE ..
            L["Spell History Memory (seconds)"] .. color.RESET .. " in the primary Rotation Master configuration " ..
            "screen ago will not be available.")
    end
})

