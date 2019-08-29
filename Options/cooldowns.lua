local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")

local isint, isSpellOnSpec = addon.isint, addon.isSpellOnSpec
local pairs, color, tonumber = pairs, color, tonumber

function addon:get_cooldown_list(frame, specID, rotid, id, callback)
    if addon.active_effect_icon then
        addon:StopCustomGlow(addon.active_effect_icon)

        addon.active_effect_icon = nil
    end

    local profile = addon.db.profile
    local rotation_settings = profile.rotations[specID][rotid]
    local effects = self.db.global.effects

    local spacer = function(width)
        local rv = AceGUI:Create("Label")
        rv:SetRelativeWidth(width)
        return rv
    end

    frame:ReleaseChildren()
    frame:PauseLayout()

    local idx, rot
    for tidx, trot in pairs(rotation_settings.cooldowns) do
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

    local button_group = AceGUI:Create("SimpleGroup")
    button_group:SetFullWidth(true)
    button_group:SetLayout("Table")
    button_group:SetUserData("table", { columns = { 1, 1, 1 } })
    frame:AddChild(button_group)

    local moveup = AceGUI:Create("Button")
    moveup:SetText(L["Move Up"])
    moveup:SetDisabled(idx == 1)
    moveup:SetCallback("OnClick", function(widget, event)
        rotation_settings.cooldowns[idx] = rotation_settings.cooldowns[idx - 1]
        idx = idx - 1
        rotation_settings.cooldowns[idx] = rot
        callback()
    end)
    button_group:AddChild(moveup)

    local movedown = AceGUI:Create("Button")
    movedown:SetText(L["Move Down"])
    movedown:SetDisabled(idx == #rotation_settings.cooldowns)
    movedown:SetCallback("OnClick", function(widget, event)
        rotation_settings.cooldowns[idx] = rotation_settings.cooldowns[idx + 1]
        idx = idx + 1
        rotation_settings.cooldowns[idx] = rot
        callback()
    end)
    button_group:AddChild(movedown)

    local delete = AceGUI:Create("Button")
    delete:SetText(DELETE)
    delete:SetCallback("OnClick", function(widget, event)
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
        table.remove(rotation_settings.cooldowns, idx)
        frame:ReleaseChildren()
        frame:DoLayout()
        callback()
    end)
    button_group:AddChild(delete)

    local effect_group = AceGUI:Create("SimpleGroup")
    effect_group:SetRelativeWidth(0.5)
    effect_group:SetLayout("Table")
    effect_group:SetUserData("table", { columns = { 44, 1 } })
    frame:AddChild(effect_group)

    local effect_map, effect_order, name2idx
    local function update_effect_map()
        effect_map = {}
        effect_order = {}
        name2idx = {}
        effect_map[DEFAULT] = DEFAULT
        table.insert(effect_order, DEFAULT)

        for k, v in pairs(effects) do
            if v.name ~= nil then
                table.insert(effect_order, v.name)
                effect_map[v.name] = v.name
                name2idx[v.name] = k
            end
        end
    end
    update_effect_map()

    local effect_icon = AceGUI:Create("Icon")
    effect_icon:SetImageSize(36, 36)
    if effects[name2idx[rot.effect or profile["effect"]]].type == "texture" then
        effect_icon:SetHeight(44)
        effect_icon:SetWidth(44)
        effect_icon:SetImage(effects[name2idx[rot.effect or profile["effect"]]].texture)
    else
        effect_icon:SetImage(nil)
        effect_icon:SetHeight(36)
        effect_icon:SetWidth(36)
        addon:ApplyCustomGlow(effects[name2idx[rot.effect or profile["effect"]]], effect_icon.frame, nil, rot.color)
    end
    addon.active_effect_icon = effect_icon.frame
    effect_group:AddChild(effect_icon)

    local magnification = AceGUI:Create("Slider")

    local effect = AceGUI:Create("Dropdown")
    effect:SetLabel(L["Effect"])
    effect:SetText(effect_map[rot.effect or DEFAULT])
    effect:SetValue(rot.effect or DEFAULT)
    effect:SetList(effect_map, effect_order)
    effect:SetHeight(44)
    effect:SetCallback("OnValueChanged", function(widget, event, val)
        if val == DEFAULT then
            rot.effect = nil
        else
            rot.effect = val
        end
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
        addon:get_cooldown_list(frame, specID, rotid, id, callback)
    end)
    effect.frame:SetScript("OnShow", function(frame)
        update_effect_map()
        effect:SetList(effect_map, effect_order)
    end)
    effect_group:AddChild(effect)

    frame:AddChild(spacer(0.05))

    magnification:SetLabel(L["Magnification"])
    magnification:SetValue(rot.magnification or profile["magnification"])
    magnification:SetRelativeWidth(0.45)
    magnification:SetSliderValues(0.1, 2.0, 0.1)
    magnification:SetDisabled(effects[name2idx[rot.effect or profile["effect"]]].type ~= "texture")
    magnification:SetCallback("OnValueChanged", function(widget, event, val)
        if val == profile["magnification"] then
            rot.magnification = nil
        else
            rot.magnification = val
        end
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
    end)
    frame:AddChild(magnification)

    if rot.color == nil then
        rot.color = { r = 0, g = 1.0, b = 0, a = 1.0 }
    end
    local color_pick = AceGUI:Create("ColorPicker")
    color_pick:SetColor(rot.color.r, rot.color.g, rot.color.b, rot.color.a)
    color_pick:SetLabel(L["Highlight Color"])
    color_pick:SetRelativeWidth(0.35)
    color_pick:SetCallback("OnValueConfirmed", function(widget, event, r, g, b, a)
        rot.color = { r = r, g = g, b = b, a = a }
        if effects[name2idx[rot.effect or profile["effect"]]].type ~= "texture" then
            addon:ApplyCustomGlow(effects[name2idx[rot.effect or profile["effect"]]], effect_icon.frame, nil, rot.color)
        end
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
    end)
    frame:AddChild(color_pick)

    local position_group = AceGUI:Create("SimpleGroup")
    position_group:SetLayout("Table")
    position_group:SetRelativeWidth(0.65)
    position_group:SetUserData("table", { columns = { 1, 20, 35, 50 } })
    frame:AddChild(position_group)

    local setpoint_values = addon.deepcopy(addon.setpoints)
    setpoint_values[DEFAULT] = DEFAULT

    local update_position_buttons

    local position = AceGUI:Create("Dropdown")
    position:SetLabel(L["Position"])
    position:SetText(setpoint_values[rot.setpoint or DEFAULT])
    position:SetValue(rot.setpoint or DEFAULT)
    position:SetList(setpoint_values, { DEFAULT, "CENTER", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOP", "BOTTOM", "LEFT", "RIGHT" })
    position:SetCallback("OnValueChanged", function(widget, event, val)
        if val == DEFAULT then
            rot.setpoint = nil
            rot.xoffs = nil
            rot.yoffs = nil
        else
            rot.setpoint = val
            rot.xoffs = 0
            rot.yoffs = 0
        end
        update_position_buttons()
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
    end)
    position_group:AddChild(position)

    position_group:AddChild(spacer(0.1))

    local directional_group = AceGUI:Create("SimpleGroup")
    directional_group:SetLayout("Table")
    directional_group:SetUserData("table", { columns = { 10, 10, 10 } })
    position_group:AddChild(directional_group)

    local offset_group = AceGUI:Create("SimpleGroup")
    offset_group:SetLayout("Table")
    offset_group:SetUserData("table", { columns = { 10, 40 } })
    position_group:AddChild(offset_group)

    local x_label = AceGUI:Create("Label")
    x_label:SetText("X")
    x_label:SetColor(1.0, 0.82, 0)
    offset_group:AddChild(x_label)

    local x_offs = AceGUI:Create("EditBox")
    x_offs:SetDisabled(true)
    offset_group:AddChild(x_offs)

    local y_label = AceGUI:Create("Label")
    y_label:SetText("Y")
    y_label:SetColor(1.0, 0.82, 0)
    offset_group:AddChild(y_label)

    local y_offs = AceGUI:Create("EditBox")
    y_offs:SetDisabled(true)
    offset_group:AddChild(y_offs)

    directional_group:AddChild(spacer(1))

    local button_up = AceGUI:Create("InteractiveLabel")
    button_up:SetText("^")
    button_up:SetColor(0, 1.0, 1.0)
    button_up:SetCallback("OnClick", function(widget, event, val)
        rot.yoffs = (rot.yoffs or 0) + 1
        y_offs:SetText(rot.yoffs)
        addon:RemoveAllCurrentGlows()
    end)
    directional_group:AddChild(button_up)

    directional_group:AddChild(spacer(1))

    local button_left = AceGUI:Create("InteractiveLabel")
    button_left:SetText("<")
    button_left:SetColor(0, 1.0, 1.0)
    button_left:SetCallback("OnClick", function(widget, event, val)
        rot.xoffs = (rot.xoffs or 0) - 1
        x_offs:SetText(rot.xoffs)
        addon:RemoveAllCurrentGlows()
    end)
    directional_group:AddChild(button_left)

    local button_center = AceGUI:Create("InteractiveLabel")
    button_center:SetText("o")
    button_center:SetColor(0, 1.0, 1.0)
    button_center:SetCallback("OnClick", function(widget, event, val)
        rot.xoffs = 0
        rot.yoffs = 0
        x_offs:SetText(rot.xoffs)
        y_offs:SetText(rot.yoffs)
        addon:RemoveAllCurrentGlows()
    end)
    directional_group:AddChild(button_center)

    local button_right = AceGUI:Create("InteractiveLabel")
    button_right:SetText(">")
    button_right:SetColor(0, 1.0, 1.0)
    button_right:SetCallback("OnClick", function(widget, event, val)
        rot.xoffs = (rot.xoffs or 0) + 1
        x_offs:SetText(rot.xoffs)
        addon:RemoveAllCurrentGlows()
    end)
    directional_group:AddChild(button_right)

    directional_group:AddChild(spacer(1))

    local button_down = AceGUI:Create("InteractiveLabel")
    button_down:SetText("v")
    button_down:SetColor(0, 1.0, 1.0)
    button_down:SetCallback("OnClick", function(widget, event, val)
        rot.yoffs = (rot.yoffs or 0) - 1
        y_offs:SetText(rot.yoffs)
        addon:RemoveAllCurrentGlows()
    end)
    directional_group:AddChild(button_down)

    directional_group:AddChild(spacer(1))

    update_position_buttons = function()
        local disable = effects[name2idx[rot.effect or profile["effect"]]] ~= nil and
            (effects[name2idx[rot.effect or profile["effect"]]].type == "blizzard" or
            (effects[name2idx[rot.effect or profile["effect"]]].type == "texture" and rot.setpoint == nil)) or false
        position:SetDisabled(effects[name2idx[rot.effect or profile["effect"]]].type ~= "texture")
        button_up:SetDisabled(disable)
        button_left:SetDisabled(disable)
        button_center:SetDisabled(disable)
        button_right:SetDisabled(disable)
        button_down:SetDisabled(disable)
        x_offs:SetText(rot.xoffs or profile["xoffs"])
        y_offs:SetText(rot.yoffs or profile["yoffs"])
    end
    update_position_buttons()

    local icon_group = AceGUI:Create("SimpleGroup")
    icon_group:SetFullWidth(true)
    icon_group:SetLayout("Table")
    icon_group:SetUserData("table", { columns = { 44, 1 } })
    frame:AddChild(icon_group)

    local action_icon, action
    if rot.type ~= nil and rot.type == "spell" then
        action_icon = AceGUI:Create("ActionSlotSpell")
        action = AceGUI:Create("Spec_EditBox")

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
        action_icon = AceGUI:Create("ActionSlotSpell")
        action = AceGUI:Create("Spell_EditBox")

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
            action:SetText(SpellData:SpellName(rot.action))
            action_icon:SetText(rot.action)
            callback()
        end)
    elseif rot.type ~= nil and rot.type == "item" then
        action_icon = AceGUI:Create("ActionSlotItem")
        action = AceGUI:Create("Inventory_EditBox")

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
            action_icon:SetText(itemID)
            rot.action = value
            callback()
        end)
    else
        action = AceGUI:Create("EditBox")
        action:SetDisabled(true)
        action_icon = AceGUI:Create("Icon")
        action_icon:SetImageSize(36, 36)
        action_icon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    icon_group:AddChild(action_icon)

    local name = AceGUI:Create("EditBox")
    name:SetText(rot.name)
    name:SetLabel(NAME)
    name:SetFullWidth(true)
    name:SetCallback("OnEnterPressed", function(widget, event, val)
        rot.name = val
        callback()
    end)
    icon_group:AddChild(name)

    local types = {
        spell = L["Spell"],
        pet = L["Pet Spell"],
        item = L["Item"],
    }

    local type = AceGUI:Create("Dropdown")
    type:SetList(types, { "spell", "pet", "item" })
    type:SetRelativeWidth(0.3)
    type:SetValue(rot.type)
    type:SetLabel(rot.type and types[rot.type])
    type:SetLabel(L["Action Type"])
    type:SetCallback("OnValueChanged", function(widget, event, val)
        if rot.type ~= val then
            rot.type = val
            rot.action = nil
            addon:get_cooldown_list(frame, specID, rotid, id, callback)
        end
    end)
    frame:AddChild(type)

    action:SetRelativeWidth(0.7)
    frame:AddChild(action)

    local announces = {
        none = L["None"],
        partyraid = L["Raid or Party"],
        party = L["Party Only"],
        raidwarn = L["Raid Warning"],
        say = L["Say"],
        yell = L["Yell"],
    }

    local announce = AceGUI:Create("Dropdown")
    announce:SetList(announces, { "none", "partyraid", "party", "raidwarn", "say", "yell" })
    announce:SetRelativeWidth(0.4)
    announce:SetValue(rot.announce or "none")
    announce:SetLabel(announces[rot.announce or "none"])
    announce:SetLabel(L["Announce"])
    announce:SetCallback("OnValueChanged", function(widget, event, val)
        rot.announce = val
    end)
    frame:AddChild(announce)

    local conditions = AceGUI:Create("InlineGroup")
    conditions:SetFullWidth(true)
    conditions:SetFullHeight(true)
    conditions:SetLayout("Flow")
    conditions:SetTitle(L["Conditions"])
    frame:AddChild(conditions)

    local function layout_conditions()
        conditions:ReleaseChildren()
        conditions:PauseLayout()

        local condition_desc = AceGUI:Create("Label")
        condition_desc:SetFullWidth(true)
        condition_desc:SetText(addon:printCondition(rot.conditions, specID))
        conditions:AddChild(condition_desc)

        local condition_eval = AceGUI:Create("Label")
        if not addon:validateCondition(rot.conditions, specID) then
            local condition_valid = AceGUI:Create("Heading")
            condition_valid:SetFullWidth(true)
            condition_valid:SetText(color.RED .. L["THIS CONDITION DOES NOT VALIDATE"] .. color.RESET)
            conditions:AddChild(condition_valid)
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

        condition_eval:SetRelativeWidth(0.5)
        conditions:AddChild(condition_eval)

        local edit_button = AceGUI:Create("Button")
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
        conditions:AddChild(edit_button)

        if not rot.disabled then
            local disable_button = AceGUI:Create("Button")
            disable_button:SetText(DISABLE)
            disable_button:SetRelativeWidth(0.25)
            disable_button:SetCallback("OnClick", function(widget, event)
                rot.disabled = true
                addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot.type, rot.action)
                layout_conditions()
                callback()
            end)
            conditions:AddChild(disable_button)
        else
            local enable_button = AceGUI:Create("Button")
            enable_button:SetText(ENABLE)
            enable_button:SetRelativeWidth(0.25)
            enable_button:SetCallback("OnClick", function(widget, event)
                rot.disabled = false
                layout_conditions()
                callback()
            end)
            conditions:AddChild(enable_button)
        end

        conditions:ResumeLayout()
        conditions:DoLayout()
    end
    layout_conditions()

    frame:ResumeLayout()
    frame:DoLayout()
end

