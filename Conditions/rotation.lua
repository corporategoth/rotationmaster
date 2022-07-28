local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local CATEGORY_NONE = nil
local CATEGORY_BUFFS = L["Buffs"]
local CATEGORY_COMBAT = L["Combat"]
local CATEGORY_SPATIAL = L["Spatial"]
local CATEGORY_SPELLS = L["Spells / Items"]

-- buffs.lua
addon:RegisterCondition(CATEGORY_BUFFS, "BUFF", addon.condition_buff)
addon:RegisterCondition(CATEGORY_BUFFS, "BUFF_REMAIN", addon.condition_buff_remain)
addon:RegisterCondition(CATEGORY_BUFFS, "BUFF_STACKS", addon.condition_buff_stacks)
addon:RegisterCondition(CATEGORY_BUFFS, "STEALABLE", addon.condition_stealable)

-- casting.lua
addon:RegisterCondition(CATEGORY_COMBAT, "CASTING", addon.condition_casting)
addon:RegisterCondition(CATEGORY_COMBAT, "CASTING_SPELL", addon.condition_casting_spell)
addon:RegisterCondition(CATEGORY_COMBAT, "CASTING_REMAIN", addon.condition_casting_remain)
addon:RegisterCondition(CATEGORY_COMBAT, "CAST_INTERRUPTABLE", addon.condition_cast_interruptable)

-- channeling.lua
addon:RegisterCondition(CATEGORY_COMBAT, "CHANNELING", addon.condition_channeling)
addon:RegisterCondition(CATEGORY_COMBAT, "CHANNELING_SPELL", addon.condition_channeling_spell)
addon:RegisterCondition(CATEGORY_COMBAT, "CHANNELING_REMAIN", addon.condition_channeling_remain)
addon:RegisterCondition(CATEGORY_COMBAT, "CHANNEL_INTERRUPTABLE", addon.condition_channel_interruptable)

-- character.lua
addon:RegisterCondition(CATEGORY_NONE, "ISSAME", addon.condition_issame)
addon:RegisterCondition(CATEGORY_NONE, "CLASS", addon.condition_class)
addon:RegisterCondition(CATEGORY_NONE, "CLASS_GROUP", addon.condition_class_group)

if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    addon:RegisterCondition(CATEGORY_NONE, "ROLE", addon.condition_role)
end
addon:RegisterCondition(CATEGORY_NONE, "TALENT", addon.condition_talent)
if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or GetServerExpansionLevel() >= 2) then
    addon:RegisterCondition(CATEGORY_SPELLS, "GLYPH", addon.condition_glyph)
end
addon:RegisterCondition(CATEGORY_NONE, "CREATURE", addon.condition_creature)
addon:RegisterCondition(CATEGORY_NONE, "CLASSIFICATION", addon.condition_classification)
addon:RegisterCondition(CATEGORY_NONE, "LEVEL", addon.condition_level)
addon:RegisterCondition(CATEGORY_NONE, "GROUP", addon.condition_group)
if MI2_GetMobData then
    addon:RegisterCondition(CATEGORY_NONE, "RUNNER", addon.condition_runner)
    addon:RegisterCondition(CATEGORY_NONE, "RESIST", addon.condition_resist)
    addon:RegisterCondition(CATEGORY_NONE, "IMMUNE", addon.condition_immune)
end

