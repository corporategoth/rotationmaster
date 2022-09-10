local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local AceGUI = LibStub("AceGUI-3.0")
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.Gap

function addon.layout_conditions_options_help(frame)
    local group = frame

    group:AddChild(CreateText(
            "Conditions are used to decide when a rotation step or cooldown will be active.  There are many " ..
            "conditions deployed with Rotation Master, serving a wide variety of purposes.  They can be grouped " ..
            "in many ways.  They can also be enabled as switch conditions (ie. used to aid in automatic " ..
            "switching rotations)."))

    group:AddChild(Gap())
    group:AddChild(CreateText("Fields", "Interface\\AddOns\\RotationMaster\\Fonts\\Inconsolata-Bold.ttf", 16))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. NAME .. color.RESET .. " - " ..
            "Select which condition group you wish to modify.  You can create a new condition group by " ..
            "selecting " .. color.GREEN .. NEW .. color.RESET .. ".  The special group " .. color.GREEN ..
            ALL .. color.RESET .. " will display all conditions that are known to Rotation Master, regardless " ..
            "of it's use.  The " .. color.CYAN .. L["Switch"] .. color.RESET .. " group shows you all " ..
            "conditions that are used for switching rotations. The " .. color.GREEN .. L["Other"] .. color.RESET ..
            " group shows all conditions that are not associated with other condition groups."))

    group:AddChild(CreatePictureText(
            "Interface\\AddOns\\RotationMaster\\textures\\UI-ChatIcon-ScrollHome-Up", 24, 24,
            color.BLIZ_YELLOW .. L["Move to Top"] .. color.RESET .. " - " ..
                    "This will move the current condition group to the first slot in the list."))

    group:AddChild(CreatePictureText(
            "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up", 24, 24,
            color.BLIZ_YELLOW .. L["Move Up"] .. color.RESET .. " - " ..
                    "This will move the current condition group up to the previous slot in the list."))

    group:AddChild(CreatePictureText(
            "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up", 24, 24,
            color.BLIZ_YELLOW .. L["Move Down"] .. color.RESET .. " - " ..
                    "This will move the current condition group down to the next slot in the list."))

    group:AddChild(CreatePictureText(
            "Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up", 24, 24,
            color.BLIZ_YELLOW .. L["Move to Bottom"] .. color.RESET .. " - " ..
                    "This will move the current condition to the last slot in the list."))

    group:AddChild(CreatePictureText(
            "Interface\\FriendsFrame\\UI-FriendsList-Small-Up", 24, 24,
            color.BLIZ_YELLOW .. L["Import/Export"] .. color.RESET .. " - " ..
                    "This will open up a window that can be used to both export " ..
                    "your current condition group and import one created by someone else."))

    group:AddChild(CreatePictureText(
            "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", 24, 24,
            color.BLIZ_YELLOW .. DELETE .. color.RESET .. " - " ..
                    "Delete this condition group.  All conditions within will show up under the " ..
                    color.GREEN .. L["Other"] .. color.RESET .. " group when selecting conditions."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Search"] .. color.RESET .. " - " ..
            "Filter the conditions displayed to only ones that contain the search string.  This makes it " ..
            "much easier to find conditions as the number of conditions grow."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Switch Condition"] .. color.RESET .. " - " ..
            "If this is checked, the condition will show up in the list of conditions that can be used " ..
            "when switching rotations."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Hidden"] .. color.RESET .. " - " ..
            "This condition should not show up in the condition selection box (for the " .. color.GREEN ..
            L["Other"] .. color.RESET .. " group).  A condition that is in another group will still " ..
            "show up in the condition selection box (including " .. color.CYAN .. L["Switch"] .. color.RESET ..
            " conditions)."))

    group:AddChild(Gap())
    local directional_group = AceGUI:Create("SimpleGroup")
    directional_group:SetFullWidth(true)
    directional_group:SetLayout("Table")
    directional_group:SetUserData("table", { columns = { 50, 1 } })
    group:AddChild(directional_group)

    local directional = AceGUI:Create("Directional")
    directional_group:AddChild(directional)

    directional_group:AddChild(CreateText(color.BLIZ_YELLOW .. "Order" .. color.RESET .. " - " ..
            "Change the order of the selected condition, moving it in the direction indicated by the arrow."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Move To"] .. color.RESET .. " - " ..
            "Move the selected condition to another condition group.  You cannot move a condition to the " ..
            color.GREEN .. ALL .. color.RESET .. " or " .. color.CYAN .. L["Switch"] .. color.RESET .. " groups."))
end
