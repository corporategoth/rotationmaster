-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Detail fields of a Set Mark step on a rotation card: the unit to mark (a fixed list of unit tokens, never free text),
-- the mark to place (or none to clear it) and the Bind button that makes the macro for the step and puts it on the
-- cursor. It builds controls on the card and commits through the callbacks UI/rotation_fields.lua passes in ctx; it
-- never writes a rotation or a secure attribute itself (Core/raid_mark_buttons.lua does the runtime part). Loaded from
-- RotationMaster.toc just before UI/rotation_fields.lua.
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

    entries[#entries + 1] = { value = platform.RaidMarkActions.none, text = L['Clear the mark'] }
    return entries
end

-- Says what a Bind failure means, in words.
-- @param reason string  The reason BeginMarkBind returned.
-- @return string  A sentence for the editor's message line; a generic one for a reason it has no wording for.
local function bindProblem(reason)
    if reason == 'combat' then
        return L['Leave combat before changing action bar bindings.']
    end
    if reason == 'cursor' then
        return L['Empty your cursor before binding.']
    end
    if reason == 'macros-full' then
        return L['Your character macros are full, so the macro could not be made.']
    end
    if reason == 'unsupported' then
        return L['Raid marks cannot be placed on this client.']
    end

    return L['The macro could not be made.']
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

    local bind = ctx.acquire('choices', function() return addon:CreateWorkbenchButton(card.fields, '', ctx.width) end)
    local y = ctx.getY()
    bind:ClearAllPoints()
    bind:SetPoint('TOPLEFT', 0, -y)
    bind:SetWidth(ctx.width)
    bind:SetText(L['Put on an action bar'])

    bind.tooltip = L["Makes a macro that presses this step's hidden button, and picks it up. Drop it on an action bar slot and Rotation Master lights it while this step is advised. In a raid only the leader and assistants can place marks."]

    ctx.controls.bind = bind
    ctx.controls[#ctx.controls + 1] = bind
    ctx.setY(y + 28)

    addon:SetUIScript(bind, 'OnClick', function()
        if not alive() then
            return
        end

        local ok, detail = addon:BeginMarkBind(step.unit, step.action)

        if ok then
            owner:Message(string.format(L['Drag the macro %s to an action bar slot.'], detail))
        else
            owner:Message(bindProblem(detail))
        end
    end)

    if ctx.readOnly then
        bind:Disable()
    else
        bind:Enable()
    end

    return ctx.getY()
end