-- combat.lua
addon:RegisterCondition(CATEGORY_COMBAT, "COMBAT", addon.condition_combat)
addon:RegisterCondition(CATEGORY_COMBAT, "PET", addon.condition_pet)
addon:RegisterCondition(CATEGORY_COMBAT, "PET_NAME", addon.condition_pet_name)
addon:RegisterCondition(CATEGORY_COMBAT, "STEALTHED", addon.condition_stealthed)
addon:RegisterCondition(CATEGORY_COMBAT, "INCONTROL", addon.condition_incontrol)
addon:RegisterCondition(CATEGORY_COMBAT, "LOC_TYPE", addon.condition_loc_type)
addon:RegisterCondition(CATEGORY_COMBAT, "LOC_BLOCKED", addon.condition_loc_blocked)
addon:RegisterCondition(CATEGORY_COMBAT, "MOVING", addon.condition_moving)
addon:RegisterCondition(CATEGORY_COMBAT, "THREAT", addon.condition_threat)
addon:RegisterCondition(CATEGORY_COMBAT, "THREAT_COUNT", addon.condition_threat_count)
addon:RegisterCondition(CATEGORY_COMBAT, "FORM", addon.condition_form)
addon:RegisterCondition(CATEGORY_COMBAT, "ATTACKABLE", addon.condition_attackable)
addon:RegisterCondition(CATEGORY_COMBAT, "ENEMY", addon.condition_enemy)
addon:RegisterCondition(CATEGORY_COMBAT, "COMBAT_HISTORY", addon.condition_combat_history)
addon:RegisterCondition(CATEGORY_COMBAT, "COMBAT_HISTORY_TIME", addon.condition_combat_history_time)

-- debuffs.lua
addon:RegisterCondition(CATEGORY_BUFFS, "DEBUFF", addon.condition_debuff)
addon:RegisterCondition(CATEGORY_BUFFS, "DEBUFF_REMAIN", addon.condition_debuff_remain)
addon:RegisterCondition(CATEGORY_BUFFS, "DEBUFF_STACKS", addon.condition_debuff_stacks)
addon:RegisterCondition(CATEGORY_BUFFS, "DISPELLABLE", addon.condition_dispellable)

-- item.lua
addon:RegisterCondition(CATEGORY_SPELLS, "EQUIPPED", addon.condition_equipped)
addon:RegisterCondition(CATEGORY_SPELLS, "CARRYING", addon.condition_carrying)
addon:RegisterCondition(CATEGORY_SPELLS, "ITEM", addon.condition_item)
addon:RegisterCondition(CATEGORY_SPELLS, "ITEM_RANGE", addon.condition_item_range)
addon:RegisterCondition(CATEGORY_SPELLS, "ITEM_COOLDOWN", addon.condition_item_cooldown)

-- misc.lua

-- petspell.lua
addon:RegisterCondition(CATEGORY_SPELLS, "PETSPELL_AVAIL", addon.condition_petspell_avail)
addon:RegisterCondition(CATEGORY_SPELLS, "PETSPELL_RANGE", addon.condition_petspell_range)
addon:RegisterCondition(CATEGORY_SPELLS, "PETSPELL_COOLDOWN", addon.condition_petspell_cooldown)
addon:RegisterCondition(CATEGORY_SPELLS, "PETSPELL_REMAIN", addon.condition_petspell_remain)
addon:RegisterCondition(CATEGORY_SPELLS, "PETSPELL_CHARGES", addon.condition_petspell_charges)

-- spatial.lua
addon:RegisterCondition(CATEGORY_SPATIAL, "PROXIMITY", addon.condition_proximity)
addon:RegisterCondition(CATEGORY_SPATIAL, "DISTANCE", addon.condition_distance)
addon:RegisterCondition(CATEGORY_SPATIAL, "DISTANCE_COUNT", addon.condition_distance_count)
addon:RegisterCondition(CATEGORY_NONE, "ZONE", addon.condition_zone)

-- spatial_stats.lua
addon:RegisterCondition(CATEGORY_SPATIAL, "PROXIMITY_HEALTH", addon.condition_proximity_health)
addon:RegisterCondition(CATEGORY_SPATIAL, "PROXIMITY_HEALTH_COUNT", addon.condition_proximity_health_count)
addon:RegisterCondition(CATEGORY_SPATIAL, "PROXIMITY_HEALTHPCT", addon.condition_proximity_healthpct)
addon:RegisterCondition(CATEGORY_SPATIAL, "PROXIMITY_HEALTHPCT_COUNT", addon.condition_proximity_healthpct_count)
addon:RegisterCondition(CATEGORY_SPATIAL, "PROXIMITY_MANA", addon.condition_proximity_mana)
addon:RegisterCondition(CATEGORY_SPATIAL, "PROXIMITY_MANA_COUNT", addon.condition_proximity_mana_count)
addon:RegisterCondition(CATEGORY_SPATIAL, "PROXIMITY_MANAPCT", addon.condition_proximity_manapct)
addon:RegisterCondition(CATEGORY_SPATIAL, "PROXIMITY_MANAPCT_COUNT", addon.condition_proximity_manapct_count)

