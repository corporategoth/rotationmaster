local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local tonumber = tonumber

-- From Constants
local operators, units = addon.operators, addon.units

-- From Utils
local isint, keys, getCached = addon.isint, addon.keys, addon.getCached

function addon:Widget_GetSpellId(spellid, ranked)
    local spellid = spellid
    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        if not ranked then
            spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                select(1, getCached(addon.longtermCache, GetSpellInfo, spellid))))
        end
    end
    return spellid
end

function addon:Widget_GetSpellLink(spellid, ranked)
    if spellid ~= nil then
        local spellid = spellid
        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            if not ranked then
                spellid = select(7, getCached(addon.longtermCache, GetSpellInfo,
                    select(1, getCached(addon.longtermCache, GetSpellInfo, spellid))))
            end
        end
        return GetSpellLink(spellid)
    end
    return nil
end

function addon:Widget_SpellWidget(spec, editbox, value, nametoid, isvalid, update)
    local spell_group = AceGUI:Create("SimpleGroup")

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
    local spell = AceGUI:Create(editbox)
    spell_group:AddChild(spell)

    spell_group:SetLayout("Table")
    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        spell_group:SetUserData("table", { columns = { 44, 30, 1 } })
    else
        spell_group:SetUserData("table", { columns = { 44, 1 } })
    end

    spellIcon:SetText(value.spell)
    spellIcon:SetWidth(44)
    spellIcon:SetHeight(44)
    spellIcon.text:Hide()
    spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
        v = tonumber(v)
        if isvalid(v) then
            value.spell = v
            spellIcon:SetText(v)
            spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
        else
            spellIcon:SetText(nil)
            spell:SetText(nil)
        end
        update()
    end)

    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        ranked:SetFullWidth(true)
        ranked:SetLayout("Table")
        ranked:SetUserData("table", { columns = { 1 } })
        ranked:SetUserData("cell", { alignV = "bottom", alignH = "center" })

        nr_label:SetText(L["Rank"])
        nr_label:SetColor(1.0, 0.82, 0.0)

        nr_button:SetLabel(nil)
        nr_button:SetValue(value.ranked or false)
        nr_button:SetCallback("OnValueChanged", function(widget, event, val)
            value.ranked = val
            spell:SetUserData("norank", not val)
            spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
            update()
        end)
    end

    spell:SetLabel(L["Spell"])
    spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
    spell:SetUserData("norank", not value.ranked)
    spell:SetUserData("spec", spec)
    spell:SetFullWidth(true)
    spell:SetCallback("OnEnterPressed", function(widget, event, v)
        if not isint(v) then
            v = nametoid(v)
        else
            v = tonumber(v)
        end
        if isvalid(v) then
            value.spell = v
        else
            value.spell = nil
            spell:SetText(nil)
        end
        spellIcon:SetText(value.spell)
        update()
    end)

    return spell_group
end

function addon:Widget_SpellNameWidget(spec, editbox, value, isvalid, update)
    local spell_group = AceGUI:Create("SimpleGroup")

    local spellIcon = AceGUI:Create("ActionSlotSpell")
    spell_group:AddChild(spellIcon)
    local spell = AceGUI:Create(editbox)
    spell_group:AddChild(spell)

    spell_group:SetLayout("Table")
    spell_group:SetUserData("table", { columns = { 44, 1 } })

    local spellid = select(7, GetSpellInfo(value.spell))
    spellIcon:SetText(spellid)
    spellIcon:SetWidth(44)
    spellIcon:SetHeight(44)
    spellIcon.text:Hide()
    spellIcon:SetCallback("OnEnterPressed", function(widget, event, v)
        v = tonumber(v)
        if isvalid(v) then
            value.spell = GetSpellInfo(v)
            spellIcon:SetText(v)
            spell:SetText(value.spell)
        else
            spellIcon:SetText(nil)
            spell:SetText(nil)
        end
        update()
    end)

    spell:SetLabel(L["Spell"])
    spell:SetText(value.spell)
    spell:SetUserData("norank", not value.ranked)
    spell:SetUserData("spec", spec)
    spell:SetFullWidth(true)
    spell:SetCallback("OnEnterPressed", function(widget, event, v)
        local name, _, _, _, _, _, spellid = GetSpellInfo(v)
        if isvalid(spellid) then
            value.spell = name
            spell:SetText(name)
            spellIcon:SetText(spellid)
        else
            value.spell = nil
            spell:SetText(nil)
            spellIcon:SetText(nil)
        end
        update()
    end)

    return spell_group
