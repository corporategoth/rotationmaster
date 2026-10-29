-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Retail (Midnight) Paladin blocks (Built In composition; authoring-time only).
-- Consumers: rm.retail.paladin.retribution, .retribution.icyveins, .protection,
-- .protection.icyveins, .protection.wowhead and .holy. A content change needs a block revision
-- bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research retail/paladin.md. Every condition here stays readable in Midnight combat except
-- the target's cast, which is secret there: Rebuke lights only where the game lets it be read.
-- Health is secret on Retail, so the defensives are cooldown reminders and Lay on Hands is yours.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
local interrupt=BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- Casting or channelling ends advice (Attack continues); no attackable target ends it too.
assert(addon:RegisterDefaultBlock({
 id='retail.paladin.boundaries',revision=2,families={'retail'},class='PALADIN',steps={
 {id='casting',type='stop',suppress_attack=false,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
}}))
-- Reminders every Paladin premade shares: an aura between pulls when none is up, Rebuke on an
-- interruptible cast.
assert(addon:RegisterDefaultBlock({
 id='retail.paladin.upkeep',revision=2,families={'retail'},class='PALADIN',steps={
 BuiltinConditions.spell('devotion-aura',465,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(BuiltinConditions.any(BuiltinConditions.ownBuff(465),BuiltinConditions.ownBuff(317920),BuiltinConditions.ownBuff(32223))))),
 BuiltinConditions.spell('rebuke',96231,BuiltinConditions.all(BuiltinConditions.combat(),interrupt)),
}}))
-- Protection defensives Assisted Combat never suggests: Ardent Defender and Guardian of Ancient
-- Kings whenever they are ready in combat.
assert(addon:RegisterDefaultBlock({
 id='retail.paladin.prot-defensives',revision=2,families={'retail'},class='PALADIN',steps={
 BuiltinConditions.spell('ardent-defender',31850,BuiltinConditions.combat()),
 BuiltinConditions.spell('guardian-of-ancient-kings',86659,BuiltinConditions.combat()),
}}))
-- Protection guide cooldowns (Icy Veins, SimulationCraft, Wowhead): Avenging Wrath or Sentinel,
-- Lightsmith's Holy Bulwark, and Sacred Weapon outside Avenging Wrath.
assert(addon:RegisterDefaultBlock({
 id='retail.paladin.prot-cooldowns',revision=1,families={'retail'},class='PALADIN',steps={
 BuiltinConditions.spell('avenging-wrath',31884,fight),
 BuiltinConditions.spell('sentinel',389539,fight),
 BuiltinConditions.spell('holy-bulwark',432459,fight),
 BuiltinConditions.spell('sacred-weapon',432472,BuiltinConditions.all(fight,BuiltinConditions.negate(BuiltinConditions.ownBuff(31884)),BuiltinConditions.negate(BuiltinConditions.ownBuff(389539)))),
}}))