-- spell.lua
addon:RegisterCondition(CATEGORY_SPELLS, "SPELL_AVAIL", addon.condition_spell_avail)
addon:RegisterCondition(CATEGORY_SPELLS, "SPELL_RANGE", addon.condition_spell_range)
addon:RegisterCondition(CATEGORY_SPELLS, "SPELL_COOLDOWN", addon.condition_spell_cooldown)
addon:RegisterCondition(CATEGORY_SPELLS, "SPELL_REMAIN", addon.condition_spell_remain)
addon:RegisterCondition(CATEGORY_SPELLS, "SPELL_CHARGES", addon.condition_spell_charges)
addon:RegisterCondition(CATEGORY_SPELLS, "SPELL_HISTORY", addon.condition_spell_history)
addon:RegisterCondition(CATEGORY_SPELLS, "SPELL_HISTORY_TIME", addon.condition_spell_history_time)
addon:RegisterCondition(CATEGORY_SPELLS, "SPELL_ACTIVE", addon.condition_spell_active)

-- stats.lua
addon:RegisterCondition(CATEGORY_COMBAT, "HEALTH", addon.condition_health)
addon:RegisterCondition(CATEGORY_COMBAT, "HEALTHPCT", addon.condition_healthpct)
addon:RegisterCondition(CATEGORY_COMBAT, "MANA", addon.condition_mana)
addon:RegisterCondition(CATEGORY_COMBAT, "MANAPCT", addon.condition_manapct)
addon:RegisterCondition(CATEGORY_COMBAT, "POWER", addon.condition_power)
addon:RegisterCondition(CATEGORY_COMBAT, "POWERPCT", addon.condition_powerpct)
addon:RegisterCondition(CATEGORY_COMBAT, "POINT", addon.condition_point)

if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and GetServerExpansionLevel() >= 2 and
        select(2, UnitClass("player")) == "DEATHKNIGHT") then
    addon:RegisterCondition(CATEGORY_COMBAT, "RUNE", addon.condition_rune)
    addon:RegisterCondition(CATEGORY_COMBAT, "RUNE_COOLDOWN", addon.condition_rune_cooldown)
end
addon:RegisterCondition(CATEGORY_COMBAT, "TT_HEALTH", addon.condition_tt_health)
addon:RegisterCondition(CATEGORY_COMBAT, "TT_HEALTHPCT", addon.condition_tt_healthpct)

-- totem.lua
if select(2, UnitClass("player")) == "SHAMAN" then
    addon:RegisterCondition(CATEGORY_SPELLS, "TOTEM", addon.condition_totem)
    addon:RegisterCondition(CATEGORY_SPELLS, "TOTEM_SPELL", addon.condition_totem_spell)
    addon:RegisterCondition(CATEGORY_SPELLS, "TOTEM_REMAIN", addon.condition_totem_remain)
    addon:RegisterCondition(CATEGORY_SPELLS, "TOTEM_SPELL_REMAIN", addon.condition_totem_spell_remain)
end

-- weapon.lua
if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
    addon:RegisterCondition(CATEGORY_BUFFS, "WEAPON", addon.condition_weapon)
    addon:RegisterCondition(CATEGORY_BUFFS, "WEAPON_REMAIN", addon.condition_weapon_remain)
    addon:RegisterCondition(CATEGORY_BUFFS, "WEAPON_STACKS", addon.condition_weapon_stacks)
end
addon:RegisterCondition(CATEGORY_COMBAT, "SWING_TIME", addon.condition_swing_time)
addon:RegisterCondition(CATEGORY_COMBAT, "SWING_TIME_REMAIN", addon.condition_swing_time_remain)
