local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")

local isint, isSpellOnSpec = addon.isint, addon.isSpellOnSpec
local pairs, color, tonumber = pairs, color, tonumber
local HideOnEscape = addon.HideOnEscape

local function spacer(width)
    local rv = AceGUI:Create("Label")
    rv:SetText(nil)
    rv:SetRelativeWidth(width)
    return rv
end

local function create_item_list(frame, items, update)
    frame:ReleaseChildren()
    frame:PauseLayout()

    for idx,item in pairs(items) do
        local row = frame

        local icon = AceGUI:Create("ActionSlotItem")
        local name = AceGUI:Create("Inventory_EditBox")

        icon:SetWidth(44)
        icon:SetHeight(44)
        if (item) then
            icon:SetText(GetItemInfoInstant(item))
        end
        icon.text:Hide()
        icon:SetCallback("OnEnterPressed", function(widget, event, v)
            if v then
                local info = GetItemInfo(v)
                if info then
                    items[idx] = info
                    icon:SetText(v)
                    name:SetText(info)
                    update()
                end
            else
                table.remove(items, idx)
                update()
                create_item_list(frame, items, update)
            end
        end)
        row:AddChild(icon)

        name:SetFullWidth(true)
        name:SetLabel(L["Item"])
        name:SetText(item)
        name:SetCallback("OnEnterPressed", function(widget, event, val)
            if val == "" then
                table.remove(items, idx)
                update()
                create_item_list(frame, items, update)
            else
                local itemID = GetItemInfoInstant(val)
                if itemID ~= nil then
                    icon:SetText(itemID)
                else
                    icon:SetText(nil)
                end
                items[idx] = val
                update()
            end
        end)
        row:AddChild(name)

        local moveup = AceGUI:Create("Button")
        moveup:SetWidth(40)
        moveup:SetText("^")
        moveup:SetDisabled(idx == 1)
        moveup:SetCallback("OnClick", function(widget, ewvent, ...)
            local tmp = items[idx-1]
            items[idx-1] = items[idx]
            items[idx] = tmp
            update()
            create_item_list(frame, items, update)
        end)
        row:AddChild(moveup)

        local movedown = AceGUI:Create("Button")
        movedown:SetWidth(40)
        movedown:SetText("v")
        movedown:SetDisabled(idx == #items or items[idx+1] == "")
        movedown:SetCallback("OnClick", function(widget, ewvent, ...)
            local tmp = items[idx+1]
            items[idx+1] = items[idx]
            items[idx] = tmp
            update()
            create_item_list(frame, items, update)
        end)
        row:AddChild(movedown)

        local delete = AceGUI:Create("Button")
        delete:SetWidth(40)
            delete:SetText("X")
            delete:SetCallback("OnClick", function(widget, ewvent, ...)
            table.remove(items, idx)
            update()
            create_item_list(frame, items, update)
        end)
        row:AddChild(delete)
    end

    if #items == 0 or (items[#items] ~= nil and items[#items] ~= "") then
        local row = frame

        local icon = AceGUI:Create("ActionSlotItem")
        icon:SetWidth(44)
        icon:SetHeight(44)
        icon.text:Hide()
        icon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = GetItemInfo(v)
            if v then
                items[#items + 1] = v
                update()
                create_item_list(frame, items, update)
            end
        end)
        row:AddChild(icon)

        local name = AceGUI:Create("Inventory_EditBox")
        name:SetFullWidth(true)
        name:SetLabel(L["Item"])
        name:SetText(nil)
        name:SetCallback("OnEnterPressed", function(widget, event, val)
            if val ~= nil then
                items[#items + 1] = val
                update()
                create_item_list(frame, items, update)
            end
        end)
        row:AddChild(name)

        local moveup = AceGUI:Create("Button")
        moveup:SetWidth(40)
        moveup:SetText("^")
        moveup:SetDisabled(true)
        row:AddChild(moveup)

        local movedown = AceGUI:Create("Button")
        movedown:SetWidth(40)
        movedown:SetText("v")
        movedown:SetDisabled(true)
        row:AddChild(movedown)

        local delete = AceGUI:Create("Button")
        delete:SetWidth(40)
        delete:SetText("X")
        delete:SetDisabled(true)
        row:AddChild(delete)
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function item_list(items, update)
    local frame = AceGUI:Create("Frame")
    frame:PauseLayout()

    frame:SetTitle(L["Item List"])
    frame:SetUserData("index", index)
    frame:SetUserData("spec", spec)
    frame:SetUserData("root", value)
    frame:SetUserData("funcs", funcs)
    frame:SetLayout("Fill")
    HideOnEscape(frame)

    local group = AceGUI:Create("ScrollFrame")
    frame:AddChild(group)
    group:SetFullWidth(true)
    group:SetFullHeight(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { 44, 1, 40, 40, 40 } })

    create_item_list(group, items, update)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function add_top_buttons(list, idx, callback, delete_cb)
    -- Layout first ...
    local button_group = AceGUI:Create("SimpleGroup")
    button_group:SetFullWidth(true)
    button_group:SetLayout("Table")
    button_group:SetUserData("table", { columns = { 1, 1, 1 } })

    local moveup = AceGUI:Create("Button")
    button_group:AddChild(moveup)
    moveup:SetText(L["Move Up"])
    moveup:SetDisabled(idx == 1)
    moveup:SetCallback("OnClick", function(widget, event)
        local rot = list[idx]
        list[idx] = list[idx - 1]
        idx = idx - 1
        list[idx] = rot
        callback()
    end)

    local movedown = AceGUI:Create("Button")
    button_group:AddChild(movedown)
    movedown:SetText(L["Move Down"])
    movedown:SetDisabled(idx == #list)
    movedown:SetCallback("OnClick", function(widget, event)
        local rot = list[idx]
        list[idx] = list[idx + 1]
        idx = idx + 1
        list[idx] = rot
        callback()
    end)

    local delete = AceGUI:Create("Button")
    button_group:AddChild(delete)
    delete:SetText(DELETE)
    delete:SetCallback("OnClick", function(widget, event)
        delete_cb()
        callback()
    end)

    return button_group
end

local function add_effect_group(specID, rotid, rot, refresh)
    local profile = addon.db.profile
    local effects = addon.db.global.effects

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    local effect_group = AceGUI:Create("SimpleGroup")
    effect_group:SetRelativeWidth(0.5)
    effect_group:SetLayout("Table")
    effect_group:SetUserData("table", { columns = { 44, 1 } })

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
        group.frame:SetScript("OnHide", function()
            addon:StopCustomGlow(effect_icon.frame)
        end)
    end
    effect_group:AddChild(effect_icon)

    local effect = AceGUI:Create("Dropdown")
    effect:SetLabel(L["Effect"])
    effect:SetHeight(44)
    effect:SetCallback("OnValueChanged", function(widget, event, val)
        if val == DEFAULT then
            rot.effect = nil
        else
            rot.effect = val
        end
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
        refresh()
    end)
    effect.frame:SetScript("OnShow", function(frame)
        update_effect_map()
        effect:SetList(effect_map, effect_order)
    end)
    effect.configure = function()
        effect:SetList(effect_map, effect_order)
        effect:SetValue(rot.effect or DEFAULT)
    end
    effect_group:AddChild(effect)

    group:AddChild(effect_group)

    group:AddChild(spacer(0.05))

    local magnification = AceGUI:Create("Slider")
    magnification:SetRelativeWidth(0.45)
    magnification:SetLabel(L["Magnification"])
    magnification:SetValue(rot.magnification or profile["magnification"])
    magnification:SetSliderValues(0.1, 2.0, 0.1)
    magnification:SetDisabled(effects[name2idx[rot.effect or profile["effect"]]].type ~= "texture")
    magnification:SetCallback("OnValueChanged", function(widget, event, val)
        if val == profile["magnification"] then
            rot.magnification = nil
        else
            rot.magnification = val
        end
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
    end)
    group:AddChild(magnification)

    if rot.color == nil then
        rot.color = { r = 0, g = 1.0, b = 0, a = 1.0 }
    end
    local color_pick = AceGUI:Create("ColorPicker")
    color_pick:SetRelativeWidth(0.35)
    color_pick:SetColor(rot.color.r, rot.color.g, rot.color.b, rot.color.a)
    color_pick:SetLabel(L["Highlight Color"])
    color_pick:SetCallback("OnValueConfirmed", function(widget, event, r, g, b, a)
        rot.color = { r = r, g = g, b = b, a = a }
        if effects[name2idx[rot.effect or profile["effect"]]].type ~= "texture" then
            addon:ApplyCustomGlow(effects[name2idx[rot.effect or profile["effect"]]], effect_icon.frame, nil, rot.color)
        end
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
    end)
    group:AddChild(color_pick)

    local position_group = AceGUI:Create("SimpleGroup")
    position_group:SetLayout("Table")
    position_group:SetRelativeWidth(0.65)
    position_group:SetUserData("table", { columns = { 1, 20, 35, 50 } })

    local setpoint_values = addon.deepcopy(addon.setpoints)
    setpoint_values[DEFAULT] = DEFAULT

    local update_position_buttons

    local position = AceGUI:Create("Dropdown")
    position:SetLabel(L["Position"])
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
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
    end)
    position.configure = function()
        position:SetList(setpoint_values, { DEFAULT, "CENTER", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOP", "BOTTOM", "LEFT", "RIGHT" })
        position:SetValue(rot.setpoint or DEFAULT)
    end
    position_group:AddChild(position)

    position_group:AddChild(spacer(0.1))

    local directional_group = AceGUI:Create("SimpleGroup")
    directional_group:SetLayout("Table")
    directional_group:SetUserData("table", { columns = { 10, 10, 10 } })

    directional_group:AddChild(spacer(1))

    local x_offs = AceGUI:Create("EditBox")
    local y_offs = AceGUI:Create("EditBox")

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

    position_group:AddChild(directional_group)

    local offset_group = AceGUI:Create("SimpleGroup")
    offset_group:SetLayout("Table")
    offset_group:SetUserData("table", { columns = { 10, 40 } })

    local x_label = AceGUI:Create("Label")
    x_label:SetText("X")
    x_label:SetColor(1.0, 0.82, 0)
    offset_group:AddChild(x_label)

    x_offs:SetDisabled(true)
    offset_group:AddChild(x_offs)

    local y_label = AceGUI:Create("Label")
    y_label:SetText("Y")
    y_label:SetColor(1.0, 0.82, 0)
    offset_group:AddChild(y_label)

    y_offs:SetDisabled(true)
    offset_group:AddChild(y_offs)

    position_group:AddChild(offset_group)

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

    group:AddChild(position_group)

    return group
end

local function add_action_group(specID, rotid, rot, callback, refresh)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    local icon_group = AceGUI:Create("SimpleGroup")
    icon_group:SetFullWidth(true)
    icon_group:SetLayout("Table")
    icon_group:SetUserData("table", { columns = { 44, 24, 1 } })

    local action_group = AceGUI:Create("SimpleGroup")
    action_group:SetFullWidth(true)
    action_group:SetLayout("Table")
    action_group:SetUserData("table", { columns = { 0, 1 } })

    local types = {
        spell = L["Spell"],
        pet = L["Pet Spell"],
        item = L["Item"],
    }

    local type = AceGUI:Create("Dropdown")
    type:SetWidth(95)
    type:SetLabel(L["Action Type"])
    type:SetCallback("OnValueChanged", function(widget, event, val)
        if rot.type ~= val then
            rot.type = val
            rot.action = nil
            refresh()
        end
    end)
    type.configure = function()
        type:SetList(types, { "spell", "pet", "item" })
        type:SetValue(rot.type)
    end
    action_group:AddChild(type)

    if rot.type ~= nil and rot.type == "spell" then
        local action = AceGUI:Create("Spec_EditBox")
        local action_icon = AceGUI:Create("ActionSlotSpell")
        action_icon:SetWidth(44)
        action_icon:SetHeight(44)
        action_icon:SetText(rot.action)
        action_icon.text:Hide()
        action_icon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(specID, v) then
                addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
                rot.action = v
                action_icon:SetText(v)
                if v then
                    action:SetText(rot.action and (rot.ranked and SpellData:SpellName(rot.action) or GetSpellInfo(rot.action)))
                else
                    action:SetText(nil)
                end

                callback()
            end
        end)
        icon_group:AddChild(action_icon)

        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            action_group:SetUserData("table", { columns = { 0, 0.025, 30, 1 } })
            action_group:AddChild(spacer(1))

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
            nr_button:SetValue(rot.ranked or false)
            nr_button:SetCallback("OnValueChanged", function(widget, event, val)
                rot.ranked = val
                action:SetUserData("norank", not val)
                action:SetText(rot.action and (rot.ranked and SpellData:SpellName(rot.action)) or GetSpellInfo(rot.action))
                callback()
            end)
            ranked:AddChild(nr_button)

            action_group:AddChild(ranked)
        end

        action:SetFullWidth(true)
        action:SetUserData("norank", not rot.ranked)
        action:SetUserData("spec", specID)
        action:SetLabel(L["Spell"])
        action:SetText(rot.action and (rot.ranked and SpellData:SpellName(rot.action)) or GetSpellInfo(rot.action))
        action:SetCallback("OnEnterPressed", function(widget, event, val)
            addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
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
        action_group:AddChild(action)
    elseif rot.type ~= nil and rot.type == "pet" then
        local action = AceGUI:Create("Spell_EditBox")
        local action_icon = AceGUI:Create("ActionSlotSpell")
        action_icon:SetWidth(44)
        action_icon:SetHeight(44)
        action_icon:SetText(rot.action)
        action_icon.text:Hide()
        action_icon:SetCallback("OnEnterPressed", function(widget, event, v)
            addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
            v = tonumber(v)
            rot.action = v
            action_icon:SetText(v)
            if v then
                action:SetText(rot.action and (rot.ranked and SpellData:SpellName(rot.action) or GetSpellInfo(rot.action)))
            else
                action:SetText(nil)
            end

            callback()
        end)
        icon_group:AddChild(action_icon)

        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            action_group:SetUserData("table", { columns = { 0, 0.025, 30, 1 } })
            action_group:AddChild(spacer(1))

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
            nr_button:SetValue(rot.ranked or false)
            nr_button:SetCallback("OnValueChanged", function(widget, event, val)
                rot.ranked = val
                action:SetUserData("norank", not val)
                action:SetText(rot.action and (rot.ranked and SpellData:SpellName(rot.action) or GetSpellInfo(rot.action)))
                callback()
            end)
            ranked:AddChild(nr_button)

            action_group:AddChild(ranked)
        end

        action:SetFullWidth(true)
        action:SetUserData("norank", not rot.ranked)
        action:SetLabel(L["Spell"])
        action:SetText(rot.action and (rot.ranked and SpellData:SpellName(rot.action) or GetSpellInfo(rot.action)))
        action:SetCallback("OnEnterPressed", function(widget, event, val)
            addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
            local spellid = select(7, GetSpellInfo(val))
            rot.action = spellid
            action:SetText(SpellData:SpellName(rot.action))
            action_icon:SetText(rot.action)
            callback()
        end)
        action_group:AddChild(action)
    elseif rot.type ~= nil and rot.type == "item" then
        action_group:SetUserData("table", { columns = { 0, 1, 0.25 } })

        local action_icon = AceGUI:Create("Icon")
        if rot.action ~= nil and #rot.action > 0 then
            action_icon:SetImage(select(5, GetItemInfoInstant(rot.action[1])))
        end
        action_icon:SetImageSize(36, 36)
        icon_group:AddChild(action_icon)

        local action = AceGUI:Create("EditBox")
        action:SetFullWidth(true)
        action:SetLabel(L["Item"])
        action:SetDisabled(true)
        if rot.action ~= nil and #rot.action > 0 then
            if #rot.action > 1 then
                action:SetText(string.format(L["%s or %d others"], rot.action[1], #rot.action-1))
            else
                action:SetText(rot.action[1])
            end
        end
        action_group:AddChild(action)

        local edit_button = AceGUI:Create("Button")
        edit_button:SetText(EDIT)
        edit_button:SetUserData("cell", { alignV = "bottom" })
        edit_button:SetCallback("OnClick", function(widget, ewvent, ...)
            if rot.action == nil then
                rot.action = {}
            end
            item_list(rot.action, function()
                addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
                if rot.action ~= nil and #rot.action > 0 then
                    action_icon:SetImage(select(5, GetItemInfoInstant(rot.action[1])))
                    if #rot.action > 1 then
                        action:SetText(string.format(L["%s or %d others"], rot.action[1], #rot.action-1))
                    else
                        action:SetText(rot.action[1])
                    end
                else
                    action_icon:SetImage(nil)
                    action:SetText(nil)
                end
                callback()
            end)
        end)
        action_group:AddChild(edit_button)
    else
        local action_icon = AceGUI:Create("Icon")
        action_icon:SetImageSize(36, 36)
        action_icon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
        icon_group:AddChild(action_icon)

        local action = AceGUI:Create("EditBox")
        action:SetFullWidth(true)
        action:SetDisabled(true)
        action_group:AddChild(action)
    end

    local use_name = AceGUI:Create("CheckBox")
    use_name:SetUserData("cell", { alignV = "bottom", alignH = "center" })
    use_name:SetValue(rot.use_name)
    use_name:SetCallback("OnValueChanged", function(widget, event, val)
        rot.use_name = val
        if not rot.use_name then
            rot.name = nil
        end
        callback()
    end)
    icon_group:AddChild(use_name)

    local name = AceGUI:Create("EditBox")
    name:SetFullWidth(true)
    name:SetLabel(NAME)
    name:SetDisabled(not rot.use_name)
    if rot.use_name then
        name:SetText(rot.name)
    elseif rot.action ~= nil then
        if rot.type == "spell" or rot.type =="pet" then
            name:SetText(GetSpellInfo(rot.action))
        elseif #rot.action > 0 then
            if #rot.action > 1 then
                name:SetText(string.format(L["%s or %d others"], rot.action[1], #rot.action-1))
            else
                name:SetText(rot.action[1])
            end
        end
    end
    name:SetCallback("OnEnterPressed", function(widget, event, val)
        rot.name = val
        callback()
    end)
    icon_group:AddChild(name)

    group:AddChild(icon_group)
    group:AddChild(action_group)

    return group
end

local function add_conditions(specID, idx, rotid, rot, callback)
    local conditions = AceGUI:Create("InlineGroup")

    conditions:SetFullWidth(true)
    conditions:SetFullHeight(true)
    conditions:SetLayout("Flow")
    conditions:SetTitle(L["Conditions"])

    local function layout_conditions()
        conditions:ReleaseChildren()
        conditions:PauseLayout()

        local condition_desc = AceGUI:Create("Label")
        condition_desc:SetFullWidth(true)
        condition_desc:SetText(addon:printCondition(rot.conditions, specID))
        conditions:AddChild(condition_desc)

        local bottom_group = AceGUI:Create("SimpleGroup")
        bottom_group:SetFullWidth(true)
        bottom_group:SetLayout("Table")
        bottom_group:SetUserData("table", { columns = { 0.5, 0.25, 0.25 } })

        if rot.disabled then
            addon.currentConditionEval = nil
            local disabled = AceGUI:Create("Label")
            disabled:SetFullWidth(true)
            disabled:SetColor(255, 0, 0)
            disabled:SetText(L["Disabled"])
            bottom_group:AddChild(disabled)

        elseif not addon:validateCondition(rot.conditions, specID) then
            addon.currentConditionEval = nil
            local condition_valid = AceGUI:Create("Heading")
            condition_valid:SetFullWidth(true)
            condition_valid:SetText(color.RED .. L["THIS CONDITION DOES NOT VALIDATE"] .. color.RESET)
            conditions:AddChild(condition_valid)

            bottom_group:AddChild(spacer(1))
        else
            if specID == addon.currentSpec then
                local condition_eval = AceGUI:Create("Label")
                local function update_eval()
                    if addon:evaluateCondition(rot.conditions) then
                        condition_eval:SetText(color.GREEN .. L["Currently satisfied"] .. color.RESET)
                    else
                        condition_eval:SetText(color.RED .. L["Not currently satisfied"] .. color.RESET)
                    end
                end
                update_eval()
                addon.currentConditionEval = update_eval
                conditions.frame:SetScript("OnHide", function()
                    addon.currentConditionEval = nil
                end)
                bottom_group:AddChild(condition_eval)
            else
                addon.currentConditionEval = nil

                bottom_group:AddChild(spacer(1))
            end
        end

        local edit_button = AceGUI:Create("Button")
        edit_button:SetFullWidth(true)
        edit_button:SetText(EDIT)
        edit_button:SetCallback("OnClick", function(widget, event)
            if rot.conditions == nil then
                rot.conditions = { type = nil }
            end
            addon:EditCondition(idx, specID, rot.conditions, function()
                layout_conditions()
                callback()
            end)
        end)
        bottom_group:AddChild(edit_button)

        local enabledisable_button = AceGUI:Create("Button")
        enabledisable_button:SetFullWidth(true)
        if not rot.disabled then
            enabledisable_button:SetText(DISABLE)
            enabledisable_button:SetCallback("OnClick", function(widget, event)
                rot.disabled = true
                addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
                layout_conditions()
                callback()
            end)
        else
            enabledisable_button:SetText(ENABLE)
            enabledisable_button:SetCallback("OnClick", function(widget, event)
                rot.disabled = false
                layout_conditions()
                callback()
            end)
        end
        bottom_group:AddChild(enabledisable_button)

        conditions:AddChild(bottom_group)

        addon:configure_frame(conditions)
        conditions:ResumeLayout()
        conditions:DoLayout()
    end
    layout_conditions()

    return conditions
end

function addon:get_cooldown_list(frame, specID, rotid, id, callback)
    local profile = self.db.profile
    local rotation_settings = self.db.char.rotations[specID][rotid]
    local effects = self.db.global.effects

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
        addon:configure_frame(frame)
        frame:ResumeLayout()
        frame:DoLayout()
        return
    end

    local rotation_frame = add_top_buttons(rotation_settings.cooldowns, idx, callback,
        function()
            addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
            addon.currentConditionEval = nil
            table.remove(rotation_settings.cooldowns, idx)
            frame:ReleaseChildren()
            frame:DoLayout()
        end)
    frame:AddChild(rotation_frame)

    local effect_frame = add_effect_group(specID, rotid, rot, function()
        addon:get_cooldown_list(frame, specID, rotid, id, callback)
    end)
    frame:AddChild(effect_frame)

    local action_frame = add_action_group(specID, rotid, rot, callback, function()
        addon:get_cooldown_list(frame, specID, rotid, id, callback)
    end)
    frame:AddChild(action_frame)

    local announces = {
        none = L["None"],
        partyraid = L["Raid or Party"],
        party = L["Party Only"],
        raidwarn = L["Raid Warning"],
        say = L["Say"],
        yell = L["Yell"],
    }

    local announce = AceGUI:Create("Dropdown")
    announce:SetRelativeWidth(0.4)
    announce:SetLabel(L["Announce"])
    announce:SetCallback("OnValueChanged", function(widget, event, val)
        rot.announce = val
    end)
    announce.configure = function()
        announce:SetList(announces, { "none", "partyraid", "party", "raidwarn", "say", "yell" })
        announce:SetValue(rot.announce or "none")
    end
    frame:AddChild(announce)

    local conditions_frame = add_conditions(specID, idx, rotid, rot, callback)
    frame:AddChild(conditions_frame)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

function addon:get_rotation_list(frame, specID, rotid, id, callback)
    local profile = self.db.profile
    local rotation_settings = self.db.char.rotations[specID][rotid]

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
        addon:configure_frame(frame)
        frame:ResumeLayout()
        frame:DoLayout()
        return
    end

    local rotation_frame = add_top_buttons(rotation_settings.rotation, idx, callback,
        function()
            table.remove(rotation_settings.rotation, idx)
            frame:ReleaseChildren()
            frame:DoLayout()
        end)
    frame:AddChild(rotation_frame)

    local action_frame = add_action_group(specID, rotid, rot, callback, function()
        addon:get_rotation_list(frame, specID, rotid, id, callback)
    end)
    frame:AddChild(action_frame)

    local conditions_frame = add_conditions(specID, idx, rotid, rot, callback)
    frame:AddChild(conditions_frame)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

