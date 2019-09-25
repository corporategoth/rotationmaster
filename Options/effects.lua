local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local table, pairs = table, pairs

function addon:create_effect_list(frame)
    local effects = self.db.global.effects
    frame:ReleaseChildren()
    frame:PauseLayout()

    local group = AceGUI:Create("ScrollFrame")

    group:SetFullWidth(true)
    group:SetFullHeight(true)
    -- group:SetLayout("Flow")
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { 35, 100, 150, 1, 24 } })

    local name2idx = {}
    for k, v in pairs(effects) do
        if v.name ~= nil then
            name2idx[v.name] = k
        end
    end

    local new_type = AceGUI:Create("Dropdown")

    local icons = {}
    for idx, v in ipairs(effects) do
        local row = group

        local icon = AceGUI:Create("Icon")
        table.insert(icons, icon.frame)
        icon:SetImageSize(36, 36)
        if v.type == "texture" then
            icon:SetWidth(44)
            icon:SetHeight(44)
            icon:SetImage(v.texture)
        else
            icon:SetWidth(36)
            icon:SetHeight(36)
            addon:ApplyCustomGlow(v, icon.frame)
        end
        row:AddChild(icon)

        local type = AceGUI:Create("Dropdown")
        type:SetLabel(L["Type"])
        type:SetCallback("OnValueChanged", function(widget, event, val)
            v.type = val
            for _, frame in pairs(icons) do
                addon:StopCustomGlow(frame)
            end
            addon:create_effect_list(frame)
        end)
        type.configure = function()
            type:SetList({
                texture = L["Texture"],
                pixel = L["Pixel"],
                autocast = L["Auto Cast"],
                blizzard = L["Glow"],
            })
            type:SetValue(v.type or "texture")
        end
        row:AddChild(type)

        local name = AceGUI:Create("EditBox")
        name:SetFullWidth(true)
        name:SetLabel(NAME)
        name:SetText(v.name)
        name:DisableButton(v.name == nil or v.name == "" or name2idx[v.name] ~= nil)
        name:SetCallback("OnTextChanged", function(widget, event, val)
            name:DisableButton(val == "" or name2idx[val] ~= nil)

        end)
        name:SetCallback("OnEnterPressed", function(widget, event, val)
            v.name = val
            new_type:SetDisabled(val == "" and idx == #effects)
        end)
        row:AddChild(name)

        local rowgroup = AceGUI:Create("SimpleGroup")

        if v.type == "texture" then
            local texture = AceGUI:Create("EditBox")
            texture:SetFullWidth(true)
            texture:SetLabel(L["Texture"])
            texture:SetText(v.texture)
            texture:SetCallback("OnEnterPressed", function(widget, event, val)
                icon:SetImage(val)
                v.texture = val
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(texture)
        elseif v.type == "pixel" then
            rowgroup:SetLayout("Table")
            rowgroup:SetUserData("table", { columns = { 1, 1, 1, 1 } })

            local lines = AceGUI:Create("Slider")
            lines:SetLabel(L["Lines"])
            lines:SetValue(v.lines or 8)
            lines:SetSliderValues(1, 20, 1)
            lines:SetCallback("OnValueChanged", function(widget, event, val)
                v.lines = val
                addon:RemoveAllCurrentGlows()
                addon:ApplyCustomGlow(v, icon.frame)
            end)
            rowgroup:AddChild(lines)

            local frequency = AceGUI:Create("Slider")
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency or 0.25)
            frequency:SetSliderValues(-1.5, 1.5, 0.05)
            frequency:SetCallback("OnValueChanged", function(widget, event, val)
                v.frequency = val
                addon:RemoveAllCurrentGlows()
                addon:ApplyCustomGlow(v, icon.frame)
            end)
            rowgroup:AddChild(frequency)

            local length = AceGUI:Create("Slider")
            length:SetLabel(L["Length"])
            length:SetValue(v.length or 2)
            length:SetSliderValues(1, 20, 1)
            length:SetCallback("OnValueChanged", function(widget, event, val)
                v.length = val
                addon:RemoveAllCurrentGlows()
                addon:ApplyCustomGlow(v, icon.frame)
            end)
            rowgroup:AddChild(length)

            local thickness = AceGUI:Create("Slider")
            thickness:SetLabel(L["Thickness"])
            thickness:SetValue(v.thickness or 2)
            thickness:SetSliderValues(1, 5, 1)
            thickness:SetCallback("OnValueChanged", function(widget, event, val)
                v.thickness = val
                addon:RemoveAllCurrentGlows()
                addon:ApplyCustomGlow(v, icon.frame)
            end)
            rowgroup:AddChild(thickness)
        elseif v.type == "autocast" then
            rowgroup:SetLayout("Table")
            rowgroup:SetUserData("table", { columns = { 1, 1, 1 } })

            local particles = AceGUI:Create("Slider")
            particles:SetLabel(L["Particles"])
            particles:SetValue(v.particles or 4)
            particles:SetSliderValues(1, 4, 1)
            particles:SetCallback("OnValueChanged", function(widget, event, val)
                v.particles = val
                addon:RemoveAllCurrentGlows()
                addon:ApplyCustomGlow(v, icon.frame)
            end)
            rowgroup:AddChild(particles)

            local frequency = AceGUI:Create("Slider")
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency or 0.125)
            frequency:SetSliderValues(-1.5, 1.5, 0.05)
            frequency:SetCallback("OnValueChanged", function(widget, event, val)
                v.frequency = val
                addon:RemoveAllCurrentGlows()
                addon:ApplyCustomGlow(v, icon.frame)
            end)
            rowgroup:AddChild(frequency)

            local scale = AceGUI:Create("Slider")
            scale:SetLabel(L["Scale"])
            scale:SetValue(v.scale or 1.0)
            scale:SetSliderValues(0.25, 5, 0.25)
            scale:SetCallback("OnValueChanged", function(widget, event, val)
                v.scale = val
                addon:RemoveAllCurrentGlows()
                addon:ApplyCustomGlow(v, icon.frame)
            end)
            rowgroup:AddChild(scale)

        elseif v.type == "blizzard" then
            local frequency = AceGUI:Create("Slider")
            frequency:SetFullWidth(true)
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency or 0.125)
            frequency:SetSliderValues(0.0, 1.5, 0.05)
            frequency:SetCallback("OnValueChanged", function(widget, event, val)
                v.frequency = val
                addon:RemoveAllCurrentGlows()
                addon:ApplyCustomGlow(v, icon.frame)
            end)
            rowgroup:AddChild(frequency)
        end

        row:AddChild(rowgroup)

        local delete = AceGUI:Create("Icon")
        delete:SetImageSize(24, 24)
        delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        delete:SetCallback("OnClick", function(widget, ewvent, ...)
            table.remove(effects, idx)
            addon:RemoveAllCurrentGlows()
            for _, frame in pairs(icons) do
                addon:StopCustomGlow(frame)
            end
            addon:create_effect_list(frame)
        end)
        row:AddChild(delete)
    end

    local spacer = function(width)
        local rv = AceGUI:Create("Label")
        rv:SetRelativeWidth(width)
        return rv
    end

    local row = group

    row:AddChild(spacer(1))

    local name = AceGUI:Create("EditBox")

    new_type:SetLabel(L["Type"])
    new_type:SetDisabled(effects[#effects].name == nil or effects[#effects].name == "")
    new_type:SetCallback("OnValueChanged", function(widget, event, val)
        table.insert(effects, { type = val, name = nil, texture = nil })
        for _, frame in pairs(icons) do
            addon:StopCustomGlow(frame)
        end
        addon:create_effect_list(frame)
    end)
    new_type.configure = function()
        new_type:SetList({
            texture = L["Texture"],
            pixel = L["Pixel"],
            autocast = L["Auto Cast"],
            blizzard = L["Glow"],
        })
    end
    row:AddChild(new_type)

    name:SetFullWidth(true)
    name:SetLabel(NAME)
    name:SetDisabled(true)
    row:AddChild(name)

    row:AddChild(spacer(1))

    local delete = AceGUI:Create("Icon")
    delete:SetImageSize(24, 24)
    delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    delete:SetDisabled(true)
    row:AddChild(delete)

    frame:AddChild(group)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

