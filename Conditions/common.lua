local addon_name, addon = ...

local SpellData = addon.SpellCatalog
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- Portable condition fields contain ordinary saved data, never live secrets.
function addon.IsConditionSpellID(value)
    return type(value)=="number" and value>0 and value<math.huge and value%1==0
end

function addon:Widget_GetSpellId(spellid, ranked)
    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        if not ranked then
            local resolved, reason = SpellData:GetSpellId(spellid)
            return resolved, reason or (not resolved and "spell-data-unavailable" or nil)
        end
    end
    return spellid
end

function addon:Widget_GetSpellLink(spellid, ranked)
    if spellid ~= nil then
        if ranked then
            local rank = SpellData:SpellRank(spellid)
            if rank then
               return (SpellData:SpellLink(spellid) or self:SpellLabel(spellid)) .. "|cFF888888 (" .. rank .. ")|r"
            end
        else
            spellid = self:Widget_GetSpellId(spellid, ranked)
        end
        return SpellData:SpellLink(spellid) or self:SpellLabel(spellid)
    end

    return nil
end

function addon:Widget_SpellWidget(spec, editbox, value, nametoid, isvalid, update)
    local spell_group = addon:CreateConditionGroup()
    spell_group:SetLayout('RM-SpellField')
    local rankChoice

    local spell = addon:CreateSpellEditBox(editbox,value.spell)
    local initialSpell=type(value.spell)=="string" and SpellData:GetSpellId(value.spell) or value.spell
    local spellIcon = addon:CreateSpellActionIcon(spec == BOOKTYPE_PET and "pet" or "spell",initialSpell,isvalid)
    spellIcon:SetWidth(44)
    spellIcon:SetHeight(44)
    spellIcon:SetText(value.spell)
    spellIcon:SetCallback("OnEnterPressed", function(_, _, v)
        v = tonumber(v)
        if v and isvalid(v) then
            value.spell = v
            spellIcon:SetText(v)
            spell:SetText(SpellData:SpellName(value.spell, not value.ranked))
            if GameTooltip:IsOwned(spellIcon.frame) and GameTooltip:IsVisible() then
                GameTooltip:SetHyperlink("spell:" .. v)
            end
        else
            value.spell = nil
            spellIcon:SetText(nil)
            spell:SetText(nil)
            if GameTooltip:IsOwned(spellIcon.frame) and GameTooltip:IsVisible() then
                GameTooltip:Hide()
            end
        end
        update()
    end)
    spellIcon:SetCallback("OnEnter", function()
        if value.spell then
            GameTooltip:SetOwner(spellIcon.frame, "ANCHOR_BOTTOMRIGHT", 3)
            GameTooltip:SetHyperlink("spell:" .. value.spell)
        end
    end)
    spellIcon:SetCallback("OnLeave", function()
        if GameTooltip:IsOwned(spellIcon.frame) then
            GameTooltip:Hide()
        end
    end)
    spellIcon:SetDisabled(value.disabled)
    spell_group:AddChild(spellIcon)

    if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and spec ~= BOOKTYPE_PET then
        local nr_button = addon:CreateConditionCheckBox()
        nr_button:SetLabel(L["Use this exact spell rank"])
        nr_button:SetValue(value.ranked or false)
        nr_button:SetCallback("OnValueChanged", function(_, _, val)
            value.ranked = val
            spell:SetUserData("norank", not val)
            spell:SetText(value.spell and SpellData:SpellName(value.spell, not value.ranked))
            update()
        end)
        nr_button:SetDisabled(value.disabled)
        rankChoice=nr_button
    end

    spell:SetFullWidth(true)
    spell:SetLabel('')
    spell:SetText(value.spell and SpellData:SpellName(value.spell, not value.ranked))
    spell:SetUserData("norank", not value.ranked)
    spell:SetUserData("spec", spec)
    spell:SetCallback("OnEnterPressed", function(_, _, v)
        if not addon.isint(v) then
            v = nametoid(v)
        else
            v = tonumber(v)
        end
        if isvalid(v) then
            value.spell = v
            spell:SetText(SpellData:SpellName(value.spell, not value.ranked))
        else
            value.spell = nil
            spell:SetText(nil)
        end
        spellIcon:SetText(value.spell)
        update()
    end)
    spell:SetDisabled(value.disabled)
    spell_group:AddChild(spell)
    if rankChoice then
        rankChoice.frame.GetFontString=function() return rankChoice.button:GetFontString() end
        spell_group:AddChild(rankChoice)
    end

    return spell_group
