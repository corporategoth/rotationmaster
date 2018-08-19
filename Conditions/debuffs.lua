local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")
local tonumber = tonumber

-- From constants
local operators, units, unitsPossessive, debufftypes = addon.operators, addon.units, addon.unitsPossessive,addon.debufftypes

-- From utils
local compare, compareString, nullable, keys, isin, deepcopy, getCached, playerize =
    addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.deepcopy, addon.getCached, addon.playerize

addon:RegisterCondition("DEBUFF", {
    description = L["Debuff Present"],
    icon = "Interface\\Icons\\spell_shadow_curseoftounges",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache)
        for i=1,40 do
            local name = getCached(cache, UnitDebuff, value.unit, i)
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
            nullable(units[value.unit], L["<unit>"]), nullable(value.spell, L["<debuff>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = AceGUI:Create("Dropdown")
        unit:SetLabel(L["Unit"])
        unit:SetList(units, keys(units))
        if (value.unit ~= nil) then
            unit:SetValue(value.unit)
        end
        unit:SetCallback("OnValueChanged", function(widget, event, v)
            value.unit = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(unit)

        local spell = AceGUI:Create("Spell_EditBox")
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        if (value.spell) then
            local spellid = SpellData.spellListReverse[string.lower(value.spell)]
            if spellid then
                spellIcon:SetText(spellid)
            else
                SpellData:RegisterPredictor(spellIcon)
            end
        end
        spellIcon.text:Hide()
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            spellIcon:SetText(v)
            if v then
                value.spell = GetSpellInfo(v)
                spell:SetText(value.spell)
            else
                value.spell = nil
                spell:SetText("")
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        function spellIcon:Query()
            local spellid = SpellData.spellListReverse[string.lower(value.spell)]
            if spellid then
                spellIcon:SetText(spellid)
                SpellData:UnregisterPredictor(self)
            end
        end
        parent:AddChild(spellIcon)

        spell:SetLabel(L["Spell"])
        if (value.spell) then
            spell:SetText(value.spell)
        end
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            value.spell = v
            local spellid = SpellData.spellListReverse[string.lower(value.spell)]
            if spellid then
                spellIcon:SetText(spellid)
            else
                SpellData:RegisterPredictor(spellIcon)
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(spell)
    end,
})

addon:RegisterCondition("DEBUFF_REMAIN", {
    description = L["Debuff Time Remaining"],
    icon = "Interface\\Icons\\ability_creature_cursed_04",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        for i=1,40 do
            local name, _, _, _, _, expirationTime = getCached(cache, UnitDebuff, value.unit, i)
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
            nullable(units[value.unit], L["<unit>"]), nullable(value.spell, L["<debuff>"]),
            compareString(value.operator, L["the remaining time"], string.format(L["%s seconds"], nullable(value.value))))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = AceGUI:Create("Dropdown")
        unit:SetLabel(L["Unit"])
        unit:SetList(units, keys(units))
        if (value.unit ~= nil) then
            unit:SetValue(value.unit)
        end
        unit:SetCallback("OnValueChanged", function(widget, event, v)
            value.unit = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(unit)

        local spell = AceGUI:Create("Spell_EditBox")
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        if (value.spell) then
            local spellid = SpellData.spellListReverse[string.lower(value.spell)]
            if spellid then
                spellIcon:SetText(spellid)
            else
                SpellData:RegisterPredictor(spellIcon)
            end
        end
        spellIcon.text:Hide()
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            spellIcon:SetText(v)
            if v then
                value.spell = GetSpellInfo(v)
                spell:SetText(value.spell)
            else
                value.spell = nil
                spell:SetText("")
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        function spellIcon:Query()
            local spellid = SpellData.spellListReverse[string.lower(value.spell)]
            if spellid then
                spellIcon:SetText(spellid)
                SpellData:UnregisterPredictor(self)
            end
        end
        parent:AddChild(spellIcon)

        spell:SetLabel(L["Spell"])
        if (value.spell) then
            spell:SetText(value.spell)
        end
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            value.spell = v
            local spellid = SpellData.spellListReverse[string.lower(value.spell)]
            if spellid then
                spellIcon:SetText(spellid)
            else
                SpellData:RegisterPredictor(spellIcon)
            end
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

addon:RegisterCondition("DEBUFF_STACKS", {
    description = L["Debuff Stacks"],
    icon = "Interface\\Icons\\inv_misc_ticket_tarot_stack_01",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        for i=1,40 do
            local name, _, count = getCached(cache, UnitDebuff, value.unit, i)
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
                compareString(value.operator, string.format(L["stacks of %s"], nullable(value.spell, L["<debuff>"])), nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = AceGUI:Create("Dropdown")
        unit:SetLabel(L["Unit"])
        unit:SetList(units, keys(units))
        if (value.unit ~= nil) then
            unit:SetValue(value.unit)
        end
        unit:SetCallback("OnValueChanged", function(widget, event, v)
            value.unit = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(unit)

        local spell = AceGUI:Create("Spell_EditBox")
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        if (value.spell) then
            local spellid = SpellData.spellListReverse[string.lower(value.spell)]
            if spellid then
                spellIcon:SetText(spellid)
            else
                SpellData:RegisterPredictor(spellIcon)
            end
        end
        spellIcon.text:Hide()
        spellIcon:SetWidth(44)
        spellIcon:SetHeight(44)
        spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
            spellIcon:SetText(v)
            if v then
                value.spell = GetSpellInfo(v)
                spell:SetText(value.spell)
            else
                value.spell = nil
                spell:SetText("")
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        function spellIcon:Query()
            local spellid = SpellData.spellListReverse[string.lower(value.spell)]
            if spellid then
                spellIcon:SetText(spellid)
                SpellData:UnregisterPredictor(self)
            end
        end
        parent:AddChild(spellIcon)

        spell:SetLabel(L["Spell"])
        if (value.spell) then
            spell:SetText(value.spell)
        end
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            value.spell = v
            local spellid = SpellData.spellListReverse[string.lower(value.spell)]
            if spellid then
                spellIcon:SetText(spellid)
            else
                SpellData:RegisterPredictor(spellIcon)
            end
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
        health:SetLabel(L["Stacks"])
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

addon:RegisterCondition("DISPELLABLE", {
    description = L["Has Dispellable Debuff"],
    icon = "Interface\\Icons\\spell_shadow_curseofsargeras",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.debufftype ~= nil and isin(debufftypes, value.debufftype))
    end,
    evaluate = function(value, cache)
        for i=1,40 do
            local name, _, _, debuffType = getCached(cache, UnitDebuff, value.unit, i)
            if (name == nil) then
                break
            end
            if debuffType == value.debufftype then
                return true
            end
        end
        return false
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s have a %s debuff"], L["%s has a %s debuff"]),
            nullable(units[value.unit], L["<unit>"]), nullable(debufftypes[value.debufftype], L["<debuff type>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = AceGUI:Create("Dropdown")
        unit:SetLabel(L["Unit"])
        unit:SetList(units, keys(units))
        if (value.unit ~= nil) then
            unit:SetValue(value.unit)
        end
        unit:SetCallback("OnValueChanged", function(widget, event, v)
            value.unit = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(unit)

        local debufftype = AceGUI:Create("Dropdown")
        debufftype:SetLabel(L["Debuff Type"])
        debufftype:SetList(debufftypes, debufftypes(debufftypes))
        if (value.debufftype ~= nil) then
            debufftype:SetValue(value.debufftype)
        end
        debufftype:SetCallback("OnValueChanged", function(widget, event, v)
            value.debufftype = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(debufftype)

        return nil
    end,
})
