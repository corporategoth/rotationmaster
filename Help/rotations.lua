-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Help layouts for the cooldown and rotation step pages: layout_cooldown_help and layout_rotation_help, built from
-- shared sections (name and list-order buttons, highlight effect, action requirements, announce, conditions) that are
-- parameterized by the singular and plural noun ("cooldown", "rotation").
-- Loaded from RotationMaster.toc with the other Help/ files, after Help/common.lua (addon.help_funcs) and UI/. It only
-- builds help widgets and never reads rotation data. Many paragraphs here are plain English literals rather than
-- L[...] keys, so they are not localized.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs

local CreateText, CreatePictureText, Indent, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.Indent, helpers.Gap

-- ============================================================================
-- Shared sections
-- ============================================================================

-- Adds the help for the name field and the list-order buttons (move to top, up, down, to bottom, duplicate, delete)
-- for one kind of entry.
local function help_top_buttons(group, singular, plural)
    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. NAME
            .. color.RESET
            .. " - "
            .. "This field is activated by the checkbox immediately preceding it.  This field is aesthetic only "
            .. "and allows you to identify this "
            .. singular
            .. " in the list of "
            .. plural
            .. ".  If the checkbox "
            .. "is not set the "
            .. singular
            .. " name will be set to the name of the spell or item set or first item "
            .. "in a custom item set automatically, and will change automatically as they do."
    ))

    group:AddChild(CreatePictureText(
        "Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-ChatIcon-ScrollHome-Up",
        24,
        24,
        color.BLIZ_YELLOW
            .. L["Move to Top"]
            .. color.RESET
            .. " - "
            .. "This will move the current "
            .. singular
            .. " to the first slot in the "
            .. singular
            .. " list."
    ))

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up",
        24,
        24,
        color.BLIZ_YELLOW
            .. L["Move Up"]
            .. color.RESET
            .. " - "
            .. "This will move the current "
            .. singular
            .. " up to the previous slot in the "
            .. singular
            .. " list."
    ))

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
        24,
        24,
        color.BLIZ_YELLOW
            .. L["Move Down"]
            .. color.RESET
            .. " - "
            .. "This will move the current "
            .. singular
            .. " down to the next slot in the "
            .. singular
            .. " list."
    ))

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up",
        24,
        24,
        color.BLIZ_YELLOW
            .. L["Move to Bottom"]
            .. color.RESET
            .. " - "
            .. "This will move the current "
            .. singular
            .. " to the last slot in the "
            .. singular
            .. " list."
    ))

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-Maximize-Up",
        24,
        24,
        color.BLIZ_YELLOW
            .. L["Duplicate"]
            .. color.RESET
            .. " - "
            .. "Duplicates this "
            .. singular
            .. ", putting the duplicate immediately after the duplicated entry."
    ))

    group:AddChild(CreatePictureText(
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
        24,
        24,
        color.BLIZ_YELLOW
            .. DELETE
            .. color.RESET
            .. " - "
            .. "Removes this "
            .. singular
            .. " from the "
            .. singular
            .. " list entirely.  This action is permanent."
    ))
end

