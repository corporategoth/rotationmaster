local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")
local tonumber = tonumber

-- From constants
local units, unitsPossessive, operators = addon.units, addon.unitsPossessive, addon.operators

-- From utils
local compare, compareString, nullable, keys, isin, isint, getCached, playerize, deepcopy =
    addon.compare, addon.compareString, addon.nullable, addon.keys, addon.isin, addon.isint, addon.getCached, addon.playerize, addon.deepcopy

addon:RegisterCondition("CHANNELING", {
    description = L["Channeling"],
    icon = "Interface\\Icons\\Spell_holy_searinglight",
    valid = function(spec, value)
        return value.unit ~= nil and isin(units, value.unit)
    end,
    evaluate = function(value, cache, evalStart)
        local name = getCached(cache, UnitChannelInfo, value.unit)
        return name ~= nil
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s are currently channeling"], L["%s is currently casting"]),
            nullable(units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = AceGUI:Create("Dropdown")
        parent:AddChild(unit)

        unit:SetLabel(L["Unit"])
        unit:SetList(units, keys(units))
        if (value.unit ~= nil) then
            unit:SetValue(value.unit)
        end
        unit:SetCallback("OnValueChanged", function(widget, event, v)
            value.unit = v
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})

addon:RegisterCondition("CHANNELING_SPELL", {
    description = L["Specific Spell Channeling"],
    icon = "Interface\\Icons\\Spell_holy_greaterheal",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and value.spell ~= nil)
    end,
    evaluate = function(value, cache, evalStart)
        local name = getCached(cache, UnitChannelInfo, value.unit)
        return name == value.spell
    end,
    print = function(spec, value)
        return string.format(playerize(value.unit, L["%s are currently channeling %s"], L["%s is currently casting %s"]),
            nullable(units[value.unit], L["<unit>"]), nullable(value.spell, L["<spell>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = AceGUI:Create("Dropdown")
        parent:AddChild(unit)
        local spellIcon = AceGUI:Create("ActionSlotSpell")
        parent:AddChild(spellIcon)
        local spell = AceGUI:Create("Spell_EditBox")
        parent:AddChild(spell)

        unit:SetLabel(L["Unit"])
        unit:SetList(units, keys(units))
        if (value.unit ~= nil) then
            unit:SetValue(value.unit)
        end
        unit:SetCallback("OnValueChanged", function(widget, event, v)
            value.unit = v
            top:SetStatusText(funcs:print(root, spec))
        end)

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

        spell:SetLabel(L["Spell"])
        if (value.spell) then
            spell:SetText(value.spell)
        end
        spell:SetUserData("spec", spec)
        spell:SetCallback("OnEnterPressed", function(widget, event, v)
            local spellid
            if isint(v) then
                spellid = tonumber(v)
                value.spell = GetSpellInfo(spellid)
                spell:SetText(value.spell)
            else
                value.spell = v
                spellid = SpellData.spellListReverse[string.lower(value.spell)]
            end
            if spellid then
                spellIcon:SetText(spellid)
            else
                SpellData:RegisterPredictor(spellIcon)
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})

addon:RegisterCondition("CHANNELING_REMAIN", {
    description = L["Channel Time Remaining"],
    icon = "Interface\\Icons\\Inv_misc_pocketwatch_01",
    valid = function(spec, value)
        return (value.unit ~= nil and isin(units, value.unit) and
                value.operator ~= nil and isin(operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache, evalStart)
        local name, _, _, _, endTimeMS = getCached(cache, UnitChannelInfo, value.unit)
        if name ~= nil then
            return compare(value.operator, endTimeMS - (GetTime()*1000), value.value)
        end
        return false
    end,
    print = function(spec, value)
        return nullable(unitsPossessive[value.unit], L["<unit>"]) ..
            compareString(value.operator, L["time remaining on spell channel"], string.format(L["%s seconds"], nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = AceGUI:Create("Dropdown")
        parent:AddChild(unit)
        local operator = AceGUI:Create("Dropdown")
        parent:AddChild(operator)
        local health = AceGUI:Create("EditBox")
        parent:AddChild(health)

        unit:SetLabel(L["Unit"])
        unit:SetList(units, keys(units))
        if (value.unit ~= nil) then
            unit:SetValue(value.unit)
        end
        unit:SetCallback("OnValueChanged", function(widget, event, v)
            value.unit = v
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

addon:RegisterCondition("CHANNEL_INTERRUPTABLE", {
    description = L["Channel Interruptable"],
    icon = "Interface\\Icons\\spell_holy_righteousfury",
    valid = function(spec, value)
        return value.unit ~= nil and isin(units, value.unit)
    end,
    evaluate = function(value, cache, evalStart)
        local name, _, _, _, _, _, _, notInterruptible = getCached(cache, UnitChannelInfo, value.unit)
        return name ~= nil and not notInterruptible
    end,
    print = function(spec, value)
        return string.format(L["%s's channeled spell is interruptable"], nullable(units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local units = deepcopy(units, { "player", "pet" })

        local unit = AceGUI:Create("Dropdown")
        parent:AddChild(unit)

        unit:SetLabel(L["Unit"])
        unit:SetList(units, keys(units))
        if (value.unit ~= nil) then
            unit:SetValue(value.unit)
        end
        unit:SetCallback("OnValueChanged", function(widget, event, v)
            value.unit = v
            top:SetStatusText(funcs:print(root, spec))
        end)
    end,
})
