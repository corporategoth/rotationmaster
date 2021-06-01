local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local AceGUI = LibStub("AceGUI-3.0")
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, CreateButtonText, Indent, Gap =
helpers.CreateText, helpers.CreatePictureText, helpers.CreateButtonText, helpers.Indent, helpers.Gap

function addon.layout_item_list_help(frame)
    local group = frame

    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Item"] .. color.RESET .. " - " ..
        "An item you may be carrying or wearing.  Items may be added by name (auto completion will occur " ..
        "for any item you are currently carrying), by item ID (if you know it from a place such as WowHead), " ..
        "or by dragging the item from your bags into the input box or the icon field to the left of it.  " ..
        "Clearing the item field will implicitly delete it from the list.  The item's icon will not show " ..
        "if the item is entered by name and you are noit currently carrying it, however the item is still " ..
        "a valid part of the item set and will work if picked up at a later time."))

    local angle = math.rad(180)
    local cos, sin = math.cos(angle), math.sin(angle)

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up", 24, 24,
        color.BLIZ_YELLOW .. L["Move to Top"] .. color.RESET .. " - " ..
                "This will move the current item to the first slot in the item list.",
        nil, nil, (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0))

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up", 24, 24,
        color.BLIZ_YELLOW .. L["Move Up"] .. color.RESET .. " - " ..
                "This will move the current item up to the previous slot in the item list.",
        nil, nil, (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0))

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up", 24, 24,
        color.BLIZ_YELLOW .. L["Move Down"] .. color.RESET .. " - " ..
                "This will move the current item down to the next slot in the item list."))

    group:AddChild(CreatePictureText(
        "Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up", 24, 24,
        color.BLIZ_YELLOW .. L["Move to Bottom"] .. color.RESET .. " - " ..
                "This will move the current item to the last slot in the item list."))

    group:AddChild(CreatePictureText(
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", 24, 24,
        color.BLIZ_YELLOW .. DELETE .. color.RESET .. " - " ..
                "Removes this item from the item list entirely.  This action is permanent."))

end

