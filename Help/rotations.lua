local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local AceGUI = LibStub("AceGUI-3.0")
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, Indent, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.Indent, helpers.Gap

local function help_top_buttons(group, singular, plural)
    group:AddChild(CreateText(color.BLIZ_YELLOW .. NAME .. color.RESET .. " - " ..
            "This field is activated by the checkbox immediately preceeding it.  This field is aesthetic only " ..
            "and allows you to identify this " .. singular .. " in the list of " .. plural .. ".  If the checkbox " ..
            "is not set the " .. singular .. " name will be set to the name of the spell or item set or first item " ..
            "in a custom item set automatically, and will change automatically as they do."))

    group:AddChild(CreatePictureText(
        "Interface\\AddOns\\RotationMaster\\textures\\UI-ChatIcon-ScrollHome-Up", 24, 24,
        color.BLIZ_YELLOW .. L["Move to Top"] .. color.RESET .. " - " ..
            "This will move the current " .. singular .. " to the first slot in the " .. singular .. " list."))

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up", 24, 24,
        color.BLIZ_YELLOW .. L["Move Up"] .. color.RESET .. " - " ..
            "This will move the current " .. singular .. " up to the previous slot in the " .. singular .. " list."))

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up", 24, 24,
        color.BLIZ_YELLOW .. L["Move Down"] .. color.RESET .. " - " ..
            "This will move the current " .. singular .. " down to the next slot in the " .. singular .. " list."))

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up", 24, 24,
        color.BLIZ_YELLOW .. L["Move to Bottom"] .. color.RESET .. " - " ..
            "This will move the current " .. singular .. " to the last slot in the " .. singular .. " list."))

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-Maximize-Up", 24, 24,
        color.BLIZ_YELLOW .. L["Duplicate"] .. color.RESET .. " - " ..
            "Duplicates this " .. singular .. ", putting the duplicate immediately after the duplicated entry."))

    group:AddChild(CreatePictureText(
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", 24, 24,
        color.BLIZ_YELLOW .. DELETE .. color.RESET .. " - " ..
            "Removes this " .. singular .. " from the " .. singular .. " list entirely.  This action is permanent."))
end

local function help_effect_group(group, singular)
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Effect"] .. color.RESET .. " - " ..
            "How the " .. singular .. " should be highlighted.  This selection can be updated in the " ..
            color.BLUE .. L["Effects"] .. color.RESET .. " configuration screen.  A value of " .. color.GREEN ..
            DEFAULT .. color.RESET .. " will use the highlight style set in the primary Rotation Master settings."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Magnification"] .. color.RESET .. " - " ..
            "How much bigger or smaller than the spell action icon should the " .. singular .. " highlight be.  " ..
            "This value is simply multiplied by the size of the action icon.  So a 1.0 value would be the same " ..
            "size as the action icon.  If this is set to the same value as the primary Rotation Master setting " ..
            "it will track that setting."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Highlight Color"] .. color.RESET .. " - " ..
            "The color and alpha value (ie. opacity) to apply to the " .. singular .. " highlight.  This defaults " ..
            "to green."))

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
end

