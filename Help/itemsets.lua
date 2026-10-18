local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, Indent, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.Indent, helpers.Gap

function addon:GetDocument_layout_item_list_help()
    return addon:SettingsHelpSections({
color.BLIZ_YELLOW .. L["Item"] .. color.RESET .. " - " ..
        "An item you may be carrying or wearing.  Items may be added by name (auto completion will occur " ..
        "for any item you are currently carrying), by item ID (if you know it from a place such as WowHead), " ..
        "or by dragging the item from your bags into the input box or the icon field to the left of it.  " ..
        "Clearing the item field will implicitly delete it from the list.  The item's icon will not show " ..
        "if the item is entered by name and you are noit currently carrying it, however the item is still " ..
        "a valid part of the item set and will work if picked up at a later time.",
color.BLIZ_YELLOW .. L["Move to Top"] .. color.RESET .. " - " ..
                "This will move the current item to the first slot in the item list.",
color.BLIZ_YELLOW .. L["Move Up"] .. color.RESET .. " - " ..
                "This will move the current item up to the previous slot in the item list.",
color.BLIZ_YELLOW .. L["Move Down"] .. color.RESET .. " - " ..
                "This will move the current item down to the next slot in the item list.",
color.BLIZ_YELLOW .. L["Move to Bottom"] .. color.RESET .. " - " ..
                "This will move the current item to the last slot in the item list.",
color.BLIZ_YELLOW .. (DELETE or L['Delete']) .. color.RESET .. " - " ..
                "Removes this item from the item list entirely.  This action is permanent."
    })
end
function addon.layout_item_list_help(frame)
    for _,entry in ipairs(addon:GetDocument_layout_item_list_help()) do frame:AddChild(Gap());frame:AddChild(CreateText((entry.title~='' and color.BLIZ_YELLOW..entry.title..color.RESET..' - ' or '')..entry.text)) end
end

function addon:GetDocument_layout_itemsets_options_help()
    return addon:SettingsHelpSections({
"Item Sets are ordered lists of items that, when used, are checked against your current inventory " ..
        "and what you have equipped.  The first item found is then used (for example checked aginst item-based " ..
        "conditions, or highliged on yor action bars.  Once an item is found, Rotation Master does not check " ..
        "for any remaining items.  This is useful to keep lists of 'mostly equivalent' items that come in " ..
        "slightly different strengths or varieties (eg. mana potions, conjured food, etc).  Item sets can " ..
        "be bound directly to your action bars, and will be automatically updated as you acquire or use items " ..
        "in the item list.",
color.BLIZ_YELLOW .. L["Item Set"] .. color.RESET .. " - " ..
        "Select which item set you wish to work on from the drop down menu.  You can create a new item set by " ..
        "selecting " .. color.GREEN .. (NEW or L['New']) .. color.RESET .. ".  The default action when selecting then " ..
        "Item Sets configuration menu is to create a new set.",
"The icon next to the item set name will automatically update to display the item that is currently " ..
        "selected by this item set.  Click this icon to pick it up so it can be dragged onto your action bars. " ..
        "When you bind an item set to your action bars, it will be updated automatically based on the " ..
        "availability of items in the item set.",
color.BLIZ_YELLOW .. (NAME or L['Name']) .. color.RESET .. " - " ..
        "The name for this item set.  This name will be used in any dropdown menu listing item sets.  An item " ..
        "set may not be modified until it has a name.",
color.BLIZ_YELLOW .. L["Global"] .. color.RESET .. " - " ..
        "If set, this item set will be availbale on all of your characters.  Otherwise is is character " ..
        "specific.  Global item sets show up in " .. color.CYAN .. "cyan" .. " when referenced.",
color.BLIZ_YELLOW .. (RESET or L['Reset']) .. color.RESET .. " - " ..
            "Reset this item set to the default one that comes with Rotation Master.",
color.BLIZ_YELLOW .. L["Import/Export"] .. color.RESET .. " - " ..
            "This will open up a window that can be used to both export " ..
            "your current item set and import one created by someone else.",
color.BLIZ_YELLOW .. L["Duplicate"] .. color.RESET .. " - " ..
                    "Duplicates this item set putting the duplicate immediately after the duplicated entry.",
color.BLIZ_YELLOW .. (DELETE or L['Delete']) .. color.RESET .. " - " ..
            "Delete this item set permanently.  If this item set is in use by " ..
            "any rotation on this character, you will be prompted to ensure this was nor performed in error.",
"Use with Macros",
"Item sets can be used in other contexts.  A number of hidden buttons are created " ..
            "that can be accessed (for example inside a macro) using " .. color.MAGENTA .. "/click <button>" ..
            color.RESET .. ".  The name of these hidden buttons is 'RM_' concatinated with the name of the " ..
            "item set (with all non-alphanumeric character stripped out) concatinated with '_<target>'.  " ..
            "So the item 'Mana Potions' would have names like RM_ManaPotions_player.",
"For an item set called Bandages, the hidden buttons would be:",
color.GREEN .. "RM_Bandages_player" .. color.RESET ..
            " This will use the highest level item in the item set on yourself.",
color.GREEN .. "RM_Bandages_pet" .. color.RESET ..
            " This will use the highest level item in the item set on your pet.",
color.GREEN .. "RM_Bandages_target" .. color.RESET ..
            " This will use the highest level item in the item set on your target.",
color.GREEN .. "RM_Bandages_focus" .. color.RESET ..
                " This will use the highest level item in the item set on your focus target.",
color.GREEN .. "RM_Bandages_mouseover" .. color.RESET ..
            " This will use the highest level item in the item set on the character or unit frame your mouse " ..
            "is hovering over.",
color.GREEN .. "RM_Bandages_pettarget" .. color.RESET ..
            " This will use the highest level item in the item set on your pet's target.",
color.GREEN .. "RM_Bandages_targetargett" .. color.RESET ..
            " This will use the highest level item in the item set on your target's target.",
color.GREEN .. "RM_Bandages_focustarget" .. color.RESET ..
                " This will use the highest level item in the item set on your focus target's target.",
color.GREEN .. "RM_Bandages_mouseovertarget" .. color.RESET ..
            " This will use the highest level item in the item set on the character or unit frame your mouse " ..
            "is hovering over's target.",
"An example usage of this might be to create a macro like this:",
color.MAGENTA .. "/click [@mouseover,nodead,help] RM_Bandages_mouseover" ..
            color.RESET,
"In the above example, the macro is 'checking' that your mouseover target " ..
            "is not dead and is an ally, and if so, invoking the hidden button that calls /use on the first " ..
            "found item in the item set with a target of your mouseover target.",
"This functionaliy is not related to action bar bindings."
    })
end
function addon.layout_itemsets_options_help(frame)
    for _,entry in ipairs(addon:GetDocument_layout_itemsets_options_help()) do frame:AddChild(Gap());frame:AddChild(CreateText((entry.title~='' and color.BLIZ_YELLOW..entry.title..color.RESET..' - ' or '')..entry.text)) end
end

