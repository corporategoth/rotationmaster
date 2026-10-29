-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight) Warrior blocks (Built In composition; authoring-time only).
-- Consumers: rm.retail.warrior.arms, .arms.slayer, .arms.colossus, .fury, .fury.slayer,
-- .fury.thane, .protection and .protection.icyveins. A content change needs a block revision
-- bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research retail/warrior.md.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local interrupt=BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- Casting or channelling ends advice (Attack continues); no attackable target ends it too.
assert(addon:RegisterDefaultBlock({
 id='retail.warrior.boundaries',revision=2,families={'retail'},class='WARRIOR',steps={
 {id='casting',type='stop',suppress_attack=false,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
}}))
-- Reminders every Warrior premade shares: Battle Shout (anyone's) between pulls, Pummel on an
-- interruptible cast (the target's cast is hidden in Midnight combat, so it lights only where it
-- can be read).
assert(addon:RegisterDefaultBlock({
 id='retail.warrior.upkeep',revision=1,families={'retail'},class='WARRIOR',steps={
 BuiltinConditions.spell('battle-shout',6673,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='BUFF',unit='player',spell=6673}))),
 BuiltinConditions.spell('pummel',6552,BuiltinConditions.all(BuiltinConditions.combat(),interrupt)),
}}))
-- The guide lists open with Charge: out of combat, Charge, then stop.
assert(addon:RegisterDefaultBlock({
 id='retail.warrior.charge',revision=3,families={'retail'},class='WARRIOR',steps={
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('charge',100),
  {id='pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
}}))
