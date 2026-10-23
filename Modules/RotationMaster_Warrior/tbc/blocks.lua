-- Shared TBC Warrior blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.warrior.dps.{wowsims,icyveins} and rm.tbc.warrior.protection.{wowhead,icyveins}.
-- A content change needs a block revision bump, every consumer's pin and revision
-- bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research tbc/warrior.md.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
-- Enemies (with nameplates) that have you on their threat table: never an uncertain range guess.
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function targetHealth(op,n)return{type='HEALTHPCT',unit='target',operator=op,value=n}end
local function debuff(id,own)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=own or nil}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
-- Heroic Strike is not queued, and Cleave (once learned) is neither queued nor wanted for a pack.
local function single()return all(negate(queued(78)),any(negate(known(845)),all(negate(queued(845)),negate(enemies(2)))))end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- One boundary each: manual casts/channels (Slam, bandages), no attackable target, and the out-of-combat pull.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.boundaries',revision=2,families={'tbc'},class='WARRIOR',steps={
 {id='manual',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('charge',100),
  {id='pull-stop',type='none',suppress_attack=false,conditions={}},
 }},
}}))
-- Independent reminders both roles agree on: a shout, Bloodrage, interrupts and the multi-target rage dump.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.upkeep',revision=1,families={'tbc'},class='WARRIOR',steps={
 spell('battle-shout',6673,all(negate({type='BUFF',unit='player',spell=6673,anyrank=true}),negate({type='BUFF',unit='player',spell=469,anyrank=true}))),
 spell('bloodrage',2687,all(combat(),rage('LESSTHAN',50),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
 spell('pummel',6552,interrupt),
 spell('shield-bash',72,interrupt),
 spell('cleave',845,all(combat(),rage('GREATERTHANOREQUALS',40),negate(queued(845)),enemies(2))),
}}))
-- DPS reminders: Heroic Strike dumps 60 rage (30 before Mortal Strike/Bloodthirst), and yields to Cleave on packs.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.dps-upkeep',revision=1,families={'tbc'},class='WARRIOR',steps={
 spell('heroic-strike',78,all(combat(),any(rage('GREATERTHANOREQUALS',60),all(rage('GREATERTHANOREQUALS',30),negate(known(12294)),negate(known(23881)))),single())),
 spell('sweeping-strikes',12328,all(combat(),enemies(2))),
 spell('death-wish',12292,all(combat(),any(classified('worldboss'),classified('elite')))),
 spell('recklessness',1719,all(combat(),classified('worldboss'))),
}}))
-- Combat opening shared by both DPS variants: procs, gap closer, Rampage upkeep, then the multi-target arm.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.dps-opening',revision=1,families={'tbc'},class='WARRIOR',steps={
 spell('victory-rush',34428),
 spell('intercept',20252,{type='BEYOND_MELEE',unit='target'}),
 spell('rampage',29801,any(negate({type='BUFF',unit='player',spell=29801,anyrank=true,ownbuff=true}),
  {type='BUFF_REMAIN',unit='player',spell=29801,anyrank=true,ownbuff=true,operator='LESSTHAN',value=5})),
 {id='aoe',type='branch',conditions=enemies(2),onFalse={},onTrue={
  spell('whirlwind',1680),
  spell('thunder-clap',6343,all(negate(known(1680)),negate(debuff(6343)))),
 }},
}}))
-- Before Mortal Strike or Bloodthirst: Whirlwind, Execute, Overpower, then Rend at the start of a fight.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.dps-leveling',revision=1,families={'tbc'},class='WARRIOR',steps={
 spell('whirlwind',1680),
 spell('execute',5308,targetHealth('LESSTHAN',.2)),
 spell('overpower',7384),
 spell('rend',772,all(negate(debuff(772,true)),targetHealth('GREATERTHAN',.5))),
}}))
-- Tanking core both protection variants share.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.prot-core',revision=1,families={'tbc'},class='WARRIOR',steps={
 spell('shield-slam',23922),
 spell('revenge',6572),
}}))
-- Tank reminders: Heroic Strike from 30 rage on one target, and emergency defensives.
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.prot-upkeep',revision=1,families={'tbc'},class='WARRIOR',steps={
 spell('heroic-strike',78,all(combat(),rage('GREATERTHANOREQUALS',30),single())),
 spell('last-stand',12975,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3})),
 spell('shield-wall',871,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.2})),
}}))
-- Armor reduction: Devastate when known, otherwise Sunder Armor up to five applications (tank and DPS filler).
assert(addon:RegisterDefaultBlock({
 id='tbc.warrior.sunder',revision=1,families={'tbc'},class='WARRIOR',steps={
 spell('devastate',20243),
 spell('sunder',7386,any(negate(debuff(7386)),{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='LESSTHAN',value=5})),
}}))
