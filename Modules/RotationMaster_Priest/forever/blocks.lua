-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared WoW Forever Priest blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.priest.dps, rm.forever.priest.dps.mobalytics and rm.forever.priest.healer.
-- A content change needs a block revision bump, every consumer's pin and revision bumped, and both
-- recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local shadowform={type='BUFF',unit='player',spell=15473}
-- Casts end advice. Channels too, except Mind Flay in Shadowform with Mind Blast ready (the only
-- Shadowform channel): Mind Blast should not wait for the Flay to finish (Mobalytics).
assert(addon:RegisterDefaultBlock({id='forever.priest.boundaries',revision=3,families={'forever'},class='PRIEST',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},BuiltinConditions.all({type='CHANNELING',unit='player'},BuiltinConditions.negate(BuiltinConditions.all(shadowform,{type='SPELL_AVAIL',spell=8092}))))),
}}))
-- Damage premades: the boundaries above, or no attackable target, end advice (one Stop).
assert(addon:RegisterDefaultBlock({id='forever.priest.dps-boundaries',revision=2,families={'forever'},class='PRIEST',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},BuiltinConditions.all({type='CHANNELING',unit='player'},BuiltinConditions.negate(BuiltinConditions.all(shadowform,{type='SPELL_AVAIL',spell=8092}))),BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))),
}}))
-- Out-of-combat buffs on yourself: Inner Fire, Fortitude and Divine Spirit (unless the Prayer
-- versions are up), and the Undead and Troll self-buffs when known.
assert(addon:RegisterDefaultBlock({id='forever.priest.upkeep',revision=1,families={'forever'},class='PRIEST',steps={
 BuiltinConditions.spell('inner-fire',588,BuiltinConditions.negate(buff(588))),
 BuiltinConditions.spell('fortitude',1243,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(buff(1243)),BuiltinConditions.negate(buff(21562)))),
 BuiltinConditions.spell('divine-spirit',14752,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(buff(14752)),BuiltinConditions.negate(buff(27681)))),
 BuiltinConditions.spell('touch-of-weakness',2652,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(buff(2652)))),
 BuiltinConditions.spell('shadowguard',18137,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(buff(18137)))),
}}))
-- Damage-dealer reminders: Vampiric Embrace on every fight, Inner Focus with Mind Blast, Silence on
-- interruptible casts, Elune's Light in combat; Psychic Scream (it can pull more mobs) is off by
-- default. Health and mana are secret on Forever, so Dark Sacrifice is the player's call.
assert(addon:RegisterDefaultBlock({id='forever.priest.dps-upkeep',revision=2,families={'forever'},class='PRIEST',steps={
 BuiltinConditions.spell('vampiric-embrace',15286,BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='DEBUFF',unit='target',spell=15286,owndebuff=true}))),
 BuiltinConditions.spell('inner-focus',14751,BuiltinConditions.all(BuiltinConditions.combat(),{type='SPELL_AVAIL',spell=8092})),
 BuiltinConditions.spell('silence',15487,{type='CAST_INTERRUPTABLE',unit='target'}),
 {id='psychic-scream',type='spell',action=8122,ranked=false,disabled=true,conditions=BuiltinConditions.all(BuiltinConditions.combat(),
  {type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2})},
 BuiltinConditions.spell('elunes-light',1259799,BuiltinConditions.combat()),
}}))
-- Wand: never toggle a running wand off (Shoot is a toggle).
assert(addon:RegisterDefaultBlock({id='forever.priest.wand',revision=2,families={'forever'},class='PRIEST',steps={
 BuiltinConditions.stop('wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),
 BuiltinConditions.spell('shoot',5019),
}}))
