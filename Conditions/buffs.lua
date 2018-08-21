local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")
local tonumber, pairs = tonumber, pairs

-- From constants
local operators, units, unitsPossessive = addon.operators, addon.units, addon.unitsPossessive

-- From utils
local compare, compareString, nullable, keys, isin, getCached, deepcopy, playerize =
    addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.getCached, addon.deepcopy, addon.playerize

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

addon:RegisterCondition("BUFF_REMAIN", {
    description = L["Buff Time Remaining"],
    icon = "Interface\\Icons\\inv_misc_pocketwatch_02",
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

addon:RegisterCondition("BUFF_STACKS", {
    description = L["Buff Stacks"],
    icon = "Interface\\Icons\\spell_priest_vowofunity",
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

addon:RegisterCondition("STEALABLE", {
    description = L["Has Stealable Buff"],
    icon = "Interface\\Icons\\inv_helm_cloth_b_01pirate_classic",
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
        local units = deepcopy(units, { "player", "pet" })

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
    end,
})
