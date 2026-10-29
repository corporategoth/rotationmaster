-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Help documents for item sets: the item-list controls (move, delete), the Item Sets settings page (name, global,
-- priority order, binding, history, Apply/Cancel, collections, legacy macros) and the native item-list editor popup,
-- each with a renderer that lays it out in a help frame. Paragraphs live in the locale tables under Help.ItemSets.*.
-- Loaded from RotationMaster.toc with the other Help/ files, after Help/common.lua (addon.help_funcs) and UI/.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs
local CreateText, Gap = helpers.CreateText, helpers.Gap

-- Returns the help sections for the item list's per-row controls (item, move, delete).
-- @return table[]  The sections, each {id=string, title=string, text=string}.
function addon:GetDocument_layout_item_list_help()
    return {
        {
            id = "list.item",
            title = L["Item"],
            text = L["Search for an item or drag it into the item field or icon. Choose the result to retain its exact item identity. The icon and name may be unavailable until metadata loads. Field clearing and save behavior belong to the editor that contains this list; use Delete when you intend to remove an entry."],
        },
        {
            id = "list.top",
            title = L["Move to Top"],
            text = L["Move this entry to the first position in the item priority list, when that control is offered."],
        },
        {
            id = "list.up",
            title = L["Move Up"],
            text = L["Move this entry one position earlier. A move before the first entry is unavailable."],
        },
        {
            id = "list.down",
            title = L["Move Down"],
            text = L["Move this entry one position later. A move past the final entry is unavailable."],
        },
        {
            id = "list.bottom",
            title = L["Move to Bottom"],
            text = L["Move this entry to the final position in the item priority list, when that control is offered."],
        },
        {
            id = "list.delete",
            title = L["Delete"],
            text = L["Remove this entry from the list. In a draft editor this remains pending until Apply, and Discard abandons the row edit. Undo is available where the containing editor provides draft history. This differs from permanently deleting the entire set after confirmation."],
        },
    }
end

-- Lays the item-list help out in a frame as a yellow title followed by its paragraph, one gap between each.
-- @param frame table  The help frame the text widgets are added to.
function addon.layout_item_list_help(frame)
    for _, entry in ipairs(addon:GetDocument_layout_item_list_help()) do
        frame:AddChild(Gap())

        frame:AddChild(CreateText(
            (entry.title ~= '' and color.BLIZ_YELLOW .. entry.title .. color.RESET .. ' - ' or '') .. entry.text
        ))
    end
end

-- Returns the Item Sets page help sections.
-- @return table[]  The sections, each {id=string, title=string, text=string}.
function addon:GetDocument_layout_itemsets_options_help()
    return {
        {
            id = "overview",
            title = L["Item Sets"],
            text = L["An item set is an ordered list of alternatives, such as different mana potions. Runtime selection checks the list from the top for a carried or, where requested, equipped item. Priority comes from the order you choose, not the item level. Selecting an item does not by itself prove that it is usable, off cooldown, or in range; action readiness is checked separately."],
        },
        {
            id = "name",
            title = L["Name"],
            text = L["Name the selected set so it can be found in the sidebar and referenced by rotations or conditions. New opens a name form; its first Apply saves an empty named set. Add items afterward and Apply again to save them. Discarding later item edits keeps that already saved set. Renaming a set does not change its identity in saved references."],
        },
        {
            id = "global",
            title = L["Global"],
            text = L["Checked stores this set in the shared global collection, available to other profiles and characters using this addon database. Unchecked stores it in the current profile, which can itself be shared by characters. This is a staged move; Apply saves it. A profile set takes precedence if a global set has the same saved identity."],
        },
        {
            id = "items",
            title = L["Items in priority order"],
            text = L["The list of item cards is the priority order. Put preferred items first. RM can leave a selection unavailable when required inventory or identity observations are missing; it does not treat unknown data as proof that a lower-priority item should be used. The sidebar icon represents the first defined item and need not be the currently carried or highlighted one."],
        },
        {
            id = "item",
            title = L["Item"],
            text = L["Search by item name and choose a result, or drag an item from your bags or action bar into its field. The icon identifies the item; metadata can take time to load. Edit a row to replace that entry. Use its red trash can to remove it rather than clearing a required item field."],
        },
        {
            id = "add",
            title = L["Add item"],
            text = L["Choose or drag an item into the empty item field above the list, then click Add item to append it to the priority list, or drag Add item into a gap between cards to insert it there. Entering an item in this field alone does not add a row."],
        },
        {
            id = "order",
            title = L["Move Up / Move Down"],
            text = L["Use the arrows on the left, or drag an item row into a highlighted insertion gap. Ctrl-drag moves that row and all following entries together. The floating preview identifies what you are moving. Moves past the beginning or end are unavailable. Reordering changes priority and stays in the draft until Apply."],
        },
        {
            id = "binding",
            title = L["Bind / Unbind"],
            text = L["Outside combat, apply pending item-set edits before binding. Drag the set (its row in the list, or the Bind pill) onto any action bar slot; an occupied slot swaps, leaving its previous action on the cursor. Or click Bind and then click an empty slot. Both pick up the first available item of the set. RM records the slot and updates it as item availability changes. The pill shows bound slot numbers; click it to unbind and remove still-matching bar items. Replaced bar actions are preserved. Binding changes are immediate action-bar operations, independent of the draft and its history."],
        },
        {
            id = "reset",
            title = L["Reset"],
            text = L["Restore the packaged item list for this set. Reset is available only for a set with a packaged default. The restored list is staged until Apply; the name is kept."],
        },
        {
            id = "delete",
            title = L["Delete"],
            text = L["The red trash can at the top right permanently removes the selected saved set after confirmation. Resolve pending edits before the final warning. References in rotations or conditions then need another set. Deletion reconciles still-matching bound bar actions and keeps the set if unbinding fails; the next selection opens without an unsaved deletion marker."],
        },
        {
            id = "history",
            title = L["Undo / Redo"],
            text = L["Undo and Redo travel through recent item-set draft edits, including replacements, additions, ordering and row removals. They are unavailable when that direction has no history. Apply, Discard or leaving the page clears this bounded history. They do not reverse confirmed entity deletion or explicit action-bar binding operations."],
        },
        {
            id = "save",
            title = L["Apply / Cancel"],
            text = L["Ordinary item-set edits stay in a draft until Apply. Discard restores the saved item sets. Cancel closes a new creation draft. Leaving with pending changes offers Apply, Discard or Cancel navigation. Invalid fields must be corrected before Apply; Discard can abandon them."],
        },
        {
            id = "collections",
            title = L["New, Duplicate, Import/Export and Compare"],
            text = L["Use the buttons below the sidebar to create, duplicate, transfer, or compare sets. Duplicate makes an independent profile copy. Import shows the source name and can create a renamed copy or replace the selected list; Apply saves the staged result. Compare inspects differences without merging or modifying either set."],
        },
        {
            id = "macros",
            title = L["Legacy macro buttons"],
            text = L["Legacy clients may allow /click to invoke an RM item-set button separately from action-bar binding. The name is RM_ followed by the set name with non-alphanumeric characters removed, then an underscore and unit token. For a set named Bandages, an example is /click [@mouseover,nodead,help] RM_Bandages_mouseover. Other unit suffixes include player, pet, target, focus, pettarget, targettarget, focustarget, and mouseovertarget. These buttons contain item-use macro lines and do not provide the same readiness or first-item guarantee as the recommendation engine. Availability is subject to the client's secure-button and macro restrictions; reference-only support does not promise executable macro buttons."],
        },
    }
