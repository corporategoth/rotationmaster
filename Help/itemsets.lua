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
function addon:GetDocument_layout_item_list_help()
    return {
        { id = "list.item", title = L["Item"], text = L["Help.ItemSets.list.item"] },
        { id = "list.top", title = L["Move to Top"], text = L["Help.ItemSets.list.top"] },
        { id = "list.up", title = L["Move Up"], text = L["Help.ItemSets.list.up"] },
        { id = "list.down", title = L["Move Down"], text = L["Help.ItemSets.list.down"] },
        { id = "list.bottom", title = L["Move to Bottom"], text = L["Help.ItemSets.list.bottom"] },
        { id = "list.delete", title = L["Delete"], text = L["Help.ItemSets.list.delete"] },
    }
end

-- Lays the item-list help out in a frame as a yellow title followed by its paragraph, one gap between each.
function addon.layout_item_list_help(frame)
    for _, entry in ipairs(addon:GetDocument_layout_item_list_help()) do
        frame:AddChild(Gap())

        frame:AddChild(CreateText(
            (entry.title ~= '' and color.BLIZ_YELLOW .. entry.title .. color.RESET .. ' - ' or '') .. entry.text
        ))
    end
end

-- Returns the Item Sets page help sections { id, title, text }.
function addon:GetDocument_layout_itemsets_options_help()
    return {
        { id = "overview", title = L["Item Sets"], text = L["Help.ItemSets.overview"] },
        { id = "name", title = L["Name"], text = L["Help.ItemSets.name"] },
        { id = "global", title = L["Global"], text = L["Help.ItemSets.global"] },
        { id = "items", title = L["Items in priority order"], text = L["Help.ItemSets.items"] },
        { id = "item", title = L["Item"], text = L["Help.ItemSets.item"] },
        { id = "add", title = L["Add item"], text = L["Help.ItemSets.add"] },
        { id = "order", title = L["Move Up / Move Down"], text = L["Help.ItemSets.order"] },
        { id = "binding", title = L["Bind / Unbind"], text = L["Help.ItemSets.binding"] },
        { id = "reset", title = L["Reset"], text = L["Help.ItemSets.reset"] },
        { id = "delete", title = L["Delete"], text = L["Help.ItemSets.delete"] },
        { id = "history", title = L["Undo / Redo"], text = L["Help.ItemSets.history"] },
        { id = "save", title = L["Apply / Cancel"], text = L["Help.ItemSets.save"] },
        {
            id = "collections",
            title = L["New, Duplicate, Import/Export and Compare"],
            text = L["Help.ItemSets.collections"],
        },
        { id = "macros", title = L["Legacy macro buttons"], text = L["Help.ItemSets.macros"] },
    }
end

-- Lays the Item Sets page help out in a frame as a yellow title followed by its paragraph, one gap between each.
function addon.layout_itemsets_options_help(frame)
    for _, entry in ipairs(addon:GetDocument_layout_itemsets_options_help()) do
        frame:AddChild(Gap())

        frame:AddChild(CreateText(
            (entry.title ~= '' and color.BLIZ_YELLOW .. entry.title .. color.RESET .. ' - ' or '') .. entry.text
        ))
    end
end

-- The native child edits one caller-owned list, not every saved item set.
function addon:GetNativeItemListHelp()
    return {
        { id = 'popup.overview', title = L['Editing this list'], text = L['Help.ItemSets.popup.overview'] },
        { id = 'item', title = L['Item'], text = L['Help.ItemSets.item'] },
        { id = 'add', title = L['Add item'], text = L['Help.ItemSets.add'] },
        { id = 'order', title = L['Move Up / Move Down'], text = L['Help.ItemSets.order'] },
        { id = 'popup.delete', title = L['Delete'], text = L['Help.ItemSets.popup.delete'] },
        { id = 'history', title = L['Undo / Redo'], text = L['Help.ItemSets.history'] },
        { id = 'popup.save', title = L['Apply / Discard'], text = L['Help.ItemSets.popup.save'] },
    }
end
