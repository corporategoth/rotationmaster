-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight 12.x) Evoker blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.evoker.* premade. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Your casts, channels (Disintegrate) and empowers (Fire Breath, Eternity Surge, Upheaval, Dream
-- Breath: the game reports an empower as a channel) end advice.
assert(addon:RegisterDefaultBlock({id='retail.evoker.boundaries',revision=3,families={'retail'},class='EVOKER',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- The healer: the same, or no attackable target, ends advice (one Stop).
assert(addon:RegisterDefaultBlock({id='retail.evoker.heal-boundaries',revision=2,families={'retail'},class='EVOKER',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Quell on an interruptible cast,
-- Obsidian Scales whenever it is ready in combat, and out of combat Blessing of the Bronze when it is
-- missing and Source of Magic on a friendly target in your group. Enemy casts are secret in Midnight
-- combat, so Quell lights only where they can be read; health is secret on Retail, so the defensive
-- is a cooldown reminder. Dracthyr have no racial cooldown to add.
assert(addon:RegisterDefaultBlock({id='retail.evoker.utility',revision=2,families={'retail'},class='EVOKER',steps={
 BuiltinConditions.spell('quell',351338,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('obsidian-scales',363916,BuiltinConditions.combat()),
 BuiltinConditions.spell('blessing-of-the-bronze',364342,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='BUFF',unit='player',spell=381748}))),
 BuiltinConditions.spell('source-of-magic',369459,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='GROUP'},{type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='BUFF',unit='target',spell=369459,ownbuff=true}))),
}}))
