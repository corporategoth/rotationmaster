-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Combat Rogue, levels 10-90 (the recommended variant): Wowhead's Phase 5 page and simulator
-- after the Siege of Orgrimmar patch (Sinister Strike now costs 50 energy), so Revealing Strike is the builder and
-- Sinister Strike is used only under a Bloodlust effect with Adrenaline Rush. Selected in the Combat specialization (260).
-- Stealth opens with Cheap Shot solo, else Ambush. Eight or more engaged enemies: Slice and Dice, Crimson Tempest,
-- Fan of Knives. One target: Slice and Dice from two points; five-point finishers only with Revealing Strike up
-- (Slice and Dice, Rupture on a long single fight without Blade Flurry, Eviscerate), pooling at five; Marked for
-- Death; Revealing Strike when its debuff is ending; Sinister Strike before 20. Reminders: Blade Flurry on and off by
-- engaged enemies, Adrenaline Rush under 35 energy with Shadow Blades, Killing Spree, Vanish and Preparation for
-- Ambush in Deep Insight. Shared parts: mop/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function buffRemain(id,op,n)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local lust=BuiltinConditions.any(BuiltinConditions.buff(2825),BuiltinConditions.buff(32182),BuiltinConditions.buff(80353),BuiltinConditions.buff(90355))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.combat',revision=8,
 blocks={['mop.rogue.boundaries']=3,['mop.rogue.combat-opener']=2,['mop.rogue.out-of-combat']=3,['mop.rogue.combat-aoe']=2,['mop.rogue.solo']=2,['mop.rogue.upkeep']=1,['mop.rogue.combat-upkeep']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE'},
 tags={'combat','dps','melee','leveling','endgame','wowhead'},
 sources={{url='https://www.wowhead.com/mop-classic/guide/classes/rogue/combat/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Combat Rogue rotation (MoP Classic, Phase 5)',reviewedAt='2026-10-23',revision='2026-06-29'},

 {url='https://www.wowhead.com/mop-classic/guide/classes/rogue/combat/dps-leveling-talent-builds-tips',title='Wowhead: Combat Rogue leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2026-06-29'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/combat-rogue-leveling',title='Icy Veins: Combat Rogue leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-09-23'}},
 body={priority=30,specs={260},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.rogue.upkeep','rogue-'),block('mop.rogue.combat-upkeep','rogue-')},
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 block('mop.rogue.combat-opener','rogue-'),
 block('mop.rogue.out-of-combat','rogue-'),
 block('mop.rogue.combat-aoe','rogue-'),
 BuiltinConditions.spell('rogue-combat-slice',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',2),BuiltinConditions.negate(BuiltinConditions.ownBuff(5171)))),
 block('mop.rogue.solo','rogue-'),
 {id='rogue-combat-finisher',type='branch',conditions=BuiltinConditions.all(points('GREATERTHANOREQUALS',5),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(84617)),mine(84617))),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-combat-finisher-slice',5171,buffRemain(5171,'LESSTHANOREQUALS',2)),
  BuiltinConditions.spell('rogue-combat-rupture',1943,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(mine(1943)),remain(1943,'LESSTHANOREQUALS',2)),BuiltinConditions.negate(BuiltinConditions.ownBuff(13877)),BuiltinConditions.any(boss,BuiltinConditions.lifetime('GREATERTHAN',26)))),
  BuiltinConditions.spell('rogue-combat-eviscerate',2098),
  {id='rogue-combat-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 BuiltinConditions.spell('rogue-combat-dying',2098,BuiltinConditions.all(points('GREATERTHANOREQUALS',2),BuiltinConditions.lifetime('LESSTHAN',4))),
 BuiltinConditions.spell('rogue-combat-marked-for-death',137619,points('LESSTHANOREQUALS',0)),
 BuiltinConditions.spell('rogue-combat-revealing-refresh',84617,BuiltinConditions.any(BuiltinConditions.negate(mine(84617)),remain(84617,'LESSTHANOREQUALS',3))),
 BuiltinConditions.spell('rogue-combat-lust-sinister',1752,BuiltinConditions.all(BuiltinConditions.ownBuff(13750),lust)),
 BuiltinConditions.spell('rogue-combat-revealing-strike',84617),
 BuiltinConditions.spell('rogue-combat-sinister',1752),
 BuiltinConditions.spell('rogue-combat-shuriken-toss',114014,{type='BEYOND_MELEE',unit='target'}),
 }},
}))
