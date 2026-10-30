-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight 12.x) Demon Hunter blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.demonhunter.* premade. A content change needs a block revision bump,
-- every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Your casts and channels (Eye Beam, Fel Devastation, Void Ray, Collapsing Star) end advice.
assert(addon:RegisterDefaultBlock({id='retail.demonhunter.boundaries',revision=3,families={'retail'},class='DEMONHUNTER',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Disrupt on an interruptible cast
-- (enemy casts are secret in Midnight combat, so it lights only where they can be read) and Blur
-- whenever it is ready in combat: health is secret on Retail, so the defensive is a cooldown reminder.
assert(addon:RegisterDefaultBlock({id='retail.demonhunter.utility',revision=2,families={'retail'},class='DEMONHUNTER',steps={
 BuiltinConditions.spell('disrupt',183752,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('blur',198589,BuiltinConditions.combat()),
}}))
