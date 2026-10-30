-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared WoW Forever Hunter blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.hunter.ranged, rm.forever.hunter.ranged.mobalytics,
-- rm.forever.hunter.survival and rm.forever.hunter.survival.weave. A content change needs a block
-- revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Forever has no Steady Shot and abilities no longer clip Auto Shot, so nothing here times shots.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function marked()return{type='DEBUFF',unit='target',spell=1130,anyrank=true}end
local function sting()return{type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}end
local function autoShot()return{type='SPELL_AUTOREPEAT',spell=75,ranked=true}end
local function stop(id,conditions,attack)return{id=id,type='stop',suppress_attack=not attack,conditions=conditions or{}}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local moving={type='MOVING'}
-- Summon Hawk and Arcane Shot share one 6 s cooldown. Arcane takes the slot only when a Hawk was
-- summoned within 7 s and Arcane has not been fired for 17 s: Hawk, Hawk, Arcane (Wowhead).
local arcaneTurn=BuiltinConditions.all({type='SPELL_HISTORY_TIME',spell=1293241,operator='LESSTHAN',value=7},
 BuiltinConditions.negate({type='SPELL_HISTORY_TIME',spell=3044,operator='LESSTHAN',value=17}))
local worth=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},
 {type='CLASSIFICATION',unit='target',value='worldboss'},{type='INSTANCE',value='party'},{type='INSTANCE',value='raid'})
