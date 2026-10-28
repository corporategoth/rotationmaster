-- Declares which Built In conditions can ever work on the running client. A condition lists the capabilities it needs
-- (combat data policy, client family, native APIs, edition rules, value-dependent gates) and addon:GetConditionSupport
-- answers `nil` when it can work or a permanent reason code; a rotation using an unsupported condition is incomplete,
-- which differs from "unavailable this poll". Owns the requirement table and reason texts; it only reads the platform's
-- cached client facts and global lookups, never evaluates a condition and never caches. Restricted clients (Retail,
-- Forever) hide secret values: docs/restricted-clients.md classifies each condition. Loaded from RotationMaster.toc
-- after Core/conditions.lua; the validation stamp (Core/rotation_references.lua) moves when the client facts change.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- BEGIN CONDITION CLIENT SUPPORT
-- A condition that can never work on this client is incomplete, not
-- momentarily unavailable. Each Built In condition declares here the client
-- capabilities its evaluation path requires: the combat data policy, the
-- client family, and the native APIs its readers feature-detect (any one
-- name of a group suffices, as the reader falls back). Validation reads
-- these declarations, so a rotation or cooldown that uses an unsupported
-- condition is unresolved and inactive through the ordinary eligibility
-- path. The condition itself is never evaluated here: a check is a policy
-- read and a few global lookups. Momentary causes (secret this poll, range
-- uncertain, data loading, no GUID yet) stay runtime-only.
--
-- A definition may instead carry its own `supported(value)` returning nil
-- when usable or a reason string; custom definitions are not looked up here.
--
-- Restricted clients (Retail, Forever) hand addons secret values: they can be
-- displayed but never compared. A condition reads there whenever its source
-- can be readable: never-secret sources always, conditionally secret ones
-- (per unit, per spell, per field, or while restrictions apply) whenever the
-- reader's CanReadValue check passes, and a secret value this poll is
-- unavailable. Only a source that is always secret or removed for addons is
-- declared unsupported here. docs/restricted-clients.md has the classification
-- per condition and its evidence.

-- ============================================================================
-- Secrecy helpers
-- ============================================================================

local env = getfenv and getfenv(1) or _G
local POLICY, FAMILY, LISTED, BOSSMOD, LOG = 'policy', 'family', 'listed', 'bossmod', 'log'

-- Resolves a dotted global path in the captured environment.
-- @param path string  A dotted global path such as 'C_Spell.GetSpellCooldown'.
-- @return any  The value at the path; nil when any part is missing.
local function lookup(path)
    local value = env

    for part in path:gmatch('[^.]+') do
        if type(value) ~= 'table' then
            return nil
        end

        value = value[part]
    end

    return value
end

-- Reports whether the client hands out secret values now.
-- @return boolean  True when restrictions apply; a restricted-policy client without the predicate, or one whose answer
--   is unreadable, is restricted.
local function secretRestrictions()
    local secrets = lookup('C_Secrets')

    if type(secrets) ~= 'table' or type(secrets.HasSecretRestrictions) ~= 'function' then
        return true
    end

    local ok, restricted = pcall(secrets.HasSecretRestrictions)
    local platform = addon.Platform

    if not ok or not platform or not platform:CanReadValue(restricted) or type(restricted) ~= 'boolean' then
        return true
    end

    return restricted
end

-- Builds a requirement that is unmet only while the client restricts a secret value.
-- @param reason string  The reason code returned when `secret()` holds.
-- @param secret function  secret(value) returns true when the condition's source is secret.
-- @return function  A requirement function(value) that returns nil on the probe policy and on a restricted client
--   without restrictions; otherwise 'unsupported-policy' for an unknown policy, `reason` when `secret()` holds, or nil.
local function whileRestricted(reason, secret)
    return function(value)
        local platform = addon.Platform

        if not platform then
            return nil
        end

        local policy = platform:GetCombatDataPolicy()

        if policy == 'probe' then
            return nil
        end
        if policy ~= 'restricted' then
            return 'unsupported-policy'
        end
        if secretRestrictions() and secret(value) then
            return reason
        end
    end
end

-- UnitHealth is SecretReturns and UnitHealthMax SecretWhenUnitHealthMaxRestricted
-- in Blizzard's generated documentation (live 12.1.5.70575, forever
-- 1.60.1.70532). On the user's Retail client with restrictions on, UnitHealth
-- and UnitHealthMax were secret for player and target, in and out of combat,
-- and UnitHealthPercent likewise (2026-10-23). Health cannot be compared there.
local SECRET_HEALTH = whileRestricted('secret-health', function() return true end)

