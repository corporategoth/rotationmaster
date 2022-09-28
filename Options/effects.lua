local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local AceGUI = LibStub("AceGUI-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")
local libc = LibStub:GetLibrary("LibCompress")

local table, pairs, ipairs = table, pairs, ipairs
local HideOnEscape = addon.HideOnEscape

local base64enc, base64dec, date, width_split = base64enc, base64dec, date, width_split

local function spacer(width)
    local rv = AceGUI:Create("Label")
    rv:SetWidth(width)
    return rv
end

local function create_sequence_list(frame, effect, update)
    frame:ReleaseChildren()
    frame:PauseLayout()

    if not effect.sequence then
        effect.sequence = {}
    end
    local sequence = effect.sequence
    if sequence then
        for idx,entry in ipairs(sequence) do
            local row = frame
            if effect.type == "dazzle" then
                local color_pick = AceGUI:Create("ColorPicker")
                color_pick:SetFullWidth(true)
                color_pick:SetColor(entry.r, entry.g, entry.b, entry.a)
                color_pick:SetLabel(L["Highlight Color"])
                color_pick:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
                    sequence[idx] = { r = r, g = g, b = b, a = a }
                    update()
                end)
                row:AddChild(color_pick)
            elseif effect.type == "animate" then
                local group = AceGUI:Create("SimpleGroup")
                group:SetFullWidth(true)
                group:SetLayout("Table")
                group:SetUserData("table", { columns = { 35, 1 } })

                local icon = AceGUI:Create("Icon")
                icon:SetImageSize(36, 36)
                icon:SetWidth(44)
                icon:SetHeight(44)
                -- icon:SetDisabled(true)
                icon:SetImage(entry)
                group:AddChild(icon)

                local texture = AceGUI:Create("EditBox")
                texture:SetFullWidth(true)
                texture:SetLabel(L["Texture"])
                texture:SetText(entry)
                texture:SetCallback("OnEnterPressed", function(_, _, val)
                    icon:SetImage(val)
                    sequence[idx] = val
                    update()
                end)
                group:AddChild(texture)

                row:AddChild(group)
            elseif effect.type == "pulse" then
                local magnification = AceGUI:Create("Slider")
                magnification:SetFullWidth(true)
                magnification:SetLabel(L["Magnification"])
                magnification:SetValue(entry)
                magnification:SetSliderValues(0.1, 2.0, 0.1)
                magnification:SetCallback("OnValueChanged", function(_, _, val)
                    sequence[idx] = val
                    update()
                end)
                row:AddChild(magnification)
            elseif effect.type == "custom" then
                local outergroup = AceGUI:Create("SimpleGroup")
                outergroup:SetFullWidth(true)
                outergroup:SetLayout("Table")
                outergroup:SetUserData("table", { columns = { 35, 1 } })

                local icon = AceGUI:Create("Icon")
                icon:SetWidth(36)
                icon:SetHeight(36)
                icon:SetDisabled(true)
                icon:SetCallback("OnRelease", function(self)
                    addon:HideGlow(self.frame, "effect")
                end)
                addon:Glow(icon.frame, "effect", { type = "texture", texture = entry.texture }, entry.color, entry.magnification, "CENTER", 0, 0, math.rad(entry.angle or 0))
                outergroup:AddChild(icon)

                local innergroup = AceGUI:Create("SimpleGroup")
                innergroup:SetFullWidth(true)
                innergroup:SetLayout("Table")
                innergroup:SetUserData("table", { columns = { 0.25, 0.25, 0.25, 0.25 } })

                local texture = AceGUI:Create("EditBox")
                texture:SetFullWidth(true)
                texture:SetLabel(L["Texture"])
                texture:SetText(entry.texture)
                texture:SetCallback("OnEnterPressed", function(_, _, val)
                    entry.texture = val
                    addon:Glow(icon.frame, "effect", { type = "texture", texture = entry.texture }, entry.color, entry.magnification, "CENTER", 0, 0, math.rad(entry.angle or 0))
                    update()
                end)
                texture:SetUserData("cell", { colspan = 3 })
                innergroup:AddChild(texture)

                local angle = AceGUI:Create("Slider")
                angle:SetFullWidth(true)
                angle:SetLabel(L["Angle"])
                angle:SetValue(entry.angle or 0)
                angle:SetSliderValues(0, 359, 1)
                angle:SetCallback("OnValueChanged", function(_, _, val)
                    entry.angle = val
                    addon:Glow(icon.frame, "effect", { type = "texture", texture = entry.texture }, entry.color, entry.magnification, "CENTER", 0, 0, math.rad(entry.angle or 0))
                    update()
                end)
                innergroup:AddChild(angle)

                local color_pick = AceGUI:Create("ColorPicker")
                color_pick:SetFullWidth(true)
                color_pick:SetColor(entry.color.r, entry.color.g, entry.color.b, entry.color.a)
                color_pick:SetLabel(L["Highlight Color"])
                color_pick:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
                    entry.color = { r = r, g = g, b = b, a = a }
                    addon:Glow(icon.frame, "effect", { type = "texture", texture = entry.texture }, entry.color, entry.magnification, "CENTER", 0, 0, math.rad(entry.angle or 0))
                    update()
                end)
                color_pick:SetUserData("cell", { colspan = 2 })
                innergroup:AddChild(color_pick)

                local magnification = AceGUI:Create("Slider")
                magnification:SetFullWidth(true)
                magnification:SetLabel(L["Magnification"])
                magnification:SetValue(entry.magnification)
                magnification:SetSliderValues(0.1, 2.0, 0.1)
                magnification:SetCallback("OnValueChanged", function(_, _, val)
                    entry.magnification = val
                    addon:Glow(icon.frame, "effect", { type = "texture", texture = entry.texture }, entry.color, entry.magnification, "CENTER", 0, 0, math.rad(entry.angle or 0))
                    update()
                end)
                magnification:SetUserData("cell", { colspan = 2 })
                innergroup:AddChild(magnification)

                outergroup:AddChild(innergroup)
                row:AddChild(outergroup)
            end

            local movers = AceGUI:Create("SimpleGroup")
            movers:SetFullWidth(true)
            movers:SetLayout("Table")
            movers:SetUserData("table", { columns = { 24, 24, 24, 24, 24 } })

            local movetop = AceGUI:Create("Icon")
            movetop:SetImageSize(24, 24)
            if (idx == 1) then
                movetop:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-ChatIcon-ScrollHome-Disabled")
                movetop:SetDisabled(true)
            else
                movetop:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-ChatIcon-ScrollHome-Up")
                movetop:SetDisabled(false)
            end
            movetop:SetCallback("OnClick", function()
                local tmp = table.remove(sequence, idx)
                table.insert(sequence, 1, tmp)
                update()
                create_sequence_list(frame, effect, update)
            end)
            addon.AddTooltip(movetop, L["Move to Top"])
            movers:AddChild(movetop)

            local moveup = AceGUI:Create("Icon")
            moveup:SetImageSize(24, 24)
            if (idx == 1) then
                moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled")
                moveup:SetDisabled(true)
            else
                moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
                moveup:SetDisabled(false)
            end
            moveup:SetCallback("OnClick", function()
                local tmp = sequence[idx-1]
                sequence[idx-1] = sequence[idx]
                sequence[idx] = tmp
                update()
                create_sequence_list(frame, effect, update)
            end)
            addon.AddTooltip(moveup, L["Move Up"])
            movers:AddChild(moveup)

            local movedown = AceGUI:Create("Icon")
            movedown:SetImageSize(24, 24)
            if (idx == #sequence or sequence[idx+1] == "") then
                movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
                movedown:SetDisabled(true)
            else
                movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
                movedown:SetDisabled(false)
            end
            movedown:SetCallback("OnClick", function()
                local tmp = sequence[idx+1]
                sequence[idx+1] = sequence[idx]
                sequence[idx] = tmp
                update()
                create_sequence_list(frame, effect, update)
            end)
            addon.AddTooltip(movedown, L["Move Down"])
            movers:AddChild(movedown)

            local movebottom = AceGUI:Create("Icon")
            movebottom:SetImageSize(24, 24)
            if (idx == #sequence or sequence[idx+1] == "") then
                movebottom:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Disabled")
                movebottom:SetDisabled(true)
            else
                movebottom:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up")
                movebottom:SetDisabled(false)
            end
            movebottom:SetCallback("OnClick", function()
                local tmp = table.remove(sequence, idx)
                table.insert(sequence, tmp)
                update()
                create_sequence_list(frame, effect, update)
            end)
            addon.AddTooltip(movebottom, L["Move to Bottom"])
            movers:AddChild(movebottom)

            local delete = AceGUI:Create("Icon")
            delete:SetImageSize(24, 24)
            delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
            delete:SetCallback("OnClick", function()
                table.remove(sequence, idx)
                update()
                create_sequence_list(frame, effect, update)
            end)
            addon.AddTooltip(delete, DELETE)
            movers:AddChild(delete)

            row:AddChild(movers)
        end
    end

    local profile = addon.db.profile
    if sequence == nil or #sequence == 0 or (sequence[#sequence] ~= nil and sequence[#sequence] ~= "") then
        local row = frame

        local addbutton = AceGUI:Create("Button")
        local entry

        if effect.type == "dazzle" then
            entry = { r = profile["color"].r, g = profile["color"].g, b = profile["color"].b, a = profile["color"].a }
            local color_pick = AceGUI:Create("ColorPicker")
            color_pick:SetFullWidth(true)
            color_pick:SetColor(entry.r, entry.g, entry.b, entry.a)
            color_pick:SetLabel(L["Highlight Color"])
            color_pick:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
                entry = { r = r, g = g, b = b, a = a }
            end)
            row:AddChild(color_pick)
        elseif effect.type == "animate" then
            local group = AceGUI:Create("SimpleGroup")
            group:SetFullWidth(true)
            group:SetLayout("Table")
            group:SetUserData("table", { columns = { 35, 1 } })

            local icon = AceGUI:Create("Icon")
            icon:SetImageSize(36, 36)
            icon:SetWidth(44)
            icon:SetHeight(44)
            -- icon:SetDisabled(true)
            group:AddChild(icon)

            addbutton:SetDisabled(true)
            local texture = AceGUI:Create("EditBox")
            texture:SetFullWidth(true)
            texture:SetLabel(L["Texture"])
            texture:SetCallback("OnEnterPressed", function(_, _, val)
                icon:SetImage(val ~= "" and val)
                entry = val
                addbutton:SetDisabled(entry == nil)
            end)
            group:AddChild(texture)

            row:AddChild(group)
        elseif effect.type == "pulse" then
            entry = profile["magnification"]
            local magnification = AceGUI:Create("Slider")
            magnification:SetFullWidth(true)
            magnification:SetLabel(L["Magnification"])
            magnification:SetValue(entry)
            magnification:SetSliderValues(0.1, 2.0, 0.1)
            magnification:SetCallback("OnValueChanged", function(_, _, val)
                entry = val
            end)
            row:AddChild(magnification)
        elseif effect.type == "custom" then
            entry = {
                color = { r = profile["color"].r, g = profile["color"].g, b = profile["color"].b, a = profile["color"].a },
                magnification = profile["magnification"]
            }

            local outergroup = AceGUI:Create("SimpleGroup")
            outergroup:SetFullWidth(true)
            outergroup:SetLayout("Table")
            outergroup:SetUserData("table", { columns = { 35, 1 } })

            local icon = AceGUI:Create("Icon")
            icon:SetWidth(36)
            icon:SetHeight(36)
            icon:SetDisabled(true)
            icon:SetCallback("OnRelease", function(self)
                addon:HideGlow(self.frame, "effect")
            end)
            outergroup:AddChild(icon)

            local innergroup = AceGUI:Create("SimpleGroup")
            innergroup:SetFullWidth(true)
            innergroup:SetLayout("Table")
            innergroup:SetUserData("table", { columns = { 0.25, 0.25, 0.25, 0.25 } })

            addbutton:SetDisabled(true)
            local texture = AceGUI:Create("EditBox")
            texture:SetFullWidth(true)
            texture:SetLabel(L["Texture"])
            texture:SetCallback("OnEnterPressed", function(_, _, val)
                entry.texture = val ~= "" and val
                addon:Glow(icon.frame, "effect", { type = "texture", texture = entry.texture }, entry.color, entry.magnification, "CENTER", 0, 0, math.rad(entry.angle or 0))
                addbutton:SetDisabled(entry.texture == nil)
            end)
            texture:SetUserData("cell", { colspan = 3 })
            innergroup:AddChild(texture)

            local angle = AceGUI:Create("Slider")
            angle:SetFullWidth(true)
            angle:SetLabel(L["Angle"])
            angle:SetValue(entry.angle or 0)
            angle:SetSliderValues(0, 359, 1)
            angle:SetCallback("OnValueChanged", function(_, _, val)
                entry.angle = val
                addon:Glow(icon.frame, "effect", { type = "texture", texture = entry.texture }, entry.color, entry.magnification, "CENTER", 0, 0, math.rad(entry.angle or 0))
            end)
            innergroup:AddChild(angle)

            local color_pick = AceGUI:Create("ColorPicker")
            color_pick:SetFullWidth(true)
            color_pick:SetColor(entry.color.r, entry.color.g, entry.color.b, entry.color.a)
            color_pick:SetLabel(L["Highlight Color"])
            color_pick:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
                entry.color = { r = r, g = g, b = b, a = a }
                addon:Glow(icon.frame, "effect", { type = "texture", texture = entry.texture }, entry.color, entry.magnification, "CENTER", 0, 0, math.rad(entry.angle or 0))
            end)
            color_pick:SetUserData("cell", { colspan = 2 })
            innergroup:AddChild(color_pick)

            local magnification = AceGUI:Create("Slider")
            magnification:SetFullWidth(true)
            magnification:SetLabel(L["Magnification"])
            magnification:SetValue(entry.magnification)
            magnification:SetSliderValues(0.1, 2.0, 0.1)
            magnification:SetCallback("OnValueChanged", function(_, _, val)
                entry.magnification = val
                addon:Glow(icon.frame, "effect", { type = "texture", texture = entry.texture }, entry.color, entry.magnification, "CENTER", 0, 0, math.rad(entry.angle or 0))
            end)
            magnification:SetUserData("cell", { colspan = 2 })
            innergroup:AddChild(magnification)

            outergroup:AddChild(innergroup)
            row:AddChild(outergroup)
        else
            addbutton:SetDisabled(true)
        end

        addbutton:SetFullWidth(true)
        addbutton:SetText(ADD)
        -- addbutton:SetUserData("cell", { alignV = "middle" })
        addbutton:SetCallback("OnClick", function()
            sequence[#sequence + 1] = entry
            update()
            create_sequence_list(frame, effect, update)
        end)
        row:AddChild(addbutton)
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function sequence_popup(name, effect, update, onclose)
    local frame = AceGUI:Create("Frame")
    frame:PauseLayout()

    frame:SetTitle(L["Effect"] .. ": " .. name)
    if effect.type == "custom" then
        frame:SetWidth(600)
    elseif effect.type == "animate" then
        frame:SetWidth(475)
    else
        frame:SetWidth(350)
    end
    frame:SetHeight(400)
    frame:SetLayout("Fill")
    if onclose then
        frame:SetCallback("OnClose", function(widget)
            onclose(widget)
        end)
    end
    HideOnEscape(frame)

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetFullHeight(true)
    group:SetLayout("List")
    frame:AddChild(group)

    local scrollwin = AceGUI:Create("ScrollFrame")
    scrollwin:SetFullWidth(true)
    scrollwin:SetFullHeight(true)
    scrollwin:SetLayout("Table")
    scrollwin:SetUserData("table", { columns = { 1, 125 } })
    group:AddChild(scrollwin)

    create_sequence_list(scrollwin, effect, update)

    local help = AceGUI:Create("Help")
    help:SetLayout(addon.layout_sequence_list_help)
    help:SetTitle(L["Effect"])
    frame:AddChild(help)
    help:SetPoint("TOPRIGHT", 8, 16)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local ImportExport
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
    local function namesort(t, a, b) return (t[a].name or "") < (t[b].name or "") end
    for idx, v in addon.spairs(effects, namesort) do
        local row = group
        local sep = AceGUI:Create("Heading")
        sep:SetUserData("cell", { colspan = 5 })

        local icon = AceGUI:Create("Icon")
        icon:SetWidth(36)
        icon:SetHeight(36)
        icon:SetDisabled(true)
        icon:SetCallback("OnRelease", function(self)
            addon:HideGlow(self.frame, "effect")
        end)
        if frame:IsShown() then
            addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
        else
            icons[idx] = icon.frame
        end
        row:AddChild(icon)

        local type = AceGUI:Create("Dropdown")
        type:SetLabel(L["Type"])
        type:SetCallback("OnValueChanged", function(_, _, val)
            v.type = val
            addon:RemoveAllCurrentGlows()
            addon:create_effect_list(frame)
        end)
        type.configure = function()
            type:SetList({
                texture = L["Texture"],
                pixel = L["Pixel"],
                autocast = L["Auto Cast"],
                blizzard = L["Glow"],
                dazzle = L["Dazzle"],
                animate = L["Animate"],
                pulse = L["Pulse"],
                rotate = L["Rotate"],
                custom = L["Custom"],
            })
            type:SetValue(v.type or "texture")
        end
        row:AddChild(type)

        if v.name == nil then
            new_type:SetDisabled(true)
        end
        local name = AceGUI:Create("EditBox")
        name:SetFullWidth(true)
        name:SetLabel(NAME)
        name:SetText(v.name)
        name:DisableButton(v.name == nil or name2idx[v.name] ~= nil)
        name:SetCallback("OnTextChanged", function(_, _, val)
            name:DisableButton(val == "" or name2idx[val] ~= nil)
        end)
        name:SetCallback("OnEnterPressed", function(_, _, val)
            v.name = val ~= "" and val
            addon:create_effect_list(frame)
        end)
        row:AddChild(name)

        local rowgroup = AceGUI:Create("SimpleGroup")
        rowgroup:SetFullWidth(true)

        if v.type == "texture" then
            rowgroup:SetLayout("List")
            local texture = AceGUI:Create("EditBox")
            texture:SetFullWidth(true)
            texture:SetLabel(L["Texture"])
            texture:SetText(v.texture)
            texture:SetDisabled(v.name == nil)
            texture:SetCallback("OnEnterPressed", function(_, _, val)
                v.texture = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(texture)
        elseif v.type == "pixel" then
            rowgroup:SetLayout("Table")
            rowgroup:SetUserData("table", { columns = { 0.5, 0.5 } })

            if v.lines == nil then
                v.lines = 8
            end
            local lines = AceGUI:Create("Slider")
            lines:SetFullWidth(true)
            lines:SetLabel(L["Lines"])
            lines:SetValue(v.lines)
            lines:SetSliderValues(1, 20, 1)
            lines:SetDisabled(v.name == nil)
            lines:SetCallback("OnValueChanged", function(_, _, val)
                v.lines = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(lines)

            if v.frequency == nil then
                v.frequency = 0.25
            end
            local frequency = AceGUI:Create("Slider")
            frequency:SetFullWidth(true)
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency)
            frequency:SetSliderValues(-1.5, 1.5, 0.05)
            frequency:SetDisabled(v.name == nil)
            frequency:SetCallback("OnValueChanged", function(_, _, val)
                v.frequency = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(frequency)

            if v.length == nil then
                v.length = 2
            end
            local length = AceGUI:Create("Slider")
            length:SetFullWidth(true)
            length:SetLabel(L["Length"])
            length:SetValue(v.length)
            length:SetSliderValues(1, 20, 1)
            length:SetDisabled(v.name == nil)
            length:SetCallback("OnValueChanged", function(_, _, val)
                v.length = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(length)

            if v.thickness == nil then
                v.thickness = 2
            end
            local thickness = AceGUI:Create("Slider")
            thickness:SetFullWidth(true)
            thickness:SetLabel(L["Thickness"])
            thickness:SetValue(v.thickness)
            thickness:SetSliderValues(1, 5, 1)
            thickness:SetDisabled(v.name == nil)
            thickness:SetCallback("OnValueChanged", function(_, _, val)
                v.thickness = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(thickness)
        elseif v.type == "autocast" then
            rowgroup:SetLayout("Table")
            rowgroup:SetUserData("table", { columns = { 0.33, 0.33, 0.33 } })

            if v.particles == nil then
                v.particles = 4
            end
            local particles = AceGUI:Create("Slider")
            particles:SetFullWidth(true)
            particles:SetLabel(L["Particles"])
            particles:SetValue(v.particles)
            particles:SetSliderValues(1, 4, 1)
            particles:SetDisabled(v.name == nil)
            particles:SetCallback("OnValueChanged", function(_, _, val)
                v.particles = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(particles)

            if v.frequency == nil then
                v.frequency = 0.125
            end
            local frequency = AceGUI:Create("Slider")
            frequency:SetFullWidth(true)
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency)
            frequency:SetSliderValues(-1.5, 1.5, 0.05)
            frequency:SetDisabled(v.name == nil)
            frequency:SetCallback("OnValueChanged", function(_, _, val)
                v.frequency = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(frequency)

            if v.scale == nil then
                v.scale = 1.0
            end
            local scale = AceGUI:Create("Slider")
            scale:SetFullWidth(true)
            scale:SetLabel(L["Scale"])
            scale:SetValue(v.scale)
            scale:SetSliderValues(0.25, 5, 0.25)
            scale:SetDisabled(v.name == nil)
            scale:SetCallback("OnValueChanged", function(_, _, val)
                v.scale = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(scale)

        elseif v.type == "blizzard" then
            rowgroup:SetLayout("List")
            if v.frequency == nil then
                v.frequency = 0.125
            end
            local frequency = AceGUI:Create("Slider")
            frequency:SetFullWidth(true)
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency)
            frequency:SetSliderValues(0.0, 1.5, 0.05)
            frequency:SetDisabled(v.name == nil)
            frequency:SetCallback("OnValueChanged", function(_, _, val)
                v.frequency = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(frequency)

        elseif v.type == "dazzle" then
            rowgroup:SetLayout("Table")
            rowgroup:SetUserData("table", { columns = { 0.67, 0.33 } })

            local texture = AceGUI:Create("EditBox")
            texture:SetFullWidth(true)
            texture:SetLabel(L["Texture"])
            texture:SetText(v.texture)
            texture:SetDisabled(v.name == nil)
            texture:SetCallback("OnEnterPressed", function(_, _, val)
                v.texture = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            texture:SetUserData("cell", { colspan = 2 })
            rowgroup:AddChild(texture)

            if v.frequency == nil then
                v.frequency = 0.25
            end
            local frequency = AceGUI:Create("Slider")
            frequency:SetFullWidth(true)
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency or 0.25)
            frequency:SetSliderValues(0.1, 5, 0.05)
            frequency:SetDisabled(v.name == nil)
            frequency:SetCallback("OnValueChanged", function(_, _, val)
                v.frequency = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(frequency)

            local sequence = AceGUI:Create("Button")
            sequence:SetFullWidth(true)
            sequence:SetText(L["Sequence"])
            sequence:SetUserData("cell", { alignV = "bottom" })
            sequence:SetDisabled(v.name == nil)
            sequence:SetCallback("OnClick", function()
                sequence_popup(v.name, v, function()
                    addon:RemoveAllCurrentGlows()
                end, function()
                    addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                end)
            end)
            rowgroup:AddChild(sequence)
        elseif v.type == "animate" then
            rowgroup:SetLayout("Table")
            rowgroup:SetUserData("table", { columns = { 0.67, 0.33 } })

            if v.frequency == nil then
                v.frequency = 0.25
            end
            local frequency = AceGUI:Create("Slider")
            frequency:SetFullWidth(true)
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency)
            frequency:SetSliderValues(0.1, 5, 0.05)
            frequency:SetDisabled(v.name == nil)
            frequency:SetCallback("OnValueChanged", function(_, _, val)
                v.frequency = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(frequency)

            local sequence = AceGUI:Create("Button")
            sequence:SetFullWidth(true)
            sequence:SetText(L["Sequence"])
            sequence:SetUserData("cell", { alignV = "bottom" })
            sequence:SetDisabled(v.name == nil)
            sequence:SetCallback("OnClick", function()
                sequence_popup(v.name, v, function()
                    addon:RemoveAllCurrentGlows()
                end, function()
                    addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                end)
            end)
            rowgroup:AddChild(sequence)
        elseif v.type == "pulse" then
            rowgroup:SetLayout("Table")
            rowgroup:SetUserData("table", { columns = { 0.67, 0.33 } })

            local texture = AceGUI:Create("EditBox")
            texture:SetFullWidth(true)
            texture:SetLabel(L["Texture"])
            texture:SetText(v.texture)
            texture:SetDisabled(v.name == nil)
            texture:SetCallback("OnEnterPressed", function(_, _, val)
                v.texture = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            texture:SetUserData("cell", { colspan = 2 })
            rowgroup:AddChild(texture)

            if v.frequency == nil then
                v.frequency = 0.25
            end
            local frequency = AceGUI:Create("Slider")
            frequency:SetFullWidth(true)
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency)
            frequency:SetSliderValues(0.1, 5, 0.05)
            frequency:SetDisabled(v.name == nil)
            frequency:SetCallback("OnValueChanged", function(_, _, val)
                v.frequency = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(frequency)

            local sequence = AceGUI:Create("Button")
            sequence:SetFullWidth(true)
            sequence:SetText(L["Sequence"])
            sequence:SetUserData("cell", { alignV = "bottom" })
            sequence:SetDisabled(v.name == nil)
            sequence:SetCallback("OnClick", function()
                sequence_popup(v.name, v, function()
                    addon:RemoveAllCurrentGlows()
                end, function()
                    addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                end)
            end)
            rowgroup:AddChild(sequence)
        elseif v.type == "custom" then
            rowgroup:SetLayout("Table")
            rowgroup:SetUserData("table", { columns = { 0.67, 0.33 } })

            if v.frequency == nil then
                v.frequency = 0.25
            end
            local frequency = AceGUI:Create("Slider")
            frequency:SetFullWidth(true)
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency)
            frequency:SetSliderValues(0.1, 5, 0.05)
            frequency:SetDisabled(v.name == nil)
            frequency:SetCallback("OnValueChanged", function(_, _, val)
                v.frequency = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(frequency)

            local sequence = AceGUI:Create("Button")
            sequence:SetFullWidth(true)
            sequence:SetText(L["Sequence"])
            sequence:SetUserData("cell", { alignV = "bottom" })
            sequence:SetDisabled(v.name == nil)
            sequence:SetCallback("OnClick", function()
                sequence_popup(v.name, v, function()
                    addon:RemoveAllCurrentGlows()
                end, function()
                    addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                end)
            end)
            rowgroup:AddChild(sequence)
        elseif v.type == "rotate" then
            rowgroup:SetLayout("Table")
            rowgroup:SetUserData("table", { columns = { 0.33, 0.33, 0.33 } })

            local texture = AceGUI:Create("EditBox")
            texture:SetFullWidth(true)
            texture:SetLabel(L["Texture"])
            texture:SetText(v.texture)
            texture:SetDisabled(v.name == nil)
            texture:SetCallback("OnEnterPressed", function(_, _, val)
                v.texture = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            texture:SetUserData("cell", { colspan = 3 })
            rowgroup:AddChild(texture)

            if v.frequency == nil then
                v.frequency = 0.25
            end
            local frequency = AceGUI:Create("Slider")
            frequency:SetFullWidth(true)
            frequency:SetLabel(L["Frequency"])
            frequency:SetValue(v.frequency)
            frequency:SetSliderValues(0.1, 5, 0.05)
            frequency:SetDisabled(v.name == nil)
            frequency:SetCallback("OnValueChanged", function(_, _, val)
                v.frequency = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(frequency)

            if v.steps == nil then
                v.steps = 4
            end
            local steps = AceGUI:Create("Slider")
            steps:SetFullWidth(true)
            steps:SetLabel(L["Steps"])
            steps:SetValue(v.steps)
            steps:SetSliderValues(2, 36, 1)
            steps:SetDisabled(v.name == nil)
            steps:SetCallback("OnValueChanged", function(_, _, val)
                v.steps = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(steps)

            local reverse = AceGUI:Create("CheckBox")
            reverse:SetLabel(L["Reverse"])
            reverse:SetValue(v.reverse)
            reverse:SetDisabled(v.name == nil)
            reverse:SetCallback("OnValueChanged", function(_, _, val)
                v.reverse = val
                addon:Glow(icon.frame, "effect", v, { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                addon:RemoveAllCurrentGlows()
            end)
            rowgroup:AddChild(reverse)
        end

        row:AddChild(rowgroup)

        local button_group = AceGUI:Create("SimpleGroup")
        button_group:SetFullWidth(true)
        button_group:SetLayout("Table")
        button_group:SetUserData("table", { columns = { 24 } })

        local importexport = AceGUI:Create("Icon")
        importexport:SetImageSize(24, 24)
        importexport:SetImage("Interface\\FriendsFrame\\UI-FriendsList-Small-Up")
        importexport:SetUserData("cell", { alignV = "bottom" })
        importexport:SetCallback("OnClick", function()
            ImportExport(idx, frame)
            addon:create_effect_list(frame)
        end)
        addon.AddTooltip(importexport, L["Import/Export"])
        button_group:AddChild(importexport)

        local delete = AceGUI:Create("Icon")
        delete:SetImageSize(24, 24)
        delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        importexport:SetUserData("cell", { alignV = "top" })
        delete:SetCallback("OnClick", function()
            effects[idx] = nil
            addon:RemoveAllCurrentGlows()
            addon:create_effect_list(frame)
        end)
        addon.AddTooltip(delete, DELETE)
        button_group:AddChild(delete)

        row:AddChild(button_group)

        group:AddChild(sep)
    end

    local row = group

    row:AddChild(spacer(1))

    local name = AceGUI:Create("EditBox")

    new_type:SetLabel(L["Type"])
    new_type:SetCallback("OnValueChanged", function(_, _, val)
        effects[addon:uuid()] = { type = val, name = nil, texture = nil }
        addon:create_effect_list(frame)
    end)
    new_type.configure = function()
        new_type:SetList({
            texture = L["Texture"],
            pixel = L["Pixel"],
            autocast = L["Auto Cast"],
            blizzard = L["Glow"],
            dazzle = L["Dazzle"],
            animate = L["Animate"],
            pulse = L["Pulse"],
            rotate = L["Rotate"],
            custom = L["Custom"],
        })
    end
    row:AddChild(new_type)

    name:SetFullWidth(true)
    name:SetLabel(NAME)
    name:SetDisabled(true)
    row:AddChild(name)

    row:AddChild(spacer(1))

    local button_group = AceGUI:Create("SimpleGroup")
    button_group:SetFullWidth(true)
    button_group:SetLayout("Table")
    button_group:SetUserData("table", { columns = { 24 } })

    local importexport = AceGUI:Create("Icon")
    importexport:SetImageSize(24, 24)
    importexport:SetImage("Interface\\FriendsFrame\\UI-FriendsList-Small-Up")
    importexport:SetUserData("cell", { alignV = "bottom" })
    importexport:SetCallback("OnClick", function()
        ImportExport(addon:uuid(), frame)
        addon:create_effect_list(frame)
    end)
    addon.AddTooltip(importexport, L["Import/Export"])
    button_group:AddChild(importexport)

    local delete = AceGUI:Create("Icon")
    delete:SetImageSize(24, 24)
    delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    delete:SetDisabled(true)
    addon.AddTooltip(delete, DELETE)
    button_group:AddChild(delete)

    row:AddChild(button_group)

    frame:AddChild(group)

    local help = AceGUI:Create("Help")
    help:SetLayout(addon.layout_effects_options_help)
    help:SetTitle(L["Effects"])
    frame:AddChild(help)
    help:SetPoint("TOPRIGHT", 8, 38)

    if not frame:IsShown() then
        frame.frame:SetScript("OnShow", function(f)
            for idx,icon in pairs(icons) do
                if effects[idx].name then
                    addon:Glow(icon, "effect", effects[idx], { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, 1.0, "CENTER", 0, 0)
                end
            end
            f:SetScript("OnShow", nil)
        end)
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

ImportExport = function(effect, parent)
    local effects = addon.db.global.effects

    local frame = AceGUI:Create("Window")
    frame:SetTitle(L["Import/Export Effect"])
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
    desc:SetText(L["Copy and paste this text share your effect with others, or import someone else's."])
    frame:AddChild(desc)

    local import = AceGUI:Create("Button")
    local editbox = AceGUI:Create("MultiLineEditBox")

    editbox:SetFullHeight(true)
    editbox:SetFullWidth(true)
    editbox:SetLabel("")
    editbox:SetNumLines(27)
    editbox:DisableButton(true)
    editbox:SetFocus(true)
    if (effects[effect] ~= nil) then
        editbox:SetText(width_split(base64enc(libc:Compress(AceSerializer:Serialize(effects[effect]))), 64))
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
            for _,e in pairs(effects) do
                if e.name == res.name then
                    res.name = res.name .. " (" .. date(L["Imported on %c"]) .. ")"
                    break
                end
            end
            effects[effect] = res

            frame:Hide()
            addon:create_effect_list(parent)
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

