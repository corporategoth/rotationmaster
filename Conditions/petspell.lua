local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local color = color

-- From constants
local operators = addon.operators

-- From utils
local compare, compareString, nullable, isin, getCached, round =
    addon.compare, addon.compareString, addon.nullable, addon.isin, addon.getCached, addon.round

local helpers = addon.help_funcs
local CreateText, CreatePictureText, CreateButtonText, Indent, Gap =
helpers.CreateText, helpers.CreatePictureText, helpers.CreateButtonText, helpers.Indent, helpers.Gap

addon:RegisterCondition(L["Spells / Items"], "PETSPELL_AVAIL", {
    description = L["Pet Spell Available"],
    icon = "Interface\\Icons\\Ability_druid_bash",
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

        local spell_group = addon:Widget_SpellWidget(spec, "Spell_EditBox", value,
            function(v) return select(7, GetSpellInfo(v)) end,
            function(v) return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end
})

addon:RegisterCondition(L["Spells / Items"], "PETSPELL_RANGE", {
    description = L["Pet Spell In Range"],
    icon = "Interface\\Icons\\inv_misc_bandage_03",
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
        if spellid then
            local sbid = getCached(addon.longtermCache, FindSpellBookSlotBySpellID, spellid, true)
            if sbid then
                return (getCached(cache, IsSpellInRange, sbid, BOOKTYPE_PET, "target") == 1)
            end
        end
        return false
    end,
    print = function(spec, value)
        local link = addon:Widget_GetSpellLink(value.spell, value.ranked)
        return string.format(L["%s is in range"], nullable(link, L["<spell>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = addon:Widget_SpellWidget(spec, "Spell_EditBox", value,
            function(v) return select(7, GetSpellInfo(v)) end,
            function(v) return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(spell_group)
    end,
    help = function(frame)
        addon.layout_condition_spellwidget_help(frame)
    end
})

addon:RegisterCondition(L["Spells / Items"], "PETSPELL_COOLDOWN", {
    description = L["Pet Spell Cooldown"],
    icon = "Interface\\Icons\\Spell_nature_sleep",
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

        local spell_group = addon:Widget_SpellWidget(spec, "Spell_EditBox", value,
            function(v) return select(7, GetSpellInfo(v)) end,
            function(v) return true end,
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

addon:RegisterCondition(L["Spells / Items"], "PETSPELL_REMAIN", {
    description = L["Pet Spell Time Remaining"],
    icon = "Interface\\Icons\\spell_nature_polymorph",
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

        local spell_group = addon:Widget_SpellWidget(spec, "Spell_EditBox", value,
            function(v) return select(7, GetSpellInfo(v)) end,
            function(v) return true end,
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

addon:RegisterCondition(L["Spells / Items"], "PETSPELL_CHARGES", {
    description = L["Pet Spell Charges"],
    icon = "Interface\\Icons\\Ability_mount_nightmarehorse",
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

        local spell_group = addon:Widget_SpellWidget(spec, "Spell_EditBox", value,
            function(v) return select(7, GetSpellInfo(v)) end,
            function(v) return true end,
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
