-- Shared Classic Era Warrior blocks, vanilla and Season of Discovery (Built In composition;
-- authoring-time only). Consumers: rm.era.warrior.dps, .protection, .protection.icyveins and
-- rm.sod.warrior.dps, .dps.wowhead, .dps.icyveins, .tank. A content change needs a block revision
-- bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research era/warrior.md. Stances are
-- checked by spell usability; Defensive Stance (FORM by spell, 71) only chooses the tank premades.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- A Slam cast in progress is kept (Attack continues); no attackable target ends advice; out of
-- combat the only advice is Charge, then stop.
assert(addon:RegisterDefaultBlock({
 id='era.warrior.boundaries',revision=3,families={'era'},class='WARRIOR',steps={
 {id='casting',type='stop',suppress_attack=false,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='stop',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 {id='pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
  spell('charge',100),
  {id='pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
}}))
-- Reminders every Warrior premade shares: Battle Shout (anyone's) missing or in its last three
-- seconds, and the interrupt the current stance allows.
assert(addon:RegisterDefaultBlock({
 id='era.warrior.upkeep',revision=1,families={'era'},class='WARRIOR',steps={
 spell('battle-shout',6673,any(negate({type='BUFF',unit='player',spell=6673,anyrank=true}),{type='BUFF_REMAIN',unit='player',spell=6673,anyrank=true,operator='LESSTHAN',value=3})),
 spell('pummel',6552,interrupt),
 spell('shield-bash',72,interrupt),
}}))
-- Area strikes on a pack: Whirlwind, or Thunder Clap while Whirlwind is not yet learned.
assert(addon:RegisterDefaultBlock({
 id='era.warrior.aoe-strikes',revision=1,families={'era'},class='WARRIOR',steps={
 spell('aoe-whirlwind',1680),
 spell('aoe-thunder-clap',6343,all(negate({type='SPELL_KNOWN',spell=1680}),negate({type='DEBUFF',unit='target',spell=6343,anyrank=true}))),
}}))
