local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, CreateButtonText, Gap, Indent =
    helpers.CreateText, helpers.CreatePictureText, helpers.CreateButtonText, helpers.Gap, helpers.Indent

function addon.layout_custom_condition_options_help(frame)
    local group = frame

    group:AddChild(CreateText(
            "Conditions are used to decide when a rotation step or cooldown will be active.  Custom Conditions " ..
            "should be treated with care, as they use raw LUA code, which can do almost anything."))

    group:AddChild(Gap())
    group:AddChild(CreateText("Fields", "Interface\\AddOns\\" .. addon_name .. "\\Fonts\\Inconsolata-Bold.ttf", 16))

    group:AddChild(Gap())
    group:AddChild(CreatePictureText("Interface\\Icons\\INV_Misc_QuestionMark", 36, 36,
        "The icon to use for quick identification of the condition in question.  This icon iself has no real " ..
        "meaning, and is simply used to make conditions more visually distinguishable."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Key"] .. color.RESET .. " - " ..
        "The key that is used to uniquely identify a condition.  This should have no spaces or special " ..
        "characters other than an underscore, and must be unique."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Description"] .. color.RESET .. " - " ..
        "The description text used to describe this condition.  This is what will show up in the list of " ..
        "conditions when selecting or categorizing conditions."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Validity Function"] .. color.RESET .. " - " ..
        "The function used to validate whether the condition itself is valid (ie. all the required fields " ..
        "are set to valid values).  This function takes the form of " .. color.CYAN .. "function(spec, value)" ..
        color.RESET .. " where:"))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "spec" .. color.RESET ..
            " is the talent specification in use for this condition, where multiple specifications are available.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "value" .. color.RESET ..
            " is a vartiable that stores all parameters for this condition.")))
    group:AddChild(CreateText("This function returns true if this condition is valid, false otherwise."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Evaluation Function"] .. color.RESET .. " - " ..
        "The function used to evaluate a this condition real-time."))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "value" .. color.RESET ..
            " is a vartiable that stores all parameters for this condition.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "cache" .. color.RESET ..
            " is a cache that is used to store the results of WoW API calls, such that they do not need " ..
            "to be evaluated more than once.  This cache is reset every time the rotation steps are evaluated." ..
            "  This is used with a function such as:")))
    group:AddChild(Indent(80, CreateText(color.CYAN .. "getCached(cache, UserClass, \"player\")")))
    group:AddChild(Indent(40, CreateText("You can also use addon.combatCache which is reset when you enter " ..
            " or exit combat, or addon.longtermCache which is reset when you learn new abilities.")))
    group:AddChild(CreateText("This function returns true if this condition is currently true."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Print Function"] .. color.RESET .. " - " ..
        "The function used to give a string representation of this condition.  This is joined with other " ..
        "condition strings to allow for a complete description of the conditions controlling a rotation step " ..
        "or cooldown."))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "spec" .. color.RESET ..
            " is the talent specification in use for this condition, where multiple specifications are available.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "value" .. color.RESET ..
            " is a vartiable that stores all parameters for this condition.")))
    group:AddChild(CreateText("This function returns a string that describes this condition, including any parameters."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Widget Function"] .. color.RESET .. " - " ..
        "The function used to edit this condition with the condition editor as part of a rotation or cooldown.  " ..
        "This should provide UI components for entering any parameters."))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "parent" .. color.RESET ..
            " is the UI container when any widgets for this condition should be added to.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "spec" .. color.RESET ..
            " is the talent specification in use for this condition, where multiple specifications are available.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "value" .. color.RESET ..
            " is a vartiable that stores all parameters for this condition.")))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Help Function"] .. color.RESET .. " - " ..
        "The function used to provide help information or users of this condition.  This help is displayed when " ..
        "a user clicks the standard help question mark in the condition editor for your condition."))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "frame" .. color.RESET ..
            " is the UI container that your help messages should be added to.")))

    group:AddChild(Gap())
    group:AddChild(CreatePictureText(
            "Interface\\FriendsFrame\\UI-FriendsList-Small-Up", 24, 24,
            color.BLIZ_YELLOW .. L["Import/Export"] .. color.RESET .. " - " ..
            "This will open up a window that can be used to both export " ..
            "your current custom condition and import one created by someone else."))

    group:AddChild(Gap())
    group:AddChild(CreateButtonText(ADD,
            "Add a new custom condition.  You can only do this when you have specified a key, " ..
            "description, and do not have any outstanding edits on any of the function texts."))
    group:AddChild(CreateButtonText(SAVE,
            "Save a custom condition.  You can only do this when you have specified a " ..
            "description, and do not have any outstanding edits on any of the function texts."))
end
