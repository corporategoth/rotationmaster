-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Subtlety Rogue, levels 10-90 (the recommended variant): simulator' Phase 5 order with Shadow
-- Focus, which Wowhead's Phase 5 page agrees with. Selected in the Subtlety specialization (261) from
-- level 10. In Stealth or Shadow Dance: Premeditation, Slice and Dice before
-- the pull, five-point finishers in combat, Ambush, Garrote. Three or more engaged enemies: Slice and Dice, Crimson
-- Tempest, Eviscerate, Fan of Knives. One target: Slice and Dice; at five points Slice and Dice and Rupture refreshes
-- under 2 s and Eviscerate while both last; Marked for Death; Hemorrhage for its bleed; Backstab with a dagger when the
-- target is not on you, else Hemorrhage. Reminders: Shadow Dance at 75 energy with both buffs up, Vanish when Find Weakness is ending,
-- Preparation, Shadow Blades outside the windows. Shared parts: mop/blocks.lua; Warcraft Tavern's Subterfuge play is
-- its own premade.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function energy(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function buffRemain(id,op,n)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local sliced=BuiltinConditions.ownBuff(5171)
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local hidden={type='STEALTHED'}
local worth=BuiltinConditions.any(boss,BuiltinConditions.lifetime('GREATERTHAN',8))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.subtlety',revision=8,
 blocks={['mop.rogue.boundaries']=3,['mop.rogue.out-of-combat']=3,['mop.rogue.solo']=2,['mop.rogue.upkeep']=1,['mop.rogue.subtlety-builders']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE'},
 tags={'subtlety','dps','melee','leveling','endgame','wowhead','icy-veins'},
 sources={
 {url='https://www.wowhead.com/mop-classic/guide/classes/rogue/subtlety/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Subtlety Rogue rotation (MoP Classic, Phase 5)',reviewedAt='2026-10-23',revision='2026-06-29'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/subtlety-rogue-leveling',title='Icy Veins: Subtlety Rogue leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-09-23'}},
 body={priority=30,specs={261},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.rogue.upkeep','rogue-'),
  BuiltinConditions.spell('rogue-subtlety-shadow-dance',51713,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(hidden),energy('GREATERTHANOREQUALS',75),sliced,mine(1943),worth)),
  BuiltinConditions.spell('rogue-subtlety-vanish',1856,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(hidden),BuiltinConditions.negate(BuiltinConditions.ownBuff(51713)),points('LESSTHAN',3),energy('GREATERTHANOREQUALS',60),
   BuiltinConditions.any(BuiltinConditions.negate(mine(91021)),remain(91021,'LESSTHANOREQUALS',1.5)),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(51713)),{type='SPELL_COOLDOWN',spell=51713,operator='GREATERTHANOREQUALS',value=5}))),
  BuiltinConditions.spell('rogue-subtlety-preparation',14185,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(hidden),{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=60})),
  BuiltinConditions.spell('rogue-subtlety-shadow-blades',121471,BuiltinConditions.all(BuiltinConditions.combat(),sliced,BuiltinConditions.negate(BuiltinConditions.ownBuff(51713)),BuiltinConditions.negate(hidden))),
 },
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 {id='rogue-subtlety-window',type='branch',conditions=BuiltinConditions.any(hidden,BuiltinConditions.ownBuff(51713)),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-subtlety-premeditation',14183,points('LESSTHANOREQUALS',3)),
  BuiltinConditions.spell('rogue-subtlety-prepull-slice',5171,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),points('GREATERTHANOREQUALS',1),BuiltinConditions.negate(sliced))),
  {id='rogue-subtlety-window-finisher',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.combat(),points('GREATERTHANOREQUALS',5)),onFalse={},onTrue={
   BuiltinConditions.spell('rogue-subtlety-window-slice',5171,BuiltinConditions.any(BuiltinConditions.negate(sliced),buffRemain(5171,'LESSTHANOREQUALS',2))),
   BuiltinConditions.spell('rogue-subtlety-window-rupture',1943,BuiltinConditions.any(BuiltinConditions.negate(mine(1943)),remain(1943,'LESSTHANOREQUALS',2))),
   BuiltinConditions.spell('rogue-subtlety-window-eviscerate',2098),
  }},
  BuiltinConditions.spell('rogue-subtlety-ambush',8676,BuiltinConditions.any(points('LESSTHANOREQUALS',4),BuiltinConditions.all({type='TALENT',layout='grid',value=18},BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(115189)),{type='BUFF_STACKS',unit='player',spell=115189,ownbuff=true,operator='LESSTHAN',value=3})))),
  BuiltinConditions.spell('rogue-subtlety-garrote',703),
  {id='rogue-subtlety-window-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 block('mop.rogue.out-of-combat','rogue-'),
 {id='rogue-subtlety-aoe',type='branch',conditions=BuiltinConditions.all(enemies('GREATERTHANOREQUALS',3),BuiltinConditions.known(51723)),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-subtlety-aoe-slice',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',1),BuiltinConditions.any(BuiltinConditions.negate(sliced),buffRemain(5171,'LESSTHANOREQUALS',2)))),
  BuiltinConditions.spell('rogue-subtlety-crimson-tempest',121411,BuiltinConditions.all(points('GREATERTHANOREQUALS',5),BuiltinConditions.any(BuiltinConditions.negate(mine(122233)),remain(122233,'LESSTHANOREQUALS',2)))),
  BuiltinConditions.spell('rogue-subtlety-aoe-eviscerate',2098,points('GREATERTHANOREQUALS',5)),
  BuiltinConditions.spell('rogue-subtlety-fan',51723),
  {id='rogue-subtlety-aoe-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 BuiltinConditions.spell('rogue-subtlety-slice',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',1),BuiltinConditions.negate(sliced))),
 block('mop.rogue.solo','rogue-'),
 {id='rogue-subtlety-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-subtlety-finisher-slice',5171,buffRemain(5171,'LESSTHANOREQUALS',2)),
  BuiltinConditions.spell('rogue-subtlety-rupture',1943,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(mine(1943)),remain(1943,'LESSTHANOREQUALS',2)),worth)),
  BuiltinConditions.spell('rogue-subtlety-eviscerate',2098,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(1943)),BuiltinConditions.negate(mine(1943)),BuiltinConditions.all(remain(1943,'GREATERTHANOREQUALS',4),buffRemain(5171,'GREATERTHANOREQUALS',4)))),
  {id='rogue-subtlety-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 BuiltinConditions.spell('rogue-subtlety-dying',2098,BuiltinConditions.all(points('GREATERTHANOREQUALS',2),BuiltinConditions.lifetime('LESSTHAN',4))),
 block('mop.rogue.subtlety-builders','rogue-'),
 BuiltinConditions.spell('rogue-subtlety-shuriken-toss',114014,{type='BEYOND_MELEE',unit='target'}),
 }},
}))
