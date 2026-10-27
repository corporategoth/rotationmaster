-- Help layouts for the condition editor: the structural conditions (AND, OR, NOT), the shared field widgets (spell,
-- spell name, item set, operator, percent operator, unit) and the cast-spell and aura-rank notes. Each layout function
-- takes the help frame (some also the field's name, value and description) and adds the text widgets that explain it.
-- Loaded from RotationMaster.toc with the other Help/ files, after Help/common.lua (addon.help_funcs) and UI/. The
-- rank notes appear only on clients that have spell ranks (addon:ClientHasSpellRanks).
-- Several paragraphs below are plain English literals rather than L[...] keys; they are not localized yet.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs

local CreateText, CreatePictureText, Indent, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.Indent, helpers.Gap

-- Help for an All (AND) group: matching rule and how card selection and grouping work.
function addon.layout_condition_and_help(frame)
    local group = frame

    group:AddChild(
        CreateText(
            L["All (AND) requires every child to match. An empty group always matches. Unavailable data remains unavailable."]
        )
    )

    group:AddChild(Gap())

    group:AddChild(
        CreateText(
            L["Select cards with Ctrl-click or Shift-click. Group with All or Any, negate each, move or drag, and remove. Undo and Redo affect only the draft until Apply. Groups can be named and collapsed."]
        )
    )
end

-- Help for an Any (OR) group: matching rule and how card selection and grouping work.
function addon.layout_condition_or_help(frame)
    local group = frame

    group:AddChild(
        CreateText(L["This condition matches if any sub-condition matches. With no sub-conditions, it does not match."])
    )

    group:AddChild(Gap())

    group:AddChild(
        CreateText(
            L["Select cards with Ctrl-click or Shift-click. Group with All or Any, negate each, move or drag, and remove. Undo and Redo affect only the draft until Apply. Groups can be named and collapsed."]
        )
    )
end

-- Help for a NOT condition: it negates its sub-condition.
function addon.layout_condition_not_help(frame)
    local group = frame

    group:AddChild(
        CreateText(
            "This condition will negate its sub-condition.  Meaning that if the sub-condition "
                .. "evaluates successfully, then this condition will NOT evaluate successfully, and vice versa."
        )
    )
end

-- Help for the spell field: the icon slot, the exact-rank option (only on clients with ranks) and the name input.
function addon.layout_condition_spellwidget_help(frame)
    local group = frame

    group:AddChild(
        CreatePictureText(
            "Interface\\Icons\\INV_Misc_QuestionMark",
            36,
            36,
            "The icon next to the spell name will automatically update to display the spell that is currently "
                .. "selected.  You can drag a new spell from your spell book or action bars into this icon slot to "
                .. "replace your selected spell."
        )
    )

    if addon:ClientHasSpellRanks() then
        group:AddChild(Gap())

        group:AddChild(
            CreateText(
                color.BLIZ_YELLOW
                    .. L["Use this exact spell rank"]
                    .. color.RESET
                    .. " - "
                    .. L["Unticked (the default), any rank of the spell matches. Ticked, only the rank you chose matches."]
            )
        )
    end

    group:AddChild(Gap())

    group:AddChild(
        CreateText(
            color.BLIZ_YELLOW
                .. L["Spell"]
                .. color.RESET
                .. " - "
                .. "This is a specific spell used in this condition.  You may drag this spell from your spell book or "
                .. "action bars into the input field or spell icon to set this value.  This input field has prediction "
                .. "enabled, so you do not have to type the full spell name, just select from the prediction frame when it "
                .. "appears."
        )
    )
end

-- Help for the spell-name field: the icon slot and the name input (no rank option).
function addon.layout_condition_spellnamewidget_help(frame)
    local group = frame

    group:AddChild(
        CreatePictureText(
            "Interface\\Icons\\INV_Misc_QuestionMark",
            36,
            36,
            "The icon next to the spell name will automatically update to display the spell that is currently "
                .. "selected.  You can drag a new spell from your spell book or action bars into this icon slot to "
                .. "replace your selected spell."
        )
    )

    group:AddChild(Gap())

    group:AddChild(
        CreateText(
            color.BLIZ_YELLOW
                .. L["Spell"]
                .. color.RESET
                .. " - "
                .. "This is a specific spell used in this condition.  You may drag this spell from your spell book or "
                .. "action bars into the input field or spell icon to set this value.  This input field has prediction "
                .. "enabled, so you do not have to type the full spell name, just select from the prediction frame when it "
                .. "appears."
        )
    )
end

-- Help for the item field: ordered item lists, pre-defined versus custom item sets, and the Edit button.
function addon.layout_condition_itemwidget_help(frame)
    local group = frame

    group:AddChild(
        CreateText(
            color.BLIZ_YELLOW
                .. L["Item Set"]
                .. color.RESET
                .. " - "
                .. "This is a list of items to look for in your inventory.  This list is ordered, the top found item "
                .. "in the list that you are carrying or wearing is what will be used in this condition.  NOTE: "
                .. "this will NOT search for ANY item in the list that matches this condition, only the first item "
                .. "found will be used in this condition."
        )
    )

    group:AddChild(
        CreateText(
            "You can choose from either a pre-defined Item Set, by picking it by name from the "
                .. "drop down menu.  You can edit these using the "
                .. color.BLUE
                .. L["Item Sets"]
                .. color.RESET
                .. " configuration menu.  Any item set in "
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
        )
    )

    group:AddChild(
        Indent(
            40,
            CreatePictureText(
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
                    .. "at least one item in it for this condition to be considered valid."
            )
        )
    )
end

-- Help for an operator field: how name is compared with value, then what value means (desc).
function addon.layout_condition_operatorwidget_help(frame, name, value, desc)
    local group = frame

    group:AddChild(
        CreateText(
            color.BLIZ_YELLOW
                .. L["Operator"]
                .. color.RESET
                .. " - "
                .. "How to compare "
                .. name
                .. " with the "
                .. color.BLIZ_YELLOW
                .. value
                .. color.RESET
                .. " value.  This "
                .. "comparison uses basic mathematical comparison operations."
        )
    )

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. value .. color.RESET .. " - " .. desc))
end

