local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")

local isint, isSpellOnSpec, getSpecSpellID = addon.isint, addon.isSpellOnSpec, addon.getSpecSpellID
local pairs, color, tonumber = pairs, color, tonumber

local function spacer(width)
    local rv = AceGUI:Create("Label")
    rv:SetText(nil)
    rv:SetWidth(width)
    return rv
end

local function add_top_buttons(list, idx, callback, delete_cb)
    local rot = list[idx]

    -- Layout first ...
    local button_group = AceGUI:Create("SimpleGroup")
    button_group:SetFullWidth(true)
    button_group:SetLayout("Table")
    button_group:SetUserData("table", { columns = { 24, 1, 24, 24, 24, 24, 24 } })

    local use_name = AceGUI:Create("CheckBox")
    use_name:SetUserData("cell", { alignV = "bottom", alignH = "center" })
    use_name:SetValue(rot.use_name)
    use_name:SetCallback("OnValueChanged", function(_, _, val)
        rot.use_name = val
        if not rot.use_name then
            rot.name = nil
        end
        callback()
    end)
    button_group:AddChild(use_name)

    local name = AceGUI:Create("EditBox")
    name:SetFullWidth(true)
    name:SetLabel(NAME)
    name:SetDisabled(not rot.use_name)
    if rot.use_name then
        name:SetText(rot.name)
    elseif rot.type == "none" then
        name:SetText(L["No Action"])
    elseif rot.action ~= nil then
        if rot.type == BOOKTYPE_SPELL or rot.type == BOOKTYPE_PET or rot.type == "any" then
            name:SetText(SpellData:SpellName(rot.action, not rot.ranked))
        elseif rot.type == "item" then
            if type(rot.action) == "string" then
                local itemset
                if addon.db.char.itemsets[rot.action] ~= nil then
                    itemset = addon.db.char.itemsets[rot.action]
                elseif addon.db.global.itemsets[rot.action] ~= nil then
                    itemset = addon.db.global.itemsets[rot.action]
                end
                if itemset ~= nil then
                    name:SetText(itemset.name)
                end
            elseif #rot.action > 0 then
                if #rot.action > 1 then
                    name:SetText(string.format(L["%s or %d others"], rot.action[1], #rot.action-1))
                else
                    name:SetText(rot.action[1])
                end
            end
        end
    end
    name:SetCallback("OnEnterPressed", function(_, _, val)
        rot.name = val
        callback()
    end)
    button_group:AddChild(name)

    local angle = math.rad(180)
    local cos, sin = math.cos(angle), math.sin(angle)

    local movetop = AceGUI:Create("Icon")
    movetop:SetImageSize(24, 24)
    if (idx == 1) then
        movetop:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Disabled", (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0)
        movetop:SetDisabled(true)
    else
        movetop:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up", (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0)
        movetop:SetDisabled(false)
    end
    movetop:SetCallback("OnClick", function()
        local tmp = table.remove(list, idx)
        table.insert(list, 1, tmp)
        callback()
    end)
    addon.AddTooltip(movetop, L["Move to Top"])
    button_group:AddChild(movetop)

    local moveup = AceGUI:Create("Icon")
    moveup:SetImageSize(24, 24)
    if (idx == 1) then
        moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled", (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0)
        moveup:SetDisabled(true)
    else
        moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up", (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0)
        moveup:SetDisabled(false)
    end
    moveup:SetCallback("OnClick", function()
        local tmp = list[idx-1]
        list[idx-1] = list[idx]
        list[idx] = tmp
        callback()
    end)
    addon.AddTooltip(moveup, L["Move Up"])
    button_group:AddChild(moveup)

    local movedown = AceGUI:Create("Icon")
    movedown:SetImageSize(24, 24)
    if (idx == #list) then
        movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
        movedown:SetDisabled(true)
    else
        movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        movedown:SetDisabled(false)
    end
    movedown:SetCallback("OnClick", function()
        local tmp = list[idx+1]
        list[idx+1] = list[idx]
        list[idx] = tmp
        callback()
    end)
    addon.AddTooltip(movedown, L["Move Down"])
    button_group:AddChild(movedown)

    local movebottom = AceGUI:Create("Icon")
    movebottom:SetImageSize(24, 24)
    if (idx == #list) then
        movebottom:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Disabled")
        movebottom:SetDisabled(true)
    else
        movebottom:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up")
        movebottom:SetDisabled(false)
    end
    movebottom:SetCallback("OnClick", function()
        local tmp = table.remove(list, idx)
        table.insert(list, tmp)
        callback()
    end)
    addon.AddTooltip(movebottom, L["Move to Bottom"])
    button_group:AddChild(movebottom)

    local delete = AceGUI:Create("Icon")
    delete:SetImageSize(24, 24)
    delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    delete:SetCallback("OnClick", function()
        delete_cb()
        callback()
    end)
    addon.AddTooltip(delete, DELETE)
    button_group:AddChild(delete)

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

    local effect_map, effect_order
    local function update_effect_map()
        effect_map = {}
        effect_order = {}
        effect_map[DEFAULT] = DEFAULT
        table.insert(effect_order, DEFAULT)
        effect_map[NONE] = NONE
        table.insert(effect_order, NONE)

        for k, v in pairs(effects) do
            if v.name ~= nil then
                table.insert(effect_order, k)
                effect_map[k] = v.name
            end
        end
    end
    update_effect_map()

    if rot.color == nil then
        rot.color = { r = 0, g = 1.0, b = 0, a = 1.0 }
    end

    local effect_idx = rot.effect or profile["effect"]
    local effect = effect_idx and effects[effect_idx]
    local effect_icon = AceGUI:Create("Icon")
    effect_icon:SetWidth(36)
    effect_icon:SetHeight(36)
    effect_icon:SetDisabled(true)
    effect_icon:SetCallback("OnRelease", function(self)
        addon:HideGlow(self.frame, "effect")
    end)
    addon:Glow(effect_icon.frame, "effect", effect, rot.color, 1.0, "CENTER", 0, 0)
    effect_group:AddChild(effect_icon)

    local effect_sel = AceGUI:Create("Dropdown")
    effect_sel:SetLabel(L["Effect"])
    effect_sel:SetHeight(44)
    effect_sel:SetFullWidth(true)
    effect_sel:SetCallback("OnValueChanged", function(_, _, val)
        if val == DEFAULT then
            rot.effect = nil
        else
            rot.effect = val
        end
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
        refresh()
    end)
    effect_sel.configure = function()
        update_effect_map()
        effect_sel:SetList(effect_map, effect_order)
        effect_sel:SetValue(rot.effect or DEFAULT)
    end

    effect_sel.frame:SetScript("OnShow", function(f)
        update_effect_map()
        f.obj:SetList(effect_map, effect_order)
        f.obj:SetValue(rot.effect or DEFAULT)
    end)
    effect_sel:SetCallback("OnRelease", function(obj)
        obj.frame:SetScript("OnShow", nil)
    end)
    effect_group:AddChild(effect_sel)

    group:AddChild(effect_group)

    local spc1 = AceGUI:Create("Label")
    spc1:SetText(nil)
    spc1:SetRelativeWidth(0.05)
    group:AddChild(spc1)

    local magnification = AceGUI:Create("Slider")
    magnification:SetRelativeWidth(0.45)
    magnification:SetLabel(L["Magnification"])
    magnification:SetValue(rot.magnification or profile["magnification"])
    magnification:SetSliderValues(0.1, 2.0, 0.1)
    magnification:SetDisabled(rot.effect == NONE or effect == nil or effect.type == "pulse" or effect.type == "custom" or addon.index(addon.textured_types, effect.type) == nil)
    magnification:SetCallback("OnValueChanged", function(_, _, val)
        if val == profile["magnification"] then
            rot.magnification = nil
        else
            rot.magnification = val
        end
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
    end)
    group:AddChild(magnification)

    local color_pick = AceGUI:Create("ColorPicker")
    color_pick:SetRelativeWidth(0.35)
    color_pick:SetColor(rot.color.r, rot.color.g, rot.color.b, rot.color.a)
    color_pick:SetLabel(L["Highlight Color"])
    color_pick:SetDisabled(rot.effect == NONE or effect == nil or effect.type == "dazzle" or effect.type == "custom")
    color_pick:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
        rot.color = { r = r, g = g, b = b, a = a }
        addon:HideGlow(effect_icon.frame, "effect")
        addon:Glow(effect_icon.frame, "effect", effect, rot.color, 1.0, "CENTER", 0, 0)
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
    end)
    group:AddChild(color_pick)

    local position_group = AceGUI:Create("SimpleGroup")
    position_group:SetLayout("Table")
    position_group:SetRelativeWidth(0.65)
    position_group:SetUserData("table", { columns = { 1, 10, 40, 10, 50 } })

    local setpoint_values = addon.deepcopy(addon.setpoints)
    setpoint_values[DEFAULT] = DEFAULT

    local update_position_buttons

    local position = AceGUI:Create("Dropdown")
    position:SetFullWidth(true)
    position:SetLabel(L["Position"])
    position:SetCallback("OnValueChanged", function(_, _, val)
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

    position_group:AddChild(spacer(5))

    local x_offs = AceGUI:Create("EditBox")
    local y_offs = AceGUI:Create("EditBox")

    local directional = AceGUI:Create("Directional")
    directional:SetCallback("OnClick", function(_, _, _, direction)
        if direction == "UP" then
            rot.yoffs = (rot.yoffs or 0) + 1
            y_offs:SetText(rot.yoffs)
        elseif direction == "LEFT" then
            rot.xoffs = (rot.xoffs or 0) - 1
            x_offs:SetText(rot.xoffs)
        elseif direction == "CENTER" then
            rot.xoffs = 0
            rot.yoffs = 0
            x_offs:SetText(rot.xoffs)
            y_offs:SetText(rot.yoffs)
        elseif direction == "RIGHT" then
            rot.xoffs = (rot.xoffs or 0) + 1
            x_offs:SetText(rot.xoffs)
        elseif direction == "DOWN" then
            rot.yoffs = (rot.yoffs or 0) - 1
            y_offs:SetText(rot.yoffs)
        end
        addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
    end)
    position_group:AddChild(directional)

    position_group:AddChild(spacer(5))

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
        local disable = rot.effect == NONE or (effect ~= nil and (effect.type == "blizzard" or
                        (addon.index(addon.textured_types, effect.type) and rot.setpoint == nil)) or false)
        position:SetDisabled(rot.effect == NONE or effect == nil or addon.index(addon.textured_types, effect.type) == nil)
        directional:SetDisabled(disable)
        x_offs:SetText(rot.xoffs or profile["xoffs"])
        y_offs:SetText(rot.yoffs or profile["yoffs"])
    end

    update_position_buttons()

    group:AddChild(position_group)

    return group
end

local function add_action_group(specID, rotid, rot, callback, refresh, cooldown)
    local itemsets = addon.db.char.itemsets
    local global_itemsets = addon.db.global.itemsets

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    local action_group = AceGUI:Create("SimpleGroup")
    action_group:SetFullWidth(true)
    action_group:SetLayout("Table")
    action_group:SetUserData("table", { columns = { 0, 44, 1 } })

    local types = {
        spell = L["Spell"],
        pet = L["Pet Spell"],
        any = L["Any Spell"],
        item = L["Item"],
    }
    local types_order = { BOOKTYPE_SPELL, BOOKTYPE_PET, "any", "item" }
    if not cooldown then
        types["none"] = L["None"]
        table.insert(types_order, "none")
    end

    local action_type = AceGUI:Create("Dropdown")
    action_type:SetWidth(95)
    action_type:SetLabel(L["Action Type"])
    action_type:SetCallback("OnValueChanged", function(_, _, val)
        if rot.type ~= val then
            rot.type = val
            rot.action = nil
            refresh()
            callback()
        end
    end)
    action_type.configure = function()
        action_type:SetList(types, types_order)
        action_type:SetValue(rot.type)
    end
    action_group:AddChild(action_type)

    if rot.type ~= nil and rot.type == BOOKTYPE_SPELL then
        local action = AceGUI:Create("Spec_EditBox")
        local action_icon = AceGUI:Create("ActionSlotSpell")
        action_icon:SetWidth(44)
        action_icon:SetHeight(44)
        action_icon:SetText(rot.action)
        action_icon.text:Hide()
        action_icon:SetCallback("OnEnterPressed", function(_, _, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(specID, v) then
                addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
                rot.action = v
                action_icon:SetText(v)
                if rot.action then
                    action:SetText(SpellData:SpellName(rot.action, not rot.ranked))
                    if GameTooltip:IsOwned(action_icon.frame) and GameTooltip:IsVisible() then
                        GameTooltip:SetHyperlink("spell:" .. rot.action)
                    end
                else
                    action:SetText(nil)
                    if GameTooltip:IsOwned(action_icon.frame) and GameTooltip:IsVisible() then
                        GameTooltip:Hide()
                    end
                end

                callback()
            end
        end)
        action_icon:SetCallback("OnEnter", function()
            if rot.action then
                GameTooltip:SetOwner(action_icon.frame, "ANCHOR_BOTTOMRIGHT", 3)
                GameTooltip:SetHyperlink("spell:" .. rot.action)
            end
        end)
        action_icon:SetCallback("OnLeave", function()
            if GameTooltip:IsOwned(action_icon.frame) then
                GameTooltip:Hide()
            end
        end)
        action_group:AddChild(action_icon)

        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            action_group:SetUserData("table", { columns = { 0, 44, 30, 1 } })

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
            nr_button:SetLabel("")
            nr_button:SetValue(rot.ranked or false)
            nr_button:SetCallback("OnValueChanged", function(_, _, val)
                rot.ranked = val
                action:SetUserData("norank", not val)
                action:SetText(rot.action and SpellData:SpellName(rot.action, not rot.ranked))
                callback()
            end)
            ranked:AddChild(nr_button)

            action_group:AddChild(ranked)
        end

        action:SetFullWidth(true)
        action:SetUserData("norank", not rot.ranked)
        action:SetUserData("spec", specID)
        action:SetLabel(L["Spell"])
        action:SetText(rot.action and SpellData:SpellName(rot.action, not rot.ranked))
        action:SetCallback("OnEnterPressed", function(_, _, val)
            addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
            if isint(val) then
                if isSpellOnSpec(specID, tonumber(val)) then
                    rot.action = tonumber(val)
                else
                    rot.action = nil
                    action:SetText(nil)
                end
            else
                rot.action = getSpecSpellID(specID, val)
                if rot.action == nil then
                    action:SetText(nil)
                end
            end
            action_icon:SetText(rot.action)
            callback()
        end)
        action_group:AddChild(action)
    elseif rot.type ~= nil and rot.type == BOOKTYPE_PET then
        local action = AceGUI:Create("Spec_EditBox")
        local action_icon = AceGUI:Create("ActionSlotPetAction")
        action_icon:SetWidth(44)
        action_icon:SetHeight(44)
        action_icon:SetText(rot.action)
        action_icon.text:Hide()
        action_icon:SetCallback("OnEnterPressed", function(_, _, v)
            v = tonumber(v)
            if not v or isSpellOnSpec(BOOKTYPE_PET, v) then
                addon:RemoveCooldownGlowIfCurrent(BOOKTYPE_PET, rotid, rot)
                rot.action = v
                action_icon:SetText(v)
                if rot.action then
                    action:SetText(SpellData:SpellName(rot.action, not rot.ranked))
                    if GameTooltip:IsOwned(action_icon.frame) and GameTooltip:IsVisible() then
                        GameTooltip:SetHyperlink("spell:" .. rot.action)
                    end
                else
                    action:SetText(nil)
                    if GameTooltip:IsOwned(action_icon.frame) and GameTooltip:IsVisible() then
                        GameTooltip:Hide()
                    end
                end

                callback()
            end
        end)
        action_icon:SetCallback("OnEnter", function()
            if rot.action then
                GameTooltip:SetOwner(action_icon.frame, "ANCHOR_BOTTOMRIGHT", 3)
                GameTooltip:SetHyperlink("spell:" .. rot.action)
            end
        end)
        action_icon:SetCallback("OnLeave", function()
            if GameTooltip:IsOwned(action_icon.frame) then
                GameTooltip:Hide()
            end
        end)
        action_group:AddChild(action_icon)

        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            action_group:SetUserData("table", { columns = { 0, 44, 30, 1 } })

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
            nr_button:SetLabel("")
            nr_button:SetValue(rot.ranked or false)
            nr_button:SetCallback("OnValueChanged", function(_, _, val)
                rot.ranked = val
                action:SetUserData("norank", not val)
                action:SetText(rot.action and SpellData:SpellName(rot.action, not rot.ranked))
                callback()
            end)
            ranked:AddChild(nr_button)

            action_group:AddChild(ranked)
        end

        action:SetFullWidth(true)
        action:SetUserData("norank", not rot.ranked)
        action:SetUserData("spec", BOOKTYPE_PET)
        action:SetLabel(L["Spell"])
        action:SetText(rot.action and SpellData:SpellName(rot.action, not rot.ranked))
        action:SetCallback("OnEnterPressed", function(_, _, val)
            addon:RemoveCooldownGlowIfCurrent(BOOKTYPE_PET, rotid, rot)
            if isint(val) then
                if isSpellOnSpec(BOOKTYPE_PET, tonumber(val)) then
                    rot.action = tonumber(val)
                else
                    rot.action = nil
                    action:SetText(nil)
                end
            else
                rot.action = getSpecSpellID(BOOKTYPE_PET, val)
                if rot.action == nil then
                    action:SetText(nil)
                end
            end
            action_icon:SetText(rot.action)
            callback()
        end)
        action_group:AddChild(action)
    elseif rot.type ~= nil and rot.type == "any" then
        local action = AceGUI:Create("Spell_EditBox")
        local action_icon = AceGUI:Create("ActionSlotSpell")
        action_icon:SetWidth(44)
        action_icon:SetHeight(44)
        action_icon:SetText(rot.action)
        action_icon.text:Hide()
        action_icon:SetCallback("OnEnterPressed", function(_, _, v)
            addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
            rot.action = v
            action_icon:SetText(v)
            if rot.action then
                action:SetText(SpellData:SpellName(rot.action, not rot.ranked))
                if GameTooltip:IsOwned(action_icon.frame) and GameTooltip:IsVisible() then
                    GameTooltip:SetHyperlink("spell:" .. rot.action)
                end
            else
                action:SetText(nil)
                if GameTooltip:IsOwned(action_icon.frame) and GameTooltip:IsVisible() then
                    GameTooltip:Hide()
                end
            end

            callback()
        end)
        action_icon:SetCallback("OnEnter", function()
            if rot.action then
                GameTooltip:SetOwner(action_icon.frame, "ANCHOR_BOTTOMRIGHT", 3)
                GameTooltip:SetHyperlink("spell:" .. rot.action)
            end
        end)
        action_icon:SetCallback("OnLeave", function()
            if GameTooltip:IsOwned(action_icon.frame) then
                GameTooltip:Hide()
            end
        end)
        action_group:AddChild(action_icon)

        if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
            action_group:SetUserData("table", { columns = { 0, 44, 30, 1 } })

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
            nr_button:SetCallback("OnValueChanged", function(_, _, val)
                rot.ranked = val
                action:SetUserData("norank", not val)
                action:SetText(rot.action and SpellData:SpellName(rot.action, not rot.ranked))
                callback()
            end)
            ranked:AddChild(nr_button)

            action_group:AddChild(ranked)
        end

        action:SetFullWidth(true)
        action:SetUserData("norank", not rot.ranked)
        action:SetLabel(L["Spell"])
        action:SetText(rot.action and SpellData:SpellName(rot.action, not rot.ranked))
        action:SetCallback("OnEnterPressed", function(_, _, val)
            addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
            local spellid = SpellData:GetSpellId(val)
            rot.action = spellid
            action:SetText(SpellData:SpellName(rot.action, not rot.ranked))
            action_icon:SetText(rot.action)
            callback()
        end)
        action_group:AddChild(action)
    elseif rot.type ~= nil and rot.type == "item" then
        action_group:SetUserData("table", { columns = { 0, 44, 1, 0.25 } })

        if rot.action == nil then
            rot.action = {}
        end

        local action_icon = AceGUI:Create("Icon")
        local update_action_image = function()
            if type(rot.action) == "string" then
                local itemid = addon:FindFirstItemOfItemSet({}, rot.action, true) or addon:FindFirstItemInItemSet(rot.action)
                addon:UpdateItem_ID_Image(itemid, nil, action_icon)
            else
                local itemid = addon:FindFirstItemOfItems({}, rot.action, true) or addon:FindFirstItemInItems(rot.action)
                addon:UpdateItem_ID_Image(itemid, nil, action_icon)
            end
        end
        update_action_image()
        action_icon:SetImageSize(36, 36)
        action_icon:SetCallback("OnEnter", function()
            local itemid
            if type(rot.action) == "string" then
                itemid = addon:FindFirstItemOfItemSet({}, rot.action, true) or addon:FindFirstItemInItemSet(rot.action)
            else
                itemid = addon:FindFirstItemOfItems({}, rot.action, true) or addon:FindFirstItemInItems(rot.action)
            end
            if itemid then
                GameTooltip:SetOwner(action_icon.frame, "ANCHOR_BOTTOMRIGHT", 3)
                GameTooltip:SetHyperlink("item:" .. itemid)
            end
        end)
        action_icon:SetCallback("OnLeave", function()
            if GameTooltip:IsOwned(action_icon.frame) then
                GameTooltip:Hide()
            end
        end)
        action_group:AddChild(action_icon)

        local edit_button = AceGUI:Create("Button")

        local action = AceGUI:Create("Dropdown")
        action:SetFullWidth(true)
        action:SetLabel(L["Item Set"])
        action:SetCallback("OnValueChanged", function(_, _, val)
            if val ~= nil then
                if val == "" then
                    rot.action = {}
                else
                    rot.action = val
                end
            else
                rot.action = {}
            end
            update_action_image()
            callback()
        end)
        action.configure = function()
            local selects, sorted = addon:get_item_list(L["Custom"])
            action:SetList(selects, sorted)
            if type(rot.action) == "string" then
                action:SetValue(rot.action)
            else
                action:SetValue("")
            end
        end
        action_group:AddChild(action)

        edit_button:SetText(EDIT)
        edit_button:SetFullWidth(true)
        edit_button:SetDisabled(rot.action == nil)
        edit_button:SetUserData("cell", { alignV = "bottom" })
        edit_button:SetCallback("OnClick", function()
            local edit_callback = function()
                addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
                update_action_image()
                if type(rot.action) == "string" then
                    addon:UpdateBoundButton(rot.action)
                end
                callback()
            end
            if type(rot.action) == "string" then
                local itemset
                if itemsets[rot.action] ~= nil then
                    itemset = itemsets[rot.action]
                elseif global_itemsets[rot.action] ~= nil then
                    itemset = global_itemsets[rot.action]
                end

                if itemset then
                    addon:item_list_popup(itemset.name, "Inventory_EditBox", itemset.items, function() return true end, edit_callback)
                end
            else
                addon:item_list_popup(L["Custom"], "Inventory_EditBox", rot.action, function() return true end, edit_callback)
            end
        end)
        action_group:AddChild(edit_button)
    --[[
    else
        local action_icon = AceGUI:Create("Icon")
        action_icon:SetImageSize(36, 36)
        action_icon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
        action_group:AddChild(action_icon)

        local action = AceGUI:Create("EditBox")
        action:SetFullWidth(true)
        action:SetDisabled(true)
        action_group:AddChild(action)
    ]]--
    end

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
        condition_desc.frame:SetHyperlinksEnabled(true)

        condition_desc.frame:SetScript("OnHyperlinkClick", function(self, link, text, button)
            -- Avoid an error for ctrl-clicking a non-equippable item
            if IsControlKeyDown() then
                local s = addon.split(link, ":")
                if s[1] ~= "item" or s[2] == nil or not IsEquippableItem(s[2]) then
                    return
                end
            end
            SetItemRef(link, text, button)
        end)
        condition_desc.frame:SetScript("OnHyperlinkEnter", function(self, link, text, button)
            GameTooltip:SetOwner(condition_desc.frame, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(link)
        end)
        condition_desc.frame:SetScript("OnHyperlinkLeave", function(self, link, text, button)
            if GameTooltip:IsOwned(condition_desc.frame) then
                GameTooltip:Hide()
            end
        end)
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

            bottom_group:AddChild(spacer(5))
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
                conditions.frame:SetScript("OnHide", function(frame)
                    addon.currentConditionEval = nil
                    frame:SetScript("OnHide", nil)
                end)
                bottom_group:AddChild(condition_eval)
            else
                addon.currentConditionEval = nil

                bottom_group:AddChild(spacer(5))
            end
        end

        local edit_button = AceGUI:Create("Button")
        edit_button:SetFullWidth(true)
        edit_button:SetText(EDIT)
        edit_button:SetCallback("OnClick", function()
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
            enabledisable_button:SetCallback("OnClick", function()
                rot.disabled = true
                addon:RemoveCooldownGlowIfCurrent(specID, rotid, rot)
                layout_conditions()
                callback()
            end)
        else
            enabledisable_button:SetText(ENABLE)
            enabledisable_button:SetCallback("OnClick", function()
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
    local rotation_settings = self.db.char.rotations[specID][rotid]

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
    end, true)
    frame:AddChild(action_frame)

    local announces = {
        none = L["None"],
        partyraid = L["Raid or Party"],
        party = L["Party Only"],
        raidwarn = L["Raid Warning"],
        -- say = L["Say"],
        -- yell = L["Yell"],
        emote = L["Emote"],
        ["local"] = L["Local Only"],
    }

    local announce = AceGUI:Create("Dropdown")
    announce:SetRelativeWidth(0.4)
    announce:SetLabel(L["Announce"])
    announce:SetCallback("OnValueChanged", function(_, _, val)
        rot.announce = val
    end)
    announce.configure = function()
        announce:SetList(announces, { "none", "partyraid", "party", "raidwarn", --[["say", "yell",]] "emote", "local" })
        announce:SetValue(rot.announce or "none")
    end
    frame:AddChild(announce)

    local announce_sound = AceGUI:Create("LSM30_Sound")
    announce_sound:SetRelativeWidth(0.6)
    -- announce_sound:SetLabel(L["Audible Announce"])
    announce_sound:SetCallback("OnValueChanged", function(_, _, val)
        if val == NONE then
            rot.announce_sound = nil
        else
            rot.announce_sound = val
        end
        announce_sound:SetValue(val)
    end)
    announce_sound.configure = function()
        announce_sound:SetList()
        announce_sound:AddItem(NONE, "")
        announce_sound:SetValue(rot.announce_sound or NONE)
    end
    frame:AddChild(announce_sound)

    local conditions_frame = add_conditions(specID, idx, rotid, rot, callback)
    frame:AddChild(conditions_frame)

    local help = AceGUI:Create("Help")
    help:SetLayout(addon.layout_cooldown_help)
    help:SetTitle(L["Cooldowns"])
    frame:AddChild(help)
    help:SetPoint("TOPLEFT", -12, 4)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

function addon:get_rotation_list(frame, specID, rotid, id, callback)
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
    end, false)
    frame:AddChild(action_frame)

    local conditions_frame = add_conditions(specID, idx, rotid, rot, callback)
    frame:AddChild(conditions_frame)

    local help = AceGUI:Create("Help")
    help:SetLayout(addon.layout_rotation_help)
    help:SetTitle(L["Rotations"])
    frame:AddChild(help)
    help:SetPoint("TOPLEFT", -12, 4)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()

end

