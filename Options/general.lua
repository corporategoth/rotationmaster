local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local AceGUI = LibStub("AceGUI-3.0")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local DBIcon = LibStub("LibDBIcon-1.0")
local libc = LibStub:GetLibrary("LibCompress")
local AboutPanel = LibStub("LibAboutPanel-2.0")

local pairs, base64enc, base64dec, date, color, width_split = pairs, base64enc, base64dec, date, color, width_split

local HideOnEscape, deepcopy = addon.HideOnEscape, addon.deepcopy

local function spacer(width)
    local rv = AceGUI:Create("Label")
    rv:SetWidth(width)
    return rv
end

function addon:CreatePreviewWindow()
    local profile = self.db.profile

    local window = AceGUI:Create("Window")
    window:SetTitle(self.pretty_name)
    window:SetCallback("OnClose", function()
        self.preview_closed_func()
        profile["preview_spells"] = 0
        self.nextWindow = nil
    end)

    window:ReleaseChildren()
    window:PauseLayout()
    window:EnableResize(false)
    window:SetHeight(128)
    window:SetWidth(profile.preview_spells * 128)
    if profile.preview_window then
        window:SetPoint(profile.preview_window.point, UIParent,
                profile.preview_window.relpoint,
                profile.preview_window.xoffs,
                profile.preview_window.yoffs)
    end
    window:SetLayout("Flow")
    local movefunc = window.title:GetScript("OnMouseUp")
    window.title:SetScript("OnMouseUp", function(widget)
        movefunc(widget)
        local point, _, relpoint, xoffs, yoffs = window:GetPoint(1)
        profile.preview_window = {
            point = point,
            relpoint = relpoint,
            xoffs = xoffs,
            yoffs = yoffs
        }
    end)
    window:ResumeLayout()
    window:DoLayout()

    self.nextWindow = window
end

local create_class_options
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

    local disable_buttons = AceGUI:Create("CheckBox")
    disable_buttons:SetFullWidth(true)
    disable_buttons:SetLabel(L["Disable Bar Highlighting"])
    disable_buttons:SetValue(profile["disable_buttons"])
    disable_buttons:SetCallback("OnValueChanged", function(_, _, val)
        if val == true then
            addon:GlowClear()
        end
        profile["disable_buttons"] = val
    end)
    general_group:AddChild(disable_buttons)

    local preview_group = AceGUI:Create("SimpleGroup")
    preview_group:SetFullWidth(true)
    preview_group:SetLayout("Table")
    preview_group:SetUserData("table", { columns = { 1, 100 } })

    local preview_reset = AceGUI:Create("Button")
    local preview_spells = AceGUI:Create("Slider")
    preview_spells:SetFullWidth(true)
    preview_spells:SetLabel(L["Preview Spells"])
    preview_spells:SetValue(profile["preview_spells"])
    preview_spells:SetSliderValues(0, 5, 1)
    preview_spells:SetCallback("OnValueChanged", function(_, _, val)
        profile["preview_spells"] = val
        if val >= 1 then
            preview_reset:SetDisabled(false)
            if addon.nextWindow then
                addon.nextWindow:SetWidth(val * 128)
            else
                addon:CreatePreviewWindow()
            end
        else
            preview_reset:SetDisabled(true)
            if addon.nextWindow then
                addon.nextWindow:Release()
                addon.nextWindow = nil
            end
        end
    end)
    preview_group:AddChild(preview_spells)

    preview_reset:SetText(RESET)
    preview_reset:SetDisabled(not profile["preview_spells"])
    preview_reset:SetCallback("OnClick", function()
        profile.preview_window = nil
        if addon.nextWindow then
            addon.nextWindow:ClearAllPoints()
            addon.nextWindow:SetPoint("CENTER", 0, 0)
        end
    end)
    preview_group:AddChild(preview_reset)

    addon.preview_closed_func = function()
        preview_spells:SetValue(0)
        preview_reset:SetDisabled(true)
    end

    general_group:AddChild(preview_group)

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

    local effect_map, effect_order
    local function update_effect_map()
        effect_map = {}
        effect_order = {}
        for k, v in pairs(effects) do
            if v.name ~= nil then
                table.insert(effect_order, k)
                effect_map[k] = v.name
            end
        end
    end
    update_effect_map()

    local effect = profile["effect"] and effects[profile["effect"]]
    local effect_icon = AceGUI:Create("Icon")
    effect_icon:SetWidth(36)
    effect_icon:SetHeight(36)
    effect_icon:SetDisabled(true)
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
        effect = profile["effect"] and effects[profile["effect"]]
        addon:Glow(effect_icon.frame, "effect", effect, profile["color"], 1.0, "CENTER", 0, 0)
        addon:RemoveAllCurrentGlows()
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

