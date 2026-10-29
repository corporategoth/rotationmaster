-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight 12.x) Druid blocks (Built In composition; authoring-time only).
-- Consumers: every rm.retail.druid.* premade. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Your casts and channels (Convoke the Spirits, Tranquility) end advice.
assert(addon:RegisterDefaultBlock({id='retail.druid.boundaries',revision=3,families={'retail'},class='DRUID',steps={
 BuiltinConditions.stop('cast',{type='OR',value={{type='CASTING',unit='player'},{type='CHANNELING',unit='player'}}}),
}}))
-- What Blizzard's Assisted Combat never suggests, for every spec: Mark of the Wild out of combat,
-- and Barkskin and the racial cooldowns whenever they are ready in combat. Health is secret on
-- Retail, so the defensive is a cooldown reminder, not a health trigger.
assert(addon:RegisterDefaultBlock({id='retail.druid.utility',revision=2,families={'retail'},class='DRUID',steps={
 BuiltinConditions.spell('mark-of-the-wild',1126,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='BUFF',unit='player',spell=1126}))),
 BuiltinConditions.spell('barkskin',22812,BuiltinConditions.combat()),
 BuiltinConditions.spell('berserking',26297,BuiltinConditions.combat()),
 BuiltinConditions.spell('ancestral-call',274738,BuiltinConditions.combat()),
}}))
