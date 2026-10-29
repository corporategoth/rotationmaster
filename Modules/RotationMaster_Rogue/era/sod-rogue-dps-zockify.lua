-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Rogue melee DPS, Zockify Phase 8 lean Envenom list (alternative premade).
-- Same switch and shared blocks as the recommended SoD premade (era/blocks.lua). Differs where
-- Zockify differs: no bleed upkeep at all (no Rupture, no Crimson Tempest) and no Expose Armor;
-- Poisoned Knife at four poison stacks; Slice and Dice when missing from two points (four with
-- Saber Slash); Envenom at five; builder by glove rune. Left manual: the Vanish and Cold Blood
-- burst, Shadowstep, Sprint and positioning.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function stacks(id,n)return{type='DEBUFF_STACKS',unit='target',spell=id,anyrank=true,owndebuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local unsliced=BuiltinConditions.negate({type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.rogue.dps.zockify',revision=7,
 blocks={['era.rogue.boundaries']=3,['era.rogue.sod-opener']=4,['era.rogue.sod-upkeep']=3,['era.rogue.sod-builders']=3},
 applicability={families={'era'},actionContext='player',class='ROGUE',rulesets={'season:2'}},
 tags={'dps','melee','endgame','season-of-discovery','zockify'},
 sources={{url='https://www.zockify.com/wowclassic/rogue/dps/',title='Zockify: SoD DPS Rogue (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-07'}},
 body={priority=42,disabled=true,
 cooldowns={block('era.rogue.sod-upkeep','rogue-')},
 rotation={
 block('era.rogue.boundaries','rogue-'),
 {id='rogue-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={block('era.rogue.sod-opener','rogue-stealth-')}},
 BuiltinConditions.spell('rogue-poisoned-knife',425012,BuiltinConditions.all(points('LESSTHAN',5),BuiltinConditions.any(stacks(458820,4),stacks(1214170,4),stacks(2818,4)))),
 BuiltinConditions.spell('rogue-slice',5171,BuiltinConditions.all(unsliced,BuiltinConditions.negate(rune(424785)),points('GREATERTHANOREQUALS',2))),
 BuiltinConditions.spell('rogue-saber-slice',5171,BuiltinConditions.all(unsliced,rune(424785),points('GREATERTHANOREQUALS',4))),
 {id='rogue-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-envenom',399963),
  BuiltinConditions.spell('rogue-eviscerate',2098,BuiltinConditions.negate(rune(399963))),
  {id='rogue-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 block('era.rogue.sod-builders','rogue-'),
 }},
}))