if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT >= 2 then
    local spec_header = AceGUI:Create("Heading")
    spec_header:SetFullWidth(true)
    spec_header:SetText(L["Specialization Names"])
    scroll:AddChild(spec_header)

    local spec_group = AceGUI:Create("SimpleGroup")
    spec_group:SetFullWidth(true)
    spec_group:SetLayout("Table")
    spec_group:SetUserData("table", { columns = { 1, 1 } })

    local primary = AceGUI:Create("EditBox")
    primary:SetFullWidth(true)
    primary:SetLabel(PRIMARY)
    primary:SetText(addon.db.char.specs[1])
    primary:SetCallback("OnEnterPressed", function(_, _, val)
        addon.db.char.specs[1] = val
        create_class_options(addon.optionsFrames.Rotation, UnitClass("player"))
    end)
    spec_group:AddChild(primary)

    local secondary = AceGUI:Create("EditBox")
    secondary:SetFullWidth(true)
    secondary:SetLabel(SECONDARY)
    secondary:SetText(addon.db.char.specs[2])
    secondary:SetCallback("OnEnterPressed", function(_, _, val)
        addon.db.char.specs[2] = val
        create_class_options(addon.optionsFrames.Rotation, UnitClass("player"))
    end)
    spec_group:AddChild(secondary)

    scroll:AddChild(spec_group)
