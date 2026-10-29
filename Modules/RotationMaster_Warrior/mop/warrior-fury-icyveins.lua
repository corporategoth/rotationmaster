-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Fury Warrior, cooldowns inside Colossus Smash (Icy Veins; off by default). Same switch
-- as the recommended Fury premade (Fury specialization), lower priority. Differs by spending Bladestorm or Dragon Roar
-- first inside the Colossus Smash window and Execute ahead of Bloodthirst below 20%. In the window: tier-4 talent,
-- Raging Blow at two charges, Bloodthirst, Raging Blow, Wild Strike. Outside: Colossus Smash, Bloodthirst, Raging
-- Blow only at two charges, Wild Strike on Bloodsurge, shout, Wild Strike. Below 20%: Dragon Roar outside the window,
-- Colossus Smash, Execute, Bloodthirst under 30 rage, Raging Blow at two, Wild Strike on Bloodsurge, shout. Four or
-- more enemies: Bloodthirst for Enrage, Whirlwind to three Meat Cleaver stacks, Raging Blow; two or three add
-- Whirlwind before the single-target list. Heroic Strike or Cleave only at the cap. Shared parts: mop/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function target(op,n)return{type='HEALTHPCT',unit='target',operator=op,value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local smashed={type='DEBUFF',unit='target',spell=86346,owndebuff=true}
local full={type='BUFF_STACKS',unit='player',spell=131116,ownbuff=true,operator='EQUALS',value=2}
local enraged={type='BUFF',unit='player',spell=12880}
local worth=BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=15})
local burst=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.negate({type='SPELL_KNOWN',spell=86346}),smashed),worth)
local function shout(prefix)return{id=prefix..'shout',type='branch',conditions=rage('LESSTHAN',30),onFalse={},onTrue={BuiltinConditions.spell(prefix..'commanding',469,BuiltinConditions.ownBuff(469)),BuiltinConditions.spell(prefix..'battle',6673)}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warrior.fury.icyveins',revision=8,
 blocks={['mop.warrior.boundaries']=4,['mop.warrior.gap']=1,['mop.warrior.dps-upkeep']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARRIOR'},
 tags={'fury','dps','melee','leveling','endgame','icy-veins'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/fury-warrior-pve-rotation-cooldowns-abilities',title='Icy Veins: Fury Warrior rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/fury-warrior-leveling',title='Icy Veins: Fury Warrior leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'}},
 body={priority=20,disabled=true,specs={72},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.warrior.dps-upkeep','warrior-'),
  BuiltinConditions.spell('warrior-fury-iv-berserker-rage',18499,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(enraged))),
  BuiltinConditions.spell('warrior-fury-iv-recklessness',1719,burst),
  BuiltinConditions.spell('warrior-fury-iv-avatar',107574,burst),
  BuiltinConditions.spell('warrior-fury-iv-bloodbath',12292,burst),
  BuiltinConditions.spell('warrior-fury-iv-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),enemies('LESSTHAN',2),rage('GREATERTHANOREQUALS',90))),
  BuiltinConditions.spell('warrior-fury-iv-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',90))),
 },
 rotation={
 block('mop.warrior.boundaries','warrior-'),
 block('mop.warrior.gap','warrior-dps-'),
 {id='warrior-fury-iv-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',4),onTrue={
  BuiltinConditions.spell('warrior-fury-iv-aoe-enrage',23881,BuiltinConditions.negate(enraged)),
  BuiltinConditions.spell('warrior-fury-iv-meat-cleaver',1680,{type='BUFF_STACKS',unit='player',spell=85739,ownbuff=true,operator='LESSTHAN',value=3}),
  BuiltinConditions.spell('warrior-fury-iv-aoe-raging-blow',85288),
  BuiltinConditions.spell('warrior-fury-iv-aoe-bloodthirst',23881),
  {id='warrior-fury-iv-aoe-stop',type='stop',suppress_attack=false,conditions={}},
 },onFalse={
  BuiltinConditions.spell('warrior-fury-iv-cleave-whirlwind',1680,BuiltinConditions.all(enemies('GREATERTHANOREQUALS',2),BuiltinConditions.negate(BuiltinConditions.ownBuff(85739)))),
 }},
 {id='warrior-fury-iv-execute-phase',type='branch',conditions=target('LESSTHAN',.2),onTrue={
  BuiltinConditions.spell('warrior-fury-iv-execute-dragon-roar',118000,BuiltinConditions.negate(smashed)),
  BuiltinConditions.spell('warrior-fury-iv-execute-smash',86346,BuiltinConditions.negate(smashed)),
  BuiltinConditions.spell('warrior-fury-iv-execute',5308),
  BuiltinConditions.spell('warrior-fury-iv-execute-bloodthirst',23881,rage('LESSTHAN',30)),
  BuiltinConditions.spell('warrior-fury-iv-execute-raging-blow',85288,full),
  BuiltinConditions.spell('warrior-fury-iv-execute-bloodsurge',100130,BuiltinConditions.ownBuff(46916)),
  shout('warrior-fury-iv-execute-'),
 },onFalse={
  {id='warrior-fury-iv-window',type='branch',conditions=smashed,onTrue={
   BuiltinConditions.spell('warrior-fury-iv-window-bladestorm',46924),
   BuiltinConditions.spell('warrior-fury-iv-window-dragon-roar',118000),
   BuiltinConditions.spell('warrior-fury-iv-window-raging-blow-full',85288,full),
   BuiltinConditions.spell('warrior-fury-iv-window-bloodthirst',23881),
   BuiltinConditions.spell('warrior-fury-iv-window-raging-blow',85288),
   BuiltinConditions.spell('warrior-fury-iv-window-wild-strike',100130),
  },onFalse={
   BuiltinConditions.spell('warrior-fury-iv-smash',86346),
   BuiltinConditions.spell('warrior-fury-iv-bloodthirst',23881),
   BuiltinConditions.spell('warrior-fury-iv-raging-blow',85288,BuiltinConditions.any(BuiltinConditions.negate({type='SPELL_KNOWN',spell=86346}),full)),
   BuiltinConditions.spell('warrior-fury-iv-bloodsurge',100130,BuiltinConditions.ownBuff(46916)),
   shout('warrior-fury-iv-'),
   BuiltinConditions.spell('warrior-fury-iv-wild-strike',100130),
  }},
 }},
 }},
}))