-- Adds the help for the highlight effect control of one kind of entry (the Default effect follows the General
-- settings). Callers pass a plural noun as well; it is not used here.
local function help_effect_group(group, singular)
    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. L["Effect"]
            .. color.RESET
            .. " - "
            .. "How the "
            .. singular
            .. " should be highlighted.  This selection can be updated in the "
            .. color.BLUE
            .. L["Effects"]
            .. color.RESET
            .. " configuration screen.  A value of "
            .. color.GREEN
            .. DEFAULT
            .. color.RESET
            .. " will use the highlight style set in the primary Rotation Master settings."
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. L["Magnification"]
            .. color.RESET
            .. " - "
            .. "How much bigger or smaller than the spell action icon should the "
            .. singular
            .. " highlight be.  "
            .. "This value is simply multiplied by the size of the action icon.  So a 1.0 value would be the same "
            .. "size as the action icon.  If this is set to the same value as the primary Rotation Master setting "
            .. "it will track that setting."
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. L["Highlight Color"]
            .. color.RESET
            .. " - "
            .. "The color and alpha value (ie. opacity) to apply to the "
            .. singular
            .. " highlight.  This defaults "
            .. "to green."
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. L["Position"]
            .. color.RESET
            .. " - "
            .. "The anchor position on the spell action icon for the highlight.  This is only valid if the highlight "
            .. "is a texture (see the "
            .. color.BLUE
            .. L["Effects"]
            .. color.RESET
            .. " configuration screen to see "
            .. "what type of highlight the effect is.)  The highlight is always anchored at it's center"
    ))

    group:AddChild(Gap())
    local directional_group = addon:CreateConditionGroup()
    directional_group:SetFullWidth(true)
    directional_group:SetLayout("Table")
    directional_group:SetUserData("table", { columns = { 50, 1 } })
    group:AddChild(directional_group)

    local directional = addon:CreateConditionPositionPad()
    directional:SetDisabled(true)
    directional_group:AddChild(directional)

    directional_group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. "Offset"
            .. color.RESET
            .. " - "
            .. "For texture glows, this will offset the anchor point of the highlight.  Left and Right arrows will "
            .. "offset the X axis, and Up and Down arrows will offset the Y axis.  The center button will reset the "
            .. "offset back to the anchor point.  For non-texture highlights, which don't have an anchor point, this "
            .. "functions somewhat like magnification, controlling how much wider (X axis) or taller (Y axis) the "
            .. "highlight will appear compared to the action icon."
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. "X"
            .. color.RESET
            .. " / "
            .. color.BLIZ_YELLOW
            .. "Y"
            .. color.RESET
            .. " - "
            .. "A display for the X and Y axis offsets controlled by the "
            .. color.BLUE
            .. "Offset"
            .. color.RESET
            .. " control."
    ))
end

-- Adds the help for the action fields of one kind of entry: automatic requirements (learned, usable, ready, in range,
-- on an action bar), the action type choices and their options. The plural noun callers pass is not used.
local function help_action_group(group, singular)
    group:AddChild(CreateText(
        L["Actions automatically require a learned spell or carried item, usable resources, cooldown readiness and valid range. Conditions can additionally test other actions."]
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        L["Actions must also be on an action bar: Rotation Master highlights an action by lighting the button that holds it, so a step or cooldown that no button holds is skipped, and its card shows an amber warning."]
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. L["Action Type"]
            .. color.RESET
            .. " - "
            .. "The type of action to highlight on your action bars."
    ))

    group:AddChild(Indent(40, CreateText(
        color.GREEN
            .. L["Spell"]
            .. color.RESET
            .. " - "
            .. "This will limit the available options to only spells you can cast (ie. what is in your spell book) "
            .. "for your specialization.  Often spells you currently cannot cast (eg. those for a different "
            .. "specialization, or that require talents) are hidden.  This is a restriction imposed by the game."
    )))

    group:AddChild(Indent(40, CreateText(
        color.GREEN
            .. L["Pet Spell"]
            .. color.RESET
            .. " - "
            .. "This will limit the available options to only spells your pets cast (ie. what is in your pet spell book). "
            .. "Often spells you currently cannot cast (eg. those for a different pet than the one you "
            .. "have summoned) are hidden.  This is a restriction imposed by the game."
    )))

    group:AddChild(Indent(40, CreateText(
        color.GREEN
            .. L["Any Spell"]
            .. color.RESET
            .. " - "
            .. L["Actions automatically require a learned spell or carried item, usable resources, cooldown readiness and valid range. Conditions can additionally test other actions."]
    )))

    group:AddChild(Indent(40, CreateText(
        color.GREEN
            .. L["Item"]
            .. color.RESET
            .. " - "
            .. "An item you are carrying OR wearing.  Only items that have a USE ability will be available."
    )))

    group:AddChild(Indent(40, CreateText(
        color.GREEN
            .. L["Blizzard's suggestion"]
            .. color.RESET
            .. " - "
            .. L["Recommends whatever spell Blizzard's Assisted Combat suggests next, read each time the rotation is evaluated. It highlights that spell's button and shows in the preview like a spell step, and is held to the same requirements: known, usable, off cooldown and in range. When nothing is suggested, the suggested spell is not on your bars, or Assisted Combat is unavailable (anywhere but Retail, or a specialization without it), the step is skipped. Rotation list only."]
    )))

    group:AddChild(Indent(40, CreateText(
        color.GREEN
            .. L["Stop"]
            .. color.RESET
            .. " - "
            .. L["Stop ends lower priority actions. The implicit auto-attack (Attack or Shoot) remains eligible unless you suppress it. An unavailable Stop condition also suppresses it. Optional reminders remain independent."]
    )))

    if addon:ClientHasSpellRanks() then
        group:AddChild(Gap())

        group:AddChild(CreateText(
            color.BLIZ_YELLOW
                .. L["Use this exact spell rank"]
                .. color.RESET
                .. " - "
                .. L["Unticked (the default), any rank of the spell matches. Ticked, only the rank you chose matches, and that rank must be on your action bars."]
        ))
    end

    group:AddChild(Gap())

    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. L["Spell"]
            .. color.RESET
            .. " - "
            .. "The spell to highlight on your action bars.  If this spell is not on your action bars, then this "
            .. singular
            .. " will be skipped entirely.  You may drag this spell from your spell book or action bars "
            .. "into the input field or spell icon to set this value.  This input field has prediction enabled, "
            .. "so you do not have to type the full spell name, just select from the prediction frame when it appears."
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. L["Item Set"]
            .. color.RESET
            .. " - "
            .. "This is a list of items to look for on your action bars.  This list is ordered, the top found item "
            .. "in the list that you are carrying or wearing is what will be looked for on your action bars.  NOTE: "
            .. "this will NOT highlight the first one in the list that is on your action bars, so if you are carrying "
            .. "something higher on the list in your bags, but have not put it on your action bars, the item that "
            .. "is on your action bars (but lower down the list) will NOT be highlighted."
    ))

    group:AddChild(CreateText(
        "You can choose from either a pre-defined Item Set, by picking it by name from the "
            .. "drop down menu.  You can edit these using the "
            .. color.BLUE
            .. L["Item Sets"]
            .. color.RESET
            .. "configuration menu.  Any item set in "
            .. color.CYAN
            .. "cyan"
            .. color.RESET
            .. " is a global "
            .. "item set available to all your characters, otherwise they are available to this character only.  "
            .. "If you do not want to set up a reusable item set, you can select "
            .. color.GREEN
            .. L["Custom"]
            .. color.RESET
            .. " to specify an ad-hoc item set."
    ))

    group:AddChild(CreatePictureText(
        "Interface\\FriendsFrame\\UI-FriendsList-Large-Up",
        24,
        24,
        color.BLIZ_YELLOW
            .. EDIT
            .. color.RESET
            .. " - "
            .. "Edit the contents of the item set.  If you have selected a "
            .. "pre-defined item set, you will be editing that item set, which may affect other usages of that "
            .. "item set (including on your other characters if it is a global item set).  An item set must have "
            .. "at least one item in it for this "
            .. singular
            .. " to be considered valid."
    ))
