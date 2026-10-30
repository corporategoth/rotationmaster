-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Combat Rogue, Sinister Strike builder (Icy Veins, Warcraft Tavern, Method, wowtbc.gg; off by
-- default): how Combat played before the Siege of Orgrimmar patch raised Sinister Strike to 50 energy on 2026-06-02,
-- superseded for Phase 5. Slice and Dice, Revealing Strike kept up, five-point Rupture on a long single fight and
-- Eviscerate, Sinister Strike as the builder; same reminders and pack play as the recommended Combat premade. Same switch
-- (Combat specialization), lower priority. Shared parts: mop/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function buffRemain(id,op,n)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.combat.icyveins',revision=7,
 blocks={['mop.rogue.boundaries']=3,['mop.rogue.combat-opener']=2,['mop.rogue.out-of-combat']=3,['mop.rogue.combat-aoe']=2,['mop.rogue.solo']=2,['mop.rogue.upkeep']=1,['mop.rogue.combat-upkeep']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE'},
 tags={'combat','dps','melee','leveling','endgame','icy-veins','warcraft-tavern','method','wowtbc'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/combat-rogue-pve-rotation-cooldowns-abilities',title='Icy Veins: Combat Rogue rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-09-23'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-combat-rogue-dps-rotations-cooldowns/',title='Warcraft Tavern: Combat Rogue rotation (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.method.gg/mop-classic/combat-rogue-class-guide-mop-classic',title='Method: Combat Rogue guide (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://wowtbc.gg/mop/class-guides/combat-rogue/',title='wowtbc.gg: Combat Rogue (MoP Classic)',reviewedAt='2026-10-23'}},
 body={priority=20,disabled=true,specs={260},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.rogue.upkeep','rogue-'),block('mop.rogue.combat-upkeep','rogue-')},
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 block('mop.rogue.combat-opener','rogue-'),
 block('mop.rogue.out-of-combat','rogue-'),
 block('mop.rogue.combat-aoe','rogue-'),
 BuiltinConditions.spell('rogue-combat-iv-slice',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',2),BuiltinConditions.negate(BuiltinConditions.ownBuff(5171)))),
 block('mop.rogue.solo','rogue-'),
 BuiltinConditions.spell('rogue-combat-iv-revealing-strike',84617,BuiltinConditions.negate(mine(84617))),
 {id='rogue-combat-iv-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-combat-iv-finisher-slice',5171,buffRemain(5171,'LESSTHANOREQUALS',2)),
  BuiltinConditions.spell('rogue-combat-iv-rupture',1943,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(mine(1943)),remain(1943,'LESSTHANOREQUALS',2)),BuiltinConditions.negate(BuiltinConditions.ownBuff(13877)),BuiltinConditions.any(boss,BuiltinConditions.lifetime('GREATERTHAN',26)))),
  BuiltinConditions.spell('rogue-combat-iv-eviscerate',2098),
  {id='rogue-combat-iv-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 BuiltinConditions.spell('rogue-combat-iv-dying',2098,BuiltinConditions.all(points('GREATERTHANOREQUALS',2),BuiltinConditions.lifetime('LESSTHAN',4))),
 BuiltinConditions.spell('rogue-combat-iv-sinister',1752),
 BuiltinConditions.spell('rogue-combat-iv-shuriken-toss',114014,{type='BEYOND_MELEE',unit='target'}),
 }},
}))
