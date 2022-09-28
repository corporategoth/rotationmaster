local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, Indent, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.Indent, helpers.Gap

function addon.layout_effects_options_help(frame)
    local group = frame

    group:AddChild(CreateText(
        "Effects are the various methods of highlighting action bar icons.  Cooldowns may have individual " ..
        "effects per cooldown, however all rotation steps will be highlighted using the effect defined in " ..
        "the primary Rotation Master configuration settings.  You may define as many different effect styles " ..
        "as you wish.  Effects are shared across all characters."))

    group:AddChild(Gap())
    group:AddChild(CreateText("Fields", "Interface\\AddOns\\" .. addon_name .. "\\Fonts\\Inconsolata-Bold.ttf", 16))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Type"] .. color.RESET .. " - " ..
            "The type of effect being configured.  A new effect may be added by defining it's type at the end " ..
            "of the list of effects."))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Texture"] .. color.RESET .. " - " ..
            "A texture file in game data files (or available via. an addon) overlayed on top of the action icon.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Pixel"] .. color.RESET .. " - " ..
            "Lines marching around the border of the action icon.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Auto Cast"] .. color.RESET .. " - " ..
            "A glow resembling pixels swarming around the action icon.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Glow"] .. color.RESET .. " - " ..
            "A standard Blizzard frame glow (like rays shining from the button).")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Animate"] .. color.RESET .. " - " ..
            "Create a sequence of textures to be overlayed in a loop.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Dazzle"] .. color.RESET .. " - " ..
            "Create a sequence of colors to change the overlayed texture to in a loop.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Pulse"] .. color.RESET .. " - " ..
            "Create a sequence of magnifications to change the overlayed texture to in a loop.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Rotate"] .. color.RESET .. " - " ..
            "Rotate the overlayed texture in a circle.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Custom"] .. color.RESET .. " - " ..
            "Create a custom sequence specifying texture, color, magnification and rotation for each step.")))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. NAME .. color.RESET .. " - " ..
            "The name of this specific effect configuration.  This be in the list of effects in both the primary " ..
            "Rotation Master configuration screen and when configuring cooldowns."))

    group:AddChild(Gap())
    group:AddChild(CreateText("Texture effects:"))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Texture"] .. color.RESET .. " - " ..
            "The name of the texture to overlay on top of action icons.")))

    group:AddChild(Gap())
    group:AddChild(CreateText("Pixel effects:"))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Lines"] .. color.RESET .. " - " ..
            "How many lines should be drawn around the action icon.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should those lines move around the action icon.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Length"] .. color.RESET .. " - " ..
            "How long should each line drawn around the action icon be.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Thickness"] .. color.RESET .. " - " ..
            "How thichk should each line drawn around the action icons be.")))

    group:AddChild(Gap())
    group:AddChild(CreateText("Auto Cast effects:"))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Particles"] .. color.RESET .. " - " ..
            "How many particles are swarming around the action item")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the particles move around the action icon.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Scale"] .. color.RESET .. " - " ..
            "How big should each paritcle around the action icon be.")))

    group:AddChild(Gap())
    group:AddChild(CreateText("Glow effects:"))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the glow animation be played.")))

    group:AddChild(Gap())
    group:AddChild(CreateText("Aimate effects:"))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the we swap between textures.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Sequence"] .. color.RESET .. " - " ..
            "The list of textures to overlay, in order.")))

    group:AddChild(Gap())
    group:AddChild(CreateText("Dazzle effects:"))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Texture"] .. color.RESET .. " - " ..
            "The name of the texture to overlay on top of action icons.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the we change the texture color.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Sequence"] .. color.RESET .. " - " ..
            "The list of colors to change to, in order.")))

    group:AddChild(Gap())
    group:AddChild(CreateText("Pulse effects:"))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Texture"] .. color.RESET .. " - " ..
            "The name of the texture to overlay on top of action icons.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the we change the texture size.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Sequence"] .. color.RESET .. " - " ..
            "The list of magnifications to change to, in order.")))

    group:AddChild(Gap())
    group:AddChild(CreateText("Rotate effects:"))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Texture"] .. color.RESET .. " - " ..
            "The name of the texture to overlay on top of action icons.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the we change the texture angle.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Steps"] .. color.RESET .. " - " ..
            "How many 'steps' around the circular path should we animate.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Reverse"] .. color.RESET .. " - " ..
            "Rotate clockwise instead of counterclockwise.")))

    group:AddChild(Gap())
    group:AddChild(CreateText("Custom effects:"))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the we swap between steps.")))
    group:AddChild(Indent(40, CreateText(color.BLIZ_YELLOW .. L["Sequence"] .. color.RESET .. " - " ..
            "The list of steps to perform (which includes overlay texture, color, magnification and angle), in order.")))

    group:AddChild(Gap())
    group:AddChild(CreatePictureText(
            "Interface\\FriendsFrame\\UI-FriendsList-Small-Up", 24, 24,
            color.BLIZ_YELLOW .. L["Import/Export"] .. color.RESET .. " - " ..
                    "This will open up a window that can be used to both export " ..
                    "your the effect set and import one created by someone else."))

    group:AddChild(Gap())
    group:AddChild(CreatePictureText(
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", 24, 24,
        color.BLIZ_YELLOW .. DELETE .. color.RESET .. " - " ..
            "Permanently delete this effect.  No checks will be made to check if this effect is in use (either in " ..
            "the primary Rotation Master settings or cooldowns for any rotation on any character.)"))
end
