local _, addon = ...

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

local pairs, base64enc, base64dec, date, color, width_split = pairs, base64enc, base64dec, date, color, width_split

local HideOnEscape = addon.HideOnEscape

local function spacer(width)
    local rv = AceGUI:Create("Label")
    rv:SetWidth(width)
    return rv
end

local function create_primary_options(frame)
    local profile = addon.db.profile
    local effects = addon.db.global.effects

    frame:ReleaseChildren()
    frame:PauseLayout()

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")

    local general_group = AceGUI:Create("SimpleGroup")
    general_group:SetFullWidth(true)
    general_group:SetLayout("Table")
    general_group:SetUserData("table", { columns = { 1, 1 } })

    local enable = AceGUI:Create("CheckBox")
    enable:SetFullWidth(true)
    enable:SetLabel(ENABLE)
    enable:SetValue(profile["enable"])
    enable:SetCallback("OnValueChanged", function(_, _, val)
        profile["enable"] = val
        if val then
            addon:enable()
        else
            addon:disable()
        end
    end)
    general_group:AddChild(enable)

    local poll = AceGUI:Create("Slider")
    poll:SetFullWidth(true)
    poll:SetLabel(L["Polling Interval (seconds)"])
    poll:SetValue(profile["poll"])
    poll:SetSliderValues(0.05, 1.0, 0.05)
    poll:SetCallback("OnValueChanged", function(_, _, val)
        profile["poll"] = val
        if addon.rotationTimer then
            addon:DisableRotationTimer()
            addon:EnableRotationTimer()
        end
    end)
    general_group:AddChild(poll)

    local disable_autoswitch = AceGUI:Create("CheckBox")
    disable_autoswitch:SetFullWidth(true)
    disable_autoswitch:SetLabel(L["Disable Auto-Switching"])
    disable_autoswitch:SetValue(profile["disable_autoswitch"])
    disable_autoswitch:SetCallback("OnValueChanged", function(_, _, val)
        profile["disable_autoswitch"] = val
    end)
    general_group:AddChild(disable_autoswitch)

    local live_config_update = AceGUI:Create("Slider")
    live_config_update:SetFullWidth(true)
    live_config_update:SetLabel(L["Live Status Update Frequency (seconds)"])
    live_config_update:SetValue(profile["live_config_update"])
    live_config_update:SetSliderValues(0, 60, 1)
    live_config_update:SetCallback("OnValueChanged", function(_, _, val)
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
    general_group:AddChild(live_config_update)

    local minimap = AceGUI:Create("CheckBox")
    minimap:SetFullWidth(true)
    minimap:SetLabel(L["Minimap Icon"])
    minimap:SetValue(not profile["minimap"].hide)
    minimap:SetCallback("OnValueChanged", function(_, _, val)
        profile["minimap"].hide = not val
        if val then
            DBIcon:Show(addon.namen)
        else
            DBIcon:Hide(addon.name)
        end
    end)
    general_group:AddChild(minimap)

    local spell_history = AceGUI:Create("Slider")
    spell_history:SetFullWidth(true)
    spell_history:SetLabel(L["Spell History Memory (seconds)"])
    spell_history:SetValue(profile["spell_history"])
    spell_history:SetSliderValues(0.0, 300, 1)
    spell_history:SetCallback("OnValueChanged", function(_, _, val)
        profile["spell_history"] = val
    end)
    general_group:AddChild(spell_history)

    local ignore_mana = AceGUI:Create("CheckBox")
    ignore_mana:SetFullWidth(true)
    ignore_mana:SetLabel(L["Ignore Mana"])
    ignore_mana:SetValue(profile["ignore_mana"])
    ignore_mana:SetCallback("OnValueChanged", function(_, _, val)
        profile["ignore_mana"] = val
    end)
    general_group:AddChild(ignore_mana)

    local combat_history = AceGUI:Create("Slider")
    combat_history:SetFullWidth(true)
    combat_history:SetLabel(L["Combat History Memory (seconds)"])
    combat_history:SetValue(profile["combat_history"])
    combat_history:SetSliderValues(0.0, 300, 1)
    combat_history:SetCallback("OnValueChanged", function(_, _, val)
        profile["combat_history"] = val
    end)
    general_group:AddChild(combat_history)

    local ignore_range = AceGUI:Create("CheckBox")
    ignore_range:SetFullWidth(true)
    ignore_range:SetLabel(L["Ignore Range"])
    ignore_range:SetValue(profile["ignore_range"])
    ignore_range:SetCallback("OnValueChanged", function(_, _, val)
        profile["ignore_range"] = val
    end)
    general_group:AddChild(ignore_range)

    local damage_history = AceGUI:Create("Slider")
    damage_history:SetFullWidth(true)
    damage_history:SetLabel(L["Damage History Memory (seconds)"])
    damage_history:SetValue(profile["damage_history"])
    damage_history:SetSliderValues(0.0, 300, 1)
    damage_history:SetCallback("OnValueChanged", function(_, _, val)
        profile["damage_history"] = val
    end)
    general_group:AddChild(damage_history)

    scroll:AddChild(general_group)

    local effect_header = AceGUI:Create("Heading")
    effect_header:SetFullWidth(true)
    effect_header:SetText(L["Effect Options"])
    scroll:AddChild(effect_header)

    local fx_group = AceGUI:Create("SimpleGroup")
    fx_group:SetFullWidth(true)
    fx_group:SetLayout("Table")
    fx_group:SetUserData("table", { columns = { 1, 1 } })

    local effect_group = AceGUI:Create("SimpleGroup")
    effect_group:SetFullWidth(true)
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

    local effect = profile["effect"] and name2idx[profile["effect"]] and effects[name2idx[profile["effect"]]]
    local effect_icon = AceGUI:Create("Icon")
    effect_icon:SetWidth(36)
    effect_icon:SetHeight(36)
    effect_icon.frame:SetScript("OnShow", function(f)
        addon:Glow(f, "effect", effect, profile["color"], 1.0, "CENTER", 0, 0)
    end)
    effect_icon:SetCallback("OnRelease", function(self)
        addon:HideGlow(self.frame, "effect")
    end)
    effect_group:AddChild(effect_icon)

    local effect_sel = AceGUI:Create("Dropdown")
    effect_sel:SetLabel(L["Effect"])
    effect_sel:SetRelativeWidth(0.9)
    effect_sel:SetHeight(44)
    effect_sel:SetCallback("OnValueChanged", function(_, _, val)
        profile["effect"] = val
        addon:RemoveAllCurrentGlows()
        create_primary_options(frame)
    end)
    effect_sel.frame:SetScript("OnShow", function(f)
        update_effect_map()
        f.obj:SetList(effect_map, effect_order)
        f.obj:SetValue(profile["effect"])
    end)
    effect_sel:SetCallback("OnRelease", function(obj)
        obj.frame:SetScript("OnShow", nil)
    end)
    effect_group:AddChild(effect_sel)

    fx_group:AddChild(effect_group)

    local magnification = AceGUI:Create("Slider")
    fx_group:AddChild(magnification)
    magnification:SetLabel(L["Magnification"])
    magnification:SetValue(profile["magnification"])
    magnification:SetSliderValues(0.1, 2.0, 0.1)
    magnification:SetDisabled(effect == nil or effect.type == "pulse" or effect.type == "custom" or addon.index(addon.textured_types, effect.type) == nil)
    magnification:SetCallback("OnValueChanged", function(_, _, val)
        profile["magnification"] = val
        addon:RemoveAllCurrentGlows()
    end)
    magnification:SetFullWidth(true)

    local color_group = AceGUI:Create("SimpleGroup")
    color_group:SetFullWidth(true)
    color_group:SetLayout("Table")
    color_group:SetUserData("table", { columns = { 44, 1 } })
    color_group:AddChild(spacer(1))

    local color_pick = AceGUI:Create("ColorPicker")
    color_pick:SetFullWidth(true)
    color_pick:SetColor(profile["color"].r, profile["color"].g, profile["color"].b, profile["color"].a)
    color_pick:SetLabel(L["Highlight Color"])
    color_pick:SetDisabled(effect == nil or effect.type == "dazzle" or effect.type == "custom" )
    color_pick:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
        profile["color"] = { r = r, g = g, b = b, a = a }
        addon:RemoveAllCurrentGlows()
        addon:HideGlow(effect_icon.frame, "effect")
        addon:Glow(effect_icon.frame, "effect", effect,
                profile["color"], 1.0, "CENTER", 0, 0)
    end)
    color_group:AddChild(color_pick)

    fx_group:AddChild(color_group)

    local position_group = AceGUI:Create("SimpleGroup")
    position_group:SetFullWidth(true)
    position_group:SetLayout("Table")
    position_group:SetUserData("table", { columns = { 1, 10, 40, 10, 50 } })

    local position = AceGUI:Create("Dropdown")
    position:SetFullWidth(true)
    position:SetLabel(L["Position"])
    position:SetDisabled(effect == nil or addon.index(addon.textured_types, effect.type) == nil)
    position:SetCallback("OnValueChanged", function(_, _, val)
        profile["setpoint"] = val
        profile["xoffs"] = 0
        profile["yoffs"] = 0
        addon:RemoveAllCurrentGlows()
    end)
    position.configure = function()
        position:SetList(addon.setpoints, { "CENTER", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOP", "BOTTOM", "LEFT", "RIGHT" })
        position:SetValue(profile["setpoint"])
    end
    position_group:AddChild(position)

    position_group:AddChild(spacer(5))

    local x_offs = AceGUI:Create("EditBox")
    local y_offs = AceGUI:Create("EditBox")

    local directional = AceGUI:Create("Directional")
    directional:SetCallback("OnClick", function(_, _, _, direction)
        if direction == "UP" then
            profile["yoffs"] = (profile["yoffs"] or 0) + 1
            y_offs:SetText(profile["yoffs"])
        elseif direction == "LEFT" then
            profile["xoffs"] = (profile["xoffs"] or 0) - 1
            x_offs:SetText(profile["xoffs"])
        elseif direction == "CENTER" then
            profile["xoffs"] = 0
            profile["yoffs"] = 0
            x_offs:SetText(profile["xoffs"])
            y_offs:SetText(profile["yoffs"])
        elseif direction == "RIGHT" then
            profile["xoffs"] = (profile["xoffs"] or 0) + 1
            x_offs:SetText(profile["xoffs"])
        elseif direction == "DOWN" then
            profile["yoffs"] = (profile["yoffs"] or 0) - 1
            y_offs:SetText(profile["yoffs"])
        end
        addon:RemoveAllCurrentGlows()
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
    x_offs:SetText(profile["xoffs"])
    offset_group:AddChild(x_offs)

    local y_label = AceGUI:Create("Label")
    y_label:SetText("Y")
    y_label:SetColor(1.0, 0.82, 0)
    offset_group:AddChild(y_label)

    y_offs:SetDisabled(true)
    y_offs:SetText(profile["yoffs"])
    offset_group:AddChild(y_offs)

    position_group:AddChild(offset_group)
    fx_group:AddChild(position_group)
    scroll:AddChild(fx_group)

    local debug_header = AceGUI:Create("Heading")
    debug_header:SetFullWidth(true)
    debug_header:SetText(L["Debugging Options"])
    scroll:AddChild(debug_header)

    local debug_group = AceGUI:Create("SimpleGroup")
    debug_group:SetFullWidth(true)
    debug_group:SetLayout("Table")
    debug_group:SetUserData("table", { columns = { 1, 1 } })

    local detailed_profiling = AceGUI:Create("CheckBox")
    local loglevel = AceGUI:Create("Dropdown")
    -- loglevel:SetFullWidth(true)
    loglevel:SetLabel(L["Log Level"])
    loglevel:SetValue(profile["loglevel"] or 2)
    loglevel:SetText(addon.loglevels[profile["loglevel"] or 2])
    loglevel:SetList(addon.loglevels)
    loglevel:SetCallback("OnValueChanged", function(_, _, val)
        profile["loglevel"] = val
        detailed_profiling:SetDisabled(val < 3)
    end)
    debug_group:AddChild(loglevel)

    detailed_profiling:SetFullWidth(true)
    detailed_profiling:SetLabel(L["Detailed Profiling"])
    detailed_profiling:SetValue(profile["detailed_profiling"])
    detailed_profiling:SetDisabled(profile["loglevel"] < 3)
    detailed_profiling:SetCallback("OnValueChanged", function(_, _, val)
        profile["detailed_profiling"] = val
    end)
    debug_group:AddChild(detailed_profiling)


    scroll:AddChild(debug_group)

    frame:AddChild(scroll)

    local help = AceGUI:Create("Help")
    help:SetLayout(addon.layout_primary_options_help)
    help:SetTitle(addon.pretty_name)
    frame:AddChild(help)
    help:SetPoint("TOPRIGHT", 8, 38)

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
        OnAccept = function()
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

    local frame = AceGUI:Create("Window")
    frame:SetTitle(L["Import/Export Rotation"])
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
    frame:SetLayout("List")
    frame:SetWidth(525)
    frame:SetHeight(475)
    frame:EnableResize(false)
    HideOnEscape(frame)

    frame:PauseLayout()

    local desc = AceGUI:Create("Label")
    desc:SetFullWidth(true)
    desc:SetText(L["Copy and paste this text share your profile with others, or import someone else's."])
    frame:AddChild(desc)

    local import = AceGUI:Create("Button")
    local editbox = AceGUI:Create("MultiLineEditBox")

    editbox:SetFullHeight(true)
    editbox:SetFullWidth(true)
    editbox:SetLabel("")
    editbox:SetNumLines(27)
    editbox:DisableButton(true)
    editbox:SetFocus(true)
    if (rotation_settings[spec][rotation] ~= nil) then
        editbox:SetText(width_split(base64enc(libc:Compress(AceSerializer:Serialize(rotation_settings[spec][rotation]))), 64))
    end
    editbox.editBox:GetRegions():SetFont("Interface\\AddOns\\RotationMaster\\Fonts\\Inconsolata-Bold.ttf", 13)
    editbox:SetCallback("OnTextChanged", function(_, _, text)
        if text:match('^[0-9A-Za-z+/\r\n]+=*[\r\n]*$') then
            local decomp = libc:Decompress(base64dec(text))
            if decomp ~= nil and AceSerializer:Deserialize(decomp) then
                --frame:SetStatusText(string.len(text) .. " " .. L["bytes"] .. " (" .. select(2, text:gsub('\n', '\n'))+1 .. " " .. L["lines"] .. ")")
                import:SetDisabled(false)
                return
            end
        end
        --frame:SetStatusText(string.len(text) .. " " .. L["bytes"] .. " (" .. select(2, text:gsub('\n', '\n'))+1 .. " " .. L["lines"] .. ") - " ..
        --        color.RED .. L["Parse Error"])
        import:SetDisabled(true)
    end)

    --frame:SetStatusText(string.len(editbox:GetText()) .. " " .. L["bytes"] .. " (" .. select(2, editbox:GetText():gsub('\n', '\n'))+1 .. " " .. L["lines"] .. ")")
    editbox:HighlightText(0, string.len(editbox:GetText()))
    frame:AddChild(editbox)

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { 1, 0.25, 0.25 } })

    group:AddChild(spacer(1))

    import:SetText(L["Import"])
    import:SetDisabled(true)
    import:SetCallback("OnClick", function(_, _)
        local ok, res = AceSerializer:Deserialize(libc:Decompress(base64dec(editbox:GetText())))
        if ok then
            addon:UpgradeRotationItemsToItemSets(res)
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
    group:AddChild(import)

    local close = AceGUI:Create("Button")
    close:SetText(CANCEL)
    close:SetCallback("OnClick", function(_, _)
        frame:Hide()
    end)
    group:AddChild(close)

    frame:AddChild(group)

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
    name:SetRelativeWidth(0.5)
    name:SetLabel(NAME)
    if rotid == DEFAULT then
        name:SetText(DEFAULT)
    elseif rotation_settings[rotid] ~= nil then
        name:SetText(rotation_settings[rotid].name)
    end
    name:SetDisabled(rotid == DEFAULT)
    name:SetCallback("OnTextChanged", function(_, _, val)
        if val == DEFAULT or val == NEW or val == "" then
            name:DisableButton(true)
        else
            name:DisableButton(name2id[val] ~= nil)
        end
    end)
    name:SetCallback("OnEnterPressed", function(_, _, val)
        if val ~= DEFAULT and val ~= NEW and val ~= "" and name2id[val] == nil then
            if rotation_settings[rotid] == nil then
                rotation_settings[rotid] = { name = val }
            else
                rotation_settings[rotid].name = val
            end
            create_spec_options(parent, specID, rotid)
        end
    end)
    frame:AddChild(name)

    local delete = AceGUI:Create("Button")
    delete:SetRelativeWidth(0.25)
    delete:SetText(DELETE)
    delete:SetDisabled(rotid == DEFAULT or rotation_settings[rotid] == nil)
    delete:SetCallback("OnClick", function()
        HandleDelete(specID, rotid, parent)
    end)
    frame:AddChild(delete)

    local importexport = AceGUI:Create("Button")
    importexport:SetRelativeWidth(0.25)
    importexport:SetText(L["Import/Export"])
    importexport:SetCallback("OnClick", function()
        ImportExport(specID, rotid, parent)
    end)
    frame:AddChild(importexport)

    local switch = AceGUI:Create("InlineGroup")
    switch:SetFullWidth(true)
    switch:SetTitle(L["Switch Condition"])
    switch:SetLayout("Flow")

    local switch_desc = AceGUI:Create("Label")
    switch_desc:SetFullWidth(true)
    switch:AddChild(switch_desc)
    if rotid == DEFAULT then
        switch_desc:SetText(L["No other rotations match."])
    else
        local switch_valid = AceGUI:Create("Label")
        switch_valid:SetRelativeWidth(0.5)
        switch_valid:SetColor(255, 0, 0)
        switch:AddChild(switch_valid)

        local enabledisable_button = AceGUI:Create("Button")
        local function update_switch()
            if (rotation_settings[rotid] == nil or rotation_settings[rotid].switch == nil or
                not addon:usefulSwitchCondition(rotation_settings[rotid].switch)) then
                switch_desc:SetText(L["Manual switch only."])
                enabledisable_button:SetDisabled(true)
                switch_valid:SetText("")
            else
                switch_desc:SetText(addon:printSwitchCondition(rotation_settings[rotid].switch, specID))
                enabledisable_button:SetDisabled(false)
                if rotation_settings[rotid].disabled then
                    switch_valid:SetText(L["Disabled"])
                else
                    if addon:validateSwitchCondition(rotation_settings[rotid].switch, specId) then
                        switch_valid:SetText("")
                    else
                        switch_valid:SetText(L["THIS CONDITION DOES NOT VALIDATE"])
                    end
                end
            end
        end
        update_switch()
        local function update_autoswitch()
            update_switch()
            addon:UpdateAutoSwitch()
            addon:SwitchRotation()
        end

        local edit_button = AceGUI:Create("Button")
        edit_button:SetRelativeWidth(0.25)
        edit_button:SetText(EDIT)
        edit_button:SetDisabled(rotation_settings[rotid] == nil)
        edit_button:SetCallback("OnClick", function()
            if rotation_settings[rotid].switch == nil then
                rotation_settings[rotid].switch = { type = nil }
            end
            addon:EditSwitchCondition(spec, rotation_settings[rotid].switch, update_autoswitch)
        end)
        switch:AddChild(edit_button)

        enabledisable_button:SetRelativeWidth(0.25)
        if not rotation_settings[rotid] or not rotation_settings[rotid].disabled then
            enabledisable_button:SetText(DISABLE)
        else
            enabledisable_button:SetText(ENABLE)
        end
        enabledisable_button:SetCallback("OnClick", function()
            rotation_settings[rotid].disabled = not rotation_settings[rotid].disabled
            if not rotation_settings[rotid].disabled then
                enabledisable_button:SetText(DISABLE)
            else
                enabledisable_button:SetText(ENABLE)
            end
            update_autoswitch()
        end)
        switch:AddChild(enabledisable_button)
    end

    frame:AddChild(switch)

    if rotation_settings[rotid] == nil or not addon:rotationValidConditions(rotation_settings[rotid]) then
        local rotation_valid = AceGUI:Create("Heading")
        rotation_valid:SetFullWidth(true)
        rotation_valid:SetText(color.RED .. L["THIS ROTATION WILL NOT BE USED AS IT IS INCOMPLETE"] .. color.RESET)
        frame:AddChild(rotation_valid)

        if addon.currentRotation == rotid and not addon.manualRotation then
            if profile.disable_autoswitch then
                addon:DisableRotation();
            else
                addon:UpdateAutoSwitch()
                addon:SwitchRotation()
            end
        end
    else
        if addon.currentRotation ~= rotid and not addon.manualRotation and not profile.disable_autoswitch then
            addon:UpdateAutoSwitch()
            addon:SwitchRotation()
        end
    end

    local tree = AceGUI:Create("TreeGroup")
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
                        if rot.type == "spell" or rot.type == "pet" then
			    local spell = GetSpellInfo(rot.action)
			    if spell then
				name = name .. " - " .. select(1, GetSpellInfo(rot.action))
			    end
                        elseif rot.type == "item" then
                            if type(rot.action) == "string" then
                                local itemset
                                if addon.db.char.itemsets[rot.action] ~= nil then
                                    itemset = addon.db.char.itemsets[rot.action]
                                elseif addon.db.global.itemsets[rot.action] ~= nil then
                                    itemset = addon.db.global.itemsets[rot.action]
                                end
                                if itemset ~= nil then
                                    name = name .. " - " .. itemset.name
                                end
                            elseif #rot.action > 0 then
                                if #rot.action > 1 then
                                    name = name .. " - " .. string.format(L["%s or %d others"], rot.action[1], #rot.action-1)
                                else
                                    name = name .. " - " .. rot.action[1]
                                end
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
                text = ADD,
                icon = "Interface\\Minimap\\UI-Minimap-ZoomInButton-Up"
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
                text = ADD,
                icon = "Interface\\Minimap\\UI-Minimap-ZoomInButton-Up"
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
    scrollwin:SetLayout("Flow")
    scrollwin:SetFullHeight(true)
    scrollwin:SetFullWidth(true)

    if selected ~= nil then
        tree:SelectByValue(selected)
        local section, key = ("\001"):split(selected)
        if section == "C" then
            addon:get_cooldown_list(scrollwin, specID, rotid, key,
                    function() create_rotation_options(frame, specID, rotid, parent, selected) end)
        elseif section == "R" then
            addon:get_rotation_list(scrollwin, specID, rotid, key,
                    function() create_rotation_options(frame, specID, rotid, parent, selected) end)
        end
    end

    tree:SetCallback("OnGroupSelected", function(_, _, val)
        local section, key = ("\001"):split(val)
        if section == "C" then
            if key == "*" then
                if rotation_settings[rotid].cooldowns == nil then
                    rotation_settings[rotid].cooldowns = {}
                end
                local id = addon:uuid()
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
                local id = addon:uuid()
                table.insert(rotation_settings[rotid].rotation, { id = id })
                create_rotation_options(frame, specID, rotid, parent, "R\001" .. id)
            else
                addon:get_rotation_list(scrollwin, specID, rotid, key,
                    function() create_rotation_options(frame, specID, rotid, parent, val) end)
            end
        end
    end)

    tree:AddChild(scrollwin)
    frame:AddChild(tree)

    local help = AceGUI:Create("Help")
    help:SetLayout(addon.layout_rotation_options_help)
    help:SetTitle(L["Rotations"])
    frame:AddChild(help)
    help:SetPoint("TOPRIGHT", 8, 8)

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
    rotations:SetGroupList(rotation_args, rotation_order)
    rotations:SetGroup(selected)
    rotations:SetTitle(L["Rotation"])
    rotations:SetLayout("Flow")
    rotations:SetFullHeight(true)
    rotations:SetFullWidth(true)

    rotations:SetCallback("OnGroupSelected", function(_, _, val)
        create_rotation_options(rotations, specID, val, frame)
    end)
    create_rotation_options(rotations, specID, selected, frame)

    frame:AddChild(rotations)

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
        addon.specTab = tabs

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

        tabs:SetCallback("OnGroupSelected", function(_, _, val)
            create_spec_options(tabs, val, (val == addon.currentSpec) and addon.currentRotation or DEFAULT)
        end)
        frame.frame:SetScript("OnShow", function(f)
            create_spec_options(tabs, currentSpec, addon.currentRotation or DEFAULT)
            f:SetScript("OnShow", nil)
        end)

        frame:AddChild(tabs)
    else
        local group = AceGUI:Create("SimpleGroup")
        group:SetLayout("Fill")
        frame.frame:SetScript("OnShow", function(f)
            create_spec_options(group, 0, addon.currentRotation or DEFAULT)
            f:SetScript("OnShow", nil)
        end)

        frame:AddChild(group)
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

function module:OnInitialize()
    self.db = addon.db

    -- AceConfig:RegisterOptionsTable(addon.name, options)
    AceConfig:RegisterOptionsTable(addon.name .. "Profiles", AceDBOptions:GetOptionsTable(self.db))

    self:SetupOptions()
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

    local itemsets = AceGUI:Create("BlizOptionsGroup")
    itemsets:SetName(L["Item Sets"], addon.pretty_name)
    itemsets:SetLayout("Fill")
    -- itemsets:SetTitle(addon.pretty_name .. " - " .. L["Item Sets"])
    addon:create_itemset_list(itemsets)
    InterfaceOptions_AddCategory(itemsets.frame)

    local rotation = AceGUI:Create("BlizOptionsGroup")
    rotation:SetName(L["Rotations"], addon.pretty_name)
    rotation:SetLayout("Fill")
    local localized, _, classID = UnitClass("player")
    rotation:SetTitle(addon.pretty_name .. " - " .. localized)
    create_class_options(rotation, classID)
    InterfaceOptions_AddCategory(rotation.frame)
    addon.Rotation = rotation.frame

    local announces = AceGUI:Create("BlizOptionsGroup")
    announces:SetName(L["Announces"], addon.pretty_name)
    announces:SetLayout("Fill")
    announces:SetTitle(addon.pretty_name .. " - " .. L["Announces"])
    addon:create_announce_list(announces)
    InterfaceOptions_AddCategory(announces.frame)

    for _, m in addon:IterateModules() do
        local f = m["SetupOptions"]
        if f then
            f(m, function(appName, name)
                AceConfigDialog:AddToBlizOptions(appName, name, addon.pretty_name)
            end)
        end
    end

    self.Profile = AceConfigDialog:AddToBlizOptions(addon.name .. "Profiles", L["Profiles"], addon.pretty_name)
    self.About = LibAboutPanel.new(addon.pretty_name, addon.name)
end
