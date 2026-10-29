-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Rogue before a specialization (levels 1-9, or a rogue who has not picked one): the catch-all
-- at the lowest priority, so each spec premade wins once a specialization is chosen. Stealth opens with Cheap Shot solo,
-- Ambush, or Sinister Strike; out of combat Stealth; Slice and Dice from two points, Recuperate and Kidney Shot solo,
-- Eviscerate at four points (two when the target is about to die), Sinister Strike. Built from the 5.5.4 kit (Sinister
-- Strike 1, Eviscerate 3, Stealth 5, Ambush 6) and Warcraft Tavern's and Icy Veins' levelling advice. Shared parts:
-- mop/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.unspecialized',revision=6,
 blocks={['mop.rogue.boundaries']=3,['mop.rogue.out-of-combat']=3,['mop.rogue.solo']=2,['mop.rogue.upkeep']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE'},
 tags={'dps','melee','leveling','warcraft-tavern','icy-veins'},
 sources={{url='https://www.warcrafttavern.com/mop/guides/rogue-leveling-guide/',title='Warcraft Tavern: Rogue leveling guide (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/combat-rogue-leveling',title='Icy Veins: Combat Rogue leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-09-23'}},
 body={priority=1,
 cooldowns={block('mop.rogue.upkeep','rogue-')},
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 {id='rogue-starter-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
  BuiltinConditions.spell('rogue-starter-cheap-shot',1833,BuiltinConditions.negate({type='GROUP'})),
  BuiltinConditions.spell('rogue-starter-ambush',8676),
  BuiltinConditions.spell('rogue-starter-stealth-sinister',1752),
  {id='rogue-starter-stealth-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 block('mop.rogue.out-of-combat','rogue-'),
 BuiltinConditions.spell('rogue-starter-slice',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',2),BuiltinConditions.negate({type='BUFF',unit='player',spell=5171,ownbuff=true}))),
 block('mop.rogue.solo','rogue-'),
 BuiltinConditions.spell('rogue-starter-eviscerate',2098,BuiltinConditions.any(points('GREATERTHANOREQUALS',4),BuiltinConditions.all(points('GREATERTHANOREQUALS',2),{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=4}))),
 BuiltinConditions.spell('rogue-starter-sinister',1752),
 }},
}))