local function help_action_group(group, singular)
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Action Type"] .. color.RESET .. " - " ..
            "The type of action to highlight on your action bars."))

    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Spell"] .. color.RESET .. " - " ..
            "This will limit the avalable options to only spells you can cast (ie. what is in your spell book) " ..
            "for your specialization.  Often spells you crrently can not cast (eg. those for another a different " ..
            "specialization, or that require talnts) are hidden.  This is a restriction imposed by the game.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Pet Spell"] .. color.RESET .. " - " ..
            "This will limit the avalable options to only spells your pets cast (ie. what is in your pet spell book). " ..
            "Often spells you crrently can not cast (eg. those for a different different pet than the one you " ..
            "have summoned) are hidden.  This is a restriction imposed by the game.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Any Spell"] .. color.RESET .. " - " ..
            "This is similar to Spell, however it is not limited to spells you can cast.  This is rarely needed, " ..
            "but could be used for spells you have not yet learned.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Item"] .. color.RESET .. " - " ..
            "An item you are carrying OR wearing.  Only items that have a USE ability will be available.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["None"] .. color.RESET .. " - " ..
            "No action.  This can be used to suspend the rotation under certain circumstances (eg. that one " ..
            "of multiple cooldowns have been applied).")))

    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        group:AddChild(Gap())
        group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Rank"] .. color.RESET .. " - " ..
                "If enabled, use a specific rank of the spell in question.  This is normally only used for " ..
                "things like downranking spells.  Note that this requires that specific rank of the spell in " ..
                "question being on your action bars (as opposed to any rank if this is disabled.)"))
    end

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Spell"] .. color.RESET .. " - " ..
            "The spell to highlight on your action bars.  If this spell is not on your action bars, then this " ..
            singular .. " will be skipped entirely.  You may drag this spell from your spell book or action bars " ..
            "into the input field or spell icon to set this value.  This input field has prediction enabled, " ..
            "so you do not have to type the full spell name, just select from the prediction frame when it appears."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Item Set"] .. color.RESET .. " - " ..
            "This is a list of items to look for on your action bars.  This list is ordered, the top found item " ..
            "in the list that you are carrying or wearing is what will be looked for on your action bars.  NOTE: " ..
            "this will NOT highlight the first one in the list that is on your action bars, so if you are carring " ..
            "something higher on the list in your bags, but have not put it on your action bars, the item that " ..
            "is on your action bars (but lower down the list) will NOT be highlighted."))
    group:AddChild(CreateText("You can choose from either a pre-defined Item Set, by picking it by name from the " ..
            "drop down menu.  You can edit these using the " .. color.BLUE .. L["Item Sets"] .. color.RESET ..
            "configuration menu.  Any item set in " .. color.CYAN .. "cyan" .. color.RESET .. " is a global " ..
            "item set available to all your characters, otherwise they are available to this character only.  " ..
            "If you do not want to setup a reusable item set, you can select " .. color.GREEN .. L["Custom"] ..
            color.RESET .. " to specify an ad-hoc item set."))

    group:AddChild(CreatePictureText(
            "Interface\\FriendsFrame\\UI-FriendsList-Large-Up", 24, 24,
            color.BLIZ_YELLOW .. EDIT .. color.RESET .. " - " ..
            "Edit the contents of the item set.  If you have selected a " ..
            "pre-defind item set, you will be editing that item set, which may effect other usages of that " ..
            "item set (including on your other characters if it is a global item set.  An item set must have " ..
            "at least one item in it for this " .. singular .. " to be considered valid."))

end

local function help_conditions(group, singular)
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Conditions"] .. color.RESET .. " - " ..
            "A human readable version of the conditions that control if this " .. singular .. " is active or " ..
            "not.  If this condition fails, it will be skipped.  If you have live updating enabled in the " ..
            "primary Rotation Master settings, you will see either " .. color.GREEN .. L["Currently satisfied"] ..
            color.RESET .. " or " .. color.RED .. L["Not currently satisfied"] .. color.RESET .. " after the " ..
            "human readable version of this condition for any non-disabed condition.  Any disabled condition " ..
            "will instead show " .. color.RED .. L["Disabled"] .. color.RESET .. "."))

    group:AddChild(Indent(40, CreatePictureText(
            "Interface\\FriendsFrame\\UI-FriendsList-Large-Up", 24, 24,
            color.BLIZ_YELLOW .. EDIT .. color.RESET .. " - " ..
            "Open up a window to allow editing of the condition for this " .. singular .. ".")))
    group:AddChild(Indent(40, CreatePictureText(
            "Interface\\Buttons\\UI-GroupLoot-Pass-Up", 24, 24,
            color.BLIZ_YELLOW .. L["Disabled"] .. color.RESET .. " - " ..
            "This " .. singular .. " is disabled, and will be excluded from the rotation.  Click " ..
            "this icon to re-enable this " .. singular .. " step.")))
    group:AddChild(Indent(40, CreatePictureText(
            "Interface\\CharacterFrame\\UI-Player-PlayTimeUnhealthy", 24, 24,
            color.BLIZ_YELLOW .. L["Invalid"] .. color.RESET .. " - " ..
            "This " .. singular .. " is disabled, and will be excluded from the rotation.  Click " ..
            "this icon to disable this " .. singular .. " step.")))
    group:AddChild(Indent(40, CreatePictureText(
            "Interface\\RaidFrame\\ReadyCheck-Ready", 24, 24,
            color.BLIZ_YELLOW .. L["Currently satisfied"] .. color.RESET .. " - " ..
            "This " .. singular .. " step's conditions are currently satisfied by game conditions. " ..
            "Click this icon to disable this " .. singular .. " step.")))
    group:AddChild(Indent(40, CreatePictureText(
            "Interface\\RaidFrame\\ReadyCheck-NotReady", 24, 24,
            color.BLIZ_YELLOW .. L["Not currently satisfied"] .. color.RESET .. " - " ..
            "This " .. singular .. " step's conditions are not currently satisfied by game conditions. " ..
            "Click this icon to disable this " .. singular .. " step.")))
    group:AddChild(Indent(40, CreatePictureText(
            "Interface\\RaidFrame\\ReadyCheck-Waiting", 24, 24,
            color.BLIZ_YELLOW .. "Off-Spec" .. color.RESET .. " - " ..
            "This " .. singular .. " step's conditions cannot be evaluated due to it being for a " ..
            "different spec.  Click this icon to disable this " .. singular .. " step.")))
