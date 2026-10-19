local _, addon = ...


local helpers = {}
local color = color

function helpers.CreateText(text, font, fontheight)
    local t = addon:CreateConditionGroup()
    t:SetFullWidth(true)
    t:SetLayout("List")

    local rv = addon:CreateConditionLabel()
    rv:SetFullWidth(true)
    rv:SetText(text .. color.RESET)
    if font then
        if fontheight then
            rv:SetFont(font, fontheight)
        else
            rv:SetFontObject(font)
        end
    end

    t:AddChild(rv)
    return t
end

function helpers.CreatePictureText(texture, width, height, text, font, fontheight, ...)
    local group = addon:CreateConditionGroup()
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { width, 1 } })

    local icon = addon:CreateConditionIcon()
    icon:SetImage(texture, ...)
    icon:SetImageSize(width, height)
    -- For some reason icon offset by +5 from the top, and the height is set to 10 + image size
    icon:SetHeight(height + 5)
    group:AddChild(icon)

    group:AddChild(helpers.CreateText(text, font, fontheight))

    return group
end

function helpers.CreateButtonText(name, text, font, fontheight, ...)
    local group = addon:CreateConditionGroup()
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { 125, 1 } })

    local icon = addon:CreateConditionButton()
    icon:SetText(name)
    group:AddChild(icon)

    group:AddChild(helpers.CreateText(text, font, fontheight))

    return group
end

function helpers.Indent(size, target)
    local group = addon:CreateConditionGroup()
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { size, 1 } })

    local spacer = addon:CreateConditionLabel()
    spacer:SetText(nil)
    spacer:SetWidth(1)
    group:AddChild(spacer)

    group:AddChild(target)

    return group
end

function helpers.Gap()
    local rv = addon:CreateConditionLabel()
    rv:SetText(" ")
    return rv
end

addon.help_funcs = helpers

-- Authored field documentation is data, independent of any renderer.
function addon:SettingsHelpSections(values)
    local rows={}
    for _,value in ipairs(values) do
        local plain=value:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
        local title,text=plain:match('^(.-) %- (.*)$')
        rows[#rows+1]={title=title or '',text=text or plain}
    end
    return rows
end