function addon.layout_itemsets_options_help(frame)
    local group = frame

    group:AddChild(CreateText(
        "Item Sets are ordered lists of items that, when used, are checked against your current inventory " ..
        "and what you have equipped.  The first item found is then used (for example checked aginst item-based " ..
        "conditions, or highliged on yor action bars.  Once an item is found, Rotation Master does not check " ..
        "for any remaining items.  This is useful to keep lists of 'mostly equivalent' items that come in " ..
        "slightly different strengths or varieties (eg. mana potions, conjured food, etc).  Item sets can " ..
        "be bound directly to your action bars, and will be automatically updated as you acquire or use items " ..
        "in the item list."))

    group:AddChild(Gap())
    group:AddChild(CreateText("Fields", "Interface\\AddOns\\RotationMaster\\Fonts\\Inconsolata-Bold.ttf", 16))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Item Set"] .. color.RESET .. " - " ..
        "Select which item set you wish to work on from the drop down menu.  You can create a new item set by " ..
        "selecting " .. color.GREEN .. NEW .. color.RESET .. ".  The default action when selecting then " ..
        "Item Sets configuration menu is to create a new set."))

    group:AddChild(Gap())
    group:AddChild(CreatePictureText("Interface\\Icons\\INV_Misc_QuestionMark", 36, 36,
        "The icon next to the item set name will automatically update to display the item that is currently " ..
        "selected by this item set."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. NAME .. color.RESET .. " - " ..
        "The name for this item set.  This name will be used in any dropdown menu listing item sets.  An item " ..
        "set may not be modified until it has a name."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Global"] .. color.RESET .. " - " ..
        "If set, this item set will be availbale on all of your characters.  Otherwise is is character " ..
        "specific.  Global item sets show up in " .. color.CYAN .. "cyan" .. " when referenced."))

    group:AddChild(Gap())
    group:AddChild(CreateButtonText(L["Bind"], "Bind this item set to your action bars.  Clicking this will 'pick " ..
            "up' the action set, and then it can simply be dragged to your action bars."))

    group:AddChild(Gap())
    group:AddChild(CreateButtonText(L["Unbind"], "Unbind a bound item set (this will remove it from your action " ..
            "bars).  This is equivalent to simply dragging it off your action bars and releasing it."))

    group:AddChild(Gap())
    group:AddChild(CreateButtonText(DELETE, "Delete this item set permanently.  If this item set is in use by " ..
        "any rotation on this character, you will be prompted to ensure this was nor performed in error."))

    group:AddChild(Gap())
    group:AddChild(CreateButtonText(L["Import/Export"], "This will open up a window that can be used to both export " ..
            "your current item set and import one created by someone else."))

    group:AddChild(Gap())
    addon.layout_item_list_help(frame)

    group:AddChild(Gap())
    group:AddChild(CreateText("Use with Macros", "Interface\\AddOns\\RotationMaster\\Fonts\\Inconsolata-Bold.ttf", 16))
    group:AddChild(Gap())

    group:AddChild(CreateText("Item sets can be used in other contexts.  A number of hidden buttons are created " ..
            "that can be accessed (for example inside a macro) using " .. color.MAGENTA .. "/click <button>" ..
            color.RESET .. ".  The name of these hidden buttons is 'RM_' concatinated with the name of the " ..
            "item set (with all non-alphanumeric character stripped out) concatinated with '_<target>'.  " ..
            "So the item 'Mana Potions' would have names like RM_ManaPotions_player."))

    group:AddChild(Gap())
    group:AddChild(CreateText("For an item set called Bandages, the hidden buttons would be:"))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "RM_Bandages_player" .. color.RESET ..
            " This will use the highest level item in the item set on yourself.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "RM_Bandages_pet" .. color.RESET ..
            " This will use the highest level item in the item set on your pet.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "RM_Bandages_target" .. color.RESET ..
            " This will use the highest level item in the item set on your target.")))
    if (WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC) then
        group:AddChild(Indent(40, CreateText(color.GREEN .. "RM_Bandages_focus" .. color.RESET ..
                " This will use the highest level item in the item set on your focus target.")))
    end
    group:AddChild(Indent(40, CreateText(color.GREEN .. "RM_Bandages_mouseover" .. color.RESET ..
            " This will use the highest level item in the item set on the character or unit frame your mouse " ..
            "is hovering over.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "RM_Bandages_pettarget" .. color.RESET ..
            " This will use the highest level item in the item set on your pet's target.")))
    group:AddChild(Indent(40, CreateText(color.GREEN .. "RM_Bandages_targetargett" .. color.RESET ..
            " This will use the highest level item in the item set on your target's target.")))
    if (WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC) then
        group:AddChild(Indent(40, CreateText(color.GREEN .. "RM_Bandages_focustarget" .. color.RESET ..
                " This will use the highest level item in the item set on your focus target's target.")))
    end
    group:AddChild(Indent(40, CreateText(color.GREEN .. "RM_Bandages_mouseovertarget" .. color.RESET ..
            " This will use the highest level item in the item set on the character or unit frame your mouse " ..
            "is hovering over's target.")))

    group:AddChild(Gap())
    group:AddChild(CreateText("An example usage of this might be to create a macro like this:"))
    group:AddChild(Indent(40, CreateText(color.MAGENTA .. "/click [@mouseover,nodead,help] RM_Bandages_mouseover" ..
            color.RESET)))
    group:AddChild(CreateText("In the above example, the macro is 'checking' that your mouseover target " ..
            "is not dead and is an ally, and if so, invoking the hidden button that calls /use on the first " ..
            "found item in the item set with a target of your mouseover target."))

    group:AddChild(Gap())
    group:AddChild(CreateText("This functionaliy is not related to action bar bindings."))
end