-- Help for a percent operator field; the same text as the plain operator help, with the percent value described.
function addon.layout_condition_operatorpercentwidget_help(frame, name, value, desc)
    local group = frame

    group:AddChild(
        CreateText(
            color.BLIZ_YELLOW
                .. L["Operator"]
                .. color.RESET
                .. " - "
                .. "How to compare "
                .. name
                .. " with the "
                .. color.BLIZ_YELLOW
                .. value
                .. color.RESET
                .. " value.  This "
                .. "comparison uses basic mathematical comparison operations."
        )
    )

    group:AddChild(Gap())
    group:AddChild(CreateText(color.BLIZ_YELLOW .. value .. color.RESET .. " - " .. desc))
end

-- Help for the unit field: the unit the condition tests.
function addon.layout_condition_unitwidget_help(frame)
    local group = frame

    group:AddChild(
        CreateText(
            color.BLIZ_YELLOW
                .. L["Unit"]
                .. color.RESET
                .. " - "
                .. "The unit this condition uses as the target of comparison."
        )
    )
end

-- Help note for casting conditions: spells match by ID, saved names keep matching by name, and an unreadable cast is
-- unavailable. The sentence about exact ranks is included only on clients that have spell ranks.
function addon.layout_condition_castspell_help(frame)
    frame:AddChild(Gap())

    if addon:ClientHasSpellRanks() then
        frame:AddChild(
            CreateText(
                L['A spell picked in the editor is matched by its spell ID, so the condition works on every client language. Any rank of that spell matches unless Use this exact spell rank is ticked. Conditions saved with a spell name keep matching by that name. If the client cannot read the spell being cast, the condition is unavailable, including under NOT.']
            )
        )
    else
        frame:AddChild(
            CreateText(
                L['A spell picked in the editor is matched by its spell ID, so the condition works on every client language. Conditions saved with a spell name keep matching by that name. If the client cannot read the spell being cast, the condition is unavailable, including under NOT.']
            )
        )
    end
end

-- Help note for the exact-rank option of aura conditions; adds nothing on clients without spell ranks.
function addon.layout_condition_aurarank_help(frame)
    if not addon:ClientHasSpellRanks() then return end
    frame:AddChild(Gap())

    frame:AddChild(
        CreateText(
            color.BLIZ_YELLOW
                .. L['Use this exact spell rank']
                .. color.RESET
                .. ' - '
                .. L['Unticked, any rank of the spell matches: a numeric spell selection also recognizes auras with the same readable localized spell name. Ticked, only the exact spell ID you chose matches. Conditions saved before this option keep the exact ID until you untick it. Spell names already match by name. Unavailable metadata or restricted aura identity stays unavailable, including under NOT. Different spells sharing a name can match; tick the option when that distinction matters.']
        )
    )
end