-- Reports whether a power type is flagged never secret.
-- @param name string  The Enum.PowerType name, for example 'Mana'.
-- @return boolean  True when the client flags the power never secret (via C_Secrets.GetPowerTypeSecrecy, else the
--   never-secret point resources Blizzard named in Platform/points.lua).
local function neverSecretPower(name)
    local enum = lookup('Enum.PowerType')

    if type(enum) ~= 'table' then
        return false
    end

    local id = rawget(enum, name)
    local platform = addon.Platform

    if not platform:CanReadValue(id) or type(id) ~= 'number' then
        return false
    end

    local query = lookup('C_Secrets.GetPowerTypeSecrecy')

    if type(query) ~= 'function' then
        return type(platform.IsNeverSecretPointPower) == 'function' and platform:IsNeverSecretPointPower(id) or false
    end

    local ok, level = pcall(query, id)

    if not ok or not platform:CanReadValue(level) or type(level) ~= 'number' then
        return false
    end

    local never = lookup('Enum.SecrecyLevel.NeverSecret')

    if not platform:CanReadValue(never) or type(never) ~= 'number' then
        never = 0
    end

    return level == never
end

local SECRET_MANA = whileRestricted('secret-power', function() return not neverSecretPower('Mana') end)

-- The bar a unit's current power reads is one of these; when none is flagged
-- never secret, the current power can never be compared.
local primaryPowers = {
    'Mana', 'Rage', 'Focus', 'Energy', 'RunicPower', 'LunarPower', 'Maelstrom', 'Insanity', 'Fury', 'Pain'
}

local SECRET_POWER = whileRestricted('secret-power', function()
    for _, name in ipairs(primaryPowers) do
        if neverSecretPower(name) then
            return false
        end
    end

    return true
end)

-- ============================================================================
-- Value-dependent gates and edition rules
-- ============================================================================

-- Value-dependent permanent gate for the TALENT condition.
-- @param value table|nil  The condition value (layout, tree, talent, value).
-- @return string|nil  A reason code ('historical-talent-layout', 'unsupported-talent-layout' or
--   'talent-layout-mismatch'); nil when usable.
local function talentLayout(value)
    if type(value) ~= 'table' then
        return nil
    end
    if value.layout == nil and value.tree == nil and value.talent == nil and type(value.value) == 'number' then
        return 'historical-talent-layout'
    end

    local platform = addon.Platform

    if not platform or type(platform.GetTalentLayout) ~= 'function' then
        return nil
    end

    local current, reason = platform:GetTalentLayout()

    if current == nil then
        return reason or 'unsupported-talent-layout'
    end

    local wanted = (value.layout == 'grid' or value.layout == 'traits') and value.layout or 'tree'

    if current ~= wanted then
        return 'talent-layout-mismatch'
    end
end

-- Requirement for the classic talent trees: the tree layout, and Forever, whose three classic trees are trait node
-- groups (Platform/talents.lua GetTraitTreeGroups).
-- @return string|nil  A reason code ('unsupported-talent-layout' or 'talent-layout-mismatch'); nil when usable.
--
-- Retail's trait tree has no such groups.
local function treeLayout()
    local platform = addon.Platform

    if not platform or type(platform.GetTalentLayout) ~= 'function' then
        return nil
    end

    local current, reason = platform:GetTalentLayout()

    if current == nil then
        return reason or 'unsupported-talent-layout'
    end
    if current == 'traits' and platform:GetClientFamily() == 'forever' then
        return nil
    end
    if current ~= 'tree' then
        return 'talent-layout-mismatch'
    end
end

-- Requirement for the POINT condition on progression clients.
-- @return string|nil  'unsupported-point-expansion' when this progression expansion has no known point resource map;
--   nil otherwise.
local function pointEdition()
    local platform = addon.Platform

    if not platform or type(platform.GetClientInfo) ~= 'function' then
        return nil
    end

    local info = platform:GetClientInfo()

    if
        type(info) == 'table'
        and info.family == 'progression'
        and info.expansion ~= 2
        and info.expansion ~= 3
        and info.expansion ~= 4
    then
        return 'unsupported-point-expansion'
    end
end

-- Requirement for the WEAPON_TYPE condition: Mists removed the ranged slot and Retail followed
-- (Core/build_context.lua).
-- @param value table|nil  The condition value (slot).
-- @return string|nil  'no-ranged-slot' when the ranged slot is chosen on a client without one; nil otherwise.
local function weaponSlot(value)
    if type(value) ~= 'table' or value.slot ~= 'ranged' then
        return nil
    end

    local platform = addon.Platform

    if not platform or type(platform.GetClientInfo) ~= 'function' then
        return nil
    end

    local info = platform:GetClientInfo()

    if
        type(info) == 'table'
        and (info.family == 'retail'
            or info.family == 'progression' and type(info.expansion) == 'number' and info.expansion >= 4)
    then
        return 'no-ranged-slot'
    end
