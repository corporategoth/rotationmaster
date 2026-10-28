-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Help document for the Conditions settings page: condition categories, ordering, switch and announcement
-- availability, hiding, and the Import/Export and Move To controls, as title and sentence pairs, with the renderer that
-- lays them out in a help frame.
-- Loaded from RotationMaster.toc with the other Help/ files, after Help/common.lua (addon.help_funcs) and UI/. The
-- sentences are L[...] literals and are translated as written; keep them whole.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, Gap = helpers.CreateText, helpers.CreatePictureText, helpers.Gap

-- Returns the Conditions page help entries { title, text }, in the order the controls appear on the page.
function addon:GetDocument_layout_conditions_options_help()
    return {
        {
            title = L["Category"],
            text = L["Use All, Built In or Custom to choose the condition source, then filter by Switch, Other or a named category. Search above these controls narrows the visible list without changing assignments."],
        },
        {
            title = L["Manage categories"],
            text = L["Open Manage categories below the list for category maintenance. Manage conditions returns to individual condition settings."],
        },
        {
            title = L["Name"],
            text = L["Rename the selected category in Manage categories. Built-in categories cannot be renamed or deleted."],
        },
        {
            title = L["Add category"],
            text = L["Add an empty named category from the category-management list. Move To in condition settings assigns a condition to it."],
        },
        {
            title = L["Move Up"],
            text = L["In Manage categories, move the selected category earlier in the category list."],
        },
        {
            title = L["Move Down"],
            text = L["In Manage categories, move the selected category later in the category list."],
        },
        {
            title = L["Delete category"],
            text = L["Delete a named category after confirmation. Its conditions remain available under Other; their definitions are preserved."],
        },
        {
            title = L["Import/Export"],
            text = L["Below the condition list, Import/Export opens the selected custom definition for transfer and code review; it is disabled for built-in conditions. In Manage categories, transfer a category’s ordered condition identifiers. Named categories and Other are exclusive destinations. Switch membership is independent."],
        },
        {
            title = L["Search"],
            text = L["Filter the visible condition list by name or identifier. The category filter still applies."],
        },
        {
            title = L["Switch Condition"],
            text = L["Allow this condition type to be used when automatically selecting a rotation."],
        },
        {
            title = L["Announcement Condition"],
            text = L["Offer this condition type when editing announcement conditions. This flag is independent of Switch Condition and does not remove or invalidate conditions already saved in announcements."],
        },
        {
            title = L["Hidden"],
            text = L["Hide this condition from the Other picker category. Explicit named-category and Switch membership remain available."],
        },
        {
            title = L["Condition order"],
            text = L["The condition ordering controls are arrows and draggable rows in the sidebar of the selected category. In Manage categories, the same controls order the categories themselves."],
        },
        {
            title = L["Move To"],
            text = L["Choose a named category or Other, then use Apply beside the destination to stage the move. Page Apply saves all pending changes. Use Switch Condition separately for automatic-switch availability."],
        },
    }
end

-- Lays the Conditions help document out in a frame as a yellow title followed by its text, one gap between each.
function addon.layout_conditions_options_help(frame)
    for _, entry in ipairs(addon:GetDocument_layout_conditions_options_help()) do
        frame:AddChild(Gap())

        frame:AddChild(CreateText(
            (entry.title ~= '' and color.BLIZ_YELLOW .. entry.title .. color.RESET .. ' - ' or '') .. entry.text
        ))
    end
end
