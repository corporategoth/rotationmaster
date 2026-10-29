-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Holy after Wowhead's Phase 4 healing guide: Holy Light is the main heal (Divine
-- Light when mana allows) for moderate and heavy damage, then Cleanse, Holy Shock for light damage or
-- while moving, Flash of Light for light damage. Same switch as the recommended SoD Holy premade,
-- lower priority, shipped disabled.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.holy.wowhead',revision=7,
 blocks={['sod.paladin.holy-upkeep']=2,['era.paladin.boundaries']=2,['era.paladin.cleanse']=1,['sod.paladin.holy-hostile']=3},
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'endgame','holy','healer','dungeon','raid','season-of-discovery','wowhead'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/paladin/healer-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Paladin healer rotation (Phase 4)',reviewedAt='2026-10-23',revision='2024-07-12'}},
 body={priority=109,disabled=true,switch=BuiltinConditions.all({type='GROUP'},BuiltinConditions.any(rune(407613),rune(458856),rune(412019),BuiltinConditions.all(BuiltinConditions.negate(rune(407676)),{type='PRIMARY_TALENT_TREE',tree=1}))),
  cooldowns={BuiltinConditions.block('sholywh-upkeep','sod.paladin.holy-upkeep','sholywh-')},
  rotation={
   BuiltinConditions.block('sholywh-boundaries','era.paladin.boundaries','sholywh-'),
   {id='sholywh-friend',type='branch',conditions=BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    BuiltinConditions.spell('sholywh-divine-light',458856,BuiltinConditions.all(hurt(0.75),mana('GREATERTHANOREQUALS',0.5))),
    BuiltinConditions.spell('sholywh-holy-light',635,hurt(0.75)),
    BuiltinConditions.block('sholywh-cleanse','era.paladin.cleanse','sholywh-'),
    BuiltinConditions.spell('sholywh-shock',20473,BuiltinConditions.any(BuiltinConditions.all({type='MOVING'},hurt(0.95)),hurt(0.9))),
    BuiltinConditions.spell('sholywh-flash',19750,hurt(0.95)),
    {id='sholywh-friend-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   BuiltinConditions.block('sholywh-hostile','sod.paladin.holy-hostile','sholywh-'),
  },
 },
}))