end

-- Requirement for the GLYPH condition.
-- @return string|nil  'unsupported-glyph-layout' when the client's glyph layout is not supported; nil otherwise.
local function glyphLayout()
    local platform = addon.Platform

    if not platform or type(platform.IsGlyphLayoutSupported) ~= 'function' then
        return nil
    end
    if not platform:IsGlyphLayoutSupported() then
        return 'unsupported-glyph-layout'
    end
end

-- Builds a requirement for mechanics that exist only in some editions.
-- @param reason string  The reason code returned when the edition lacks the mechanic.
-- @param test function  test(info) receives the client info (family, and for progression the expansion level: 2 Wrath,
--   3 Cataclysm, 4 Mists of Pandaria) and answers whether the edition has the mechanic.
-- @return function  A requirement function() that returns `reason` when the edition lacks the mechanic, else nil.
local function editionRule(reason, test)
    return function()
        local platform = addon.Platform

        if not platform or type(platform.GetClientInfo) ~= 'function' then
            return nil
        end

        local info = platform:GetClientInfo()

        if type(info) ~= 'table' then
            return nil
        end
        if not test(info) then
            return reason
        end
    end
end

-- Reports whether a client is a progression client of at least a given expansion.
-- @param info table  The client info (family, expansion).
-- @param first number  The lowest expansion level that counts.
-- @return boolean  True for a progression client whose expansion level is at least `first`.
local function progressionFrom(info, first)
    return info.family == 'progression' and type(info.expansion) == 'number' and info.expansion >= first
end

local RETAIL_ONLY = editionRule('retail-only', function(info) return info.family == 'retail' end)

local PET_HAPPINESS_EDITION = editionRule('no-pet-happiness', function(info)
    return info.family == 'era' or info.family == 'tbc' or info.family == 'progression' and info.expansion == 2
end)

local STAGGER_EDITION = editionRule('no-stagger', function(info)
    return info.family == 'retail' or info.family == 'forever' or progressionFrom(info, 4)
end)

local ECLIPSE_EDITION = editionRule('no-eclipse', function(info) return progressionFrom(info, 2) end)

local GROUP_ROLE_EDITION = editionRule('no-group-roles', function(info)
    return info.family == 'retail' or info.family == 'forever' or info.family == 'progression'
end)

-- ============================================================================
-- Requirement building blocks
-- ============================================================================

-- Defined below the requirement table; requirements that depend on the saved
-- value (a chosen state, a measure, a hand) call it for the API they need.
local check
local UNIT = { 'UnitExists' }
local CASTING = { POLICY, UNIT, { 'UnitCastingInfo' } }
local CHANNELING = { POLICY, UNIT, { 'UnitChannelInfo' } }
local AURA = { UNIT, { 'C_UnitAuras.GetAuraDataByIndex', 'UnitAura' } }
local SPELL_COOLDOWN = { { 'C_Spell.GetSpellCooldown', 'GetSpellCooldown' } }
local SPELL_CHARGES = { { 'C_Spell.GetSpellCharges', 'GetSpellCharges' } }
local SPELL_RANGE = { FAMILY, UNIT, { 'C_Spell.IsSpellInRange', 'IsSpellInRange' } }
local SPELL_CURRENT = { { 'C_Spell.IsCurrentSpell', 'IsCurrentSpell' } }
local KNOWN = { { 'C_SpellBook.IsSpellKnown', 'IsSpellKnown' } }

