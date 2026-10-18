local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, Indent, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.Indent, helpers.Gap

function addon:GetDocument_layout_effects_options_help()
    return addon:SettingsHelpSections({
"Effects are the various methods of highlighting action bar icons.  Cooldowns may have individual " ..
        "effects per cooldown, however all rotation steps will be highlighted using the effect defined in " ..
        "the primary Rotation Master configuration settings.  You may define as many different effect styles " ..
        "as you wish.  Effects are shared across all characters.",
color.BLIZ_YELLOW .. L["Type"] .. color.RESET .. " - " ..
            "The type of effect being configured.  A new effect may be added by defining it's type at the end " ..
            "of the list of effects.",
color.GREEN .. L["Texture"] .. color.RESET .. " - " ..
            "A texture file in game data files (or available via. an addon) overlayed on top of the action icon.",
color.GREEN .. L["Pixel"] .. color.RESET .. " - " ..
            "Lines marching around the border of the action icon.",
color.GREEN .. L["Auto Cast"] .. color.RESET .. " - " ..
            "A glow resembling pixels swarming around the action icon.",
color.GREEN .. L["Glow"] .. color.RESET .. " - " ..
            "A standard Blizzard frame glow (like rays shining from the button).",
color.GREEN .. L["Animate"] .. color.RESET .. " - " ..
            "Create a sequence of textures to be overlayed in a loop.",
color.GREEN .. L["Dazzle"] .. color.RESET .. " - " ..
            "Create a sequence of colors to change the overlayed texture to in a loop.",
color.GREEN .. L["Pulse"] .. color.RESET .. " - " ..
            "Create a sequence of magnifications to change the overlayed texture to in a loop.",
color.GREEN .. L["Rotate"] .. color.RESET .. " - " ..
            "Rotate the overlayed texture in a circle.",
color.GREEN .. L["Custom"] .. color.RESET .. " - " ..
            "Create a custom sequence specifying texture, color, magnification and rotation for each step.",
color.BLIZ_YELLOW .. (NAME or L['Name']) .. color.RESET .. " - " ..
            "The name of this specific effect configuration.  This be in the list of effects in both the primary " ..
            "Rotation Master configuration screen and when configuring cooldowns.",
"Texture effects:",
color.BLIZ_YELLOW .. L["Texture"] .. color.RESET .. " - " ..
            "The name of the texture to overlay on top of action icons.",
"Pixel effects:",
color.BLIZ_YELLOW .. L["Lines"] .. color.RESET .. " - " ..
            "How many lines should be drawn around the action icon.",
color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should those lines move around the action icon.",
color.BLIZ_YELLOW .. L["Length"] .. color.RESET .. " - " ..
            "How long should each line drawn around the action icon be.",
color.BLIZ_YELLOW .. L["Thickness"] .. color.RESET .. " - " ..
            "How thichk should each line drawn around the action icons be.",
"Auto Cast effects:",
color.BLIZ_YELLOW .. L["Particles"] .. color.RESET .. " - " ..
            "How many particles are swarming around the action item",
color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the particles move around the action icon.",
color.BLIZ_YELLOW .. L["Scale"] .. color.RESET .. " - " ..
            "How big should each paritcle around the action icon be.",
"Glow effects:",
color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the glow animation be played.",
"Aimate effects:",
color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the we swap between textures.",
color.BLIZ_YELLOW .. L["Sequence"] .. color.RESET .. " - " ..
            "The list of textures to overlay, in order.",
"Dazzle effects:",
color.BLIZ_YELLOW .. L["Texture"] .. color.RESET .. " - " ..
            "The name of the texture to overlay on top of action icons.",
color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the we change the texture color.",
color.BLIZ_YELLOW .. L["Sequence"] .. color.RESET .. " - " ..
            "The list of colors to change to, in order.",
"Pulse effects:",
color.BLIZ_YELLOW .. L["Texture"] .. color.RESET .. " - " ..
            "The name of the texture to overlay on top of action icons.",
color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the we change the texture size.",
color.BLIZ_YELLOW .. L["Sequence"] .. color.RESET .. " - " ..
            "The list of magnifications to change to, in order.",
"Rotate effects:",
color.BLIZ_YELLOW .. L["Texture"] .. color.RESET .. " - " ..
            "The name of the texture to overlay on top of action icons.",
color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the we change the texture angle.",
color.BLIZ_YELLOW .. L["Steps"] .. color.RESET .. " - " ..
            "How many 'steps' around the circular path should we animate.",
color.BLIZ_YELLOW .. L["Reverse"] .. color.RESET .. " - " ..
            "Rotate clockwise instead of counterclockwise.",
"Custom effects:",
color.BLIZ_YELLOW .. L["Frequency"] .. color.RESET .. " - " ..
            "How quickly should the we swap between steps.",
color.BLIZ_YELLOW .. L["Sequence"] .. color.RESET .. " - " ..
            "The list of steps to perform (which includes overlay texture, color, magnification and angle), in order.",
color.BLIZ_YELLOW .. L["Import/Export"] .. color.RESET .. " - " ..
                    "This will open up a window that can be used to both export " ..
                    "your the effect set and import one created by someone else.",
color.BLIZ_YELLOW .. (DELETE or L['Delete']) .. color.RESET .. " - " ..
            "Permanently delete this effect.  No checks will be made to check if this effect is in use (either in " ..
            "the primary Rotation Master settings or cooldowns for any rotation on any character.)"
    })
end
function addon.layout_effects_options_help(frame)
    for _,entry in ipairs(addon:GetDocument_layout_effects_options_help()) do frame:AddChild(Gap());frame:AddChild(CreateText((entry.title~='' and color.BLIZ_YELLOW..entry.title..color.RESET..' - ' or '')..entry.text)) end
end
