-- Shared Retail (Midnight) Warrior blocks (Built In composition; authoring-time only).
-- Consumers: rm.retail.warrior.arms, .arms.slayer, .arms.colossus, .fury, .fury.slayer,
-- .fury.thane, .protection and .protection.icyveins. A content change needs a block revision
-- bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research retail/warrior.md.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- Casting or channelling ends advice (Attack continues); no attackable target ends it too.
assert(addon:RegisterDefaultBlock({
 id='retail.warrior.boundaries',revision=1,families={'retail'},class='WARRIOR',steps={
 {id='casting',type='none',suppress_attack=false,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
}}))
-- Reminders every Warrior premade shares: Battle Shout (anyone's) between pulls, Pummel on an
-- interruptible cast (the target's cast is hidden in Midnight combat, so it lights only where it
-- can be read).
assert(addon:RegisterDefaultBlock({
 id='retail.warrior.upkeep',revision=1,families={'retail'},class='WARRIOR',steps={
 spell('battle-shout',6673,all(negate(combat()),negate({type='BUFF',unit='player',spell=6673}))),
 spell('pummel',6552,all(combat(),interrupt)),
}}))
-- The guide lists open with Charge: out of combat, Charge, then stop.
assert(addon:RegisterDefaultBlock({
 id='retail.warrior.charge',revision=2,families={'retail'},class='WARRIOR',steps={
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('charge',100),
  {id='pull-stop',type='none',suppress_attack=false,conditions={}},
 }},
}}))
