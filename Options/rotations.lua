local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")

local isint, isSpellOnSpec = addon.isint, addon.isSpellOnSpec
local pairs, color, tonumber = pairs, color, tonumber

function addon:get_rotation_list(frame, specID, rotid, id, callback)
    if addon.active_effect_icon then
        addon:StopCustomGlow(addon.active_effect_icon)
        addon.active_effect_icon = nil
    end

    local rotation_settings = self.db.char.rotations[specID][rotid]

    local spacer = function(width)
        local rv = AceGUI:Create("Label")
        rv:SetRelativeWidth(width)
        return rv
    end

    frame:ReleaseChildren()
    frame:PauseLayout()

    local idx, rot
    for tidx, trot in pairs(rotation_settings.rotation) do
        if trot.id == id then
            idx = tidx
            rot = trot
            break
        end
    end

    if idx == nil then
        frame:ResumeLayout()
        frame:DoLayout()
        return
    end

    -- Layout first ...
    local button_group = AceGUI:Create("SimpleGroup")
    frame:AddChild(button_group)
    local moveup = AceGUI:Create("Button")
    button_group:AddChild(moveup)
    local movedown = AceGUI:Create("Button")
    button_group:AddChild(movedown)
    local delete = AceGUI:Create("Button")
    button_group:AddChild(delete)
    local icon_group = AceGUI:Create("SimpleGroup")
    frame:AddChild(icon_group)

    local action_icon, action
    if rot.type ~= nil and rot.type == "spell" then
        action_icon = AceGUI:Create("ActionSlotSpell")
        action = AceGUI:Create("Spec_EditBox")
    elseif rot.type ~= nil and rot.type == "pet" then
        action_icon = AceGUI:Create("ActionSlotSpell")
        action = AceGUI:Create("Spell_EditBox")
    elseif rot.type ~= nil and rot.type == "item" then
        action_icon = AceGUI:Create("ActionSlotItem")
        action = AceGUI:Create("Inventory_EditBox")
    else
        action = AceGUI:Create("EditBox")
        action_icon = AceGUI:Create("Icon")
    end
    icon_group:AddChild(action_icon)
    local use_name = AceGUI:Create("CheckBox")
    icon_group:AddChild(use_name)
    local name = AceGUI:Create("EditBox")
    icon_group:AddChild(name)

    local type = AceGUI:Create("Dropdown")
    frame:AddChild(type)
    frame:AddChild(action)

    local conditions = AceGUI:Create("InlineGroup")
    frame:AddChild(conditions)


    button_group:SetFullWidth(true)
    button_group:SetLayout("Table")
    button_group:SetUserData("table", { columns = { 1, 1, 1 } })

    moveup:SetText(L["Move Up"])
    moveup:SetDisabled(idx == 1)
    moveup:SetCallback("OnClick", function(widget, event)
        rotation_settings.rotation[idx] = rotation_settings.rotation[idx - 1]
        idx = idx - 1
        rotation_settings.rotation[idx] = rot
        callback()
    end)

    movedown:SetText(L["Move Down"])
    movedown:SetDisabled(idx == #rotation_settings.rotation)
    movedown:SetCallback("OnClick", function(widget, event)
        rotation_settings.rotation[idx] = rotation_settings.rotation[idx + 1]
        idx = idx + 1
        rotation_settings.rotation[idx] = rot
        callback()
    end)

    delete:SetText(DELETE)
    delete:SetCallback("OnClick", function(widget, event)
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
        table.remove(rotation_settings.rotation, idx)
        frame:ReleaseChildren()
        frame:DoLayout()
        callback()
    end)

    icon_group:SetFullWidth(true)
    icon_group:SetLayout("Table")
    icon_group:SetUserData("table", { columns = { 44, 24, 1 } })

    if rot.type ~= nil and rot.type == "spell" then
        if (rot.action) then
            action_icon:SetText(rot.action)
        end
        action_icon:SetWidth(44)
        action_icon:SetHeight(44)
        action_icon.text:Hide()
        action_icon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(specID, v) then
                addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
                rot.action = v
                action_icon:SetText(v)
                if v then
                    action:SetText(SpellData:SpellName(v))
                else
                    action:SetText(nil)
                end

                callback()
            end
        end)

        action:SetUserData("spec", specID)
        action:SetLabel(L["Spell"])
        action:SetText(rot.action and SpellData:SpellName(rot.action))
        action:SetCallback("OnEnterPressed", function(widget, event, val)
            addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
            if isint(val) then
                if isSpellOnSpec(specID, tonumber(val)) then
                    rot.action = tonumber(val)
                else
                    rot.action = nil
                    action:SetText(nil)
                end
            else
                rot.action = addon:GetSpecSpellID(specID, val)
                if rot.action == nil then
                    action:SetText(nil)
                end
            end
            action_icon:SetText(rot.action)
            callback()
        end)
    elseif rot.type ~= nil and rot.type == "pet" then
        if (rot.action) then
            action_icon:SetText(rot.action)
        end
        action_icon:SetWidth(44)
        action_icon:SetHeight(44)
        action_icon.text:Hide()
        action_icon:SetCallback("OnEnterPressed", function(widget, event, v)
            addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
            v = tonumber(v)
            rot.action = v
            action_icon:SetText(v)
            if v then
                action:SetText(SpellData:SpellName(v))
            else
                action:SetText(nil)
            end

            callback()
        end)

        action:SetLabel(L["Spell"])
        action:SetText(rot.action and SpellData:SpellName(rot.action))
        action:SetCallback("OnEnterPressed", function(widget, event, val)
            addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
            local spellid = select(7, GetSpellInfo(v))
            rot.action = spellid
            action_icon:SetText(rot.action)
            callback()
        end)
    elseif rot.type ~= nil and rot.type == "item" then
        if (rot.action) then
            action_icon:SetText(GetItemInfoInstant(rot.action))
        end
        action_icon:SetWidth(44)
        action_icon:SetHeight(44)
        action_icon.text:Hide()
        action_icon:SetCallback("OnEnterPressed", function(widget, event, v)
            if v then
                rot.action = GetItemInfo(v)
            else
                rot.action = nil
            end
            action_icon:SetText(v)
            action:SetText(rot.action)
        end)

        action:SetLabel(L["Item"])
        action:SetText(rot.action)
        action:SetCallback("OnEnterPressed", function(widget, event, val)
            addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
            local itemID = GetItemInfoInstant(val)
            if itemID ~= nil then
                action_icon:SetText(itemID)
            else
                action_icon:SetText(nil)
            end
            rot.action = val
            callback()
        end)
    else
        action:SetDisabled(true)
        action_icon:SetImageSize(36, 36)
        action_icon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    use_name:SetValue(rot.use_name)
    use_name:SetCallback("OnValueChanged", function(widget, event, val)
        rot.use_name = val
        if not rot.use_name then
            rot.name = nil
        end
        callback()
    end)

    name:SetLabel(NAME)
    name:SetDisabled(not rot.use_name)
    if rot.use_name then
        name:SetText(rot.name)
    elseif rot.action ~= nil then
        if rot.type == "spell" or rot.type =="petspell" then
            name:SetText(GetSpellInfo(rot.action))
        else
            name:SetText(rot.action)
        end
    end
    name:SetFullWidth(true)
    name:SetCallback("OnEnterPressed", function(widget, event, val)
        rot.name = val
        callback()
    end)

    local types = {
        spell = L["Spell"],
        pet = L["Pet Spell"],
        item = L["Item"],
    }

    type:SetLabel(L["Action Type"])
    type:SetRelativeWidth(0.3)
    type:SetList(types, { "spell", "pet", "item" })
    type:SetValue(rot.type)
    type:SetCallback("OnValueChanged", function(widget, event, val)
        if rot.type ~= val then
            rot.type = val
            rot.action = nil
            addon:get_rotation_list(frame, specID, rotid, id, callback)
        end
    end)

    action:SetRelativeWidth(0.7)

    conditions:SetFullWidth(true)
    conditions:SetFullHeight(true)
    conditions:SetLayout("Flow")
    conditions:SetTitle(L["Conditions"])

    local function layout_conditions()
        conditions:ReleaseChildren()
        conditions:PauseLayout()

        local condition_desc = AceGUI:Create("Label")
        conditions:AddChild(condition_desc)
        local condition_eval = AceGUI:Create("Label")
        conditions:AddChild(condition_eval)
        local edit_button = AceGUI:Create("Button")

        condition_desc:SetFullWidth(true)
        condition_desc:SetText(addon:printCondition(rot.conditions, specID))

        if not addon:validateCondition(rot.conditions, specID) then
            local condition_valid = AceGUI:Create("Heading")
            conditions:AddChild(condition_valid)

            condition_valid:SetFullWidth(true)
            condition_valid:SetText(color.RED .. L["THIS CONDITION DOES NOT VALIDATE"] .. color.RESET)
            addon.currentConditionEval = nil
        else
            if specID == addon.currentSpec then
                local function update_eval()
                    if addon:evaluateCondition(rot.conditions) then
                        condition_eval:SetText(color.GREEN .. L["Currently satisfied"] .. color.RESET)
                    else
                        condition_eval:SetText(color.RED .. L["Not currently satisfied"] .. color.RESET)
                    end
                end
                update_eval()
                addon.currentConditionEval = update_eval
                condition_eval.frame:SetScript("OnHide", function(frame)
                    addon.currentConditionEval = nil
                end)
                condition_eval.frame:SetScript("OnShow", function(frame)
                    addon.currentConditionEval = update_eval
                end)
            else
                addon.currentConditionEval = nil
            end
        end

        conditions:AddChild(edit_button)
        local enabledisable_button = AceGUI:Create("Button")
        conditions:AddChild(enabledisable_button)

        condition_eval:SetRelativeWidth(0.5)

        edit_button:SetText(EDIT)
        edit_button:SetRelativeWidth(0.25)
        edit_button:SetCallback("OnClick", function(widget, event)
            if rot.conditions == nil then
                rot.conditions = { type = nil }
            end
            addon:EditCondition(idx, specID, rot.conditions, function()
                layout_conditions()
                callback()
            end)

        end)

        if not rot.disabled then
            enabledisable_button:SetText(DISABLE)
            enabledisable_button:SetRelativeWidth(0.25)
            enabledisable_button:SetCallback("OnClick", function(widget, event)
                rot.disabled = true
                addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
                layout_conditions()
                callback()
            end)
        else
            enabledisable_button:SetText(ENABLE)
            enabledisable_button:SetRelativeWidth(0.25)
            enabledisable_button:SetCallback("OnClick", function(widget, event)
                rot.disabled = false
                layout_conditions()
                callback()
            end)
        end

        conditions:ResumeLayout()
        conditions:DoLayout()
    end
    layout_conditions()

    frame:ResumeLayout()
    frame:DoLayout()
end

