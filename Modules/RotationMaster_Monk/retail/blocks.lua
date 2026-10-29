-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight 12.x) Monk blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.monk.* premade. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Your casts and channels (Fists of Fury, Celestial Conduit, Spinning Crane Kick, Crackling Jade
-- Lightning, Soothing Mist) end advice.
assert(addon:RegisterDefaultBlock({id='retail.monk.boundaries',revision=3,families={'retail'},class='MONK',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- The healer: the same, or no attackable target, ends advice (one Stop).
assert(addon:RegisterDefaultBlock({id='retail.monk.heal-boundaries',revision=2,families={'retail'},class='MONK',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},{type='NOT',value={type='ATTACKABLE',unit='target'}})),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Spear Hand Strike on an
-- interruptible cast (enemy casts are secret in Midnight combat, so it lights only where they can be
-- read), and Fortifying Brew and the racial cooldowns whenever they are ready in combat. Health is
-- secret on Retail, so the defensive is a cooldown reminder, not a health trigger.
assert(addon:RegisterDefaultBlock({id='retail.monk.utility',revision=2,families={'retail'},class='MONK',steps={
 BuiltinConditions.spell('spear-hand-strike',116705,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('fortifying-brew',115203,BuiltinConditions.combat()),
 BuiltinConditions.spell('blood-fury',33697,BuiltinConditions.combat()),
 BuiltinConditions.spell('berserking',26297,BuiltinConditions.combat()),
 BuiltinConditions.spell('fireblood',265221,BuiltinConditions.combat()),
 BuiltinConditions.spell('ancestral-call',274738,BuiltinConditions.combat()),
}}))
