local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, Indent, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.Indent, helpers.Gap

function addon.layout_condition_and_help(frame)
    local group = frame

    group:AddChild(CreateText(L["All (AND) requires every child to match. An empty group always matches. Unavailable data remains unavailable."]))
    group:AddChild(Gap())
    group:AddChild(CreateText(L["Select cards with Ctrl-click or Shift-click. Group with All or Any, negate each, move or drag, and remove. Undo and Redo affect only the draft until Apply. Groups can be named and collapsed."]))
end

function addon.layout_condition_or_help(frame)
    local group = frame

    group:AddChild(CreateText(L["This condition matches if any sub-condition matches. With no sub-conditions, it does not match."]))
    group:AddChild(Gap())
    group:AddChild(CreateText(L["Select cards with Ctrl-click or Shift-click. Group with All or Any, negate each, move or drag, and remove. Undo and Redo affect only the draft until Apply. Groups can be named and collapsed."]))
end

function addon.layout_condition_not_help(frame)
    local group = frame

    group:AddChild(CreateText("This condition will negate it's sub-condition.  Meaning that if the sub-condition " ..
            "evaluates successfully, then this condition will NOT evaluate successfully, and vice versa."))
end

function addon.layout_condition_spellwidget_help(frame)
    local group = frame

    group:AddChild(CreatePictureText("Interface\\Icons\\INV_Misc_QuestionMark", 36, 36,
        "The icon next to the spell name will automatically update to display the spell that is currently " ..
        "selected.  You can drag a new spell from your spell book or action bars into this icon slot to " ..
        "replace your selected spell."))

    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        group:AddChild(Gap())
        group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Rank"] .. color.RESET .. " - " ..
                "If enabled, use a specific rank of the spell in question.  This is normally only used for " ..
                "things like downranked spells."))
    end

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Spell"] .. color.RESET .. " - " ..
        "This is a specific spell used in this condition.  You may drag this spell from your spell book or " ..
        "action bars into the input field or spell icon to set this value.  This input field has prediction " ..
        "enabled, so you do not have to type the full spell name, just select from the prediction frame when it " ..
        "appears."))
end

function addon.layout_condition_spellnamewidget_help(frame)
    local group = frame

    group:AddChild(CreatePictureText("Interface\\Icons\\INV_Misc_QuestionMark", 36, 36,
        "The icon next to the spell name will automatically update to display the spell that is currently " ..
                "selected.  You can drag a new spell from your spell book or action bars into this icon slot to " ..
                "replace your selected spell."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Spell"] .. color.RESET .. " - " ..
            "This is a specific spell used in this condition.  You may drag this spell from your spell book or " ..
            "action bars into the input field or spell icon to set this value.  This input field has prediction " ..
            "enabled, so you do not have to type the full spell name, just select from the prediction frame when it " ..
            "appears."))
end

function addon.layout_condition_itemwidget_help(frame)
    local group = frame

    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Item Set"] .. color.RESET .. " - " ..
            "This is a list of items to look for in your inventory.  This list is ordered, the top found item " ..
            "in the list that you are carrying or wearing is what will be used in this condition.  NOTE: " ..
            "this will NOT search for ANY item in the list that matches this condition, only the first item " ..
            "found will be used in this condition."))
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
            "item set (including on your other characters if it is a global item set.  An item set must have " ..
            "at least one item in it for this condition to be considered valid.")))
end

function addon.layout_condition_operatorwidget_help(frame, name, value, desc)
    local group = frame

    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Operator"] .. color.RESET .. " - " ..
        "How to compare " .. name .. " with the " .. color.BLIZ_YELLOW .. value .. color.RESET .. " value.  This " ..
        "comparison uses basic mathematical comparison operations."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. value .. color.RESET .. " - " .. desc))
end

function addon.layout_condition_operatorpercentwidget_help(frame, name, value, desc)
    local group = frame

    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Operator"] .. color.RESET .. " - " ..
        "How to compare " .. name .. " with the " .. color.BLIZ_YELLOW .. value .. color.RESET .. " value.  This " ..
        "comparison uses basic mathematical comparison operations."))

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. value .. color.RESET .. " - " .. desc))
end

function addon.layout_condition_unitwidget_help(frame)
    local group = frame

    group:AddChild(CreateText(color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " - " ..
        "The unit this condition uses as the target of comparison."))
end
