-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight 12.x) Mage blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.mage.* premade. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Your casts and channels (Arcane Missiles, Ray of Frost, Evocation) end advice.
assert(addon:RegisterDefaultBlock({id='retail.mage.boundaries',revision=3,families={'retail'},class='MAGE',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Arcane Intellect out of combat
-- (readable there; in combat the buff is hidden), Counterspell on an interruptible cast (enemy casts
-- are secret in Midnight combat, so it lights only where they can be read), and the racial cooldowns
-- in combat. Health is secret on Retail, so Ice Block, an emergency button, stays yours.
assert(addon:RegisterDefaultBlock({id='retail.mage.utility',revision=2,families={'retail'},class='MAGE',steps={
 BuiltinConditions.spell('arcane-intellect',1459,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='BUFF',unit='player',spell=1459}))),
 BuiltinConditions.spell('counterspell',2139,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('blood-fury',33702,BuiltinConditions.combat()),
 BuiltinConditions.spell('berserking',26297,BuiltinConditions.combat()),
 BuiltinConditions.spell('fireblood',265221,BuiltinConditions.combat()),
 BuiltinConditions.spell('ancestral-call',274738,BuiltinConditions.combat()),
}}))
