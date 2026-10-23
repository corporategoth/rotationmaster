local _,addon=...
local platform=addon.Platform

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

local function method(name)
    local namespace=C_AssistedCombat
    if type(namespace)~='table' then return nil end
    local fn=namespace[name]
    if type(fn)=='function' then return fn end
end
local function spellID(value)
    return type(value)=='number' and value>0 and value<math.huge and value%1==0
end

-- Whether the game offers Assisted Combat to this character and spec. The
-- second value is Blizzard's own failure text when it does not.
function platform:GetAssistedCombatAvailability()
    local fn=method('IsAvailable')
    if not fn then return nil,'missing-api' end
    local ok,available,reason=pcall(fn)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(available) or not self:CanReadValue(reason) then return nil,'restricted-value' end
    if type(available)~='boolean' then return nil,'invalid-api-result' end
    return available,type(reason)=='string' and reason~='' and reason or nil
end

-- The spell Assisted Combat suggests casting next, regardless of which
-- buttons are on the bars (checkForVisibleButton=false, as MaxDps reads it).
-- false: available, but nothing is suggested right now.
function platform:GetAssistedSuggestion()
    local next=method('GetNextCastSpell')
    if not next then return nil,'missing-api' end
    local available,why=self:GetAssistedCombatAvailability()
    if available==false then return nil,'assisted-unavailable' end
    if available==nil and why~='missing-api' then return nil,why end
    local ok,spell=pcall(next,false)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(spell) then return nil,'restricted-value' end
    if spell==nil or spell==0 then return false end
    if not spellID(spell) then return nil,'invalid-api-result' end
    return spell
end

-- The specialization's Assisted Combat rotation set, as a fresh array.
function platform:GetAssistedRotationSpells()
    local fn=method('GetRotationSpells')
    if not fn then return nil,'missing-api' end
    local ok,spells=pcall(fn)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(spells) then return nil,'restricted-value' end
    if type(spells)~='table' then return nil,'invalid-api-result' end
    local result={}
    for index=1,#spells do
        local spell=spells[index]
        if not self:CanReadValue(spell) then return nil,'restricted-value' end
        if not spellID(spell) then return nil,'invalid-api-result' end
        result[index]=spell
    end
    return result
end

-- The spell behind the one-button assistant action, false when none.
function platform:GetAssistedActionSpell()
    local fn=method('GetActionSpell')
    if not fn then return nil,'missing-api' end
    local ok,spell=pcall(fn)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(spell) then return nil,'restricted-value' end
    if spell==nil or spell==0 then return false end
    if not spellID(spell) then return nil,'invalid-api-result' end
    return spell
end

-- Override relations (C_Spell.GetBaseSpell / GetOverrideSpell, Retail and
-- Forever): both return the argument when there is no override. Unreadable
-- or missing relations are reported, never guessed.
local function relation(self,name,spell)
    local namespace=C_Spell
    local fn=type(namespace)=='table' and namespace[name] or nil
    if type(fn)~='function' then return nil,'missing-api' end
    local ok,value=pcall(fn,spell)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(value) then return nil,'restricted-value' end
    if not spellID(value) then return nil,'invalid-api-result' end
    return value
end

-- Spell IDs under which the suggestion may sit on an action button: the
-- suggestion itself, then its base spell and its current override.
function platform:GetAssistedSpellCandidates(spell)
    if not spellID(spell) then return {} end
    local result={spell}
    for _,name in ipairs({'GetBaseSpell','GetOverrideSpell'}) do
        local other=relation(self,name,spell)
        if other and other~=result[1] and other~=result[2] then result[#result+1]=other end
    end
    return result
end

-- Whether a chosen spell is the suggested one. Either may be an override of
-- the other (Hammer of Light suggested while the condition names Wake of
-- Ashes, or the reverse), so two spells match when they share a base spell.
function platform:IsAssistedSpellMatch(spell,suggestion)
    if not spellID(spell) or not spellID(suggestion) then return nil,'invalid-spell' end
    if spell==suggestion then return true end
    local suggestedBase,suggestedWhy=relation(self,'GetBaseSpell',suggestion)
    if suggestedBase==spell then return true end
    local chosenBase,chosenWhy=relation(self,'GetBaseSpell',spell)
    if chosenBase and (chosenBase==suggestion or chosenBase==suggestedBase) then return true end
    if suggestedWhy=='restricted-value' or chosenWhy=='restricted-value' then return nil,'restricted-value' end
    return false
end