end

-- Adds the help for the conditions summary of one kind of entry, including the live satisfied/not satisfied marker.
-- The plural noun callers pass is not used.
local function help_conditions(group, singular)
    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. L["Conditions"]
            .. color.RESET
            .. " - "
            .. "A human readable version of the conditions that control if this "
            .. singular
            .. " is active or "
            .. "not.  If this condition fails, it will be skipped.  If you have live updating enabled in the "
            .. "primary Rotation Master settings, you will see either "
            .. color.GREEN
            .. L["Currently satisfied"]
            .. color.RESET
            .. " or "
            .. color.RED
            .. L["Not currently satisfied"]
            .. color.RESET
            .. " after the "
            .. "human readable version of this condition for any non-disabled condition.  Any disabled condition "
            .. "will instead show "
            .. color.RED
            .. L["Disabled"]
            .. color.RESET
            .. "."
    ))

    group:AddChild(Indent(40, CreatePictureText(
        "Interface\\FriendsFrame\\UI-FriendsList-Large-Up",
        24,
        24,
        color.BLIZ_YELLOW
            .. EDIT
            .. color.RESET
            .. " - "
            .. "Open up a window to allow editing of the condition for this "
            .. singular
            .. "."
    )))

    group:AddChild(Indent(40, CreatePictureText(
        "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
        24,
        24,
        color.BLIZ_YELLOW
            .. L["Disabled"]
            .. color.RESET
            .. " - "
            .. "This "
            .. singular
            .. " is disabled, and will be excluded from the rotation.  Click "
            .. "this icon to re-enable this "
            .. singular
            .. " step."
    )))

    group:AddChild(Indent(40, CreatePictureText(
        "Interface\\CharacterFrame\\UI-Player-PlayTimeUnhealthy",
        24,
        24,
        color.BLIZ_YELLOW
            .. L["Invalid"]
            .. color.RESET
            .. " - "
            .. "This "
            .. singular
            .. " is disabled, and will be excluded from the rotation.  Click "
            .. "this icon to disable this "
            .. singular
            .. " step."
    )))

    group:AddChild(Indent(40, CreatePictureText(
        "Interface\\RaidFrame\\ReadyCheck-Ready",
        24,
        24,
        color.BLIZ_YELLOW
            .. L["Currently satisfied"]
            .. color.RESET
            .. " - "
            .. "This "
            .. singular
            .. " step's conditions are currently satisfied by game conditions. "
            .. "Click this icon to disable this "
            .. singular
            .. " step."
    )))

    group:AddChild(Indent(40, CreatePictureText(
        "Interface\\RaidFrame\\ReadyCheck-NotReady",
        24,
        24,
        color.BLIZ_YELLOW
            .. L["Not currently satisfied"]
            .. color.RESET
            .. " - "
            .. "This "
            .. singular
            .. " step's conditions are not currently satisfied by game conditions. "
            .. "Click this icon to disable this "
            .. singular
            .. " step."
    )))

    group:AddChild(Indent(40, CreatePictureText(
        "Interface\\RaidFrame\\ReadyCheck-Waiting",
        24,
        24,
        color.BLIZ_YELLOW
            .. "Off-Spec"
            .. color.RESET
            .. " - "
            .. "This "
            .. singular
            .. " step's conditions cannot be evaluated due to it being for a "
            .. "different spec.  Click this icon to disable this "
            .. singular
            .. " step."
    )))
