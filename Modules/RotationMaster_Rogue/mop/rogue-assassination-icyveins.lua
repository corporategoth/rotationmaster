-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Assassination Rogue, Icy Veins and Method variant (Phase 2 text; off by default): Vanish on
-- cooldown for a stealthed Mutilate, Vendetta on cooldown when a fight is long enough, Envenom only at five points.
-- Four to eight engaged enemies: Fan of Knives with Rupture at three or more on each target; nine or more: Fan of Knives
-- and Envenom only. Same switch as the recommended Assassination premade (Assassination specialization), lower priority; enable it and
-- disable the recommended one to use it. Shared parts: mop/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function target(op,n)return{type='HEALTHPCT',unit='target',operator=op,value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local sliced=BuiltinConditions.ownBuff(5171)
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local dying=BuiltinConditions.all(points('GREATERTHANOREQUALS',2),BuiltinConditions.lifetime('LESSTHAN',4))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.assassination.icyveins',revision=8,
 blocks={['mop.rogue.boundaries']=3,['mop.rogue.assassination-opener']=3,['mop.rogue.out-of-combat']=3,['mop.rogue.solo']=2,['mop.rogue.upkeep']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE'},
 tags={'assassination','dps','melee','leveling','endgame','icy-veins','method'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/assassination-rogue-pve-rotation-cooldowns-abilities',title='Icy Veins: Assassination Rogue rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-09-23'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/assassination-rogue-leveling',title='Icy Veins: Assassination Rogue leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-09-23'},
 {url='https://www.method.gg/mop-classic/assassination-rogue-class-guide-mop-classic',title='Method: Assassination Rogue guide (MoP Classic)',reviewedAt='2026-10-23'}},
 body={priority=20,disabled=true,specs={259},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.rogue.upkeep','rogue-'),
  BuiltinConditions.spell('rogue-assassination-iv-vendetta',79140,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(boss,BuiltinConditions.lifetime('GREATERTHAN',20)))),
  BuiltinConditions.spell('rogue-assassination-iv-shadow-blades',121471,BuiltinConditions.all(BuiltinConditions.combat(),mine(79140))),
  BuiltinConditions.spell('rogue-assassination-iv-vanish',1856,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='STEALTHED'}))),
  BuiltinConditions.spell('rogue-assassination-iv-preparation',14185,BuiltinConditions.all(BuiltinConditions.combat(),{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=60})),
 },
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 block('mop.rogue.assassination-opener','rogue-'),
 block('mop.rogue.out-of-combat','rogue-'),
 {id='rogue-assassination-iv-aoe',type='branch',conditions=BuiltinConditions.all(enemies('GREATERTHANOREQUALS',4),BuiltinConditions.known(51723)),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-assassination-iv-aoe-slice',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',1),BuiltinConditions.negate(sliced))),
  BuiltinConditions.spell('rogue-assassination-iv-aoe-rupture',1943,BuiltinConditions.all(enemies('LESSTHANOREQUALS',8),points('GREATERTHANOREQUALS',3),BuiltinConditions.negate(mine(1943)))),
  {id='rogue-assassination-iv-aoe-spend',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
   BuiltinConditions.spell('rogue-assassination-iv-aoe-envenom',32645),BuiltinConditions.spell('rogue-assassination-iv-aoe-eviscerate',2098)}},
  BuiltinConditions.spell('rogue-assassination-iv-fan',51723),
  {id='rogue-assassination-iv-aoe-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 BuiltinConditions.spell('rogue-assassination-iv-slice',5171,BuiltinConditions.all(points('GREATERTHANOREQUALS',1),BuiltinConditions.negate(sliced))),
 block('mop.rogue.solo','rogue-'),
 BuiltinConditions.spell('rogue-assassination-iv-rupture',1943,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.all(points('GREATERTHANOREQUALS',1),BuiltinConditions.negate(mine(1943))),BuiltinConditions.all(points('GREATERTHANOREQUALS',5),remain(1943,'LESSTHAN',2))),
  BuiltinConditions.any(boss,BuiltinConditions.lifetime('GREATERTHAN',8)))),
 {id='rogue-assassination-iv-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  BuiltinConditions.spell('rogue-assassination-iv-envenom',32645),BuiltinConditions.spell('rogue-assassination-iv-eviscerate',2098),
  {id='rogue-assassination-iv-pool',type='stop',suppress_attack=false,conditions={}}}},
 BuiltinConditions.spell('rogue-assassination-iv-dying-envenom',32645,dying),
 BuiltinConditions.spell('rogue-assassination-iv-dying-eviscerate',2098,dying),
 BuiltinConditions.spell('rogue-assassination-iv-dispatch',111240,BuiltinConditions.all({type='WEAPON_TYPE',slot='mainhand',subclass=15},BuiltinConditions.any(target('LESSTHAN',.35),BuiltinConditions.ownBuff(121153)))),
 BuiltinConditions.spell('rogue-assassination-iv-mutilate',1329),
 BuiltinConditions.spell('rogue-assassination-iv-shuriken-toss',114014,{type='BEYOND_MELEE',unit='target'}),
 }},
}))