-- No attackable target, or your casts and channels (Aimed Shot, Sniper Shot, Volley, Mend Pet), end advice.
assert(addon:RegisterDefaultBlock({id='forever.hunter.boundaries',revision=4,families={'forever'},class='HUNTER',steps={
 stop('cast',BuiltinConditions.any(BuiltinConditions.negate({type='ATTACKABLE',unit='target'}),{type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- A ranged Hunter whose target is in melee (levels 1–9, or a mob that reached you): melee
-- strikes, then auto attack. Wing Clip, Disengage and traps for kiting stay with the player.
assert(addon:RegisterDefaultBlock({id='forever.hunter.deadzone',revision=3,families={'forever'},class='HUNTER',steps={
 {id='melee',type='branch',conditions={type='BEYOND_MELEE',unit='target'},onTrue={},onFalse={
  BuiltinConditions.spell('raptor-strike',2973,BuiltinConditions.negate({type='SPELL_ACTIVE',spell=2973})),
  BuiltinConditions.spell('mongoose-bite',1495),
  BuiltinConditions.spell('counterattack',19306),
  stop('melee-stop',nil,true)}},
}}))
-- The pull: Hunter's Mark unless someone's Mark is up, Sniper Shot while Rapid Killing lasts,
-- Auto Shot. Sending the pet in first stays with the player.
assert(addon:RegisterDefaultBlock({id='forever.hunter.pull',revision=3,families={'forever'},class='HUNTER',steps={
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-mark',1130,BuiltinConditions.negate(marked())),
  BuiltinConditions.spell('pull-sniper',1310687,{type='BUFF',unit='player',spell=415407}),
  BuiltinConditions.spell('pull-auto-shot',75,BuiltinConditions.negate(autoShot())),
  stop('pull-stop')}},
}}))
-- On the move only instants: Summon Hawk (keeping the cycle), Multi-Shot, Arcane Shot, own Sting.
assert(addon:RegisterDefaultBlock({id='forever.hunter.moving',revision=2,families={'forever'},class='HUNTER',steps={
 {id='moving',type='branch',conditions=moving,onFalse={},onTrue={
  BuiltinConditions.spell('moving-hawk',1293241,BuiltinConditions.negate(arcaneTurn)),
  BuiltinConditions.spell('moving-multi-shot',2643),
  BuiltinConditions.spell('moving-arcane-shot',3044),
  BuiltinConditions.spell('moving-serpent-sting',1978,BuiltinConditions.negate(sting())),
  stop('moving-stop')}},
}}))
-- Shots for a Survival Hunter out of melee: own Serpent Sting, Arcane Shot, Aimed Shot, Auto Shot.
assert(addon:RegisterDefaultBlock({id='forever.hunter.range-shots',revision=1,families={'forever'},class='HUNTER',steps={
 BuiltinConditions.spell('serpent-sting',1978,BuiltinConditions.negate(sting())),
 BuiltinConditions.spell('arcane-shot',3044),
 BuiltinConditions.spell('aimed-shot',19434,BuiltinConditions.negate(moving)),
 BuiltinConditions.spell('auto-shot',75,BuiltinConditions.all(BuiltinConditions.negate(autoShot()),BuiltinConditions.negate(moving))),
}}))
-- Survival pull: Mark, own Sting from range, then run in (auto attack allowed).
assert(addon:RegisterDefaultBlock({id='forever.hunter.survival-pull',revision=3,families={'forever'},class='HUNTER',steps={
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-mark',1130,BuiltinConditions.negate(marked())),
  BuiltinConditions.spell('pull-serpent-sting',1978,BuiltinConditions.all(BuiltinConditions.negate(sting()),{type='BEYOND_MELEE',unit='target'})),
  stop('pull-stop',nil,true)}},
}}))
-- Survival in melee with three or more enemies fighting you: Explosive Trap (it sits at your feet).
assert(addon:RegisterDefaultBlock({id='forever.hunter.melee-aoe',revision=1,families={'forever'},class='HUNTER',steps={
 {id='aoe',type='branch',conditions=engaged(3),onFalse={},onTrue={BuiltinConditions.spell('aoe-explosive-trap',13813)}},
}}))
-- Aspects for a ranged Hunter: Hawk in combat (Monkey before Hawk is learned); Cheetah to travel
-- is optional and off by default. A chosen Wild, Pack or Beast is left alone out of combat.
assert(addon:RegisterDefaultBlock({id='forever.hunter.aspects-ranged',revision=1,families={'forever'},class='HUNTER',steps={
 BuiltinConditions.spell('aspect-hawk',13165,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(own(13165)))),
 BuiltinConditions.spell('aspect-monkey',13163,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(BuiltinConditions.known(13165)),BuiltinConditions.negate(own(13163)))),
 {id='aspect-cheetah',type='spell',action=5118,ranked=false,disabled=true,conditions=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),
  BuiltinConditions.negate(own(13165)),BuiltinConditions.negate(own(13163)),BuiltinConditions.negate(own(5118)),BuiltinConditions.negate(own(13159)),BuiltinConditions.negate(own(13161)))},
}}))
-- Pet care: call a missing pet, revive a dead one. Feeding is manual (RM cannot read happiness),
-- and so is Mend Pet (health is secret on Forever); Lone Wolf players disable these.
assert(addon:RegisterDefaultBlock({id='forever.hunter.pet-care',revision=2,families={'forever'},class='HUNTER',steps={
 BuiltinConditions.spell('call-pet',883,BuiltinConditions.negate({type='PET'})),
 BuiltinConditions.spell('revive-pet',982,{type='DEAD',unit='pet'}),
}}))
-- Major cooldowns only where they matter: an elite, rare elite or boss, or a group instance.
assert(addon:RegisterDefaultBlock({id='forever.hunter.burst',revision=1,families={'forever'},class='HUNTER',steps={
 BuiltinConditions.spell('bestial-wrath',19574,BuiltinConditions.all(BuiltinConditions.combat(),worth,{type='PET'})),
 BuiltinConditions.spell('rapid-fire',3045,BuiltinConditions.all(BuiltinConditions.combat(),worth,BuiltinConditions.negate({type='BUFF',unit='player',spell=3045}))),
 BuiltinConditions.spell('blood-fury',20572,BuiltinConditions.all(BuiltinConditions.combat(),worth)),
}}))
