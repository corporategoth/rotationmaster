-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight) Shaman blocks (Built In composition; authoring-time only).
-- Consumers: rm.retail.shaman.elemental, .elemental.icyveins, .enhancement,
-- .enhancement.stormbringer, .enhancement.totemic and .restoration. A content change needs a
-- block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research retail/shaman.md. Shields are read between pulls.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local interrupt=BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
local rest=BuiltinConditions.negate(BuiltinConditions.combat())
-- Elemental and Enhancement: casting or channelling ends advice; no attackable target too.
assert(addon:RegisterDefaultBlock({
 id='retail.shaman.boundaries',revision=2,families={'retail'},class='SHAMAN',steps={
 {id='casting',type='stop',suppress_attack=false,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
}}))
-- Reminders every Shaman premade shares: Skyfury (anyone's) between pulls, Wind Shear on an
-- interruptible cast (it lights only where Midnight lets the target's cast be read), Astral Shift
-- whenever it is ready in combat (health is secret on Retail, so it is a cooldown reminder).
assert(addon:RegisterDefaultBlock({
 id='retail.shaman.upkeep',revision=2,families={'retail'},class='SHAMAN',steps={
 BuiltinConditions.spell('skyfury',462854,BuiltinConditions.all(rest,BuiltinConditions.negate({type='BUFF',unit='player',spell=462854}))),
 BuiltinConditions.spell('wind-shear',57994,BuiltinConditions.all(BuiltinConditions.combat(),interrupt)),
 BuiltinConditions.spell('astral-shift',108271,BuiltinConditions.combat()),
}}))
-- Elemental and Enhancement between pulls: Lightning Shield. Retail has no weapon-imbue
-- condition (WEAPON is a Classic-family condition), so Flametongue, Windfury and Thunderstrike
-- Ward are left to Blizzard's suggestion, which keeps them itself.
assert(addon:RegisterDefaultBlock({
 id='retail.shaman.lightning-shield',revision=1,families={'retail'},class='SHAMAN',steps={
 BuiltinConditions.spell('lightning-shield',192106,BuiltinConditions.all(rest,BuiltinConditions.negate(BuiltinConditions.ownBuff(192106)))),
}}))