end

-- ============================================================================
-- Page layouts
-- ============================================================================

-- Lays out the cooldown help page: what cooldowns are, then the shared sections, plus the cooldown's own Announce
-- options.
function addon.layout_cooldown_help(frame)
    local group = frame

    group:AddChild(CreateText(
        "Cooldowns are used to highlight spells or items that can be activated at any time during your "
            .. "rotation, but are not necessarily part of it.  This is ideal for things such as spells with "
            .. "long cooldowns that should be activated only at crucial parts of a fight, or mana/health potions "
            .. "that should be used when you are critically low. Unlike rotation spells, the order of cooldowns "
            .. "makes no difference.  Any amount of your cooldowns (including zero or all) can be active at "
            .. "once."
    ))

    group:AddChild(Gap())
    group:AddChild(CreateText("Fields", "Interface\\AddOns\\" .. addon_name .. "\\Fonts\\Inconsolata-Bold.ttf", 16))

    group:AddChild(Gap())
    help_top_buttons(group, "cooldown", "cooldowns")

    group:AddChild(Gap())
    help_effect_group(group, "cooldown", "cooldowns")

    group:AddChild(Gap())
    help_action_group(group, "cooldown", "cooldowns")

    group:AddChild(Gap())

    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. L["Announce"]
            .. color.RESET
            .. " - "
            .. "This will announce that your cooldown is available in the manner you specify.  The cooldown is "
            .. "only announced when it becomes available after previously not being available."
    ))

    group:AddChild(Indent(40, CreateText(
        color.GREEN .. L["None"] .. color.RESET .. " - " .. "Do not announce cooldowns at all."
    )))

    group:AddChild(Indent(40, CreateText(
        color.GREEN
            .. L["Raid or Party"]
            .. color.RESET
            .. " - "
            .. "Announce to all members of your raid or party (detected automatically)."
    )))

    group:AddChild(Indent(40, CreateText(
        color.GREEN
            .. L["Party Only"]
            .. color.RESET
            .. " - "
            .. "Announce to all party only, even if you are in a raid."
    )))

    group:AddChild(Indent(40, CreateText(
        color.GREEN
            .. L["Raid Warning"]
            .. color.RESET
            .. " - "
            .. "Announce to the raid as a raid warning (usually shows up in the middle of everyone's screen)."
    )))

    group:AddChild(Indent(40, CreateText(
        color.GREEN
            .. L["Emote"]
            .. color.RESET
            .. " - "
            .. "Announce using /emote (showing up as an action you are performing)"
    )))

    group:AddChild(Indent(40, CreateText(
        color.GREEN
            .. L["Local Only"]
            .. color.RESET
            .. " - "
            .. "Announce only to your chat frame (nobody else will see it)."
    )))

    group:AddChild(CreateText(
        color.BLIZ_YELLOW
            .. L["Sound Alert"]
            .. color.RESET
            .. " - "
            .. "This will make an audible alert when your cooldown becomes available.  The cooldown is "
            .. "only alerted when it becomes available after previously not being available."
    ))

    group:AddChild(Gap())
    help_conditions(group, "cooldown", "cooldowns")
