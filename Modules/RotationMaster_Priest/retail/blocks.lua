-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight) Priest blocks (Built In composition; authoring-time only).
-- Consumers: rm.retail.priest.shadow, .shadow.icyveins, .discipline, .discipline.wowhead and
-- .holy. A content change needs a block revision bump, every consumer's pin and revision bumped,
-- and both recorded in tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the
-- consumers'; see premade-research retail/priest.md.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local interrupt=BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- Shadow: casting or channelling ends advice; no attackable target ends it too.
assert(addon:RegisterDefaultBlock({
 id='retail.priest.boundaries',revision=3,families={'retail'},class='PRIEST',steps={
 {id='casting',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
}}))
-- Reminders every Priest premade shares: Power Word: Fortitude (anyone's) between pulls, Silence
-- on an interruptible cast (Shadow; the target's cast is hidden in Midnight combat, so it lights only
-- where it can be read). Health is secret on Retail, so Desperate Prayer is yours.
assert(addon:RegisterDefaultBlock({
 id='retail.priest.upkeep',revision=2,families={'retail'},class='PRIEST',steps={
 BuiltinConditions.spell('fortitude',21562,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='BUFF',unit='player',spell=21562}))),
 BuiltinConditions.spell('silence',15487,BuiltinConditions.all(BuiltinConditions.combat(),interrupt)),
}}))
-- Discipline cooldowns both guides keep on hand: Power Word: Radiance, Evangelism and Ultimate
-- Penitence in combat, Pain Suppression on a friendly target; when to press them is yours.
assert(addon:RegisterDefaultBlock({
 id='retail.priest.disc-cooldowns',revision=1,families={'retail'},class='PRIEST',steps={
 BuiltinConditions.spell('radiance',194509,BuiltinConditions.combat()),
 BuiltinConditions.spell('evangelism',472433,BuiltinConditions.combat()),
 BuiltinConditions.spell('ultimate-penitence',421453,BuiltinConditions.combat()),
 BuiltinConditions.spell('pain-suppression',33206,BuiltinConditions.all(BuiltinConditions.combat(),{type='FRIENDLY',unit='target'})),
}}))
