local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tostring, tonumber, pairs = tostring, tonumber, pairs
local floor = math.floor

-- From constants
local operators, units, unitsPossessive, classes, roles, debufftypes, zonepvp, instances, totems =
addon.operators, addon.units, addon.unitsPossessive, addon.classes, addon.roles, addon.debufftypes,
addon.zonepvp, addon.instances, addon.totems

-- From utils
local compare, compareString, nullable, keys, tomap, isin, cleanArray, deepcopy, getCached, isSpellOnSpec, round =
addon.compare, addon.compareString, addon.nullable, addon.keys, addon.tomap,
addon.isin, addon.cleanArray, addon.deepcopy, addon.getCached, addon.isSpellOnSpec, addon.round

addon:RegisterCondition("SPELL_AVAIL", {
    description = L["Spell Available"],
    icon = "Interface\\Icons\\spell_burningsoul",
    valid = function(spec, value)
        if value.spell ~= nil then
            local name = GetSpellInfo(value.spell)
            return name ~= nil
        else
            return false
        end
    end,
    evaluate = function(value, cache, evalStart)
        local start, duration, enabled = getCached(cache, GetSpellCooldown, value.spell)
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
        local link
        if value.spell ~= nil then
            link = GetSpellLink(value.spell)
        end
        return string.format(L["%s is available"], nullable(link, L["<spell>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell = AceGUI:Create("Spec_EditBox")
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        if (value.spell) then
            spellIcon:SetText(value.spell)
        end
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon.text:Hide()
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(spec, v) then
                value.spell = v
                spellIcon:SetText(v)
                if v then
                    spell:SetText(GetSpellInfo(v))
                else
                    spell:SetText("")
                end
                top:SetStatusText(funcs:print(root, spec))
            end
        end)
        parent:AddChild(spellIcon)

        spell:SetLabel(L["Spell"])
        if (value.spell) then
            spell:SetText(GetSpellInfo(value.spell))
        end
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            value.spell = addon:GetSpecSpellID(spec, v)
            spellIcon:SetText(value.spell)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(spell)

    end,
})

addon:RegisterCondition("SPELL_COOLDOWN", {
    description = L["Spell Cooldown"],
    icon = "Interface\\Icons\\spell_nature_timestop",
    valid = function(spec, value)
        if value.spell ~= nil then
            local name, icon, castTime, minRange, maxRange = GetSpellInfo(value.spell)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    name ~= nil and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    evaluate = function(value, cache, evalStart) -- Cooldown until the spell is available
        local start, duration, enabled = getCached(cache, GetSpellCooldown, value.spell)
        local remain = 0
        if start ~= 0 and duration ~= 0 then
            remain = round(duration - (GetTime() - start), 3)
            if (remain < 0) then remain = 0 end
        end
        return compare(value.operator, remain, value.value)
    end,
    print = function(spec, value)
        local link
        if value.spell ~= nil then
            link = GetSpellLink(value.spell)
        end
        return string.format(L["the %s"],
                compareString(value.operator, string.format(L["cooldown on %s"],  nullable(link, L["<spell>"])),
                string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell = AceGUI:Create("Spec_EditBox")
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        if (value.spell) then
            spellIcon:SetText(value.spell)
        end
        spellIcon.text:Hide()
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(spec, v) then
                value.spell = v
                spellIcon:SetText(v)
                if v then
                    spell:SetText(GetSpellInfo(v))
                else
                    spell:SetText("")
                end
                top:SetStatusText(funcs:print(root, spec))
            end
        end)
        parent:AddChild(spellIcon)

        spell:SetLabel(L["Spell"])
        if (value.spell) then
            spell:SetText(GetSpellInfo(value.spell))
        end
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            value.spell = addon:GetSpecSpellID(spec, v)
            spellIcon:SetText(value.spell)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(spell)

        local operator = AceGUI:Create("Dropdown")
        operator:SetLabel(L["Operator"])
        operator:SetList(operators, keys(operators))
        if (value.operator ~= nil) then
            operator:SetValue(value.operator)
        end
        operator:SetCallback("OnValueChanged", function(widget, event, v)
            value.operator = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(operator)

        local health = AceGUI:Create("EditBox")
        health:SetLabel(L["Seconds"])
        health:SetWidth(100)
        if (value.value ~= nil) then
            health:SetText(value.value)
        end
        health:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(health)
    end,
})

addon:RegisterCondition("SPELL_REMAIN", {
    description = L["Spell Time Remaining"],
    icon = "Interface\\Icons\\inv_misc_pocketwatch_01",
    valid = function(spec, value)
        if value.spell ~= nil then
            local name, icon, castTime, minRange, maxRange = GetSpellInfo(value.spell)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    name ~= nil and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    evaluate = function(value, cache, evalStart) -- How long the spell remains effective
        local charges, maxcharges, start, duration = getCached(cache, GetSpellCharges, value.spell)
        local remain = 0
        if (charges and charges >= 0) then
            remain = duration - (GetTime() - start)
        end
        return compare(value.operator, remain, value.value)
    end,
    print = function(spec, value)
        local link
        if value.spell ~= nil then
            link = GetSpellLink(value.spell)
        end
        return string.format(L["the %s"],
            compareString(value.operator, string.format(L["remaining time on %s"], nullable(link, L["<spell>"])),
                            string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell = AceGUI:Create("Spec_EditBox")
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        if (value.spell) then
            spellIcon:SetText(value.spell)
        end
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon.text:Hide()
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(spec, v) then
                value.spell = v
                spellIcon:SetText(v)
                if v then
                    spell:SetText(GetSpellInfo(v))
                else
                    spell:SetText("")
                end
                top:SetStatusText(funcs:print(root, spec))
            end
        end)
        parent:AddChild(spellIcon)

        spell:SetLabel(L["Spell"])
        if (value.spell) then
            spell:SetText(GetSpellInfo(value.spell))
        end
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            value.spell = addon:GetSpecSpellID(spec, v)
            spellIcon:SetText(value.spell)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(spell)

        local operator = AceGUI:Create("Dropdown")
        operator:SetLabel(L["Operator"])
        operator:SetList(operators, keys(operators))
        if (value.operator ~= nil) then
            operator:SetValue(value.operator)
        end
        operator:SetCallback("OnValueChanged", function(widget, event, v)
            value.operator = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(operator)

        local health = AceGUI:Create("EditBox")
        health:SetLabel(L["Seconds"])
        health:SetWidth(100)
        if (value.value ~= nil) then
            health:SetText(value.value)
        end
        health:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(health)
    end,
})

addon:RegisterCondition("SPELL_CHARGES", {
    description = L["Spell Charges"],
    icon = "Interface\\Icons\\spell_fire_felrainoffire",
    valid = function(spec, value)
        if value.spell ~= nil then
            local name, icon, castTime, minRange, maxRange = GetSpellInfo(value.spell)
            return (value.operator ~= nil and isin(operators, value.operator) and
                    name ~= nil and value.value ~= nil and value.value >= 0)
        else
            return false
        end
    end,
    evaluate = function(value, cache, evalStart)
        local charges, maxcharges, start, duration = getCached(cache, GetSpellCharges, value.spell)
        return compare(value.operator, charges, value.value)
    end,
    print = function(spec, value)
        local link
        if value.spell ~= nil then
            link = GetSpellLink(value.spell)
        end
        return string.format(L["the %s"],
            compareString(value.operator, string.format(L["number of charges on %s"], nullable(link, L["<spell>"])), nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell = AceGUI:Create("Spec_EditBox")
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        if (value.spell) then
            spellIcon:SetText(value.spell)
        end
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon.text:Hide()
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(spec, v) then
                value.spell = v
                spellIcon:SetText(v)
                if v then
                    spell:SetText(GetSpellInfo(v))
                else
                    spell:SetText("")
                end
                top:SetStatusText(funcs:print(root, spec))
            end
        end)
        parent:AddChild(spellIcon)

        spell:SetLabel(L["Spell"])
        if (value.spell) then
            spell:SetText(GetSpellInfo(value.spell))
        end
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            value.spell = addon:GetSpecSpellID(spec, v)
            spellIcon:SetText(value.spell)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(spell)

        local operator = AceGUI:Create("Dropdown")
        operator:SetLabel(L["Operator"])
        operator:SetList(operators, keys(operators))
        if (value.operator ~= nil) then
            operator:SetValue(value.operator)
        end
        operator:SetCallback("OnValueChanged", function(widget, event, v)
            value.operator = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(operator)

        local health = AceGUI:Create("EditBox")
        health:SetLabel(L["Charges"])
        health:SetWidth(100)
        if (value.value ~= nil) then
            health:SetText(value.value)
        end
        health:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(health)
    end,
})
