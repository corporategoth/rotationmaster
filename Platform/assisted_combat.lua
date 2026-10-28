-- Platform adapter for C_AssistedCombat, C_Spell override relations and the assisted highlight CVar.
-- Owns the `value or nil, reason` readers for Blizzard's suggested spell, its rotation set and availability, the
-- spell-matching rules between a chosen spell and the suggestion, and the one writer in this file, the highlight CVar
-- (outside combat only). It must not cast, press a button or choose between suggestions. Every read is
-- feature-detected and protected (docs/restricted-clients.md). Loaded from RotationMaster.toc after
-- Platform/spells.lua.
local _, addon = ...
local platform = addon.Platform

-- Blizzard Assisted Combat: the game's own next-spell pick (the one-button
-- assistant and the action bar highlight). On Retail Midnight this is the
-- only rotation guidance an addon can still read in combat.
--
-- Contract (Blizzard's generated API documentation, Gethe/wow-ui-source):
--   live e7aa82019dc298e0351c7159d60c2a9b916b9b67 (12.1.5.70529, 2026-10-22)
--   Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua
--     C_AssistedCombat.GetNextCastSpell(checkForVisibleButton: bool = false) -> spellID: number?
--       (SecretArguments "AllowedWhenUntainted"; the return carries no secret flag)
--     C_AssistedCombat.GetRotationSpells() -> spellIDs: number[] (never nil)
--     C_AssistedCombat.GetActionSpell() -> spellID: number?  (the one-button action's spell)
--     C_AssistedCombat.IsAvailable() -> isAvailable: bool, failureReason: string
--     event ASSISTED_COMBAT_ACTION_SPELL_CAST (synchronous)
--   Blizzard_ActionBar/Mainline/AssistedCombatManager.lua polls
--   GetNextCastSpell(true) from OnUpdate at the assistedCombatIconUpdateRate
--   CVar and compares the result with each action button's spell ID.
-- forever ca8368f2f2380cbe696854f7f2646387c278a61b (1.60.1.70532): the same
-- file, byte for byte. classic 45eb466d (5.5.4), classic_era 8165d4cd (1.15.9)
-- and classic_anniversary 2cfec7c0 (2.5.6) declare the same four functions
-- (without the secret-argument note) but ship no AssistedCombatManager, so a
-- Classic-family client may expose the namespace while IsAvailable() is false.
--
-- Every function is feature-detected and protected. Results are value, reason:
-- nil plus a reason when nothing usable could be read ("missing-api",
-- "api-error", "restricted-value", "assisted-unavailable",
-- "invalid-api-result"); false when the game positively has no suggestion.

-- ============================================================================
-- Assisted Combat readers
-- ============================================================================

-- Returns the named C_AssistedCombat function, or nil when the namespace or the function does not exist.
local function method(name)
    local namespace = C_AssistedCombat

    if type(namespace) ~= 'table' then
        return nil
    end

    local fn = namespace[name]

    if type(fn) == 'function' then
        return fn
    end
end

-- True for a positive whole number, the only shape a spell id may have.
local function spellID(value)
    return type(value) == 'number' and value > 0 and value < math.huge and value % 1 == 0
end

-- Whether the game offers Assisted Combat to this character and spec. The
-- second value is Blizzard's own failure text when it does not.
function platform:GetAssistedCombatAvailability()
    local fn = method('IsAvailable')

    if not fn then
        return nil, 'missing-api'
    end

    local ok, available, reason = pcall(fn)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(available) or not self:CanReadValue(reason) then
        return nil, 'restricted-value'
    end
    if type(available) ~= 'boolean' then
        return nil, 'invalid-api-result'
    end

    return available, type(reason) == 'string' and reason ~= '' and reason or nil
end

-- The spell Assisted Combat suggests casting next, regardless of which
-- buttons are on the bars (checkForVisibleButton=false, as MaxDps reads it).
-- false: available, but nothing is suggested right now.
function platform:GetAssistedSuggestion()
    local next = method('GetNextCastSpell')

    if not next then
        return nil, 'missing-api'
    end

    local available, why = self:GetAssistedCombatAvailability()

    if available == false then
        return nil, 'assisted-unavailable'
    end
    if available == nil and why ~= 'missing-api' then
        return nil, why
    end

    local ok, spell = pcall(next, false)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(spell) then
        return nil, 'restricted-value'
    end
    if spell == nil or spell == 0 then
        return false
    end
    if not spellID(spell) then
        return nil, 'invalid-api-result'
    end

    return spell
end

-- The specialization's Assisted Combat rotation set, as a fresh array.
function platform:GetAssistedRotationSpells()
    local fn = method('GetRotationSpells')

    if not fn then
        return nil, 'missing-api'
    end

    local ok, spells = pcall(fn)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(spells) then
        return nil, 'restricted-value'
    end
    if type(spells) ~= 'table' then
        return nil, 'invalid-api-result'
    end

    local result = {}

    for index = 1, #spells do
        local spell = spells[index]

        if not self:CanReadValue(spell) then
            return nil, 'restricted-value'
        end
        if not spellID(spell) then
            return nil, 'invalid-api-result'
        end

        result[index] = spell
    end

    return result
end

-- The spell behind the one-button assistant action, false when none.
function platform:GetAssistedActionSpell()
    local fn = method('GetActionSpell')

    if not fn then
        return nil, 'missing-api'
    end

    local ok, spell = pcall(fn)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(spell) then
        return nil, 'restricted-value'
    end
    if spell == nil or spell == 0 then
        return false
    end
    if not spellID(spell) then
        return nil, 'invalid-api-result'
    end

    return spell
end

-- Override relations (C_Spell.GetBaseSpell / GetOverrideSpell, Retail and
-- Forever): both return the argument when there is no override. Unreadable
-- or missing relations are reported, never guessed.
-- Returns the result of C_Spell[name](spell) (GetBaseSpell or GetOverrideSpell) when it is a valid spell id, or nil
-- and a reason code.
local function relation(self, name, spell)
    local namespace = C_Spell
    local fn = type(namespace) == 'table' and namespace[name] or nil

    if type(fn) ~= 'function' then
        return nil, 'missing-api'
    end

    local ok, value = pcall(fn, spell)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(value) then
        return nil, 'restricted-value'
    end
    if not spellID(value) then
        return nil, 'invalid-api-result'
    end

    return value
end

-- Spell IDs under which the suggestion may sit on an action button: the
-- suggestion itself, then its base spell and its current override.
function platform:GetAssistedSpellCandidates(spell)
    if not spellID(spell) then
        return {}
    end

    local result = { spell }

    for _, name in ipairs({ 'GetBaseSpell', 'GetOverrideSpell' }) do
        local other = relation(self, name, spell)

        if other and other ~= result[1] and other ~= result[2] then
            result[#result + 1] = other
        end
    end

    return result
end

-- Whether a chosen spell is the suggested one. Either may be an override of
-- the other (Hammer of Light suggested while the condition names Wake of
-- Ashes, or the reverse), so two spells match when they share a base spell.
function platform:IsAssistedSpellMatch(spell, suggestion)
    if not spellID(spell) or not spellID(suggestion) then
        return nil, 'invalid-spell'
    end
    if spell == suggestion then
        return true
    end

    local suggestedBase, suggestedWhy = relation(self, 'GetBaseSpell', suggestion)

    if suggestedBase == spell then
        return true
    end

    local chosenBase, chosenWhy = relation(self, 'GetBaseSpell', spell)

    if chosenBase and (chosenBase == suggestion or chosenBase == suggestedBase) then
        return true
    end
    if suggestedWhy == 'restricted-value' or chosenWhy == 'restricted-value' then
        return nil, 'restricted-value'
    end

    return false
end

-- Rotation-set membership: "is this spell one Assisted Combat may suggest for
-- the current specialization". Blizzard's own AssistedCombatManager rebuilds
-- its set only on SPELLS_CHANGED, so this keeps one reused set and refreshes
-- it on the same event (and on a specialization change). A failed read is
-- retried on the next call rather than cached. Nothing is created until the
-- first membership question, so profiles that never ask pay nothing.
local rotationSet, rotationDirty, rotationWatcher = {}, true, nil

-- Creates, once, the event frame that marks the cached rotation set stale. Returns the frame, or false when no frame
-- could be made or no event registered; the caller then rereads on every call instead of trusting the cache.
local function watchRotationSet()
    if rotationWatcher ~= nil then
        return rotationWatcher
    end

    rotationWatcher = false

    if type(CreateFrame) ~= 'function' then
        return false
    end

    local ok, frame = pcall(CreateFrame, 'Frame')

    if
        not ok
        or type(frame) ~= 'table'
        or type(frame.RegisterEvent) ~= 'function'
        or type(frame.SetScript) ~= 'function'
    then
        return false
    end

    frame:SetScript('OnEvent', function()
        rotationDirty = true
    end)

    local watching = false

    for _, event in ipairs({ 'SPELLS_CHANGED', 'PLAYER_SPECIALIZATION_CHANGED' }) do
        if pcall(frame.RegisterEvent, frame, event) then
            watching = true
        end
    end

    if watching then
        rotationWatcher = frame
    end

    return rotationWatcher
end

-- Returns the reused set of spell ids Assisted Combat may suggest, rebuilt when it is stale, or nil and a reason code.
-- The returned table is shared; callers must only read it. A failed rebuild leaves it marked stale.
local function rotationMembership(self)
    local watched = watchRotationSet()

    if rotationDirty or not watched then
        local fn = method('GetRotationSpells')

        if not fn then
            return nil, 'missing-api'
        end

        local ok, spells = pcall(fn)

        if not ok then
            return nil, 'api-error'
        end
        if not self:CanReadValue(spells) then
            return nil, 'restricted-value'
        end
        if type(spells) ~= 'table' then
            return nil, 'invalid-api-result'
        end

        for spell in pairs(rotationSet) do
            rotationSet[spell] = nil
        end

        for index = 1, #spells do
            local spell = spells[index]

            if not self:CanReadValue(spell) then
                rotationDirty = true
                return nil, 'restricted-value'
            end

            if not spellID(spell) then
                rotationDirty = true
                return nil, 'invalid-api-result'
            end

            rotationSet[spell] = true
        end

        rotationDirty = false
    end

    return rotationSet
end

-- Whether a chosen spell is in this specialization's Assisted Combat rotation
-- set. As in Blizzard's own tooltip line, the spell's current override and its
-- base spell count too (Wake of Ashes while Hammer of Light is listed, or the
-- reverse). Unavailable when Assisted Combat is not offered here.
function platform:IsAssistedRotationSpell(spell)
    if not spellID(spell) then
        return nil, 'invalid-spell'
    end

    local available, why = self:GetAssistedCombatAvailability()

    if available == false then
        return nil, 'assisted-unavailable'
    end
    if available == nil and why ~= 'missing-api' then
        return nil, why
    end

    local set, reason = rotationMembership(self)

    if not set then
        return nil, reason
    end
    if set[spell] then
        return true
    end

    local override, overrideWhy = relation(self, 'GetOverrideSpell', spell)

    if override and set[override] then
        return true
    end

    local base, baseWhy = relation(self, 'GetBaseSpell', spell)

    if base and set[base] then
        return true
    end
    if overrideWhy == 'restricted-value' or baseWhy == 'restricted-value' then
        return nil, 'restricted-value'
    end

    return false
end

-- ============================================================================
-- Assisted Highlight CVar
-- ============================================================================

-- Blizzard's Assisted Highlight: the action-bar glow Blizzard's own
-- AssistedCombatManager draws on the suggested spell's button while the
-- character CVar assistedCombatHighlight is on (default off; Blizzard's
-- Options > Gameplay > Combat > Assisted Highlight sets it with SetCVar).
-- The manager loads only for the Mainline game type, so Retail has it and
-- Forever (game type camelot, whose InterfaceOverrides.HasAssistedCombat()
-- is false) and the Classic clients do not, even where the API namespace and
-- the CVar exist. Sources: live e7aa82019d and forever ca8368f2f2,
-- Blizzard_ActionBar/Blizzard_ActionBar.toc, AssistedCombatManager.lua,
-- Blizzard_SettingsDefinitions_Frame/AdvancedOptions.lua.
local HIGHLIGHT_CVAR = 'assistedCombatHighlight'
platform.ASSISTED_HIGHLIGHT_CVAR = HIGHLIGHT_CVAR

-- Returns C_CVar[name] or the legacy global of the same name, or nil when neither exists.
local function cvarFunction(name)
    local namespace = C_CVar

    if type(namespace) == 'table' and type(namespace[name]) == 'function' then
        return namespace[name]
    end

    local legacy = _G[name]

    if type(legacy) == 'function' then
        return legacy
    end
end

-- The CVar's raw value ("0" or "1"), or nil plus a reason.
function platform:GetAssistedHighlightCVar()
    local get = cvarFunction('GetCVar')

    if not get then
        return nil, 'missing-api'
    end

    local ok, value = pcall(get, HIGHLIGHT_CVAR)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(value) then
        return nil, 'restricted-value'
    end
    if value == nil then
        return nil, 'missing-cvar'
    end
    if type(value) ~= 'string' and type(value) ~= 'number' then
        return nil, 'invalid-api-result'
    end

    return tostring(value)
end

-- Whether Blizzard's highlight can be used on this client: the Assisted
-- Combat API, the CVar and Blizzard's highlighter must all exist. Being
-- unavailable for the current specialization is a separate, changing fact
-- (GetAssistedCombatAvailability).
function platform:GetAssistedHighlightSupport()
    if type(C_AssistedCombat) ~= 'table' or not method('GetNextCastSpell') then
        return nil, 'missing-api'
    end
    if not cvarFunction('SetCVar') then
        return nil, 'missing-api'
    end

    local value, why = self:GetAssistedHighlightCVar()

    if value == nil then
        return nil, why
    end
    if type(AssistedCombatManager) ~= 'table' then
        return nil, 'missing-highlighter'
    end

    return true
end

-- Writes the CVar, outside combat only (never from protected-state code),
-- and reads it back. Returns the value now in effect, or nil plus a reason.
function platform:SetAssistedHighlightCVar(value)
    if type(value) ~= 'string' then
        return nil, 'invalid-value'
    end

    if type(InCombatLockdown) == 'function' then
        local ok, locked = pcall(InCombatLockdown)

        if not ok or locked ~= false and locked ~= nil then
            return nil, 'combat-lockdown'
        end
    end

    local set = cvarFunction('SetCVar')

    if not set then
        return nil, 'missing-api'
    end
    if not pcall(set, HIGHLIGHT_CVAR, value) then
        return nil, 'api-error'
    end

    return self:GetAssistedHighlightCVar()
end