end

function addon:Widget_SpellNameWidget(spec, editbox, value, isvalid, update, storeId)
    local spell_group = addon:CreateConditionGroup()
    spell_group:SetLayout("Table")
    spell_group:SetUserData("table", { columns = { 44, 1 } })

    local spell = addon:CreateSpellEditBox(editbox,value.spell)
    local initialSpell=type(value.spell)=="string" and SpellData:GetSpellId(value.spell) or value.spell
    local spellIcon = addon:CreateSpellActionIcon(spec == BOOKTYPE_PET and "pet" or "spell",initialSpell,isvalid)
    spellIcon:SetWidth(44)
    spellIcon:SetHeight(44)
    if value.spell then
        spellIcon:SetText(initialSpell)
    end
    spellIcon:SetCallback("OnEnterPressed", function(_, _, v)
        v = tonumber(v)
        if v and isvalid(v) then
            local name = SpellData:SpellName(v, not storeId)
            value.spell = storeId and v or name
            spellIcon:SetText(v)
            spell:SetText(storeId and v or name)
            if GameTooltip:IsOwned(spellIcon.frame) and GameTooltip:IsVisible() then
                GameTooltip:SetHyperlink("spell:" .. v)
            end
        else
            value.spell = nil
            spellIcon:SetText(nil)
            spell:SetText(nil)
            if GameTooltip:IsOwned(spellIcon.frame) and GameTooltip:IsVisible() then
                GameTooltip:Hide()
            end
        end
        update()
    end)
    spellIcon:SetCallback("OnEnter", function()
        local id=spellIcon:GetUserData("spell")
        if id then
            GameTooltip:SetOwner(spellIcon.frame, "ANCHOR_BOTTOMRIGHT", 3)
            GameTooltip:SetHyperlink("spell:" .. id)
        end
    end)
    spellIcon:SetCallback("OnLeave", function()
        if GameTooltip:IsOwned(spellIcon.frame) then
            GameTooltip:Hide()
        end
    end)
    spellIcon:SetDisabled(value.disabled)
    spell_group:AddChild(spellIcon)

    spell:SetFullWidth(true)
    spell:SetLabel(L["Spell"])
    spell:SetText(value.spell)
    spell:SetUserData("norank", not (storeId or value.ranked))
    spell:SetUserData("spec", spec)
    spell:SetCallback("OnEnterPressed", function(_, _, v)
        local spellid = SpellData:ResolveSelection(v)
        local name = SpellData:SpellName(spellid, not storeId)

        if isvalid(spellid) then
            value.spell = storeId and spellid or name
            spell:SetText(storeId and spellid or name)
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

function addon:Widget_AuraRankWidget(value,update)
    local check=self:CreateConditionCheckBox();check:SetLabel(L['Match all ranks']);check:SetWidth(170);check:SetValue(value.anyrank==true);check:SetDisabled(value.disabled)
    check:SetCallback('OnValueChanged',function(_,_,enabled) value.anyrank=enabled and true or nil;update() end)
    return check
end

function addon:Widget_ItemWidget(top, editbox, value, isvalid, update)
    local itemsets = addon.db.profile.itemsets
    local global_itemsets = addon.db.global.itemsets

    local item_group = addon:CreateConditionGroup()
    local lease=item_group.rmLease;local profile,global=addon.db.profile,addon.db.global
    local function ownerAlive() return item_group.rmActive and item_group.rmLease==lease and not item_group:IsReleasing() and addon.db.profile==profile and addon.db.global==global end
    local function closePopup(widget)
        addon:ReleaseConditionWidget(widget)
        if top then
            if type(top.rmResumeFromChild)=='function' then top.rmResumeFromChild()
            elseif ownerAlive() then addon.LayoutConditionFrame(top);top:Show() end
        end
    end
    item_group:SetLayout("Table")
    item_group:SetUserData("table", { columns = { 44, 1, 24 } })

    local itemIcon = addon:CreateConditionIcon()
    local update_action_image = function()
        if value.item ~= nil then
            if type(value.item) == "string" then
                local itemid = addon:FindFirstItemOfItemSet({}, value.item, true) or addon:FindFirstItemInItemSet(value.item)
                addon:UpdateItem_ID_Image(itemid, nil, itemIcon)
            elseif #value.item > 0 then
                local itemid = addon:FindFirstItemOfItems({}, value.item, true) or addon:FindFirstItemInItems(value.item)
                addon:UpdateItem_ID_Image(itemid, nil, itemIcon)
            else
                addon:UpdateItem_ID_Image(nil, nil, itemIcon)
            end
        else
            addon:UpdateItem_ID_Image(nil, nil, itemIcon)
        end
    end
    update_action_image()
    itemIcon:SetImageSize(36, 36)
    itemIcon:SetCallback("OnEnter", function()
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
    itemIcon:SetCallback("OnLeave", function()
        if GameTooltip:IsOwned(itemIcon.frame) then
            GameTooltip:Hide()
        end
    end)
    itemIcon:SetDisabled(value.disabled)
    item_group:AddChild(itemIcon)

    local edit_button = addon:CreateConditionIcon()

    local item = addon:CreateConditionDropdown()
    item:SetFullWidth(true)
    item:SetLabel(L["Item Set"])
    item:SetCallback("OnValueChanged", function(_, _, val)
        if val ~= nil then
            if val == "" then
                value.item = {}
            else
                value.item = val
            end
            edit_button:SetDisabled(false)
            edit_button:SetImage("Interface\\FriendsFrame\\UI-FriendsList-Large-Up")
        else
            value.item = nil
            edit_button:SetDisabled(true)
            edit_button:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-FriendsList-Large-Disabled")
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

    edit_button:SetImageSize(24, 24)
    edit_button:SetImage("Interface\\FriendsFrame\\UI-FriendsList-Large-Up")
    edit_button:SetUserData("cell", { alignV = "bottom" })
    addon.AddTooltip(edit_button, EDIT)
    if value.item == nil or value.disabled then
        edit_button:SetDisabled(true)
        edit_button:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-FriendsList-Large-Disabled")
    else
        edit_button:SetDisabled(false)
        edit_button:SetImage("Interface\\FriendsFrame\\UI-FriendsList-Large-Up")
    end
    edit_button:SetUserData("cell", { alignV = "bottom" })
    edit_button:SetCallback("OnClick", function()
        if not ownerAlive() then return end
        local edit_callback = function()
            if not ownerAlive() then return end
            update_action_image()
            if type(value.item) == "string" then
                addon:UpdateBoundButton(value.item)
            end
            update()
        end
        if type(value.item) == "string" then
            local itemset
            if itemsets[value.item] ~= nil then
                itemset = itemsets[value.item]
            elseif global_itemsets[value.item] ~= nil then
                itemset = global_itemsets[value.item]
            end

            if itemset then
                if top then
                    top:SetCallback("OnClose", function() end)
                    top:Hide()
                end
                local selected,expected,items=value.item,itemset,itemset.items
                local function current()
                    if not ownerAlive() or value.item~=selected or expected.items~=items then return false end
                    local personal=addon.db.profile.itemsets;local shared=addon.db.global.itemsets
                    local entry=type(personal)=='table' and personal[selected]
                    if entry==nil then entry=type(shared)=='table' and shared[selected] end
                    return entry==expected
                end
                addon:item_list_popup(itemset.name, editbox, items, isvalid, edit_callback, top and closePopup or nil,{valid=current})
            end
        else
            if top then
                top:SetCallback("OnClose", function() end)
                top:Hide()
            end
            local items=value.item
            addon:item_list_popup(L["Custom"], editbox, items, isvalid, edit_callback, top and closePopup or nil,{valid=function() return ownerAlive() and value.item==items end})
        end
    end)
    item_group:AddChild(edit_button)

    return item_group
end

function addon:Widget_SingleItemWidget(spec, editbox, value, isvalid, update)
    local item_group = addon:CreateConditionGroup()
    item_group:SetLayout("Table")

    item_group:SetUserData("table", { columns = { 44, 1 } })

    local item = addon:CreateItemEditBox(editbox,value.item)
    local itemIcon = addon:CreateItemActionIcon(value.item,isvalid)
    itemIcon:SetWidth(44)
    itemIcon:SetHeight(44)
    itemIcon:SetCallback("OnEnterPressed", function(_, _, v)
        v = tonumber(v)
        if v and isvalid(v) then
            value.item = v
            if GameTooltip:IsOwned(itemIcon.frame) and GameTooltip:IsVisible() then
                GameTooltip:SetHyperlink("item:" .. v)
            end
        else
            value.item = nil
            if GameTooltip:IsOwned(itemIcon.frame) and GameTooltip:IsVisible() then
                GameTooltip:Hide()
            end
        end
        addon:UpdateItem_Name_ID(value.item, item, itemIcon)
        update()
    end)
    itemIcon:SetCallback("OnEnter", function()
        if value.item then
            local itemid = addon.Platform:GetItemID(value.item)
            if itemid then
                GameTooltip:SetOwner(itemIcon.frame, "ANCHOR_BOTTOMRIGHT", 3)
                GameTooltip:SetHyperlink("item:" .. itemid)
            end
        end
    end)
    itemIcon:SetCallback("OnLeave", function()
        if GameTooltip:IsOwned(itemIcon.frame) then
            GameTooltip:Hide()
        end
    end)
    itemIcon:SetDisabled(value.disabled)
    item_group:AddChild(itemIcon)

    item:SetFullWidth(true)
    item:SetLabel(L["Item"])
    item:SetUserData("spec", spec)
    item:SetCallback("OnEnterPressed", function(_, _, v)
        local itemid
        if not addon.Functions.values.isint(v) then
            itemid = addon.Platform:GetItemID(v)
        else
            itemid = tonumber(v)
        end
        if isvalid(itemid or v) then
            value.item = itemid or v
        else
            value.item = nil
        end
        addon:UpdateItem_Name_ID(value.item, item, itemIcon)
        update()
    end)
    item:SetDisabled(value.disabled)
    item_group:AddChild(item)

    addon:UpdateItem_Name_ID(value.item, item, itemIcon)

    return item_group
end

function addon:Widget_OperatorWidget(value, name, update, op_field, val_field)
    local operator_group = addon:CreateConditionGroup()
    operator_group:SetLayout("Table")
    operator_group:SetUserData("table", { columns = { 0, 75 } })

    local operator = addon:CreateConditionDropdown()
    operator:SetFullWidth(true)
    operator:SetLabel(L["Operator"])
    operator:SetCallback("OnValueChanged", function(_, _, v)
        value[op_field or "operator"] = v
        update()
    end)
    operator:SetDisabled(value.disabled)
    operator.configure = function()
        operator:SetList(addon.operators, addon.Functions.collections.keys(addon.operators))
        operator:SetValue(value[op_field or "operator"])
    end
    operator_group:AddChild(operator)

    local edit = addon:CreateConditionEditBox()
    edit:SetFullWidth(true)
    edit:SetLabel(name)
    edit:SetText(value[val_field or "value"])
    edit:SetCallback("OnEnterPressed", function(_, _, v)
        value[val_field or "value"] = tonumber(v)
        update()
    end)
    edit:SetDisabled(value.disabled)
    operator_group:AddChild(edit)

    return operator_group
end

function addon:Widget_OperatorPercentWidget(value, name, update, op_field, val_field)
    local operator_group = addon:CreateConditionGroup()
    operator_group:SetLayout("Table")
    operator_group:SetUserData("table", { columns = { 0, 150 } })

    local operator = addon:CreateConditionDropdown()
    operator:SetFullWidth(true)
    operator:SetLabel(L["Operator"])
    operator:SetCallback("OnValueChanged", function(_, _, v)
        value[op_field or "operator"] = v
        update()
    end)
    operator:SetDisabled(value.disabled)
    operator.configure = function()
        operator:SetList(addon.operators, addon.Functions.collections.keys(addon.operators))
        operator:SetValue(value[op_field or "operator"])
    end
    operator_group:AddChild(operator)

    local edit = addon:CreateConditionSlider()
    edit:SetFullWidth(true)
    edit:SetLabel(name)
    if (value[val_field or "value"] ~= nil) then
        edit:SetValue(value[val_field or "value"])
    end
    edit:SetSliderValues(0, 1, 0.01)
    edit:SetIsPercent(true)
    edit:SetCallback("OnValueChanged", function(_, _, v)
        value[val_field or "value"] = tonumber(v)
        update()
    end)
    edit:SetDisabled(value.disabled)
    operator_group:AddChild(edit)

    return operator_group
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="SpellData" then return SpellData end
        if name=="Widget_GetSpellId" then return addon.Widget_GetSpellId end
        if name=="Widget_SpellWidget" then return addon.Widget_SpellWidget end
        if name=="Widget_UnitWidget" then return addon.Widget_UnitWidget end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/common.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/common.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
