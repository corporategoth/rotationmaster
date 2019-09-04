local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local tostring, tonumber, pairs = tostring, tonumber, pairs
local floor = math.floor

-- From constants
local operators, units, unitsPossessive, classes, roles, debufftypes, zonepvp, instances, totems =
addon.operators, addon.units, addon.unitsPossessive, addon.classes, addon.roles, addon.debufftypes,
addon.zonepvp, addon.instances, addon.totems

-- From utils
local compare, compareString, nullable, keys, tomap, isin, isint, cleanArray, deepcopy, getCached, isSpellOnSpec, round =
addon.compare, addon.compareString, addon.nullable, addon.keys, addon.tomap,
addon.isin, addon.isint, addon.cleanArray, addon.deepcopy, addon.getCached, addon.isSpellOnSpec, addon.round

addon:RegisterCondition("SPELL_AVAIL", {
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
        local spellid = value.spell
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            if not value.ranked then
                spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                    select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
            end
        end
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
        local link
        if value.spell ~= nil then
            local spellid = value.spell
            if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
                if not value.ranked then
                    spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                        select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
                end
            end
            link = GetSpellLink(spellid)
        end
        return string.format(L["%s is available"], nullable(link, L["<spell>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = AceGUI:Create("SimpleGroup")
        parent:AddChild(spell_group)
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        spell_group:AddChild(spellIcon)
        local ranked, nr_label, nr_button
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked = AceGUI:Create("SimpleGroup")
            spell_group:AddChild(ranked)
            nr_label = AceGUI:Create("Label")
            ranked:AddChild(nr_label)
            nr_button = AceGUI:Create("CheckBox")
            ranked:AddChild(nr_button)
        end
        local spell = AceGUI:Create("Spec_EditBox")
        spell_group:AddChild(spell)

        spell_group:SetLayout("Table")
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
		spell_group:SetUserData("table", { columns = { 44, 0.1, 1 } })
	else
		spell_group:SetUserData("table", { columns = { 44, 1 } })
	end

        spellIcon:SetText(value.spell)
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon.text:Hide()
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(spec, v) then
                value.spell = v
                spellIcon:SetText(v)
                if v then
                    spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                else
                    spell:SetText(nil)
                end
                top:SetStatusText(funcs:print(root, spec))
            end
        end)

        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked:SetFullWidth(true)
            ranked:SetLayout("Table")
            ranked:SetUserData("table", { columns = { 1 } })
            ranked:SetUserData("cell", { alignV = "bottom", alignH = "center" })

            nr_label:SetText(L["Rank"])
            nr_label:SetColor(1.0, 0.82, 0.0)

            nr_button:SetValue(value.ranked or false)
            nr_button:SetCallback("OnValueChanged", function(widget, event, val)
                value.ranked = val
                spell:SetUserData("norank", not val)
                spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                top:SetStatusText(funcs:print(root, spec))
            end)
        end

        spell:SetLabel(L["Spell"])
        spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
        spell:SetUserData("norank", not value.ranked)
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            if isint(v) then
                if isSpellOnSpec(spec, tonumber(v)) then
                    value.spell = tonumber(v)
                else
                    value.spell = nil
                    spell:SetText(nil)
                end
            else
                value.spell = addon:GetSpecSpellID(spec, v)
                if value.spell == nil then
                    spell:SetText(nil)
                end
            end
            spellIcon:SetText(value.spell)
            top:SetStatusText(funcs:print(root, spec))
        end)

    end,
})

addon:RegisterCondition("SPELL_COOLDOWN", {
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
        local spellid = value.spell
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            if not value.ranked then
                spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                    select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
            end
        end
        local start, duration, enabled = getCached(cache, GetSpellCooldown, spellid)
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
            local spellid = value.spell
            if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
                if not value.ranked then
                    spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                        select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
                end
            end
            link = GetSpellLink(spellid)
        end
        return string.format(L["the %s"],
                compareString(value.operator, string.format(L["cooldown on %s"],  nullable(link, L["<spell>"])),
                string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = AceGUI:Create("SimpleGroup")
        parent:AddChild(spell_group)
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        spell_group:AddChild(spellIcon)
        local ranked, nr_label, nr_button
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked = AceGUI:Create("SimpleGroup")
            spell_group:AddChild(ranked)
            nr_label = AceGUI:Create("Label")
            ranked:AddChild(nr_label)
            local nr_button = AceGUI:Create("CheckBox")
            ranked:AddChild(nr_button)
        end
        local spell = AceGUI:Create("Spec_EditBox")
        spell_group:AddChild(spell)
        local operator = AceGUI:Create("Dropdown")
        parent:AddChild(operator)
        local health = AceGUI:Create("EditBox")
        parent:AddChild(health)

        spell_group:SetLayout("Table")
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
		spell_group:SetUserData("table", { columns = { 44, 0.1, 1 } })
	else
		spell_group:SetUserData("table", { columns = { 44, 1 } })
	end

        spellIcon:SetText(value.spell)
        spellIcon.text:Hide()
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(spec, v) then
                value.spell = v
                spellIcon:SetText(v)
                if v then
                    spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                else
                    spell:SetText(nil)
                end
                top:SetStatusText(funcs:print(root, spec))
            end
        end)

        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked:SetFullWidth(true)
            ranked:SetLayout("Table")
            ranked:SetUserData("table", { columns = { 1 } })
            ranked:SetUserData("cell", { alignV = "bottom", alignH = "center" })

            nr_label:SetText(L["Rank"])
            nr_label:SetColor(1.0, 0.82, 0.0)

            nr_button:SetValue(value.ranked or false)
            nr_button:SetCallback("OnValueChanged", function(widget, event, val)
                value.ranked = val
                spell:SetUserData("norank", not val)
                spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                top:SetStatusText(funcs:print(root, spec))
            end)
        end

        spell:SetLabel(L["Spell"])
        spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
        spell:SetUserData("norank", not value.ranked)
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            if isint(v) then
                if isSpellOnSpec(spec, tonumber(v)) then
                    value.spell = tonumber(v)
                else
                    value.spell = nil
                    spell:SetText(nil)
                end
            else
                value.spell = addon:GetSpecSpellID(spec, v)
                if value.spell == nil then
                    spell:SetText(nil)
                end
            end
            spellIcon:SetText(value.spell)
            top:SetStatusText(funcs:print(root, spec))
        end)

        operator:SetLabel(L["Operator"])
        operator:SetList(operators, keys(operators))
        if (value.operator ~= nil) then
            operator:SetValue(value.operator)
        end
        operator:SetCallback("OnValueChanged", function(widget, event, v)
            value.operator = v
            top:SetStatusText(funcs:print(root, spec))
        end)

        health:SetLabel(L["Seconds"])
        health:SetWidth(100)
        if (value.value ~= nil) then
            health:SetText(value.value)
        end
        health:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})

addon:RegisterCondition("SPELL_REMAIN", {
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
        local spellid = value.spell
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            if not value.ranked then
                spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                    select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
            end
        end
        local charges, maxcharges, start, duration = getCached(cache, GetSpellCharges, spellid)
        local remain = 0
        if (charges and charges >= 0) then
            remain = duration - (GetTime() - start)
        end
        return compare(value.operator, remain, value.value)
    end,
    print = function(spec, value)
        local link
        if value.spell ~= nil then
            local spellid = value.spell
            if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
                if not value.ranked then
                    spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                        select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
                end
            end
            link = GetSpellLink(spellid)
        end
        return string.format(L["the %s"],
            compareString(value.operator, string.format(L["remaining time on %s"], nullable(link, L["<spell>"])),
                            string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = AceGUI:Create("SimpleGroup")
        parent:AddChild(spell_group)
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        spell_group:AddChild(spellIcon)
        local ranked, nr_label, nr_button
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked = AceGUI:Create("SimpleGroup")
            spell_group:AddChild(ranked)
            nr_label = AceGUI:Create("Label")
            ranked:AddChild(nr_label)
            local nr_button = AceGUI:Create("CheckBox")
            ranked:AddChild(nr_button)
        end
        local spell = AceGUI:Create("Spec_EditBox")
        spell_group:AddChild(spell)
        local operator = AceGUI:Create("Dropdown")
        parent:AddChild(operator)
        local health = AceGUI:Create("EditBox")
        parent:AddChild(health)

        spell_group:SetLayout("Table")
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
		spell_group:SetUserData("table", { columns = { 44, 0.1, 1 } })
	else
		spell_group:SetUserData("table", { columns = { 44, 1 } })
	end

        spellIcon:SetText(value.spell)
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon.text:Hide()
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(spec, v) then
                value.spell = v
                spellIcon:SetText(v)
                if v then
                    spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                else
                    spell:SetText(nil)
                end
                top:SetStatusText(funcs:print(root, spec))
            end
        end)

        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked:SetFullWidth(true)
            ranked:SetLayout("Table")
            ranked:SetUserData("table", { columns = { 1 } })
            ranked:SetUserData("cell", { alignV = "bottom", alignH = "center" })

            nr_label:SetText(L["Rank"])
            nr_label:SetColor(1.0, 0.82, 0.0)

            nr_button:SetValue(value.ranked or false)
            nr_button:SetCallback("OnValueChanged", function(widget, event, val)
                value.ranked = val
                spell:SetUserData("norank", not val)
                spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                top:SetStatusText(funcs:print(root, spec))
            end)
        end

        spell:SetLabel(L["Spell"])
        spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
        spell:SetUserData("norank", not value.ranked)
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            if isint(v) then
                if isSpellOnSpec(spec, tonumber(v)) then
                    value.spell = tonumber(v)
                else
                    value.spell = nil
                    spell:SetText(nil)
                end
            else
                value.spell = addon:GetSpecSpellID(spec, v)
                if value.spell == nil then
                    spell:SetText(nil)
                end
            end
            spellIcon:SetText(value.spell)
            top:SetStatusText(funcs:print(root, spec))
        end)

        operator:SetLabel(L["Operator"])
        operator:SetList(operators, keys(operators))
        if (value.operator ~= nil) then
            operator:SetValue(value.operator)
        end
        operator:SetCallback("OnValueChanged", function(widget, event, v)
            value.operator = v
            top:SetStatusText(funcs:print(root, spec))
        end)

        health:SetLabel(L["Seconds"])
        health:SetWidth(100)
        if (value.value ~= nil) then
            health:SetText(value.value)
        end
        health:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})

addon:RegisterCondition("SPELL_CHARGES", {
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
        local spellid = value.spell
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            if not value.ranked then
                spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                    select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
            end
        end
        local charges, maxcharges, start, duration = getCached(cache, GetSpellCharges, spellid)
        return compare(value.operator, charges, value.value)
    end,
    print = function(spec, value)
        local link
        if value.spell ~= nil then
            local spellid = value.spell
            if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
                if not value.ranked then
                    spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                        select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
                end
            end
            link = GetSpellLink(spellid)
        end
        return string.format(L["the %s"],
            compareString(value.operator, string.format(L["number of charges on %s"], nullable(link, L["<spell>"])), nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = AceGUI:Create("SimpleGroup")
        parent:AddChild(spell_group)
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        spell_group:AddChild(spellIcon)
        local ranked, nr_label, nr_button
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked = AceGUI:Create("SimpleGroup")
            spell_group:AddChild(ranked)
            nr_label = AceGUI:Create("Label")
            ranked:AddChild(nr_label)
            local nr_button = AceGUI:Create("CheckBox")
            ranked:AddChild(nr_button)
        end
        local spell = AceGUI:Create("Spec_EditBox")
        spell_group:AddChild(spell)
        local operator = AceGUI:Create("Dropdown")
        parent:AddChild(operator)
        local health = AceGUI:Create("EditBox")
        parent:AddChild(health)

        spell_group:SetLayout("Table")
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
		spell_group:SetUserData("table", { columns = { 44, 0.1, 1 } })
	else
		spell_group:SetUserData("table", { columns = { 44, 1 } })
	end

        spellIcon:SetText(value.spell)
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon.text:Hide()
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(spec, v) then
                value.spell = v
                spellIcon:SetText(v)
                if v then
                    spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                else
                    spell:SetText(nil)
                end
                top:SetStatusText(funcs:print(root, spec))
            end
        end)

        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked:SetFullWidth(true)
            ranked:SetLayout("Table")
            ranked:SetUserData("table", { columns = { 1 } })
            ranked:SetUserData("cell", { alignV = "bottom", alignH = "center" })

            nr_label:SetText(L["Rank"])
            nr_label:SetColor(1.0, 0.82, 0.0)

            nr_button:SetValue(value.ranked or false)
            nr_button:SetCallback("OnValueChanged", function(widget, event, val)
                value.ranked = val
                spell:SetUserData("norank", not val)
                spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                top:SetStatusText(funcs:print(root, spec))
            end)
        end

        spell:SetLabel(L["Spell"])
        spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
        spell:SetUserData("norank", not value.ranked)
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            if isint(v) then
                if isSpellOnSpec(spec, tonumber(v)) then
                    value.spell = tonumber(v)
                else
                    value.spell = nil
                    spell:SetText(nil)
                end
            else
                value.spell = addon:GetSpecSpellID(spec, v)
                if value.spell == nil then
                    spell:SetText(nil)
                end
            end
            spellIcon:SetText(value.spell)
            top:SetStatusText(funcs:print(root, spec))
        end)

        operator:SetLabel(L["Operator"])
        operator:SetList(operators, keys(operators))
        if (value.operator ~= nil) then
            operator:SetValue(value.operator)
        end
        operator:SetCallback("OnValueChanged", function(widget, event, v)
            value.operator = v
            top:SetStatusText(funcs:print(root, spec))
        end)

        health:SetLabel(L["Charges"])
        health:SetWidth(100)
        if (value.value ~= nil) then
            health:SetText(value.value)
        end
        health:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})

addon:RegisterCondition("SPELL_HISTORY", {
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
                local spellid = value.spell
                if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
                    if not value.ranked then
                        spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                            select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
                    end
                end
                return compare(value.operator, idx, spellid)
            end
        end
        return false
    end,
    print = function(spec, value)
        local link
        if value.spell ~= nil then
            local spellid = value.spell
            if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
                if not value.ranked then
                    spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                        select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
                end
            end
            link = GetSpellLink(spellid)
        end
        return compareString(value.operator, string.format(L["%s was cast"], nullable(link, L["<spell>"])),
                        string.format(L["%s casts ago"], nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = AceGUI:Create("SimpleGroup")
        parent:AddChild(spell_group)
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        spell_group:AddChild(spellIcon)
        local ranked, nr_label, nr_button
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked = AceGUI:Create("SimpleGroup")
            spell_group:AddChild(ranked)
            nr_label = AceGUI:Create("Label")
            ranked:AddChild(nr_label)
            local nr_button = AceGUI:Create("CheckBox")
            ranked:AddChild(nr_button)
        end
        local spell = AceGUI:Create("Spec_EditBox")
        spell_group:AddChild(spell)
        local operator = AceGUI:Create("Dropdown")
        parent:AddChild(operator)
        local health = AceGUI:Create("EditBox")
        parent:AddChild(health)

        spell_group:SetLayout("Table")
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
		spell_group:SetUserData("table", { columns = { 44, 0.1, 1 } })
	else
		spell_group:SetUserData("table", { columns = { 44, 1 } })
	end

        spellIcon:SetText(value.spell)
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon.text:Hide()
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(spec, v) then
                value.spell = v
                spellIcon:SetText(v)
                if v then
                    spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                else
                    spell:SetText(nil)
                end
                top:SetStatusText(funcs:print(root, spec))
            end
        end)

        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked:SetFullWidth(true)
            ranked:SetLayout("Table")
            ranked:SetUserData("table", { columns = { 1 } })
            ranked:SetUserData("cell", { alignV = "bottom", alignH = "center" })

            nr_label:SetText(L["Rank"])
            nr_label:SetColor(1.0, 0.82, 0.0)

            nr_button:SetValue(value.ranked or false)
            nr_button:SetCallback("OnValueChanged", function(widget, event, val)
                value.ranked = val
                spell:SetUserData("norank", not val)
                spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                top:SetStatusText(funcs:print(root, spec))
            end)
        end

        spell:SetLabel(L["Spell"])
        spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
        spell:SetUserData("norank", not value.ranked)
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            if isint(v) then
                if isSpellOnSpec(spec, tonumber(v)) then
                    value.spell = tonumber(v)
                else
                    value.spell = nil
                    spell:SetText(nil)
                end
            else
                value.spell = addon:GetSpecSpellID(spec, v)
                if value.spell == nil then
                    spell:SetText(nil)
                end
            end
            spellIcon:SetText(value.spell)
            top:SetStatusText(funcs:print(root, spec))
        end)

        operator:SetLabel(L["Operator"])
        operator:SetList(operators, keys(operators))
        if (value.operator ~= nil) then
            operator:SetValue(value.operator)
        end
        operator:SetCallback("OnValueChanged", function(widget, event, v)
            value.operator = v
            top:SetStatusText(funcs:print(root, spec))
        end)

        health:SetLabel(L["Count"])
        health:SetWidth(100)
        if (value.value ~= nil) then
            health:SetText(value.value)
        end
        health:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})

addon:RegisterCondition("SPELL_HISTORY_TIME", {
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
            local spellid = value.spell
            if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
                if not value.ranked then
                    spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                        select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
                end
            end
            if entry.spell == spellid then
                return compare(value.operator, (evalStart - entry.time), value.value)
            end
        end
        return false
    end,
    print = function(spec, value)
        local link
        if value.spell ~= nil then
            local spellid = value.spell
            if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
                if not value.ranked then
                    spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                        select(1, getCached(addon.longtermCache, GetSpellInfo, value.spell))))
                end
            end
            link = GetSpellLink(spellid)
        end
        return compareString(value.operator, string.format(L["%s was cast"], nullable(link, L["<spell>"])),
                string.format(L["%s seconds ago"], nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local spell_group = AceGUI:Create("SimpleGroup")
        parent:AddChild(spell_group)
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        spell_group:AddChild(spellIcon)
        local ranked, nr_label, nr_button
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked = AceGUI:Create("SimpleGroup")
            spell_group:AddChild(ranked)
            nr_label = AceGUI:Create("Label")
            ranked:AddChild(nr_label)
            local nr_button = AceGUI:Create("CheckBox")
            ranked:AddChild(nr_button)
        end
        local spell = AceGUI:Create("Spec_EditBox")
        spell_group:AddChild(spell)
        local operator = AceGUI:Create("Dropdown")
        parent:AddChild(operator)
        local health = AceGUI:Create("EditBox")
        parent:AddChild(health)

        spell_group:SetLayout("Table")
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
		spell_group:SetUserData("table", { columns = { 44, 0.1, 1 } })
	else
		spell_group:SetUserData("table", { columns = { 44, 1 } })
	end

        spellIcon:SetText(value.spell)
        spellIcon.text:Hide()
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(spec, v) then
                value.spell = v
                spellIcon:SetText(v)
                if v then
                    spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                else
                    spell:SetText(nil)
                end
                top:SetStatusText(funcs:print(root, spec))
            end
        end)

        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            ranked:SetFullWidth(true)
            ranked:SetLayout("Table")
            ranked:SetUserData("table", { columns = { 1 } })
            ranked:SetUserData("cell", { alignV = "bottom", alignH = "center" })

            nr_label:SetText(L["Rank"])
            nr_label:SetColor(1.0, 0.82, 0.0)

            nr_button:SetValue(value.ranked or false)
            nr_button:SetCallback("OnValueChanged", function(widget, event, val)
                value.ranked = val
                spell:SetUserData("norank", not val)
                spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
                top:SetStatusText(funcs:print(root, spec))
            end)
        end

        spell:SetLabel(L["Spell"])
        spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
        spell:SetUserData("norank", not value.ranked)
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            if isint(v) then
                if isSpellOnSpec(spec, tonumber(v)) then
                    value.spell = tonumber(v)
                else
                    value.spell = nil
                    spell:SetText(nil)
                end
            else
                value.spell = addon:GetSpecSpellID(spec, v)
                if value.spell == nil then
                    spell:SetText(nil)
                end
            end
            spellIcon:SetText(value.spell)
            top:SetStatusText(funcs:print(root, spec))
        end)

        operator:SetLabel(L["Operator"])
        operator:SetList(operators, keys(operators))
        if (value.operator ~= nil) then
            operator:SetValue(value.operator)
        end
        operator:SetCallback("OnValueChanged", function(widget, event, v)
            value.operator = v
            top:SetStatusText(funcs:print(root, spec))
        end)

        health:SetLabel(L["Seconds"])
        health:SetWidth(100)
        if (value.value ~= nil) then
            health:SetText(value.value)
        end
        health:SetCallback("OnEnterPressed", function(widget, event, v)
            value.value = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})

