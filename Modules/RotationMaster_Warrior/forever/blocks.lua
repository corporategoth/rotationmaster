-- Shared WoW Forever Warrior blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.warrior.dps, .dps.warcrafttavern, .protection and
-- .protection.warcrafttavern. A content change needs a block revision bump, every consumer's
-- pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research forever/warrior.md.
-- Stances are checked by spell usability; FORM 2 (Defensive Stance) only chooses the tank pack.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local interrupt=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})
-- A Slam cast in progress is kept (Attack continues); no attackable target ends advice; out of
-- combat the only advice is Charge, then stop.
assert(addon:RegisterDefaultBlock({
 id='forever.warrior.boundaries',revision=3,families={'forever'},class='WARRIOR',steps={
 {id='casting',type='stop',suppress_attack=false,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='stop',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 {id='pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
  spell('charge',100),
  {id='pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
}}))
-- Reminders every Warrior premade shares: Battle Shout (anyone's), Bloodrage whenever it is ready,
-- between pulls too (it no longer starts combat in Forever; rage and health are secret there, so
-- it no longer waits for low rage), and the interrupt the current stance allows.
assert(addon:RegisterDefaultBlock({
 id='forever.warrior.upkeep',revision=2,families={'forever'},class='WARRIOR',steps={
 spell('battle-shout',6673,any(negate({type='BUFF',unit='player',spell=6673,anyrank=true}),{type='BUFF_REMAIN',unit='player',spell=6673,anyrank=true,operator='LESSTHAN',value=3})),
 spell('bloodrage',2687),
 spell('pummel',6552,interrupt),
 spell('shield-bash',72,interrupt),
}}))