-- Returns a copy of a requirement list with extra requirements appended.
-- @param base table  The requirement list to copy.
-- @param ... any  The extra requirements to append.
-- @return table  The new requirement list.
local function with(base, ...)
    local result = {}

    for i, v in ipairs(base) do
        result[i] = v
    end

    for i = 1, select('#', ...) do
        result[#result + 1] = select(i, ...)
    end

    return result
end

local HEALTH = { SECRET_HEALTH, UNIT, { 'UnitHealth' } }
local HEALTHPCT = { SECRET_HEALTH, UNIT, { 'UnitHealth' }, { 'UnitHealthMax' } }
local MANA = { SECRET_MANA, UNIT, { 'Enum.PowerType' }, { 'UnitPower' } }
local MANAPCT = { SECRET_MANA, UNIT, { 'Enum.PowerType' }, { 'UnitPower' }, { 'UnitPowerMax' } }
local POWER = { SECRET_POWER, UNIT, { 'Enum.PowerType' }, { 'UnitPower' }, { 'UnitPowerType' } }
local POWERPCT = { SECRET_POWER, UNIT, { 'Enum.PowerType' }, { 'UnitPower' }, { 'UnitPowerMax' }, { 'UnitPowerType' } }
-- Health secret where restrictions apply, and the damage history the forecast
-- extrapolates comes from the combat log, which addons cannot read there.
local FORECAST = { SECRET_HEALTH, LOG, UNIT, { 'UnitGUID' }, { 'UnitHealth' }, { 'GetTime' } }

local LOC = {
    POLICY,
    { 'C_LossOfControl.GetActiveLossOfControlDataCount' },
    { 'C_LossOfControl.GetActiveLossOfControlData' },
}

local PROXIMITY = { UNIT, { 'IsInRaid' }, { 'IsInGroup' }, { 'UnitIsUnit' }, { 'UnitPosition' } }
local MOBINFO = { POLICY, UNIT, { 'UnitName' }, { 'UnitLevel' } }
-- Retail/Forever read C_PaperDollInfo (the global is a loadDeprecationFallbacks alias there).
local WEAPON = { { 'C_PaperDollInfo.GetTemporaryEnchantmentInfo', 'GetWeaponEnchantInfo' } }
local TOTEM = { { 'GetTotemInfo' } }
local TOTEM_SPELL = { { 'GetNumTotemSlots' }, { 'GetTotemInfo' } }
local RUNE = { POLICY, { 'GetRuneType' }, { 'GetRuneCooldown' } }
local ITEM_LOOKUP = { { 'C_Item.GetItemCount', 'GetItemCount' } }
local TREES = { 'GetNumTalentTabs', 'C_Traits.GetGroupDisplayInfoByTreeID' }

-- The API each PLAYER_STATE state reads; ghost is dead-or-ghost without dead.
local PLAYER_STATE_API = {
    mounted = { { 'IsMounted' } },
    swimming = { { 'IsSwimming' } },
    falling = { { 'IsFalling' } },
    flying = { { 'IsFlying' } },
    resting = { { 'IsResting' } },
    dead = { { 'UnitIsDead' } },
    ghost = { { 'UnitIsDead' }, { 'UnitIsDeadOrGhost' } },
}

-- Requirement for PLAYER_STATE: checks the API that the chosen state reads.
-- @param value table|nil  The condition value (state).
-- @return string|nil  The reason code of the first unmet API requirement; nil when usable.
local function playerState(value)
    local needs = type(value) == 'table' and PLAYER_STATE_API[value.state]

    if not needs then
        return nil
    end

    for _, path in ipairs(needs) do
        local reason = check(path, value)

        if reason then
            return reason
        end
    end
end

-- Requirement for GROUP_COUNT.
-- @param value table|nil  The condition value (measure).
-- @return string|nil  The reason code; nil when usable.
--
-- Size and dead members read on every client; assigned roles only where a client lets players assign them (not Era or
-- Burning Crusade: the function exists there, but the client generated manifests prove only that, not that a role can
-- be
-- assigned).
local function groupCount(value)
    local measure = type(value) == 'table' and value.measure

    if measure == 'TANK' or measure == 'HEALER' or measure == 'DAMAGER' then
        local reason = GROUP_ROLE_EDITION()

        if reason then
            return reason
        end

        return check({ 'UnitGroupRolesAssigned' }, value)
    elseif measure == 'dead' then
        return check({ 'UnitIsDeadOrGhost' }, value)
    end
end

-- Requirement for ITEM_COOLDOWN with a trinket slot, which reads the equipped item from the slot.
-- @param value table|nil  The condition value (slot).
-- @return string|nil  The reason code; nil when usable or no slot is chosen.
local function itemCooldownSlot(value)
    if type(value) ~= 'table' or value.slot == nil then
        return nil
    end

    return check({ 'GetInventoryItemID' }, value)
end

-- Requirement for DISTANCE_COUNT with `incombat`, which also asks whether each counted unit is in combat.
-- @param value table|nil  The condition value (incombat).
-- @return string|nil  The reason code; nil when usable or incombat is not set.
local function distanceCountCombat(value)
    if type(value) ~= 'table' or not value.incombat then
        return nil
    end

    return check({ 'UnitAffectingCombat' }, value)
end

-- Requirement for ECLIPSE: the direction and the energy each read their own API.
-- @param value table|nil  The condition value (measure).
-- @return string|nil  The reason code; nil when usable.
local function eclipse(value)
    local measure = type(value) == 'table' and value.measure

    if measure == 'direction' then
        return check({ 'GetEclipseDirection' }, value)
    elseif measure == 'energy' then
        local reason = check({ 'UnitPower' }, value)

        if reason then
            return reason
        end

        return check({ 'Enum.PowerType' }, value)
    end
end

-- Requirement for the swing timers: the ranged option reads UnitRangedDamage, the melee hand UnitAttackSpeed.
-- @param value table|nil  The condition value (ranged).
-- @return string|nil  The reason code; nil when usable.
--
-- The remaining time needs the combat log for either (a restricted client has none).
local function swingApi(value)
    return check(type(value) == 'table' and value.ranged and { 'UnitRangedDamage' } or { 'UnitAttackSpeed' }, value)
end

-- ============================================================================
-- Requirement table
-- ============================================================================

local requirements = {
    SELF_LEVEL = { FAMILY, UNIT, { 'UnitLevel' } },
    LEVEL = { FAMILY, UNIT, { 'UnitLevel' } },
    PVP = { POLICY, UNIT, { 'UnitIsPVP' } },
    ZONEPVP = { LISTED, { 'C_PvP.GetZonePVPInfo', 'GetZonePVPInfo' } },
    INSTANCE = { LISTED, { 'IsInInstance' } },
    OUTDOORS = { POLICY, { 'IsOutdoors' } },
    EQUIPPED = { { 'C_Item.IsEquippedItem', 'IsEquippedItem' } },
    CARRYING = {
        { 'C_Container.GetContainerNumSlots', 'GetContainerNumSlots' },
        { 'C_Container.GetContainerItemInfo', 'GetContainerItemInfo' },
    },
    ITEM = ITEM_LOOKUP,
    ITEM_RANGE = { { 'C_Item.IsItemInRange', 'IsItemInRange' } },
    ITEM_COOLDOWN = {
        { 'C_Item.GetItemCooldown', 'C_Container.GetItemCooldown', 'GetItemCooldown' },
        itemCooldownSlot,
    },
    SET_PIECES = { { 'GetInventoryItemID' } },
    WEAPON_IMBUE = WEAPON,
    WEAPON = WEAPON,
    WEAPON_REMAIN = WEAPON,
    WEAPON_STACKS = WEAPON,
    -- The first entry names both APIs so test fixtures can stub them; swingApi then requires the one the hand needs.
    SWING_TIME = { { 'UnitAttackSpeed', 'UnitRangedDamage' }, swingApi },
    SWING_TIME_REMAIN = { { 'UnitAttackSpeed', 'UnitRangedDamage' }, swingApi, LOG },
    BUFF = AURA,
    BUFF_REMAIN = AURA,
    BUFF_STACKS = AURA,
    STEALABLE = AURA,
    DEBUFF = AURA,
    DEBUFF_REMAIN = AURA,
    DEBUFF_STACKS = AURA,
    DISPELLABLE = AURA,
    TOTEM = TOTEM,
    TOTEM_REMAIN = TOTEM,
    TOTEM_SPELL = TOTEM_SPELL,
    TOTEM_SPELL_REMAIN = TOTEM_SPELL,
    BOSSMOD_ENCOUNTER = { BOSSMOD },
    BOSSMOD_STAGE = { BOSSMOD },
    BOSSMOD_TIMER = { BOSSMOD },
    PROXIMITY = PROXIMITY,
    PROXIMITY_HEALTH = with(PROXIMITY, SECRET_HEALTH, { 'UnitHealth' }, { 'UnitHealthMax' }),
    PROXIMITY_HEALTH_COUNT = with(PROXIMITY, SECRET_HEALTH, { 'UnitHealth' }, { 'UnitHealthMax' }),
    PROXIMITY_HEALTHPCT = with(PROXIMITY, SECRET_HEALTH, { 'UnitHealth' }, { 'UnitHealthMax' }),
    PROXIMITY_HEALTHPCT_COUNT = with(PROXIMITY, SECRET_HEALTH, { 'UnitHealth' }, { 'UnitHealthMax' }),
    PROXIMITY_MANA = with(PROXIMITY, SECRET_MANA, { 'UnitPower' }, { 'UnitPowerMax' }),
    PROXIMITY_MANA_COUNT = with(PROXIMITY, SECRET_MANA, { 'UnitPower' }, { 'UnitPowerMax' }),
    PROXIMITY_MANAPCT = with(PROXIMITY, SECRET_MANA, { 'UnitPower' }, { 'UnitPowerMax' }),
    PROXIMITY_MANAPCT_COUNT = with(PROXIMITY, SECRET_MANA, { 'UnitPower' }, { 'UnitPowerMax' }),
    STAT = { POLICY, UNIT },
    CASTING = CASTING,
    CASTING_SPELL = CASTING,
    CAST_INTERRUPTABLE = CASTING,
    CASTING_REMAIN = with(CASTING, { 'GetTime' }),
    CASTING_PROGRESS = with(CASTING, { 'GetTime' }),
    CHANNELING = CHANNELING,
    CHANNELING_SPELL = CHANNELING,
    CHANNEL_INTERRUPTABLE = CHANNELING,
    CHANNELING_REMAIN = with(CHANNELING, { 'GetTime' }),
    CHANNELING_PROGRESS = with(CHANNELING, { 'GetTime' }),
    BEYOND_MELEE = { UNIT },
    SPELL_AVAIL = SPELL_COOLDOWN,
    SPELL_COOLDOWN = SPELL_COOLDOWN,
    SPELL_RANGE = SPELL_RANGE,
    SPELL_REMAIN = SPELL_CHARGES,
    SPELL_CHARGES = SPELL_CHARGES,
    SPELL_ACTIVE = SPELL_CURRENT,
    SPELL_HISTORY = { POLICY },
    SPELL_HISTORY_TIME = { POLICY },
    COMBAT_HISTORY = { POLICY },
    COMBAT_HISTORY_TIME = { POLICY },
    SPELL_AUTOREPEAT = { POLICY, { 'C_Spell.IsAutoRepeatSpell', 'IsAutoRepeatSpell' } },
    SPELL_KNOWN = KNOWN,
    ANYSPELL_AVAIL = SPELL_COOLDOWN,
    ANYSPELL_COOLDOWN = SPELL_COOLDOWN,
    ANYSPELL_RANGE = SPELL_RANGE,
    ANYSPELL_REMAIN = SPELL_CHARGES,
    ANYSPELL_CHARGES = SPELL_CHARGES,
    PETSPELL_AVAIL = with(KNOWN, SPELL_COOLDOWN[1]),
    PETSPELL_COOLDOWN = with(KNOWN, SPELL_COOLDOWN[1]),
    PETSPELL_RANGE = with(SPELL_RANGE, KNOWN[1]),
    PETSPELL_REMAIN = with(KNOWN, SPELL_CHARGES[1]),
    PETSPELL_CHARGES = with(KNOWN, SPELL_CHARGES[1]),
    PETSPELL_HISTORY = with(KNOWN, POLICY),
    PETSPELL_HISTORY_TIME = with(KNOWN, POLICY),
    PETSPELL_ACTIVE = with(KNOWN, SPELL_CURRENT[1]),
    HEALTH = HEALTH,
    HEALTHPCT = HEALTHPCT,
    MANA = MANA,
    MANAPCT = MANAPCT,
    POWER = POWER,
    POWERPCT = POWERPCT,
    POINT = { POLICY, UNIT, { 'UnitClass' }, { 'UnitPower' }, pointEdition },
    RUNE = RUNE,
    RUNE_COOLDOWN = with(RUNE, { 'GetTime' }),
    TT_HEALTH = FORECAST,
    TT_HEALTHPCT = with(FORECAST, { 'UnitHealthMax' }),
    COMBAT = { POLICY, UNIT, { 'UnitAffectingCombat' } },
    PET = { POLICY, UNIT },
    PET_NAME = { POLICY, UNIT, { 'GetUnitName' } },
    STEALTHED = { POLICY, { 'IsStealthed' } },
    INCONTROL = { POLICY, { 'HasFullControl' } },
    LOC_TYPE = LOC,
    LOC_BLOCKED = with(LOC, { 'bit' }),
    MOVING = { POLICY, { 'GetUnitSpeed' } },
    THREAT = { POLICY, UNIT, { 'UnitIsEnemy' }, { 'UnitThreatSituation' } },
    THREAT_COUNT = { POLICY, UNIT, { 'UnitGUID' }, { 'UnitIsEnemy' }, { 'UnitThreatSituation' } },
    FORM = { POLICY, { 'GetShapeshiftForm' } },
    ATTACKABLE = { POLICY, UNIT, { 'UnitCanAttack' }, { 'UnitIsDead' } },
    ENEMY = { POLICY, UNIT, { 'UnitIsEnemy' } },
    ISSAME = { POLICY, UNIT, { 'UnitIsUnit' } },
    CLASS = { POLICY, UNIT, { 'UnitClass' } },
    CLASSIFICATION = { POLICY, UNIT, { 'UnitClassification' } },
    CLASS_GROUP = { FAMILY, UNIT, { 'IsInGroup' }, { 'IsInRaid' }, { 'UnitClass' } },
    GROUP = { FAMILY, { 'IsInGroup' }, { 'IsInRaid' } },
    ROLE = { POLICY, UNIT },
    GLYPH = { glyphLayout, { 'GetNumGlyphSockets' }, { 'GetGlyphSocketInfo' } },
    CREATURE = { POLICY, UNIT, { 'UnitCreatureType' } },
    DEAD = { POLICY, UNIT, { 'UnitIsDeadOrGhost' } },
    FRIENDLY = { POLICY, UNIT, { 'UnitIsFriend' } },
    RUNNER = MOBINFO,
    RESIST = MOBINFO,
    IMMUNE = MOBINFO,
    ASSISTED_SUGGESTION = { { 'C_AssistedCombat.GetNextCastSpell' } },
    ASSISTED_ROTATION_SPELL = { { 'C_AssistedCombat.GetRotationSpells' } },
    ASSISTED_AVAILABLE = { { 'C_AssistedCombat.IsAvailable' } },
    TALENT = { talentLayout },
    TALENT_TREE_POINTS = { treeLayout, TREES },
    PRIMARY_TALENT_TREE = { treeLayout, TREES },
    DISTANCE = { FAMILY, UNIT },
    DISTANCE_COUNT = {
        POLICY,
        UNIT,
        { 'UnitIsEnemy' },
        { 'UnitGUID' },
        { 'C_CVar.GetCVar', 'GetCVar' },
        distanceCountCombat,
    },
    RUNE_ENGRAVED = { { 'C_Engraving.IsEngravingEnabled' } },
    WEAPON_TYPE = { weaponSlot },
    PLAYER_STATE = {
        POLICY,
        { 'IsMounted', 'IsSwimming', 'IsFalling', 'IsFlying', 'IsResting', 'UnitIsDead' },
        playerState,
    },
    ENCOUNTER = { POLICY, { 'C_InstanceEncounter.IsEncounterInProgress', 'IsEncounterInProgress' } },
    KEYSTONE_LEVEL = {
        POLICY,
        RETAIL_ONLY,
        { 'C_ChallengeMode.IsChallengeModeActive' },
        { 'C_ChallengeMode.GetActiveKeystoneInfo' },
    },
    HERO_TALENT = { POLICY, RETAIL_ONLY, { 'C_ClassTalents.GetActiveHeroTalentSpec' } },
    SPELL_GLOW = { POLICY, { 'C_SpellActivationOverlay.IsSpellOverlayed' } },
    GROUP_COUNT = { POLICY, { 'GetNumGroupMembers' }, { 'IsInRaid' }, groupCount },
    PET_HAPPINESS = { POLICY, PET_HAPPINESS_EDITION, { 'GetPetHappiness' } },
    STAGGER = { POLICY, STAGGER_EDITION, { 'UnitStagger' } },
    ECLIPSE = { POLICY, ECLIPSE_EDITION, { 'UnitClass' }, eclipse },
    ZONE = { { 'GetZoneText' }, { 'GetSubZoneText' } },
}

addon.conditionRequirements = requirements

local listedFamilies = { retail = true, forever = true, era = true, tbc = true, progression = true }
local bossmodFamilies = { era = true, tbc = true, progression = true }

-- ============================================================================
-- Checking requirements
-- ============================================================================

-- Evaluates one requirement against the client.
-- @param requirement function|table|string  A function of the condition value, a list of alternative API names (any one
--   existing suffices) or one of the POLICY, FAMILY, LISTED, BOSSMOD and LOG markers.
-- @param value table|nil  The condition value, passed to a function requirement.
-- @return string|nil  nil when satisfied, else a reason code.
function check(requirement, value)
    local kind = type(requirement)

    if kind == 'function' then
        return requirement(value)
    end

    if kind == 'table' then
        for _, path in ipairs(requirement) do
            local found = lookup(path)

            if type(found) == 'function' or type(found) == 'table' and (path == 'Enum.PowerType' or path == 'bit') then
                return nil
            end
        end

        return 'missing-api'
    end

    local platform = addon.Platform

    if not platform then
        return nil
    end

    if requirement == LOG then
        -- Retail and Forever deliver COMBAT_LOG_EVENT_UNFILTERED's payload only
        -- through C_CombatLogSecure.GetCurrentEventInfo, a SecureOnly system in
        -- Blizzard's generated documentation; Blizzard's own combat log reads it
        -- there. Without the payload this history is never recorded.
        local policy = platform:GetCombatDataPolicy()

        if policy == 'restricted' then
            return 'combat-log-unavailable'
        end
        if policy ~= 'probe' then
            return 'unsupported-policy'
        end
    elseif requirement == POLICY then
        local policy = platform:GetCombatDataPolicy()

        if policy ~= 'probe' and policy ~= 'restricted' then
            return 'unsupported-policy'
        end
    elseif requirement == FAMILY then
        if platform:GetClientFamily() == 'unknown' then
            return 'unsupported-client'
        end
    elseif requirement == LISTED then
        if not listedFamilies[platform:GetClientFamily()] then
            return 'unsupported-policy'
        end
    elseif requirement == BOSSMOD then
        if not bossmodFamilies[platform:GetClientFamily()] then
            return 'unsupported-client'
        end
    end
end

-- Checks that the client can resolve a group unit type used in a unit field.
-- @param value table|nil  The condition value (unit, otherunit).
-- @return string|nil  The platform's reason code; nil when supported.
--
-- A group unit type (the main tank, an assigned healer, ...) in a unit field needs the client to resolve it
-- (Platform/group_units.lua). Applies to any condition.
local function groupUnitSupport(value)
    local kinds = addon.groupUnitKinds
    local platform = addon.Platform

    if type(value) ~= 'table' or not kinds or not platform or type(platform.GetGroupUnitSupport) ~= 'function' then
        return nil
    end

    for _, field in ipairs({ 'unit', 'otherunit' }) do
        local kind = value[field]

        if kinds[kind] then
            local reason = platform:GetGroupUnitSupport(kind)

            if reason then
                return reason
            end
        end
    end
end

-- Reports whether a condition can work on this client.
-- @param tag string  The condition tag.
-- @param definition table|nil  The condition definition; a non-table gives nil.
-- @param value table|nil  The condition value, for requirements that depend on the saved value.
-- @return string|nil  nil when the condition can work on this client, else a permanent reason code (see `reasonText`);
--   'support-check-error' when a support check errors.
--
-- A definition's own `supported(value)` wins, custom conditions are always supported here, and a group unit kind in a
-- unit field is checked first. Never evaluates the condition and never caches: client facts are cached by the platform,
-- and validation results are keyed by the validation stamp, which advances when the client changes
-- (Core/rotation_references.lua).
function addon:GetConditionSupport(tag, definition, value)
    if type(definition) ~= 'table' then
        return nil
    end

    if type(definition.supported) == 'function' then
        local ok, reason = pcall(definition.supported, value)

        if not ok then
            return 'support-check-error'
        end

        return type(reason) == 'string' and reason or nil
    end

    if definition.customCode then
        return nil
    end

    local unitReason = groupUnitSupport(value)

    if unitReason then
        return unitReason
    end

    local list = requirements[tag]

    if not list then
        return nil
    end

    for _, requirement in ipairs(list) do
        local reason = check(requirement, value)

        if reason then
            return reason
        end
    end
end

local reasonText = {
    ['unsupported-policy'] = L['combat data is restricted on this client'],
    ['combat-log-unavailable'] = L['the combat log is not available to addons on this client'],
    ['secret-health'] = L['health is secret on this client'],
    ['secret-power'] = L['this power is secret on this client'],
    ['no-ranged-slot'] = L['this client has no ranged slot'],
    ['specialization-unsupported'] = L['this client has no specializations for your class'],
    ['missing-api'] = L['the game API it needs is missing'],
    ['unsupported-client'] = L['this client is not supported'],
    ['talent-layout-mismatch'] = L['this client uses a different talent system'],
    ['historical-talent-layout'] = L['this client uses a different talent system'],
    ['unsupported-talent-layout'] = L['this client uses a different talent system'],
    ['unsupported-glyph-layout'] = L['glyphs are not supported on this client build'],
    ['unsupported-point-expansion'] = L['this edition has no point resource'],
    ['retail-only'] = L['only Retail has this'],
    ['no-pet-happiness'] = L['this edition has no pet happiness'],
    ['no-stagger'] = L['this edition has no Stagger'],
    ['no-eclipse'] = L['this edition has no Eclipse'],
    ['no-group-roles'] = L['this client has no assigned group roles'],
}

-- Describes an unsupported-condition validation issue: "X is not available on this client (reason)."
-- @param problem table  The validation issue ({ code, condition, reason }).
-- @return string|nil  The localized sentence; nil for any other issue.
function addon:DescribeUnsupportedCondition(problem)
    if type(problem) ~= 'table' or problem.code ~= 'unsupported-condition' then
        return nil
    end

    local definition = self.conditionDefinitions and self.conditionDefinitions[problem.condition]

    local name = type(definition) == 'table' and type(definition.description) == 'string' and definition.description
        or tostring(problem.condition)

    return string.format(
        L['%s is not available on this client (%s).'],
        name,
        reasonText[problem.reason] or tostring(problem.reason)
    )
end
-- END CONDITION CLIENT SUPPORT
