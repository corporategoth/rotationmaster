-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared WoW Forever Rogue blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.rogue.dps, rm.forever.rogue.subtlety.warcrafttavern and
-- rm.forever.rogue.subtlety.wowhead. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research forever/rogue.md.
-- Spell and item IDs are from Wowhead's Forever database and SimulationCraft's 1.60.1 dump; verify in game.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function item(id,items,conditions)return{id=id,type='item',action=items,conditions=conditions}end
local tanked={type='THREAT',unit='target',threat=3}
-- Instant Poison I-VI; the off hand prefers Deadly Poison I-V (30) and falls back to Instant.
local instant={8928,8927,8926,6950,6949,6947}
local offhand={20844,8985,8984,2893,2892}
for _,id in ipairs(instant)do offhand[#offhand+1]=id end
-- Manual casts/channels (bandages, Pick Lock, poisons) and a missing target end advice and Attack.
assert(addon:RegisterDefaultBlock({
 id='forever.rogue.boundaries',revision=3,families={'forever'},class='ROGUE',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
}}))
-- The end of every stealth opener: Ambush when the target is not facing you, Garrote, then
-- Sinister Strike before either is learned; Stop so the opener never falls into the builders.
assert(addon:RegisterDefaultBlock({
 id='forever.rogue.stealth-fallback',revision=3,families={'forever'},class='ROGUE',steps={
 BuiltinConditions.spell('ambush',8676,BuiltinConditions.negate(tanked)),
 BuiltinConditions.spell('garrote',703),
 BuiltinConditions.spell('sinister',1752),
 {id='stop',type='stop',suppress_attack=true,conditions={}},
}}))
-- Reactive strikes the engine enables: Riposte after a parry, Ambush out of Stealth on a
-- Cutthroat proc (spent below five points).
assert(addon:RegisterDefaultBlock({
 id='forever.rogue.reactive',revision=1,families={'forever'},class='ROGUE',steps={
 BuiltinConditions.spell('riposte',14251),
 BuiltinConditions.spell('cutthroat-ambush',8676,points('LESSTHANOREQUALS',4)),
}}))
-- Expose Armor in a group against an elite or boss, unless a warrior already holds five Sunders.
assert(addon:RegisterDefaultBlock({
 id='forever.rogue.expose-armor',revision=1,families={'forever'},class='ROGUE',steps={
 BuiltinConditions.spell('expose-armor',8647,BuiltinConditions.all({type='GROUP'},BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite')),points('GREATERTHANOREQUALS',5),
  BuiltinConditions.negate({type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=5}),
  BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=8647,anyrank=true,owndebuff=true}),
   {type='DEBUFF_REMAIN',unit='target',spell=8647,anyrank=true,owndebuff=true,operator='LESSTHAN',value=3}))),
}}))
-- Independent reminders: poisons per weapon, Thistle Tea in combat outside Adrenaline Rush, Kick,
-- the talent cooldowns, and Evasion (solo) / Feint (group) when the target turns on you. Energy and
-- health are secret on Forever, so Thistle Tea no longer waits for low energy and Evasion no longer
-- waits for low health.
assert(addon:RegisterDefaultBlock({
 id='forever.rogue.upkeep',revision=2,families={'forever'},class='ROGUE',steps={
 item('mainhand-poison',instant,BuiltinConditions.negate({type='WEAPON'})),
 item('offhand-poison',offhand,BuiltinConditions.all({type='SWING_TIME',offhand=true,operator='GREATERTHAN',value=0},BuiltinConditions.negate({type='WEAPON',offhand=true}))),
 item('thistle-tea',{7676},BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='BUFF',unit='player',spell=13750,ownbuff=true}))),
 BuiltinConditions.spell('kick',1766,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('blade-flurry',13877,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite'),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2}))),
 BuiltinConditions.spell('adrenaline-rush',13750,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite'),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2}))),
 -- Venom known (Assassination): empower a Mutilate at two points or fewer; else a five-point Eviscerate.
 BuiltinConditions.spell('cold-blood',14177,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.all(BuiltinConditions.known(1310703),points('LESSTHANOREQUALS',2)),BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(1310703)),points('GREATERTHANOREQUALS',5))))),
 BuiltinConditions.spell('evasion',5277,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),tanked)),
 BuiltinConditions.spell('feint',1966,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},{type='THREAT',unit='target',threat=2})),
}}))
