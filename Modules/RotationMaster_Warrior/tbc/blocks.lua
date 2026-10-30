-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared TBC Warrior blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.warrior.dps.{simulator,icyveins} and rm.tbc.warrior.protection.{wowhead,icyveins}.
-- A content change needs a block revision bump, every consumer's pin and revision
-- bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research tbc/warrior.md.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
-- Enemies (with nameplates) that have you on their threat table: never an uncertain range guess.
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function targetHealth(op,n)return{type='HEALTHPCT',unit='target',operator=op,value=n}end
local function debuff(id,own)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=own or nil}end
-- Heroic Strike is not queued, and Cleave (once learned) is neither queued nor wanted for a pack.
local function single()return BuiltinConditions.all(BuiltinConditions.negate(queued(78)),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(845)),BuiltinConditions.all(BuiltinConditions.negate(queued(845)),BuiltinConditions.negate(enemies(2)))))end
local interrupt=BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- One boundary each: manual casts/channels (Slam, bandages), no attackable target, and the out-of-combat pull.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.boundaries',revision=4,families={'tbc'},class='WARRIOR',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('charge',100),
  {id='pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
}}))
-- Independent reminders both roles agree on: a shout, Bloodrage, interrupts and the multi-target rage dump.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.upkeep',revision=1,families={'tbc'},class='WARRIOR',steps={
 BuiltinConditions.spell('battle-shout',6673,BuiltinConditions.all(BuiltinConditions.negate({type='BUFF',unit='player',spell=6673,anyrank=true}),BuiltinConditions.negate({type='BUFF',unit='player',spell=469,anyrank=true}))),
 BuiltinConditions.spell('bloodrage',2687,BuiltinConditions.all(BuiltinConditions.combat(),rage('LESSTHAN',50),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
 BuiltinConditions.spell('pummel',6552,interrupt),
 BuiltinConditions.spell('shield-bash',72,interrupt),
 BuiltinConditions.spell('cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),rage('GREATERTHANOREQUALS',40),BuiltinConditions.negate(queued(845)),enemies(2))),
}}))
-- DPS reminders: Heroic Strike dumps 60 rage (30 before Mortal Strike/Bloodthirst), and yields to Cleave on packs.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.dps-upkeep',revision=1,families={'tbc'},class='WARRIOR',steps={
 BuiltinConditions.spell('heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(rage('GREATERTHANOREQUALS',60),BuiltinConditions.all(rage('GREATERTHANOREQUALS',30),BuiltinConditions.negate(BuiltinConditions.known(12294)),BuiltinConditions.negate(BuiltinConditions.known(23881)))),single())),
 BuiltinConditions.spell('sweeping-strikes',12328,BuiltinConditions.all(BuiltinConditions.combat(),enemies(2))),
 BuiltinConditions.spell('death-wish',12292,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite')))),
 BuiltinConditions.spell('recklessness',1719,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.classified('worldboss'))),
}}))
-- Combat opening shared by both DPS variants: procs, gap closer, Rampage upkeep, then the multi-target arm.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.dps-opening',revision=1,families={'tbc'},class='WARRIOR',steps={
 BuiltinConditions.spell('victory-rush',34428),
 BuiltinConditions.spell('intercept',20252,{type='BEYOND_MELEE',unit='target'}),
 BuiltinConditions.spell('rampage',29801,BuiltinConditions.any(BuiltinConditions.negate({type='BUFF',unit='player',spell=29801,anyrank=true,ownbuff=true}),
  {type='BUFF_REMAIN',unit='player',spell=29801,anyrank=true,ownbuff=true,operator='LESSTHAN',value=5})),
 {id='aoe',type='branch',conditions=enemies(2),onFalse={},onTrue={
  BuiltinConditions.spell('whirlwind',1680),
  BuiltinConditions.spell('thunder-clap',6343,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(1680)),BuiltinConditions.negate(debuff(6343)))),
 }},
}}))
-- Before Mortal Strike or Bloodthirst: Whirlwind, Execute, Overpower, then Rend at the start of a fight.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.dps-leveling',revision=1,families={'tbc'},class='WARRIOR',steps={
 BuiltinConditions.spell('whirlwind',1680),
 BuiltinConditions.spell('execute',5308,targetHealth('LESSTHAN',.2)),
 BuiltinConditions.spell('overpower',7384),
 BuiltinConditions.spell('rend',772,BuiltinConditions.all(BuiltinConditions.negate(debuff(772,true)),targetHealth('GREATERTHAN',.5))),
}}))
-- Tanking core both protection variants share.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.prot-core',revision=1,families={'tbc'},class='WARRIOR',steps={
 BuiltinConditions.spell('shield-slam',23922),
 BuiltinConditions.spell('revenge',6572),
}}))
-- Tank reminders: Heroic Strike from 30 rage on one target, and emergency defensives.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.prot-upkeep',revision=1,families={'tbc'},class='WARRIOR',steps={
 BuiltinConditions.spell('heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),rage('GREATERTHANOREQUALS',30),single())),
 BuiltinConditions.spell('last-stand',12975,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3})),
 BuiltinConditions.spell('shield-wall',871,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.2})),
}}))
-- Armor reduction: Devastate when known, otherwise Sunder Armor up to five applications (tank and DPS filler).
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.sunder',revision=1,families={'tbc'},class='WARRIOR',steps={
 BuiltinConditions.spell('devastate',20243),
 BuiltinConditions.spell('sunder',7386,BuiltinConditions.any(BuiltinConditions.negate(debuff(7386)),{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='LESSTHAN',value=5})),
}}))
