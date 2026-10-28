-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared WoW Forever Druid blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.druid.balance, rm.forever.druid.balance.tavern, rm.forever.druid.feral,
-- rm.forever.druid.restoration and rm.forever.druid.restoration.icyveins. A content change needs a
-- block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Forms are read from their auras (the shapeshift-bar index moves as forms are learned).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function aura(id)return{type='BUFF',unit='player',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
-- Casts and channels (Starfire, Hurricane, Tranquility, Healing Touch) and travel forms end advice.
assert(addon:RegisterDefaultBlock({id='forever.druid.boundaries',revision=3,families={'forever'},class='DRUID',steps={
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},aura(783),aura(1066))),
}}))
-- Out of combat: Mark of the Wild unless Mark or Gift is up; Thorns on yourself while solo
-- (in a group it belongs on the tank, by hand). Omen of Clarity is passive on Forever.
assert(addon:RegisterDefaultBlock({id='forever.druid.upkeep',revision=1,families={'forever'},class='DRUID',steps={
 spell('mark',1126,all(negate(combat()),negate(buff(1126)),negate(buff(21849)))),
 spell('thorns',467,all(negate(combat()),negate({type='GROUP'}),negate(buff(467)))),
}}))
-- Your own Moonfire, then your own Insect Swarm (Balance talent). DoTs do not snapshot on Forever,
-- so a running one is never refreshed early. Health is secret on Forever, so a nearly dead target
-- still gets them.
assert(addon:RegisterDefaultBlock({id='forever.druid.dots',revision=2,families={'forever'},class='DRUID',steps={
 spell('moonfire',8921,negate(dot(8921))),
 spell('insect-swarm',5570,negate(dot(5570))),
}}))
-- A healer's spare-time damage on a hostile target: the DoTs, then Wrath; nothing else.
assert(addon:RegisterDefaultBlock({id='forever.druid.spare-damage',revision=2,families={'forever'},class='DRUID',steps={
 {id='dots',type='block',block='forever.druid.dots',prefix='spare-'},
 spell('wrath',5176),
 stop('done'),
}}))
-- Healer reminders: Nature's Swiftness in combat on a friendly target, curse and poison removal on
-- the friendly target. Health is secret on Forever, so whether the target is dying, and Tranquility,
-- are the player's call.
local friendly={type='FRIENDLY',unit='target'}
local function dispel(kind)return all(friendly,{type='DISPELLABLE',unit='target',debufftype=kind})end
assert(addon:RegisterDefaultBlock({id='forever.druid.healer-upkeep',revision=2,families={'forever'},class='DRUID',steps={
 spell('swiftness',17116,all(combat(),friendly)),
 spell('remove-curse',2782,dispel('Curse')),
 spell('abolish-poison',2893,dispel('Poison')),
 spell('cure-poison',8946,all(negate({type='SPELL_KNOWN',spell=2893}),dispel('Poison'))),
}}))
