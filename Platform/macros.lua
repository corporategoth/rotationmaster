-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for macro buttons: GetMacroItem and GetMacroSpell.
-- Owns platform:GetMacroAction, the `value or nil, reason` reader that says which item or spell an existing macro
-- uses; it must not parse, run or reconstruct a macro body. Runs only under the probe policy (a restricted client
-- answers "unsupported-policy"). Observed on every poll, so it reads the session-fixed policy through the shared
-- reader. Loaded from RotationMaster.toc after Platform/glyphs.lua; uses platform:GetItemID and
-- platform:GetItemUseSpell from Platform/items.lua.
local _, addon = ...
local platform = addon.Platform

-- Reads the combat data policy of the client.
-- @param current table  The platform table whose client info is read.
-- @return string  The policy name: "probe", "restricted" or another value for an unsupported client.
--
-- Macro buttons are observed every poll: the session-fixed policy is read through the shared reader (replaced just
-- below by the allocation-free one from Platform/client.lua) rather than building client metadata each time.
local function readClientPolicy(current)
    return current:GetClientInfo().combatDataPolicy
end

---@type function
local consumeClientPolicy = addon.ConsumeClientPolicyReader

if type(consumeClientPolicy) == 'function' then
    readClientPolicy = consumeClientPolicy(addon)
end

-- Whether a value is a positive whole number.
-- @param value any  The value to test.
-- @return boolean  True for a positive integer.
local function id(value)
    return type(value) == 'number' and value > 0 and value < math.huge and value % 1 == 0
end

-- Whether a value is a non-empty string of at most 1024 characters.
-- @param value any  The value to test.
-- @return boolean  True for such a string.
local function text(value)
    return type(value) == 'string' and #value > 0 and #value <= 1024
end

-- Extracts the item id from a plain or hyperlink item string (colors stripped).
-- @param link string  The item link or "item:<id>" string.
-- @return number|nil  The item id; nil when the link is not an item link.
local function linkedItemID(link)
    local plain = link:gsub('^|c%x%x%x%x%x%x%x%x', ''):gsub('|r$', '')

    local digits = plain:match('^item:(%d+)$')
        or plain:match('^item:(%d+):[^|]*$')
        or plain:match('^|Hitem:(%d+)|h.-|h$')
        or plain:match('^|Hitem:(%d+):[^|]*|h.-|h$')

    local value = digits and tonumber(digits)
    return id(value) and value or nil
end

-- Resolves the item or spell an existing macro uses (GetMacroItem, then GetMacroSpell).
-- @param macro number|string  The macro index or name.
-- @return table|nil  { kind = "item", itemID, spellID } or { kind = "spell", spellID }; nil when it cannot be
--   resolved.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Only the action Blizzard exposes for an existing macro is resolved; this does not parse, execute or reconstruct a
-- macro body or its hidden decisions.
function platform:GetMacroAction(macro)
    -- A macro that presses a Set Mark button (Platform/raid_mark_actions.lua) stands for that step's pseudo spell id.
    -- Answered before the policy gate: the macro body is plain text, readable on every client, and nothing is parsed
    -- but the button name.
    local mark = self.GetMarkMacroActionId and self:GetMarkMacroActionId(macro)

    if mark then
        return { kind = 'mark', spellID = mark }
    end
    if readClientPolicy(self) ~= 'probe' then
        return nil, 'unsupported-policy'
    end
    if not self:CanReadValue(macro) then
        return nil, 'restricted-value'
    end
    if not (id(macro) or text(macro)) then
        return nil, 'invalid-macro'
    end
    if type(GetMacroItem) ~= 'function' then
        return nil, 'missing-api'
    end

    local ok, name, link = pcall(GetMacroItem, macro)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(name) or not self:CanReadValue(link) then
        return nil, 'restricted-value'
    end
    if name ~= nil and not text(name) or link ~= nil and not text(link) then
        return nil, 'invalid-api-result'
    end

    if name ~= nil or link ~= nil then
        if link == nil then
            return nil, 'macro-item-unavailable'
        end

        local expected = linkedItemID(link)

        if not expected then
            return nil, 'invalid-api-result'
        end

        local item, reason = self:GetItemID(link)

        if not item then
            return nil, reason
        end
        if item ~= expected then
            return nil, 'invalid-api-result'
        end

        local use, why = self:GetItemUseSpell(item)

        if not use then
            return nil, why
        end

        return { kind = 'item', itemID = item, spellID = use.spellID }
    end

    -- Both nil from a successful item query is observed absence. A failed or
    -- missing item query above must never become a spell-only ownership bypass.
    if type(GetMacroSpell) ~= 'function' then
        return nil, 'missing-api'
    end

    ---@diagnostic disable-next-line: unbalanced-assignments
    local success, first, rank, spell = pcall(GetMacroSpell, macro)

    if not success then
        return nil, 'api-error'
    end
    if not self:CanReadValue(first) or not self:CanReadValue(rank) or not self:CanReadValue(spell) then
        return nil, 'restricted-value'
    end
    if first == nil and rank == nil and spell == nil then
        return nil, 'macro-action-unavailable'
    end
    if id(first) and rank == nil and spell == nil then
        return { kind = 'spell', spellID = first }
    end
    if text(first) and (rank == nil or type(rank) == 'string') and id(spell) then
        return { kind = 'spell', spellID = spell }
    end

    return nil, 'invalid-api-result'
end