end

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
    local rotation_settings = addon.db.profile.rotations

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
    local rotation_settings = addon.db.profile.rotations
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
    desc:SetText(L["Copy and paste this text share your rotation with others, or import someone else's."])
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
    editbox.editBox:GetRegions():SetFont("Interface\\AddOns\\" .. addon_name .. "\\Fonts\\Inconsolata-Bold.ttf", 13)
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
    -- editbox:HighlightText(0, string.len(editbox:GetText()))
    editbox:HighlightText()
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
            if rotation == DEFAULT then
                res.name = nil
            elseif original_name ~= nil then
                res.name = original_name
            elseif res.name == nil then
                res.name = date(L["Imported on %c"])
            else
                for k, v in pairs(rotation_settings[spec]) do
                    if k ~= DEFAULT and k ~= rotation then
                        if v.name == res.name then
                            res.name = date(L["Imported on %c"])
                            break
                        end
                    end
                end
            end
            addon:validate_rotation(L["Import"], rotation, res, true)
            rotation_settings[spec][rotation] = res

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
    local rotation_settings = addon.db.profile.rotations[specID]

    local name2id = {}
    for id,rot in pairs(rotation_settings) do
        if id ~= DEFAULT then
            name2id[rot.name] = id
        end
    end

    frame:ReleaseChildren()
    frame:PauseLayout()

    -- Layout first ...
    local rot_opt = AceGUI:Create("SimpleGroup")
    rot_opt:SetFullWidth(true)
    rot_opt:SetLayout("Table")
    rot_opt:SetUserData("table", { columns = { 1, 24, 24, 24 } })

    if (rotid == DEFAULT and rotation_settings[rotid] == nil) then
        rotation_settings[rotid] = {}
    end

    local name = AceGUI:Create("EditBox")
    name:SetFullWidth(true)
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
    rot_opt:AddChild(name)

    local importexport = AceGUI:Create("Icon")
    importexport:SetImageSize(24, 24)
    importexport:SetImage("Interface\\FriendsFrame\\UI-FriendsList-Small-Up")
    importexport:SetUserData("cell", { alignV = "bottom" })
    importexport:SetCallback("OnClick", function()
        ImportExport(specID, rotid, parent)
    end)
    addon.AddTooltip(importexport, L["Import/Export"])
    rot_opt:AddChild(importexport)

    local duplicate = AceGUI:Create("Icon")
    duplicate:SetImageSize(24, 24)
    duplicate:SetUserData("cell", { alignV = "bottom" })
    if rotation_settings[rotid] == nil then
        duplicate:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-ChatIcon-Maximize-Disabled")
        duplicate:SetDisabled(true)
    else
        duplicate:SetImage("Interface\\ChatFrame\\UI-ChatIcon-Maximize-Up")
        duplicate:SetDisabled(false)
    end
    duplicate:SetCallback("OnClick", function()
        local tmp = deepcopy(rotation_settings[rotid])
        tmp.name = string.format(L["Copy of %s"], tmp.name or DEFAULT)
        local newid = addon:uuid()
        rotation_settings[newid] = tmp

        create_spec_options(parent, specID, newid)
    end)
    addon.AddTooltip(duplicate, L["Duplicate"])
    rot_opt:AddChild(duplicate)

    local delete = AceGUI:Create("Icon")
    delete:SetImageSize(24, 24)
    delete:SetUserData("cell", { alignV = "bottom" })
    if rotid == DEFAULT or rotation_settings[rotid] == nil then
        delete:SetDisabled(true)
        delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled")
    else
        delete:SetDisabled(false)
        delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    end
    delete:SetCallback("OnClick", function()
        HandleDelete(specID, rotid, parent)
    end)
    addon.AddTooltip(delete, DELETE)
    rot_opt:AddChild(delete)

    frame:AddChild(rot_opt)

    local switch = AceGUI:Create("SimpleGroup")
    switch:SetLayout("Table")
    switch:SetFullWidth(true)
    switch:SetUserData("table", { columns = { 1, 36 } })

    local switch_sub = AceGUI:Create("InlineGroup")
    switch_sub:SetUserData("cell", { rowspan = 2, alignV = "top" })
    switch_sub:SetFullWidth(true)
    switch_sub:SetFullHeight(true)
    switch_sub:SetLayout("List")
    switch_sub:SetTitle(L["Switch Condition"])

    -- Enforce minimum height
    local OrigLayoutFinished = switch_sub.LayoutFinished
    switch_sub.LayoutFinished = function(self, width, height)
        if height < 40 then
            height = 40
        end
        OrigLayoutFinished(self, width, height)
    end
    switch:AddChild(switch_sub)

    local disabled = AceGUI:Create("Icon")
    disabled:SetUserData("cell", { alignV = "top" })
    switch:AddChild(disabled)

    local edit_button = AceGUI:Create("Icon")
    edit_button:SetImageSize(36, 36)
    edit_button:SetUserData("cell", { alignV = "bottom" })
    addon.AddTooltip(edit_button, EDIT)
    switch:AddChild(edit_button)

    if rotid == DEFAULT then
        local switch_desc = AceGUI:Create("Label")
        switch_desc:SetFullWidth(true)
        switch_desc:SetText(L["No other rotations match."])
        switch_sub:AddChild(switch_desc)

        disabled:SetImage("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
        disabled:SetImageSize(24, 24)
        disabled:SetDisabled(true)
        addon.AddTooltip(disabled, L["Disabled"])

        edit_button:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-FriendsList-Large-Disabled")
        edit_button:SetDisabled(true)
    else
        local function update_switch()
            switch_sub:ReleaseChildren()
            switch_sub:PauseLayout()

            local switch_desc = AceGUI:Create("Label")
            switch_desc:SetFullWidth(true)

            if (rotation_settings[rotid] == nil or rotation_settings[rotid].switch == nil or
                not addon:usefulCondition(rotation_settings[rotid].switch)) then
                switch_desc:SetText(L["Manual switch only."])
                disabled:SetImage("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
                disabled:SetImageSize(24, 24)
                disabled:SetDisabled(true)
                addon.AddTooltip(disabled, L["Disabled"])
            else
                if not addon:validateCondition(rotation_settings[rotid].switch, specID) then
                    local switch_valid = AceGUI:Create("Heading")
                    switch_valid:SetFullWidth(true)
                    switch_valid:SetText(color.RED .. L["THIS CONDITION DOES NOT VALIDATE"] .. color.RESET)
                    switch_sub:AddChild(switch_valid)
                    if rotation_settings[rotid].disabled then
                        disabled:SetImage("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                        disabled:SetImageSize(24, 24)
                        addon.AddTooltip(disabled, L["Disabled"])
                    else
                        disabled:SetImage("Interface\\CharacterFrame\\UI-Player-PlayTimeUnhealthy")
                        disabled:SetImageSize(28, 28)
                        addon.AddTooltip(disabled, L["Invalid"])
                    end
                elseif rotation_settings[rotid].disabled then
                    disabled:SetImage("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                    disabled:SetImageSize(24, 24)
                    addon.AddTooltip(disabled, L["Disabled"])
                else
                    disabled:SetImage("Interface\\Buttons\\UI-CheckBox-Check")
                    disabled:SetImageSize(24, 24)
                    addon.AddTooltip(disabled, L["Enabled"])
                end
                disabled:SetDisabled(false)
                switch_desc:SetText(addon:printCondition(rotation_settings[rotid].switch, specID))
            end
            switch_sub:AddChild(switch_desc)

            addon:configure_frame(switch_sub)
            switch_sub:ResumeLayout()
            switch_sub:DoLayout()
        end

        update_switch()
        local function update_autoswitch()
            update_switch()
            addon:UpdateAutoSwitch()
            addon:SwitchRotation()
        end

        disabled:SetCallback("OnClick", function()
            rotation_settings[rotid].disabled = not rotation_settings[rotid].disabled
            update_autoswitch()
        end)

        if rotation_settings[rotid] == nil then
            edit_button:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-FriendsList-Large-Disabled")
            edit_button:SetDisabled(true)
        else
            edit_button:SetImage("Interface\\FriendsFrame\\UI-FriendsList-Large-Up")
            edit_button:SetDisabled(false)
        end
        edit_button:SetCallback("OnClick", function()
            if rotation_settings[rotid].switch == nil then
                rotation_settings[rotid].switch = { type = nil }
            end
            addon:EditCondition(0, spec, rotation_settings[rotid].switch, update_autoswitch)
        end)
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
                local rv
                if rot.disabled ~= nil and rot.disabled == true then
                    rv = color.GRAY
                elseif rot.type == nil or not addon:validateCondition(rot.conditions, specID) then
                    rv = color.RED
                elseif rot.type ~= "none" and rot.action == nil then
                    rv = color.RED
                else
                    rv = ""
                end
                rv = rv .. tostring(idx)

                if rot.use_name == nil then
                    rot.use_name = (rot.name ~= nil and string.len(rot.name) > 0)
                end

                if rot.use_name then
                    if (rot.name ~= nil and string.len(rot.name)) then
                        rv = rv .. " - " .. rot.name
                    end
                elseif rot.type == "none" then
                    rv = rv .. " - " .. L["No Action"]
                else
                    if rot.action ~= nil then
                        if rot.type == BOOKTYPE_SPELL or rot.type == BOOKTYPE_PET or rot.type == "any" then
                            local spell = SpellData:SpellName(rot.action, not rot.ranked)
                            if spell then
                                rv = rv .. " - " .. spell
                            end
                        elseif rot.type == "item" then
                            if type(rot.action) == "string" then
                                local itemset
                                if addon.db.profile.itemsets[rot.action] ~= nil then
                                    itemset = addon.db.profile.itemsets[rot.action]
                                elseif addon.db.global.itemsets[rot.action] ~= nil then
                                    itemset = addon.db.global.itemsets[rot.action]
                                end
                                if itemset ~= nil then
                                    rv = rv .. " - " .. itemset.name
                                end
                            elseif #rot.action > 0 then
                                local item = rot.action[1]
                                if (type(item) == "number") then
                                    item = GetItemInfo(item) or item
                                end
                                if #rot.action > 1 then
                                    rv = rv .. " - " .. string.format(L["%s or %d others"], item, #rot.action-1)
                                else
                                    rv = rv .. " - " .. item
                                end
                            end
                        end
                    end
                end
                rv = rv .. color.RESET

                return rv
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
    local rotation_settings = addon.db.profile.rotations

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

create_class_options = function (frame, classID)
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
        tabs:SetLayout("Fill")

        tabs:SetCallback("OnGroupSelected", function(_, _, val)
            create_spec_options(tabs, val, (val == addon.currentSpec) and addon.currentRotation or DEFAULT)
        end)
        frame.frame:SetScript("OnShow", function()
            tabs:SelectTab(addon.currentSpec)
        end)

        frame:AddChild(tabs)
    elseif (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT >= 2) then
        local tabs = AceGUI:Create("TabGroup")
        addon.specTab = tabs

        local spec_tabs = {}
        for i=1,GetNumTalentGroups() do
            table.insert(spec_tabs, {
                value = i,
                text = addon.db.char.specs[i] or tostring(i)
            })
        end
        if currentSpec == nil then
            currentSpec = addon:GetSpecialization()
        end

        tabs:SetTabs(spec_tabs)
        tabs:SetLayout("Fill")

        tabs:SetCallback("OnGroupSelected", function(_, _, val)
            create_spec_options(tabs, val, (val == addon.currentSpec) and addon.currentRotation or DEFAULT)
        end)
        frame.frame:SetScript("OnShow", function()
            tabs:SelectTab(addon.currentSpec)
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

function addon:SetupOptions()
    if self.optionsConfigured then
        return
    end
    self.optionsConfigured = true

    self.optionsFrames = {}

    self.optionsFrames.General = AceGUI:Create("BlizOptionsGroup")
    self.optionsFrames.General:SetName(addon.pretty_name)
    self.optionsFrames.General:SetUserData("appName", addon.name)
    self.optionsFrames.General:SetLayout("Fill")
    self.optionsFrames.General:SetTitle(addon.pretty_name)
    create_primary_options(self.optionsFrames.General)
    InterfaceOptions_AddCategory(self.optionsFrames.General.frame)

    self.optionsFrames.Rotation = AceGUI:Create("BlizOptionsGroup")
    self.optionsFrames.Rotation:SetName(L["Rotations"], self.optionsFrames.General.frame.name)
    self.optionsFrames.Rotation:SetUserData("appName", addon.name .. "Rotations")
    self.optionsFrames.Rotation:SetLayout("Fill")
    local localized, _, classID = UnitClass("player")
    self.optionsFrames.Rotation:SetTitle(addon.pretty_name .. " - " .. localized)
    create_class_options(self.optionsFrames.Rotation, classID)
    InterfaceOptions_AddCategory(self.optionsFrames.Rotation.frame)

    self.optionsFrames.Conditions = AceGUI:Create("BlizOptionsGroup")
    self.optionsFrames.Conditions:SetName(L["Conditions"], self.optionsFrames.General.frame.name)
    self.optionsFrames.Conditions:SetUserData("appName", addon.name .. "Conditions")
    self.optionsFrames.Conditions:SetLayout("Fill")
    -- self.optionsFrames.Conditions:SetTitle(addon.pretty_name .. " - " .. L["Conditions"])
    addon:create_condition_list(self.optionsFrames.Conditions)
    InterfaceOptions_AddCategory(self.optionsFrames.Conditions.frame)

    self.optionsFrames.Effects = AceGUI:Create("BlizOptionsGroup")
    self.optionsFrames.Effects:SetName(L["Effects"], self.optionsFrames.General.frame.name)
    self.optionsFrames.Effects:SetUserData("appName", addon.name .. "Effects")
    self.optionsFrames.Effects:SetLayout("Fill")
    self.optionsFrames.Effects:SetTitle(addon.pretty_name .. " - " .. L["Effects"])
    addon:create_effect_list(self.optionsFrames.Effects)
    InterfaceOptions_AddCategory(self.optionsFrames.Effects.frame)

    self.optionsFrames.ItemSets = AceGUI:Create("BlizOptionsGroup")
    self.optionsFrames.ItemSets:SetName(L["Item Sets"], self.optionsFrames.General.frame.name)
    self.optionsFrames.ItemSets:SetUserData("appName", addon.name .. "ItemSets")
    self.optionsFrames.ItemSets:SetLayout("Fill")
    -- self.optionsFrames.ItemSets:SetTitle(addon.pretty_name .. " - " .. L["Item Sets"])
    addon:create_itemset_list(self.optionsFrames.ItemSets)
    InterfaceOptions_AddCategory(self.optionsFrames.ItemSets.frame)

    self.optionsFrames.Announces = AceGUI:Create("BlizOptionsGroup")
    self.optionsFrames.Announces:SetName(L["Announces"], self.optionsFrames.General.frame.name)
    self.optionsFrames.Announces:SetUserData("appName", addon.name .. "Announces")
    self.optionsFrames.Announces:SetLayout("Fill")
    self.optionsFrames.Announces:SetTitle(addon.pretty_name .. " - " .. L["Announces"])
    addon:create_announce_list(self.optionsFrames.Announces)
    InterfaceOptions_AddCategory(self.optionsFrames.Announces.frame)

    self.optionsFrames.module = {}
    for _, m in addon:IterateModules() do
        local f = m["SetupOptions"]
        if f then
            f(m, function(appName, name)
                self.optionsFrames.module[name] = AceConfigDialog:AddToBlizOptions(appName, name, self.optionsFrames.General.frame.name)
            end)
        end
    end

    local options = AceDBOptions:GetOptionsTable(self.db)
    local prev_setprofile = options.handler.SetProfile
    options.handler["SetProfile"] = function(obj, info, value)
        addon:DisableRotation()
        prev_setprofile(obj, info, value)
        -- create_class_options(self.optionsFrames.Rotation, classID)
        addon:create_itemset_list(self.optionsFrames.ItemSets)
        addon:create_announce_list(self.optionsFrames.Announces)
        addon:EnableRotation()
    end
    AceConfig:RegisterOptionsTable(addon.name .. "Profiles", options)
    self.optionsFrames.Profiles = AceConfigDialog:AddToBlizOptions(addon.name .. "Profiles", L["Profiles"], self.optionsFrames.General.frame.name)

    local about = AboutPanel:AboutOptionsTable(addon.name)
    about.order = -1
    AceConfig:RegisterOptionsTable(addon.name .. "About", about)
    self.optionsFrames.About = AceConfigDialog:AddToBlizOptions(addon.name .. "About", L["About"], self.optionsFrames.General.frame.name)
end