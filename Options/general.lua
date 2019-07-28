local addon_name, addon = ...

local module = addon:NewModule("Options", "AceConsole-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local LibAboutPanel = LibStub("LibAboutPanel")
local DBIcon = LibStub("LibDBIcon-1.0")

local assert, error, hooksecurefunc, pairs, base64enc, base64dec, date, color
    = assert, error, hooksecurefunc, pairs, base64enc, base64dec, date, color

local serpent = serpent

local HideOnEscape = addon.HideOnEscape

local options = {
    name = addon.pretty_name,
    handler = addon,
    type = "group",
    args = {
        main = {
            type = "group",
            name = GENERAL,
            width = "full",
            args = {
                enable = {
                    order = 10,
                    type = "toggle",
                    name = ENABLE,
                    desc = L["Enable Rotation Master"],
                    order = 10,
                    width = 1.5,
                    get  = function(info) return addon.db.profile[info[#info]] end,
                    set = function(info, val)
                        addon.db.profile[info[#info]] = val
                        if val then
                            addon:OnEnable()
                            addon:EnableRotation()
                        else
                            addon:DisableRotation()
                            addon:UnregisterAllEvents()
                        end
                    end,
                },
                spacer1 = {
                    order = 15,
                    type = "description",
                    name = "",
                    width = 0.3
                },
                poll = {
                    order = 20,
                    name = L["Polling Interval (seconds)"],
                    type = "range",
                    min = 0.05,
                    max = 1.0,
                    step = 0.05,
                    width = 1.5,
                    get  = function(info) return addon.db.profile[info[#info]] end,
                    set = function(info, val)
                        addon.db.profile[info[#info]] = val
                        if addon.rotationTimer then
                            addon:DisableRotationTimer()
                            addon:EnableRotationTimer()
                        end
                    end,
                },
                minimap = {
                    order = 30,
                    type = "toggle",
                    name = L["Minimap Icon"],
                    width = 1.5,
                    get  = function(info) return not addon.db.profile[info[#info]].hide end,
                    set = function(info, val)
			    addon.db.profile[info[#info]].hide = not val
			    if val then
				    DBIcon:Show("RotationMaster")
			    else
				    DBIcon:Hide("RotationMaster")
			    end

		    end,
                },
                overlay_header = {
                    order = 50,
                    type = "header",
                    name = L["Overlay Options"],
                },
                overlay_icon = {
                    order = 60,
                    name = "",
                    type = "execute",
                    width = 0.3,
                    image = function(info)
                        local overlay = addon.db.profile.overlay

                        for k,v in pairs(addon.db.global.textures) do
                            if v.name == overlay then
                                return v.texture
                            end
                        end
                        return nil
                    end
                },
                overlay = {
                    order = 70,
                    name = L["Overlay Texture"],
                    type = "select",
                    width = 1.2,
                    values = function(item)
                        local vals = {}
                        for k,v in pairs(addon.db.global.textures) do
                            vals[v.name] = v.name
                        end
                        return vals
                    end,
                    get  = function(info) return addon.db.profile[info[#info]] end,
                    set = function(info, val)
                        addon.db.profile[info[#info]] = val
                        AceConfigRegistry:NotifyChange(addon.name)
                        addon:RemoveAllCurrentGlows()
                    end,
                },
                spacer2 = {
                    order = 75,
                    type = "description",
                    name = "",
                    width = 0.3
                },
                magnification = {
                    order = 80,
                    name = L["Magnification"],
                    type = "range",
                    min = 0.1,
                    max = 2.0,
                    step = 0.1,
                    width = 1.5,
                    get  = function(info) return addon.db.profile[info[#info]] end,
                    set = function(info, val)
                        addon.db.profile[info[#info]] = val
                        addon:RemoveAllCurrentGlows()
                    end,
                },
                spacer3 = {
                    order = 85,
                    type = "description",
                    name = "",
                    width = "full"
                },
                spacer4 = {
                    order = 86,
                    type = "description",
                    name = "",
                    width = 0.3
                },
                color = {
                    order = 90,
                    name = L["Highlight Color"],
                    type = "color",
                    width = 1.5,
                    hasAlpha = true,
                    get = function(info) return
                        addon.db.profile[info[#info]].r, addon.db.profile[info[#info]].g,
                        addon.db.profile[info[#info]].b, addon.db.profile[info[#info]].a
                    end,
                    set = function(info, r, g, b, a)
                        addon.db.profile[info[#info]] = { r = r, g = g, b = b, a = a }
                        addon:RemoveAllCurrentGlows()
                    end
                },
                setpoint = {
                    order = 94,
                    name = L["Position"],
                    type = "select",
                    style = "dropdown",
                    width = 1.0,
                    values = {
                        CENTER = "Center",
                        TOPLEFT = "Top Left",
                        TOPRIGHT = "Top Right",
                        BOTTOMLEFT = "Bottom Left",
                        BOTTOMRIGHT = "Bottom Right",
                        TOP = "Top Center",
                        BOTTOM = "Bottom Center",
                        LEFT = "Left Center",
                        RIGHT = "Right Center",
                    },
                    get  = function(info) return addon.db.profile[info[#info]] end,
                    set = function(info, val)
                        addon.db.profile[info[#info]] = val
                        addon.db.profile.xoffs = 0
                        addon.db.profile.yoffs = 0
                        addon:RemoveAllCurrentGlows()
                    end,
                },
                reset_offs = {
                    order = 95,
                    name = "o",
                    type = "execute",
                    width = 0.1,
                    func = function(info)
                        addon.db.profile.xoffs = 0
                        addon.db.profile.yoffs = 0
                        addon:RemoveAllCurrentGlows()
                    end
                },
                xoffs_left = {
                    order = 96,
                    name = "<",
                    type = "execute",
                    width = 0.1,
                    func = function(info)
                        addon.db.profile.xoffs = (addon.db.profile.xoffs or 0) - 1
                        addon:RemoveAllCurrentGlows()
                    end
                },
                xoffs_right = {
                    order = 97,
                    name = ">",
                    type = "execute",
                    width = 0.1,
                    func = function(info)
                        addon.db.profile.xoffs = (addon.db.profile.xoffs or 0) + 1
                        addon:RemoveAllCurrentGlows()
                    end
                },
                yoffs_up = {
                    order = 98,
                    name = "^",
                    type = "execute",
                    width = 0.1,
                    func = function(info)
                        addon.db.profile.yoffs = (addon.db.profile.yoffs or 0) + 1
                        addon:RemoveAllCurrentGlows()
                    end
                },
                yoffs_down = {
                    order = 99,
                    name = "v",
                    type = "execute",
                    width = 0.1,
                    func = function(info)
                        addon.db.profile.yoffs = (addon.db.profile.yoffs or 0) - 1
                        addon:RemoveAllCurrentGlows()
                    end
                },
                debugging_header = {
                    order = 100,
                    type = "header",
                    name = L["Debugging Options"],
                },
                debug = {
                    order = 110,
                    type = "toggle",
                    name = L["Debug Logging"],
                    width = 1.5,
                    get  = function(info) return addon.db.profile[info[#info]] end,
                    set = function(info, val) addon.db.profile[info[#info]] = val end,
                },
                spacer5 = {
                    order = 115,
                    type = "description",
                    name = "",
                    width = 0.3
                },
                disable_autoswitch = {
                    order = 120,
                    type = "toggle",
                    name = L["Disable Auto-Switching"],
                    width = 1.5,
                    get  = function(info) return addon.db.profile[info[#info]] end,
                    set = function(info, val) addon.db.profile[info[#info]] = val end,
                },
                verbose = {
                    order = 130,
                    type = "toggle",
                    name = L["Verbose Debug Logging"],
                    width = 1.5,
                    disabled = function(info) return addon.db.profile.debug == false end,
                    get  = function(info) return addon.db.profile[info[#info]] end,
                    set = function(info, val) addon.db.profile[info[#info]] = val end,
                },
                spacer6 = {
                    order = 135,
                    type = "description",
                    name = "",
                    width = 0.3
                },
                live_config_update = {
                    order = 140,
                    name = L["Live Status Update Frequency (seconds)"],
                    desc = L["This is specifically how often the configuration pane will receive updates about live status.  Too frequently could make your configuration pane unusable.  0 = Disabled."],
                    type = "range",
                    min = 0,
                    max = 60.0,
                    step = 1.0,
                    width = 1.5,
                    get  = function(info) return addon.db.profile[info[#info]] end,
                    set = function(info, val) addon.db.profile[info[#info]] = val end,
                },
            }
        }
    }
}

local function HandleDelete(spec, rotation)
    local rotation_settings = addon.db.profile.rotations

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
                AceConfigRegistry:NotifyChange(addon.name .. "Class")
            end
        end,
        showAlert = 1,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1
    }
    StaticPopup_Show("ROTATIONMASTER_DELETE_ROTATION")
end

local function ImportExport(spec, rotation)
    local rotation_settings = addon.db.profile.rotations
    local original_name
    if rotation ~= DEFAULT and rotation_settings[spec][rotation] ~= nil then
        original_name = rotation_settings[spec][rotation].name
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle(L["Import/Export Rotation"])
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        AceConfigRegistry:NotifyChange(addon.name .. "Class")
    end)
    frame:SetLayout("List")
    HideOnEscape(frame)

    frame:PauseLayout()

    local desc = AceGUI:Create("Label")
    desc:SetText(L["Copy and paste this text share your profile with others, or import someone else's."])
    desc:SetFullWidth(true)
    frame:AddChild(desc)

    local import = AceGUI:Create("Button")
    import:SetText("Import")
    import:SetDisabled(true)

    local editbox = AceGUI:Create("MultiLineEditBox")
    editbox:SetLabel("")
    editbox:SetFullHeight(true)
    editbox:SetFullWidth(true)
    editbox:SetNumLines(27)
    editbox:DisableButton(true)
    editbox:SetFocus(true)
    if (rotation_settings[spec][rotation] ~= nil) then
        editbox:SetText(base64enc(serpent.dump(rotation_settings[spec][rotation])))
    end
    editbox:SetCallback("OnTextChanged", function (widget, event, text)
        frame:SetStatusText(string.len(text) .. " " .. L["bytes"])
        import:SetDisabled(false)
    end)
    frame:AddChild(editbox)

    frame:SetStatusText(string.len(editbox:GetText()) .. " " .. L["bytes"])
    editbox:HighlightText(0, string.len(editbox:GetText()))

    import:SetCallback("OnClick", function(wiget, event)
        ok, res = serpent.load(base64dec(editbox:GetText()))
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
                    for k,v in pairs(rotation_settings[spec]) do
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
        end
    end)
    frame:AddChild(import)

    frame:ResumeLayout()
    frame:DoLayout()
end

local function create_rotation_options(spec, rotation, order)
    local rotation_settings = addon.db.profile.rotations

    local isnew = (rotation ~= DEFAULT and (rotation_settings[spec] == nil or rotation_settings[spec][rotation] == nil))

    return {
        order = order,
        name = function(info)
            if (rotation == DEFAULT) then
                return DEFAULT
            elseif isnew then
                return NEW
            else
                return rotation_settings[spec][rotation].name;
            end
        end,

        type = "group",
        args = {
            name = {
                order = 10,
                name = NAME,
                disabled = (rotation == DEFAULT),
                type = "input",
                width = 1.25,
                get = function(info)
                    if (rotation == DEFAULT) then
                        return DEFAULT;
                    elseif isnew then
                        return "";
                    else
                        return rotation_settings[spec][rotation].name;
                    end
                end,
                validate = function(info, text)
                    if rotation == DEFAULT or text == DEFAULT or text == NEW or text == "" then
                        return false
                    end

                    if rotation_settings ~= nil and rotation_settings[spec] ~= nil then
                        for key, value in pairs(rotation_settings[spec]) do
                            if value.name == text then
                                return key == rotation
                            end
                        end
                    end

                    return true
                end,
                set = function(info, val)
                    if rotation_settings[spec] == nil then
                        rotation_settings[spec] = {}
                    end

                    if rotation_settings[spec][rotation] == nil then
                        rotation_settings[spec][rotation] = { name = val }
                    else
                        rotation_settings[spec][rotation].name = val
                    end
                    AceConfigRegistry:NotifyChange(addon.name .. "Class")
                end
            },
            delete = {
                order = 11,
                name = DELETE,
                disabled = (rotation == DEFAULT or isnew),
                type = "execute",
                func = function(info) HandleDelete(spec, rotation) end
            },
            importexport = {
                order = 11,
                name = L["Import/Export"],
                type = "execute",
                func = function(info) ImportExport(spec, rotation) end
            },
            switch = {
                order = 12,
                name = L["Switch Condition"],
                type = "group",
                inline = true,
                args = {
                    default_desc = {
                        order = 1,
                        type = "description",
                        name = L["No other rotations match."],
                        hidden = (rotation ~= DEFAULT)
                    },
                    useless_desc = {
                        order = 2,
                        type = "description",
                        name = L["Manual switch only."],
                        hidden = function(info)
                            if (rotation == DEFAULT) then
                                return true
                            end
                            if rotation_settings[spec] ~= nil and rotation_settings[spec][rotation] ~= nil and rotation_settings[spec][rotation].switch ~= nil then
                                return addon:usefulSwitchCondition(rotation_settings[spec][rotation].switch)
                            else
                                return false
                            end
                        end
                    },
                    desc = {
                        order = 10,
                        type = "description",
                        width = "full",
                        hidden = function(info)
                            if (rotation == DEFAULT) then
                                return true
                            end
                            if rotation_settings[spec] ~= nil and rotation_settings[spec][rotation] ~= nil and rotation_settings[spec][rotation].switch ~= nil then
                                return not addon:usefulSwitchCondition(rotation_settings[spec][rotation].switch)
                            else
                                return true
                            end
                        end,
                        name = function(info)
                            if rotation_settings[spec] ~= nil and rotation_settings[spec][rotation] ~= nil and rotation_settings[spec][rotation].switch ~= nil then
                                return addon:printSwitchCondition(rotation_settings[spec][rotation].switch, spec)
                            else
                                return ""
                            end
                        end
                    },
                    validated = {
                        order = 11,
                        type = "header",
                        width = "full",
                        name = color.RED .. L["THIS CONDITION DOES NOT VALIDATE"] .. color.RESET,
                        hidden = function(info)
                            if (rotation == DEFAULT) then
                                return true
                            end
                            if rotation_settings[spec] ~= nil and rotation_settings[spec][rotation] ~= nil and rotation_settings[spec][rotation].switch ~= nil then
                                return addon:validateSwitchCondition(rotation_settings[spec][rotation].switch, spec)
                            else
                                return true
                            end
                        end
                    },
                    edit_button = {
                        order = 12,
                        type = "execute",
                        name = EDIT,
                        disabled = isnew,
                        hidden = (rotation == DEFAULT),
                        func = function(info)
                            if (rotation_settings[spec][rotation].switch == nil) then
                                rotation_settings[spec][rotation].switch = { type = nil }
                            end
                            addon:EditSwitchCondition(spec, rotation_settings[spec][rotation].switch)
                        end
                    },
                }
            },
            validated = {
                order = 13,
                type = "header",
                width = "full",
                name = color.RED .. L["THIS ROTATION WILL NOT BE USED AS IT IS INCOMPLETE"] .. color.RESET,
                hidden = function(info)
                    return rotation_settings[spec] ~= nil and rotation_settings[spec][rotation] ~= nil and
                            addon:rotationValidConditions(rotation_settings[spec][rotation])
                end
            },
            cooldowns = {
                order = 14,
                name = L["Cooldowns"],
                type = "group",
                -- inline = true,
                args = addon:get_cooldown_list(spec, rotation)
            },
            rotation = {
                order = 15,
                name = L["Rotation"],
                type = "group",
                -- inline = true,
                args = addon:get_rotation_list(spec, rotation)
            },
        }
    }
end

local function create_class_options()
    local rotation_settings = addon.db.profile.rotations

    local spec_tabs = {}
    local localized, english, classID = UnitClass("player")
    for j=1,GetNumSpecializationsForClassID(classID) do
        local specID, specName = GetSpecializationInfoForClassID(classID, j)

        local rotation_args = {}
        local idx = 10;
        rotation_args[DEFAULT] = create_rotation_options(specID, DEFAULT, idx)
        if (rotation_settings ~= nil and rotation_settings[specID] ~= nil) then
            local groupsOrder = {}
            for id, rot in pairs(rotation_settings[specID]) do
                if id ~= DEFAULT then
                    table.insert(groupsOrder, id)
                end
            end
            table.sort(groupsOrder, function (lhs, rhs) return rotation_settings[specID][lhs].name < rotation_settings[specID][rhs].name end)
            for k,v in pairs(groupsOrder) do
                idx = idx + 1
                rotation_args[v] = create_rotation_options(specID, v, idx)
            end
        end
        local newid = addon:uuid()
        rotation_args[newid] = create_rotation_options(specID, newid, idx + 1)

        spec_tabs[tostring(specID)] = {
            name = specName,
            order = 10 + j,
            width = "full",
            type = "group",
            childGroups = "select",
            args = rotation_args
        }
    end

    return {
        name = L["Rotations"] .. " - " .. localized,
        type = "group",
        childGroups = "tab",
        args = spec_tabs,
    }
end

local function create_texture_list(frame)
    local textures = addon.db.global.textures
    frame:ReleaseChildren()
    frame:PauseLayout()

    local group = AceGUI:Create("ScrollFrame")
    group:SetFullWidth(true)
    group:SetFullHeight(true)
    -- group:SetLayout("Flow")
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { 35, 1, 1, 40 } })
    frame:AddChild(group)

    local updateDisabled

    local label1 = AceGUI:Create("Label")
    label1:SetText("")
    group:AddChild(label1)

    local label2 = AceGUI:Create("Label")
    label2:SetText(NAME)
    group:AddChild(label2)

    local label3 = AceGUI:Create("Label")
    label3:SetText(L["Texture"])
    group:AddChild(label3)

    local label4 = AceGUI:Create("Label")
    label4:SetText("")
    group:AddChild(label4)

    for k,v in pairs(textures) do
        local row = group

        local icon = AceGUI:Create("Icon")
        icon:SetWidth(44)
        icon:SetHeight(44)
        icon:SetImageSize(36, 36)
        icon:SetImage(v.texture)
        row:AddChild(icon)

        local name = AceGUI:Create("EditBox")
        name:SetText(v.name)
        name:SetFullWidth(true)
        name:SetCallback("OnEnterPressed", function (widget, event, val)
            v.name = val
            updateDisabled()
        end)
        row:AddChild(name)

        local texture = AceGUI:Create("EditBox")
        texture:SetText(v.texture)
        texture:SetFullWidth(true)
        texture:SetCallback("OnEnterPressed", function (widget, event, val)
            icon:SetImage(val)
            v.texture = val
            updateDisabled()
        end)
        group:AddChild(texture)

        local delete = AceGUI:Create("Button")
        delete:SetText("X")
        delete:SetWidth(40)
        delete:SetCallback("OnClick", function (widget, ewvent, ...)
            table.remove(textures, k)
            create_texture_list(frame)
        end)
        row:AddChild(delete)
    end

    local addnew = AceGUI:Create("Button")
    addnew:SetText("Add New")
    addnew:SetCallback("OnClick", function (widget, ewvent, ...)
        table.insert(textures, { name = nil, texture = nil })
        create_texture_list(frame)
    end)
    addnew:SetUserData("cell", { colspan = 4 })
    group:AddChild(addnew)

    updateDisabled = function()
        local tblsz = #textures
        addnew:SetDisabled(textures[tblsz].name == nil or textures[tblsz].name == "" or
                           textures[tblsz].texture == nil or textures[tblsz].texture == "")
    end
    updateDisabled()

    frame:ResumeLayout()
    frame:DoLayout()
end

function module:OnInitialize()
    self.db = addon.db

    self.options = options
    self.options.args.profiles = AceDBOptions:GetOptionsTable(self.db)
    -- self.options_slashcmd = options_slashcmd

    AceConfig:RegisterOptionsTable(addon.name, options)
    AceConfig:RegisterOptionsTable(addon.name .. "Class", create_class_options)
    -- AceConfig:RegisterOptionsTable(addon.name .. "RotationMaster", options_slashcmd, { "rotationmaster", "rm" })

    hooksecurefunc("InterfaceCategoryList_Update", function() self:SetupOptions() end)
end

function module:SetupOptions()
    if self.didSetup then return end
    self.didSetup = true

    self.optionsFrame = AceConfigDialog:AddToBlizOptions(addon.name, addon.pretty_name, nil, "main")

    local textures = AceGUI:Create("BlizOptionsGroup")
    textures:SetName(L["Textures"], addon.pretty_name)
    textures:SetLayout("Flow")
    create_texture_list(textures)

    InterfaceOptions_AddCategory(textures.frame)

    AceConfigDialog:AddToBlizOptions(addon.name .. "Class", L["Rotations"], addon.pretty_name)

    for name, module in addon:IterateModules() do
        local f = module["SetupOptions"]
        if f then
            f(module, function(appName, name) AceConfigDialog:AddToBlizOptions(appName, name, addon.name) end)
        end
    end

    self.Profile = AceConfigDialog:AddToBlizOptions(addon.name, L["Profiles"], addon.pretty_name, "profiles")
    self.About = LibAboutPanel.new(addon.pretty_name, addon.name)
end
