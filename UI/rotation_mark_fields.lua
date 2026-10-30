-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Detail fields for the unit and marker of a Set Mark step. Changes are committed through the rotation editor.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Lists the unit choices of the editor: the whitelisted tokens this client offers, labeled with the unit names the
-- condition editors use.
-- @return table[]  One { value = string, text = string } per unit token, in editor order; text falls back to the
--   token itself when the condition editors have no name for it.
local function unitEntries()
    local entries = {}

    for _, token in ipairs(addon.Platform:GetMarkActionUnits()) do
        entries[#entries + 1] = { value = token, text = addon.units[token] or token }
    end

    return entries
end

-- Lists the mark choices: the eight marks, skull first, then the choice that clears the mark.
-- @return table[]  One { value = string, text = string } per choice; value is the mark's key (or the "none" word), text
--   its localized name.
local function markEntries()
    local platform = addon.Platform
    local entries = {}

    for _, index in ipairs(platform.RaidMarks.priority) do
        entries[#entries + 1] = { value = platform.RaidMarks.keys[index], text = platform:GetRaidMarkName(index) }
    end

    entries[#entries + 1] = { value = platform.RaidMarkActions.highestUnset, text = L['Highest priority unset'] }
    entries[#entries + 1] = { value = platform.RaidMarkActions.none, text = L['Clear the mark'] }
    return entries
end

-- Builds the rows of a Set Mark step and returns the y position below them.
-- @param owner table  The rotation editor view; it shows the Bind button's messages through owner:Message.
-- @param card table  The card being filled; its fields frame holds the Bind button.
-- @param model table  The card model; model.step is the step being edited.
-- @param alive function  Returns true while the card is still the current one.
-- @param ctx table  What UI/rotation_fields.lua hands over: acquire(kind, build), choice(key, caption, entries,
--   selected, commit), patch(set, unset), controls (the card's control list), width (the field width), readOnly
--   (boolean), and getY() / setY(value) for the running vertical position.
-- @return number  The running vertical position after the last row.
function addon:BuildRotationMarkFields(owner, card, model, alive, ctx)
    local step = model.step

    ctx.choice('markunit', L['Unit'], unitEntries(), step.unit, function(value)
        ctx.patch({ unit = value })
    end)

    ctx.choice('mark', L['Mark'], markEntries(), step.action, function(value)
        ctx.patch({ action = value })
    end)

    return ctx.getY()
end
