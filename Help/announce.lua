local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, Indent, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.Indent, helpers.Gap

function addon.layout_announce_options_help(frame)
    local group = frame

    group:AddChild(CreateText(
        "Announces allow you to announce when you cast certain spells or use certain items.  These announcements " ..
        "can be customized and the destination for these announcmeents can be of your choosing.  These " ..
        "announcements have no relation to any rotation, and this feature is merely a convenience feature to " ..
        "save you from creating macros for each spell.  Additionally these announcements work well with items (and " ..
        "thus item sets)."))

    group:AddChild(Gap())
    group:AddChild(CreateText("Fields", "Interface\\AddOns\\" .. addon_name .. "\\Fonts\\Inconsolata-Bold.ttf", 16))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Action Type"] .. color.RESET .. " - " ..
            "The type of action that triggers an announcement."))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Spell"] .. color.RESET .. " - " ..
            "You have cast a spell.  This must be a spell YOU can cast, NOT a pet's spell.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Pet Spell"] .. color.RESET .. " - " ..
            "Your pet has cast a spell.  This must be a spell your pet can cast.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Item"] .. color.RESET .. " - " ..
            "You have used an item in an item set (either a pre-defined one or custom item set.)")))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Spell"] .. color.RESET .. " - " ..
            "The spell that will trigger the announcement. You may drag this spell from your spell book or action " ..
            "bars into the input field or spell icon to set this value.  This input field has prediction enabled, " ..
            "so you do not have to type the full spell name, just select from the prediction frame when it appears."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Item Set"] .. color.RESET .. " - " ..
            "This is a list of items that will trigger the announcement.  Using ANY item in this list will " ..
            "trigger the announcement.  This differs from how item sets are used in either rotations or when " ..
            "put onto your action bars, where only the top entry in the list that you have (in your bags or " ..
            "are wearing) will be used, regardless of if you are carrying other items in the list."))
    group:AddChild(CreateText("You can choose from either a pre-defined Item Set, by picking it by name from the " ..
            "drop down menu.  You can edit these using the " .. color.BLUE .. L["Item Sets"] .. color.RESET ..
            "configuration menu.  Any item set in " .. color.CYAN .. "cyan" .. color.RESET .. " is a global " ..
            "item set available to all your characters, otherwise they are available to this character only.  " ..
            "If you do not want to setup a reusable item set, you can select " .. color.GREEN .. L["Custom"] ..
            color.RESET .. " to specify an ad-hoc item set."))

    group:AddChild(Indent(40, CreatePictureText(
            "Interface\\FriendsFrame\\UI-FriendsList-Large-Up", 24, 24,
            color.BLIZ_YELLOW .. EDIT .. color.RESET .. " - " ..
             "Edit the contents of the item set.  If you have selected a " ..
            "pre-defind item set, you will be editing that item set, which may effect other usages of that " ..
            "item set (including on your other characters if it is a global item set.")))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Event"] .. color.RESET .. " - " ..
            "What action should trigger the event."))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Started"] .. color.RESET .. " - " ..
            "You have begun to cast the spell or use the item.  This happens at the beginning of the cast, and " ..
            "does not factor in if this cast was successful or not.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Stopped"] .. color.RESET .. " - " ..
            "The casting of the spell or usage of the item has completed.  Regardless of the method of completion " ..
            "(which could mean it failed, was interruped, or was successful.)  This is most useful for channeling " ..
            "spells.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Succeeded"] .. color.RESET .. " - " ..
            "The cast of the spell or item use was successful.  If this is a channeled spell, this will be " ..
            "triggered when the spell begins channeling.  This is the default and most common.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. L["Interrupted"] .. color.RESET .. " - " ..
            "The cast of the spell or use of the item was interruped.  This could be interrupted by you (ie. " ..
            "aborting your cast) or by having your cast being interrupted by being attacked.")))

    group:AddChild(Gap())
    group:AddChild(CreatePictureText(
            "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", 24, 24,
            color.BLIZ_YELLOW .. DELETE .. color.RESET .. " - " ..
                    "Permanently delete this announcement."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Announce"] .. color.RESET .. " - " ..
            "How do you wish this announcement to be made."))
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

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Text"] .. color.RESET .. " - " ..
            "The text of the announcement you wish to make.  Certain substitutions may be used to augment your " ..
            "announcement."))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "{{spell}}" .. color.RESET .. " - " ..
            "The name of the spell being cast.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "{{item}}" .. color.RESET .. " - " ..
            "The name of the item being used.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "{{event}}" .. color.RESET .. " - " ..
            "The event (as identified above) that has happened.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "{{target}}" .. color.RESET .. " - " ..
            "Your current target's name, or your own name if you do not have a target selected.")))

    group:AddChild(Gap())
    group:AddChild(CreatePictureText(
            "Interface\\Buttons\\UI-CheckBox-Check", 24, 24,
            color.BLIZ_YELLOW .. L["Enabled"] .. color.RESET .. " - " ..
                    "This announcement is active."))
    group:AddChild(CreatePictureText(
            "Interface\\Buttons\\UI-GroupLoot-Pass-Up", 24, 24,
            color.BLIZ_YELLOW .. L["Disabled"] .. color.RESET .. " - " ..
                    "This announcement is not active."))
end
