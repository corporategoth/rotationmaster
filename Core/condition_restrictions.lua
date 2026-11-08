-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Where the game hides a condition's data on restricted clients (Retail, Forever). A Built In condition that can work on
-- the client may still be unavailable in some situations: Blizzard's generated documentation says, per API, when its
-- values turn secret (SecretPredicatesDocumentation.lua: combat, boss encounters, Mythic+, PvP matches, restricted maps,
-- or a unit that is not you). This file declares those situations per condition and turns them into sentences the
-- editor shows next to the condition; per spell, C_Secrets.GetSpell*Secrecy refines them (a spell the game flags never
-- secret has no note, one flagged always secret says so). It never evaluates a condition and only answers on the
-- restricted combat data policy; docs/restricted-clients.md has the classification. Loaded from RotationMaster.toc
-- after Core/condition_support.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- What hides each condition
-- ============================================================================

-- Situations, each one note shown as a whole sentence (fallback and totems are not situations but what can still
-- answer: Platform/cooldown_viewer.lua, the remembered values in Platform/auras.lua and Platform/spells.lua, and the
-- tracked totem slots in Platform/totems.lua):
--   restricted  combat, encounter, challenge mode or PvP match restrictions (SecretWhenUnitAuraRestricted,
--               SecretWhenCooldownsRestricted, SecretWhenTotemSlotSecret)
--   combat      unit stats (SecretWhenUnitStatsRestricted; secret in combat in game, Hekili Forever's probes)
--   identity    a unit that is not player-controlled or in your group (SecretWhenUnitIdentityRestricted and the name
--               variant)
--   cast        a unit other than you or your pet (SecretWhenUnitSpellCastRestricted)
--   map         dungeons and raids (SecretWhenUnitComparisonRestricted; UnitPosition is nil there)
-- `secrecy` names the C_Secrets reader that refines the note for the condition's saved spell.
local AURA = { 'restricted', 'fallback', secrecy = 'GetSpellAuraSecrecy' }
local COOLDOWN = { 'restricted', 'fallback', secrecy = 'GetSpellCooldownSecrecy' }
local TOTEM = { 'restricted', 'totems', secrecy = 'GetSpellAuraSecrecy' }
local CAST = { 'cast', unitBound = true, secrecy = 'GetSpellCastSecrecy' }
local IDENTITY = { 'identity', unitBound = true }

local restrictions = {
    BUFF = AURA,
    BUFF_REMAIN = AURA,
    BUFF_STACKS = AURA,
    DEBUFF = AURA,
    DEBUFF_REMAIN = AURA,
    DEBUFF_STACKS = AURA,
    DISPELLABLE = AURA,
    STEALABLE = AURA,
    SPELL_COOLDOWN = COOLDOWN,
    SPELL_CHARGES = COOLDOWN,
    SPELL_REMAIN = COOLDOWN,
    ANYSPELL_COOLDOWN = COOLDOWN,
    ANYSPELL_CHARGES = COOLDOWN,
    ANYSPELL_REMAIN = COOLDOWN,
    PETSPELL_COOLDOWN = COOLDOWN,
    PETSPELL_CHARGES = COOLDOWN,
    PETSPELL_REMAIN = COOLDOWN,
    TOTEM = TOTEM,
    TOTEM_REMAIN = TOTEM,
    TOTEM_SPELL = TOTEM,
    TOTEM_SPELL_REMAIN = TOTEM,
    CASTING_SPELL = CAST,
    CASTING_REMAIN = CAST,
    CASTING_PROGRESS = CAST,
    CAST_INTERRUPTABLE = CAST,
    CHANNELING_SPELL = CAST,
    CHANNELING_REMAIN = CAST,
    CHANNELING_PROGRESS = CAST,
    CHANNEL_INTERRUPTABLE = CAST,
    CLASS = IDENTITY,
    CREATURE = IDENTITY,
    PVP = IDENTITY,
    IMMUNE = IDENTITY,
    RESIST = IDENTITY,
    RUNNER = IDENTITY,
    STAT = { 'combat' },
    SWING_TIME = { 'combat' },
    ISSAME = { 'map' },
    ENEMIES_TARGETING = { 'map' },
    PROXIMITY = { 'map' },
}

addon.conditionRestrictions = restrictions

local noteText = {
    restricted = L['The game hides this in combat, during boss encounters, in Mythic+ and in PvP matches.'],
    combat = L['The game hides this in combat.'],
    identity = L['The game hides this for units that are not you, your pet or in your group.'],
    cast = L['The game hides this for anyone but you and your pet.'],
    map = L['The game hides this in dungeons and raids.'],
    always = L['The game always hides this for the chosen spell.'],
    fallback = L['Blizzard\'s Cooldown Manager, or the last readable value when Remember hidden buffs and cooldowns is on, can still answer for your own buffs and cooldowns.'],
    totems = L['Your own totems are still followed from the game\'s totem events once their duration has been seen.'],
}

-- Units whose identity and casts these predicates never hide; group unit kinds are added by ownUnit below.
local ownUnits = { player = true, pet = true }

-- ============================================================================
-- Answers
-- ============================================================================

-- True when the unit field names you, your pet or a group member, whose identity and casts the game shows.
-- @param unit any  The saved unit field.
-- @return boolean  True for player, pet or a group unit kind (addon.groupUnitKinds).
local function ownUnit(unit)
    return ownUnits[unit] == true or type(addon.groupUnitKinds) == 'table' and addon.groupUnitKinds[unit] ~= nil
end

-- Reads the game's secrecy level for the saved spell, when the condition names one by ID.
-- @param reader string  The C_Secrets function name.
-- @param spell any  The saved spell field.
-- @return number|nil  Enum.SecrecyLevel (0 never, 1 always, 2 contextual); nil when it cannot be read.
local function spellSecrecy(reader, spell)
    local secrets = C_Secrets
    local platform = addon.Platform

    if type(spell) ~= 'number' or type(secrets) ~= 'table' or type(secrets[reader]) ~= 'function' or not platform then
        return nil
    end

    local ok, level = pcall(secrets[reader], spell)

    if not ok or not platform:CanReadValue(level) or type(level) ~= 'number' then
        return nil
    end

    return level
end

-- Lists the situations in which the game hides this condition's data on this client.
-- @param tag string  The condition tag.
-- @param value table|nil  The saved condition, for its unit and spell fields.
-- @return table|nil  Note keys in display order ('restricted', 'combat', 'identity', 'cast', 'map', 'always'); nil when
--   nothing hides it here (not a restricted client, an unlisted condition, your own unit, or a never-secret spell).
function addon:GetConditionRestrictions(tag, value)
    local entry = restrictions[tag]
    local platform = self.Platform

    if not entry or not platform or platform:GetCombatDataPolicy() ~= 'restricted' then
        return nil
    end

    value = type(value) == 'table' and value or {}

    if entry.unitBound and ownUnit(value.unit) then
        return nil
    end

    local level = entry.secrecy and spellSecrecy(entry.secrecy, value.spell)

    if level == 0 then
        return nil
    end
    if level == 1 then
        return { 'always' }
    end

    local notes = {}

    for _, key in ipairs(entry) do
        notes[#notes + 1] = key
    end

    return notes
end

-- Describes where the game hides this condition's data, for the editor.
-- @param tag string  The condition tag.
-- @param value table|nil  The saved condition.
-- @return string|nil  One or more localized sentences; nil when nothing hides it on this client.
function addon:DescribeConditionRestrictions(tag, value)
    local notes = self:GetConditionRestrictions(tag, value)

    if not notes then
        return nil
    end

    local text = {}

    for _, key in ipairs(notes) do
        text[#text + 1] = noteText[key]
    end

    text[#text + 1] = L['While hidden, the condition is unavailable: a Branch or Stop waits and an action is skipped.']
    return table.concat(text, ' ')
end
