local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local AceGUI = LibStub("AceGUI-3.0")
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, Indent, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.Indent, helpers.Gap

function addon.layout_primary_options_help(frame)
    local group = frame

    group:AddChild(CreateText(
            "Rotation Master is a mod that will try and help you know what the optimal action bar button to " ..
                    "press is in combat situations.  It allows for you to create situationally distinct rotations, " ..
                    "rotations that are different for different rotations, and supports item sets (lists of items " ..
                    "in priority order, for things such as mana potions, etc)."))

    group:AddChild(Gap())
    group:AddChild(CreateText("Fields", "Interface\\AddOns\\RotationMaster\\Fonts\\Inconsolata-Bold.ttf", 16))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. ENABLE .. color.RESET .. " - " ..
            "Allow Rotation Master to perform it's function.  Unckecking this will remove all highlighting, " ..
            "prevent rotation switching and no longer update bound item sets."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Polling Interval (seconds)"] .. color.RESET .. " - " ..
        "How often should Rotation Master check all cooldowns and rotation steps in the currently active " ..
        "rotation to adjust which cooldowns should be highlighted and which rotation step should be active.  " ..
        "The lower this value, the more frequent updates will be made, but also the higher the performance " ..
        "impact will be.  As human response time is generally not much better than 0.25 seconds, setting this " ..
        "too low has no practical impact."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Disable Auto-Switching"] .. color.RESET .. " - " ..
            "Prevent Rotation Master from automatically switching to a different rotation based on it's switch " ..
            "conditions.  This can also be achieved by manually switching to a rotation with the " .. color.MAGENTA ..
            "/rm set <rotation>" .. color.RESET .. " command, however this option is persistent through UI reloads."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Live Status Update Frequency (seconds)"] .. color.RESET .. " - " ..
            "How often should we check cooldown or rotation step conditions (while the configuration menu is " ..
            "open) to update the " .. color.GREEN .. L["Currently satisfied"] .. color.RESET .. " or " .. color.RED ..
            L["Not currently satisfied"] .. color.RESET .. " message to allow for easier condition editing.  If " ..
            "this is set to 0, updaing this condition status will be disabled."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Minimap Icon"] .. color.RESET .. " - " ..
        "Should a Rotation Master icon be added to the border of the minimap.  Left-clicking the minimap icon " ..
        "will open the Rotation Master settings.  Right-clicking will give a mini-menu that allows both enabling " ..
        "and disabling Rotation Master, and switching rotations"))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Spell History Memory (seconds)"] .. color.RESET .. " - " ..
        "Some conditions use spell cast history as part of their evaluation.  This adjusts how long to remember " ..
        "all previous spell casts for."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Ignore Mana"] .. color.RESET .. " - " ..
        "As conditions are evaluated for cooldowns or rotation steps Rotation Master will check to ensure you " ..
        "currently have enough mana to cast the spell in question.  If not, that cooldown will not be active or " ..
        "rotation step will be skipped.  Enabling this option will skip the mana check and allow the spell to " ..
        "be highlighted even if you currently do not have enough mana to cast it."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Combat History Memory (seconds)"] .. color.RESET .. " - " ..
            "Some conditions use combat history as part of their evaluation (eg. if you were parried, hit, etc).  " ..
            "This adjusts how long to remember your combat history for."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Ignore Range"] .. color.RESET .. " - " ..
        "While evaluating rotation steps, Rotation Master will check to ensure your target is in range of the " ..
        "rotation spell.  Enabling this option will skip this check and allow highlighting the spell even if " ..
        "the target is out of range."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Damage History Memory (seconds)"] .. color.RESET .. " - " ..
        "How long to remember the heals and damage for units in your vacinity.  This is used in the burn rate " ..
        "calculation (ie. dps or hps) on a unit, which is in turn used for Time to Die style calculations.  " ..
        "Newer DPS or heals are given more weight than older DPS or heals in a burn rate calculation."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Effect"] .. color.RESET .. " - " ..
        "How a rotation step should be highlighted (and the default for cooldowns).  This selection can be " ..
        "updated in the " .. color.BLUE .. L["Effects"] .. color.RESET .. " configuration screen."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Magnification"] .. color.RESET .. " - " ..
        "How much bigger or smaller than the spell action icon should the cooldown or rotation step highlight " ..
        "be.  This value is simply multiplied by the size of the action icon.  So a 1.0 value would be the " ..
        "same size as the action icon."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Highlight Color"] .. color.RESET .. " - " ..
        "The color and alpha value (ie. opacity) to apply to the rotation step highlight."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Position"] .. color.RESET .. " - " ..
        "The anchor position on the spell action icon for the highlight.  This is only valid if the highlight " ..
        "is a texture (see the " .. color.BLUE .. L["Effects"] .. color.RESET .. " configuration screen to see " ..
        "what type of highlight the effect is.)  The highlight is always anchored at it's center"))

    group:AddChild(Gap())
    local directional_group = AceGUI:Create("SimpleGroup")
    directional_group:SetFullWidth(true)
    directional_group:SetLayout("Table")
    directional_group:SetUserData("table", { columns = { 50, 1 } })
    group:AddChild(directional_group)

    local directional = AceGUI:Create("Directional")
    directional_group:AddChild(directional)

    directional_group:AddChild(CreateText(color.BLIZ_YELLOW .. "Offset" .. color.RESET .. " - " ..
        "For texture glows, this will offset the anchor point of the highlight.  Left and Right arrows will " ..
        "offset the X axis, and Up and Down arrows will offset the Y axis.  The center button will reset the " ..
        "offset back to the anchor point.  For non-texture highlights, which don't have an anchor point, this " ..
        "functions somewhat like magnification, controlling how much wider (X axis) or taller (Y axis) the " ..
        "highlight will appear compared to the action icon."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. "X" .. color.RESET .. " / " ..
        color.BLIZ_YELLOW .. "Y" .. color.RESET .. " - " ..
        "A display for the X and Y axis offsets controlled by the " .. color.BLUE .. "Offset" .. color.RESET ..
        " control."))

    if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT >= 2 then
        group:AddChild(Gap())
        group:AddChild(CreateText(color.BLIZ_YELLOW .. PRIMARY .. color.RESET .. " - " ..
            "The name we use for your primary specialization (as shown in the tabs for in the " ..
            "rotation editing screen)."))
        group:AddChild(CreateText(color.BLIZ_YELLOW .. SECONDARY .. color.RESET .. " - " ..
                "The name we use for your secondary specialization (as shown in the tabs for in the " ..
                "rotation editing screen)."))
    end

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Log Level"] .. color.RESET .. " - " ..
        "The of information that Rotation Master will put into your chat text box."))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Quiet"] .. color.RESET .. " - " ..
        "No output from Rotation Master at all.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. DEFAULT .. color.RESET .. " - " ..
            "Normal output about when Rotation Master switches rotation profiles.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Debug"] .. color.RESET .. " - " ..
            "Some information about runtime statistics and when certain trigger events happen.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Verbose"] .. color.RESET .. " - " ..
            "Detailed information about evaluation of conditions for highlighting buttons.")))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Detailed Profiling"] .. color.RESET .. " - " ..
            "Should the profiling statistics (visible in debug mode) contain extra information about " ..
            "components of evaluating rotation settings (as opposed to just the overall statistics)."))