end

-- Lays out the rotation help page: what a rotation is, how one is chosen (priority, specializations, identifier, list
-- markers), the implicit auto-attack fallback, then the shared sections.
function addon.layout_rotation_help(frame)
    local group = frame

    group:AddChild(CreateText(
        "Rotations are used to highlight spells or items in order of priority (ie. the higher up the rotation "
            .. "it is, the more preferential it is to highlight it).  This highlighting is subject to both the "
            .. "conditions present with each rotation, and the usability of the spell or item (including taking "
            .. "into account available resources, cooldown and range). A maximum of one rotation highlight may be active at any time."
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        L["Choosing a rotation"],
        "Interface\\AddOns\\" .. addon_name .. "\\Fonts\\Inconsolata-Bold.ttf",
        16
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        L["Automatic switching tries the enabled rotations in priority order, yours and Built Ins alike: higher numbers are tried first, equal priorities by name. It picks the first that matches; a rotation with no switch condition always matches, so turn it off to keep it from being chosen. The fallback (Default) is used only when none matches. The rotation list is sorted in this same order and shows each priority."]
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        L["Each rotation says which specializations it is for, in the picker before its name: several, or Any. It is listed, in the minimap menu and for /rm set, only while you play one of them; its switch condition never hides it. Automatic switching checks the specialization first, then the switch condition, then priority; a rotation with no switch condition matches whenever its specialization and level apply, so priority alone decides; turn it off to keep it for choosing by hand. The specialization menu above the list's search box starts at the one you are playing; choose another, or All specializations, to see theirs. Where the game has dual specialization instead of named specializations (Classic Era, TBC, Wrath, Cataclysm and Forever), they are your primary and secondary talents: exports leave them out, and an import is for the talents the list shows."]
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        L["Priority sits beside Enabled at the top of the editor. A Built In cannot be edited, but its Enabled setting and priority are yours to change for this profile: they are saved at once, shown in amber when they differ from how it ships, and Reset to default puts it back. Copy a Built In to your rotations to edit anything else."]
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        L["A Built In shows a blue Read-Only pill in place of Undo and Redo; Duplicate makes your own copy. It loads only for the edition and class it was written for (the pill's tooltip). The specializations it is for show in the picker before its name; any level it needs is part of its switch condition. The switch's tooltip says when it can be selected together with another rotation, or is for another specialization."]
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        L["Every rotation has an identifier (ID), shown beside its priority: type /rm set <id> to choose it (any case), /rm set auto to go back to automatic switching, and /rm list to see every identifier. A Built In's identifier is fixed; yours is made from its name until you change it."]
    ))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        L["In the list, a red border means the rotation cannot be selected (the tooltip names why), gray means it is switched off, and an amber bar means it can be selected at the same time as another rotation (yours or Built In), so only priority decides between them; a wider bar means they also have the same priority and the name decides. /rm why lists the order and what automatic switching would choose now."]
    ))

    group:AddChild(Gap())
    group:AddChild(CreateText("Fields", "Interface\\AddOns\\" .. addon_name .. "\\Fonts\\Inconsolata-Bold.ttf", 16))

    group:AddChild(Gap())

    group:AddChild(CreateText(
        L["When no priority action is ready, auto-attack (Attack or Shoot) is the implicit final fallback against a living hostile target in combat: Attack in melee range; beyond it, Auto Shot or wand Shoot while the target is in range and that button is on your action bars. Nothing is recommended while that auto-attack is already running. It uses the normal rotation highlight and never presses a button."]
    ))

    group:AddChild(Gap())
    help_top_buttons(group, "rotation", "rotations")

    group:AddChild(Gap())
    help_action_group(group, "rotation", "rotations")

    group:AddChild(Gap())
    help_conditions(group, "rotation", "rotations")
end
