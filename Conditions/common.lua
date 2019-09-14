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
    spell_group:SetLayout("Table")

    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        spell_group:SetUserData("table", { columns = { 44, 30, 1 } })
    else
        spell_group:SetUserData("table", { columns = { 44, 1 } })
    end

    local spell = AceGUI:Create(editbox)
    local spellIcon = AceGUI:Create("ActionSlotSpell")
    spellIcon:SetWidth(44)
    spellIcon:SetHeight(44)
    spellIcon:SetText(value.spell)
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
    spell_group:AddChild(spellIcon)

    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        local ranked = AceGUI:Create("SimpleGroup")
        ranked:SetFullWidth(true)
        ranked:SetLayout("Table")
        ranked:SetUserData("table", { columns = { 1 } })
        ranked:SetUserData("cell", { alignV = "bottom", alignH = "center" })

        local nr_label = AceGUI:Create("Label")
        nr_label:SetText(L["Rank"])
        nr_label:SetColor(1.0, 0.82, 0.0)
        ranked:AddChild(nr_label)

        local nr_button = AceGUI:Create("CheckBox")
        nr_button:SetLabel(nil)
        nr_button:SetValue(value.ranked or false)
        nr_button:SetCallback("OnValueChanged", function(widget, event, val)
            value.ranked = val
            spell:SetUserData("norank", not val)
            spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
            update()
        end)
        ranked:AddChild(nr_button)

        spell_group:AddChild(ranked)
    end

    spell:SetFullWidth(true)
    spell:SetLabel(L["Spell"])
    spell:SetText(value.spell and (value.ranked and SpellData:SpellName(value.spell) or GetSpellInfo(value.spell)))
    spell:SetUserData("norank", not value.ranked)
    spell:SetUserData("spec", spec)
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
    spell_group:AddChild(spell)

    return spell_group
end

function addon:Widget_SpellNameWidget(spec, editbox, value, isvalid, update)
    local spell_group = AceGUI:Create("SimpleGroup")
    spell_group:SetLayout("Table")
    spell_group:SetUserData("table", { columns = { 44, 1 } })

    local spell = AceGUI:Create(editbox)
    local spellIcon = AceGUI:Create("ActionSlotSpell")
    spellIcon:SetWidth(44)
    spellIcon:SetHeight(44)
    spellIcon:SetText(select(7, GetSpellInfo(value.spell)) or SpellData.spellListReverse[string.lower(value.spell)])
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
    spell_group:AddChild(spellIcon)

    spell:SetFullWidth(true)
    spell:SetLabel(L["Spell"])
    spell:SetText(value.spell)
    spell:SetUserData("norank", not value.ranked)
    spell:SetUserData("spec", spec)
    spell:SetCallback("OnEnterPressed", function(widget, event, v)
        local name, _, _, _, _, _, spellid = GetSpellInfo(v)
        if spellid == nil then
            name = v
            spellid = SpellData.spellListReverse[string.lower(v)]
        end

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
    spell_group:AddChild(spell)

    return spell_group
end

function addon:Widget_ItemWidget(spec, value, update)
    local item_group = AceGUI:Create("SimpleGroup")
    item_group:SetLayout("Table")
    item_group:SetUserData("table", { columns = { 44, 1 } })

    local itemid
    if value.item then
        itemid = GetItemInfoInstant(value.item)
    end

    local item = AceGUI:Create("Inventory_EditBox")
    local itemIcon = AceGUI:Create("ActionSlotSpell")
    itemIcon:SetWidth(44)
    itemIcon:SetHeight(44)
    itemIcon:SetText(itemid)
    itemIcon.text:Hide()
    itemIcon:SetCallback("OnEnterPressed", function(widget, event, v)
        value.item = GetItemInfo(v)
        item:SetText(value.item)
        update()
    end)
    item_group:AddChild(itemIcon)

    item:SetFullWidth(true)
    item:SetLabel(L["Item"])
    item:SetText(value.item)
    item:SetUserData("spec", spec)
    item:SetCallback("OnEnterPressed", function(widget, event, v)
        local itemid
        if v then
            v = GetItemInfoInstant(v)
        end
        value.item = v
        itemIcon:SetText(itemid)
        update()
    end)
    item_group:AddChild(item)

    return item_group
end

function addon:Widget_OperatorWidget(value, name, update)
    local operator_group = AceGUI:Create("SimpleGroup")
    operator_group:SetLayout("Table")
    operator_group:SetUserData("table", { columns = { 0, 75 } })

    local operator = AceGUI:Create("Dropdown")
    operator:SetFullWidth(true)
    operator:SetLabel(L["Operator"])
    operator:SetCallback("OnValueChanged", function(widget, event, v)
        value.operator = v
        update()
    end)
    operator.configure = function()
        operator:SetList(operators, keys(operators))
        operator:SetValue(value.operator)
    end
    operator_group:AddChild(operator)

    local edit = AceGUI:Create("EditBox")
    edit:SetFullWidth(true)
    edit:SetLabel(name)
    edit:SetText(value.value)
    edit:SetCallback("OnEnterPressed", function(widget, event, v)
        value.value = tonumber(v)
        update()
    end)
    operator_group:AddChild(edit)

    return operator_group
end

function addon:Widget_OperatorPercentWidget(value, name, update)
    local operator_group = AceGUI:Create("SimpleGroup")
    operator_group:SetLayout("Table")
    operator_group:SetUserData("table", { columns = { 0, 150} })

    local operator = AceGUI:Create("Dropdown")
    operator:SetFullWidth(true)
    operator:SetLabel(L["Operator"])
    operator:SetCallback("OnValueChanged", function(widget, event, v)
        value.operator = v
        update()
    end)
    operator.configure = function()
        operator:SetList(operators, keys(operators))
        operator:SetValue(value.operator)
    end
    operator_group:AddChild(operator)

    local edit = AceGUI:Create("Slider")
    edit:SetFullWidth(true)
    edit:SetLabel(name)
    if (value.value ~= nil) then
        edit:SetValue(value.value)
    end
    edit:SetSliderValues(0, 1, 0.01)
    edit:SetIsPercent(true)
    edit:SetCallback("OnValueChanged", function(widget, event, v)
        value.value = tonumber(v)
        update()
    end)
    operator_group:AddChild(edit)

    return operator_group
end

function addon:Widget_UnitWidget(value, units, update)
    local unit = AceGUI:Create("Dropdown")
    unit:SetLabel(L["Unit"])
    unit:SetCallback("OnValueChanged", function(widget, event, v)
        value.unit = v
        update()
    end)
    unit.configure = function()
        unit:SetList(units, keys(units))
        unit:SetValue(value.unit)
    end

    return unit
end