end

function addon.layout_cooldown_help(frame)
    local group = frame
    group:AddChild(CreateText(
        "Cooldowns are used to highlight spells or items that can be activated at any time during your " ..
        "rotation, but are not necessarily part of it.  This is ideal for things such as spells with " ..
        "long cooldowns that should be activated only at crutial parts of a fight, or mana/health potions " ..
        "that should be used when you are critically low. Unlike rotation spells, the order of cooldowns " ..
        "makes no difference.  Any amount of your cooldowns (including zero or all) can be active at " ..
        "once."))

    group:AddChild(Gap())
    group:AddChild(CreateText("Fields", "Interface\\AddOns\\RotationMaster\\Fonts\\Inconsolata-Bold.ttf", 16))

    group:AddChild(Gap())
    help_top_buttons(group, "cooldown", "cooldowns")

    group:AddChild(Gap())
    help_effect_group(group, "cooldown", "cooldowns")

    group:AddChild(Gap())
    help_action_group(group, "cooldown", "cooldowns")

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Announce"] .. color.RESET .. " - " ..
            "This will announce that your cooldown is available in the manner you specify.  The cooldown is " ..
            "only announced when it becomes available after previously not being available."))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["None"] .. color.RESET .. " - " ..
            "Do not announce cooldowns at all.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Raid or Party"] .. color.RESET .. " - " ..
            "Announce to all memebers of your raid or party (detected automatically).")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Party Only"] .. color.RESET .. " - " ..
            "Announce to all party only, even if you are in a raid.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Raid Warning"] .. color.RESET .. " - " ..
            "Announce to the raid as a raid warning (usually shows up in the middle of everyone's screen).")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Emote"] .. color.RESET .. " - " ..
            "Announce using /emote (showing up as an action you are performing)")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Local Only"] .. color.RESET .. " - " ..
            "Announce only to your chat frame (nobody else will see it).")))

    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Sound Alert"] .. color.RESET .. " - " ..
            "This will make an audible alert when your cooldown becomes available.  The cooldown is " ..
            "only alerted when it becomes available after previously not being available."))

    group:AddChild(Gap())
    help_conditions(group, "cooldown", "cooldowns")
end

function addon.layout_rotation_help(frame)
    local group = frame

    group:AddChild(CreateText(
        "Rotations are used to highlight spells or items in order of priority (ie. the higher up the rotation " ..
        "it is, the more preferential it is to highlight it).  This highlighting is subject to both the " ..
        "conditions present with each rotation, and the usability of the spell or item (including taking " ..
        "into account available mana and range to target unless these are disabled in the primary Rotation " ..
        "Master settings.)  A maximum of one rotation highlight may be active at any time."))

    group:AddChild(Gap())
    group:AddChild(CreateText("Fields", "Interface\\AddOns\\RotationMaster\\Fonts\\Inconsolata-Bold.ttf", 16))

    group:AddChild(Gap())
    help_top_buttons(group, "rotation", "rotations")

    group:AddChild(Gap())
    help_action_group(group, "rotation", "rotations")

    group:AddChild(Gap())
    help_conditions(group, "rotation", "rotations")
end
