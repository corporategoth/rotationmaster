-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Fury Warrior, levels 10-90 (the recommended variant): simulator' Phase 5 order,
-- simplified. Selected in the Fury specialization (72). The off hand tells Titan's Grip (a two-hander) from
-- Single-Minded Fury (a one-hander) where simulator plays them apart. Colossus Smash when two Raging Blow charges
-- are banked (one with Recklessness); Raging Blow to spend charges as the window closes; Bloodthirst; Colossus
-- Smash; Storm Bolt with it; Dragon Roar outside it; Execute here with Single-Minded Fury; Bladestorm outside the
-- window while Bloodthirst is cooling; with Titan's Grip one more Raging Blow outside the window and Recklessness;
-- Execute; Wild
-- Strike on Bloodsurge; Raging Blow keeping one charge for the next window; Wild Strike as the filler; Heroic
-- Throw; Battle Shout for rage. Two or more engaged enemies add Bladestorm, Dragon Roar, Whirlwind for Meat
-- Cleaver and Raging Blow cleaves. Before Colossus Smash (81) the "not known" arms keep Raging Blow and Wild
-- Strike open. Shared parts: mop/blocks.lua. The Icy Veins variant spends the tier-4 talent inside the window.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function target(op,n)return{type='HEALTHPCT',unit='target',operator=op,value=n}end
local function charges(op,n)return{type='BUFF_STACKS',unit='player',spell=131116,ownbuff=true,operator=op,value=n}end
local function smash(op,n)return{type='SPELL_COOLDOWN',spell=86346,operator=op,value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local smashed={type='DEBUFF',unit='target',spell=86346,owndebuff=true}
local unsmashed={type='NOT',value={type='SPELL_KNOWN',spell=86346}}
local worth=BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=15})
-- Heroic Strike / Cleave dump: 60 rage in the window, 90 outside it (not in execute).
local dump=BuiltinConditions.any(BuiltinConditions.all(smashed,rage('GREATERTHANOREQUALS',60)),BuiltinConditions.all(target('GREATERTHANOREQUALS',.2),rage('GREATERTHANOREQUALS',90)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warrior.fury',revision=8,
 blocks={['mop.warrior.boundaries']=4,['mop.warrior.gap']=1,['mop.warrior.dps-upkeep']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARRIOR'},
 tags={'fury','dps','melee','leveling','endgame'},
 sources={
 {url='https://wowtbc.gg/mop/class-guides/fury-warrior/',title='wowtbc.gg: Fury Warrior (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-fury-warrior-dps-rotation-cooldowns/',title='Warcraft Tavern: Fury Warrior rotation (MoP)',reviewedAt='2026-10-23'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/fury-warrior-leveling',title='Icy Veins: Fury Warrior leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'}},
 body={priority=30,specs={72},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.warrior.dps-upkeep','warrior-'),
  BuiltinConditions.spell('warrior-fury-berserker-rage',18499,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.negate({type='BUFF',unit='player',spell=12880}),BuiltinConditions.all(smashed,charges('EQUALS',0),target('GREATERTHANOREQUALS',.2))))),
  BuiltinConditions.spell('warrior-fury-recklessness',1719,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(unsmashed,smashed,smash('LESSTHANOREQUALS',1.5),enemies('GREATERTHANOREQUALS',4)),worth)),
  BuiltinConditions.spell('warrior-fury-avatar',107574,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(unsmashed,smashed),worth)),
  BuiltinConditions.spell('warrior-fury-bloodbath',12292,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(unsmashed,smashed),worth)),
  BuiltinConditions.spell('warrior-fury-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),enemies('LESSTHAN',2),dump)),
  BuiltinConditions.spell('warrior-fury-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),enemies('GREATERTHANOREQUALS',2),dump)),
 },
 rotation={
 block('mop.warrior.boundaries','warrior-'),
 block('mop.warrior.gap','warrior-dps-'),
 {id='warrior-fury-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  BuiltinConditions.spell('warrior-fury-aoe-bladestorm',46924,enemies('GREATERTHANOREQUALS',3)),
  BuiltinConditions.spell('warrior-fury-aoe-dragon-roar',118000,BuiltinConditions.negate(smashed)),
  BuiltinConditions.spell('warrior-fury-aoe-enrage',23881,BuiltinConditions.negate({type='BUFF',unit='player',spell=12880})),
  BuiltinConditions.spell('warrior-fury-meat-cleaver',1680,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(85739)),BuiltinConditions.all(enemies('GREATERTHANOREQUALS',4),{type='BUFF_STACKS',unit='player',spell=85739,ownbuff=true,operator='LESSTHAN',value=3}))),
  BuiltinConditions.spell('warrior-fury-aoe-raging-blow',85288,BuiltinConditions.ownBuff(85739)),
  BuiltinConditions.spell('warrior-fury-aoe-smash',86346,BuiltinConditions.negate(smashed)),
  BuiltinConditions.spell('warrior-fury-aoe-bloodthirst',23881),
  BuiltinConditions.spell('warrior-fury-whirlwind',1680,enemies('GREATERTHANOREQUALS',3)),
 }},
 BuiltinConditions.spell('warrior-fury-smash-setup',86346,BuiltinConditions.all(BuiltinConditions.negate(smashed),BuiltinConditions.any(charges('EQUALS',2),BuiltinConditions.all(charges('EQUALS',1),BuiltinConditions.ownBuff(1719))))),
 BuiltinConditions.spell('warrior-fury-raging-blow-closing',85288,BuiltinConditions.all(smashed,{type='DEBUFF_REMAIN',unit='target',spell=86346,owndebuff=true,operator='LESSTHANOREQUALS',value=1.5})),
 BuiltinConditions.spell('warrior-fury-bloodthirst',23881),
 BuiltinConditions.spell('warrior-fury-smash',86346,BuiltinConditions.negate(smashed)),
 BuiltinConditions.spell('warrior-fury-storm-bolt',107570,BuiltinConditions.any(smashed,smash('GREATERTHAN',1.5))),
 BuiltinConditions.spell('warrior-fury-dragon-roar',118000,BuiltinConditions.negate(smashed)),
 BuiltinConditions.spell('warrior-fury-execute-single-minded',5308,{type='WEAPON_TYPE',slot='offhand',kind='onehand'}),
 BuiltinConditions.spell('warrior-fury-bladestorm',46924,BuiltinConditions.all(BuiltinConditions.negate(smashed),{type='SPELL_COOLDOWN',spell=23881,operator='GREATERTHANOREQUALS',value=2.5})),
 BuiltinConditions.spell('warrior-fury-raging-blow-titans-grip',85288,BuiltinConditions.all({type='WEAPON_TYPE',slot='offhand',kind='twohand'},BuiltinConditions.negate(smashed),BuiltinConditions.negate(BuiltinConditions.ownBuff(1719)))),
 BuiltinConditions.spell('warrior-fury-execute',5308),
 BuiltinConditions.spell('warrior-fury-bloodsurge',100130,BuiltinConditions.all(BuiltinConditions.ownBuff(46916),charges('LESSTHANOREQUALS',1))),
 BuiltinConditions.spell('warrior-fury-raging-blow',85288,BuiltinConditions.any(unsmashed,charges('EQUALS',2),smashed,smash('GREATERTHAN',1.5))),
 BuiltinConditions.spell('warrior-fury-wild-strike',100130,BuiltinConditions.all(target('GREATERTHANOREQUALS',.2),BuiltinConditions.any(unsmashed,smashed,smash('GREATERTHAN',3),rage('GREATERTHANOREQUALS',80)))),
 BuiltinConditions.spell('warrior-fury-heroic-throw',57755,BuiltinConditions.any(unsmashed,smash('GREATERTHAN',1))),
 {id='warrior-fury-shout-rage',type='branch',conditions=BuiltinConditions.all(rage('LESSTHANOREQUALS',80),BuiltinConditions.negate({type='SPELL_KNOWN',spell=46924})),onFalse={},onTrue={
  BuiltinConditions.spell('warrior-fury-commanding',469,BuiltinConditions.ownBuff(469)),BuiltinConditions.spell('warrior-fury-battle',6673)}},
 }},
}))
