local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local helpers = {}
local color = color

function helpers.CreateText(text, font, fontheight)
    local rv = AceGUI:Create("Label")
    -- There is a bug in Table (I think) that doesn't handle SetFullWidth correctly
    rv:SetFullWidth(true)
    rv:SetText(text .. color.RESET)
    if font then
        if fontheight then
            rv:SetFont(font, fontheight)
        else
            rv:SetFontObject(font)
        end
    end
    return rv
end

function helpers.CreatePictureText(texture, width, height, text, font, fontheight, ...)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { width, 1 } })

    local icon = AceGUI:Create("Icon")
    icon:SetImage(texture, ...)
    icon:SetImageSize(width, height)
    -- For some reason icon offset by +5 from the top, and the height is set to 10 + image size
    icon:SetHeight(height + 5)
    group:AddChild(icon)

    group:AddChild(helpers.CreateText(text, font, fontheight))

    return group
end

function helpers.CreateButtonText(name, text, font, fontheight, ...)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { 125, 1 } })

    local icon = AceGUI:Create("Button")
    icon:SetText(name)
    group:AddChild(icon)

    group:AddChild(helpers.CreateText(text, font, fontheight))

    return group
end

function helpers.Indent(size, target)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { size, 1 } })

    local spacer = AceGUI:Create("Label")
    spacer:SetText(nil)
    spacer:SetWidth(1)
    group:AddChild(spacer)

    group:AddChild(target)

    return group
end

function helpers.Gap()
    local rv = AceGUI:Create("Label")
    rv:SetText(" ")
    return rv
end

addon.help_funcs = helpers