end

function addon.layout_rotation_options_help(frame)
    local group = frame

    group:AddChild(CreateText(
        "A rotation is a set of cooldown and step-by-step rotation spells that can encompass a specific style " ..
        "of play (for example single target vs. area of effect DPS) that can be activated either automaatically " ..
        "via. a current circumstances or manually."))

    if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or LE_EXPANSION_LEVEL_CURRENT >= 2) then
        group:AddChild(CreateText(
            "Rotations are separated by specializations.  A rotation will only be available when in the " ..
            "specialization in which it is defined.  You can modify rotations from other specializations " ..
            "by selecting that specialization tab."))
    end

    group:AddChild(Gap())
    group:AddChild(CreateText("Fields", "Interface\\AddOns\\RotationMaster\\Fonts\\Inconsolata-Bold.ttf", 16))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Rotation"] .. color.RESET .. " - " ..
        "Select which rotation you wish to work on from the drop down menu.  You can create a new rotation by " ..
        "selecting " .. color.GREEN .. NEW .. color.RESET .. ".  A rotation called " .. color.GREEN .. DEFAULT ..
        color.RESET .. " always exists and is used when no other rotation can be automatically switched to."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. NAME .. color.RESET .. " - " ..
        "The name to use to identify your rotation.  This is is used both aesthetically (ie. in the drop down and " ..
        "the message informing you of what rotation has been selected) and in the " .. color.MAGENTA ..
        "/rm set <rotation>" .. color.RESET .. " command.  You can not configure a rotation without a name, so " ..
        "upon selecting " .. color.GREEN .. NEW .. color.RESET .. " from the rotation dropdown menu, you must " ..
        "complete this name before you can configure it."))

    group:AddChild(Gap())
    group:AddChild(CreatePictureText(
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", 24, 24,
        color.BLIZ_YELLOW .. DELETE .. color.RESET .. " - " ..
        "Delete this rotation permanently.  You will be prompted to ensure " ..
        "this was not performed by accident.  However if confirmed, this action can not be undone."))

    group:AddChild(Gap())
    group:AddChild(CreatePictureText(
            "Interface\\FriendsFrame\\UI-FriendsList-Small-Up", 24, 24,
            color.BLIZ_YELLOW .. L["Import/Export"] .. color.RESET .. " - " ..
        "This will open up a window that can be used to both export " ..
        "your current roation and import one created by someone else.  Imported rotations are not checked for " ..
        "their suitability, but will fail to import if they are not valid.  If there is a name conflict with the " ..
        "imported rotation, it will be named by the date and time of import."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Switch Condition"] .. color.RESET .. " - " ..
        "A human readable versions of the conditions that control when this rotation will be automatically " ..
        "selected.  For the " .. color.GREEN .. DEFAULT .. color.RESET .. " rotation, no switch condition " ..
        "can be defined, it will be selected when no other rotation's switch condition is satisfied.  " ..
        "Any disabled rotation that has a valid switch condition will show " .. color.RED .. L["Disabled"] ..
        color.RESET .. " will be displayed after the human readable version of the condition."))

    group:AddChild(Indent(40, CreatePictureText(
            "Interface\\FriendsFrame\\UI-FriendsList-Large-Up", 24, 24,
            color.BLIZ_YELLOW .. EDIT .. color.RESET .. " - " ..
            "Open up a window to allow editing of the switch condition for this rotation.")))
    group:AddChild(Indent(40, CreatePictureText(
            "Interface\\Buttons\\UI-GroupLoot-Pass-Up", 24, 24,
            color.BLIZ_YELLOW .. L["Disabled"] .. color.RESET .. " - " ..
                    "Rotation Master will not automatically switch to this rotation.  Click this to enable " ..
                    "auto-switching to this rotation.")))
    group:AddChild(Indent(40, CreatePictureText(
            "Interface\\CharacterFrame\\UI-Player-PlayTimeUnhealthy", 24, 24,
            color.BLIZ_YELLOW .. L["Invalid"] .. color.RESET .. " - " ..
                    "Rotation Master cannot automatically switch to this rotation as the switch condition " ..
                    "is not valid. Click this to disable auto-switching for this rotation explicitly.")))
    group:AddChild(Indent(40, CreatePictureText(
            "Interface\\Buttons\\UI-CheckBox-Check", 24, 24,
            color.BLIZ_YELLOW .. L["Enabled"] .. color.RESET .. " - " ..
                    "Rotation Master will automatically switch to this rotation.  Click this to disable " ..
                    "auto-switching to this rotation.")))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Cooldowns"] .. color.RESET .. " - " ..
        "A list of cooldowns that can be highlighted while this rotation is active.  While the cooldowns are " ..
        "numbered, any or all of them may be highlighted at once.  A cooldown will be colored " .. color.GRAY ..
        "gray" .. color.RESET .. " if it is disabled, or " .. color.RED .. "red" .. color.RESET .. " if it " ..
        "is incomplete.  The name in the list is set in the cooldown details."))
    group:AddChild(Indent(40, CreatePictureText("Interface\\Minimap\\UI-Minimap-ZoomInButton-Up", 12, 12,
        color.BLIZ_YELLOW .. ADD .. color.RESET .. " - Add a new cooldown.")))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Rotations"] .. color.RESET .. " - " ..
            "A list of rotation setps that can be highlighted while this rotation is active.  These are evaluated " ..
            "in order, and only one rotation step can be active at once (the highest numbered step).  A rotation " ..
            "step will be colored " .. color.GRAY .. "gray" .. color.RESET .. " if it is disabled, or " .. color.RED ..
            "red" .. color.RESET .. " if it is incomplete.  The name in the list is set in the rotation step details."))
    group:AddChild(Indent(40, CreatePictureText("Interface\\Minimap\\UI-Minimap-ZoomInButton-Up", 12, 12,
        color.BLIZ_YELLOW .. ADD .. color.RESET .. " - Add a new rotation step.")))
end
