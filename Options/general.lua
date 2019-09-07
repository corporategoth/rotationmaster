local addon_name, addon = ...

local module = addon:NewModule("Options", "AceConsole-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local LibAboutPanel = LibStub("LibAboutPanel")
local DBIcon = LibStub("LibDBIcon-1.0")
local libc = LibStub:GetLibrary("LibCompress")

local assert, error, hooksecurefunc, pairs, base64enc, base64dec, date, color, width_split = assert, error, hooksecurefunc, pairs, base64enc, base64dec, date, color, width_split

local HideOnEscape = addon.HideOnEscape

local function create_primary_options(frame)
    local profile = addon.db.profile
    local effects = addon.db.global.effects

    local function spacer(width)
        local rv = AceGUI:Create("Label")
        rv:SetRelativeWidth(width)
        return rv
    end

    frame:ReleaseChildren()
    frame:PauseLayout()

    local scroll = AceGUI:Create("ScrollFrame")
    frame:AddChild(scroll)
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")

    local general_group = AceGUI:Create("SimpleGroup")
    scroll:AddChild(general_group)
    general_group:SetFullWidth(true)
    general_group:SetLayout("Table")
    general_group:SetUserData("table", { columns = { 1, 1 } })

    local enable = AceGUI:Create("CheckBox")
    general_group:AddChild(enable)
    enable.configure = function()
        enable:SetLabel(ENABLE)
        enable:SetValue(profile["enable"])
        enable:SetRelativeWidth(0.4)
        enable:SetCallback("OnValueChanged", function(widget, event, val)
            profile["enable"] = val
            if val then
                addon:enable()
            else
                addon:disable()
            end
        end)
    end

    local poll = AceGUI:Create("Slider")
    general_group:AddChild(poll)
    poll.configure = function()
        poll:SetLabel(L["Polling Interval (seconds)"])
        poll:SetValue(profile["poll"])
        poll:SetRelativeWidth(0.4)
        poll:SetSliderValues(0.05, 1.0, 0.05)
        poll:SetCallback("OnValueChanged", function(widget, event, val)
            profile["poll"] = val
            if addon.rotationTimer then
                addon:DisableRotationTimer()
                addon:EnableRotationTimer()
            end
        end)
    end

    local minimap = AceGUI:Create("CheckBox")
    general_group:AddChild(minimap)
    minimap.configure = function()
        minimap:SetLabel(L["Minimap Icon"])
        minimap:SetValue(not profile["minimap"].hide)
        minimap:SetRelativeWidth(0.4)
        minimap:SetCallback("OnValueChanged", function(widget, event, val)
            profile["minimap"].hide = not val
            if val then
                DBIcon:Show(addon.namen)
            else
                DBIcon:Hide(addon.name)
            end
        end)
    end

    local spell_history = AceGUI:Create("Slider")
    general_group:AddChild(spell_history)
    spell_history.configure = function()
        spell_history:SetLabel(L["Spell History Memory (seconds)"])
        spell_history:SetValue(profile["spell_history"])
        spell_history:SetRelativeWidth(0.4)
        spell_history:SetSliderValues(0.0, 300, 1)
        spell_history:SetCallback("OnValueChanged", function(widget, event, val)
            profile["spell_history"] = val
        end)
    end

    local ignore_mana = AceGUI:Create("CheckBox")
    general_group:AddChild(ignore_mana)
    ignore_mana.configure = function()
        ignore_mana:SetLabel(L["Ignore Mana"])
        ignore_mana:SetValue(profile["ignore_mana"])
        ignore_mana:SetRelativeWidth(0.4)
        ignore_mana:SetCallback("OnValueChanged", function(widget, event, val)
            profile["ignore_mana"] = val
        end)
    end

    local ignore_range = AceGUI:Create("CheckBox")
    general_group:AddChild(ignore_range)
    ignore_range.configure = function()
        ignore_range:SetLabel(L["Ignore Range"])
        ignore_range:SetValue(profile["ignore_range"])
        ignore_range:SetRelativeWidth(0.4)
        ignore_range:SetCallback("OnValueChanged", function(widget, event, val)
            profile["ignore_range"] = val
        end)
    end

    local effect_header = AceGUI:Create("Heading")
    scroll:AddChild(effect_header)
    effect_header.configure = function()
        effect_header:SetText(L["Effect Options"])
        effect_header:SetFullWidth(true)
    end

    local fx_group = AceGUI:Create("SimpleGroup")
    scroll:AddChild(fx_group)
    fx_group:SetFullWidth(true)
    fx_group:SetLayout("Table")
    fx_group:SetUserData("table", { columns = { 1, 1 } })

    local effect_group = AceGUI:Create("SimpleGroup")
    fx_group:AddChild(effect_group)
    effect_group:SetRelativeWidth(0.4)
    effect_group:SetLayout("Table")
    effect_group:SetUserData("table", { columns = { 44, 1 } })

    local effect_map, effect_order, name2idx
    local function update_effect_map()
        effect_map = {}
        effect_order = {}
        name2idx = {}
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
    effect_group:AddChild(effect_icon)
    effect_icon.configure = function()
        effect_icon:SetImageSize(36, 36)
        if name2idx[profile["effect"]] ~= nil then
            if effects[name2idx[profile["effect"]]].type == "texture" then
                effect_icon:SetHeight(44)
                effect_icon:SetWidth(44)
                effect_icon:SetImage(effects[name2idx[profile["effect"]]].texture)
            else
                effect_icon:SetImage(nil)
                effect_icon:SetHeight(36)
                effect_icon:SetWidth(36)
                addon:ApplyCustomGlow(effects[name2idx[profile["effect"]]], effect_icon.frame, nil, profile["color"])
            end
        end
    end

    local effect = AceGUI:Create("Dropdown")
    effect_group:AddChild(effect)
    effect.configure = function()
        effect:SetLabel(L["Effect"])
        effect:SetText(effect_map[profile["effect"]])
        effect:SetValue(profile["effect"])
        effect:SetList(effect_map, effect_order)
        effect:SetHeight(44)
        effect:SetCallback("OnValueChanged", function(widget, event, val)
            profile["effect"] = val
            addon:RemoveAllCurrentGlows()
            addon:StopCustomGlow(effect_icon.frame)
            create_primary_options(frame)
        end)
        effect.frame:SetScript("OnShow", function(frame)
            update_effect_map()
            effect:SetList(effect_map, effect_order)
        end)
    end

    local magnification = AceGUI:Create("Slider")
    fx_group:AddChild(magnification)
    magnification.configure = function()
        magnification:SetLabel(L["Magnification"])
        magnification:SetValue(profile["magnification"])
        magnification:SetRelativeWidth(0.4)
        magnification:SetSliderValues(0.1, 2.0, 0.1)
        magnification:SetDisabled(name2idx[profile["effect"]] == nil or effects[name2idx[profile["effect"]]].type ~= "texture")
        magnification:SetCallback("OnValueChanged", function(widget, event, val)
            profile["magnification"] = val
            addon:RemoveAllCurrentGlows()
        end)
    end

    local color_group = AceGUI:Create("SimpleGroup")
    fx_group:AddChild(color_group)
    color_group:SetRelativeWidth(0.4)
    color_group:SetLayout("Table")
    color_group:SetUserData("table", { columns = { 44, 1 } })

    local color_pick = AceGUI:Create("ColorPicker")
    color_group:AddChild(color_pick)
    color_pick.configure = function()
        color_pick:SetColor(profile["color"].r, profile["color"].g, profile["color"].b, profile["color"].a)
        color_pick:SetLabel(L["Highlight Color"])
        color_pick:SetCallback("OnValueConfirmed", function(widget, event, r, g, b, a)
            profile["color"] = { r = r, g = g, b = b, a = a }
            addon:RemoveAllCurrentGlows()
            if name2idx[profile["effect"]] ~= nil and effects[name2idx[profile["effect"]]].type ~= "texture" then
                addon:ApplyCustomGlow(effects[name2idx[profile["effect"]]], effect_icon.frame, nil, profile["color"])
            end
        end)
    end

    local position_group = AceGUI:Create("SimpleGroup")
    fx_group:AddChild(position_group)
    position_group:SetLayout("Table")
    position_group:SetRelativeWidth(0.4)
    position_group:SetUserData("table", { columns = { 1, 20, 35, 50 } })

    local position = AceGUI:Create("Dropdown")
    position_group:AddChild(position)
    position.configure = function()
        position:SetLabel(L["Position"])
        position:SetText(addon.setpoints[profile["setpoint"]])
        position:SetValue(profile["setpoint"])
        position:SetList(addon.setpoints, { "CENTER", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOP", "BOTTOM", "LEFT", "RIGHT" })
        position:SetDisabled(name2idx[profile["effect"]] == nil or effects[name2idx[profile["effect"]]].type ~= "texture")
        position:SetCallback("OnValueChanged", function(widget, event, val)
            profile["setpoint"] = val
            profile["xoffs"] = 0
            profile["yoffs"] = 0
            addon:RemoveAllCurrentGlows()
        end)
    end

    position_group:AddChild(spacer(0.1))

    local directional_group = AceGUI:Create("SimpleGroup")
    position_group:AddChild(directional_group)
    directional_group:SetLayout("Table")
    directional_group:SetUserData("table", { columns = { 10, 10, 10 } })

    local offset_group = AceGUI:Create("SimpleGroup")
    position_group:AddChild(offset_group)
    offset_group:SetLayout("Table")
    offset_group:SetUserData("table", { columns = { 10, 40 } })

    local x_label = AceGUI:Create("Label")
    offset_group:AddChild(x_label)
    x_label.configure = function()
        x_label:SetText("X")
        x_label:SetColor(1.0, 0.82, 0)
    end

    local x_offs = AceGUI:Create("EditBox")
    offset_group:AddChild(x_offs)
    x_offs.configure = function()
        x_offs:SetDisabled(true)
        x_offs:SetText(profile["xoffs"])
    end

    local y_label = AceGUI:Create("Label")
    offset_group:AddChild(y_label)
    y_label.configure = function()
        y_label:SetText("Y")
        y_label:SetColor(1.0, 0.82, 0)
    end

    local y_offs = AceGUI:Create("EditBox")
    offset_group:AddChild(y_offs)
    y_offs.configure = function()
        y_offs:SetDisabled(true)
        y_offs:SetText(profile["yoffs"])
    end

    directional_group:AddChild(spacer(1))

    local button_up = AceGUI:Create("InteractiveLabel")
    directional_group:AddChild(button_up)
    button_up.configure = function()
        button_up:SetText("^")
        button_up:SetDisabled(name2idx[profile["effect"]] ~= nil and effects[name2idx[profile["effect"]]].type == "blizzard")
        button_up:SetCallback("OnClick", function(widget, event, val)
            profile["yoffs"] = (profile["yoffs"] or 0) + 1
            y_offs:SetText(profile["yoffs"])
            addon:RemoveAllCurrentGlows()
        end)
    end

    directional_group:AddChild(spacer(1))

    local button_left = AceGUI:Create("InteractiveLabel")
    directional_group:AddChild(button_left)
    button_left.configure = function()
        button_left:SetText("<")
        button_left:SetDisabled(name2idx[profile["effect"]] ~= nil and effects[name2idx[profile["effect"]]].type == "blizzard")
        button_left:SetCallback("OnClick", function(widget, event, val)
            profile["xoffs"] = (profile["xoffs"] or 0) - 1
            x_offs:SetText(profile["xoffs"])
            addon:RemoveAllCurrentGlows()
        end)
    end

    local button_center = AceGUI:Create("InteractiveLabel")
    directional_group:AddChild(button_center)
    button_center.configure = function()
        button_center:SetText("o")
        button_center:SetDisabled(name2idx[profile["effect"]] ~= nil and effects[name2idx[profile["effect"]]].type == "blizzard")
        button_center:SetCallback("OnClick", function(widget, event, val)
            profile["xoffs"] = 0
            profile["yoffs"] = 0
            x_offs:SetText(profile["xoffs"])
            y_offs:SetText(profile["yoffs"])
            addon:RemoveAllCurrentGlows()
        end)
    end

    local button_right = AceGUI:Create("InteractiveLabel")
    directional_group:AddChild(button_right)
    button_right.configure = function()
        button_right:SetText(">")
        button_right:SetDisabled(name2idx[profile["effect"]] ~= nil and effects[name2idx[profile["effect"]]].type == "blizzard")
        button_right:SetCallback("OnClick", function(widget, event, val)
            profile["xoffs"] = (profile["xoffs"] or 0) + 1
            x_offs:SetText(profile["xoffs"])
            addon:RemoveAllCurrentGlows()
        end)
    end

    directional_group:AddChild(spacer(1))

    local button_down = AceGUI:Create("InteractiveLabel")
    directional_group:AddChild(button_down)
    button_down.configure = function()
        button_down:SetText("v")
        button_down:SetDisabled(name2idx[profile["effect"]] ~= nil and effects[name2idx[profile["effect"]]].type == "blizzard")
        button_down:SetCallback("OnClick", function(widget, event, val)
            profile["yoffs"] = (profile["yoffs"] or 0) - 1
            y_offs:SetText(profile["yoffs"])
            addon:RemoveAllCurrentGlows()
        end)
    end

    directional_group:AddChild(spacer(1))

    local debug_header = AceGUI:Create("Heading")
    scroll:AddChild(debug_header)
    debug_header.configure = function()
        debug_header:SetText(L["Debugging Options"])
        debug_header:SetFullWidth(true)
    end

    local debug_group = AceGUI:Create("SimpleGroup")
    scroll:AddChild(debug_group)
    debug_group:SetFullWidth(true)
    debug_group:SetLayout("Table")
    debug_group:SetUserData("table", { columns = { 1, 1 } })

    local debug = AceGUI:Create("CheckBox")
    debug_group:AddChild(debug)
    debug.configure = function()
        debug:SetLabel(L["Debug Logging"])
        debug:SetValue(profile["debug"])
        debug:SetRelativeWidth(0.4)
        debug:SetCallback("OnValueChanged", function(widget, event, val)
            profile["debug"] = val
            addon:StopCustomGlow(effect_icon.frame)
            create_primary_options(frame)
        end)
    end

    local disable_autoswitch = AceGUI:Create("CheckBox")
    debug_group:AddChild(disable_autoswitch)
    disable_autoswitch.configure = function()
        disable_autoswitch:SetLabel(L["Disable Auto-Switching"])
        disable_autoswitch:SetValue(profile["disable_autoswitch"])
        disable_autoswitch:SetRelativeWidth(0.4)
        disable_autoswitch:SetCallback("OnValueChanged", function(widget, event, val)
            profile["disable_autoswitch"] = val
        end)
    end

    local verbose = AceGUI:Create("CheckBox")
    debug_group:AddChild(verbose)
    verbose.configure = function()
        verbose:SetLabel(L["Verbose Debug Logging"])
        verbose:SetValue(profile["verbose"])
        verbose:SetRelativeWidth(0.4)
        verbose:SetDisabled(not profile["debug"])
        verbose:SetCallback("OnValueChanged", function(widget, event, val)
            profile["verbose"] = val
        end)
    end

    local live_config_update = AceGUI:Create("Slider")
    debug_group:AddChild(live_config_update)
    live_config_update.configure = function()
        live_config_update:SetLabel(L["Live Status Update Frequency (seconds)"])
        live_config_update:SetValue(profile["live_config_update"])
        live_config_update:SetRelativeWidth(0.4)
        live_config_update:SetSliderValues(0, 60, 1)
        live_config_update:SetCallback("OnValueChanged", function(widget, event, val)
            if profile["live_config_update"] ~= val then
                profile["live_config_update"] = val
                if addon.rotationTimer then
                    addon:CancelTimer(addon.conditionEvalTimer)
                end
                if val > 0 then
                    addon.conditionEvalTimer = addon:ScheduleRepeatingTimer('UpdateCurrentCondition', val)
                end
            end
        end)
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local create_spec_options

local function HandleDelete(spec, rotation, frame)
    local rotation_settings = addon.db.char.rotations

    StaticPopupDialogs["ROTATIONMASTER_DELETE_ROTATION"] = {
        text = L["Are you sure you wish to delete this rotation?"],
        button1 = ACCEPT,
        button2 = CANCEL,
        OnAccept = function(self)
            if (rotation_settings[spec] ~= nil and rotation_settings[spec][rotation] ~= nil) then
                if addon.currentSpec == spec and addon.currentRotation == rotation then
                    addon:RemoveAllCurrentGlows()
                    addon.manualRotation = false
                    addon.currentRotation = nil
                end
                rotation_settings[spec][rotation] = nil
                if addon.currentSpec == spec then
                    addon:UpdateAutoSwitch()
                    addon:SwitchRotation()
                end

                addon.currentConditionEval = nil
                create_spec_options(frame, spec, DEFAULT)
            end
        end,
        showAlert = 1,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1
    }
    StaticPopup_Show("ROTATIONMASTER_DELETE_ROTATION")
end

local function ImportExport(spec, rotation, parent)
    local rotation_settings = addon.db.char.rotations
    local original_name
    if rotation ~= DEFAULT and rotation_settings[spec][rotation] ~= nil then
        original_name = rotation_settings[spec][rotation].name
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle(L["Import/Export Rotation"])
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
    frame:SetLayout("List")
    frame:SetWidth(500)
    HideOnEscape(frame)

    frame:PauseLayout()

    local desc = AceGUI:Create("Label")
    frame:AddChild(desc)
    desc.configure = function()
        desc:SetText(L["Copy and paste this text share your profile with others, or import someone else's."])
        desc:SetFullWidth(true)
    end

    local import = AceGUI:Create("Button")
    local editbox = AceGUI:Create("MultiLineEditBox")
    frame:AddChild(editbox)

    editbox.configure = function()
        editbox:SetLabel("")
        editbox:SetFullHeight(true)
        editbox:SetFullWidth(true)
        editbox:SetNumLines(27)
        editbox:DisableButton(true)
        editbox:SetFocus(true)
        if (rotation_settings[spec][rotation] ~= nil) then
            editbox:SetText(width_split(base64enc(libc:Compress(AceSerializer:Serialize(rotation_settings[spec][rotation]))), 64))
        end
        editbox.editBox:GetRegions():SetFont("Interface\\AddOns\\RotationMaster\\Fonts\\Inconsolata-Bold.ttf", 13)
        editbox:SetCallback("OnTextChanged", function(widget, event, text)
            if text:match('^[0-9A-Za-z+/\r\n]+=*$') then
                local decomp = libc:Decompress(base64dec(text))
                if decomp ~= nil and AceSerializer:Deserialize(decomp) then
                    frame:SetStatusText(string.len(text) .. " " .. L["bytes"] .. " (" .. select(2, text:gsub('\n', '\n'))+1 .. " " .. L["lines"] .. ")")
                    import:SetDisabled(false)
                    return
                end
            end
            frame:SetStatusText(string.len(text) .. " " .. L["bytes"] .. " (" .. select(2, text:gsub('\n', '\n'))+1 .. " " .. L["lines"] .. ") - " ..
                    color.RED .. L["Parse Error"])
            import:SetDisabled(true)
        end)

        frame:SetStatusText(string.len(editbox:GetText()) .. " " .. L["bytes"] .. " (" .. select(2, editbox:GetText():gsub('\n', '\n'))+1 .. " " .. L["lines"] .. ")")
        editbox:HighlightText(0, string.len(editbox:GetText()))
    end

    frame:AddChild(import)
    import.configure = function()
        import:SetText(L["Import"])
        import:SetDisabled(true)
        import:SetCallback("OnClick", function(wiget, event)
            ok, res = AceSerializer:Deserialize(libc:Decompress(base64dec(editbox:GetText())))
            if ok then
                rotation_settings[spec][rotation] = res
                if rotation == DEFAULT then
                    rotation_settings[spec][rotation].name = nil
                elseif original_name ~= nil then
                    rotation_settings[spec][rotation].name = original_name
                else
                    original_name = rotation_settings[spec][rotation].name
                    if original_name == nil then
                        rotation_settings[spec][rotation].name = date(L["Imported on %c"])
                    else
                        -- Keep the imported name, IF it's a duplicate
                        for k, v in pairs(rotation_settings[spec]) do
                            if k ~= DEFAULT and k ~= rotation then
                                if v.name == original_name then
                                    rotation_settings[spec][rotation].name = date(L["Imported on %c"])
                                    break
                                end
                            end
                        end
                    end
                end

                frame:Hide()
                create_spec_options(parent, spec, rotation)
            end
        end)
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function create_rotation_options(frame, specID, rotid, parent, selected)
    local profile = addon.db.profile
    local rotation_settings = addon.db.char.rotations[specID]

    local name2id = {}
    for id,rot in pairs(rotation_settings) do
        if id ~= DEFAULT then
            name2id[rot.name] = id
        end
    end

    frame:ReleaseChildren()
    frame:PauseLayout()

    if (rotid == DEFAULT and rotation_settings[rotid] == nil) then
        rotation_settings[rotid] = {}
    end

    local name = AceGUI:Create("EditBox")
    frame:AddChild(name)
    name.configure = function()
        name:SetLabel(NAME)
        name:SetRelativeWidth(0.5)
        if rotid == DEFAULT then
            name:SetText(DEFAULT)
        elseif rotation_settings[rotid] ~= nil then
            name:SetText(rotation_settings[rotid].name)
        end
        name:SetDisabled(rotid == DEFAULT)
        name:SetCallback("OnTextChanged", function(widget, event, val)
            if val == DEFAULT or val == NEW or val == "" then
                name:DisableButton(true)
            else
                name:DisableButton(name2id[val] ~= nil)
            end
        end)
        name:SetCallback("OnEnterPressed", function(widget, event, val)
            if val ~= DEFAULT and val ~= NEW and val ~= "" and name2id[val] == nil then
                if rotation_settings[rotid] == nil then
                    rotation_settings[rotid] = { name = val }
                else
                    rotation_settings[rotid].name = val
                end
                create_spec_options(parent, specID, rotid)
            end
        end)
    end

    local delete = AceGUI:Create("Button")
    frame:AddChild(delete)
    delete.configure = function()
        delete:SetText(DELETE)
        delete:SetRelativeWidth(0.25)
        delete:SetDisabled(rotid == DEFAULT or rotation_settings[rotid] == nil)
        delete:SetCallback("OnClick", function(widget, event)
            HandleDelete(specID, rotid, parent)
        end)
    end

    local importexport = AceGUI:Create("Button")
    frame:AddChild(importexport)
    importexport.configure = function()
        importexport:SetText(L["Import/Export"])
        importexport:SetRelativeWidth(0.25)
        importexport:SetCallback("OnClick", function(widget, event)
            ImportExport(specID, rotid, parent)
        end)
    end

    local switch = AceGUI:Create("InlineGroup")
    frame:AddChild(switch)
    switch:SetTitle(L["Switch Condition"])
    switch:SetLayout("Flow")
    switch:SetFullWidth(true)

    local switch_desc = AceGUI:Create("Label")
    switch:AddChild(switch_desc)
    switch_desc:SetFullWidth(true)
    if rotid == DEFAULT then
        switch_desc:SetText(L["No other rotations match."])
    else
        local switch_valid = AceGUI:Create("Label")
        switch:AddChild(switch_valid)
        switch_valid.configure = function()
            switch_valid:SetColor(255, 0, 0)
            switch_valid:SetRelativeWidth(0.75)
        end

        local function update_switch()
            if rotation_settings[rotid] == nil or rotation_settings[rotid].switch == nil or
                    not addon:usefulSwitchCondition(rotation_settings[rotid].switch) then
                switch_desc:SetText(L["Manual switch only."])
                switch_valid:SetText("")
            else
                switch_desc:SetText(addon:printSwitchCondition(rotation_settings[rotid].switch, specID))
                if addon:validateSwitchCondition(rotation_settings[rotid].switch, specId) then
                    switch_valid:SetText("")
                else
                    switch_valid:SetText(L["THIS CONDITION DOES NOT VALIDATE"])
                end
            end
        end
        update_switch()

        local switch_button = AceGUI:Create("Button")
        switch:AddChild(switch_button)
        switch_button.configure = function()
            switch_button:SetRelativeWidth(0.25)
            switch_button:SetText(EDIT)
            switch_button:SetDisabled(rotation_settings[rotid] == nil)
            switch_button:SetCallback("OnClick", function(widget, event)
                if rotation_settings[rotid].switch == nil then
                    rotation_settings[rotid].switch = { type = nil }
                end
                addon:EditSwitchCondition(spec, rotation_settings[rotid].switch, update_switch)
            end)
        end
    end

    if rotation_settings[rotid] == nil or not addon:rotationValidConditions(rotation_settings[rotid]) then
        local rotation_valid = AceGUI:Create("Heading")
        frame:AddChild(rotation_valid)
        rotation_valid.configure = function()
            rotation_valid:SetText(color.RED .. L["THIS ROTATION WILL NOT BE USED AS IT IS INCOMPLETE"] .. color.RESET)
            rotation_valid:SetFullWidth(true)
        end

        if addon.currentRotation == rotid and not addon.manualRotation then
            if profile.disable_autoswitch then
                addon:DisableRotation();
            else
                addon:UpdateAutoSwitch()
                addon:SwitchRotation()
            end
        end
    else
        if addon.currentRotation == nil and not addon.manualRotation and not profile.disable_autoswitch then
            addon:UpdateAutoSwitch()
            addon:SwitchRotation()
        end
    end

    local tree = AceGUI:Create("TreeGroup")
    frame:AddChild(tree)
    tree:SetFullWidth(true)
    tree:SetFullHeight(true)
    tree:SetLayout("Fill")

    local cooldowns
    local rotation
    local function update_rotation_list()
        cooldowns = {}
        rotation = {}

        if rotation_settings[rotid] ~= nil then
            local function make_name(idx, rot)
                local name
                if rot.disabled ~= nil and rot.disabled == true then
                    name = color.GRAY
                elseif rot.type == nil or rot.action == nil or not addon:validateCondition(rot.conditions, specID) then
                    name = color.RED
                else
                    name = ""
                end
                name = name .. tostring(idx)

                if rot.use_name == nil then
                    rot.use_name = (rot.name ~= nil and string.len(rot.name) > 0)
                end

                if rot.use_name then
                    if (rot.name ~= nil and string.len(rot.name)) then
                        name = name .. " - " .. rot.name
                    end
                else
                    if rot.action ~= nil then
                        if rot.type == "spell" or rot.type =="petspell" then
                            name = name .. " - " .. select(1, GetSpellInfo(rot.action))
                        elseif rot.type == "item" and #rot.action > 0 then
                            if #rot.action > 1 then
                                name = name .. " - " .. string.format(L["%s or %d others"], rot.action[1], #rot.action-1)
                            else
                                name = name .. " - " .. rot.action[1]
                            end
                        end
                    end
                end
                name = name .. color.RESET

                return name
            end

            if rotation_settings[rotid].cooldowns ~= nil then
                for idx, rot in pairs(rotation_settings[rotid].cooldowns) do
                    table.insert(cooldowns, {
                        value = rot.id,
                        text = make_name(idx, rot)
                    })
                end
            end
            table.insert(cooldowns, {
                value = "*",
                text = ADD
            })

            if rotation_settings[rotid].rotation ~= nil then
                for idx, rot in pairs(rotation_settings[rotid].rotation) do
                    table.insert(rotation, {
                        value = rot.id,
                        text = make_name(idx, rot)
                    })
                end
            end

            table.insert(rotation, {
                value = "*",
                text = ADD
            })
        end

        tree:SetTree( {
            {
                value = "C",
                text = color.BLIZ_YELLOW .. L["Cooldowns"] .. color.RESET,
                children = cooldowns,
                disabled = true,
            },
            {
                value = "R",
                text = color.BLIZ_YELLOW .. L["Rotation"] .. color.RESET,
                children = rotation,
                disabled = true,
            },
        })
    end
    update_rotation_list()

    local status = {
        groups = {
            C = true,
            R = true
        }
    }
    tree:SetStatusTable(status)

    local scrollwin = AceGUI:Create("ScrollFrame")
    tree:AddChild(scrollwin)
    scrollwin:SetLayout("Flow")
    scrollwin:SetFullHeight(true)
    scrollwin:SetFullWidth(true)

    if selected ~= nil then
        tree:SelectByValue(selected)
        section, key = ("\001"):split(selected)
        if section == "C" then
            addon:get_cooldown_list(scrollwin, specID, rotid, key,
                    function() create_rotation_options(frame, specID, rotid, parent, selected) end)
        elseif section == "R" then
            addon:get_rotation_list(scrollwin, specID, rotid, key,
                    function() create_rotation_options(frame, specID, rotid, parent, selected) end)
        end
    end

    tree:SetCallback("OnGroupSelected", function(widget, event, val)
        section, key = ("\001"):split(val)
        if section == "C" then
            if key == "*" then
                if rotation_settings[rotid].cooldowns == nil then
                    rotation_settings[rotid].cooldowns = {}
                end
                id = addon:uuid()
                table.insert(rotation_settings[rotid].cooldowns, { id = id })
                create_rotation_options(frame, specID, rotid, parent, "C\001" .. id)
            else
                addon:get_cooldown_list(scrollwin, specID, rotid, key,
                    function() create_rotation_options(frame, specID, rotid, parent, val) end)
            end
        elseif section == "R" then
            if key == "*" then
                if rotation_settings[rotid].rotation == nil then
                    rotation_settings[rotid].rotation = {}
                end
                id = addon:uuid()
                table.insert(rotation_settings[rotid].rotation, { id = id })
                create_rotation_options(frame, specID, rotid, parent, "R\001" .. id)
            else
                addon:get_rotation_list(scrollwin, specID, rotid, key,
                    function() create_rotation_options(frame, specID, rotid, parent, val) end)
            end
        end
    end)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

create_spec_options = function(frame, specID, selected)
    local rotation_settings = addon.db.char.rotations

    frame:ReleaseChildren()
    frame:PauseLayout()

    if rotation_settings[specID] == nil then
        rotation_settings[specID] = {}
    end

    local rotation_args = {}
    local rotation_order = {}
    for id, rot in pairs(rotation_settings[specID]) do
        if id ~= DEFAULT then
            table.insert(rotation_order, id)
            rotation_args[id] = rot.name
        end
    end

    table.sort(rotation_order, function(lhs, rhs)
        return rotation_settings[specID][lhs].name < rotation_settings[specID][rhs].name
    end)

    rotation_args[DEFAULT] = DEFAULT;
    table.insert(rotation_order, 1, DEFAULT)

    local newid = addon:uuid()
    rotation_args[newid] = NEW;
    rotation_order[#rotation_order + 1] = newid

    local rotations = AceGUI:Create("DropdownGroup")
    frame:AddChild(rotations)
    rotations:SetGroupList(rotation_args, rotation_order)
    rotations:SetGroup(selected)
    rotations:SetTitle(L["Rotation"])
    rotations:SetLayout("Flow")
    rotations:SetFullHeight(true)
    rotations:SetFullWidth(true)

    rotations:SetCallback("OnGroupSelected", function(widget, event, val)
        create_rotation_options(rotations, specID, val, frame)
    end)
    create_rotation_options(rotations, specID, selected, frame)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function create_class_options(frame, classID)
    local currentSpec = addon.currentSpec

    frame:ReleaseChildren()
    frame:PauseLayout()

    if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
        local tabs = AceGUI:Create("TabGroup")
        frame:AddChild(tabs)

        local spec_tabs = {}
        for j = 1, GetNumSpecializationsForClassID(classID) do
            local specID, specName = GetSpecializationInfoForClassID(classID, j)
            if currentSpec == nil then
                currentSpec = specID
            end
            table.insert(spec_tabs, {
                value = specID,
                text = specName
            })
        end
        tabs:SetTabs(spec_tabs)
        tabs:SelectTab(currentSpec)
        tabs:SetLayout("Fill")

        tabs:SetCallback("OnGroupSelected", function(widget, event, val)
            create_spec_options(tabs, val, DEFAULT)
        end)
        create_spec_options(tabs, currentSpec, addon.currentRotation or DEFAULT)
    else
        local group = AceGUI:Create("SimpleGroup")
        frame:AddChild(group)
        group:SetLayout("Fill")
        create_spec_options(group, 0, addon.currentRotation or DEFAULT)
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

function module:OnInitialize()
    self.db = addon.db

    -- AceConfig:RegisterOptionsTable(addon.name, options)
    AceConfig:RegisterOptionsTable(addon.name .. "Profiles", AceDBOptions:GetOptionsTable(self.db))

    hooksecurefunc("InterfaceCategoryList_Update", function()
        self:SetupOptions()
    end)
end

function module:SetupOptions()
    if self.didSetup then
        return
    end
    self.didSetup = true

    self.optionsFrame = AceGUI:Create("BlizOptionsGroup")
    self.optionsFrame:SetName(addon.pretty_name)
    self.optionsFrame:SetLayout("Fill")
    self.optionsFrame:SetTitle(addon.pretty_name)
    create_primary_options(self.optionsFrame)
    InterfaceOptions_AddCategory(self.optionsFrame.frame)

    local effects = AceGUI:Create("BlizOptionsGroup")
    effects:SetName(L["Effects"], addon.pretty_name)
    effects:SetLayout("Fill")
    effects:SetTitle(addon.pretty_name .. " - " .. L["Effects"])
    addon:create_effect_list(effects)
    InterfaceOptions_AddCategory(effects.frame)

    local rotation = AceGUI:Create("BlizOptionsGroup")
    rotation:SetName(L["Rotations"], addon.pretty_name)
    rotation:SetLayout("Fill")
    local localized, _, classID = UnitClass("player")
    rotation:SetTitle(addon.pretty_name .. " - " .. localized)
    create_class_options(rotation, classID)
    InterfaceOptions_AddCategory(rotation.frame)
    addon.Rotation = rotation.frame

    for name, module in addon:IterateModules() do
        local f = module["SetupOptions"]
        if f then
            f(module, function(appName, name)
                AceConfigDialog:AddToBlizOptions(appName, name, addon.pretty_name)
            end)
        end
    end

    self.Profile = AceConfigDialog:AddToBlizOptions(addon.name .. "Profiles", L["Profiles"], addon.pretty_name)
    self.About = LibAboutPanel.new(addon.pretty_name, addon.name)
end
