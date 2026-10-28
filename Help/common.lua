-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared builders for the Help/ files and the condition help callbacks: text blocks, picture and button rows, an
-- indent and a gap, built from the condition widget set (addon:CreateCondition*). Exposed as addon.help_funcs.
-- Loaded first of the Help/ files (RotationMaster.toc), after UI/ has defined the widget constructors; each helper
-- must only build widgets when called, never at load. Help text itself lives in the locale tables, not here.
local _, addon = ...

local helpers = {}
local color = color

-- Builds a full-width group holding one wrapped label of help text. font is a font object name, or a font file when
-- fontheight is also given. Returns the group.
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

-- Builds a two-column row with an icon (texture plus optional texcoords) at the left and help text at the right.
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

-- Builds a two-column row with a button labeled like the real control at the left and its explanation at the right.
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

-- Wraps a widget in a row with an empty left column of the given width, so it appears indented.
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

-- Returns a one-line blank label used as vertical spacing between help paragraphs.
function helpers.Gap()
    local rv = addon:CreateConditionLabel()
    rv:SetText(" ")
    return rv
end

addon.help_funcs = helpers
