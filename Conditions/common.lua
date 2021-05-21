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
    spellIcon:SetCallback("OnEnter", function(widget)
        if value.spell then
            GameTooltip:SetOwner(spellIcon.frame, "ANCHOR_BOTTOMRIGHT", 3)
            GameTooltip:SetHyperlink("spell:" .. value.spell)
        end
    end)
    spellIcon:SetCallback("OnLeave", function(widget)
        GameTooltip:Hide()
    end)
    spellIcon:SetDisabled(value.disabled)
    spell_group:AddChild(spellIcon)

    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        local ranked = AceGUI:Create("SimpleGroup")
        ranked:SetFullWidth(true)
        ranked:SetLayout("Table")
        ranked:SetUserData("table", { columns = { 1 } })
        ranked:SetUserData("cell", { alignV = "bottom", alignH = "center" })

        local nr_label = AceGUI:Create("Label")
        nr_label:SetText(L["Rank"])
        if value.disabled then
            nr_label:SetColor(0.5, 0.5, 0.5)
        else
            nr_label:SetColor(1.0, 0.82, 0.0)
        end
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
        nr_button:SetDisabled(value.disabled)
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
    spell:SetDisabled(value.disabled)
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
    if value.spell then
        spellIcon:SetText(select(7, GetSpellInfo(value.spell)) or SpellData.spellListReverse[string.lower(value.spell)])
    end
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
    spellIcon:SetCallback("OnEnter", function(widget)
        if value.spell then
            GameTooltip:SetOwner(spellIcon.frame, "ANCHOR_BOTTOMRIGHT", 3)
            GameTooltip:SetHyperlink("spell:" .. value.spell)
        end
    end)
    spellIcon:SetCallback("OnLeave", function(widget)
        GameTooltip:Hide()
    end)
    spellIcon:SetDisabled(value.disabled)
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
    spell:SetDisabled(value.disabled)
    spell_group:AddChild(spell)

    return spell_group
end

function addon:Widget_ItemWidget(top, value, update)
    local itemsets = addon.db.char.itemsets
    local global_itemsets = addon.db.global.itemsets

    local item_group = AceGUI:Create("SimpleGroup")
    item_group:SetLayout("Table")
    item_group:SetUserData("table", { columns = { 44, 1, 0.25 } })

    local itemIcon = AceGUI:Create("Icon")
    local update_action_image = function()
        if value.item ~= nil then
            if type(value.item) == "string" then
                local itemid = addon:FindFirstItemOfItemSet({}, value.item, true) or addon:FindFirstItemInItemSet(value.item)
                addon:UpdateItem_ID_Image(itemid, nil, itemIcon)
            elseif value.item ~= nil and #value.item > 0 then
                local itemid = addon:FindFirstItemOfItems({}, value.item, true) or addon:FindFirstItemInItems(value.item)
                addon:UpdateItem_ID_Image(itemid, nil, itemIcon)
            end
        else
            itemIcon:SetImage(nil)
        end
    end
    update_action_image()
    itemIcon:SetImageSize(36, 36)
    itemIcon:SetCallback("OnEnter", function(widget)
        local itemid
        if type(value.item) == "string" then
            itemid = addon:FindFirstItemOfItemSet({}, value.item, true) or addon:FindFirstItemInItemSet(value.item)
        else
            itemid = addon:FindFirstItemOfItems({}, value.item, true) or addon:FindFirstItemInItems(value.item)
        end
        if itemid then
            GameTooltip:SetOwner(itemIcon.frame, "ANCHOR_BOTTOMRIGHT", 3)
            GameTooltip:SetHyperlink("item:" .. itemid)
        end
    end)
    itemIcon:SetCallback("OnLeave", function(widget)
        GameTooltip:Hide()
    end)
    itemIcon:SetDisabled(value.disabled)
    item_group:AddChild(itemIcon)

    local edit_button = AceGUI:Create("Button")

    local item = AceGUI:Create("Dropdown")
    item:SetFullWidth(true)
    item:SetLabel(L["Item Set"])
    item:SetCallback("OnValueChanged", function(widget, event, val)
        if val ~= nil then
            if val == "" then
                value.item = {}
            else
                value.item = val
            end
            edit_button:SetDisabled(false)
        else
            value.item = nil
            edit_button:SetDisabled(true)
        end
        update_action_image()
        update()
    end)
    item:SetDisabled(value.disabled)
    item.configure = function()
        local selects, sorted = addon:get_item_list(L["Custom"])
        item:SetList(selects, sorted)
        if value.item then
            if type(value.item) == "string" then
                item:SetValue(value.item)
            else
                item:SetValue("")
            end
        end
    end
    item_group:AddChild(item)

    edit_button:SetText(EDIT)
    edit_button:SetFullWidth(true)
    edit_button:SetDisabled(value.item == nil or value.disabled)
    edit_button:SetUserData("cell", { alignV = "bottom" })
    edit_button:SetCallback("OnClick", function(widget, event, ...)
        local edit_callback = function()
            update_action_image()
            if type(value.item) == "string" then
                addon:UpdateBoundButton(value.item)
            end
            update()
        end
        if type(value.item) == "string" then
            local itemset = nil
            if itemsets[value.item] ~= nil then
                itemset = itemsets[value.item]
            elseif global_itemsets[value.item] ~= nil then
                itemset = global_itemsets[value.item]
            end

            if itemset then
                if top then
                    top:SetCallback("OnClose", function(widget) end)
                    top:Hide()
                end
                addon:item_list_popup(itemset.name, itemset.items, edit_callback, top and function(widget)
                    AceGUI:Release(widget)
                    addon.LayoutConditionFrame(top)
                    top:Show()
                end)
            end
        else
            if top then
                top:SetCallback("OnClose", function(widget) end)
                top:Hide()
            end
            addon:item_list_popup(L["Custom"], value.item, edit_callback, top and function(widget)
                AceGUI:Release(widget)
                addon.LayoutConditionFrame(top)
                top:Show()
            end)
        end
    end)
    item_group:AddChild(edit_button)

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
    operator:SetDisabled(value.disabled)
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
    edit:SetDisabled(value.disabled)
    operator_group:AddChild(edit)

    return operator_group
end

function addon:Widget_OperatorPercentWidget(value, name, update)
    local operator_group = AceGUI:Create("SimpleGroup")
    operator_group:SetLayout("Table")
    operator_group:SetUserData("table", { columns = { 0, 150 } })

    local operator = AceGUI:Create("Dropdown")
    operator:SetFullWidth(true)
    operator:SetLabel(L["Operator"])
    operator:SetCallback("OnValueChanged", function(widget, event, v)
        value.operator = v
        update()
    end)
    operator:SetDisabled(value.disabled)
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
    edit:SetDisabled(value.disabled)
    operator_group:AddChild(edit)

    return operator_group
end

function addon:Widget_UnitWidget(value, units, update, field)
    if field == nil then
        field = "unit"
    end
    local unit = AceGUI:Create("Dropdown")
    unit:SetLabel(L["Unit"])
    unit:SetCallback("OnValueChanged", function(widget, event, v)
        value[field] = v
        update()
    end)
    unit:SetDisabled(value.disabled)
    unit.configure = function()
        unit:SetList(units, keys(units))
        unit:SetValue(value[field])
    end

    return unit
end
