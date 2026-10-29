-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Warrior blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.warrior.{arms,arms.icyveins,fury,fury.icyveins,protection,unspecialized}. A content
-- change needs a block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research progression/warrior.md.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function health(op,n)return{type='HEALTHPCT',unit='player',operator=op,value=n}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function form(id)return{type='FORM',form=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local smashed={type='DEBUFF',unit='target',spell=86346,owndebuff=true}
-- Boundaries for every Warrior premade: manual casts/channels and no attackable target stop with
-- Attack suppressed; out of combat Charge (the engine checks 8-25 yd) or Heroic Throw from range, then
-- stop and let Attack start the fight.
assert(addon:RegisterDefaultBlock({
 id='mop.warrior.boundaries',revision=4,families={'progression'},class='WARRIOR',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},negate({type='ATTACKABLE',unit='target'}))},
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-charge',100),
  spell('pull-throw',57755,{type='BEYOND_MELEE',unit='target'}),
  {id='pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
}}))
-- Damage-dealer gap closing and sustain (simulator, Icy Veins): Charge for rage when you have stepped out
-- (below 66 rage), Heroic Throw from range, Victory Rush or Impending Victory under 70% health.
assert(addon:RegisterDefaultBlock({
 id='mop.warrior.gap',revision=1,families={'progression'},class='WARRIOR',steps={
 spell('charge',100,{type='POWER',unit='player',operator='LESSTHANOREQUALS',value=65}),
 spell('throw',57755,{type='BEYOND_MELEE',unit='target'}),
 {id='sustain',type='branch',conditions=health('LESSTHAN',.7),onFalse={},onTrue={spell('impending-victory',103840),spell('victory-rush',34428)}},
}}))
-- Independent reminders every damage dealer shares: a shout when neither is up, Battle Stance (Berserker
-- is left alone; stances are read by spell, so the stance bar order does not matter), the shout during Bladestorm, Skull Banner under Recklessness in a group, Heroic Leap in
-- Colossus Smash, Pummel, Die by the Sword and Enraged Regeneration when low. Shattering Throw (usually a
-- raid assignment) ships off.
assert(addon:RegisterDefaultBlock({
 id='mop.warrior.dps-upkeep',revision=2,families={'progression'},class='WARRIOR',steps={
 spell('shout',6673,all(negate(buff(6673)),negate(buff(469)))),
 spell('stance',2457,all(negate(form(2457)),negate(form(2458)))),
 spell('bladestorm-shout',6673,own(46924)),
 spell('skull-banner',114207,all(combat(),{type='GROUP'},own(1719))),
 spell('leap',6544,all(combat(),smashed)),
 spell('pummel',6552,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('die-by-the-sword',118038,all(combat(),health('LESSTHAN',.4))),
 spell('enraged-regeneration',55694,all(buff(12880),health('LESSTHAN',.5))),
 {id='shattering-throw',type='spell',action=64382,ranked=false,disabled=true,conditions=all({type='GROUP'},classified('worldboss'),
  any(negate(combat()),{type='TIME_IN_COMBAT',operator='LESSTHAN',value=3}))},
}}))
