-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Holy (Icy Veins and Warcraft Tavern, Phase 4: no later healing guide exists):
-- chosen in a group by an engraved Beacon of Light, Divine Light or Sacred Shield, or by the Holy tree
-- without Crusader Strike. Heals act on your friendly target: Cleanse, Holy Shock while moving or for
-- a target below 30%, Divine Light (else Holy Light) below 60%, Flash of Light below 90%. Beacon and
-- Sacred Shield are reminders for the target that lacks them. Choosing whom to heal stays with you.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.holy',revision=6,
 blocks={['sod.paladin.holy-upkeep']=2,['era.paladin.boundaries']=2,['era.paladin.cleanse']=1,['sod.paladin.holy-hostile']=3},
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'leveling','endgame','holy','healer','dungeon','raid','season-of-discovery','icy-veins','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/wow-classic/holy-paladin-healer-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Holy Paladin rotation (Phase 4)',reviewedAt='2026-10-23',revision='2024-07-09'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/season-of-discovery-sod-paladin-healer-build/',title='Warcraft Tavern: SoD Paladin healer guide (Phase 4)',reviewedAt='2026-10-23'}},
 body={priority=110,switch=BuiltinConditions.all({type='GROUP'},BuiltinConditions.any(rune(407613),rune(458856),rune(412019),BuiltinConditions.all(BuiltinConditions.negate(rune(407676)),{type='PRIMARY_TALENT_TREE',tree=1}))),
  cooldowns={BuiltinConditions.block('sholy-upkeep','sod.paladin.holy-upkeep','sholy-')},
  rotation={
   BuiltinConditions.block('sholy-boundaries','era.paladin.boundaries','sholy-'),
   {id='sholy-friend',type='branch',conditions=BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    BuiltinConditions.block('sholy-cleanse','era.paladin.cleanse','sholy-'),
    BuiltinConditions.spell('sholy-shock',20473,BuiltinConditions.any(BuiltinConditions.all({type='MOVING'},hurt(0.9)),hurt(0.3))),
    BuiltinConditions.spell('sholy-divine-light',458856,BuiltinConditions.all(hurt(0.6),mana('GREATERTHANOREQUALS',0.5))),
    BuiltinConditions.spell('sholy-holy-light',635,hurt(0.6)),
    BuiltinConditions.spell('sholy-flash',19750,hurt(0.9)),
    {id='sholy-friend-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   BuiltinConditions.block('sholy-hostile','sod.paladin.holy-hostile','sholy-'),
  },
 },
}))
