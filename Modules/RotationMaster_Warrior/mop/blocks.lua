-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Warrior blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.warrior.{arms,arms.icyveins,fury,fury.icyveins,protection,unspecialized}. A content
-- change needs a block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research progression/warrior.md.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function health(op,n)return{type='HEALTHPCT',unit='player',operator=op,value=n}end
local smashed={type='DEBUFF',unit='target',spell=86346,owndebuff=true}
-- Boundaries for every Warrior premade: manual casts/channels and no attackable target stop with
-- Attack suppressed; out of combat Charge (the engine checks 8-25 yd) or Heroic Throw from range, then
-- stop and let Attack start the fight.
assert(addon:RegisterDefaultBlock({
 id='mop.warrior.boundaries',revision=4,families={'progression'},class='WARRIOR',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-charge',100),
  BuiltinConditions.spell('pull-throw',57755,{type='BEYOND_MELEE',unit='target'}),
  {id='pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
}}))
-- Damage-dealer gap closing and sustain (simulator, Icy Veins): Charge for rage when you have stepped out
-- (below 66 rage), Heroic Throw from range, Victory Rush or Impending Victory under 70% health.
assert(addon:RegisterDefaultBlock({
 id='mop.warrior.gap',revision=1,families={'progression'},class='WARRIOR',steps={
 BuiltinConditions.spell('charge',100,{type='POWER',unit='player',operator='LESSTHANOREQUALS',value=65}),
 BuiltinConditions.spell('throw',57755,{type='BEYOND_MELEE',unit='target'}),
 {id='sustain',type='branch',conditions=health('LESSTHAN',.7),onFalse={},onTrue={BuiltinConditions.spell('impending-victory',103840),BuiltinConditions.spell('victory-rush',34428)}},
}}))
-- Independent reminders every damage dealer shares: a shout when neither is up, Battle Stance (Berserker
-- is left alone; stances are read by spell, so the stance bar order does not matter), the shout during Bladestorm, Skull Banner under Recklessness in a group, Heroic Leap in
-- Colossus Smash, Pummel, Die by the Sword and Enraged Regeneration when low. Shattering Throw (usually a
-- raid assignment) ships off.
assert(addon:RegisterDefaultBlock({
 id='mop.warrior.dps-upkeep',revision=2,families={'progression'},class='WARRIOR',steps={
 BuiltinConditions.spell('shout',6673,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.buff(6673)),BuiltinConditions.negate(BuiltinConditions.buff(469)))),
 BuiltinConditions.spell('stance',2457,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.form(2457)),BuiltinConditions.negate(BuiltinConditions.form(2458)))),
 BuiltinConditions.spell('bladestorm-shout',6673,BuiltinConditions.ownBuff(46924)),
 BuiltinConditions.spell('skull-banner',114207,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.ownBuff(1719))),
 BuiltinConditions.spell('leap',6544,BuiltinConditions.all(BuiltinConditions.combat(),smashed)),
 BuiltinConditions.spell('pummel',6552,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('die-by-the-sword',118038,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.4))),
 BuiltinConditions.spell('enraged-regeneration',55694,BuiltinConditions.all(BuiltinConditions.buff(12880),health('LESSTHAN',.5))),
 {id='shattering-throw',type='spell',action=64382,ranked=false,disabled=true,conditions=BuiltinConditions.all({type='GROUP'},BuiltinConditions.classified('worldboss'),
  BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.combat()),{type='TIME_IN_COMBAT',operator='LESSTHAN',value=3}))},
}}))
