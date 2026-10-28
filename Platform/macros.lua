-- Platform adapter for macro buttons: GetMacroItem and GetMacroSpell.
-- Owns platform:GetMacroAction, the `value or nil, reason` reader that says which item or spell an existing macro
-- uses; it must not parse, run or reconstruct a macro body. Runs only under the probe policy (a restricted client
-- answers "unsupported-policy"). Observed on every poll, so it reads the session-fixed policy through the shared
-- reader. Loaded from RotationMaster.toc after Platform/glyphs.lua; uses platform:GetItemID and
-- platform:GetItemUseSpell from Platform/items.lua.
local _, addon = ...
local platform = addon.Platform

-- Macro buttons are observed every poll: read the session-fixed policy
-- through the shared reader rather than building client metadata each time.
local function readClientPolicy(current)
    return current:GetClientInfo().combatDataPolicy
end

---@type function
local consumeClientPolicy = addon.ConsumeClientPolicyReader

if type(consumeClientPolicy) == 'function' then
    readClientPolicy = consumeClientPolicy(addon)
end

-- True for a positive whole number.
local function id(value)
    return type(value) == 'number' and value > 0 and value < math.huge and value % 1 == 0
end

-- True for a non-empty string of at most 1024 characters.
local function text(value)
    return type(value) == 'string' and #value > 0 and #value <= 1024
end

-- Extracts the item id from a plain or hyperlink item string (colors stripped), or nil when the link is not one.
local function linkedItemID(link)
    local plain = link:gsub('^|c%x%x%x%x%x%x%x%x', ''):gsub('|r$', '')

    local digits = plain:match('^item:(%d+)$')
        or plain:match('^item:(%d+):[^|]*$')
        or plain:match('^|Hitem:(%d+)|h.-|h$')
        or plain:match('^|Hitem:(%d+):[^|]*|h.-|h$')

    local value = digits and tonumber(digits)
    return id(value) and value or nil
end

-- Resolve only the action Blizzard exposes for an existing macro. This does
-- not parse, execute or reconstruct a macro body or its hidden decisions.
-- macro is a macro index or name. Returns { kind = "item", itemID, spellID } or { kind = "spell", spellID }, or nil
-- and a reason code.
function platform:GetMacroAction(macro)
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