end

-- Lays the Item Sets page help out in a frame as a yellow title followed by its paragraph, one gap between each.
-- @param frame table  The help frame the text widgets are added to.
function addon.layout_itemsets_options_help(frame)
    for _, entry in ipairs(addon:GetDocument_layout_itemsets_options_help()) do
        frame:AddChild(Gap())

        frame:AddChild(CreateText(
            (entry.title ~= '' and color.BLIZ_YELLOW .. entry.title .. color.RESET .. ' - ' or '') .. entry.text
        ))
    end
end

-- Returns the help sections for the native item list editor, which edits one caller-owned list, not every saved item
-- set.
-- @return table[]  The sections, each {id=string, title=string, text=string}.
function addon:GetNativeItemListHelp()
    return {
        {
            id = 'popup.overview',
            title = L['Editing this list'],
            text = L["This window edits only the item list you opened. Search or drag items into the fields, then arrange preferred items first. A named item set is shared by its other users; a custom list belongs to the calling condition or action draft. Applying this list does not apply the parent editor."],
        },
        {
            id = 'item',
            title = L['Item'],
            text = L["Search by item name and choose a result, or drag an item from your bags or action bar into its field. The icon identifies the item; metadata can take time to load. Edit a row to replace that entry. Use its red trash can to remove it rather than clearing a required item field."],
        },
        {
            id = 'add',
            title = L['Add item'],
            text = L["Choose or drag an item into the empty item field above the list, then click Add item to append it to the priority list, or drag Add item into a gap between cards to insert it there. Entering an item in this field alone does not add a row."],
        },
        {
            id = 'order',
            title = L['Move Up / Move Down'],
            text = L["Use the arrows on the left, or drag an item row into a highlighted insertion gap. Ctrl-drag moves that row and all following entries together. The floating preview identifies what you are moving. Moves past the beginning or end are unavailable. Reordering changes priority and stays in the draft until Apply."],
        },
        {
            id = 'popup.delete',
            title = L['Delete'],
            text = L["Use a row's red trash can to remove that entry from the draft list. This does not delete a named item set or remove an item from your inventory. The removal takes effect when you Apply this list."],
        },
        {
            id = 'history',
            title = L['Undo / Redo'],
            text = L["Undo and Redo travel through recent item-set draft edits, including replacements, additions, ordering and row removals. They are unavailable when that direction has no history. Apply, Discard or leaving the page clears this bounded history. They do not reverse confirmed entity deletion or explicit action-bar binding operations."],
        },
        {
            id = 'popup.save',
            title = L['Apply / Discard'],
            text = L["Apply validates every entry and writes the edited list back to its original owner. Discard closes without changing it. Closing with pending edits offers Apply, Discard or Cancel; Cancel keeps this window open. View Changes compares the original list with this draft. If the original list changed elsewhere, close and reopen it before applying."],
        },
    }
end
