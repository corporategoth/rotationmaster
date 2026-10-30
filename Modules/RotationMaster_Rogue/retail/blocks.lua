-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight) Rogue blocks (Built In composition; authoring-time only).
-- Consumers: rm.retail.rogue.assassination, .assassination.icyveins, .outlaw, .outlaw.icyveins,
-- .subtlety and .subtlety.icyveins. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research retail/rogue.md. Retail poisons are buffs on you, read between pulls.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local interrupt=BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
local lethal=BuiltinConditions.any(BuiltinConditions.ownBuff(2823),BuiltinConditions.ownBuff(315584),BuiltinConditions.ownBuff(8679),BuiltinConditions.ownBuff(381664))
-- Casting or channelling ends advice; no attackable target ends it too.
assert(addon:RegisterDefaultBlock({
 id='retail.rogue.boundaries',revision=2,families={'retail'},class='ROGUE',steps={
 {id='casting',type='stop',suppress_attack=false,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
}}))
-- Reminders every Rogue premade shares. Between pulls: a lethal poison (Deadly, else Instant;
-- Wound or Amplifying count), a non-lethal one (Crippling; Atrophic or Numbing count), Stealth on
-- an enemy target. In combat: Kick on an interruptible cast (it lights only where Midnight lets the
-- target's cast be read). Health is secret on Retail, so Crimson Vial is yours.
assert(addon:RegisterDefaultBlock({
 id='retail.rogue.upkeep',revision=2,families={'retail'},class='ROGUE',steps={
 BuiltinConditions.spell('deadly-poison',2823,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(lethal))),
 BuiltinConditions.spell('instant-poison',315584,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(lethal),BuiltinConditions.negate({type='SPELL_KNOWN',spell=2823}))),
 BuiltinConditions.spell('crippling-poison',3408,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(BuiltinConditions.any(BuiltinConditions.ownBuff(3408),BuiltinConditions.ownBuff(381637),BuiltinConditions.ownBuff(5761))))),
 BuiltinConditions.spell('stealth',1784,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='STEALTHED'}))),
 BuiltinConditions.spell('kick',1766,BuiltinConditions.all(BuiltinConditions.combat(),interrupt)),
}}))
