-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Runtime services of the Set Mark step: the hidden secure button for each (unit, mark) pair, the Bind flow that puts a
-- macro for that button on the player's cursor, the step's spell ids, its readable description and its client support.
-- This is the second place Rotation Master writes secure text (the first is Core/itemset_services.lua), and it is held
-- to a stricter rule: the only text ever written is the one line "/tm [@unit] N" that Platform/raid_mark_actions.lua
-- builds by looking a saved value up in a fixed whitelist, so no saved, imported or typed value can add to it. Rotation
-- Master only recommends: the button runs when the player presses it (from the action bar macro or a /click line).
-- Buttons are made out of combat, the first time a Set Mark step is evaluated or bound. Owns addon.markButtons; saved
-- data is untouched. Loaded from RotationMaster.toc after Core/itemset_services.lua.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local platform = addon.Platform

-- The hidden buttons made so far, by pseudo spell id. Frames cannot be destroyed, so they are kept for the session.
addon.markButtons = addon.markButtons or {}

-- True while the client is in combat lockdown, when secure attributes cannot be set.
local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

-- Makes the hidden secure button for a pseudo spell id if it does not exist yet.
-- Arguments:
--   id (number): a pseudo spell id from Platform:GetMarkActionId.
-- Returns:
--   ready (boolean): true when the button exists after the call.
--   reason (string|nil): why not: 'invalid-mark-step', 'combat', 'missing-api' or 'name-taken'.
--
-- Out of combat only. The first button also turns on the recognition of Set Mark macros on the action bars and asks for
-- a rescan, so a macro placed before the first evaluation is found.
function addon:EnsureMarkButton(id)
    local buttons = self.markButtons

    if buttons[id] then
        return true
    end

    local unit, mark = platform:DecodeMarkActionId(id)

    if not unit then
        return false, 'invalid-mark-step'
    end
    if inCombat() then
        return false, 'combat'
    end
    if type(CreateFrame) ~= 'function' then
        return false, 'missing-api'
    end

    local name = platform:GetMarkButtonName(unit, mark)
    local text = platform:GetMarkMacroText(unit, mark)

    if not name or not text then
        return false, 'invalid-mark-step'
    end

    -- A global of that name that is not ours belongs to someone else; it is never reused or overwritten.
    if _G[name] ~= nil then
        return false, 'name-taken'
    end

    local created, button = pcall(CreateFrame, 'Button', name, UIParent, 'SecureActionButtonTemplate')

    if not created or type(button) ~= 'table' then
        return false, 'missing-api'
    end

    button:Hide()
    button:SetAttribute('type', 'macro')
    button:SetAttribute('macrotext', text)
    buttons[id] = button

    if not platform:IsMarkActionTracking() then
        platform:SetMarkActionTracking(true)

        if self.ButtonFetch then
            self:ButtonFetch()
        end
    end

    return true
end

-- Gives the spell ids of a Set Mark step for the engines: its one pseudo spell id, after making sure its button exists.
-- Arguments:
--   step (table): a rotation step of type mark.
-- Returns:
--   ids (table): { id } for a valid step on a client that can place marks, otherwise empty.
function addon:GetMarkStepSpellIds(step)
    local id = platform:GetMarkStepActionId(step)

    if not id or platform:GetMarkActionSupport() then
        return {}
    end

    self:EnsureMarkButton(id)
    return { id }
end

-- Tells why a rotation step cannot work on this client.
-- Arguments:
--   step (table): any rotation step.
-- Returns:
--   reason (string|nil): nil for every step but a Set Mark step that cannot run: 'invalid-mark-step' when its unit or
--     mark is not on the whitelist, 'unsupported-unit', or the client reason ('missing-api', 'unsupported-policy').
function addon:GetStepSupport(step)
    if type(step) ~= 'table' or step.type ~= 'mark' then
        return nil
    end

    local id, reason = platform:GetMarkStepActionId(step)

    if not id then
        return reason
    end

    return platform:GetMarkActionSupport()
end

-- Describes a Set Mark step in words for cards, reports and tooltips.
-- Arguments:
--   step (table): a rotation step of type mark.
-- Returns:
--   text (string): "Set Skull on your target", "Clear the mark on your target", or "Set Mark" while it is not filled in.
function addon:DescribeMarkStep(step)
    if type(step) ~= 'table' then
        return L['Set Mark']
    end

    local unit = type(step.unit) == 'string' and platform:IsMarkActionUnit(step.unit) and self.units[step.unit] or nil
    local mark = type(step.action) == 'string' and platform.RaidMarkActions.marks[step.action] or nil

    if not unit or not mark then
        return L['Set Mark']
    end
    if mark == 0 then
        return string.format(L['Clear the mark on %s'], unit)
    end

    return string.format(L['Set %s on %s'], platform:GetRaidMarkName(mark), unit)
end

-- Describes the pseudo spell id of a Set Mark step in words, for the preview window's tooltip.
-- Arguments:
--   id (any): a spell id or pseudo spell id.
-- Returns:
--   text (string|nil): the same sentence as DescribeMarkStep; nil for a real spell id.
function addon:DescribeMarkAction(id)
    local unit, mark = platform:DecodeMarkActionId(id)

    if not unit then
        return nil
    end

    local marks = platform.RaidMarks.keys
    return self:DescribeMarkStep({ unit = unit, action = mark == 0 and platform.RaidMarkActions.none or marks[mark] })
end

-- Gives the icon a Set Mark step shows on its card.
-- Arguments:
--   step (table): a rotation step of type mark.
-- Returns:
--   texture (string): the chosen mark's icon, or the generic question mark while it is not filled in.
function addon:GetMarkStepIcon(step)
    local mark = type(step) == 'table' and type(step.action) == 'string' and platform.RaidMarkActions.marks[step.action]
    return platform:GetRaidMarkTexture(mark or 0)
end

-- Starts the Bind flow for a pair: makes the character macro that presses the step's button, if it does not exist, and
-- puts it on the cursor so the player can drop it on an action bar slot.
-- Arguments:
--   unit (string): a unit token from the whitelist.
--   action (string): a mark word or none.
-- Returns:
--   ok (boolean): true when the macro is on the cursor.
--   detail (string): the macro name when ok, else the reason: 'invalid-mark-step', 'unsupported', 'combat', 'cursor',
--     'macros-full', 'missing-api' or 'api-error'.
function addon:BeginMarkBind(unit, action)
    local mark = type(action) == 'string' and platform.RaidMarkActions.marks[action]
    local id = type(unit) == 'string' and mark and platform:GetMarkActionId(unit, mark)

    if not id or not platform:IsMarkActionUnit(unit) then
        return false, 'invalid-mark-step'
    end
    if platform:GetMarkActionSupport() then
        return false, 'unsupported'
    end
    if inCombat() then
        return false, 'combat'
    end
    if type(GetCursorInfo) == 'function' and GetCursorInfo() then
        return false, 'cursor'
    end

    local ready, reason = self:EnsureMarkButton(id)

    if not ready then
        return false, reason
    end

    local index, why = platform:CreateMarkBarMacro(unit, mark)

    if not index then
        return false, why
    end
    if not platform:PickupMarkBarMacro(index) then
        return false, 'api-error'
    end

    return true, (platform:GetMarkBarMacro(unit, mark))
end
