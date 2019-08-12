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
    group:SetUserData("table", { columns = { 35, 100, 150, 1, 40 } })
    frame:AddChild(group)

    local updateDisabled

    local name2idx = {}
    for k, v in pairs(effects) do
        if v.name ~= nil then
            name2idx[v.name] = k
        end
    end

    local icons = {}
    for k, v in pairs(effects) do
        local row = group

        local icon = AceGUI:Create("Icon")
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
        table.insert(icons, icon.frame)
        row:AddChild(icon)

        local type = AceGUI:Create("Dropdown")
        type:SetLabel(L["Type"])
        type:SetList({
            texture = L["Texture"],
            pixel = L["Pixel"],
            autocast = L["Auto Cast"],
            blizzard = L["Glow"],
        })
        type:SetValue(v.type or "texture")
        type:SetCallback("OnValueChanged", function(widget, event, val)
            v.type = val
            for _, frame in pairs(icons) do
                addon:StopCustomGlow(frame)
            end
            addon:create_effect_list(frame)
        end)
        row:AddChild(type)

        local name = AceGUI:Create("EditBox")
        name:SetLabel(NAME)
        name:SetText(v.name)
        name:SetFullWidth(true)
        name:DisableButton(v.name == nil or v.name == "" or name2idx[v.name] ~= nil)
        name:SetCallback("OnTextChanged", function(widget, event, val)
            name:DisableButton(val == "" or name2idx[val] ~= nil)
        end)
        name:SetCallback("OnEnterPressed", function(widget, event, val)
            v.name = val
            updateDisabled()
        end)
        row:AddChild(name)

        local rowgroup = AceGUI:Create("SimpleGroup")

        if v.type == "texture" then
            local texture = AceGUI:Create("EditBox")
            texture:SetLabel(L["Texture"])
            texture:SetText(v.texture)
            texture:SetFullWidth(true)
            texture:SetCallback("OnEnterPressed", function(widget, event, val)
                icon:SetImage(val)
                v.texture = val
                addon:RemoveAllCurrentGlows()
                updateDisabled()
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
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency or 0.125)
            frequency:SetSliderValues(0.0, 1.5, 0.05)
            frequency:SetFullWidth(true)
            frequency:SetCallback("OnValueChanged", function(widget, event, val)
                v.frequency = val
                addon:RemoveAllCurrentGlows()
                addon:ApplyCustomGlow(v, icon.frame)
            end)
            rowgroup:AddChild(frequency)
        end

        row:AddChild(rowgroup)

        local delete = AceGUI:Create("Button")
        delete:SetText("X")
        delete:SetWidth(40)
        delete:SetCallback("OnClick", function(widget, ewvent, ...)
            table.remove(effects, k)
            addon:RemoveAllCurrentGlows()
            for _, frame in pairs(icons) do
                addon:StopCustomGlow(frame)
            end
            addon:create_effect_list(frame)
        end)
        row:AddChild(delete)
    end

    local addnew = AceGUI:Create("Button")
    addnew:SetText("Add New")
    addnew:SetCallback("OnClick", function(widget, ewvent, ...)
        table.insert(effects, { type = "texture", name = nil, texture = nil })
        for _, frame in pairs(icons) do
            addon:StopCustomGlow(frame)
        end
        addon:create_effect_list(frame)
    end)
    addnew:SetUserData("cell", { colspan = 4 })
    group:AddChild(addnew)

    updateDisabled = function()
        local tblsz = #effects
        addnew:SetDisabled(effects[tblsz].name == nil or effects[tblsz].name == "" or
                (effects[tblsz].type == "texture" and (effects[tblsz].texture == nil or effects[tblsz].texture == "")))
    end
    updateDisabled()

    frame:ResumeLayout()
    frame:DoLayout()
end

