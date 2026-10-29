-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight 12.x) Hunter blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.hunter.* premade. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Your casts and channels (Aimed Shot, Steady Shot, Rapid Fire) end advice.
assert(addon:RegisterDefaultBlock({id='retail.hunter.boundaries',revision=3,families={'retail'},class='HUNTER',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Counter Shot (Beast Mastery,
-- Marksmanship) or Muzzle (Survival) on an interruptible cast (enemy casts are secret in Midnight
-- combat, so it lights only where they can be read), and Survival of the Fittest and the racial
-- cooldowns whenever they are ready in combat. Health is secret on Retail, so the damage reduction
-- is a cooldown reminder, and the emergency buttons (Exhilaration, Aspect of the Turtle) stay yours.
local interruptible=BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
assert(addon:RegisterDefaultBlock({id='retail.hunter.utility',revision=2,families={'retail'},class='HUNTER',steps={
 BuiltinConditions.spell('counter-shot',147362,interruptible),
 BuiltinConditions.spell('muzzle',187707,interruptible),
 BuiltinConditions.spell('survival-of-the-fittest',264735,BuiltinConditions.combat()),
 BuiltinConditions.spell('blood-fury',20572,BuiltinConditions.combat()),
 BuiltinConditions.spell('berserking',26297,BuiltinConditions.combat()),
 BuiltinConditions.spell('fireblood',265221,BuiltinConditions.combat()),
 BuiltinConditions.spell('ancestral-call',274738,BuiltinConditions.combat()),
}}))
-- Before the pull: Hunter's Mark on a target that does not carry one.
assert(addon:RegisterDefaultBlock({id='retail.hunter.mark',revision=1,families={'retail'},class='HUNTER',steps={
 BuiltinConditions.spell('hunters-mark',257284,BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='DEBUFF',unit='target',spell=257284}))),
}}))