end

function addon:Widget_ItemWidget(spec, value, update)
    local icon_group = AceGUI:Create("SimpleGroup")

    local iconIcon = AceGUI:Create("ActionSlotSpell")
    icon_group:AddChild(iconIcon)
    local icon = AceGUI:Create("Inventory_EditBox")
    icon_group:AddChild(icon)

    icon_group:SetLayout("Table")
    icon_group:SetUserData("table", { columns = { 44, 1 } })

    local itemid
    if value.item then
        itemid = GetItemInfoInstant(value.item)
    end
    iconIcon:SetText(itemid)
    iconIcon:SetWidth(44)
    iconIcon:SetHeight(44)
    iconIcon.text:Hide()
    iconIcon:SetCallback("OnEnterPressed", function(widget, event, v)
        value.item = GetItemInfo(v)
        icon:SetText(value.item)
        update()
    end)

    icon:SetLabel(L["Item"])
    icon:SetText(value.item)
    icon:SetUserData("spec", spec)
    icon:SetFullWidth(true)
    icon:SetCallback("OnEnterPressed", function(widget, event, v)
        local itemid
        if v then
            v = GetItemInfoInstant(v)
        end
        value.item = v
        iconIcon:SetText(itemid)
        update()
    end)

    return icon_group
end

function addon:Widget_OperatorWidget(value, name, update)
    local operator_group = AceGUI:Create("SimpleGroup")

    local operator = AceGUI:Create("Dropdown")
    operator_group:AddChild(operator)
    local edit = AceGUI:Create("EditBox")
    operator_group:AddChild(edit)

    operator_group:SetLayout("Table")
    operator_group:SetUserData("table", { columns = { 0, 75 } })

    operator:SetLabel(L["Operator"])
    operator:SetList(operators, keys(operators))
    operator:SetValue(value.operator)
    operator:SetFullWidth(true)
    operator:SetCallback("OnValueChanged", function(widget, event, v)
        value.operator = v
        update()
    end)

    edit:SetLabel(name)
    edit:SetText(value.value)
    edit:SetFullWidth(true)
    edit:SetCallback("OnEnterPressed", function(widget, event, v)
        value.value = tonumber(v)
        update()
    end)

    return operator_group
end

function addon:Widget_OperatorPercentWidget(value, name, update)
    local operator_group = AceGUI:Create("SimpleGroup")

    local operator = AceGUI:Create("Dropdown")
    operator_group:AddChild(operator)
    local edit = AceGUI:Create("Slider")
    operator_group:AddChild(edit)

    operator_group:SetLayout("Table")
    operator_group:SetUserData("table", { columns = { 0, 150} })

    operator:SetLabel(L["Operator"])
    operator:SetList(operators, keys(operators))
    operator:SetValue(value.operator)
    operator:SetFullWidth(true)
    operator:SetCallback("OnValueChanged", function(widget, event, v)
        value.operator = v
        update()
    end)

    edit:SetLabel(name)
    if (value.value ~= nil) then
        edit:SetValue(value.value)
    end
    edit:SetFullWidth(true)
    edit:SetSliderValues(0, 1, 0.01)
    edit:SetIsPercent(true)
    edit:SetCallback("OnValueChanged", function(widget, event, v)
        value.value = tonumber(v)
        update()
    end)

    return operator_group
end

function addon:Widget_UnitWidget(value, units, update)
    local unit = AceGUI:Create("Dropdown")

    unit:SetLabel(L["Unit"])
    unit:SetList(units, keys(units))
    unit:SetValue(value.unit)
    unit:SetCallback("OnValueChanged", function(widget, event, v)
        value.unit = v
        update()
    end)

    return unit
end
